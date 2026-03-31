---
title: "HLD-TEST-P02 — Controllers, Components & Popup UI"
permalink: /design/hld-test-p02/
---

# HLD-TEST-P02 — Controllers, Components & Popup UI (BRD-TEST Phase 2)

**Phase:** Test Enhancement Phase 2 — Controllers, Components & Popup UI
**Version:** 1.0
**Date:** 2026-03-30
**Source:** BRD_enhance_unit_test_phase2_2026-03-30.md (REQ-P2-01 through REQ-P2-06)
**Predecessor:** HLD-TEST-P01.md (Phase 1 — APPROVED per REVIEW-TEST-P01.md)

---

## 1. Phase Objective

### Business Goal
Close the three highest-impact coverage gaps remaining after Phase 1: backend controllers (0% → ≥90%), web components (60.94% → ≥75%), and the extension popup UI (0% App.tsx → ≥80%). After this phase, every user-facing code path — controller endpoints, dashboard components, and the Chrome extension popup — carries test coverage sufficient for safe refactoring.

### Developer-Facing Outcome
- Backend overall ≥90% statement coverage (up from 70.91%).
- Web overall ≥75% statement coverage (up from 60.94%).
- Extension overall ≥75% statement coverage (up from 65.16%).
- All 217 existing tests continue to pass (zero regressions).
- ~67 new tests across three packages.

---

## 2. Component Scope

### In Scope

| Repo | Changes |
|---|---|
| **smart-apply-backend** | Add `profiles.controller.spec.ts` (~5 tests); add `applications.controller.spec.ts` (~5 tests); add `optimize.controller.spec.ts` (~3 tests); add `health.controller.spec.ts` (~2 tests); add `account.controller.spec.ts` (~3 tests) |
| **smart-apply-web** | Add `api-client.spec.ts` (~6 tests); add `profile-upload.spec.tsx` (~7 tests); add `applications-table.spec.tsx` (~4 tests); add `stats-cards.spec.tsx` (~4 tests); extend `profile-editor.spec.tsx` (~6 new tests); extend `dashboard-shell.spec.tsx` (~4 new tests); extend `settings-page.spec.tsx` (~3 new tests) |
| **smart-apply-extension** | Add `app.spec.tsx` (~14 tests) |

### Out of Scope
- Web `page.tsx` / `layout.tsx` route shell tests (Phase 3 — REQ-TEST-13)
- Extension content script improvements beyond 79.84% (diminishing returns)
- CI threshold enforcement (Phase 3 — NFR-01)
- Backend `account.service.ts` additional tests (Phase 3)
- Backend `*.module.ts` DI wiring tests (declarative — excluded)
- E2E / integration tests (separate initiative)

---

## 3. Architecture Decisions

### AD-01: Controller Tests Use NestJS Testing Module with Direct Method Invocation (REQ-P2-01)

Controller tests will create a NestJS `TestingModule` with the controller under test and mock providers for each injected service. Tests invoke controller methods directly (e.g., `controller.getProfile(mockRequest)`) rather than spinning up an HTTP server with supertest.

**Rationale:**
1. Controllers are thin pass-through layers — each method calls one service method and returns the result.
2. Direct invocation is faster (~0ms per test vs ~50ms for HTTP setup/teardown).
3. Routing decorators (`@Get`, `@Post`, etc.) are framework-tested by NestJS itself.
4. Auth guard behavior is tested separately by overriding the guard in the testing module.

**Trade-off:** Route paths and HTTP verbs are not verified by these tests. This is acceptable because the controller layer is declarative — deviations would be caught in manual testing or future E2E tests.

### AD-02: ClerkAuthGuard Tested via Module Override, Not HTTP Interception (REQ-P2-01)

For each controller, two guard scenarios are tested:
1. **Guard passes:** Override `ClerkAuthGuard` with a mock guard that sets `request.userId = 'test-user-id'` and returns `true`.
2. **Guard rejects:** Override `ClerkAuthGuard` with a mock guard that throws `UnauthorizedException`.

This validates that controllers are decorated with `@UseGuards(ClerkAuthGuard)` without requiring real JWT tokens or Clerk API calls.

**Justification:** architecture.md §3 — auth is enforced at the controller boundary; the guard itself is already unit-tested in `auth.guard.spec.ts`.

### AD-03: Web Component Tests Use @testing-library/react with vi.mock for Dependencies (REQ-P2-02 through REQ-P2-04)

