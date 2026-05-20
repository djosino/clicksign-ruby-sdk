# frozen_string_literal: true

module Clicksign
  module RetryBackoff
    BASE_SECONDS = 0.5
    CAP_SECONDS  = 30.0

    module_function

    def ceiling(attempt)
      [BASE_SECONDS * (2**(attempt - 1)), CAP_SECONDS].min.to_f
    end

    # Full jitter: uniform in [0, ceiling) to spread retries and avoid thundering herd.
    def delay(attempt, rng: Random)
      max = ceiling(attempt)
      return 0.0 if max <= 0

      rng.rand(max)
    end
  end
end
