---
title: "LLD-TEST-P02 — Controllers, Components & Popup UI (Detailed Design)"
permalink: /design/lld-test-p02/
---

# LLD-TEST-P02 — Controllers, Components & Popup UI (Detailed Design)

**Phase:** Test Enhancement Phase 2 — Controllers, Components & Popup UI
**Version:** 1.0
**Date:** 2026-03-30
**Input:** HLD-TEST-P02.md + architecture.md + BRD_enhance_unit_test_phase2_2026-03-30.md

---

## 1. File-Level Change Manifest

| # | File | Action | Purpose |
|---|---|---|---|
| 1 | `smart-apply-backend/test/profiles.controller.spec.ts` | CREATE | ~5 tests for profiles controller endpoints + guard |
| 2 | `smart-apply-backend/test/applications.controller.spec.ts` | CREATE | ~5 tests for applications controller endpoints + guard |
| 3 | `smart-apply-backend/test/optimize.controller.spec.ts` | CREATE | ~3 tests for optimize controller endpoint + guard |
| 4 | `smart-apply-backend/test/health.controller.spec.ts` | CREATE | ~2 tests for health controller |
| 5 | `smart-apply-backend/test/account.controller.spec.ts` | CREATE | ~3 tests for account controller endpoint + guard |
| 6 | `smart-apply-web/test/api-client.spec.ts` | CREATE | ~6 tests for apiFetch with mocked global fetch |
| 7 | `smart-apply-web/test/components/profile-upload.spec.tsx` | CREATE | ~7 tests for profile upload component |
| 8 | `smart-apply-web/test/components/applications-table.spec.tsx` | CREATE | ~4 tests for applications table component |
| 9 | `smart-apply-web/test/components/stats-cards.spec.tsx` | CREATE | ~4 tests for stats cards component |
| 10 | `smart-apply-web/test/components/profile-editor.spec.tsx` | MODIFY | +6 tests for form handlers, skill/field operations, save mutation |
| 11 | `smart-apply-web/test/components/dashboard-shell.spec.tsx` | MODIFY | +4 tests for view toggle, status mutation, error state |
| 12 | `smart-apply-web/test/components/settings-page.spec.tsx` | MODIFY | +2 tests for delete error, deleting state |
| 13 | `smart-apply-extension/test/app.spec.tsx` | CREATE | ~14 tests for popup App.tsx 5-screen state machine |
| 14 | `smart-apply-web/vitest.config.ts` | MODIFY | Add coverage.exclude for page.tsx, layout.tsx, providers.tsx |

---

## 2. Detailed Design Per File

### 2.1 Backend: `profiles.controller.spec.ts` (REQ-P2-01)

**Mock strategy:**
- Create NestJS `Test.createTestingModule` with `ProfilesController` and mocked `ProfilesService`.
- Override `ClerkAuthGuard` with a mock that sets `request.userId`.
- Use `@CurrentUserId()` decorator by setting `userId` on the request object.

**File structure:**

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Test } from '@nestjs/testing';
import { UnauthorizedException } from '@nestjs/common';
import { ProfilesController } from '../src/modules/profiles/profiles.controller';
import { ProfilesService } from '../src/modules/profiles/profiles.service';
import { ClerkAuthGuard } from '../src/modules/auth/clerk-auth.guard';

const mockProfilesService = {
  getProfile: vi.fn(),
  ingestProfile: vi.fn(),
  updateProfile: vi.fn(),
};

// Guard mock that passes and sets userId
const mockGuardPass = { canActivate: vi.fn((ctx) => {
  const req = ctx.switchToHttp().getRequest();
  req.userId = 'test-user-id';
  return true;
}) };

