# # frozen_string_literal: true
# require_relative '../spec_helper'

# describe Praxis::CollectionView do
#   let(:root_context) { ['people'] }

#   let(:people) do
#     Array.new(3) do |i|
#       context = ['people', "at(#{i})"]
#       Person.example(context)
#     end
#   end

#   let(:contents_definition) do
#     proc do
#       attribute :name
#       attribute :address, view: :state
#     end
#   end

#   let(:member_view) do
#     Praxis::View.new(:tiny, Person, &contents_definition)
#   end

#   let(:collection_view) do
#     Praxis::CollectionView.new(:collection_view, Person, member_view)
#   end

#   context 'creating from a member view' do
#     it 'gets the proper contents' do
#       collection_view.contents.should eq member_view.contents
#     end

#     context 'lazy initializes its contents' do
#       it 'so it will not call contents until it is first needed' do
#         member_view.stub(:contents) { raise 'No!' }
#         expect { collection_view.name }.to_not raise_error
#       end
#       it 'when contents is needed, it will clone it from the member_view' do
#         # Twice is because we're callong member_view.contents for the right side of the equality
#         expect(member_view).to receive(:contents).twice.and_call_original
#         collection_view.contents.should eq member_view.contents
#       end
#     end
#   end

#   context 'creating with a set of attributes defined in a block' do
#     let(:collection_view) do
#       Praxis::CollectionView.new(:collection_view, Person, &contents_definition)
#     end

#     it 'gets the proper contents' do
#       collection_view.contents.should eq member_view.contents
#     end
#   end

#   context '#render' do
#     subject(:output) { collection_view.render(people, context: root_context) }

#     it { should be_kind_of(Array) }
#     it { should eq people.collect { |person| member_view.render(person) } }
#   end

#   context '#example' do
#     it 'generates an example from the schema and renders it' do
#       # because we set the context throughout, we know +people+ will
#       # will generate with identical contents across all runs.
#       expected = people.collect do |person|
#         { name: person.name, address: person.address.render(view: :state) }
#       end

#       collection_view.example(root_context).should eq expected
#     end
#   end

#   context '#describe' do
#     subject(:description) { collection_view.describe }

#     its([:attributes]) { should eq(member_view.describe[:attributes]) }
#     its([:type]) { should eq(:collection) }
#   end
# end
