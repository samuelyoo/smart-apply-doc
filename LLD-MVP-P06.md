---
title: LLD-MVP-P06 — Core Growth Features
description: Low-Level Design for MVP Phase 6A — file-level change manifest, function signatures, test specifications, and implementation sequence for AI Cover Letter, Subscription Model, and Resume Templates.
hero_eyebrow: Low-level design
hero_title: LLD for MVP Phase 06
hero_summary: Detailed implementation specification for the three P0 requirements from BRD-MVP-06 / HLD-MVP-P06, following TDD methodology.
permalink: /lld-mvp-p06/
---

# LLD-MVP-P06 — Core Growth Features

**Version:** 1.0  
**Date:** 2026-03-31  
**Input:** HLD-MVP-P06.md  
**Phase:** P06A (AI Cover Letter, Subscription, Resume Templates)

---

## 1. File-Level Change Manifest

### Source Files

| # | File Path | Action | REQ | Purpose |
|:--|:---|:---|:---|:---|
| 1 | `smart-apply-shared/src/schemas/cover-letter.schema.ts` | CREATE | REQ-06-01 | Zod schema for cover letter generation request/response |
| 2 | `smart-apply-shared/src/schemas/subscription.schema.ts` | CREATE | REQ-06-02 | Subscription tier enum, checkout request, usage types |
| 3 | `smart-apply-shared/src/schemas/template.schema.ts` | CREATE | REQ-06-03 | Resume template ID enum, template layout config type |
| 4 | `smart-apply-shared/src/types/cover-letter.ts` | CREATE | REQ-06-01 | TypeScript types inferred from cover letter schema |
| 5 | `smart-apply-shared/src/types/subscription.ts` | CREATE | REQ-06-02 | TypeScript types inferred from subscription schema |
| 6 | `smart-apply-shared/src/types/template.ts` | CREATE | REQ-06-03 | TypeScript types inferred from template schema |
| 7 | `smart-apply-shared/src/index.ts` | MODIFY | ALL | Export new schemas and types |
| 8 | `smart-apply-shared/src/schemas/application.schema.ts` | MODIFY | REQ-06-01/03 | Add `cover_letter_snapshot` and `template_id` fields |
| 9 | `supabase/migrations/00003_user_usage.sql` | CREATE | REQ-06-02 | user_usage table with RLS |
| 10 | `supabase/migrations/00004_application_cover_letter.sql` | CREATE | REQ-06-01/03 | Add cover_letter_snapshot and template_id to application_history |
| 11 | `smart-apply-backend/src/modules/cover-letter/cover-letter.module.ts` | CREATE | REQ-06-01 | NestJS module for cover letter generation |
| 12 | `smart-apply-backend/src/modules/cover-letter/cover-letter.controller.ts` | CREATE | REQ-06-01 | POST /api/cover-letter/generate endpoint |
| 13 | `smart-apply-backend/src/modules/cover-letter/cover-letter.service.ts` | CREATE | REQ-06-01 | Cover letter generation logic via LLM |
| 14 | `smart-apply-backend/src/modules/subscription/subscription.module.ts` | CREATE | REQ-06-02 | NestJS module for Stripe subscription |
| 15 | `smart-apply-backend/src/modules/subscription/subscription.controller.ts` | CREATE | REQ-06-02 | Checkout + status endpoints |
| 16 | `smart-apply-backend/src/modules/subscription/subscription.service.ts` | CREATE | REQ-06-02 | Stripe Checkout, webhook handling, usage management |
| 17 | `smart-apply-backend/src/modules/subscription/subscription.guard.ts` | CREATE | REQ-06-02 | SubscriptionGuard: tier enforcement per endpoint |
| 18 | `smart-apply-backend/src/modules/subscription/requires-tier.decorator.ts` | CREATE | REQ-06-02 | `@RequiresTier()` custom decorator |
| 19 | `smart-apply-backend/src/modules/subscription/usage.service.ts` | CREATE | REQ-06-02 | Usage tracking: check & increment |
| 20 | `smart-apply-backend/src/infra/llm/llm.service.ts` | MODIFY | REQ-06-01 | Add `generateCoverLetter()` method |
| 21 | `smart-apply-backend/src/modules/webhooks/webhooks.controller.ts` | MODIFY | REQ-06-02 | Add Stripe webhook endpoint |
| 22 | `smart-apply-backend/src/modules/webhooks/webhooks.service.ts` | MODIFY | REQ-06-02 | Add Stripe event handling |
| 23 | `smart-apply-backend/src/app.module.ts` | MODIFY | ALL | Import CoverLetterModule, SubscriptionModule |
| 24 | `smart-apply-extension/src/lib/pdf-generator.ts` | MODIFY | REQ-06-03 | Refactor to accept template config parameter |
| 25 | `smart-apply-extension/src/lib/templates.ts` | CREATE | REQ-06-03 | Template registry (classic, modern, minimal) |
| 26 | `smart-apply-extension/src/lib/cover-letter-pdf.ts` | CREATE | REQ-06-01 | Cover letter PDF generator (business letter format) |
| 27 | `smart-apply-extension/src/background/service-worker.ts` | MODIFY | REQ-06-01 | Add GENERATE_COVER_LETTER message handler |
| 28 | `smart-apply-extension/src/ui/popup/App.tsx` | MODIFY | REQ-06-01/03 | Add cover letter generation UI, template picker |
| 29 | `smart-apply-web/src/app/pricing/page.tsx` | CREATE | REQ-06-02 | Pricing page with tier comparison |
| 30 | `smart-apply-web/src/components/pricing/pricing-card.tsx` | CREATE | REQ-06-02 | Pricing tier card component |
| 31 | `smart-apply-web/src/components/optimize/template-picker.tsx` | CREATE | REQ-06-03 | Template selection component with previews |
| 32 | `smart-apply-web/src/components/optimize/cover-letter-section.tsx` | CREATE | REQ-06-01 | Cover letter generate + edit + download section |
| 33 | `smart-apply-web/src/components/shared/upgrade-prompt.tsx` | CREATE | REQ-06-02 | Reusable upgrade prompt dialog |
| 34 | `smart-apply-web/src/app/optimize/page.tsx` | MODIFY | REQ-06-01/03 | Integrate cover letter section and template picker |

### Test Files

| # | File Path | Action | REQ | Purpose |
|:--|:---|:---|:---|:---|
| T1 | `smart-apply-shared/test/cover-letter.schema.spec.ts` | CREATE | REQ-06-01 | Validate cover letter schema parsing |
| T2 | `smart-apply-shared/test/subscription.schema.spec.ts` | CREATE | REQ-06-02 | Validate subscription schema parsing |
| T3 | `smart-apply-shared/test/template.schema.spec.ts` | CREATE | REQ-06-03 | Validate template schema |
| T4 | `smart-apply-backend/test/cover-letter.service.spec.ts` | CREATE | REQ-06-01 | Cover letter generation unit tests |
| T5 | `smart-apply-backend/test/cover-letter.controller.spec.ts` | CREATE | REQ-06-01 | Controller endpoint tests |
| T6 | `smart-apply-backend/test/subscription.service.spec.ts` | CREATE | REQ-06-02 | Stripe checkout, webhook, usage tests |
| T7 | `smart-apply-backend/test/subscription.guard.spec.ts` | CREATE | REQ-06-02 | Tier enforcement guard tests |
| T8 | `smart-apply-backend/test/usage.service.spec.ts` | CREATE | REQ-06-02 | Usage check/increment tests |
| T9 | `smart-apply-extension/test/pdf-generator.spec.ts` | MODIFY | REQ-06-03 | Add template-aware PDF tests |
| T10 | `smart-apply-extension/test/cover-letter-pdf.spec.ts` | CREATE | REQ-06-01 | Cover letter PDF generation tests |
| T11 | `smart-apply-extension/test/templates.spec.ts` | CREATE | REQ-06-03 | Template registry tests |
| T12 | `smart-apply-web/test/pricing-page.spec.tsx` | CREATE | REQ-06-02 | Pricing page render tests |
| T13 | `smart-apply-web/test/template-picker.spec.tsx` | CREATE | REQ-06-03 | Template picker interaction tests |
| T14 | `smart-apply-web/test/cover-letter-section.spec.tsx` | CREATE | REQ-06-01 | Cover letter section tests |

