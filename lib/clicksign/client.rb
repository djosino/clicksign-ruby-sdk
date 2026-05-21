# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module Clicksign
  class Client
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

    def get(path, params: {})
      uri = build_uri(path, params)
      execute_with_retry(Net::HTTP::Get.new(uri, headers), uri)
    end

    def post(path, body:)
      uri = build_uri(path)
      request = Net::HTTP::Post.new(uri, headers)
      request.body = body.to_json
      execute_with_retry(request, uri)
    end

    def patch(path, body:)
      uri = build_uri(path)
      request = Net::HTTP::Patch.new(uri, headers)
      request.body = body.to_json
      execute_with_retry(request, uri)
    end

    def delete(path, body: nil)
      uri = build_uri(path)
      request = Net::HTTP::Delete.new(uri, headers)
      request.body = body.to_json if body
      execute_with_retry(request, uri)
    end

    private

    def headers
      HEADERS.merge('Authorization' => @api_key)
    end

    def build_uri(path, params = {})
      uri = URI.parse("#{@base_url}#{path}")
      uri.query = URI.encode_www_form(params) unless params.empty?
      uri
    end

    def execute_with_retry(request, uri)
      attempts = 0
      begin
        attempts += 1
        execute_once(request, uri, attempt: attempts)
      rescue Clicksign::TimeoutError, Clicksign::RateLimitError,
             Clicksign::ServerError => e
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
      response = http_request(request, uri)
      handle_response(response, context, start)
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED => e
      handle_network_error(e, context, elapsed_ms(start))
    end

    def http_request(request, uri)
      Net::HTTP.start(uri.host, uri.port,
        use_ssl: uri.scheme == 'https',
        open_timeout: @open_timeout,
        read_timeout: @read_timeout,
        write_timeout: @write_timeout,
        &proc { |http| http.request(request) })
    end

    def handle_response(response, context, start)
      _response, status, duration = publish_http_outcome(response, context, start)
      begin
        ErrorHandler.call(response)
      rescue Error => e
        publish_http_error(context, e, status, duration)
        raise
      end
      return nil if response.body.nil? || response.body.empty?

      JSON.parse(response.body)
    end
  end
end
