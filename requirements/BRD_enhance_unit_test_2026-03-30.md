---
title: BRD — Enhance Unit Test Coverage
description: Business Requirements Document for achieving ≥90% unit test coverage across all packages, covering core functionality gaps identified in the 2026-03-30 coverage report.
hero_eyebrow: Business requirements
hero_title: BRD for Unit Test Enhancement
hero_summary: Defines test coverage targets, prioritised per-package requirements, and acceptance criteria to raise overall statement coverage from ~59% to ≥90% across the Smart Apply codebase.
permalink: /brd-enhance-unit-test/
---

# Business Requirements Document — Enhance Unit Test Coverage

**Version:** 1.0  
**Date:** 2026-03-30  
**Source:** test-coverage-report.md (2026-03-30)  
**Author:** Business Analyst Agent  

---

## 1. Executive Summary

The Smart Apply application comprises four packages: `@smart-apply/shared`, `@smart-apply/api` (backend), `@smart-apply/web`, and `@smart-apply/extension`. A coverage audit on 2026-03-30 revealed that only the shared package meets production-grade coverage (100%). The backend sits at 55%, the web app at 61%, and the extension at just 19% statement coverage. There is also one failing test in the backend (`profiles.service.spec.ts`).

This BRD defines the requirements to:

1. **Fix the existing failing test** so the full suite is green.
2. **Raise overall statement coverage to ≥90%** across all packages by targeting core business logic, service layers, and reusable UI components.
3. **Exclude non-core files** from mandatory coverage targets (NestJS module bootstrap files, Next.js page shells, config files, and the extension manifest) where testing yields low value relative to effort.

The goal is not 100% coverage for its own sake, but confidence that core functionality — profile management, optimization pipeline, scoring, webhooks, authentication, API clients, content scripts, and UI components — is thoroughly tested and regressions are caught early.

---

## 2. Stakeholder Goals

| Stakeholder | Goal | Success Metric |
|:---|:---|:---|
| Engineering Team | Catch regressions early and refactor with confidence | ≥90% statement coverage on core files; zero failing tests |
| Product Owner | Ship stable releases without manual regression testing for core flows | All critical user-journey code paths have unit tests; no production bugs in tested code |
| QA / Reviewer | Review PRs with coverage context and enforce minimum thresholds | CI enforces ≥90% threshold; PRs that drop coverage below threshold are blocked |

---

## 3. Current State (Baseline)

| Package | Tests | Pass / Fail | Stmts | Branch | Funcs | Lines |
|---------|------:|-------------|------:|-------:|------:|------:|
| @smart-apply/shared | 23 | 23 / 0 | 100% | 100% | 100% | 100% |
| @smart-apply/api (backend) | 32 | 31 / 1 | 55.44% | 67.26% | 58% | 55.44% |
| @smart-apply/web | 52 | 52 / 0 | 60.94% | 65.80% | 52.17% | 60.94% |
| @smart-apply/extension | 32 | 32 / 0 | 19.02% | 73.52% | 76.47% | 19.02% |
| **Overall (weighted)** | **139** | **138 / 1** | **~59%** | **~77%** | **~72%** | **~59%** |

### 3.1 Key Gaps by Package

**Backend (55.44% → target ≥90%):**
- 1 failing test in `profiles.service.spec.ts`
- All controllers at 0% (account, applications, optimize, profiles, health)
- Infra layer (LLM service, Supabase service) at 0%
- All module bootstrap files at 0%

**Web (60.94% → target ≥90%):**
- `api-client.ts` at 0%
- `profile-upload.tsx`, `applications-table.tsx`, `stats-cards.tsx` at 0% statements
- `profile-editor.tsx` at 17.64% function coverage
- `dashboard-shell.tsx` at 33.33% function coverage
- All page-level components (`page.tsx`, `layout.tsx`) at 0%

