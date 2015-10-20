module Praxis
  class FieldExpander
    def self.expand(object, fields=true)
      self.new.expand(object,fields)
    end

    attr_reader :stack
    attr_reader :history

    def initialize
      @stack = Hash.new do |hash, key|
        hash[key] = Set.new
      end
      @history = Hash.new do |hash,key|
        hash[key] = Hash.new
      end
    end

    def expand(object, fields=true)
      if stack[object].include? fields
        if history[object].include? fields
          return history[object][fields]
        end
        # We should probably never get here, since we should have a record
        # of the history of an expansion if we're trying to redo it,
        # but we should also be conservative and raise here just in case.
        raise "Circular expansion detected for object #{object.inspect} with fields #{fields.inspect}"
      else
        stack[object] << fields
      end

      if object.kind_of?(Praxis::View)
        self.expand_view(object, fields)
      elsif object.kind_of? Attributor::Attribute
        self.expand_type(object.type, fields)
      else
        self.expand_type(object,fields)
      end
    rescue CircularExpansionError => e
      e.stack.unshift [object,fields]
      raise
    ensure
      stack[object].delete fields
    end

    def expand_fields(attributes, fields)
      raise ArgumentError, "expand_fields must be given a block" unless block_given?

      unless fields == true
        attributes = attributes.select do |k,v|
          fields.key?(k)
        end
      end

      attributes.each_with_object({}) do |(name, dumpable), hash|
        sub_fields = case fields
          when true
            true
          when Hash
            fields[name] || true
          end
        hash[name] = yield(dumpable,sub_fields)
      end
    end


    def expand_view(object,fields=true)
      result = expand_fields(object.contents, fields) do |dumpable, sub_fields|
        self.expand(dumpable, sub_fields)
      end

      return [result] if object.kind_of?(Praxis::CollectionView)
      result
    end


    def expand_type(object,fields=true)
      unless object.respond_to?(:attributes)
        if object.respond_to?(:member_attribute)
          fields = fields[0] if fields.kind_of? Array
          return [self.expand(object.member_attribute.type, fields)]
        else
          return true
        end
      end

      # just include the full thing if it has no attributes
      if object.attributes.empty?
        return true
      end

      if history[object].include? fields
        return history[object][fields]
      end

      history[object][fields] = {}
      result = expand_fields(object.attributes, fields) do |dumpable, sub_fields|
        self.expand(dumpable.type, sub_fields)
      end
      history[object][fields].merge!(result)
    end

  end
end
