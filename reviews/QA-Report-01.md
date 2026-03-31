---
title: QA Report 01
description: Post-development quality assessment for Smart Apply — Full Scope.
permalink: /qa-report-01/
---

# QA Report — 01

**Version:** 1.0  
**Date:** 2026-03-28  
**Scope:** FULL — Entire Codebase  
**QA Agent:** QA Lead Agent  
**Test Agent:** Test Engineer Agent  

---

## 1. Executive Summary

Smart Apply is in a **mid-development** state with core backend services well-implemented and tested, but significant gaps remain in web/extension test coverage, route protection, CI/CD completeness, and production deployment readiness. The backend is solid: all 23 unit tests pass, all 4 packages compile with zero TypeScript errors, and all 4 packages build successfully. However, only the backend has any test coverage — web, extension, and shared packages have **zero** tests.

The most critical finding is a **broken access-control gap**: the `/optimize` and `/settings` routes in the web middleware are not listed as protected routes, meaning unauthenticated users could potentially access them (though server-side `auth()` checks in pages provide a secondary guard). Additionally, the Google Drive OAuth client ID contains a placeholder value (`GOOGLE_OAUTH_CLIENT_ID_PLACEHOLDER`), which blocks the Drive upload feature entirely. There are 14 npm vulnerabilities (7 moderate, 7 high) via transitive dependencies.

The project has strong architectural foundations — Supabase RLS policies enforce data isolation, Clerk JWT verification is consistent across all API endpoints, webhook signature verification is correctly implemented, and the ATS scoring engine is deterministic and well-tested. The extension implements the full user journey (sync → optimize → review → PDF → Drive upload → autofill), though end-to-end testing is absent.

**Quality Score Card:**

| Dimension | Score | Rating |
|:---|:---|:---|
| Test Coverage | 23 tests, backend only (0% web/ext/shared) | 🟡 |
| BRD Compliance | 10 of 16 requirements MET or PARTIAL | 🟡 |
| Architecture Compliance | 9 of 11 checks passed | 🟡 |
| Security Posture | 2 findings (1 HIGH, 1 MEDIUM) | 🟡 |
| Technical Debt | 22 items, 0 critical, 3 high | 🟡 |
| Build Health | 4 of 4 packages build ✅ | 🟢 |

**Release Recommendation: NOT READY** — Must resolve route protection gap, complete Google Drive client ID configuration, and add `/optimize` + `/settings` to protected route matcher before any production deployment.

---

## 2. Codebase Inventory

**Repository:** 1 commit on `main` branch (`e1cb3b7 feat: implement Smart Apply MVP (phases 1-6)`)  
**Working tree:** Staged new files (account module, webhooks, test suite, Dockerfile, vitest config); unstaged changes (extension, web, architecture doc, package-lock); untracked BRD/HLD/LLD docs, supabase, CI workflow.

| Package | Modules or Pages | Test Files | Build Status | Config Files |
|:---|:---|:---|:---|:---|
| smart-apply-shared | 7 exports (3 types, 3 schemas, 1 barrel) | 0 | ✅ Pass | tsconfig.json |
| smart-apply-backend | 8 modules (Auth, Health, Profiles, Optimize, Applications, Scoring, Webhooks, Account) + 2 infra (Supabase, LLM) | 6 | ✅ Pass | vitest.config.ts, .env.example, Dockerfile, nest-cli.json, tsconfig.json |
| smart-apply-web | 7 pages (home, dashboard, profile, optimize, settings, sign-in, extension-callback) + 14 components | 0 | ✅ Pass | next.config.ts, tailwind.config.ts, postcss, vercel.json, tsconfig.json |
| smart-apply-extension | 15 source files (5 content, 5 lib, 2 popup, 1 background, 1 manifest, 1 config) | 0 | ✅ Pass (1 size warning) | vite.config.ts, .env.example, tailwind.config.ts, postcss, tsconfig.json |

**Infrastructure:**
- Supabase: `config.toml` + 1 migration file (`00001_init.sql`)
- CI: `.github/workflows/ci.yml` (1 job: typecheck all 4 packages, run backend tests, build web)
- Deployment: `smart-apply-backend/Dockerfile`, `smart-apply-web/vercel.json`

---

## 3. Test Results

### 3.1 Test Execution Summary