All web component tests follow a consistent pattern:
1. `vi.mock('@clerk/nextjs')` — provides `useAuth()` returning `{ getToken: vi.fn() }`.
2. `vi.mock('@tanstack/react-query')` — provides controlled `useQuery`/`useMutation`/`useQueryClient` mocks.
3. `vi.mock('@/lib/api-client')` — provides mock `apiFetch` for components that call the API.
4. Render with `@testing-library/react`'s `render()`, query with `getByRole`/`getByText`/`findByText`.
5. Interactions via `fireEvent` or `@testing-library/user-event`.

**Justification:** architecture.md — UI components must handle loading, error, empty, and success states. @testing-library enforces testing from the user's perspective.

### AD-04: profile-upload.tsx PDF Path Uses vi.mock for Dynamic Import (REQ-P2-03)

`profile-upload.tsx` dynamically imports `pdfjs-dist` via `import('pdfjs-dist')`. Tests will mock this dynamic import:

```typescript
vi.mock('pdfjs-dist', () => ({
  getDocument: vi.fn().mockReturnValue({
    promise: Promise.resolve({
      numPages: 1,
      getPage: vi.fn().mockResolvedValue({
        getTextContent: vi.fn().mockResolvedValue({
          items: [{ str: 'Extracted PDF text content here' }],
        }),
      }),
    }),
  }),
}));
```

The text-paste path is tested separately without PDF mocking, ensuring at least two independent code paths are covered.

### AD-05: Extension App.tsx Tests Reuse chrome-mock.ts and Mock All Lib Modules (REQ-P2-05)

App.tsx imports from five internal lib modules (`auth`, `storage`, `config`, `pdf-generator`, `google-drive`) and uses four Chrome APIs (`chrome.storage`, `chrome.runtime`, `chrome.tabs`, `chrome.downloads`). Tests will:

1. Import and call `resetChromeMock()` in `beforeEach` (reuse existing infrastructure from Phase 1).
2. `vi.mock('../../../lib/auth')` — control `getAuthToken` return to drive screen transitions.
3. `vi.mock('../../../lib/storage')` — control stored data for optimization results.
4. `vi.mock('../../../lib/config')` — provide `{ webBaseUrl: 'http://test.local', apiBaseUrl: 'http://api.test.local' }`.
5. `vi.mock('../../../lib/pdf-generator')` — mock `generateResumePDF` returning `Uint8Array`.
6. `vi.mock('../../../lib/google-drive')` — mock `uploadPdfToDrive` returning a URL string.
7. Render with `@testing-library/react` + happy-dom environment (already configured).

Each screen state (loading, login, dashboard, optimizing, results) is tested by controlling mock return values before render or triggering state transitions via interactions.

**Justification:** NFR-P2-05 — extension popup tests must reuse existing chrome-mock.ts infrastructure.

### AD-06: Web Coverage Exclusions Configured Now (NFR-P2-06)

Web `vitest.config.ts` will be updated to add `coverage.exclude` for `page.tsx`, `layout.tsx`, and `providers.tsx` files. This prevents these Phase 3 files from dragging down the measured coverage baseline.

---

## 4. Test Strategy Overview

### 4.1 Phase 2a — Backend Controllers + Web Foundation

#### Backend Test Organization

```
smart-apply-backend/
  test/
    profiles.controller.spec.ts   ← NEW (~5 tests)
    applications.controller.spec.ts ← NEW (~5 tests)
    optimize.controller.spec.ts   ← NEW (~3 tests)
    health.controller.spec.ts     ← NEW (~2 tests)
    account.controller.spec.ts    ← NEW (~3 tests)
    auth.guard.spec.ts            ← EXISTING (no changes)
    profiles.service.spec.ts      ← EXISTING (no changes)
    applications.service.spec.ts  ← EXISTING (no changes)
    optimize.service.spec.ts      ← EXISTING (no changes)
    scoring.service.spec.ts       ← EXISTING (no changes)
```

#### Web Foundation Test Organization

```
smart-apply-web/
  test/
    api-client.spec.ts            ← NEW (~6 tests)
    profile-upload.spec.tsx       ← NEW (~7 tests)
    applications-table.spec.tsx   ← NEW (~4 tests)
    stats-cards.spec.tsx          ← NEW (~4 tests)
```

### 4.2 Phase 2b — Component Improvements + Extension Popup

#### Web Improvement Tests

```
smart-apply-web/
  test/
    profile-editor.spec.tsx       ← EXTEND (+6 tests)
    dashboard-shell.spec.tsx      ← EXTEND (+4 tests)
    settings-page.spec.tsx        ← EXTEND (+3 tests)
```

#### Extension Popup Test

```
smart-apply-extension/
  test/
    app.spec.tsx                  ← NEW (~14 tests)
```

---

## 5. Mock Boundaries

### 5.1 Backend Controller Mocks

