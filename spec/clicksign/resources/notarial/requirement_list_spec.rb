# frozen_string_literal: true

RSpec.describe Clicksign::Resources::Notarial::Requirement do
  include_context 'with clicksign configured'

  let(:document_id) { '11111111-1111-1111-1111-111111111111' }
  let(:signer_id) { '22222222-2222-2222-2222-222222222222' }
  let(:envelope_id) { 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }

  let(:requirement) do
    requirement_data(
      id: '33333333-3333-3333-3333-333333333333',
      action: 'agree',
      role: 'sign',
      envelope_id: envelope_id,
      document_id: document_id,
      signer_id: signer_id,
    )
  end

  describe '.list_for_document' do
    subject(:requirements) { described_class.list_for_document(document_id) }

    let(:url) { "#{JsonApiFixtures::BASE_URL}/documents/#{document_id}/relationships/requirements" }

    before do
      stub_request(:get, url)
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

      expect(WebMock).to have_requested(:get, url)
    end

    it 'returns parsed requirements', :aggregate_failures do
      expect(requirements.first.id).to eq('33333333-3333-3333-3333-333333333333')
      expect(requirements.first.document_id).to eq(document_id)
      expect(requirements.first.signer_id).to eq(signer_id)
    end

    context 'with filters' do
      subject(:requirements) do
        described_class.list_for_document(document_id, 'requirement.action': 'agree')
      end

      before do
        stub_request(:get, url)
          .with(query: { 'filter[requirement.action]' => 'agree' })
          .to_return(
            status: 200,
            body: collection_resource([requirement]).to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'passes filter params to the API' do
        requirements

        expect(WebMock).to have_requested(:get, url)
          .with(query: { 'filter[requirement.action]' => 'agree' })
      end
    end
  end

  describe '.list_for_signer' do
    subject(:requirements) { described_class.list_for_signer(signer_id) }

    let(:url) { "#{JsonApiFixtures::BASE_URL}/signers/#{signer_id}/relationships/requirements" }

    before do
      stub_request(:get, url)
        .to_return(
          status: 200,
          body: collection_resource([requirement]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it { is_expected.to be_an(Array) }

    it 'requests the signer relationships endpoint' do
      requirements

      expect(WebMock).to have_requested(:get, url)
    end
  end
end
