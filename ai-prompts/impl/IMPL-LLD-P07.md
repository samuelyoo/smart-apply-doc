---
title: Implementation Prompt — Phase P07
description: TDD-based implementation prompt for Phase 7 (Deployment Readiness), derived from approved LLD-MVP-P07.
hero_eyebrow: Implementation prompt
hero_title: IMPL-LLD-P07 — Deployment Readiness
hero_summary: Self-contained, executable implementation instructions following TDD methodology for all 7 in-scope requirements.
permalink: /ai-prompts/impl-lld-p07/
---

# Implementation Prompt — Phase P07: Deployment Readiness

> **Source:** Approved LLD-MVP-P07.md  
> **Methodology:** TDD — Red (write failing tests) → Green (implement) → Refactor  
> **Total Changes:** 11 source files + 3 test files + 2 documentation files

---

## Context

### Project State

- **Repository:** smart-apply monorepo (npm workspaces)
- **All 281 tests pass** — zero regressions allowed
- **Packages:** smart-apply-shared, smart-apply-backend, smart-apply-web, smart-apply-extension

### Files to Read First

| File | Purpose |
|:--|:---|
| `smart-apply-extension/src/background/service-worker.ts` | Contains the snapshot mismatch bug (line ~194) |
| `smart-apply-extension/src/ui/popup/App.tsx` | Contains inline `buildApprovedResume()` to extract |
| `smart-apply-extension/src/lib/storage.ts` | `getStorage()` used to load cached profile |
| `smart-apply-backend/src/modules/health/health.controller.ts` | Current shallow health check |
| `smart-apply-backend/src/modules/health/health.module.ts` | HealthModule registration |
| `smart-apply-backend/src/infra/supabase/supabase.service.ts` | SupabaseService to inject |
| `smart-apply-backend/test/health.controller.spec.ts` | Existing health tests to update |
| `.github/workflows/ci.yml` | CI pipeline to fix |
| `.env.example` | Env docs to complete |
| `smart-apply-extension/vite.config.ts` | Extension build config |
| `smart-apply-web/next.config.ts` | Web build config |

### Shared Schemas

- `@smart-apply/shared` → `OptimizeResponse`, `ExperienceItem`, `SuggestedChange`, `CreateApplicationRequest`

### What This Phase Builds

Fix the extension's data integrity bug where the wrong resume snapshot is saved, complete the CI pipeline with a backend build step, document all environment variables, configure Render hosting, write the release runbook, strengthen the health check, and strip console logs from production builds.

---

## Step 1: Write Tests (Red Phase)

Write ALL test files BEFORE any implementation code. Run tests — they should FAIL.

### Test File 1: `smart-apply-extension/test/resume-utils.spec.ts`

```typescript
import { describe, it, expect } from 'vitest';
import { buildApprovedResume } from '../src/lib/resume-utils';
import type { OptimizeResponse } from '@smart-apply/shared';

const mockProfile: Record<string, unknown> = {
  summary: 'Original summary',
  base_skills: ['JavaScript', 'React'],
  experiences: [
    {
      company: 'Acme Corp',
      title: 'Engineer',
      description: ['Built APIs', 'Led team'],
      start_date: '2020-01',
      end_date: '2023-01',
    },
  ],
};

const mockOptimizeResult: OptimizeResponse = {
  ats_score_before: 45,
  ats_score_after: 82,
  optimized_resume_json: {} as Record<string, unknown>,
  suggested_changes: [
    { type: 'summary_update', before: 'Original summary', after: 'Updated summary', confidence: 0.9, reason: 'Better ATS match' },
    { type: 'skills_insertion', before: null, after: 'TypeScript, Node.js', confidence: 0.8, reason: 'Missing skills' },
    { type: 'bullet_injection', before: 'Built APIs', after: 'Built RESTful APIs serving 10K RPM', confidence: 0.7, reason: 'Quantified impact' },
    { type: 'summary_update', before: 'Updated summary', after: 'Final summary', confidence: 0.5, reason: 'Alternative' },
    { type: 'skills_insertion', before: null, after: 'AWS', confidence: 0.4, reason: 'Cloud skills' },
  ],
};

describe('buildApprovedResume', () => {
  it('returns original profile when no changes selected', () => {
    const result = buildApprovedResume(mockProfile, mockOptimizeResult, new Set());
    expect(result.summary).toBe('Original summary');
    expect(result.skills).toEqual(['JavaScript', 'React']);
    expect(result.experiences[0].description).toEqual(['Built APIs', 'Led team']);
  });

  it('applies only selected changes', () => {
    const result = buildApprovedResume(mockProfile, mockOptimizeResult, new Set([0, 2]));
    expect(result.summary).toBe('Updated summary');
    expect(result.skills).toEqual(['JavaScript', 'React']);
    expect(result.experiences[0].description).toEqual(['Built RESTful APIs serving 10K RPM', 'Led team']);
  });

  it('applies all changes when all selected', () => {
    const result = buildApprovedResume(mockProfile, mockOptimizeResult, new Set([0, 1, 2, 3, 4]));
    expect(result.summary).toBe('Final summary');
    expect(result.skills).toContain('TypeScript');
    expect(result.skills).toContain('Node.js');
    expect(result.skills).toContain('AWS');
    expect(result.experiences[0].description[0]).toBe('Built RESTful APIs serving 10K RPM');
  });

  it('deduplicates skills on insertion', () => {
    const profileWithExistingSkill = { ...mockProfile, base_skills: ['JavaScript', 'TypeScript'] };
    const result = buildApprovedResume(profileWithExistingSkill, mockOptimizeResult, new Set([1]));
    const typescriptCount = result.skills.filter((s) => s === 'TypeScript').length;
    expect(typescriptCount).toBe(1);
  });

  it('handles empty profile gracefully', () => {
    const result = buildApprovedResume({}, mockOptimizeResult, new Set([0]));
    expect(result.summary).toBe('Updated summary');
    expect(result.skills).toEqual([]);
    expect(result.experiences).toEqual([]);
  });

  it('does not mutate the original profile', () => {
    const originalDesc = [...(mockProfile.experiences as Array<{ description: string[] }>)[0].description];
    buildApprovedResume(mockProfile, mockOptimizeResult, new Set([2]));
    expect((mockProfile.experiences as Array<{ description: string[] }>)[0].description).toEqual(originalDesc);
  });
});
```

