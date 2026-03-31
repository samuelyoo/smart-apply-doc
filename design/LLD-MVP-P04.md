---
title: "LLD-MVP-P04 — Security, Testing & Quality Hardening"
permalink: /design/lld-mvp-p04/
---

# LLD-MVP-P04 — Security, Testing & Quality Hardening

**Version:** 1.0  
**Date:** 2026-03-29  
**Phase:** Security, Testing & Quality Hardening  
**Input:** HLD-MVP-P04.md + architecture.md  
**Source BRD:** BRD-MVP-02.md  

---

## 1. File-Level Change Manifest

### 1.1 P0 — Security Fixes

```
File: smart-apply-web/src/middleware.ts
Action: MODIFY
Purpose: Invert route protection to public-allowlist model (REQ-02-01)
Dependencies: @clerk/nextjs/server
Estimated Lines: 20
```

```
File: smart-apply-backend/src/main.ts
Action: MODIFY
Purpose: Restrict CORS to specific Chrome extension ID (REQ-02-02)
Dependencies: @nestjs/core, @nestjs/config
Estimated Lines: 45
```

```
File: smart-apply-extension/src/lib/api-client.ts
Action: MODIFY
Purpose: Add 401 interceptor — clear token + broadcast SESSION_EXPIRED (REQ-02-03)
Dependencies: ./auth (clearAuthToken), chrome.runtime
Estimated Lines: 45
```

### 1.2 P0 — Google Drive Completion

```
File: smart-apply-extension/src/manifest.ts
Action: MODIFY
Purpose: Replace OAuth placeholder with build-time env var (REQ-02-04)
Dependencies: @crxjs/vite-plugin
Estimated Lines: ~50 (unchanged length, 1-line edit)
```

```
File: smart-apply-extension/src/background/service-worker.ts
Action: MODIFY
Purpose: Pass drive_link from SAVE_APPLICATION payload to API body (REQ-02-04)
Dependencies: @smart-apply/shared types
Estimated Lines: ~260 (minor edit inside handleSaveApplication)
```

### 1.3 P0 — Test Framework Setup

```
File: smart-apply-shared/vitest.config.ts
Action: CREATE
Purpose: Vitest config for shared package (REQ-02-05)
Dependencies: vitest
Estimated Lines: 10
```

```
File: smart-apply-shared/test/schemas.spec.ts
Action: CREATE
Purpose: Smoke test to verify Vitest runs in shared package (REQ-02-05)
Dependencies: vitest, @smart-apply/shared schemas
Estimated Lines: 15
```

```
File: smart-apply-web/vitest.config.ts
Action: CREATE
Purpose: Vitest config for web package with jsdom (REQ-02-05)
Dependencies: vitest, @vitejs/plugin-react
Estimated Lines: 18
```

```
File: smart-apply-web/test/setup.ts
Action: CREATE
Purpose: Test setup with React Testing Library matchers (REQ-02-05)
Dependencies: @testing-library/jest-dom
Estimated Lines: 5
```

```
File: smart-apply-extension/vitest.config.ts
Action: CREATE
Purpose: Vitest config for extension with Chrome API mocks (REQ-02-05)
Dependencies: vitest
Estimated Lines: 15
```

```
File: smart-apply-extension/test/chrome-mock.ts
Action: CREATE
Purpose: Global Chrome API mock setup (REQ-02-05)
Dependencies: vitest
Estimated Lines: 60
```

### 1.4 P1 — Regression Tests

```
File: smart-apply-web/test/middleware.spec.ts
Action: CREATE
Purpose: Test route protection for all authenticated routes (REQ-02-06)
Dependencies: vitest, @clerk/nextjs testing utilities
Estimated Lines: 60
```

```
File: smart-apply-shared/test/schemas.spec.ts
Action: MODIFY (expand from smoke test in 1.3)
Purpose: Full Zod schema validation tests (REQ-02-06)
Dependencies: vitest, all shared schemas
Estimated Lines: 120
```

### 1.5 P1 — Web Component Tests

```
File: smart-apply-web/test/components/optimize-form.spec.tsx
Action: CREATE
Purpose: OptimizeForm render + submit + loading state tests (REQ-02-07)
Dependencies: vitest, @testing-library/react, @testing-library/user-event
Estimated Lines: 80
```

```
File: smart-apply-web/test/components/optimize-results.spec.tsx
Action: CREATE
Purpose: OptimizeResults score display + change toggles (REQ-02-07)
Dependencies: vitest, @testing-library/react
Estimated Lines: 90
```

