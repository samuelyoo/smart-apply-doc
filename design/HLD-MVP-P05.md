---
title: "HLD-MVP-P05 — Test Coverage Completion"
permalink: /design/hld-mvp-p05/
---

# HLD-MVP-P05 — Test Coverage Completion

**Version:** 1.0  
**Date:** 2026-03-29  
**Phase:** Test Coverage Completion  
**Source:** BRD-MVP-03.md (driven by LLD-MVP-P04 §10 Implementation Review, W-01 through W-05)  
**Prerequisite:** Phase P04 (Security, Testing & Quality Hardening) approved with warnings.

---

## 1. Phase Objective

### Business Goal

Close all test coverage gaps identified in the P04 implementation review so that every LLD-MVP-P04 test specification is fully implemented. This is the final gate before declaring the product beta-ready.

### User-Facing Outcome After This Phase

No user-facing changes. This phase is exclusively test infrastructure work. After completion, 100+ automated tests will cover all critical user journeys across all four packages, providing confidence for beta deployment. CI will catch regressions in web components, PDF generation, optimization flow, audit logging, and CORS security.

---

## 2. Component Scope

### Repos Affected

| Repo | Impact | Justification |
|:---|:---|:---|
| smart-apply-web | **HIGH** — 5 new test files | W-01: Web component tests for OptimizeForm, OptimizeResults, DashboardShell, ProfileEditor, SettingsPage |
| smart-apply-extension | **MEDIUM** — 1 new + 1 extended test file | W-02: pdf-generator.spec.ts (new); W-03: extend service-worker.spec.ts (OPTIMIZE_JD) |
| smart-apply-backend | **LOW** — 1 new + 1 extended test file | W-04: extend webhooks.controller.spec.ts (audit); W-05: cors.spec.ts (new) |
| smart-apply-shared | **NONE** | No changes needed |

### REQ Mapping

| REQ | Title | Repos | Priority |
|:---|:---|:---|:---|
| REQ-03-01 | OptimizeForm Tests | web | P1 |
| REQ-03-02 | OptimizeResults Tests | web | P1 |
| REQ-03-03 | DashboardShell Tests | web | P1 |
| REQ-03-04 | ProfileEditor Tests | web | P1 |
| REQ-03-05 | SettingsPage Tests | web | P1 |
| REQ-03-06 | PDF Generator Tests | extension | P1 |
| REQ-03-07 | OPTIMIZE_JD Handler Tests | extension | P1 |
| REQ-03-08 | Webhook Audit Assertion Tests | backend | P2 |
| REQ-03-09 | CORS Restriction Unit Tests | backend | P2 |

### Explicitly Out of Scope

- New feature development (no production code changes)
- Integration or E2E tests (this phase is unit/component tests only)
- REQ-02-12 through REQ-02-16 (P2 deferred items from BRD-MVP-02)
- Refactoring production code for testability beyond minimal extraction (e.g., CORS callback extraction)

---

## 3. Architecture Decisions

### AD-01: Component Test Isolation Strategy

**Decision:** All web component tests use mocked fetch and mocked Clerk auth, never hitting real APIs or auth providers.

**Rationale:** Component tests validate rendering behavior and user interactions in isolation. External dependencies (API, auth) are mocked to ensure fast, deterministic tests. This aligns with architecture.md §7 which separates client responsibilities from server intelligence.

**Mock Stack:**
- `@clerk/nextjs` — mock `useAuth()` returning `{ isSignedIn: true, getToken: vi.fn() }` and `useUser()` returning user object
- `next/navigation` — mock `useRouter()`, `useSearchParams()`
- `global.fetch` — mock with `vi.fn()` for API responses
- `@tanstack/react-query` — wrap components in `QueryClientProvider` with test query client

### AD-02: Extend Existing Test Files vs. Create New

**Decision:** W-03 (OPTIMIZE_JD) and W-04 (audit assertions) extend existing test files. All other gaps create new files.

**Rationale:** service-worker.spec.ts and webhooks.controller.spec.ts already have the mock setup, describe blocks, and import patterns. Adding new describe blocks to these files minimizes duplication and keeps related tests co-located.

### AD-03: CORS Callback Extraction for Testability

**Decision:** Extract the CORS `origin` callback from `main.ts` into a standalone exported function `validateCorsOrigin()` so it can be unit-tested without bootstrapping the full NestJS application.

**Current State:**
```typescript
// main.ts — CORS callback inline in bootstrap()
app.enableCors({
  origin: (origin, callback) => {
    // 3-tier check logic embedded in bootstrap
  },
});
```