### Test File 2: `smart-apply-backend/test/health.controller.spec.ts` (REPLACE)

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { HealthController } from '../src/modules/health/health.controller';
import { SupabaseService } from '../src/infra/supabase/supabase.service';

describe('HealthController', () => {
  let controller: HealthController;
  let mockSupabase: { admin: { rpc: ReturnType<typeof vi.fn> } };
  let mockRes: { status: ReturnType<typeof vi.fn>; json: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    mockSupabase = {
      admin: {
        rpc: vi.fn().mockReturnValue({
          throwOnError: vi.fn().mockResolvedValue({ data: true }),
        }),
      },
    };
    controller = new HealthController(mockSupabase as unknown as SupabaseService);
    mockRes = {
      status: vi.fn().mockReturnThis(),
      json: vi.fn().mockReturnThis(),
    };
  });

  it('returns status ok with db connected when Supabase is reachable', async () => {
    await controller.check(mockRes as any);
    expect(mockRes.status).toHaveBeenCalledWith(200);
    expect(mockRes.json).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'ok', db: 'connected' }),
    );
  });

  it('includes ISO timestamp in response', async () => {
    const before = new Date().toISOString();
    await controller.check(mockRes as any);
    const after = new Date().toISOString();
    const body = mockRes.json.mock.calls[0][0];
    expect(body.timestamp >= before).toBe(true);
    expect(body.timestamp <= after).toBe(true);
  });

  it('returns 503 with degraded status when Supabase is unreachable', async () => {
    mockSupabase.admin.rpc.mockReturnValue({
      throwOnError: vi.fn().mockRejectedValue(new Error('Connection refused')),
    });
    await controller.check(mockRes as any);
    expect(mockRes.status).toHaveBeenCalledWith(503);
    expect(mockRes.json).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'degraded', db: 'disconnected' }),
    );
  });

  it('returns 503 when DB check exceeds 2-second timeout', async () => {
    mockSupabase.admin.rpc.mockReturnValue({
      throwOnError: vi.fn().mockImplementation(
        () => new Promise((resolve) => setTimeout(resolve, 5000)),
      ),
    });
    await controller.check(mockRes as any);
    expect(mockRes.status).toHaveBeenCalledWith(503);
    expect(mockRes.json).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'degraded', db: 'disconnected' }),
    );
  }, 10000);

  it('includes version field in response', async () => {
    await controller.check(mockRes as any);
    const body = mockRes.json.mock.calls[0][0];
    expect(body).toHaveProperty('version');
  });
});
```

### Verify Red Phase

```bash
# Extension tests — resume-utils should fail (module not found)
npm -w @smart-apply/extension run test -- --run

