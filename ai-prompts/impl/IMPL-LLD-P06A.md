---
title: IMPL-LLD-P06A — Implementation Prompt
description: Context-engineered TDD implementation prompt for MVP Phase 6A — Core Growth features (Cover Letter, Subscription, Templates).
---

# IMPL-LLD-P06A — Implementation Prompt

**Purpose:** Executable prompt for a coding agent to implement all 34 source files and 14 test files from LLD-MVP-P06 (Phase 6A), following strict TDD methodology.

---

## Role

You are a Senior Full-Stack Developer implementing MVP Phase 6A for the Smart Apply application. Follow TDD (Red → Green → Refactor) for every file. Write tests first, watch them fail, implement until green, then refactor.

---

## Context

### Project Structure
- **Monorepo** with npm workspaces: `smart-apply-shared`, `smart-apply-backend`, `smart-apply-web`, `smart-apply-extension`, `supabase`
- **Backend:** NestJS 11, TypeScript strict, Vitest, port 3001
- **Web:** Next.js 15, React 19, TanStack Query, Clerk auth, shadcn/ui, Tailwind, Vitest
- **Extension:** Chrome MV3, Vite + @crxjs, React popup, pdf-lib, Vitest
- **Shared:** Zod schemas + TypeScript types, compiled to JS
- **DB:** Supabase (PostgreSQL), RLS with `requesting_clerk_user_id()` function
- **Auth:** Clerk JWT verification via `ClerkAuthGuard`
- **LLM:** OpenAI GPT-4o via `LlmService` (120s timeout)

### Existing Patterns to Follow
- **Zod validation at API boundary:** See `optimizeRequestSchema` usage in `optimize.service.ts`
- **Webhook verification:** See `webhooks.service.ts` using `standardwebhooks` — Stripe follows same pattern with `stripe.webhooks.constructEvent()`
- **Guard pattern:** See `clerk-auth.guard.ts` implementing `CanActivate`
- **Module structure:** See any existing module (e.g., `optimize/`) — module.ts, controller.ts, service.ts
- **PDF generation:** See `pdf-generator.ts` — uses pdf-lib with Helvetica fonts
- **Test pattern:** See `test/*.spec.ts` — Vitest with mocked services injected via `Test.createTestingModule()`

### Key Type References
```typescript
// From @smart-apply/shared (existing)
type MasterProfile = { clerk_user_id, full_name, email, phone, location, linkedin_url, portfolio_url, summary, base_skills: string[], certifications, experiences: ExperienceItem[], education: EducationItem[], raw_profile_source, profile_version }
type OptimizeResponse = { ats_score_before, ats_score_after, extracted_requirements, suggested_changes: SuggestedChange[], optimized_resume_json }
type SuggestedChange = { type: 'summary_update' | 'skills_insertion' | 'bullet_injection' | 'warning', target_section, reason, before, after, confidence }
```

---

## Implementation Order (TDD)

Execute in this exact order. For each step:
1. Write test file(s)
2. Run tests — confirm RED (failures)
3. Implement source file(s)
4. Run tests — confirm GREEN (passing)
5. Refactor if needed — confirm still GREEN
6. Move to next step

### Step 1: Shared Schemas & Types

**Test files first:**
- `smart-apply-shared/test/cover-letter.schema.spec.ts`
- `smart-apply-shared/test/subscription.schema.spec.ts`
- `smart-apply-shared/test/template.schema.spec.ts`

**Then implement:**
- `smart-apply-shared/src/schemas/cover-letter.schema.ts`
- `smart-apply-shared/src/schemas/subscription.schema.ts`
- `smart-apply-shared/src/schemas/template.schema.ts`
- `smart-apply-shared/src/types/cover-letter.ts`
- `smart-apply-shared/src/types/subscription.ts`
- `smart-apply-shared/src/types/template.ts`
- MODIFY `smart-apply-shared/src/index.ts` — append new exports
- MODIFY `smart-apply-shared/src/schemas/application.schema.ts` — add `cover_letter_snapshot` and `template_id` fields

**Run:** `npm -w @smart-apply/shared run test`

### Step 2: Database Migrations

**Create:**
- `supabase/migrations/00003_user_usage.sql`
- `supabase/migrations/00004_application_cover_letter.sql`

**Verify:** `supabase db push` or manual review

### Step 3: Template Registry + PDF Refactor

**Test files first:**
- `smart-apply-extension/test/templates.spec.ts`
- MODIFY `smart-apply-extension/test/pdf-generator.spec.ts` — add template-aware tests

**Then implement:**
- `smart-apply-extension/src/lib/templates.ts` — template registry object
- MODIFY `smart-apply-extension/src/lib/pdf-generator.ts` — accept `templateId` parameter, read layout from registry

**Critical regression:** Classic template output must exactly match current hardcoded behavior.

**Run:** `npm -w @smart-apply/extension run test`

### Step 4: Cover Letter PDF

