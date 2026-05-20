# frozen_string_literal: true

module Clicksign
  module Resources
    module Notarial
      class Document < Clicksign::Resource
        self.resource_type = 'documents'

        def self.retrieve(id, envelope_id:)
          raw    = client.get("/envelopes/#{envelope_id}/documents/#{id}")
          parsed = JsonApi::Parser.parse(raw)
          build_instance(parsed[:data].first, parent_id: envelope_id)
        end

        def self.create(envelope_id:, **attributes)
          raw = client.post(
            "/envelopes/#{envelope_id}/documents",
            body: JsonApi::Serializer.dump(type: resource_type, attributes: attributes),
          )
          parsed = JsonApi::Parser.parse(raw)
          build_instance(parsed[:data].first, parent_id: envelope_id)
        end

        def self.list_events(document_id, envelope_id:)
          raw    = client.get("/envelopes/#{envelope_id}/documents/#{document_id}/events")
          parsed = JsonApi::Parser.parse(raw)
          parsed[:data].map { |item| Event.send(:build_instance, item) }
        end

        def base_path
          "/envelopes/#{@_parent_id || envelope_id}/documents"
        end

        def envelope_id
          @_parent_id || relationships.dig('envelope', 'data', 'id')
        end
      end
    end
  end
end
