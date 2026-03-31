# IMPL-LLD-TEST-P01 — Implementation Prompt

**Phase:** Test Enhancement Phase 1 — Fix and Foundation
**Version:** 1.0
**Date:** 2026-03-30
**Input:** LLD-TEST-P01.md

---

## Instructions

Implement all test files specified in LLD-TEST-P01 using TDD approach. For each test file:

1. Create the test file with all specified test cases.
2. Run the test to verify it passes.
3. If any test fails due to implementation mismatch, adjust the test to match actual behavior.

### Prerequisite: Install happy-dom in extension

```bash
npm -w smart-apply-extension install -D happy-dom
```

Update `smart-apply-extension/vitest.config.ts` to add `environment: 'happy-dom'`.

### File 1: Fix `smart-apply-backend/test/profiles.service.spec.ts`

Change the test "getProfile throws NotFoundException when not found" to:

```typescript
it('getProfile returns null when not found', async () => {
  mockSupabase.admin.from.mockReturnValue(chainedQuery(null, { message: 'not found' }));
  const result = await service.getProfile('user_x');
  expect(result).toBeNull();
});
```

### File 2: Create `smart-apply-backend/test/llm.service.spec.ts`

12 tests covering extractRequirements, optimizeResume, parseProfileText, retry logic, error handling.

### File 3: Create `smart-apply-backend/test/supabase.service.spec.ts`

3 tests covering constructor, admin getter, env var missing.

### File 4-7: Create extension content script tests

`autofill.spec.ts`, `dom-utils.spec.ts`, `jd-detector.spec.ts`, `linkedin-profile.spec.ts`

### File 8-12: Create extension lib module tests

`auth.spec.ts`, `config.spec.ts`, `google-drive.spec.ts`, `message-bus.spec.ts`, `storage.spec.ts`

---

## Execution Order

1. Fix profiles.service.spec.ts
2. Create backend test files (llm, supabase)
3. Install happy-dom, update vitest config
4. Create extension test files (content scripts, lib modules)
5. Run all tests and verify
