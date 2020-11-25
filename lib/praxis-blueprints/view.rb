# # frozen_string_literal: true
# module Praxis
#   class View
#     attr_reader :schema
#     attr_reader :contents
#     attr_reader :name
#     attr_reader :options

#     def initialize(name, schema, **options, &block)
#       @name = name
#       @schema = schema
#       @contents = ::Hash.new
#       @block = block

#       @options = options
#     end

#     def contents
#       if @block
#         instance_eval(&@block)
#         @block = nil
#       end

#       @contents
#     end

#     def expanded_fields
#       @expanded_fields ||= begin
#         contents # force evaluation of the contents
#         FieldExpander.expand(self)
#       end
#     end

#     def render(object, context: Attributor::DEFAULT_ROOT_CONTEXT, renderer: Renderer.new)
#       renderer.render(object, expanded_fields, context: context)
#     end

#     def attribute(name, **opts, &block)
#       raise AttributorException, "Attribute names must be symbols, got: #{name.inspect}" unless name.is_a? ::Symbol

#       attribute = schema.attributes.fetch(name) do
#         raise "Displaying :#{name} is not allowed in view :#{self.name} of #{schema}. This attribute does not exist in the mediatype"
#       end

#       if block_given?
#         type = attribute.type
#         @contents[name] = if type < Attributor::Collection
#                             CollectionView.new(name, type.member_attribute.type, &block)
#                           else
#                             View.new(name, attribute, &block)
#                           end
#       else
#         type = attribute.type
#         if type < Attributor::Collection
#           is_collection = true
#           type = type.member_attribute.type
#         end

#         if type < Praxis::Blueprint
#           view_name = opts[:view] || :default
#           view = type.views.fetch(view_name) do
#             raise "view with name '#{view_name.inspect}' is not defined in #{type}"
#           end
#           @contents[name] = if is_collection
#                               Praxis::CollectionView.new(view_name, type, view)
#                             else
#                               view
#                             end
#         else
#           @contents[name] = attribute # , opts]
#         end
#       end
#     end

#     def example(context = Attributor::DEFAULT_ROOT_CONTEXT)
#       object = schema.example(context)
#       opts = {}
#       opts[:context] = context if context
#       render(object, **opts)
#     end

#     def describe
#       # TODO: for now we are just return the first level keys
#       view_attributes = {}

#       contents.each do |k, dumpable|
#         inner_desc = {}
#         if dumpable.is_a?(Praxis::View)
#           inner_desc[:view] = dumpable.name if dumpable.name
#         end
#         view_attributes[k] = inner_desc
#       end

#       { attributes: view_attributes, type: :standard }
#     end
#   end
# end