// Guard mock that rejects
const mockGuardReject = { canActivate: vi.fn(() => {
  throw new UnauthorizedException();
}) };
```

**Test cases (5 tests):**

| # | it | Setup | Assertion |
|---|---|---|---|
| 1 | `getProfile returns profile from service` | `mockProfilesService.getProfile.mockResolvedValue(profileFixture)` | Controller returns profile; service called with `'test-user-id'` |
| 2 | `ingestProfile calls service with userId and body` | `mockProfilesService.ingestProfile.mockResolvedValue({ success: true, profile: profileFixture })` | Controller returns result; service called with `('test-user-id', body)` |
| 3 | `updateProfile calls service with userId and body` | `mockProfilesService.updateProfile.mockResolvedValue(profileFixture)` | Controller returns result; service called with `('test-user-id', body)` |
| 4 | `rejects unauthenticated request` | Override guard with `mockGuardReject` | Calling any endpoint throws `UnauthorizedException` |
| 5 | `getProfile returns null when profile not found` | `mockProfilesService.getProfile.mockResolvedValue(null)` | Controller returns `null` |

**Implementation note:** Since `@CurrentUserId()` is a parameter decorator that reads `request.userId`, and the guard sets `request.userId`, we test the controller methods directly passing userId. For the guard rejection test, we create a separate test module with the rejecting guard.

---

### 2.2 Backend: `applications.controller.spec.ts` (REQ-P2-01)

**Mock strategy:** Same pattern as profiles — mocked `ApplicationsService` + guard override.

```typescript
const mockApplicationsService = {
  list: vi.fn(),
  create: vi.fn(),
  updateStatus: vi.fn(),
};
```

**Test cases (5 tests):**

| # | it | Setup | Assertion |
|---|---|---|---|
| 1 | `list returns applications from service` | `mockApplicationsService.list.mockResolvedValue({ items: [appFixture] })` | Returns `{ items: [...] }`; service called with `'test-user-id'` |
| 2 | `create calls service with userId and body` | `mockApplicationsService.create.mockResolvedValue(appFixture)` | Returns result; service called with `('test-user-id', body)` |
| 3 | `updateStatus calls service with userId, id, and body` | `mockApplicationsService.updateStatus.mockResolvedValue(appFixture)` | Returns result; service called with `('test-user-id', 'app-1', body)` |
| 4 | `rejects unauthenticated request` | Override guard with rejecting mock | Throws `UnauthorizedException` |
| 5 | `list returns empty items when user has no applications` | `mockApplicationsService.list.mockResolvedValue({ items: [] })` | Returns `{ items: [] }` |

---

### 2.3 Backend: `optimize.controller.spec.ts` (REQ-P2-01)

**Mock strategy:** Mocked `OptimizeService` + guard override.

```typescript
const mockOptimizeService = {
  optimize: vi.fn(),
};
```

**Test cases (3 tests):**

| # | it | Setup | Assertion |
|---|---|---|---|
| 1 | `optimize calls service with userId and body` | `mockOptimizeService.optimize.mockResolvedValue(optimizeResultFixture)` | Returns result; service called with `('test-user-id', body)` |
| 2 | `rejects unauthenticated request` | Override guard with rejecting mock | Throws `UnauthorizedException` |
| 3 | `propagates service errors` | `mockOptimizeService.optimize.mockRejectedValue(new Error('Job description too short'))` | Throws the error |

---

### 2.4 Backend: `health.controller.spec.ts` (REQ-P2-01)

**Mock strategy:** No dependencies — direct instantiation. No guard to test.

```typescript
import { HealthController } from '../src/modules/health/health.controller';
```

**Test cases (2 tests):**

| # | it | Setup | Assertion |
|---|---|---|---|
| 1 | `check returns ok status with ISO timestamp` | None | Returns `{ status: 'ok', timestamp }` where timestamp is valid ISO string |
| 2 | `timestamp is close to current time` | Freeze time with `vi.useFakeTimers` | Returned timestamp matches expected time |

---

### 2.5 Backend: `account.controller.spec.ts` (REQ-P2-01)

**Mock strategy:** Mocked `AccountService`. Note: `@UseGuards(ClerkAuthGuard)` is on the method level, not class level.

```typescript
const mockAccountService = {
  deleteAccount: vi.fn(),
};
```

**Test cases (3 tests):**

| # | it | Setup | Assertion |
|---|---|---|---|
| 1 | `deleteAccount calls service and returns success` | `mockAccountService.deleteAccount.mockResolvedValue(undefined)` | Returns `{ success: true }`; service called with `'test-user-id'` |
| 2 | `rejects unauthenticated request` | Override guard with rejecting mock | Throws `UnauthorizedException` |
| 3 | `propagates service errors` | `mockAccountService.deleteAccount.mockRejectedValue(new Error('Clerk error'))` | Throws error |

---

### 2.6 Web: `api-client.spec.ts` (REQ-P2-02)

**Mock strategy:** `vi.stubGlobal('fetch', mockFetch)` to control all fetch behavior.

```typescript
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { apiFetch } from '@/lib/api-client';

