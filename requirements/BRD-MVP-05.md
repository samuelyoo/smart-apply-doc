---
title: BRD — MVP 05
description: Business Requirements Document for MVP Phase 5, driven by MVP_status_review_03 deployment readiness gaps and data correctness issues.
hero_eyebrow: Business requirements
hero_title: BRD for MVP 05
hero_summary: Translates deployment blockers, data correctness bugs, environment documentation gaps, and operational readiness issues into prioritised business requirements for release preparation.
permalink: /brd-mvp-05/
---

# Business Requirements Document — MVP 05

**Version:** 1.0  
**Date:** 2026-03-31  
**Source:** MVP_status_review_03.md  
**Author:** Business Analyst Agent  

---

## 1. Executive Summary

The Smart Apply MVP is functionally complete across all four packages (web, backend, extension, shared). All 8 development phases (P01–P06, Test P1, Test P2) are complete and architect-reviewed. 281 tests pass with 100% pass rate, and coverage targets are met (backend 93.01%, web 90.65%, extension 83.34%, shared 100%). The dashboard has evolved from a flat table into a rich home base with 6 content sections. The core user journey — sign in → import profile → optimize against JD → approve changes → generate PDF → save application — works across both web and extension surfaces.

However, MVP_status_review_03 identifies **four categories of gaps** that must be closed before production release:

1. **Data correctness** — The extension saves the raw LLM output as `applied_resume_snapshot` instead of the user-approved version, creating a mismatch between what the user downloaded and what is stored in the database.
2. **Deployment blockers** — No backend hosting platform is configured, the CI pipeline is missing a backend build step, and no release runbook exists.
3. **Environment documentation** — 8 of 18 environment variables consumed by the codebase are undocumented in `.env.example`, creating setup risk for any new deployment.
4. **Operational readiness** — The health check is shallow (no downstream connectivity verification), 14 console.log statements remain in production code, and there is no structured error reporting.

This BRD defines the requirements to transform the MVP from "functionally complete" to "release-ready," targeting the final gate before production deployment.

---

## 2. Stakeholder Goals

| Stakeholder | Goal | Success Metric |
|:---|:---|:---|
| Job Seeker (primary user) | Application history accurately reflects the resume I approved and downloaded | 100% of saved `applied_resume_snapshot` records match the user-approved PDF content |
| Job Seeker (primary user) | Access the product reliably in production | Backend API uptime ≥99% during business hours; web app deployed on Vercel |
| Product Owner | Ship the MVP to production with confidence | All P0 items resolved; release runbook executed successfully in staging |
| Product Owner | New team members can set up the project without tribal knowledge | A developer can run the full stack locally using only `.env.example` and README |
| Engineering Team | CI catches all build/test regressions across all 4 packages | CI pipeline builds and tests all 4 packages with zero gaps |
| Engineering Team | Production incidents are detectable and diagnosable | Health endpoint verifies DB connectivity; errors are reported to a monitoring service |

---

## 3. Previous Phase Outcomes

### 3.1 Requirements Closed (from BRD-MVP-04 / Phases P05–P06 + Test P1–P2)

| REQ ID | Title | Status |
|:---|:---|:---|
| REQ-04-01 | Extension Autofill Toggle in Popup | ✅ COMPLETE — toggle with persistence in `chrome.storage.local` |
| REQ-04-02 | Programmatic Autofill Script Injection on Any Domain | ✅ COMPLETE — `chrome.scripting.executeScript` with URL filtering |
| REQ-04-03 | Auto-Activate Autofill on External Application Redirect | ✅ COMPLETE — 60s guard, tab navigation detection |
| REQ-04-04 | Dashboard Onboarding Checklist | ✅ COMPLETE — `<OnboardingChecklist />` component |
| REQ-04-05 | Dashboard Quick Actions Bar | ✅ COMPLETE — `<QuickActions />` with 4 action buttons |
| REQ-04-06 | Dashboard Profile Completeness Meter | ✅ COMPLETE — `<ProfileCompleteness />` component |
| REQ-04-07 | Dashboard Application Status Pipeline View | ✅ COMPLETE — `<PipelineView />` with table/pipeline toggle |
| REQ-04-08 | Web Optimize Flow — Save Application Record | ✅ COMPLETE — POST /api/applications on PDF download |
| BRD-TEST-P1 | Baseline test coverage (all packages) | ✅ COMPLETE — 142 tests |
| BRD-TEST-P2 | Coverage target achievement | ✅ COMPLETE — 281 tests, all targets met |