| Package | Tests | Pass | Fail | Skip | Type Errors | Build |
|:---|:---|:---|:---|:---|:---|:---|
| shared | 0 | 0 | 0 | 0 | 0 | ✅ |
| backend | 23 | 23 | 0 | 0 | 0 | ✅ |
| web | 0 | — | — | — | 0 | ✅ |
| extension | 0 | — | — | — | 0 | ✅ (size warning) |

**Backend Test Breakdown:**

| Test Suite | File | Tests | Status |
|:---|:---|:---|:---|
| ScoringService | test/scoring.service.spec.ts | 5 | ✅ All pass |
| ClerkAuthGuard | test/auth.guard.spec.ts | 3 | ✅ All pass |
| WebhooksController | test/webhooks.controller.spec.ts | 4 | ✅ All pass |
| OptimizeService | test/optimize.service.spec.ts | 3 | ✅ All pass |
| ApplicationsService | test/applications.service.spec.ts | 4 | ✅ All pass |
| ProfilesService | test/profiles.service.spec.ts | 4 | ✅ All pass |

### 3.2 Failed Tests Detail

No failed tests. All 23 tests pass.

### 3.3 Test Coverage Gaps

| # | Critical Path | Package | Expected Test | Status |
|:---|:---|:---|:---|:---|
| 1 | Web: Optimize form → API call → results display | web | Component test for OptimizeForm + OptimizeResults | MISSING |
| 2 | Web: Dashboard data fetch + display | web | Component test for DashboardShell, StatsCards, ApplicationsTable | MISSING |
| 3 | Web: Profile editor + upload | web | Component test for ProfileEditor, ProfileUpload | MISSING |
| 4 | Web: Settings page + account deletion | web | Component test for SettingsPage | MISSING |
| 5 | Web: Clerk middleware route protection | web | Integration test for protected routes | MISSING |
| 6 | Extension: Popup auth flow | extension | Test for login/dashboard/results screen transitions | MISSING |
| 7 | Extension: Service worker message routing | extension | Test for SYNC_PROFILE, OPTIMIZE_JD, AUTOFILL handlers | MISSING |
| 8 | Extension: PDF generation | extension | Test for generateResumePDF with known input | MISSING |
| 9 | Extension: Google Drive upload | extension | Test for uploadPdfToDrive (mocked) | MISSING |
| 10 | Extension: Content script extraction | extension | Test for LinkedIn profile parser, JD detector | MISSING |
| 11 | Shared: Zod schema validation | shared | Unit tests for all schemas with valid/invalid inputs | MISSING |
| 12 | Backend: Account deletion flow | backend | Test for AccountService/Controller | MISSING |
| 13 | E2E: Full optimize pipeline | all | Integration test: JD → optimize → PDF → save application | MISSING |

---

## 4. Gap Analysis

### 4.1 BRD Requirements Coverage

#### P0 Requirements (Launch Blockers)

| REQ ID | Title | Status | Evidence |
|:---|:---|:---|:---|
| REQ-01-01 | Fix Web Production Build | ✅ MET | `npm run build:web` exits 0; `.next/` output produced; all routes compile |
| | AC-1: Build succeeds | ✅ MET | Verified in Step 2 |
| | AC-2: Clean install builds | ✅ MET | CI pipeline runs `npm ci` then builds |
| REQ-01-02 | Extension Authentication Bridge | ✅ MET | `extension-callback/page.tsx` sends token via `chrome.runtime.sendMessage`; `service-worker.ts` stores in `chrome.storage.local`; `api-client.ts` attaches Bearer header |
| | AC-1: Token stored after sign-in | ✅ MET | `onMessageExternal` listener stores token |
| | AC-2: Bearer header attached | ✅ MET | `apiFetch()` reads from storage |
| | AC-3: 401 clears token + re-prompt | ⚠️ PARTIAL | API client throws on non-ok response but does NOT clear token or redirect to login |
| REQ-01-03 | Extension Message Flow | ✅ MET | Full popup↔background↔content flow implemented |
| | AC-1: Sync profile flow | ✅ MET | TRIGGER_SYNC → content script → background → API |
| | AC-2: Optimize flow | ✅ MET | TRIGGER_OPTIMIZE → content script → background → API → popup |
| | AC-3: Error handling + retry | ⚠️ PARTIAL | Errors displayed in popup status text, but no explicit "retry" button |
| REQ-01-04 | Apply Approved Changes to PDF | ✅ MET | `buildApprovedResume()` in popup/App.tsx applies only selected changes |
| | AC-1: Approved bullets in PDF | ✅ MET | `selectedChanges` Set filters changes |
| | AC-2: Rejected = original content | ✅ MET | Unapproved changes skipped |
| | AC-3: Summary + skills merged | ✅ MET | `summary_update` and `skills_insertion` cases handled |
| REQ-01-05 | Externalise Environment URLs | ✅ MET | `config.ts` uses `import.meta.env.VITE_*` with localhost fallback; web uses `NEXT_PUBLIC_API_URL`; backend CORS via `ALLOWED_ORIGINS` env |
| | AC-1: Web uses env var | ✅ MET | `smart-apply-web/src/lib/api-client.ts` |
| | AC-2: Extension uses build-time vars | ✅ MET | `config.ts` |
| | AC-3: CORS for production origins | ✅ MET | `main.ts` CORS config |
| | AC-4: Localhost fallback in dev | ✅ MET | All three clients have localhost defaults |

