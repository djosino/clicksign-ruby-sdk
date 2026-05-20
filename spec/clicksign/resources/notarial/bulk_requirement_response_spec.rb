# frozen_string_literal: true

RSpec.describe Clicksign::Resources::Notarial::BulkRequirement::OperationResult do
  subject(:result) do
    described_class.new(
      index: 0,
      op: 'add',
      requirement: requirement,
      errors: errors,
      raw: { 'data' => {} },
    )
  end

  let(:requirement) do
    Clicksign::Resources::Notarial::Requirement.send(
      :build_instance,
      {
        'id' => '11111111-1111-1111-1111-111111111111',
        'type' => 'requirements',
        'attributes' => { 'action' => 'agree' },
        'relationships' => {},
      },
      parent_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    )
  end
  let(:errors) { nil }

  describe '#success?' do
    context 'when errors are nil' do
      it { is_expected.to be_success }
    end

    context 'when errors is an empty array' do
      let(:errors) { [] }

      it { is_expected.to be_success }
    end

    context 'when errors are present' do
      let(:errors) { [{ 'detail' => 'not found' }] }

      it { is_expected.not_to be_success }
    end
  end
end

RSpec.describe Clicksign::Resources::Notarial::BulkRequirement::Response do
  subject(:response) { described_class.new(envelope_id: envelope_id, results: results) }

  let(:envelope_id) { 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
  let(:success_result) do
    Clicksign::Resources::Notarial::BulkRequirement::OperationResult.new(
      index: 0,
      op: 'add',
      requirement: requirement,
      errors: nil,
      raw: {},
    )
  end
  let(:failure_result) do
    Clicksign::Resources::Notarial::BulkRequirement::OperationResult.new(
      index: 1,
      op: 'remove',
      requirement: nil,
      errors: [{ 'detail' => 'not found' }],
      raw: {},
    )
  end
  let(:requirement) do
    Clicksign::Resources::Notarial::Requirement.send(
      :build_instance,
      {
        'id' => 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        'type' => 'requirements',
        'attributes' => { 'action' => 'agree' },
        'relationships' => {},
      },
      parent_id: envelope_id,
    )
  end

  describe '#success?' do
    context 'when all results succeeded' do
      let(:results) { [success_result] }

      it { is_expected.to be_success }
    end

    context 'when any result failed' do
      let(:results) { [success_result, failure_result] }

      it { is_expected.not_to be_success }
    end
  end

  describe '#requirements' do
    let(:results) { [success_result, failure_result] }

    it 'returns only successful requirement instances' do
      expect(response.requirements).to eq([requirement])
    end
  end

  describe '#failures' do
    let(:results) { [success_result, failure_result] }

    it 'returns only failed operation results' do
      expect(response.failures).to eq([failure_result])
    end
  end

  describe '#envelope_id' do
    let(:results) { [] }

    it 'exposes the envelope id' do
      expect(response.envelope_id).to eq(envelope_id)
    end
  end
end
