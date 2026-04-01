---
title: HLD-MVP-P07 — Deployment Readiness & Production Release Gate
description: High-Level Design for MVP Phase 7 — fixing data-correctness bugs, completing CI/CD, documenting environment configuration, configuring backend hosting, and writing the release runbook.
hero_eyebrow: High-level design
hero_title: HLD for MVP Phase 7
hero_summary: Translates BRD-MVP-05 P0 and P1 requirements into architecture decisions, data flows, and acceptance criteria to move Smart Apply from "functionally complete" to "release-ready."
permalink: /hld-mvp-p07/
---

# HLD-MVP-P07 — Deployment Readiness & Production Release Gate

**Version:** 1.0  
**Date:** 2026-03-31  
**Phase:** P07 (Release Preparation)  
**Source:** BRD-MVP-05.md §5.1 (REQ-05-01 through REQ-05-05) and §5.2 (REQ-05-06 through REQ-05-08)  
**Prerequisite:** All prior phases (P01–P06, Test P1–P2) complete and architect-reviewed.

---

## 1. Phase Objective

### Business Goal

Transform the Smart Apply MVP from "functionally complete" (281 tests passing, all features working) to "release-ready" by resolving data correctness bugs, completing CI/CD coverage, documenting the full environment, configuring backend hosting, and creating a release runbook.

### User-Facing Outcome After This Phase

- Application history accurately records the exact resume the user approved and downloaded (snapshot mismatch fixed).
- The backend API is live on a production hosting platform reachable by both the web app and extension.
- Any new developer can set up the full stack locally using only `.env.example` and the README.
- The health endpoint reports real infrastructure status (database connectivity).
- Production builds of the extension do not leak internal payloads to DevTools console.
- A step-by-step release runbook exists for deploying all components.

---

## 2. Component Scope

### Repos Affected

| Repo | Changes |
|:---|:---|
| `smart-apply-extension` | Fix snapshot mismatch in service-worker.ts (REQ-05-01); strip console logs for production (REQ-05-08) |
| `smart-apply-backend` | Strengthen health check with DB connectivity (REQ-05-06) |
| `.github/workflows` | Add backend build step to CI pipeline (REQ-05-02) |
| Root (`.env.example`) | Complete environment variable documentation (REQ-05-03) |
| `smart-apply-backend` | Add hosting platform configuration (REQ-05-04) |
| `smart-apply-doc` | Release runbook (REQ-05-05); this HLD + LLD |

### REQ Mapping

| REQ | Title | Priority | Status at Start | In Scope |
|:---|:---|:---|:---|:---|
| REQ-05-01 | Fix Extension Snapshot Mismatch | P0 | ⚠️ Bug — saves raw LLM output | ✅ Yes |
| REQ-05-02 | Add Backend Build Step to CI Pipeline | P0 | ❌ Missing | ✅ Yes |
| REQ-05-03 | Complete Environment Variable Documentation | P0 | ⚠️ Partial — 10/18 documented | ✅ Yes |
| REQ-05-04 | Configure Backend Hosting Platform | P0 | ❌ Missing | ✅ Yes |
| REQ-05-05 | Write Release Runbook | P0 | ❌ Missing | ✅ Yes |
| REQ-05-06 | Strengthen Health Check with DB Connectivity | P1 | ⚠️ Shallow (liveness only) | ✅ Yes |
| REQ-05-07 | Verify Google Drive E2E with Real OAuth Client ID | P1 | ⚠️ Placeholder ID | ❌ Deferred — requires external Google Cloud Console setup |
| REQ-05-08 | Guard Console Logging for Production Builds | P1 | ⚠️ 14 statements remain | ✅ Yes |

### Explicitly Out of Scope

- REQ-05-07 (Google Drive E2E verification) — Requires external Google Cloud Console setup that cannot be done in code alone. Documented as prerequisite in the release runbook.
- REQ-05-09 (E2E smoke tests) — P2; deferred to post-release hardening.
- REQ-05-10 (Structured error reporting / Sentry) — P2; deferred.
- REQ-05-11 (DOM selector versioning) — P2; deferred.
- Chrome Web Store submission — Separate operational task.
- New feature development of any kind.

---

## 3. Architecture Decisions

### AD-01: Fix Extension Snapshot Mismatch via buildApprovedResume Reuse (REQ-05-01)

**Decision:** The service worker's `handleSaveApplication()` must call `buildApprovedResume()` to filter the LLM output by `selectedChanges` before saving `applied_resume_snapshot`. The function already exists in the extension popup (`App.tsx` lines 16–52) and performs identical logic to the web flow's `buildApprovedResume()` in `optimize-results.tsx`.

