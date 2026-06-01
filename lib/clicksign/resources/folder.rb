# frozen_string_literal: true

module Clicksign
  module Resources
    class Folder < Clicksign::Resource
      self.resource_type = 'folders'

      def self.create(name:, folder_id: nil)
        rels = folder_id ? { folder: { data: { type: 'folders', id: folder_id } } } : {}
        super(name: name, relationships: rels)
      end

      def folder_id
        relationships.dig('folder', 'data', 'id')
      end

      def child_folder_ids
        Array(relationships.dig('folders', 'data')).filter_map do |d|
          d.is_a?(Hash) ? d['id'] : nil
        end
      end
    end
  end
end
