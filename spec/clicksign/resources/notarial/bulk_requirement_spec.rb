# frozen_string_literal: true

RSpec.describe Clicksign::Resources::Notarial::BulkRequirement do
  include_context 'with clicksign configured'

  let(:envelope_id) { 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
  let(:signer_id) { '11111111-1111-1111-1111-111111111111' }
  let(:document_id) { '22222222-2222-2222-2222-222222222222' }
  let(:requirement_id) { '33333333-3333-3333-3333-333333333333' }
  let(:bulk_url) { "#{JsonApiFixtures::BASE_URL}/envelopes/#{envelope_id}/bulk_requirements" }

  def stub_bulk_post(response_body:, status: 200)
    stub_request(:post, bulk_url)
      .to_return(
        status: status,
        body: response_body.to_json,
        headers: { 'Content-Type' => 'application/json' },
      )
  end

  describe '.create' do
    it 'raises ArgumentError when block is omitted' do
      expect { described_class.create(envelope_id: envelope_id) }
        .to raise_error(ArgumentError, 'block is required')
    end

    it 'raises ArgumentError when envelope_id is nil' do
      expect { described_class.create(envelope_id: nil) { |_| } }
        .to raise_error(ArgumentError, /envelope_id is required/)
    end

    it 'raises ArgumentError when envelope_id is empty string' do
      expect { described_class.create(envelope_id: '') { |_| } }
        .to raise_error(ArgumentError, /envelope_id is required/)
    end

    context 'with add_agree' do
      subject(:response) do
        described_class.create(envelope_id: envelope_id) do |ops|
          ops.add_agree(signer_id: signer_id, document_id: document_id, role: 'sign')
        end
      end

      let(:api_response) do
        {
          'atomic:results' => [
            { 'data' => requirement_data(id: requirement_id, action: 'agree',
              role: 'sign') },
          ],
        }
      end

      before { stub_bulk_post(response_body: api_response) }

      it 'returns a successful Response with the created requirement',
        :aggregate_failures do
        expect(response).to be_a(described_class::Response)
        expect(response.envelope_id).to eq(envelope_id)
        expect(response).to be_success
        expect(response.requirements.size).to eq(1)
        expect(response.requirements.first).to be_a(Clicksign::Resources::Notarial::Requirement)
        expect(response.requirements.first.id).to eq(requirement_id)
        expect(response.requirements.first.action).to eq('agree')
        expect(response.requirements.first.envelope_id).to eq(envelope_id)
        expect(response.results.first.op).to eq('add')
      end

      it 'posts atomic:operations with agree payload' do
        response

        expect(WebMock).to(have_requested(:post, bulk_url).with do |req|
          body = JSON.parse(req.body)
          op = body.fetch('atomic:operations').first

          op['op'] == 'add' &&
            op.dig('data', 'type') == 'requirements' &&
            op.dig('data', 'attributes') == { 'action' => 'agree', 'role' => 'sign' } &&
            op.dig('data', 'relationships', 'signer', 'data', 'id') == signer_id &&
            op.dig('data', 'relationships', 'document', 'data', 'id') == document_id
        end)
      end
    end

    context 'with add_provide_evidence' do
      subject(:response) do
        described_class.create(envelope_id: envelope_id) do |ops|
          ops.add_provide_evidence(signer_id: signer_id, document_id: document_id,
            auth: 'email')
        end
      end

      before do
        stub_bulk_post(
          response_body: {
            'atomic:results' => [
              { 'data' => requirement_data(id: requirement_id,
                action: 'provide_evidence', auth: 'email') },
            ],
          },
        )
      end

      it 'returns a provide_evidence requirement', :aggregate_failures do
        expect(response).to be_success
        expect(response.requirements.first.action).to eq('provide_evidence')
        expect(response.requirements.first.auth).to eq('email')
      end
    end

    context 'with add_rubricate' do
      subject(:response) do
        described_class.create(envelope_id: envelope_id) do |ops|
          ops.add_rubricate(signer_id: signer_id, document_id: document_id, pages: 'all',
            kind: 'initials')
        end
      end

      before do
        stub_bulk_post(
          response_body: {
            'atomic:results' => [
              {
                'data' => requirement_data(
                  id: requirement_id,
                  action: 'rubricate',
                  pages: 'all',
                  kind: 'initials',
                ),
              },
            ],
          },
        )
      end

      it 'returns a rubricate requirement', :aggregate_failures do
        expect(response).to be_success
        expect(response.requirements.first.action).to eq('rubricate')
        expect(response.requirements.first.pages).to eq('all')
        expect(response.requirements.first.kind).to eq('initials')
      end
    end

    context 'with multiple operations' do
      subject(:response) do
        described_class.create(envelope_id: envelope_id) do |ops|
          ops.add_agree(signer_id: signer_id, document_id: document_id, role: 'sign')
          ops.add_provide_evidence(signer_id: signer_id, document_id: document_id,
            auth: 'email')
        end
      end

      let(:second_requirement_id) { '44444444-4444-4444-4444-444444444444' }

      before do
        stub_bulk_post(
          response_body: {
            'atomic:results' => [
              { 'data' => requirement_data(id: requirement_id, action: 'agree',
                role: 'sign') },
              { 'data' => requirement_data(id: second_requirement_id,
                action: 'provide_evidence', auth: 'email') },
            ],
          },
        )
      end

      it 'returns one result per operation', :aggregate_failures do
        expect(response.results.size).to eq(2)
        expect(response.results.map(&:op)).to eq(%w[add add])
        expect(response.requirements.map(&:id)).to eq([requirement_id,
                                                       second_requirement_id])
      end

      it 'posts two add operations in order' do
        response

        expect(WebMock).to(have_requested(:post, bulk_url).with do |req|
          ops = JSON.parse(req.body).fetch('atomic:operations')
          ops.size == 2 && ops.all? { |op| op['op'] == 'add' }
        end)
      end
    end

    context 'with remove' do
      subject(:remove_response) do
        described_class.create(envelope_id: envelope_id) do |ops|
          ops.remove(requirement_id: requirement_id)
        end
      end

      before do
        stub_bulk_post(response_body: { 'atomic:results' => [{ 'data' => {} }] })
      end

      it 'returns a successful remove result', :aggregate_failures do
        expect(remove_response).to be_success
        expect(remove_response.results.size).to eq(1)
        expect(remove_response.results.first.op).to eq('remove')
        expect(remove_response.results.first.requirement).to be_nil
        expect(remove_response.requirements).to be_empty
      end

      it 'posts a remove operation with ref' do
        remove_response

        expect(WebMock).to(have_requested(:post, bulk_url).with do |req|
          op = JSON.parse(req.body).fetch('atomic:operations').first

          op == {
            'op' => 'remove',
            'ref' => { 'type' => 'requirements', 'id' => requirement_id },
          }
        end)
      end
    end

    context 'when an operation fails in atomic:results' do
      subject(:response) do
        described_class.create(envelope_id: envelope_id) do |ops|
          ops.remove(requirement_id: requirement_id)
        end
      end

      before do
        stub_bulk_post(
          response_body: {
            'atomic:results' => [
              { 'errors' => [{ 'detail' => 'not found', 'status' => '404' }] },
            ],
          },
          status: 404,
        )
      end

      it 'returns a failed result without raising', :aggregate_failures do
        expect(response).not_to be_success
        expect(response.failures.size).to eq(1)
        expect(response.failures.first.errors.first['detail']).to eq('not found')
      end
    end

    context 'when the envelope validation fails' do
      it 'raises ValidationError for top-level errors' do
        stub_bulk_post(
          response_body: { 'errors' => [{ 'detail' => 'envelope invalid' }] },
          status: 422,
        )

        expect do
          described_class.create(envelope_id: envelope_id) do |ops|
            ops.add_agree(signer_id: signer_id, document_id: document_id, role: 'sign')
          end
        end.to raise_error(Clicksign::ValidationError, 'envelope invalid')
      end
    end
  end
end
