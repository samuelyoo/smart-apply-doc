# IMPL-LLD-P04 — Security, Testing & Quality Hardening

**Phase:** P04  
**Input:** APPROVED LLD-MVP-P04.md  
**Date:** 2026-03-29

---

## Context

### Project State
- Repository root: `/Users/syoo/Documents/code/smart-apply`
- Monorepo with 4 packages: `smart-apply-shared`, `smart-apply-backend`, `smart-apply-web`, `smart-apply-extension`
- Shared schemas from `@smart-apply/shared`: `createApplicationRequestSchema`, `applicationStatusSchema`, `sourcePlatformSchema`, `profileIngestRequestSchema`, `updateProfileRequestSchema`, `experienceItemSchema`, `educationItemSchema`, `optimizeRequestSchema`, `llmOutputSchema`
- Package manager: npm workspaces (root `package.json`)
- Environment variables:
  - Backend: `CHROME_EXTENSION_ID`, `ALLOWED_ORIGINS`, `NODE_ENV`
  - Extension build-time: `VITE_GOOGLE_OAUTH_CLIENT_ID`

### What This Phase Builds
Closes all security gaps (route protection, CORS, 401 handling), completes Google Drive link persistence, establishes Vitest across all packages, creates regression + component + extension tests, expands CI to build/test all packages, adds audit logging for account deletion, and adds retry buttons to the extension popup.

### Implementation Order
1. **Phase 1 — Security Fixes** (REQ-02-01, 02-02, 02-03): Modify middleware.ts, main.ts, api-client.ts
2. **Phase 2 — Drive Completion** (REQ-02-04): Modify manifest.ts, service-worker.ts
3. **Phase 3 — Test Infrastructure** (REQ-02-05): Install deps, create vitest configs, Chrome mock, test setup
4. **Phase 4 — Regression Tests** (REQ-02-06): Schema tests, middleware tests
5. **Phase 5 — Component + Extension Tests** (REQ-02-07, 02-08): Web component tests, extension tests
6. **Phase 6 — CI + Audit + Retry** (REQ-02-09, 02-10, 02-11): CI pipeline, audit_events migration, retry buttons

---

## Step 1: Security Fixes (REQ-02-01, 02-02, 02-03)

### 1.1 Fix Web Middleware Route Protection (REQ-02-01)

**File:** `smart-apply-web/src/middleware.ts`  
**Action:** MODIFY — Replace protected-route blocklist with public-route allowlist.

Replace the entire file contents with:

```typescript
import { clerkMiddleware, createRouteMatcher } from '@clerk/nextjs/server';

const isPublicRoute = createRouteMatcher([
  '/sign-in(.*)',
  '/sign-up(.*)',
  '/api/webhooks(.*)',
  '/',
  '/not-found',
]);

export default clerkMiddleware(async (auth, req) => {
  if (!isPublicRoute(req)) {
    await auth.protect();
  }
});

export const config = {
  matcher: ['/((?!_next|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|webp|png|gif|svg|ttf|woff2?|ico|csv|docx?|xlsx?|zip|webmanifest)).*)'],
};
```

**Key change:** `isProtectedRoute` → `isPublicRoute` with inverted logic. All routes are protected by default. Only sign-in, sign-up, webhooks, landing page, and not-found are public.

---

### 1.2 Restrict CORS to Specific Extension ID (REQ-02-02)

**File:** `smart-apply-backend/src/main.ts`  
**Action:** MODIFY — Update the CORS origin callback to check `CHROME_EXTENSION_ID`.

Replace the full CORS origin callback:

```typescript
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ConfigService } from '@nestjs/config';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { rawBody: true });
  const config = app.get(ConfigService);

  const allowedOrigins = config
    .get<string>('ALLOWED_ORIGINS', 'http://localhost:3000')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);

  const extId = config.get<string>('CHROME_EXTENSION_ID');
  const isProd = config.get<string>('NODE_ENV') === 'production';

  app.enableCors({
    origin: (origin: string | undefined, callback: (err: Error | null, allow?: boolean) => void) => {
      // Allow same-origin or listed web origins
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
        return;
      }

      // Allow specific Chrome extension by ID
      if (extId && origin === `chrome-extension://${extId}`) {
        callback(null, true);
        return;
      }

      // Dev-only: allow any Chrome extension when no ID is configured
      if (!isProd && !extId && /^chrome-extension:\/\//.test(origin)) {
        callback(null, true);
        return;
      }

      callback(new Error('CORS not allowed'));
    },
    credentials: true,
  });

  const port = config.get<number>('PORT', 3001);
  await app.listen(port);
  console.log(`API running on port ${port}`);
}
bootstrap();
```

**Key changes:**
- Read `CHROME_EXTENSION_ID` from env
- In production: only allow the specific extension ID
- In dev without ID: fallback to wildcard chrome-extension pattern
- In production without ID: no extension origins allowed

---

### 1.3 Complete Extension 401 Handling (REQ-02-03)

**File:** `smart-apply-extension/src/lib/api-client.ts`  
**Action:** MODIFY — Add 401 interceptor before the generic error throw.

Replace the full file contents with:

```typescript
import { config } from './config';
import { clearAuthToken } from './auth';

