---
title: BRD — MVP 01
description: Business Requirements Document generated from MVP Status Review 01, covering gaps, priorities, and acceptance criteria.
hero_eyebrow: Business requirements
hero_title: BRD for MVP 01
hero_summary: Translates engineering observations from the first MVP status review into formal business requirements with prioritised acceptance criteria.
permalink: /brd-mvp-01/
---

# Business Requirements Document — MVP 01

**Version:** 1.0
**Date:** 2026-03-28
**Source:** MVP_status_review_01.md
**Author:** Business Analyst Agent

---

## 1. Executive Summary

The Smart Apply MVP is a functional multi-surface application (NestJS backend, Next.js web portal, Chrome extension, shared contract package) with core logic for profile ingestion, JD analysis, ATS scoring, resume optimization, and application history tracking implemented across its codebase. However, the product cannot be released in its current state due to five critical blockers: the web app fails to build for production, the extension authentication bridge is incomplete (preventing any real authenticated extension-to-backend flow), the popup-to-content-script message flow is broken for sync and optimise actions, approved optimization changes are not applied to the generated resume output (undermining the core product promise), and all surface URLs are hardcoded to localhost (preventing production deployment). This BRD defines the business requirements needed to close these gaps, stabilise the MVP, and deliver the core user journey: sign in → sync profile → optimise for a job → generate an ATS-friendly PDF → track applications.

---

## 2. Stakeholder Goals

| Stakeholder | Goal | Success Metric |
|:---|:---|:---|
| Job Seeker (primary user) | Tailor resumes to job descriptions quickly and accurately, with ATS improvement visibility | End-to-end journey (sync → optimise → PDF → save) completes in < 15 seconds with a measurable ATS score increase |
| Product Owner | Ship a deployable MVP that proves core value and supports early-user feedback | All P0 requirements met; the product is accessible via a public URL and Chrome Web Store listing |
| Engineering Team | Reach a stable, testable, and deployable codebase with repeatable environments | All packages build for production; CI runs at least smoke tests; deployment is automated or scripted |

---

## 3. Delivered Capabilities (Foundation)

The following items are **COMPLETE** and form the foundation for the next phase:

| # | Capability | Business Value |
|:---|:---|:---|
| 1 | Monorepo structure with clear package boundaries | Enables parallel development across web, backend, extension, and shared packages |
| 2 | Shared Zod schemas and TypeScript types (`smart-apply-shared`) | Guarantees API contract consistency across all surfaces |
| 3 | Backend compiles and boots successfully | Backend is ready to serve API requests once deployed |
| 4 | Public health endpoint (`GET /health`) | Provides a liveness probe for monitoring and load balancers |
| 5 | Clerk-protected API routes (profile, optimise, applications) | Ensures no unauthenticated access to user data |
| 6 | Supabase-backed profile CRUD and application history CRUD | Persistent storage with ownership-scoped data access |
| 7 | LLM-backed profile parsing and JD optimisation logic | Core AI intelligence is implemented and callable |
| 8 | ATS scoring engine (hard skills, soft skills, keyword density) | Provides a quantifiable resume-to-JD relevance metric |
| 9 | Optimisation pipeline with graceful partial-failure handling | Prevents total failure; returns partial results when LLM is unavailable |
| 10 | Authenticated web pages (landing, dashboard, profile, sign-in) | Users can access and manage their data through a browser |
| 11 | Dashboard with loading, error, empty, and success states | Professional UX covering all interaction states |
| 12 | Profile editor with nested experience and education editing | Users can manually refine their master profile |
| 13 | Extension content scripts (LinkedIn profile sync, JD detection, basic autofill) | Client-side scraping foundation is functional |
| 14 | Extension background service worker (message routing skeleton) | Architectural backbone for extension ↔ backend communication |
| 15 | Client-side PDF generation (`pdf-lib`) | Enables zero-server-storage resume PDF creation in the browser |
| 16 | Extension and backend production builds succeed | Two of three surfaces are buildable for release |

---

## 4. Functional Requirements

### 4.1 Must-Have (P0 — Launch Blockers)

