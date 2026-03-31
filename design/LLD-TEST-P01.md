---
title: "LLD-TEST-P01 — Fix and Foundation (Detailed Design)"
permalink: /design/lld-test-p01/
---

# LLD-TEST-P01 — Fix and Foundation (Detailed Design)

**Phase:** Test Enhancement Phase 1 — Fix and Foundation
**Version:** 1.0
**Date:** 2026-03-30
**Input:** HLD-TEST-P01.md + architecture.md + BRD_enhance_unit_test_2026-03-30.md

---

## 1. File-Level Change Manifest

| # | File | Action | Purpose |
|---|---|---|---|
| 1 | `smart-apply-backend/test/profiles.service.spec.ts` | MODIFY | Fix failing assertion: expect `null` not `NotFoundException` |
| 2 | `smart-apply-backend/test/llm.service.spec.ts` | CREATE | ~12 tests for LLM service (all 4 public + 2 private methods) |
| 3 | `smart-apply-backend/test/supabase.service.spec.ts` | CREATE | ~3 tests for Supabase service constructor + admin getter |
| 4 | `smart-apply-extension/test/autofill.spec.ts` | CREATE | ~8 tests for form autofill logic |
| 5 | `smart-apply-extension/test/dom-utils.spec.ts` | CREATE | ~6 tests for DOM query helpers |
| 6 | `smart-apply-extension/test/jd-detector.spec.ts` | CREATE | ~6 tests for JD extraction |
| 7 | `smart-apply-extension/test/linkedin-profile.spec.ts` | CREATE | ~5 tests for profile extraction |
| 8 | `smart-apply-extension/test/auth.spec.ts` | CREATE | ~4 tests for auth token management |
| 9 | `smart-apply-extension/test/config.spec.ts` | CREATE | ~2 tests for config module |
| 10 | `smart-apply-extension/test/google-drive.spec.ts` | CREATE | ~6 tests for Google Drive upload |
| 11 | `smart-apply-extension/test/message-bus.spec.ts` | CREATE | ~4 tests for typed message bus |
| 12 | `smart-apply-extension/test/storage.spec.ts` | CREATE | ~4 tests for Chrome storage wrapper |

---

## 2. Detailed Design Per File

### 2.1 Backend: `profiles.service.spec.ts` — Fix Failing Test (REQ-TEST-01)

**Change:** Update test "getProfile throws NotFoundException when not found" to assert `null` return.

Current code (BROKEN):
```typescript
it('getProfile throws NotFoundException when not found', async () => {
  mockSupabase.admin.from.mockReturnValue(chainedQuery(null, { message: 'not found' }));
  await expect(service.getProfile('user_x')).rejects.toThrow(NotFoundException);
});
```

Updated code:
```typescript
it('getProfile returns null when not found', async () => {
  mockSupabase.admin.from.mockReturnValue(chainedQuery(null, { message: 'not found' }));
  const result = await service.getProfile('user_x');
  expect(result).toBeNull();
});
```

**Rationale:** `ProfilesService.getProfile()` returns `null` when `error || !data` (line 30 of profiles.service.ts). The controller handles the null → 404 mapping.

---

### 2.2 Backend: `llm.service.spec.ts` — LLM Service Tests (REQ-TEST-03)

**Mock strategy:**
- Mock `ConfigService` to return test API key and model.
- Mock `OpenAI` constructor — intercept `chat.completions.create` via `vi.mock('openai')`.
- No NestJS Testing Module needed — direct instantiation with mocked deps.

**Test file structure:**

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ConfigService } from '@nestjs/config';
import { LlmService } from '../src/infra/llm/llm.service';

// Mock OpenAI
const mockCreate = vi.fn();
vi.mock('openai', () => ({
  default: vi.fn().mockImplementation(() => ({
    chat: { completions: { create: mockCreate } },
  })),
}));

