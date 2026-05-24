# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.7] — 2026-05-24

### Fixed

- `gemspec` — `REVISION` adicionado a `spec.files`; instalação via RubyGems não quebra mais com `Errno::ENOENT` ao carregar a versão
- `Client` — `Net::WriteTimeout` adicionado ao rescue de erros de rede; uploads grandes não levantam mais exceção não resgatada
- `Webhook.compute_signature` — levanta `ArgumentError` quando `secret` é nil ou vazio; HMAC com secret vazio agora é detectado no boot
- `Webhook.secure_compare?` — substituído double-hash + XOR manual por `OpenSSL.fixed_length_secure_compare`; corrigida coerção de `actual` via `is_a?(String)` (bug com header Rack como Array)
- `Serializer.dump` — `attributes` agora tem default `{}` e fallback `|| {}`; `nil` não produz mais JSON:API inválido
- `AtomicResultsParser.build_requirement` — guard refinado: retorna nil apenas para `data` nil ou sem `id`/`type`; `data: {}` de operações `remove` continua retornando nil
- `BulkRequirement.create` — levanta `ArgumentError` quando `envelope_id` é nil ou vazio antes de montar a URL
- `Parser.parse` — guard para `raw` nil retorna estrutura vazia em vez de `NoMethodError`
- `base_path` em Document, Signer, Requirement, SignatureWatcher — levanta `Clicksign::Error` descritivo quando `envelope_id` é nil em vez de interpolar nil silenciosamente na URL
- `BulkOperationsClient.handle_bulk_body` — `ErrorHandler.call` agora executa antes de retornar `{}` para respostas com body vazio; 500/401/422 com body vazio levantam a exceção correta

### Changed

- `docs/cookbook/` renomeado para `docs/examples/`; todas as referências atualizadas
- `ARCHITECTURE.md` — seção adicionada sobre padrão `@_parent_id` para recursos nested, incluindo fallback e comportamento de erro

---

## [0.1.6] — 2026-05-21

### Added

- GitHub Actions workflow `release.yml` — push em `release/*` roda testes (Ruby 3.0–3.4), RuboCop, publica a gem no RubyGems (versão lida de `REVISION`) e cria tag `vX.Y.Z`

---

## [0.1.5] — 2026-05-21

### Added

- `Event.create_add_image` — payload pré-montado para comprovante JPEG (`title`, `occurred_at`, `content_base64`)
- `Event.create_custom` — eventos `token_email` / `token_sms` com validação de `kind` (`ArgumentError` antes da request se inválido); atributos opcionais omitidos via `.compact`
- `Event#update`, `#delete` e `#reload` levantam `NotImplementedError` — API expõe apenas `GET` (list) e `POST` (create)

### Fixed

- `Webhook.verify_signature!` — assinatura nil/vazia levanta `WebhookSignatureError` em vez de `TypeError`
- `ErrorHandler#extract_message` — erros JSON:API sem `detail`/`title` retornam `response.message` em vez de string vazia
- `Resource` — `build_instance(nil)`, `update` e `reload` levantam `NotFoundError` quando a API retorna `data: null` (evita `NoMethodError` opaco)
- `BulkOperationsClient` — JSON inválido em resposta 2xx levanta `Clicksign::Error` explícito em vez de retornar `{}` silencioso
- `Instrumentation` — callbacks protegidos por `Mutex`; `on`/`publish` thread-safe; `publish` itera sobre cópia da lista de callbacks
- `QueryBuilder#include` — chamadas sucessivas a `with_includes`/`include` acumulam e deduplicam tipos (antes a última chamada sobrescrevia as anteriores)

### Changed

- README: aviso sobre `api_key` nil (erro só na primeira request — preferir `ENV.fetch`); fórmula exata do backoff full jitter; seção de eventos com `create_add_image`, `create_custom` e `create` (baixo nível)
- `docs/SPEC.md` — tabela de tipos de `Event` com atributos obrigatórios/opcionais; listagens aninhadas documentadas via `Envelope.list_*`

---

## [0.1.4] — 2026-05-20

### Added

- `docs/examples/07-list-and-filter.md` — guia `list` vs `filter` vs auto-pagination
- `docs/examples/08-production-limitations.md` — connection pool, Fibers e thread safety

### Changed

- README, `docs/ARCHITECTURE.md`, `docs/OBSERVABILITY.md` e `docs/TROUBLESHOOTING.md` — alinhados a `list` sem args, `links.next` e `with_includes`

---

## [0.1.3] — 2026-05-20

### Added

- `Clicksign::RetryBackoff` — backoff exponencial com **full jitter**, compartilhado por `Client` e `BulkOperationsClient`
- `Configuration#logger` — log opcional de erros em callbacks de instrumentação
- Arquivo `REVISION` como fonte única da versão da gem
- `docs/examples/` — receitas de retries, bulk requirements, webhooks e multi-cliente
- `docs/TROUBLESHOOTING.md` — guia sintoma → causa → correção
- `docs/ARCHITECTURE.md` — diagramas (Mermaid) e camadas da gem
- `docs/OBSERVABILITY.md` — hooks, logs, métricas e exemplo OpenTelemetry
- `docs/README.md` — índice da documentação
- `docs/WORKFLOW.md` — alinhado a `environment`, links para examples e troubleshooting
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
