
class Person < Praxis::Blueprint
  attributes do
    attribute :name, String, example: /[:first_name:]/
    attribute :email, String, example: proc { |person| "#{person.name}@example.com" }
    
    attribute :full_name, FullName
    attribute :aliases, Attributor::Collection.of(FullName)

    attribute :address, Address, example: proc { |person, context| Address.example(context, resident: person) }

    attribute :prior_addresses, Attributor::Collection.of(Address)

    attribute :parents do
      attribute :father, String
      attribute :mother, String
    end

    attribute :href, String
    attribute :alive, Attributor::Boolean, default: true
  end

  view :default do
    attribute :name
    attribute :full_name
    attribute :address
  end

  view :current do
    attribute :name
    attribute :full_name
    attribute :address
  end


  view :extended do
    attribute :name
    attribute :full_name
    attribute :address
    attribute :alive
  end

end


class Address  < Praxis::Blueprint
  attributes do
    attribute :id, Integer
    attribute :name, String
    attribute :street, String
    attribute :state, String, values: %w{OR CA}

    attribute :resident, Person, example: proc { |address,context| Person.example(context, address: address) }
  end

  view :default do
    attribute :street
    attribute :state
  end

  view :state do
    attribute :state
  end


end


class FullName < Attributor::Model
  
  attributes do
    attribute :first, String, example: /[:first_name:]/
    attribute :last, String, example: /[:last_name:]/
  end

end
