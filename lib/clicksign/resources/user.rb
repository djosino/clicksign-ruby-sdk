# frozen_string_literal: true

module Clicksign
  module Resources
    class User < Clicksign::Resource
      self.resource_type = 'users'

      def self.me
        raw    = client.get('/users/me')
        parsed = JsonApi::Parser.parse(raw)
        build_instance(parsed[:data].first)
      end
    end
  end
end
