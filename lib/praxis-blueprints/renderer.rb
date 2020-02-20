# frozen_string_literal: true
module Praxis
  class Renderer
    attr_reader :include_nil
    attr_reader :cache

    class CircularRenderingError < StandardError
      attr_reader :object
      attr_reader :context

      def initialize(object, context)
        @object = object
        @context = context

        first = Attributor.humanize_context(context[0..10])
        last = Attributor.humanize_context(context[-5..-1])
        pretty_context = "#{first}...#{last}"
        super("SystemStackError in rendering #{object.class} with context: #{pretty_context}")
      end
    end

    def initialize(include_nil: false)
      @cache = Hash.new do |hash, key|
        hash[key] = {}
      end

      @include_nil = include_nil
    end

    # Renders an a collection using a given list of per-member fields.
    #
    # @param [Object] object the object to render
    # @param [Hash] fields the set of fields, as from FieldExpander, to apply to each member of the collection.
    def render_collection(collection, member_fields, view = nil, context: Attributor::DEFAULT_ROOT_CONTEXT)
      render(collection, [member_fields], view, context: context)
    end

    # Renders an object using a given list of fields.
    #
    # @param [Object] object the object to render
    # @param [Hash] fields the correct set of fields, as from FieldExpander
    def render(object, fields, view = nil, context: Attributor::DEFAULT_ROOT_CONTEXT)
      if fields.is_a? Array
        sub_fields = fields[0]
        object.each_with_index.collect do |sub_object, i|
          sub_context = context + ["at(#{i})"]
          render(sub_object, sub_fields, view, context: sub_context)
        end
      elsif object.is_a? Praxis::Blueprint
        @cache[object._cache_key][fields] ||= _render(object, fields, view, context: context)
      else
        _render(object, fields, view, context: context)
      end
    rescue SystemStackError
      raise CircularRenderingError.new(object, context)
    end

    def _render(object, fields, view = nil, context: Attributor::DEFAULT_ROOT_CONTEXT)
      if fields == true
        return case object
               when Attributor::Dumpable
                 object.dump
               else
                 object
               end
      end

      notification_payload = {
        blueprint: object,
        fields: fields,
        view: view
      }

      ActiveSupport::Notifications.instrument 'praxis.blueprint.render', notification_payload do
        fields.each_with_object({}) do |(key, subfields), hash|
          begin
            value = object._get_attr(key)
          rescue => e
            raise Attributor::DumpError, context: context, name: key, type: object.class, original_exception: e
          end

          if value.nil?
            hash[key] = nil if self.include_nil
            next
          end

          if subfields == true
            hash[key] = case value
                        when Attributor::Dumpable
                          value.dump
                        else
                          value
                        end
          else
            new_context = context + [key]
            hash[key] = render(value, subfields, context: new_context)
          end
        end
      end
    end
  end
end
