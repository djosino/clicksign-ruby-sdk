# frozen_string_literal: true

RSpec.describe Clicksign::JsonApi::AtomicResultsParser do
  let(:envelope_id) { 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }

  describe '.envelope_errors?' do
    it 'returns true when errors are present without atomic:results' do
      raw = { 'errors' => [{ 'detail' => 'envelope invalid' }] }

      expect(described_class.envelope_errors?(raw)).to be(true)
    end

    it 'returns false when atomic:results is present' do
      raw = { 'atomic:results' => [], 'errors' => [{ 'detail' => 'ignored' }] }

      expect(described_class.envelope_errors?(raw)).to be(false)
    end
  end

  describe '.format_errors' do
    it 'joins detail messages' do
      errors = [{ 'detail' => 'first' }, { 'title' => 'second' }]

      expect(described_class.format_errors(errors)).to eq('first, second')
    end

    it 'returns a default message for nil errors' do
      expect(described_class.format_errors(nil)).to eq('Validation failed')
    end

    it 'returns a default message when errors is not an Array' do
      expect(described_class.format_errors('detail' => 'x')).to eq('Validation failed')
    end
  end

  describe '.parse' do
    let(:operations) do
      [
        { 'op' => 'add' },
        { 'op' => 'remove' },
      ]
    end

    context 'with successful add and remove slots' do
      subject(:results) do
        described_class.parse(raw, envelope_id: envelope_id, operations: operations)
      end

      let(:raw) do
        {
          'atomic:results' => [
            {
              'data' => {
                'type' => 'requirements',
                'id' => 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
                'attributes' => { 'action' => 'agree', 'role' => 'sign' },
                'relationships' => {},
              },
            },
            { 'data' => {} },
          ],
        }
      end

      it { is_expected.to all(be_a(Clicksign::Resources::Notarial::BulkRequirement::OperationResult)) }

      it 'maps slots to OperationResult objects', :aggregate_failures do
        expect(results.size).to eq(2)
        expect(results[0]).to be_success
        expect(results[0].index).to eq(0)
        expect(results[0].op).to eq('add')
        expect(results[0].requirement).to be_a(Clicksign::Resources::Notarial::Requirement)
        expect(results[0].requirement.id).to eq('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')
        expect(results[0].requirement.action).to eq('agree')
        expect(results[0].requirement.envelope_id).to eq(envelope_id)
        expect(results[1]).to be_success
        expect(results[1].op).to eq('remove')
        expect(results[1].requirement).to be_nil
      end
    end

    context 'with a slot containing errors' do
      subject(:result) do
        described_class.parse(raw, envelope_id: envelope_id,
          operations: [{ 'op' => 'remove' }]).first
      end

      let(:raw) do
        {
          'atomic:results' => [
            { 'errors' => [{ 'detail' => 'not found', 'status' => '404' }] },
          ],
        }
      end

      it { is_expected.not_to be_success }

      it 'preserves errors and raw slot' do
        aggregate_failures do
          expect(result.errors).to eq([{ 'detail' => 'not found', 'status' => '404' }])
          expect(result.raw).to eq(raw['atomic:results'].first)
        end
      end
    end

    context 'with top-level errors only' do
      let(:raw) { { 'errors' => [{ 'detail' => 'envelope invalid' }] } }

      it 'raises ValidationError' do
        expect do
          described_class.parse(raw, envelope_id: envelope_id, operations: [])
        end.to raise_error(Clicksign::ValidationError, 'envelope invalid')
      end
    end

    context 'with empty atomic:results' do
      it 'returns an empty array' do
        raw = { 'atomic:results' => [] }

        results = described_class.parse(raw, envelope_id: envelope_id, operations: [])

        expect(results).to eq([])
      end
    end
  end
end
