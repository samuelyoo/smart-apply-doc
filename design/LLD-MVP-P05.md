---
title: "LLD-MVP-P05 — Test Coverage Completion"
permalink: /design/lld-mvp-p05/
---

# LLD-MVP-P05 — Test Coverage Completion

**Version:** 1.0  
**Date:** 2026-03-29  
**Phase:** Test Coverage Completion  
**Source:** HLD-MVP-P05.md, BRD-MVP-03.md  
**Prerequisite:** HLD-MVP-P05 approved.

---

## 1. File-Level Change Manifest

### 1.1 Web Component Tests (REQ-03-01 through REQ-03-05)

| File | Action | Est. Lines | Dependencies |
|:---|:---|:---|:---|
| `smart-apply-web/test/components/optimize-form.spec.tsx` | **CREATE** | ~90 | vitest, @testing-library/react, optimize-form.tsx |
| `smart-apply-web/test/components/optimize-results.spec.tsx` | **CREATE** | ~110 | vitest, @testing-library/react, optimize-results.tsx |
| `smart-apply-web/test/components/dashboard-shell.spec.tsx` | **CREATE** | ~70 | vitest, @testing-library/react, dashboard-shell.tsx |
| `smart-apply-web/test/components/profile-editor.spec.tsx` | **CREATE** | ~80 | vitest, @testing-library/react, profile-editor.tsx |
| `smart-apply-web/test/components/settings-page.spec.tsx` | **CREATE** | ~85 | vitest, @testing-library/react, settings-page.tsx |

### 1.2 Extension Tests (REQ-03-06, REQ-03-07)

| File | Action | Est. Lines | Dependencies |
|:---|:---|:---|:---|
| `smart-apply-extension/test/pdf-generator.spec.ts` | **CREATE** | ~60 | vitest, pdf-lib (transitive via pdf-generator.ts) |
| `smart-apply-extension/test/service-worker.spec.ts` | **MODIFY** | +40 | vitest, existing mocks |

### 1.3 Backend Tests (REQ-03-08, REQ-03-09)

| File | Action | Est. Lines | Dependencies |
|:---|:---|:---|:---|
| `smart-apply-backend/test/webhooks.controller.spec.ts` | **MODIFY** | +30 | vitest, existing mocks |
| `smart-apply-backend/test/cors.spec.ts` | **CREATE** | ~70 | vitest |
| `smart-apply-backend/src/cors.ts` | **CREATE** | ~25 | none (pure function) |
| `smart-apply-backend/src/main.ts` | **MODIFY** | ~5 changed | cors.ts import |

---

## 2. Interface & Type Definitions

No new interfaces or types. All tests consume existing component props, function signatures, and shared types.

### Shared Types Referenced by Tests

| Type | Package | Used By |
|:---|:---|:---|
| `OptimizeResponse` | @smart-apply/shared | optimize-form.spec, optimize-results.spec |
| `SuggestedChange` | @smart-apply/shared | optimize-results.spec |
| `MasterProfile` | @smart-apply/shared | optimize-results.spec, profile-editor.spec |
| `ListApplicationsResponse` | @smart-apply/shared | dashboard-shell.spec |
| `UpdateProfileRequest` | @smart-apply/shared | profile-editor.spec |

### New Exported Function (cors.ts)

```typescript
export function validateCorsOrigin(
  origin: string | undefined,
  allowedOrigins: string[],
  extensionId: string | undefined,
  isProd: boolean,
): { allowed: boolean; error?: string };
```

---

## 3. Function-Level Design

### 3.1 validateCorsOrigin (NEW — smart-apply-backend/src/cors.ts)

```
Function: validateCorsOrigin
Input: origin (string | undefined), allowedOrigins (string[]), extensionId (string | undefined), isProd (boolean)
Output: { allowed: boolean; error?: string }
Logic:
  1. If !origin → { allowed: true } (same-origin / server-to-server)
  2. If allowedOrigins includes origin → { allowed: true }
  3. If extensionId exists AND origin === `chrome-extension://${extensionId}` → { allowed: true }
  4. If !isProd AND !extensionId AND origin matches /^chrome-extension:\/\// → { allowed: true }
  5. Otherwise → { allowed: false, error: 'CORS not allowed' }
