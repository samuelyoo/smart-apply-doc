---
title: BRD — MVP 02
description: Business Requirements Document for MVP Phase 2, driven by QA-Report-01 findings and Architect Review.
hero_eyebrow: Business requirements
hero_title: BRD for MVP 02
hero_summary: Translates QA findings from the first full-scope quality assessment into prioritised business requirements for the next development phase.
permalink: /brd-mvp-02/
---

# Business Requirements Document — MVP 02

**Version:** 1.0  
**Date:** 2026-03-28  
**Source:** QA-Report-01.md, Arch-Review-QA-01.md, BRD-MVP-01.md  
**Author:** Business Analyst Agent  
**Reviewed By:** Architect Agent  

---

## 1. Executive Summary

The Phase 1 development cycle (BRD-MVP-01) delivered significant results: all five P0 launch blockers were resolved, all six P1 requirements were addressed (four fully, two partially), and all five P2 items were implemented at least partially. The backend is solid with 23 passing tests, all 4 packages compile and build successfully, and the core user journey (sign in → sync profile → optimize → approve changes → generate PDF → save application) is functionally complete across both the web portal and Chrome extension.

However, QA-Report-01 identified critical gaps preventing production deployment. Two HIGH-severity security findings — unprotected web routes (`/optimize`, `/settings` missing from Clerk middleware) and overly permissive CORS (any Chrome extension can make API requests) — must be resolved before any public deployment. The Google Drive OAuth client ID remains a placeholder, blocking the Drive upload feature entirely. Additionally, test coverage is severely imbalanced: 23 backend tests exist but web, extension, and shared packages have zero automated tests, creating a significant regression risk.

This BRD scopes the next phase of work to close security gaps, establish test coverage foundations, complete partially-met requirements from BRD-MVP-01, and address the highest-priority technical debt. After this phase, the product will be **CONDITIONALLY READY for beta deployment** — all security findings resolved, critical paths tested, and CI pipeline guarding against regressions.

---

## 2. Stakeholder Goals

| Stakeholder | Goal | Success Metric |
|:---|:---|:---|
| Job Seeker | Use Smart Apply securely without risk of unauthorized data access | All routes require authentication; CORS restricted to known clients only |
| Job Seeker | Have optimized resume PDFs automatically saved to Google Drive with working links in application history | Drive upload completes successfully; `drive_link` persists in application history records |
| Product Owner | Reach beta deployment readiness with confidence in code stability | All security findings resolved; ≥50 automated tests across all packages; CI runs full build + test suite |
| Engineering Team | Maintain code quality with automated guardrails and reduce regression risk | Test frameworks configured for all 4 packages; CI pipeline covers typecheck + build + test for every package |

---

## 3. Previous Phase Outcomes

### 3.1 Requirements Closed (from BRD-MVP-01)

| REQ ID | Title | QA Verdict |
|:---|:---|:---|
| REQ-01-01 | Fix Web Production Build | ✅ MET — closing |
| REQ-01-03 | Extension Message Flow | ✅ MET — closing (error handling + retry is a new requirement below) |
| REQ-01-04 | Apply Approved Changes to PDF | ✅ MET — closing |
| REQ-01-05 | Externalise Environment URLs | ✅ MET — closing |
| REQ-01-07 | Complete ATS Scoring | ✅ MET — closing |
| REQ-01-08 | Supabase Migration System | ✅ MET — closing (incremental migration pattern untested, carried as new req) |
| REQ-01-09 | Account Deletion (Webhook) | ✅ MET — closing (audit log gap carried forward as new requirement) |
| REQ-01-13 | Web-Based Optimize/Apply Flow | ✅ MET — closing |
| REQ-01-14 | Settings & Account Management UI | ✅ MET — closing |
| REQ-01-15 | Manual Profile Upload/Import | ✅ MET — closing |

### 3.2 Requirements Carried Forward

| REQ ID | Original Priority | New Priority | Change Reason |
|:---|:---|:---|:---|
| REQ-01-02 | P0 | P0 | AC-3 NOT MET — extension API client does not clear token or redirect on 401. Core auth flow incomplete. |
| REQ-01-06 | P1 | P0 | AC-1 blocked by placeholder OAuth client ID (RISK-03). AC-3 NOT MET — `drive_link` not passed to API body (RISK-06). Elevated because Drive upload is core to the product promise. |
| REQ-01-10 | P1 | P1 | AC-1 PARTIAL — CI only builds web; needs backend + extension builds. AC-3 PARTIAL — Dockerfile exists but no deploy pipeline. |
| REQ-01-11 | P1 | P1 | MET for backend, but QA found zero tests for web/extension/shared — scope expanded. |
| REQ-01-12 | P2 | P2 | PARTIAL — 7 fields covered, resume file upload attempted but no clipboard fallback. Carry forward. |
| REQ-01-16 | P2 | P2 | PARTIAL — selector failure reporting exists but no version registry. Carry forward. |

