# frozen_string_literal: true

module Clicksign
  module ErrorHandler
    ERROR_MAP = {
      [401, 403] => AuthenticationError,
      [404] => NotFoundError,
      [400, 422] => ValidationError,
      [409] => ConflictError,
      [429] => RateLimitError,
    }.freeze

    def self.call(response)
      return nil if (200..299).cover?(response.code.to_i)

      metadata   = extract_metadata(response)
      message    = extract_message(response)
      error_class = error_class_for(response.code.to_i)
      raise error_class.new(message, **metadata)
    end

    def self.error_class_for(code)
      ERROR_MAP.each { |codes, klass| return klass if codes.include?(code) }
      return ServerError if (500..599).cover?(code)

      Error
    end

    def self.extract_metadata(response)
      {
        status_code: response.code.to_i,
        request_id: response['x-request-id'],
        response_body: response.body,
        response_headers: response.each_header.to_h,
      }
    end

    def self.extract_message(response)
      body = JSON.parse(response.body)
      return response.message unless body.is_a?(Hash)

      errors = body['errors']
      return response.message if errors.nil? || !errors.is_a?(Array)

      errors.filter_map { |e| e['detail'] || e['title'] }.join(', ')
    rescue JSON::ParserError
      response.message
    end
  end
end
