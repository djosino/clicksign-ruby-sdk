# frozen_string_literal: true

module Clicksign
  module Resources
    class Membership < Clicksign::Resource
      self.resource_type = 'memberships'

      def self.create(role:, user_id:, **attributes)
        super(
          **attributes,
          role: role,
          relationships: { user: { data: { type: 'users', id: user_id } } }
        )
      end

      def user_id
        relationships.dig('user', 'data', 'id')
      end
    end
  end
end
