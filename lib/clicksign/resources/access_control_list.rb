# frozen_string_literal: true

module Clicksign
  module Resources
    class AccessControlList < Clicksign::Resource
      self.resource_type = 'access_control_lists'

      def self.create(folder_id:, group_id:)
        super(
          relationships: acl_relationships(folder_id: folder_id, group_id: group_id)
        )
      end

      def self.destroy(folder_id:, group_id:)
        client.delete(
          endpoint,
          body: JsonApi::Serializer.dump(
            type: resource_type,
            attributes: {},
            relationships: acl_relationships(folder_id: folder_id, group_id: group_id),
          ),
        )
        nil
      end

      def self.acl_relationships(folder_id:, group_id:)
        {
          folder: { data: { type: 'folders', id: folder_id } },
          group: { data: { type: 'groups', id: group_id } },
        }
      end
      private_class_method :acl_relationships
    end
  end
end
