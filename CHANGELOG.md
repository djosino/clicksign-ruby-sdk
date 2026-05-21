# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.3] — 2026-05-20

### Added

- `Clicksign::RetryBackoff` — backoff exponencial com **full jitter**, compartilhado por `Client` e `BulkOperationsClient`
- `Configuration#logger` — log opcional de erros em callbacks de instrumentação
- Arquivo `REVISION` como fonte única da versão da gem
- `docs/cookbook/` — receitas de retries, bulk requirements, webhooks, multi-cliente, list vs filter e limitações de produção
- `docs/TROUBLESHOOTING.md` — guia sintoma → causa → correção
- `docs/ARCHITECTURE.md` — diagramas (Mermaid) e camadas da gem
- `docs/OBSERVABILITY.md` — hooks, logs, métricas e exemplo OpenTelemetry
- `docs/README.md` — índice da documentação
- `docs/WORKFLOW.md` — alinhado a `environment`, links para cookbook e troubleshooting
- `RequestInstrumentation` — módulo compartilhado entre `Client` e `BulkOperationsClient`

### Fixed

- `Resource.include` não sombreia mais `Module#include` — módulos Ruby em subclasses voltam a funcionar; strings/símbolos continuam em JSON:API sideload (`with_includes` como API explícita)
- `infer_resource_type` não quebra em classe anônima (`name` nil) — fallback `'resources'`
- `BulkOperationsClient` publica eventos `:request`, `:retry` e `:error` (via `RequestInstrumentation`)
- Auto-pagination usa `links.next` quando a API envia `links` — evita requisição extra na última página cheia; fallback por tamanho da página se `links` ausente

### Changed

- `Resource.list` não aceita mais `**filters` — use `filter(...).to_a` para consultas com critérios; `list` retorna sempre `Array` (primeira página)
- `Clicksign::VERSION` lê de `REVISION` em vez de constante fixa no código
- `Instrumentation#publish` emite `logger.warn` quando um callback falha e `config.logger` está definido (comportamento silencioso permanece o padrão)
- README: seções de multi-conta (`Services`, `Client`), timeouts, retry, instrumentação, `environment` e limitações de produção (sem pool, Fibers)
- README: retry documentado com full jitter; removida referência a VCR nos testes

---

## [0.1.2] — 2026-05-20

### Added

- Cobertura de testes ampliada na quarta passagem de revisão — resources, `QueryProxy` (auto-pagination), `Serializer`, `Client` (retry), `BulkOperationsClient` (timeout/retry), integração de `Instrumentation`
- Specs para `Membership`, `TemplateField`, `AutoSignature::Term`, fluxos notariais (`Envelope`, `Document`, `Signer`, `Event`, `Requirement`) e demais resources sem cobertura dedicada

### Changed

- Padronização de estrutura dos specs (`describe`/`context`, agrupamento de exemplos)

---

## [0.1.1] — 2026-05-20

### Fixed

- `BulkOperationsClient#execute_with_retry`: retry logic era código morto — corrigido extraindo `safe_http_post`
- `BulkOperationsClient#parse_response_body`: `JSON::ParserError` não era capturado para body inválido
- `ErrorHandler#extract_message`: `JSON.parse(nil)` levantava `TypeError` quando body é nil/vazio
- `Instrumentation#publish`: exceção em callback propagava para a requisição — agora isolada
- `Resource#[]`: safe navigation `&.[]` evita `NoMethodError` antes de `load_data`
- `AtomicResultsParser.parse`: `raw ||= {}` evita `NoMethodError` quando recebe nil

### Changed

- `BulkOperationsClient` retry agora funciona corretamente para timeouts de rede
- `QueryBuilder#filter` aceita `false` como valor; `#fields` aceita string além de array
- `requirement_list_spec.rb` consolidado em `requirement_spec.rb`

---

## [0.1.0] — 2026-05-20

### Added

- Full JSON:API CRUD via `Clicksign::Resource` — `list`, `retrieve`, `create`, `update`, `delete`
- Chainable `QueryProxy` — `filter`, `include`, `order`, `page`, `per`, `fields`
- Auto-pagination — `auto_paging_each`, `each_page`, `auto_paging` (lazy Enumerator)
- Resources: `Envelope`, `Document`, `Signer`, `Requirement`, `BulkRequirement`, `SignatureWatcher`, `Webhook`, `User`, `Membership`, `Group`, `Template`, `TemplateField`, `Folder`, `EnvelopeBulkCreation`, `AccessControlList`
- JSON:API Atomic Operations via `BulkOperationsClient`
- Configurable timeouts — `open_timeout`, `read_timeout`, `write_timeout`
- Automatic retry with exponential backoff for retryable errors (5xx, 429, timeout)
- Structured errors — `status_code`, `request_id`, `response_body`, `retryable?`
- `RateLimitError` with `rate_limit_remaining` and `rate_limit_reset`
- `Clicksign::Services` for isolated client contexts (multi-tenant, thread-safe)
- `Clicksign::Webhook.verify_signature!` with constant-time HMAC comparison
- `Clicksign::Instrumentation` hooks — `:request`, `:retry`, `:error` events
- `environment=` shortcut on `Configuration` (`:sandbox`, `:production`)
- No runtime gem dependencies — pure Ruby stdlib (`net/http`, `json`, `uri`)
