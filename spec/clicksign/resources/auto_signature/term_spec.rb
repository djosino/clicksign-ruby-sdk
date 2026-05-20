# frozen_string_literal: true

RSpec.describe Clicksign::Resources::AutoSignature::Term do
  include_context 'with clicksign configured'

  let(:terms_url) { "#{JsonApiFixtures::BASE_URL}/auto_signature/terms" }
  let(:signer_id) { '11111111-1111-1111-1111-111111111111' }
  let(:term_id)   { 'tttttttt-tttt-tttt-tttt-tttttttttttt' }

  it 'has the correct resource type' do
    expect(described_class.resource_type).to eq('auto_signature_terms')
  end

  it 'has the correct endpoint' do
    expect(described_class.endpoint).to eq('/auto_signature/terms')
  end

  describe '.create' do
    let(:created_term) do
      {
        'id' => term_id,
        'type' => 'auto_signature_terms',
        'attributes' => {
          'created' => '2026-01-01T00:00:00.000-03:00',
          'modified' => '2026-01-01T00:00:00.000-03:00',
        },
        'relationships' => {
          'signer' => { 'data' => { 'type' => 'signers', 'id' => signer_id } },
        },
      }
    end

    before do
      stub_request(:post, terms_url)
        .to_return(
          status: 201,
          body: single_resource(created_term).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns a Term instance', :aggregate_failures do
      term = described_class.create(signer_id: signer_id)

      expect(term).to be_a(described_class)
      expect(term.id).to eq(term_id)
    end

    it 'posts to the correct URL' do
      described_class.create(signer_id: signer_id)
      expect(WebMock).to have_requested(:post, terms_url)
    end

    context 'when the signer does not accept the term' do
      before do
        stub_request(:post, terms_url)
          .to_return(
            status: 422,
            body: { errors: [{ detail: 'signer not eligible' }] }.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'raises ValidationError' do
        expect do
          described_class.create(signer_id: 'invalid')
        end.to raise_error(Clicksign::ValidationError)
      end
    end
  end
end