**Extension (19.02% → target ≥90%):**
- All content scripts at 0% (`autofill.ts`, `dom-utils.ts`, `jd-detector.ts`, `linkedin-profile.ts`)
- Popup UI (`App.tsx`, 446 lines) at 0%
- Lib modules (`auth.ts`, `config.ts`, `google-drive.ts`, `message-bus.ts`, `storage.ts`) at 0%
- `service-worker.ts` at 45%

---

## 4. Target State

| Package | Target Stmts | Target Branch | Target Funcs | Target Lines |
|---------|-------------:|--------------:|-------------:|-------------:|
| @smart-apply/shared | 100% (maintain) | 100% | 100% | 100% |
| @smart-apply/api (backend) | ≥90% | ≥85% | ≥90% | ≥90% |
| @smart-apply/web | ≥90% | ≥85% | ≥85% | ≥90% |
| @smart-apply/extension | ≥90% | ≥85% | ≥85% | ≥90% |

### 4.1 Coverage Exclusions

The following file categories may be excluded from coverage enforcement via vitest config `coverage.exclude` as they provide negligible safety value from unit tests:

| File Pattern | Reason |
|:---|:---|
| `*.module.ts` (NestJS modules) | Declarative DI wiring; tested implicitly by integration tests |
| `main.ts` (NestJS bootstrap) | App bootstrap; tested by e2e or smoke tests |
| `app.module.ts` | Root module wiring |
| `page.tsx`, `layout.tsx` (Next.js) | Thin route shells; tested by e2e or integration tests |
| `manifest.ts` (extension) | Static config object |
| `postcss.config.mjs`, `tailwind.config.ts`, `next.config.ts` | Build-time config |
| `src/ui/popup/index.tsx` | ReactDOM.render entry point |

---

## 5. Functional Requirements

### 5.1 Must-Have (P0 — Blocking)

```
REQ-TEST-01
Title: Fix Failing profiles.service.spec.ts Test
Package: @smart-apply/api
Current State: FAILING — Test "getProfile throws NotFoundException when not
  found" expects the service to throw NotFoundException, but the service now
  returns null.
Required State: Test updated to match current service behavior, OR service
  restored to throw NotFoundException — whichever aligns with the API contract.
Acceptance Criteria:
  - Given `npm -w @smart-apply/api run test` is executed, then all tests pass
    with exit code 0.
  - Given the test is updated, then it validates the actual getProfile behavior
    (return null or throw) consistently with the controller's response handling.
Dependencies: None
Estimated Tests: 0 new (1 fix)
```

```
REQ-TEST-02
Title: Backend Controller Tests
Package: @smart-apply/api
Current State: MISSING — All 5 controllers (AccountController,
  ApplicationsController, OptimizeController, ProfilesController,
  HealthController) have 0% coverage. No request/response shape, input
  validation, or auth guard tests exist at the controller level.
Required State: Each controller has tests covering: successful request handling,
  input validation rejection (bad payloads), and auth guard enforcement.
Acceptance Criteria:
  - Given each controller, then at least one test validates a successful 2xx
    response for each endpoint.
  - Given an invalid request body, when the controller endpoint is called, then
    a 400-level error is returned (for endpoints with Zod/DTO validation).
  - Given no auth token, when a protected endpoint is called, then 401 is
    returned.
  - Given all controller tests pass, then controllers achieve ≥85% statement
    coverage.
Dependencies: REQ-TEST-01 (green suite baseline)
Estimated Tests: ~20 new
```

