---
title: BRD — MVP 03
description: Business Requirements Document for MVP Phase 3, driven by P04 Implementation Review warnings W-01 through W-05.
hero_eyebrow: Business requirements
hero_title: BRD for MVP 03
hero_summary: Translates test coverage gaps identified in the P04 implementation architect review into prioritised business requirements for the next development phase.
permalink: /brd-mvp-03/
---

# Business Requirements Document — MVP 03

**Version:** 1.0  
**Date:** 2026-03-29  
**Source:** LLD-MVP-P04.md §10 (Implementation Review — W-01 through W-05)  
**Author:** Business Analyst Agent  
**Reviewed By:** Architect Agent  

---

## 1. Executive Summary

The Phase P04 development cycle (Security, Testing & Quality Hardening) was approved with all P0 security requirements fully implemented and 66 tests passing across all four packages. However, the architect review identified five test coverage gaps (W-01 through W-05) that must be closed before declaring the product beta-ready. The test infrastructure is in place — Vitest configs, test setups, Chrome API mocks, and CI pipeline are all operational — so these gaps represent missing test files and test cases rather than missing tooling.

The highest-priority gap is W-01: zero web component tests exist despite the test framework being ready. Five React component test files covering the core user journey (optimize, dashboard, profile, settings) were specified in LLD-MVP-P04 §5.6 but not created. The remaining gaps (W-02 through W-05) are lower-severity: missing PDF generator tests, incomplete service worker handler tests, missing audit assertion tests, and missing CORS unit tests.

After this phase, all LLD-MVP-P04 test specifications will be fully implemented, bringing total test coverage to approximately 100+ tests across all four packages and closing the last gaps before beta gate.

---

## 2. Stakeholder Goals

| Stakeholder | Goal | Success Metric |
|:---|:---|:---|
| Product Owner | Reach beta deployment confidence with complete test coverage across all user-facing components | All 5 web component test suites passing; all LLD §5 test specs implemented |
| Engineering Team | Eliminate regression risk on core user journey pages | ≥19 new web component tests covering optimize, dashboard, profile, and settings flows |
| Engineering Team | Complete extension test coverage for PDF generation and remaining handlers | pdf-generator and OPTIMIZE_JD handler tests passing |
| Engineering Team | Validate security controls with dedicated unit tests | CORS restriction tests and audit log assertion tests passing |

---

## 3. Previous Phase Outcomes

### 3.1 Requirements Closed (from BRD-MVP-02 / Phase P04)

| REQ ID | Title | Status |
|:---|:---|:---|
| REQ-02-01 | Fix Web Middleware Route Protection | ✅ PASS — closing |
| REQ-02-02 | Restrict CORS to Specific Extension ID | ✅ PASS — closing |
| REQ-02-03 | Complete Extension 401 Handling | ✅ PASS — closing |
| REQ-02-04 | Complete Google Drive Integration | ✅ PASS — closing |
| REQ-02-05 | Establish Test Frameworks for All Packages | ✅ PASS — closing |
| REQ-02-06 | P0 Regression Test Suite | ✅ PASS — closing |
| REQ-02-09 | Complete CI Pipeline Coverage | ✅ PASS — closing |
| REQ-02-10 | Account Deletion Audit Log | ✅ PASS — closing |
| REQ-02-11 | Extension Error State Retry Buttons | ✅ PASS — closing |

### 3.2 Requirements Carried Forward

| REQ ID | Original Priority | New Priority | Change Reason |
|:---|:---|:---|:---|
| REQ-02-07 | P1 | P1 | NOT IMPLEMENTED — 5 web component test files not created (W-01). Test framework is ready. |
| REQ-02-08 | P1 | P1 | PARTIAL — service-worker tests created but pdf-generator.spec.ts missing (W-02) and OPTIMIZE_JD handler tests missing (W-03). |
| REQ-02-12–16 | P2 | P2 | DEFERRED (intentional) — structured logging, ESLint/Prettier, npm audit, unsafe type casts. |

