# frozen_string_literal: true
module Praxis
  class ConfigHash < BasicObject
    attr_reader :hash

    def self.from(hash = {}, &block)
      new(hash, &block)
    end

    def initialize(hash = {}, &block)
      @hash = hash
      @block = block
    end

    def to_hash
      instance_eval(&@block)
      @hash
    end

    def method_missing(name, value, *rest, &block)
      if (existing = @hash[name])
        if block
          existing << [value, block]
        else
          existing << value
          rest.each do |v|
            existing << v
          end
        end
      else
        @hash[name] = if rest.any?
                        [value] + rest
                      else
                        value
                      end
      end
    end
  end
end
