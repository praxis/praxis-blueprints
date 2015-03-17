require_relative '../spec_helper'

describe Praxis::View do

  let(:person) { Person.example(['person']) }
  let(:address) { person.address }

  let(:view) do
    Praxis::View.new(:tiny, Person) do
      attribute :name
      attribute :alive
      attribute :address, view: :state
    end
  end

  subject(:output) { view.to_hash(person) }


  it 'can generate examples' do
    view.example.should have_key(:name)
  end

  context 'swanky rendering options' do
    let(:view) do
      Praxis::View.new(:info, Person) do
        attribute :name
        attribute :email
        attribute :age
        attribute :address
      end
    end

    let(:data) { {name: 'Bob', email: nil, address: nil } }

    let(:person) { Person.load(data) }

    context 'with default rendering options' do
      it 'attributor works right' do
        person.object.key?(:name).should be(true)
        person.object.key?(:email).should be(true)
        person.object.key?(:age).should be(false)
        person.object.key?(:address).should be(true)

        person.name.should eq('Bob')
        person.email.should eq(nil)
        person.age.should eq(nil)
        person.address.should eq(nil)
      end

      it 'renders existing, non-nil, attributes' do
        output.key?(:name).should be(true)
        output.key?(:email).should_not be(true)
        output.key?(:age).should_not be(true)
        output.key?(:address).should_not be(true)
      end
    end

    context 'with include_nil: true' do
      let(:view) do
        Praxis::View.new(:info, Person, include_nil: true) do
          attribute :name
          attribute :email
          attribute :age
          attribute :address
        end
      end

      subject(:output) { view.to_hash(person) }

      it 'includes attributes with nil values' do
        output.key?(:email).should be(true)
        output[:email].should be(nil)

        output.key?(:address).should be(true)
        output[:address].should be(nil)

        output.key?(:age).should be(true)
        output[:age].should be(nil)
      end

    end

  
  end



  context 'direct attributes' do

    let(:person) { Person.load(person_data) }
    context 'with undisputably existing values' do

      let(:person_data) { {name:'somename', alive:true} }

      let(:expected_output) do
        {
          :name => 'somename',
          :alive => true
        }
      end
      it 'should show up' do
        subject.should == expected_output
      end
    end
    context 'with nil values' do
      let(:person_data) { {name:'alive_is_nil', alive: nil} }
      let(:expected_output) do
        {
          name: 'alive_is_nil',
          alive: true
        }
      end
      it 'are skipped completely' do
        subject.should == expected_output
      end
    end

    context 'with false values' do
      let(:person_data) { {name:'alive_is_false', alive:false} }
      let(:expected_output) do
        {
          :name => 'alive_is_false',
          :alive => false
        }
      end
      it 'should still show up, since "false" is really a valid value' do
        subject.should == expected_output
      end
    end

  end

  context 'nested attributes' do

    context 'without block' do
      let(:view) do
        Praxis::View.new(:parents, Person) do
          attribute :name
          attribute :parents
        end
      end

      let(:expected_output) do
        {
          :name => person.name,
          :parents => {
            :father => person.parents.father,
            :mother => person.parents.mother
          }
        }
      end

      it { should eq expected_output }

    end

    context 'with block' do
      let(:view) do
        Praxis::View.new(:paternal, Person) do
          attribute :name
          attribute :parents do
            attribute :father
          end
        end
      end
      let(:expected_output) do
        {
          :name => person.name,
          :parents => {
            :father => person.parents.father
          }
        }
      end

      it { should eq expected_output }
    end

  end


  context 'using a related object as an attribute' do

    context 'using default view' do
      let(:view) do
        Praxis::View.new(:default, Person) do
          attribute :name
          attribute :address
        end
      end
      let(:expected_output) do
        {
          :name => person.name,
          :address => {
            :street => address.street,
            :state => address.state
          }
        }
      end


      it { should eq expected_output }

    end


    context 'specifying a view' do
      let(:view) do
        Praxis::View.new(:default, Person) do
          attribute :name
          attribute :address, :view => :state
        end
      end



      let(:expected_output) do
        {
          :name => person.name,
          :address => {
            :state => address.state
          }
        }
      end

      it { should eq expected_output }
    end


    context 'with some sort of "in-lined" view' do
      let(:view) do
        Praxis::View.new(:default, Person) do
          attribute :name
          attribute :address do
            attribute :state
          end
        end
      end

      let(:expected_output) do
        {
          :name => person.name,
          :address => {
            :state => address.state
          }
        }
      end



      it { should eq expected_output }
    end

    context 'when the related object is nil (does not respond to the related method)' do
      let(:person) { Person.load(name: 'Bob') }

      let(:view) do
        Praxis::View.new(:default, Person) do
          attribute :name
          attribute :address
        end
      end
      let(:expected_output) do
        {
          :name => person.name
        }
      end

      it { should eq expected_output }
    end

  end


  context 'using a related collection as an attribute' do
    context 'with the default view' do
      let(:view) do
        Praxis::View.new(:default, Person) do
          attribute :name
          attribute :prior_addresses
        end
      end

      let(:expected_output) do
        {
          :name => person.name,
          :prior_addresses => person.prior_addresses.collect { |a| a.to_hash(:default)}
        }
      end

      it { should eq expected_output }
    end


    context 'with a specified view' do
      let(:view) do
        Praxis::View.new(:default, Person) do
          attribute :name
          attribute :prior_addresses, :view => :state
        end
      end

      let(:expected_output) do
        {
          :name => person.name,
          :prior_addresses => person.prior_addresses.collect { |a| a.to_hash(:state)}
        }
      end

      it { should eq expected_output }
    end

  end


  context '#describe' do
    subject(:description) { view.describe}
    its(:keys){ should =~ [:attributes, :type] }
    its([:type]) { should eq(:standard) }
    context 'returns attributes' do
      subject { description[:attributes] }

      its(:keys){ should == [:name,:alive,:address]  }

      it 'should return empty hashes for attributes with no specially defined view' do
        subject[:name].should == {}
        subject[:alive].should == {}
      end
      it 'should return the view name if specified' do
        subject[:address].should == {view: :state}
      end
    end
  end

end
