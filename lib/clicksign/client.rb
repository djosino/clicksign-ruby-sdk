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
        execute_once(request, uri, attempt: attempts)
      rescue Clicksign::TimeoutError, Clicksign::RateLimitError,
             Clicksign::ServerError => e
        raise unless e.retryable? && attempts <= @max_retries

        delay = backoff_delay(attempts)
        Instrumentation.publish(:retry, {
                                  method: request.method.downcase.to_sym,
                                  path: resource_path(uri),
                                  attempt: attempts,
                                  max_retries: @max_retries,
                                  error: e,
                                  wait_ms: (delay * 1000).round,
                                })
        sleep(delay)
        retry
      end
    end

    def execute_once(request, uri, attempt: 1) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
      start  = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      method = request.method.downcase.to_sym
      path   = resource_path(uri)

      response = Net::HTTP.start(uri.host, uri.port,
                                 use_ssl: uri.scheme == 'https',
                                 open_timeout: @open_timeout,
                                 read_timeout: @read_timeout,
                                 write_timeout: @write_timeout,
                                 &proc { |http| http.request(request) })
      duration = elapsed_ms(start)

      begin
        ErrorHandler.call(response)
      rescue Error => e
        Instrumentation.publish(:request,
                                request_payload(method, path, response.code.to_i,
                                                duration, attempt))
        Instrumentation.publish(:error,
                                error_payload(method, path, e, response.code.to_i,
                                              duration, attempt))
        raise
      end

      Instrumentation.publish(:request,
                              request_payload(method, path, response.code.to_i, duration,
                                              attempt))
      return nil if response.body.nil? || response.body.empty?

      JSON.parse(response.body)
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED => e
      duration = elapsed_ms(start)
      err = TimeoutError.new(e.message)
      Instrumentation.publish(:error,
                              error_payload(method, path, err, nil, duration, attempt))
      raise err, e.message, e.backtrace
    end

    def request_payload(method, path, status, duration_ms, attempt)
      { method: method, path: path, status: status, duration_ms: duration_ms,
        attempt: attempt }
    end

    def error_payload(method, path, error, status, duration_ms, attempt) # rubocop:disable Metrics/ParameterLists
      { method: method, path: path, error: error, status: status,
        duration_ms: duration_ms, attempt: attempt }
    end

    def elapsed_ms(start)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(1)
    end

    def resource_path(uri)
      base = URI.parse(@base_url).path
      uri.path.delete_prefix(base)
    end

    def backoff_delay(attempt)
      [0.5 * (2**(attempt - 1)), 30].min
    end
  end
end