```
REQ-01-01
Title: Fix Web Production Build
User Story: As a job seeker, I want to access the Smart Apply web portal so
  that I can view my dashboard, edit my profile, and track my applications.
Current State: MISSING — `npm run build:web` fails with a Next.js module
  resolution error (`global-not-found.js`).
Required State: `npm run build:web` succeeds without errors on every commit.
Acceptance Criteria:
  - Given the current codebase, when `npm run build:web` is executed, then the
    build completes with exit code 0 and produces a deployable `.next/` output.
  - Given a clean install (`rm -rf node_modules && npm install`), when
    `npm run build:web` is executed, then the build still succeeds.
Dependencies: None
```

```
REQ-01-02
Title: Extension Authentication Bridge
User Story: As a job seeker using the Chrome extension, I want to log in once
  and have my session persist so that I can use all extension features without
  re-authenticating.
Current State: PARTIAL — The popup opens `localhost:3000/sign-in`, but no
  mechanism transmits the Clerk token back to the extension or persists it in
  `chrome.storage.local`.
Required State: A complete auth flow where the extension obtains a valid Clerk
  session token, stores it, attaches it to all API calls, and prompts re-login
  on 401.
Acceptance Criteria:
  - Given the extension popup, when the user completes the Clerk sign-in flow,
    then a valid Bearer token is stored in `chrome.storage.local`.
  - Given a stored token, when the extension makes an API call, then the
    `Authorization: Bearer <token>` header is attached.
  - Given an expired or invalid token, when the backend returns 401, then the
    extension clears the stored token and prompts the user to re-login.
Dependencies: None (backend auth guard is complete)
```

```
REQ-01-03
Title: Extension Message Flow (Popup ↔ Background ↔ Content Script)
User Story: As a job seeker on a LinkedIn job page, I want to click "Sync
  Profile" or "Optimise" in the extension popup so that my profile syncs and
  resume optimisation runs automatically.
Current State: MISSING — The popup sends `TRIGGER_SYNC` and `TRIGGER_OPTIMIZE`
  messages, but no listeners exist in content scripts; the background worker does
  not send `OPTIMIZE_RESULT` back to the popup.
Required State: End-to-end message flow completes: popup → background →
  content script (if needed) → backend API → background → popup with result.
Acceptance Criteria:
  - Given a user on their LinkedIn profile page, when the user clicks "Sync
    Profile" in the popup, then the content script extracts profile data, the
    background worker calls `POST /api/profile/ingest`, and the popup displays
    the synced profile summary.
  - Given a user on a job description page, when the user clicks "Optimise" in
    the popup, then the content script extracts JD text, the background worker
    calls `POST /api/optimize`, and the popup displays ATS before/after scores
    and suggested changes.
  - Given a network or server error during sync or optimise, when the operation
    fails, then the popup displays a user-friendly error message with a retry
    option.
Dependencies: REQ-01-02 (extension auth)
```

```
REQ-01-04
Title: Apply Approved Optimisation Changes to Resume Output
User Story: As a job seeker, I want my approved keyword changes to appear in the
  generated resume PDF so that the optimised version actually improves my ATS
  score.
Current State: PARTIAL — The extension collects `selectedChanges` from the user,
  but they are not applied to the resume snapshot or PDF generation. The backend
  returns `optimized_resume_json.experiences` as the original profile.
Required State: User-approved changes are merged into the resume JSON before PDF
  generation. Rejected changes are excluded. The final PDF reflects exactly and
  only the approved edits.
Acceptance Criteria:
  - Given a user has approved 3 of 5 suggested bullet edits, when "Generate PDF"
    is triggered, then the PDF contains the 3 revised bullets and the 2 original
    bullets.
  - Given a user has rejected all suggested changes, when "Generate PDF" is
    triggered, then the PDF contains only original profile content.
  - Given accepted changes to summary and skills, when the resume JSON is
    assembled, then the optimised summary and merged skill list are included.
Dependencies: REQ-01-03 (optimise flow must work end-to-end first)
```

```
REQ-01-05
Title: Externalise Environment-Specific URLs
User Story: As a job seeker, I want to use Smart Apply on the production
  website and extension so that I do not depend on a developer's local machine.
Current State: MISSING — API base URLs are hardcoded to `http://localhost:3001`
  in `smart-apply-web/src/lib/api-client.ts` and
  `smart-apply-extension/src/lib/api-client.ts`. Sign-in and dashboard links in
  the extension popup point to `http://localhost:3000`. Backend CORS only allows
  `localhost:3000`.
