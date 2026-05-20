# frozen_string_literal: true

RSpec.describe Clicksign::Resources::Webhook do
  include_context 'with clicksign configured'

  let(:webhook_id)   { 'w1111111-1111-1111-1111-111111111111' }
  let(:webhooks_url) { "#{JsonApiFixtures::BASE_URL}/webhooks" }
  let(:webhook_url)  { "#{webhooks_url}/#{webhook_id}" }

  let(:active_webhook) do
    webhook_data(
      id: webhook_id,
      endpoint: 'https://example.com/webhook',
      events: %w[sign close],
      status: 'active',
    )
  end

  let(:inactive_webhook) do
    webhook_data(
      id: 'w2222222-2222-2222-2222-222222222222',
      endpoint: 'https://example.com/other',
      events: %w[cancel],
      status: 'inactive',
    )
  end

  describe 'resource configuration' do
    it 'has the correct resource type' do
      expect(described_class.resource_type).to eq('webhooks')
    end

    it 'has the correct endpoint' do
      expect(described_class.endpoint).to eq('/webhooks')
    end
  end

  describe '.list' do
    subject(:webhooks) { described_class.list }

    before do
      stub_request(:get, webhooks_url)
        .to_return(
          status: 200,
          body: collection_resource([active_webhook, inactive_webhook]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it { is_expected.to be_an(Array) }
    it { is_expected.to all(be_a(described_class)) }

    it 'returns records with expected attributes', :aggregate_failures do
      expect(webhooks.first.id).to eq(webhook_id)
      expect(webhooks.first.endpoint).to eq('https://example.com/webhook')
      expect(webhooks.first.events).to eq(%w[sign close])
      expect(webhooks.first.status).to eq('active')
    end
  end

  describe '.filter' do
    context 'with status: active' do
      subject(:webhooks) { described_class.filter(status: 'active').to_a }

      before do
        stub_request(:get, webhooks_url)
          .with(query: { 'filter[status]' => 'active' })
          .to_return(
            status: 200,
            body: collection_resource([active_webhook]).to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it { is_expected.to all(have_attributes(status: 'active')) }
    end

    context 'with status: inactive' do
      subject(:webhooks) { described_class.filter(status: 'inactive').to_a }

      before do
        stub_request(:get, webhooks_url)
          .with(query: { 'filter[status]' => 'inactive' })
          .to_return(
            status: 200,
            body: collection_resource([inactive_webhook]).to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it { is_expected.to all(have_attributes(status: 'inactive')) }
    end
  end

  describe '.retrieve' do
    before do
      stub_request(:get, webhook_url)
        .to_return(
          status: 200,
          body: single_resource(active_webhook).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns the record matching the given id' do
      expect(described_class.retrieve(webhook_id).id).to eq(webhook_id)
    end

    context 'when the webhook does not exist' do
      before do
        stub_request(:get, "#{webhooks_url}/00000000-0000-0000-0000-000000000000")
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
    let(:created_webhook) do
      webhook_data(
        id: webhook_id,
        endpoint: 'https://example.com/hook',
        events: %w[sign],
        status: 'active',
        secret: 'abc123',
      )
    end

    before do
      stub_request(:post, webhooks_url)
        .to_return(
          status: 201,
          body: single_resource(created_webhook).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns a persisted webhook with expected attributes', :aggregate_failures do
      hook = described_class.create(
        endpoint: 'https://example.com/hook',
        events: %w[sign],
      )

      expect(hook).to be_a(described_class)
      expect(hook.id).to eq(webhook_id)
      expect(hook.endpoint).to eq('https://example.com/hook')
      expect(hook.events).to include('sign')
      expect(hook.secret).to be_a(String)
    end

    context 'with invalid attributes' do
      before do
        stub_request(:post, webhooks_url)
          .to_return(
            status: 422,
            body: { errors: [{ detail: 'endpoint is required' }] }.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'raises ValidationError when endpoint is missing' do
        expect do
          described_class.create(events: %w[sign])
        end.to raise_error(Clicksign::ValidationError)
      end
    end
  end

  describe '#update' do
    let(:webhook) { described_class.send(:build_instance, active_webhook) }

    let(:updated_webhook) do
      webhook_data(
        id: webhook_id,
        endpoint: 'https://example.com/updated',
        events: %w[sign close],
        status: 'inactive',
      )
    end

    before do
      stub_request(:patch, webhook_url)
        .to_return(
          status: 200,
          body: single_resource(updated_webhook).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'updates and returns the record', :aggregate_failures do
      updated = webhook.update(endpoint: 'https://example.com/updated',
                               status: 'inactive')

      expect(updated).to be_a(described_class)
      expect(updated.endpoint).to eq('https://example.com/updated')
      expect(updated.status).to eq('inactive')
    end
  end

  describe '#delete' do
    let(:webhook) { described_class.send(:build_instance, active_webhook) }

    before do
      stub_request(:delete, webhook_url).to_return(status: 204, body: '')
    end

    it 'deletes the webhook without raising' do
      expect { webhook.delete }.not_to raise_error
    end
  end
end