### 3.2 Requirements Carried Forward

| Original Source | Priority | Carry-Forward Reason |
|:---|:---|:---|
| MVP Review 02 §4 — No backend hosting target | → P0 | Still no Render/Railway/Fly configuration |
| MVP Review 02 §4 — Backend build missing from CI | → P0 | Still missing |
| MVP Review 02 §4 — Incomplete `.env.example` | → P0 | 8 vars still undocumented |
| MVP Review 02 §3 — Snapshot mismatch in extension | → P0 | Most impactful product bug; still present |
| MVP Review 02 §6 — Shallow health check | → P1 | Still returns only `{ status: 'ok' }` |
| MVP Review 02 §6 — No release runbook | → P1 | No deployment documentation exists |
| BRD-MVP-02 REQ-02-13 — Structured logging | → P2 | Deferred twice; 14 console.log statements remain |
| BRD-MVP-01 REQ-01-16 — DOM selector hardening | → P2 | Heuristic-only; no selector versioning |

---

## 4. Delivered Capabilities (Foundation)

| # | Capability | Business Value |
|:---|:---|:---|
| 1 | Complete auth across web (Clerk middleware), backend (JWT guard), and extension (auth bridge) | Users are securely authenticated on all surfaces |
| 2 | Profile import from LinkedIn (extension) and PDF/text upload (web) | Users can onboard from multiple sources |
| 3 | LLM-powered resume optimization with ATS scoring (before/after) | Users see measurable improvement in ATS compatibility |
| 4 | Selectable change approval with PDF generation | Users control exactly what goes into their resume |
| 5 | Application tracking with table + pipeline views, stats, and status updates | Users can manage their job search pipeline |
| 6 | Dashboard with onboarding checklist, profile completeness, quick actions | New and returning users have an actionable home base |
| 7 | Cross-domain autofill injection with toggle and auto-activation | Users can auto-fill forms on any career portal |
| 8 | Google Drive upload (extension, best-effort) | Generated resumes are stored in the user's own Drive |
| 9 | Account deletion with Clerk webhook cascade | Users can exercise right-to-be-forgotten |
| 10 | 281 tests across all packages with coverage targets met | Engineering team has confidence in code quality |
| 11 | CI pipeline with typecheck + test + build for 3 of 4 packages | Regressions are caught automatically on PR |
| 12 | Web app saves application record on PDF download | Web-originated optimizations are tracked in history |

---

## 5. Functional Requirements

### 5.1 Must-Have (P0 — Release Blockers)

```
REQ-05-01
Title: Fix Extension Snapshot Mismatch
User Story: As a job seeker, I want the application history to store the exact
  resume content I approved so that my records accurately reflect what I submitted
  to employers.
Current State: PARTIAL — The extension's handleSaveApplication() in
  service-worker.ts (line 194) saves payload.optimizeResult.optimized_resume_json
  (the raw LLM output) as applied_resume_snapshot instead of the version filtered
  by the user's selectedChanges. The web flow is correct (uses buildApprovedResume).
Required State: The extension's save flow must apply the same selectedChanges
  filter used for PDF generation before saving the applied_resume_snapshot. The
  stored snapshot must match byte-for-byte what the user approved and downloaded.
Acceptance Criteria:
  - Given a user selects 3 of 5 suggested changes in the extension popup, when
    the application is saved, then applied_resume_snapshot contains only the 3
    approved changes, not all 5.
  - Given a user deselects all changes, when the application is saved, then
    applied_resume_snapshot contains the original profile data with zero
    modifications.
  - Given the web flow saves an application, then its applied_resume_snapshot
    matches the extension's for the same set of selections (parity test).
Dependencies: None — isolated fix in service-worker.ts
```

