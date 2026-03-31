---
title: "HLD-MVP-P02 — P1 Stabilisation & Production Readiness"
permalink: /design/hld-mvp-p02/
---

# HLD-MVP-P02 — P1 Stabilisation & Production Readiness

**Version:** 1.0  
**Date:** 2026-03-28  
**Phase:** P1 (Should-Have)  
**Source:** BRD-MVP-01.md §4.2 (REQ-01-06 through REQ-01-11)  
**Prerequisite:** All P0 requirements (HLD/LLD-MVP-P01) complete and verified.

---

## 1. Phase Objective

### Business Goal
Bring the MVP from "it compiles and the core journey works locally" to "deployable, testable, and feature-complete for early users." This phase closes every P1 gap identified in the BRD: database migration tooling, account deletion compliance, deployment automation, a baseline automated test suite, full ATS scoring, and Google Drive integration.

### User-Facing Outcome After This Phase
- The product is reachable at a public URL (web + API) and installable from a Chrome Web Store build artifact.
- Users can delete their account and all data is removed (right to be forgotten).
- Generated PDFs are uploaded to Google Drive with a shareable link stored in application history.
- All five ATS scoring dimensions are live and fully calculated (confirmed already complete).
- Regressions are guarded by smoke tests running in CI.

---

## 2. Component Scope

### Repos Affected

| Repo | Changes |
|:---|:---|
| `smart-apply-backend` | New webhooks module, Vitest smoke tests, deployment config |
| `smart-apply-web` | Deployment config (Vercel) |
| `smart-apply-extension` | Google Drive upload integration, OAuth helpers |
| `smart-apply-shared` | No changes needed (types/schemas already cover drive_link, scoring) |
| `smart-apply-doc` | New supabase/migrations/ directory |

### REQ Mapping

| REQ | Title | Status at Start | In Scope |
|:---|:---|:---|:---|
| REQ-01-06 | Google Drive PDF Upload | ❌ Missing | ✅ Yes |
| REQ-01-07 | Complete ATS Scoring | ✅ Already Complete | ❌ No work needed |
| REQ-01-08 | Supabase Migration System | ❌ Missing | ✅ Yes |
| REQ-01-09 | Account Deletion (Clerk Webhook) | ❌ Missing | ✅ Yes |
| REQ-01-10 | Deployment Configuration | ❌ Missing | ✅ Yes |
| REQ-01-11 | Automated Test Suite (Smoke Tests) | ❌ Missing | ✅ Yes |

### Explicitly Out of Scope
- P2 requirements (REQ-01-12 through REQ-01-16)
- Monitoring dashboards or APM integration (future)
- Load testing or performance optimization
- Chrome Web Store submission process (only build artifact creation)

---

## 3. Architecture Decisions

### AD-01: Supabase CLI Migrations (REQ-01-08)
**Decision:** Use the Supabase CLI migration workflow (`supabase/migrations/` directory) with numbered SQL files.  
**Rationale:** The schema already exists in `resume_flow_schema.sql`. Wrapping it in the Supabase CLI convention enables `supabase db push` for new environments and integrates with the Supabase dashboard migration tracker.  
**Reference:** architecture.md §2 (independently buildable repos), §6 (data model).

### AD-02: Clerk Webhook with standardwebhooks Verification (REQ-01-09)
**Decision:** Create a `WebhooksModule` with a single `POST /api/webhooks/clerk` endpoint. Use the already-installed `standardwebhooks` package for signature verification. On `user.deleted`, delete from `master_profiles` — cascade constraints handle `application_history` and `user_integrations`.  
**Rationale:** Clerk uses the Standard Webhooks spec (Svix). The `standardwebhooks` package is already in `package.json`. CASCADE ON DELETE in the schema means a single `DELETE FROM master_profiles WHERE clerk_user_id = ?` handles full cleanup.  
**Reference:** architecture.md §11 (account deletion), TRD §15 (security).

