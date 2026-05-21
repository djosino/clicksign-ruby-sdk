# clicksign-ruby-sdk

## Testing

- Run all tests: `just test`
- Tests use RSpec: `bundle exec rspec`
- Format: `just format` (rubocop -A)
- Lint check: `just format-check` (rubocop)

## Key Locations

- HTTP client (requests, headers, auth, retry, instrumentation): `lib/clicksign/client.rb`
- Instrumentation shared module (publish_event, request_context): `lib/clicksign/request_instrumentation.rb`
- Retry backoff with full jitter: `lib/clicksign/retry_backoff.rb`
- Base resource class (CRUD, QueryProxy, method_missing, pagination): `lib/clicksign/resource.rb`
- Error handling (HTTP status → exception): `lib/clicksign/error_handler.rb`
- Errors hierarchy (retryable?, status_code, rate_limit_*): `lib/clicksign/errors.rb`
- Instrumentation hooks (on/publish/clear): `lib/clicksign/instrumentation.rb`
- Thread-local client scoping: `lib/clicksign/services.rb`
- Webhook HMAC validation: `lib/clicksign/webhook.rb`
- JSON:API layer: `lib/clicksign/json_api/` (parser, serializer, query_builder, operations, atomic_results_parser)
- Bulk operations client: `lib/clicksign/json_api/bulk_operations_client.rb`
- Resources: `lib/clicksign/resources/` (notarial/, auto_signature/, acceptance_term/, root)
- Version (read from REVISION file): `lib/clicksign/version.rb`
- Spec shared context: `spec/support/shared_contexts.rb`
- Spec fixtures: `spec/support/json_api_fixtures.rb`

## Architecture

- No runtime gem dependencies — only Ruby stdlib (`net/http`, `json`, `uri`)
- JSON:API protocol (v1.1) for all requests/responses
- `Authorization: <token>` header — **NO** `Bearer` prefix
- Version read from `REVISION` file at load time — single source of truth
- Resources inherit from `Clicksign::Resource`; dynamic attribute access via `method_missing`
- Notarial namespace groups envelope-flow resources (Envelope, Document, Signer, etc.)
- `@_parent_id` pattern for nested resources so `reload`/`update`/`delete` work without re-fetching parent context
- `RequestInstrumentation` module shared by `Client` and `BulkOperationsClient` — both publish `:request`, `:retry`, `:error`
- `RetryBackoff` module shared by both clients — full jitter, capped at 30s
- `Thread.current[:clicksign_client]` for thread-local client scoping via `Services#use`
- `Clicksign.configure` must be called once at app startup, before threads spawn (not thread-safe for concurrent first access)
- `config.logger` — optional Ruby Logger for instrumentation callback errors (nil = silent)

## QueryProxy chain

`Resource.filter`, `.order`, `.with_includes`, `.include`, `.page`, `.per`, `.fields` all return a `QueryProxy`.

- `Resource.list` — no arguments, eager Array (use `filter` for filtered queries)
- `Resource.with_includes(*types)` — canonical JSON:API sideload (String/Symbol only, validated)
- `Resource.include(*types)` — delegates to `with_includes` for strings; delegates to `super` for Modules; raises `ArgumentError` if mixed
- Auto-pagination uses `links.next` when present; falls back to item-count heuristic only when API omits `links`

## Instrumentation events

```ruby
Clicksign.on_request { |e| }  # e: { method:, path:, status:, attempt:, duration_ms: }
Clicksign.on_retry   { |e| }  # e: { method:, path:, attempt:, max_retries:, error:, wait_ms: }
Clicksign.on_error   { |e| }  # e: { method:, path:, status:, error:, duration_ms: }
```

## Skills (slash commands)

- `/gen-resource <name>` — generate a new resource + spec from the Clicksign API source of truth
- `/sync-spec` — compare API routes with SDK resources, list gaps
- `/release` — release checklist

## Spec conventions

- All specs use WebMock stubs + `JsonApiFixtures` — no VCR, no real network
- Specs start with `include_context 'with clicksign configured'`
- IDs in specs: `'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'` pattern — never real sandbox UUIDs
- Every resource spec has `describe 'resource configuration'` with `resource_type` and `endpoint`
- Routes with `except: [:update]` must override `def update(**); raise NotImplementedError`
- Stubs de erro: `body: { errors: [{ detail: 'msg' }] }.to_json`
- `stub_request(:get, url)` sem `.with(query:)` não casa com requests que têm query params — sempre especificar
- `spec_helper.rb` faz `Clicksign.reset!` (before) e `Clicksign::Instrumentation.clear` (after) em cada exemplo

## Boas práticas aprendidas

- `ErrorHandler.extract_message` guarda `unless body.is_a?(Hash)` — API pode retornar array JSON
- `raise TimeoutError, e.message, e.backtrace` — preserva backtrace da exceção de rede original
- `nested_create` foi removido do `Resource` base por ser código morto — não recriar
- `BulkOperationsClient` retenta apenas `TimeoutError`, não `ServerError` — comportamento intencional documentado em spec
- `Resource.include` com Module → `super`; com String/Symbol → `with_includes`; mistura → `ArgumentError`
- `infer_resource_type` tem guard `return 'resources' if name.nil?` — classes anônimas sem `resource_type` explícito
- `fetch_auto_pages` usa `links['next']` quando presente — evita requests extras desnecessários
- Callbacks de instrumentação são isolados com `rescue StandardError`; erros logados via `config.logger&.warn`
- `Thread.current[:clicksign_client]` incompatível com Fiber-based runtimes (Falcon/async-ruby)

## Comments

- Use comentários apenas para o WHY não-óbvio de um trecho de código
- Nunca para dizer o que o código faz (código bem nomeado já comunica isso)
