# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module Clicksign
  class Client
    HEADERS = {
      'Content-Type' => 'application/vnd.api+json',
      'Accept' => 'application/vnd.api+json',
    }.freeze

    def initialize(api_key:, base_url:, open_timeout: 2, read_timeout: 10, # rubocop:disable Metrics/ParameterLists
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
        execute_once(request, uri)
      rescue Clicksign::TimeoutError, Clicksign::RateLimitError,
             Clicksign::ServerError => e
        raise unless e.retryable? && attempts <= @max_retries

        sleep(backoff_delay(attempts))
        retry
      end
    end

    def execute_once(request, uri)
      Net::HTTP.start(uri.host, uri.port,
                      use_ssl: uri.scheme == 'https',
                      open_timeout: @open_timeout,
                      read_timeout: @read_timeout,
                      write_timeout: @write_timeout) do |http|
        response = http.request(request)
        ErrorHandler.call(response)
        return nil if response.body.nil? || response.body.empty?

        JSON.parse(response.body)
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED => e
      raise TimeoutError, e.message, e.backtrace
    end

    def backoff_delay(attempt)
      [0.5 * (2**(attempt - 1)), 30].min
    end
  end
end
