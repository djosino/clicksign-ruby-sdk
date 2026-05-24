# frozen_string_literal: true

module Clicksign
  module Resources
    module Notarial
      class Requirement < Clicksign::Resource
        self.resource_type = 'requirements'

        def self.retrieve(id, envelope_id:)
          raw    = client.get("/envelopes/#{envelope_id}/requirements/#{id}")
          parsed = JsonApi::Parser.parse(raw)
          build_instance(parsed[:data].first, parent_id: envelope_id)
        end

        def self.create(envelope_id:, **attributes)
          relationships = attributes.delete(:relationships) || {}
          raw = client.post(
            "/envelopes/#{envelope_id}/requirements",
            body: JsonApi::Serializer.dump(
              type: resource_type, attributes: attributes, relationships: relationships,
            ),
          )
          parsed = JsonApi::Parser.parse(raw)
          build_instance(parsed[:data].first, parent_id: envelope_id)
        end

        def self.list_for_document(document_id, **filters)
          list_related('documents', document_id, **filters)
        end

        def self.list_for_signer(signer_id, **filters)
          list_related('signers', signer_id, **filters)
        end

        def self.list_related(resource_type, resource_id, **filters)
          raw = client.get(
            "/#{resource_type}/#{resource_id}/relationships/requirements",
            params: filter_params(**filters),
          )
          parsed = JsonApi::Parser.parse(raw)
          parsed[:data].map { |item| build_instance(item) }
        end
        private_class_method :list_related

        def base_path
          eid = @_parent_id || envelope_id
          raise Clicksign::Error, 'envelope_id is required for Requirement operations' if eid.nil?

          "/envelopes/#{eid}/requirements"
        end

        def envelope_id
          @_parent_id || relationships.dig('envelope', 'data', 'id')
        end

        def document_id
          relationships.dig('document', 'data', 'id')
        end

        def signer_id
          relationships.dig('signer', 'data', 'id')
        end
      end
    end
  end
end