**Target State:**
```typescript
// cors.ts (new) — exported for testing
export function validateCorsOrigin(
  origin: string | undefined,
  allowedOrigins: string[],
  extensionId: string | undefined,
  isProd: boolean,
): { allowed: boolean; error?: string }

// main.ts — uses validateCorsOrigin()
app.enableCors({
  origin: (origin, callback) => {
    const result = validateCorsOrigin(origin, allowedOrigins, extId, isProd);
    result.allowed ? callback(null, true) : callback(new Error(result.error!));
  },
});
```

**Rationale:** The current CORS logic is embedded inside the NestJS bootstrap function, making it untestable without spinning up the full app. Extracting it into a pure function enables direct unit testing of all 6 CORS origin scenarios.

---

## 4. Data Flow

No new data flows. This phase only adds test coverage for existing flows:

1. **Web Component Flow (tested by REQ-03-01 through REQ-03-05):** User interacts with React components → components call API via fetch → components render response data. Tests mock the fetch layer.

2. **PDF Generation Flow (tested by REQ-03-06):** ResumeData input → pdf-lib generates PDF bytes → Uint8Array output. Tests call the function directly.

3. **OPTIMIZE_JD Flow (tested by REQ-03-07):** Chrome message → handler calls apiFetch → stores context in chrome.storage → returns result. Tests mock apiFetch and chrome.storage.

4. **Webhook Audit Flow (tested by REQ-03-08):** Clerk webhook → service deletes user → service inserts audit_events row. Tests assert mock insert calls.

5. **CORS Validation Flow (tested by REQ-03-09):** HTTP request origin → validateCorsOrigin() → allow/reject. Tests call function directly with different origins.

---

## 5. API Contracts

No new API endpoints. No API changes. All tests mock existing endpoints.

---

## 6. Security Considerations

- **No security changes in this phase.** All security controls were implemented in P04.
- **REQ-03-09 (CORS tests)** validates the existing CORS security implementation, increasing confidence in the security posture.
- **REQ-03-08 (Audit tests)** validates the existing audit log, ensuring compliance events are properly recorded.
- **Test mocks must not weaken security assertions** — mock Clerk auth must default to authenticated state but tests should verify component behavior handles both authenticated and unauthenticated states where relevant.

---

## 7. Dependencies & Integration Points

### From Previous Phases

| Dependency | Phase | Status |
|:---|:---|:---|
| Vitest configured for all 4 packages | P04 | ✅ Complete |
| React Testing Library + jsdom for web | P04 | ✅ Complete |
| Chrome API mocks for extension | P04 | ✅ Complete |
| CI pipeline running tests for all packages | P04 | ✅ Complete |
| web/test/setup.ts with @testing-library/jest-dom | P04 | ✅ Complete |
| extension/test/chrome-mock.ts with storage/runtime mocks | P04 | ✅ Complete |

### External Dependencies

None. All tests use mocks for external services. No new packages required (may need `@tanstack/react-query` in web devDependencies if not already present, but it's already a production dependency).

---

## 8. Acceptance Criteria Summary

### Unit Testable

| # | Criterion | Test Type | REQ |
|:---|:---|:---|:---|
| AC-1 | OptimizeForm renders textarea, button; submits JD; shows loading; shows error | Component (RTL) | REQ-03-01 |
| AC-2 | OptimizeResults displays scores, checkboxes, toggles, warnings, badges | Component (RTL) | REQ-03-02 |
| AC-3 | DashboardShell fetches and renders history, shows empty/loading states | Component (RTL) | REQ-03-03 |
| AC-4 | ProfileEditor loads profile, submits updates, shows validation errors | Component (RTL) | REQ-03-04 |
| AC-5 | SettingsPage shows account info, delete dialog, typing DELETE, calls API | Component (RTL) | REQ-03-05 |
| AC-6 | generateResumePDF produces valid PDF bytes, handles empty arrays | Unit | REQ-03-06 |
| AC-7 | OPTIMIZE_JD handler calls API, stores context, returns result | Unit (mock) | REQ-03-07 |
| AC-8 | Webhook audit inserts row, validates fields, tolerates insert failure | Unit (mock) | REQ-03-08 |
| AC-9 | CORS validation allows/rejects origins per 6 scenarios | Unit | REQ-03-09 |

### CI Verifiable

| # | Criterion |
|:---|:---|
| CI-1 | All existing 66 tests continue to pass (no regressions) |
| CI-2 | All new tests pass in CI |
| CI-3 | Total test count ≥ 101 across all 4 packages |
| CI-4 | All 4 packages typecheck clean |