---

## 2. Detailed Design Per File

---

### 2.1 Shared Schemas & Types (REQ-06-01, REQ-06-02, REQ-06-03)

#### File 1: `smart-apply-shared/src/schemas/cover-letter.schema.ts` — CREATE

```typescript
import { z } from 'zod';

export const generateCoverLetterRequestSchema = z.object({
  job_description_text: z.string().min(1),
  job_title: z.string().min(1),
  company_name: z.string().min(1),
  profile_snapshot: z.record(z.unknown()),
  optimized_resume_json: z.record(z.unknown()).optional(),
  extracted_requirements: z.record(z.unknown()).optional(),
});

export const generateCoverLetterResponseSchema = z.object({
  cover_letter_text: z.string().min(1),
  metadata: z.object({
    word_count: z.number().int().nonnegative(),
    estimated_read_time_seconds: z.number().nonnegative(),
    key_skills_highlighted: z.array(z.string()),
  }),
});
```

#### File 2: `smart-apply-shared/src/schemas/subscription.schema.ts` — CREATE

```typescript
import { z } from 'zod';

export const subscriptionTierSchema = z.enum(['free', 'pro', 'premium']);

export const createCheckoutRequestSchema = z.object({
  tier: z.enum(['pro', 'premium']),
  success_url: z.string().url().optional(),
  cancel_url: z.string().url().optional(),
});

export const createCheckoutResponseSchema = z.object({
  checkout_url: z.string().url(),
});

export const usageLimitsSchema = z.object({
  optimizations: z.object({
    used: z.number().int().nonnegative(),
    limit: z.number().int().positive().nullable(),
  }),
  cover_letters: z.object({
    used: z.number().int().nonnegative(),
    limit: z.number().int().positive().nullable(),
  }),
});

export const subscriptionStatusResponseSchema = z.object({
  tier: subscriptionTierSchema,
  usage: usageLimitsSchema,
  stripe_customer_id: z.string().optional(),
  current_period_end: z.string().optional(),
});

/** Tier-based usage limits */
export const TIER_LIMITS = {
  free: { optimizations: 3, cover_letters: 1 },
  pro: { optimizations: null, cover_letters: null },
  premium: { optimizations: null, cover_letters: null },
} as const;
```

#### File 3: `smart-apply-shared/src/schemas/template.schema.ts` — CREATE

```typescript
import { z } from 'zod';

export const templateIdSchema = z.enum(['classic', 'modern', 'minimal']);

export const templateLayoutSchema = z.object({
  fontFamily: z.string(),
  headingFontFamily: z.string(),
  fontSize: z.number(),
  headingSize: z.number(),
  nameSize: z.number(),
  margins: z.object({
    top: z.number(),
    bottom: z.number(),
    left: z.number(),
    right: z.number(),
  }),
  lineSpacing: z.number(),
  sectionSpacing: z.number(),
  accentColor: z.object({
    r: z.number().min(0).max(1),
    g: z.number().min(0).max(1),
    b: z.number().min(0).max(1),
  }),
  sectionOrder: z.array(
    z.enum(['contact', 'summary', 'experience', 'education', 'skills']),
  ),
  showSectionDividers: z.boolean(),
  headerAlignment: z.enum(['left', 'center']),
});

export const resumeTemplateSchema = z.object({
  id: templateIdSchema,
  name: z.string(),
  description: z.string(),
  previewImageUrl: z.string(),
  layout: templateLayoutSchema,
});
```

#### File 4: `smart-apply-shared/src/types/cover-letter.ts` — CREATE

```typescript
import { z } from 'zod';
import {
  generateCoverLetterRequestSchema,
  generateCoverLetterResponseSchema,
} from '../schemas/cover-letter.schema';

export type GenerateCoverLetterRequest = z.infer<typeof generateCoverLetterRequestSchema>;
export type GenerateCoverLetterResponse = z.infer<typeof generateCoverLetterResponseSchema>;
```

#### File 5: `smart-apply-shared/src/types/subscription.ts` — CREATE

```typescript
import { z } from 'zod';
import {
  subscriptionTierSchema,
  createCheckoutRequestSchema,
  createCheckoutResponseSchema,
  subscriptionStatusResponseSchema,
  usageLimitsSchema,
} from '../schemas/subscription.schema';

export type SubscriptionTier = z.infer<typeof subscriptionTierSchema>;
export type CreateCheckoutRequest = z.infer<typeof createCheckoutRequestSchema>;
export type CreateCheckoutResponse = z.infer<typeof createCheckoutResponseSchema>;
export type SubscriptionStatusResponse = z.infer<typeof subscriptionStatusResponseSchema>;
export type UsageLimits = z.infer<typeof usageLimitsSchema>;
```

#### File 6: `smart-apply-shared/src/types/template.ts` — CREATE

```typescript
import { z } from 'zod';
import {
  templateIdSchema,
  templateLayoutSchema,
  resumeTemplateSchema,
} from '../schemas/template.schema';

export type TemplateId = z.infer<typeof templateIdSchema>;
export type TemplateLayout = z.infer<typeof templateLayoutSchema>;
export type ResumeTemplate = z.infer<typeof resumeTemplateSchema>;
```

#### File 7: `smart-apply-shared/src/index.ts` — MODIFY

**Append these exports after the existing ones:**

```typescript
export * from './types/cover-letter';
export * from './types/subscription';
export * from './types/template';
export * from './schemas/cover-letter.schema';
export * from './schemas/subscription.schema';
export * from './schemas/template.schema';
```

#### File 8: `smart-apply-shared/src/schemas/application.schema.ts` — MODIFY

**Add two optional fields to `createApplicationRequestSchema`:**

```typescript
// Add to the z.object({...}) body:
  cover_letter_snapshot: z.string().nullable().optional(),
  template_id: z.string().nullable().optional(),
```

**Before:**
```typescript
export const createApplicationRequestSchema = z.object({
  company_name: z.string().min(1),
  job_title: z.string().min(1),
  source_platform: sourcePlatformSchema.optional().default('other'),
  source_url: z.string().url().nullable().optional(),
  drive_link: z.string().url().nullable().optional(),
  ats_score_before: z.number().int().min(0).max(100).nullable().optional(),
  ats_score_after: z.number().int().min(0).max(100).nullable().optional(),
  status: applicationStatusSchema,
  applied_resume_snapshot: z.record(z.unknown()).nullable().optional(),
});
```

**After:**
```typescript
export const createApplicationRequestSchema = z.object({
  company_name: z.string().min(1),
  job_title: z.string().min(1),
  source_platform: sourcePlatformSchema.optional().default('other'),
  source_url: z.string().url().nullable().optional(),
  drive_link: z.string().url().nullable().optional(),
  ats_score_before: z.number().int().min(0).max(100).nullable().optional(),
  ats_score_after: z.number().int().min(0).max(100).nullable().optional(),
  status: applicationStatusSchema,
  applied_resume_snapshot: z.record(z.unknown()).nullable().optional(),
  cover_letter_snapshot: z.string().nullable().optional(),
  template_id: z.string().nullable().optional(),
});
```

---

### 2.2 Database Migrations (REQ-06-02, REQ-06-01, REQ-06-03)

#### File 9: `supabase/migrations/00003_user_usage.sql` — CREATE

