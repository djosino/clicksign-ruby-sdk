# frozen_string_literal: true

module Clicksign
  module RequestInstrumentation
    private

    def publish_event(type, context, extra)
      Instrumentation.publish(type, context.merge(extra))
    end

    def elapsed_ms(start)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(1)
    end

    def resource_path(uri)
      base = URI.parse(@base_url).path
      uri.path.delete_prefix(base)
    end

    def request_context(request, uri, attempt)
      {
        method: request.method.downcase.to_sym,
        path: resource_path(uri),
        attempt: attempt,
      }
    end

    def publish_retry(request, uri, attempt, error, delay)
      Instrumentation.publish(:retry, {
                                method: request.method.downcase.to_sym,
                                path: resource_path(uri),
                                attempt: attempt,
                                max_retries: @max_retries,
                                error: error,
                                wait_ms: (delay * 1000).round,
                              })
    end

    def handle_network_error(error, context, start)
      duration = elapsed_ms(start)
      err = TimeoutError.new(error.message)
      publish_event(:error, context, error: err, status: nil, duration_ms: duration)
      raise err, error.message, error.backtrace
    end

    def publish_http_outcome(response, context, start)
      duration = elapsed_ms(start)
      status   = response.code.to_i
      publish_event(:request, context, status: status, duration_ms: duration)
      [response, status, duration]
    end

    def publish_http_error(context, error, status, duration)
      publish_event(:error, context, error: error, status: status, duration_ms: duration)
    end
  end
end
