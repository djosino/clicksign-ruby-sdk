# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module Clicksign
  module JsonApi
    class BulkOperationsClient
      include RequestInstrumentation

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
        uri     = build_uri(path)
        request = build_request(uri, body)
        execute_with_retry(request, uri)
      end

      private

      def build_request(uri, body)
        request = Net::HTTP::Post.new(uri, headers)
        request.body = body.to_json
        request
      end

      def execute_with_retry(request, uri)
        attempts = 0
        begin
          attempts += 1
          execute_once(request, uri, attempt: attempts)
        rescue Clicksign::TimeoutError => e
          raise unless e.retryable? && attempts <= @max_retries

          delay = RetryBackoff.delay(attempts)
          publish_retry(request, uri, attempts, e, delay)
          sleep(delay)
          retry
        end
      end

      def execute_once(request, uri, attempt: 1)
        start   = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        context = request_context(request, uri, attempt)
        response = http_post(request, uri)
        _response, status, duration = publish_http_outcome(response, context, start)
        handle_bulk_body(response, context, status, duration)
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED => e
        handle_network_error(e, context, start)
      end

      def handle_bulk_body(response, context, status, duration)
        parsed = parse_response_body(response) || {}
        return parsed if parsed.key?('atomic:results')

        begin
          ErrorHandler.call(response)
        rescue Error => e
          publish_http_error(context, e, status, duration)
          raise
        end
        parsed
      end

      def http_post(request, uri)
        Net::HTTP.start(uri.host, uri.port,
          use_ssl: uri.scheme == 'https',
          open_timeout: @open_timeout,
          read_timeout: @read_timeout,
          write_timeout: @write_timeout,
          &proc { |http| http.request(request) })
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
      rescue JSON::ParserError => e
        raise Error, "Invalid JSON response from bulk operations endpoint: #{e.message}"
      end
    end
  end
end
