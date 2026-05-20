# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