---

## 4. Functional Requirements

### 4.1 Must-Have (P0 — Launch Blockers)

```
REQ-02-01
Title: Fix Web Middleware Route Protection
Source: RISK-01, TD-02 (QA-Report-01)
User Story: As a job seeker, I want all authenticated pages to require login so
  that no one can access my optimization results or account settings without
  being signed in.
Current State: `/optimize` and `/settings` routes are NOT listed in the Clerk
  `createRouteMatcher()` protected route list. Unauthenticated users can access
  these pages at the middleware level (secondary `auth()` check in page
  components provides a fallback guard).
Required State: All authenticated routes are protected at the middleware level.
  The route protection model is inverted to protect-by-default with an explicit
  public route allowlist.
Acceptance Criteria:
  - AC-1: Given an unauthenticated user, when they navigate to `/optimize`,
    then they are redirected to `/sign-in` before the page renders.
  - AC-2: Given an unauthenticated user, when they navigate to `/settings`,
    then they are redirected to `/sign-in` before the page renders.
  - AC-3: Given a new route is added to the web app, then it is protected by
    default unless explicitly added to the public routes allowlist.
Architect Notes: S effort. Invert the route protection model — maintain a public
  allowlist instead of a protected blocklist. This eliminates the class of bug
  where new routes are accidentally left unprotected.
Dependencies: None
```

```
REQ-02-02
Title: Restrict CORS to Specific Extension ID
Source: RISK-02, TD-03 (QA-Report-01)
User Story: As a job seeker, I want the Smart Apply API to only accept requests
  from the official Smart Apply extension and web portal so that third-party
  extensions cannot access my data.
Current State: Backend CORS regex matches ANY `chrome-extension://` origin,
  allowing any Chrome extension to make cross-origin requests to the API.
Required State: CORS only allows the specific published Smart Apply extension ID
  and the production web portal origin, configured via environment variable.
Acceptance Criteria:
  - AC-1: Given a request from the Smart Apply Chrome extension (matching the
    configured extension ID), when it reaches the backend, then CORS allows it.
  - AC-2: Given a request from an unknown Chrome extension, when it reaches the
    backend, then CORS blocks it.
  - AC-3: Given the extension ID is configured via the `CHROME_EXTENSION_ID`
    environment variable, when the backend starts, then CORS uses this value.
  - AC-4: Given no `CHROME_EXTENSION_ID` is set, when the backend starts in dev
    mode, then CORS falls back to allowing all extension origins (dev only).
Architect Notes: S effort. No dependencies. Env var pattern matches existing
  `ALLOWED_ORIGINS` approach.
Dependencies: None
```

```
REQ-02-03
Title: Complete Extension 401 Handling
Source: RISK-04, TD-22, REQ-01-02 AC-3 (carried forward)
User Story: As a job seeker using the Chrome extension, I want to be
  automatically prompted to re-login when my session expires so that I am never
  stuck with a broken extension.
Current State: The extension API client (`apiFetch`) throws on non-ok responses
  but does NOT clear the stored auth token or redirect the user to the login
  screen when a 401 is received.
Required State: On 401 response, the extension clears the stored token from
  `chrome.storage.local` and transitions the popup UI to the login screen.
Acceptance Criteria:
  - AC-1: Given an expired or invalid token, when the backend returns 401, then
    the extension clears `auth_token` from `chrome.storage.local`.
  - AC-2: Given a 401 response, when the token is cleared, then the popup UI
    transitions to the login screen with a message "Session expired. Please
    sign in again."
  - AC-3: Given a 401 during an in-progress operation (sync/optimize), then the
    error is shown before navigating to login.
Architect Notes: S effort. Part of a broader API client error handling pattern
  (see Arch-Review-QA-01 §6.3).
Dependencies: None
```

```
REQ-02-04
Title: Complete Google Drive Integration
Source: RISK-03, RISK-06, TD-01, REQ-01-06 (carried forward)
User Story: As a job seeker, I want my optimised resume PDF uploaded to Google
  Drive and the link saved in my application history so that I have a permanent
  record of every tailored resume.
