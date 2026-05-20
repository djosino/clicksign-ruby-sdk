# frozen_string_literal: true

RSpec.describe Clicksign::JsonApi::Serializer do
  describe '.dump' do
    context 'without id or relationships (create)' do
      it 'produces a JSON:API create body', :aggregate_failures do
        result = described_class.dump(
          type: 'envelopes',
          attributes: { name: 'Contract', locale: 'pt-BR' },
        )

        expect(result).to eq(
          { data: { type: 'envelopes',
                    attributes: { name: 'Contract', locale: 'pt-BR' } } },
        )
        expect(result[:data]).not_to have_key(:id)
        expect(result[:data]).not_to have_key(:relationships)
      end
    end

    context 'with id (update / PATCH)' do
      it 'includes the id in the payload' do
        result = described_class.dump(
          type: 'envelopes',
          id: 'aaa-111',
          attributes: { name: 'Updated' },
        )

        expect(result[:data][:id]).to eq('aaa-111')
      end
    end

    context 'with relationships' do
      it 'includes relationships in the payload' do
        rels = { folder: { data: { type: 'folders', id: 'f-1' } } }
        result = described_class.dump(
          type: 'envelopes',
          attributes: { name: 'Envelope' },
          relationships: rels,
        )

        expect(result[:data][:relationships]).to eq(rels)
      end
    end

    context 'with empty relationships' do
      it 'omits the relationships key' do
        result = described_class.dump(
          type: 'signers',
          attributes: { name: 'Alice' },
          relationships: {},
        )

        expect(result[:data]).not_to have_key(:relationships)
      end
    end

    context 'with empty attributes' do
      it 'still produces a valid body' do
        result = described_class.dump(type: 'events', attributes: {})

        expect(result).to eq({ data: { type: 'events', attributes: {} } })
      end
    end

    context 'with nil attributes' do
      it 'passes nil through to the payload' do
        result = described_class.dump(type: 'events', attributes: nil)

        expect(result[:data][:attributes]).to be_nil
      end
    end
  end
end
