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

      def update(**attributes)
        raw = self.class.client.put(
          "#{base_path}/#{@id}",
          body: JsonApi::Serializer.dump(
            type: self.class.resource_type, id: @id, attributes: attributes,
          ),
        )
        parsed = JsonApi::Parser.parse(raw)
        data   = parsed[:data].first
        raise NotFoundError, 'API returned null data' if data.nil?

        load_data(data, parent_id: @_parent_id)
        self
      end

      def user_id
        relationships.dig('user', 'data', 'id')
      end
    end
  end
end
