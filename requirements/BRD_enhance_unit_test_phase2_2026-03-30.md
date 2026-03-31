---
title: BRD — Enhance Unit Test Coverage (Phase 2)
description: Business Requirements Document for Phase 2 test enhancement — Controllers, Components, and Popup UI — building on the Phase 1 foundation.
hero_eyebrow: Business requirements
hero_title: BRD for Unit Test Enhancement — Phase 2
hero_summary: Defines requirements to raise backend coverage to ≥90%, web to ≥75%, and extension to ≥75% by testing controllers, untested web components, and the extension popup UI.
permalink: /brd-enhance-unit-test-phase2/
---

# Business Requirements Document — Enhance Unit Test Coverage (Phase 2)

**Version:** 1.0
**Date:** 2026-03-30
**Source:** REVIEW-TEST-P01.md, BRD_enhance_unit_test_2026-03-30.md
**Author:** Business Analyst Agent
**Predecessor:** BRD_enhance_unit_test_2026-03-30.md (Phase 1 — APPROVED per REVIEW-TEST-P01.md)

---

## 1. Executive Summary

Phase 1 established a green test baseline and foundational coverage for the backend (70.91%) and extension (65.16%). All 142 tests pass with zero failures. Phase 1 also completed the service-worker coverage ahead of schedule (45.37% → 95.37%), which was originally planned for Phase 2 (REQ-TEST-07).

Phase 2 targets the three highest-impact coverage gaps remaining:

1. **Backend controllers** — all five controllers sit at 0% coverage despite the services behind them being well-tested.
2. **Web package** — five components and the API client sit at 0% coverage, and two components have low function coverage.
3. **Extension popup UI** — `App.tsx` (the largest single untested file at 446 lines) is at 0% and drags overall extension coverage down.

Phase 2 targets: **Backend ≥90%, Web ≥75%, Extension ≥75%.**

---

## 2. Stakeholder Goals

| Stakeholder | Goal | Success Metric |
|:---|:---|:---|
| Engineering Team | Controller layer and web components are tested; safe to refactor API contracts and UI | Backend ≥90%, Web ≥75% coverage on core files |
| Product Owner | Extension popup is tested; regressions in the primary user interface are caught | Extension popup ≥80% coverage; overall extension ≥75% |
| QA / Reviewer | Web components carry tests for all user-facing states (loading, error, empty, success) | Each component test covers ≥3 render states |

---

## 3. Current State (Post-Phase 1 Baseline)

| Package | Tests | Pass / Fail | Stmts | Branch | Funcs | Lines |
|---------|------:|-------------|------:|-------:|------:|------:|
| @smart-apply/shared | 23 | 23 / 0 | 100% | 100% | 100% | 100% |
| @smart-apply/api (backend) | 47 | 47 / 0 | 70.91% | 70.91% | 66.07% | 70.91% |
| @smart-apply/web | 52 | 52 / 0 | 60.94% | 65.80% | 52.17% | 60.94% |
| @smart-apply/extension | 95 | 95 / 0 | 65.16% | 80.40% | 92.85% | 65.16% |
| **Overall** | **217** | **217 / 0** | — | — | — | — |

### 3.1 Key Gaps by Package

**Backend (70.91% → target ≥90%):**

| File | Stmts | Lines | Gap |
|------|------:|------:|-----|
| profiles.controller.ts | 0% | 37 | All 3 endpoints untested |
| applications.controller.ts | 0% | 33 | All 3 endpoints untested |
| optimize.controller.ts | 0% | 17 | Single endpoint untested |
| health.controller.ts | 0% | 11 | Health check untested |
| account.controller.ts | 0% | 15 | Delete account untested |
| All `*.module.ts` | 0% | ~60 | DI wiring — exclude from targets |

**Web (60.94% → target ≥75%):**