```sql
-- Migration: 00003_user_usage.sql
-- Purpose: Track monthly feature usage per user for subscription tier enforcement.

CREATE TABLE user_usage (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  clerk_user_id TEXT NOT NULL,
  usage_month TEXT NOT NULL,
  optimizations_count INTEGER DEFAULT 0,
  cover_letters_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (clerk_user_id, usage_month)
);

ALTER TABLE user_usage ENABLE ROW LEVEL SECURITY;

-- Users can read their own usage
CREATE POLICY "Users can read own usage"
  ON user_usage FOR SELECT
  USING (requesting_clerk_user_id() = clerk_user_id);

-- Backend service role manages all usage (insert/update via service_role key)
CREATE POLICY "Service role manages usage"
  ON user_usage FOR ALL
  USING (auth.role() = 'service_role');

CREATE INDEX idx_user_usage_clerk_month ON user_usage (clerk_user_id, usage_month);
```

#### File 10: `supabase/migrations/00004_application_cover_letter.sql` — CREATE

```sql
-- Migration: 00004_application_cover_letter.sql
-- Purpose: Add cover letter snapshot and template ID to application_history.

ALTER TABLE application_history
  ADD COLUMN cover_letter_snapshot TEXT,
  ADD COLUMN resume_template_id TEXT DEFAULT 'classic';
```

---

### 2.3 Backend — Cover Letter Module (REQ-06-01)

#### File 11: `smart-apply-backend/src/modules/cover-letter/cover-letter.module.ts` — CREATE

```typescript
import { Module } from '@nestjs/common';
import { CoverLetterController } from './cover-letter.controller';
import { CoverLetterService } from './cover-letter.service';
import { LlmModule } from '../../infra/llm/llm.module';
import { SubscriptionModule } from '../subscription/subscription.module';

@Module({
  imports: [LlmModule, SubscriptionModule],
  controllers: [CoverLetterController],
  providers: [CoverLetterService],
})
export class CoverLetterModule {}
```

#### File 12: `smart-apply-backend/src/modules/cover-letter/cover-letter.controller.ts` — CREATE

```typescript
import { Controller, Post, Body, Req, UseGuards } from '@nestjs/common';
import { CoverLetterService } from './cover-letter.service';
import { ClerkAuthGuard } from '../auth/clerk-auth.guard';
import { SubscriptionGuard } from '../subscription/subscription.guard';
import { RequiresTier } from '../subscription/requires-tier.decorator';
import {
  generateCoverLetterRequestSchema,
  type GenerateCoverLetterRequest,
  type GenerateCoverLetterResponse,
} from '@smart-apply/shared';

@Controller('api/cover-letter')
@UseGuards(ClerkAuthGuard)
export class CoverLetterController {
  constructor(private readonly service: CoverLetterService) {}

  @Post('generate')
  @UseGuards(SubscriptionGuard)
  @RequiresTier('free') // all tiers can access, but usage limit is enforced by UsageService
  async generate(
    @Req() req: { userId: string },
    @Body() body: GenerateCoverLetterRequest,
  ): Promise<GenerateCoverLetterResponse> {
    const validated = generateCoverLetterRequestSchema.parse(body);
    return this.service.generate(req.userId, validated);
  }
}
```

#### File 13: `smart-apply-backend/src/modules/cover-letter/cover-letter.service.ts` — CREATE

```typescript
import { Injectable, Logger, ForbiddenException } from '@nestjs/common';
import { LlmService } from '../../infra/llm/llm.service';
import { UsageService } from '../subscription/usage.service';
import type {
  GenerateCoverLetterRequest,
  GenerateCoverLetterResponse,
} from '@smart-apply/shared';

@Injectable()
export class CoverLetterService {
  private readonly logger = new Logger(CoverLetterService.name);

  constructor(
    private readonly llm: LlmService,
    private readonly usage: UsageService,
  ) {}

  async generate(
    userId: string,
    request: GenerateCoverLetterRequest,
  ): Promise<GenerateCoverLetterResponse> {
    // Check usage before calling LLM
    const canUse = await this.usage.checkAndIncrement(
      userId,
      'cover_letters',
    );
    if (!canUse.allowed) {
      throw new ForbiddenException({
        error: 'usage_limit_exceeded',
        limit: canUse.limit,
        used: canUse.used,
        tier: canUse.tier,
      });
    }

    this.logger.log(`Generating cover letter for user ${userId}`);
    const start = Date.now();

    const coverLetterText = await this.llm.generateCoverLetter(
      request.profile_snapshot,
      request.job_description_text,
      request.job_title,
      request.company_name,
      request.extracted_requirements,
    );

    const wordCount = coverLetterText.split(/\s+/).length;

    this.logger.log(
      `Cover letter generated in ${Date.now() - start}ms (${wordCount} words)`,
    );

    return {
      cover_letter_text: coverLetterText,
      metadata: {
        word_count: wordCount,
        estimated_read_time_seconds: Math.ceil(wordCount / 3.5), // ~200 wpm speaking
        key_skills_highlighted: this.extractHighlightedSkills(
          coverLetterText,
          request.profile_snapshot,
        ),
      },
    };
  }

  private extractHighlightedSkills(
    coverLetter: string,
    profile: Record<string, unknown>,
  ): string[] {
    const skills = (profile.base_skills as string[]) ?? [];
    const lowerCoverLetter = coverLetter.toLowerCase();
    return skills.filter((skill) =>
      lowerCoverLetter.includes(skill.toLowerCase()),
    );
  }
}
```

---

### 2.4 Backend — Subscription Module (REQ-06-02)

#### File 14: `smart-apply-backend/src/modules/subscription/subscription.module.ts` — CREATE

```typescript
import { Module } from '@nestjs/common';
import { SubscriptionController } from './subscription.controller';
import { SubscriptionService } from './subscription.service';
import { UsageService } from './usage.service';
import { SubscriptionGuard } from './subscription.guard';
import { SupabaseModule } from '../../infra/supabase/supabase.module';

@Module({
  imports: [SupabaseModule],
  controllers: [SubscriptionController],
  providers: [SubscriptionService, UsageService, SubscriptionGuard],
  exports: [UsageService, SubscriptionGuard],
})
export class SubscriptionModule {}
```

#### File 15: `smart-apply-backend/src/modules/subscription/subscription.controller.ts` — CREATE

```typescript
import { Controller, Post, Get, Body, Req, UseGuards } from '@nestjs/common';
import { SubscriptionService } from './subscription.service';
import { ClerkAuthGuard } from '../auth/clerk-auth.guard';
import {
  createCheckoutRequestSchema,
  type CreateCheckoutResponse,
  type SubscriptionStatusResponse,
} from '@smart-apply/shared';

@Controller('api/subscription')
@UseGuards(ClerkAuthGuard)
export class SubscriptionController {
  constructor(private readonly service: SubscriptionService) {}

  @Post('checkout')
  async createCheckout(
    @Req() req: { userId: string },
    @Body() body: unknown,
  ): Promise<CreateCheckoutResponse> {
    const validated = createCheckoutRequestSchema.parse(body);
    return this.service.createCheckoutSession(req.userId, validated);
  }

  @Get('status')
  async getStatus(
    @Req() req: { userId: string },
  ): Promise<SubscriptionStatusResponse> {
    return this.service.getStatus(req.userId);
  }
}
```

#### File 16: `smart-apply-backend/src/modules/subscription/subscription.service.ts` — CREATE