### AD-03: Raw Body Access for Webhook Signature Verification
**Decision:** Use NestJS raw body parsing for the webhooks route only. Configure `NestFactory.create` with `rawBody: true` and access `req.rawBody` in the controller.  
**Rationale:** Webhook signature verification requires the exact raw bytes of the request body. JSON parsing alters the body (key ordering, whitespace) which invalidates HMAC signatures.  
**Reference:** NestJS docs — raw body access.

### AD-04: Deployment Targets (REQ-01-10)
**Decision:** 
- Web: Vercel (zero-config Next.js deployment with `vercel.json`)
- Backend: Dockerfile + docker-compose for portable deployment (Render/Railway/Fly.io)
- Extension: Vite build produces a `dist/` folder suitable for Chrome Web Store upload
- CI: GitHub Actions workflow for build + test on PR and push to main

**Rationale:** architecture.md §8 specifies Vercel for web and Render/Railway for backend. Docker gives flexibility across cloud providers. GitHub Actions is already partially used (deploy-pages.yml exists).  
**Reference:** architecture.md §8 (deployment architecture).

### AD-05: Vitest Smoke Tests with Mocked External Services (REQ-01-11)
**Decision:** Use Vitest (already installed) for backend smoke tests. Mock Supabase, OpenAI, and Clerk at the service boundary level using vi.mock(). Tests cover: auth guard, profile CRUD, application CRUD, ATS scoring, and optimization pipeline.  
**Rationale:** Smoke tests must run in CI without external dependencies. Vitest is already configured in backend `package.json`. NestJS `@nestjs/testing` supports module overrides for dependency injection mocking.  
**Reference:** BRD REQ-01-11 acceptance criteria.

### AD-06: Google Drive Upload from Extension (REQ-01-06)
**Decision:** Implement Google Drive upload in the Chrome extension using `chrome.identity.getAuthToken()` for Google OAuth and direct REST API calls to the Drive v3 upload endpoint. The extension creates a `Smart-Apply/{Company_Name}/` folder structure.  
**Rationale:** architecture.md §7 assigns Google Drive upload responsibility to the extension (client-side). Using `chrome.identity` avoids adding googleapis dependencies — the Drive REST API is simple enough for direct `fetch()` calls. The `drive.file` scope limits access to only files the app creates.  
**Reference:** architecture.md §4.2 (optimization flow), §5 (security — drive.file scope), §11 (zero resume storage on server).

---

## 4. Data Flow

### 4.1 Account Deletion Flow (REQ-01-09)

```
Clerk Dashboard (user deletes account)
  → Clerk sends POST /api/webhooks/clerk (user.deleted event)
    → Backend verifies webhook signature (standardwebhooks)
      → Backend extracts clerk_user_id from event payload
        → DELETE FROM master_profiles WHERE clerk_user_id = :userId
          → CASCADE deletes application_history rows
          → CASCADE deletes user_integrations rows
    → Return 200 OK
```

### 4.2 Google Drive Upload Flow (REQ-01-06)

```
User approves changes in extension popup
  → Extension generates PDF (pdf-lib)
    → Extension calls chrome.identity.getAuthToken({scopes: ['drive.file']})
      → Google OAuth consent (first time only)
        → Extension creates/finds "Smart-Apply" folder via Drive API
          → Extension creates "{Company_Name}" subfolder
            → Extension uploads PDF as multipart/related
              → Drive returns file ID + webViewLink
                → Extension stores drive_link in SAVE_APPLICATION message
                  → Background sends POST /api/applications with drive_link
```

### 4.3 CI Pipeline Flow (REQ-01-10)

```
Developer pushes to PR or main
  → GitHub Actions: .github/workflows/ci.yml
    → Job: install dependencies
      → Job: build shared package
        → Job (parallel): type-check backend, web, extension
        → Job (parallel): run backend smoke tests
    → On main branch only:
      → Deploy web to Vercel (via Vercel GitHub integration)
      → Deploy backend to Render/Railway (via Docker push)
```

