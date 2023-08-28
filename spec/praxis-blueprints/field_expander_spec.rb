# frozen_string_literal: true

require 'spec_helper'

describe Praxis::FieldExpander do
  let(:field_expander) { Praxis::FieldExpander.new }

  let(:view) do
    Praxis::View.new(:testing, Person) do
      attribute :name
      attribute :full_name
      attribute :parents do
        attribute :father
        attribute :mother
      end
      attribute :address, view: :extended
      attribute :prior_addresses, view: :state
      attribute :tags
    end
  end

  let(:full_expected) do
    {
      name: true,
      full_name: { first: true, last: true },
      parents: { mother: true, father: true },
      address: {
        state: true,
        street: true,
        resident: {
          name: true,
          full_name: { first: true, last: true },
          address: { street: true, state: true },
          prior_addresses: [{ street: true, state: true }]
        }
      },
      prior_addresses: [{ state: true }],
      tags: [true]
    }
  end

  context 'expanding a view' do
    it 'expands all fields on the view, subviews, and related attributes' do
      field_expander.expand(view, true).should eq(full_expected)
    end

    it 'expands for a subset of the direct fields' do
      field_expander.expand(view, name: true).should eq(name: true)
    end

    it 'expands for a subview' do
      field_expander.expand(view, parents: true).should eq(parents: { mother: true, father: true })
    end

    it 'expands for a related attribute' do
      field_expander.expand(view, address: true).should eq(address: full_expected[:address])
    end

    it 'expands for a subset of a related attribute' do
      field_expander.expand(view, address: { resident: true }).should eq(address: { resident: full_expected[:address][:resident] })
    end

    it 'expands for a subset of a subview' do
      field_expander.expand(view, parents: { mother: true }).should eq(parents: { mother: true })
    end

    it 'ignores fields not defined in the view' do
      field_expander.expand(view, name: true, age: true).should eq(name: true)
    end

    it 'expands a specific subattribute of a struct' do
      field_expander.expand(view, full_name: { first: true }).should eq(full_name: { first: true })
    end

    it 'wraps expanded collections in arrays' do
      field_expander.expand(view, prior_addresses: { state: true }).should eq(prior_addresses: [{ state: true }])
    end

    it 'wraps expanded collections in arrays' do
      field_expander.expand(view, prior_addresses: true).should eq(prior_addresses: [{ state: true }])
    end
  end

  it 'expands for an Attributor::Model' do
    field_expander.expand(FullName).should eq(first: true, last: true)
  end

  it 'expands for a Blueprint' do
    field_expander.expand(Person, parents: true).should eq(parents: { father: true, mother: true })
  end

  it 'expands for an Attributor::Collection of an Attrbutor::Model' do
    expected = [{ first: true, last: true }]
    field_expander.expand(Attributor::Collection.of(FullName)).should eq expected
  end

  it 'expands for an Attributor::Collection of a Blueprint' do
    expected = [{ name: true, resident: { full_name: { first: true, last: true } } }]

    field_expander.expand(Attributor::Collection.of(Address), name: true, resident: { full_name: true }).should eq expected
  end

  it 'also expands array-wrapped field hashes for collections' do
    expected = [{ name: true, resident: { full_name: { first: true, last: true } } }]
    field_expander.expand(Attributor::Collection.of(Address), [name: true, resident: { full_name: true }]).should eq expected
  end

  it 'expands for an Attributor::Collection of a primitive type' do
    field_expander.expand(Attributor::Collection.of(String)).should eq([true])
  end

  it 'expands for for a primitive type' do
    field_expander.expand(String).should eq(true)
  end

  context 'expanding a two-dimensional collection' do
    let(:matrix_type) do
      Attributor::Collection.of(Attributor::Collection.of(FullName))
    end

    it 'expands the fields with proper nesting' do
      field_expander.expand(matrix_type).should eq([[first: true, last: true]])
    end
  end

  context 'circular expansions' do
    it 'preserve field object identity for circular references' do
      result = field_expander.expand(Address, true)
      result.should be result[:resident][:address]
    end

    context 'with collections of Blueprints' do
      it 'still preserves object identity' do
        result = field_expander.expand(Person, prior_addresses: true)[:prior_addresses][0]
        result.should be result[:resident][:prior_addresses][0]
      end
    end

    context 'for views' do
      it 'still preserves object identity' do
        result = field_expander.expand(Person.views[:circular], true)
        result[:address][:resident].should be result
      end
    end
  end

  it 'optimizes duplicate field expansions' do
    expect(field_expander.expand(FullName, true)).to be(field_expander.expand(FullName, true))
  end

  context 'expanding hash attributes' do
    let(:type) do
      Class.new(Attributor::Model) do
        attributes do
          attribute :name, String
          attribute :simple_hash, Hash
          attribute :keyed_hash, Hash do
            key :foo, String
            key :bar, String
          end
          attribute :some_struct do
            attribute :something, String
          end
        end
      end
    end

    it 'expands' do
      expected = {
        name: true,
        simple_hash: true,
        keyed_hash: { foo: true, bar: true },
        some_struct: { something: true }
      }
      field_expander.expand(type, true).should eq(expected)
    end
  end
end
