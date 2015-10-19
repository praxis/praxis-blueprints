require_relative '../spec_helper'

describe Praxis::CollectionView do

  let(:root_context) { ['people'] }

  let(:people) do
    3.times.collect do |i|
      context = ["people", "at(#{i})"]
      Person.example(context)
    end
  end


  let(:contents_definition) do
    proc do
      attribute :name
      attribute :address, view: :state
    end
  end

  let(:member_view) do
    Praxis::View.new(:tiny, Person, &contents_definition)
  end

  let(:collection_view) do
    Praxis::CollectionView.new(:collection_view, Person, member_view)
  end

  context 'creating from a member view' do

    it 'gets the proper contents' do
      collection_view.contents.should eq member_view.contents
    end
  end

  context 'creating with a set of attributes defined in a block' do
    let(:collection_view) do
      Praxis::CollectionView.new(:collection_view, Person, &contents_definition)
    end

    it 'gets the proper contents' do
      collection_view.contents.should eq member_view.contents
    end
  end

  context '#render' do
    subject(:output) { collection_view.render(people, context: root_context) }

    it { should be_kind_of(Array) }
    it { should eq people.collect {|person| member_view.render(person)} }
  end

  context '#example' do
    it 'generates an example from the schema and renders it' do
      # because we set the context throughout, we know +people+ will
      # will generate with identical contents across all runs.
      expected = people.collect do |person|
        { name: person.name, address: person.address.render(view: :state) }
      end

      collection_view.example(root_context).should eq expected
    end
  end

  context '#describe' do
    subject(:description) { collection_view.describe }

    its([:attributes]) { should eq(member_view.describe[:attributes]) }
    its([:type]) { should eq(:collection) }
  end

end