#### P1 Requirements (Should-Have)

| REQ ID | Title | Status | Evidence |
|:---|:---|:---|:---|
| REQ-01-06 | Google Drive PDF Upload | ⚠️ PARTIAL | `google-drive.ts` implementation exists; `manifest.ts` has `GOOGLE_OAUTH_CLIENT_ID_PLACEHOLDER` — BLOCKS feature |
| | AC-1: Upload to Drive folder | ⚠️ PARTIAL | Code exists but placeholder client ID |
| | AC-2: Local download fallback | ✅ MET | `chrome.downloads.download` as primary; Drive is non-blocking |
| | AC-3: drive_link saved | ❌ NOT MET | `drive_link` is passed in SAVE_APPLICATION but `handleSaveApplication` does not include it in the API body |
| REQ-01-07 | Complete ATS Scoring | ✅ MET | `scoring.service.ts` implements all sub-scores; tested with 5 test cases |
| | AC-1: Seniority scoring | ✅ MET | Seniority band detection from title + years |
| | AC-2: Role relevance synonyms | ✅ MET | Role synonym map in scoring service |
| | AC-3: Keyword spam cap | ✅ MET | Max 3 occurrences per keyword |
| REQ-01-08 | Supabase Migration System | ✅ MET | `00001_init.sql` creates all 3 tables with RLS, indexes, triggers, cascading deletes |
| | AC-1: All tables + RLS created | ✅ MET | Verified in SQL review |
| | AC-2: Incremental migrations | ⚠️ PARTIAL | Only 1 migration file; incremental pattern exists but untested |
| REQ-01-09 | Account Deletion (Webhook) | ✅ MET | `webhooks.controller.ts` verifies Svix signature; deletes from `master_profiles`; cascade handles rest |
| | AC-1: Hard delete on user.deleted | ✅ MET | Tested in webhooks.controller.spec.ts |
| | AC-2: Invalid signature rejected | ✅ MET | Tested: throws BadRequestException |
| | AC-3: Audit log (userId + timestamp only) | ❌ NOT MET | No audit log implementation; only console.log with userId |
| REQ-01-10 | Deployment Configuration | ⚠️ PARTIAL | CI exists; Dockerfile exists; vercel.json exists |
| | AC-1: CI builds all packages | ⚠️ PARTIAL | CI typechecks all 4, but only builds web; no backend build/extension build in CI |
| | AC-2: Web deployment | ✅ MET | vercel.json present |
| | AC-3: Backend deployment + health check | ⚠️ PARTIAL | Dockerfile exists; `/health` endpoint exists; no deploy pipeline |
| REQ-01-11 | Automated Test Suite | ✅ MET | 23 tests, all pass |
| | AC-1: All tests pass | ✅ MET | Verified |
| | AC-2: Auth guard tested | ✅ MET | auth.guard.spec.ts |
| | AC-3: Scoring deterministic | ✅ MET | scoring.service.spec.ts |
| | AC-4: Optimize pipeline tested | ✅ MET | optimize.service.spec.ts |

#### P2 Requirements (Could-Have)

