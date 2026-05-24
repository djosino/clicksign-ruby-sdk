# frozen_string_literal: true

RSpec.describe Clicksign::Resources::Notarial::Document do
  include_context 'with clicksign configured'

  let(:envelope_id) { 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
  let(:document_id) { '22222222-2222-2222-2222-222222222222' }
  let(:documents_url) { "#{JsonApiFixtures::BASE_URL}/envelopes/#{envelope_id}/documents" }
  let(:document_url) { "#{documents_url}/#{document_id}" }

  let(:document) do
    document_data(id: document_id, filename: 'contract.pdf', status: 'draft',
      envelope_id: envelope_id)
  end

  describe 'resource configuration' do
    it 'has the correct resource type' do
      expect(described_class.resource_type).to eq('documents')
    end

    it 'has the correct endpoint' do
      expect(described_class.endpoint).to eq('/documents')
    end
  end

  describe '.create' do
    let(:created_document) do
      document_data(
        id: document_id,
        filename: 'contract.pdf',
        status: 'draft',
        envelope_id: envelope_id,
      )
    end

    before do
      stub_request(:post, documents_url)
        .to_return(
          status: 201,
          body: single_resource(created_document).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns a Document instance with the correct attributes', :aggregate_failures do
      doc = described_class.create(
        envelope_id: envelope_id,
        filename: 'contract.pdf',
        content_base64: docx_content_base64,
      )

      expect(doc).to be_a(described_class)
      expect(doc.id).to eq(document_id)
      expect(doc.filename).to eq('contract.pdf')
      expect(doc.envelope_id).to eq(envelope_id)
    end

    it 'posts to the correct nested URL' do
      described_class.create(
        envelope_id: envelope_id,
        filename: 'contract.pdf',
        content_base64: docx_content_base64,
      )
      expect(WebMock).to have_requested(:post, documents_url)
    end

    context 'with invalid attributes' do
      before do
        stub_request(:post, documents_url)
          .to_return(
            status: 422,
            body: { errors: [{ detail: 'filename is required' }] }.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'raises ValidationError' do
        expect do
          described_class.create(envelope_id: envelope_id)
        end.to raise_error(Clicksign::ValidationError)
      end
    end
  end

  describe '.list_events' do
    let(:event_id) { '55555555-5555-5555-5555-555555555555' }
    let(:events_url) { "#{document_url}/events" }
    let(:event) do
      event_data(id: event_id, name: 'sign', envelope_id: envelope_id,
        document_id: document_id)
    end

    before do
      stub_request(:get, events_url)
        .to_return(
          status: 200,
          body: collection_resource([event]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns Event instances for the document', :aggregate_failures do
      events = described_class.list_events(document_id, envelope_id: envelope_id)

      expect(events).to all(be_a(Clicksign::Resources::Notarial::Event))
      expect(events.first.name).to eq('sign')
    end

    it 'requests the correct nested URL' do
      described_class.list_events(document_id, envelope_id: envelope_id)
      expect(WebMock).to have_requested(:get, events_url)
    end
  end

  describe 'listed via Envelope' do
    subject(:documents) { Clicksign::Resources::Notarial::Envelope.list_documents(envelope_id) }

    before do
      stub_request(:get, documents_url)
        .to_return(
          status: 200,
          body: collection_resource([document]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it { is_expected.to be_an(Array) }
    it { is_expected.to all(be_a(described_class)) }

    it 'returns records with expected attributes', :aggregate_failures do
      expect(documents.first.id).to eq(document_id)
      expect(documents.first.filename).to eq('contract.pdf')
      expect(documents.first.status).to eq('draft')
    end

    it 'sets envelope_id so nested operations work' do
      expect(documents.first.envelope_id).to eq(envelope_id)
    end
  end

  describe '.retrieve' do
    before do
      stub_request(:get, document_url)
        .to_return(
          status: 200,
          body: single_resource(document).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns the document matching the given id' do
      retrieved = described_class.retrieve(document_id, envelope_id: envelope_id)
      expect(retrieved.id).to eq(document_id)
    end

    context 'when the document does not exist' do
      before do
        stub_request(:get, "#{documents_url}/00000000-0000-0000-0000-000000000000")
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

  describe 'metadata attribute' do
    let(:document_with_metadata) do
      document_data(
        id: document_id,
        filename: 'contract.pdf',
        status: 'draft',
        envelope_id: envelope_id,
        metadata: { 'order_id' => '123', 'customer' => 'ACME' },
      )
    end

    before do
      stub_request(:get, document_url)
        .to_return(
          status: 200,
          body: single_resource(document_with_metadata).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'exposes metadata as an attribute' do
      doc = described_class.retrieve(document_id, envelope_id: envelope_id)

      expect(doc.metadata).to eq('order_id' => '123', 'customer' => 'ACME')
    end
  end

  describe '#update' do
    let(:instance) do
      described_class.send(:build_instance, document, parent_id: envelope_id)
    end

    before do
      stub_request(:patch, document_url)
        .to_return(
          status: 200,
          body: single_resource(
            document_data(id: document_id, filename: 'updated.pdf',
              envelope_id: envelope_id),
          ).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'updates and returns the record', :aggregate_failures do
      updated = instance.update(filename: 'updated.pdf')
      expect(updated).to be_a(described_class)
      expect(updated.filename).to eq('updated.pdf')
    end
  end

  describe '#delete' do
    let(:instance) do
      described_class.send(:build_instance, document, parent_id: envelope_id)
    end

    before do
      stub_request(:delete, document_url).to_return(status: 204, body: '')
    end

    it 'deletes without raising' do
      expect { instance.delete }.not_to raise_error
    end
  end

  describe '#base_path guard' do
    context 'when envelope_id is unavailable (no parent_id, no relationship)' do
      let(:doc_no_envelope) do
        {
          'id' => document_id,
          'type' => 'documents',
          'attributes' => { 'filename' => 'test.pdf' },
          'relationships' => {},
        }
      end

      it 'raises Clicksign::Error on update instead of silently using nil in the URL' do
        instance = described_class.send(:build_instance, doc_no_envelope)
        expect { instance.update(filename: 'new.pdf') }
          .to raise_error(Clicksign::Error, /envelope_id is required/)
      end

      it 'raises Clicksign::Error on delete instead of silently using nil in the URL' do
        instance = described_class.send(:build_instance, doc_no_envelope)
        expect { instance.delete }
          .to raise_error(Clicksign::Error, /envelope_id is required/)
      end
    end
  end

  describe '#envelope_id' do
    context 'when built with parent_id' do
      let(:instance) do
        described_class.send(:build_instance, document, parent_id: envelope_id)
      end

      it 'returns the parent_id' do
        expect(instance.envelope_id).to eq(envelope_id)
      end
    end

    context 'when built without parent_id (relationship path)' do
      let(:instance) { described_class.send(:build_instance, document) }

      it 'returns the id from the envelope relationship' do
        expect(instance.envelope_id).to eq(envelope_id)
      end
    end
  end

  describe '#reload' do
    let(:instance) do
      described_class.send(:build_instance, document, parent_id: envelope_id)
    end

    before do
      stub_request(:get, document_url)
        .to_return(
          status: 200,
          body: single_resource(document).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'refreshes the record without raising' do
      expect { instance.reload }.not_to raise_error
    end

    it 'returns self and preserves envelope_id after reload', :aggregate_failures do
      reloaded = instance.reload
      expect(reloaded).to be_a(described_class)
      expect(reloaded.envelope_id).to eq(envelope_id)
    end
  end
end