```
REQ-05-02
Title: Add Backend Build Step to CI Pipeline
User Story: As an engineer, I want the CI pipeline to build the backend package
  so that compilation failures are caught before merge.
Current State: MISSING — .github/workflows/ci.yml typechecks and tests the backend
  but does not run the build step. A backend-specific compilation error (e.g.,
  missing import in a module not covered by tests) would go undetected.
Required State: The CI workflow includes a backend build step after tests, using
  the same command as local builds (npm -w @smart-apply/api run build).
Acceptance Criteria:
  - Given a PR introduces a backend compilation error, when CI runs, then the
    pipeline fails at the backend build step with a clear error message.
  - Given all 4 packages are healthy, then CI passes all typecheck + test + build
    steps for all 4 packages.
Dependencies: None — single-line addition to ci.yml
```

```
REQ-05-03
Title: Complete Environment Variable Documentation
User Story: As a developer setting up the project for the first time, I want a
  single .env.example file that lists every required environment variable so that
  I can configure my local environment without reading source code.
Current State: PARTIAL — The root .env.example documents 10 of 18 variables
  consumed by the codebase. Missing: ALLOWED_ORIGINS, CHROME_EXTENSION_ID, PORT,
  NODE_ENV, CLERK_WEBHOOK_SECRET, VITE_API_BASE_URL, VITE_WEB_BASE_URL,
  VITE_GOOGLE_OAUTH_CLIENT_ID.
Required State: The root .env.example documents all environment variables
  consumed by any package, organized by category (Clerk, Supabase, LLM, Google,
  Backend, Extension), with comments explaining purpose and example values.
Acceptance Criteria:
  - Given a developer clones the repo, when they copy .env.example to .env, then
    every variable referenced by process.env or import.meta.env in the codebase
    has a corresponding entry in the file.
  - Given each variable entry, then it includes a comment describing its purpose,
    which package consumes it, and an example value (using placeholder format, not
    real credentials).
  - Given VITE_API_BASE_URL and VITE_WEB_BASE_URL, then example values show both
    localhost (development) and production URL patterns.
Dependencies: None
```

```
REQ-05-04
Title: Configure Backend Hosting Platform
User Story: As a product owner, I want the backend API deployed to a production
  hosting platform so that the web app and extension can reach it over the
  internet.
Current State: MISSING — A Dockerfile exists in smart-apply-backend/ but no
  hosting platform is configured. There is no Render blueprint, Railway config,
  Fly.io config, or equivalent deployment manifest in the repository.
Required State: The backend has a production hosting configuration committed to
  the repo. The configuration supports environment variable injection, health
  check routing, and auto-deploy from the main branch. The hosting platform
  supports Docker or Node.js native builds.
Acceptance Criteria:
  - Given the hosting configuration is committed, when a developer reads the
    release runbook, then they can deploy the backend to production in under
    30 minutes.
  - Given the backend is deployed, when making a GET request to /health, then
    the response returns HTTP 200 with { status: 'ok' }.
  - Given an environment variable is changed in the hosting platform, when the
    service restarts, then the new value is reflected without code changes.
  - Given the deployment configuration, then it specifies the health check
    endpoint, port, and required environment variables.
Dependencies: REQ-05-03 (env documentation needed for hosting setup)
```

```
REQ-05-05
Title: Write Release Runbook
User Story: As an engineer deploying to production for the first time, I want a
  step-by-step release runbook so that I can execute the deployment without
  guessing at configuration or sequencing.
Current State: MISSING — No deployment documentation exists in the repository
  beyond the Dockerfile and vercel.json.
Required State: A release runbook document covers the full deployment sequence
  for all components: Supabase migrations, backend deployment, web deployment,
  extension build, DNS/domain setup, environment variable configuration, Clerk
  webhook registration, and post-deploy verification.
Acceptance Criteria:
  - Given a new engineer reads the runbook, then they can deploy the full stack
    to a staging environment without additional guidance.
  - Given the runbook, then it includes a pre-deploy checklist (env vars set,
    migrations run, secrets configured), deploy steps for each component, and a
    post-deploy verification checklist (health check, auth flow, optimize flow).
  - Given Supabase migrations, then the runbook specifies the exact CLI commands
    and expected output.
  - Given Clerk webhook setup, then the runbook specifies the webhook URL, event
    types to subscribe to, and how to obtain the webhook secret.
Dependencies: REQ-05-03 (env documentation), REQ-05-04 (backend hosting chosen)
```