const API_BASE = config.apiBaseUrl;

export async function apiFetch<T>(
  path: string,
  init?: RequestInit,
): Promise<T> {
  const token = await getTokenFromStorage();

  const res = await fetch(`${API_BASE}${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...init?.headers,
    },
  });

  if (res.status === 401) {
    await clearAuthToken();
    chrome.runtime.sendMessage({ type: 'SESSION_EXPIRED' });
    throw new Error('Session expired. Please sign in again.');
  }

  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.message ?? `API error: ${res.status}`);
  }

  return res.json() as Promise<T>;
}

async function getTokenFromStorage(): Promise<string | null> {
  return new Promise((resolve) => {
    chrome.storage.local.get('auth_token', (result) => {
      resolve((result.auth_token as string) ?? null);
    });
  });
}
```

**Key changes:**
- Import `clearAuthToken` from `./auth`
- Add 401 check before generic `!res.ok` check
- On 401: clear token, broadcast SESSION_EXPIRED, throw descriptive error

---

## Step 2: Drive Completion (REQ-02-04)

### 2.1 Fix Manifest OAuth Client ID

**File:** `smart-apply-extension/src/manifest.ts`  
**Action:** MODIFY — Replace the placeholder with build-time env var.

Change this line:
```typescript
    client_id: 'GOOGLE_OAUTH_CLIENT_ID_PLACEHOLDER',
```

To:
```typescript
    client_id: process.env.VITE_GOOGLE_OAUTH_CLIENT_ID || 'GOOGLE_OAUTH_CLIENT_ID_PLACEHOLDER',
```

---

### 2.2 Pass drive_link in SAVE_APPLICATION

**File:** `smart-apply-extension/src/background/service-worker.ts`  
**Action:** MODIFY — Update `MessageType`, update `handleSaveApplication` signature and body.

**Change 1:** Update the `SAVE_APPLICATION` member in the `MessageType` union (around line 38):

From:
```typescript
  | { type: 'SAVE_APPLICATION'; payload: { optimizeResult: OptimizeResponse; selectedChanges: number[] } }
```

To:
```typescript
  | { type: 'SAVE_APPLICATION'; payload: { optimizeResult: OptimizeResponse; selectedChanges: number[]; drive_link?: string } }
```

**Change 2:** Update `handleSaveApplication` function signature and body (around line 165):

From:
```typescript
async function handleSaveApplication(payload: {
  optimizeResult: OptimizeResponse;
  selectedChanges: number[];
}): Promise<{ success: boolean; application_id?: string; error?: string }> {
```

To:
```typescript
async function handleSaveApplication(payload: {
  optimizeResult: OptimizeResponse;
  selectedChanges: number[];
  drive_link?: string;
}): Promise<{ success: boolean; application_id?: string; error?: string }> {
```

**Change 3:** Add `drive_link` to the request body. After the `applied_resume_snapshot` line in the body object:

Add:
```typescript
      ...(payload.drive_link ? { drive_link: payload.drive_link } : {}),
```

So the body becomes:
```typescript
    const body: CreateApplicationRequest = {
      company_name: context.company,
      job_title: context.jobTitle,
      source_platform: context.sourcePlatform as CreateApplicationRequest['source_platform'],
      source_url: context.sourceUrl,
      ats_score_before: payload.optimizeResult.ats_score_before,
      ats_score_after: payload.optimizeResult.ats_score_after,
      status: 'generated',
      applied_resume_snapshot: payload.optimizeResult.optimized_resume_json as unknown as Record<string, unknown>,
      ...(payload.drive_link ? { drive_link: payload.drive_link } : {}),
    };
```

---

## Step 3: Test Infrastructure (REQ-02-05)

### 3.1 Install Test Dependencies

Run these commands:

```bash
# Shared package — add vitest
npm -w @smart-apply/shared install -D vitest

# Web package — add vitest + React Testing Library + jsdom
npm -w @smart-apply/web install -D vitest @vitejs/plugin-react @testing-library/react @testing-library/jest-dom @testing-library/user-event jsdom

# Extension package — add vitest
npm -w @smart-apply/extension install -D vitest
```

### 3.2 Add Test Scripts to package.json Files

**File:** `smart-apply-shared/package.json`  
Add to `scripts`:
```json
"test": "vitest run",
"test:watch": "vitest"
```

**File:** `smart-apply-web/package.json`  
Add to `scripts`:
```json
"test": "vitest run",
"test:watch": "vitest"
```

**File:** `smart-apply-extension/package.json`  
Add to `scripts`:
```json
"test": "vitest run",
"test:watch": "vitest"
```

### 3.3 Create Vitest Configs

**File:** `smart-apply-shared/vitest.config.ts` (CREATE)

```typescript
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    root: '.',
    include: ['test/**/*.spec.ts'],
    globals: true,
  },
});
```

**File:** `smart-apply-web/vitest.config.ts` (CREATE)

```typescript
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    root: '.',
    include: ['test/**/*.spec.{ts,tsx}'],
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./test/setup.ts'],
  },
});
```

**File:** `smart-apply-web/test/setup.ts` (CREATE)

```typescript
import '@testing-library/jest-dom/vitest';
```

**File:** `smart-apply-extension/vitest.config.ts` (CREATE)

```typescript
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    root: '.',
    include: ['test/**/*.spec.{ts,tsx}'],
    globals: true,
    setupFiles: ['./test/chrome-mock.ts'],
  },
});
```

### 3.4 Create Chrome API Mock

**File:** `smart-apply-extension/test/chrome-mock.ts` (CREATE)

```typescript
import { vi } from 'vitest';

const storageMock: Record<string, unknown> = {};

const chromeMock = {
  storage: {
    local: {
      get: vi.fn((keys: string | string[], callback?: (result: Record<string, unknown>) => void) => {
        const keyList = typeof keys === 'string' ? [keys] : keys;
        const result: Record<string, unknown> = {};
        for (const key of keyList) {
          if (key in storageMock) result[key] = storageMock[key];
        }
        if (callback) callback(result);
        return Promise.resolve(result);
      }),
      set: vi.fn((items: Record<string, unknown>, callback?: () => void) => {
        Object.assign(storageMock, items);
        if (callback) callback();
        return Promise.resolve();
      }),
      remove: vi.fn((keys: string | string[], callback?: () => void) => {
        const keyList = typeof keys === 'string' ? [keys] : keys;
        for (const key of keyList) delete storageMock[key];
        if (callback) callback();
        return Promise.resolve();
      }),
    },
    onChanged: {
      addListener: vi.fn(),
      removeListener: vi.fn(),
    },
  },
  runtime: {
    onMessage: { addListener: vi.fn(), removeListener: vi.fn() },
    onMessageExternal: { addListener: vi.fn(), removeListener: vi.fn() },
    onInstalled: { addListener: vi.fn() },
    sendMessage: vi.fn(),
    lastError: null,
  },
  tabs: {
    query: vi.fn(),
    sendMessage: vi.fn(),
    create: vi.fn(),
  },
  identity: {
    getAuthToken: vi.fn(),
  },
  downloads: {
    download: vi.fn(),
  },
};

Object.defineProperty(globalThis, 'chrome', {
  value: chromeMock,
  writable: true,
});

// Helper to reset storage between tests
export function resetChromeMock() {
  Object.keys(storageMock).forEach((key) => delete storageMock[key]);
  vi.clearAllMocks();
}

// Helper to seed storage
export function seedStorage(data: Record<string, unknown>) {
  Object.assign(storageMock, data);
}
```

---

## Step 4: Regression Tests (REQ-02-06)

### 4.1 Shared Schema Tests

**File:** `smart-apply-shared/test/schemas.spec.ts` (CREATE)

```typescript
import { describe, it, expect } from 'vitest';
import {
  createApplicationRequestSchema,
  applicationStatusSchema,
  sourcePlatformSchema,
  profileIngestRequestSchema,
  updateProfileRequestSchema,
  experienceItemSchema,
  educationItemSchema,
  optimizeRequestSchema,
  llmOutputSchema,
} from '../src/index';

describe('Profile Schemas', () => {
  it('profileIngestRequestSchema accepts valid linkedin ingest', () => {
    const result = profileIngestRequestSchema.parse({
      source: 'linkedin',
      raw_text: 'John Doe - Software Engineer',
      source_url: 'https://www.linkedin.com/in/johndoe',
    });
    expect(result.source).toBe('linkedin');
    expect(result.overwrite).toBe(true); // default
  });

  it('profileIngestRequestSchema rejects empty raw_text', () => {
    expect(() =>
      profileIngestRequestSchema.parse({ source: 'linkedin', raw_text: '' }),
    ).toThrow();
  });

  it('profileIngestRequestSchema rejects invalid source', () => {
    expect(() =>
      profileIngestRequestSchema.parse({ source: 'github', raw_text: 'text' }),
    ).toThrow();
  });

  it('updateProfileRequestSchema accepts partial update', () => {
    const result = updateProfileRequestSchema.parse({ full_name: 'Jane Doe' });
    expect(result.full_name).toBe('Jane Doe');
  });

  it('experienceItemSchema rejects missing company', () => {
    expect(() =>
      experienceItemSchema.parse({ role: 'Eng', description: [] }),
    ).toThrow();
  });

  it('educationItemSchema rejects missing degree', () => {
    expect(() =>
      educationItemSchema.parse({ school: 'MIT' }),
    ).toThrow();
  });
});

describe('Application Schemas', () => {
  const validApp = {
    company_name: 'Acme Corp',
    job_title: 'Senior Engineer',
    status: 'generated' as const,
  };

  it('createApplicationRequestSchema accepts full valid input', () => {
    const result = createApplicationRequestSchema.parse({
      ...validApp,
      source_platform: 'linkedin',
      source_url: 'https://linkedin.com/jobs/123',
      ats_score_before: 48,
      ats_score_after: 85,
    });
    expect(result.company_name).toBe('Acme Corp');
  });

  it('createApplicationRequestSchema accepts optional drive_link', () => {
    const result = createApplicationRequestSchema.parse({
      ...validApp,
      drive_link: 'https://drive.google.com/file/d/abc',
    });
    expect(result.drive_link).toBe('https://drive.google.com/file/d/abc');
  });

  it('createApplicationRequestSchema rejects empty company_name', () => {
    expect(() =>
      createApplicationRequestSchema.parse({ ...validApp, company_name: '' }),
    ).toThrow();
  });

  it('applicationStatusSchema accepts all valid statuses', () => {
    const statuses = ['draft', 'generated', 'applied', 'interviewing', 'offer', 'rejected', 'withdrawn'];
    for (const s of statuses) {
      expect(applicationStatusSchema.parse(s)).toBe(s);
    }
  });

  it('applicationStatusSchema rejects invalid status', () => {
    expect(() => applicationStatusSchema.parse('pending')).toThrow();
  });

  it('sourcePlatformSchema accepts all valid platforms', () => {
    const platforms = ['linkedin', 'indeed', 'workday', 'greenhouse', 'lever', 'other'];
    for (const p of platforms) {
      expect(sourcePlatformSchema.parse(p)).toBe(p);
    }
  });
});

describe('Optimization Schemas', () => {
  it('optimizeRequestSchema accepts valid JD input', () => {
    const result = optimizeRequestSchema.parse({
      job_description_text: 'Looking for a senior engineer...',
      job_title: 'Senior Engineer',
      company_name: 'Acme Corp',
    });
    expect(result.source_platform).toBe('other'); // default
  });

  it('optimizeRequestSchema rejects empty job_description_text', () => {
    expect(() =>
      optimizeRequestSchema.parse({
        job_description_text: '',
        job_title: 'Eng',
        company_name: 'Acme',
      }),
    ).toThrow();
  });

  it('llmOutputSchema accepts valid LLM response', () => {
    const result = llmOutputSchema.parse({
      summary: 'Senior engineer with 10 years...',
      skills: ['TypeScript', 'React'],
      experience_edits: [
        {
          company: 'Acme',
          original_bullet: 'Built features',
          revised_bullet: 'Built scalable features using React',
          inserted_keywords: ['React'],
          confidence: 0.85,
        },
      ],
      warnings: [],
    });
    expect(result.skills).toHaveLength(2);
  });

  it('llmOutputSchema rejects missing skills array', () => {
    expect(() =>
      llmOutputSchema.parse({
        summary: 'text',
        experience_edits: [],
        warnings: [],
      }),
    ).toThrow();
  });
});
```

### 4.2 Middleware Route Protection Tests

**File:** `smart-apply-web/test/middleware.spec.ts` (CREATE)

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock @clerk/nextjs/server before importing middleware
const mockProtect = vi.fn();
const mockAuth = vi.fn((callback: (auth: { protect: typeof mockProtect }, req: { nextUrl: { pathname: string } }) => Promise<void>) => {
  return (req: { nextUrl: { pathname: string } }) => callback({ protect: mockProtect }, req);
});
const mockCreateRouteMatcher = vi.fn((routes: string[]) => {
  return (req: { nextUrl: { pathname: string } }) => {
    return routes.some((pattern) => {
      // Simple matching: convert (.*) to regex
      const regex = new RegExp(`^${pattern.replace('(.*)', '.*')}$`);
      return regex.test(req.nextUrl.pathname);
    });
  };
});

vi.mock('@clerk/nextjs/server', () => ({
  clerkMiddleware: mockAuth,
  createRouteMatcher: mockCreateRouteMatcher,
}));

describe('Clerk Middleware Route Protection', () => {
  let middleware: (req: { nextUrl: { pathname: string } }) => Promise<void>;

  beforeEach(async () => {
    vi.clearAllMocks();
    // Re-import to pick up mocks
    const mod = await import('../src/middleware');
    middleware = mod.default as unknown as typeof middleware;
  });

  const makeReq = (pathname: string) => ({ nextUrl: { pathname } });

  it('protects /dashboard from unauthenticated users', async () => {
    await middleware(makeReq('/dashboard'));
    expect(mockProtect).toHaveBeenCalled();
  });

  it('protects /dashboard/applications from unauthenticated users', async () => {
    await middleware(makeReq('/dashboard/applications'));
    expect(mockProtect).toHaveBeenCalled();
  });

  it('protects /profile from unauthenticated users', async () => {
    await middleware(makeReq('/profile'));
    expect(mockProtect).toHaveBeenCalled();
  });

  it('protects /optimize from unauthenticated users', async () => {
    await middleware(makeReq('/optimize'));
    expect(mockProtect).toHaveBeenCalled();
  });

  it('protects /settings from unauthenticated users', async () => {
    await middleware(makeReq('/settings'));
    expect(mockProtect).toHaveBeenCalled();
  });

  it('allows unauthenticated access to /sign-in', async () => {
    await middleware(makeReq('/sign-in'));
    expect(mockProtect).not.toHaveBeenCalled();
  });

  it('allows unauthenticated access to /sign-up', async () => {
    await middleware(makeReq('/sign-up'));
    expect(mockProtect).not.toHaveBeenCalled();
  });

  it('allows unauthenticated access to /', async () => {
    await middleware(makeReq('/'));
    expect(mockProtect).not.toHaveBeenCalled();
  });

  it('allows unauthenticated access to /api/webhooks/clerk', async () => {
    await middleware(makeReq('/api/webhooks/clerk'));
    expect(mockProtect).not.toHaveBeenCalled();
  });

  it('protects unknown routes by default', async () => {
    await middleware(makeReq('/some-new-feature'));
    expect(mockProtect).toHaveBeenCalled();
  });
});
```

---

## Step 5: Extension Tests (REQ-02-08) + API Client Tests

### 5.1 API Client Tests

**File:** `smart-apply-extension/test/api-client.spec.ts` (CREATE)

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { resetChromeMock, seedStorage } from './chrome-mock';

// Mock the auth module
vi.mock('../src/lib/auth', () => ({
  clearAuthToken: vi.fn(() => Promise.resolve()),
}));

// Mock the config module
vi.mock('../src/lib/config', () => ({
  config: { apiBaseUrl: 'http://localhost:3001' },
}));

// Mock global fetch
const mockFetch = vi.fn();
globalThis.fetch = mockFetch;

describe('apiFetch', () => {
  let apiFetch: <T>(path: string, init?: RequestInit) => Promise<T>;
  let clearAuthToken: ReturnType<typeof vi.fn>;

  beforeEach(async () => {
    resetChromeMock();
    vi.clearAllMocks();
    // Re-import to get fresh module
    const mod = await import('../src/lib/api-client');
    apiFetch = mod.apiFetch;
    const authMod = await import('../src/lib/auth');
    clearAuthToken = authMod.clearAuthToken as ReturnType<typeof vi.fn>;
  });

  it('attaches Bearer token from storage', async () => {
    seedStorage({ auth_token: 'test-token-123' });
    mockFetch.mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: () => Promise.resolve({ data: 'ok' }),
    });

    await apiFetch('/api/profile');

    expect(mockFetch).toHaveBeenCalledWith(
      'http://localhost:3001/api/profile',
      expect.objectContaining({
        headers: expect.objectContaining({
          Authorization: 'Bearer test-token-123',
        }),
      }),
    );
  });

  it('omits Authorization header when no token', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: () => Promise.resolve({ data: 'ok' }),
    });

    await apiFetch('/api/health');

    const callHeaders = mockFetch.mock.calls[0][1].headers;
    expect(callHeaders.Authorization).toBeUndefined();
  });

  it('returns parsed JSON on 200', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: () => Promise.resolve({ profile: { name: 'John' } }),
    });

    const result = await apiFetch('/api/profile');
    expect(result).toEqual({ profile: { name: 'John' } });
  });

  it('clears auth token on 401', async () => {
    seedStorage({ auth_token: 'expired-token' });
    mockFetch.mockResolvedValueOnce({ ok: false, status: 401 });

    await expect(apiFetch('/api/optimize')).rejects.toThrow('Session expired');
    expect(clearAuthToken).toHaveBeenCalled();
  });

  it('broadcasts SESSION_EXPIRED on 401', async () => {
    seedStorage({ auth_token: 'expired-token' });
    mockFetch.mockResolvedValueOnce({ ok: false, status: 401 });

    await expect(apiFetch('/api/optimize')).rejects.toThrow();
    expect(chrome.runtime.sendMessage).toHaveBeenCalledWith({ type: 'SESSION_EXPIRED' });
  });

  it('throws "Session expired" error on 401', async () => {
    seedStorage({ auth_token: 'expired-token' });
    mockFetch.mockResolvedValueOnce({ ok: false, status: 401 });

    await expect(apiFetch('/api/optimize')).rejects.toThrow(
      'Session expired. Please sign in again.',
    );
  });

  it('throws generic error on non-401 failure', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: false,
      status: 500,
      json: () => Promise.resolve({}),
    });

    await expect(apiFetch('/api/optimize')).rejects.toThrow('API error: 500');
  });

  it('includes body.message in error when available', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: false,
      status: 422,
      json: () => Promise.resolve({ message: 'Validation failed' }),
    });

    await expect(apiFetch('/api/optimize')).rejects.toThrow('Validation failed');
  });
});
```

### 5.2 Service Worker Tests

**File:** `smart-apply-extension/test/service-worker.spec.ts` (CREATE)

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { resetChromeMock, seedStorage } from './chrome-mock';

// Mock api-client
const mockApiFetch = vi.fn();
vi.mock('../src/lib/api-client', () => ({
  apiFetch: (...args: unknown[]) => mockApiFetch(...args),
}));

// Mock storage helpers
const mockSetStorage = vi.fn(() => Promise.resolve());
const mockGetStorage = vi.fn();
vi.mock('../src/lib/storage', () => ({
  setStorage: (...args: unknown[]) => mockSetStorage(...args),
  getStorage: (...args: unknown[]) => mockGetStorage(...args),
}));

describe('Service Worker Message Handlers', () => {
  let messageHandler: (
    message: Record<string, unknown>,
    sender: { tab?: { id?: number } },
    sendResponse: (response?: unknown) => void,
  ) => boolean | undefined;

  beforeEach(async () => {
    resetChromeMock();
    vi.clearAllMocks();

    // Import the module to trigger registration of onMessage listener
    await import('../src/background/service-worker');

    // Extract the registered message listener
    const calls = chrome.runtime.onMessage.addListener.mock.calls;
    messageHandler = calls[calls.length - 1][0];
  });

  describe('SYNC_PROFILE', () => {
    it('calls /api/profile/ingest with correct body', async () => {
      mockApiFetch.mockResolvedValueOnce({ profile: { full_name: 'John' } });

      await new Promise<void>((resolve) => {
        messageHandler(
          { type: 'SYNC_PROFILE', payload: { rawText: 'John Doe - Engineer', sourceUrl: 'https://linkedin.com/in/john' } },
          {},
          (response) => {
            expect(mockApiFetch).toHaveBeenCalledWith('/api/profile/ingest', {
              method: 'POST',
              body: expect.stringContaining('"source":"linkedin"'),
            });
            expect(response).toEqual(expect.objectContaining({ success: true }));
            resolve();
          },
        );
      });
    });

    it('caches profile in storage on success', async () => {
      mockApiFetch.mockResolvedValueOnce({ profile: { full_name: 'John' } });

      await new Promise<void>((resolve) => {
        messageHandler(
          { type: 'SYNC_PROFILE', payload: { rawText: 'John', sourceUrl: 'https://linkedin.com/in/john' } },
          {},
          () => {
            expect(mockSetStorage).toHaveBeenCalledWith('cached_profile', { full_name: 'John' });
            resolve();
          },
        );
      });
    });

    it('returns error on API failure', async () => {
      mockApiFetch.mockRejectedValueOnce(new Error('Network error'));

      await new Promise<void>((resolve) => {
        messageHandler(
          { type: 'SYNC_PROFILE', payload: { rawText: 'X', sourceUrl: 'https://linkedin.com/in/x' } },
          {},
          (response) => {
            expect(response).toEqual(expect.objectContaining({ success: false, error: 'Network error' }));
            resolve();
          },
        );
      });
    });
  });

  describe('SAVE_APPLICATION', () => {
    const optimizeResult = {
      ats_score_before: 48,
      ats_score_after: 85,
      optimized_resume_json: { summary: 'test' },
      suggested_changes: [],
    };

    const context = {
      company: 'Acme',
      jobTitle: 'Engineer',
      sourceUrl: 'https://linkedin.com/jobs/123',
      sourcePlatform: 'linkedin',
    };

    it('reads optimize context from storage', async () => {
      mockGetStorage.mockResolvedValueOnce(context);
      mockApiFetch.mockResolvedValueOnce({ application_id: 'app-1' });

      await new Promise<void>((resolve) => {
        messageHandler(
          { type: 'SAVE_APPLICATION', payload: { optimizeResult, selectedChanges: [0] } },
          {},
          () => {
            expect(mockGetStorage).toHaveBeenCalledWith('last_optimize_context');
            resolve();
          },
        );
      });
    });

    it('sends POST /api/applications with all fields', async () => {
      mockGetStorage.mockResolvedValueOnce(context);
      mockApiFetch.mockResolvedValueOnce({ application_id: 'app-1' });

      await new Promise<void>((resolve) => {
        messageHandler(
          { type: 'SAVE_APPLICATION', payload: { optimizeResult, selectedChanges: [0] } },
          {},
          () => {
            expect(mockApiFetch).toHaveBeenCalledWith('/api/applications', {
              method: 'POST',
              body: expect.stringContaining('"company_name":"Acme"'),
            });
            resolve();
          },
        );
      });
    });

    it('includes drive_link when provided', async () => {
      mockGetStorage.mockResolvedValueOnce(context);
      mockApiFetch.mockResolvedValueOnce({ application_id: 'app-1' });

      await new Promise<void>((resolve) => {
        messageHandler(
          { type: 'SAVE_APPLICATION', payload: { optimizeResult, selectedChanges: [], drive_link: 'https://drive.google.com/file/d/abc' } },
          {},
          () => {
            const callBody = JSON.parse(mockApiFetch.mock.calls[0][1].body);
            expect(callBody.drive_link).toBe('https://drive.google.com/file/d/abc');
            resolve();
          },
        );
      });
    });

    it('omits drive_link when not provided', async () => {
      mockGetStorage.mockResolvedValueOnce(context);
      mockApiFetch.mockResolvedValueOnce({ application_id: 'app-1' });

      await new Promise<void>((resolve) => {
        messageHandler(
          { type: 'SAVE_APPLICATION', payload: { optimizeResult, selectedChanges: [] } },
          {},
          () => {
            const callBody = JSON.parse(mockApiFetch.mock.calls[0][1].body);
            expect(callBody).not.toHaveProperty('drive_link');
            resolve();
          },
        );
      });
    });

    it('returns error when no optimize context', async () => {
      mockGetStorage.mockResolvedValueOnce(null);

      await new Promise<void>((resolve) => {
        messageHandler(
          { type: 'SAVE_APPLICATION', payload: { optimizeResult, selectedChanges: [] } },
          {},
          (response) => {
            expect(response).toEqual(expect.objectContaining({ success: false, error: 'No optimization context found' }));
            resolve();
          },
        );
      });
    });
  });

  describe('GET_AUTH_TOKEN', () => {
    it('retrieves token from chrome.storage.local', async () => {
      seedStorage({ auth_token: 'my-token' });

      await new Promise<void>((resolve) => {
        messageHandler(
          { type: 'GET_AUTH_TOKEN' },
          {},
          (response) => {
            expect(response).toEqual({ token: 'my-token' });
            resolve();
          },
        );
      });
    });
  });
});
```

---

## Step 6: Audit Log (REQ-02-10)

### 6.1 Database Migration

**File:** `supabase/migrations/00002_audit_events.sql` (CREATE)

```sql
CREATE TABLE IF NOT EXISTS audit_events (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  clerk_user_id text NOT NULL,
  event_type text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_audit_events_clerk_user_id ON audit_events (clerk_user_id);
CREATE INDEX idx_audit_events_event_type ON audit_events (event_type);
```

### 6.2 Webhook Service Audit Insert

**File:** `smart-apply-backend/src/modules/webhooks/webhooks.service.ts`  
**Action:** MODIFY — Add audit event insert after deletion.

Update the `handleUserDeleted` method:

```typescript
  private async handleUserDeleted(clerkUserId: string): Promise<void> {
    this.logger.log(`Deleting data for user: ${clerkUserId}`);

    const { error } = await this.supabase.admin
      .from('master_profiles')
      .delete()
      .eq('clerk_user_id', clerkUserId);

    if (error) {
      this.logger.error(
        `Failed to delete user data: ${error.message}`,
        error,
      );
      throw error;
    }

    // Write audit event (best-effort — don't block on failure)
    const { error: auditError } = await this.supabase.admin
      .from('audit_events')
      .insert({
        clerk_user_id: clerkUserId,
        event_type: 'user.deleted',
        metadata: {},
      });

    if (auditError) {
      this.logger.error(`Failed to write audit event: ${auditError.message}`, auditError);
    } else {
      this.logger.log(`Audit event recorded for user deletion: ${clerkUserId}`);
    }
  }
```

---

## Step 7: Extension Retry Buttons (REQ-02-11)

**File:** `smart-apply-extension/src/ui/popup/App.tsx`  
**Action:** MODIFY — Add retry buttons and SESSION_EXPIRED listener.

### Changes:

**1. Add new state variables** (after the existing state declarations):

```typescript
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [lastFailedAction, setLastFailedAction] = useState<'sync' | 'optimize' | null>(null);
```

**2. Add SESSION_EXPIRED listener** (new useEffect block after existing ones):

```typescript
  useEffect(() => {
    const listener = (message: { type: string }) => {
      if (message.type === 'SESSION_EXPIRED') {
        setStatus('Session expired. Please sign in again.');
        setScreen('login');
      }
    };
    chrome.runtime.onMessage.addListener(listener);
    return () => chrome.runtime.onMessage.removeListener(listener);
  }, []);
```

**3. Update the OPTIMIZE_RESULT listener** — add error state tracking:

Replace the existing error handling in the OPTIMIZE_RESULT listener:
```typescript
        } else {
          setStatus(message.error ?? 'Optimization failed');
          setScreen('dashboard');
        }
```

With:
```typescript
        } else {
          setErrorMessage(message.error ?? 'Optimization failed');
          setLastFailedAction('optimize');
          setScreen('dashboard');
        }
```

**4. Update the Sync Profile button** — add error state tracking:

Replace the sync button's onClick handler sendMessage callback:
```typescript
            chrome.runtime.sendMessage({ type: 'TRIGGER_SYNC' }, (response) => {
              if (response?.success) {
                setStatus('Profile synced successfully!');
              } else {
                setStatus(response?.error ?? 'Profile sync failed');
              }
            });
```

With:
```typescript
            chrome.runtime.sendMessage({ type: 'TRIGGER_SYNC' }, (response) => {
              if (response?.success) {
                setStatus('Profile synced successfully!');
                setErrorMessage(null);
                setLastFailedAction(null);
              } else {
                setErrorMessage(response?.error ?? 'Profile sync failed');
                setLastFailedAction('sync');
              }
            });
```

**5. Add retry UI** in the dashboard screen. Replace:
```tsx
      {status && (
        <p className="text-xs text-gray-500 text-center">{status}</p>
      )}
```

With:
```tsx
      {errorMessage && lastFailedAction && (
        <div role="alert" className="p-3 bg-red-50 border border-red-200 rounded-lg">
          <p className="text-xs text-red-700">{errorMessage}</p>
          <button
            className="mt-2 px-3 py-1 bg-red-600 text-white rounded text-xs"
            onClick={() => {
              setErrorMessage(null);
              setLastFailedAction(null);
              if (lastFailedAction === 'sync') {
                setStatus('Syncing profile…');
                chrome.runtime.sendMessage({ type: 'TRIGGER_SYNC' }, (response) => {
                  if (response?.success) {
                    setStatus('Profile synced successfully!');
                  } else {
                    setErrorMessage(response?.error ?? 'Profile sync failed');
                    setLastFailedAction('sync');
                  }
                });
              } else if (lastFailedAction === 'optimize') {
                setScreen('optimizing');
                setStatus(null);
                chrome.runtime.sendMessage({ type: 'TRIGGER_OPTIMIZE' });
              }
            }}
          >
            Retry
          </button>
        </div>
      )}

      {status && !errorMessage && (
        <p className="text-xs text-gray-500 text-center">{status}</p>
      )}
```

---

## Step 8: CI Pipeline (REQ-02-09)

**File:** `.github/workflows/ci.yml`  
**Action:** MODIFY — Add build + test for all 4 packages.

Replace the full file with:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci

      # Typecheck all packages
      - run: npx tsc -p smart-apply-shared/tsconfig.json --noEmit
      - run: npx tsc -p smart-apply-backend/tsconfig.json --noEmit
      - run: npx tsc -p smart-apply-web/tsconfig.json --noEmit
      - run: npx tsc -p smart-apply-extension/tsconfig.json --noEmit

      # Test all packages
      - run: npm -w @smart-apply/shared run test
      - run: npm -w @smart-apply/api run test
      - run: npm -w @smart-apply/web run test
      - run: npm -w @smart-apply/extension run test

      # Build all packages
      - run: npm -w @smart-apply/shared run build
      - run: npm -w @smart-apply/web run build
        env:
          NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY: ${{ secrets.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY }}
      - run: npm -w @smart-apply/extension run build
        env:
          VITE_GOOGLE_OAUTH_CLIENT_ID: ${{ secrets.VITE_GOOGLE_OAUTH_CLIENT_ID }}
```

---

## Verification

### After Each Phase

```bash
# Phase 1 — Security fixes
cd smart-apply-web && npx tsc --noEmit && cd ..
cd smart-apply-backend && npx tsc --noEmit && cd ..
cd smart-apply-extension && npx tsc --noEmit && cd ..

# Phase 2 — Drive completion
cd smart-apply-extension && npx tsc --noEmit && cd ..

# Phase 3 — Test infrastructure
cd smart-apply-shared && npm test && cd ..
cd smart-apply-web && npm test && cd ..
cd smart-apply-extension && npm test && cd ..

# Phase 4 — Regression tests
cd smart-apply-shared && npm test && cd ..
cd smart-apply-web && npm test && cd ..

# Phase 5 — Extension tests
cd smart-apply-extension && npm test && cd ..

# Phase 6 — CI + Audit + Retry
cd smart-apply-backend && npm test && cd ..
cd smart-apply-extension && npx tsc --noEmit && cd ..
```

### Full Suite Verification

```bash
# All packages typecheck
npx tsc -p smart-apply-shared/tsconfig.json --noEmit
npx tsc -p smart-apply-backend/tsconfig.json --noEmit
npx tsc -p smart-apply-web/tsconfig.json --noEmit
npx tsc -p smart-apply-extension/tsconfig.json --noEmit

# All packages test
npm -w @smart-apply/shared run test
npm -w @smart-apply/api run test
npm -w @smart-apply/web run test
npm -w @smart-apply/extension run test

# All packages build
npm -w @smart-apply/shared run build
npm -w @smart-apply/api run build
npm -w @smart-apply/web run build
npm -w @smart-apply/extension run build
```

---

## Rollback Plan

If implementation breaks existing functionality:
1. `git stash` current changes
2. Verify existing tests pass: `npm -w @smart-apply/api run test`
3. Re-read the specific IMPL step for the failing component
4. Identify the breaking change and fix incrementally
5. If dependencies are the issue: `git checkout -- package-lock.json && npm ci`