**Rationale:** The bug is at `service-worker.ts` line ~194 where `applied_resume_snapshot` is set to `payload.optimizeResult.optimized_resume_json` (the raw, unfiltered LLM output). The user may have deselected some suggested changes, but the saved snapshot includes all changes. This creates a silent data integrity violation — the database record doesn't match what the user approved and downloaded as PDF.

**Key Design:**
- Extract `buildApprovedResume()` to a shared utility within the extension (e.g., `smart-apply-extension/src/lib/resume-utils.ts`) so both the popup and service worker can import it without duplication.
- The service worker must load `cached_profile` from `chrome.storage.local` (already available via `getStorage`) to provide the base profile for the function.
- The `selectedChanges` payload is already sent as `number[]` from the popup; convert to `Set<number>` before calling the function.
- The returned `{ summary, skills, experiences }` object becomes the `applied_resume_snapshot` value.

**Reference:** architecture.md §4.2 (optimization flow — "explicit user approval"), BRD-MVP-05 NFR-01 (data integrity).

### AD-02: Add Backend Build Step to CI (REQ-05-02)

**Decision:** Add `npm -w @smart-apply/api run build` to `.github/workflows/ci.yml` in the build section, after the test steps and alongside the other build steps.

**Rationale:** The CI pipeline currently typechecks and tests the backend but does not build it. This means a NestJS compilation error in an untested module would go undetected until deployment. All other packages (shared, web, extension) already have build steps.

**Key Design:**
- Single-line addition: `- run: npm -w @smart-apply/api run build` placed after the existing test steps and before or after the web build step.
- No additional environment variables are needed for the backend build (unlike the web and extension builds which need Clerk/Google keys).

**Reference:** BRD-MVP-05 NFR-06 (CI must build all 4 packages).

### AD-03: Complete Environment Variable Documentation (REQ-05-03)

**Decision:** Update `.env.example` to document all 18 environment variables consumed by the codebase, organized by category (Clerk, Supabase, LLM, Google, Backend, Extension), with inline comments explaining purpose, consuming package, and example placeholder values.

**Rationale:** 8 of 18 variables are undocumented: `ALLOWED_ORIGINS`, `CHROME_EXTENSION_ID`, `PORT`, `NODE_ENV`, `CLERK_WEBHOOK_SECRET`, `VITE_API_BASE_URL`, `VITE_WEB_BASE_URL`, `VITE_GOOGLE_OAUTH_CLIENT_ID`. A new developer cannot set up the full stack without reading source code to discover these. This violates BRD-MVP-05 NFR-05.

**Key Design:**
- Organize by category with section headers.
- Each variable includes: placeholder value, inline comment with purpose + which package consumes it.
- Do not include real secrets — use `sk_test_...`, `eyJ0...`, etc. as format indicators.
- Document `LLM_PROVIDER` and `LLM_MODEL` even if they have defaults, so developers know they exist.

**Reference:** BRD-MVP-05 NFR-05, NFR-07 (deployability).

### AD-04: Configure Backend Hosting Platform — Render (REQ-05-04)

**Decision:** Use Render.com as the backend hosting platform. Add a `render.yaml` Infrastructure as Code (IaC) blueprint to the repository root.

**Rationale:** Render offers: (a) native Docker support (our multi-stage Dockerfile works as-is), (b) free tier suitable for MVP launch, (c) auto-deploy from GitHub main branch, (d) built-in health check routing to `GET /health`, (e) environment variable injection via dashboard, (f) zero additional infrastructure beyond the existing Dockerfile. Railway and Fly.io are viable alternatives, but Render requires the least configuration overhead for a single-container NestJS deployment.

**Key Design:**
- `render.yaml` at repo root defines a single web service:
  - Name: `smart-apply-api`
  - Environment: Docker
  - Dockerfile path: `smart-apply-backend/Dockerfile`
  - Health check path: `/health`
  - Auto-deploy: on push to `main`
  - Plan: free (upgrade to starter for production traffic)
- Environment variables configured via Render dashboard (not committed to repo).
- The `render.yaml` references the Dockerfile context as the repo root (monorepo).

**Reference:** architecture.md deployment section, BRD-MVP-05 REQ-05-04.

### AD-05: Write Release Runbook (REQ-05-05)

**Decision:** Create `smart-apply-doc/RELEASE_RUNBOOK.md` that documents the full deployment sequence for all components. The runbook lives in `smart-apply-doc/` to be published alongside other documentation on GitHub Pages.