### 5.2 Should-Have (P1 — High Value)

```
REQ-05-06
Title: Strengthen Health Check with Database Connectivity
User Story: As an operations engineer, I want the health endpoint to verify
  database connectivity so that I can detect infrastructure failures before users
  are affected.
Current State: PARTIAL — GET /health returns { status: 'ok', timestamp } without
  verifying Supabase, Clerk, or LLM availability. The endpoint is a liveness
  check only, not a readiness check.
Required State: The health endpoint performs a lightweight Supabase connectivity
  check (e.g., SELECT 1 or equivalent) and reports the result. The response
  distinguishes between liveness (app running) and readiness (app + dependencies
  healthy). If the DB check fails, the endpoint returns HTTP 503 with a
  degraded status.
Acceptance Criteria:
  - Given Supabase is reachable, when GET /health is called, then the response
    includes { status: 'ok', db: 'connected' } with HTTP 200.
  - Given Supabase is unreachable, when GET /health is called, then the response
    includes { status: 'degraded', db: 'disconnected' } with HTTP 503.
  - Given the health check, then the DB query completes within 2 seconds or
    times out with a degraded status.
  - Given the health check response, then it includes a timestamp and the
    application version or git commit hash.
Dependencies: Supabase service injection in HealthController
```

```
REQ-05-07
Title: Verify Google Drive End-to-End with Real OAuth Client ID
User Story: As a job seeker, I want my optimized resume PDF to upload to my
  Google Drive so that I have a backup copy organized by company.
Current State: PARTIAL — Google Drive upload code is complete in the extension
  (google-drive.ts), but manifest.ts uses GOOGLE_OAUTH_CLIENT_ID_PLACEHOLDER as
  fallback when VITE_GOOGLE_OAUTH_CLIENT_ID is not set at build time. CI passes
  the real ID as a secret, but local builds and any non-CI build produce a
  non-functional extension.
Required State: The Google Drive upload flow is verified end-to-end with a real
  Google OAuth client ID. The local development workflow is documented so that
  developers can test Drive upload without CI.
Acceptance Criteria:
  - Given the extension is built with a valid VITE_GOOGLE_OAUTH_CLIENT_ID, when
    the user completes the optimize flow and approves changes, then the PDF is
    uploaded to Google Drive under Resume-Flow/[Company_Name]/.
  - Given a developer sets up the project locally, when they follow the setup
    instructions, then they can obtain and configure a Google OAuth client ID
    for local testing.
  - Given the Drive upload fails (network error, auth expired), then the
    extension shows a user-friendly message and the rest of the flow (PDF
    download, application save) continues unblocked.
Dependencies: Google Cloud Console setup (external), REQ-05-05 (runbook
  documents the setup)
```

```
REQ-05-08
Title: Guard Console Logging for Production Builds
User Story: As a security-conscious user, I want the extension to not expose
  internal payloads in my browser's DevTools console so that sensitive data is
  not leaked to anyone with physical access to my machine.
Current State: 14 console statements exist across the codebase (1 backend,
  2 web, 11 extension). Extension logs include error details, autofill results,
  and internal state that could expose profile data or API responses in user
  DevTools.
Required State: Console logging in production builds is either stripped by the
  bundler or gated behind a development-mode check. Error-level logs that are
  needed for debugging may remain, but info/debug/warn logs that expose internal
  payloads must be removed or guarded.
Acceptance Criteria:
  - Given a production build of the extension, when the user performs any action,
    then no console.log or console.warn statements execute that expose internal
    payloads (autofill results, profile data, optimization output).
  - Given a development build of the extension, then all existing console
    statements continue to function for debugging purposes.
  - Given the backend production build, then the startup log
    ("API running on port") may remain as it contains no sensitive data.
  - Given console.error statements that log caught exceptions, then they may
    remain in production as they aid in debugging without exposing user data.
Dependencies: Vite build configuration (define or plugin-based dead code
  elimination)
```

