# frozen_string_literal: true
require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Praxis::Blueprint do
  subject(:blueprint_class) { Person }

  its(:family) { should eq('hash') }

  context 'deterministic examples' do
    it 'works' do
      person_1 = Person.example('person 1')
      person_2 = Person.example('person 1')

      person_1.name.should eq(person_2.name)
      person_1.address.name.should eq(person_2.address.name)
    end
  end

  context 'implicit default_fieldset' do
    subject(:default_fieldset) { Person.default_fieldset }

    it { should_not be(nil) }
    it 'contains all attributes' do
      default_fieldset.keys.should include(
        :name, :email, :age, :full_name, :aliases, :parents, :tags, :href, :alive, :metadata
      )
      # Should not have blueprint-derived attributes (or collections of them)
      default_fieldset.keys.should_not include(
        :address, :work_address, :prior_addresses, :myself, :friends
      )
    end
  end

  context 'creating a new Blueprint class' do
    subject!(:blueprint_class) do
      Class.new(Praxis::Blueprint) do
        domain_model Hash
        attributes do
          attribute :id, Integer
        end
      end
    end

    its(:finalized?) { should be(false) }
    its(:domain_model) { should be(Hash) }

    context '.finalize on Praxis::Blueprint' do
      before do
        blueprint_class.should_receive(:_finalize!).and_call_original
        Praxis::Blueprint.finalize!
      end

      its(:finalized?) { should be(true) }
    end

    context '.finalize on that subclass' do
      before do
        blueprint_class.should_receive(:_finalize!).and_call_original
        blueprint_class.finalize!
      end

      its(:finalized?) { should be(true) }
    end
  end

  context 'creating a base abstract Blueprint class without attributes' do
    subject!(:blueprint_class) do
      Class.new(Praxis::Blueprint)
    end

    it 'skips attribute definition' do
      blueprint_class.should_receive(:_finalize!).and_call_original
      blueprint_class.should_not_receive(:define_attribute)
      blueprint_class.finalize!
      blueprint_class.finalized?.should be(true)
    end
  end

  it 'has an inner Struct class for the attributes' do
    blueprint_class.attribute.type.should be blueprint_class::Struct
  end

  context '.views' do
    it { blueprint_class.should respond_to(:views) }
    it 'sorta has view objects' do
      blueprint_class.views.should have_key(:default)
    end
  end

  context 'an instance' do
    shared_examples 'a blueprint instance' do
      let(:expected_name) { blueprint_instance.name }

      context '#render' do
        let(:view) { :default }
        subject(:output) { blueprint_instance.render(view: view) }

        it { should have_key(:name) }
        it 'has the right values' do
          subject[:name].should eq(expected_name)
        end
      end

      context 'validation' do
        subject(:errors) { blueprint_class.validate(blueprint_instance) }
        it { should be_empty }
      end
    end

    context 'from Blueprint.example' do
      subject(:blueprint_instance) do
        blueprint_class.example('ExamplePerson', 
          address: nil,
          prior_addresses: [],
          work_address: nil,
          myself: nil,
          friends: []
        )
      end
      it_behaves_like 'a blueprint instance'
    end

    context 'wrapping an object' do
      let(:data) do
        {
          name: 'Bob',
          full_name: FullName.example,
          address: nil,
          email: 'bob@example.com',
          aliases: [],
          prior_addresses: [],
          parents: { father: Randgen.first_name, mother: Randgen.first_name },
          href: 'www.example.com',
          alive: true
        }
      end

      let(:resource) { blueprint_class.load(data).object }

      subject(:blueprint_instance) { blueprint_class.new(resource) }

      it_behaves_like 'a blueprint instance'

      context 'creating additional blueprint instances from that object' do
        subject(:additional_instance) { blueprint_class.new(resource) }

        context 'with caching enabled' do
          around do |example|
            Praxis::Blueprint.caching_enabled = true
            Praxis::Blueprint.cache = Hash.new { |h, k| h[k] = {} }
            example.run

            Praxis::Blueprint.caching_enabled = false
            Praxis::Blueprint.cache = nil
          end

          it 'uses the cache to memoize instance creation' do
            additional_instance.should be(additional_instance)
            blueprint_class.cache.should have_key(resource)
            blueprint_class.cache[resource].should be(blueprint_instance)
          end
        end

        context 'with caching disabled' do
          it { should_not be blueprint_instance }
        end
      end
    end
  end

  context '.describe' do
    let(:shallow) { false }
    let(:example_object) { nil }

    before do
      expect(blueprint_class.attribute.type).to receive(:describe).with(shallow, example: example_object).ordered.and_call_original
    end

    context 'for non-shallow descriptions' do
      before do
        # Describing a Person also describes the :myself and :friends attributes. They are both a Person and a Coll of Person.
        # This means that Person type `describe` is called two more times, thes times with shallow=true
        expect(blueprint_class.attribute.type).to receive(:describe).with(true, example: example_object).twice.and_call_original
      end

      subject(:output) { blueprint_class.describe }

      its([:name]) { should eq(blueprint_class.name) }
      its([:id]) { should eq(blueprint_class.id) }
      its([:views]) { should be_kind_of(Hash) }
      its(:keys) { should_not include(:anonymous) }
      it 'should contain the an entry for each view' do
        subject[:views].keys.should include(:default, :current, :extended)
      end
    end

    context 'for shallow descriptions' do
      let(:shallow) { true }

      it 'should not include views' do
        blueprint_class.describe(true).key?(:views).should be(false)
      end
      context 'for anonymous blueprints' do
        let(:blueprint_class) do
          klass = Class.new(Praxis::Blueprint) do
            anonymous_type
            attributes do
              attribute :name, String
            end
          end
          klass.finalize!
          klass
        end
        it 'reports their anonymous-ness' do
          description = blueprint_class.describe(true)
          expect(description).to have_key(:anonymous)
          expect(description[:anonymous]).to be(true)
        end
      end
    end

    context 'with an example' do
      let(:example) { blueprint_class.example }
      let(:example_object) { example.object }
      let(:shallow) { false }

      subject(:output) { blueprint_class.describe(false, example: example) }
      before do
        # Describing a Person also describes the :myself and :friends attributes. They are both a Person and a Coll of Person.
        # This means that Person type `describe` is called two more times, thes times with shallow=true
        expect(blueprint_class.attribute.type).to receive(:describe)
          .with(true, example: an_instance_of(blueprint_class.attribute.type)).twice.and_call_original
      end

      it 'outputs examples for leaf values using the provided example' do
        output[:attributes][:name][:example].should eq example.name
        output[:attributes][:age][:example].should eq example.age

        output[:attributes][:aliases].should have_key(:example)
        output[:attributes][:aliases][:example].should eq example.aliases.dump

        output[:attributes][:full_name].should_not have_key(:example)

        parents_attributes = output[:attributes][:parents][:type][:attributes]
        parents_attributes[:father][:example].should eq example.parents.father
        parents_attributes[:mother][:example].should eq example.parents.mother
      end
    end
  end

  context '.validate' do
    let(:hash) { { name: 'bob' } }
    let(:person) { Person.load(hash) }
    subject(:errors) { person.validate }

    context 'that is valid' do
      it { should be_empty }
    end

    context 'with invalid sub-attribute' do
      let(:hash) { { name: 'bob', address: { state: 'ME' } } }

      it { should have(1).item }
      its(:first) { should =~ /Attribute \$.address.state/ }
    end

    context 'for objects of the wrong type' do
      it 'raises an error' do
        expect do
          Person.validate(Object.new)
        end.to raise_error(ArgumentError, /Error validating .* as Person for an object of type Object/)
      end
    end
  end

  context '.load' do
    let(:hash) do
      {
        name: 'Bob',
        full_name: { first: 'Robert', last: 'Robertson' },
        address: { street: 'main', state: 'OR' }
      }
    end
    subject(:person) { Person.load(hash) }

    it { should be_kind_of(Person) }

    context 'recursively loading sub-attributes' do
      context 'for a Blueprint' do
        subject(:address) { person.address }
        it { should be_kind_of(Address) }
      end
      context 'for an Attributor::Model' do
        subject(:full_name) { person.full_name }
        it { should be_kind_of(FullName) }
      end
    end
  end

  context 'with a provided :reference option on attributes' do
    context 'that does not match the value set on the class' do
      subject(:mismatched_reference) do
        Class.new(Praxis::Blueprint) do
          self.reference = Class.new(Praxis::Blueprint)
          attributes(reference: Class.new(Praxis::Blueprint)) {}
        end
      end

      it 'should raise an error' do
        expect do
          mismatched_reference.attributes
        end.to raise_error
      end
    end
  end

  context '.example' do
    context 'with some attribute values provided' do
      let(:name) { 'Sir Bobbert' }
      subject(:person) { Person.example(name: name) }
      its(:name) { should eq(name) }
    end
  end

  context '.render' do
    let(:person) { Person.example('1') }
    it 'is an alias to dump' do
      person.object.contents
      rendered = Person.render(person, fields: [:name, :full_name])
      dumped = Person.dump(person, fields: [:name, :full_name])
      expect(rendered).to eq(dumped)
    end
  end

  context '#render' do
    let(:person) { Person.example }
    let(:view_name) { :default }
    let(:fields) do 
      {
        name: true,
        full_name: true,
        address: {
          street: true,
          state: true,
        },
        prior_addresses: {
          street: true,
          state: true,
        }
      }
    end
    let(:render_opts) { {} }
    subject(:output) { person.render(fields: fields, **render_opts) }

    context 'with a sub-attribute that is a blueprint' do
      it { should have_key(:name) }
      it { should have_key(:address) }
      it 'renders the sub-attribute correctly' do
        output[:address].should have_key(:street)
        output[:address].should have_key(:state)
      end

      it 'reports a dump error with the appropriate context' do
        person.address.should_receive(:state).and_raise('Kaboom')
        expect do
          person.render(fields: fields, context: ['special_root'])
        end.to raise_error(/Error while dumping attribute state of type Address for context special_root.address. Reason: .*Kaboom/)
      end
    end

    context 'with sub-attribute that is an Attributor::Model' do
      it { should have_key(:full_name) }
      it 'renders the model correctly' do
        output[:full_name].should be_kind_of(Hash)
        output[:full_name].should have_key(:first)
        output[:full_name].should have_key(:last)
      end
    end

    context 'using the `fields` option' do
      context 'as a hash' do
        subject(:output) { person.render(fields: { address: { state: true } }) }
        it 'should only have the address rendered' do
          output.keys.should eq [:address]
        end
        it 'address should only have state' do
          output[:address].keys.should eq [:state]
        end
      end
      context 'as a simple array' do
        subject(:output) { person.render(fields: [:full_name]) }
        it 'accepts it as the list of top-level attributes to be rendered' do
          output.keys.should == [:full_name]
        end
      end
    end
  end

  context '.as_json_schema' do
    it 'delegates to the attribute type' do
      Person.attribute.type.should receive(:as_json_schema)
      Person.as_json_schema
    end
  end
  context '.json_schema_type' do
    it 'delegates to the attribute type' do
      Person.attribute.type.should receive(:json_schema_type)
      Person.json_schema_type
    end
  end
end