```
File: smart-apply-web/test/components/dashboard-shell.spec.tsx
Action: CREATE
Purpose: DashboardShell fetch + render history (REQ-02-07)
Dependencies: vitest, @testing-library/react
Estimated Lines: 60
```

```
File: smart-apply-web/test/components/profile-editor.spec.tsx
Action: CREATE
Purpose: ProfileEditor load + submit tests (REQ-02-07)
Dependencies: vitest, @testing-library/react, @testing-library/user-event
Estimated Lines: 70
```

```
File: smart-apply-web/test/components/settings-page.spec.tsx
Action: CREATE
Purpose: SettingsPage account info + delete confirmation (REQ-02-07)
Dependencies: vitest, @testing-library/react, @testing-library/user-event
Estimated Lines: 70
```

### 1.6 P1 — Extension Tests

```
File: smart-apply-extension/test/service-worker.spec.ts
Action: CREATE
Purpose: Service worker message handler tests (REQ-02-08)
Dependencies: vitest, chrome-mock.ts, @smart-apply/shared types
Estimated Lines: 150
```

```
File: smart-apply-extension/test/api-client.spec.ts
Action: CREATE
Purpose: apiFetch Bearer token + 401 handling tests (REQ-02-08)
Dependencies: vitest, chrome-mock.ts
Estimated Lines: 80
```

```
File: smart-apply-extension/test/pdf-generator.spec.ts
Action: CREATE
Purpose: PDF generation tests (REQ-02-08)
Dependencies: vitest, pdf-lib
Estimated Lines: 50
```

### 1.7 P1 — CI Pipeline

```
File: .github/workflows/ci.yml
Action: MODIFY
Purpose: Add build + test for all 4 packages (REQ-02-09)
Dependencies: GitHub Actions
Estimated Lines: 50
```

### 1.8 P1 — Audit Log

```
File: supabase/migrations/00002_audit_events.sql
Action: CREATE
Purpose: Create audit_events table (REQ-02-10)
Dependencies: Supabase
Estimated Lines: 10
```

```
File: smart-apply-backend/src/modules/webhooks/webhooks.service.ts
Action: MODIFY
Purpose: Write audit event after user deletion (REQ-02-10)
Dependencies: SupabaseService
Estimated Lines: ~75 (add ~10 lines)
```

### 1.9 P1 — Retry Buttons

```
File: smart-apply-extension/src/ui/popup/App.tsx
Action: MODIFY
Purpose: Add retry buttons to error states + SESSION_EXPIRED handling (REQ-02-11)
Dependencies: react
Estimated Lines: ~320 (add ~40 lines)
```

---

## 2. Interface & Type Definitions

### 2.1 Extension Message Types Update

In `smart-apply-extension/src/background/service-worker.ts`, the existing `MessageType` union needs a new member:

```typescript
// Add to existing MessageType union:
| { type: 'SESSION_EXPIRED' }
```

The `SAVE_APPLICATION` message payload needs `drive_link`:

```typescript
// Update existing SAVE_APPLICATION in MessageType:
| { type: 'SAVE_APPLICATION'; payload: { 
    optimizeResult: OptimizeResponse; 
    selectedChanges: number[]; 
    drive_link?: string  // ← NEW
  } }
```

### 2.2 Chrome API Mock Types

```typescript
// smart-apply-extension/test/chrome-mock.ts
// Provides globalThis.chrome mock with:
interface ChromeMock {
  storage: {
    local: {
      get: vi.Mock;
      set: vi.Mock;
      remove: vi.Mock;
    };
    onChanged: {
      addListener: vi.Mock;
      removeListener: vi.Mock;
    };
  };
  runtime: {
    onMessage: { addListener: vi.Mock; removeListener: vi.Mock };
    onMessageExternal: { addListener: vi.Mock; removeListener: vi.Mock };
    onInstalled: { addListener: vi.Mock };
    sendMessage: vi.Mock;
    lastError: null;
  };
  tabs: {
    query: vi.Mock;
    sendMessage: vi.Mock;
    create: vi.Mock;
  };
  identity: {
    getAuthToken: vi.Mock;
  };
  downloads: {
    download: vi.Mock;
  };
}
```

### 2.3 No New Shared Types Required

All existing shared types (`CreateApplicationRequest`, `OptimizeResponse`, etc.) already support the needed fields. `CreateApplicationRequest` already has `drive_link?: string | null`.