### 5.3 Could-Have (P2 — Nice To Have)

```
REQ-05-09
Title: Add End-to-End Smoke Test for Critical Path
User Story: As an engineer, I want an automated E2E test that validates the core
  user journey so that full-stack regressions are caught before deployment.
Current State: MISSING — All 281 tests are unit/component tests within individual
  packages. No test validates the full flow across packages (web → backend → DB).
Required State: At least one E2E smoke test covers the critical path: authenticate
  → fetch profile → submit optimization → receive results → save application. The
  test may use a test backend with mocked LLM responses.
Acceptance Criteria:
  - Given the E2E test environment is set up, when the test runs, then it
    completes the full optimize → save flow and verifies the application record
    exists in the database.
  - Given the LLM is mocked, then the test is deterministic and does not depend
    on external AI availability.
Dependencies: Test infrastructure setup, backend hosting (staging)
```

```
REQ-05-10
Title: Add Structured Error Reporting
User Story: As an operations engineer, I want production errors reported to a
  monitoring service so that I can detect and diagnose issues without relying on
  users to report them.
Current State: MISSING — No error reporting service (Sentry, LogRocket, etc.) is
  configured. Errors are caught but only logged to console or swallowed.
Required State: A lightweight error reporting integration captures unhandled
  exceptions and key error events in the backend and web app. Source maps are
  uploaded for readable stack traces.
Acceptance Criteria:
  - Given an unhandled exception occurs in the backend, then it is reported to
    the monitoring service with stack trace and request context.
  - Given a client-side error occurs in the web app, then it is reported with
    component context and user session ID (not PII).
  - Given the monitoring service, then it supports alerting on error rate spikes.
Dependencies: Monitoring service account setup (external)
```

```
REQ-05-11
Title: DOM Selector Versioning for LinkedIn/Indeed
User Story: As a job seeker, I want the extension to continue working when
  LinkedIn or Indeed updates their page layout so that profile sync and JD
  detection don't silently break.
Current State: PARTIAL — Content scripts use direct CSS selectors for DOM
  extraction. When LinkedIn or Indeed changes their markup, the extension fails
  silently (console.warn only). There is no selector versioning, fallback chain,
  or failure notification to the user.
Required State: DOM selectors are organized in a versioned registry. When a
  primary selector fails, the extension tries fallback selectors before reporting
  failure. Failed extractions surface a user-visible notification (e.g.,
  "Profile sync may be incomplete — LinkedIn layout may have changed").
Acceptance Criteria:
  - Given LinkedIn changes a DOM selector, when the primary selector fails, then
    the extension tries at least one fallback selector before giving up.
  - Given all selectors fail, then the user sees a notification explaining that
    extraction may be incomplete.
  - Given a new selector version is needed, then it can be added to the registry
    without changing the extraction logic.
Dependencies: Selector registry module (new), content script refactor
```

---

## 6. Non-Functional Requirements

| # | Category | Requirement | Source |
|:---|:---|:---|:---|
| NFR-01 | Data Integrity | The `applied_resume_snapshot` stored in the database must match the resume content the user approved, across both web and extension flows | PRD §3.2 (Anti-Hallucination Review UI) |
| NFR-02 | Availability | Backend health endpoint must verify database connectivity and return HTTP 503 when downstream services are unavailable | TRD §17 (Reliability) |
| NFR-03 | Security | Production builds must not expose internal payloads, API responses, or profile data via console logging | TRD §15 (Security) |
| NFR-04 | Privacy | Zero server-side PDF storage policy remains in effect — no resume files stored on backend or database | PRD §1 (Zero-Storage Policy) |
| NFR-05 | Operability | All environment variables consumed by the codebase must be documented in `.env.example` with purpose, consuming package, and example values | TRD §18 (Deployment) |
| NFR-06 | CI/CD | The CI pipeline must typecheck, test, and build all 4 packages; a failure in any package must fail the pipeline | TRD §18 (Deployment) |
| NFR-07 | Deployability | A new engineer must be able to deploy the full stack to staging using only the release runbook and `.env.example` without additional guidance | TRD §18 (Deployment) |
| NFR-08 | Accessibility | All interactive elements must remain keyboard-accessible with visible focus indicators (no regression from P06) | PRD §3, copilot-instructions.md |