Current State: Google Drive upload code exists in `google-drive.ts` but is
  non-functional due to `GOOGLE_OAUTH_CLIENT_ID_PLACEHOLDER` in manifest.ts.
  Additionally, the `drive_link` value is computed but not included in the
  SAVE_APPLICATION API request body.
Required State: A real Google OAuth client ID is configured; Drive upload
  succeeds and the shareable link is persisted in `application_history.drive_link`.
Acceptance Criteria:
  - AC-1: Given a valid Google OAuth consent, when a PDF is generated and
    approved, then it is uploaded to `Smart-Apply/{Company_Name}/` in the
    user's Google Drive.
  - AC-2: Given a successful upload, then a shareable link is returned and
    stored in the application history record's `drive_link` field.
  - AC-3: Given the upload fails (quota, network, permissions), then the
    extension falls back to local download and notifies the user.
  - AC-4: Given the `GOOGLE_OAUTH_CLIENT_ID` in the manifest, when the
    extension is built, then it uses the value from build-time env substitution
    (not a placeholder).
Architect Notes: S effort for code fixes (pass drive_link, env substitution).
  External dependency: Google Cloud project + OAuth consent screen setup required.
Dependencies: None (code-level). External: Google Cloud project setup.
```

```
REQ-02-05
Title: Establish Test Frameworks for All Packages
Source: RISK-05, QA-Report-01 §3.3 (13 missing test categories)
User Story: As an engineer, I want every package to have a configured test
  framework so that I can write and run tests for any part of the codebase.
Current State: Only `smart-apply-backend` has Vitest configured. The web,
  extension, and shared packages have no test framework setup — no test config,
  no test runner, no mock infrastructure.
Required State: All four packages have Vitest (or appropriate runner) configured
  with necessary mocks (Chrome APIs for extension, React Testing Library for
  web, node environment for shared).
Acceptance Criteria:
  - AC-1: Given the shared package, when `npm test` is run in `smart-apply-shared`,
    then Vitest executes and reports results (even if 0 tests initially).
  - AC-2: Given the web package, when `npm test` is run in `smart-apply-web`,
    then Vitest + React Testing Library executes and reports results.
  - AC-3: Given the extension package, when `npm test` is run in
    `smart-apply-extension`, then Vitest with Chrome API mocks executes and
    reports results.
  - AC-4: Given any package, when tests are added, then they run in CI
    alongside existing backend tests.
Architect Notes: M effort. Prerequisite for all test-writing requirements below.
  Recommend shared test utilities in `smart-apply-shared/test-utils/`.
Dependencies: None
```

---

### 4.2 Should-Have (P1 — High Value)

```
REQ-02-06
Title: P0 Regression Test Suite
Source: RISK-01, RISK-05, Arch-Review-QA-01 §4 (P0 tests)
User Story: As an engineer, I want automated tests guarding the security fixes
  so that route protection and schema validation cannot silently regress.
Current State: No tests exist for Clerk middleware route protection or shared
  Zod schema validation.
Required State: Tests verify that all protected routes reject unauthenticated
  access, and all Zod schemas correctly validate and reject inputs.
Acceptance Criteria:
  - AC-1: Given the middleware test suite, when run, then it verifies
    `/dashboard`, `/profile`, `/optimize`, and `/settings` reject
    unauthenticated requests.
  - AC-2: Given the shared schema test suite, when run with valid inputs, then
    all schemas parse successfully.
  - AC-3: Given the shared schema test suite, when run with invalid inputs, then
    all schemas throw validation errors with descriptive messages.
  - AC-4: Given any new route added, when the test suite runs, then it is
    verified as protected (via the inverted protection model from REQ-02-01).
Architect Notes: S effort once test frameworks are set up (REQ-02-05).
Dependencies: REQ-02-05 (test frameworks), REQ-02-01 (route protection fix)
```

```
REQ-02-07
Title: Web Component Test Coverage
Source: RISK-05, QA-Report-01 §8 tests #1–7
User Story: As an engineer, I want the core web components tested so that UI
  regressions are caught before deployment.
Current State: Zero web component tests.
Required State: Core web components (OptimizeForm, OptimizeResults,
  DashboardShell, ProfileEditor, SettingsPage) have React Testing Library tests
  covering render, user interaction, and API call mocking.
Acceptance Criteria:
  - AC-1: OptimizeForm — test submits JD text and renders loading state.
  - AC-2: OptimizeResults — test displays before/after scores and change list
    with toggle functionality.
  - AC-3: DashboardShell — test fetches and renders application history.
  - AC-4: ProfileEditor — test loads profile data and submits updates.
  - AC-5: SettingsPage — test shows account info and delete button with
    confirmation.
