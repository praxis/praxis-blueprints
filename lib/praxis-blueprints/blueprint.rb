require 'ostruct'

# Blueprint ==
#   - part implementation definition for attributes
#   - part container for views

module Praxis
  class Blueprint
    include Attributor::Type
    extend Finalizable

    if RUBY_ENGINE =~ /^jruby/
      # We are "forced" to require it here (in case hasn't been yet) to make sure the added methods have been applied
      require 'java'
      # Only to then delete them, to make sure we don't have them clashing with any attributes
      undef java, javax, org, com
    end

    @@caching_enabled = false

    CIRCULAR_REFERENCE_MARKER = '...'.freeze

    attr_accessor :object, :decorators
    attr_reader :validating, :active_renders

    class << self
      attr_reader :views, :attribute, :options
      attr_accessor :reference
    end

    def self.inherited(klass)
      super

      klass.instance_eval do
        @views = Hash.new
        @options = Hash.new
      end
    end

    # Override default new behavior to support memoized creation through an IdentityMap
    def self.new(object, decorators=nil)
      if @@caching_enabled && decorators.nil?
        key = object

        cache = if object.respond_to?(:identity_map) && object.identity_map
          object.identity_map.blueprint_cache[self]
        else
          self.cache
        end

        return cache[key] ||= begin
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

    def self.describe(shallow=false)
      type_name = self.ancestors.find { |k| k.name && !k.name.empty? }.name

      description = self.attribute.type.describe(shallow).merge!(id: self.id, name: type_name)

      unless shallow
        description[:views] = self.views.each_with_object({}) do |(view_name, view), hash|
          hash[view_name] = view.describe
        end
      end

      description
    end


    def self.attributes(opts={}, &block)
      if block_given?
        if self.const_defined?(:Struct, false)
          raise "Redefining Blueprint attributes is not currently supported"
        else

          if opts.has_key?(:reference) && opts[:reference] != self.reference
            raise "Reference mismatch in #{self.inspect}. Given :reference option #{opts[:reference].inspect}, while using #{self.reference.inspect}"
          elsif self.reference
            opts[:reference] = self.reference #pass the reference Class down
          else
            opts[:reference] = self
          end

          @options.merge!(opts)
          @block = block
        end

        return @attribute
      end

      unless @attribute
        raise "@attribute not defined yet for #{self.name}"
      end

      @attribute.attributes
    end


    def self.check_option!(name, value)
      case name
      when :identity
        raise Attributor::AttributorException, "Invalid identity type #{value.inspect}" unless value.kind_of?(::Symbol)
        return :ok
      else
        return Attributor::Struct.check_option!(name, value)
      end
    end


    def self.load(value,context=Attributor::DEFAULT_ROOT_CONTEXT, **options)
      case value
      when self
        value
      when nil, Hash, String
        # Need to parse/deserialize first
        # or apply default/recursive loading options if necessary
        if (value = self.attribute.load(value,context, **options))
          self.new(value)
        end
      else
        # Just wrap whatever value
        self.new(value)
      end
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
      value.kind_of?(self) || value.kind_of?(self.attribute.type)
    end

    def self.example(context=nil, **values)
      context = case context
      when nil
        ["#{self.name}-#{values.object_id.to_s}"]
      when ::String
        [context]
      else
        context
      end

      self.new(self.attribute.example(context, values: values))
    end


    def self.validate(value, context=Attributor::DEFAULT_ROOT_CONTEXT, _attribute=nil)

      raise ArgumentError, "Invalid context received (nil) while validating value of type #{self.name}" if context == nil
      context = [context] if context.is_a? ::String

      unless value.kind_of?(self)
        raise ArgumentError, "Error validating #{Attributor.humanize_context(context)} as #{self.name} for an object of type #{value.class.name}."
      end

      value.validate(context)
    end


    def self.view(name, **options, &block)
      if block_given?
        return self.views[name] = View.new(name, self, **options, &block)
      end

      self.views[name]
    end

    def self.dump(object, view: :default, context: Attributor::DEFAULT_ROOT_CONTEXT, **opts)
      object = self.load(object, context, **opts)
      return nil if object.nil?

      object.render(view: view, context: context, **opts)
    end

    # Allow render on the class too, for completeness and consistency
    def self.render(object, **opts)
      self.dump(object, **opts)
    end

    # Internal finalize! logic
    def self._finalize!
      if @block
        self.define_attribute!
        self.define_readers!
        # Don't blindly override a master view if the MediaType wants to define it on its own
        self.generate_master_view! unless self.view(:master)
      end
      super
    end

    def self.define_attribute!
      @attribute = Attributor::Attribute.new(Attributor::Struct, @options, &@block)
      @block = nil
      self.const_set(:Struct, @attribute.type)
    end

    def self.define_readers!
      self.attributes.each do |name, attribute|
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
          return value if value.nil? || value.kind_of?(attribute.type)
          attribute.load(value)
        end
      end
    end


    def self.generate_master_view!
      attributes = self.attributes
      view :master do
        attributes.each do | name, attr |
          # Note: we can freely pass master view for attributes that aren't blueprint/containers because
          # their dump methods will ignore it (they always dump everything regardless)
          attribute name, view: :master
        end
      end
    end


    def initialize(object, decorators=nil)
      # TODO: decide what sort of type checking (if any) we want to perform here.
      @object = object
      @decorators = if decorators.kind_of?(Hash) && decorators.any?
        OpenStruct.new(decorators)
      else
        decorators
      end
      @rendered_views = {}
      @validating = false

      # OPTIMIZE: revisit the circular rendering tracking.
      #           removing this results in a significant performance
      #           and memory use savings.
      @active_renders = []
    end


    # Render the wrapped data with the given view
    def render(view_name=nil, context: Attributor::DEFAULT_ROOT_CONTEXT,**opts)
      if view_name != nil
        warn "DEPRECATED: please do not pass the view name as the first parameter in Blueprint.render, pass through the view: named param instead."
      else
        view_name = :default # Backwards compatibility with the default param value
      end

      # Allow the opts to specify the view name for consistency with dump (overriding the deprecated named param)
      view_name = opts[:view] if opts[:view]
      unless (view = self.class.views[view_name])
        raise "view with name '#{view_name.inspect}' is not defined in #{self.class}"
      end

      rendered_key = if fields = opts[:fields]
        if fields.is_a? Array
          # Accept a simple array of fields, and transform it to a 1-level hash with nil values
          opts[:fields] = opts[:fields].each_with_object({}) {|field, hash| hash[field] = nil }
        end
        # Rendered key needs to be different if only some fields were output
        "%s:#%s" % [view_name, opts[:fields].hash.to_s]
      else
        view_name
      end

      return @rendered_views[rendered_key] if @rendered_views.has_key? rendered_key
      return CIRCULAR_REFERENCE_MARKER if @active_renders.include?(rendered_key)
      @active_renders << rendered_key

      @rendered_views[rendered_key] = view.dump(self, context: context,**opts)
    ensure
      @active_renders.delete rendered_key
    end
    alias_method :to_hash, :render


    def dump(view: :default, context: Attributor::DEFAULT_ROOT_CONTEXT)
      self.render(view: view, context: context)
    end


    def validate(context=Attributor::DEFAULT_ROOT_CONTEXT)
      raise ArgumentError, "Invalid context received (nil) while validating value of type #{self.name}" if context == nil
      context = [context] if context.is_a? ::String

      raise "validation conflict" if @validating
      @validating = true

      self.class.attributes.each_with_object(Array.new) do |(sub_attribute_name, sub_attribute), errors|
        sub_context = self.class.generate_subcontext(context,sub_attribute_name)
        value = self.send(sub_attribute_name)

        if value.respond_to?(:validating) # really, it's a thing with sub-attributes
          next if value.validating
        end
        errors.push *sub_attribute.validate(value, sub_context)
      end
    ensure
      @validating = false
    end

  end

end
