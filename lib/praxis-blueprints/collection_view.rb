module Praxis

  class CollectionView
    attr_reader :name, :schema, :using

    def initialize(name, schema, using)
      @name = name
      @schema = schema
      @using = using
    end

    def dump(collection, context: Attributor::DEFAULT_ROOT_CONTEXT,**opts)
      collection.collect.with_index do |object, i|
        subcontext = context + ["at(#{i})"]
        using.dump(object, context: subcontext, **opts)
      end
    end

    def example(context=Attributor::DEFAULT_ROOT_CONTEXT)
      collection = self.schema.example(context)
      opts = {}
      opts[:context] = context if context
      self.dump(collection, opts)
    end

    def describe
      using.describe.merge(type: :collection)
    end

  end
end