Architect Notes: M effort. Requires mocked API client and Clerk auth context.
Dependencies: REQ-02-05 (test framework for web)
```

```
REQ-02-08
Title: Extension Service Worker & PDF Test Coverage
Source: RISK-05, QA-Report-01 §8 tests #9–14
User Story: As an engineer, I want the extension's core logic tested so that
  message handling and PDF generation don't break silently.
Current State: Zero extension tests.
Required State: Service worker message handlers (SYNC_PROFILE, OPTIMIZE_JD,
  SAVE_APPLICATION, AUTH_TOKEN) and PDF generator have automated tests with
  mocked Chrome APIs and backend responses.
Acceptance Criteria:
  - AC-1: SYNC_PROFILE handler — test extracts text, calls API, caches result.
  - AC-2: OPTIMIZE_JD handler — test extracts JD, calls API, returns scores.
  - AC-3: AUTH_TOKEN handler — test stores and retrieves token.
  - AC-4: generateResumePDF — test produces valid PDF bytes for known input.
  - AC-5: buildApprovedResume — test correctly merges only selected changes.
  - AC-6: apiFetch — test attaches Bearer token; test 401 handling (REQ-02-03).
Architect Notes: M effort. Requires Chrome API mock layer. Recommend
  `webextension-polyfill` or manual `globalThis.chrome` mock.
Dependencies: REQ-02-05 (test framework for extension)
```

```
REQ-02-09
Title: Complete CI Pipeline Coverage
Source: RISK-07, REQ-01-10 (carried forward)
User Story: As an engineer, I want the CI pipeline to build and test all
  packages so that regressions in any package are caught before merge.
Current State: CI runs typecheck on all 4 packages + builds web + runs backend
  tests. Backend build, extension build, and non-backend tests are missing.
Required State: CI pipeline builds all 4 packages, runs all test suites, and
  reports failures on PR and push to main.
Acceptance Criteria:
  - AC-1: Given a PR to main, when CI runs, then all 4 packages are typechecked.
  - AC-2: Given a PR to main, when CI runs, then all 4 packages are built.
  - AC-3: Given a PR to main, when CI runs, then all test suites (backend, web,
    extension, shared) execute and report results.
  - AC-4: Given any test failure, when CI runs, then the pipeline fails and
    blocks merge.
Architect Notes: S effort. Add build + test steps for backend, extension, shared
  to existing CI workflow.
Dependencies: REQ-02-05 (test frameworks must exist before CI can run them)
```

```
REQ-02-10
Title: Account Deletion Audit Log
Source: RISK-08, REQ-01-09 AC-3 (NOT MET)
User Story: As a product owner, I need a verifiable record of account deletions
  so that the product can demonstrate GDPR/CCPA compliance.
Current State: Account deletion works correctly (webhook cascade deletes all
  data) but the only record is a `console.log` with the userId. No persistent
  audit trail exists.
Required State: An audit log entry is created for each account deletion,
  containing only the user ID and timestamp (no PII). The audit log is
  append-only and queriable.
Acceptance Criteria:
  - AC-1: Given a `user.deleted` webhook event, when deletion completes, then
    an audit log entry is written with `{clerk_user_id, event_type, timestamp}`.
  - AC-2: Given the audit log, when queried, then it returns all deletion events
    in chronological order.
  - AC-3: Given the audit log storage, it must NOT contain any PII (no name,
    email, or profile data).
Architect Notes: M effort. Requires design decision on storage — recommend a
  simple `audit_events` Supabase table with no RLS (admin-only access via
  service role). Migration required.
Dependencies: None
```

```
REQ-02-11
Title: Extension Error State Retry Buttons
Source: RISK-11, REQ-01-03 AC-3 (PARTIAL — errors shown but no retry)
User Story: As a job seeker, I want a retry button when an extension operation
  fails so that I can recover from transient network errors without
  closing/reopening the popup.
Current State: Error messages are displayed in the popup but there is no
  "Retry" button. Users must close and reopen the popup to retry.
Required State: All error states in the extension popup include a "Retry" button
  that re-triggers the failed operation.
Acceptance Criteria:
  - AC-1: Given a failed sync operation, when the error is displayed, then a
    "Retry" button is visible and re-triggers the sync.
  - AC-2: Given a failed optimize operation, when the error is displayed, then a
    "Retry" button is visible and re-triggers the optimisation.
  - AC-3: Given a network connectivity issue, when the user clicks "Retry"
    after connectivity resumes, then the operation completes successfully.
