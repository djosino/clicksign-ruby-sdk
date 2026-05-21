# frozen_string_literal: true

RSpec.describe Clicksign::Webhook do
  let(:secret)          { 'my-webhook-secret' }
  let(:payload)         { '{"event":"sign","data":{}}' }
  let(:valid_signature) { described_class.compute_signature(payload, secret: secret) }

  describe '.compute_signature' do
    it 'returns a sha256= prefixed HMAC hex digest' do
      expect(valid_signature).to match(/\Asha256=[0-9a-f]{64}\z/)
    end

    it 'is deterministic for the same payload and secret' do
      expect(described_class.compute_signature(payload,
        secret: secret)).to eq(valid_signature)
    end

    it 'differs when the payload changes' do
      other = described_class.compute_signature('{"event":"close"}', secret: secret)
      expect(other).not_to eq(valid_signature)
    end

    it 'differs when the secret changes' do
      other = described_class.compute_signature(payload, secret: 'other-secret')
      expect(other).not_to eq(valid_signature)
    end
  end

  describe '.verify_signature!' do
    context 'with a valid signature' do
      it 'returns true' do
        expect(described_class.verify_signature!(payload, valid_signature,
          secret: secret)).to be(true)
      end
    end

    context 'with an invalid signature' do
      it 'raises WebhookSignatureError' do
        expect do
          described_class.verify_signature!(payload, 'sha256=invalid', secret: secret)
        end.to raise_error(Clicksign::WebhookSignatureError, /mismatch/)
      end
    end

    context 'with a tampered payload' do
      it 'raises WebhookSignatureError' do
        expect do
          described_class.verify_signature!('{"tampered":true}', valid_signature,
            secret: secret)
        end.to raise_error(Clicksign::WebhookSignatureError)
      end
    end

    context 'with a wrong secret' do
      it 'raises WebhookSignatureError' do
        expect do
          described_class.verify_signature!(payload, valid_signature,
            secret: 'wrong-secret')
        end.to raise_error(Clicksign::WebhookSignatureError)
      end
    end

    context 'with nil signature (missing header)' do
      it 'raises WebhookSignatureError instead of TypeError' do
        expect do
          described_class.verify_signature!(payload, nil, secret: secret)
        end.to raise_error(Clicksign::WebhookSignatureError)
      end
    end

    context 'with empty string signature' do
      it 'raises WebhookSignatureError' do
        expect do
          described_class.verify_signature!(payload, '', secret: secret)
        end.to raise_error(Clicksign::WebhookSignatureError)
      end
    end
  end

  describe '.verify_signature' do
    it 'returns true for a valid signature' do
      expect(described_class.verify_signature(payload, valid_signature,
        secret: secret)).to be(true)
    end

    it 'returns false for an invalid signature' do
      expect(described_class.verify_signature(payload, 'sha256=bad',
        secret: secret)).to be(false)
    end

    it 'returns false for a tampered payload' do
      expect(described_class.verify_signature('tampered', valid_signature,
        secret: secret)).to be(false)
    end

    it 'returns false for a wrong secret' do
      expect(described_class.verify_signature(payload, valid_signature,
        secret: 'wrong')).to be(false)
    end
  end
end
