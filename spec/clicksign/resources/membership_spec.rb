# frozen_string_literal: true

RSpec.describe Clicksign::Resources::Membership do
  include_context 'with clicksign configured'

  let(:membership_id) { '33333333-3333-3333-3333-333333333333' }
  let(:user_id) { '11111111-1111-1111-1111-111111111111' }
  let(:memberships_url) { "#{JsonApiFixtures::BASE_URL}/memberships" }
  let(:membership_url) { "#{JsonApiFixtures::BASE_URL}/memberships/#{membership_id}" }

  let(:primary_membership) do
    membership_data(id: membership_id, role: 'admin', user_id: user_id)
  end

  let(:member_membership) do
    membership_data(
      id: '44444444-4444-4444-4444-444444444444',
      role: 'member',
      user_id: '22222222-2222-2222-2222-222222222222',
    )
  end

  describe '.list' do
    subject(:memberships) { described_class.list }

    before do
      stub_request(:get, memberships_url)
        .to_return(
          status: 200,
          body: collection_resource([primary_membership, member_membership]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it { is_expected.to be_an(Array) }
    it { is_expected.to all(be_a(described_class)) }

    it 'returns records with expected attributes', :aggregate_failures do
      expect(memberships.first.id).to eq(membership_id)
      expect(memberships.first.role).to eq('admin')
      expect(memberships.first.user_id).to eq(user_id)
      expect(memberships.first.consumption_accessible).to be(false)
      expect(memberships.first.tracking_accessible).to be(false)
      expect(memberships.first.folder_management_accessible).to be(false)
    end
  end

  describe '.filter' do
    subject(:memberships) { described_class.filter('user.id': user_id).to_a }

    before do
      stub_request(:get, memberships_url)
        .with(query: { 'filter[user.id]' => user_id })
        .to_return(
          status: 200,
          body: collection_resource([primary_membership]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it { is_expected.to be_an(Array) }
    it { is_expected.to all(have_attributes(user_id: user_id)) }
  end

  describe '.create' do
    subject(:membership) do
      described_class.create(role: 'member', user_id: user_id)
    end

    let(:created_membership) do
      membership_data(
        id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        role: 'member',
        user_id: user_id,
      )
    end

    before do
      stub_request(:post, memberships_url)
        .to_return(
          status: 201,
          body: single_resource(created_membership).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it { is_expected.to be_a(described_class) }

    it 'returns a persisted membership', :aggregate_failures do
      expect(membership.id).to eq('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
      expect(membership.role).to eq('member')
      expect(membership.user_id).to eq(user_id)
    end

    it 'posts role and user relationship' do
      membership

      expect(WebMock).to(have_requested(:post, memberships_url).with do |req|
        body = JSON.parse(req.body)
        data = body['data']

        data['type'] == 'memberships' &&
          data.dig('attributes', 'role') == 'member' &&
          data.dig('relationships', 'user', 'data', 'id') == user_id
      end)
    end

    context 'with optional accessibility attributes' do
      subject(:membership) do
        described_class.create(
          role: 'admin',
          user_id: user_id,
          consumption_accessible: true,
          tracking_accessible: false,
        )
      end

      before do
        stub_request(:post, memberships_url)
          .to_return(
            status: 201,
            body: single_resource(
              membership_data(
                id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
                role: 'admin',
                user_id: user_id,
                consumption_accessible: true,
                tracking_accessible: false,
              ),
            ).to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'includes optional attributes in the request' do
        membership

        expect(WebMock).to(have_requested(:post, memberships_url).with do |req|
          attrs = JSON.parse(req.body).dig('data', 'attributes')
          attrs['consumption_accessible'] == true && attrs['tracking_accessible'] == false
        end)
      end
    end
  end

  describe '#update' do
    subject(:updated) { membership.update(role: 'member') }

    let(:membership) { described_class.send(:build_instance, primary_membership) }

    before do
      stub_request(:patch, membership_url)
        .to_return(
          status: 200,
          body: single_resource(
            membership_data(id: membership_id, role: 'member', user_id: user_id),
          ).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'updates and returns the record', :aggregate_failures do
      expect(updated).to be_a(described_class)
      expect(updated.id).to eq(membership_id)
      expect(updated.role).to eq('member')
      expect(updated.user_id).to eq(user_id)
    end
  end

  describe '#delete' do
    let(:membership) { described_class.send(:build_instance, primary_membership) }

    before do
      stub_request(:delete, membership_url).to_return(status: 204, body: '')
    end

    it 'deletes the membership without raising' do
      expect { membership.delete }.not_to raise_error
    end

    it 'issues a DELETE request' do
      membership.delete

      expect(WebMock).to have_requested(:delete, membership_url)
    end
  end
end