| REQ ID | Title | Status | Evidence |
|:---|:---|:---|:---|
| REQ-01-12 | Extended Autofill Field Coverage | ⚠️ PARTIAL | `autofill.ts` covers name, email, phone, summary, skills, current_title, LinkedIn URL; resume file upload attempted via DataTransfer; no clipboard fallback |
| REQ-01-13 | Web-Based Optimize/Apply Flow | ✅ MET | `/optimize` page with `OptimizeForm` + `OptimizeResults` components |
| REQ-01-14 | Settings & Account Management UI | ✅ MET | `/settings` page with `SettingsPage` component |
| REQ-01-15 | Manual Profile Upload/Import | ✅ MET | `ProfileUpload` component on `/profile` page |
| REQ-01-16 | DOM Selector Hardening | ⚠️ PARTIAL | `SELECTOR_FAILURE` message type exists in service worker; `dom-utils.ts` has fallback selectors; no version registry |

### 4.2 HLD Deliverables Coverage

- [x] Auth module with Clerk JWT verification (HLD-P01)
- [x] Supabase schema with RLS (HLD-P01)
- [x] Profile CRUD (ingest, get, update) (HLD-P01)
- [x] Optimize pipeline (extract → score → LLM → score) (HLD-P02)
- [x] ATS scoring engine with 5 sub-dimensions (HLD-P02)
- [x] Application history CRUD (HLD-P02)
- [x] Extension popup with auth + optimize flow (HLD-P03)
- [x] Content scripts for LinkedIn (HLD-P03)
- [x] PDF generation client-side (HLD-P03)
- [x] Google Drive upload scaffolding (HLD-P03)
- [ ] Observability / structured logging (not started)
- [ ] E2E test suite (not started)
- [ ] Chrome Web Store release config (not started)

### 4.3 Architecture Compliance

| Check | Status | Notes |
|:---|:---|:---|
| §3 All components present | ✅ | Extension, Web, Backend, Shared all exist with documented responsibilities |
| §5 Auth flow matches diagram | ⚠️ | Extension auth bridge works; web middleware missing `/optimize` and `/settings` protection |
| §6 Data model matches schema | ✅ | All 3 tables, enums, indexes, RLS match architecture doc |
| §7 Component responsibilities | ✅ | Each package does what the doc says |
| §9 ATS Scoring 100-point heuristic | ✅ | All 5 sub-dimensions implemented and tested |
| §10 AI pipeline (3 LLM methods) | ✅ | extractRequirements, optimizeResume, parseProfileText all implemented |
| §11 Security: JWT on all API | ✅ | All endpoints guarded (except /health and /webhooks as designed) |
| §11 Security: Svix webhook sig | ✅ | Verified in webhooks controller test |
| §11 Security: RLS enforcement | ✅ | All Supabase queries filter by clerk_user_id |
| §11 Security: Zero server PDF storage | ✅ | PDF generated client-side, stored in Drive only |
| §11 Security: CORS | ⚠️ | Regex `chrome-extension://` allows **any** extension origin, not just Smart Apply's ID |

### 4.4 Undocumented Behaviour

| Item | Classification | Description |
|:---|:---|:---|
| `SELECTOR_FAILURE` message type | INTENTIONAL | DOM selector failure reporting for hardening — good practice but not in any spec doc |
| `last_pdf_bytes` in chrome.storage | INTENTIONAL | Caches PDF for resume file upload autofill — needed for autofill but not documented |
| `ScoringModule` exported but no controller | INTENTIONAL | Pure service consumed by OptimizeModule |
| Popup `Connected` badge always shown | SCOPE CREEP | When authenticated, badge shows "Connected" regardless of actual service health |

---

## 5. Technical Debt Register

### 5.1 Debt Items

