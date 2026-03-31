---
title: "LLD-MVP-P02 — P1 Stabilisation & Production Readiness"
permalink: /design/lld-mvp-p02/
---

# LLD-MVP-P02 — P1 Stabilisation & Production Readiness

**Version:** 1.0  
**Date:** 2026-03-28  
**Input:** HLD-MVP-P02.md + architecture.md  
**Phase:** P1 (Should-Have)

---

## 1. File-Level Change Manifest

| # | File Path | Action | REQ | Purpose |
|:--|:---|:---|:---|:---|
| 1 | `supabase/migrations/00001_init.sql` | CREATE | REQ-01-08 | Initial DB migration from existing schema |
| 2 | `supabase/config.toml` | CREATE | REQ-01-08 | Supabase CLI project config |
| 3 | `smart-apply-backend/src/modules/webhooks/webhooks.module.ts` | CREATE | REQ-01-09 | NestJS module for webhook handling |
| 4 | `smart-apply-backend/src/modules/webhooks/webhooks.controller.ts` | CREATE | REQ-01-09 | POST /api/webhooks/clerk endpoint |
| 5 | `smart-apply-backend/src/modules/webhooks/webhooks.service.ts` | CREATE | REQ-01-09 | Signature verification + user deletion logic |
| 6 | `smart-apply-backend/src/app.module.ts` | MODIFY | REQ-01-09 | Register WebhooksModule |
| 7 | `smart-apply-backend/src/main.ts` | MODIFY | REQ-01-09 | Enable rawBody for webhook signature verification |
| 8 | `smart-apply-backend/test/scoring.service.spec.ts` | CREATE | REQ-01-11 | Smoke tests for ATS scoring engine |
| 9 | `smart-apply-backend/test/auth.guard.spec.ts` | CREATE | REQ-01-11 | Smoke tests for Clerk auth guard |
| 10 | `smart-apply-backend/test/profiles.service.spec.ts` | CREATE | REQ-01-11 | Smoke tests for profile CRUD |
| 11 | `smart-apply-backend/test/applications.service.spec.ts` | CREATE | REQ-01-11 | Smoke tests for application CRUD |
| 12 | `smart-apply-backend/test/optimize.service.spec.ts` | CREATE | REQ-01-11 | Smoke tests for optimization pipeline |
| 13 | `smart-apply-backend/test/webhooks.controller.spec.ts` | CREATE | REQ-01-11 | Smoke tests for webhook endpoint |
| 14 | `smart-apply-backend/vitest.config.ts` | CREATE | REQ-01-11 | Vitest configuration |
| 15 | `.github/workflows/ci.yml` | CREATE | REQ-01-10 | CI pipeline: build + test on PR/push |
| 16 | `smart-apply-backend/Dockerfile` | CREATE | REQ-01-10 | Docker image for backend |
| 17 | `smart-apply-backend/.dockerignore` | CREATE | REQ-01-10 | Docker build exclusions |
| 18 | `smart-apply-web/vercel.json` | CREATE | REQ-01-10 | Vercel deployment config |
| 19 | `smart-apply-extension/src/lib/google-drive.ts` | CREATE | REQ-01-06 | Google Drive upload via REST API |
| 20 | `smart-apply-extension/src/manifest.ts` | MODIFY | REQ-01-06 | Add oauth2 config for Google Drive |
| 21 | `smart-apply-extension/src/ui/popup/App.tsx` | MODIFY | REQ-01-06 | Wire Drive upload after PDF generation |
| 22 | `smart-apply-extension/src/background/service-worker.ts` | MODIFY | REQ-01-06 | Add UPLOAD_TO_DRIVE message handler |

---

## 2. Detailed Design Per File

### 2.1 Supabase Migrations (REQ-01-08)

#### File 1: `supabase/migrations/00001_init.sql`
- **Action:** CREATE
- **Content:** Copy of `smart-apply-doc/resume_flow_schema.sql` wrapped in the Supabase migration format.
- **Notes:** The existing schema already includes `begin;` / `commit;`, utility functions, enums, tables, RLS policies, triggers, and indexes. Place it verbatim as the initial migration.

