# Clicksign Ruby SDK

[![Gem Version](https://badge.fury.io/rb/clicksign-ruby-sdk.svg)](https://badge.fury.io/rb/clicksign-ruby-sdk)
[![CI](https://github.com/djosino/clicksign-ruby-sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/djosino/clicksign-ruby-sdk/actions/workflows/ci.yml)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.0-red)](https://www.ruby-lang.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](clicksign-ruby-sdk.gemspec)

Cliente Ruby oficial para a [API v3 da Clicksign](https://developers.clicksign.com/) (JSON:API). Permite criar envelopes, adicionar documentos e signatários, configurar requisitos de assinatura, webhooks e demais recursos da plataforma com uma API idiomática em Ruby.

**Requisitos:** Ruby >= 3.0 · dependências de runtime: apenas biblioteca padrão (`net/http`, `json`).

**Documentação da API:** [Sandbox](https://sandbox.clicksign.com/api/v3) · [Produção](https://app.clicksign.com/api/v3) · Referência interna: [`docs/SPEC.md`](docs/SPEC.md)

---

## Índice

- [Instalação](#instalação)
- [Configuração](#configuração)
- [Início rápido](#início-rápido)
- [Fluxo de assinatura (notarial)](#fluxo-de-assinatura-notarial)
- [Filtros, ordenação e paginação](#filtros-ordenação-e-paginação)
- [Outros recursos](#outros-recursos)
- [Tratamento de erros](#tratamento-de-erros)
- [Ambientes](#ambientes)
- [Desenvolvimento](#desenvolvimento)
- [Licença](#licença)

> **Exemplo passo a passo:** [`docs/WORKFLOW.md`](docs/WORKFLOW.md) — fluxo completo de envelope → documento → signatário → requisitos → ativação → notificação.

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

Configure a chave de API e a URL base **uma vez** no boot da aplicação (initializer, `config/initializers/clicksign.rb`, script, etc.):

```ruby
require 'clicksign'

Clicksign.configure do |c|
  c.api_key  = ENV.fetch('CLICKSIGN_API_KEY')
  c.base_url = ENV.fetch('CLICKSIGN_API_BASE_URL', 'https://sandbox.clicksign.com/api/v3')
end
```

A API usa o header `Authorization: <seu-token>` **sem** o prefixo `Bearer`.

> **Segurança:** não commite tokens no código. Use variáveis de ambiente ou cofre de secrets (Rails credentials, etc.).

Para testar interativamente no console da gem:

```bash
CLICKSIGN_API_KEY=seu-token bundle exec ruby bin/console
```

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

# Criar evento customizado no documento
Event.create_for_document(
  envelope_id: envelope.id,
  document_id: document.id,
  name: 'custom',
  data: { description: 'Etapa interna concluída' }
)
```

---

## Filtros, ordenação e paginação

A API de listagem é chainable:

```ruby
Envelope
  .filter(status: 'running', name: 'Contrato')
  .order('-created')
  .page(1)
  .per(20)
  .to_a

# Atalho quando há poucos filtros
Template.filter(name: 'NDA padrão').first

# Navegação no resultado
Envelope.order('-created').first   # mais recente
Envelope.order('-created').last    # mais antigo
Envelope.filter(status: 'draft').count  # total de rascunhos
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

---

## Outros recursos

| Recurso | Classe | Exemplo |
|---------|--------|---------|
| Webhook | `Clicksign::Resources::Webhook` | `Webhook.create(endpoint: 'https://...', events: ['envelope.completed'], status: 'active')` |
| Pasta | `Clicksign::Resources::Folder` | `Folder.create(name: 'Contratos 2026', folder_id: pai&.id)` |
| Template | `Clicksign::Resources::Template` | `Template.list` · `Template.list_template_fields(id)` |
| Usuário | `Clicksign::Resources::User` | `User.me` · `User.filter(email: '...')` |
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

| HTTP | Exceção |
|------|---------|
| 401, 403 | `Clicksign::AuthenticationError` |
| 404 | `Clicksign::NotFoundError` |
| 400, 422 | `Clicksign::ValidationError` |
| 409 | `Clicksign::ConflictError` |
| 429 | `Clicksign::RateLimitError` |
| 5xx | `Clicksign::ServerError` |
| Timeout / conexão | `Clicksign::TimeoutError` |

Exemplo:

```ruby
begin
  Envelope.retrieve('00000000-0000-0000-0000-000000000000')
rescue Clicksign::NotFoundError
  puts 'Envelope não encontrado'
rescue Clicksign::ValidationError => e
  puts "Dados inválidos: #{e.message}"
rescue Clicksign::AuthenticationError
  puts 'Verifique CLICKSIGN_API_KEY'
end
```

Operações em lote (`BulkRequirement`) podem retornar falhas **por slot** em `response.failures` sem lançar exceção, quando a API responde com `atomic:results` parcial.

---

## Ambientes

| Ambiente | `base_url` |
|----------|------------|
| Sandbox | `https://sandbox.clicksign.com/api/v3` |
| Produção | `https://app.clicksign.com/api/v3` |

O padrão da gem em `Clicksign::Configuration` é produção (`app.clicksign.com`). Para desenvolvimento, defina explicitamente o sandbox:

```ruby
Clicksign.configure do |c|
  c.api_key  = ENV['CLICKSIGN_API_KEY']
  c.base_url = 'https://sandbox.clicksign.com/api/v3'
end
```

Gere tokens de API no painel da Clicksign do ambiente correspondente.

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

A suíte principal usa **WebMock** e não exige rede. Alguns specs antigos ainda podem usar **VCR** com gravação no sandbox.

Estrutura relevante:

```
lib/clicksign/
  client.rb              # HTTP (GET, POST, PATCH, DELETE)
  resource.rb            # CRUD base, filtros, nested lists
  resources/notarial/    # Envelope, Document, Signer, Requirement, ...
  json_api/              # Serializer, Parser, bulk operations
docs/SPEC.md             # mapa completo de resources e rotas
```

---

## Licença

MIT — ver [`clicksign-ruby-sdk.gemspec`](clicksign-ruby-sdk.gemspec).
