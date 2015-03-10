module Praxis

  class View
    attr_reader :schema
    attr_reader :contents
    attr_reader :name
    attr_reader :options

    attr_reader :include_unset
    attr_reader :include_nil

    def initialize(name, schema, **options, &block)
      @name = name
      @schema = schema
      @contents = ::Hash.new
      @block = block

      @include_unset = options.fetch(:include_unset, false)
      # implicitly set include_nil to true when include_unset is true
      @include_nil = options.fetch(:include_nil, @include_unset)

      if @include_unset && !@include_nil
        msg = "Error while defining view with name #{name.inspect} for schema #{schema.inspect}."
        msg += " include_nil may not be false if include_unset is true"
        raise ArgumentError, msg
      end

      @options = options

    end

    def contents
      if @block
        self.instance_eval(&@block)
        @block = nil
      end

      @contents
    end


    def dump(object, context: Attributor::DEFAULT_ROOT_CONTEXT,**opts)

      self.contents.each_with_object({}) do |(name, (dumpable, dumpable_opts)), hash|
        unless object.respond_to?(name)
          warn "#{object} does not respond to #{name} during rendering???"
          next
        end

        begin
          value = object.send(name)
        rescue => e
          raise Attributor::DumpError, context: context, name: name, type: object.class, original_exception: e
        end

        if value.nil?
          unless @include_unset
            if object.respond_to?(:key?)
              next unless object.key?(name)
            else
              msg = "WARNING: #{object} does not respond to :key? during rendering for #{Attributor.humanize_context(context)}. "
              msg += "Can not check key #{name.inspect} is set, but include_unset option is true."
              warn msg
            end
          end

          next unless @include_nil
        end
        
        # FIXME: this is such an ugly way to do this. Need attributor#67.
        if dumpable.kind_of?(View) || dumpable.kind_of?(CollectionView)
          new_context = context + [name]
          hash[name] = dumpable.dump(value, context: new_context ,**(dumpable_opts||{}))
        else
          type = dumpable.type
          if type.respond_to?(:attributes) || type.respond_to?(:member_attribute)
            new_context = context + [name]
            hash[name] = dumpable.dump(value, context: new_context ,**(dumpable_opts||{}))
          else
            hash[name] = value
          end
        end
      end
    end
    alias_method :to_hash, :dump


    def attribute(name, opts={}, &block)
      raise AttributorException, "Attribute names must be symbols, got: #{name.inspect}" unless name.kind_of? ::Symbol

      attribute = self.schema.attributes.fetch(name) do
        raise "Attribute '#{name}' does not exist in #{self.schema}"
      end

      if block_given?
        view = View.new(name, attribute, &block)
        @contents[name] = view
      else
        raise "Invalid options (#{opts.inspect}) for #{name} while defining view #{@name}" unless opts.is_a?(Hash)
        @contents[name] = [attribute, opts]
      end

    end


    def example(context=nil)
      object = self.schema.example(context)
      opts = {}
      opts[:context] = context if context
      self.dump(object, opts)
    end

    def describe
      # TODO: for now we are just return the first level keys
      view_attributes = {}

      self.contents.each do |k,(dumpable,dumpable_opts)|
        inner_desc = {}
        inner_desc[:view] = dumpable_opts[:view] if dumpable_opts && dumpable_opts[:view]
        view_attributes[k] = inner_desc
      end

      { attributes: view_attributes, type: :standard }
    end

  end
end