Architect Notes: S effort. Localised to popup component error state rendering.
Dependencies: None
```

---

### 4.3 Could-Have (P2 — Nice To Have)

```
REQ-02-12
Title: Extension Popup Bundle Size Reduction
Source: RISK-09, TD-20
User Story: As a job seeker on a low-end device, I want the extension popup to
  open quickly so that I don't experience lag when using Smart Apply.
Current State: Extension popup bundle is 638 kB, exceeding the 500 kB Rollup
  recommendation.
Required State: Popup bundle is under 500 kB via code splitting / dynamic
  imports for pdf-lib.
Acceptance Criteria:
  - AC-1: Given the extension build, then the popup chunk is ≤500 kB.
  - AC-2: Given PDF generation is triggered, then `pdf-lib` is loaded on demand
    (not at popup startup).
Architect Notes: M effort. Dynamic import for pdf-lib module.
Dependencies: None
```

```
REQ-02-13
Title: Structured Logging Strategy
Source: TD-04 through TD-16, Arch-Review-QA-01 §6.4
User Story: As an engineer, I want structured, conditional logging so that
  debug logs don't leak to production and production logs are machine-parseable.
Current State: 13 console.log/warn/error statements scattered across backend and
  extension code. Backend uses console.log for server startup.
Required State: Backend uses NestJS Logger with JSON output. Extension uses a
  conditional logger utility (no-op in production).
Acceptance Criteria:
  - AC-1: Given the backend in production, when a log is emitted, then it is
    JSON-formatted with request ID correlation.
  - AC-2: Given the extension in production, then no `console.log/warn/error`
    calls execute.
  - AC-3: Given the extension in development, then debug logging is available.
Architect Notes: M effort. Batch fix for 13 debt items. One systematic change.
Dependencies: None
```

```
REQ-02-14
Title: ESLint + Prettier CI Integration
Source: RISK-12
User Story: As an engineer, I want code style enforced automatically so that
  reviews focus on logic, not formatting.
Current State: No lint or format checks in CI. Code style is not enforced.
Required State: ESLint + Prettier configured for all packages and enforced in CI.
Acceptance Criteria:
  - AC-1: Given a PR, when CI runs, then ESLint and Prettier checks pass.
  - AC-2: Given a lint or format violation, then CI fails with a clear error.
Architect Notes: S effort. Standard tooling setup.
Dependencies: None
```

```
REQ-02-15
Title: Resolve npm Audit Vulnerabilities
Source: RISK-10, TD-21
User Story: As a product owner, I want known vulnerabilities in dependencies
  resolved so that security audit reports are clean.
Current State: 14 npm vulnerabilities (7 moderate, 7 high) via transitive deps.
Required State: `npm audit` reports 0 high vulnerabilities. Moderate
  vulnerabilities in build-only tools documented in security exceptions.
Acceptance Criteria:
  - AC-1: Given `npm audit`, then 0 high-severity vulnerabilities are reported.
  - AC-2: Any unresolvable moderate vulnerabilities in build-time-only
    dependencies are documented with risk acceptance.
Architect Notes: S effort. May require waiting for upstream patches for some deps.
Dependencies: None
```

```
REQ-02-16
Title: Fix Unsafe Type Casts in Extension
Source: TD-17, TD-18, TD-19
User Story: As an engineer, I want type-safe code in the extension so that
  type errors are caught at compile time.
Current State: Three `as unknown as` double casts in service worker and popup for
  message payloads and PDF byte arrays.
Required State: Proper TypeScript interfaces defined for Chrome message payloads
  and PDF byte handling. No `as unknown as` casts.
Acceptance Criteria:
  - AC-1: Given the extension codebase, then zero `as unknown as` double casts
    remain.
  - AC-2: Message payloads use typed interfaces matching the message bus protocol.
