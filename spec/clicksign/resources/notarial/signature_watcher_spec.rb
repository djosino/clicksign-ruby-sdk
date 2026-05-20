# frozen_string_literal: true

RSpec.describe Clicksign::Resources::Notarial::SignatureWatcher do
  include_context 'with clicksign configured'

  let(:envelope_id) { 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
  let(:watcher_id) { '44444444-4444-4444-4444-444444444444' }
  let(:watchers_url) { "#{JsonApiFixtures::BASE_URL}/envelopes/#{envelope_id}/signature_watchers" }
  let(:watcher_url) { "#{watchers_url}/#{watcher_id}" }

  let(:watcher) do
    signature_watcher_data(
      id: watcher_id,
      email: 'watcher@example.com',
      kind: 'all_steps',
      envelope_id: envelope_id,
    )
  end

  describe 'resource configuration' do
    it 'has the correct resource type' do
      expect(described_class.resource_type).to eq('signature_watchers')
    end

    it 'has the correct endpoint' do
      expect(described_class.endpoint).to eq('/signature_watchers')
    end
  end

  describe 'listed via Envelope' do
    subject(:watchers) { Clicksign::Resources::Notarial::Envelope.list_signature_watchers(envelope_id) }

    before do
      stub_request(:get, watchers_url)
        .to_return(
          status: 200,
          body: collection_resource([watcher]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it { is_expected.to all(be_a(described_class)) }
  end

  describe '.create and #delete' do
    before do
      stub_request(:post, watchers_url)
        .to_return(
          status: 201,
          body: single_resource(watcher).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
      stub_request(:delete, watcher_url).to_return(status: 204, body: '')
    end

    it 'creates and deletes a signature watcher without raising', :aggregate_failures do
      instance = described_class.create(
        envelope_id: envelope_id,
        email: 'watcher@example.com',
        kind: 'all_steps',
      )

      expect(instance).to be_a(described_class)
      expect(instance.envelope_id).to eq(envelope_id)
      expect { instance.delete }.not_to raise_error
    end
  end

  describe '.retrieve' do
    before do
      stub_request(:get, watcher_url)
        .to_return(
          status: 200,
          body: single_resource(watcher).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns the watcher matching the given id' do
      expect(described_class.retrieve(watcher_id,
                                      envelope_id: envelope_id).id).to eq(watcher_id)
    end

    context 'when the watcher does not exist' do
      before do
        stub_request(:get, "#{watchers_url}/00000000-0000-0000-0000-000000000000")
          .to_return(
            status: 404,
            body: { errors: [{ detail: 'not found' }] }.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'raises NotFoundError' do
        expect do
          described_class.retrieve('00000000-0000-0000-0000-000000000000',
                                   envelope_id: envelope_id)
        end.to raise_error(Clicksign::NotFoundError)
      end
    end
  end

  describe '#update' do
    let(:instance) do
      described_class.send(:build_instance, watcher, parent_id: envelope_id)
    end

    it 'raises NotImplementedError' do
      expect do
        instance.update(kind: 'specific_steps')
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#reload' do
    let(:instance) do
      described_class.send(:build_instance, watcher, parent_id: envelope_id)
    end

    before do
      stub_request(:get, watcher_url)
        .to_return(
          status: 200,
          body: single_resource(watcher).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'refreshes the record and preserves envelope_id' do
      expect(instance.reload.envelope_id).to eq(envelope_id)
    end
  end
end
