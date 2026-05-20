# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

require_relative 'clicksign/version'
require_relative 'clicksign/configuration'
require_relative 'clicksign/errors'
require_relative 'clicksign/error_handler'
require_relative 'clicksign/webhook'
require_relative 'clicksign/json_api/query_builder'
require_relative 'clicksign/json_api/serializer'
require_relative 'clicksign/json_api/parser'
require_relative 'clicksign/json_api/operations'
require_relative 'clicksign/json_api/operations/bulk_requirement'
require_relative 'clicksign/json_api/atomic_results_parser'
require_relative 'clicksign/client'
require_relative 'clicksign/json_api/bulk_operations_client'
require_relative 'clicksign/resource'
require_relative 'clicksign/services'

Dir[File.join(__dir__, 'clicksign', 'resources', '**', '*.rb')].each do |file|
  require file
end

module Clicksign
  class << self
    # Must be called once at application startup, before any threads are spawned.
    # Module-level memoisation (@client, @configuration) is not thread-safe for
    # concurrent first-access; subsequent calls are safe once initialised.
    def configure
      yield configuration
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def client
      @client ||= Client.new(
        api_key: configuration.api_key,
        base_url: configuration.base_url,
        open_timeout: configuration.open_timeout,
        read_timeout: configuration.read_timeout,
        write_timeout: configuration.write_timeout,
        max_retries: configuration.max_retries,
      )
    end

    def bulk_operations_client
      @bulk_operations_client ||= JsonApi::BulkOperationsClient.new(
        api_key: configuration.api_key,
        base_url: configuration.base_url,
        open_timeout: configuration.open_timeout,
        read_timeout: configuration.read_timeout,
        write_timeout: configuration.write_timeout,
        max_retries: configuration.max_retries,
      )
    end

    def reset!
      @configuration = nil
      @client                  = nil
      @bulk_operations_client  = nil
    end
  end
end
