# # frozen_string_literal: true
# require_relative '../spec_helper'

# describe Praxis::View do
#   let(:person) { Person.example(['person']) }
#   let(:address) { person.address }

#   let(:view) do
#     Praxis::View.new(:testing, Person) do
#       attribute :name
#       attribute :email
#       attribute :full_name
#       attribute :parents do
#         attribute :father
#         attribute :mother
#       end
#       attribute :address, view: :extended
#       attribute :prior_addresses, view: :state
#       attribute :work_address
#     end
#   end

#   it 'can generate examples' do
#     view.example.should have_key(:name)
#   end

#   it 'delegates to Renderer with its expanded_fields' do
#     renderer = Praxis::Renderer.new
#     renderer.should_receive(:render).with(person, view.expanded_fields, context: 'foo')
#     view.render(person, context: 'foo', renderer: renderer)
#   end

#   context 'defining views' do
#     subject(:contents) { view.contents }
#     its(:keys) { should match_array([:name, :email, :full_name, :parents, :address, :prior_addresses, :work_address]) }
#     it 'saves attributes defined on the Blueprint' do
#       [:name, :email, :full_name].each do |attr|
#         contents[attr].should be Person.attributes[attr]
#       end
#     end

#     it 'saves views for attributes for Blueprints' do
#       contents[:address].should be Address.views[:extended]
#       contents[:work_address].should be Address.views[:default]
#     end

#     it 'does something with collections of Blueprints' do
#       contents[:prior_addresses].should be_kind_of(Praxis::CollectionView)
#       contents[:prior_addresses].contents.should eq Address.views[:state].contents
#     end

#     context 'creating subviews' do
#       it 'creates subviews when a block is used' do
#         contents[:parents].should be_kind_of(Praxis::View)
#       end

#       context 'for collections' do
#         let(:view) do
#           Praxis::View.new(:testing, Person) do
#             attribute :name
#             attribute :prior_addresses do
#               attribute :name
#               attribute :street
#             end
#           end
#         end

#         it 'creates sub-CollectionViews from a block' do
#           contents[:prior_addresses].should be_kind_of(Praxis::CollectionView)
#           contents[:prior_addresses].contents.keys.should match_array([:name, :street])
#         end
#       end

#       context 'that reference the enclosing view' do
#         let(:view) { Person.views.fetch(:self_referencing) }
#         context 'for non-collection attributes' do
#           it 'the view points exactly to parent view' do
#             contents[:myself].should be_kind_of(Praxis::View)
#             contents[:myself].should be(view)
#             contents[:myself].contents.should eq(view.contents)
#           end
#         end
#         context 'for collection attributes' do
#           it 'creates the sub-CollectionViews with a member view with the same contents of the parent' do
#             contents[:friends].should be_kind_of(Praxis::CollectionView)
#             contents[:friends].contents.should eq(view.contents)
#             contents[:friends].contents.keys.should match_array([:myself, :friends])
#           end
#         end
#       end
#     end
#   end

#   context '#describe' do
#     subject(:description) { view.describe }
#     its(:keys) { should =~ [:attributes, :type] }
#     its([:type]) { should eq(:standard) }
#     context 'returns attributes' do
#       subject { description[:attributes] }

#       its(:keys) { should match_array view.contents.keys }

#       it 'should return empty hashes for attributes with no specially defined view' do
#         subject[:name].should eq({})
#         subject[:email].should eq({})
#       end
#       it 'should return the view name if specified' do
#         subject[:address].should eq(view: :extended)
#         subject[:prior_addresses].should eq(view: :state)
#       end
#     end
#   end
# end
