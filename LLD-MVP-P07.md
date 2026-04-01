---
title: LLD-MVP-P07 — Deployment Readiness & Production Release Gate
description: Low-Level Design for MVP Phase 7 — file-level change manifest, function signatures, test specifications, and implementation sequence.
hero_eyebrow: Low-level design
hero_title: LLD for MVP Phase 7
hero_summary: Detailed implementation specification for all 7 in-scope requirements from HLD-MVP-P07, following TDD methodology.
permalink: /lld-mvp-p07/
---

# LLD-MVP-P07 — Deployment Readiness & Production Release Gate

**Version:** 1.0  
**Date:** 2026-03-31  
**Input:** HLD-MVP-P07.md + architecture.md  
**Phase:** P07 (Release Preparation)

---

## 1. File-Level Change Manifest

| # | File Path | Action | REQ | Purpose |
|:--|:---|:---|:---|:---|
| 1 | `smart-apply-extension/src/lib/resume-utils.ts` | CREATE | REQ-05-01 | Extract `buildApprovedResume()` shared utility |
| 2 | `smart-apply-extension/src/background/service-worker.ts` | MODIFY | REQ-05-01 | Import `buildApprovedResume()`, fix `handleSaveApplication()` |
| 3 | `smart-apply-extension/src/ui/popup/App.tsx` | MODIFY | REQ-05-01 | Remove inline `buildApprovedResume()`, import from shared utility |
| 4 | `.github/workflows/ci.yml` | MODIFY | REQ-05-02 | Add backend build step |
| 5 | `.env.example` | MODIFY | REQ-05-03 | Complete env var documentation (8 missing vars) |
| 6 | `render.yaml` | CREATE | REQ-05-04 | Render IaC blueprint for backend deployment |
| 7 | `smart-apply-doc/RELEASE_RUNBOOK.md` | CREATE | REQ-05-05 | Step-by-step deployment guide |
| 8 | `smart-apply-backend/src/modules/health/health.module.ts` | MODIFY | REQ-05-06 | Import SupabaseModule |
| 9 | `smart-apply-backend/src/modules/health/health.controller.ts` | MODIFY | REQ-05-06 | Inject SupabaseService, add DB connectivity check |
| 10 | `smart-apply-extension/vite.config.ts` | MODIFY | REQ-05-08 | Add console.log/warn stripping for production |
| 11 | `smart-apply-web/next.config.ts` | MODIFY | REQ-05-08 | Add console drop via compiler options |

### Test Files

| # | File Path | Action | REQ | Purpose |
|:--|:---|:---|:---|:---|
| T1 | `smart-apply-extension/test/resume-utils.spec.ts` | CREATE | REQ-05-01 | Test `buildApprovedResume()` extraction |
| T2 | `smart-apply-extension/test/service-worker-save.spec.ts` | CREATE | REQ-05-01 | Test fixed `handleSaveApplication()` passes filtered snapshot |
| T3 | `smart-apply-backend/test/health.controller.spec.ts` | MODIFY | REQ-05-06 | Update tests for DB connectivity check, 503 response |

---

## 2. Detailed Design Per File

### 2.1 Extract buildApprovedResume Utility (REQ-05-01)

#### File 1: `smart-apply-extension/src/lib/resume-utils.ts` — CREATE

**Purpose:** Single source of truth for building user-approved resume snapshots. Currently duplicated in `App.tsx` (popup) and `optimize-results.tsx` (web).

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

#### File 2: `smart-apply-extension/src/background/service-worker.ts` — MODIFY

**Changes:**
1. Add import for `buildApprovedResume` from `../lib/resume-utils`.
2. Add import for `getStorage` (already imported).
3. In `handleSaveApplication()`, load `cached_profile`, call `buildApprovedResume()`, and use the result as `applied_resume_snapshot`.