| File | Stmts | Funcs | Lines | Gap |
|------|------:|------:|------:|-----|
| api-client.ts | 0% | 0% | 21 | Zero coverage |
| applications-table.tsx | 0% | — | 47 | Zero coverage |
| stats-cards.tsx | 0% | — | 40 | Zero coverage |
| profile-upload.tsx | 0% | — | 142 | Zero coverage; largest untested web component |
| dashboard-shell.tsx | 74.56% | 33.33% | 107 | Low function coverage; mutations untested |
| profile-editor.tsx | 80.56% | 17.64% | 283 | Low function coverage; form handlers untested |
| All page.tsx / layout.tsx | 0% | — | ~146 | Route shells — Phase 3 scope |

**Extension (65.16% → target ≥75%):**

| File | Stmts | Lines | Gap |
|------|------:|------:|-----|
| App.tsx | 0% | 446 | Entire popup UI untested; largest single gap |
| index.tsx | 0% | 8 | ReactDOM entry — exclude from targets |
| Background | 95.63% | — | ✅ Complete |
| Content | 79.84% | — | ✅ Complete |
| Lib | 98% | — | ✅ Complete |

---

## 4. Target State

| Package | Current Stmts | Target Stmts | Target Branch | Target Funcs |
|---------|-------------:|-------------:|--------------:|-------------:|
| @smart-apply/shared | 100% | 100% (maintain) | 100% | 100% |
| @smart-apply/api (backend) | 70.91% | **≥90%** | ≥85% | ≥85% |
| @smart-apply/web | 60.94% | **≥75%** | ≥70% | ≥65% |
| @smart-apply/extension | 65.16% | **≥75%** | ≥80% | ≥90% |

### 4.1 Coverage Exclusions (Carried Forward from Phase 1)

| File Pattern | Reason |
|:---|:---|
| `*.module.ts` (NestJS) | Declarative DI wiring |
| `main.ts`, `cors.ts` (NestJS bootstrap) | App bootstrap |
| `page.tsx`, `layout.tsx` (Next.js) | Route shells — Phase 3 |
| `providers.tsx` (Next.js) | Client provider wiring |
| `manifest.ts`, `src/ui/popup/index.tsx` (Extension) | Static config / entry point |

---

## 5. Completed Requirements (Carried Forward)

The following requirements from the original BRD are already satisfied and require no additional work in Phase 2:

| Req | Title | Completion |
|-----|-------|------------|
| REQ-TEST-01 | Fix failing profiles test | ✅ Phase 1 — assertion updated to `toBeNull()` |
| REQ-TEST-03 | LLM service tests | ✅ Phase 1 — 12 tests, 100% coverage |
| REQ-TEST-04 | Supabase service tests | ✅ Phase 1 — 3 tests, 100% coverage |
| REQ-TEST-05 | Content script tests | ✅ Phase 1 — 27 tests, 79.84% coverage |
| REQ-TEST-06 | Extension lib module tests | ✅ Phase 1 — 22 tests, 98% coverage |
| REQ-TEST-07 | Service worker full coverage | ✅ Phase 1 (early) — 26 tests, 95.37% coverage |

---

## 6. Functional Requirements

### 6.1 Must-Have (P0)