Side Effects: None (pure function)
```

---

## 4. Database Operations

None. No database changes in this phase.

---

## 5. Test Specification

### 5.1 OptimizeForm Tests — `smart-apply-web/test/components/optimize-form.spec.tsx`

**Component Under Test:** `OptimizeForm` from `../../src/components/optimize/optimize-form`

**Mock Strategy:**
- `@clerk/nextjs` → `useAuth()` returns `{ getToken: vi.fn().mockResolvedValue('test-token') }`
- `@/lib/api-client` → `apiFetch` as `vi.fn()`

```
Suite: OptimizeForm
│
├─ it("renders JD textarea and submit button")
│    Arrange: render <OptimizeForm />
│    Assert: textarea with placeholder "Paste the full job description here..." visible
│    Assert: button "Optimize Resume" visible
│
├─ it("submits JD text to optimize API")
│    Arrange: render, fill company, title, JD (≥50 chars)
│    Act: click "Optimize Resume"
│    Assert: apiFetch called with '/api/optimize', token, { method: 'POST', body containing jdText }
│
├─ it("shows loading state during submission")
│    Arrange: apiFetch returns pending promise
│    Act: fill form, click submit
│    Assert: button text is "Optimizing..."
│    Assert: button is disabled
│
└─ it("shows error message on API failure")
     Arrange: apiFetch rejects with Error('Server error')
     Act: fill form, click submit, await
     Assert: text "Server error" visible in red error div
```

### 5.2 OptimizeResults Tests — `smart-apply-web/test/components/optimize-results.spec.tsx`

**Component Under Test:** `OptimizeResults` from `../../src/components/optimize/optimize-results`

**Mock Strategy:**
- Same as 5.1 plus `@tanstack/react-query` `useQuery` for profile fetch
- Profile query returns mock `MasterProfile`

**Fixture:**
```typescript
const mockResult: OptimizeResponse = {
  ats_score_before: 45,
  ats_score_after: 82,
  extracted_requirements: { hard_skills: ['TypeScript'], soft_skills: ['leadership'], certifications: [] },
  optimized_resume_json: { summary: 'Optimized summary', skills: ['TypeScript', 'React'], experiences: [], warnings: [] },
  suggested_changes: [
    { type: 'summary_update', target_section: 'summary', before: 'Old summary', after: 'New summary', reason: 'Better keywords', confidence: 0.9 },
    { type: 'skills_insertion', target_section: 'skills', before: null, after: 'React, TypeScript', reason: 'Missing skills', confidence: 0.7 },
    { type: 'warning', target_section: 'warning', before: null, after: null, reason: 'Company uses ATS filter', confidence: null },
  ],
};
```

```
Suite: OptimizeResults
│
├─ it("displays before and after ATS scores")
│    Arrange: render <OptimizeResults result={mockResult} companyName="Acme" onBack={vi.fn()} />
│    Assert: text "45%" and "82%" visible
│
├─ it("renders suggested changes with checkboxes")
│    Arrange: render with mockResult
│    Assert: checkboxes present for non-warning changes
│    Assert: checkbox count equals 2 (summary_update + skills_insertion)
│
├─ it("toggles change selection on click")
│    Arrange: render, find first checkbox
│    Act: click checkbox
│    Assert: checked state toggles
│
├─ it("displays warning messages")
│    Arrange: render with mockResult containing warning type
│    Assert: text "Company uses ATS filter" visible in warning div
│
└─ it("renders confidence badges")
     Arrange: render with mockResult
     Assert: badge with "90%" visible
     Assert: badge with "70%" visible
```

### 5.3 DashboardShell Tests — `smart-apply-web/test/components/dashboard-shell.spec.tsx`

**Component Under Test:** `DashboardShell` from `../../src/components/dashboard/dashboard-shell`

**Mock Strategy:**
- `@clerk/nextjs` → `useAuth()` returns `{ getToken: vi.fn().mockResolvedValue('test-token') }`
- `@/lib/api-client` → `apiFetch` as `vi.fn()`
- Wrap in `QueryClientProvider`

```
Suite: DashboardShell
│
├─ it("fetches and renders application history")
│    Arrange: apiFetch resolves with { items: [{ company_name: 'Acme', job_title: 'Engineer', ... }] }
│    Act: render, wait for query to resolve
│    Assert: text "Acme" visible
│
├─ it("shows empty state when no applications")
│    Arrange: apiFetch resolves with { items: [] }
│    Act: render, wait for query to resolve
│    Assert: text "No applications yet." visible
│
└─ it("shows loading state while fetching")
     Arrange: fetch returns pending promise
     Act: render
     Assert: text "Loading applications..." visible
