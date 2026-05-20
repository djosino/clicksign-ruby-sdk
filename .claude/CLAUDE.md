# clicksign-ruby-sdk

## Testing

- Run all tests: `just test`
- Tests use RSpec: `bundle exec rspec`
- Format: `just format` (rubocop -A)
- Lint check: `just format-check` (rubocop)

## Key Locations

- HTTP client (requests, headers, auth): `lib/clicksign/client.rb`
- Base resource class (CRUD, QueryProxy, method_missing): `lib/clicksign/resource.rb`
- Error handling (HTTP status → exception): `lib/clicksign/error_handler.rb`
- JSON:API layer: `lib/clicksign/json_api/` (parser, serializer, query_builder, operations)
- Resources: `lib/clicksign/resources/` (notarial/, auto_signature/, acceptance_term/, root)
- Version: `lib/clicksign/version.rb`
- Spec shared context: `spec/support/shared_contexts.rb`
- Spec fixtures: `spec/support/json_api_fixtures.rb`

## Architecture

- No runtime gem dependencies — only Ruby stdlib (`net/http`, `json`, `uri`)
- JSON:API protocol (v1.1) for all requests/responses
- `Authorization: <token>` header — **NO** `Bearer` prefix
- Resources inherit from `Clicksign::Resource`; dynamic attribute access via `method_missing`
- Notarial namespace groups envelope-flow resources (Envelope, Document, Signer, etc.)
- `@_parent_id` pattern for nested resources so `reload`/`update`/`delete` work without re-fetching parent context

## Skills (slash commands)

- `/gen-resource <name>` — generate a new resource + spec from the Clicksign API source of truth
- `/sync-spec` — compare API routes with SDK resources, list gaps
- `/release` — release checklist

## Conventions

- All specs use WebMock stubs + `JsonApiFixtures` — no VCR, no real network
- Specs start with `include_context 'with clicksign configured'` (includes `JsonApiFixtures` and configures the SDK)
- IDs in specs: `'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'` pattern — never real sandbox UUIDs
- Routes with `except: [:update]` must override `def update(**); raise NotImplementedError`
- `Clicksign.configure` must be called once at app startup, before threads spawn (not thread-safe for concurrent first access)

## Boas práticas aprendidas

- `ErrorHandler.extract_message` guarda `unless body.is_a?(Hash)` — API pode retornar array JSON
- `raise TimeoutError, e.message, e.backtrace` — preserva backtrace da exceção de rede original
- `nested_create` foi removido do `Resource` base por ser código morto — não recriar
- Specs com `vcr: true` quebravam CI (cassettes são gitignored) — usar WebMock puro
- `stub_request(:get, url)` sem `.with(query:)` não casa quando VCR está carregado; sempre especificar query params no stub
- Stubs de erro seguem o padrão: `body: { errors: [{ detail: 'msg' }] }.to_json`

### Comments

- Use comentários apenas para o WHY não-óbvio de um trecho de código
- Nunca para dizer o que o código faz (código bem nomeado já comunica isso)