const mockFetch = vi.fn();

beforeEach(() => {
  vi.stubGlobal('fetch', mockFetch);
});

afterEach(() => {
  vi.unstubAllGlobals();
});
```

**Test cases (6 tests):**

| # | it | Setup | Assertion |
|---|---|---|---|
| 1 | `returns parsed JSON on success` | `mockFetch.mockResolvedValue({ ok: true, json: () => Promise.resolve({ data: 'test' }) })` | Returns `{ data: 'test' }` |
| 2 | `sends Authorization header with Bearer token` | Successful response mock | `fetch` called with headers containing `Authorization: 'Bearer test-token'` |
| 3 | `sends Content-Type application/json` | Successful response mock | `fetch` called with headers containing `Content-Type: 'application/json'` |
| 4 | `throws with server error message on 401` | `mockFetch.mockResolvedValue({ ok: false, status: 401, json: () => Promise.resolve({ message: 'Unauthorized' }) })` | Throws `Error('Unauthorized')` |
| 5 | `throws with status fallback when response has no message` | `mockFetch.mockResolvedValue({ ok: false, status: 500, json: () => Promise.reject() })` | Throws `Error('API error: 500')` |
| 6 | `merges custom options with defaults` | Request with `{ method: 'POST', body: JSON.stringify({}) }` | `fetch` called with merged options including method and body |

---

### 2.7 Web: `profile-upload.spec.tsx` (REQ-P2-03)

**Mock strategy:**
- `vi.mock('@clerk/nextjs')` → `useAuth` returns `{ getToken: vi.fn() }`
- `vi.mock('@tanstack/react-query')` → `useQueryClient` returns `{ invalidateQueries: vi.fn() }`
- `vi.mock('@/lib/api-client')` → `apiFetch` mock
- `vi.mock('pdfjs-dist')` → mock PDF extraction pipeline

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

const mockGetToken = vi.fn().mockResolvedValue('test-token');
vi.mock('@clerk/nextjs', () => ({
  useAuth: () => ({ getToken: mockGetToken }),
}));

const mockInvalidateQueries = vi.fn();
vi.mock('@tanstack/react-query', () => ({
  useQueryClient: () => ({ invalidateQueries: mockInvalidateQueries }),
}));

const mockApiFetch = vi.fn();
vi.mock('@/lib/api-client', () => ({
  apiFetch: (...args: unknown[]) => mockApiFetch(...args),
}));

import { ProfileUpload } from '../../src/components/profile/profile-upload';
```

**Test cases (7 tests):**

| # | it | Setup | Assertion |
|---|---|---|---|
| 1 | `renders idle state with upload and paste options` | None | "Choose File" button and "Paste Resume Text" button visible |
| 2 | `switches to paste mode and shows textarea` | Click "Paste Resume Text" | Textarea with "Paste your resume text here..." placeholder visible |
| 3 | `paste submit calls API and shows success` | Enter >10 chars in textarea, click "Import Text" | `mockApiFetch` called with `/api/profile/ingest`, shows success message |
| 4 | `paste submit disabled for short text` | Enter <10 chars | "Import Text" button is disabled |
| 5 | `file upload triggers ingestion for text file` | Create `File` object, fire change event on hidden input | `mockApiFetch` called with extracted text |
| 6 | `shows error for file over 5MB` | Create `File` with size >5MB | Error message "File size must be under 5MB" visible |
| 7 | `shows success and invalidates profile query` | Successful paste submit | Success message visible; `mockInvalidateQueries` called with `{ queryKey: ['profile'] }` |

---

### 2.8 Web: `applications-table.spec.tsx` (REQ-P2-03)

**Mock strategy:** Pure presentational component — no mocks needed. Pass props directly.