---

## 4. Functional Requirements

### 4.1 Must-Have (P0)

_No P0 requirements — all security and infrastructure blockers were resolved in Phase P04._

### 4.2 Should-Have (P1 — Beta Gate)

```
REQ-03-01
Title: Web Component Test Coverage — OptimizeForm
Source: W-01, LLD-MVP-P04 §5.6, REQ-02-07
User Story: As an engineer, I want automated tests for the OptimizeForm component
  so that regressions in the JD submission flow are caught before deployment.
Current State: No test file exists. Test framework (Vitest + React Testing Library
  + jsdom) is configured and operational for the web package.
Required State: smart-apply-web/test/components/optimize-form.spec.tsx exists with
  4 test cases covering the core component behavior.
Acceptance Criteria:
  - AC-1: Given the component renders, then a JD textarea and submit button are
    visible.
  - AC-2: Given text entered in the textarea, when submit is clicked, then the
    JD text is sent to the optimize API.
  - AC-3: Given a submission in progress, then a loading spinner is displayed.
  - AC-4: Given an API error response, then an error message is displayed.
Architect Notes: S effort. Test framework already configured. Mock fetch for API.
Dependencies: smart-apply-web/test/setup.ts (exists)
```

```
REQ-03-02
Title: Web Component Test Coverage — OptimizeResults
Source: W-01, LLD-MVP-P04 §5.6, REQ-02-07
User Story: As an engineer, I want automated tests for the OptimizeResults
  component so that regressions in the optimization review UI are caught before
  deployment.
Current State: No test file exists. Test framework is configured.
Required State: smart-apply-web/test/components/optimize-results.spec.tsx exists
  with 5 test cases covering the results display and interaction behavior.
Acceptance Criteria:
  - AC-1: Given optimization results, then before/after ATS scores are displayed.
  - AC-2: Given suggested changes, then each change is rendered with a checkbox.
  - AC-3: Given a checkbox is clicked, then the selection state toggles.
  - AC-4: Given warnings in the results, then warning messages are displayed.
  - AC-5: Given confidence data, then confidence badges are rendered.
Architect Notes: S effort. Requires mock optimization response data fixture.
Dependencies: smart-apply-web/test/setup.ts (exists)
```

```
REQ-03-03
Title: Web Component Test Coverage — DashboardShell
Source: W-01, LLD-MVP-P04 §5.6, REQ-02-07
User Story: As an engineer, I want automated tests for the DashboardShell
  component so that regressions in the application history display are caught
  before deployment.
Current State: No test file exists. Test framework is configured.
Required State: smart-apply-web/test/components/dashboard-shell.spec.tsx exists
  with 3 test cases covering history fetching and state handling.
Acceptance Criteria:
  - AC-1: Given application history data, then history entries are rendered.
  - AC-2: Given no history data, then an empty state message is displayed.
  - AC-3: Given data is loading, then a loading state is displayed.
Architect Notes: S effort. Mock fetch for /api/applications endpoint.
Dependencies: smart-apply-web/test/setup.ts (exists)
```

```
REQ-03-04
Title: Web Component Test Coverage — ProfileEditor
Source: W-01, LLD-MVP-P04 §5.6, REQ-02-07
User Story: As an engineer, I want automated tests for the ProfileEditor
  component so that regressions in profile viewing and editing are caught before
  deployment.
Current State: No test file exists. Test framework is configured.
Required State: smart-apply-web/test/components/profile-editor.spec.tsx exists
  with 3 test cases covering profile load and submit behavior.
Acceptance Criteria:
  - AC-1: Given a fetched profile, then profile data is displayed in the form.
  - AC-2: Given updated profile data, when submit is clicked, then the updated
    profile is sent to the API.
  - AC-3: Given validation errors, then error messages are displayed.
Architect Notes: S effort. Mock fetch for /api/profile/me endpoint.
Dependencies: smart-apply-web/test/setup.ts (exists)
```