Architect Notes: S effort. Define proper interfaces and eliminate casts.
Dependencies: None
```

---

## 5. Non-Functional Requirements

| # | Category | Requirement | Source | QA Finding |
|:---|:---|:---|:---|:---|
| NFR-01 | Security | All web routes must be protected by default; only explicitly allowlisted routes are public | TRD §15, RISK-01 | TD-02: `/optimize` and `/settings` missing from protected route matcher |
| NFR-02 | Security | CORS must restrict `chrome-extension://` origins to the specific published extension ID | TRD §15, RISK-02 | TD-03: CORS accepts any extension origin |
| NFR-03 | Security | Extension must handle 401 responses by clearing stored credentials and prompting re-authentication | TRD §15.3, RISK-04 | TD-22: No 401 handling in extension API client |
| NFR-04 | Privacy | Account deletion events must produce an append-only audit trail with no PII | PRD §6, TRD §15.4, RISK-08 | No audit log, only console.log |
| NFR-05 | Testing | All packages must have a configured test runner executable in CI | QA-Report-01 §3.3, RISK-05 | Zero tests for web, extension, shared |
| NFR-06 | Observability | Backend must use structured JSON logging with request-ID correlation in production | TRD §17.1, NFR-15 | TD-04–16: 13 console leak items |
| NFR-07 | Performance | Extension popup bundle must not exceed 500 kB | Performance best practice, RISK-09 | TD-20: 638 kB current bundle |

---

## 6. Test Coverage Requirements

| # | Package | Required Tests | Priority | Addresses |
|:---|:---|:---|:---|:---|
| TC-01 | web | Clerk middleware route protection — verify `/dashboard`, `/profile`, `/optimize`, `/settings` reject unauthenticated users | P0 | RISK-01, QA §8 test #8 |
| TC-02 | shared | Zod schema validation — valid and invalid inputs for all schemas (profile, application, optimization) | P0 | RISK-05, QA §8 test #18 |
| TC-03 | web | OptimizeForm — submit JD, loading state, error handling | P1 | QA §8 test #1 |
| TC-04 | web | OptimizeResults — before/after scores, change toggles, PDF download | P1 | QA §8 tests #2–3 |
| TC-05 | web | DashboardShell — fetch and render application history | P1 | QA §8 test #4 |
| TC-06 | web | ProfileEditor — load profile, submit updates | P1 | QA §8 test #5 |
| TC-07 | web | ProfileUpload — parse uploaded file, call ingest API | P1 | QA §8 test #6 |
| TC-08 | web | SettingsPage — account info, delete confirmation | P1 | QA §8 test #7 |
| TC-09 | extension | Service worker SYNC_PROFILE handler | P1 | QA §8 test #9 |
| TC-10 | extension | Service worker OPTIMIZE_JD handler | P1 | QA §8 test #10 |
| TC-11 | extension | Service worker AUTH_TOKEN handler + 401 handling | P1 | QA §8 test #11 |
| TC-12 | extension | generateResumePDF — valid PDF for known input | P1 | QA §8 test #12 |
| TC-13 | extension | buildApprovedResume — selected changes merge | P1 | QA §8 test #13 |
| TC-14 | extension | apiFetch — Bearer token attachment + error handling | P1 | QA §8 test #14 |
| TC-15 | backend | AccountService/Controller — delete flow + Clerk failure | P1 | QA §8 tests #19–20 |
| TC-16 | extension | LinkedIn profile content script extraction | P2 | QA §8 test #15 |
| TC-17 | extension | JD detector content script extraction | P2 | QA §8 test #16 |
| TC-18 | extension | Autofill field mapping | P2 | QA §8 test #17 |

---

## 7. Technical Debt to Address

| TD ID | Description | Fix Approach (from Arch Review) | Priority |
|:---|:---|:---|:---|
| TD-02 | `/optimize` and `/settings` not in Clerk middleware protected routes | Invert to protect-by-default with public allowlist | P0 |
| TD-03 | CORS accepts any `chrome-extension://` origin | Restrict to specific extension ID via `CHROME_EXTENSION_ID` env var | P0 |
| TD-01 | `GOOGLE_OAUTH_CLIENT_ID_PLACEHOLDER` blocks Drive upload | Replace with env-based substitution in Vite build | P0 |
| TD-22 | No 401 handling in extension API client | Add response interceptor: clear token + redirect to login | P0 |
| TD-17 | `as unknown as Record<string, unknown>` double cast in service worker (line 119) | Define typed interface for Chrome message payloads | P2 |
| TD-18 | `as unknown as Record<string, unknown>` double cast in service worker (line 181) | Define typed interface for Chrome message payloads | P2 |
| TD-19 | `as unknown as ArrayBuffer` / `as unknown as BlobPart` casts in popup | Use proper `Uint8Array` types for PDF byte handling | P2 |
| TD-20 | 638 kB popup bundle exceeds 500 kB recommendation | Dynamic import for pdf-lib, Rollup manual chunks | P2 |
| TD-21 | 14 npm vulnerabilities (7 moderate, 7 high) in transitive deps | `npm audit fix`; document exceptions for build-time-only deps | P2 |
| TD-04–16 | 13 console.log/warn/error statements in production code | Backend: NestJS Logger; Extension: conditional logger utility | P2 |