Required State: All URLs are configurable via environment variables or build-time
  configuration. Production builds use production URLs. CORS allows the deployed
  web origin and the published extension ID.
Acceptance Criteria:
  - Given a production build of the web app, when the app makes an API call,
    then it uses the value of `NEXT_PUBLIC_API_URL` (not localhost).
  - Given a production build of the extension, when the extension calls the API
    or links to the web portal, then it uses build-time injected production URLs.
  - Given the backend is deployed, when a request arrives from the production web
    origin or the published extension ID, then CORS allows the request.
  - Given no environment variable is set, when the app starts in development,
    then it falls back to localhost defaults.
Dependencies: None
```

---

### 4.2 Should-Have (P1 — High Value)

```
REQ-01-06
Title: Google Drive PDF Upload
User Story: As a job seeker, I want my optimised resume PDF uploaded to my
  Google Drive automatically so that I have a permanent, organised record of
  every tailored resume.
Current State: MISSING — Google Drive integration is referenced in docs and
  environment examples but has no working implementation in the codebase.
Required State: After PDF generation, the extension uploads the file to
  `Resume-Flow/{Company_Name}/` in the user's Drive, returns a shareable link,
  and stores the link in `application_history.drive_link`.
Acceptance Criteria:
  - Given Google OAuth consent is granted, when a PDF is generated, then it is
    uploaded to the correct Drive folder and a shareable link is returned.
  - Given the upload fails (quota, network, permissions), then the extension
    offers a local download fallback.
  - Given the upload succeeds, then the `drive_link` is saved to the application
    history record.
Dependencies: REQ-01-04 (PDF must contain approved changes before uploading)
```

```
REQ-01-07
Title: Complete ATS Scoring (Role Relevance & Seniority)
User Story: As a job seeker, I want the ATS score to accurately reflect how
  well my experience level and job titles match the target role so that I can
  trust the score as a useful signal.
Current State: PARTIAL — Role relevance (20 pts) and seniority alignment
  (10 pts) return fixed placeholder values. Only hard skills (50 pts), soft
  skills (10 pts), and keyword density (10 pts) are calculated.
Required State: All five scoring dimensions are fully implemented with synonym
  mapping, experience-year calculation, and keyword spam capping.
Acceptance Criteria:
  - Given a profile with 8 years of backend experience and a JD requesting a
    "Senior Backend Engineer", then the seniority score is 10/10.
  - Given a profile with "Software Developer" titles and a JD for "Software
    Engineer", then role relevance scores proportionally via synonym mapping.
  - Given a keyword appears 10 times in the resume, then it is capped at 3
    occurrences for scoring purposes.
Dependencies: None
```

```
REQ-01-08
Title: Supabase Migration System
User Story: As an engineer, I want database schema changes tracked in version-
  controlled migration files so that environments can be set up and updated
  repeatably.
Current State: MISSING — Schema exists only as a SQL document in
  `smart-apply-doc/resume_flow_schema.sql`. No `supabase/migrations/` folder or
  migration tooling is present.
Required State: A migration folder exists with numbered migration files. Schema
  can be applied to a fresh Supabase instance via a documented command.
Acceptance Criteria:
  - Given a new Supabase instance, when the migration command is run, then all
    tables (`master_profiles`, `application_history`, `user_integrations`) are
    created with correct columns and RLS policies.
  - Given an existing instance, when a new migration is added, then it applies
    incrementally without data loss.
Dependencies: None
```

```
REQ-01-09
Title: Account Deletion (Clerk Webhook)
User Story: As a job seeker, I want my data permanently deleted when I delete my
  account so that my privacy is respected (Right to be Forgotten).
Current State: MISSING — No Clerk webhook handler exists. Docs mention it as a
  requirement but no implementation is present.
Required State: A `POST /api/webhooks/clerk` endpoint receives the
  `user.deleted` event, verifies the webhook signature, and hard-deletes all
  rows for the user across `master_profiles`, `application_history`, and
  `user_integrations`.
Acceptance Criteria:
  - Given a `user.deleted` Clerk webhook event, when the endpoint receives it,
    then all user data is hard-deleted from all three tables.
  - Given the webhook signature is invalid, when the request arrives, then it is
    rejected with 401.
  - Given a deletion occurs, then an audit log entry is created with only the
    user ID and timestamp (no PII).
