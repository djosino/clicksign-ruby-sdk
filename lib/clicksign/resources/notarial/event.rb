# frozen_string_literal: true

module Clicksign
  module Resources
    module Notarial
      class Event < Clicksign::Resource
        self.resource_type = 'events'

        def self.create_for_document(envelope_id:, document_id:, **attributes)
          raw = client.post(
            "/envelopes/#{envelope_id}/documents/#{document_id}/events",
            body: JsonApi::Serializer.dump(type: resource_type, attributes: attributes),
          )
          parsed = JsonApi::Parser.parse(raw)
          build_instance(parsed[:data].first)
        end
      end
    end
  end
end