const mockConfig = {
  get: vi.fn((key: string, fallback?: string) => {
    if (key === 'LLM_API_KEY') return 'test-api-key';
    if (key === 'LLM_MODEL') return 'gpt-4o';
    return fallback;
  }),
} as unknown as ConfigService;
```

**Test cases (12 tests):**

| # | describe | it | Setup | Assertion |
|---|---|---|---|---|
| 1 | constructor | creates OpenAI client with config values | Mock config returns key/model | Service instantiates without error |
| 2 | extractRequirements | returns parsed requirements from valid LLM response | Mock LLM returns valid JSON `{hard_skills:[], soft_skills:[], certifications:[]}` | Returns typed `ExtractedRequirements` |
| 3 | extractRequirements | calls LLM with correct system prompt containing analyst instructions | Mock LLM returns valid JSON | Assert `mockCreate` called with messages array containing system prompt |
| 4 | extractRequirements | throws on malformed JSON response | Mock LLM returns `"not json{"` | Throws `Error('LLM returned invalid JSON for extractRequirements')` |
| 5 | extractRequirements | throws on schema validation failure | Mock LLM returns `{"wrong": "shape"}` | Throws `Error('LLM output validation failed for extractRequirements')` |
| 6 | optimizeResume | returns parsed optimization result | Mock LLM returns valid `llmOutputSchema` JSON | Returns `LlmOutput` with summary, skills, experience_edits, warnings |
| 7 | optimizeResume | strips fabricated companies from experience_edits | Mock LLM returns edit with company not in profile | `experience_edits` filtered to exclude non-matching company |
| 8 | optimizeResume | keeps valid company edits | Mock LLM returns edit matching profile company | `experience_edits` contains the edit |
| 9 | parseProfileText | returns parsed profile from valid response | Mock LLM returns valid `parsedProfileSchema` JSON | Returns structured profile object |
| 10 | chatCompletion (via public methods) | retries once on failure then succeeds | Mock rejects first, resolves second | Returns valid result (retry works) |
| 11 | chatCompletion (via public methods) | throws after retry exhaustion (MAX_RETRIES=1) | Mock rejects twice | Throws the original error |
| 12 | chatCompletion (via public methods) | throws on empty LLM response | Mock returns `{ choices: [{ message: { content: null } }] }` | Throws `Error('Empty response from LLM')` |

---

### 2.3 Backend: `supabase.service.spec.ts` — Supabase Service Tests (REQ-TEST-04)

**Mock strategy:**
- Mock `@supabase/supabase-js` `createClient` to return a mock client.
- Mock `ConfigService.getOrThrow` to return test values.

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ConfigService } from '@nestjs/config';

const mockClient = { from: vi.fn() };
vi.mock('@supabase/supabase-js', () => ({
  createClient: vi.fn(() => mockClient),
}));
```

**Test cases (3 tests):**

| # | it | Setup | Assertion |
|---|---|---|---|
| 1 | creates client with configured URL and key | Config returns test URL/key | `createClient` called with `'https://test.supabase.co'`, `'test-service-key'` |
| 2 | exposes admin as SupabaseClient | Standard setup | `service.admin` is the mock client |
| 3 | throws when env var is missing | Config `.getOrThrow` throws | Constructor throws |

---

### 2.4 Extension: `autofill.spec.ts` — Content Script Tests (REQ-TEST-05)

**Environment:** Tests run under happy-dom (extension vitest.config.ts does not set an environment — will need to add `@vitest-environment happy-dom` comment or update config). Since the extension config has `setupFiles: ['./test/chrome-mock.ts']`, Chrome mocks are auto-loaded.

**Note:** The extension's vitest.config.ts does not currently specify `environment: 'happy-dom'`. Content script tests need DOM. Options:
- **Option A:** Add `environment: 'happy-dom'` to vitest.config.ts (affects all extension tests).
- **Option B:** Use `// @vitest-environment happy-dom` comment directive per test file.
- **Recommended:** Option A — all extension tests benefit from DOM availability, and the chrome-mock setup is compatible with happy-dom.

**Prerequisites:** Ensure `happy-dom` is installed as devDependency in `smart-apply-extension`.

**Mock strategy:**
- DOM provided by happy-dom.
- Content scripts import chrome global — already mocked by chrome-mock.ts setupFile.

**Test cases (8 tests):**

| # | describe | it | Setup | Assertion |
|---|---|---|---|---|
| 1 | setNativeValue | sets value on input element and dispatches events | Create `<input>` element | `.value` is set; input event fired |
| 2 | findFieldByHeuristic | finds field by name attribute | `<input name="email">` | Returns the input element |
| 3 | findFieldByHeuristic | finds field by placeholder | `<input placeholder="Enter email">` | Returns the input element |
| 4 | findFieldByHeuristic | finds field by aria-label | `<input aria-label="Email Address">` | Returns the input element |
| 5 | findFieldByHeuristic | returns null when no match | Empty DOM | Returns null |
| 6 | FIELD_MAP | has entries for all expected field types | n/a | 13 expected keys exist |
| 7 | autofillForm | fills multiple fields with provided data | Create form with name/email inputs | Both inputs receive values |
| 8 | autofillForm | skips fields that cannot be found | Partial DOM (only email input) | Email filled, no error thrown |

---

### 2.5 Extension: `dom-utils.spec.ts` — DOM Utility Tests (REQ-TEST-05)

**Test cases (6 tests):**