Dependencies: REQ-01-08 (database must exist before deletion can be tested)
```

```
REQ-01-10
Title: Deployment Configuration
User Story: As a product owner, I want the web app, backend, and extension
  deployable via an automated or scripted process so that releases are
  repeatable and not dependent on a single developer's machine.
Current State: MISSING — No `vercel.json`, `Dockerfile`, GitHub Actions
  workflows, or equivalent deployment automation exists in the repository.
Required State: Deployment manifests or CI/CD configuration exist for web
  (Vercel), backend (Render/Railway/Fly.io), and extension (Chrome Web Store
  build artifact). A single documented process produces deployable artifacts.
Acceptance Criteria:
  - Given a merged PR to `main`, when CI runs, then all three packages build
    successfully.
  - Given the web deployment config, when triggered, then the Next.js app
    deploys to the configured platform.
  - Given the backend deployment config, when triggered, then the NestJS app
    deploys and passes the health check.
Dependencies: REQ-01-01 (web must build), REQ-01-05 (URLs must be configurable)
```

```
REQ-01-11
Title: Automated Test Suite (Smoke Tests)
User Story: As an engineer, I want automated tests covering critical paths so
  that regressions are caught before deployment.
Current State: MISSING — `npm test` fails because no test files exist. Zero
  automated test coverage.
Required State: Smoke tests exist for backend auth, profile CRUD, application
  CRUD, ATS scoring, and optimisation pipeline (with mocked LLM). Tests run in
  CI without external dependencies.
Acceptance Criteria:
  - Given the test command is run, then all tests pass with exit code 0.
  - Given a valid Clerk JWT mock, when the auth guard is tested, then
    authenticated routes return 200 and unauthenticated routes return 401.
  - Given the scoring engine, when tested with a known profile and JD, then the
    score is deterministic and within expected bounds.
  - Given the optimise pipeline with a mocked LLM, when called, then
    before/after scores and suggested changes are returned.
Dependencies: None
```

---

### 4.3 Could-Have (P2 — Nice To Have)

```
REQ-01-12
Title: Extended Autofill Field Coverage
Current State: PARTIAL — only full_name, email, phone, location are filled.
Required State: Autofill covers summary, skills, work experience, education, and
  resume file upload on LinkedIn Easy Apply. Unsupported fields offer clipboard
  fallback.
Dependencies: REQ-01-03, REQ-01-04
```

```
REQ-01-13
Title: Web-Based Optimise/Apply Flow
Current State: PARTIAL — The web dashboard is read-only (history view). The
  optimise flow is extension-only.
Required State: Users can paste a JD URL or text into the web portal and trigger
  optimisation without the extension installed.
Dependencies: REQ-01-04, REQ-01-07
```

```
REQ-01-14
Title: Settings & Account Management UI
Current State: MISSING — No settings area exists beyond profile editing.
Required State: A settings page shows connected integrations (Google Drive),
  account info, and an account deletion option.
Dependencies: REQ-01-06 (Google Drive), REQ-01-09 (account deletion)
```

```
REQ-01-15
Title: Manual Profile Upload / Import
Current State: MISSING — Profile ingestion relies solely on extension-based
  LinkedIn scraping. The shared schema supports `manual` and `upload` sources
  but no UI exists.
Required State: Users can upload a resume file (PDF or plain text) via the web
  portal, which is parsed into a structured master profile.
Dependencies: None
```

```
REQ-01-16
Title: DOM Selector Hardening for LinkedIn/Indeed
Current State: PARTIAL — Extraction is selector-dependent and works on
  happy-path pages. Not robust enough for production-level reliability.
Required State: A selector registry/versioning model is in place with fallback
  extractors and structured error reporting when selectors fail.
