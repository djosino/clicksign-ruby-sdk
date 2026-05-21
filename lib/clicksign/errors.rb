# frozen_string_literal: true

module Clicksign
  class Error < StandardError
    attr_reader :status_code, :request_id, :response_body, :response_headers

    def initialize(message = nil, status_code: nil, request_id: nil,
      response_body: nil, response_headers: {})
      super(message)
      @status_code      = status_code
      @request_id       = request_id
      @response_body    = response_body
      @response_headers = response_headers || {}
    end

    def retryable?
      false
    end
  end

  class AuthenticationError < Error; end
  class NotFoundError        < Error; end
  class ValidationError      < Error; end
  class ConflictError        < Error; end

  class RateLimitError < Error
    def retryable?
      true
    end

    def rate_limit_remaining
      response_headers['x-ratelimit-remaining']&.to_i
    end

    def rate_limit_reset
      response_headers['x-ratelimit-reset']
    end
  end

  class ServerError < Error
    def retryable?
      true
    end
  end

  class TimeoutError < Error
    def retryable?
      true
    end
  end

  class WebhookSignatureError < Error; end
end