```typescript
import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Stripe from 'stripe';
import { clerkClient } from '@clerk/backend';
import { UsageService } from './usage.service';
import type {
  CreateCheckoutRequest,
  CreateCheckoutResponse,
  SubscriptionStatusResponse,
  SubscriptionTier,
} from '@smart-apply/shared';
import { TIER_LIMITS } from '@smart-apply/shared';

@Injectable()
export class SubscriptionService {
  private readonly logger = new Logger(SubscriptionService.name);
  private readonly stripe: Stripe;
  private readonly priceIds: Record<'pro' | 'premium', string>;
  private readonly webBaseUrl: string;

  constructor(
    private readonly config: ConfigService,
    private readonly usage: UsageService,
  ) {
    this.stripe = new Stripe(
      this.config.getOrThrow<string>('STRIPE_SECRET_KEY'),
    );
    this.priceIds = {
      pro: this.config.getOrThrow<string>('STRIPE_PRO_PRICE_ID'),
      premium: this.config.getOrThrow<string>('STRIPE_PREMIUM_PRICE_ID'),
    };
    this.webBaseUrl =
      this.config.get<string>('WEB_BASE_URL') ?? 'http://localhost:3000';
  }

  async createCheckoutSession(
    userId: string,
    request: CreateCheckoutRequest,
  ): Promise<CreateCheckoutResponse> {
    const priceId = this.priceIds[request.tier];

    const session = await this.stripe.checkout.sessions.create({
      mode: 'subscription',
      line_items: [{ price: priceId, quantity: 1 }],
      success_url:
        request.success_url ?? `${this.webBaseUrl}/dashboard?upgraded=true`,
      cancel_url: request.cancel_url ?? `${this.webBaseUrl}/pricing`,
      metadata: { clerk_user_id: userId, tier: request.tier },
      client_reference_id: userId,
    });

    if (!session.url) {
      throw new BadRequestException('Failed to create checkout session');
    }

    return { checkout_url: session.url };
  }

  async handleStripeWebhook(
    rawBody: Buffer,
    signature: string,
  ): Promise<void> {
    const webhookSecret = this.config.getOrThrow<string>(
      'STRIPE_WEBHOOK_SECRET',
    );

    let event: Stripe.Event;
    try {
      event = this.stripe.webhooks.constructEvent(
        rawBody,
        signature,
        webhookSecret,
      );
    } catch {
      throw new BadRequestException('Invalid Stripe webhook signature');
    }

    this.logger.log(`Stripe webhook received: ${event.type}`);

    switch (event.type) {
      case 'checkout.session.completed':
        await this.handleCheckoutCompleted(
          event.data.object as Stripe.Checkout.Session,
        );
        break;
      case 'customer.subscription.updated':
        await this.handleSubscriptionUpdated(
          event.data.object as Stripe.Subscription,
        );
        break;
      case 'customer.subscription.deleted':
        await this.handleSubscriptionDeleted(
          event.data.object as Stripe.Subscription,
        );
        break;
    }
  }

  async getStatus(userId: string): Promise<SubscriptionStatusResponse> {
    const user = await clerkClient.users.getUser(userId);
    const tier =
      (user.publicMetadata.subscriptionTier as SubscriptionTier) ?? 'free';
    const stripeCustomerId = user.publicMetadata.stripeCustomerId as
      | string
      | undefined;

    const usageData = await this.usage.getUsage(userId);
    const limits = TIER_LIMITS[tier];

    return {
      tier,
      usage: {
        optimizations: {
          used: usageData.optimizations_count,
          limit: limits.optimizations,
        },
        cover_letters: {
          used: usageData.cover_letters_count,
          limit: limits.cover_letters,
        },
      },
      stripe_customer_id: stripeCustomerId,
    };
  }

  private async handleCheckoutCompleted(
    session: Stripe.Checkout.Session,
  ): Promise<void> {
    const userId = session.client_reference_id;
    const tier = session.metadata?.tier as SubscriptionTier;
    const customerId =
      typeof session.customer === 'string'
        ? session.customer
        : session.customer?.id;

    if (!userId || !tier) {
      this.logger.error('Missing userId or tier in checkout session metadata');
      return;
    }

    await clerkClient.users.updateUserMetadata(userId, {
      publicMetadata: {
        subscriptionTier: tier,
        stripeCustomerId: customerId,
      },
    });

    this.logger.log(`User ${userId} upgraded to ${tier}`);
  }

  private async handleSubscriptionUpdated(
    subscription: Stripe.Subscription,
  ): Promise<void> {
    const customerId =
      typeof subscription.customer === 'string'
        ? subscription.customer
        : subscription.customer?.id;

    if (!customerId) return;

    // Find clerk user by stripe customer ID
    const users = await clerkClient.users.getUserList({
      query: customerId,
    });

    if (users.data.length === 0) {
      this.logger.warn(
        `No Clerk user found for Stripe customer ${customerId}`,
      );
      return;
    }

    const user = users.data[0];
    const isActive = subscription.status === 'active';

    if (!isActive) {
      await clerkClient.users.updateUserMetadata(user.id, {
        publicMetadata: { subscriptionTier: 'free' },
      });
      this.logger.log(`User ${user.id} downgraded to free (subscription ${subscription.status})`);
    }
  }

  private async handleSubscriptionDeleted(
    subscription: Stripe.Subscription,
  ): Promise<void> {
    const customerId =
      typeof subscription.customer === 'string'
        ? subscription.customer
        : subscription.customer?.id;

    if (!customerId) return;

    const users = await clerkClient.users.getUserList({
      query: customerId,
    });

    if (users.data.length === 0) return;

    const user = users.data[0];
    await clerkClient.users.updateUserMetadata(user.id, {
      publicMetadata: { subscriptionTier: 'free' },
    });

    this.logger.log(`User ${user.id} subscription deleted — reverted to free`);
  }
}
```

#### File 17: `smart-apply-backend/src/modules/subscription/subscription.guard.ts` — CREATE

```typescript
import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { REQUIRES_TIER_KEY } from './requires-tier.decorator';
import type { SubscriptionTier } from '@smart-apply/shared';

const TIER_HIERARCHY: Record<SubscriptionTier, number> = {
  free: 0,
  pro: 1,
  premium: 2,
};

@Injectable()
export class SubscriptionGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredTier = this.reflector.getAllAndOverride<SubscriptionTier>(
      REQUIRES_TIER_KEY,
      [context.getHandler(), context.getClass()],
    );

    if (!requiredTier) return true; // no tier requirement

    const request = context.switchToHttp().getRequest();
    const userTier: SubscriptionTier =
      request.userPublicMetadata?.subscriptionTier ?? 'free';

    if (TIER_HIERARCHY[userTier] < TIER_HIERARCHY[requiredTier]) {
      throw new ForbiddenException({
        error: 'upgrade_required',
        required_tier: requiredTier,
        current_tier: userTier,
      });
    }

    return true;
  }
}
```

#### File 18: `smart-apply-backend/src/modules/subscription/requires-tier.decorator.ts` — CREATE

```typescript
import { SetMetadata } from '@nestjs/common';
import type { SubscriptionTier } from '@smart-apply/shared';

export const REQUIRES_TIER_KEY = 'requiresTier';
export const RequiresTier = (tier: SubscriptionTier) =>
  SetMetadata(REQUIRES_TIER_KEY, tier);
```

#### File 19: `smart-apply-backend/src/modules/subscription/usage.service.ts` — CREATE

