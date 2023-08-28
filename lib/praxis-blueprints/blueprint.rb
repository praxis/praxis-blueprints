# frozen_string_literal: true

require 'ostruct'

# Blueprint ==
#   - part implementation definition for attributes
#   - part container for views

module Praxis
  class Blueprint
    include Attributor::Type
    include Attributor::Dumpable

    extend Finalizable

    if RUBY_ENGINE =~ /^jruby/
      # We are "forced" to require it here (in case hasn't been yet) to make sure the added methods have been applied
      require 'java'
      # Only to then delete them, to make sure we don't have them clashing with any attributes
      undef java, javax, org, com
    end

    @@caching_enabled = false

    attr_reader :validating
    attr_accessor :object, :decorators

    class << self
      attr_reader :views, :attribute, :options
      attr_accessor :reference
    end

    def self.inherited(klass)
      super

      klass.instance_eval do
        @views = {}
        @options = {}
        @domain_model = Object
      end
    end

    # Override default new behavior to support memoized creation through an IdentityMap
    def self.new(object, decorators = nil)
      if @@caching_enabled && decorators.nil?
        cache = if object.respond_to?(:identity_map) && object.identity_map
                  object.identity_map.blueprint_cache[self]
                else
                  self.cache
                end

        return cache[object] ||= begin
          blueprint = self.allocate
          blueprint.send(:initialize, object, decorators)
          blueprint
        end
      end

      blueprint = self.allocate
      blueprint.send(:initialize, object, decorators)
      blueprint
    end

    def self.family
      'hash'
    end

    def self.describe(shallow = false, example: nil, **opts)
      type_name = self.ancestors.find { |k| k.name && !k.name.empty? }.name

      example = example.object if example

      description = self.attribute.type.describe(shallow, example: example, **opts).merge!(id: self.id, name: type_name)
      description.delete :anonymous # discard the Struct's view of anonymity, and use the Blueprint's one
      description[:anonymous] = @_anonymous unless @_anonymous.nil?

      unless shallow
        description[:views] = self.views.each_with_object({}) do |(view_name, view), hash|
          hash[view_name] = view.describe
        end
      end

      description
    end

    def self.attributes(opts = {}, &block)
      if block_given?
        raise 'Redefining Blueprint attributes is not currently supported' if self.const_defined?(:Struct, false)

        if opts.key?(:reference) && opts[:reference] != self.reference
          raise "Reference mismatch in #{self.inspect}. Given :reference option #{opts[:reference].inspect}, while using #{self.reference.inspect}"
        elsif self.reference
          opts[:reference] = self.reference # pass the reference Class down
        else
          opts[:reference] = self
        end

        @options.merge!(opts)
        @block = block

        return @attribute
      end

      raise "@attribute not defined yet for #{self.name}" unless @attribute

      @attribute.attributes
    end

    def self.domain_model(klass = nil)
      return @domain_model if klass.nil?

      @domain_model = klass
    end

    def self.check_option!(name, value)
      case name
      when :identity
        raise Attributor::AttributorException, "Invalid identity type #{value.inspect}" unless value.is_a?(::Symbol)

        :ok
      else
        Attributor::Struct.check_option!(name, value)
      end
    end

    def self.load(value, context = Attributor::DEFAULT_ROOT_CONTEXT, **options)
      case value
      when self
        value
      when nil, Hash, String
        # Need to parse/deserialize first
        # or apply default/recursive loading options if necessary
        if (value = self.attribute.load(value, context, **options))
          self.new(value)
        end
      else
        if value.is_a?(self.domain_model) || value.is_a?(self::Struct)
          # Wrap the value directly
          self.new(value)
        else
          # Wrap the object inside the domain_model
          self.new(domain_model.new(value))
        end
      end
    end

    class << self
      alias from load
    end

    def self.caching_enabled?
      @@caching_enabled
    end

    def self.caching_enabled=(caching_enabled)
      @@caching_enabled = caching_enabled
    end

    # Fetch current blueprint cache, scoped by this class
    def self.cache
      Thread.current[:praxis_blueprints_cache][self]
    end

    def self.cache=(cache)
      Thread.current[:praxis_blueprints_cache] = cache
    end

    def self.valid_type?(value)
      # FIXME: this should be more... ducklike
      value.is_a?(self) || value.is_a?(self.attribute.type)
    end

    def self.example(context = nil, **values)
      context = case context
                when nil
                  ["#{self.name}-#{values.object_id}"]
                when ::String
                  [context]
                else
                  context
                end

      self.new(self.attribute.example(context, values: values))
    end

    def self.validate(value, context = Attributor::DEFAULT_ROOT_CONTEXT, _attribute = nil)
      raise ArgumentError, "Invalid context received (nil) while validating value of type #{self.name}" if context.nil?

      context = [context] if context.is_a? ::String

      raise ArgumentError, "Error validating #{Attributor.humanize_context(context)} as #{self.name} for an object of type #{value.class.name}." unless value.is_a?(self)

      value.validate(context)
    end

    def self.view(name, **options, &block)
      return self.views[name] = View.new(name, self, **options, &block) if block_given?

      self.views[name]
    end

    def self.dump(object, view: :default, context: Attributor::DEFAULT_ROOT_CONTEXT, **opts)
      object = self.load(object, context, **opts)
      return nil if object.nil?

      object.render(view: view, context: context, **opts)
    end
    class << self
      alias render dump
    end

    # Internal finalize! logic
    def self._finalize!
      if @block
        self.define_attribute!
        self.define_readers!
        # Don't blindly override a master view if the MediaType wants to define it on its own
        self.generate_master_view! unless self.view(:master)
        self.resolve_domain_model!
      end
      super
    end

    def self.resolve_domain_model!
      return unless self.domain_model.is_a?(String)

      @domain_model = self.domain_model.constantize
    end

    def self.define_attribute!
      @attribute = Attributor::Attribute.new(Attributor::Struct, @options, &@block)
      @block = nil
      @attribute.type.anonymous_type true
      self.const_set(:Struct, @attribute.type)
    end

    def self.define_readers!
      self.attributes.each do |name, _attribute|
        name = name.to_sym

        # Don't redefine existing methods
        next if self.instance_methods.include? name

        define_reader! name
      end
    end

    def self.define_reader!(name)
      attribute = self.attributes[name]
      # TODO: profile and optimize
      # because we use the attribute in the reader,
      # it's likely faster to use define_method here
      # than module_eval, but we should make sure.
      define_method(name) do
        if @decorators && @decorators.respond_to?(name)
          @decorators.send(name)
        else
          value = @object.__send__(name)
          return value if value.nil? || value.is_a?(attribute.type)

          attribute.load(value)
        end
      end
    end

    def self.generate_master_view!
      attributes = self.attributes
      view :master do
        attributes.each do |name, _attr|
          # NOTE: we can freely pass master view for attributes that aren't blueprint/containers because
          # their dump methods will ignore it (they always dump everything regardless)
          attribute name, view: :default
        end
      end
    end

    def initialize(object, decorators = nil)
      # TODO: decide what sort of type checking (if any) we want to perform here.
      @object = object

      @decorators = if decorators.is_a?(Hash) && decorators.any?
                      OpenStruct.new(decorators)
                    else
                      decorators
                    end

      @validating = false
    end

    # By default we'll use the object identity, to avoid rendering the same object twice
    # Override, if there is a better way cache things up
    def _cache_key
      self.object
    end

    # Render the wrapped data with the given view
    def render(view_name = nil, context: Attributor::DEFAULT_ROOT_CONTEXT, renderer: Renderer.new, **opts)
      if !view_name.nil?
        warn 'DEPRECATED: please do not pass the view name as the first parameter in Blueprint.render, pass through the view: named param instead.'
      elsif opts.key?(:view)
        view_name = opts[:view]
      end

      fields = opts[:fields]
      view_name = :default if view_name.nil? && fields.nil?

      if view_name
        unless (view = self.class.views[view_name])
          raise "view with name '#{view_name.inspect}' is not defined in #{self.class}"
        end

        return view.render(self, context: context, renderer: renderer)
      end

      # Accept a simple array of fields, and transform it to a 1-level hash with true values
      fields = fields.each_with_object({}) { |field, hash| hash[field] = true } if fields.is_a? Array

      # expand fields
      expanded_fields = FieldExpander.expand(self.class, fields)

      renderer.render(self, expanded_fields, context: context)
    end

    alias dump render

    def to_h
      Attributor.recursive_to_h(@object)
    end

    def validate(context = Attributor::DEFAULT_ROOT_CONTEXT)
      raise ArgumentError, "Invalid context received (nil) while validating value of type #{self.name}" if context.nil?

      context = [context] if context.is_a? ::String
      keys_with_values = []

      raise 'validation conflict' if @validating

      @validating = true

      errors = []
      self.class.attributes.each do |sub_attribute_name, sub_attribute|
        sub_context = self.class.generate_subcontext(context, sub_attribute_name)
        value = self.send(sub_attribute_name)
        keys_with_values << sub_attribute_name unless value.nil?

        next if value.respond_to?(:validating) && value.validating # really, it's a thing with sub-attributes

        errors.concat(sub_attribute.validate(value, sub_context))
      end
      self.class.attribute.type.requirements.each do |req|
        validation_errors = req.validate(keys_with_values, context)
        errors.concat(validation_errors) unless validation_errors.empty?
      end
      errors
    ensure
      @validating = false
    end

    # generic semi-private getter used by Renderer
    def _get_attr(name)
      self.send(name)
    end

    # Delegates the json-schema methods to the underlying attribute/member_type
    def self.as_json_schema(**args)
      @attribute.type.as_json_schema(args)
    end

    def self.json_schema_type
      @attribute.type.json_schema_type
    end
  end
end