```
REQ-TEST-03
Title: Backend Infra Layer Tests (LLM Service)
Package: @smart-apply/api
Current State: MISSING — llm.service.ts (237 lines) has 0% coverage. This is
  the core AI integration layer handling profile parsing, JD extraction, and
  optimization suggestions.
Required State: LLM service has tests covering: prompt construction, response
  parsing, error handling (API timeout, malformed response, rate limiting), and
  retry/fallback behavior. External API calls are mocked.
Acceptance Criteria:
  - Given a valid profile text input, when parseProfile is called with a mocked
    LLM response, then the parsed profile JSON matches expected structure.
  - Given a valid JD input, when extractRequirements is called, then extracted
    requirements match expected format.
  - Given an LLM API timeout, when any LLM method is called, then a
    descriptive error is thrown (not an unhandled promise rejection).
  - Given a malformed LLM response, when the response is parsed, then the
    service falls back gracefully or throws a typed error.
  - Given all tests pass, then llm.service.ts achieves ≥90% statement coverage.
Dependencies: None
Estimated Tests: ~10-12 new
```

```
REQ-TEST-04
Title: Backend Infra Layer Tests (Supabase Service)
Package: @smart-apply/api
Current State: MISSING — supabase.service.ts (15 lines) has 0% coverage.
Required State: Supabase service has tests covering client initialization and
  the admin accessor.
Acceptance Criteria:
  - Given environment variables are set, when the service initializes, then a
    Supabase client is created.
  - Given the admin property is accessed, then a SupabaseClient instance is
    returned.
  - Given all tests pass, then supabase.service.ts achieves ≥90% coverage.
Dependencies: None
Estimated Tests: ~2-3 new
```

```
REQ-TEST-05
Title: Extension Content Script Tests
Package: @smart-apply/extension
Current State: MISSING — All content scripts at 0%: autofill.ts (234 lines),
  dom-utils.ts (136 lines), jd-detector.ts (103 lines), linkedin-profile.ts
  (52 lines). These implement core extension functionality — form filling, DOM
  field detection, job description extraction, and LinkedIn scraping.
Required State: Each content script has tests covering core logic with DOM
  interactions mocked or simulated via JSDOM/happy-dom.
Acceptance Criteria:
  - Given autofill.ts, then tests cover: field mapping for standard form
    inputs, file attachment handling, clipboard fallback trigger, and floating
    button injection.
  - Given dom-utils.ts, then tests cover: field detection by label/name/
    placeholder/aria-label, input type identification, and edge cases
    (hidden fields, disabled fields).
  - Given jd-detector.ts, then tests cover: JD text extraction from known
    page structures (LinkedIn, Indeed), fallback extraction from generic pages,
    and no-JD-found scenario.
  - Given linkedin-profile.ts, then tests cover: profile data extraction from
    mocked LinkedIn DOM structure and graceful handling of missing fields.
  - Given all tests pass, then content scripts achieve ≥85% statement coverage
    collectively.
Dependencies: Test environment setup (JSDOM or happy-dom for DOM simulation)
Estimated Tests: ~20-25 new
```

```
REQ-TEST-06
Title: Extension Lib Module Tests
Package: @smart-apply/extension
Current State: MISSING — auth.ts (30 lines), config.ts (8 lines),
  google-drive.ts (131 lines), message-bus.ts (48 lines), storage.ts (43 lines)
  all at 0% coverage. These modules handle authentication, configuration,
  Drive upload, inter-script messaging, and chrome.storage persistence.
Required State: Each lib module has tests with chrome APIs mocked.
Acceptance Criteria:
  - Given auth.ts, then tests cover: token retrieval from storage, token
    refresh trigger, and cleared-token state.
  - Given config.ts, then tests cover: config value resolution for dev and
    production environments.
  - Given google-drive.ts, then tests cover: successful file upload, folder
    creation, error handling (quota exceeded, network failure, auth failure),
    and shareable link generation. All Google API calls mocked.
  - Given message-bus.ts, then tests cover: message send/receive between
    popup and background, message type routing, and timeout handling.
  - Given storage.ts, then tests cover: get/set/remove operations on
    chrome.storage.local with mocked Chrome APIs.
  - Given all tests pass, then lib modules achieve ≥90% statement coverage
    collectively.
Dependencies: Chrome API mock setup (already partially in test/chrome-mock.ts)
Estimated Tests: ~15-18 new
```