```

### 5.4 ProfileEditor Tests — `smart-apply-web/test/components/profile-editor.spec.tsx`

**Component Under Test:** `ProfileEditor` from `../../src/components/profile/profile-editor`

**Mock Strategy:**
- `@clerk/nextjs` → `useAuth()` with getToken
- `@/lib/api-client` → `apiFetch` as `vi.fn()`
- Wrap in `QueryClientProvider`

**Fixture:**
```typescript
const mockProfile: Partial<MasterProfile> = {
  full_name: 'Jane Doe',
  email: 'jane@example.com',
  phone: '555-0100',
  location: 'San Francisco, CA',
  summary: 'Experienced engineer',
  base_skills: ['TypeScript', 'React'],
  experiences: [],
  education: [],
  certifications: [],
};
```

```
Suite: ProfileEditor
│
├─ it("loads and displays profile data")
│    Arrange: fetch /api/profile/me returns mockProfile
│    Act: render, wait for query to resolve
│    Assert: text "Jane Doe" visible
│    Assert: text "jane@example.com" visible
│
├─ it("submits updated profile on save")
│    Arrange: render, wait for load, click "Edit Profile"
│    Act: change full_name input, click "Save Changes"
│    Assert: apiFetch called with '/api/profile/me', token, { method: 'PATCH', body containing updated data }
│
└─ it("shows validation errors on invalid input")
     Arrange: render, click "Edit Profile"
     Act: clear required field, submit form
     Assert: error message visible (form validation from Zod resolver)
```

### 5.5 SettingsPage Tests — `smart-apply-web/test/components/settings-page.spec.tsx`

**Component Under Test:** `SettingsPage` from `../../src/components/settings/settings-page`

**Mock Strategy:**
- `@clerk/nextjs` → `useUser()` returns `{ user: { fullName, primaryEmailAddress, createdAt } }`, `useAuth()` returns `{ getToken, signOut }`
- `@/lib/api-client` → `apiFetch` as `vi.fn()`

```
Suite: SettingsPage
│
├─ it("displays account information")
│    Arrange: render with mocked user
│    Assert: text user.fullName visible
│    Assert: text user email visible
│
├─ it("shows delete confirmation dialog on button click")
│    Arrange: render
│    Act: click "Delete Account" button
│    Assert: confirmation text visible (Type DELETE to confirm)
│    Assert: "Permanently Delete Account" button visible and disabled
│
├─ it("enables confirm button when DELETE is typed")
│    Arrange: render, open delete dialog
│    Act: type "DELETE" in confirmation input
│    Assert: "Permanently Delete Account" button is NOT disabled
│
└─ it("calls delete API and signs out on confirm")
     Arrange: render, open dialog, type DELETE
     Act: click "Permanently Delete Account"
     Assert: apiFetch called with '/api/account', token, { method: 'DELETE' }
     Assert: signOut called
```

### 5.6 PDF Generator Tests — `smart-apply-extension/test/pdf-generator.spec.ts`

**Function Under Test:** `generateResumePDF` from `../../src/lib/pdf-generator`

**Mock Strategy:** None needed — pdf-lib runs in Node.

**Fixture:**
```typescript
const validInput = {
  name: 'John Doe',
  email: 'john@example.com',
  phone: '555-0100',
  summary: 'Experienced full-stack developer.',
  experience: [
    { title: 'Engineer', company: 'Acme', dates: '2020-2023', bullets: ['Built APIs', 'Led team'] },
  ],
  skills: ['TypeScript', 'React', 'Node.js'],
};
```

```
Suite: generateResumePDF
│
├─ it("produces non-empty Uint8Array for valid input")
│    Act: const result = await generateResumePDF(validInput)
│    Assert: result instanceof Uint8Array
│    Assert: result.length > 0
│
├─ it("produces valid PDF header bytes")
│    Act: const result = await generateResumePDF(validInput)
│    Assert: new TextDecoder().decode(result.slice(0, 5)) === '%PDF-'
│
├─ it("handles empty experience array")
│    Act: await generateResumePDF({ ...validInput, experience: [] })
│    Assert: does not throw
│    Assert: result.length > 0
│
└─ it("handles empty skills array")
     Act: await generateResumePDF({ ...validInput, skills: [] })
     Assert: does not throw
     Assert: result.length > 0