```
REQ-P2-01
Title: Backend Controller Tests
Package: @smart-apply/api
Maps to: REQ-TEST-02 (original BRD)
Current State: All 5 controllers at 0% — profiles (37 lines, 3 endpoints),
  applications (33 lines, 3 endpoints), optimize (17 lines, 1 endpoint),
  health (11 lines, 1 endpoint), account (15 lines, 1 endpoint).
Required State: Each controller has tests for success paths, input validation,
  and auth guard enforcement via NestJS Testing Module.
Acceptance Criteria:
  - Given ProfilesController, then tests cover:
    - GET /profiles/me returns profile (success), returns null handling
    - POST /profiles/ingest calls service with userId + body
    - PATCH /profiles/me calls service with userId + body
    - Auth guard rejects unauthenticated requests
    Achieves ≥90% statement coverage.
  - Given ApplicationsController, then tests cover:
    - GET /applications lists user applications
    - POST /applications creates application with userId + body
    - PATCH /applications/:id/status updates status with userId + id + body
    - Auth guard rejects unauthenticated requests
    Achieves ≥90% statement coverage.
  - Given OptimizeController, then tests cover:
    - POST /optimize calls service with userId + body
    - Auth guard rejects unauthenticated requests
    Achieves ≥90% statement coverage.
  - Given HealthController, then tests cover:
    - GET /health returns { status: 'ok', timestamp } with valid ISO string
    Achieves 100% statement coverage.
  - Given AccountController, then tests cover:
    - DELETE /account calls service with userId
    - Returns { success: true }
    - Auth guard rejects unauthenticated requests
    Achieves ≥90% statement coverage.
  - Given all controller tests pass, backend overall achieves ≥90% statements.
Dependencies: Phase 1 complete (green baseline)
Estimated Tests: ~18-22 new
Mock Strategy: NestJS Testing Module with mocked services (providers override).
  ClerkAuthGuard mocked to either pass userId or reject. No HTTP-level testing
  (use controller method calls directly via the testing module).
```

```
REQ-P2-02
Title: Web API Client Tests
Package: @smart-apply/web
Maps to: REQ-TEST-08 (original BRD)
Current State: api-client.ts (21 lines) at 0% coverage. Used by every web
  component — single point of failure if broken.
Required State: Full test coverage with mocked fetch.
Acceptance Criteria:
  - Given a successful API response, when apiFetch is called, then parsed
    JSON data is returned with correct type.
  - Given a 401 response, when apiFetch is called, then an error is thrown
    with the server's error message.
  - Given a 500 response, when apiFetch is called, then an error is thrown
    with HTTP status fallback message.
  - Given a network failure, when apiFetch is called, then the fetch error
    propagates.
  - Given a custom auth token, when apiFetch is called, then the Authorization
    header includes the bearer token.
  - Given all tests pass, then api-client.ts achieves 100% statement coverage.
Dependencies: None
Estimated Tests: ~5-6 new
Mock Strategy: vi.stubGlobal('fetch', mockFetch) with controlled Response objects.
```

```
REQ-P2-03
Title: Web Untested Component Tests
Package: @smart-apply/web
Maps to: REQ-TEST-09 (original BRD)
Current State: Three components at 0% — profile-upload.tsx (142 lines),
  applications-table.tsx (47 lines), stats-cards.tsx (40 lines).
Required State: Each component has render + interaction tests covering loading,
  error, empty, and success states.
Acceptance Criteria:
  - Given profile-upload.tsx, then tests cover:
    - Renders idle state with mode selection (paste vs. upload)
    - Text paste mode: entering text and submitting
    - File upload mode: selecting a .txt file triggers extraction
    - Error state: file too large (>5MB) shows error
    - Error state: file too short (<10 chars) shows error
    - Loading state during ingestion
    - Success callback triggers profile query invalidation
    Achieves ≥80% statement coverage.
  - Given applications-table.tsx, then tests cover:
    - Renders table rows with application data
    - Status badge has correct variant mapping
    - Date formatting renders correctly
    - Empty state (no applications)
    Achieves ≥90% statement coverage.
  - Given stats-cards.tsx, then tests cover:
    - Renders 4 stats cards with correct labels
    - Calculates totals, applied count, interviewing count correctly
    - Calculates average ATS improvement, filtering null scores
    - Zero state (no applications) shows 0 values
    Achieves ≥90% statement coverage.
Dependencies: REQ-P2-02 (api-client mocks established for profile-upload)
Estimated Tests: ~12-15 new
Mock Strategy: vi.mock for useAuth, useQueryClient, apiFetch. Render with
  @testing-library/react. Mock pdfjs-dist dynamic import for profile-upload.
```

### 6.2 Should-Have (P1)