---

## 3. Function-Level Design

### 3.1 REQ-02-01: Middleware Route Protection Inversion

```
Function: default export (clerkMiddleware callback)
Location: smart-apply-web/src/middleware.ts
Signature: clerkMiddleware(async (auth, req) => void)
Logic:
  1. Define isPublicRoute = createRouteMatcher([
       '/sign-in(.*)', '/sign-up(.*)', '/api/webhooks(.*)', '/', '/not-found'
     ])
  2. If !isPublicRoute(req) → await auth.protect()
  3. All other routes are protected by default
Error Cases:
  - Unauthenticated access to any non-public route → 302 to /sign-in
```

### 3.2 REQ-02-02: CORS Extension Restriction

```
Function: bootstrap() CORS origin callback
Location: smart-apply-backend/src/main.ts
Signature: origin callback: (origin: string | undefined, callback) => void
Logic:
  1. Read CHROME_EXTENSION_ID from ConfigService
  2. Read NODE_ENV from ConfigService
  3. Allow if: !origin (same-origin), or origin in allowedOrigins
  4. Allow if: CHROME_EXTENSION_ID set AND origin === `chrome-extension://${extId}`
  5. Allow if: NODE_ENV !== 'production' AND /^chrome-extension:\/\//.test(origin)
  6. Otherwise: callback(new Error('CORS not allowed'))
Error Cases:
  - Unknown extension origin in production → CORS error
  - No CHROME_EXTENSION_ID in production → only web origins allowed
```

### 3.3 REQ-02-03: apiFetch 401 Interceptor

```
Function: apiFetch<T>(path, init?)
Location: smart-apply-extension/src/lib/api-client.ts
Signature: async function apiFetch<T>(path: string, init?: RequestInit): Promise<T>
Logic:
  1. Get token from storage (existing)
  2. Make fetch request (existing)
  3. If res.status === 401:
     a. import { clearAuthToken } from './auth'
     b. await clearAuthToken()
     c. chrome.runtime.sendMessage({ type: 'SESSION_EXPIRED' })
     d. throw new Error('Session expired. Please sign in again.')
  4. If !res.ok: throw generic error (existing)
  5. Return res.json() (existing)
Error Cases:
  - 401 → clear token + broadcast + throw
  - Other non-ok → throw with body.message (existing)
```

### 3.4 REQ-02-04: Manifest OAuth Client ID

```
Function: defineManifest() oauth2 config
Location: smart-apply-extension/src/manifest.ts
Logic:
  1. Replace: client_id: 'GOOGLE_OAUTH_CLIENT_ID_PLACEHOLDER'
  2. With: client_id: process.env.VITE_GOOGLE_OAUTH_CLIENT_ID || 'GOOGLE_OAUTH_CLIENT_ID_PLACEHOLDER'
```

### 3.5 REQ-02-04: Service Worker drive_link Pass-Through

```
Function: handleSaveApplication(payload)
Location: smart-apply-extension/src/background/service-worker.ts
Signature: async function handleSaveApplication(payload: { optimizeResult; selectedChanges; drive_link?: string }): Promise<...>
Logic:
  1. Read context from storage (existing)
  2. Build CreateApplicationRequest body (existing)
  3. Add: if (payload.drive_link) body.drive_link = payload.drive_link  ← NEW
  4. POST to /api/applications (existing)
Error Cases:
  - No optimization context → return error (existing)
  - API error → return error (existing)
```

### 3.6 REQ-02-10: Audit Event Insertion

```
Function: handleUserDeleted(clerkUserId)
Location: smart-apply-backend/src/modules/webhooks/webhooks.service.ts
Signature: private async handleUserDeleted(clerkUserId: string): Promise<void>
Logic:
  1. Delete master_profiles (existing, triggers cascade)
  2. NEW: Insert into audit_events:
     { clerk_user_id: clerkUserId, event_type: 'user.deleted', metadata: {} }
  3. Log audit event creation
Error Cases:
  - Deletion fails → throw (existing)
  - Audit insert fails → log error but do not throw (deletion is the critical op)