```typescript
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { ApplicationsTable } from '../../src/components/dashboard/applications-table';
import type { ApplicationHistoryItem } from '@smart-apply/shared';

const mockItems: ApplicationHistoryItem[] = [
  {
    id: '1',
    company_name: 'Acme Corp',
    job_title: 'Software Engineer',
    status: 'applied',
    ats_score_before: 65,
    ats_score_after: 85,
    applied_at: '2024-06-15T00:00:00Z',
    // ... other required fields
  },
  {
    id: '2',
    company_name: 'Globex Inc',
    job_title: 'Frontend Dev',
    status: 'interviewing',
    ats_score_before: null,
    ats_score_after: null,
    applied_at: '2024-07-01T00:00:00Z',
  },
];
```

**Test cases (4 tests):**

| # | it | Setup | Assertion |
|---|---|---|---|
| 1 | `renders table rows with application data` | Render with `mockItems` | Company names and job titles visible |
| 2 | `displays correct status badges` | Render with items of different statuses | Badges with matching text ("applied", "interviewing") are present |
| 3 | `formats dates correctly` | Render with items | Date column shows locale-formatted dates |
| 4 | `shows dash for null ATS scores` | Render with item having null scores | `—` displays in ATS columns |

---

### 2.9 Web: `stats-cards.spec.tsx` (REQ-P2-03)

**Mock strategy:** Pure presentational — pass props directly.

```typescript
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { StatsCards } from '../../src/components/dashboard/stats-cards';
```

**Test cases (4 tests):**

| # | it | Setup | Assertion |
|---|---|---|---|
| 1 | `renders all 4 stat card labels` | Render with items | "Total Applications", "Applied", "Interviewing", "Avg ATS Improvement" visible |
| 2 | `calculates correct counts` | 3 items: 2 applied, 1 interviewing | "Total Applications" shows 3, "Applied" shows 2, "Interviewing" shows 1 |
| 3 | `calculates average ATS improvement` | Items with before/after scores | Shows expected improvement percentage |
| 4 | `shows zero values for empty list` | Render with `[]` | "0" for counts, "+0%" for improvement |

---

### 2.10 Web: `profile-editor.spec.tsx` — Extensions (REQ-P2-04)

**Add 6 new tests to the existing describe block, after current 3 tests:**

| # | it | Setup | Assertion |
|---|---|---|---|
| 4 | `adds a skill in edit mode` | Enter edit mode, type skill name, click Add | New skill badge appears |
| 5 | `removes a skill by clicking it` | Enter edit mode, click existing skill badge | Skill removed from list |
| 6 | `adds an experience entry` | Enter edit mode, click "+ Add" on Experience section | New empty experience fields appear |
| 7 | `removes an experience entry` | Enter edit mode with existing experience, click Remove | Experience entry removed |
| 8 | `save mutation calls API with form data` | Enter edit mode, click Save Changes | `mockApiFetch` called with PATCH method and form body |
| 9 | `cancel resets form and exits edit mode` | Enter edit mode, modify a field, click Cancel | Returns to view mode with original data |

**Mock additions needed:**
- Current mock setup already has `mockApiFetch` and `mockGetToken`
- `useForm` already provided by the actual component — no mock needed
- `useMutation` and `useQueryClient` handled by wrapping in `QueryClientProvider`

---

### 2.11 Web: `dashboard-shell.spec.tsx` — Extensions (REQ-P2-04)

**Add 4 new tests to the existing describe block, after current 3 tests:**

| # | it | Setup | Assertion |
|---|---|---|---|
| 4 | `toggles view mode between table and pipeline` | Render with data, click "Pipeline" button | Pipeline view renders; localStorage updated |
| 5 | `persists view mode in localStorage` | Set localStorage to 'pipeline', re-render | Pipeline view is selected initially |
| 6 | `renders error state when query fails` | `mockApiFetch.mockRejectedValue(new Error('Network error'))` | Error message "Failed to load applications: Network error" visible |
| 7 | `status mutation updates application status` | Render, find status change trigger (if exposed by mocked children) | `mockApiFetch` called with PATCH and new status |