```
REQ-03-05
Title: Web Component Test Coverage — SettingsPage
Source: W-01, LLD-MVP-P04 §5.6, REQ-02-07
User Story: As an engineer, I want automated tests for the SettingsPage component
  so that regressions in account settings and deletion flow are caught before
  deployment.
Current State: No test file exists. Test framework is configured.
Required State: smart-apply-web/test/components/settings-page.spec.tsx exists
  with 4 test cases covering account info display and deletion confirmation.
Acceptance Criteria:
  - AC-1: Given a signed-in user, then account information is displayed.
  - AC-2: Given the delete account button is clicked, then a confirmation dialog
    is shown.
  - AC-3: Given the confirmation dialog, when the user types DELETE, then the
    confirm button becomes enabled.
  - AC-4: Given confirmation, when confirm is clicked, then the delete account
    API is called.
Architect Notes: S effort. Mock @clerk/nextjs for auth context and user data.
Dependencies: smart-apply-web/test/setup.ts (exists)
```

```
REQ-03-06
Title: Extension PDF Generator Test Coverage
Source: W-02, LLD-MVP-P04 §5.5, REQ-02-08
User Story: As an engineer, I want automated tests for the PDF generator module
  so that PDF generation regressions are caught before deployment.
Current State: No test file exists. pdf-lib runs in Node so no special mocks needed.
Required State: smart-apply-extension/test/pdf-generator.spec.ts exists with 4
  test cases validating PDF output.
Acceptance Criteria:
  - AC-1: Given valid profile input, then a non-empty Uint8Array is produced.
  - AC-2: Given the output bytes, then the PDF header (%PDF-) is present.
  - AC-3: Given an empty experience array, then PDF generates without error.
  - AC-4: Given an empty skills array, then PDF generates without error.
Architect Notes: S effort. Pure unit tests, no mocks required.
Dependencies: pdf-lib (installed)
```

```
REQ-03-07
Title: Extension Service Worker OPTIMIZE_JD Handler Tests
Source: W-03, LLD-MVP-P04 §5.4, REQ-02-08
User Story: As an engineer, I want automated tests for the OPTIMIZE_JD message
  handler so that the optimization message flow is validated.
Current State: service-worker.spec.ts exists with 9 tests covering SYNC_PROFILE,
  AUTH_TOKEN, and SAVE_APPLICATION handlers. OPTIMIZE_JD handler tests are missing.
Required State: service-worker.spec.ts extended with 3 additional test cases for
  the OPTIMIZE_JD handler.
Acceptance Criteria:
  - AC-1: Given an OPTIMIZE_JD message, then /api/optimize is called with the
    JD payload.
  - AC-2: Given a successful response, then the optimize context is stored in
    chrome.storage.local.
  - AC-3: Given a successful response, then { success: true, data } is returned.
Architect Notes: S effort. Extend existing test file using established patterns.
Dependencies: smart-apply-extension/test/service-worker.spec.ts (exists)
```

### 4.3 Nice-to-Have (P2 — Post-Beta)

```
REQ-03-08
Title: Webhook Audit Events Assertion Tests
Source: W-04, LLD-MVP-P04 §5.7
User Story: As an engineer, I want assertions verifying audit_events table inserts
  during webhook processing so that the audit trail is validated.
Current State: webhooks.controller.spec.ts exists with 5 tests covering deletion
  flow but no assertions on audit_events inserts.
Required State: webhooks.controller.spec.ts extended with 3 audit-specific test
  cases.
Acceptance Criteria:
  - AC-1: Given a user deletion webhook, then supabase.insert is called on
    audit_events.
  - AC-2: Given the audit event insert, then the row contains clerk_user_id and
    event_type.
  - AC-3: Given the audit insert fails, then the deletion still succeeds.
Architect Notes: S effort. Extend existing mock to assert audit insert calls.
Dependencies: smart-apply-backend/test/webhooks.controller.spec.ts (exists)
```

