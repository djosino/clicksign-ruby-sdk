# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module Clicksign
  module JsonApi
    class BulkOperationsClient
      HEADERS = {
        'Content-Type' => 'application/vnd.api+json',
        'Accept' => 'application/vnd.api+json',
      }.freeze

      def initialize(api_key:, base_url:, open_timeout: 2, read_timeout: 10,
                     write_timeout: 10, max_retries: 0)
        @api_key       = api_key
        @base_url      = base_url
        @open_timeout  = open_timeout
        @read_timeout  = read_timeout
        @write_timeout = write_timeout
        @max_retries   = max_retries
      end

      def post(path, body:)
        response = perform_post(path, body)
        parsed = parse_response_body(response) || {}

        return parsed if parsed.key?('atomic:results')

        ErrorHandler.call(response)
        parsed
      end

      private

      def perform_post(path, body)
        uri     = build_uri(path)
        request = build_request(uri, body)
        execute_with_retry(request, uri)
      end

      def build_request(uri, body)
        request = Net::HTTP::Post.new(uri, headers)
        request.body = body.to_json
        request
      end

      def execute_with_retry(request, uri)
        attempts = 0
        begin
          attempts += 1
          safe_http_post(request, uri)
        rescue Clicksign::TimeoutError => e
          raise unless e.retryable? && attempts <= @max_retries

          sleep(Clicksign::RetryBackoff.delay(attempts))
          retry
        end
      end

      def safe_http_post(request, uri)
        http_post(request, uri)
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED => e
        raise TimeoutError, e.message, e.backtrace
      end

      def http_post(request, uri)
        Net::HTTP.start(uri.host, uri.port,
                        use_ssl: uri.scheme == 'https',
                        open_timeout: @open_timeout,
                        read_timeout: @read_timeout,
                        write_timeout: @write_timeout) do |http|
          http.request(request)
        end
      end

      def headers
        HEADERS.merge('Authorization' => @api_key)
      end

      def build_uri(path)
        URI.parse("#{@base_url}#{path}")
      end

      def parse_response_body(response)
        return nil if response.body.nil? || response.body.empty?

        JSON.parse(response.body)
      rescue JSON::ParserError
        nil
      end
    end
  end
end
