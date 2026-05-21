# frozen_string_literal: true

module Clicksign
  module JsonApi
    module Parser
      def self.parse(raw)
        raw_data = raw['data']
        data = case raw_data
               when Array then raw_data.map { |item| build(item) }
               when Hash  then [build(raw_data)]
               else            []
               end

        included = Array(raw['included'])
                   .select { |item| item.is_a?(Hash) && item['type'] }
                   .map { |item| build(item) }

        links = raw['links'] if raw.key?('links')

        { data: data, included: included, links: links }
      end

      def self.build(item)
        {
          'id' => item['id'],
          'type' => item['type'],
          'attributes' => item.fetch('attributes', {}),
          'relationships' => item.fetch('relationships', {}),
        }
      end
    end
  end
end