#### File 2: `supabase/config.toml`
- **Action:** CREATE
- **Content:** Minimal Supabase CLI config with project_id placeholder.
```toml
[project]
id = "_placeholder_"

[db]
port = 54322
major_version = 15
```

---

### 2.2 Webhooks Module (REQ-01-09)

#### File 3: `smart-apply-backend/src/modules/webhooks/webhooks.module.ts`
```typescript
import { Module } from '@nestjs/common';
import { WebhooksController } from './webhooks.controller';
import { WebhooksService } from './webhooks.service';
import { SupabaseModule } from '../../infra/supabase/supabase.module';

@Module({
  imports: [SupabaseModule],
  controllers: [WebhooksController],
  providers: [WebhooksService],
})
export class WebhooksModule {}
```

#### File 4: `smart-apply-backend/src/modules/webhooks/webhooks.controller.ts`
- **Route:** `POST /api/webhooks/clerk`
- **No auth guard** — webhook endpoints use signature verification instead.
- **Raw body access:** Uses `@Req()` to get `req.rawBody` (Buffer).
- **Headers:** Extracts `webhook-id`, `webhook-timestamp`, `webhook-signature`.
- **Delegates** to `WebhooksService.handleClerkEvent()`.
- **Returns:** `{ received: true }` on success, throws `BadRequestException` on invalid signature or missing headers.

```typescript
import { Controller, Post, Req, BadRequestException, Logger } from '@nestjs/common';
import { WebhooksService } from './webhooks.service';
import type { Request } from 'express';

@Controller('api/webhooks')
export class WebhooksController {
  private readonly logger = new Logger(WebhooksController.name);

  constructor(private readonly webhooks: WebhooksService) {}

  @Post('clerk')
  async handleClerk(@Req() req: Request & { rawBody?: Buffer }) {
    const webhookId = req.headers['webhook-id'] as string | undefined;
    const webhookTimestamp = req.headers['webhook-timestamp'] as string | undefined;
    const webhookSignature = req.headers['webhook-signature'] as string | undefined;

    if (!webhookId || !webhookTimestamp || !webhookSignature) {
      throw new BadRequestException('Missing webhook headers');
    }

    const rawBody = req.rawBody;
    if (!rawBody) {
      throw new BadRequestException('Missing raw body');
    }

    await this.webhooks.handleClerkEvent(
      rawBody,
      { 'webhook-id': webhookId, 'webhook-timestamp': webhookTimestamp, 'webhook-signature': webhookSignature },
    );

    return { received: true };
  }
}
```

#### File 5: `smart-apply-backend/src/modules/webhooks/webhooks.service.ts`
- **Verify signature** using `standardwebhooks` `Webhook` class.
- **Parse payload** and check `type === 'user.deleted'`.
- **Delete** from `master_profiles` by `clerk_user_id` — CASCADE handles children.
- **Idempotent:** If user doesn't exist, log and return (no error).

```typescript
import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Webhook } from 'standardwebhooks';
import { SupabaseService } from '../../infra/supabase/supabase.service';

interface ClerkWebhookEvent {
  type: string;
  data: { id: string; deleted?: boolean };
}

@Injectable()
export class WebhooksService {
  private readonly logger = new Logger(WebhooksService.name);
  private readonly wh: Webhook;

  constructor(
    private readonly config: ConfigService,
    private readonly supabase: SupabaseService,
  ) {
    this.wh = new Webhook(this.config.getOrThrow<string>('CLERK_WEBHOOK_SECRET'));
  }

  async handleClerkEvent(
    rawBody: Buffer,
    headers: Record<string, string>,
  ): Promise<void> {
    let event: ClerkWebhookEvent;
    try {
      event = this.wh.verify(rawBody.toString('utf8'), headers) as ClerkWebhookEvent;
    } catch {
      throw new BadRequestException('Invalid webhook signature');
    }

    this.logger.log(`Received Clerk event: ${event.type}`);

    if (event.type === 'user.deleted') {
      await this.handleUserDeleted(event.data.id);
    }
    // Ignore other event types silently
  }

  private async handleUserDeleted(clerkUserId: string): Promise<void> {
    this.logger.warn(`Deleting all data for user ${clerkUserId}`);

    const { error } = await this.supabase.admin
      .from('master_profiles')
      .delete()
      .eq('clerk_user_id', clerkUserId);

    if (error) {
      this.logger.error(`Failed to delete user data: ${error.message}`);
      throw new Error(`Deletion failed: ${error.message}`);
    }

    this.logger.log(`User data deleted for ${clerkUserId}`);
  }
}
```

