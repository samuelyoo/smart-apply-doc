---
title: "HLD-TEST-P01 — Fix and Foundation"
permalink: /design/hld-test-p01/
---

# HLD-TEST-P01 — Fix and Foundation (BRD-TEST Phase 1)

**Phase:** Test Enhancement Phase 1 — Fix and Foundation
**Version:** 1.0
**Date:** 2026-03-30
**Source:** BRD_enhance_unit_test_2026-03-30.md (REQ-TEST-01, REQ-TEST-03, REQ-TEST-04, REQ-TEST-05, REQ-TEST-06)

---

## 1. Phase Objective

### Business Goal
Establish a green test baseline and build foundational test coverage for the two lowest-covered packages: backend (55% → ≥70%) and extension (19% → ≥65%). After this phase, the test suite is stable, all tests pass, and the core infrastructure (LLM service, Supabase service, content scripts, extension lib modules) is tested enough to enable safe refactoring and future development.

### Developer-Facing Outcome
- Zero failing tests across all packages.
- Backend infra layer (LLM + Supabase services) has ≥90% coverage.
- Extension content scripts have ≥85% coverage.
- Extension lib modules have ≥90% coverage.
- Existing test patterns and mock infrastructure are reused and extended — not replaced.

---

## 2. Component Scope

### In Scope
| Repo | Changes |
|---|---|
| **smart-apply-backend** | Fix failing `profiles.service.spec.ts` test; add `llm.service.spec.ts` (~12 tests); add `supabase.service.spec.ts` (~3 tests) |
| **smart-apply-extension** | Add `autofill.spec.ts` (~8 tests); add `dom-utils.spec.ts` (~6 tests); add `jd-detector.spec.ts` (~6 tests); add `linkedin-profile.spec.ts` (~5 tests); add `auth.spec.ts` (~4 tests); add `config.spec.ts` (~2 tests); add `google-drive.spec.ts` (~6 tests); add `message-bus.spec.ts` (~4 tests); add `storage.spec.ts` (~4 tests) |

### Out of Scope
- Backend controller tests (Phase 2 — REQ-TEST-02)
- Extension service-worker additional coverage (Phase 2 — REQ-TEST-07)
- Web package tests (Phase 2/3 — REQ-TEST-08 through REQ-TEST-10)
- Extension popup UI tests (Phase 3 — REQ-TEST-11)
- CI threshold enforcement configuration (Phase 3 — NFR-01)
- Page-level smoke tests (Phase 3 — REQ-TEST-13)

---

## 3. Architecture Decisions

### AD-01: Fix Failing Test by Updating Test Assertion (REQ-TEST-01)
The `profiles.service.spec.ts` test "getProfile throws NotFoundException when not found" expects the service to throw, but the service now returns `null`. The test must be updated to match current behavior because:

1. The controller (`profiles.controller.ts`) already handles `null` by returning a 404 response at the controller layer.
2. Changing the service back to throw would break the controller's null-check pattern.
3. Returning `null` from service → controller decides HTTP status is the correct NestJS pattern.

**Justification:** architecture.md §3 — the service layer is responsible for data access; the controller layer is responsible for HTTP semantics.

### AD-02: LLM Service Tests Mock OpenAI at the Client Level (REQ-TEST-03)
Tests will mock the OpenAI client's `chat.completions.create` method, not the HTTP layer. This aligns with the existing mock pattern in `optimize.service.spec.ts` and avoids coupling tests to HTTP transport details.

- Mock `openai.chat.completions.create` to return controlled responses.
- Test the parsing/validation layer (`parseAndValidate` with Zod schemas) by varying the mock response content.
- Test timeout/error handling by making the mock reject with appropriate error types.

**Justification:** architecture.md §7 — LLM interaction is isolated behind the `LlmService` injectable; tests verify the service contract, not the OpenAI SDK internals.

### AD-03: Supabase Service Tests Use Environment Variable Mocking (REQ-TEST-04)
The `SupabaseService` reads `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` from env at construction time. Tests will:

1. Set environment variables before module initialization.
2. Verify the `admin` getter returns a `SupabaseClient` instance.

This is a thin wrapper — 2-3 tests suffice.

**Justification:** architecture.md §4 — Supabase is accessed via a singleton NestJS provider; test verifies initialization contract.