| # | describe | it | Setup | Assertion |
|---|---|---|---|---|
| 1 | SELECTOR_REGISTRY | has entries for LinkedIn and Indeed | n/a | Keys include linkedin/indeed variants |
| 2 | queryWithFallback | returns element matching primary selector | `<div class="jobs-description">text</div>` | Returns the div |
| 3 | queryWithFallback | falls back to secondary selector | No primary match; `<div class="jobsearch-JobComponent">text</div>` | Returns fallback div |
| 4 | queryWithFallback | returns null when no selector matches | Empty DOM | Returns null |
| 5 | queryAllWithFallback | returns all matching elements | Multiple matching elements | Returns NodeList with correct count |
| 6 | reportSelectorFailure | sends SELECTOR_FAILURE message | Mock `chrome.runtime.sendMessage` | Called with failure payload |

---

### 2.6 Extension: `jd-detector.spec.ts` — JD Extraction Tests (REQ-TEST-05)

**Test cases (6 tests):**

| # | describe | it | Setup | Assertion |
|---|---|---|---|---|
| 1 | isLinkedInJobPage | returns true for LinkedIn job URL | `window.location.href` set to LinkedIn job URL | Returns `true` |
| 2 | isLinkedInJobPage | returns false for non-LinkedIn URL | Generic URL | Returns `false` |
| 3 | isIndeedJobPage | returns true for Indeed job URL | Indeed URL | Returns `true` |
| 4 | extractJDText | extracts text from LinkedIn job posting DOM | Build LinkedIn-like DOM with `.jobs-description__content` | Returns extracted text |
| 5 | extractJDText | extracts text from Indeed job posting DOM | Build Indeed-like DOM with `.jobsearch-JobComponent-description` | Returns extracted text |
| 6 | extractJobMeta | extracts company and job title from DOM | DOM with `.job-details-jobs-unified-top-card__company-name` and title elements | Returns `{company, jobTitle}` |

---

### 2.7 Extension: `linkedin-profile.spec.ts` — LinkedIn Profile Tests (REQ-TEST-05)

**Test cases (5 tests):**

| # | describe | it | Setup | Assertion |
|---|---|---|---|---|
| 1 | isLinkedInProfilePage | returns true for LinkedIn profile URL | Set location to `linkedin.com/in/username` | Returns `true` |
| 2 | isLinkedInProfilePage | returns false for non-profile page | Set location to `linkedin.com/jobs/123` | Returns `false` |
| 3 | extractProfileText | extracts text from profile sections | Build DOM with LinkedIn profile sections | Returns concatenated text |
| 4 | extractProfileText | returns empty string when no profile sections found | Empty DOM | Returns `''` or null |
| 5 | injectSyncButton | creates and appends button element | Clean DOM | Button exists in DOM with expected text |

---

### 2.8 Extension: `auth.spec.ts` — Auth Module Tests (REQ-TEST-06)

**Test cases (4 tests):**

| # | describe | it | Setup | Assertion |
|---|---|---|---|---|
| 1 | getAuthToken | returns stored token | `seedStorage({ auth_token: 'test-tok' })` | Returns `'test-tok'` |
| 2 | setAuthToken | stores token in chrome.storage.local | Call `setAuthToken('new-tok')` | `chrome.storage.local.set` called with `{ auth_token: 'new-tok' }` |
| 3 | clearAuthToken | removes token from storage | `seedStorage({ auth_token: 'tok' })`; call `clearAuthToken()` | `chrome.storage.local.remove` called with `'auth_token'` |
| 4 | isAuthenticated | returns true when token exists, false when absent | Seed with token; then clear | Returns `true` then `false` |

---

### 2.9 Extension: `config.spec.ts` — Config Module Tests (REQ-TEST-06)

**Mock strategy:** Use `vi.stubEnv` or mock `import.meta.env` before import.

**Test cases (2 tests):**

| # | it | Setup | Assertion |
|---|---|---|---|
| 1 | uses default values when env vars not set | No env vars | `config.apiBaseUrl === 'http://localhost:3001'`, `config.webBaseUrl === 'http://localhost:3000'` |
| 2 | uses env var values when set | Set `VITE_API_BASE_URL` and `VITE_WEB_BASE_URL` | Config reflects overridden values |

---

### 2.10 Extension: `google-drive.spec.ts` — Google Drive Tests (REQ-TEST-06)

**Mock strategy:**
- Mock `chrome.identity.getAuthToken` via chrome-mock.
- Mock global `fetch` via `vi.fn()`.

**Test cases (6 tests):**