# Backend tests — health controller should fail (constructor signature changed)
npm -w @smart-apply/api run test -- --run
```

**Expected:** New/modified tests FAIL. All other tests still pass.

---

## Step 2: Implement (Green Phase)

Implement the minimum code to make all tests pass.

### File 1: `smart-apply-extension/src/lib/resume-utils.ts` — CREATE

**Action:** CREATE

```typescript
import type { OptimizeResponse, ExperienceItem } from '@smart-apply/shared';

/**
 * Merge only user-approved suggested changes into a copy of the cached profile.
 * Unapproved changes keep the original profile values.
 */
export function buildApprovedResume(
  cachedProfile: Record<string, unknown>,
  optimizeResult: OptimizeResponse,
  selectedChanges: Set<number>,
): { summary: string; skills: string[]; experiences: ExperienceItem[] } {
  let summary = (cachedProfile.summary as string) ?? '';
  let skills = [...((cachedProfile.base_skills as string[]) ?? [])];
  const experiences: ExperienceItem[] = JSON.parse(
    JSON.stringify(cachedProfile.experiences ?? []),
  );

  optimizeResult.suggested_changes.forEach((change, index) => {
    if (!selectedChanges.has(index)) return;

    switch (change.type) {
      case 'summary_update':
        if (change.after) summary = change.after;
        break;
      case 'skills_insertion':
        if (change.after) {
          const newSkills = change.after.split(', ').filter(Boolean);
          skills = [...new Set([...skills, ...newSkills])];
        }
        break;
      case 'bullet_injection':
        for (const exp of experiences) {
          const bulletIdx = exp.description.findIndex((b) => b === change.before);
          if (bulletIdx !== -1 && change.after) {
            exp.description[bulletIdx] = change.after;
            break;
          }
        }
        break;
    }
  });

  return { summary, skills, experiences };
}
```

### File 2: `smart-apply-extension/src/ui/popup/App.tsx` — MODIFY

1. Add import: `import { buildApprovedResume } from '../../lib/resume-utils';`
2. Remove the inline `buildApprovedResume` function (lines 10–52 approximately — the function and its JSDoc comment).
3. Remove `SuggestedChange` and `ExperienceItem` from the `@smart-apply/shared` type import if they are only used by the removed function.

### File 3: `smart-apply-extension/src/background/service-worker.ts` — MODIFY

1. Add import at top:
   ```typescript
   import { buildApprovedResume } from '../lib/resume-utils';
   ```

2. In `handleSaveApplication()`, after loading context, add cached profile loading and filtering:

   **Replace:**
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

   **With:**
   ```typescript
       const cachedProfile = await getStorage('cached_profile');
       if (!cachedProfile) {
         return { success: false, error: 'No cached profile found' };
       }

       const approvedResume = buildApprovedResume(
         cachedProfile,
         payload.optimizeResult,
         new Set(payload.selectedChanges),
       );

       const body: CreateApplicationRequest = {
         company_name: context.company,
         job_title: context.jobTitle,
         source_platform: context.sourcePlatform as CreateApplicationRequest['source_platform'],
         source_url: context.sourceUrl,
         ats_score_before: payload.optimizeResult.ats_score_before,
         ats_score_after: payload.optimizeResult.ats_score_after,
         status: 'generated',
         applied_resume_snapshot: approvedResume as unknown as Record<string, unknown>,
         ...(payload.drive_link ? { drive_link: payload.drive_link } : {}),
       };
   ```

### File 4: `.github/workflows/ci.yml` — MODIFY

**Add after the shared build line:**
```yaml
      - run: npm -w @smart-apply/api run build
```

### File 5: `.env.example` — MODIFY

**Replace entire file content** with the complete categorized documentation (see LLD §2.3).

### File 6: `smart-apply-backend/src/modules/health/health.controller.ts` — MODIFY

**Replace entire file content:**
```typescript
import { Controller, Get, Res } from '@nestjs/common';
import { Response } from 'express';
import { SupabaseService } from '../../infra/supabase/supabase.service';

@Controller('health')
export class HealthController {
  constructor(private readonly supabase: SupabaseService) {}

  @Get()
  async check(@Res() res: Response) {
    const base = {
      timestamp: new Date().toISOString(),
      version: process.env.GIT_COMMIT_SHA ?? 'unknown',
    };

    try {
      const timeoutMs = 2000;
      await Promise.race([
        this.supabase.admin.from('master_profiles').select('id', { count: 'exact', head: true }),
        new Promise((_, reject) =>
          setTimeout(() => reject(new Error('DB health check timeout')), timeoutMs),
        ),
      ]);

      return res.status(200).json({ status: 'ok', db: 'connected', ...base });
    } catch {
      return res.status(503).json({ status: 'degraded', db: 'disconnected', ...base });
    }
  }
}
```

### File 7: `smart-apply-extension/vite.config.ts` — MODIFY

**Replace content:**
```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { crx } from '@crxjs/vite-plugin';
import manifest from './src/manifest';