Dependencies: None
```

---

## 5. Non-Functional Requirements

| # | Category | Requirement | Source |
|:---|:---|:---|:---|
| NFR-01 | Performance | End-to-end optimise flow (click → results) completes within 5–10 seconds | TRD §16.1 |
| NFR-02 | Performance | PDF generation completes within 2 seconds | TRD §16.1 |
| NFR-03 | Performance | Autofill perceived response within 1 second | TRD §16.1 |
| NFR-04 | Security | Never store resume PDFs on the server; generated PDFs exist only in the user's browser and Google Drive | TRD §15.1, PRD §1 (Zero-Storage Policy) |
| NFR-05 | Security | Clerk secrets, Supabase service-role keys, and LLM API keys must exist only in server environments; never bundled into the extension | TRD §15.3 |
| NFR-06 | Security | Sanitise all text extracted from LinkedIn/Indeed DOM to prevent XSS and injection | TRD §15.2 |
| NFR-07 | Security | Clerk webhook signature must be verified to prevent spoofed deletion requests | TRD §15.4 |
| NFR-08 | Privacy | Zero server-side PDF storage; Drive files remain user-owned and are not deleted on account termination | PRD §1, PRD §6 |
| NFR-09 | Privacy | Account deletion triggers a hard delete of all user data across all tables (Right to be Forgotten) | PRD §6, TRD §15.4 |
| NFR-10 | Accessibility | All interactive UI elements must be keyboard-navigable with visible focus indicators | PRD §3, Project conventions |
| NFR-11 | Accessibility | All layouts must be responsive across mobile, tablet, and desktop | Project conventions |
| NFR-12 | Reliability | LLM timeout → retry once → graceful fallback returning partial data | TRD §17.3 |
| NFR-13 | Reliability | Google Drive upload failure → local download fallback | TRD §17.3 |
| NFR-14 | Reliability | Unsupported job board form → clipboard copy mode | TRD §17.3 |
| NFR-15 | Observability | Request-ID-based tracing on all backend API calls; LLM calls logged with token counts and latency; no PII in logs | TRD §17.1 |
| NFR-16 | AI Safety | LLM must not fabricate experience or certifications; low-confidence inferences must be flagged in warnings; user approval is mandatory | TRD §10.3 |
| NFR-17 | AI Safety | All LLM responses validated against Zod schemas; unexpected fields stripped (defence against prompt injection via JD text) | TRD §10.4 |

---

## 6. Out of Scope

This BRD explicitly does **not** cover the following:

| Item | Reason |
|:---|:---|
| Full auto-apply / auto-submit | PRD §1 mandates human-in-the-loop; submit is always manual |
| Multi-template resume design marketplace | Post-MVP feature (PRD §7, v2.0+) |
| Cover letter generation workflow | Post-MVP feature (PRD §7, v2.0+) |
| Batch/overnight PDF generation ("Cart") | Post-MVP feature (PRD §7, v2.0) |
| Multi-language resume support | Post-MVP feature |
| Interview coaching | Post-MVP feature (PRD §7, v3.0) |
| Workday / Greenhouse / Lever autofill adapters | MVP targets LinkedIn Easy Apply only (TRD §14.1 priority 1); other platforms are v1.5 |
| Mobile-native application | Web responsive is in scope; native apps are not |
| Advanced analytics / insights dashboard | MVP dashboard shows history only |

---

## 7. Open Questions

| # | Question | Owner | Due |
|:---|:---|:---|:---|
| 1 | What is the target deployment platform for the backend (Render, Railway, Fly.io, or AWS)? This affects Dockerfile and CI/CD configuration. | Engineering Lead | Phase 1 |
| 2 | Should the extension auth bridge use Clerk's `getToken()` via an injected content script on the web app, or a separate OAuth-like redirect flow? | Engineering Lead | Phase 1 |
| 3 | Is Google Drive integration a hard requirement for MVP launch, or can an initial release offer local PDF download only with Drive as a fast follow? | Product Owner | Phase 1 |
| 4 | What is the minimum acceptable automated test coverage for the first production deployment? | Engineering Lead | Phase 2 |
| 5 | Should the web portal eventually offer a full optimise flow (paste-JD), or will it remain read-only for the foreseeable future? | Product Owner | Phase 2 |
| 6 | How should the Clerk token be refreshed in the extension — silent refresh, or prompt the user to re-login via the web app? | Engineering Lead | Phase 1 |
| 7 | What is the Next.js version target? The current build failure may be related to a version mismatch — should the project pin to a known-good version? | Engineering Lead | Immediate |

---

## 8. Approval Checklist

- [x] All P0 requirements have at least two acceptance criteria
- [x] Every requirement references a user story
- [x] No requirement contradicts the Zero-Storage Policy (PRD §1)
- [x] No requirement contradicts Clerk auth model
- [x] NFRs traceable to TRD sections
- [x] Out-of-scope list reviewed to prevent unintended inclusions
