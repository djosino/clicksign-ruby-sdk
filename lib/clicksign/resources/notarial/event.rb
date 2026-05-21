# frozen_string_literal: true

module Clicksign
  module Resources
    module Notarial
      class Event < Clicksign::Resource
        self.resource_type = 'events'

        CUSTOM_KINDS = %w[token_email token_sms].freeze

        def self.create(envelope_id:, document_id:, **attributes)
          raw = client.post(
            "/envelopes/#{envelope_id}/documents/#{document_id}/events",
            body: JsonApi::Serializer.dump(type: resource_type, attributes: attributes),
          )
          parsed = JsonApi::Parser.parse(raw)
          build_instance(parsed[:data].first)
        end

        def self.create_add_image(envelope_id:, document_id:, title:, occurred_at:,
          content_base64:)
          create(
            envelope_id: envelope_id,
            document_id: document_id,
            name: 'add_image',
            content_base64: content_base64,
            data: { title: title, occurred_at: occurred_at },
          )
        end

        def self.create_custom(envelope_id:, document_id:, kind:, occurred_at:,
          signer_name:, signer_email: nil, signer_phone_number: nil)
          unless CUSTOM_KINDS.include?(kind.to_s)
            raise ArgumentError, "kind must be one of: #{CUSTOM_KINDS.join(', ')}"
          end

          create(
            envelope_id: envelope_id,
            document_id: document_id,
            name: 'custom',
            data: {
              kind: kind,
              occurred_at: occurred_at,
              signer_name: signer_name,
              signer_email: signer_email,
              signer_phone_number: signer_phone_number,
            }.compact,
          )
        end

        # API only exposes GET (list) and POST (create) for events — no singleton routes.
        def update(**)
          raise NotImplementedError, 'Event does not support update'
        end

        def delete
          raise NotImplementedError, 'Event does not support delete'
        end

        def reload
          raise NotImplementedError, 'Event does not support reload'
        end
      end
    end
  end
end