**Test first:**
- `smart-apply-extension/test/cover-letter-pdf.spec.ts`

**Then implement:**
- `smart-apply-extension/src/lib/cover-letter-pdf.ts`

**Run:** `npm -w @smart-apply/extension run test`

### Step 5: Subscription Guard + Usage Service

**Test files first:**
- `smart-apply-backend/test/subscription.guard.spec.ts`
- `smart-apply-backend/test/usage.service.spec.ts`

**Then implement:**
- `smart-apply-backend/src/modules/subscription/requires-tier.decorator.ts`
- `smart-apply-backend/src/modules/subscription/subscription.guard.ts`
- `smart-apply-backend/src/modules/subscription/usage.service.ts`

**Run:** `npm -w @smart-apply/api run test`

### Step 6: LLM Service — Cover Letter Method

**Implement:**
- MODIFY `smart-apply-backend/src/infra/llm/llm.service.ts` — add `generateCoverLetter()` method

**Test:** Update `smart-apply-backend/test/llm.service.spec.ts` with cover letter generation test

**Run:** `npm -w @smart-apply/api run test`

### Step 7: Cover Letter Module (Backend)

**Test files first:**
- `smart-apply-backend/test/cover-letter.service.spec.ts`
- `smart-apply-backend/test/cover-letter.controller.spec.ts`

**Then implement:**
- `smart-apply-backend/src/modules/cover-letter/cover-letter.service.ts`
- `smart-apply-backend/src/modules/cover-letter/cover-letter.controller.ts`
- `smart-apply-backend/src/modules/cover-letter/cover-letter.module.ts`

**Run:** `npm -w @smart-apply/api run test`

### Step 8: Subscription Module (Backend)

**Install dependency first:**
```bash
npm -w @smart-apply/api install stripe
```

**Test first:**
- `smart-apply-backend/test/subscription.service.spec.ts`

**Then implement:**
- `smart-apply-backend/src/modules/subscription/subscription.service.ts`
- `smart-apply-backend/src/modules/subscription/subscription.controller.ts`
- `smart-apply-backend/src/modules/subscription/subscription.module.ts`

**Run:** `npm -w @smart-apply/api run test`

### Step 9: Webhook + App Module Updates

**Implement:**
- MODIFY `smart-apply-backend/src/modules/webhooks/webhooks.controller.ts` — add Stripe webhook POST
- MODIFY `smart-apply-backend/src/modules/webhooks/webhooks.module.ts` — import SubscriptionModule
- MODIFY `smart-apply-backend/src/app.module.ts` — import CoverLetterModule, SubscriptionModule

**Run:** `npm -w @smart-apply/api run test`

### Step 10: Web Components

**Test files first:**
- `smart-apply-web/test/template-picker.spec.tsx`
- `smart-apply-web/test/cover-letter-section.spec.tsx`

**Then implement:**
- `smart-apply-web/src/components/optimize/template-picker.tsx`
- `smart-apply-web/src/components/optimize/cover-letter-section.tsx`
- `smart-apply-web/src/components/shared/upgrade-prompt.tsx`

**Run:** `npm -w @smart-apply/web run test`

### Step 11: Pricing Page

**Test first:**
- `smart-apply-web/test/pricing-page.spec.tsx`

**Then implement:**
- `smart-apply-web/src/components/pricing/pricing-card.tsx`
- `smart-apply-web/src/app/pricing/page.tsx`

**Run:** `npm -w @smart-apply/web run test`

### Step 12: Optimize Page Integration

**Implement:**
- MODIFY `smart-apply-web/src/app/optimize/page.tsx` — integrate TemplatePicker + CoverLetterSection

**Run:** `npm -w @smart-apply/web run test`

### Step 13: Extension Updates

**Implement:**
- MODIFY `smart-apply-extension/src/background/service-worker.ts` — add GENERATE_COVER_LETTER handler
- MODIFY `smart-apply-extension/src/ui/popup/App.tsx` — add template picker + cover letter UI

**Run:** `npm -w @smart-apply/extension run test`

---

## Environment Variables Required

Add to `.env` for local development:
```
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PRO_PRICE_ID=price_...
STRIPE_PREMIUM_PRICE_ID=price_...
```

---

## Acceptance Verification

After all 13 steps, run the full test suite:
```bash
npm -w @smart-apply/shared run test
npm -w @smart-apply/api run test
npm -w @smart-apply/web run test
npm -w @smart-apply/extension run test
```

All tests must pass. Zero regressions in existing test files.

---

## Constraints

- Do NOT add libraries not listed in Section 5 of LLD-MVP-P06
- Do NOT modify files not listed in the File-Level Change Manifest
- Use existing design-system components (shadcn/ui) — do not introduce new UI libraries
- All interactive elements must be keyboard-accessible with visible focus indicators
- Validate all API inputs at the boundary with Zod
- Handle loading, error, and empty states in UI components
- TypeScript strict mode — no `any` types, no `@ts-ignore`
