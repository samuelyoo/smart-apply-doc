# HLD-MVP-P01 — P0 Critical Fixes (BRD-MVP-01)

**Phase:** P0 Launch Blockers
**Version:** 1.0
**Date:** 2026-03-28
**Source:** BRD-MVP-01.md (REQ-01-01 through REQ-01-05)

---

## 1. Phase Objective

### Business Goal
Resolve the five production blockers that prevent shipping the Smart Apply MVP. After this phase, all three surfaces (web, backend, extension) can build for production, communicate via configurable URLs, and the core user journey works end-to-end: sign in → optimize → approve changes → generate PDF.

### User-Facing Outcome
- Job seekers can access Smart Apply via a deployed web portal (not localhost).
- The Chrome extension connects to a production backend.
- Approved keyword optimizations actually appear in the generated resume PDF.
- Extension sign-in completes a full auth round-trip.

---

## 2. Component Scope

### In Scope
| Repo | Changes |
|---|---|
| **smart-apply-backend** | Externalize CORS origins via env vars |
| **smart-apply-web** | Verify production build; add auth callback page for extension token handoff |
| **smart-apply-extension** | Externalize API/web URLs via Vite env vars; complete auth bridge (token receipt from web); fix popup↔content↔background message flow; apply selected changes to PDF generation |
| **smart-apply-shared** | No changes |

### Out of Scope
- Google Drive upload (P1 REQ-01-06)
- Full ATS scoring (P1 REQ-01-07)
- Supabase migrations (P1 REQ-01-08)
- Account deletion webhook (P1 REQ-01-09)
- CI/CD deployment configuration (P1 REQ-01-10)
- Automated test suite (P1 REQ-01-11)
- P2 items (REQ-01-12 through REQ-01-16)

---

## 3. Architecture Decisions

### AD-01: Environment Variable Strategy for Extension
Chrome extensions cannot read env vars at runtime. All configuration must be injected at **build time** via Vite's `import.meta.env.VITE_*` mechanism.

- `VITE_API_BASE_URL` — Backend API URL (default: `http://localhost:3001`)
- `VITE_WEB_BASE_URL` — Web portal URL (default: `http://localhost:3000`)

**Justification:** architecture.md §2 — each repo is independently buildable; extension configuration must be baked into the build artifact.

### AD-02: Extension Auth Bridge via Web Callback Page
The extension auth flow uses a dedicated `/auth/extension-callback` page on the web portal:

1. Extension popup opens `{WEB_BASE_URL}/auth/extension-callback`
2. Page uses Clerk's `useAuth()` to obtain the session token
3. Page sends the token back to the extension via `chrome.runtime.sendMessage()` using the extension ID
4. Extension stores the token in `chrome.storage.local`

**Justification:** architecture.md §5 — extension stores token in `chrome.storage.local`; web portal uses Clerk's built-in Next.js auth. This bridges the two without exposing secrets in the extension.

### AD-03: Selected Changes Applied Client-Side Before PDF
The extension popup tracks which changes the user approved (`selectedChanges` Set). Before PDF generation, the popup merges only approved changes into a copy of the cached profile:

- Summary: use optimized if the summary change is selected, else keep original.
- Skills: merge new skills only if the skills change is selected.
- Experience bullets: replace individual bullets only for selected edits.

**Justification:** architecture.md §1 Core Principles — "Client-first processing" and "Explicit user approval". No server round-trip needed.

### AD-04: Backend CORS via Environment Variable
Replace hardcoded CORS origins with `ALLOWED_ORIGINS` environment variable (comma-separated list). Falls back to `http://localhost:3000,chrome-extension://*` in development.

**Justification:** architecture.md §8 — production deployment requires configurable origins.

---

## 4. Data Flow

### 4.1 Extension Auth Bridge Flow

```
User clicks "Sign In" in extension popup
→ Extension opens {WEB_BASE_URL}/auth/extension-callback?extensionId={ID}
→ Web page checks Clerk session (redirects to /sign-in if needed)
→ After auth, page calls getToken() from Clerk
→ Page sends token via chrome.runtime.sendMessage(extensionId, {type: 'AUTH_TOKEN', token})
→ Extension background listener stores token in chrome.storage.local
→ Popup detects token → shows dashboard screen
```

