# frozen_string_literal: true

require 'openssl'

module Clicksign
  module Webhook
    DIGEST = 'sha256'

    # Raises WebhookSignatureError if the Content-HMAC header does not match.
    def self.verify_signature!(payload, signature, secret:)
      expected = compute_signature(payload, secret: secret)
      raise WebhookSignatureError, 'Webhook signature mismatch' unless secure_compare?(
        expected, signature
      )

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
      raise ArgumentError, 'secret must not be empty' if secret.nil? || secret.empty?

      "#{DIGEST}=#{OpenSSL::HMAC.hexdigest(DIGEST, secret, payload)}"
    end

    # Constant-time comparison to prevent timing attacks.
    def self.secure_compare?(expected, actual)
      return false if actual.nil?

      actual_str = actual.is_a?(String) ? actual : actual.to_s
      return false if actual_str.empty?

      OpenSSL.fixed_length_secure_compare(expected, actual_str)
    rescue ArgumentError
      false
    end
    private_class_method :secure_compare?
  end
end
