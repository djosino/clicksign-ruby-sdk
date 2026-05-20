# frozen_string_literal: true

RSpec.describe Clicksign::Resources::Group do
  include_context 'with clicksign configured'

  let(:group_id)   { 'g1111111-1111-1111-1111-111111111111' }
  let(:user_id)    { 'u1111111-1111-1111-1111-111111111111' }
  let(:groups_url) { "#{JsonApiFixtures::BASE_URL}/groups" }
  let(:group_url)  { "#{groups_url}/#{group_id}" }

  let(:first_group)  { group_data(id: group_id, name: 'Admins') }
  let(:second_group) do
    group_data(id: 'g2222222-2222-2222-2222-222222222222', name: 'Members')
  end

  describe 'resource configuration' do
    it 'has the correct resource type' do
      expect(described_class.resource_type).to eq('groups')
    end

    it 'has the correct endpoint' do
      expect(described_class.endpoint).to eq('/groups')
    end
  end

  describe '.list' do
    subject(:groups) { described_class.list }

    before do
      stub_request(:get, groups_url)
        .to_return(
          status: 200,
          body: collection_resource([first_group, second_group]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it { is_expected.to be_an(Array) }
    it { is_expected.to all(be_a(described_class)) }

    it 'returns records with expected attributes', :aggregate_failures do
      expect(groups.first.id).to eq(group_id)
      expect(groups.first.name).to eq('Admins')
    end
  end

  describe '.filter' do
    context 'with name' do
      subject(:groups) { described_class.filter(name: 'Admins').to_a }

      before do
        stub_request(:get, groups_url)
          .with(query: { 'filter[name]' => 'Admins' })
          .to_return(
            status: 200,
            body: collection_resource([first_group]).to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it { is_expected.to all(have_attributes(name: 'Admins')) }
    end
  end

  describe '.order' do
    before do
      stub_request(:get, groups_url)
        .with(query: { 'sort' => 'name' })
        .to_return(
          status: 200,
          body: collection_resource([first_group, second_group]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'requests sorted results' do
      described_class.order('name').to_a
      expect(WebMock).to have_requested(:get,
                                        groups_url).with(query: { 'sort' => 'name' })
    end
  end

  describe '.retrieve' do
    before do
      stub_request(:get, group_url)
        .to_return(
          status: 200,
          body: single_resource(first_group).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns the record matching the given id' do
      expect(described_class.retrieve(group_id).id).to eq(group_id)
    end

    context 'when the group does not exist' do
      before do
        stub_request(:get, "#{groups_url}/00000000-0000-0000-0000-000000000000")
          .to_return(
            status: 404,
            body: { errors: [{ detail: 'not found' }] }.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'raises NotFoundError' do
        expect do
          described_class.retrieve('00000000-0000-0000-0000-000000000000')
        end.to raise_error(Clicksign::NotFoundError)
      end
    end
  end

  describe '.create' do
    let(:created_group) { group_data(id: group_id, name: 'New Group') }

    before do
      stub_request(:post, groups_url)
        .to_return(
          status: 201,
          body: single_resource(created_group).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns a persisted group', :aggregate_failures do
      group = described_class.create(name: 'New Group')

      expect(group).to be_a(described_class)
      expect(group.id).to eq(group_id)
      expect(group.name).to eq('New Group')
    end
  end

  describe '#update' do
    let(:group) { described_class.send(:build_instance, first_group) }

    before do
      stub_request(:patch, group_url)
        .to_return(
          status: 200,
          body: single_resource(group_data(id: group_id, name: 'Updated Group')).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'updates the name and returns the record', :aggregate_failures do
      updated = group.update(name: 'Updated Group')

      expect(updated).to be_a(described_class)
      expect(updated.name).to eq('Updated Group')
    end
  end

  describe '#delete' do
    let(:group) { described_class.send(:build_instance, first_group) }

    before do
      stub_request(:delete, group_url).to_return(status: 204, body: '')
    end

    it 'deletes the group without raising' do
      expect { group.delete }.not_to raise_error
    end
  end

  describe '.add_users and .remove_users' do
    let(:relationship_url) { "#{groups_url}/#{group_id}/relationships/users" }

    before do
      stub_request(:post, relationship_url)
        .to_return(status: 204, body: '')
      stub_request(:delete, relationship_url)
        .to_return(status: 204, body: '')
    end

    it '.add_users posts user IDs to the relationship endpoint' do
      described_class.add_users(group_id, [user_id])

      expect(WebMock).to(have_requested(:post, relationship_url).with do |req|
        JSON.parse(req.body)['data'].first['id'] == user_id
      end)
    end

    it '.remove_users sends DELETE with user IDs in the body' do
      described_class.remove_users(group_id, [user_id])

      expect(WebMock).to(have_requested(:delete, relationship_url).with do |req|
        JSON.parse(req.body)['data'].first['id'] == user_id
      end)
    end

    it '.add_users with empty array posts an empty data array' do
      described_class.add_users(group_id, [])

      expect(WebMock).to(have_requested(:post, relationship_url).with do |req|
        JSON.parse(req.body)['data'] == []
      end)
    end

    it '.remove_users with empty array sends DELETE with empty data array' do
      described_class.remove_users(group_id, [])

      expect(WebMock).to(have_requested(:delete, relationship_url).with do |req|
        JSON.parse(req.body)['data'] == []
      end)
    end
  end
end