---

## 8. Out of Scope

| Item | Reason |
|:---|:---|
| Full auto-apply / auto-submit | PRD §1 mandates human-in-the-loop; submit is always manual |
| Multi-template resume design marketplace | Post-MVP feature (PRD §7, v2.0+) |
| Cover letter generation workflow | Post-MVP feature (PRD §7, v2.0+) |
| Batch/overnight PDF generation ("Cart") | Post-MVP feature (PRD §7, v2.0) |
| Multi-language resume support | Post-MVP feature |
| Interview coaching | Post-MVP feature (PRD §7, v3.0) |
| Workday / Greenhouse / Lever autofill adapters | MVP targets LinkedIn Easy Apply only (TRD §14.1) |
| Mobile-native application | Web responsive is in scope; native apps are not |
| Advanced analytics / insights dashboard | MVP dashboard shows history only |
| Monitoring dashboards / APM integration | Future infrastructure work |
| Load testing / performance optimization (beyond bundle size) | Not warranted at beta stage |
| Chrome Web Store submission process | Only build artifact creation; manual upload acceptable for beta |
| Extended autofill field coverage (REQ-01-12) | Carried but remains P2; deferred if capacity is exceeded |
| DOM selector hardening (REQ-01-16) | Carried but remains P2; deferred if capacity is exceeded |

---

## 9. Open Questions

| # | Question | Origin | Owner | Due |
|:---|:---|:---|:---|:---|
| 1 | What is the published Chrome extension ID for CORS restriction? If not yet published, should we use a development ID for now? | RISK-02, REQ-02-02 | Engineering Lead | Start of phase |
| 2 | Has the Google Cloud project and OAuth consent screen been set up? If not, who owns this external setup? | RISK-03, REQ-02-04 | Product Owner | Start of phase |
| 3 | Should the audit log for account deletion live in a Supabase table (audit_events) or in an external log service (e.g., Datadog, CloudWatch)? | RISK-08, REQ-02-10 | Engineering Lead | Week 1 |
| 4 | What is the target minimum test count per package for beta readiness? (Architect recommends: shared ≥10, web ≥10, extension ≥10, backend ≥23 existing) | RISK-05, REQ-02-05 | Engineering Lead | Week 1 |
| 5 | Should the route protection inversion (REQ-02-01 AC-3) be implemented as Clerk's `publicRoutes` config or as custom middleware logic? | Arch-Review-QA-01 §6.1 | Engineering Lead | Week 1 |
| 6 | The Architect flagged a broader API client error handling pattern (429 backoff, 5xx retry, offline detection) beyond 401 — should this be scoped into this phase or deferred? | Arch-Review-QA-01 §6.3 | Product Owner | Week 1 |

---

## 10. Approval Checklist

- [x] All P0 requirements have at least two acceptance criteria
- [x] Every carried-forward requirement references its original REQ ID
- [x] Every new requirement traces to a QA finding or Arch Review recommendation
- [x] No requirement contradicts the Zero-Storage Policy (PRD §1)
- [x] No requirement contradicts Clerk auth model
- [x] Test coverage requirements address all P0 gaps from QA report §3.3
- [x] Technical debt items reference original TD IDs from QA report
- [x] NFRs traceable to TRD sections
- [x] Out-of-scope list reviewed to prevent unintended inclusions
- [x] Architect Agent has validated technical feasibility (Step 4) — see below

---

## 11. Architect Feasibility Validation

**Reviewer:** Architect Agent  
**Date:** 2026-03-28  
**Verdict: APPROVED**

### Feasibility Checklist