```typescript
import { Injectable, Logger } from '@nestjs/common';
import { SupabaseService } from '../../infra/supabase/supabase.service';
import { clerkClient } from '@clerk/backend';
import { TIER_LIMITS, type SubscriptionTier } from '@smart-apply/shared';

interface UsageCheckResult {
  allowed: boolean;
  used: number;
  limit: number | null;
  tier: SubscriptionTier;
}

interface UsageRow {
  optimizations_count: number;
  cover_letters_count: number;
}

@Injectable()
export class UsageService {
  private readonly logger = new Logger(UsageService.name);

  constructor(private readonly supabase: SupabaseService) {}

  async checkAndIncrement(
    userId: string,
    feature: 'optimizations' | 'cover_letters',
  ): Promise<UsageCheckResult> {
    const tier = await this.getUserTier(userId);
    const limits = TIER_LIMITS[tier];
    const limit = limits[feature];
    const usageMonth = this.getCurrentMonth();

    // Ensure usage row exists
    await this.supabase.admin.from('user_usage').upsert(
      { clerk_user_id: userId, usage_month: usageMonth },
      { onConflict: 'clerk_user_id,usage_month' },
    );

    // Get current usage
    const { data, error } = await this.supabase.admin
      .from('user_usage')
      .select(`${feature}_count`)
      .eq('clerk_user_id', userId)
      .eq('usage_month', usageMonth)
      .single();

    if (error) {
      this.logger.error(`Failed to get usage: ${error.message}`);
      // Fail open — allow the operation
      return { allowed: true, used: 0, limit, tier };
    }

    const used = (data as Record<string, number>)?.[`${feature}_count`] ?? 0;

    if (limit !== null && used >= limit) {
      return { allowed: false, used, limit, tier };
    }

    // Increment usage
    const columnName = `${feature}_count`;
    const { error: updateError } = await this.supabase.admin
      .from('user_usage')
      .update({
        [columnName]: used + 1,
        updated_at: new Date().toISOString(),
      })
      .eq('clerk_user_id', userId)
      .eq('usage_month', usageMonth);

    if (updateError) {
      this.logger.error(`Failed to increment usage: ${updateError.message}`);
    }

    return { allowed: true, used: used + 1, limit, tier };
  }

  async getUsage(userId: string): Promise<UsageRow> {
    const usageMonth = this.getCurrentMonth();
    const { data } = await this.supabase.admin
      .from('user_usage')
      .select('optimizations_count, cover_letters_count')
      .eq('clerk_user_id', userId)
      .eq('usage_month', usageMonth)
      .single();

    return {
      optimizations_count: (data as UsageRow)?.optimizations_count ?? 0,
      cover_letters_count: (data as UsageRow)?.cover_letters_count ?? 0,
    };
  }

  private async getUserTier(userId: string): Promise<SubscriptionTier> {
    const user = await clerkClient.users.getUser(userId);
    return (user.publicMetadata.subscriptionTier as SubscriptionTier) ?? 'free';
  }

  private getCurrentMonth(): string {
    const now = new Date();
    return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
  }
}
```

---

### 2.5 Backend — LLM Service Addition (REQ-06-01)

#### File 20: `smart-apply-backend/src/infra/llm/llm.service.ts` — MODIFY

**Add new method `generateCoverLetter()` to the existing LlmService class:**

```typescript
  /**
   * Generate a tailored cover letter based on profile, JD, and requirements.
   */
  async generateCoverLetter(
    profile: Record<string, unknown>,
    jobDescriptionText: string,
    jobTitle: string,
    companyName: string,
    extractedRequirements?: Record<string, unknown>,
  ): Promise<string> {
    const systemPrompt = `You are a professional career advisor and cover letter writer.
Write a compelling, professional cover letter for the candidate applying to the specified role.

Guidelines:
- Address the hiring manager (use "Dear Hiring Manager" if name unknown)
- Opening paragraph: state the position and express enthusiasm
- Body (1-2 paragraphs): connect candidate's experience/skills to job requirements
- Closing paragraph: reiterate interest, include call to action
- Professional sign-off with candidate's name
- Keep to 250-350 words
- Be specific — reference actual skills and experience from the profile
- DO NOT fabricate experience or skills not in the profile
- Return ONLY the cover letter text, no JSON wrapper`;

    const userPrompt = `Candidate Profile:
${JSON.stringify(profile, null, 2)}

Job Title: ${jobTitle}
Company: ${companyName}

Job Description:
${jobDescriptionText}

${extractedRequirements ? `Key Requirements Extracted:\n${JSON.stringify(extractedRequirements, null, 2)}` : ''}

Write the cover letter now.`;

    const response = await this.client.chat.completions.create({
      model: this.model,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
      temperature: 0.7,
      max_tokens: 1500,
    });

    const content = response.choices[0]?.message?.content;
    if (!content) {
      throw new Error('LLM returned empty cover letter');
    }

    return content.trim();
  }
```

**Note:** This method returns plain text (not JSON) since cover letters are free-form text. The existing `response_format: { type: 'json_object' }` used in other methods is NOT applied here.

---

### 2.6 Backend — Webhook Modifications (REQ-06-02)

#### File 21: `smart-apply-backend/src/modules/webhooks/webhooks.controller.ts` — MODIFY

**Add a new Stripe webhook endpoint alongside the existing Clerk endpoint:**

```typescript
  @Post('stripe')
  @HttpCode(200)
  async handleStripe(
    @Req() req: { rawBody: Buffer; headers: Record<string, string> },
  ): Promise<{ received: boolean }> {
    const signature = req.headers['stripe-signature'];
    if (!signature) {
      throw new BadRequestException('Missing stripe-signature header');
    }
    await this.subscriptionService.handleStripeWebhook(req.rawBody, signature);
    return { received: true };
  }
```

**Controller constructor must inject `SubscriptionService`:**

```typescript
  constructor(
    private readonly webhooksService: WebhooksService,
    private readonly subscriptionService: SubscriptionService,
  ) {}
```

#### File 22: `smart-apply-backend/src/modules/webhooks/webhooks.module.ts` — MODIFY

**Import SubscriptionModule and inject SubscriptionService:**

```typescript
import { SubscriptionModule } from '../subscription/subscription.module';

@Module({
  imports: [SupabaseModule, SubscriptionModule],
  // ...
})
```

---

### 2.7 Backend — App Module (ALL)

#### File 23: `smart-apply-backend/src/app.module.ts` — MODIFY

**Before:**
```typescript
import { AccountModule } from './modules/account/account.module';
import { SupabaseModule } from './infra/supabase/supabase.module';
import { LlmModule } from './infra/llm/llm.module';
```

**After:**
```typescript
import { AccountModule } from './modules/account/account.module';
import { CoverLetterModule } from './modules/cover-letter/cover-letter.module';
import { SubscriptionModule } from './modules/subscription/subscription.module';
import { SupabaseModule } from './infra/supabase/supabase.module';
import { LlmModule } from './infra/llm/llm.module';
```

**Module imports array — add:**
```typescript
    CoverLetterModule,
    SubscriptionModule,
```

---

### 2.8 Extension — PDF Generator Refactor (REQ-06-03)

#### File 24: `smart-apply-extension/src/lib/pdf-generator.ts` — MODIFY

**Refactor `generateResumePDF` to accept an optional template config:**

**Before signature:**
```typescript
export async function generateResumePDF(data: ResumeData): Promise<Uint8Array> {
```

**After signature:**
```typescript
import type { TemplateLayout } from '@smart-apply/shared';
import { TEMPLATE_REGISTRY } from './templates';

export async function generateResumePDF(
  data: ResumeData,
  templateId: string = 'classic',
): Promise<Uint8Array> {
  const template = TEMPLATE_REGISTRY[templateId]?.layout ?? TEMPLATE_REGISTRY['classic'].layout;
```

**Key changes inside the function:**
1. Replace hardcoded `MARGIN`, `FONT_SIZE_*`, `LINE_HEIGHT` with values from `template.margins`, `template.fontSize`, `template.headingSize`, `template.nameSize`.
2. Replace `rgb(0, 0, 0)` for headings with `rgb(template.accentColor.r, template.accentColor.g, template.accentColor.b)`.
3. Use `template.sectionOrder` to determine section rendering sequence.
4. Add `template.showSectionDividers` logic to draw horizontal lines between sections.
5. Adjust `template.headerAlignment` for name/contact positioning.

**The full refactored function preserves all existing behavior when `templateId = 'classic'`** — the classic template layout values match the current hardcoded constants exactly (MARGIN=50, FONT_SIZE_NAME=18, etc).

#### File 25: `smart-apply-extension/src/lib/templates.ts` — CREATE

