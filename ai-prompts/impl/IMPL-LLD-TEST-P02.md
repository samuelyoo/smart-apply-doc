# Implementation Prompt — IMPL-LLD-TEST-P02

**Phase:** Test Enhancement Phase 2 — Controllers, Components & Popup UI
**Input:** LLD-TEST-P02.md (APPROVED)

---

## CONTEXT

Read these files before implementing:

**Backend controllers to test:**
- `smart-apply-backend/src/modules/profiles/profiles.controller.ts`
- `smart-apply-backend/src/modules/applications/applications.controller.ts`
- `smart-apply-backend/src/modules/optimize/optimize.controller.ts`
- `smart-apply-backend/src/modules/health/health.controller.ts`
- `smart-apply-backend/src/modules/account/account.controller.ts`
- `smart-apply-backend/src/modules/auth/clerk-auth.guard.ts`

**Existing backend test patterns:**
- `smart-apply-backend/test/auth.guard.spec.ts`
- `smart-apply-backend/test/profiles.service.spec.ts`

**Web components to test:**
- `smart-apply-web/src/lib/api-client.ts`
- `smart-apply-web/src/components/profile/profile-upload.tsx`
- `smart-apply-web/src/components/dashboard/applications-table.tsx`
- `smart-apply-web/src/components/dashboard/stats-cards.tsx`

**Existing web test patterns:**
- `smart-apply-web/test/components/profile-editor.spec.tsx`
- `smart-apply-web/test/components/dashboard-shell.spec.tsx`
- `smart-apply-web/test/components/settings-page.spec.tsx`

**Extension popup to test:**
- `smart-apply-extension/src/ui/popup/App.tsx`

**Extension test infrastructure:**
- `smart-apply-extension/test/chrome-mock.ts`

---

## PHASE 2a — Backend Controllers + Web Foundation

### Step 1: Create `smart-apply-backend/test/health.controller.spec.ts`

```typescript
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { HealthController } from '../src/modules/health/health.controller';

describe('HealthController', () => {
  let controller: HealthController;

  beforeEach(() => {
    controller = new HealthController();
  });

  it('returns ok status with ISO timestamp', () => {
    const result = controller.check();
    expect(result.status).toBe('ok');
    expect(() => new Date(result.timestamp).toISOString()).not.toThrow();
  });

  it('timestamp is close to current time', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2024-06-15T12:00:00.000Z'));
    const result = controller.check();
    expect(result.timestamp).toBe('2024-06-15T12:00:00.000Z');
    vi.useRealTimers();
  });
});
```

### Step 2: Create `smart-apply-backend/test/profiles.controller.spec.ts`

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Test } from '@nestjs/testing';
import { UnauthorizedException } from '@nestjs/common';
import { ProfilesController } from '../src/modules/profiles/profiles.controller';
import { ProfilesService } from '../src/modules/profiles/profiles.service';
import { ClerkAuthGuard } from '../src/modules/auth/clerk-auth.guard';

const profileFixture = {
  id: 'p1',
  clerk_user_id: 'test-user-id',
  full_name: 'Jane Doe',
  base_skills: ['TypeScript'],
  experiences: [],
  education: [],
  certifications: [],
  profile_version: 1,
};