| Controller Under Test | Mocked Dependency | Mock Strategy |
|---|---|---|
| ProfilesController | ProfilesService | `{ getProfile: vi.fn(), ingestProfile: vi.fn(), updateProfile: vi.fn() }` |
| ProfilesController | ClerkAuthGuard | Module override: `{ canActivate: () => true }` with request.userId set |
| ApplicationsController | ApplicationsService | `{ list: vi.fn(), create: vi.fn(), updateStatus: vi.fn() }` |
| OptimizeController | OptimizeService | `{ optimize: vi.fn() }` |
| HealthController | (none) | No dependencies — test directly |
| AccountController | AccountService | `{ deleteAccount: vi.fn() }` |

### 5.2 Web Component Mocks

| Component Under Test | Mocked Dependency | Mock Strategy |
|---|---|---|
| api-client.ts | global `fetch` | `vi.stubGlobal('fetch', vi.fn())` with controlled Response objects |
| profile-upload.tsx | `@clerk/nextjs`, `@tanstack/react-query`, `@/lib/api-client`, `pdfjs-dist` | `vi.mock()` for each; control `useAuth`, `useQueryClient`, `apiFetch`, PDF extraction |
| applications-table.tsx | (none) | Pure presentational — pass props directly |
| stats-cards.tsx | (none) | Pure presentational — pass props directly |
| profile-editor.tsx | `@clerk/nextjs`, `@tanstack/react-query`, `@/lib/api-client` | Extend existing mocks; add `useMutation` mock for save handler |
| dashboard-shell.tsx | Child components, `@tanstack/react-query`, `localStorage` | Mock children as stubs; add `useMutation` mock; spy on `localStorage` |
| settings-page.tsx | `@clerk/nextjs`, `@/lib/api-client` | Extend existing mocks for delete confirmation flow |

### 5.3 Extension Popup Mocks

| Module Under Test | Mocked Dependency | Mock Strategy |
|---|---|---|
| App.tsx | `../../../lib/auth` | `vi.mock()`: `getAuthToken` resolves to token or null |
| App.tsx | `../../../lib/storage` | `vi.mock()`: control stored optimization results |
| App.tsx | `../../../lib/config` | `vi.mock()`: return static config object |
| App.tsx | `../../../lib/pdf-generator` | `vi.mock()`: `generateResumePDF` returns mock Uint8Array |
| App.tsx | `../../../lib/google-drive` | `vi.mock()`: `uploadPdfToDrive` returns mock URL |
| App.tsx | Chrome APIs | `chrome-mock.ts`: `resetChromeMock()` + `seedStorage()` in beforeEach |

---

## 6. Data Flow (Test Execution)

### 6.1 Backend Controller Test Flow

```
Test setup:
  1. Create TestingModule with controller + mocked service providers
  2. Override ClerkAuthGuard with mock guard (pass or reject)
  3. Get controller instance from module

Success path:
  → Set mock service method to resolve with expected data
  → Create mock request object with userId property
  → Call controller.method(request, ...args)
  → Assert result equals expected data
  → Assert service method was called with (userId, ...args)

Guard rejection path:
  → Override guard to throw UnauthorizedException
  → Assert controller method invocation throws UnauthorizedException
```

### 6.2 Web API Client Test Flow

```
Test setup: vi.stubGlobal('fetch', mockFetch)

Success path:
  → mockFetch resolves Response({ json: { data: {...} }, ok: true, status: 200 })
  → Call apiFetch('/api/test', 'test-token')
  → Assert result is { data: {...} }
  → Assert fetch called with correct URL, Authorization header

Error path:
  → mockFetch resolves Response({ ok: false, status: 401, json: { error: 'Unauthorized' } })
  → Call apiFetch('/api/test', 'test-token')
  → Assert throws Error('Unauthorized')
```

### 6.3 Web Component Test Flow

```
Test setup: vi.mock dependencies, prepare props/mock returns

Render test:
  → render(<Component {...props} />)
  → Assert element presence with getByText/getByRole
  → Assert correct data display

Interaction test:
  → render(<Component />)
  → fireEvent.click(getByRole('button', { name: /submit/ }))
  → Assert mock function called with expected args
  → Assert UI updates (loading → success states)
```

### 6.4 Extension Popup Test Flow

```
Test setup:
  1. resetChromeMock()
  2. vi.mock all lib modules
  3. Configure mock return values for desired screen state

Screen transition test:
  → Mock getAuthToken to return null
  → render(<App />)
  → Assert login screen visible (getByText('Sign In'))

  → Mock getAuthToken to return 'valid-token'
  → Rerender or trigger storage change
  → Assert dashboard screen visible (getByText('Smart Apply'))

Action test:
  → Render dashboard screen (auth token mocked)
  → fireEvent.click(getByText('Optimize for This Job'))
  → Assert chrome.runtime.sendMessage called with { type: 'TRIGGER_OPTIMIZE' }
  → Assert screen transitions to optimizing state
```

