# frozen_string_literal: true
class Person < Praxis::Blueprint
  attributes do
    attribute :name, String, example: /[:first_name:]/
    attribute :email, String, example: proc { |person| "#{person.name}@example.com" }

    attribute :age, Integer

    attribute :full_name, FullName
    attribute :aliases, Attributor::Collection.of(FullName)

    attribute :address, Address, example: proc { |person, context| Address.example(context, resident: person) }
    attribute :work_address, Address

    attribute :prior_addresses, Attributor::Collection.of(Address)
    attribute :parents do
      attribute :father, String
      attribute :mother, String
    end

    attribute :tags, Attributor::Collection.of(String)
    attribute :href, String
    attribute :alive, Attributor::Boolean, default: true
    attribute :myself, Person
    attribute :friends, Attributor::Collection.of(Person)
    attribute :metadata, Attributor::Hash
  end

  default_fieldset do
    attribute :name
    attribute :full_name
    attribute :address do
      attribute :name
      attribute :street
    end
    attribute :prior_addresses do
      attribute :name
    end
  end
end

class Address < Praxis::Blueprint
  attributes do
    attribute :id, Integer
    attribute :name, String
    attribute :street, String
    attribute :state, String, values: %w(OR CA)

    attribute :resident, Person, example: proc { |address, context| Person.example(context, address: address) }
  end
end

class FullName < Attributor::Model
  attributes do
    attribute :first, String, example: /[:first_name:]/
    attribute :last, String, example: /[:last_name:]/
  end
end

class SimpleHash < Attributor::Model
  attributes do
    attribute :id, Integer
    attribute :hash, Hash
  end
end

class SimpleHashCollection < Attributor::Model
  attributes do
    attribute :id, Integer
    attribute :hash_collection, Attributor::Collection.of(Hash)
  end
end
