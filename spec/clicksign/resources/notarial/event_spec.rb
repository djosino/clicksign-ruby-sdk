# frozen_string_literal: true

RSpec.describe Clicksign::Resources::Notarial::Event do
  include_context 'with clicksign configured'

  let(:envelope_id) { 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
  let(:document_id) { '22222222-2222-2222-2222-222222222222' }
  let(:event_id)    { '55555555-5555-5555-5555-555555555555' }

  let(:events_url) do
    "#{JsonApiFixtures::BASE_URL}/envelopes/#{envelope_id}/documents/#{document_id}/events"
  end

  describe 'resource configuration' do
    it 'has the correct resource type' do
      expect(described_class.resource_type).to eq('events')
    end

    it 'has the correct endpoint' do
      expect(described_class.endpoint).to eq('/events')
    end
  end

  describe '.create_for_document' do
    let(:created_event) do
      event_data(
        id: event_id,
        name: 'read',
        envelope_id: envelope_id,
        document_id: document_id,
      )
    end

    before do
      stub_request(:post, events_url)
        .to_return(
          status: 201,
          body: single_resource(created_event).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns an Event instance', :aggregate_failures do
      event = described_class.create_for_document(
        envelope_id: envelope_id,
        document_id: document_id,
        name: 'read',
      )

      expect(event).to be_a(described_class)
      expect(event.id).to eq(event_id)
      expect(event.name).to eq('read')
    end

    it 'posts to the correct nested URL' do
      described_class.create_for_document(
        envelope_id: envelope_id,
        document_id: document_id,
        name: 'read',
      )

      expect(WebMock).to have_requested(:post, events_url)
    end

    context 'with event data payload' do
      let(:created_event_with_data) do
        event_data(
          id: event_id,
          name: 'sign',
          data: { 'ip' => '127.0.0.1' },
          envelope_id: envelope_id,
          document_id: document_id,
        )
      end

      before do
        stub_request(:post, events_url)
          .to_return(
            status: 201,
            body: single_resource(created_event_with_data).to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'exposes the data attribute', :aggregate_failures do
        event = described_class.create_for_document(
          envelope_id: envelope_id,
          document_id: document_id,
          name: 'sign',
          data: { ip: '127.0.0.1' },
        )

        expect(event.name).to eq('sign')
        expect(event.data).to eq('ip' => '127.0.0.1')
      end
    end

    context 'when the envelope does not exist' do
      before do
        stub_request(:post, events_url)
          .to_return(
            status: 404,
            body: { errors: [{ detail: 'not found' }] }.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'raises NotFoundError' do
        expect do
          described_class.create_for_document(
            envelope_id: envelope_id,
            document_id: document_id,
            name: 'read',
          )
        end.to raise_error(Clicksign::NotFoundError)
      end
    end

    context 'with invalid attributes' do
      before do
        stub_request(:post, events_url)
          .to_return(
            status: 422,
            body: { errors: [{ detail: 'name is invalid' }] }.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'raises ValidationError' do
        expect do
          described_class.create_for_document(
            envelope_id: envelope_id,
            document_id: document_id,
            name: 'invalid_name',
          )
        end.to raise_error(Clicksign::ValidationError, 'name is invalid')
      end
    end
  end

  describe 'listed via Envelope' do
    let(:list_events_url) do
      "#{JsonApiFixtures::BASE_URL}/envelopes/#{envelope_id}/events"
    end

    let(:event) { event_data(id: event_id, name: 'close', envelope_id: envelope_id) }

    before do
      stub_request(:get, list_events_url)
        .to_return(
          status: 200,
          body: collection_resource([event]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns Event instances' do
      events = Clicksign::Resources::Notarial::Envelope.list_events(envelope_id)
      expect(events).to all(be_a(described_class))
    end

    it 'exposes event name' do
      expect(Clicksign::Resources::Notarial::Envelope.list_events(envelope_id).first.name)
        .to eq('close')
    end

    context 'with filter params' do
      before do
        stub_request(:get, list_events_url)
          .with(query: { 'filter[name]' => 'sign' })
          .to_return(
            status: 200,
            body: collection_resource([event]).to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'forwards filter params to the request' do
        Clicksign::Resources::Notarial::Envelope.list_events(envelope_id, name: 'sign')

        expect(WebMock).to have_requested(:get, list_events_url)
          .with(query: { 'filter[name]' => 'sign' })
      end
    end
  end
end