```typescript
import type { ResumeTemplate } from '@smart-apply/shared';

export const TEMPLATE_REGISTRY: Record<string, ResumeTemplate> = {
  classic: {
    id: 'classic',
    name: 'Classic',
    description: 'Clean, traditional resume layout — ATS-optimized.',
    previewImageUrl: '/templates/classic-preview.png',
    layout: {
      fontFamily: 'Helvetica',
      headingFontFamily: 'Helvetica-Bold',
      fontSize: 10,
      headingSize: 13,
      nameSize: 18,
      margins: { top: 50, bottom: 50, left: 50, right: 50 },
      lineSpacing: 14,
      sectionSpacing: 8,
      accentColor: { r: 0, g: 0, b: 0 },
      sectionOrder: ['contact', 'summary', 'experience', 'education', 'skills'],
      showSectionDividers: false,
      headerAlignment: 'left',
    },
  },
  modern: {
    id: 'modern',
    name: 'Modern',
    description: 'Contemporary design with accent colors and centered header.',
    previewImageUrl: '/templates/modern-preview.png',
    layout: {
      fontFamily: 'Helvetica',
      headingFontFamily: 'Helvetica-Bold',
      fontSize: 10,
      headingSize: 12,
      nameSize: 22,
      margins: { top: 40, bottom: 40, left: 55, right: 55 },
      lineSpacing: 15,
      sectionSpacing: 12,
      accentColor: { r: 0.16, g: 0.36, b: 0.6 },
      sectionOrder: ['contact', 'summary', 'skills', 'experience', 'education'],
      showSectionDividers: true,
      headerAlignment: 'center',
    },
  },
  minimal: {
    id: 'minimal',
    name: 'Minimal',
    description: 'Ultra-clean layout with generous whitespace.',
    previewImageUrl: '/templates/minimal-preview.png',
    layout: {
      fontFamily: 'Helvetica',
      headingFontFamily: 'Helvetica-Bold',
      fontSize: 10,
      headingSize: 11,
      nameSize: 16,
      margins: { top: 60, bottom: 60, left: 65, right: 65 },
      lineSpacing: 16,
      sectionSpacing: 14,
      accentColor: { r: 0.33, g: 0.33, b: 0.33 },
      sectionOrder: ['contact', 'summary', 'experience', 'skills', 'education'],
      showSectionDividers: false,
      headerAlignment: 'left',
    },
  },
};
```

#### File 26: `smart-apply-extension/src/lib/cover-letter-pdf.ts` — CREATE

```typescript
import { PDFDocument, StandardFonts, rgb } from 'pdf-lib';

interface CoverLetterData {
  senderName: string;
  senderEmail: string;
  senderPhone: string;
  recipientCompany: string;
  jobTitle: string;
  coverLetterText: string;
}

export async function generateCoverLetterPDF(
  data: CoverLetterData,
): Promise<Uint8Array> {
  const doc = await PDFDocument.create();
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const boldFont = await doc.embedFont(StandardFonts.HelveticaBold);

  const page = doc.addPage([612, 792]); // US Letter
  const margin = 72; // 1 inch
  const maxWidth = 612 - 2 * margin;
  let y = 792 - margin;

  // Sender info
  page.drawText(data.senderName, {
    x: margin,
    y,
    size: 12,
    font: boldFont,
    color: rgb(0, 0, 0),
  });
  y -= 16;
  page.drawText(`${data.senderEmail}  |  ${data.senderPhone}`, {
    x: margin,
    y,
    size: 10,
    font,
    color: rgb(0.3, 0.3, 0.3),
  });
  y -= 30;

  // Date
  const dateStr = new Date().toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });
  page.drawText(dateStr, { x: margin, y, size: 10, font, color: rgb(0, 0, 0) });
  y -= 24;

  // Recipient
  page.drawText(`Re: ${data.jobTitle}`, {
    x: margin,
    y,
    size: 10,
    font: boldFont,
    color: rgb(0, 0, 0),
  });
  y -= 14;
  page.drawText(data.recipientCompany, {
    x: margin,
    y,
    size: 10,
    font,
    color: rgb(0, 0, 0),
  });
  y -= 24;

  // Cover letter body
  const paragraphs = data.coverLetterText.split('\n\n');
  for (const paragraph of paragraphs) {
    const lines = wrapText(paragraph.trim(), font, 10, maxWidth);
    for (const line of lines) {
      if (y < margin + 40) break; // don't overflow
      page.drawText(line, {
        x: margin,
        y,
        size: 10,
        font,
        color: rgb(0, 0, 0),
      });
      y -= 14;
    }
    y -= 8; // paragraph spacing
  }

  return doc.save();
}

function wrapText(
  text: string,
  font: { widthOfTextAtSize: (text: string, size: number) => number },
  size: number,
  maxWidth: number,
): string[] {
  const words = text.split(' ');
  const lines: string[] = [];
  let current = '';

  for (const word of words) {
    const test = current ? `${current} ${word}` : word;
    const width = font.widthOfTextAtSize(test, size);
    if (width > maxWidth && current) {
      lines.push(current);
      current = word;
    } else {
      current = test;
    }
  }
  if (current) lines.push(current);
  return lines;
}
```

---

### 2.9 Extension — Service Worker & Popup (REQ-06-01, REQ-06-03)

#### File 27: `smart-apply-extension/src/background/service-worker.ts` — MODIFY

**Add `GENERATE_COVER_LETTER` message handler in the `chrome.runtime.onMessage.addListener` block:**

```typescript
    case 'GENERATE_COVER_LETTER': {
      const token = await getAuthToken();
      if (!token) {
        sendResponse({ success: false, error: 'Not authenticated' });
        return;
      }

      try {
        const response = await fetch(`${API_BASE_URL}/api/cover-letter/generate`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`,
          },
          body: JSON.stringify(message.payload),
        });

        if (!response.ok) {
          const error = await response.json();
          sendResponse({ success: false, error });
          return;
        }

        const result = await response.json();
        sendResponse({ success: true, data: result });
      } catch (error) {
        sendResponse({ success: false, error: String(error) });
      }
      return true; // async response
    }
```

#### File 28: `smart-apply-extension/src/ui/popup/App.tsx` — MODIFY

**Key changes to the results screen:**

1. Add `templateId` state: `const [templateId, setTemplateId] = useState<string>('classic');`
2. Add `coverLetterText` state: `const [coverLetterText, setCoverLetterText] = useState<string | null>(null);`
3. Add `coverLetterLoading` state.
4. Add template picker UI section before the "Generate PDF" button (renders 3 template cards with radio selection).
5. Add "Generate Cover Letter" button after selected changes section.
6. Pass `templateId` to `generateResumePDF(resumeData, templateId)`.
7. Cover letter section: textarea for editing + "Download Cover Letter PDF" button using `generateCoverLetterPDF()`.

---

### 2.10 Web — Pricing Page (REQ-06-02)

#### File 29: `smart-apply-web/src/app/pricing/page.tsx` — CREATE

```typescript
'use client';

import { useAuth } from '@clerk/nextjs';
import { PricingCard } from '@/components/pricing/pricing-card';
import { apiFetch } from '@/lib/api';
import type { CreateCheckoutResponse } from '@smart-apply/shared';

const tiers = [
  {
    id: 'free' as const,
    name: 'Free',
    price: '$0',
    period: 'forever',
    features: [
      '3 resume optimizations/month',
      '1 cover letter/month',
      'Classic resume template',
      'ATS scoring',
    ],
    cta: 'Current Plan',
    highlighted: false,
  },
  {
    id: 'pro' as const,
    name: 'Pro',
    price: '$9.99',
    period: '/month',
    features: [
      'Unlimited optimizations',
      'Unlimited cover letters',
      'All resume templates',
      'ATS scoring',
      'Priority support',
    ],
    cta: 'Upgrade to Pro',
    highlighted: true,
  },
  {
    id: 'premium' as const,
    name: 'Premium',
    price: '$19.99',
    period: '/month',
    features: [
      'Everything in Pro',
      'AI Interview Prep (coming soon)',
      'Resume translation (coming soon)',
      'Analytics dashboard (coming soon)',
    ],
    cta: 'Upgrade to Premium',
    highlighted: false,
  },
];

