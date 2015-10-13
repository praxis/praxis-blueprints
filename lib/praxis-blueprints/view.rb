module Praxis

  class View
    attr_reader :schema
    attr_reader :contents
    attr_reader :name
    attr_reader :options

    def initialize(name, schema, **options, &block)
      @name = name
      @schema = schema
      @contents = ::Hash.new
      @block = block

      @options = options
    end

    def contents
      if @block
        self.instance_eval(&@block)
        @block = nil
      end

      @contents
    end

    def expanded_fields
      @expanded_fields ||= begin
        self.contents # force evaluation of the contents
        FieldExpander.expand(self)
      end
    end

    def render(object, context: Attributor::DEFAULT_ROOT_CONTEXT, renderer: Renderer.new)
      renderer.render(object, self.expanded_fields, context: context)
    end

    alias_method :to_hash, :render # Why did we need this again?

    # def dump(object, context: Attributor::DEFAULT_ROOT_CONTEXT,**opts)
    #   fields = opts[:fields]
    #   # Restrict which attributes to output if we receive a fields parameter
    #   # Note: should we complain if any of the names in "fields" do not match an existing attribute name?
    #   attributes_to_render = self.contents.keys
    #   attributes_to_render &= fields.keys if fields
    #
    #   attributes_to_render.each_with_object({}) do |name, hash|
    #     dumpable, dumpable_opts = self.contents[name]
    #     unless object.respond_to?(name)
    #       warn "#{object} does not respond to #{name} during rendering???"
    #       next
    #     end
    #
    #     begin
    #       value = object.send(name)
    #     rescue => e
    #       raise Attributor::DumpError, context: context, name: name, type: object.class, original_exception: e
    #     end
    #
    #     if value.nil?
    #       next unless @include_nil
    #     end
    #
    #     # FIXME: this is such an ugly way to do this. Need attributor#67.
    #     if dumpable.kind_of?(View) || dumpable.kind_of?(CollectionView)
    #       new_context = context + [name]
    #
    #       sub_opts = add_subfield_options(fields, name, dumpable_opts)
    #       hash[name] = dumpable.dump(value, context: new_context, **sub_opts)
    #     else
    #       type = dumpable.type
    #       if type.respond_to?(:attributes) || type.respond_to?(:member_attribute)
    #         new_context = context + [name]
    #         sub_opts = add_subfield_options(fields, name, dumpable_opts)
    #         hash[name] = dumpable.dump(value, context: new_context ,**sub_opts)
    #       else
    #         hash[name] = value
    #       end
    #     end
    #   end
    # end


    def attribute(name, **opts, &block)
      raise AttributorException, "Attribute names must be symbols, got: #{name.inspect}" unless name.kind_of? ::Symbol

      attribute = self.schema.attributes.fetch(name) do
        raise "Displaying :#{name} is not allowed in view :#{self.name} of #{self.schema}. This attribute does not exist in the mediatype"
      end

      if block_given?
        type = attribute.type
        @contents[name] = if type < Attributor::Collection
          CollectionView.new(name, type.member_attribute.type, &block)
        else
          View.new(name, attribute, &block)
        end
      else
        type = attribute.type
        if type < Attributor::Collection
          is_collection = true
          type = type.member_attribute.type
        end


        if type < Praxis::Blueprint
          view_name = opts[:view] || :default
          view = type.views.fetch(view_name) do
            raise "view with name '#{view_name.inspect}' is not defined in #{type}"
          end
          if is_collection
            @contents[name] = Praxis::CollectionView.new(view_name, type, view)
          else
            @contents[name] = view
          end
        else
          @contents[name] = attribute #, opts]
        end
      end

    end

    def example(context=Attributor::DEFAULT_ROOT_CONTEXT)
      object = self.schema.example(context)
      opts = {}
      opts[:context] = context if context
      self.render(object, opts)
    end

    def describe
      # TODO: for now we are just return the first level keys
      view_attributes = {}

      self.contents.each do |k,dumpable|
        inner_desc = {}
        #inner_desc[:view] = dumpable_opts[:view] if dumpable_opts && dumpable_opts[:view]
        if dumpable.kind_of?(Praxis::View)
          inner_desc[:view] = dumpable.name if dumpable.name
        end
        view_attributes[k] = inner_desc
      end

      { attributes: view_attributes, type: :standard }
    end


  end
end
