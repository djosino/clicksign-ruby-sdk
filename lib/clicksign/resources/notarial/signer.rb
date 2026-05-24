# frozen_string_literal: true

module Clicksign
  module Resources
    module Notarial
      class Signer < Clicksign::Resource
        self.resource_type = 'signers'

        def self.retrieve(id, envelope_id:)
          raw    = client.get("/envelopes/#{envelope_id}/signers/#{id}")
          parsed = JsonApi::Parser.parse(raw)
          build_instance(parsed[:data].first, parent_id: envelope_id)
        end

        def self.create(envelope_id:, **attributes)
          raw = client.post(
            "/envelopes/#{envelope_id}/signers",
            body: JsonApi::Serializer.dump(type: resource_type, attributes: attributes),
          )
          parsed = JsonApi::Parser.parse(raw)
          build_instance(parsed[:data].first, parent_id: envelope_id)
        end

        def self.notify(id, envelope_id:, message: nil, **email_customization)
          attributes = {}
          attributes[:message] = message if message
          unless email_customization.empty?
            attributes[:email_customization] =
              email_customization
          end
          body = { data: { type: 'notifications', attributes: attributes } }
          client.post("/envelopes/#{envelope_id}/signers/#{id}/notifications", body: body)
          nil
        end

        def notify(message: nil, **email_customization)
          self.class.notify(@id, envelope_id: envelope_id, message: message,
                                 **email_customization)
        end

        def update(**)
          raise NotImplementedError,
            'Signer does not support update (route: except: [:update])'
        end

        def base_path
          eid = @_parent_id || envelope_id
          if eid.nil?
            raise Clicksign::Error,
              'envelope_id is required for Signer operations'
          end

          "/envelopes/#{eid}/signers"
        end

        def envelope_id
          @_parent_id || relationships.dig('envelope', 'data', 'id')
        end
      end
    end
  end
end
