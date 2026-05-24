# frozen_string_literal: true

module Clicksign
  module Resources
    module Notarial
      class BulkRequirement
        class OperationResult
          attr_reader :index, :op, :requirement, :errors, :raw

          def initialize(index:, op:, requirement:, errors:, raw:)
            @index = index
            @op = op
            @requirement = requirement
            @errors = errors
            @raw = raw
          end

          def success?
            errors.nil? || (errors.is_a?(Array) && errors.empty?)
          end
        end

        class Response
          attr_reader :envelope_id, :results

          def initialize(envelope_id:, results:)
            @envelope_id = envelope_id
            @results = results
          end

          def success?
            results.all?(&:success?)
          end

          def requirements
            results.filter_map(&:requirement)
          end

          def failures
            results.reject(&:success?)
          end
        end

        def self.create(envelope_id:, &block)
          if envelope_id.nil? || envelope_id.to_s.empty?
            raise ArgumentError,
              'envelope_id is required'
          end
          raise ArgumentError, 'block is required' unless block

          ops = JsonApi::Operations::BulkRequirement.new
          yield ops

          raw = Clicksign.bulk_operations_client.post(
            "/envelopes/#{envelope_id}/bulk_requirements",
            body: ops.to_h,
          )

          Response.new(
            envelope_id: envelope_id,
            results: JsonApi::AtomicResultsParser.parse(
              raw,
              envelope_id: envelope_id,
              operations: ops.entries,
            ),
          )
        end
      end
    end
  end
end
