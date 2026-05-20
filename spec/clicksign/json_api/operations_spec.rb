# frozen_string_literal: true

RSpec.describe Clicksign::JsonApi::Operations do
  subject(:operations) { described_class.new }

  describe '#add' do
    it 'appends an add operation with stringified keys' do
      operations.add(
        data: {
          type: 'requirements',
          attributes: { action: :agree, role: 'party' },
        },
      )

      expect(operations.entries).to eq([
                                         {
                                           'op' => 'add',
                                           'data' => {
                                             'type' => 'requirements',
                                             'attributes' => { 'action' => 'agree',
                                                               'role' => 'party' },
                                           },
                                         },
                                       ])
    end

    it 'returns self for chaining' do
      expect(operations.add(data: { type: 'requirements',
                                    attributes: {} })).to be(operations)
    end

    it 'preserves operation order' do
      operations.add(data: { type: 'requirements', attributes: { action: 'agree' } })
      operations.add(data: { type: 'requirements', attributes: { action: 'rubricate' } })

      expect(operations.entries.map { |e| e.dig('data', 'attributes', 'action') })
        .to eq(%w[agree rubricate])
    end
  end

  describe '#remove' do
    it 'appends a remove operation with stringified ref' do
      operations.remove(ref: { type: 'requirements', id: 'uuid' })

      expect(operations.entries).to eq([
                                         { 'op' => 'remove',
                                           'ref' => { 'type' => 'requirements',
                                                      'id' => 'uuid' } },
                                       ])
    end

    it 'returns self for chaining' do
      expect(operations.remove(ref: { type: 'requirements', id: 'id' })).to be(operations)
    end
  end

  describe '#to_h' do
    context 'with no operations' do
      it 'returns an empty atomic:operations array' do
        expect(operations.to_h).to eq('atomic:operations' => [])
      end
    end

    context 'with add and remove operations' do
      before do
        operations.add(data: { type: 'requirements', attributes: {} })
        operations.remove(ref: { type: 'requirements', id: 'id' })
      end

      it 'wraps entries in atomic:operations' do
        expect(operations.to_h).to eq('atomic:operations' => operations.entries)
      end
    end
  end
end