---

## 5. API Contracts

### 5.1 Clerk Webhook Endpoint (REQ-01-09)

**New Endpoint:** `POST /api/webhooks/clerk`

| Property | Value |
|:---|:---|
| Auth | None (webhook signature verification instead) |
| Content-Type | `application/json` |
| Headers Required | `webhook-id`, `webhook-timestamp`, `webhook-signature` |
| Body | Clerk webhook event payload |

**Request Body (relevant event):**
```json
{
  "type": "user.deleted",
  "data": {
    "id": "user_2abc...",
    "deleted": true
  }
}
```

**Responses:**
| Status | Body | Condition |
|:---|:---|:---|
| 200 | `{ "received": true }` | Event processed successfully |
| 400 | `{ "error": "Invalid signature" }` | Signature verification failed |
| 400 | `{ "error": "Missing webhook headers" }` | Required headers absent |

### 5.2 Existing Endpoints (Unchanged)
No changes to existing API contracts. The applications POST already accepts `drive_link` (optional string).

---

## 6. Security Considerations

### Webhook Endpoint Security
- **No auth guard** — webhook endpoints must be publicly accessible for Clerk to call them.
- **Signature verification** is the security mechanism. The `CLERK_WEBHOOK_SECRET` env var holds the signing secret from Clerk dashboard.
- **Idempotency**: `user.deleted` events should be idempotent — if the user doesn't exist, return 200 anyway (no error).
- **Timing attacks**: Use `standardwebhooks` which implements constant-time comparison.

### Google Drive OAuth Security
- **Scope**: `https://www.googleapis.com/auth/drive.file` — app can only access files it created.
- **Token storage**: OAuth tokens managed by Chrome identity API — extension never stores refresh tokens directly.
- **manifest.json**: Requires `identity` permission and `oauth2.client_id` in manifest.

### CI/CD Security
- **Secrets in GitHub Actions**: All API keys and secrets stored as GitHub repository secrets, never in code.
- **Docker**: No secrets baked into images — all injected via environment variables at runtime.

---

## 7. Dependencies & Integration Points

### From Previous Phases
- P0 complete: web builds for production, extension auth bridge works, message flow complete, URLs externalized.
- Backend CORS already allows configurable origins.
- `standardwebhooks@^1.0.0` already installed in backend.

### External Service Integrations

| Service | Integration Point | Configuration |
|:---|:---|:---|
| Clerk Webhooks | `POST /api/webhooks/clerk` | CLERK_WEBHOOK_SECRET env var |
| Google Drive API | Extension `fetch()` via chrome.identity | OAuth2 client_id in manifest, Google Cloud Console project |
| Supabase CLI | Migration files in `supabase/migrations/` | SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY |
| GitHub Actions | `.github/workflows/ci.yml` | Repository secrets for env vars |
| Vercel | `vercel.json` in smart-apply-web | VERCEL_TOKEN (optional for CI push) |
| Docker Registry | Dockerfile in smart-apply-backend | Optional for automated deployment |

---

## 8. Acceptance Criteria Summary

### Unit Testable
- ATS scoring returns correct values for all 5 dimensions (REQ-01-07 — already passes).
- Webhook controller returns 400 on invalid signature.
- Webhook controller returns 200 and deletes user data on valid `user.deleted` event.
- Smoke tests cover auth guard, profile CRUD, application CRUD, scoring, optimization pipeline.

### Integration Testable
- `supabase db push` applies migrations to a fresh database.
- `npm run build` succeeds for all packages (web, backend, extension).
- Docker image builds and starts successfully.
- CI workflow runs green on a sample commit.

### Manual Verification
- Google Drive upload creates correct folder structure and stores PDF.
- Account deletion via Clerk dashboard cascades to all Supabase tables.
- Vercel deployment serves the web app at a public URL.
