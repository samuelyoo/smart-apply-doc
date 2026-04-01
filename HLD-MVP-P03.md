# HLD-MVP-P03 — P2 Could-Have Enhancements

**Version:** 1.0  
**Date:** 2026-03-28  
**Phase:** P2 (Could-Have)  
**Source:** BRD-MVP-01.md §4.3 (REQ-01-12 through REQ-01-16)  
**Prerequisite:** All P0 (HLD/LLD-MVP-P01) and P1 (HLD/LLD-MVP-P02) complete and verified.

---

## 1. Phase Objective

### Business Goal
Expand Smart Apply from a core-loop MVP into a more capable, resilient, and self-service product. This phase extends autofill to cover the full LinkedIn Easy Apply flow, enables web-only users to optimise without the extension, adds settings/account management UI, allows manual profile upload via the web portal, and hardens DOM selectors against LinkedIn/Indeed page changes.

### User-Facing Outcome After This Phase
- LinkedIn Easy Apply modal steps are auto-filled including summary, skills, work experience, education, and resume file upload.
- Unsupported form fields surface a clipboard copy button.
- Users without the extension can paste a JD into the web portal and run the full optimise flow.
- A settings page shows connected integrations and allows account deletion.
- Users can upload a resume PDF or paste text via the web portal to create/update their profile.
- Content script selectors are centralised, versioned, and report failures with structured telemetry.

---

## 2. Component Scope

### Repos Affected

| Repo | Changes |
|:---|:---|
| `smart-apply-extension` | Extended autofill (REQ-01-12), selector hardening (REQ-01-16) |
| `smart-apply-web` | Web optimize flow (REQ-01-13), settings page (REQ-01-14), profile upload UI (REQ-01-15) |
| `smart-apply-backend` | Web optimize endpoint adaptation (REQ-01-13), no new endpoints needed for REQ-01-14/15 |
| `smart-apply-shared` | New schemas for web optimize request, profile upload source types |
| `smart-apply-doc` | This HLD + LLD |

### REQ Mapping

| REQ | Title | Status at Start | In Scope |
|:---|:---|:---|:---|
| REQ-01-12 | Extended Autofill Field Coverage | ⚠️ Partial (4 fields) | ✅ Yes |
| REQ-01-13 | Web-Based Optimise/Apply Flow | ⚠️ Partial (extension-only) | ✅ Yes |
| REQ-01-14 | Settings & Account Management UI | ❌ Missing | ✅ Yes |
| REQ-01-15 | Manual Profile Upload / Import | ⚠️ Partial (backend done, no UI) | ✅ Yes |
| REQ-01-16 | DOM Selector Hardening | ⚠️ Minimal (3 entries, unused) | ✅ Yes |

### Explicitly Out of Scope
- P0/P1 requirements (already complete)
- Workday / Greenhouse / Lever autofill adapters (post-MVP)
- Multi-template resume design (post-MVP)
- Cover letter generation (post-MVP)
- Monitoring dashboards or APM

---

## 3. Architecture Decisions

### AD-01: Extended Autofill with LinkedIn Easy Apply Modal Support (REQ-01-12)

**Decision:** Expand `autofill.ts` field map from 4 entries to cover summary, skills, work experience, education, and LinkedIn Easy Apply resume upload. For file inputs, use `DataTransfer` to programmatically set a `File` object on `<input type="file">`. For unsupported fields, inject per-field "Copy" buttons that write to clipboard.

**Rationale:** LinkedIn Easy Apply uses multi-step modal dialogs. The autofill script must detect new inputs as modal steps advance. A `MutationObserver` watching the modal container handles dynamic content. The `DataTransfer` API is the standard way to set file inputs programmatically in content scripts without security violations. Clipboard fallback meets BRD NFR-14.

**Key Design:**
- Field map expands to include: `summary`, `skills`, `current_title`, `years_experience`, `work_experience`, `education`, `cover_letter`, `linkedin_url`, `portfolio_url`.
- Resume file upload: Generate a minimal text file from profile data or use cached PDF bytes (from last generation stored in `chrome.storage.local`).
- `MutationObserver` on `document.body` for LinkedIn Easy Apply modal step transitions.
- Per-failed-field clipboard buttons injected adjacent to unfilled inputs.