---

## 7. Out of Scope

| Item | Reason |
|:---|:---|
| Application detail view and resume version history (REQ-02-12 from BRD-MVP-02) | Post-release feature; deferred to v1.5 |
| Bulk application status update and export (CSV/JSON) | Post-release feature per PRD §7 roadmap |
| Smart filtering / search on dashboard | Post-release feature; current table/pipeline views are sufficient for MVP |
| Platform-specific autofill adapters (Workday step handling, etc.) | Deferred to v1.5 per PRD §7 |
| Batch/bulk apply ("cart" system) | Deferred to v2.0 per PRD §7 |
| AI-driven interview prep | Deferred to v3.0 per PRD §7 |
| Multiple resume templates / template marketplace | MVP ships with single ATS-friendly template per TRD §12.3 |
| Mobile native app | Desktop-first per TRD §4.3 |
| Chrome Web Store submission | Separate operational task, not a product requirement |
| ESLint / Prettier CI integration | Deferred from BRD-MVP-02 REQ-02-14; not a release blocker |
| npm audit vulnerability resolution | Deferred from BRD-MVP-02 REQ-02-15; transitive dependencies only |

---

## 8. Open Questions

| # | Question | Owner | Due |
|:---|:---|:---|:---|
| 1 | Which backend hosting platform should be used (Render, Railway, Fly.io, AWS ECS)? Consider free tier availability, Docker support, and auto-deploy capability. | Engineering Team | Before REQ-05-04 implementation |
| 2 | Should the health check also verify LLM API availability, or only database connectivity? LLM checks may add latency and rate-limit risk. | Engineering Team | Before REQ-05-06 implementation |
| 3 | Should console.log stripping be done via Vite `define` (replacing `console.log` with no-ops) or via a Vite plugin that removes the calls entirely? | Engineering Team | Before REQ-05-08 implementation |
| 4 | Should the release runbook live in `smart-apply-doc/` (published to GitHub Pages) or in the repo root as `RELEASE.md`? | Product Owner | Before REQ-05-05 implementation |
| 5 | For E2E smoke tests (REQ-05-09), should we use Playwright, Cypress, or a lightweight API-only test runner? | Engineering Team | Post-release planning |
| 6 | Should we use Sentry (free tier) or a lighter alternative for error reporting (REQ-05-10)? | Engineering Team | Post-release planning |

---

## 9. Approval Checklist

- [x] All P0 requirements have at least two acceptance criteria
- [x] Every requirement references a user story
- [x] No requirement contradicts the Zero-Storage Policy (PRD §1)
- [x] No requirement contradicts Clerk auth model
- [x] NFRs traceable to TRD/PRD sections
- [x] Out-of-scope list reviewed to prevent unintended inclusions
- [x] All carried-forward requirements from previous BRDs are addressed or explicitly deferred

---

## 10. Summary

**Top 3 P0 requirements:**

1. **REQ-05-01 (Fix Extension Snapshot Mismatch)** — The most impactful product-correctness bug. Users download one version of their resume but the database stores a different version, creating silent data corruption in application history. Fix is isolated to `service-worker.ts` and should mirror the web flow's `buildApprovedResume()` pattern.

2. **REQ-05-04 (Configure Backend Hosting Platform)** — The backend has no production target. Without this, the web app and extension cannot reach the API over the internet. This is the single largest deployment blocker.

3. **REQ-05-03 (Complete Environment Variable Documentation)** — 8 of 18 environment variables are undocumented, making first-time setup error-prone and deployment risky. This is a prerequisite for both backend hosting (REQ-05-04) and the release runbook (REQ-05-05).