```
REQ-P2-04
Title: Web Low-Coverage Component Improvements
Package: @smart-apply/web
Maps to: REQ-TEST-10 (original BRD)
Current State: profile-editor.tsx at 80.56% stmts / 17.64% funcs;
  dashboard-shell.tsx at 74.56% stmts / 33.33% funcs. Key event handlers and
  mutations are untested.
Required State: Missing function coverage filled in — form handlers, mutations,
  and conditional render paths tested.
Acceptance Criteria:
  - Given profile-editor.tsx, then additional tests cover:
    - Edit mode toggle (display → edit → display)
    - Skill add/remove interactions
    - Experience field array add/remove
    - Education field array add/remove
    - Save mutation (success and error paths)
    - Unsaved changes are reflected in form state
    Achieves ≥85% function coverage (up from 17.64%).
  - Given dashboard-shell.tsx, then additional tests cover:
    - View mode toggle (table ↔ pipeline) persists to localStorage
    - Status update mutation (optimistic update)
    - Error and loading state rendering
    Achieves ≥65% function coverage (up from 33.33%).
Dependencies: None (existing test files can be extended)
Estimated Tests: ~8-12 new (added to existing spec files)
Mock Strategy: Extend existing test mocks. Add mutation mock returns for
  useMutation. Mock localStorage for view mode persistence.
```

```
REQ-P2-05
Title: Extension Popup UI Tests (App.tsx)
Package: @smart-apply/extension
Maps to: REQ-TEST-11 (original BRD, pulled forward from Phase 3)
Current State: App.tsx (446 lines) at 0% coverage. This is the primary
  extension popup interface implementing a 5-screen state machine
  (loading → login → dashboard → optimizing → results).
Required State: Component tests covering each screen state and key user
  interactions with Chrome APIs and lib modules mocked.
Acceptance Criteria:
  - Given no auth token in storage, when popup opens, then the login screen
    renders with a sign-in button.
  - Given a valid auth token, when popup opens, then the dashboard screen
    renders with profile summary and action buttons.
  - Given the dashboard screen, when "Sync Profile" is triggered, then a
    loading indicator shows and chrome.tabs.sendMessage is called with
    TRIGGER_SYNC type.
  - Given the dashboard screen, when "Optimize" is triggered, then the
    optimizing screen renders and chrome.tabs.sendMessage is called with
    TRIGGER_OPTIMIZE type.
  - Given optimization results, when the results screen renders, then
    suggested changes are listed with checkboxes (high-confidence ≥0.6
    pre-selected).
  - Given the results screen, when "Generate PDF" is clicked, then
    generateResumePDF is called and a download is triggered.
  - Given any error during an action, then an error message is displayed with
    a retry option.
  - Given all tests pass, then App.tsx achieves ≥80% statement coverage.
  - Given all tests pass, then extension overall achieves ≥75% statements.
Dependencies: Phase 1 chrome-mock.ts + lib module mocks
Estimated Tests: ~12-16 new
Mock Strategy: vi.mock for auth, storage, config, pdf-generator, google-drive
  modules. Use chrome-mock for chrome.tabs, chrome.runtime, chrome.storage,
  chrome.downloads. Render with @testing-library/react + happy-dom. Control
  screen transitions by manipulating mock return values.
```

### 6.3 Could-Have (P2)

```
REQ-P2-06
Title: Web Settings Page Coverage Improvement
Package: @smart-apply/web
Current State: settings-page.tsx at 96% stmts / 56.25% branch / 80% funcs.
  Delete account confirmation flow branches are partially untested.
Required State: Branch coverage improved to ≥80%.
Acceptance Criteria:
  - Given the delete confirmation dialog, when user types "DELETE" and submits,
    then the delete API is called and user is signed out.
  - Given the delete confirmation dialog, when user types wrong text, then the
    submit button remains disabled.
  - Given a delete API error, then the error message is displayed.
Dependencies: None
Estimated Tests: ~2-3 new
Mock Strategy: Extend existing settings-page.spec.tsx.
```