**Rationale:** No deployment documentation exists beyond the Dockerfile and `vercel.json`. A new engineer cannot deploy the stack without tribal knowledge of the sequencing: Supabase migrations must run before backend deployment, backend must be live before the web app and extension can reach it, Clerk webhooks must be registered after the backend URL is known.

**Key Design:**
- **Section 1: Prerequisites** — accounts needed (Supabase, Render, Vercel, Clerk, Google Cloud), tools to install.
- **Section 2: Environment Setup** — reference `.env.example`, explain how to obtain each secret.
- **Section 3: Deployment Sequence** — ordered steps:
  1. Supabase: run migrations (`supabase db push` or manual SQL).
  2. Backend: deploy to Render (Docker), set env vars, verify `/health`.
  3. Web: deploy to Vercel, set env vars (including backend URL), verify.
  4. Clerk: configure webhook endpoint to point to backend URL.
  5. Extension: build with production env vars, load unpacked or submit to Chrome Web Store.
- **Section 4: Post-Deploy Verification** — smoke test checklist (auth, profile sync, optimize, application save, health endpoint).
- **Section 5: Rollback** — how to revert each component.

**Reference:** BRD-MVP-05 NFR-07 (deployability), REQ-05-05 acceptance criteria.

### AD-06: Strengthen Health Check with Database Connectivity (REQ-05-06)

**Decision:** Inject `SupabaseService` into `HealthController` and perform a lightweight query (`SELECT 1`) with a 2-second timeout. Return HTTP 200 with `{ status: 'ok', db: 'connected' }` when healthy, or HTTP 503 with `{ status: 'degraded', db: 'disconnected' }` when the database is unreachable.

**Rationale:** The current health check is liveness-only (returns `{ status: 'ok', timestamp }` without verifying any downstream dependency). Hosting platforms like Render use the health endpoint for container readiness checks. A degraded response with a 503 status code signals to the load balancer that the container should not receive traffic.

**Key Design:**
- Inject `SupabaseService` (already exists in the backend DI container).
- Use a raw query via the Supabase client, wrapped in a 2-second `Promise.race` timeout.
- Response includes `timestamp` and `version` (from `process.env.GIT_COMMIT_SHA || 'unknown'`).
- Do NOT check LLM availability — LLM checks would add latency and risk rate-limiting on the health endpoint.

**Reference:** TRD §15 (reliability), BRD-MVP-05 NFR-02.

### AD-07: Guard Console Logging for Production Builds (REQ-05-08)

**Decision:** Use Vite's `define` configuration to replace `console.log` and `console.warn` with no-ops in production builds of the extension. Keep `console.error` for genuine error reporting. For the backend, use NestJS Logger instead of console.log for the single remaining statement.

**Rationale:** 14 console statements exist (1 backend, 2 web, 11 extension). Extension logs include error details, autofill results, and profile data that would be visible in DevTools. The Vite `define` approach is the simplest — it replaces `console.log(...)` with `(() => {})(...)` at build time, resulting in dead code that minification can strip entirely.

**Key Design:**
- In `smart-apply-extension/vite.config.ts`, add to `define`:
  ```
  'console.log': mode === 'production' ? '(() => {})' : 'console.log',
  'console.warn': mode === 'production' ? '(() => {})' : 'console.warn',
  ```
- Keep `console.error` — these indicate genuine failures the developer should see.
- For the backend's single `console.log('Smart Apply extension installed')` — this is in the extension service worker, not the backend. Replace with no-op or Logger as appropriate.
- For the web's 2 console statements — add same `define` to `next.config.ts` compiler options, or use `terserOptions.compress.drop_console` if Next.js supports it.

**Reference:** TRD §15 (security), BRD-MVP-05 NFR-03.

---

## 4. Data Flow

### 4.1 Fixed Extension Snapshot Save Flow (REQ-05-01)

```
User in extension popup selects 3 of 5 suggested changes
  → Clicks "Download PDF" button
  → Popup calls buildApprovedResume(cachedProfile, optimizeResult, selectedChanges)
  → pdf-lib generates PDF from approved data only ← (already correct)
  → PDF downloaded to user's machine
  → Popup sends SAVE_APPLICATION message to service worker:
      { optimizeResult, selectedChanges: [0, 2, 4], drive_link? }
  → Service worker receives message
  → Service worker loads cached_profile from chrome.storage.local
  → Service worker calls buildApprovedResume(cachedProfile, optimizeResult, new Set(selectedChanges))
  → applied_resume_snapshot = { summary, skills, experiences } ← FILTERED, user-approved only
  → POST /api/applications with filtered snapshot
  → Database stores snapshot matching the downloaded PDF ← DATA INTEGRITY RESTORED
```