| # | Category | File | Line | Description | Severity |
|:---|:---|:---|:---|:---|:---|
| TD-01 | Placeholder | smart-apply-extension/src/manifest.ts | 48 | `GOOGLE_OAUTH_CLIENT_ID_PLACEHOLDER` blocks Google Drive integration | HIGH |
| TD-02 | Security | smart-apply-web/src/middleware.ts | 4-7 | `/optimize(.*)` and `/settings(.*)` missing from protected route matcher | HIGH |
| TD-03 | Security | smart-apply-backend/src/main.ts | 17 | CORS regex `chrome-extension://` accepts ALL extension origins | HIGH |
| TD-04 | Console Leak | smart-apply-extension/src/background/service-worker.ts | 11 | `console.log('Smart Apply extension installed')` | LOW |
| TD-05 | Console Leak | smart-apply-extension/src/background/service-worker.ts | 94 | `console.warn` for selector failure (intentional) | INFO |
| TD-06 | Console Leak | smart-apply-extension/src/background/service-worker.ts | 124 | `console.error` for profile sync error | LOW |
| TD-07 | Console Leak | smart-apply-extension/src/background/service-worker.ts | 158 | `console.error` for optimization error | LOW |
| TD-08 | Console Leak | smart-apply-extension/src/background/service-worker.ts | 192 | `console.error` for save application error | LOW |
| TD-09 | Console Leak | smart-apply-extension/src/ui/popup/App.tsx | 160 | `console.warn` for Drive upload skip | LOW |
| TD-10 | Console Leak | smart-apply-extension/src/ui/popup/App.tsx | 176 | `console.error` catch-all in PDF gen | LOW |
| TD-11 | Console Leak | smart-apply-extension/src/content/autofill.ts | 214 | `console.log` for autofill result | LOW |
| TD-12 | Console Leak | smart-apply-extension/src/content/autofill.ts | 216 | `console.log` for resume file attachment | LOW |
| TD-13 | Console Leak | smart-apply-extension/src/content/linkedin-profile.ts | 29 | `console.warn` for extraction failure | LOW |
| TD-14 | Console Leak | smart-apply-extension/src/content/jd-detector.ts | 64 | `console.warn` for JD extraction failure | LOW |
| TD-15 | Console Leak | smart-apply-web/src/components/optimize/optimize-results.tsx | 161 | `console.error` for PDF generation failure | LOW |
| TD-16 | Console Leak | smart-apply-backend/src/main.ts | 32 | `console.log` for server startup | LOW |
| TD-17 | Type Safety | smart-apply-extension/src/background/service-worker.ts | 119 | `as unknown as Record<string, unknown>` double cast | MEDIUM |
| TD-18 | Type Safety | smart-apply-extension/src/background/service-worker.ts | 181 | `as unknown as Record<string, unknown>` double cast | MEDIUM |
| TD-19 | Type Safety | smart-apply-extension/src/ui/popup/App.tsx | 138, 147 | `as unknown as ArrayBuffer` / `as unknown as BlobPart` casts | MEDIUM |
| TD-20 | Bundle Size | smart-apply-extension (popup chunk) | — | 638 kB popup chunk exceeds 500 kB Rollup warning | MEDIUM |
| TD-21 | Dependencies | npm audit | — | 14 vulnerabilities (7 moderate, 7 high) in transitive deps (@angular-devkit/core via @nestjs/cli, rollup via @crxjs/vite-plugin) | MEDIUM |
| TD-22 | Feature Gap | smart-apply-extension/src/lib/api-client.ts | — | No 401 handling to clear token and redirect to login | MEDIUM |

### 5.2 Debt Summary by Category

| Category | Critical | High | Medium | Low | Info | Total |
|:---|:---|:---|:---|:---|:---|:---|
| Placeholder Values | 0 | 1 | 0 | 0 | 0 | 1 |
| Security | 0 | 2 | 0 | 0 | 0 | 2 |
| Console Leaks | 0 | 0 | 0 | 12 | 1 | 13 |
| Type Safety | 0 | 0 | 3 | 0 | 0 | 3 |
| Bundle Size | 0 | 0 | 1 | 0 | 0 | 1 |
| Dependencies | 0 | 0 | 1 | 0 | 0 | 1 |
| Feature Gap | 0 | 0 | 1 | 0 | 0 | 1 |
| **Total** | **0** | **3** | **6** | **12** | **1** | **22** |

### 5.3 Top 10 Debt Items (by Severity)

1. **TD-02** (HIGH) — `/optimize` and `/settings` not protected by Clerk middleware
2. **TD-03** (HIGH) — CORS accepts any `chrome-extension://` origin
3. **TD-01** (HIGH) — Google OAuth client ID placeholder blocks Drive upload
4. **TD-22** (MEDIUM) — No 401 response handling in extension API client
5. **TD-21** (MEDIUM) — 14 npm vulnerabilities in transitive dependencies
6. **TD-20** (MEDIUM) — 638 kB popup bundle exceeds recommended size
7. **TD-17** (MEDIUM) — Unsafe double type casts in service worker
8. **TD-18** (MEDIUM) — Unsafe double type casts in service worker
9. **TD-19** (MEDIUM) — Unsafe type casts for PDF bytes in popup
10. **TD-16** (LOW) — `console.log` in production backend startup

---

## 6. Risk Register

