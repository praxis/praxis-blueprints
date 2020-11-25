# frozen_string_literal: true
require_relative '../spec_helper'

describe Praxis::Renderer do
  let(:address) { Address.example }
  let(:prior_addresses) { Array.new(2) { Address.example } }
  let(:alias_one) { FullName.example }
  let(:alias_two) { FullName.example }
  let(:aliases) { [alias_one, alias_two] }
  let(:metadata_hash) { { something: 'here' } }
  let(:metadata) { Attributor::Hash.load(metadata_hash) }

  let(:person) do
    Person.example(
      address: address,
      email: nil,
      prior_addresses: prior_addresses,
      alive: false,
      work_address: nil,
      aliases: aliases,
      metadata: metadata
    )
  end

  let(:fields) do
    {
      name: true,
      email: true,
      full_name: { first: true, last: true },
      address: {
        state: true,
        street: true,
        resident:  { name: true }
      },
      prior_addresses: { name: true },
      work_address: true,
      alive: true,
      metadata: true,
      aliases: true
    }
  end

  let(:renderer) { Praxis::Renderer.new }

  subject(:output) { renderer.render(person, fields) }

  it 'renders existing attributes' do
    output.keys.should match_array([:name, :full_name, :alive, :address, :prior_addresses, :metadata, :aliases])

    output[:name].should eq person.name
    output[:full_name].should eq(first: person.full_name.first, last: person.full_name.last)
    output[:alive].should be false

    output[:address].should eq(state: person.address.state,
                               street: person.address.street,
                               resident: { name: person.address.resident.name })

    expected_prior_addresses = prior_addresses.collect { |addr| { name: addr.name } }
    output[:prior_addresses].should match_array(expected_prior_addresses)

    expected_aliases = aliases.collect(&:dump)
    output[:aliases].should match_array(expected_aliases)

    output[:metadata].should eq(metadata.dump)
  end

  context 'calls dump for non-Blueprint, but still Dumpable instances' do
    it 'when rendering them in full as array members' do
      alias_one.should_receive(:dump).and_call_original
      output[:aliases].first.should eq(first: alias_one.first, last: alias_one.last)
    end
    it 'when rendering them in full as leaf object' do
      metadata.should_receive(:dump).and_call_original
      output[:metadata].should eq(metadata_hash)
    end
  end

  it 'does not render attributes with nil values' do
    output.should_not have_key(:email)
  end

  context 'with include_nil: true' do
    let(:renderer) { Praxis::Renderer.new(include_nil: true) }
    let(:address) { nil }

    it 'renders attributes with nil values' do
      output.should have_key :email
      output[:email].should be nil

      output.should have_key :work_address
      output[:work_address].should be nil
    end

    it 'renders nil directly for nil subobjects' do
      output.should have_key :address
      output[:address].should be nil
    end
  end

  context 'rendering a two-dimmensional collection' do
    let(:names) { Array.new(9) { |i| Address.example(i.to_s, name: i.to_s) } }
    let(:matrix_type) do
      Attributor::Collection.of(Attributor::Collection.of(Address))
    end

    let(:matrix) { matrix_type.load(names.each_slice(3).collect { |slice| slice }) }

    let(:fields) { { name: true } }

    it 'renders with render_collection and per-element field spec' do
      rendered = renderer.render(matrix, fields)
      rendered.flatten.collect { |r| r[:name] }.should eq((0..8).collect(&:to_s))
    end

    it 'renders with render and proper field spec' do
      rendered = renderer.render(matrix, fields)
      rendered.flatten.collect { |r| r[:name] }.should eq((0..8).collect(&:to_s))
    end
  end

  context 'rendering stuff that breaks badly' do
    it 'does not break badly' do
      renderer.render(person, {tags: true})
    end
  end

  context 'caching rendered objects' do
    let(:fields) { {full_name: true} }
    it 'caches and returns identical results for the same field objects' do
      expect(person).to receive(:full_name).once.and_call_original

      render_1 = renderer.render(person, fields)
      render_2 = renderer.render(person, fields)
      expect(render_1).to be(render_2)
    end
  end

  context 'rendering hashes' do
    let(:fields) do
      {
        id: true,
        hash: true
      }
    end

    let(:data) { { id: 10, hash: { foo: 'bar' } } }
    let(:object) { SimpleHash.load(data) }
    let(:renderer) { Praxis::Renderer.new }

    subject(:output) { renderer.render(object, fields) }

    its([:id]) { should eq data[:id] }
    its([:hash]) { should eq data[:hash] }
    its([:hash]) { should be_kind_of(Hash) }
  end

  context 'rendering collections of hashes' do
    let(:fields) do
      {
        id: true,
        hash_collection: true
      }
    end

    let(:data) { { id: 10, hash_collection: [{ foo: 'bar' }] } }
    let(:object) { SimpleHashCollection.load(data) }
    let(:renderer) { Praxis::Renderer.new }

    subject(:output) { renderer.render(object, fields) }

    its([:id]) { should eq data[:id] }
    its([:hash_collection]) { should eq data[:hash_collection] }
    its([:hash_collection]) { should be_kind_of(Array) }

    it 'renders the hashes' do
      expect(output[:hash_collection].first).to be_kind_of(Hash)
    end
  end

  context 'rendering a Blueprint with fields true' do
    let(:fields) do
      {
        name: true,
        address: true
      }
    end

    its([:address]) { should eq person.address.dump }
  end
end