#### File 6: `smart-apply-backend/src/app.module.ts` (MODIFY)
- Add `WebhooksModule` import to the `imports` array.

#### File 7: `smart-apply-backend/src/main.ts` (MODIFY)
- Change `NestFactory.create(AppModule)` to `NestFactory.create(AppModule, { rawBody: true })`.

---

### 2.3 Smoke Tests (REQ-01-11)

#### File 14: `smart-apply-backend/vitest.config.ts`
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

#### File 8: `test/scoring.service.spec.ts`
Tests the `ScoringService.calculate()` method with:
- **Happy path:** Profile with matching skills returns score > 50.
- **Empty profile:** Returns 0 for hard skills, non-zero defaults for role/seniority.
- **Synonym matching:** `node.js` in JD matches `nodejs` in profile.
- **Seniority match/mismatch:** Senior JD + senior profile ⇒ 10 pts; Senior JD + junior profile ⇒ 0 pts.
- **Keyword spam cap:** Repeated keywords don't inflate score beyond cap.

All tests instantiate `ScoringService` directly (no DI mocking needed — it has no dependencies).

#### File 9: `test/auth.guard.spec.ts`
Tests `ClerkAuthGuard` with mocked `ConfigService` and mocked `verifyToken`:
- **Valid token:** Returns `true`, sets `request.userId`.
- **Missing header:** Throws `UnauthorizedException`.
- **Invalid token:** Mock `verifyToken` to throw, guard throws `UnauthorizedException`.

#### File 10: `test/profiles.service.spec.ts`
Tests `ProfilesService` with mocked `SupabaseService` and `LlmService`:
- **getProfile:** Returns profile data from mocked Supabase `select().single()`.
- **getProfile not found:** Throws `NotFoundException`.
- **ingestProfile:** Calls LLM parse, upserts to Supabase, returns success.
- **updateProfile:** Calls Supabase update, returns updated data.

#### File 11: `test/applications.service.spec.ts`
Tests `ApplicationsService` with mocked `SupabaseService`:
- **list:** Returns items array.
- **create:** Inserts and returns application_id.
- **updateStatus:** Updates status, returns updated record.
- **updateStatus not found:** Throws `NotFoundException`.

#### File 12: `test/optimize.service.spec.ts`
Tests `OptimizeService` with mocked `ProfilesService`, `ScoringService`, `LlmService`:
- **Happy path:** Returns scores before/after, suggested changes, optimized JSON.
- **LLM failure (partial):** Returns pre-optimization score with warning.
- **Summary unchanged:** No summary_update in suggested_changes.

#### File 13: `test/webhooks.controller.spec.ts`
Tests `WebhooksController` and `WebhooksService` together:
- **Valid signature + user.deleted:** Returns `{ received: true }`, verifies Supabase delete was called.
- **Invalid signature:** Throws `BadRequestException`.
- **Missing headers:** Throws `BadRequestException`.
- **Non-deletion event:** Returns `{ received: true }`, no delete called.

---

### 2.4 Deployment Configuration (REQ-01-10)

#### File 15: `.github/workflows/ci.yml`
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
      - run: npx tsc -p smart-apply-shared/tsconfig.json --noEmit
      - run: npx tsc -p smart-apply-backend/tsconfig.json --noEmit
      - run: npx tsc -p smart-apply-web/tsconfig.json --noEmit
      - run: npx tsc -p smart-apply-extension/tsconfig.json --noEmit
      - run: npm -w @smart-apply/api run test
      - run: npm -w @smart-apply/web run build
        env:
          NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY: ${{ secrets.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY }}
