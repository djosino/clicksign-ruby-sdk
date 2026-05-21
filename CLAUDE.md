# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
bundle exec rspec                          # all tests
bundle exec rspec spec/path/to/file_spec.rb                  # single file
bundle exec rspec spec/path/to/file_spec.rb:42               # single example
bundle exec rubocop                        # lint check
bundle exec rubocop -A                     # lint + autofix
```

Justfile shortcuts: `just test`, `just format`, `just format-check`.

## Architecture

SDK sem dependências de runtime — apenas stdlib Ruby (`net/http`, `json`, `uri`). JSON:API v1.1 para todas as requests/responses. Header de autenticação: `Authorization: <token>` — **sem** prefixo `Bearer`.

### Camadas

```
Clicksign.configure / Clicksign::Services  →  configuração e scoping de cliente
Clicksign::Client / BulkOperationsClient   →  HTTP, retry, instrumentação
Clicksign::Resource (base)                 →  CRUD, QueryProxy, paginação
lib/clicksign/resources/**                 →  recursos concretos
lib/clicksign/json_api/**                  →  parser, serializer, query_builder, operations
```

### Padrões críticos

**`@_parent_id`** — recursos nested (Signer, Document, Requirement, etc.) armazenam o ID do pai para que `reload`/`update`/`delete` construam o path correto sem re-fetch.

**`QueryProxy`** — mutável in-place. Toda chamada a `filter`/`order`/`page`/`per`/`fields`/`with_includes` muta o `@builder` da proxy e retorna `self`. Referência guardada antes de encadear acumula todos os params da chain.

**`QueryBuilder.include`** — acumula e deduplica chamadas sucessivas. `with_includes('a').with_includes('b')` → `include=a,b`.

**`build_instance(nil)`** → `NotFoundError`. API JSON:API pode retornar `{ data: null }`. Guards em `build_instance`, `update` e `reload`.

**`BulkOperationsClient`** retenta apenas `TimeoutError`, não `ServerError` — comportamento intencional.

**`Instrumentation.@callbacks`** protegido por `Mutex` — `on` e `publish` são thread-safe.

**`Thread.current[:clicksign_client]`** — incompatível com Fiber-based runtimes (Falcon/async-ruby).

**`build_uri`** com path contendo query string existente sobrescreve essa query — sempre passar params via hash, nunca embutir query no path.

### Resources

`Resource.create` base serializa `**attributes` em JSON:API e faz `POST endpoint`. Só precisa de override quando:
- há **relacionamentos** a embutir (ex: `Envelope` com `folder`)
- endpoint é **nested** (ex: `Signer`, `Document`)
- payload tem estrutura especial fora de `attributes` (ex: `Event` com `content_base64` no nível raiz)

`Event` não suporta `retrieve`/`update`/`delete`/`reload` (API só expõe list e create). Helpers:
- `Event.create_add_image(envelope_id:, document_id:, title:, occurred_at:, content_base64:)`
- `Event.create_custom(envelope_id:, document_id:, kind:, occurred_at:, signer_name:, ...)` — `kind`: `token_email` | `token_sms`; `ArgumentError` antes da request se inválido

### Versão

`VERSION` lido de `REVISION` em load time. Para release: atualizar `REVISION`, push para `release/*` → CI roda testes + rubocop → publica no RubyGems + cria tag `vX.Y.Z`. Requer secret `RUBYGEMS_API_KEY` no repositório.

## Spec conventions

- WebMock + `JsonApiFixtures` — sem VCR, sem rede real
- `include_context 'with clicksign configured'` em todo resource spec
- IDs: padrão `'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'` — nunca UUIDs reais
- Todo resource spec tem `describe 'resource configuration'` com `resource_type` e `endpoint`
- Rotas com `except: [:update]` → `def update(**); raise NotImplementedError`
- `stub_request(:get, url)` sem `.with(query:)` não casa com requests com query params
- `spec_helper.rb`: `Clicksign.reset!` (before) e `Clicksign::Instrumentation.clear` (after) por exemplo

## Instrumentação

```ruby
Clicksign.on_request { |e| }  # { method:, path:, status:, attempt:, duration_ms: }
Clicksign.on_retry   { |e| }  # { method:, path:, attempt:, max_retries:, error:, wait_ms: }
Clicksign.on_error   { |e| }  # { method:, path:, status:, error:, duration_ms: }
```

Callbacks isolados com `rescue StandardError`; erros logados via `config.logger&.warn`.

## Skills

- `/gen-resource <name>` — gera resource + spec a partir da fonte de verdade da API
- `/sync-spec` — compara rotas da API com resources do SDK, lista gaps
- `/release` — checklist de release

## Comments

Só o WHY não-óbvio. Nunca o quê (código bem nomeado já faz isso).
