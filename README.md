# Clicksign Ruby SDK

[![Gem Version](https://badge.fury.io/rb/clicksign-ruby-sdk.svg)](https://badge.fury.io/rb/clicksign-ruby-sdk)
[![CI](https://github.com/djosino/clicksign-ruby-sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/djosino/clicksign-ruby-sdk/actions/workflows/ci.yml)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.0-red)](https://www.ruby-lang.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](clicksign-ruby-sdk.gemspec)

Cliente Ruby não-oficial para a [API v3 da Clicksign](https://developers.clicksign.com/) (JSON:API). Permite criar envelopes, adicionar documentos e signatários, configurar requisitos de assinatura, webhooks e demais recursos da plataforma com uma API idiomática em Ruby.

**Requisitos:** Ruby >= 3.0 · dependências de runtime: apenas biblioteca padrão (`net/http`, `json`).

**Documentação:** [índice `docs/`](docs/) · [Workflow](docs/WORKFLOW.md) · [Cookbook](docs/examples/) · [Troubleshooting](docs/TROUBLESHOOTING.md) · [Arquitetura](docs/ARCHITECTURE.md) · [Observabilidade](docs/OBSERVABILITY.md) · [SPEC](docs/SPEC.md) · API: [Sandbox](https://sandbox.clicksign.com/api/v3) · [Produção](https://app.clicksign.com/api/v3)

---

## Índice

- [Instalação](#instalação)
- [Configuração](#configuração)
- [Multi-conta e cliente instanciável](#multi-conta-e-cliente-instantiável)
- [Timeouts, retry e instrumentação](#timeouts-retry-e-instrumentação)
- [Início rápido](#início-rápido)
- [Fluxo de assinatura (notarial)](#fluxo-de-assinatura-notarial)
- [Filtros, ordenação e paginação](#filtros-ordenação-e-paginação)
- [Outros recursos](#outros-recursos)
- [Tratamento de erros](#tratamento-de-erros)
- [Ambientes](#ambientes)
- [Limitações e produção](#limitações-e-produção)
- [Desenvolvimento](#desenvolvimento)
- [Licença](#licença)

> **Exemplo passo a passo:** [`docs/WORKFLOW.md`](docs/WORKFLOW.md) — fluxo completo de envelope → documento → signatário → requisitos → ativação → notificação.

> **Cookbook (receitas por cenário):** [`docs/examples/`](docs/examples/) — [retries](docs/examples/01-retries.md), [bulk requirements](docs/examples/02-bulk-requirements.md), [webhooks](docs/examples/03-webhooks.md), [vários clientes](docs/examples/04-multi-client.md), [list vs filter](docs/examples/07-list-and-filter.md), [limitações de produção](docs/examples/08-production-limitations.md).

> **Troubleshooting:** [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) — sintoma → causa → correção (erros HTTP, multi-tenant, bulk parcial, webhooks).

> **Arquitetura e observabilidade:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · [`docs/OBSERVABILITY.md`](docs/OBSERVABILITY.md)

---

## Instalação

Adicione ao `Gemfile`:

```ruby
source 'https://rubygems.org'

gem 'clicksign-ruby-sdk'
```

Depois:

```bash
bundle install
```

Ou instale diretamente:

```bash
gem install clicksign-ruby-sdk
```

---

## Configuração

A forma mais simples é a configuração global no boot da aplicação (initializer, `config/initializers/clicksign.rb`, script, etc.):

```ruby
require 'clicksign'

Clicksign.configure do |c|
  c.api_key  = ENV.fetch('CLICKSIGN_API_KEY')
  c.environment = :sandbox   # ou :production — define base_url automaticamente
  # c.base_url = '...'      # opcional: sobrescreve o URL do ambiente
  c.open_timeout  = 2       # segundos (padrão)
  c.read_timeout  = 10
  c.write_timeout = 10
  c.max_retries   = 0       # retentativas automáticas (ver seção abaixo)
end
```

| Opção | Padrão | Descrição |
|-------|--------|-----------|
| `api_key` | — | Token da API (obrigatório) |
| `environment` | — | `:sandbox` ou `:production` (atalho para `base_url`) |
| `base_url` | produção | URL completa da API v3 |
| `open_timeout` | `2` | Timeout de conexão (s) |
| `read_timeout` | `10` | Timeout de leitura (s) |
| `write_timeout` | `10` | Timeout de escrita (s) |
| `max_retries` | `0` | Retentativas em erros transitórios |

A API usa o header `Authorization: <seu-token>` **sem** o prefixo `Bearer`.

> **Segurança:** não commite tokens no código. Use variáveis de ambiente ou cofre de secrets (Rails credentials, etc.).

> **`api_key` é obrigatório em runtime:** o SDK não valida a presença do token no boot. Se `api_key` for `nil`, nenhum erro é levantado no `configure` — o `AuthenticationError` só aparece na primeira request HTTP. Use `ENV.fetch('CLICKSIGN_API_KEY')` (em vez de `ENV[]`) para detectar a ausência da variável no startup da aplicação.

> **Multi-conta / multi-tenant:** se cada requisição pode usar credenciais diferentes (SaaS, workers por cliente), prefira [`Clicksign::Services`](#multi-conta-e-cliente-instantiável) em vez da config global.

Para testar interativamente no console da gem:

```bash
CLICKSIGN_API_KEY=seu-token bundle exec ruby bin/console
```

---

## Multi-conta e cliente instanciável

Além da config global, a gem oferece clientes isolados por contexto — útil em apps multi-tenant, jobs Sidekiq com token por conta e testes paralelos.

### `Clicksign::Services` (recomendado para resources)

Encapsula um `Clicksign::Client` e roteia todas as chamadas de `Clicksign::Resources::*` dentro do bloco `use`:

```ruby
conta_a = Clicksign::Services.new(
  api_key: ENV['CLICKSIGN_TOKEN_CONTA_A'],
  environment: :production,
  max_retries: 2
)

conta_b = Clicksign::Services.new(
  api_key: ENV['CLICKSIGN_TOKEN_CONTA_B'],
  environment: :sandbox
)

conta_a.use do
  Clicksign::Resources::Notarial::Envelope.create(name: 'Contrato A')
end

conta_b.use do
  Clicksign::Resources::Notarial::Envelope.filter(status: 'draft').to_a
end
```

O client ativo fica em `Thread.current` durante o bloco; blocos aninhados restauram o client externo ao sair. Fora de `use`, os resources voltam a usar `Clicksign.client` (config global).

Em Rails, um padrão comum é resolver o service no controller e executar a lógica dentro de `use`:

```ruby
class EnvelopesController < ApplicationController
  def create
    current_tenant.clicksign_service.use do
      envelope = Clicksign::Resources::Notarial::Envelope.create(envelope_params)
      render json: { id: envelope.id }
    end
  end
end
```

### `Clicksign::Client` (HTTP direto)

Para chamadas JSON:API de baixo nível sem passar pelos resources:

```ruby
client = Clicksign::Client.new(
  api_key: ENV['CLICKSIGN_API_KEY'],
  base_url: 'https://sandbox.clicksign.com/api/v3',
  open_timeout: 2,
  read_timeout: 30,
  max_retries: 3
)

response = client.get('/envelopes', params: { 'filter[status]' => 'draft' })
client.post('/envelopes', body: { data: { type: 'envelopes', attributes: { name: 'Novo' } } })
```

| Abordagem | Quando usar |
|-----------|-------------|
| `Clicksign.configure` | App single-tenant; initializer único |
| `Clicksign::Services#use` | Multi-conta; token por request/job |
| `Clicksign::Client.new` | Controle fino do HTTP ou integração customizada |

---

## Timeouts, retry e instrumentação

### Timeouts

Configuráveis globalmente (`Clicksign.configure`), por `Services` ou diretamente em `Client.new`. Timeouts de rede disparam `Clicksign::TimeoutError` (retryable quando `max_retries > 0`).

### Retry automático

Com `max_retries > 0`, o client reexecuta a requisição em erros **transitórios**:

- `Clicksign::TimeoutError`
- `Clicksign::RateLimitError`
- `Clicksign::ServerError` (5xx)

Backoff exponencial com **full jitter**: espera aleatória uniforme em `[0, teto)` onde o teto cresce como `0.5s × 2^(tentativa-1)` (0,5s → 1s → 2s…) com cap de **30s**. O zero é possível — o jitter distribui a espera para evitar thundering herd. Após esgotar as retentativas, a exceção original é relançada.

```ruby
Clicksign.configure do |c|
  c.api_key     = ENV['CLICKSIGN_API_KEY']
  c.environment = :production
  c.max_retries = 3
end
```

Operações em lote (`BulkRequirement`) usam o mesmo `max_retries` e os mesmos hooks de instrumentação via `Clicksign.bulk_operations_client` (retry automático só em timeout).

### Instrumentação

Registre callbacks para observabilidade (logs, métricas, APM). Callbacks não propagam exceções — falhas internas são ignoradas para não afetar a requisição.

```ruby
Clicksign.on_request do |event|
  # event: :method, :path, :status, :duration_ms, :attempt
  Rails.logger.info "[Clicksign] #{event[:method]} #{event[:path]} → #{event[:status]} (#{event[:duration_ms]}ms)"
end

Clicksign.on_retry do |event|
  # event: :method, :path, :attempt, :max_retries, :error, :wait_ms
  Rails.logger.warn "[Clicksign] retry #{event[:attempt]}/#{event[:max_retries]} em #{event[:wait_ms]}ms"
end

Clicksign.on_error do |event|
  # event: :method, :path, :error, :status, :duration_ms
  Sentry.capture_exception(event[:error])
end
```

Eventos publicados: `:request` (toda tentativa, sucesso ou erro HTTP), `:retry` (antes de cada retentativa), `:error` (quando uma exceção é lançada).

---

## Início rápido

Listar envelopes em rascunho e criar um novo:

```ruby
require 'clicksign'

Clicksign.configure do |c|
  c.api_key  = ENV['CLICKSIGN_API_KEY']
  c.base_url = 'https://sandbox.clicksign.com/api/v3'
end

Envelope = Clicksign::Resources::Notarial::Envelope

# Listar com filtro
drafts = Envelope.filter(status: 'draft').to_a
puts drafts.map { |e| [e.id, e.name, e.status] }

# Criar envelope (status inicial: draft)
envelope = Envelope.create(
  name: 'Contrato de prestação de serviços',
  locale: 'pt-BR',
  auto_close: true
)

puts envelope.id    # UUID do envelope
puts envelope.status # => "draft"
```

Buscar, atualizar e excluir:

```ruby
found = Envelope.retrieve(envelope.id)
found.update(name: 'Contrato — revisão 2')

found.delete
```

---

## Fluxo de assinatura (notarial)

Namespace principal: `Clicksign::Resources::Notarial`.

### 1. Envelope

```ruby
Envelope = Clicksign::Resources::Notarial::Envelope
Folder   = Clicksign::Resources::Folder

# Opcional: associar a uma pasta
folder = Folder.filter(in_root: true).first
envelope = Envelope.create(
  name: 'Proposta comercial #1042',
  folder_id: folder&.id,
  deadline_at: '2026-12-31T23:59:59.000-03:00',
  default_subject: 'Documentos para assinatura',
  default_message: 'Por favor, assine os documentos em anexo.'
)
```

### 2. Documento

Envie o PDF em Base64, via URL ou a partir de um template:

```ruby
Document = Clicksign::Resources::Notarial::Document

document = Document.create(
  envelope_id: envelope.id,
  filename: 'contrato.pdf',
  content_base64: 'data:application/pdf;base64,JVBERi0xLjQK...'
)

# Alternativas (mutuamente exclusivas na API):
# content_url: 'https://exemplo.com/arquivo.pdf'
# template: { key: template_id, data: {} }  # filename deve ser .doc ou .docx

# Listar documentos do envelope
Envelope.list_documents(envelope.id).each do |doc|
  puts "#{doc.id} — #{doc.filename} (#{doc.status})"
end
```

### 3. Signatário

```ruby
Signer = Clicksign::Resources::Notarial::Signer

signer = Signer.create(
  envelope_id:      envelope.id,
  name:             'Maria Silva',
  email:            'maria.silva@example.com',
  phone_number:     '11999998888',
  has_documentation: true,
  documentation:    '12345678909',
  refusable:        true,
  communicate_events: {
    signature_request:  'email',   # canal de convite para assinar
    signature_reminder: 'email',   # canal de lembrete automático
    document_signed:    'email',   # canal de confirmação pós-assinatura
  },
)

# Reenviar notificação por e-mail
signer.notify(message: 'Lembrete: seu documento aguarda assinatura.')

# Ou via classe
Signer.notify(signer.id, envelope_id: envelope.id, message: 'Lembrete de assinatura')
```

### 4. Requisitos (requirements)

Cada requisito associa um signatário a um documento com uma ação (`agree`, `provide_evidence`, `rubricate`). O envelope precisa estar em **draft** para criar ou remover requisitos.

#### 4.1 Endpoint padrão

`POST /envelopes/:envelope_id/requirements` — uma operação por requisição.

```ruby
Requirement = Clicksign::Resources::Notarial::Requirement

rels = {
  document: { data: { type: 'documents', id: document.id } },
  signer:   { data: { type: 'signers',   id: signer.id } },
}

# Concordância (agree)
agree = Requirement.create(
  envelope_id: envelope.id,
  action: 'agree',
  role: 'sign',
  relationships: rels
)

# Evidência de autenticação (ex.: e-mail)
Requirement.create(
  envelope_id: envelope.id,
  action: 'provide_evidence',
  auth: 'email',
  relationships: rels
)

# Rubrica em todas as páginas
Requirement.create(
  envelope_id: envelope.id,
  action: 'rubricate',
  pages: 'all',
  relationships: rels
)

# Rubrica em campo específico do documento
Requirement.create(
  envelope_id: envelope.id,
  action: 'rubricate',
  rubric_field: 'campo_rubrica_1',
  relationships: rels
)

# Consultar
Requirement.retrieve(agree.id, envelope_id: envelope.id)
Envelope.list_requirements(envelope.id, 'signer.key': signer.id)
Requirement.list_for_document(document.id)
Requirement.list_for_signer(signer.id)

# Remover (envelope em draft)
agree.delete
```

#### 4.2 Operações em lote (bulk)

`POST /envelopes/:envelope_id/bulk_requirements` — várias operações em uma requisição (`atomic:operations` → `atomic:results`). Indicado quando você monta o setup completo de uma vez.

```ruby
BulkRequirement = Clicksign::Resources::Notarial::BulkRequirement

response = BulkRequirement.create(envelope_id: envelope.id) do |ops|
  ops.add_agree(
    signer_id: signer.id,
    document_id: document.id,
    role: 'sign'
  )
  ops.add_provide_evidence(
    signer_id: signer.id,
    document_id: document.id,
    auth: 'email'
  )
  ops.add_rubricate(
    signer_id: signer.id,
    document_id: document.id,
    pages: 'all'
  )
  # ops.remove(requirement_id: requisito_antigo.id)
end

if response.success?
  response.requirements.each { |r| puts "OK: #{r.id} (#{r.action})" }
else
  response.failures.each do |failure|
    puts "Falha na operação #{failure.index}: #{failure.errors}"
  end
end
```

| Abordagem | Endpoint | Quando usar |
|-----------|----------|-------------|
| **4.1 Padrão** | `/requirements` | Criar/alterar requisitos um a um, fluxos incrementais |
| **4.2 Bulk** | `/bulk_requirements` | Várias ações na mesma chamada; tratar sucesso/falha por slot |

### 5. Ativar o envelope

Atualize o `status` para `running` via PATCH:

```ruby
activated = envelope.update(status: 'running')
puts activated.status # => "running"
```

### 6. Observadores e eventos

```ruby
SignatureWatcher = Clicksign::Resources::Notarial::SignatureWatcher
Event            = Clicksign::Resources::Notarial::Event

watcher = SignatureWatcher.create(
  envelope_id: envelope.id,
  email: 'compliance@empresa.com',
  kind: 'all_steps',
  attach_documents_enabled: true
)

# Eventos do envelope
Envelope.list_events(envelope.id)

# Eventos de um documento
Document.list_events(document.id, envelope_id: envelope.id)

# Criar evento de imagem no documento (comprovante JPEG)
Event.create_add_image(
  envelope_id: envelope.id,
  document_id: document.id,
  title: 'Comprovante de identidade',
  occurred_at: Time.now.iso8601,
  content_base64: 'data:image/jpeg;base64,...'
)

# Criar evento customizado — token_email ou token_sms
Event.create_custom(
  envelope_id: envelope.id,
  document_id: document.id,
  kind: 'token_email',           # ou 'token_sms'
  occurred_at: Time.now.iso8601,
  signer_name: 'Maria Silva',
  signer_email: 'maria@empresa.com',
  # signer_phone_number: '11988887777'  # obrigatório quando kind: 'token_sms'
)

# API de baixo nível — qualquer name customizado
Event.create(
  envelope_id: envelope.id,
  document_id: document.id,
  name: 'custom',
  data: { kind: 'token_email', signer_name: 'Maria Silva',
          signer_email: 'maria@empresa.com', occurred_at: Time.now.iso8601 }
)
```

---

## Filtros, ordenação e paginação

### `list` vs `filter`

| Método | Retorno | Uso |
|--------|---------|-----|
| `Resource.list` | `Array` | Primeira página da collection, **sem** filtros na chain |
| `Resource.filter(...)` | `QueryProxy` | Filtros, ordenação, paginação, includes — termine com `.to_a`, `.first`, `.auto_paging_each`, etc. |

`list` **não** aceita argumentos. Para filtrar: `Envelope.filter(status: 'draft').to_a` (não `Envelope.list(status: 'draft')`).

Guia completo: [`docs/examples/07-list-and-filter.md`](docs/examples/07-list-and-filter.md).

```ruby
# Sem filtros — retorna Array imediatamente
Webhook.list

# Com filtros ou chain — começa em filter
Envelope.filter(status: 'draft').to_a
```

### Chain de consulta

```ruby
Envelope
  .filter(status: 'running', name: 'Contrato')
  .with_includes('folder')   # sideload JSON:API (.include('folder') também funciona)
  .order('-created')
  .page(1)
  .per(20)
  .to_a

Template.filter(name: 'NDA padrão').first

Envelope.order('-created').first
Envelope.filter(status: 'draft').count
```

Atributos dos objetos retornados são acessados como métodos ou por chave string:

```ruby
envelope.name          # método gerado dinamicamente
envelope['name']       # equivalente via operador []
envelope['status']     # útil quando a chave é uma variável
```

O `QueryProxy` inclui `Enumerable`, então `each`, `map`, `select` e afins funcionam diretamente na chain sem precisar de `.to_a`:

```ruby
Envelope.filter(status: 'draft').each { |e| puts e.id }
Envelope.filter(status: 'running').map(&:name)
Envelope.order('-created').select { |e| e.auto_close }
```

Percorrer **todas** as páginas automaticamente (`auto_paging_each`, `each_page`, `auto_paging`): a gem segue `links.next` da JSON:API quando presente; se a API não enviar `links`, usa heurística por `page[size]`.

---

## Outros recursos

| Recurso | Classe | Exemplo |
|---------|--------|---------|
| Webhook | `Clicksign::Resources::Webhook` | `Webhook.create(endpoint: 'https://...', events: ['envelope.completed'], status: 'active')` |
| Pasta | `Clicksign::Resources::Folder` | `Folder.create(name: 'Contratos 2026', folder_id: pai&.id)` |
| Template | `Clicksign::Resources::Template` | `Template.list` · `Template.filter(name: '...')` · `Template.list_template_fields(id)` |
| Usuário | `Clicksign::Resources::User` | `User.me` · `User.list` · `User.filter(email: '...')` |
| Membership | `Clicksign::Resources::Membership` | `Membership.create(role: 'member', user_id: user.id)` |
| Grupo | `Clicksign::Resources::Group` | `Group.add_users(group_id, [user.id])` |
| ACL pasta/grupo | `Clicksign::Resources::AccessControlList` | `AccessControlList.create(folder_id:, group_id:)` |
| Criação em lote de envelopes | `Clicksign::Resources::EnvelopeBulkCreation` | Ver exemplo abaixo |
| Auto assinatura | `Clicksign::Resources::AutoSignature::Term` | `AutoSignature::Term.create(...)` |
| Termo WhatsApp | `Clicksign::Resources::AcceptanceTerm::Whatsapp` | `AcceptanceTerm::Whatsapp.list` |

Exemplo de webhook:

```ruby
Webhook = Clicksign::Resources::Webhook

hook = Webhook.create(
  endpoint: 'https://minhaapp.com/webhooks/clicksign',
  events: %w[sign close cancel add_signer],
  status: 'active'
)

hook.update(status: 'inactive')
hook.delete
```

Exemplo de usuário e membership:

```ruby
User       = Clicksign::Resources::User
Membership = Clicksign::Resources::Membership

eu = User.me
puts "#{eu.name} <#{eu.email}>"

novo = User.create(
  name: 'João Integração',
  email: 'joao.integracao@example.com',
  phone_number: '11988887777'
)

Membership.create(role: 'admin', user_id: novo.id)
```

Criação de envelope em lote (job assíncrono):

```ruby
EnvelopeBulkCreation = Clicksign::Resources::EnvelopeBulkCreation

job = EnvelopeBulkCreation.create(
  envelope: { name: 'Contrato Lote', locale: 'pt-BR', auto_close: true },
  document: {
    filename: 'contrato.docx',
    content_base64: 'data:application/msword;base64,...'
  },
  signers: [
    {
      name: 'Carlos',
      email: 'carlos@example.com',
      requirements: [{ action: 'agree', role: 'sign', auth: 'email' }]
    }
  ]
)

puts job.job_id      # UUID do job enfileirado
puts job.enqueued_at # timestamp de enfileiramento
```

Controle de acesso em pasta:

```ruby
AccessControlList = Clicksign::Resources::AccessControlList

AccessControlList.create(folder_id: folder.id, group_id: group.id)
AccessControlList.destroy(folder_id: folder.id, group_id: group.id)
```

---

## Tratamento de erros

Erros HTTP são convertidos em exceções antes de chegar ao seu código:

| HTTP | Exceção | `retryable?` |
|------|---------|--------------|
| 401, 403 | `Clicksign::AuthenticationError` | não |
| 404 | `Clicksign::NotFoundError` | não |
| 400, 422 | `Clicksign::ValidationError` | não |
| 409 | `Clicksign::ConflictError` | não |
| 429 | `Clicksign::RateLimitError` | sim |
| 5xx | `Clicksign::ServerError` | sim |
| Timeout / conexão | `Clicksign::TimeoutError` | sim |

Todas herdam de `Clicksign::Error` e expõem metadados úteis para debug:

- `status_code` — código HTTP da resposta
- `request_id` — quando enviado pela API
- `response_body` — corpo JSON da resposta de erro
- `response_headers` — headers da resposta (`RateLimitError` também expõe `rate_limit_remaining` e `rate_limit_reset`)

Exemplo:

```ruby
begin
  Envelope.retrieve('00000000-0000-0000-0000-000000000000')
rescue Clicksign::NotFoundError
  puts 'Envelope não encontrado'
rescue Clicksign::ValidationError => e
  puts "Dados inválidos: #{e.message}"
  puts e.response_body
rescue Clicksign::RateLimitError => e
  puts "Aguarde reset em #{e.rate_limit_reset}" if e.retryable?
rescue Clicksign::AuthenticationError
  puts 'Verifique CLICKSIGN_API_KEY'
end
```

Operações em lote (`BulkRequirement`) podem retornar falhas **por slot** em `response.failures` sem lançar exceção, quando a API responde com `atomic:results` parcial.

Guia detalhado: [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md).

---

## Ambientes

| Ambiente | Símbolo | `base_url` |
|----------|---------|------------|
| Sandbox | `:sandbox` | `https://sandbox.clicksign.com/api/v3` |
| Produção | `:production` | `https://app.clicksign.com/api/v3` |

O padrão em `Clicksign::Configuration` é **produção**. Para desenvolvimento, use o atalho `environment` (equivalente a definir `base_url`):

```ruby
Clicksign.configure do |c|
  c.api_key     = ENV['CLICKSIGN_API_KEY']
  c.environment = :sandbox
end

# Ou em multi-conta:
service = Clicksign::Services.new(
  api_key: ENV['CLICKSIGN_API_KEY'],
  environment: :sandbox
)
```

Também é possível passar `base_url` manualmente quando precisar de um endpoint customizado (proxy, mock, etc.).

Gere tokens de API no painel da Clicksign do ambiente correspondente.

---

## Limitações e produção

Design **stdlib-only** (`net/http`) — sem dependências de runtime extras. Duas limitações importantes em alta carga ou runtimes modernos:

### Sem connection pool

Cada request abre e fecha uma conexão TCP (via `Net::HTTP.start`). Não há reutilização persistente entre chamadas.

- **OK** para jobs sequenciais, integrações moderadas e a maioria dos apps Rails.
- **Atenção** em Puma com muitas threads e várias chamadas Clicksign por request: overhead de handshake/TLS pode virar gargalo antes do rate limit da API.

Mitigações: menos round-trips (`BulkRequirement`, batch na app), filas (Sidekiq), cache de leitura. Detalhes: [`docs/examples/08-production-limitations.md`](docs/examples/08-production-limitations.md).

### `Thread.current` e Fibers

`Clicksign::Services#use` armazena o client em `Thread.current[:clicksign_client]`. Resources usam esse client dentro do bloco.

- **Compatível:** Puma (thread por request), Sidekiq, scripts.
- **Incompatível** com propagar contexto em **Fibers** (Falcon, async-ruby): o client do `use` pode não estar visível no Fiber que chama `Envelope.create`.

Mitigações: `Clicksign.configure` por processo (single-tenant), `Clicksign::Client.new` explícito no seu contexto async, ou evitar `Services` em stacks fiberizadas.

---

## Desenvolvimento

Clone o repositório e instale dependências de desenvolvimento:

```bash
bundle install
bundle exec rspec
```

| Variável | Uso |
|----------|-----|
| `CLICKSIGN_API_KEY` | Token para testes contra sandbox (opcional) |
| `CLICKSIGN_API_BASE_URL` | URL da API (padrão sandbox nos specs de integração legados) |

A suíte usa **WebMock** e não exige rede.

Estrutura relevante:

```
lib/clicksign/
  retry_backoff.rb       # Exponential backoff com full jitter
  client.rb              # HTTP (GET, POST, PATCH, DELETE), retry, timeouts
  services.rb            # Cliente por contexto (multi-conta via #use)
  configuration.rb       # Config global, environment, timeouts, retry
  request_instrumentation.rb  # Hooks compartilhados Client + BulkOperationsClient
  instrumentation.rb     # Eventos :request, :retry, :error
  resource.rb            # CRUD base, filtros, nested lists
  resources/notarial/    # Envelope, Document, Signer, Requirement, ...
  json_api/              # Serializer, Parser, bulk operations
docs/SPEC.md             # mapa completo de resources e rotas
docs/WORKFLOW.md         # fluxo notarial ponta a ponta
docs/README.md           # índice da documentação
docs/examples/           # receitas: retries, bulk, webhooks, multi-cliente
docs/TROUBLESHOOTING.md  # diagnóstico e erros comuns
docs/ARCHITECTURE.md     # diagramas e camadas
docs/OBSERVABILITY.md    # logs, métricas, OpenTelemetry
```

---

## Licença

MIT — ver [`clicksign-ruby-sdk.gemspec`](clicksign-ruby-sdk.gemspec).
