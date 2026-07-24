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
- `BulkOperationsClient` retenta `TimeoutError`, `RateLimitError` e `ServerError` — alinhado com `Client.rb`
- `Resource.include` com Module → `super`; com String/Symbol → `with_includes`; mistura → `ArgumentError`
- `infer_resource_type` tem guard `return 'resources' if name.nil?` — classes anônimas sem `resource_type` explícito
- `fetch_auto_pages` usa `links['next']` quando presente — evita requests extras desnecessários; `links: {}` (sem chave `next`) também para; `per=0` não cria loop infinito (guard `per.positive?` em `more_pages?`)
- `AtomicResultsParser.build_operation_result` normaliza `slot ||= {}` — `atomic:results: [null]` não levanta `NoMethodError`
- `JsonApi::Parser.parse` levanta `Clicksign::Error` para `data` de tipo inesperado (não Array/Hash/nil) — resposta malformada não é silenciada como `[]`
- `ErrorHandler.extract_from_json` guarda `e.is_a?(Hash)` em `filter_map` — itens de erro que são strings não são descartados silenciosamente (fallback para `response.message`)
- Callbacks de instrumentação são isolados com `rescue StandardError`; erros logados via `config.logger&.warn`
- `Thread.current[:clicksign_client]` incompatível com Fiber-based runtimes (Falcon/async-ruby)
- `Webhook.verify_signature!` com `signature: nil` levanta `WebhookSignatureError`, não `TypeError` — guard em `secure_compare?`
- `build_instance(nil)` levanta `NotFoundError` — API pode retornar `{ data: null }` válido em JSON:API; guard em `build_instance` e nos `load_data` diretos em `update`/`reload`
- `ErrorHandler.extract_from_json`: quando todos os errors items não têm `detail` nem `title`, `join('')` retornava `""` — corrigido para fallback em `response.message`
- `BulkOperationsClient#parse_response_body`: JSON inválido em 2xx agora levanta `Clicksign::Error` explícito em vez de retornar `nil` silencioso
- `Instrumentation.@callbacks` protegido por `Mutex` — `on` e `publish` são thread-safe; `publish` faz `.dup` para evitar race condition durante iteração
- `QueryProxy` muta `@builder` in-place ao encadear — referência guardada acumula todos os params da chain; design intencional, mas surpreendente se proxy for reutilizado
- `Requirement.list_for_document/list_for_signer` não passa `parent_id` — `requirement.envelope_id` retorna `nil` quando API não inclui relacionamento `envelope` nesses endpoints; comportamento esperado e documentado em spec
- `api_key: nil` não levanta erro no `configure` nem no `Client.new` — o `AuthenticationError` só aparece na primeira request; usar `ENV.fetch` para detectar ausência no boot
- `Event` não suporta `delete`/`reload`/`update` — API só expõe `GET` (list) e `POST` (create); os três métodos levantam `NotImplementedError`
- `Event.create(envelope_id:, document_id:, **attributes)` — método base genérico; helpers `create_add_image` e `create_custom` delegam para ele com payload montado e `kind` validado via `CUSTOM_KINDS`
- `Event.create_add_image` envia `content_base64` no nível de `attributes`, e `title`/`occurred_at` dentro de `data:`
- `Event.create_custom` valida `kind` (ArgumentError antes da request) e usa `.compact` para omitir `signer_email`/`signer_phone_number` quando nil
- `QueryBuilder.include` acumula tipos em chamadas sucessivas (não sobrescreve); deduplica automaticamente
- `build_uri` com `path` contendo query string existente sobrescreve essa query — callers devem sempre passar params via hash; nunca embutir query no path

## API Resource Map

Tabela de todos os resources v3. Usar como referência ao gerar novos resources (`/gen-resource`).