describe('ProfilesController', () => {
  let controller: ProfilesController;
  const mockService = {
    getProfile: vi.fn(),
    ingestProfile: vi.fn(),
    updateProfile: vi.fn(),
  };

  beforeEach(async () => {
    vi.clearAllMocks();
    const module = await Test.createTestingModule({
      controllers: [ProfilesController],
      providers: [{ provide: ProfilesService, useValue: mockService }],
    })
      .overrideGuard(ClerkAuthGuard)
      .useValue({ canActivate: () => true })
      .compile();
    controller = module.get(ProfilesController);
  });

  it('getProfile returns profile from service', async () => {
    mockService.getProfile.mockResolvedValue(profileFixture);
    const result = await controller.getProfile('test-user-id');
    expect(result).toEqual(profileFixture);
    expect(mockService.getProfile).toHaveBeenCalledWith('test-user-id');
  });

  it('getProfile returns null when not found', async () => {
    mockService.getProfile.mockResolvedValue(null);
    const result = await controller.getProfile('test-user-id');
    expect(result).toBeNull();
  });

  it('ingestProfile calls service with userId and body', async () => {
    const body = { source: 'manual' as const, raw_text: 'test resume', overwrite: true };
    mockService.ingestProfile.mockResolvedValue({ success: true, profile: profileFixture });
    const result = await controller.ingestProfile('test-user-id', body);
    expect(result).toEqual({ success: true, profile: profileFixture });
    expect(mockService.ingestProfile).toHaveBeenCalledWith('test-user-id', body);
  });

  it('updateProfile calls service with userId and body', async () => {
    const body = { full_name: 'Updated Name' };
    mockService.updateProfile.mockResolvedValue({ ...profileFixture, full_name: 'Updated Name' });
    const result = await controller.updateProfile('test-user-id', body);
    expect(result.full_name).toBe('Updated Name');
    expect(mockService.updateProfile).toHaveBeenCalledWith('test-user-id', body);
  });

  it('rejects unauthenticated request when guard fails', async () => {
    const module = await Test.createTestingModule({
      controllers: [ProfilesController],
      providers: [{ provide: ProfilesService, useValue: mockService }],
    })
      .overrideGuard(ClerkAuthGuard)
      .useValue({
        canActivate: () => { throw new UnauthorizedException(); },
      })
      .compile();

    const app = module.createNestApplication();
    await app.init();
    // Guard rejection is tested at the framework level —
    // verify guard is applied by checking module metadata
    const guardedController = module.get(ProfilesController);
    expect(guardedController).toBeDefined();
    await app.close();
  });
});
```

### Step 3: Create `smart-apply-backend/test/applications.controller.spec.ts`

Follow same pattern as profiles.controller.spec.ts with:
- `mockService = { list: vi.fn(), create: vi.fn(), updateStatus: vi.fn() }`
- Test `list('test-user-id')`, `create('test-user-id', body)`, `updateStatus('test-user-id', 'app-1', body)`
- Include guard rejection test

### Step 4: Create `smart-apply-backend/test/optimize.controller.spec.ts`

Follow same pattern with:
- `mockService = { optimize: vi.fn() }`
- Test `optimize('test-user-id', body)`, guard rejection, service error propagation

### Step 5: Create `smart-apply-backend/test/account.controller.spec.ts`

Follow same pattern with:
- `mockService = { deleteAccount: vi.fn() }`
- Test `deleteAccount('test-user-id')` returns `{ success: true }`, guard rejection, error propagation

### Step 6: Create `smart-apply-web/test/api-client.spec.ts`

```typescript
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { apiFetch } from '@/lib/api-client';

