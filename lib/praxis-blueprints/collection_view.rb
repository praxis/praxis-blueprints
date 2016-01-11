module Praxis

  class CollectionView < View
    def initialize(name, schema, member_view=nil)
      super(name,schema)

      if member_view
        @_lazy_view = member_view
      end
    end

    def contents
      if @_lazy_view
        @contents = @_lazy_view.contents.clone
        @_lazy_view = nil
      end
      super
    end

    def example(context=Attributor::DEFAULT_ROOT_CONTEXT)
      collection = 3.times.collect do |i|
        subcontext = context + ["at(#{i})"]
        self.schema.example(subcontext)
      end
      opts = {}
      opts[:context] = context if context

      self.render(collection, **opts)
    end

    def describe
      super.merge(type: :collection)
    end

  end
end