**Mock additions needed:**
- `vi.spyOn(Storage.prototype, 'setItem')` and `vi.spyOn(Storage.prototype, 'getItem')` for localStorage
- Extend child component mocks to expose status change callback testing

---

### 2.12 Web: `settings-page.spec.tsx` — Extensions (REQ-P2-06)

**Add 2 new tests to the existing describe block, after current 4 tests:**

| # | it | Setup | Assertion |
|---|---|---|---|
| 5 | `shows error message when delete API fails` | `mockApiFetch.mockRejectedValue(new Error('Server error'))`, complete delete flow | Error text "Server error" visible |
| 6 | `shows deleting state during API call` | `mockApiFetch.mockReturnValue(new Promise(() => {}))`, complete delete flow | "Deleting..." text visible on button |

---

### 2.13 Extension: `app.spec.tsx` (REQ-P2-05)

**Mock strategy:**

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react';
import { resetChromeMock, seedStorage } from './chrome-mock';

// Mock all lib modules before importing App
const mockGetAuthToken = vi.fn();
vi.mock('../src/lib/auth', () => ({
  getAuthToken: (...args: unknown[]) => mockGetAuthToken(...args),
}));

const mockGetStorage = vi.fn();
const mockSetStorage = vi.fn();
vi.mock('../src/lib/storage', () => ({
  getStorage: (...args: unknown[]) => mockGetStorage(...args),
  setStorage: (...args: unknown[]) => mockSetStorage(...args),
}));

vi.mock('../src/lib/config', () => ({
  config: { webBaseUrl: 'http://test.local', apiBaseUrl: 'http://api.test.local' },
}));

const mockGenerateResumePDF = vi.fn();
vi.mock('../src/lib/pdf-generator', () => ({
  generateResumePDF: (...args: unknown[]) => mockGenerateResumePDF(...args),
}));

const mockUploadPdfToDrive = vi.fn();
vi.mock('../src/lib/google-drive', () => ({
  uploadPdfToDrive: (...args: unknown[]) => mockUploadPdfToDrive(...args),
}));

