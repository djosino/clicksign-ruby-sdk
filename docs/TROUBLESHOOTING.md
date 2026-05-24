# Troubleshooting — Clicksign Ruby SDK

Guia **sintoma → causa provável → o que fazer**. Para exemplos de configuração, veja o [Cookbook](examples/) e o [README](../README.md).

---

## Diagnóstico rápido

Antes de abrir chamado ou debugar em profundidade, confira:

| Pergunta | Se “não”, investigue |
|----------|----------------------|
| Token é do **mesmo ambiente** que `environment` / `base_url`? | [401 / 403](#authenticationerror-401-403) |
| Envelope está em **`draft`** para criar/remover requirements? | [ValidationError — envelope](#validationerror-400-422) |
| IDs (`envelope_id`, `document_id`, `signer_id`) são UUIDs válidos da **mesma conta**? | [NotFoundError](#notfounderror-404) |
| Em multi-tenant, a chamada está dentro de `service.use`? | [Token errado / conta B](#token-da-conta-errado-multi-tenant) |
| `BulkRequirement` retornou `success?` antes de `update(status: 'running')`? | [Bulk — falha parcial](#bulkrequirement--falha-parcial-sem-exceção) |
| Webhook usa `request.raw_post` e header `Content-HMAC`? | [WebhookSignatureError](#webhooksignatureerror) |

### Inspecionar qualquer exceção `Clicksign::Error`

```ruby
rescue Clicksign::Error => e
  puts e.class.name
  puts e.message
  puts "status: #{e.status_code}"
  puts "request_id: #{e.request_id}"
  puts e.response_body # JSON bruto da API
end
```

---

## Por tipo de exceção

### `AuthenticationError` (401 / 403)

**Sintomas:** todas ou quase todas as chamadas falham; mensagem de não autorizado.

**Causas comuns:**

- `CLICKSIGN_API_KEY` inválido, revogado ou de outro ambiente.
- Sandbox token com `environment: :production` (ou o inverso).
- Header esperado pela API: `Authorization: <token>` **sem** `Bearer`.

**O que fazer:**

```ruby
Clicksign.configure do |c|
  c.api_key     = ENV.fetch('CLICKSIGN_API_KEY')
  c.environment = :sandbox  # token gerado no painel sandbox
end
```

Gere um novo token no painel do ambiente correto. Em multi-tenant, confira o token **dentro** do bloco `use` ([04-multi-client](examples/04-multi-client.md)).

---

### `NotFoundError` (404)

**Sintomas:** `retrieve`, nested routes ou `Requirement.retrieve` falham.

**Causas comuns:**

- UUID incorreto ou recurso de outra conta.
- Rota aninhada sem `envelope_id` (ex.: documento listado sem `parent_id`).
- Requirement removido ou envelope já encerrado.

**O que fazer:**

- Confirme o ID na API ou via `Envelope.retrieve(id)`.
- Para recursos aninhados, use os helpers do SDK (`Document.create(envelope_id: ...)`, `Requirement.retrieve(id, envelope_id: ...)`).
- Liste relações: `Envelope.list_documents(envelope.id)`.

---

### `ValidationError` (400 / 422)

**Sintomas:** `create` / `update` rejeitados; `e.message` com um ou mais `detail` da API.

**Causas comuns:**

| Situação | Detalhe |
|----------|---------|
| Requirements em envelope **`running`** | Só é possível criar/remover requisitos em **`draft`** |
| Ativar sem requisitos | Falta `agree` / `provide_evidence` para signatário+documento |
| Documento inválido | `content_base64` sem prefixo `data:application/pdf;base64,...` ou template com extensão errada |
| Signatário | E-mail/telefone/documentação inconsistentes com `has_documentation` |
| Webhook | `endpoint` ausente ou URL inválida |
| Bulk top-level | Erro no envelope inteiro → **exceção** (não `response.failures`) |

**O que fazer:**

```ruby
rescue Clicksign::ValidationError => e
  puts e.response_body  # array errors[] completo
  envelope = Envelope.retrieve(envelope_id)
  puts envelope.status  # deve ser "draft" para alterar requirements
end
```

Fluxo correto: draft → documento → signatário → requirements → `update(status: 'running')`. Ver [WORKFLOW.md](WORKFLOW.md).

---

### `ConflictError` (409)

**Sintomas:** operação rejeitada por estado conflitante.

**Causas comuns:** recurso já existe, transição de status inválida, duplicidade de relacionamento.

**O que fazer:** leia `e.message` e `response_body`; use `retrieve` para estado atual; evite repetir POST idempotente sem checar existência.

---

### `RateLimitError` (429)

**Sintomas:** muitas requisições em curto intervalo; `e.retryable?` é `true`.

**O que fazer:**

- Ative retry: `c.max_retries = 3` ([01-retries](examples/01-retries.md)).
- Use `e.rate_limit_reset` e `e.rate_limit_remaining` para backoff manual em jobs.
- Reduza concorrência (menos workers disparando sync em massa).

---

### `ServerError` (5xx)

**Sintomas:** falha transitória no servidor Clicksign; `retryable?` é `true` no `Client`.

**O que fazer:**

- Configure `max_retries` e monitore `Clicksign.on_retry`.
- Se persistir, abra suporte com `e.request_id` e horário da falha.
- **BulkRequirement:** 5xx **não** dispara retry automático no bulk client — só timeout; repita a operação manualmente ou use requirement individual.

---

### `TimeoutError`

**Sintomas:** `Net::OpenTimeout`, `Net::ReadTimeout`, `ECONNREFUSED`; sem `status_code` HTTP.

**Causas comuns:**

- PDF grande com `read_timeout` baixo (padrão 10s).
- Rede/firewall bloqueando saída HTTPS.
- API lenta; thread do Sidekiq presa com timeout alto demais.

**O que fazer:**

```ruby
Clicksign.configure do |c|
  c.read_timeout  = 60
  c.write_timeout = 60
  c.open_timeout  = 5
  c.max_retries   = 2
end
```

Em jobs, alinhe timeout da gem com `sidekiq_options timeout:`.

---

### `WebhookSignatureError`

**Sintomas:** controller retorna 401; assinatura sempre inválida.

**Causas comuns:**

| Erro | Correção |
|------|----------|
| Body alterado antes do HMAC | Use `request.raw_post` (Rails), não `params` ou JSON re-serializado |
| Header errado | `Content-HMAC` (não `X-` alternativo sem confirmar na doc Clicksign) |
| Secret errado | Secret do **mesmo** webhook cadastrado (`hook.secret` na criação) |
| Prefixo | Valor deve bater com `sha256=<hex>` como em `compute_signature` |

**O que fazer:**

```ruby
payload   = request.raw_post
signature = request.headers['Content-HMAC']
Clicksign::Webhook.verify_signature!(payload, signature, secret: ENV.fetch('CLICKSIGN_WEBHOOK_SECRET'))
```

Teste local: [03-webhooks](examples/03-webhooks.md).

---

### `Error` genérico (outros códigos HTTP)

**Sintomas:** status não mapeado na tabela padrão (ex.: 402, 418).

**O que fazer:** trate como erro não retryable; inspecione `status_code` e `response_body`; consulte documentação da API para o código específico.

---

## Cenários frequentes (sem exceção óbvia)

### Token da conta errado (multi-tenant)

**Sintoma:** dados de outra empresa, 404 em massa, ou 401 intermitente.

**Causa:** chamada `Resources::*` **fora** de `tenant.clicksign_service.use`.

**Correção:**

```ruby
current_tenant.clicksign_service.use do
  Envelope.list  # usa token do tenant
end
```

Fora do bloco vale `Clicksign.client` global — pode ser token default errado.

---

### `BulkRequirement` — falha parcial sem exceção

**Sintoma:** código segue após `create`, mas envelope sem todos os requisitos.

**Causa:** API retornou `atomic:results` com slot em erro; Ruby não levantou exceção.

**Correção:**

```ruby
response = BulkRequirement.create(envelope_id: envelope.id) { |ops| ... }

unless response.success?
  response.failures.each { |f| Rails.logger.error(f.errors) }
  raise "Setup de assinatura incompleto"
end
```

Ver [02-bulk-requirements](examples/02-bulk-requirements.md).

---

### Retry não acontece

**Sintoma:** 500 ou 429 falha na primeira tentativa.

| Verificar | Valor esperado |
|-----------|----------------|
| `max_retries` | `> 0` |
| Tipo de erro | `ServerError`, `RateLimitError`, `TimeoutError` |
| Client | Resources usam `Client`; bulk só retenta **timeout** (ambos publicam hooks `:request`/`:error`) |
| `ValidationError` | Nunca retenta (corrigir payload) |

---

### Instrumentação “some” erro do callback

**Sintoma:** bug no `on_request` não aparece na requisição.

**Causa:** callbacks não propagam exceção (por design).

**Correção:** defina `config.logger`; erros em callbacks vão para `logger.warn`:

```ruby
Clicksign.configure { |c| c.logger = Rails.logger }
```

---

### `list` vs `filter` — tipo inesperado

**Sintoma:** `filter` não itera como `Array`; ou `list(status: 'x')` levanta `ArgumentError`.

| Esperado | API |
|----------|-----|
| Lista simples (1ª página) | `Webhook.list` → `Array` |
| Com filtros / ordenação | `Envelope.filter(status: 'draft').to_a` |
| Chain sem materializar | `Envelope.filter(...).order(...)` → `QueryProxy` |

`list` **não** aceita argumentos. Guia: [examples/07-list-and-filter.md](examples/07-list-and-filter.md).

---

### Paginação / lista vazia inesperada

**Sintoma:** `.filter(...).to_a` retorna `[]` mas há dados no painel.

**Causas:** filtro incorreto (`status`, `name`); conta/ambiente errado; primeira página só — use `.auto_paging_each` para percorrer todas as páginas.

```ruby
Envelope.filter(status: 'running').auto_paging_each { |e| puts e.id }
```

**Nota:** `auto_paging_each` / `each_page` param quando `links.next` é `null` ou ausente (JSON:API). Se a API **não** enviar `links`, a gem usa heurística `page[size]` (pode haver 1 GET extra quando a última página vem cheia).

---

### Atributo “não existe” no resource

**Sintoma:** `NoMethodError` para método de atributo.

**Causa:** atributo não veio na resposta JSON:API (campos omitidos, `fields` restritivo).

**Correção:** use `envelope['nome_do_campo']` ou `include` / reload; confira payload em `e.response_body` em erros de validação.

---

## Alta carga / lentidão

**Sintoma:** app lenta sob concorrência; muitas conexões; CPU em TLS.

**Causas:** a gem abre **nova conexão TCP por request** (`Net::HTTP.start`) — sem pool. Normal no design stdlib-only.

**O que fazer:** menos chamadas por request, `BulkRequirement`, jobs em fila, cache; medir com `on_request` (`duration_ms`). Ver [examples/08-production-limitations.md](examples/08-production-limitations.md).

---

## Falcon / async / token errado em Fiber

**Sintoma:** em Falcon ou async-ruby, chamadas usam token global ou falham após `Services#use`.

**Causa:** client em `Thread.current[:clicksign_client]` não propaga para Fibers filhos.

**Correção:** `Clicksign.configure` por processo (single-tenant) ou não usar `Services#use` em código fiberizado. Ver [08-production-limitations.md](examples/08-production-limitations.md).

---

## Checklist de produção

- [ ] `environment` alinhado ao token (sandbox vs produção)
- [ ] Timeouts adequados a tamanho de PDF e SLA do job
- [ ] `max_retries` > 0 apenas onde retry automático faz sentido
- [ ] Multi-tenant sempre em `Services#use`
- [ ] Bulk: checar `response.success?` antes de ativar envelope
- [ ] Webhooks: HMAC no raw body, processamento assíncrono, idempotência
- [ ] Logs com `request_id` em erros para suporte Clicksign

---

## Onde ir a seguir

| Tópico | Documento |
|--------|-----------|
| Retries, rate limit | [examples/01-retries.md](examples/01-retries.md) |
| Bulk / atomic:results | [examples/02-bulk-requirements.md](examples/02-bulk-requirements.md) |
| Webhooks | [examples/03-webhooks.md](examples/03-webhooks.md) |
| Multi-conta | [examples/04-multi-client.md](examples/04-multi-client.md) |
| Fluxo notarial | [WORKFLOW.md](WORKFLOW.md) |
| Rotas e resources | [SPEC.md](SPEC.md) |
| Arquitetura da gem | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Observabilidade | [OBSERVABILITY.md](OBSERVABILITY.md) |
| List vs filter | [examples/07-list-and-filter.md](examples/07-list-and-filter.md) |
| Limitações (pool, Fibers) | [examples/08-production-limitations.md](examples/08-production-limitations.md) |
| API oficial | [developers.clicksign.com](https://developers.clicksign.com/) |