```

#### File 16: `smart-apply-backend/Dockerfile`
```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json ./
COPY smart-apply-shared/ ./smart-apply-shared/
COPY smart-apply-backend/ ./smart-apply-backend/
RUN npm ci --workspace=@smart-apply/api --include-workspace-root
RUN npm -w @smart-apply/api run build

FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/smart-apply-shared ./smart-apply-shared
COPY --from=builder /app/smart-apply-backend/dist ./dist
COPY --from=builder /app/smart-apply-backend/package.json ./package.json
EXPOSE 3001
CMD ["node", "dist/main"]
```

#### File 17: `smart-apply-backend/.dockerignore`
```
node_modules
dist
.env
.env.*
*.md
test
```

#### File 18: `smart-apply-web/vercel.json`
```json
{
  "framework": "nextjs",
  "installCommand": "cd .. && npm ci",
  "buildCommand": "cd .. && npm -w @smart-apply/web run build",
  "outputDirectory": ".next"
}
```

---

### 2.5 Google Drive Upload (REQ-01-06)

#### File 19: `smart-apply-extension/src/lib/google-drive.ts`
```typescript
const DRIVE_UPLOAD_URL = 'https://www.googleapis.com/upload/drive/v3/files';
const DRIVE_FILES_URL = 'https://www.googleapis.com/drive/v3/files';

export async function getGoogleAuthToken(): Promise<string> {
  return new Promise((resolve, reject) => {
    chrome.identity.getAuthToken(
      { interactive: true, scopes: ['https://www.googleapis.com/auth/drive.file'] },
      (token) => {
        if (chrome.runtime.lastError || !token) {
          reject(new Error(chrome.runtime.lastError?.message ?? 'Failed to get Google auth token'));
        } else {
          resolve(token);
        }
      }
    );
  });
}

async function findOrCreateFolder(token: string, name: string, parentId?: string): Promise<string> {
  // Search for existing folder
  let q = `name='${name}' and mimeType='application/vnd.google-apps.folder' and trashed=false`;
  if (parentId) q += ` and '${parentId}' in parents`;

  const searchRes = await fetch(
    `${DRIVE_FILES_URL}?q=${encodeURIComponent(q)}&fields=files(id)`,
    { headers: { Authorization: `Bearer ${token}` } },
  );
  const searchData = await searchRes.json();
  if (searchData.files?.length > 0) {
    return searchData.files[0].id;
  }

  // Create folder
  const metadata: Record<string, unknown> = {
    name,
    mimeType: 'application/vnd.google-apps.folder',
  };
  if (parentId) metadata.parents = [parentId];

  const createRes = await fetch(DRIVE_FILES_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(metadata),
  });
  const created = await createRes.json();
  return created.id;
}