```
REQ-03-09
Title: CORS Restriction Unit Tests
Source: W-05, LLD-MVP-P04 §5.8
User Story: As an engineer, I want unit tests validating CORS origin checking so
  that security regressions in CORS configuration are caught automatically.
Current State: No CORS test file exists. CORS configuration is implemented in
  main.ts with 3-tier origin check.
Required State: smart-apply-backend/test/cors.spec.ts exists with 6 test cases
  covering all CORS origin scenarios.
Acceptance Criteria:
  - AC-1: Given a request from the configured web origin, then CORS allows it.
  - AC-2: Given a request from the configured Chrome extension ID, then CORS
    allows it.
  - AC-3: Given a request from an unknown Chrome extension, then CORS rejects it.
  - AC-4: Given no CHROME_EXTENSION_ID in dev mode, then any extension is allowed.
  - AC-5: Given no CHROME_EXTENSION_ID in production, then extensions are rejected.
  - AC-6: Given a same-origin request (null origin), then CORS allows it.
Architect Notes: S effort. Extract CORS origin callback for testability.
Dependencies: None
```

---

## 5. Non-Functional Requirements

| # | Category | Requirement | Source |
|:---|:---|:---|:---|
| NFR-01 | Testing | All new test files must use Vitest and follow existing test patterns in each package | LLD-MVP-P04 §5 |
| NFR-02 | Testing | Web component tests must use React Testing Library with jsdom environment | LLD-MVP-P04 §5.6 |
| NFR-03 | Testing | All new tests must pass in CI (GitHub Actions) | REQ-02-09 |
| NFR-04 | Quality | No decrease in existing test count (66 baseline) | P04 Implementation Review |

---

## 6. Test Coverage Requirements

| # | Package | Required Tests | Priority | Addresses |
|:---|:---|:---|:---|:---|
| TC-01 | web | OptimizeForm — JD textarea, submit, loading, error (4 tests) | P1 | REQ-03-01, W-01 |
| TC-02 | web | OptimizeResults — scores, checkboxes, toggle, warnings, badges (5 tests) | P1 | REQ-03-02, W-01 |
| TC-03 | web | DashboardShell — history, empty state, loading (3 tests) | P1 | REQ-03-03, W-01 |
| TC-04 | web | ProfileEditor — display, submit, validation errors (3 tests) | P1 | REQ-03-04, W-01 |
| TC-05 | web | SettingsPage — account info, delete dialog, typing DELETE, API call (4 tests) | P1 | REQ-03-05, W-01 |
| TC-06 | extension | PDF generator — output, header, empty experience, empty skills (4 tests) | P1 | REQ-03-06, W-02 |
| TC-07 | extension | OPTIMIZE_JD handler — API call, storage, response (3 tests) | P1 | REQ-03-07, W-03 |
| TC-08 | backend | Webhook audit assertions — insert, schema, failure tolerance (3 tests) | P2 | REQ-03-08, W-04 |
| TC-09 | backend | CORS origin validation — 6 scenarios (6 tests) | P2 | REQ-03-09, W-05 |

**Total new tests: 35** (19 web + 7 extension + 9 backend)  
**Expected total after phase: 101+** (66 existing + 35 new)

---

## 7. Out of Scope

| Item | Reason |
|:---|:---|
| REQ-02-12: Environment Variable Audit | P2 — deferred, no regression risk |
| REQ-02-13: Structured Logging Strategy | P2 — deferred, cosmetic improvement |
| REQ-02-14: ESLint + Prettier CI Integration | P2 — deferred, no functional impact |
| REQ-02-15: Resolve npm Audit Vulnerabilities | P2 — requires upstream patches |
| REQ-02-16: Fix Unsafe Type Casts in Extension | P2 — deferred, no runtime impact |
| Integration/E2E tests | Separate initiative; this phase focuses on unit/component tests |
| New feature development | This phase is exclusively test coverage completion |
