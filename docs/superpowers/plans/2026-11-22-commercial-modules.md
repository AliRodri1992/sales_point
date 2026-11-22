# Commercial Modules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver independently managed, secure, polished price lists and promotions with a reusable pricing contract.

**Architecture:** Extend the existing domain and services with tested contracts, then give the existing routes independent views, authorization, filters and sidebar navigation. Retain existing records and audit snapshots; do not replace the pricing engine or expand into checkout internals.

**Tech Stack:** Rails 8.1, PostgreSQL, Tailwind 4, Hotwire/Stimulus, Pundit, RSpec, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-22-commercial-modules-design.md`

## Global Constraints

- `feature/fixes` only; no force push, protected branch changes or skipped hooks/CI. Check remote head before publishing; validate exact SHA using Actions, not assumed local tools.
- Delta Emerald, existing components, inline original SVG, es/en/ko, tenant isolation, Pundit, server validations, no external dependencies. Preserve historical references, existing APIs and permanent quality IDs.

## Review Focus

- Manipulated foreign/legacy/retired category or product ID: rejected, no data exposure (Task 1).
- Simultaneous sequence or redemption: unique code, quota not exceeded (Task 2).
- Exact end timestamp, paused state and currency mismatch: never apply incorrect pricing (Tasks 2 and 5).
- Existing price changes and historical associations: no destructive deletion or silent unauthorized edits (Tasks 3 and 4).
- Unauthorized user, invalid filter, keyboard and localized mobile view: no exposed cost, correct scope and recovery (Tasks 3 and 4).

### Task 1 — Promotion eligibility and tenant integrity

**Files:** `app/models/promotion_condition.rb`, `app/services/products/promotion_eligibility.rb`, `spec/services/products/promotion_targets_spec.rb`, `docs/quality/modules/promotions.md`.

**Interfaces:** `Products::PromotionEligibility#eligible?` returns Boolean; `Products::Quote#call` remains unchanged, `PromotionCondition` model validates associations.

- [ ] Add regression specs: product A or B qualifies, C does not; quantity and category remain mandatory, retired/inactive/foreign or global targets cannot be newly assigned; unaffected historical records remain readable.
- [ ] Validate red through GitHub Actions; confirm failures specifically represent the missing behavior.
- [ ] Implement grouped OR validation within product/category kinds; AND across groups and other conditions. Validate new/reassigned target state and organization, preserve same-tenant historical identities on unchanged edits. Record PROMOTIONS-001 in quality log.
- [ ] Validate green in RSpec and RuboCop on exact SHA. Commit only the scope justified by these specs.

### Task 2 — Lifecycle and codes

**Files:** `app/models/{price_list,promotion}.rb`, `app/models/concerns/commercial_period.rb`, new service under `app/services/products/`, controllers, routes, policies, `db/migrate/`, schema, locales `catalog_design.{es,en,ko}.yml`, `spec/requests/admin/commercial_catalog_spec.rb`, `spec/services/products/commercial_boundaries_spec.rb`.

**Interfaces:** effective status at `at: Time.current`, transition service under row lock, code generation with organization-scoped counter and existing unique index.

- [ ] Tests: code prefix and monotonic uniqueness across concurrent requests, existing code unchanged, tampered code/status rejected; draft without rows/benefits cannot activate; exact boundary, paused/resumed and archived rules; unauthorized change rejected.
- [ ] Run red, implement schema/model/service/controller changes with reversible migrations and stable codes, maintain delete as archival for compatibility.
- [ ] Run green, verify clean migration and CI, document and publish verified slice.

### Task 3 — Navigation, permissions and dedicated price list screens

**Files:** `app/policies/{price_list_policy,promotion_policy}.rb`, `app/services/granular_permission_catalog.rb`, `app/helpers/{application_helper,sidebar_helper,catalog_design_helper}.rb`, `app/views/admin/shared/_sidebar.html.erb`, `app/views/admin/products/index.html.erb`, `app/controllers/admin/{commercial_catalog_controller,price_lists_controller}.rb`, new `app/views/admin/price_lists/`, `app/javascript/controllers/`, `config/locales/admin_sidebar.{es,en,ko}.yml`, locales for both modules and permissions, `spec/policies/commercial_policy_spec.rb`, `spec/requests/admin/commercial_catalog_spec.rb`, `spec/features/admin_sidebar_navigation_spec.rb` and new browser spec.

**Interfaces:** separate module permissions and screens; existing route names and tenant scoped queries remain; existing `delta-select` and pagination.

- [ ] Test sidebar access and active state, migration of read rights with no write escalation, filter/search/sort persistence, new/edit/show, click-to-add products, removal after margin column, persisted price change reason, foreign lookup rejected, cost disclosure controlled in HTML/JSON, keyboard and 422 recovery at responsive widths.
- [ ] Run red. Implement independent navigation, permission synchronization and translations; dedicated price list index, detail and form; search backed by scoped product queries with fixed limit and escaped search; retain persisted price history; preserve list variant/presentation/time options.
- [ ] Run green; browser visual evidence where available; verify CI exact SHA and update quality record.

### Task 4 — Dedicated promotion screens

**Files:** `app/controllers/admin/promotions_controller.rb`, new `app/views/admin/promotions/`, shared reusable filter/summary components where justified, `app/javascript/controllers/`, `config/locales/`, request and new browser specs, `docs/quality/modules/promotions.md`.

**Interfaces:** list filters use allowlisted persisted/derived states, existing eligibility and quote services; create/edit retains entered values and never permits unauthorized mutations.

- [ ] Test campaign index/filter chips/pagination, clickable target search and remove, benefit/conditions summary, usage state, single-level sections, locale render/preservation on 422, denied cross-tenant targets, archival/duplication/permissions and no destructive edits to history.
- [ ] Run red, implement dedicated views with responsive campaign composition and consistent selectors, context-aware actions and confirmation. Reuse existing query/status components, do not display unsupported controls.
- [ ] Run green, verify browser and exact SHA, update quality record.

### Task 5 — Advanced pricing and integrations

**Files:** `app/services/products/{quote,promotion_eligibility,redeem_promotion,save_price_list}.rb`, commercial models and migrations, dedicated screens/locales, `spec/services/products/{commercial_pricing,commercial_integrity,promotion_concurrency}_spec.rb`.

**Interfaces:** existing single-line quote and redemption stay backward compatible; introduce explicit new contracts for multi-promotion or cart scope only after tests.

- [ ] Specify and test each independent slice: same-currency default/customer/segment list precedence; volume ranges and conflict detection; cost margin authorization; target exclusions; cap/priority/exclusive and explicit accumulation order; frequency and validity; simulator not redeeming; currency precision; audit data; quota race and idempotency.
- [ ] For each slice, verify red through CI, implement minimal compatible behavior, verify green, then enable corresponding UI. Keep checkout, returns, branch support and reporting as clearly separated integrations until their contracts are verified.
- [ ] Run full CI on final SHA, audit quality module records, independent code review and visual review; publish and report verified vs pending items. Never mark closed with failing required checks.