import App from '../src/ui/popup/App';
```

**Note on chrome.runtime.onMessage listener:** App.tsx adds listeners for `OPTIMIZE_RESULT` and `SESSION_EXPIRED` messages via `chrome.runtime.onMessage.addListener`. To test screen transitions triggered by these messages, tests will:

1. Capture the listener callback registered via `chrome.runtime.onMessage.addListener`.
2. Call it manually with the appropriate message object.
3. Assert screen transitions.

```typescript
function getMessageListener(): (message: any) => void {
  const calls = vi.mocked(chrome.runtime.onMessage.addListener).mock.calls;
  // Return the last registered listener
  return calls[calls.length - 1][0];
}
```

**Test cases (14 tests):**

| # | describe | it | Setup | Assertion |
|---|---|---|---|---|
| 1 | loading | `shows loading state on mount` | `mockGetAuthToken` returns pending promise | "Loading…" text visible |
| 2 | login | `shows login screen when no auth token` | `mockGetAuthToken.mockResolvedValue(null)` | "Sign In" button visible |
| 3 | login | `sign in button opens web auth URL` | Click "Sign In" | `chrome.tabs.create` called with URL containing `/auth/extension-callback` |
| 4 | dashboard | `shows dashboard when authenticated` | `mockGetAuthToken.mockResolvedValue('valid-token')` | "Smart Apply" heading + action buttons visible |
| 5 | dashboard | `sync profile sends TRIGGER_SYNC message` | Render dashboard, click "Sync Profile from Page" | `chrome.runtime.sendMessage` called with `{ type: 'TRIGGER_SYNC' }` |
| 6 | dashboard | `optimize triggers optimizing screen` | Render dashboard, click "Optimize for This Job" | Screen transitions to show "Optimizing your resume..." |
| 7 | dashboard | `open dashboard button creates new tab` | Click "Open Dashboard" | `chrome.tabs.create` called with URL containing `/dashboard` |
| 8 | dashboard | `autofill toggle calls chrome storage` | Click autofill toggle | `chrome.storage.local.set` called with updated `autofill_enabled` value |
| 9 | results | `renders optimization results with changes` | Trigger `OPTIMIZE_RESULT` message with mock data | Score bars and suggested changes visible |
| 10 | results | `pre-selects high-confidence changes` | Trigger `OPTIMIZE_RESULT` with changes having confidence ≥0.6 | Checkboxes checked for high-confidence items |
| 11 | results | `toggle change updates selection` | Render results, click a checkbox | Checkbox toggled, selection updated |
| 12 | results | `generate PDF calls pdf-generator and triggers download` | Click "Approve & Generate PDF" | `mockGenerateResumePDF` called; `chrome.downloads.download` called |
| 13 | results | `cancel returns to dashboard` | Click "Cancel" on results | Returns to dashboard screen |
| 14 | error | `shows error with retry on sync failure` | Render dashboard, mock sync response with error | Error message visible with "Retry" button |

---

### 2.14 Web: `vitest.config.ts` — Coverage Exclusions (NFR-P2-06)

**Current config (relevant section):**
```typescript
test: {
  root: '.',
  include: ['test/**/*.spec.{ts,tsx}'],
  environment: 'jsdom',
  globals: true,
  setupFiles: ['./test/setup.ts'],
},
```

**Updated config:**
```typescript
test: {
  root: '.',
  include: ['test/**/*.spec.{ts,tsx}'],
  environment: 'jsdom',
  globals: true,
  setupFiles: ['./test/setup.ts'],
  coverage: {
    include: ['src/**/*.{ts,tsx}'],
    exclude: [
      'src/app/**/page.tsx',
      'src/app/**/layout.tsx',
      'src/app/providers.tsx',
    ],
  },
},
```

---

## 3. Shared Test Fixtures

### 3.1 Backend Application Fixture

Used across controller specs:

```typescript
const appFixture = {
  id: 'app-1',
  clerk_user_id: 'test-user-id',
  company_name: 'Acme Corp',
  job_title: 'Software Engineer',
  status: 'applied',
  ats_score_before: 65,
  ats_score_after: 85,
  applied_at: '2024-06-15T00:00:00Z',
  created_at: '2024-06-15T00:00:00Z',
  updated_at: '2024-06-15T00:00:00Z',
};
```

### 3.2 Web Application History Item Fixture

Used across web component specs:

```typescript
const appHistoryFixture: ApplicationHistoryItem = {
  id: '1',
  company_name: 'Acme Corp',
  job_title: 'Software Engineer',
  status: 'applied' as const,
  ats_score_before: 65,
  ats_score_after: 85,
  applied_at: '2024-06-15T00:00:00Z',
  job_posting_url: 'https://example.com/jobs/1',
  resume_pdf_url: null,
  drive_link: null,
  created_at: '2024-06-15T00:00:00Z',
  updated_at: '2024-06-15T00:00:00Z',
};
```

### 3.3 Extension Optimize Result Fixture

```typescript
const optimizeResultFixture = {
  ats_score_before: 55,
  ats_score_after: 82,
  suggested_changes: [
    {
      type: 'summary_update',
      before: 'Old summary',
      after: 'New improved summary',
      reason: 'Better keyword alignment',
      confidence: 0.85,
    },
    {
      type: 'skills_insertion',
      before: null,
      after: 'Docker, Kubernetes',
      reason: 'Missing required skills',
      confidence: 0.72,
    },
    {
      type: 'warning',
      before: null,
      after: null,
      reason: 'Job requires 5+ years, profile shows 3',
      confidence: null,
    },
  ],
};
```

---

## 4. Alignment Checklist

- [x] All external services mocked (Clerk, Supabase, Chrome APIs, pdfjs-dist, fetch)
- [x] No real network calls in any test
- [x] Test files follow existing naming conventions: `test/<module>.spec.ts` (backend), `test/components/<component>.spec.tsx` (web)
- [x] Existing mock patterns reused (mockApiFetch for web, NestJS Testing Module for backend, chrome-mock for extension)
- [x] TypeScript strict mode maintained in all test files
- [x] No PII or real credentials in test data
- [x] Web components tested with @testing-library/react (no enzyme, no snapshots)
- [x] Extension tests reuse chrome-mock.ts infrastructure (NFR-P2-05)
- [x] UI tests cover loading, error, empty, and success states per coding guidelines