---

## 7. Non-Functional Requirements

| # | Category | Requirement |
|:---|:---|:---|
| NFR-P2-01 | Test Isolation | All new controller tests use NestJS Testing Module — no real HTTP server, no real database, no real auth provider |
| NFR-P2-02 | Component Test Pattern | All React component tests use @testing-library/react with `render()` + queries (`getByRole`, `getByText`). No enzyme. No snapshot tests unless explicitly justified |
| NFR-P2-03 | Performance | Full test suite (all 4 packages) completes in < 60 seconds |
| NFR-P2-04 | No Regressions | All 217 existing tests continue to pass after Phase 2 additions |
| NFR-P2-05 | Mock Consistency | Extension popup tests reuse the existing chrome-mock.ts infrastructure — no parallel mock files |
| NFR-P2-06 | Coverage Config | Web vitest.config.ts updated with `coverage.exclude` for page.tsx, layout.tsx, and providers.tsx files (Phase 3 scope) |

---

## 8. Implementation Priority & Phasing

Phase 2 is split into two sub-phases for incremental delivery:

### Phase 2a — Backend Controllers + Web Foundation

| Req | Title | Package | Est. Tests | Coverage Impact |
|:---|:---|:---|---:|:---|
| REQ-P2-01 | Backend controller tests | Backend | ~20 | Backend 70.91% → ≥90% |
| REQ-P2-02 | Web API client tests | Web | ~6 | Web api-client 0% → 100% |
| REQ-P2-03 | Web untested component tests | Web | ~14 | Web +8-10% |

**Phase 2a outcome:** Backend ≥90%, Web ~72%.

### Phase 2b — Component Improvements + Extension Popup

| Req | Title | Package | Est. Tests | Coverage Impact |
|:---|:---|:---|---:|:---|
| REQ-P2-04 | Web low-coverage improvements | Web | ~10 | Web → ≥75% |
| REQ-P2-05 | Extension popup UI tests | Extension | ~14 | Extension 65% → ≥75% |
| REQ-P2-06 | Web settings improvements | Web | ~3 | Web branch +2% |

**Phase 2b outcome:** Web ≥75%, Extension ≥75%.

---

## 9. Estimated Test Count Summary

| Package | Current Tests | New (Phase 2) | Total (Est.) |
|:---|---:|---:|---:|
| @smart-apply/shared | 23 | 0 | 23 |
| @smart-apply/api (backend) | 47 | ~20 | ~67 |
| @smart-apply/web | 52 | ~33 | ~85 |
| @smart-apply/extension | 95 | ~14 | ~109 |
| **Total** | **217** | **~67** | **~284** |

---

## 10. Coverage Impact Projections

### Backend (→ ≥90%)

| File | Current | Projected | Reason |
|------|--------:|----------:|--------|
| profiles.controller.ts | 0% | ≥90% | 3 endpoint tests + guard test |
| applications.controller.ts | 0% | ≥90% | 3 endpoint tests + guard test |
| optimize.controller.ts | 0% | ≥90% | 1 endpoint test + guard test |
| health.controller.ts | 0% | 100% | 1 simple endpoint |
| account.controller.ts | 0% | ≥90% | 1 endpoint + guard test |
| *.module.ts (excluded) | 0% | 0% | DI wiring — excluded |
| **Overall** | **70.91%** | **≥90%** | Controllers add ~113 tested lines |

### Web (→ ≥75%)

| File | Current | Projected | Reason |
|------|--------:|----------:|--------|
| api-client.ts | 0% | 100% | Full mock coverage |
| applications-table.tsx | 0% | ≥90% | Render + data tests |
| stats-cards.tsx | 0% | ≥90% | Render + calculation tests |
| profile-upload.tsx | 0% | ≥80% | Mode, validation, upload tests |
| profile-editor.tsx | 80.56% (17.64% fn) | ≥85% (≥85% fn) | Form handler tests |
| dashboard-shell.tsx | 74.56% (33.33% fn) | ≥80% (≥65% fn) | Mutation + toggle tests |
| page.tsx / layout.tsx (excluded) | 0% | 0% | Phase 3 scope |
| **Overall** | **60.94%** | **≥75%** | ~229 new tested lines |