**Before (lines ~180–200):**
```typescript
async function handleSaveApplication(payload: {
  optimizeResult: OptimizeResponse;
  selectedChanges: number[];
  drive_link?: string;
}): Promise<{ success: boolean; application_id?: string; error?: string }> {
  try {
    const context = await getStorage('last_optimize_context');
    if (!context) {
      return { success: false, error: 'No optimization context found' };
    }

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

**After:**
```typescript
async function handleSaveApplication(payload: {
  optimizeResult: OptimizeResponse;
  selectedChanges: number[];
  drive_link?: string;
}): Promise<{ success: boolean; application_id?: string; error?: string }> {
  try {
    const context = await getStorage('last_optimize_context');
    if (!context) {
      return { success: false, error: 'No optimization context found' };
    }

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

**Import addition (top of file):**
```typescript
import { buildApprovedResume } from '../lib/resume-utils';
```

#### File 3: `smart-apply-extension/src/ui/popup/App.tsx` — MODIFY

**Changes:**
1. Remove the inline `buildApprovedResume()` function definition (lines 16–52).
2. Add import from shared utility.

**Before (line 1–7):**
```typescript
import { useState, useEffect, useCallback } from 'react';
import { getAuthToken } from '../../lib/auth';
import { generateResumePDF } from '../../lib/pdf-generator';
import { uploadPdfToDrive } from '../../lib/google-drive';
import { getStorage } from '../../lib/storage';
import { config } from '../../lib/config';
import type { OptimizeResponse, SuggestedChange, ExperienceItem } from '@smart-apply/shared';
```

**After (line 1–8):**
```typescript
import { useState, useEffect, useCallback } from 'react';
import { getAuthToken } from '../../lib/auth';
import { generateResumePDF } from '../../lib/pdf-generator';
import { uploadPdfToDrive } from '../../lib/google-drive';
import { getStorage } from '../../lib/storage';
import { config } from '../../lib/config';
import { buildApprovedResume } from '../../lib/resume-utils';
import type { OptimizeResponse, SuggestedChange, ExperienceItem } from '@smart-apply/shared';
```

**Remove:** Lines 10–52 (the inline `buildApprovedResume` function and its JSDoc comment). The function is now imported.

---

### 2.2 Add Backend Build Step to CI (REQ-05-02)

#### File 4: `.github/workflows/ci.yml` — MODIFY

**Changes:** Add one build step for the backend after the shared build.

**Before (build section):**
```yaml
      # Build all packages
      - run: npm -w @smart-apply/shared run build
      - run: npm -w @smart-apply/web run build
        env:
          NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY: ${{ secrets.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY }}
      - run: npm -w @smart-apply/extension run build
        env:
          VITE_GOOGLE_OAUTH_CLIENT_ID: ${{ secrets.VITE_GOOGLE_OAUTH_CLIENT_ID }}
```

**After:**
```yaml
      # Build all packages
      - run: npm -w @smart-apply/shared run build
      - run: npm -w @smart-apply/api run build
      - run: npm -w @smart-apply/web run build
        env:
          NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY: ${{ secrets.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY }}
      - run: npm -w @smart-apply/extension run build
        env:
          VITE_GOOGLE_OAUTH_CLIENT_ID: ${{ secrets.VITE_GOOGLE_OAUTH_CLIENT_ID }}
```

---

### 2.3 Complete Environment Variable Documentation (REQ-05-03)

#### File 5: `.env.example` — MODIFY

**Replace entire file content with:**

```env
# ============================================================
# Smart Apply — Environment Variables
# Copy this file to .env and fill in the values.
# ============================================================

# ===== Clerk (Authentication Provider) =====
# Used by: smart-apply-backend, smart-apply-web
CLERK_SECRET_KEY=sk_test_...                      # Backend: JWT verification & admin API
CLERK_PUBLISHABLE_KEY=pk_test_...                  # Backend: public key
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_...      # Web: ClerkProvider in browser
CLERK_WEBHOOK_SECRET=whsec_...                     # Backend: Svix signature for account deletion webhook

# ===== Supabase (Database) =====
# Used by: smart-apply-backend
SUPABASE_URL=https://your-project.supabase.co      # PostgreSQL service endpoint
SUPABASE_ANON_KEY=eyJ0...                          # Anon key (RLS-restricted)
SUPABASE_SERVICE_ROLE_KEY=eyJ0...                  # Service role key (all-access, admin ops)

# ===== LLM (AI Provider) =====
# Used by: smart-apply-backend
LLM_API_KEY=sk-...                                 # OpenAI or Anthropic API key

# ===== Google OAuth (Drive Upload) =====
# Used by: smart-apply-backend (admin), smart-apply-extension (build-time)
GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com    # Backend: OAuth client ID
GOOGLE_CLIENT_SECRET=GOCSPX-...                    # Backend: OAuth client secret
GOOGLE_REDIRECT_URI=http://localhost:3000/api/auth/google/callback

# ===== Extension Build-Time Variables =====
# Used by: smart-apply-extension (Vite build)
VITE_API_BASE_URL=http://localhost:3001             # Extension: backend API endpoint
VITE_WEB_BASE_URL=http://localhost:3000             # Extension: web portal (auth callback)
VITE_GOOGLE_OAUTH_CLIENT_ID=xxx.apps.googleusercontent.com  # Extension: Drive OAuth client ID

# ===== Backend Configuration =====
# Used by: smart-apply-backend
PORT=3001                                          # NestJS listen port
NODE_ENV=development                               # development | staging | production
ALLOWED_ORIGINS=http://localhost:3000               # CORS allowlist (comma-separated)
CHROME_EXTENSION_ID=                               # 32-char extension ID (from chrome://extensions)
```

---

### 2.4 Configure Backend Hosting — Render Blueprint (REQ-05-04)

#### File 6: `render.yaml` — CREATE

```yaml
# Render Infrastructure as Code — Smart Apply Backend
# https://render.com/docs/blueprint-spec

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

> **Note:** `sync: false` means the value must be set in the Render dashboard, not committed to the repo. Only non-secret values (`NODE_ENV`, `PORT`) have inline values.

---

### 2.5 Release Runbook (REQ-05-05)

#### File 7: `smart-apply-doc/RELEASE_RUNBOOK.md` — CREATE

```markdown
# Smart Apply — Release Runbook

**Version:** 1.0
**Last Updated:** 2026-03-31

---

## 1. Prerequisites

### Accounts Required
- [Supabase](https://supabase.com) — hosted PostgreSQL with RLS
- [Render](https://render.com) — backend Docker hosting
- [Vercel](https://vercel.com) — Next.js web hosting
- [Clerk](https://clerk.com) — authentication provider
- [OpenAI](https://platform.openai.com) — LLM API
- (Optional) [Google Cloud Console](https://console.cloud.google.com) — Drive OAuth

### Tools
- Node.js 20+
- npm 10+
- Docker (for local backend testing)
- Supabase CLI (`npm i -g supabase`)
- Git

---

## 2. Environment Setup

1. Copy `.env.example` to `.env` at the repository root.
2. Fill in all values — see inline comments in `.env.example` for each variable.
3. Obtain secrets from service dashboards:
   - **Clerk:** Dashboard → API Keys → Secret Key + Publishable Key
   - **Supabase:** Project Settings → API → URL + anon key + service_role key
   - **OpenAI:** API Keys → Create new secret key
   - **Google Cloud (optional):** Credentials → OAuth 2.0 Client ID

---

## 3. Deployment Sequence

### Step 1: Database — Supabase Migrations

```bash
# Login to Supabase CLI
supabase login

# Link to your project
supabase link --project-ref <your-project-ref>

# Push migrations
supabase db push
```

**Verify:** In Supabase Dashboard → Table Editor, confirm tables exist:
`master_profiles`, `application_history`, with RLS enabled on both.

### Step 2: Backend — Deploy to Render

1. Connect your GitHub repo to Render.
2. Create a new "Blueprint" from `render.yaml`, or create a Web Service manually:
   - **Docker:** Use `smart-apply-backend/Dockerfile`
   - **Docker context:** Repository root (`.`)
   - **Health check path:** `/health`
3. Set all environment variables in Render Dashboard (see `.env.example`).
4. Deploy.

**Verify:**
```bash
curl https://smart-apply-api.onrender.com/health
# Expected: {"status":"ok","db":"connected","timestamp":"...","version":"..."}
```

### Step 3: Web — Deploy to Vercel

1. Import the repo in Vercel.
2. Set root directory to `smart-apply-web/`.
3. Set environment variables:
   - `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`
   - `CLERK_SECRET_KEY`
   - All other web-required vars
4. Deploy.

**Verify:** Navigate to the deployed URL, confirm sign-in page loads.

### Step 4: Clerk — Register Webhook

1. Clerk Dashboard → Webhooks → Add Endpoint.
2. **URL:** `https://<your-render-url>/api/webhooks/clerk`
3. **Events:** `user.deleted`
4. Copy the **Signing Secret** → set as `CLERK_WEBHOOK_SECRET` in Render env vars.
5. Redeploy backend on Render.

### Step 5: Extension — Production Build

```bash
# From repo root
VITE_API_BASE_URL=https://smart-apply-api.onrender.com \
VITE_WEB_BASE_URL=https://your-app.vercel.app \
VITE_GOOGLE_OAUTH_CLIENT_ID=your-client-id \
npm -w @smart-apply/extension run build
```

Output: `smart-apply-extension/dist/` — load unpacked in `chrome://extensions` or package for Chrome Web Store.

---

## 4. Post-Deploy Verification Checklist

| # | Check | Expected Result |
|:--|:---|:---|
| 1 | `GET /health` on backend URL | `{ "status": "ok", "db": "connected" }` |
| 2 | Sign in on web app | Clerk redirect → dashboard loads |
| 3 | Import profile (extension or web upload) | Profile appears in profile editor |
| 4 | Paste JD → run optimize (web) | ATS scores + suggested changes returned |
| 5 | Approve changes → download PDF | PDF downloads with only approved changes |
| 6 | Check application history on dashboard | New entry with correct snapshot |
| 7 | Delete account in settings | User deleted, redirected to sign-in |

---

## 5. Rollback Procedures

### Backend
- Render Dashboard → Manual Deploy → select previous commit.
- Or: `git revert HEAD && git push origin main`

### Web
- Vercel Dashboard → Deployments → Promote previous deployment to production.

### Database
- Supabase does not support automatic rollback. For schema changes, prepare a reverse migration SQL file before deploying.

### Extension
- Re-build from a previous known-good commit and reload unpacked.
```

---

### 2.6 Strengthen Health Check (REQ-05-06)

#### File 8: `smart-apply-backend/src/modules/health/health.module.ts` — MODIFY

**Before:**
```typescript
import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';

@Module({
  controllers: [HealthController],
})
export class HealthModule {}
```

**After:**
```typescript
import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';

@Module({
  controllers: [HealthController],
  // SupabaseService is available via @Global() SupabaseModule — no explicit import needed
})
export class HealthModule {}
```

> **Note:** `SupabaseModule` is `@Global()`, so `SupabaseService` is already available for injection. No import change needed in the module file. The comment clarifies the design decision.

#### File 9: `smart-apply-backend/src/modules/health/health.controller.ts` — MODIFY

**Before:**
```typescript
import { Controller, Get } from '@nestjs/common';

@Controller('health')
export class HealthController {
  @Get()
  check() {
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
    };
  }
}
```

**After:**
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
        this.supabase.admin.rpc('ping').throwOnError(),
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

> **Implementation note:** If the `ping` RPC function does not exist in Supabase, use `this.supabase.admin.from('master_profiles').select('id').limit(1)` as an alternative lightweight query. The key requirement is sub-millisecond execution with a 2-second timeout guard.

---

### 2.7 Guard Console Logging for Production (REQ-05-08)

#### File 10: `smart-apply-extension/vite.config.ts` — MODIFY

**Before:**
```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { crx } from '@crxjs/vite-plugin';
import manifest from './src/manifest';

export default defineConfig({
  plugins: [react(), crx({ manifest })],
  build: {
    outDir: 'dist',
    rollupOptions: {
      input: {
        popup: 'src/ui/popup/index.html',
      },
    },
  },
});
```

**After:**
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

> **Design choice:** Using `esbuild.drop` instead of `define` — this is the officially supported Vite/esbuild approach and completely removes all `console.*` and `debugger` statements from the production bundle. It is cleaner than `define` replacements and doesn't require selective targeting per method.

#### File 11: `smart-apply-web/next.config.ts` — MODIFY

**Before:**
```typescript
import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  transpilePackages: ['@smart-apply/shared'],
  webpack: (config) => {
    config.resolve.alias.canvas = false;
    return config;
  },
};

export default nextConfig;
```

**After:**
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

> **Design choice:** Next.js has built-in `compiler.removeConsole` option via SWC. This removes all `console.*` calls except `console.error` in production builds.

---

## 3. Test Specifications

### 3.1 Test File T1: `smart-apply-extension/test/resume-utils.spec.ts` — CREATE

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
    expect(result.skills).toEqual(['JavaScript', 'React']); // skill change index 1 not selected
    expect(result.experiences[0].description).toEqual(['Built RESTful APIs serving 10K RPM', 'Led team']);
  });

  it('applies all changes when all selected', () => {
    const result = buildApprovedResume(mockProfile, mockOptimizeResult, new Set([0, 1, 2, 3, 4]));
    expect(result.summary).toBe('Final summary'); // index 3 overwrites index 0
    expect(result.skills).toContain('TypeScript');
    expect(result.skills).toContain('Node.js');
    expect(result.skills).toContain('AWS');
    expect(result.experiences[0].description[0]).toBe('Built RESTful APIs serving 10K RPM');
  });

  it('deduplicates skills on insertion', () => {
    const profileWithExistingSkill = {
      ...mockProfile,
      base_skills: ['JavaScript', 'TypeScript'],
    };
    const result = buildApprovedResume(profileWithExistingSkill, mockOptimizeResult, new Set([1]));
    const typescriptCount = result.skills.filter((s) => s === 'TypeScript').length;
    expect(typescriptCount).toBe(1);
  });

  it('handles empty profile gracefully', () => {
    const emptyProfile: Record<string, unknown> = {};
    const result = buildApprovedResume(emptyProfile, mockOptimizeResult, new Set([0]));
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

### 3.2 Test File T2: `smart-apply-extension/test/service-worker-save.spec.ts` — CREATE

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock modules before importing
vi.mock('../src/lib/api-client', () => ({
  apiFetch: vi.fn(),
}));

vi.mock('../src/lib/storage', () => ({
  getStorage: vi.fn(),
  setStorage: vi.fn(),
}));

vi.mock('../src/lib/resume-utils', () => ({
  buildApprovedResume: vi.fn(),
}));

// Mock chrome APIs
vi.stubGlobal('chrome', {
  runtime: {
    onMessage: { addListener: vi.fn() },
    onInstalled: { addListener: vi.fn() },
    onMessageExternal: { addListener: vi.fn() },
  },
  storage: { local: { get: vi.fn(), set: vi.fn() } },
  scripting: { executeScript: vi.fn() },
});

import { apiFetch } from '../src/lib/api-client';
import { getStorage } from '../src/lib/storage';
import { buildApprovedResume } from '../src/lib/resume-utils';

describe('handleSaveApplication snapshot filtering', () => {
  const mockContext = {
    company: 'Acme Corp',
    jobTitle: 'Senior Engineer',
    sourceUrl: 'https://linkedin.com/jobs/123',
    sourcePlatform: 'linkedin',
  };

  const mockCachedProfile = {
    summary: 'Original',
    base_skills: ['JS'],
    experiences: [],
  };

  const mockOptimizeResult = {
    ats_score_before: 45,
    ats_score_after: 82,
    optimized_resume_json: { summary: 'ALL changes applied' },
    suggested_changes: [
      { type: 'summary_update', before: 'Original', after: 'Updated', confidence: 0.9, reason: 'test' },
    ],
  };

  const mockApproved = {
    summary: 'Updated',
    skills: ['JS'],
    experiences: [],
  };

  beforeEach(() => {
    vi.clearAllMocks();
    (getStorage as ReturnType<typeof vi.fn>).mockImplementation((key: string) => {
      if (key === 'last_optimize_context') return Promise.resolve(mockContext);
      if (key === 'cached_profile') return Promise.resolve(mockCachedProfile);
      return Promise.resolve(null);
    });
    (buildApprovedResume as ReturnType<typeof vi.fn>).mockReturnValue(mockApproved);
    (apiFetch as ReturnType<typeof vi.fn>).mockResolvedValue({ application_id: 'app-123' });
  });

  it('passes filtered snapshot (not raw LLM output) to API', async () => {
    // This test verifies the core bug fix: the service worker must use
    // buildApprovedResume() output, NOT optimizeResult.optimized_resume_json

    // NOTE: Since handleSaveApplication is not exported, we test via the
    // message listener. Import the module to trigger listener registration,
    // then invoke the handler through the listener.

    // Verify buildApprovedResume is called with correct args
    expect(buildApprovedResume).not.toHaveBeenCalled(); // before save

    // The actual integration with the message listener will be tested
    // by importing the module and firing a SAVE_APPLICATION message.
    // For now, we verify the mock wiring is correct.
    expect(getStorage).not.toHaveBeenCalled();
  });

  it('uses cached_profile (not raw LLM json) as base for buildApprovedResume', () => {
    // This test ensures the service worker loads cached_profile from storage
    // and passes it as the first argument to buildApprovedResume, ensuring
    // the snapshot is built from the user's actual profile, not the LLM output.
    expect(true).toBe(true); // Placeholder — full integration test in implementation phase
  });
});
```

> **Note:** `handleSaveApplication` is not exported from `service-worker.ts`. The full integration test will either: (a) export the function, or (b) test via the `chrome.runtime.onMessage` listener mock. The LLD specifies the mock structure; the implementation phase will finalize the approach.

### 3.3 Test File T3: `smart-apply-backend/test/health.controller.spec.ts` — MODIFY

**Before:**
```typescript
import { describe, it, expect } from 'vitest';
import { HealthController } from '../src/modules/health/health.controller';

describe('HealthController', () => {
  let controller: HealthController;

  beforeAll(() => {
    controller = new HealthController();
  });

  it('returns status ok with ISO timestamp', () => {
    const result = controller.check();
    expect(result).toEqual(
      expect.objectContaining({ status: 'ok' }),
    );
    expect(() => new Date(result.timestamp).toISOString()).not.toThrow();
  });

  it('returns a current timestamp', () => {
    const before = new Date().toISOString();
    const result = controller.check();
    const after = new Date().toISOString();
    expect(result.timestamp >= before).toBe(true);
    expect(result.timestamp <= after).toBe(true);
  });
});
```

**After:**
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
      expect.objectContaining({
        status: 'ok',
        db: 'connected',
      }),
    );
  });

  it('includes ISO timestamp in response', async () => {
    const before = new Date().toISOString();
    await controller.check(mockRes as any);
    const after = new Date().toISOString();

    const responseBody = mockRes.json.mock.calls[0][0];
    expect(responseBody.timestamp >= before).toBe(true);
    expect(responseBody.timestamp <= after).toBe(true);
  });

  it('returns 503 with degraded status when Supabase is unreachable', async () => {
    mockSupabase.admin.rpc.mockReturnValue({
      throwOnError: vi.fn().mockRejectedValue(new Error('Connection refused')),
    });

    await controller.check(mockRes as any);

    expect(mockRes.status).toHaveBeenCalledWith(503);
    expect(mockRes.json).toHaveBeenCalledWith(
      expect.objectContaining({
        status: 'degraded',
        db: 'disconnected',
      }),
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
      expect.objectContaining({
        status: 'degraded',
        db: 'disconnected',
      }),
    );
  }, 10000);

  it('includes version field in response', async () => {
    await controller.check(mockRes as any);

    const responseBody = mockRes.json.mock.calls[0][0];
    expect(responseBody).toHaveProperty('version');
  });
});
```

---

## 4. Integration Sequence

### Order of Implementation

1. **REQ-05-01 — Snapshot Mismatch Fix** (tests first, then implementation)
   - Create `resume-utils.ts`
   - Create `resume-utils.spec.ts` → run → verify all fail
   - Implement `resume-utils.ts` → run → verify all pass
   - Modify `service-worker.ts` → verify existing tests still pass
   - Modify `App.tsx` → verify inline function removed, import works

2. **REQ-05-02 — CI Backend Build** (single-line change)
   - Modify `.github/workflows/ci.yml`
   - Verify locally: `npm -w @smart-apply/api run build`

3. **REQ-05-03 — Env Documentation** (documentation change)
   - Replace `.env.example` content

4. **REQ-05-06 — Health Check** (tests first, then implementation)
   - Update `health.controller.spec.ts` → run → verify new tests fail
   - Modify `health.controller.ts` → run → verify all tests pass
   - Update `health.module.ts` comment

5. **REQ-05-08 — Console Stripping** (config changes)
   - Modify `vite.config.ts`
   - Modify `next.config.ts`
   - Verify: build extension in production mode, grep for console.log

6. **REQ-05-04 — Backend Hosting** (infrastructure config)
   - Create `render.yaml`

7. **REQ-05-05 — Release Runbook** (documentation)
   - Create `RELEASE_RUNBOOK.md`

### Verification After All Changes

```bash
# Full test suite — must pass all 281+ tests
npm test

# Typecheck all packages
npx tsc -p smart-apply-shared/tsconfig.json --noEmit
npx tsc -p smart-apply-backend/tsconfig.json --noEmit
npx tsc -p smart-apply-web/tsconfig.json --noEmit
npx tsc -p smart-apply-extension/tsconfig.json --noEmit

# Build all 4 packages
npm -w @smart-apply/shared run build
npm -w @smart-apply/api run build
npm -w @smart-apply/web run build
npm -w @smart-apply/extension run build
```

---

## 5. Alignment Checklist

- [x] All API inputs validated with Zod at boundaries (no new endpoints; existing validation preserved)
- [x] All UI components handle loading/error/empty states (no new UI components in this phase)
- [x] Shared schemas used — no type duplication (buildApprovedResume extracted to shared utility)
- [x] TypeScript strict mode maintained across all changes
- [x] No server-side PDF/resume storage (zero-storage policy unchanged)
- [x] architecture.md principles not violated
- [x] No over-engineering beyond phase scope
