# frozen_string_literal: true

module Clicksign
  module JsonApi
    module AtomicResultsParser
      module_function

      def parse(raw, envelope_id:, operations:)
        raw ||= {}
        raise ValidationError, format_errors(raw['errors']) if envelope_errors?(raw)

        Array(raw['atomic:results']).each_with_index.map do |slot, index|
          build_operation_result(
            slot: slot,
            index: index,
            op: operations.dig(index, 'op'),
            envelope_id: envelope_id,
          )
        end
      end

      def envelope_errors?(raw)
        raw.key?('errors') && !raw.key?('atomic:results')
      end

      def build_operation_result(slot:, index:, op:, envelope_id:)
        slot ||= {}
        errors = slot['errors']
        requirement = build_requirement(slot['data'], envelope_id: envelope_id)

        Resources::Notarial::BulkRequirement::OperationResult.new(
          index: index,
          op: op,
          requirement: requirement,
          errors: errors,
          raw: slot,
        )
      end

      def build_requirement(data, envelope_id:)
        return nil if data.nil? || (!data['id'] && !data['type'])

        Resources::Notarial::Requirement.send(
          :build_instance,
          {
            'id' => data['id'],
            'type' => data['type'],
            'attributes' => data.fetch('attributes', {}),
            'relationships' => data.fetch('relationships', {}),
          },
          parent_id: envelope_id,
        )
      end

      def format_errors(errors)
        return 'Validation failed' unless errors.is_a?(Array)

        errors.filter_map { |e| e.is_a?(Hash) && (e['detail'] || e['title']) }.join(', ')
      end
    end
  end
end
