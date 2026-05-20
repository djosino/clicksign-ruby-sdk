# frozen_string_literal: true

require 'openssl'

module Clicksign
  module Webhook
    DIGEST = 'sha256'

    # Raises WebhookSignatureError if the Content-HMAC header does not match.
    def self.verify_signature!(payload, signature, secret:) # rubocop:disable Naming/PredicateMethod
      expected = compute_signature(payload, secret: secret)
      unless secure_compare(expected, signature)
        raise WebhookSignatureError, 'Webhook signature mismatch'
      end

      true
    end

    # Returns true/false instead of raising.
    def self.verify_signature(payload, signature, secret:)
      verify_signature!(payload, signature, secret: secret)
    rescue WebhookSignatureError
      false
    end

    # Computes the expected Content-HMAC value for a given payload and secret.
    def self.compute_signature(payload, secret:)
      "#{DIGEST}=#{OpenSSL::HMAC.hexdigest(DIGEST, secret, payload)}"
    end

    # Constant-time comparison to prevent timing attacks.
    def self.secure_compare(str_a, str_b) # rubocop:disable Naming/PredicateMethod
      digest_a = OpenSSL::Digest::SHA256.hexdigest(str_a)
      digest_b = OpenSSL::Digest::SHA256.hexdigest(str_b)
      result = 0
      digest_a.bytes.zip(digest_b.bytes) { |x, y| result |= x ^ y }
      result.zero?
    end
    private_class_method :secure_compare
  end
end
