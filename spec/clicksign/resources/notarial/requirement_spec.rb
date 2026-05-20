# frozen_string_literal: true

RSpec.describe Clicksign::Resources::Notarial::Requirement do
  include_context 'with clicksign configured'

  let(:envelope_id) { 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
  let(:document_id) { '22222222-2222-2222-2222-222222222222' }
  let(:signer_id) { '33333333-3333-3333-3333-333333333333' }
  let(:requirement_id) { '55555555-5555-5555-5555-555555555555' }

  let(:requirements_url) { "#{JsonApiFixtures::BASE_URL}/envelopes/#{envelope_id}/requirements" }
  let(:requirement_url) { "#{requirements_url}/#{requirement_id}" }

  let(:requirement) do
    requirement_data(
      id: requirement_id,
      action: 'agree',
      role: 'sign',
      envelope_id: envelope_id,
      document_id: document_id,
      signer_id: signer_id,
    )
  end

  describe '.create and #delete' do
    before do
      stub_request(:post, requirements_url)
        .to_return(
          status: 201,
          body: single_resource(requirement).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
      stub_request(:delete, requirement_url).to_return(status: 204, body: '')
    end

    it 'creates and deletes a requirement without raising', :aggregate_failures do
      instance = described_class.create(
        envelope_id: envelope_id,
        action: 'agree',
        role: 'sign',
        relationships: {
          document: { data: { type: 'documents', id: document_id } },
          signer: { data: { type: 'signers', id: signer_id } },
        },
      )

      expect(instance).to be_a(described_class)
      expect(instance.action).to eq('agree')
      expect(instance.envelope_id).to eq(envelope_id)
      expect { instance.delete }.not_to raise_error
    end

    it 'posts document and signer relationships' do
      described_class.create(
        envelope_id: envelope_id,
        action: 'agree',
        role: 'sign',
        relationships: {
          document: { data: { type: 'documents', id: document_id } },
          signer: { data: { type: 'signers', id: signer_id } },
        },
      )

      expect(WebMock).to(have_requested(:post, requirements_url).with do |req|
        rels = JSON.parse(req.body).dig('data', 'relationships')
        rels.dig('document', 'data', 'id') == document_id &&
          rels.dig('signer', 'data', 'id') == signer_id
      end)
    end
  end

  describe '.create with rubric_field' do
    let(:rubricate_requirement) do
      requirement_data(
        id: requirement_id,
        action: 'rubricate',
        envelope_id: envelope_id,
        document_id: document_id,
        signer_id: signer_id,
        rubric_field: 'field_1',
        pages: 'all',
      )
    end

    before do
      stub_request(:post, requirements_url)
        .to_return(
          status: 201,
          body: single_resource(rubricate_requirement).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'creates a rubricate requirement and exposes rubric_field', :aggregate_failures do
      instance = described_class.create(
        envelope_id: envelope_id,
        action: 'rubricate',
        pages: 'all',
        rubric_field: 'field_1',
        relationships: {
          document: { data: { type: 'documents', id: document_id } },
          signer: { data: { type: 'signers', id: signer_id } },
        },
      )

      expect(instance.action).to eq('rubricate')
      expect(instance.rubric_field).to eq('field_1')
      expect(instance.pages).to eq('all')
    end

    it 'includes rubric_field in the request body' do
      described_class.create(
        envelope_id: envelope_id,
        action: 'rubricate',
        pages: 'all',
        rubric_field: 'field_1',
        relationships: {
          document: { data: { type: 'documents', id: document_id } },
          signer: { data: { type: 'signers', id: signer_id } },
        },
      )

      expect(WebMock).to(have_requested(:post, requirements_url).with do |req|
        attrs = JSON.parse(req.body).dig('data', 'attributes')
        attrs['rubric_field'] == 'field_1' && attrs['action'] == 'rubricate'
      end)
    end
  end

  describe '.retrieve' do
    before do
      stub_request(:get, requirement_url)
        .to_return(
          status: 200,
          body: single_resource(requirement).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns the requirement matching the given id' do
      retrieved = described_class.retrieve(requirement_id, envelope_id: envelope_id)
      expect(retrieved.id).to eq(requirement_id)
    end

    context 'when the requirement does not exist' do
      before do
        stub_request(:get, "#{requirements_url}/00000000-0000-0000-0000-000000000000")
          .to_return(
            status: 404,
            body: { errors: [{ detail: 'not found' }] }.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'raises NotFoundError for an unknown id' do
        expect do
          described_class.retrieve('00000000-0000-0000-0000-000000000000',
                                   envelope_id: envelope_id)
        end.to raise_error(Clicksign::NotFoundError)
      end
    end
  end

  describe '#envelope_id / #document_id / #signer_id' do
    let(:instance) { described_class.send(:build_instance, requirement) }

    it 'returns envelope_id from relationship' do
      expect(instance.envelope_id).to eq(envelope_id)
    end

    it 'returns document_id from relationship' do
      expect(instance.document_id).to eq(document_id)
    end

    it 'returns signer_id from relationship' do
      expect(instance.signer_id).to eq(signer_id)
    end

    context 'when built with parent_id' do
      let(:instance) do
        described_class.send(:build_instance, requirement, parent_id: envelope_id)
      end

      it 'prefers parent_id over relationship for envelope_id' do
        expect(instance.envelope_id).to eq(envelope_id)
      end
    end
  end

  describe '#update' do
    let(:instance) do
      described_class.send(:build_instance, requirement, parent_id: envelope_id)
    end

    before do
      stub_request(:patch, requirement_url)
        .to_return(
          status: 200,
          body: single_resource(
            requirement_data(id: requirement_id, action: 'provide_evidence',
                             envelope_id: envelope_id, document_id: document_id,
                             signer_id: signer_id),
          ).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'updates and returns the record', :aggregate_failures do
      updated = instance.update(action: 'provide_evidence')
      expect(updated).to be_a(described_class)
      expect(updated.action).to eq('provide_evidence')
    end
  end

  describe '#delete' do
    let(:instance) do
      described_class.send(:build_instance, requirement, parent_id: envelope_id)
    end

    before do
      stub_request(:delete, requirement_url).to_return(status: 204, body: '')
    end

    it 'deletes without raising' do
      expect { instance.delete }.not_to raise_error
    end
  end

  describe '.list_for_document' do
    subject(:requirements) { described_class.list_for_document(document_id) }

    let(:doc_requirements_url) do
      "#{JsonApiFixtures::BASE_URL}/documents/#{document_id}/relationships/requirements"
    end

    before do
      stub_request(:get, doc_requirements_url)
        .to_return(
          status: 200,
          body: collection_resource([requirement]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it { is_expected.to be_an(Array) }
    it { is_expected.to all(be_a(described_class)) }

    it 'requests the document relationships endpoint' do
      requirements
      expect(WebMock).to have_requested(:get, doc_requirements_url)
    end

    it 'returns parsed requirements', :aggregate_failures do
      expect(requirements.first.document_id).to eq(document_id)
      expect(requirements.first.signer_id).to eq(signer_id)
    end

    context 'with filters' do
      subject(:requirements) do
        described_class.list_for_document(document_id, 'requirement.action': 'agree')
      end

      before do
        stub_request(:get, doc_requirements_url)
          .with(query: { 'filter[requirement.action]' => 'agree' })
          .to_return(
            status: 200,
            body: collection_resource([requirement]).to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'passes filter params to the API' do
        requirements
        expect(WebMock).to have_requested(:get, doc_requirements_url)
          .with(query: { 'filter[requirement.action]' => 'agree' })
      end
    end
  end

  describe '.list_for_signer' do
    subject(:requirements) { described_class.list_for_signer(signer_id) }

    let(:signer_requirements_url) do
      "#{JsonApiFixtures::BASE_URL}/signers/#{signer_id}/relationships/requirements"
    end

    before do
      stub_request(:get, signer_requirements_url)
        .to_return(
          status: 200,
          body: collection_resource([requirement]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it { is_expected.to be_an(Array) }
    it { is_expected.to all(be_a(described_class)) }

    it 'requests the signer relationships endpoint' do
      requirements
      expect(WebMock).to have_requested(:get, signer_requirements_url)
    end
  end
end
