require_relative '../spec_helper'

describe Praxis::Renderer do

  let(:address) { Address.example }
  let(:prior_addresses) { 2.times.collect { Address.example } }
  let(:person) do
     Person.example(
      address: address,
      email: nil,
      prior_addresses: prior_addresses,
      alive: false,
      work_address: nil
    )
  end


  let(:fields) do
    {
      name:true,
      email:true,
      full_name: {first:true, last:true},
      address: {
        state:true,
        street:true,
        resident:  {name:true}
      },
      prior_addresses: [{name: true}],
      work_address: true,
      alive: true
    }
  end

  let(:renderer) { Praxis::Renderer.new }

  subject(:output) { renderer.render(person, fields) }

  it 'renders existing attributes' do
    output.keys.should match_array([:name, :full_name, :alive, :address, :prior_addresses])

    output[:name].should eq person.name
    output[:full_name].should eq({first: person.full_name.first, last: person.full_name.last})
    output[:alive].should be false

    output[:address].should eq({
      state: person.address.state,
      street: person.address.street,
      resident: {name: person.address.resident.name}
    })

    expected_prior_addresses = prior_addresses.collect { |addr| {name: addr.name} }
    output[:prior_addresses].should match_array(expected_prior_addresses)
  end

  it 'does not render attributes with nil values' do
    output.should_not have_key(:email)
  end


  it 'sends the correct ActiveSupport::Notification' do
    fields = {
      name:true,
      email:true
    }

    notification_payload = {
      blueprint: person,
      view: nil,
      fields: fields
    }

    ActiveSupport::Notifications.should_receive(:instrument).
      with('praxis.blueprint.render',notification_payload).
      and_call_original

    renderer.render(person, fields)
   end


  context 'with include_nil: true' do
    let(:renderer) { Praxis::Renderer.new(include_nil: true) }

    it 'renders attributes with nil values' do
      output.should have_key :email
      output[:email].should be nil

      output.should have_key :work_address
      output[:work_address].should be nil
    end
  end

  context '#render_collection' do
    let(:people) { 10.times.collect { Person.example(address: address, email: nil) } }
    subject(:output) { renderer.render_collection(people, fields) }

    it { should have(10).items }

    it 'renders the collection' do
      output.first.should eq(renderer.render(people.first,fields))
    end

  end

  context 'rendering a two-dimmensional collection' do
    let(:names) { 9.times.collect { |i| Address.example(i.to_s, name: i.to_s) } }
    let(:matrix_type) do
      Attributor::Collection.of(Attributor::Collection.of(Address))
    end

    let(:matrix) { matrix_type.load(names.each_slice(3).collect { |slice| slice })  }

    let(:fields) { [[{name: true}]] }

    it 'renders with render_collection and per-element field spec' do
      rendered = renderer.render_collection(matrix,fields.first)
      rendered.flatten.collect {|r| r[:name] }.should eq((0..8).collect(&:to_s))
    end

    it 'renders with render and proper field spec' do
      rendered =  renderer.render(matrix,fields)
      rendered.flatten.collect {|r| r[:name] }.should eq((0..8).collect(&:to_s))
    end
  end

  context 'rendering stuff that breaks badly' do
    it 'does not break badly' do
      renderer.render(person, tags: [true])
    end
  end

  context 'caching rendered objects' do
    let(:fields) { Praxis::FieldExpander.expand(Person, full_name: true) }
    it 'caches and returns identical results for the same field objects' do
      expect(person).to receive(:full_name).once.and_call_original

      render_1 = renderer.render(person, fields)
      render_2 = renderer.render(person, fields)
      expect(render_1).to be(render_2)
    end

  end

  context 'circular rendering' do
    it do
      field_expander = Praxis::FieldExpander.new
      fields = field_expander.expand(Person,true)

      person.object.address.object.resident = person
      expect { renderer.render(person, fields) }.to raise_error(Praxis::Renderer::CircularRenderingError)
    end

  end

  context 'rendering hashes' do
    let(:fields) do
      {
        id: true,
        hash: true
      }
    end

    let(:data) { {id: 10, hash: {foo: 'bar'}} }
    let(:object) { SimpleHash.load(data)}
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
        hash_collection: [true]
      }
    end

    let(:data) { {id: 10, hash_collection: [{foo: 'bar'}]} }
    let(:object) { SimpleHashCollection.load(data)}
    let(:renderer) { Praxis::Renderer.new }

    subject(:output) { renderer.render(object, fields) }

    its([:id]) { should eq data[:id] }
    its([:hash_collection]) { should eq data[:hash_collection] }
    its([:hash_collection]) { should be_kind_of(Array) }

    it 'renders the hashes' do
      expect(output[:hash_collection].first).to be_kind_of(Hash)
    end
  end

end