```
REQ-TEST-07
Title: Extension Service Worker Full Coverage
Package: @smart-apply/extension
Current State: PARTIAL — service-worker.ts at 45.37% statement coverage.
  Lines 202-321 (second half of message handlers) are untested.
Required State: All message handler branches tested, including SYNC_PROFILE,
  OPTIMIZE_JD, GENERATE_PDF, SAVE_APPLICATION, and error/fallback paths.
Acceptance Criteria:
  - Given each message type handled by the service worker, then at least one
    success-path and one error-path test exists.
  - Given an unknown message type, when received, then the handler returns an
    error response (not an unhandled exception).
  - Given all tests pass, then service-worker.ts achieves ≥90% statement
    coverage.
Dependencies: REQ-TEST-06 (lib mocks established)
Estimated Tests: ~8-10 new
```

### 5.2 Should-Have (P1 — High Value)

```
REQ-TEST-08
Title: Web API Client Tests
Package: @smart-apply/web
Current State: MISSING — api-client.ts (25 lines) at 0% coverage. This is the
  HTTP client used by all web components to call the backend.
Required State: API client has tests covering: successful requests, error
  responses (4xx, 5xx), network failures, and auth header attachment.
Acceptance Criteria:
  - Given a successful API response, when any client method is called, then
    the parsed data is returned.
  - Given a 401 response, when any client method is called, then an
    appropriate auth error is thrown or handled.
  - Given a network failure, when any client method is called, then a
    descriptive error is thrown.
  - Given all tests pass, then api-client.ts achieves 100% statement coverage.
Dependencies: None
Estimated Tests: ~5-6 new
```

```
REQ-TEST-09
Title: Web Component Tests — Untested Components
Package: @smart-apply/web
Current State: MISSING — profile-upload.tsx (203 lines), applications-table.tsx
  (59 lines), stats-cards.tsx (45 lines) have 0% statement coverage.
Required State: Each component has tests covering rendering, user interactions,
  loading/error/empty states, and data display.
Acceptance Criteria:
  - Given profile-upload.tsx, then tests cover: file selection, upload trigger,
    upload progress/success/error states, and file type validation.
  - Given applications-table.tsx, then tests cover: table rendering with data,
    empty state display, and row data formatting.
  - Given stats-cards.tsx, then tests cover: rendering with various data values,
    zero-state display, and number formatting.
  - Given all tests pass, then these components achieve ≥85% statement coverage
    collectively.
Dependencies: None
Estimated Tests: ~10-12 new
```

```
REQ-TEST-10
Title: Web Component Tests — Improve Low-Coverage Components
Package: @smart-apply/web
Current State: PARTIAL — profile-editor.tsx at 17.64% function coverage (80.56%
  statements); dashboard-shell.tsx at 33.33% function coverage (74.56%
  statements). Key event handlers and conditional branches are untested.
Required State: Missing function coverage filled in — event handlers, form
  submissions, conditional renders, and error states tested.
Acceptance Criteria:
  - Given profile-editor.tsx, then tests cover: form field changes, experience/
    education add/remove, save submission, validation errors, and unsaved
    changes warning. Achieves ≥85% function coverage.
  - Given dashboard-shell.tsx, then tests cover: navigation interactions,
    responsive menu toggle, and conditional rendering paths. Achieves ≥80%
    function coverage.
Dependencies: None
Estimated Tests: ~8-10 new
```