### Extension (→ ≥75%)

| File | Current | Projected | Reason |
|------|--------:|----------:|--------|
| App.tsx | 0% | ≥80% | 5-screen state + interactions |
| index.tsx (excluded) | 0% | 0% | Entry point — excluded |
| Background | 95.63% | 95.63% | No changes |
| Content | 79.84% | 79.84% | No changes |
| Lib | 98% | 98% | No changes |
| **Overall** | **65.16%** | **≥75%** | App.tsx adds ~356 tested lines |

---

## 11. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|:---|:---|:---|:---|
| NestJS Testing Module setup complexity for controllers with guards | Medium | Low | Follow established NestJS testing patterns; mock guard at module level |
| profile-upload.tsx requires mocking pdfjs-dist dynamic import | Medium | Medium | Use vi.mock with factory function; test text-paste path separately from PDF path |
| App.tsx state machine complexity (5 screens, multiple async operations) | High | Medium | Test each screen transition independently; mock all chrome/lib dependencies; use act() for async state updates |
| Extension popup rendering requires @testing-library/react in happy-dom | Low | Low | happy-dom already installed; @testing-library/react compatible with happy-dom |
| dashboard-shell.tsx optimistic updates are hard to test deterministically | Medium | Low | Mock useMutation's onMutate callback; verify query cache invalidation |

---

## 12. Out of Scope (Deferred to Phase 3)

| Item | Reason |
|:---|:---|
| Web page.tsx / layout.tsx route shell tests (REQ-TEST-13) | Thin wrappers; Phase 3 polish |
| Extension content script coverage improvements beyond 79.84% | Diminishing returns on DOM fixture creation |
| CI threshold enforcement (NFR-01 from original BRD) | Requires all packages at ≥90%; implement after Phase 3 |
| Web optimize-form.tsx improvements (already at 100% stmts) | Already well-covered |
| Web optimize-results.tsx improvements (87.61% stmts) | Minor gaps; Phase 3 polish |
| Backend account.service.ts (REQ-TEST-12) | Low line count (20 lines); Phase 3 |
| E2E / integration tests | Separate initiative |

---

## 13. Open Questions

| # | Question | Owner | Due |
|:---|:---|:---|:---|
| 1 | Should backend controller tests use `request(app.getHttpServer())` (supertest) or direct method invocation via Testing Module? Direct invocation is simpler but doesn't test routing/decorators. | Engineering Team | Phase 2a start |
| 2 | Does the extension popup (App.tsx) need @testing-library/react installed in the extension package, or can we use React test utilities directly with happy-dom? | Engineering Team | Phase 2b start |
| 3 | Should profile-upload.tsx PDF tests be deferred if pdfjs-dist mocking proves overly complex? Text-paste path coverage alone would achieve ~60%. | Engineering Team | Phase 2a execution |
| 4 | Should web coverage.exclude be configured now to exclude page.tsx and layout.tsx files, or wait until Phase 3 when those files get tested? | Engineering Team | Phase 2a start |

---

## 14. Approval Checklist

- [x] All P0 requirements have at least two acceptance criteria
- [x] Every requirement references specific package, files, and line counts
- [x] Phase 1 completion status documented with actual coverage numbers
- [x] Coverage targets are realistic with per-file projections
- [x] Requirements mapped to original BRD (REQ-TEST-02, 08, 09, 10, 11)
- [x] Service worker (REQ-TEST-07) marked complete — no redundant work
- [x] Estimated test counts provided for planning
- [x] Risk assessment included with mitigations
- [x] Out-of-scope items documented to prevent scope creep
- [x] Non-functional requirements cover isolation, patterns, and regression safety