**Reference:** architecture.md §4.3 (autofill flow), TRD §14.3.

### AD-02: Web-Based Optimise Flow (REQ-01-13)

**Decision:** Add an `/app/optimize` page to the web portal with a JD input form (textarea for JD text + optional company/title fields). The page calls `POST /api/optimize` (same backend endpoint used by the extension) via the existing `apiFetch` client, and displays results with the same ATS score diff + suggested changes UI pattern as the extension popup.

**Rationale:** The backend optimize endpoint is already fully functional and auth-guarded. No new backend endpoint is needed — the web portal simply provides an alternative client surface. The profile is loaded from the backend (same as extension flow). This gives users without the extension the full core loop.

**Key Design:**
- New route: `smart-apply-web/src/app/optimize/page.tsx`
- New component: `smart-apply-web/src/components/optimize/optimize-form.tsx` — JD textarea + company/title inputs.
- New component: `smart-apply-web/src/components/optimize/optimize-results.tsx` — ATS score bars, suggested changes with toggles, download PDF button.
- PDF generation: Use `pdf-lib` in-browser (same as extension). Add `pdf-lib` to web `package.json`.
- No Google Drive upload from web (extension-only per architecture.md §7).

**Reference:** architecture.md §4.2 (optimization flow), §7 (web portal responsibility).

### AD-03: Settings & Account Management Page (REQ-01-14)

**Decision:** Add an `/app/settings` page with three sections: (1) Account Info (name, email from Clerk), (2) Connected Integrations (Google Drive status), (3) Danger Zone (account deletion button with confirmation dialog). Account deletion calls the Clerk API via a new `DELETE /api/account` backend endpoint that triggers Clerk user deletion (which fires the webhook for cascading data cleanup).

**Rationale:** The existing `POST /api/webhooks/clerk` handles the actual data deletion on `user.deleted` event. The settings page needs a way to initiate deletion from the client side. Rather than calling Clerk directly from the browser (which would require exposing secret keys), a thin backend endpoint accepts the authenticated request, calls Clerk's `users.deleteUser()`, and Clerk then fires the webhook back to our backend for data cleanup.

**Key Design:**
- New route: `smart-apply-web/src/app/settings/page.tsx`
- New component: `smart-apply-web/src/components/settings/settings-page.tsx`
- New backend endpoint: `DELETE /api/account` in a new `AccountModule` — verifies Clerk JWT, calls `clerkClient.users.deleteUser(userId)`, which triggers the existing webhook cascade.
- Confirmation dialog: Two-step with typed confirmation ("DELETE") to prevent accidental deletion.
- Integration status: Query Google Drive connection status via extension message (if extension installed) or show "Install extension" CTA.

**Reference:** architecture.md §11 (account deletion), BRD REQ-01-14.

### AD-04: Manual Profile Upload UI (REQ-01-15)

