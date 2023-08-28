# frozen_string_literal: true

class Person < Praxis::Blueprint
  attributes do
    attribute :name, String, example: proc { Faker::Name.first_name }
    attribute :email, String, example: proc { |person| "#{person.name}@example.com" }, null: true

    attribute :age, Integer, null: true

    attribute :full_name, FullName, null: true
    attribute :aliases, Attributor::Collection.of(FullName), null: true

    attribute :address, Address, example: proc { |person, context| Address.example(context, resident: person) }, null: true
    attribute :work_address, Address, null: true

    attribute :prior_addresses, Attributor::Collection.of(Address), null: true
    attribute :parents, null: true do
      attribute :father, String
      attribute :mother, String
    end

    attribute :tags, Attributor::Collection.of(String), null: true
    attribute :href, String, null: true
    attribute :alive, Attributor::Boolean, default: true, null: true
    attribute :myself, Person, null: true
    attribute :friends, Attributor::Collection.of(Person), null: true
    attribute :metadata, Attributor::Hash, null: true
  end

  view :default do
    attribute :name
    attribute :full_name
    attribute :address
    attribute :prior_addresses
  end

  view :circular do
    attribute :address, view: :circular
  end

  view :self_referencing do
    attribute :myself, view: :self_referencing
    attribute :friends, view: :self_referencing
  end

  view :current do
    attribute :name
    attribute :full_name
    attribute :address
  end

  view :name_only do
    attribute :name
  end

  view :extended do
    attribute :name
    attribute :full_name
    attribute :age
    attribute :address
    attribute :alive
  end
end

class Address < Praxis::Blueprint
  attributes do
    attribute :id, Integer, null: true
    attribute :name, String, null: true
    attribute :street, String, null: true
    attribute :state, String, values: %w[OR CA], null: true

    attribute :resident, Person, example: proc { |address, context| Person.example(context, address: address) }, null: true
  end

  view :default do
    attribute :street
    attribute :state
  end

  view :circular do
    attribute :resident, view: :circular
  end
  view :state do
    attribute :state
  end

  view :extended do
    attribute :state
    attribute :street
    attribute :resident
  end
end

class FullName < Attributor::Model
  attributes do
    attribute :first, String, example: proc { Faker::Name.first_name }
    attribute :last, String, example: proc { Faker::Name.last_name }
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
