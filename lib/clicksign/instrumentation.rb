# frozen_string_literal: true

module Clicksign
  module Instrumentation
    EVENTS = %i[request retry error].freeze

    @callbacks = Hash.new { |h, k| h[k] = [] }

    class << self
      def on(event, &block)
        unless EVENTS.include?(event)
          raise ArgumentError, "Unknown event: #{event}. Valid: #{EVENTS.join(', ')}"
        end

        @callbacks[event] << block
      end

      def publish(event, payload)
        @callbacks[event].each do |cb|
          cb.call(payload)
        rescue StandardError => e
          Clicksign.configuration.logger&.warn(
            "[Clicksign] instrumentation callback error (#{event}): " \
            "#{e.class}: #{e.message}",
          )
        end
      end

      # Removes all registered callbacks — intended for test teardown.
      def clear
        @callbacks = Hash.new { |h, k| h[k] = [] }
      end
    end
  end
end