export async function uploadPdfToDrive(
  pdfBlob: Blob,
  fileName: string,
  companyName: string,
): Promise<{ fileId: string; webViewLink: string }> {
  const token = await getGoogleAuthToken();

  // Create folder structure: Smart-Apply/{companyName}/
  const rootFolderId = await findOrCreateFolder(token, 'Smart-Apply');
  const companyFolderId = await findOrCreateFolder(token, companyName, rootFolderId);

  // Multipart upload
  const metadata = JSON.stringify({
    name: fileName,
    parents: [companyFolderId],
  });

  const boundary = '---smartapply' + Date.now();
  const body = [
    `--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${metadata}\r\n`,
    `--${boundary}\r\nContent-Type: application/pdf\r\n\r\n`,
  ];

  const metadataPart = new TextEncoder().encode(body[0]);
  const pdfPart = new Uint8Array(await pdfBlob.arrayBuffer());
  const closingBoundary = new TextEncoder().encode(`\r\n--${boundary}--`);
  const separatorPart = new TextEncoder().encode(body[1]);

  const combined = new Uint8Array(
    metadataPart.length + separatorPart.length + pdfPart.length + closingBoundary.length,
  );
  combined.set(metadataPart, 0);
  combined.set(separatorPart, metadataPart.length);
  combined.set(pdfPart, metadataPart.length + separatorPart.length);
  combined.set(closingBoundary, metadataPart.length + separatorPart.length + pdfPart.length);

  const uploadRes = await fetch(
    `${DRIVE_UPLOAD_URL}?uploadType=multipart&fields=id,webViewLink`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': `multipart/related; boundary=${boundary}`,
      },
      body: combined,
    },
  );

  if (!uploadRes.ok) {
    const errText = await uploadRes.text();
    throw new Error(`Drive upload failed: ${uploadRes.status} ${errText}`);
  }

  const result = await uploadRes.json();
  return { fileId: result.id, webViewLink: result.webViewLink };
}
```

#### File 20: `smart-apply-extension/src/manifest.ts` (MODIFY)
- Add `oauth2` section:
```typescript
oauth2: {
  client_id: 'GOOGLE_OAUTH_CLIENT_ID_PLACEHOLDER',
  scopes: ['https://www.googleapis.com/auth/drive.file'],
},
```

#### File 21: `smart-apply-extension/src/ui/popup/App.tsx` (MODIFY)
- After PDF blob is generated, call `uploadPdfToDrive(blob, fileName, companyName)`.
- On success, include `drive_link: webViewLink` in the `SAVE_APPLICATION` message.
- On failure (user declines OAuth, network error), still save application without drive_link and show a non-blocking warning.

#### File 22: `smart-apply-extension/src/background/service-worker.ts` (MODIFY)
- No changes needed — the `SAVE_APPLICATION` handler already forwards all fields to the API, and the backend API already accepts `drive_link`.

---

## 3. Integration Sequence

Implementation order (respects dependency chain):

1. **REQ-01-08** (Supabase migrations) — No code dependencies, just file creation.
2. **REQ-01-09** (Webhooks) — Depends on Supabase being set up conceptually, but code-wise independent.
3. **REQ-01-11** (Smoke tests) — Tests existing + new webhook code. Must be done after REQ-01-09.
4. **REQ-01-10** (Deployment) — CI workflow references test command, so must be after REQ-01-11.
5. **REQ-01-06** (Google Drive) — Independent of other P1 items, but last because it requires Google Cloud Console setup for OAuth client ID.

---

## 4. Alignment Checklist

- [x] All API inputs validated with Zod at boundaries (webhook uses standardwebhooks signature verification instead — appropriate for external webhook)
- [x] Shared schemas from `@smart-apply/shared` used where applicable
- [x] TypeScript strict mode maintained
- [x] No new UI libraries introduced
- [x] Existing shadcn/ui components preferred
- [x] Architecture.md §7 component boundaries respected (Drive upload in extension, webhook in backend)
- [x] Architecture.md §11 security: webhook signature verification, drive.file scope
- [x] No PII in logs (webhook logs user ID only, not personal data)
- [x] RLS enforced via existing Supabase service (admin key for webhook deletion — appropriate for server-side cascade)

---

## 5. Architect Review

**Verdict:** APPROVED

### Summary
The LLD is complete, architecturally sound, and properly scoped. All 5 active P1 requirements have detailed file-level specifications. The integration order respects dependency chains. Security measures (webhook signature verification, drive.file scope, raw body access) are correct.

### Approved Items
- REQ-01-08: Migration approach (Supabase CLI with existing schema)
- REQ-01-09: Webhook module design with standardwebhooks, raw body, CASCADE delete
- REQ-01-11: Vitest smoke test strategy with mocked dependencies
- REQ-01-10: Multi-target deployment (Vercel + Docker + GitHub Actions CI)
- REQ-01-06: Google Drive upload via chrome.identity + Drive REST API

### Notes for Implementation
- In `google-drive.ts` `findOrCreateFolder()`: properly escape single quotes in folder names before constructing the Drive API query string (replace `'` with `\\'` in the name parameter).
- The Dockerfile uses a multi-stage build — verify that `file:` workspace references resolve correctly during `npm ci` by copying both shared and backend directories.
- For Vercel: the `installCommand` with `cd ..` assumes Vercel root is set to `smart-apply-web/`. Document this requirement.