```
REQ-TEST-11
Title: Extension Popup UI Tests
Package: @smart-apply/extension
Current State: MISSING — App.tsx (446 lines) at 0% coverage. This is the
  primary user interface for the Chrome extension popup.
Required State: App.tsx has component tests covering key user flows: auth state
  display (signed in vs. signed out), profile sync trigger, optimize trigger,
  result display, and error states.
Acceptance Criteria:
  - Given the user is not authenticated, then the popup renders a sign-in
    prompt.
  - Given the user is authenticated, then the popup renders the dashboard view
    with profile summary and action buttons.
  - Given the user triggers "Sync Profile," then a loading state is shown,
    followed by success or error feedback.
  - Given the user triggers "Optimize," then the optimize flow UI renders with
    JD input, results display, and PDF generation.
  - Given all tests pass, then App.tsx achieves ≥80% statement coverage.
Dependencies: REQ-TEST-06 (chrome mock infrastructure)
Estimated Tests: ~12-15 new
```

### 5.3 Could-Have (P2 — Nice To Have)

```
REQ-TEST-12
Title: Backend Account Service and Controller Tests
Package: @smart-apply/api
Current State: MISSING — account.controller.ts (16 lines) and
  account.service.ts (20 lines) at 0%. Low line count but untested.
Required State: Account module has basic tests covering account deletion and
  any data export flows.
Acceptance Criteria:
  - Given the delete account endpoint, then a test validates successful
    deletion and cascading data cleanup.
  - Given all tests pass, then account module achieves ≥85% coverage.
Dependencies: None
Estimated Tests: ~3-4 new
```

```
REQ-TEST-13
Title: Web Page-Level Smoke Tests
Package: @smart-apply/web
Current State: MISSING — All page.tsx / layout.tsx files at 0%. These are thin
  Next.js route components.
Required State: Lightweight smoke tests validate that each page component
  renders without crashing.
Acceptance Criteria:
  - Given each page component (dashboard, profile, optimize, settings,
    sign-in), then a smoke test confirms it renders without throwing.
  - Tests do not validate deep component behavior (covered by component tests).
Dependencies: REQ-TEST-09, REQ-TEST-10 (component tests provide stable mocks)
Estimated Tests: ~5-6 new
```

---

## 6. Non-Functional Requirements

| # | Category | Requirement |
|:---|:---|:---|
| NFR-01 | CI Enforcement | Coverage thresholds (≥90% statements for core files) are enforced in CI via vitest `coverage.thresholds`; PRs that drop below threshold fail the check |
| NFR-02 | Performance | Full test suite across all 4 packages completes in < 60 seconds on CI |
| NFR-03 | Isolation | All tests are fully isolated — no shared state, no real network calls, no real database connections. External services (Supabase, LLM APIs, Chrome APIs, Google APIs) are mocked |
| NFR-04 | Maintainability | Test files are co-located with source or in a parallel `test/` directory per existing convention. Each test file covers one module/component |
| NFR-05 | Determinism | Tests produce the same result on every run. No time-dependent or order-dependent tests. Flaky tests are fixed or quarantined within 24 hours |
| NFR-06 | Coverage Config | Each package's vitest.config.ts is updated with `coverage.exclude` patterns for non-core files (see §4.1) and `coverage.thresholds` reflecting target percentages |

---

## 7. Implementation Priority & Phasing

### Phase 1 — Fix and Foundation (P0)

| Req | Title | Package | Est. Tests | Coverage Impact |
|:---|:---|:---|---:|:---|
| REQ-TEST-01 | Fix failing profiles test | Backend | 0 (fix) | Unblocks CI |
| REQ-TEST-03 | LLM service tests | Backend | ~12 | Backend +15% |
| REQ-TEST-04 | Supabase service tests | Backend | ~3 | Backend +1% |
| REQ-TEST-05 | Content script tests | Extension | ~25 | Extension +30% |
| REQ-TEST-06 | Extension lib module tests | Extension | ~18 | Extension +15% |

**Phase 1 outcome:** Backend ≥70%, Extension ≥65%, all tests green.

### Phase 2 — Controllers & Components (P0/P1)

