# frozen_string_literal: true

module Clicksign
  module JsonApi
    module Serializer
      def self.dump(type:, attributes:, id: nil, relationships: {})
        data = { type: type, attributes: attributes }
        data[:id] = id if id
        data[:relationships] = relationships unless relationships.empty?
        { data: data }
      end
    end
  end
end