**Decision:** Add an upload section to the existing profile page (`/app/profile`). Provide two input methods: (1) File upload (PDF/TXT) that extracts text client-side before sending to the existing `POST /api/profile/ingest` endpoint, and (2) a paste textarea for raw text input. PDF text extraction uses `pdf.js` (Mozilla's library) in the browser.

**Rationale:** The backend already supports `POST /api/profile/ingest` with `source: 'upload' | 'manual'`. The gap is purely UI. Client-side PDF text extraction keeps the zero-storage principle intact (no file uploads to server). The `pdfjs-dist` library is the standard for browser-based PDF text extraction and works well with Next.js.

**Key Design:**
- New component: `smart-apply-web/src/components/profile/profile-upload.tsx` — drag-and-drop zone + file picker + paste textarea.
- PDF text extraction: `pdfjs-dist` extracts text content from uploaded PDF pages.
- After extraction, text is sent to `POST /api/profile/ingest` with `source: 'upload'` or `source: 'manual'`.
- On success, the profile editor re-fetches and displays the newly parsed profile for user review.
- File size limit: 5MB enforced client-side.

**Reference:** architecture.md §4.1 (profile ingestion flow), BRD REQ-01-15.

### AD-05: DOM Selector Hardening & Centralization (REQ-01-16)

**Decision:** Expand the `dom-utils.ts` selector registry to cover **all** selectors used across content scripts (currently 10+ hardcoded selectors). Add a version field per entry, structured error reporting via `chrome.runtime.sendMessage`, and migrate all content scripts to use `queryWithFallback()` instead of direct `document.querySelector()`. Add selectors for LinkedIn Easy Apply modal elements.

**Rationale:** Currently only 3 of 10+ selectors are in the registry, and content scripts call `document.querySelector()` directly. Centralising all selectors enables: (a) single point of maintenance when LinkedIn/Indeed changes DOM, (b) fallback chains that keep the extension working during partial DOM changes, (c) structured failure reports that can be logged for monitoring, (d) version tracking so we know which selector era a user is on.

**Key Design:**
- `SelectorEntry` gains a `version: number` field.
- New entries for: `linkedin.profile.main`, `linkedin.jd.company`, `linkedin.jd.title`, `linkedin.easyapply.modal`, `linkedin.easyapply.resume`, `indeed.jd.company`, `indeed.jd.title`, and all autofill-related selectors.
- New `reportSelectorFailure(key: string, context: string)` function that sends a `SELECTOR_FAILURE` message to the background service worker for structured logging.
- All content scripts (`linkedin-profile.ts`, `jd-detector.ts`, `autofill.ts`) migrate to use `queryWithFallback()`.
- Background service worker logs `SELECTOR_FAILURE` events with timestamp, URL, and registry key.

**Reference:** BRD REQ-01-16, architecture.md §7.

---

## 4. Data Flow

### 4.1 Extended Autofill Flow (REQ-01-12)

```
User opens LinkedIn Easy Apply modal
  → MutationObserver detects modal step
  → autofill.ts scans step inputs (expanded field map)
  → For each detectable field:
      Match by heuristic (label, name, aria-label)
      → setNativeValue() + event dispatch
  → For file input (resume):
      Retrieve cached PDF from chrome.storage.local
      → DataTransfer API sets File on input
  → For unsupported fields:
      Inject "Copy" button next to input
      → Click copies value to clipboard
  → Return { filled[], failed[], clipboard[] }
```

### 4.2 Web Optimize Flow (REQ-01-13)

```
User navigates to /optimize
  → Enters JD text + company + job title
  → Submit calls POST /api/optimize (Bearer JWT)
  → Backend runs 5-step pipeline (same as extension)
  → Response: { ats_before, ats_after, suggested_changes, optimized_json }
  → Web UI displays:
      ATS score comparison bars
      Toggleable suggested changes list
      "Download PDF" button
  → User approves changes → pdf-lib generates PDF in browser
  → Download triggered (no Drive upload from web)
```

### 4.3 Account Deletion Flow (REQ-01-14)

```
User navigates to /settings
  → Clicks "Delete Account" → confirmation dialog
  → Types "DELETE" to confirm
  → Frontend calls DELETE /api/account (Bearer JWT)
  → Backend verifies auth → calls clerkClient.users.deleteUser(userId)
  → Clerk fires user.deleted webhook to POST /api/webhooks/clerk
  → Existing webhook handler: DELETE FROM master_profiles (CASCADE)
  → Frontend redirects to sign-in page
```

### 4.4 Profile Upload Flow (REQ-01-15)

```
User navigates to /profile
  → Clicks "Upload Resume" or pastes text
  → [PDF path]: pdfjs-dist extracts text from uploaded file
  → [Text path]: Raw text from textarea
  → Frontend calls POST /api/profile/ingest { source, raw_text }
  → Backend: LLM parses text → structured profile → upsert
  → Profile editor re-fetches and displays parsed result
  → User reviews and can manually edit fields
```

### 4.5 Selector Failure Reporting Flow (REQ-01-16)

```
Content script calls queryWithFallback('linkedin.jd.content')
  → Primary selector fails
  → Fallback 1 succeeds → returns element
  → Sends SELECTOR_FAILURE message to background:
    { key, failedSelector, usedFallback, url, timestamp, version }
  → Background worker logs structured event
  → [Future: aggregate and surface in settings UI]
```

---

## 5. API Contracts

### 5.1 New Endpoint: DELETE /api/account (REQ-01-14)

```
DELETE /api/account
Headers: Authorization: Bearer <clerk-jwt>
Response 200: { success: true }
Response 401: { error: "Unauthorized" }
Response 500: { error: "Failed to delete account" }
```

No request body. The user ID is extracted from the JWT.

### 5.2 Existing Endpoints (No Changes Needed)

| Endpoint | Used By | Notes |
|:---|:---|:---|
| `POST /api/optimize` | Web optimize form (REQ-01-13) | Already accepts JD text + profile-from-DB |
| `POST /api/profile/ingest` | Profile upload UI (REQ-01-15) | Already accepts `source: 'upload'\|'manual'` |
| `GET /api/profile/me` | Profile upload preview (REQ-01-15) | Already returns full profile |
| `POST /api/webhooks/clerk` | Account deletion cascade (REQ-01-14) | Already handles `user.deleted` |

---

## 6. Security Considerations

| Concern | Mitigation |
|:---|:---|
| Account deletion must be intentional | Two-step confirmation dialog with typed "DELETE" |
| Backend must own deletion authority | `DELETE /api/account` uses server-side Clerk SDK; no client-side secret keys |
| PDF text extraction in browser | Client-side only; no file upload to server (zero-storage policy) |
| Uploaded file size | 5MB client-side limit; reject oversized files before network call |
| DOM-injected clipboard buttons | Scoped to extension content scripts; no cross-origin data exposure |
| Selector telemetry | No PII in failure reports (URL hostname only, no query params) |
| Web optimize input sanitization | JD text validated by existing Zod schema at backend boundary |
| File input injection | Only sets files from user-approved content (cached PDF or generated text) |

---

## 7. Acceptance Criteria (From BRD)

### REQ-01-12: Extended Autofill
- Given a LinkedIn Easy Apply modal, when autofill runs, then summary, skills, work experience, and education fields are populated.
- Given a resume file input on Easy Apply, when autofill runs, then the cached PDF is attached.
- Given an unsupported field, then a "Copy" button appears next to it offering clipboard copy.

### REQ-01-13: Web-Based Optimise Flow
- Given a user on the web portal without the extension, when they paste a JD and submit, then they receive ATS before/after scores and suggested changes.
- Given approved changes, when the user clicks download, then a PDF is generated in-browser and downloaded.

### REQ-01-14: Settings & Account Management
- Given the settings page, then the user sees their account info and connected integrations.
- Given the user clicks "Delete Account" and confirms, then all user data is deleted and they are redirected to the sign-in page.

### REQ-01-15: Manual Profile Upload
- Given a user uploads a PDF resume, then the text is extracted client-side and sent for LLM parsing.
- Given a user pastes plain text, then it is sent for LLM parsing and the profile is created/updated.
- Given successful parsing, the profile editor displays the result for review.

### REQ-01-16: DOM Selector Hardening
- Given a selector fails, then the fallback chain is tried and a structured failure event is reported.
- Given all content scripts, then none use hardcoded `document.querySelector()` — all use `queryWithFallback()`.
- Given a selector entry, it includes a version number for tracking.

---

## 8. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|:---|:---|:---|:---|
| LinkedIn DOM changes break Easy Apply selectors | High | Medium | Selector registry with fallbacks + failure reporting |
| `DataTransfer` file injection blocked by browser security | Low | High | Fallback: show "Upload resume manually" instruction |
| `pdfjs-dist` bundle size impacts web load time | Medium | Low | Dynamic import with code splitting |
| Account deletion webhook race condition | Low | Medium | Backend endpoint returns after Clerk SDK call completes; webhook processes async |
| LLM parsing of poorly formatted resume text | Medium | Medium | Existing partial-failure handling returns what it can parse |

---

## 9. Implementation Order

Recommended implementation sequence based on dependencies:

1. **REQ-01-16 — Selector Hardening** (no dependencies; enables REQ-01-12)
2. **REQ-01-12 — Extended Autofill** (depends on REQ-01-16 for selectors)
3. **REQ-01-15 — Manual Profile Upload** (no dependencies; smallest scope)
4. **REQ-01-14 — Settings & Account Management** (depends on existing webhook)
5. **REQ-01-13 — Web Optimize Flow** (largest scope; last to enable parallel testing)
