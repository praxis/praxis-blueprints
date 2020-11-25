# # frozen_string_literal: true
# module Praxis
#   class CollectionView < View
#     def initialize(name, schema, member_view = nil)
#       super(name, schema)

#       @_lazy_view = member_view if member_view
#     end

#     def contents
#       if @_lazy_view
#         @contents = @_lazy_view.contents.clone
#         @_lazy_view = nil
#       end
#       super
#     end

#     def example(context = Attributor::DEFAULT_ROOT_CONTEXT)
#       collection = Array.new(3) do |i|
#         subcontext = context + ["at(#{i})"]
#         schema.example(subcontext)
#       end
#       opts = {}
#       opts[:context] = context if context

#       render(collection, **opts)
#     end

#     def describe
#       super.merge(type: :collection)
#     end
#   end
# end
