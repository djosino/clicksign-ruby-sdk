# frozen_string_literal: true

RSpec.describe Clicksign::Resources::AccessControlList do
  include_context 'with clicksign configured'

  let(:folder_id) { '11111111-1111-1111-1111-111111111111' }
  let(:group_id) { '22222222-2222-2222-2222-222222222222' }
  let(:acl_url) { "#{JsonApiFixtures::BASE_URL}/access_control_lists" }

  describe 'resource configuration' do
    it 'has the correct resource type' do
      expect(described_class.resource_type).to eq('access_control_lists')
    end
  end

  describe '.create' do
    before do
      stub_request(:post, acl_url)
        .to_return(status: 201, body: { data: { type: 'access_control_lists' } }.to_json,
                   headers: { 'Content-Type' => 'application/vnd.api+json' })
    end

    it 'returns without raising' do
      expect do
        described_class.create(folder_id: folder_id, group_id: group_id)
      end.not_to raise_error
    end

    it 'posts folder and group relationships' do
      described_class.create(folder_id: folder_id, group_id: group_id)

      expect(WebMock).to(have_requested(:post, acl_url).with do |req|
        body = JSON.parse(req.body)
        rels = body.dig('data', 'relationships')

        body.dig('data', 'type') == 'access_control_lists' &&
          rels.dig('folder', 'data', 'id') == folder_id &&
          rels.dig('group', 'data', 'id') == group_id
      end)
    end

    context 'with invalid attributes' do
      before do
        stub_request(:post, acl_url)
          .to_return(
            status: 422,
            body: { errors: [{ detail: 'folder not found' }] }.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'raises ValidationError' do
        expect do
          described_class.create(folder_id: 'bad', group_id: group_id)
        end.to raise_error(Clicksign::ValidationError, 'folder not found')
      end
    end
  end

  describe '.destroy' do
    before do
      stub_request(:delete, acl_url).to_return(status: 204, body: '')
    end

    it 'does not raise' do
      expect do
        described_class.destroy(folder_id: folder_id, group_id: group_id)
      end.not_to raise_error
    end

    context 'when the resource does not exist' do
      before do
        stub_request(:delete, acl_url)
          .to_return(
            status: 404,
            body: { errors: [{ detail: 'not found' }] }.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'raises NotFoundError' do
        expect do
          described_class.destroy(folder_id: folder_id, group_id: group_id)
        end.to raise_error(Clicksign::NotFoundError)
      end
    end

    it 'sends DELETE with relationships in the body' do
      described_class.destroy(folder_id: folder_id, group_id: group_id)

      expect(WebMock).to(have_requested(:delete, acl_url).with do |req|
        body = JSON.parse(req.body)
        rels = body.dig('data', 'relationships')

        rels.dig('folder', 'data', 'id') == folder_id &&
          rels.dig('group', 'data', 'id') == group_id
      end)
    end
  end
end
