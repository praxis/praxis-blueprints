require_relative '../spec_helper'

describe Praxis::CollectionView do

  let(:collection_schema) { double(:collection_schema) }

  let(:people) { [Person.example('p-1'), Person.example('p-2')] }


  let(:member_view) do
    Praxis::View.new(:tiny, Person) do
      attribute :name
      attribute :address, view: :state
    end
  end

  let(:collection_view) do
    Praxis::CollectionView.new(:collection_view, collection_schema, member_view)
  end

  let(:root_context) { ['people'] }

  context '#dump' do
    before do
      people.each_with_index do |person, i|
        subcontext = root_context + ["at(#{i})"]
        expect(member_view).to(
          receive(:dump).
          with(person, context: subcontext).
        and_call_original)
      end
    end

    subject(:output) { collection_view.dump(people, context: root_context) }

    it { should be_kind_of(Array) }
  end

  context '#example' do
    it 'generates an example from the schema and renders it' do
      expect(collection_schema).to(
        receive(:example).
        with(root_context).
        and_return(people)
      )
      expect(collection_view).to receive(:dump).and_call_original

      collection_view.example(root_context)
    end
  end

  context '#describe' do
    subject(:description) { collection_view.describe }

    its([:attributes]) { should eq(member_view.describe[:attributes]) }
    its([:type]) { should eq(:collection) }
  end

end
