# frozen_string_literal: true

RSpec.describe Clicksign::JsonApi::Operations::BulkRequirement do
  subject(:ops) { described_class.new }

  let(:signer_id) { '11111111-1111-1111-1111-111111111111' }
  let(:document_id) { '22222222-2222-2222-2222-222222222222' }
  let(:requirement_id) { '33333333-3333-3333-3333-333333333333' }

  describe '#add_agree' do
    it 'builds an add operation with agree attributes' do
      ops.add_agree(signer_id: signer_id, document_id: document_id, role: :party)

      expect(ops.entries.last).to eq(
        'op' => 'add',
        'data' => {
          'type' => 'requirements',
          'attributes' => { 'action' => 'agree', 'role' => 'party' },
          'relationships' => {
            'signer' => { 'data' => { 'type' => 'signers', 'id' => signer_id } },
            'document' => { 'data' => { 'type' => 'documents', 'id' => document_id } },
          },
        },
      )
    end

    it 'returns self for chaining' do
      expect(ops.add_agree(signer_id: signer_id, document_id: document_id,
        role: 'sign')).to be(ops)
    end

    context 'with missing signer_id' do
      it 'raises ArgumentError' do
        expect do
          ops.add_agree(signer_id: '', document_id: document_id, role: 'sign')
        end.to raise_error(ArgumentError, 'signer_id is required')
      end
    end

    context 'with missing role' do
      it 'raises ArgumentError' do
        expect do
          ops.add_agree(signer_id: signer_id, document_id: document_id, role: '')
        end.to raise_error(ArgumentError, 'role is required')
      end
    end
  end

  describe '#add_provide_evidence' do
    it 'builds an add operation with auth' do
      ops.add_provide_evidence(signer_id: signer_id, document_id: document_id,
        auth: 'email')

      expect(ops.entries.last['data']['attributes']).to eq(
        'action' => 'provide_evidence',
        'auth' => 'email',
      )
    end

    context 'with missing auth' do
      it 'raises ArgumentError' do
        expect do
          ops.add_provide_evidence(signer_id: signer_id, document_id: document_id,
            auth: '')
        end.to raise_error(ArgumentError, 'auth is required')
      end
    end
  end

  describe '#add_rubricate' do
    context 'with pages' do
      it 'builds an add operation with pages attribute' do
        ops.add_rubricate(signer_id: signer_id, document_id: document_id, pages: 'all')

        expect(ops.entries.last['data']['attributes']).to eq(
          'action' => 'rubricate',
          'pages' => 'all',
        )
      end
    end

    context 'with rubric_field and kind' do
      it 'builds an add operation with rubric_field and kind' do
        ops.add_rubricate(
          signer_id: signer_id,
          document_id: document_id,
          rubric_field: 'positioned_sign_signer',
          kind: 'initials',
        )

        expect(ops.entries.last['data']['attributes']).to eq(
          'action' => 'rubricate',
          'rubric_field' => 'positioned_sign_signer',
          'kind' => 'initials',
        )
      end
    end

    context 'without pages or rubric_field' do
      it 'raises ArgumentError' do
        expect do
          ops.add_rubricate(signer_id: signer_id, document_id: document_id)
        end.to raise_error(ArgumentError, 'pages or rubric_field is required')
      end
    end

    context 'with invalid kind' do
      it 'raises ArgumentError' do
        expect do
          ops.add_rubricate(
            signer_id: signer_id,
            document_id: document_id,
            pages: 'all',
            kind: 'invalid',
          )
        end.to raise_error(ArgumentError, /kind must be one of/)
      end
    end
  end

  describe '#remove' do
    it 'builds a remove operation with ref' do
      ops.remove(requirement_id: requirement_id)

      expect(ops.entries.last).to eq(
        'op' => 'remove',
        'ref' => { 'type' => 'requirements', 'id' => requirement_id },
      )
    end

    context 'with missing requirement_id' do
      it 'raises ArgumentError' do
        expect { ops.remove(requirement_id: '') }
          .to raise_error(ArgumentError, 'requirement_id is required')
      end
    end
  end

  describe 'chained operations' do
    it 'builds multiple operations in order' do
      ops
        .add_agree(signer_id: signer_id, document_id: document_id, role: 'sign')
        .add_provide_evidence(
          signer_id: signer_id, document_id: document_id, auth: 'email',
        )
        .add_rubricate(signer_id: signer_id, document_id: document_id, pages: '1')
        .remove(requirement_id: requirement_id)

      aggregate_failures do
        expect(ops.entries.size).to eq(4)
        expect(ops.entries.map { |e| e['op'] }).to eq(%w[add add add remove])
        expect(ops.to_h).to have_key('atomic:operations')
      end
    end
  end
end