```

### 5.7 OPTIMIZE_JD Handler Tests — extend `smart-apply-extension/test/service-worker.spec.ts`

**Handler Under Test:** OPTIMIZE_JD case in onMessage listener

**Mock Strategy:** Uses existing `mockApiFetch`, `mockSetStorage` from same file.

```
Suite: OPTIMIZE_JD (new describe block in existing file)
│
├─ it("calls /api/optimize with JD payload")
│    Arrange: mockApiFetch resolves with { ats_score_before: 45, ats_score_after: 85, ... }
│    Act: send { type: 'OPTIMIZE_JD', payload: { jdText, company, jobTitle, sourceUrl } }
│    Assert: mockApiFetch called with '/api/optimize', { method: 'POST', body containing jdText }
│
├─ it("stores optimize context in storage on success")
│    Arrange: mockApiFetch resolves
│    Act: send OPTIMIZE_JD message
│    Assert: mockSetStorage called with 'last_optimize_context', containing { company, jobTitle }
│    Assert: mockSetStorage called with 'last_optimized_at'
│
└─ it("returns { success: true, data } on success")
     Arrange: mockApiFetch resolves with mockOptimizeResult
     Act: send OPTIMIZE_JD message
     Assert: response.success === true
     Assert: response.data matches mockOptimizeResult
```

### 5.8 Webhook Audit Tests — extend `smart-apply-backend/test/webhooks.controller.spec.ts`

**Service Under Test:** `WebhooksService.handleClerkWebhook` → `handleUserDeleted`

**Mock Strategy:** Uses existing mockSupabase. Verify `from('audit_events').insert()` calls.

```
Suite: Webhook Audit Events (new describe block in existing file)
│
├─ it("inserts audit_events row after user deletion")
│    Arrange: verify mock, set up from().insert/delete chains
│    Act: send user.deleted webhook
│    Assert: mockSupabase.admin.from called with 'audit_events'
│    Assert: insert called with { clerk_user_id, event_type: 'user.deleted', metadata: {} }
│
├─ it("audit event contains clerk_user_id and event_type")
│    Arrange: same as above
│    Act: send user.deleted webhook
│    Assert: insert arg matches { clerk_user_id: 'user_to_delete', event_type: 'user.deleted' }
│
└─ it("does not block deletion if audit insert fails")
     Arrange: mock insert to return { error: { message: 'DB error' } }
     Act: send user.deleted webhook
     Assert: controller returns { received: true } (no throw)
     Assert: delete still called on master_profiles
```

### 5.9 CORS Restriction Tests — `smart-apply-backend/test/cors.spec.ts`

**Function Under Test:** `validateCorsOrigin` from `../../src/cors`

**Mock Strategy:** None — pure function.

```
Suite: validateCorsOrigin
│
├─ it("allows requests from configured web origin")
│    Act: validateCorsOrigin('http://localhost:3000', ['http://localhost:3000'], undefined, false)
│    Assert: { allowed: true }
│
├─ it("allows configured chrome extension ID")
│    Act: validateCorsOrigin('chrome-extension://abcdef123', [], 'abcdef123', true)
│    Assert: { allowed: true }
│
├─ it("rejects unknown chrome extension")
│    Act: validateCorsOrigin('chrome-extension://unknown', [], 'abcdef123', true)
│    Assert: { allowed: false }
│
├─ it("allows any extension in dev mode without CHROME_EXTENSION_ID")
│    Act: validateCorsOrigin('chrome-extension://anything', [], undefined, false)
│    Assert: { allowed: true }
│
├─ it("rejects extensions in production without CHROME_EXTENSION_ID")
│    Act: validateCorsOrigin('chrome-extension://anything', [], undefined, true)
│    Assert: { allowed: false }
│
└─ it("allows same-origin (null/undefined origin)")
     Act: validateCorsOrigin(undefined, ['http://localhost:3000'], undefined, true)
     Assert: { allowed: true }
