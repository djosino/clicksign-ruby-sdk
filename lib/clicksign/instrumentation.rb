# frozen_string_literal: true

module Clicksign
  module Instrumentation
    EVENTS = %i[request retry error].freeze

    @callbacks = Hash.new { |h, k| h[k] = [] }
    @mutex     = Mutex.new

    class << self
      def on(event, &block)
        unless EVENTS.include?(event)
          raise ArgumentError, "Unknown event: #{event}. Valid: #{EVENTS.join(', ')}"
        end

        @mutex.synchronize { @callbacks[event] << block }
      end

      def publish(event, payload)
        callbacks = @mutex.synchronize { @callbacks[event].dup }
        callbacks.each do |cb|
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
        @mutex.synchronize { @callbacks = Hash.new { |h, k| h[k] = [] } }
      end
    end
  end
end
