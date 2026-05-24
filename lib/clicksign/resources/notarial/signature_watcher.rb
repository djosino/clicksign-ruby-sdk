# frozen_string_literal: true

module Clicksign
  module Resources
    module Notarial
      class SignatureWatcher < Clicksign::Resource
        self.resource_type = 'signature_watchers'

        def self.retrieve(id, envelope_id:)
          raw    = client.get("/envelopes/#{envelope_id}/signature_watchers/#{id}")
          parsed = JsonApi::Parser.parse(raw)
          build_instance(parsed[:data].first, parent_id: envelope_id)
        end

        def self.create(envelope_id:, **attributes)
          raw = client.post(
            "/envelopes/#{envelope_id}/signature_watchers",
            body: JsonApi::Serializer.dump(type: resource_type, attributes: attributes),
          )
          parsed = JsonApi::Parser.parse(raw)
          build_instance(parsed[:data].first, parent_id: envelope_id)
        end

        def base_path
          eid = @_parent_id || envelope_id
          if eid.nil?
            raise Clicksign::Error,
              'envelope_id is required for SignatureWatcher operations'
          end

          "/envelopes/#{eid}/signature_watchers"
        end

        def update(**)
          raise NotImplementedError,
            'SignatureWatcher does not support update (route: except: [:update])'
        end

        def envelope_id
          @_parent_id || relationships.dig('envelope', 'data', 'id')
        end
      end
    end
  end
end
