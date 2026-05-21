# frozen_string_literal: true

module Clicksign
  module Resources
    module Notarial
      class Envelope < Clicksign::Resource
        self.resource_type = 'envelopes'

        def self.create(folder_id: nil, **attributes)
          relationships = if folder_id
                            { folder: { data: { type: 'folders',
                                                id: folder_id } } }
                          else
                            {}
                          end
          super(**attributes, relationships: relationships)
        end

        # POST /envelopes/:id/activate — rota disponível mas prefira
        # envelope.update(status: 'running') via PATCH, que é o caminho
        # recomendado e suportado por todos os ambientes.
        def self.activate(id)
          raw    = client.post("#{endpoint}/#{id}/activate", body: {})
          parsed = JsonApi::Parser.parse(raw)
          build_instance(parsed[:data].first)
        end

        def self.list_events(envelope_id, **filters)
          nested_list(envelope_id, nested_type: 'events', as: Event,
            params: filter_params(**filters))
        end

        def self.list_documents(envelope_id, **filters)
          nested_list(envelope_id, nested_type: 'documents', as: Document,
            params: filter_params(**filters))
        end

        def self.list_signers(envelope_id, **filters)
          nested_list(envelope_id, nested_type: 'signers', as: Signer,
            params: filter_params(**filters))
        end

        def self.list_signature_watchers(envelope_id, **filters)
          nested_list(envelope_id, nested_type: 'signature_watchers',
            as: SignatureWatcher,
            params: filter_params(**filters))
        end

        def self.list_requirements(envelope_id, **filters)
          nested_list(
            envelope_id,
            nested_type: 'requirements',
            as: Requirement,
            params: filter_params(**filters),
          )
        end

        def self.notify(id, message: nil, **email_customization)
          attributes = {}
          attributes[:message] = message if message
          unless email_customization.empty?
            attributes[:email_customization] =
              email_customization
          end
          body = { data: { type: 'notifications', attributes: attributes } }
          client.post("#{endpoint}/#{id}/notifications", body: body)
          nil
        end

        def notify(message: nil, **email_customization)
          self.class.notify(@id, message: message, **email_customization)
        end

        def folder_id
          relationships.dig('folder', 'data', 'id')
        end
      end
    end
  end
end
