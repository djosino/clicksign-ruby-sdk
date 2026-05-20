# frozen_string_literal: true

RSpec.describe Clicksign::Resources::EnvelopeBulkCreation do
  include_context 'with clicksign configured'

  let(:bulk_creations_url) { "#{JsonApiFixtures::BASE_URL}/envelope_bulk_creations" }
  let(:job_id) { 'ffffffff-ffff-ffff-ffff-ffffffffffff' }

  let(:bulk_creation_payload) do
    {
      data: {
        type: 'envelope_bulk_creations',
        attributes: {
          envelope: { name: 'Bulk Envelope' },
          document: { content_base64: JsonApiFixtures.docx_content_base64,
                      filename: 'contract.docx' },
          signers: [
            {
              name: 'Alice',
              email: 'alice@example.com',
              requirements: [{ action: 'agree', role: 'sign', auth: 'email' }],
            },
          ],
        },
      },
    }
  end

  it 'is defined with the correct resource type' do
    expect(described_class.resource_type).to eq('envelope_bulk_creations')
  end

  it 'has the correct endpoint' do
    expect(described_class.endpoint).to eq('/envelope_bulk_creations')
  end

  describe '.create' do
    let(:created) { envelope_bulk_creation_data(job_id: job_id) }

    before do
      stub_request(:post, bulk_creations_url)
        .to_return(
          status: 201,
          body: single_resource(created).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns an EnvelopeBulkCreation instance', :aggregate_failures do
      result = described_class.create(**bulk_creation_payload[:data][:attributes])

      expect(result).to be_a(described_class)
      expect(result.job_id).to eq(job_id)
      expect(result.enqueued_at).to eq('2026-01-01T00:00:00.000-03:00')
    end

    it 'posts to the correct URL' do
      described_class.create(**bulk_creation_payload[:data][:attributes])

      expect(WebMock).to have_requested(:post, bulk_creations_url)
    end

    context 'with invalid payload' do
      before do
        stub_request(:post, bulk_creations_url)
          .to_return(
            status: 422,
            body: { errors: [{ detail: 'signers is missing' }] }.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'raises ValidationError' do
        expect do
          described_class.create(envelope: { name: 'x' })
        end.to raise_error(Clicksign::ValidationError)
      end
    end
  end
end
