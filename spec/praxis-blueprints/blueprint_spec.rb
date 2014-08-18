require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Praxis::Blueprint do

  subject(:blueprint_class) { Person }


  context 'deterministic examples' do
    it 'works' do
      person_1 = Person.example('person 1')
      person_2 = Person.example('person 1')

      person_1.name.should eq(person_2.name)
      person_1.address.name.should eq(person_2.address.name)
    end
  end

  context 'implicit master view' do
    subject(:master_view) { Person.view(:master) }

    it { should_not be(nil) }
    it 'contains all attributes' do
      master_view.contents.keys.should =~ Person.attributes.keys
    end

    it 'uses :master view for rendering blueprint sub-attributes' do
      dumpable, dumpable_opts = master_view.contents[:address]
      dumpable_opts[:view].should == :master
    end
  end

  context 'creating a new Blueprint class' do
    subject!(:blueprint_class) do
      Class.new(Praxis::Blueprint) do
        attributes do
          attribute :id, Integer
        end
      end
    end

    its(:finalized?) { should be(false) }

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
        subject(:output) { blueprint_instance.render(view) }

        it { should have_key(:name) }
        it 'has the right values' do
          subject[:name].should eq(expected_name)
        end
      end

      context 'validation' do
        subject(:errors) { blueprint_class.validate(blueprint_instance) }
        pending do
          it { should be_empty }
        end
      end
    end


    context 'from Blueprint.example' do
      subject(:blueprint_instance) { blueprint_class.example }
      it_behaves_like 'a blueprint instance'
    end

    context 'wrapping an object' do

      let(:resource) do
        double("resource",
               name: 'Bob',
               full_name: FullName.example,
               address: Address.example,
               email: "bob@example.com",
               aliases: [],
               prior_addresses: [],
               parents: double('parents', father: /[:first_name:]/.gen, mother: /[:first_name:]/.gen),
               href: "www.example.com",
               alive: true)
      end

      subject(:blueprint_instance) { blueprint_class.new(resource) }

      it_behaves_like 'a blueprint instance'

      context 'creating additional blueprint instances from that object' do
        subject(:additional_instance) { blueprint_class.new(resource) }

        context 'with caching enabled' do
          around do |example|
            Praxis::Blueprint.caching_enabled = true
            Praxis::Blueprint.cache = Hash.new { |h,k| h[k] = Hash.new }
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


  context '.validate' do
    let(:hash) { {name: 'bob'} }
    let(:person) { Person.load(hash) }
    subject(:errors) { person.validate }

    context 'that is valid' do
      it { should be_empty }
    end

    context 'with invalid sub-attribute' do
      let(:hash) { {name: 'bob', address: {state: "ME"}} }

      it { should have(1).item }
      its(:first) { should =~ /Attribute \$.address.state/ }
 end

 context 'for objects of the wrong type' do
   it 'raises an error' do
     expect {
       Person.validate(Object.new)
     }.to raise_error(ArgumentError, /Error validating .* as Person for an object of type Object/)
   end
 end
 end


 context '.load' do
   let(:hash) do
     {
       :name => 'Bob',
       :full_name => {:first => 'Robert', :last => 'Robertson'},
       :address => {:street => 'main', :state => 'OR'}
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


 context 'decorators' do
   let(:name) { 'Soren II' }

   let(:object) { Person.example.object }
   subject(:person) { Person.new(object, decorators) }


   context 'as a hash' do
     let(:decorators) { {name: name} }
     it do
       pers = person
       # binding.pry
       pers.name.should eq('Soren II')
     end

     its(:name) { should be(name) }

     context 'an additional instance with the equivalent hash' do
       subject(:additional_person) { Person.new(object, {name: name}) }
       it { should_not be person }
     end

     context 'an additional instance with the same hash object' do
       subject(:additional_person) { Person.new(object, decorators) }
       it { should_not be person }
     end

     context 'an instance of the same object without decorators' do
       subject(:additional_person) { Person.new(object) }
       it { should_not be person }
     end
   end

   context 'as an object' do
     let(:decorators) { double("decorators", name: name) }
     its(:name) { should be(name) }

     context 'an additional instance with the same object' do
       subject(:additional_person) { Person.new(object, decorators) }
       it { should_not be person }
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
       expect {
         mismatched_reference.attributes
       }.to raise_error
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

 context '#render' do
   let(:person) { Person.example }
   let(:view_name) { :default }
   subject(:output) { person.render(view_name) }

   context 'with a sub-attribute that is a blueprint' do

     it { should have_key(:name) }
     it { should have_key(:address) }
     it 'renders the sub-attribute correctly' do
       output[:address].should have_key(:street)
       output[:address].should have_key(:state)
     end

     it 'reports a dump error with the appropriate context' do
       person.address.should_receive(:state).and_raise("Kaboom")
       expect {
         person.render(view_name, context: ['special_root'])
       }.to raise_error(/Error while dumping attribute state of type Address for context special_root.address .*. Reason: .*Kaboom/)
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


   # context 'with circular references' do
   #   let(:view_name) { :master }

   #   # TODO: think about circular references without caching
   #   around do |example|
   #     Praxis::Blueprint.caching_enabled = true
   #     example.run
   #     Praxis::Blueprint.caching_enabled = false
   #   end

   #   it 'terminates' do
   #     expect {
   #       Person.example.render(:master)
   #     }.to_not raise_error
   #   end

   #   it 'renders Praxis::Blueprint::CIRCULAR_REFERENCE_MARKER for circular references' do
   #     person.address.resident.should be(person)
   #     output[:address][:resident].should eq(Praxis::Blueprint::CIRCULAR_REFERENCE_MARKER)
   #   end

   # end
   
 end

end