export default function PricingPage() {
  const { getToken } = useAuth();

  const handleUpgrade = async (tier: 'pro' | 'premium') => {
    const token = await getToken();
    if (!token) return;

    const response = await apiFetch<CreateCheckoutResponse>(
      '/api/subscription/checkout',
      {
        method: 'POST',
        body: JSON.stringify({ tier }),
        token,
      },
    );

    window.location.href = response.checkout_url;
  };

  return (
    <div className="container mx-auto py-12 px-4">
      <h1 className="text-3xl font-bold text-center mb-2">Choose Your Plan</h1>
      <p className="text-muted-foreground text-center mb-10">
        Unlock powerful features to supercharge your job search.
      </p>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-5xl mx-auto">
        {tiers.map((tier) => (
          <PricingCard
            key={tier.id}
            tier={tier}
            onUpgrade={handleUpgrade}
          />
        ))}
      </div>
    </div>
  );
}
```

#### File 30: `smart-apply-web/src/components/pricing/pricing-card.tsx` — CREATE

```typescript
'use client';

import { Button } from '@/components/ui/button';
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from '@/components/ui/card';
import { Check } from 'lucide-react';
import { cn } from '@/lib/utils';

interface PricingTier {
  id: 'free' | 'pro' | 'premium';
  name: string;
  price: string;
  period: string;
  features: string[];
  cta: string;
  highlighted: boolean;
}

interface PricingCardProps {
  tier: PricingTier;
  onUpgrade: (tier: 'pro' | 'premium') => void;
}

export function PricingCard({ tier, onUpgrade }: PricingCardProps) {
  return (
    <Card
      className={cn(
        'flex flex-col',
        tier.highlighted && 'border-primary shadow-lg scale-105',
      )}
    >
      <CardHeader>
        <CardTitle className="text-xl">{tier.name}</CardTitle>
        <div className="mt-2">
          <span className="text-3xl font-bold">{tier.price}</span>
          <span className="text-muted-foreground ml-1">{tier.period}</span>
        </div>
      </CardHeader>
      <CardContent className="flex-1">
        <ul className="space-y-2">
          {tier.features.map((feature) => (
            <li key={feature} className="flex items-center gap-2">
              <Check className="h-4 w-4 text-primary" />
              <span className="text-sm">{feature}</span>
            </li>
          ))}
        </ul>
      </CardContent>
      <CardFooter>
        <Button
          className="w-full"
          variant={tier.highlighted ? 'default' : 'outline'}
          disabled={tier.id === 'free'}
          onClick={() => tier.id !== 'free' && onUpgrade(tier.id)}
        >
          {tier.cta}
        </Button>
      </CardFooter>
    </Card>
  );
}
```

#### File 31: `smart-apply-web/src/components/optimize/template-picker.tsx` — CREATE

```typescript
'use client';

import { Card } from '@/components/ui/card';
import { cn } from '@/lib/utils';
import { TEMPLATE_REGISTRY } from '@smart-apply/shared'; // shared template data
import { Lock } from 'lucide-react';

interface TemplatePickerProps {
  selectedTemplateId: string;
  onSelect: (templateId: string) => void;
  userTier: 'free' | 'pro' | 'premium';
}

const templates = Object.values(TEMPLATE_REGISTRY);

export function TemplatePicker({
  selectedTemplateId,
  onSelect,
  userTier,
}: TemplatePickerProps) {
  return (
    <div className="space-y-2">
      <h3 className="text-sm font-medium">Resume Template</h3>
      <div className="grid grid-cols-3 gap-3">
        {templates.map((template) => {
          const isLocked = userTier === 'free' && template.id !== 'classic';
          return (
            <Card
              key={template.id}
              role="radio"
              aria-checked={selectedTemplateId === template.id}
              tabIndex={0}
              className={cn(
                'cursor-pointer p-3 text-center relative',
                selectedTemplateId === template.id &&
                  'ring-2 ring-primary',
                isLocked && 'opacity-60 cursor-not-allowed',
              )}
              onClick={() => !isLocked && onSelect(template.id)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' || e.key === ' ') {
                  e.preventDefault();
                  if (!isLocked) onSelect(template.id);
                }
              }}
            >
              {isLocked && (
                <Lock className="absolute top-2 right-2 h-3 w-3 text-muted-foreground" />
              )}
              <p className="text-sm font-medium">{template.name}</p>
              <p className="text-xs text-muted-foreground">
                {template.description}
              </p>
            </Card>
          );
        })}
      </div>
    </div>
  );
}
```

#### File 32: `smart-apply-web/src/components/optimize/cover-letter-section.tsx` — CREATE

```typescript
'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { Loader2, Download, FileText } from 'lucide-react';
import { useAuth } from '@clerk/nextjs';
import { apiFetch } from '@/lib/api';
import type { GenerateCoverLetterResponse } from '@smart-apply/shared';

interface CoverLetterSectionProps {
  jobDescriptionText: string;
  jobTitle: string;
  companyName: string;
  profileSnapshot: Record<string, unknown>;
  optimizedResumeJson?: Record<string, unknown>;
  extractedRequirements?: Record<string, unknown>;
  onCoverLetterGenerated?: (text: string) => void;
}