| # | describe | it | Setup | Assertion |
|---|---|---|---|---|
| 1 | getGoogleAuthToken | resolves with token on success | Mock `getAuthToken` calls callback with token | Resolves `'mock-google-token'` |
| 2 | getGoogleAuthToken | rejects when lastError set | Mock `chrome.runtime.lastError` | Rejects with error message |
| 3 | uploadPdfToDrive | creates folder structure and uploads | Mock fetch: folder search (empty) → create folder → create subfolder → upload OK | Returns `{ fileId, webViewLink }` |
| 4 | uploadPdfToDrive | reuses existing folders | Mock fetch: folder search returns existing ID | Skips folder creation; proceeds to upload |
| 5 | uploadPdfToDrive | throws on upload failure | Mock fetch: folders OK → upload returns 403 | Throws `Error('Drive upload failed: 403 ...')` |
| 6 | escapeDriveQuery (via uploadPdfToDrive) | handles special characters in company name | Company name with apostrophe: `O'Reilly` | Folder created with escaped name |

---

### 2.11 Extension: `message-bus.spec.ts` — Message Bus Tests (REQ-TEST-06)

**Test cases (4 tests):**

| # | describe | it | Setup | Assertion |
|---|---|---|---|---|
| 1 | sendMessage | calls chrome.runtime.sendMessage with type and payload | Call `sendMessage('SYNC_PROFILE', { rawText: 'x', sourceUrl: 'y' })` | `chrome.runtime.sendMessage` called with `{ type: 'SYNC_PROFILE', payload: { rawText: 'x', sourceUrl: 'y' } }` |
| 2 | sendTabMessage | calls chrome.tabs.sendMessage with tabId | Call `sendTabMessage(42, 'AUTOFILL', { name: 'John' })` | `chrome.tabs.sendMessage` called with `42, { type: 'AUTOFILL', payload: { name: 'John' } }` |
| 3 | onMessage | registers listener on chrome.runtime.onMessage | Call `onMessage('SYNC_PROFILE', handler)` | `chrome.runtime.onMessage.addListener` called |
| 4 | onMessage | listener only fires for matching message type | Register for 'SYNC_PROFILE'; simulate message with type 'SYNC_PROFILE' and 'AUTOFILL' | Handler called once (for SYNC_PROFILE only) |

---

### 2.12 Extension: `storage.spec.ts` — Chrome Storage Wrapper Tests (REQ-TEST-06)

**Test cases (4 tests):**

| # | describe | it | Setup | Assertion |
|---|---|---|---|---|
| 1 | getStorage | returns value when key exists | `seedStorage({ auth_token: 'tok' })` | Returns `'tok'` |
| 2 | getStorage | returns null when key missing | Empty storage | Returns `null` |
| 3 | setStorage | stores value in chrome.storage.local | Call `setStorage('auth_token', 'new-tok')` | `chrome.storage.local.set` called with `{ auth_token: 'new-tok' }` |
| 4 | removeStorage | removes key from storage | Call `removeStorage('auth_token')` | `chrome.storage.local.remove` called with `'auth_token'` |

---

## 3. Vitest Configuration Updates

### 3.1 Extension: Add happy-dom Environment

Update `smart-apply-extension/vitest.config.ts`:
```typescript
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    root: '.',
    include: ['test/**/*.spec.{ts,tsx}'],
    globals: true,
    setupFiles: ['./test/chrome-mock.ts'],
    environment: 'happy-dom',  // ADD: enables DOM for content script tests
  },
});
```

**Prerequisite:** Install `happy-dom` as devDependency:
```bash
npm -w smart-apply-extension install -D happy-dom
```

### 3.2 No Backend Config Changes
Backend vitest.config.ts is sufficient as-is. LLM and Supabase tests use mocks only — no DOM needed.

---

## 4. Alignment Checklist

- [x] All external services mocked (OpenAI, Supabase, Chrome APIs, Google APIs, fetch)
- [x] No real network calls in any test
- [x] Test files follow existing naming convention: `test/<module-name>.spec.ts`
- [x] Existing mock patterns reused (chainedQuery for Supabase, chrome-mock for extension)
- [x] TypeScript strict mode maintained in all test files
- [x] No PII or real credentials in test data

---

## Architect Review

**Verdict:** APPROVED

### Summary
The LLD correctly addresses all 5 Phase 1 requirements with detailed test specifications. Mock strategies are consistent with existing patterns. The happy-dom addition for extension tests is necessary and well-scoped. The failing test fix aligns with the current service behavior.

### Notes for Implementation
- Install `happy-dom` before running extension tests with DOM features.
- For `llm.service.spec.ts`, the `chatCompletion` method is private — test it indirectly through the 3 public methods (`extractRequirements`, `optimizeResume`, `parseProfileText`).
- For `google-drive.spec.ts`, `escapeDriveQuery` and `findOrCreateFolder` are not exported — test indirectly via `uploadPdfToDrive`.
- The `autofill.spec.ts` tests should verify that `setNativeValue` dispatches both `input` and `change` events (React synthetic event compatibility).
