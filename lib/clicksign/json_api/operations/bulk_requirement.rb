# frozen_string_literal: true

module Clicksign
  module JsonApi
    class Operations
      class BulkRequirement < Operations
        VALID_KINDS = %w[initials manuscript].freeze

        def add_agree(signer_id:, document_id:, role:)
          validate_ids!(signer_id, document_id)
          raise ArgumentError, 'role is required' if role.to_s.empty?

          add(
            data: build_add_data(
              signer_id: signer_id,
              document_id: document_id,
              attributes: { action: 'agree', role: role },
            ),
          )
        end

        def add_provide_evidence(signer_id:, document_id:, auth:)
          validate_ids!(signer_id, document_id)
          raise ArgumentError, 'auth is required' if auth.to_s.empty?

          add(
            data: build_add_data(
              signer_id: signer_id,
              document_id: document_id,
              attributes: { action: 'provide_evidence', auth: auth },
            ),
          )
        end

        def add_rubricate(signer_id:, document_id:, pages: nil, rubric_field: nil,
                          kind: nil)
          validate_ids!(signer_id, document_id)
          if pages.nil? && rubric_field.nil?
            raise ArgumentError, 'pages or rubric_field is required'
          end
          if kind && !VALID_KINDS.include?(kind.to_s)
            raise ArgumentError, "kind must be one of: #{VALID_KINDS.join(', ')}"
          end

          add(
            data: build_add_data(
              signer_id: signer_id,
              document_id: document_id,
              attributes: { action: 'rubricate', pages: pages,
                            rubric_field: rubric_field, kind: kind },
            ),
          )
        end

        def remove(requirement_id:)
          raise ArgumentError, 'requirement_id is required' if requirement_id.to_s.empty?

          super(ref: { type: 'requirements', id: requirement_id })
        end

        private

        def validate_ids!(signer_id, document_id)
          raise ArgumentError, 'signer_id is required' if signer_id.to_s.empty?
          raise ArgumentError, 'document_id is required' if document_id.to_s.empty?
        end

        def build_add_data(signer_id:, document_id:, attributes:)
          {
            type: 'requirements',
            attributes: compact_attributes(attributes),
            relationships: {
              signer: { data: { type: 'signers', id: signer_id.to_s } },
              document: { data: { type: 'documents', id: document_id.to_s } },
            },
          }
        end

        def compact_attributes(attrs)
          attrs.each_with_object({}) do |(key, value), result|
            next if value.nil?

            result[key.to_s] = value.is_a?(Symbol) ? value.to_s : value
          end
        end
      end
    end
  end
end
