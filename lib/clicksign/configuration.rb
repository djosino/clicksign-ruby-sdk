# frozen_string_literal: true

module Clicksign
  class Configuration
    ENVIRONMENTS = {
      sandbox: 'https://sandbox.clicksign.com/api/v3',
      production: 'https://app.clicksign.com/api/v3',
    }.freeze

    attr_accessor :api_key, :base_url, :open_timeout, :read_timeout,
      :write_timeout, :max_retries, :logger

    def initialize
      @base_url      = 'https://app.clicksign.com/api/v3'
      @open_timeout  = 2
      @read_timeout  = 10
      @write_timeout = 10
      @max_retries   = 3
    end

    def environment=(env)
      url = ENVIRONMENTS.fetch(env.to_sym) do
        raise ArgumentError,
          "Unknown environment: #{env}. Valid: #{ENVIRONMENTS.keys.join(', ')}"
      end
      self.base_url = url
    end
  end
end