---

## 7. Security Considerations

| Concern | Mitigation |
|---|---|
| Controller tests must verify auth guard enforcement | Each controller spec includes a "rejects unauthenticated request" test that asserts UnauthorizedException when guard is configured to reject |
| Test fixtures must not contain real credentials | All test data uses synthetic values: `'test-user-id'`, `'mock-token'`, fixture objects with fake data |
| Mock bypass allowing real external calls | All external dependencies (Clerk, Supabase, Chrome APIs, Google Drive, PDF libs) are mocked via `vi.mock()` or provider override. No real network calls in unit tests |
| Web API client tests must verify auth header presence | API client tests assert that `Authorization: Bearer <token>` header is sent on every request |

---

## 8. Dependencies & Integration Points

| Dependency | Status | Notes |
|---|---|---|
| Phase 1 complete (217 tests, 0 failures) | ✅ | REVIEW-TEST-P01 APPROVED |
| Vitest 3.2.4 + @vitest/coverage-v8 3.2.4 | ✅ | Installed in all packages |
| @testing-library/react | ✅ | Installed in web + extension |
| happy-dom (extension test environment) | ✅ | Configured in extension vitest.config.ts |
| jsdom (web test environment) | ✅ | Configured in web vitest.config.ts |
| chrome-mock.ts (extension mock infra) | ✅ | Complete — Phase 1 |
| NestJS @nestjs/testing | ✅ | Available in backend devDependencies |
| Existing service spec patterns (backend) | ✅ | Established in optimize/profiles/applications service specs |
| Existing component spec patterns (web) | ✅ | Established in profile-editor/dashboard-shell/settings-page specs |

---

## 9. Acceptance Criteria Summary

### REQ-P2-01: Backend Controller Tests
- [ ] `profiles.controller.spec.ts` covers GET/POST/PATCH endpoints + guard rejection (~5 tests)
- [ ] `applications.controller.spec.ts` covers GET/POST/PATCH endpoints + guard rejection (~5 tests)
- [ ] `optimize.controller.spec.ts` covers POST endpoint + guard rejection (~3 tests)
- [ ] `health.controller.spec.ts` covers GET endpoint returning status + timestamp (~2 tests)
- [ ] `account.controller.spec.ts` covers DELETE endpoint + guard rejection (~3 tests)
- [ ] Backend overall achieves ≥90% statement coverage

### REQ-P2-02: Web API Client Tests
- [ ] `api-client.spec.ts` covers success, 401, 500, network error, auth header, custom options (~6 tests)
- [ ] `api-client.ts` achieves 100% statement coverage

### REQ-P2-03: Web Untested Component Tests
- [ ] `profile-upload.spec.tsx` covers idle render, paste mode, file upload, size error, short text error, loading, success (~7 tests)
- [ ] `applications-table.spec.tsx` covers data render, badge variants, date formatting, empty state (~4 tests)
- [ ] `stats-cards.spec.tsx` covers all 4 cards, calculations, zero state (~4 tests)
- [ ] Each component achieves target coverage per BRD

### REQ-P2-04: Web Low-Coverage Improvements
- [ ] `profile-editor.spec.tsx` extended with skill add/remove, field array operations, save mutation tests (~6 new)
- [ ] `dashboard-shell.spec.tsx` extended with view toggle, status mutation, error state tests (~4 new)
- [ ] profile-editor.tsx achieves ≥85% function coverage
- [ ] dashboard-shell.tsx achieves ≥65% function coverage

### REQ-P2-05: Extension Popup UI Tests
- [ ] `app.spec.tsx` covers loading screen, login screen, dashboard screen, sync action, optimize action, results screen with change selection, PDF generation, error + retry, autofill toggle (~14 tests)
- [ ] App.tsx achieves ≥80% statement coverage
- [ ] Extension overall achieves ≥75% statement coverage

### REQ-P2-06: Web Settings Improvements
- [ ] `settings-page.spec.tsx` extended with delete confirmation, wrong text, and error tests (~3 new)
- [ ] settings-page.tsx branch coverage ≥80%

### Phase 2 Overall
- [ ] All 217 existing tests continue to pass (zero regressions)
- [ ] ~67 new tests pass (zero failures)
- [ ] Backend ≥90%, Web ≥75%, Extension ≥75% statement coverage
- [ ] Full test suite completes in < 60 seconds (NFR-P2-03)
