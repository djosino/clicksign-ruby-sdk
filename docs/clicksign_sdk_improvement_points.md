# Clicksign Ruby SDK — Improvement Points

This document contains architectural, operational, and developer experience improvements inspired by SDKs such as Stripe, AWS, Twilio, and modern Ruby ecosystem best practices.

---

# 1. Configurable Timeouts

## Current Situation

The SDK uses Net::HTTP but does not expose explicit timeout configuration.

This can create production issues:

- hanging requests
- Sidekiq thread starvation
- slow failure detection
- cascading latency

---

## Recommendation

Expose:

- open_timeout
- read_timeout
- write_timeout

---

## Suggested API

```ruby
Clicksign.configure do |config|
  config.api_key = ENV['CLICKSIGN_API_KEY']

  config.open_timeout = 2
  config.read_timeout = 10
  config.write_timeout = 10
end
```

---

## Recommended Defaults

```yaml
open_timeout: 2s
read_timeout: 10s
write_timeout: 10s
```

---

# 2. Retry Strategy with Exponential Backoff

## Current Situation

The SDK does not appear to provide automatic retries.

This increases operational complexity for integrators.

---

## Recommendation

Add optional automatic retries for transient failures.

Retry scenarios:

- timeouts
- network failures
- HTTP 429
- HTTP 5xx

Do not retry:

- validation errors
- authentication errors
- malformed requests

---

## Suggested API

```ruby
Clicksign.configure do |config|
  config.max_retries = 3
  config.retry_strategy = :exponential_backoff
end
```

---

## Additional Recommendation

Expose retry metadata:

- retry_count
- retry_reason
- request_duration

---

# 3. Idempotency Support

## Current Situation

The SDK does not expose idempotency handling.

This is critical for:

- Sidekiq retries
- distributed systems
- duplicated requests
- network instability

---

## Recommendation

Support:

```txt
Idempotency-Key
```

header propagation.

---

## Suggested API

### Option A

```ruby
Envelope.create(
  payload,
  idempotency_key: 'abc123'
)
```

### Option B

```ruby
client.with_idempotency_key('abc123') do
  Envelope.create(payload)
end
```

---

## Benefits

- safe retries
- protection against duplicated operations
- easier distributed job execution
- safer integrations

---

# 4. Client Instance Support

## Current Situation

The SDK primarily promotes global configuration.

Example:

```ruby
Clicksign.configure do |config|
  config.api_key = '...'
end
```

This works well for simple applications but creates limitations for:

- multi-account applications
- multi-tenant systems
- background workers
- tests running in parallel
- isolated contexts

---

## Recommendation

Support explicit client instances.

---

## Suggested API

```ruby
client = Clicksign::Client.new(
  api_key: ENV['CLICKSIGN_API_KEY'],
  environment: :production
)

client.envelopes.create(...)
```

---

## Benefits

- isolated contexts
- safer concurrency
- improved testability
- enterprise readiness
- easier SDK composition

---

# 5. Rich Structured Errors

## Current Situation

The SDK already maps error categories.

This is good.

However, errors could expose more operational metadata.

---

## Recommendation

All errors should expose:

- status_code
- request_id
- error_code
- response_body
- response_headers
- retryable?
- timeout?

---

## Suggested Structure

```ruby
begin
  Envelope.create(...)
rescue Clicksign::ValidationError => e
  e.status_code
  e.request_id
  e.error_code
  e.response_body
end
```

---

## Benefits

- easier debugging
- improved observability
- better Datadog/Sentry integration
- operational visibility

---

# 6. Request ID Propagation

## Recommendation

Capture and expose request identifiers returned by the API.

---

## Suggested Behavior

```ruby
response.request_id
```

and:

```ruby
error.request_id
```

---

## Benefits

- easier support debugging
- traceability
- correlation with API logs
- distributed tracing support

---

# 7. Instrumentation Hooks

## Recommendation

Expose instrumentation hooks compatible with:

- ActiveSupport::Notifications
- OpenTelemetry
- Datadog
- custom metrics systems

---

## Suggested Events

```txt
clicksign.request
clicksign.retry
clicksign.error
clicksign.rate_limit
```

---

## Example

```ruby
ActiveSupport::Notifications.subscribe('clicksign.request') do |*args|
end
```

---

# 8. Pagination Abstractions

## Recommendation

Improve pagination ergonomics.

---

## Suggested API

```ruby
Envelope.all.each do |envelope|
end
```

or:

```ruby
Envelope.auto_paging_each do |envelope|
end
```

Inspired by Stripe auto-pagination.

---

# 9. Better Environment Handling

## Recommendation

Explicit environment abstraction.

---

## Suggested API

```ruby
Clicksign.configure do |config|
  config.environment = :sandbox
end
```

Instead of relying only on URLs.

---

# 10. Official Webhook Validation Helper

## Recommendation

Provide built-in webhook signature validation.

---

## Suggested API

```ruby
Clicksign::Webhook.verify_signature!(payload, signature)
```

---

## Benefits

- safer integrations
- less duplicated code
- standard security behavior

---

# 11. Rate Limit Awareness

## Recommendation

Expose rate limit metadata.

---

## Suggested Accessors

```ruby
response.rate_limit_remaining
response.rate_limit_reset
```

---

## Benefits

- adaptive retry strategies
- operational visibility
- easier queue throttling

---

# 12. Better SDK Typing and Response Objects

## Recommendation

Responses should expose typed accessors instead of only hashes.

---

## Suggested API

```ruby
envelope.status
envelope.id
envelope.documents
```

while preserving raw response access.

---

## Optional

```ruby
envelope.raw_response
```

---

# 13. Improved Test Utilities

## Recommendation

Provide official testing helpers.

---

## Examples

```ruby
Clicksign::Testing.fake_webhook(...)
Clicksign::Testing.stub_request(...)
```

---

## Benefits

- easier onboarding
- standardized integration tests
- better developer experience

---

# 14. API Version Exposure

## Recommendation

Expose API version support directly.

---

## Suggested API

```ruby
Clicksign.configure do |config|
  config.api_version = 'v3'
end
```

---

# 15. Changelog and Migration Guides

## Recommendation

Maintain:

- detailed CHANGELOG.md
- migration guides
- breaking changes section
- upgrade examples

---

## Benefits

- safer upgrades
- enterprise adoption
- predictable SDK evolution

---

# 16. Enterprise Readiness Goals

The SDK should evolve toward:

- production resilience
- excellent observability
- retry safety
- enterprise compatibility
- distributed systems readiness
- traceability
- strong developer experience
- operational simplicity

---

# Final Evaluation

The SDK already has:

- very good structure
- good Ruby ergonomics
- broad API coverage
- lightweight dependency strategy
- good README/documentation
- organized test setup
- CI support
- proper error categorization

The recommendations above focus mainly on:

- operational maturity
- distributed systems resilience
- enterprise robustness
- observability
- production-grade DX

The project already stands above most custom/internal Ruby SDKs and has strong potential to become a reference-quality SDK in the Ruby ecosystem.