### AD-04: Content Script Tests Use happy-dom for DOM Simulation (REQ-TEST-05)
Content scripts manipulate the DOM directly. Tests will:

1. Use Vitest's `happy-dom` environment (already configured in the extension's vitest.config.ts `environment` option) to provide a DOM.
2. Build minimal HTML fixtures that simulate LinkedIn and Indeed page structures.
3. Test extraction functions (`extractJDText`, `extractProfileText`, etc.) against these fixtures.
4. Test form-filling functions (`setNativeValue`, `findFieldByHeuristic`) by creating input elements and verifying value changes.

**Justification:** architecture.md §6 — content scripts operate in the page's DOM context. Testing with a simulated DOM validates the actual extraction logic without requiring a browser.

### AD-05: Extension Lib Tests Reuse Existing Chrome Mock (REQ-TEST-06)
The `test/chrome-mock.ts` file already provides a comprehensive mock for `chrome.storage.local`, `chrome.runtime`, `chrome.tabs`, `chrome.identity`, and `chrome.downloads`. New lib tests will:

1. Import `resetChromeMock` and `seedStorage` helpers.
2. Add any missing Chrome API mocks (none expected — current mock covers all needed APIs).
3. Follow the same pattern as `service-worker.spec.ts` for setup/teardown.

**Justification:** Reusing existing infrastructure avoids mock drift between test files and maintains a single source of truth for Chrome API behavior.

---

## 4. Test Strategy Overview

### 4.1 Backend Test Organization

```
smart-apply-backend/
  test/
    profiles.service.spec.ts  ← FIX (1 assertion change)
    llm.service.spec.ts       ← NEW (~12 tests)
    supabase.service.spec.ts  ← NEW (~3 tests)
    applications.service.spec.ts  ← EXISTING (no changes)
    optimize.service.spec.ts      ← EXISTING (no changes)
    scoring.service.spec.ts       ← EXISTING (no changes)
```

### 4.2 Extension Test Organization

```
smart-apply-extension/
  test/
    chrome-mock.ts                ← EXISTING (no changes expected)
    service-worker.spec.ts        ← EXISTING (no changes this phase)
    autofill.spec.ts              ← NEW (~8 tests)
    dom-utils.spec.ts             ← NEW (~6 tests)
    jd-detector.spec.ts           ← NEW (~6 tests)
    linkedin-profile.spec.ts      ← NEW (~5 tests)
    auth.spec.ts                  ← NEW (~4 tests)
    config.spec.ts                ← NEW (~2 tests)
    google-drive.spec.ts          ← NEW (~6 tests)
    message-bus.spec.ts           ← NEW (~4 tests)
    storage.spec.ts               ← NEW (~4 tests)
```

### 4.3 Mock Boundaries

| Module Under Test | What Is Mocked | Why |
|---|---|---|
| `llm.service.ts` | OpenAI client (`chat.completions.create`) | No real LLM calls; test prompt construction + response parsing |
| `supabase.service.ts` | Environment variables | Verify client creation from env |
| `autofill.ts` | DOM (happy-dom provides it), `chrome.tabs.sendMessage` | Simulate form fields; no real browser |
| `dom-utils.ts` | DOM (happy-dom) | Simulate page structures |
| `jd-detector.ts` | DOM (happy-dom) | Simulate job posting pages |
| `linkedin-profile.ts` | DOM (happy-dom) | Simulate LinkedIn profile pages |
| `auth.ts` | `chrome.storage.local` (chrome-mock) | No real Chrome storage |
| `config.ts` | `import.meta.env` | Control env vars |
| `google-drive.ts` | `chrome.identity.getAuthToken`, `fetch` | No real Google API calls |
| `message-bus.ts` | `chrome.runtime.sendMessage`, `chrome.tabs.sendMessage`, `chrome.runtime.onMessage` | No real message passing |
| `storage.ts` | `chrome.storage.local` (chrome-mock) | No real Chrome storage |

---

## 5. Data Flow (Test Execution)

### 5.1 LLM Service Test Flow

```
Test setup: Create NestJS Testing Module with mocked OpenAI client
→ Test calls llmService.extractRequirements(jdText)
→ Mock OpenAI returns structured JSON string
→ Service parses with Zod schema
→ Test asserts extracted requirements match expected structure

Error path:
→ Mock OpenAI throws timeout error
→ Service retries (MAX_RETRIES=1)
→ Mock throws again
→ Service wraps in descriptive error
→ Test asserts error message + type
```