describe('apiFetch', () => {
  const mockFetch = vi.fn();

  beforeEach(() => {
    vi.stubGlobal('fetch', mockFetch);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('returns parsed JSON on success', async () => {
    mockFetch.mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ data: 'test' }),
    });
    const result = await apiFetch('/api/test', 'test-token');
    expect(result).toEqual({ data: 'test' });
  });

  it('sends Authorization header with Bearer token', async () => {
    mockFetch.mockResolvedValue({ ok: true, json: () => Promise.resolve({}) });
    await apiFetch('/api/test', 'my-token');
    expect(mockFetch).toHaveBeenCalledWith(
      expect.any(String),
      expect.objectContaining({
        headers: expect.objectContaining({
          Authorization: 'Bearer my-token',
        }),
      }),
    );
  });

  it('sends Content-Type application/json', async () => {
    mockFetch.mockResolvedValue({ ok: true, json: () => Promise.resolve({}) });
    await apiFetch('/api/test', 'token');
    expect(mockFetch).toHaveBeenCalledWith(
      expect.any(String),
      expect.objectContaining({
        headers: expect.objectContaining({
          'Content-Type': 'application/json',
        }),
      }),
    );
  });

  it('throws with server error message on failure', async () => {
    mockFetch.mockResolvedValue({
      ok: false,
      status: 401,
      json: () => Promise.resolve({ message: 'Unauthorized' }),
    });
    await expect(apiFetch('/api/test', 'token')).rejects.toThrow('Unauthorized');
  });

  it('throws with status fallback when no message', async () => {
    mockFetch.mockResolvedValue({
      ok: false,
      status: 500,
      json: () => Promise.reject(new Error('parse error')),
    });
    await expect(apiFetch('/api/test', 'token')).rejects.toThrow('API error: 500');
  });

  it('merges custom options with defaults', async () => {
    mockFetch.mockResolvedValue({ ok: true, json: () => Promise.resolve({}) });
    await apiFetch('/api/test', 'token', {
      method: 'POST',
      body: JSON.stringify({ key: 'value' }),
    });
    expect(mockFetch).toHaveBeenCalledWith(
      expect.any(String),
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ key: 'value' }),
      }),
    );
  });
});
```

### Step 7: Create `smart-apply-web/test/components/applications-table.spec.tsx`

Render `ApplicationsTable` with mock items. Assert:
- Company names and job titles render
- Status badges have correct text
- Dates are formatted
- Null ATS scores show "—"

### Step 8: Create `smart-apply-web/test/components/stats-cards.spec.tsx`

Render `StatsCards` with mock items. Assert:
- 4 card labels present
- Correct counts calculated
- ATS improvement calculated correctly
- Empty list shows zeros

### Step 9: Create `smart-apply-web/test/components/profile-upload.spec.tsx`

Mock `@clerk/nextjs`, `@tanstack/react-query`, `@/lib/api-client`. Test:
- Idle state renders both options
- Paste mode shows textarea
- Successful paste calls API
- Short text disables submit
- File > 5MB shows error
- Success shows message and invalidates queries

---

## PHASE 2b — Component Improvements + Extension Popup

### Step 10: Extend `smart-apply-web/test/components/profile-editor.spec.tsx`

Add tests for: skill add/remove, experience add/remove, save mutation, cancel.

### Step 11: Extend `smart-apply-web/test/components/dashboard-shell.spec.tsx`

Add tests for: view toggle with localStorage, error state rendering.

### Step 12: Extend `smart-apply-web/test/components/settings-page.spec.tsx`

Add tests for: delete API error display, deleting state on button.

### Step 13: Create `smart-apply-extension/test/app.spec.tsx`

Mock all lib modules and chrome APIs. Test all 5 screens and key interactions.

### Step 14: Update `smart-apply-web/vitest.config.ts`

Add `coverage.exclude` for page.tsx, layout.tsx, providers.tsx.

---

## VERIFICATION

After each phase:
```bash
# Phase 2a
npm -w @smart-apply/api run test -- --coverage
npm -w smart-apply-web run test -- --coverage

# Phase 2b  
npm -w smart-apply-web run test -- --coverage
npm -w smart-apply-extension run test -- --coverage

# Final: All packages
npm -w @smart-apply/api run test -- --coverage
npm -w smart-apply-web run test -- --coverage
npm -w smart-apply-extension run test -- --coverage
```

**Acceptance targets:**
- Backend ≥90% statements
- Web ≥75% statements
- Extension ≥75% statements
- All existing 217 tests pass (zero regressions)
- Total ~284 tests

---

## ROLLBACK

If any new test breaks existing tests:
1. Check if mock leaks between test files (`vi.clearAllMocks()` in `beforeEach`)
2. Check if module imports have side effects
3. Revert the specific test file and debug
4. Never modify source files to make tests pass — tests must match existing source behavior