### 4.2 Optimized Resume PDF Generation (with approved changes)

```
User on results screen with checkboxes
→ User clicks "Approve & Generate PDF"
→ Popup reads cached_profile from storage
→ Popup iterates suggested_changes:
   For each selected change:
     - summary_update → replace profile.summary
     - skills_insertion → add to profile.base_skills
     - bullet_injection → find matching experience bullet, replace
→ Merged profile passed to generateResumePDF()
→ PDF downloaded
```

### 4.3 Extension Message Flow (Sync & Optimize)

```
Popup "Optimize" button clicked
→ Popup sends {type: TRIGGER_OPTIMIZE} to content script (active tab)
→ Content script (jd-detector) extracts JD text from page DOM
→ Content script sends {type: OPTIMIZE_JD, payload: {jd_text, company, job_title}} to background
→ Background calls POST /api/optimize with auth token
→ Background receives response
→ Background sends {type: OPTIMIZE_RESULT, data: response} to popup
→ Popup renders results screen
```

---

## 5. API Contracts

### No new API endpoints required.

Existing endpoints are sufficient:
- `POST /api/optimize` — already implemented
- `POST /api/profile/ingest` — already implemented
- `POST /api/applications` — already implemented

### Backend Change: CORS Configuration

```
# Environment variable
ALLOWED_ORIGINS=https://smart-apply.example.com,chrome-extension://abcdefg123
```

---

## 6. Security Considerations

| Concern | Mitigation |
|---|---|
| Extension ID spoofing in auth callback | Validate extensionId format (32 alphanumeric chars); callback page only sends token to requestor via chrome.runtime.sendMessage which requires extension context |
| Token exposure in URL | Token is NOT passed via URL params. It's sent via chrome.runtime.sendMessage after page load |
| CORS misconfiguration | Strictly list allowed origins; no wildcards in production (except chrome-extension protocol) |
| XSS in diff UI | Already using React's default escaping; no `dangerouslySetInnerHTML` in the results view |
| JD injection into LLM | Already handled by backend's Zod validation and field stripping (Task 3.4) |

---

## 7. Dependencies & Integration Points

| Dependency | Status |
|---|---|
| Clerk auth (backend guard) | ✅ Complete |
| Clerk auth (web middleware) | ✅ Complete |
| Supabase profile CRUD | ✅ Complete |
| LLM optimization pipeline | ✅ Complete |
| ATS scoring engine | ✅ Complete (partial — role/seniority are P1) |
| Chrome Extension popup UI | ✅ Complete (needs wiring fixes) |
| Content scripts | ✅ Complete (need message listeners) |

No external service integrations are added in this phase.

---

## 8. Acceptance Criteria Summary

### REQ-01-01: Web Production Build
- [ ] `cd smart-apply-web && npm run build` succeeds with exit code 0

### REQ-01-02: Extension Auth Bridge
- [ ] User clicks "Sign In" in popup → web auth page opens
- [ ] After Clerk sign-in, token is stored in chrome.storage.local
- [ ] Subsequent API calls include the Bearer token
- [ ] On 401, user is prompted to re-login

### REQ-01-03: Extension Message Flow
- [ ] Popup "Sync Profile" → content script extracts → background calls API → popup shows result
- [ ] Popup "Optimize" → content script extracts JD → background calls API → popup shows results

### REQ-01-04: Apply Approved Changes
- [ ] Only user-selected changes are merged into the resume JSON before PDF generation
- [ ] Rejected changes show original text in the PDF
- [ ] Experience bullets are individually selectable

### REQ-01-05: Externalize URLs
- [ ] Backend CORS origins configurable via `ALLOWED_ORIGINS` env var
- [ ] Extension API URL configurable via `VITE_API_BASE_URL`
- [ ] Extension web URL configurable via `VITE_WEB_BASE_URL`
- [ ] All packages include `.env.example` with documented variables