### 5.2 Content Script Test Flow

```
Test setup: Create DOM fixture via document.body.innerHTML = '...'
→ Test calls extractJDText()
→ Function queries DOM using SELECTOR_REGISTRY
→ Returns extracted text
→ Test asserts text matches expected content

No-match path:
→ DOM fixture has no JD selectors
→ extractJDText() returns null/empty
→ Test asserts graceful empty return
```

### 5.3 Extension Lib Test Flow

```
Test setup: import chrome-mock, call resetChromeMock()
→ Test calls setStorage('auth_token', 'test-token')
→ Chrome mock records the call
→ Test calls getStorage('auth_token')
→ Chrome mock returns stored value
→ Test asserts 'test-token' returned
```

---

## 6. Security Considerations

| Concern | Mitigation |
|---|---|
| Test fixtures containing real credentials | All test data uses synthetic values (`'test-token'`, `'mock-api-key'`). No real API keys or PII in test files. |
| Mock bypass allowing real API calls | All external clients (OpenAI, Supabase, Google Drive, Chrome APIs) are mocked via `vi.mock()` before module import. Tests will fail fast if a real call slips through (no network in CI). |
| LLM prompt injection in test data | Test JD inputs use benign synthetic text. No actual prompt injection payloads — security testing is out of scope for unit tests. |

---

## 7. Dependencies & Integration Points

| Dependency | Status |
|---|---|
| Vitest 3.2.4 + @vitest/coverage-v8 3.2.4 | ✅ Installed |
| happy-dom (DOM simulation for extension) | ⚠️ Verify in extension vitest.config.ts |
| Existing chrome-mock.ts | ✅ Complete — covers storage, runtime, tabs, identity, downloads |
| Existing backend mock patterns | ✅ Established in profiles/applications/optimize service specs |
| OpenAI SDK types | ✅ Available in @smart-apply/api devDependencies |

---

## 8. Acceptance Criteria Summary

### REQ-TEST-01: Fix Failing Test
- [ ] `npm -w @smart-apply/api run test` exits with code 0 (zero failures)
- [ ] `profiles.service.spec.ts` "getProfile" test asserts `null` return (not throw)

### REQ-TEST-03: LLM Service Tests
- [ ] `llm.service.spec.ts` has ≥10 tests covering: extractRequirements, optimizeResume, parseProfileText, chatCompletion, parseAndValidate
- [ ] Covers: successful parse, malformed response, timeout, retry exhaustion
- [ ] `llm.service.ts` achieves ≥90% statement coverage

### REQ-TEST-04: Supabase Service Tests
- [ ] `supabase.service.spec.ts` has ≥2 tests covering: initialization, admin getter
- [ ] `supabase.service.ts` achieves ≥90% statement coverage

### REQ-TEST-05: Content Script Tests
- [ ] `autofill.spec.ts` covers: field mapping, setNativeValue, findFieldByHeuristic, FIELD_MAP resolution
- [ ] `dom-utils.spec.ts` covers: queryWithFallback, queryAllWithFallback, SELECTOR_REGISTRY lookups
- [ ] `jd-detector.spec.ts` covers: LinkedIn JD extraction, Indeed JD extraction, no-JD fallback
- [ ] `linkedin-profile.spec.ts` covers: profile extraction, missing fields, page detection
- [ ] Content scripts achieve ≥85% statement coverage collectively

### REQ-TEST-06: Extension Lib Module Tests
- [ ] `auth.spec.ts` covers: getAuthToken, setAuthToken, clearAuthToken, isAuthenticated
- [ ] `config.spec.ts` covers: default values, env var override
- [ ] `google-drive.spec.ts` covers: getGoogleAuthToken, findOrCreateFolder, uploadPdfToDrive success/error
- [ ] `message-bus.spec.ts` covers: sendMessage, sendTabMessage, onMessage routing
- [ ] `storage.spec.ts` covers: getStorage, setStorage, removeStorage
- [ ] Lib modules achieve ≥90% statement coverage collectively

### Phase 1 Overall
- [ ] Backend coverage ≥70% statements
- [ ] Extension coverage ≥65% statements
- [ ] All 139+ tests pass (zero failures)
- [ ] No new test introduces flakiness or order-dependency