```

### 3.7 REQ-02-11: Extension Retry Buttons

```
Function: App() — error state rendering
Location: smart-apply-extension/src/ui/popup/App.tsx
Logic:
  1. Track lastFailedAction: 'sync' | 'optimize' | null
  2. When sync fails → set lastFailedAction = 'sync', display error + Retry button
  3. When optimize fails → set lastFailedAction = 'optimize', display error + Retry button
  4. Retry button onClick → re-dispatch TRIGGER_SYNC or TRIGGER_OPTIMIZE
  5. Listen for SESSION_EXPIRED message → show "Session expired" message, then transition to login

  New state variables:
  - errorMessage: string | null
  - lastFailedAction: 'sync' | 'optimize' | null

  ErrorWithRetry inline component:
  - Props: message: string, onRetry: () => void
  - Renders: <p>{message}</p> <button onClick={onRetry}>Retry</button>
```

---

## 4. Database Operations

### 4.1 Migration: audit_events Table (REQ-02-10)

```sql
-- supabase/migrations/00002_audit_events.sql
CREATE TABLE IF NOT EXISTS audit_events (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  clerk_user_id text NOT NULL,
  event_type text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

-- No RLS enabled — admin/service-role only
CREATE INDEX idx_audit_events_clerk_user_id ON audit_events (clerk_user_id);
CREATE INDEX idx_audit_events_event_type ON audit_events (event_type);
```

### 4.2 Audit Insert (in WebhooksService)

```typescript
// Supabase client syntax:
await this.supabase.admin
  .from('audit_events')
  .insert({
    clerk_user_id: clerkUserId,
    event_type: 'user.deleted',
    metadata: {},
  });
```

No RLS implications — the `audit_events` table uses service role access only.

---

## 5. Test Specification

### 5.1 Shared Package Schema Tests (REQ-02-06)

```
Test Suite: Zod Schema Validation
Test File: smart-apply-shared/test/schemas.spec.ts
Cases:
  Profile Schemas:
  - it("profileIngestRequestSchema accepts valid linkedin ingest") → parse succeeds
  - it("profileIngestRequestSchema rejects empty raw_text") → ZodError with min(1)
  - it("profileIngestRequestSchema rejects invalid source") → ZodError
  - it("updateProfileRequestSchema accepts partial update") → parse succeeds
  - it("experienceItemSchema rejects missing company") → ZodError

  Application Schemas:
  - it("createApplicationRequestSchema accepts full valid input") → parse succeeds
  - it("createApplicationRequestSchema accepts optional drive_link") → parse succeeds
  - it("createApplicationRequestSchema rejects empty company_name") → ZodError
  - it("applicationStatusSchema accepts all valid statuses") → parse succeeds for each
  - it("applicationStatusSchema rejects invalid status") → ZodError

  Optimization Schemas:
  - it("optimizeRequestSchema accepts valid JD input") → parse succeeds
  - it("optimizeRequestSchema rejects empty job_description_text") → ZodError
  - it("llmOutputSchema accepts valid LLM response") → parse succeeds
  - it("llmOutputSchema rejects missing skills array") → ZodError

Mocks Required: None (pure validation logic)
```

### 5.2 Middleware Route Protection Tests (REQ-02-06)

```
Test Suite: Clerk Middleware Route Protection
Test File: smart-apply-web/test/middleware.spec.ts
Cases:
  - it("protects /dashboard from unauthenticated users") → auth.protect() called
  - it("protects /profile from unauthenticated users") → auth.protect() called
  - it("protects /optimize from unauthenticated users") → auth.protect() called
  - it("protects /settings from unauthenticated users") → auth.protect() called
  - it("allows unauthenticated access to /sign-in") → auth.protect() NOT called
  - it("allows unauthenticated access to /sign-up") → auth.protect() NOT called
  - it("allows unauthenticated access to /") → auth.protect() NOT called
  - it("protects unknown routes by default") → auth.protect() called for /some-new-route

Mocks Required: @clerk/nextjs/server (createRouteMatcher, clerkMiddleware, auth)
```

### 5.3 Extension API Client Tests (REQ-02-08)

```
Test Suite: apiFetch
Test File: smart-apply-extension/test/api-client.spec.ts
Cases:
  - it("attaches Bearer token from storage") → fetch called with Authorization header
  - it("omits Authorization header when no token") → no Authorization header
  - it("returns parsed JSON on 200") → returns response body
  - it("clears auth token on 401") → clearAuthToken() called
  - it("broadcasts SESSION_EXPIRED on 401") → chrome.runtime.sendMessage called
  - it("throws 'Session expired' error on 401") → error message matches
  - it("throws generic error on non-401 failure") → error includes status code
  - it("includes body.message in error when available") → error message from body

Mocks Required: globalThis.fetch, chrome.storage.local, chrome.runtime.sendMessage
```

### 5.4 Service Worker Tests (REQ-02-08)

```
Test Suite: Service Worker Message Handlers
Test File: smart-apply-extension/test/service-worker.spec.ts
Cases:
  SYNC_PROFILE:
  - it("calls /api/profile/ingest with correct body") → apiFetch called with POST
  - it("caches profile in storage on success") → setStorage('cached_profile') called
  - it("returns error on API failure") → { success: false, error }

  OPTIMIZE_JD:
  - it("calls /api/optimize with JD payload") → apiFetch called with correct body
  - it("stores optimize context in storage") → setStorage('last_optimize_context')
  - it("returns optimized data on success") → { success: true, data }

  AUTH_TOKEN:
  - it("stores token in chrome.storage.local") → storage.set called
  - it("retrieves token from chrome.storage.local") → returns stored token

  SAVE_APPLICATION:
  - it("reads optimize context from storage") → getStorage called
  - it("sends POST /api/applications with all fields") → apiFetch called
  - it("includes drive_link when provided") → body contains drive_link field
  - it("omits drive_link when not provided") → body does not contain drive_link

Mocks Required: chrome-mock.ts, apiFetch (mock module), storage (mock module)
```

### 5.5 PDF Generator Tests (REQ-02-08)

```
Test Suite: generateResumePDF
Test File: smart-apply-extension/test/pdf-generator.spec.ts
Cases:
  - it("produces non-empty Uint8Array for valid input") → result.length > 0
  - it("produces valid PDF header bytes") → starts with %PDF-
  - it("handles empty experience array") → generates without error
  - it("handles empty skills array") → generates without error

Mocks Required: None (pdf-lib runs in node)
```

### 5.6 Web Component Tests (REQ-02-07)

```
Test Suite: OptimizeForm
Test File: smart-apply-web/test/components/optimize-form.spec.tsx
Cases:
  - it("renders JD textarea and submit button") → elements visible
  - it("submits JD text on form submit") → API call triggered with text
  - it("shows loading spinner during submission") → loading indicator visible
  - it("shows error message on API failure") → error displayed

Test Suite: OptimizeResults
Test File: smart-apply-web/test/components/optimize-results.spec.tsx
Cases:
  - it("displays before/after ATS scores") → scores visible
  - it("renders suggested changes with checkboxes") → changes listed
  - it("toggles change selection on checkbox click") → state updates
  - it("shows warning changes without checkbox") → warnings display properly
  - it("shows confidence badges") → badge colors correct

Test Suite: DashboardShell
Test File: smart-apply-web/test/components/dashboard-shell.spec.tsx
Cases:
  - it("fetches and renders application history") → list rendered
  - it("shows empty state when no applications") → empty message shown
  - it("shows loading state while fetching") → spinner visible

Test Suite: ProfileEditor
Test File: smart-apply-web/test/components/profile-editor.spec.tsx
Cases:
  - it("loads and displays existing profile data") → fields populated
  - it("submits updated profile") → API call with changed data
  - it("shows validation errors") → error messages for invalid fields

Test Suite: SettingsPage
Test File: smart-apply-web/test/components/settings-page.spec.tsx
Cases:
  - it("displays account information") → name/email visible
  - it("shows delete confirmation dialog") → dialog opens on click
  - it("requires typing DELETE to confirm") → button disabled until typed
  - it("calls delete API on confirmation") → API call triggered

Mocks Required: @clerk/nextjs (auth context), fetch (API mocking), next/navigation (router)
```

### 5.7 Webhook Audit Test (REQ-02-10)

```
Test Suite: WebhooksService (extend existing)
Test File: smart-apply-backend/test/webhooks.controller.spec.ts (extend)
Cases:
  - it("inserts audit_events row after user deletion") → supabase.insert called on audit_events
  - it("audit event contains clerk_user_id and event_type") → inserted row matches schema
  - it("does not block deletion if audit insert fails") → deletion still succeeds

Mocks Required: SupabaseService (existing mock), Webhook (existing mock)
```

### 5.8 CORS Restriction Tests (REQ-02-02)

```
Test Suite: CORS Origin Validation
Test File: smart-apply-backend/test/cors.spec.ts
Cases:
  - it("allows requests from configured web origin") → callback(null, true)
  - it("allows configured chrome extension ID") → callback(null, true)
  - it("rejects unknown chrome extension") → callback(Error)
  - it("allows any extension in dev mode without CHROME_EXTENSION_ID") → callback(null, true)
  - it("rejects any extension in production without CHROME_EXTENSION_ID") → callback(Error)
  - it("allows same-origin (null origin)") → callback(null, true)

Mocks Required: ConfigService mock
```

---

## 6. Component Design (UI Files)

### 6.1 Extension Popup — Error + Retry (REQ-02-11)

```
Component: App (modified)
File: smart-apply-extension/src/ui/popup/App.tsx
Props: None (root component)
New State:
  - errorMessage: string | null (replaces inline status for errors)
  - lastFailedAction: 'sync' | 'optimize' | null
Effects:
  - Add listener for SESSION_EXPIRED message → show "Session expired" + transition to login
Children:
  - Inline ErrorWithRetry: displays error text + "Retry" button
Accessibility:
  - Retry button must be keyboard-accessible (native <button> is sufficient)
  - Error message should be announced (role="alert")
```

**Render logic changes in dashboard screen:**

```tsx
{errorMessage && lastFailedAction && (
  <div role="alert" className="p-3 bg-red-50 border border-red-200 rounded-lg">
    <p className="text-xs text-red-700">{errorMessage}</p>
    <button
      className="mt-2 px-3 py-1 bg-red-600 text-white rounded text-xs"
      onClick={() => {
        setErrorMessage(null);
        if (lastFailedAction === 'sync') {
          setStatus('Syncing profile…');
          chrome.runtime.sendMessage({ type: 'TRIGGER_SYNC' }, handleSyncResponse);
        } else if (lastFailedAction === 'optimize') {
          setScreen('optimizing');
          chrome.runtime.sendMessage({ type: 'TRIGGER_OPTIMIZE' });
        }
      }}
    >
      Retry
    </button>
  </div>
)}
```

---

## 7. Integration Sequence

### Phase 1: Security Fixes (Parallel — REQ-02-01, 02-02, 02-03)

1. **REQ-02-01**: Modify `middleware.ts` (1 file, S effort)
   - Verify: Navigate to `/optimize` unauthenticated → redirected to `/sign-in`
2. **REQ-02-02**: Modify `main.ts` (1 file, S effort)
   - Verify: Backend starts; test with curl from unknown origin → CORS rejection
3. **REQ-02-03**: Modify `api-client.ts` (1 file, S effort)
   - Verify: Mock 401 from backend → token cleared, popup shows login

### Phase 2: Drive Completion (REQ-02-04)

4. **REQ-02-04a**: Modify `manifest.ts` — OAuth client ID env substitution
5. **REQ-02-04b**: Modify `service-worker.ts` — pass `drive_link` in handleSaveApplication
   - Verify: Build extension → manifest has real client ID; save application includes drive_link

### Phase 3: Test Infrastructure (REQ-02-05)

6. Install dev dependencies:
   - `smart-apply-shared`: `vitest`
   - `smart-apply-web`: `vitest`, `@vitejs/plugin-react`, `@testing-library/react`, `@testing-library/jest-dom`, `@testing-library/user-event`, `jsdom`
   - `smart-apply-extension`: `vitest`
7. Create `vitest.config.ts` for each package
8. Create `smart-apply-extension/test/chrome-mock.ts`
9. Create `smart-apply-web/test/setup.ts`
10. Add `"test": "vitest run"` to each package's `package.json` scripts
   - Verify: `npm test` runs in each package (0 tests, pass)

### Phase 4: Regression Tests (REQ-02-06)

11. Create `smart-apply-shared/test/schemas.spec.ts` (full suite)
12. Create `smart-apply-web/test/middleware.spec.ts`
   - Verify: All schema + middleware tests pass

### Phase 5: Component + Extension Tests (REQ-02-07, 02-08 — Parallel)

13. Create web component test files (5 files)
14. Create extension test files (3 files)
   - Verify: All tests pass in both packages

### Phase 6: CI + Audit + Retry (REQ-02-09, 02-10, 02-11 — Parallel)

15. Modify `.github/workflows/ci.yml` — add all package builds + tests
16. Create `supabase/migrations/00002_audit_events.sql`
17. Modify `webhooks.service.ts` — add audit event insert
18. Modify `App.tsx` — add retry buttons + SESSION_EXPIRED listener
   - Verify: CI passes; audit events created; retry buttons visible

### Build Verification at Each Stage

After each phase:
```bash
cd smart-apply-shared && npm run build
cd smart-apply-backend && npm run build
cd smart-apply-web && npm run build
cd smart-apply-extension && npm run build
```

---

## 8. Alignment Checklist

- [x] All API inputs validated with Zod at boundaries (existing schemas cover all inputs)
- [x] Loading, error, empty states handled in UI (retry buttons added for error state REQ-02-11)
- [x] No secrets in client bundles (OAuth client ID is from Chrome manifest; extension ID is env var on backend only)
- [x] Existing design-system components used where possible (extension uses plain Tailwind — no design system library)
- [x] TypeScript strict mode compatibility verified (all changes are strictly typed)
- [x] architecture.md principles not violated:
  - Client-first processing preserved (PDF/Drive/autofill still in extension)
  - Zero file storage preserved (no server-side PDF storage)
  - Explicit user approval preserved (no change to approval flow)
  - Auth model matches §5 (Clerk middleware + backend guard + extension token)
---

## 9. Architect Review

## LLD Review: LLD-MVP-P04

**Verdict:** APPROVED

### Summary

The LLD is comprehensive, covers all P0 and P1 requirements from HLD-MVP-P04, and maintains full alignment with architecture.md principles. The function-level design, test specification, and integration sequencing are well-structured. A few minor gaps identified below should be addressed during the implementation step.

### Review Checklist

#### Completeness ✅
- [x] Every HLD P0/P1 requirement has a corresponding LLD specification (REQ-02-01 through REQ-02-11)
- [x] API contracts match — SAVE_APPLICATION updated with `drive_link?`, SESSION_EXPIRED message defined
- [x] Test cases cover all unit-testable acceptance criteria from HLD §8
- [x] Error cases defined for external calls (401 handling, audit insert failure, CORS rejection)
- [x] P2 items (REQ-02-12 through REQ-02-16) correctly excluded from LLD scope

#### Architecture Compliance ✅
- [x] Component boundaries match architecture.md §7 — all changes stay within their respective repos
- [x] Data flows match architecture.md §4 sequence diagrams — no new data paths introduced
- [x] Auth model matches architecture.md §5 — Clerk middleware + backend guard + extension token bridge
- [x] No server-side PDF/resume storage (zero storage principle maintained)
- [x] Client-first processing preserved (scraping, PDF, autofill remain in extension)

#### Security ✅
- [x] Input sanitization at boundaries — existing Zod schemas cover all API inputs
- [x] No PII in logs — audit_events stores only clerk_user_id + event_type
- [x] Secrets only in server env vars — CHROME_EXTENSION_ID on backend, VITE_GOOGLE_OAUTH_CLIENT_ID at build-time only
- [x] RLS implications addressed — audit_events intentionally has no RLS (service-role-only, append-only)
- [x] XSS: No new user-generated content rendering introduced

#### Code Quality ✅
- [x] Shared schemas used consistently (no type duplication)
- [x] Existing components preferred over new ones
- [x] TypeScript strict mode compatibility verified across all function signatures
- [x] No over-engineering beyond phase scope — implementations are minimal and focused

### Approved Items
- AD-01 public-route allowlist implementation (§3.1)
- AD-02 CORS restriction with env var + dev fallback (§3.2)
- AD-03 401 interceptor pattern including token clearance + message broadcast (§3.3)
- AD-04 Drive OAuth env substitution + drive_link pass-through (§3.4, §3.5)
- AD-05 Vitest configuration for all packages with Chrome mock utility (§1.3)
- AD-06 audit_events table with append-only, no-RLS design (§4.1, §4.2)
- AD-07 ErrorWithRetry pattern in popup (§6.1, §3.7)
- Full test specification for schemas, middleware, API client, service worker, PDF generator, web components (§5.1–§5.7)
- CI pipeline expansion (§1.7)
- Integration sequencing with 6 ordered phases (§7)

### Warnings for Implementation

| # | Section | Issue | Guidance | Severity |
|---|---------|-------|----------|----------|
| 1 | §5 | Missing extension popup test file for retry buttons (REQ-02-11 acceptance criteria: "Retry button re-triggers original operation") | Add test file `smart-apply-extension/test/popup-app.spec.tsx` with cases: render retry button on error, onClick re-dispatches message, SESSION_EXPIRED shows expire message | WARNING |
| 2 | §1 | `smart-apply-backend/test/cors.spec.ts` referenced in §5.8 but missing from File-Level Change Manifest | Add to §1.1 or §1.4 as CREATE | WARNING |
| 3 | §3.1 | `/not-found` added to public routes but not in HLD AD-01 target list | Reasonable addition — not-found page should be accessible without auth. Keep it. | INFO |
| 4 | §3.3 | No error handling if `chrome.runtime.sendMessage()` fails silently in the 401 path | The token clearance is the critical operation (popup already listens to storage changes). The sendMessage is best-effort UX. No change needed. | INFO |

### Notes for Implementation
- The warnings #1 and #2 are non-blocking — the Context Engineering Agent should include the missing test file and manifest entry in the IMPL prompt.
- The integration sequence in §7 is well-ordered. Security fixes (Phase 1) can all be parallelized. Test infrastructure (Phase 3) must complete before any test-writing phases.
- For Chrome mock setup (§2.2): the mock should use `vi.fn()` and be imported via Vitest's `setupFiles` config option to ensure it's available before all extension tests.
- For web component tests (§5.6): ensure Clerk context is mocked at the test-file level, not globally, to avoid interference between test suites.

---

## 10. Implementation Review — P04

**Date:** 2026-03-29  
**Verdict:** APPROVED_WITH_WARNINGS

### Test Results Summary

| Package | Tests | Status |
|:---|:---|:---|
| @smart-apply/shared | 16/16 | PASS |
| @smart-apply/api | 23/23 | PASS |
| @smart-apply/web | 10/10 | PASS |
| @smart-apply/extension | 17/17 | PASS |
| TypeScript (all 4) | 0 errors | PASS |

**Total: 66 tests passing, 0 failures, 4 packages typecheck clean.**

### Requirement Coverage

| REQ | Title | Priority | Status |
|:---|:---|:---|:---|
| REQ-02-01 | Fix Web Middleware Route Protection | P0 | **PASS** |
| REQ-02-02 | Restrict CORS to Specific Extension ID | P0 | **PASS** |
| REQ-02-03 | Complete Extension 401 Handling | P0 | **PASS** |
| REQ-02-04 | Complete Google Drive Integration | P0 | **PASS** |
| REQ-02-05 | Establish Test Frameworks for All Packages | P0 | **PASS** |
| REQ-02-06 | P0 Regression Test Suite | P1 | **PASS** |
| REQ-02-07 | Web Component Test Coverage | P1 | **NOT IMPLEMENTED** (W-01) |
| REQ-02-08 | Extension Service Worker & PDF Test Coverage | P1 | **PARTIAL** (W-02) |
| REQ-02-09 | Complete CI Pipeline Coverage | P1 | **PASS** |
| REQ-02-10 | Account Deletion Audit Log | P1 | **PASS** |
| REQ-02-11 | Extension Error State Retry Buttons | P1 | **PASS** |
| REQ-02-12 – REQ-02-16 | P2 Items | P2 | **DEFERRED** (intentional) |

### Warnings

| # | Severity | Issue | Recommendation |
|:---|:---|:---|:---|
| W-01 | Medium | Web component tests (REQ-02-07) — 5 test files not created | Add before beta gate. Test framework is ready. |
| W-02 | Low | `pdf-generator.spec.ts` not created (REQ-02-08 partial) | Add for full LLD §5.5 coverage. |
| W-03 | Low | `service-worker.spec.ts` missing OPTIMIZE_JD handler tests (3 cases from LLD §5.4) | Extend existing file. |
| W-04 | Low | `webhooks.controller.spec.ts` not extended with audit_events assertions (LLD §5.7) | Add 3 audit-specific test cases. |
| W-05 | Low | `cors.spec.ts` not created (LLD §5.8, 6 cases) | Add for CORS restriction unit coverage. |

### Security Assessment

- **REQ-02-01 (Route Protection):** Correct. Public-route allowlist with `auth.protect()` on all others.
- **REQ-02-02 (CORS):** Correct. 3-tier origin check: exact ID → dev fallback → reject. Implementation stricter than HLD (good).
- **REQ-02-03 (401 Interceptor):** Correct. Clear token → broadcast → throw.
- **REQ-02-10 (Audit Log):** Correct. Best-effort insert, does not block deletion path.

### Recommendation

All P0 security requirements are fully and correctly implemented. Core test infrastructure and regression suites are in place. CI pipeline covers the full build/test matrix. The implementation is approved for merge.

Before declaring beta-ready, address W-01 (web component tests) as the highest priority gap.