| Resource (classe Ruby) | `resource_type` | `endpoint` | Métodos expostos | Gotchas |
|------------------------|-----------------|------------|-----------------|---------|
| `Notarial::Envelope` | `envelopes` | `/envelopes` | list, retrieve, create, update, delete + `activate(id)`, `notify(id)`, `list_documents`, `list_signers`, `list_requirements`, `list_signature_watchers`, `list_events` | — |
| `Notarial::Document` | `documents` | `/envelopes/:id/documents` | list (via Envelope), retrieve, create, update, delete | nested; `content_base64`/`content_url`/`template`/`duplicate` mutuamente exclusivos |
| `Notarial::Signer` | `signers` | `/envelopes/:id/signers` | list (via Envelope), create, delete | **sem update** — `except: [:update]` |
| `Notarial::Requirement` | `requirements` | `/envelopes/:id/requirements` | list (via Envelope/Document/Signer), retrieve, create, delete | **sem update** — API não expõe PATCH; `create`/`delete` só em envelope `draft` |
| `Notarial::BulkRequirement` | `bulk_requirements` | `/envelopes/:id/bulk_requirements` | create (block API com `atomic:operations`) | resposta `atomic:results`; sempre checar `response.success?` |
| `Notarial::SignatureWatcher` | `signature_watchers` | `/envelopes/:id/signature_watchers` | list (via Envelope), retrieve, create, delete | nested |
| `Resources::Webhook` | `webhooks` | `/webhooks` | list, retrieve, create, update, delete | filtros: `status` |
| `Resources::User` | `users` | `/users` | list, retrieve, create + `me` | **sem update/delete** — `only: %i[index show create]` |
| `Resources::Membership` | `memberships` | `/memberships` | list, create, update, delete | **update usa PUT**, não PATCH — sobrescrever método |
| `Resources::Group` | `groups` | `/groups` | list, retrieve, create, update, delete | relacionamento `users` has_many |
| `Resources::Template` | `templates` | `/templates` | list, retrieve, create, update, delete | relacionamento `template_fields` has_many |
| `Resources::TemplateField` | `template_fields` | `/template_fields` | list | **só index** — `only: %i[index]` |
| `Resources::Folder` | `folders` | `/folders` | list, retrieve, create | **sem update/delete** — `only: %i[index create show]`; auto-referencial (`resolve_custom_type`) |
| `Resources::EnvelopeBulkCreation` | `envelope_bulk_creations` | `/envelope_bulk_creations` | create | **só create** — resposta: `job_id`, `enqueued_at` |
| `Resources::AccessControlList` | `access_control_lists` | `/access_control_lists` | create, delete | **singular** (`jsonapi_resource`, não plural); delete envia body com relationships |
| `Resources::Event` | `events` | `/envelopes/:id/documents/:id/events` | list (via Envelope), create, `create_add_image`, `create_custom` | **sem retrieve/update/delete/reload**; nested duplo (envelope + document) |
| `AutoSignature::Term` | `auto_signature_terms` | `/auto_signature/terms` | create | **só create** — namespace de rota |
| `AcceptanceTerm::Whatsapp` | `acceptance_term_whatsapps` | `/acceptance_term/whatsapps` | list, retrieve, create, update | **sem delete** — `except: %i[destroy]` |

## API Constraints (não deriváveis do código)

Regras da API que devem ser respeitadas na geração de resources:

- **Membership#update** — usa `PUT /memberships/:id`, não `PATCH`; sobrescrever método na classe para trocar verbo HTTP
- **Requirement** — `create`/`delete` só funcionam com envelope em status `draft`; em `running` a API retorna 422
- **Signer** — sem `update`; API não expõe `PATCH /signers/:id`; declarar `except: [:update]` e `raise NotImplementedError`
- **Requirement** — sem `update`; API não expõe `PATCH /requirements/:id`; idem
- **Event** — sem `retrieve`/`update`/`delete`/`reload`; API só tem `GET` (list) e `POST` (create)
- **User** — sem `update`/`delete`; `only: %i[index show create]` + método `me` (`GET /users/me`)
- **TemplateField** — só `list`; `only: %i[index]`; sem create/update/delete
- **Folder** — sem `update`/`delete`; `only: %i[index create show]`; auto-referencial (pasta pai = relacionamento `folder` has_one)
- **AccessControlList** — rota singular (`jsonapi_resource`, não `jsonapi_resources`); `DELETE` envia relacionamentos no body, não ID na URL
- **BulkRequirement** — não usa thread-local do `Services#use`; usa `Clicksign.bulk_operations_client` global memoizado
- **Webhook (HMAC)** — `verify_signature!` valida `Content-HMAC` header com `sha256=<hex>`; usar `request.raw_post`, nunca body re-serializado
- **Authorization header** — `Authorization: <token>` sem prefixo `Bearer`; token de sandbox ≠ token de produção
- **Namespace de rota ≠ namespace Ruby** — `AutoSignature::Term` tem `resource_type = 'auto_signature_terms'` e `endpoint = '/auto_signature/terms'`; idem `AcceptanceTerm::Whatsapp`

## Comments

- Use comentários apenas para o WHY não-óbvio de um trecho de código
- Nunca para dizer o que o código faz (código bem nomeado já comunica isso)