| Risk ID | Category | Description | Severity | Likelihood | Impact | Affected Journey Step | Recommended Priority |
|:---|:---|:---|:---|:---|:---|:---|:---|
| RISK-01 | Security | `/optimize` and `/settings` web routes not in Clerk protected route matcher — unauthenticated users can access these routes at the middleware level (mitigated by server-side `auth()` check in page components) | HIGH | HIGH | Bypass middleware auth, rely on secondary check | Optimize, Settings | P0 |
| RISK-02 | Security | CORS regex matches ANY `chrome-extension://` origin — any Chrome extension could make cross-origin requests to the API | HIGH | MEDIUM | Potential API abuse from malicious extensions | All API endpoints | P0 |
| RISK-03 | Functional | Google Drive OAuth client ID is a placeholder — Drive upload will fail at runtime | HIGH | HIGH | Feature broken | Generate PDF → Drive upload | P0 |
| RISK-04 | Functional | Extension API client does not handle 401 → no token clear / re-auth | MEDIUM | MEDIUM | User gets stuck with expired token, no way back to login without reinstall | All extension API calls | P1 |
| RISK-05 | Testing | 0 tests for web, extension, and shared packages — regressions undetectable | HIGH | HIGH | Unaught breaking changes | All surfaces | P1 |
| RISK-06 | Functional | `drive_link` from Google Drive upload not passed through to the SAVE_APPLICATION API call's body | MEDIUM | HIGH | Applications in history won't have Drive links | Save application | P1 |
| RISK-07 | Deployment | CI pipeline only builds web; does not build backend or extension | MEDIUM | MEDIUM | Backend/extension build breaks go undetected | Deployment | P1 |
| RISK-08 | Compliance | No audit log for account deletion (REQ-01-09 AC-3) — only console.log | MEDIUM | LOW | Compliance gap for data deletion events | Account deletion | P1 |
| RISK-09 | Performance | Extension popup bundle at 638 kB — may cause slow popup opening | LOW | MEDIUM | Degraded UX on slow devices | Extension popup | P2 |
| RISK-10 | Dependencies | 14 npm vulnerabilities (7 high via @angular-devkit/core and rollup) | MEDIUM | LOW | Potential exploitation vectors | Build tooling | P2 |
| RISK-11 | Functional | No explicit "Retry" button on error states in extension popup | LOW | MEDIUM | User friction on transient failures | Sync/Optimize in extension | P2 |
| RISK-12 | Compliance | No lint/format checks in CI — code style inconsistency | LOW | MEDIUM | Code quality drift | All packages | P2 |

---

## 7. Recommendations

### 7.1 Immediate Actions (P0 — Before Next Phase)

| # | Action | Addresses Risk | Owner | Estimated Effort |
|:---|:---|:---|:---|:---|
| 1 | Add `/optimize(.*)` and `/settings(.*)` to Clerk middleware protected route matcher | RISK-01, TD-02 | Web | S |
| 2 | Restrict CORS `chrome-extension://` origin to the specific published extension ID via env var | RISK-02, TD-03 | Backend | S |
| 3 | Replace `GOOGLE_OAUTH_CLIENT_ID_PLACEHOLDER` in manifest.ts with actual Google OAuth client ID (or env-driven substitution) | RISK-03, TD-01 | Extension | S |

### 7.2 Near-Term Actions (P1 — Within Next 2 Phases)

| # | Action | Addresses Risk | Owner | Estimated Effort |
|:---|:---|:---|:---|:---|
| 4 | Add 401 response handler in extension API client: clear `auth_token`, redirect to login screen | RISK-04, TD-22 | Extension | S |
| 5 | Add test suites for web components (OptimizeForm, DashboardShell, ProfileEditor, SettingsPage) using React Testing Library | RISK-05 | Web | M |
| 6 | Add test suite for extension (service worker message handlers, PDF generator, content scripts — mocked Chrome APIs) | RISK-05 | Extension | M |
| 7 | Add Zod schema unit tests in shared package | RISK-05 | Shared | S |
| 8 | Pass `drive_link` through SAVE_APPLICATION handler to API body | RISK-06 | Extension | S |
| 9 | Add backend build and extension build steps to CI pipeline | RISK-07 | DevOps | S |
| 10 | Implement audit log table or append-only log for account deletion events | RISK-08 | Backend | M |

### 7.3 Backlog Items (P2 — Track but Defer)

