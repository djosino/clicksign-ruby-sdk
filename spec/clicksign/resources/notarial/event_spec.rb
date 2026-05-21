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

  describe '.create' do
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
      event = described_class.create(
        envelope_id: envelope_id,
        document_id: document_id,
        name: 'read',
      )

      expect(event).to be_a(described_class)
      expect(event.id).to eq(event_id)
      expect(event.name).to eq('read')
    end

    it 'posts to the correct nested URL' do
      described_class.create(
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
        event = described_class.create(
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
          described_class.create(
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
          described_class.create(
            envelope_id: envelope_id,
            document_id: document_id,
            name: 'invalid_name',
          )
        end.to raise_error(Clicksign::ValidationError, 'name is invalid')
      end
    end
  end

  describe '.create_add_image' do
    let(:created_event) do
      event_data(id: event_id, name: 'add_image', envelope_id: envelope_id,
        document_id: document_id)
    end

    before do
      stub_request(:post, events_url)
        .to_return(status: 201, body: single_resource(created_event).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' })
    end

    it 'returns an Event instance', :aggregate_failures do
      event = described_class.create_add_image(
        envelope_id: envelope_id,
        document_id: document_id,
        title: 'Comprovante',
        occurred_at: '2026-01-01T10:00:00-03:00',
        content_base64: 'data:image/jpeg;base64,/9j/4AAQ==',
      )

      expect(event).to be_a(described_class)
      expect(event.name).to eq('add_image')
    end

    it 'posts name=add_image with content_base64 and data payload' do
      described_class.create_add_image(
        envelope_id: envelope_id,
        document_id: document_id,
        title: 'Comprovante',
        occurred_at: '2026-01-01T10:00:00-03:00',
        content_base64: 'data:image/jpeg;base64,/9j/4AAQ==',
      )

      expect(WebMock).to(have_requested(:post, events_url).with do |req|
        attrs = JSON.parse(req.body).dig('data', 'attributes')
        attrs['name'] == 'add_image' &&
          attrs['content_base64'] == 'data:image/jpeg;base64,/9j/4AAQ==' &&
          attrs.dig('data', 'title') == 'Comprovante' &&
          attrs.dig('data', 'occurred_at') == '2026-01-01T10:00:00-03:00'
      end)
    end
  end

  describe '.create_custom' do
    let(:created_event) do
      event_data(id: event_id, name: 'custom', envelope_id: envelope_id,
        document_id: document_id)
    end

    before do
      stub_request(:post, events_url)
        .to_return(status: 201, body: single_resource(created_event).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' })
    end

    context 'with kind: token_email' do
      it 'returns an Event instance' do
        event = described_class.create_custom(
          envelope_id: envelope_id,
          document_id: document_id,
          kind: 'token_email',
          occurred_at: '2026-01-01T10:00:00-03:00',
          signer_name: 'Maria Silva',
          signer_email: 'maria@example.com',
        )

        expect(event).to be_a(described_class)
      end

      it 'posts name=custom with correct data payload' do
        described_class.create_custom(
          envelope_id: envelope_id,
          document_id: document_id,
          kind: 'token_email',
          occurred_at: '2026-01-01T10:00:00-03:00',
          signer_name: 'Maria Silva',
          signer_email: 'maria@example.com',
        )

        expect(WebMock).to(have_requested(:post, events_url).with do |req|
          data = JSON.parse(req.body).dig('data', 'attributes', 'data')
          data['kind'] == 'token_email' &&
            data['signer_name'] == 'Maria Silva' &&
            data['signer_email'] == 'maria@example.com' &&
            !data.key?('signer_phone_number')
        end)
      end
    end

    context 'with kind: token_sms' do
      it 'posts signer_phone_number and omits signer_email when nil' do
        described_class.create_custom(
          envelope_id: envelope_id,
          document_id: document_id,
          kind: 'token_sms',
          occurred_at: '2026-01-01T10:00:00-03:00',
          signer_name: 'João Costa',
          signer_phone_number: '11988887777',
        )

        expect(WebMock).to(have_requested(:post, events_url).with do |req|
          data = JSON.parse(req.body).dig('data', 'attributes', 'data')
          data['kind'] == 'token_sms' &&
            data['signer_phone_number'] == '11988887777' &&
            !data.key?('signer_email')
        end)
      end
    end

    context 'with invalid kind' do
      it 'raises ArgumentError before making a request' do
        expect do
          described_class.create_custom(
            envelope_id: envelope_id,
            document_id: document_id,
            kind: 'invalid',
            occurred_at: '2026-01-01T10:00:00-03:00',
            signer_name: 'Maria Silva',
          )
        end.to raise_error(ArgumentError, /kind must be one of/)

        expect(WebMock).not_to have_requested(:post, events_url)
      end
    end
  end

  describe 'unsupported instance operations' do
    let(:event) do
      described_class.send(:build_instance,
        event_data(id: event_id, name: 'sign',
          envelope_id: envelope_id))
    end

    it '#update raises NotImplementedError' do
      expect { event.update(name: 'x') }.to raise_error(NotImplementedError)
    end

    it '#delete raises NotImplementedError' do
      expect { event.delete }.to raise_error(NotImplementedError)
    end

    it '#reload raises NotImplementedError' do
      expect { event.reload }.to raise_error(NotImplementedError)
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
