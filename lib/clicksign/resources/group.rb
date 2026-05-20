# frozen_string_literal: true

module Clicksign
  module Resources
    class Group < Clicksign::Resource
      self.resource_type = 'groups'

      def self.add_users(group_id, user_ids)
        data = Array(user_ids).map { |id| { type: 'users', id: id } }
        client.post("/groups/#{group_id}/relationships/users", body: { data: data })
        nil
      end

      def self.remove_users(group_id, user_ids)
        data = Array(user_ids).map { |id| { type: 'users', id: id } }
        client.delete("/groups/#{group_id}/relationships/users", body: { data: data })
        nil
      end
    end
  end
end