| Req | Title | Package | Est. Tests | Coverage Impact |
|:---|:---|:---|---:|:---|
| REQ-TEST-02 | Backend controller tests | Backend | ~20 | Backend → ≥90% |
| REQ-TEST-07 | Service worker full coverage | Extension | ~10 | Extension +10% |
| REQ-TEST-08 | Web API client tests | Web | ~6 | Web +2% |
| REQ-TEST-09 | Web untested components | Web | ~12 | Web +10% |

**Phase 2 outcome:** Backend ≥90%, Web ≥75%, Extension ≥75%.

### Phase 3 — Polish to ≥90% (P1/P2)

| Req | Title | Package | Est. Tests | Coverage Impact |
|:---|:---|:---|---:|:---|
| REQ-TEST-10 | Web low-coverage components | Web | ~10 | Web → ≥90% |
| REQ-TEST-11 | Extension popup UI tests | Extension | ~15 | Extension → ≥90% |
| REQ-TEST-12 | Backend account module | Backend | ~4 | Backend maintain ≥90% |
| REQ-TEST-13 | Web page smoke tests | Web | ~6 | Web maintain ≥90% |

**Phase 3 outcome:** All packages ≥90%. Target achieved.

---

## 8. Estimated Test Count Summary

| Package | Current Tests | New Tests (Est.) | Total (Est.) |
|:---|---:|---:|---:|
| @smart-apply/shared | 23 | 0 | 23 |
| @smart-apply/api (backend) | 32 | ~35-39 | ~67-71 |
| @smart-apply/web | 52 | ~33-34 | ~85-86 |
| @smart-apply/extension | 32 | ~68-78 | ~100-110 |
| **Total** | **139** | **~136-151** | **~275-290** |

---

## 9. Out of Scope

| Item | Reason |
|:---|:---|
| End-to-end (E2E) tests (Playwright, Cypress) | Separate initiative; this BRD focuses on unit/component tests only |
| Integration tests against real Supabase/LLM | Unit tests mock all external services; integration tests are a separate effort |
| Visual regression tests | Not part of unit test coverage; requires separate tooling |
| Performance/load testing | Deferred; not related to unit test coverage |
| NestJS module bootstrap files (`*.module.ts`) | Declarative DI wiring; excluded from coverage targets |
| Next.js config files (`next.config.ts`, `postcss.config.mjs`, `tailwind.config.ts`) | Build-time config; excluded from coverage targets |
| Extension `manifest.ts` and `index.tsx` | Static config and entry point; excluded from coverage targets |
| Achieving >90% on files currently at 0% that are purely declarative/config | Diminishing returns; excluded via vitest coverage.exclude |

---

## 10. Open Questions

| # | Question | Owner | Due |
|:---|:---|:---|:---|
| 1 | Should the failing `profiles.service.spec.ts` test be fixed by updating the test (match to current `null`-return behavior) or by restoring the `NotFoundException` throw in the service? | Engineering Team | Phase 1 start |
| 2 | Should `happy-dom` or `jsdom` be used for extension content script DOM testing? `happy-dom` is faster but `jsdom` is more complete. | Engineering Team | Phase 1 start |
| 3 | Should coverage thresholds be enforced per-file or per-package? Per-file is stricter but creates more CI noise for small utility files. | Engineering Team | Phase 1 start |
| 4 | Is the ~60-second CI timeout for the full test suite achievable, or should it be relaxed to 90 seconds given the extension content script DOM tests? | Engineering Team | Phase 2 start |
| 5 | Should `google-drive.ts` (131 lines) be tested with full mock coverage given that Google Drive integration is not yet fully implemented? | Product Owner | Phase 1 planning |

---

## 11. Approval Checklist

- [x] All P0 requirements have at least two acceptance criteria
- [x] Every requirement references a specific package and file(s)
- [x] Coverage targets are realistic (≥90% with documented exclusions)
- [x] Estimated test counts are provided for planning
- [x] Implementation is phased with incremental coverage milestones
- [x] Out-of-scope items documented to prevent scope creep
- [x] Non-functional requirements cover CI enforcement, isolation, and determinism