| REQ ID | Title | Effort Accurate? | Dependencies Correct? | AC Testable? | Technically Sound? | Verdict |
|:---|:---|:---|:---|:---|:---|:---|
| REQ-02-01 | Fix Web Middleware Route Protection | ✅ S | ✅ None | ✅ All ACs testable via middleware integration test | ✅ Inverted allowlist model is standard Clerk pattern (`publicRoutes`) | APPROVE |
| REQ-02-02 | Restrict CORS to Specific Extension ID | ✅ S | ✅ None | ✅ AC-1/AC-2 testable via CORS preflight check; AC-3/AC-4 via env var config test | ✅ Env-var-driven CORS is the standard NestJS pattern | APPROVE |
| REQ-02-03 | Complete Extension 401 Handling | ✅ S | ✅ None | ✅ All ACs testable with mocked API responses | ✅ Standard interceptor pattern | APPROVE |
| REQ-02-04 | Complete Google Drive Integration | ✅ S (code) | ⚠️ External dependency on Google Cloud project setup should be called out more prominently | ✅ AC-1 through AC-4 testable (AC-1 requires mocked Drive API) | ✅ Architecture already supports this; code exists, just needs config | APPROVE |
| REQ-02-05 | Establish Test Frameworks | ✅ M | ✅ None | ✅ ACs are verifiable by running `npm test` in each package | ✅ Vitest is already in the monorepo; extending to other packages is straightforward | APPROVE |
| REQ-02-06 | P0 Regression Test Suite | ✅ S | ✅ Correctly depends on REQ-02-05 and REQ-02-01 | ✅ All ACs are concrete test descriptions | ✅ Standard test patterns | APPROVE |
| REQ-02-07 | Web Component Test Coverage | ✅ M | ✅ Correctly depends on REQ-02-05 | ✅ All ACs map to specific component test scenarios | ✅ React Testing Library is mature for this | APPROVE |
| REQ-02-08 | Extension Service Worker & PDF Test Coverage | ✅ M | ✅ Correctly depends on REQ-02-05 | ✅ All ACs testable with Chrome API mocks | ✅ `webextension-polyfill` or manual mocks are proven patterns | APPROVE |
| REQ-02-09 | Complete CI Pipeline Coverage | ✅ S | ✅ Correctly depends on REQ-02-05 | ✅ All ACs verifiable by CI run output | ✅ Adding steps to existing GitHub Actions workflow | APPROVE |
| REQ-02-10 | Account Deletion Audit Log | ✅ M | ✅ None | ✅ AC-1/AC-2 testable via DB query; AC-3 via schema constraint | ✅ Simple append-only table pattern | APPROVE |
| REQ-02-11 | Extension Error State Retry Buttons | ✅ S | ✅ None | ✅ All ACs testable via component render tests | ✅ Standard React state management | APPROVE |
| REQ-02-12 | Popup Bundle Size Reduction | ✅ M | ✅ None | ✅ AC-1 measurable from build output | ✅ Dynamic import is well-supported in Vite | APPROVE |
| REQ-02-13 | Structured Logging Strategy | ✅ M | ✅ None | ✅ AC-1 testable via log output format; AC-2/AC-3 via build config | ✅ NestJS Logger + build-conditional is standard | APPROVE |
| REQ-02-14 | ESLint + Prettier CI Integration | ✅ S | ✅ None | ✅ Verifiable via CI run | ✅ Standard tooling | APPROVE |
| REQ-02-15 | Resolve npm Audit Vulnerabilities | ✅ S | ✅ None | ✅ Verifiable via `npm audit` | ⚠️ Some deps may not have upstream fixes yet — document exceptions | APPROVE |
| REQ-02-16 | Fix Unsafe Type Casts | ✅ S | ✅ None | ✅ Verifiable via TypeScript strict checks | ✅ Proper interface definitions | APPROVE |

### Phase Scope Assessment

- **Is the total effort realistic?** YES. P0 items total approximately 1S + 1S + 1S + 1S + 1M = ~4-5 days. P1 items total approximately 1S + 1M + 1M + 1S + 1M + 1S = ~6-8 days. P2 items are optional. Total P0+P1 fits within a 2-week sprint.

- **Hidden dependencies?**
  - REQ-02-04 (Google Drive) has an external dependency on Google Cloud project setup that is not within the engineering team's control. If delayed, the code fix (passing `drive_link`) can proceed independently; only the OAuth client ID replacement is blocked.
  - REQ-02-05 (test frameworks) is a critical path prerequisite for REQ-02-06, REQ-02-07, REQ-02-08, and REQ-02-09. It should be the first P0 item worked on after security fixes.

- **Requirements needing decomposition?** None. All requirements are appropriately scoped.

### Sequencing Recommendation

1. REQ-02-01 + REQ-02-02 + REQ-02-03 (security fixes, all S, parallelizable)
2. REQ-02-04 (Drive completion, S, parallelizable with #1 if Google Cloud setup is ready)
3. REQ-02-05 (test framework setup, M, prerequisite for all test requirements)
4. REQ-02-06 (P0 regression tests, S, validates security fixes)
5. REQ-02-09 (CI pipeline, S, enables automated verification)
6. REQ-02-07 + REQ-02-08 (component + extension tests, M each, parallelizable)
7. REQ-02-10 + REQ-02-11 (audit log + retry buttons, M + S, parallelizable)
8. P2 items in any order if capacity remains