export function CoverLetterSection({
  jobDescriptionText,
  jobTitle,
  companyName,
  profileSnapshot,
  optimizedResumeJson,
  extractedRequirements,
  onCoverLetterGenerated,
}: CoverLetterSectionProps) {
  const { getToken } = useAuth();
  const [coverLetterText, setCoverLetterText] = useState<string>('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleGenerate = async () => {
    setLoading(true);
    setError(null);
    try {
      const token = await getToken();
      if (!token) throw new Error('Not authenticated');

      const response = await apiFetch<GenerateCoverLetterResponse>(
        '/api/cover-letter/generate',
        {
          method: 'POST',
          body: JSON.stringify({
            job_description_text: jobDescriptionText,
            job_title: jobTitle,
            company_name: companyName,
            profile_snapshot: profileSnapshot,
            optimized_resume_json: optimizedResumeJson,
            extracted_requirements: extractedRequirements,
          }),
          token,
        },
      );

      setCoverLetterText(response.cover_letter_text);
      onCoverLetterGenerated?.(response.cover_letter_text);
    } catch (err) {
      const message =
        err instanceof Error ? err.message : 'Failed to generate cover letter';
      setError(message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-medium flex items-center gap-2">
          <FileText className="h-4 w-4" />
          Cover Letter
        </h3>
        <Button
          size="sm"
          onClick={handleGenerate}
          disabled={loading}
        >
          {loading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
          {coverLetterText ? 'Regenerate' : 'Generate Cover Letter'}
        </Button>
      </div>

      {error && (
        <p className="text-sm text-destructive">{error}</p>
      )}

      {coverLetterText && (
        <>
          <Textarea
            value={coverLetterText}
            onChange={(e) => setCoverLetterText(e.target.value)}
            rows={12}
            className="font-mono text-sm"
          />
          <Button
            variant="outline"
            size="sm"
            onClick={() => {
              const blob = new Blob([coverLetterText], { type: 'text/plain' });
              const url = URL.createObjectURL(blob);
              const a = document.createElement('a');
              a.href = url;
              a.download = `cover-letter-${companyName.replace(/\s+/g, '-').toLowerCase()}.txt`;
              a.click();
              URL.revokeObjectURL(url);
            }}
          >
            <Download className="mr-2 h-4 w-4" />
            Download as Text
          </Button>
        </>
      )}
    </div>
  );
}
```

#### File 33: `smart-apply-web/src/components/shared/upgrade-prompt.tsx` — CREATE

```typescript
'use client';

import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { useRouter } from 'next/navigation';

interface UpgradePromptProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  feature: string;
  requiredTier: 'pro' | 'premium';
}

export function UpgradePrompt({
  open,
  onOpenChange,
  feature,
  requiredTier,
}: UpgradePromptProps) {
  const router = useRouter();

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Upgrade Required</DialogTitle>
          <DialogDescription>
            {feature} requires a {requiredTier === 'pro' ? 'Pro' : 'Premium'}{' '}
            subscription. Upgrade now to unlock this feature.
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Maybe Later
          </Button>
          <Button onClick={() => router.push('/pricing')}>
            View Plans
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
```

#### File 34: `smart-apply-web/src/app/optimize/page.tsx` — MODIFY

**Key changes:**
1. Import `TemplatePicker` and `CoverLetterSection` components.
2. Add `templateId` state and `coverLetterSnapshot` state.
3. Render `TemplatePicker` between the results section and the PDF download button.
4. Render `CoverLetterSection` after the template picker.
5. Pass `templateId` to the PDF generation call.
6. Include `cover_letter_snapshot` and `template_id` when saving the application.

---

## 3. Test Specifications

### T1: `smart-apply-shared/test/cover-letter.schema.spec.ts`

```typescript
describe('generateCoverLetterRequestSchema', () => {
  it('should accept valid request with all fields', () => { /* ... */ });
  it('should accept request without optional fields', () => { /* ... */ });
  it('should reject empty job_description_text', () => { /* ... */ });
  it('should reject empty company_name', () => { /* ... */ });
});

describe('generateCoverLetterResponseSchema', () => {
  it('should accept valid response', () => { /* ... */ });
  it('should reject missing cover_letter_text', () => { /* ... */ });
  it('should reject negative word_count', () => { /* ... */ });
});
```

### T2: `smart-apply-shared/test/subscription.schema.spec.ts`

```typescript
describe('subscriptionTierSchema', () => {
  it('should accept free, pro, premium', () => { /* ... */ });
  it('should reject invalid tier', () => { /* ... */ });
});

describe('createCheckoutRequestSchema', () => {
  it('should accept pro tier', () => { /* ... */ });
  it('should accept premium tier with URLs', () => { /* ... */ });
  it('should reject free tier', () => { /* ... */ });
  it('should reject invalid URL format', () => { /* ... */ });
});

describe('TIER_LIMITS', () => {
  it('should define limits for free tier', () => { /* ... */ });
  it('should define null (unlimited) for pro tier', () => { /* ... */ });
});
```

### T4: `smart-apply-backend/test/cover-letter.service.spec.ts`

```typescript
describe('CoverLetterService', () => {
  describe('generate()', () => {
    it('should check usage before calling LLM', () => { /* ... */ });
    it('should throw ForbiddenException when usage limit exceeded', () => { /* ... */ });
    it('should call LLM with correct prompt context', () => { /* ... */ });
    it('should return cover letter text with metadata', () => { /* ... */ });
    it('should count words correctly', () => { /* ... */ });
    it('should extract highlighted skills from cover letter', () => { /* ... */ });
    it('should increment usage count on success', () => { /* ... */ });
  });
});
```

### T6: `smart-apply-backend/test/subscription.service.spec.ts`

```typescript
describe('SubscriptionService', () => {
  describe('createCheckoutSession()', () => {
    it('should create Stripe Checkout session with correct price ID', () => { /* ... */ });
    it('should include clerk_user_id in session metadata', () => { /* ... */ });
    it('should use default URLs when not provided', () => { /* ... */ });
    it('should throw BadRequestException on Stripe failure', () => { /* ... */ });
  });

  describe('handleStripeWebhook()', () => {
    it('should verify webhook signature', () => { /* ... */ });
    it('should throw BadRequestException on invalid signature', () => { /* ... */ });
    it('should update Clerk metadata on checkout.session.completed', () => { /* ... */ });
    it('should revert to free on customer.subscription.deleted', () => { /* ... */ });
    it('should downgrade on subscription status change to non-active', () => { /* ... */ });
  });

  describe('getStatus()', () => {
    it('should return free tier for new user', () => { /* ... */ });
    it('should return correct usage limits for pro tier', () => { /* ... */ });
    it('should include Stripe customer ID when available', () => { /* ... */ });
  });
});
```

### T7: `smart-apply-backend/test/subscription.guard.spec.ts`

```typescript
describe('SubscriptionGuard', () => {
  it('should allow access when no tier requirement', () => { /* ... */ });
  it('should allow access when user tier >= required tier', () => { /* ... */ });
  it('should throw ForbiddenException when user tier < required', () => { /* ... */ });
  it('should default to free tier when metadata missing', () => { /* ... */ });
  it('should respect tier hierarchy: free < pro < premium', () => { /* ... */ });
});
```

### T8: `smart-apply-backend/test/usage.service.spec.ts`

```typescript
describe('UsageService', () => {
  describe('checkAndIncrement()', () => {
    it('should allow when under limit', () => { /* ... */ });
    it('should deny when at limit', () => { /* ... */ });
    it('should increment count on allow', () => { /* ... */ });
    it('should create usage row if not exists (upsert)', () => { /* ... */ });
    it('should return correct month format', () => { /* ... */ });
    it('should allow unlimited for pro tier (null limit)', () => { /* ... */ });
  });

  describe('getUsage()', () => {
    it('should return zero counts for new user', () => { /* ... */ });
    it('should return current month counts', () => { /* ... */ });
  });
});
```

### T11: `smart-apply-extension/test/templates.spec.ts`

```typescript
describe('TEMPLATE_REGISTRY', () => {
  it('should contain classic, modern, and minimal templates', () => { /* ... */ });
  it('should have classic template matching original hardcoded values', () => {
    // Regression: ensure classic template = MARGIN=50, FONT_SIZE_NAME=18, etc.
  });
  it('should have valid layout properties for all templates', () => { /* ... */ });
  it('should have unique IDs', () => { /* ... */ });
});
```

---

## 4. Implementation Sequence

| Order | Files | Dependency | TDD Step |
|:---|:---|:---|:---|
| 1 | Files 1–8 (Shared schemas + types + index export + app schema update) | None | Write T1, T2, T3 first → implement schemas |
| 2 | Files 9–10 (Supabase migrations) | Shared types | Run migration, verify table creation |
| 3 | Files 25, 24 (Template registry + PDF refactor) | Shared types | Write T11, T9 first → implement templates |
| 4 | File 26 (Cover letter PDF) | None | Write T10 → implement cover letter PDF |
| 5 | Files 18, 17, 19 (Decorator, Guard, UsageService) | Shared types, Supabase migration | Write T7, T8 → implement guard + usage |
| 6 | File 20 (LLM service — add generateCoverLetter) | None | Manual test with LLM |
| 7 | Files 11–13 (CoverLetter module/controller/service) | LLM, UsageService | Write T4, T5 → implement cover letter backend |
| 8 | Files 14–16 (Subscription module/controller/service) | UsageService, Guard | Write T6 → implement subscription backend |
| 9 | Files 21–23 (Webhook + app module additions) | SubscriptionService | Update webhook tests |
| 10 | Files 31–33 (Web: template picker, cover letter section, upgrade prompt) | Backend APIs | Write T12, T13, T14 → implement components |
| 11 | File 29–30 (Web: pricing page + card) | Backend APIs | Write T12 → implement pricing page |
| 12 | File 34 (Web: optimize page integration) | Components from steps 10–11 | Integration test |
| 13 | Files 27–28 (Extension: service worker + popup changes) | Backend APIs, PDF generator | Manual E2E test |

---

## 5. New Dependencies

| Package | Version | Repo | Purpose |
|:---|:---|:---|:---|
| `stripe` | `^17.x` | smart-apply-backend | Stripe Node.js SDK for Checkout Sessions, webhook verification |
| `@clerk/backend` | (already installed) | smart-apply-backend | Update user publicMetadata for subscription tier |

**Install command:**
```bash
npm -w @smart-apply/api install stripe
```

No new frontend dependencies — Stripe Checkout is a redirect (no Stripe.js needed in Phase 6A).