export default defineConfig(({ mode }) => ({
  plugins: [react(), crx({ manifest })],
  build: {
    outDir: 'dist',
    rollupOptions: {
      input: {
        popup: 'src/ui/popup/index.html',
      },
    },
  },
  esbuild: mode === 'production'
    ? { drop: ['console', 'debugger'] }
    : undefined,
}));
```

### File 8: `smart-apply-web/next.config.ts` — MODIFY

**Replace content:**
```typescript
import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  transpilePackages: ['@smart-apply/shared'],
  webpack: (config) => {
    config.resolve.alias.canvas = false;
    return config;
  },
  compiler: {
    removeConsole: process.env.NODE_ENV === 'production'
      ? { exclude: ['error'] }
      : false,
  },
};

export default nextConfig;
```

### File 9: `render.yaml` — CREATE

```yaml
services:
  - type: web
    name: smart-apply-api
    runtime: docker
    dockerfilePath: smart-apply-backend/Dockerfile
    dockerContext: .
    repo: https://github.com/samuelyoo/smart-apply
    branch: main
    healthCheckPath: /health
    envVars:
      - key: NODE_ENV
        value: production
      - key: PORT
        value: "3001"
      - key: CLERK_SECRET_KEY
        sync: false
      - key: CLERK_PUBLISHABLE_KEY
        sync: false
      - key: CLERK_WEBHOOK_SECRET
        sync: false
      - key: SUPABASE_URL
        sync: false
      - key: SUPABASE_ANON_KEY
        sync: false
      - key: SUPABASE_SERVICE_ROLE_KEY
        sync: false
      - key: LLM_API_KEY
        sync: false
      - key: ALLOWED_ORIGINS
        sync: false
      - key: CHROME_EXTENSION_ID
        sync: false
```

### File 10: `smart-apply-doc/RELEASE_RUNBOOK.md` — CREATE

Create the full release runbook as specified in LLD §2.5.

### Verify Green Phase

```bash
# Run all tests
npm -w @smart-apply/extension run test -- --run
npm -w @smart-apply/api run test -- --run
npm -w @smart-apply/shared run test -- --run
npm -w @smart-apply/web run test -- --run
```

**Expected:** ALL tests pass (281 existing + new tests).

---

## Step 3: Refactor

Review implementation for:
- [ ] No duplicated `buildApprovedResume` code — App.tsx inline version removed, shared utility imported
- [ ] No leftover `console.log` references in production builds
- [ ] Health check timeout value (2000ms) is not a magic number — documented in code comment
- [ ] `render.yaml` has no committed secrets (`sync: false` on all sensitive vars)

### Verify After Refactor

```bash
npm test
```

**Expected:** ALL tests still pass.

---

## Step 4: Integration Check

### Manual Verification Steps

1. **Snapshot fix:** In the extension popup, optimize a JD, select 2 of 4 changes, download PDF, check that `SAVE_APPLICATION` message payload uses filtered snapshot (verify in DevTools network tab or service worker console).

2. **CI pipeline:** Run `npm -w @smart-apply/api run build` locally — should succeed.

3. **Env documentation:** Copy `.env.example` to `.env.test`, verify all packages can start with filled values.

4. **Health check:** Start backend locally with Supabase running, `curl http://localhost:3001/health` → expect `{"status":"ok","db":"connected",...}`. Stop Supabase, retry → expect `{"status":"degraded","db":"disconnected",...}` with HTTP 503.

5. **Console stripping:** Build extension in production mode (`NODE_ENV=production npm -w @smart-apply/extension run build`), then `grep -r "console.log" smart-apply-extension/dist/` → expect zero matches.

### Cross-Phase Verification

- All P01–P06 features still work (test suite covers this).
- Shared package still builds cleanly: `npm -w @smart-apply/shared run build`
- All 4 packages typecheck: `npx tsc -p <each>/tsconfig.json --noEmit`

---

## Rollback Plan

If implementation breaks existing functionality:

1. `git stash` current changes
2. Verify existing tests pass: `npm test`
3. Re-read LLD section for the failing component
4. Identify the breaking change and fix incrementally
5. If the health check causes issues in existing tests, the SupabaseService mock may need updating in other test files — check `supabase.service.spec.ts`
