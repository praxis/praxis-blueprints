# # frozen_string_literal: true
# module Praxis
#   class FieldExpander
#     def self.expand(object, fields = true)
#       new.expand(object, fields)
#     end

#     attr_reader :stack
#     attr_reader :history

#     def initialize
#       @stack = Hash.new do |hash, key|
#         hash[key] = Set.new
#       end
#       @history = Hash.new do |hash, key|
#         hash[key] = {}
#       end
#     end

#     def expand(object, fields = true)
#       if stack[object].include? fields
#         return history[object][fields] if history[object].include? fields
#         # We should probably never get here, since we should have a record
#         # of the history of an expansion if we're trying to redo it,
#         # but we should also be conservative and raise here just in case.
#         raise "Circular expansion detected for object #{object.inspect} with fields #{fields.inspect}"
#       else
#         stack[object] << fields
#       end

#       result = if object.is_a?(Praxis::View)
#                  expand_view(object, fields)
#                elsif object.is_a? Attributor::Attribute
#                  expand_type(object.type, fields)
#                else
#                  expand_type(object, fields)
#                end

#       result
#     ensure
#       stack[object].delete fields
#     end

#     def expand_fields(attributes, fields)
#       raise ArgumentError, 'expand_fields must be given a block' unless block_given?

#       unless fields == true
#         attributes = attributes.select do |k, _v|
#           fields.key?(k)
#         end
#       end

#       attributes.each_with_object({}) do |(name, dumpable), hash|
#         sub_fields = case fields
#                      when true
#                        true
#                      when Hash
#                        fields[name] || true
#                      end
#         hash[name] = yield(dumpable, sub_fields)
#       end
#     end

#     def expand_view(object, fields = true)
#       history[object][fields] = if object.is_a?(Praxis::CollectionView)
#                                   []
#                                 else
#                                   {}
#                                 end

#       result = expand_fields(object.contents, fields) do |dumpable, sub_fields|
#         expand(dumpable, sub_fields)
#       end

#       if object.is_a?(Praxis::CollectionView)
#         history[object][fields] << result
#       else
#         history[object][fields].merge!(result)
#       end
#       history[object][fields]
#     end

#     def expand_type(object, fields = true)
#       unless object.respond_to?(:attributes)
#         if object.respond_to?(:member_attribute)
#           return expand_with_member_attribute(object, fields)
#         else
#           return true
#         end
#       end

#       # just include the full thing if it has no attributes
#       return true if object.attributes.empty?

#       return history[object][fields] if history[object].include? fields

#       history[object][fields] = {}
#       result = expand_fields(object.attributes, fields) do |dumpable, sub_fields|
#         expand(dumpable.type, sub_fields)
#       end
#       history[object][fields].merge!(result)
#     end

#     def expand_with_member_attribute(object, fields = true)
#       return history[object][fields] if history[object].include? fields
#       history[object][fields] = []

#       new_fields = fields.is_a?(Array) ? fields[0] : fields

#       result = [expand(object.member_attribute.type, new_fields)]
#       history[object][fields].concat(result)

#       result
#     end
#   end
# end