**Before (bug):**
```
applied_resume_snapshot = optimizeResult.optimized_resume_json  ← RAW LLM OUTPUT (all 5 changes)
```

**After (fix):**
```
applied_resume_snapshot = buildApprovedResume(cachedProfile, optimizeResult, new Set(selectedChanges))
                                                                              ← FILTERED (3 changes)
```

### 4.2 CI Pipeline — Complete Build Flow (REQ-05-02)

```
Developer pushes to main or opens PR
  → GitHub Actions triggered
  → Step 1: npm ci (install all workspace dependencies)
  → Step 2: Typecheck all 4 packages (shared, backend, web, extension)
  → Step 3: Test all 4 packages (shared, backend, web, extension)
  → Step 4: Build all 4 packages:
      - npm -w @smart-apply/shared run build
      - npm -w @smart-apply/api run build        ← NEW
      - npm -w @smart-apply/web run build
      - npm -w @smart-apply/extension run build
  → All steps must pass for green CI
```

### 4.3 Health Check — Readiness Probe Flow (REQ-05-06)

```
Hosting platform or monitoring calls GET /health
  → HealthController.check() runs
  → Supabase client executes: SELECT 1
      → Race against 2-second timeout
  → If DB responds within 2s:
      HTTP 200 { status: 'ok', db: 'connected', timestamp, version }
  → If DB unreachable or timeout:
      HTTP 503 { status: 'degraded', db: 'disconnected', timestamp, version }
  → Hosting platform uses response to route or reject traffic
```

### 4.4 Deployment Sequence (REQ-05-04, REQ-05-05)

```
Step 1: Supabase — Apply migrations
  → supabase db push (or run SQL from supabase/migrations/)
  → Verify: tables exist with RLS enabled

Step 2: Backend — Deploy to Render
  → Push to main triggers Render auto-deploy
  → Render builds Docker image from smart-apply-backend/Dockerfile
  → Render sets env vars (from dashboard)
  → Verify: GET https://smart-apply-api.onrender.com/health returns 200

Step 3: Web — Deploy to Vercel
  → Push to main triggers Vercel auto-deploy
  → Vercel builds Next.js app
  → Env vars include backend URL (NEXT_PUBLIC_API_URL)
  → Verify: https://app.smartapply.com loads, auth works

Step 4: Clerk — Register webhook
  → Clerk dashboard → Webhooks → Add endpoint
  → URL: https://smart-apply-api.onrender.com/api/webhooks/clerk
  → Events: user.deleted

Step 5: Extension — Build for production
  → npm -w @smart-apply/extension run build (with production env vars)
  → Load unpacked from dist/ or package for Chrome Web Store
```

---

## 5. API Contracts

### 5.1 Modified Endpoint: GET /health (REQ-05-06)

**Before:**
```
GET /health
Response 200: { status: "ok", timestamp: "2026-03-31T..." }
```

**After:**
```
GET /health
Response 200:
{
  "status": "ok",
  "db": "connected",
  "timestamp": "2026-03-31T12:00:00.000Z",
  "version": "abc1234"
}

Response 503:
{
  "status": "degraded",
  "db": "disconnected",
  "timestamp": "2026-03-31T12:00:00.000Z",
  "version": "abc1234"
}
```

### 5.2 No Other API Changes

All existing endpoints remain unchanged. This phase only modifies the health check response shape.

---

## 6. Security Considerations

| Concern | Mitigation |
|:---|:---|
| Console logs expose profile data in extension DevTools | Vite `define` strips console.log/console.warn in production builds (AD-07) |
| `.env.example` must not contain real secrets | Use placeholder format indicators only (`sk_test_...`, `eyJ0...`) |
| `render.yaml` must not contain secrets | Only references env var names; actual values set in Render dashboard |
| Health endpoint must not leak internal errors | Return generic `db: 'disconnected'` message, not raw error details |
| Snapshot mismatch is a data integrity violation | Fix ensures database record matches user-approved content (AD-01) |
| Backend hosting must support HTTPS | Render provides automatic TLS for all services |

---

## 7. Testing Strategy

### 7.1 REQ-05-01 — Snapshot Mismatch Fix

- **Unit test:** Verify `buildApprovedResume()` in extracted utility returns only selected changes.
- **Unit test:** Verify `handleSaveApplication()` passes filtered snapshot (not raw LLM output) to the API call.
- **Test technique:** Mock `apiFetch` and verify the `applied_resume_snapshot` field in the request body.
- **Existing test update:** Update `applications.service.spec.ts` or add a new service-worker test if needed.

### 7.2 REQ-05-02 — CI Backend Build