```

---

## 6. Component Design (UI Files)

No UI components created or modified. All work in this phase is test files.

---

## 7. Integration Sequence

### Implementation Order

1. **Phase 1 — Backend CORS extraction** (REQ-03-09)
   - Create `cors.ts` with `validateCorsOrigin()`
   - Modify `main.ts` to import and use it
   - Create `cors.spec.ts`
   - Verify: `npm test` in backend — all 23 existing + 6 new pass

2. **Phase 2 — Backend webhook audit tests** (REQ-03-08)
   - Extend `webhooks.controller.spec.ts` with 3 audit tests
   - Verify: `npm test` in backend — 23 + 6 + 3 = 32 pass

3. **Phase 3 — Extension PDF generator tests** (REQ-03-06)
   - Create `pdf-generator.spec.ts`
   - Verify: `npm test` in extension — 17 existing + 4 new = 21 pass

4. **Phase 4 — Extension OPTIMIZE_JD tests** (REQ-03-07)
   - Add OPTIMIZE_JD describe block to `service-worker.spec.ts`
   - Verify: `npm test` in extension — 21 + 3 = 24 pass

5. **Phase 5 — Web component tests** (REQ-03-01 through REQ-03-05)
   - Create all 5 test files in order: dashboard-shell → settings-page → profile-editor → optimize-form → optimize-results
   - (Simplest components first to validate mock setup, complex ones last)
   - Verify after each: `npm test` in web
   - Final: 10 existing + 19 new = 29 pass

6. **Phase 6 — Full suite verification**
   - Run all packages: total ≥ 101 tests
   - TypeScript: all 4 packages clean
   - CI dry-run confirmation

---

## 8. Alignment Checklist

- [x] No production code changes except CORS extraction (minimal, behavior-preserving)
- [x] All API inputs validated with Zod at boundaries (no new APIs)
- [x] Loading/error/empty states tested in UI components
- [x] TypeScript strict mode — no `any`, no `@ts-ignore` in test files
- [x] Shared schemas used for test fixtures, no type duplication
- [x] Existing components and patterns reused (mock setup matches P04 tests)
- [x] architecture.md principles not violated (no new data flows, no storage changes)

---

## 9. Architect Review

| Round | Verdict | Date |
|-------|---------|------|
| R1 | REVISE | 2025-01-27 |
| R2 | APPROVED | 2025-01-27 |

### R1 Findings (REVISE)

**BLOCKING Issues (3):**

| ID | Section | Issue | Resolution |
|----|---------|-------|------------|
| B-01 | §5.2 | `SuggestedChange` fixture missing required `target_section` field | Added `target_section: 'experience'` to fixture |
| B-02 | §5.2 | `OptimizeResponse` fixture missing `extracted_requirements` field | Added `extracted_requirements: { hard_skills: ['React'], soft_skills: ['teamwork'], certifications: [] }` |
| B-03 | §5.2 | `optimized_resume_json: {}` does not satisfy `OptimizedResume` type | Replaced with full `OptimizedResume` object: `{ summary, skills, experiences, warnings }` |

**WARNING Issues (5):**

| ID | Section | Issue | Resolution |
|----|---------|-------|------------|
| W-01 | §5.1 | Listed `next/navigation` mock but OptimizeForm doesn't import it | Removed from mock strategy |
| W-02 | §5.1 | Listed `QueryClientProvider` but OptimizeForm doesn't use TanStack Query | Removed from mock strategy |
| W-03 | §5.1–§5.5 | Inconsistent mock strategy — some specs mocked `global.fetch`, others `@/lib/api-client` | Standardized all web tests to mock `@/lib/api-client` → `apiFetch` |
| W-04 | §5.1 | Placeholder text "Paste the full job description" doesn't match actual "Paste the full job description here..." | Fixed to match actual component text |
| W-05 | §5.3 | Empty-state text missing trailing period vs actual "No applications yet." | Fixed to include trailing period |

### R2 Verdict: APPROVED

All 3 blocking issues and 5 warnings resolved. LLD is ready for implementation.