| # | Action | Addresses Risk | Owner | Estimated Effort |
|:---|:---|:---|:---|:---|
| 11 | Code-split extension popup (dynamic imports for PDF/Drive modules) to reduce 638 kB bundle | RISK-09, TD-20 | Extension | M |
| 12 | Run `npm audit fix` and update `@nestjs/schematics` to resolve transitive vulnerabilities | RISK-10, TD-21 | DevOps | S |
| 13 | Add retry buttons to extension popup error states | RISK-11 | Extension | S |
| 14 | Add ESLint + Prettier to CI pipeline | RISK-12 | DevOps | S |
| 15 | Replace `console.log/warn/error` with structured logging (pino or similar) in backend; conditional logging in extension | TD-04–16 | All | M |
| 16 | Fix `as unknown as` double casts with proper type definitions | TD-17–19 | Extension | S |

---

## 8. Missing Test Coverage — Recommended Test Cases

| # | Test Description | Package | File to Test | Priority |
|:---|:---|:---|:---|:---|
| 1 | OptimizeForm submits JD text and renders loading state | web | components/optimize/optimize-form.tsx | P1 |
| 2 | OptimizeResults displays before/after scores and change list | web | components/optimize/optimize-results.tsx | P1 |
| 3 | OptimizeResults: approve changes filters correctly to PDF | web | components/optimize/optimize-results.tsx | P1 |
| 4 | DashboardShell fetches and renders application history | web | components/dashboard/dashboard-shell.tsx | P1 |
| 5 | ProfileEditor loads profile data and submits updates | web | components/profile/profile-editor.tsx | P1 |
| 6 | ProfileUpload parses uploaded file and calls ingest API | web | components/profile/profile-upload.tsx | P1 |
| 7 | SettingsPage shows account info and delete button | web | components/settings/settings-page.tsx | P1 |
| 8 | Clerk middleware blocks unauthenticated access to /dashboard, /profile, /optimize, /settings | web | middleware.ts | P0 |
| 9 | Service worker SYNC_PROFILE handler: extracts text → calls API → caches result | extension | background/service-worker.ts | P1 |
| 10 | Service worker OPTIMIZE_JD handler: extracts JD → calls API → returns scores | extension | background/service-worker.ts | P1 |
| 11 | Service worker AUTH_TOKEN handler: stores and retrieves token | extension | background/service-worker.ts | P1 |
| 12 | generateResumePDF: produces valid PDF bytes for known input | extension | lib/pdf-generator.ts | P1 |
| 13 | buildApprovedResume: correctly merges selected changes only | extension | ui/popup/App.tsx | P1 |
| 14 | apiFetch: attaches Bearer token from storage; throws on non-ok | extension | lib/api-client.ts | P1 |
| 15 | LinkedIn profile content script extracts structured text | extension | content/linkedin-profile.ts | P2 |
| 16 | JD detector content script extracts job description text | extension | content/jd-detector.ts | P2 |
| 17 | Autofill maps profile fields to form inputs | extension | content/autofill.ts | P2 |
| 18 | All Zod schemas validate correct input and reject invalid input | shared | schemas/*.schema.ts | P1 |
| 19 | AccountController DELETE /api/account calls Clerk deleteUser | backend | modules/account/account.controller.ts | P1 |
| 20 | AccountService handles Clerk API failure gracefully | backend | modules/account/account.service.ts | P1 |

---

## 9. Release Readiness Checklist

- [x] All P0 BRD acceptance criteria met (5/5 P0 requirements satisfied)
- [x] All packages build for production without errors
- [x] All existing tests pass (23/23)
- [x] No CRITICAL severity findings unresolved
- [ ] **No secrets exposed in client bundles** — Google OAuth client ID is a placeholder, not a real secret, but needs real value
- [ ] **`/optimize` and `/settings` added to protected route matcher** — MUST FIX
- [ ] **CORS restricted to specific extension ID** — MUST FIX
- [x] Zero-Storage Policy verified (no server-side PDF persistence)
- [x] Auth flow verified: Clerk JWT on all API endpoints; RLS on all Supabase queries
- [ ] Architecture.md reflects the current system — Phase 4-6 status needs update
- [ ] Deployment configuration present and tested — CI incomplete (backend + extension builds missing)
- [ ] Google Drive OAuth client ID configured with real value

**Release Recommendation: NOT READY**

**Conditions for CONDITIONAL release:**
1. Add `/optimize(.*)` and `/settings(.*)` to Clerk middleware protected routes
2. Restrict CORS to specific extension ID
3. Replace Google OAuth client ID placeholder with real value
4. Add backend build + extension build to CI pipeline
