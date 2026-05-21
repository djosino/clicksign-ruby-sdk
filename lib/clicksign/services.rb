# frozen_string_literal: true

module Clicksign
  class Services
    def initialize(api_key:, environment: :production, base_url: nil,
      open_timeout: 2, read_timeout: 10, write_timeout: 10, max_retries: 0)
      resolved_url = base_url || resolve_environment(environment)
      @client = Client.new(
        api_key: api_key,
        base_url: resolved_url,
        open_timeout: open_timeout,
        read_timeout: read_timeout,
        write_timeout: write_timeout,
        max_retries: max_retries,
      )
    end

    def use
      previous = Thread.current[:clicksign_client]
      Thread.current[:clicksign_client] = @client
      yield
    ensure
      Thread.current[:clicksign_client] = previous
    end

    private

    def resolve_environment(env)
      Configuration::ENVIRONMENTS.fetch(env.to_sym) do
        valid = Configuration::ENVIRONMENTS.keys.join(', ')
        raise ArgumentError, "Unknown environment: #{env}. Valid: #{valid}"
      end
    end
  end
end