- **Verification:** Push a deliberate compilation error to the backend, verify CI fails.
- **No unit test needed** — this is a CI configuration change.

### 7.3 REQ-05-03 — Env Documentation

- **Manual verification:** A reviewer copies `.env.example` to `.env` and confirms all packages start without undocumented var warnings.
- **No unit test needed** — documentation change.

### 7.4 REQ-05-04 — Backend Hosting

- **Manual verification:** Deploy to Render, verify GET /health returns 200 from the public URL.
- **No unit test needed** — infrastructure configuration.

### 7.5 REQ-05-05 — Release Runbook

- **Manual verification:** A reviewer follows the runbook end-to-end and reports any missing steps.
- **No unit test needed** — documentation.

### 7.6 REQ-05-06 — Health Check

- **Unit test:** Verify HealthController returns `{ status: 'ok', db: 'connected' }` when Supabase is reachable.
- **Unit test:** Verify HealthController returns HTTP 503 `{ status: 'degraded', db: 'disconnected' }` when Supabase throws.
- **Unit test:** Verify timeout handling (DB query exceeds 2 seconds → degraded response).

### 7.7 REQ-05-08 — Console Log Stripping

- **Build verification:** Production build of extension, `grep console.log dist/` returns zero matches.
- **Unit test (optional):** Verify Vite config includes console.log stripping in production mode.

---

## 8. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|:---|:---|:---|:---|
| `buildApprovedResume` extracted to shared util but service worker cannot import ES module | Low | High | Service worker already imports from `../lib/*`; same pattern applies |
| Render free tier cold starts add latency to first API call | High | Low | Documented in runbook; upgrade to starter tier for production traffic |
| Health check DB query adds latency to every health poll | Low | Low | 2-second timeout; lightweight `SELECT 1` query (sub-millisecond) |
| Vite `define` console stripping breaks legitimate error logging | Medium | Medium | Only strip `console.log` and `console.warn`; keep `console.error` |
| `render.yaml` Docker context path incorrect for monorepo | Medium | Medium | Test locally with `docker build` from repo root before pushing |

---

## 9. Implementation Order

Recommended implementation sequence based on dependencies:

1. **REQ-05-01 — Fix Extension Snapshot Mismatch** (no dependencies; highest-impact bug fix)
2. **REQ-05-02 — Add Backend Build Step to CI** (no dependencies; single-line change)
3. **REQ-05-03 — Complete Environment Variable Documentation** (no dependencies; needed by REQ-05-04 and REQ-05-05)
4. **REQ-05-06 — Strengthen Health Check** (no dependencies; needed before hosting setup)
5. **REQ-05-08 — Guard Console Logging** (no dependencies; config-only change)
6. **REQ-05-04 — Configure Backend Hosting Platform** (depends on REQ-05-03 for env documentation, REQ-05-06 for health check)
7. **REQ-05-05 — Write Release Runbook** (depends on REQ-05-03 and REQ-05-04 — must know the hosting URL and all env vars)

---

## 10. Success Criteria

### Phase-Level

- [ ] All 7 in-scope requirements implemented and verified.
- [ ] Zero regression — all 281 existing tests still pass.
- [ ] CI pipeline typechecks, tests, and builds all 4 packages.
- [ ] Health endpoint returns `{ status: 'ok', db: 'connected' }` in local development.
- [ ] A developer can clone the repo, copy `.env.example` to `.env`, and start the full stack.

### Per-Requirement Acceptance Criteria

**REQ-05-01:**
- Given a user selects 3 of 5 suggested changes, when the application is saved, then `applied_resume_snapshot` contains only the 3 approved changes applied to the base profile.
- Given the same user downloads the PDF, the PDF content matches the stored snapshot byte-for-byte.

**REQ-05-02:**
- Given a PR introduces a backend compilation error, when CI runs, then the pipeline fails at the backend build step.

**REQ-05-03:**
- Given a developer copies `.env.example` to `.env`, then all 18 environment variables are documented with purpose and example values.

**REQ-05-04:**
- Given `render.yaml` is committed and configured, when deployed, then `GET /health` on the public URL returns HTTP 200.

**REQ-05-05:**
- Given a new engineer reads the runbook, they can deploy the full stack to staging without additional guidance.

**REQ-05-06:**
- Given Supabase is reachable, then `GET /health` returns `{ status: 'ok', db: 'connected' }` (HTTP 200).
- Given Supabase is unreachable, then `GET /health` returns `{ status: 'degraded', db: 'disconnected' }` (HTTP 503).

**REQ-05-08:**
- Given a production build of the extension, when any action is performed, then zero `console.log` or `console.warn` output appears in DevTools.
