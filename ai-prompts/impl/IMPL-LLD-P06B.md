---
title: IMPL-LLD-P06B — Implementation Prompt
description: Context-engineered TDD implementation prompt for MVP Phase 6B — Competitive Parity (Interview Prep, Auto-Apply, Landing Page & SEO).
---

# IMPL-LLD-P06B — Implementation Prompt

**Purpose:** Executable prompt for a coding agent to implement all source files and test files from LLD-MVP-P06B (Phase 6B), following strict TDD methodology.

---

## Role

You are a Senior Full-Stack Developer implementing MVP Phase 6B for the Smart Apply application. Follow TDD (Red → Green → Refactor) for every file. Write tests first, watch them fail, implement until green, then refactor.

---

## Context

### Project Structure
- **Monorepo** with npm workspaces: `smart-apply-shared`, `smart-apply-backend`, `smart-apply-web`, `smart-apply-extension`, `supabase`
- **Backend:** NestJS 11, TypeScript strict, Vitest, port 3001
- **Web:** Next.js 15, React 19, TanStack Query, Clerk auth, shadcn/ui, Tailwind, Vitest
- **Extension:** Chrome MV3, Vite + @crxjs, React popup, pdf-lib, Vitest
- **Shared:** Zod schemas + TypeScript types, compiled to JS via `npm -w @smart-apply/shared run build`
- **DB:** Supabase (PostgreSQL), RLS with `requesting_clerk_user_id()` function
- **Auth:** Clerk JWT verification via `ClerkAuthGuard`
- **LLM:** OpenAI GPT-4o via `LlmService` (120s timeout)
- **Subscriptions:** Stripe + `SubscriptionGuard` + `@RequiresTier()` decorator (Phase 6A)

### Existing Patterns to Follow
- **Zod validation at API boundary:** See `optimizeRequestSchema` usage in `optimize.service.ts`; `generateQuestionsRequestSchema` and `evaluateAnswerRequestSchema` must be validated in the controller before calling the service.
- **Guard pattern:** See `subscription.guard.ts` — reads `requiredTier` from `@RequiresTier()` metadata, compares against `request.userPublicMetadata.subscriptionTier`.
- **Module structure:** See any existing module (e.g., `cover-letter/`) — `module.ts`, `controller.ts`, `service.ts`.
- **LLM method pattern:** See `llm.service.ts` — system prompt + user prompt → `chatCompletion()` → `parseAndValidate()` with Zod schema.
- **Test pattern:** See `test/*.spec.ts` — Vitest with mocked services injected via `Test.createTestingModule()`.
- **Web API client:** `apiFetch<T>(path: string, token: string, options?: RequestInit): Promise<T>` in `src/lib/api-client.ts`.
- **Extension API client:** `apiFetch<T>(path, init?)` in service-worker with auth token from `chrome.storage.local`.
- **Storage:** `getStorage(key)` / `setStorage(key, value)` typed wrapper around `chrome.storage.local`.

### Key Type References (Existing)
```typescript
// @smart-apply/shared — existing types
type MasterProfile = { clerk_user_id, full_name, email, phone, location, linkedin_url, portfolio_url, summary, base_skills: string[], certifications, experiences: ExperienceItem[], education: EducationItem[], raw_profile_source, profile_version }
type ApplicationHistoryItem = { id, clerk_user_id, company_name, job_title, source_platform, source_url, status: ApplicationStatus, ... }
type SubscriptionTier = 'free' | 'pro' | 'premium'

// APPLICATION_STATUSES — currently: 'draft' | 'generated' | 'applied' | 'interviewing' | 'offer' | 'rejected' | 'withdrawn'
// Must add: 'auto-applied'

// StorageSchema (extension) — currently: auth_token, cached_profile, last_optimized_at, last_optimize_context, last_pdf_bytes
```

### Existing Backend Module Registry (app.module.ts)
```typescript
// Currently imports: ConfigModule, SupabaseModule, LlmModule, AuthModule, HealthModule,
// ProfilesModule, OptimizeModule, ApplicationsModule, WebhooksModule, AccountModule,
// CoverLetterModule, SubscriptionModule
// Must add: InterviewModule
```

### Existing Web Middleware (public routes)
```typescript
// Currently public: '/sign-in(.*)', '/sign-up(.*)', '/api/webhooks(.*)', '/', '/not-found'
// Must add: '/pricing(.*)', '/examples(.*)'
```

### Migration Numbering
```
supabase/migrations/
  00001_init.sql
  00002_audit_events.sql
  00003_user_usage.sql
  00004_application_cover_letter.sql
  → Next: 00005_interview_sessions.sql
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

---

### Step 1: Shared Types & Schemas (Interview + Auto-Apply)

**Test files first:**
- `smart-apply-shared/test/interview.schema.spec.ts`

```typescript
// Tests for interview schema validation
// - generateQuestionsRequestSchema: valid input passes, empty job_title rejects, short JD rejects (<10 chars)
// - evaluateAnswerRequestSchema: valid input passes, invalid UUID rejects, short answer rejects (<10 chars)
// - interviewFeedbackSchema: valid feedback passes, score <1 rejects, score >5 rejects
// - interviewQuestionsArraySchema: array of 5 questions passes, array of 4 rejects, array of 11 rejects
// - interviewQuestionCategorySchema: 'behavioral' passes, 'unknown' rejects
```

**Then implement:**

1. `smart-apply-shared/src/types/interview.ts` — CREATE

```typescript
export const INTERVIEW_QUESTION_CATEGORIES = ['behavioral', 'technical', 'situational'] as const;
export type InterviewQuestionCategory = (typeof INTERVIEW_QUESTION_CATEGORIES)[number];

export interface InterviewQuestion {
  id: number;
  text: string;
  category: InterviewQuestionCategory;
}

export interface StarSuggestion {
  situation: string;
  task: string;
  action: string;
  result: string;
}

export interface InterviewFeedback {
  strengths: string[];
  improvements: string[];
  star_suggestion: StarSuggestion;
  score: number; // 1–5
}

export interface InterviewAnswerEntry {
  question_id: number;
  answer_text: string;
  feedback: InterviewFeedback | null;
}

export interface InterviewSession {
  id: string;
  clerk_user_id: string;
  job_title: string;
  company_name: string;
  job_description_text: string | null;
  questions: InterviewQuestion[];
  answers: Record<string, InterviewAnswerEntry>;
  created_at: string;
  updated_at: string;
}

export interface InterviewSessionSummary {
  id: string;
  job_title: string;
  company_name: string;
  question_count: number;
  answered_count: number;
  average_score: number | null;
  created_at: string;
}

export interface GenerateQuestionsRequest {
  job_title: string;
  company_name: string;
  job_description_text: string;
  profile_summary?: string;
}

export interface GenerateQuestionsResponse {
  session_id: string;
  questions: InterviewQuestion[];
}

export interface EvaluateAnswerRequest {
  session_id: string;
  question_id: number;
  question_text: string;
  answer_text: string;
  job_description_text: string;
  profile_summary?: string;
}

export interface EvaluateAnswerResponse {
  feedback: InterviewFeedback;
}
```

2. `smart-apply-shared/src/schemas/interview.schema.ts` — CREATE

```typescript
import { z } from 'zod';

export const interviewQuestionCategorySchema = z.enum(['behavioral', 'technical', 'situational']);

export const generateQuestionsRequestSchema = z.object({
  job_title: z.string().min(1),
  company_name: z.string().min(1),
  job_description_text: z.string().min(10),
  profile_summary: z.string().optional(),
});

export const evaluateAnswerRequestSchema = z.object({
  session_id: z.string().uuid(),
  question_id: z.number().int().positive(),
  question_text: z.string().min(1),
  answer_text: z.string().min(10),
  job_description_text: z.string().min(10),
  profile_summary: z.string().optional(),
});

export const interviewFeedbackSchema = z.object({
  strengths: z.array(z.string()),
  improvements: z.array(z.string()),
  star_suggestion: z.object({
    situation: z.string(),
    task: z.string(),
    action: z.string(),
    result: z.string(),
  }),
  score: z.number().int().min(1).max(5),
});

export const interviewQuestionSchema = z.object({
  id: z.number().int().positive(),
  text: z.string(),
  category: interviewQuestionCategorySchema,
});

export const interviewQuestionsArraySchema = z.array(interviewQuestionSchema).min(5).max(10);
```

3. `smart-apply-shared/src/types/auto-apply.ts` — CREATE

```typescript
export interface AutoApplyConfig {
  enabled: boolean;
  daily_limit: number; // 10–100, default 50
}

export interface AutoApplyResult {
  success: boolean;
  job_title: string;
  company_name: string;
  source_url: string;
  source_platform: string;
  error?: string;
}

export const AUTO_APPLY_DEFAULTS: AutoApplyConfig = {
  enabled: false,
  daily_limit: 50,
};
```

4. MODIFY `smart-apply-shared/src/types/application.ts` — Add `'auto-applied'` to `APPLICATION_STATUSES`:

```typescript
// Before:
export const APPLICATION_STATUSES = [
  'draft',
  'generated',
  'applied',
  'interviewing',
  ...
] as const;

// After:
export const APPLICATION_STATUSES = [
  'draft',
  'generated',
  'applied',
  'auto-applied',
  'interviewing',
  ...
] as const;
```

5. MODIFY `smart-apply-shared/src/schemas/application.schema.ts` — Add `'auto-applied'` to `applicationStatusSchema`:

```typescript
// Before:
export const applicationStatusSchema = z.enum([
  'draft',
  'generated',
  'applied',
  'interviewing',
  ...
]);

// After:
export const applicationStatusSchema = z.enum([
  'draft',
  'generated',
  'applied',
  'auto-applied',
  'interviewing',
  ...
]);
```

6. MODIFY `smart-apply-shared/src/index.ts` — Append exports:

```typescript
// Add these lines:
export * from './types/interview';
export * from './types/auto-apply';
export * from './schemas/interview.schema';
```

7. **Rebuild shared package:**
```bash
npm -w @smart-apply/shared run build
```

**Run:** `npm -w @smart-apply/shared run test`

---

### Step 2: Database Migration

**Create:** `supabase/migrations/00005_interview_sessions.sql`

```sql
-- Interview practice sessions for Premium users
CREATE TABLE IF NOT EXISTS interview_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clerk_user_id TEXT NOT NULL,
  job_title TEXT NOT NULL,
  company_name TEXT NOT NULL,
  job_description_text TEXT,
  questions JSONB NOT NULL DEFAULT '[]'::jsonb,
  answers JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_interview_sessions_user
  ON interview_sessions(clerk_user_id);

CREATE INDEX IF NOT EXISTS idx_interview_sessions_created
  ON interview_sessions(clerk_user_id, created_at DESC);

ALTER TABLE interview_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY interview_sessions_user_policy ON interview_sessions
  FOR ALL
  USING (clerk_user_id = requesting_clerk_user_id())
  WITH CHECK (clerk_user_id = requesting_clerk_user_id());
```

**Verify:** `supabase db push` or manual review.

---

### Step 3: LLM Service — Interview Methods

**Test first:** MODIFY `smart-apply-backend/test/llm.service.spec.ts` — Add tests:

```typescript
// Add to existing test file:
// describe('generateInterviewQuestions')
//   - should return 5–10 questions with valid categories
//   - should propagate LLM errors
//   - should validate response with interviewQuestionsArraySchema
//
// describe('evaluateInterviewAnswer')
//   - should return feedback with strengths, improvements, star_suggestion, score
//   - should validate response with interviewFeedbackSchema
//   - should propagate LLM errors
```

**Then implement:** MODIFY `smart-apply-backend/src/infra/llm/llm.service.ts` — Add two methods:

```typescript
async generateInterviewQuestions(
  profileSummary: string,
  jobDescriptionText: string,
  jobTitle: string,
  companyName: string,
): Promise<Array<{ id: number; text: string; category: string }>> {
  const systemPrompt = `You are an expert interviewer preparing role-specific questions.
Generate 5-10 interview questions for a candidate applying to the specified role.

For each question, provide:
- id: sequential integer starting from 1
- text: the interview question
- category: exactly one of "behavioral", "technical", or "situational"

Rules:
- Mix categories (at least 2 behavioral, 2 technical, 1 situational)
- Make questions specific to the job description and candidate's background
- Include at least 1 question about skills gaps between the candidate profile and JD
- Do NOT ask generic questions like "Tell me about yourself"

Return ONLY a valid JSON array.`;

  const userPrompt = `Job Title: ${jobTitle}
Company: ${companyName}
Job Description: ${jobDescriptionText}
Candidate Summary: ${profileSummary}`;

  const raw = await this.chatCompletion(systemPrompt, userPrompt, {
    temperature: 0.8,
    max_tokens: 2000,
  });

  return this.parseAndValidate(raw, interviewQuestionsArraySchema);
}

async evaluateInterviewAnswer(
  questionText: string,
  answerText: string,
  jobDescriptionText: string,
  profileSummary?: string,
): Promise<{ strengths: string[]; improvements: string[]; star_suggestion: { situation: string; task: string; action: string; result: string }; score: number }> {
  const systemPrompt = `You are an interview coach evaluating a candidate's practice answer using the STAR method.

Evaluate the answer and provide:
- strengths: array of 1-3 specific things done well
- improvements: array of 1-3 specific areas for improvement
- star_suggestion: a structured STAR framework suggestion with keys: situation, task, action, result
- score: integer 1-5 (1=poor, 2=below average, 3=average, 4=good, 5=excellent)

Be specific — reference actual content from the candidate's answer.
Consider the job description context when evaluating relevance.

Return ONLY valid JSON.`;

  const userPrompt = `Question: ${questionText}
Answer: ${answerText}
Job Description: ${jobDescriptionText}${profileSummary ? `\nCandidate Summary: ${profileSummary}` : ''}`;

  const raw = await this.chatCompletion(systemPrompt, userPrompt, {
    temperature: 0.3,
    max_tokens: 1500,
  });

  return this.parseAndValidate(raw, interviewFeedbackSchema);
}
```

Import `interviewQuestionsArraySchema` and `interviewFeedbackSchema` from `@smart-apply/shared`.

**Run:** `npm -w @smart-apply/api run test`

---

### Step 4: Interview Module (Backend)

**Test files first:**
- `smart-apply-backend/test/interview.service.spec.ts`
- `smart-apply-backend/test/interview.controller.spec.ts`

```typescript
// interview.service.spec.ts:
// describe('InterviewService')
//   describe('generateQuestions')
//     - should call LlmService.generateInterviewQuestions with correct args
//     - should insert session into Supabase and return session_id + questions
//     - should throw if Supabase insert fails
//   describe('evaluateAnswer')
//     - should fetch session, call LlmService.evaluateInterviewAnswer, update session
//     - should throw NotFoundException if session not found
//   describe('listSessions')
//     - should return sessions ordered by created_at DESC
//     - should compute answered_count and average_score from answers JSONB
//   describe('getSession')
//     - should return full session with questions and answers
//     - should throw NotFoundException if session not found

// interview.controller.spec.ts:
// describe('InterviewController')
//   describe('POST /api/interview/generate-questions')
//     - should call service.generateQuestions with userId and validated body
//     - should return 403 for non-premium users (mocked SubscriptionGuard)
//   describe('POST /api/interview/evaluate-answer')
//     - should call service.evaluateAnswer with userId and validated body
//   describe('GET /api/interview/sessions')
//     - should call service.listSessions with userId
//   describe('GET /api/interview/sessions/:id')
//     - should call service.getSession with userId and id param
```

**Then implement:**

1. `smart-apply-backend/src/modules/interview/interview.service.ts` — CREATE

```typescript
import { Injectable, NotFoundException } from '@nestjs/common';
import { SupabaseService } from '../../infra/supabase/supabase.service';
import { LlmService } from '../../infra/llm/llm.service';
import type {
  GenerateQuestionsRequest,
  GenerateQuestionsResponse,
  EvaluateAnswerRequest,
  EvaluateAnswerResponse,
  InterviewSession,
  InterviewSessionSummary,
} from '@smart-apply/shared';

@Injectable()
export class InterviewService {
  constructor(
    private readonly supabase: SupabaseService,
    private readonly llm: LlmService,
  ) {}

  async generateQuestions(userId: string, request: GenerateQuestionsRequest): Promise<GenerateQuestionsResponse> {
    const questions = await this.llm.generateInterviewQuestions(
      request.profile_summary ?? '',
      request.job_description_text,
      request.job_title,
      request.company_name,
    );

    const { data, error } = await this.supabase.client
      .from('interview_sessions')
      .insert({
        clerk_user_id: userId,
        job_title: request.job_title,
        company_name: request.company_name,
        job_description_text: request.job_description_text,
        questions,
        answers: {},
      })
      .select('id')
      .single();

    if (error) throw error;

    return { session_id: data.id, questions };
  }

  async evaluateAnswer(userId: string, request: EvaluateAnswerRequest): Promise<EvaluateAnswerResponse> {
    const { data: session, error: fetchError } = await this.supabase.client
      .from('interview_sessions')
      .select('answers')
      .eq('id', request.session_id)
      .eq('clerk_user_id', userId)
      .single();

    if (fetchError || !session) throw new NotFoundException('Interview session not found');

    const feedback = await this.llm.evaluateInterviewAnswer(
      request.question_text,
      request.answer_text,
      request.job_description_text,
      request.profile_summary,
    );

    const updatedAnswers = {
      ...(session.answers as Record<string, unknown>),
      [request.question_id]: {
        question_id: request.question_id,
        answer_text: request.answer_text,
        feedback,
      },
    };

    const { error: updateError } = await this.supabase.client
      .from('interview_sessions')
      .update({ answers: updatedAnswers, updated_at: new Date().toISOString() })
      .eq('id', request.session_id)
      .eq('clerk_user_id', userId);

    if (updateError) throw updateError;

    return { feedback };
  }

  async listSessions(userId: string): Promise<InterviewSessionSummary[]> {
    const { data, error } = await this.supabase.client
      .from('interview_sessions')
      .select('id, job_title, company_name, questions, answers, created_at')
      .eq('clerk_user_id', userId)
      .order('created_at', { ascending: false });

    if (error) throw error;

    return (data ?? []).map((row) => {
      const questions = row.questions as unknown[];
      const answers = row.answers as Record<string, { feedback?: { score?: number } }>;
      const answerEntries = Object.values(answers);
      const scores = answerEntries
        .map((a) => a.feedback?.score)
        .filter((s): s is number => typeof s === 'number');

      return {
        id: row.id,
        job_title: row.job_title,
        company_name: row.company_name,
        question_count: questions.length,
        answered_count: answerEntries.length,
        average_score: scores.length > 0
          ? Math.round((scores.reduce((a, b) => a + b, 0) / scores.length) * 10) / 10
          : null,
        created_at: row.created_at,
      };
    });
  }

  async getSession(userId: string, sessionId: string): Promise<InterviewSession> {
    const { data, error } = await this.supabase.client
      .from('interview_sessions')
      .select('*')
      .eq('id', sessionId)
      .eq('clerk_user_id', userId)
      .single();

    if (error || !data) throw new NotFoundException('Interview session not found');

    return {
      id: data.id,
      clerk_user_id: data.clerk_user_id,
      job_title: data.job_title,
      company_name: data.company_name,
      job_description_text: data.job_description_text,
      questions: data.questions as InterviewSession['questions'],
      answers: data.answers as InterviewSession['answers'],
      created_at: data.created_at,
      updated_at: data.updated_at,
    };
  }
}
```

2. `smart-apply-backend/src/modules/interview/interview.controller.ts` — CREATE

```typescript
import {
  Controller,
  Post,
  Get,
  Body,
  Param,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ClerkAuthGuard } from '../auth/clerk-auth.guard';
import { SubscriptionGuard } from '../subscription/subscription.guard';
import { RequiresTier } from '../subscription/requires-tier.decorator';
import { InterviewService } from './interview.service';
import {
  generateQuestionsRequestSchema,
  evaluateAnswerRequestSchema,
} from '@smart-apply/shared';
import type {
  GenerateQuestionsResponse,
  EvaluateAnswerResponse,
  InterviewSession,
  InterviewSessionSummary,
} from '@smart-apply/shared';

@Controller('api/interview')
@UseGuards(ClerkAuthGuard)
export class InterviewController {
  constructor(private readonly service: InterviewService) {}

  @Post('generate-questions')
  @UseGuards(SubscriptionGuard)
  @RequiresTier('premium')
  async generateQuestions(
    @Req() req: { userId: string },
    @Body() body: unknown,
  ): Promise<GenerateQuestionsResponse> {
    const validated = generateQuestionsRequestSchema.parse(body);
    return this.service.generateQuestions(req.userId, validated);
  }

  @Post('evaluate-answer')
  @UseGuards(SubscriptionGuard)
  @RequiresTier('premium')
  async evaluateAnswer(
    @Req() req: { userId: string },
    @Body() body: unknown,
  ): Promise<EvaluateAnswerResponse> {
    const validated = evaluateAnswerRequestSchema.parse(body);
    return this.service.evaluateAnswer(req.userId, validated);
  }

  @Get('sessions')
  async listSessions(
    @Req() req: { userId: string },
  ): Promise<{ sessions: InterviewSessionSummary[] }> {
    const sessions = await this.service.listSessions(req.userId);
    return { sessions };
  }

  @Get('sessions/:id')
  async getSession(
    @Req() req: { userId: string },
    @Param('id') id: string,
  ): Promise<InterviewSession> {
    return this.service.getSession(req.userId, id);
  }
}
```

3. `smart-apply-backend/src/modules/interview/interview.module.ts` — CREATE

```typescript
import { Module } from '@nestjs/common';
import { InterviewController } from './interview.controller';
import { InterviewService } from './interview.service';
import { SubscriptionGuard } from '../subscription/subscription.guard';

@Module({
  controllers: [InterviewController],
  providers: [InterviewService, SubscriptionGuard],
})
export class InterviewModule {}
```

4. MODIFY `smart-apply-backend/src/app.module.ts` — Add `InterviewModule` to imports:

```typescript
import { InterviewModule } from './modules/interview/interview.module';

// In @Module.imports array, add:
InterviewModule,
```

**Run:** `npm -w @smart-apply/api run test`

---

### Step 5: Auto-Apply Extension — Content Script + Storage

**Test first:**
- `smart-apply-extension/test/auto-apply.spec.ts`

```typescript
// describe('detectSubmitButton')
//   - should find button[type="submit"]
//   - should find input[type="submit"]
//   - should find button containing "Apply Now" text
//   - should NOT match buttons containing "Cancel" or "Save Draft"
//   - should return null when no submit button found
//
// describe('executeAutoApply')
//   - should abort if fill rate < 80%
//   - should abort if submit button not found
//   - should abort if daily limit reached
//   - should return success after countdown completes (mock timer)
//   - should return cancelled if user cancels during countdown
//
// describe('showCountdownOverlay')
//   - should create overlay element in DOM
//   - should call onComplete after countdown
//   - should call onCancel when cancel clicked
//   - should remove overlay after completion
```

**Then implement:**

1. MODIFY `smart-apply-extension/src/lib/storage.ts` — Add auto-apply fields to `StorageSchema`:

```typescript
// Add to StorageSchema interface:
auto_apply_enabled: boolean;
auto_apply_daily_limit: number;
auto_apply_date: string;   // ISO date string YYYY-MM-DD
auto_apply_count: number;  // today's count
```

2. `smart-apply-extension/src/content/auto-apply.ts` — CREATE

```typescript
import { getStorage, setStorage } from '../lib/storage';

const SUBMIT_BUTTON_SELECTORS = [
  'button[type="submit"]',
  'input[type="submit"]',
];

const SUBMIT_TEXT_PATTERNS = /submit|apply now|send application|apply for this job/i;
const EXCLUDE_TEXT_PATTERNS = /save draft|cancel|back|previous|reset/i;

export function detectSubmitButton(): HTMLButtonElement | HTMLInputElement | null {
  // First try explicit submit types
  for (const selector of SUBMIT_BUTTON_SELECTORS) {
    const elements = document.querySelectorAll<HTMLButtonElement | HTMLInputElement>(selector);
    for (const el of elements) {
      const text = el.textContent?.trim() ?? el.value ?? '';
      if (!EXCLUDE_TEXT_PATTERNS.test(text)) return el;
    }
  }

  // Fallback: search all buttons for submit-like text
  const allButtons = document.querySelectorAll<HTMLButtonElement>('button');
  for (const btn of allButtons) {
    const text = btn.textContent?.trim() ?? '';
    if (SUBMIT_TEXT_PATTERNS.test(text) && !EXCLUDE_TEXT_PATTERNS.test(text)) {
      return btn;
    }
  }

  return null;
}

export function showCountdownOverlay(
  seconds: number,
  onComplete: () => void,
  onCancel: () => void,
): HTMLDivElement {
  const overlay = document.createElement('div');
  overlay.id = 'smart-apply-auto-submit-overlay';
  overlay.style.cssText = `
    position: fixed; bottom: 20px; right: 20px; z-index: 999999;
    background: #1a1a2e; color: white; padding: 16px 24px;
    border-radius: 12px; font-family: system-ui, sans-serif;
    box-shadow: 0 4px 12px rgba(0,0,0,0.3); display: flex;
    align-items: center; gap: 16px; font-size: 14px;
  `;

  const textSpan = document.createElement('span');
  textSpan.textContent = `Auto-submitting in ${seconds}s...`;

  const cancelBtn = document.createElement('button');
  cancelBtn.textContent = 'Cancel';
  cancelBtn.style.cssText = `
    background: #dc2626; color: white; border: none; padding: 6px 16px;
    border-radius: 6px; cursor: pointer; font-size: 14px;
  `;

  overlay.appendChild(textSpan);
  overlay.appendChild(cancelBtn);
  document.body.appendChild(overlay);

  let remaining = seconds;
  const intervalId = setInterval(() => {
    remaining--;
    textSpan.textContent = `Auto-submitting in ${remaining}s...`;
    if (remaining <= 0) {
      clearInterval(intervalId);
      overlay.remove();
      onComplete();
    }
  }, 1000);

  cancelBtn.addEventListener('click', () => {
    clearInterval(intervalId);
    overlay.remove();
    onCancel();
  });

  return overlay;
}

export async function executeAutoApply(
  filledFieldCount: number,
  totalFieldCount: number,
): Promise<{ success: boolean; error?: string }> {
  // Check fill rate
  if (totalFieldCount > 0 && filledFieldCount / totalFieldCount < 0.8) {
    return { success: false, error: 'Fill rate below 80% threshold' };
  }

  // Check daily limit
  const today = new Date().toISOString().slice(0, 10);
  const savedDate = await getStorage('auto_apply_date');
  let todayCount = 0;
  if (savedDate === today) {
    todayCount = (await getStorage('auto_apply_count')) ?? 0;
  }
  const dailyLimit = (await getStorage('auto_apply_daily_limit')) ?? 50;
  if (todayCount >= dailyLimit) {
    return { success: false, error: 'Daily limit reached' };
  }

  // Detect submit button
  const submitBtn = detectSubmitButton();
  if (!submitBtn) {
    return { success: false, error: 'Submit button not found' };
  }

  // Show countdown and wait for result
  return new Promise((resolve) => {
    showCountdownOverlay(
      5,
      async () => {
        // Countdown completed — click submit
        submitBtn.click();
        // Increment daily count
        await setStorage('auto_apply_date', today);
        await setStorage('auto_apply_count', todayCount + 1);
        resolve({ success: true });
      },
      () => {
        // User cancelled
        resolve({ success: false, error: 'Cancelled by user' });
      },
    );
  });
}
```

3. MODIFY `smart-apply-extension/src/background/service-worker.ts` — Add `AUTO_APPLY_RESULT` handler:

```typescript
// In the message handler switch/if chain, add:
// case 'AUTO_APPLY_RESULT':
//   If payload.success, call POST /api/applications with:
//   { company_name, job_title, source_platform, source_url, status: 'auto-applied' }
```

4. MODIFY `smart-apply-extension/src/ui/popup/App.tsx` — Import and render `AutoApplySettings` component (created in next step).

**Run:** `npm -w @smart-apply/extension run test`

---

### Step 6: Auto-Apply Settings UI (Extension Popup)

**Create:** `smart-apply-extension/src/ui/popup/AutoApplySettings.tsx`

```typescript
// React component with:
// - Toggle switch for auto-apply enabled/disabled
// - Number input for daily limit (10–100, default 50)
// - Display of today's count: "X / Y applications today"
// - Premium tier check: if not premium, show upgrade prompt instead of controls
// - Read/write from chrome.storage.local (auto_apply_enabled, auto_apply_daily_limit, etc.)
// - All interactive elements keyboard-accessible with visible focus
```

**Integrate:** Add `<AutoApplySettings />` to the popup App.tsx in a collapsible "Auto-Apply" section.

**Run:** `npm -w @smart-apply/extension run test`

---

### Step 7: Landing Page & SEO (Web)

**Test first:**
- `smart-apply-web/test/landing.spec.tsx`

```typescript
// describe('Landing Page')
//   - should render hero section with heading
//   - should render feature grid with 6 features
//   - should render how-it-works section with 3 steps
//   - should render "Get Started" CTA link pointing to /sign-in
//   - should render "View Pricing" link pointing to /pricing
//   - should have proper heading hierarchy (h1, h2s)
```

**Then implement:**

1. `smart-apply-web/src/components/landing/hero-section.tsx` — CREATE

```typescript
// Server component (no 'use client')
// Renders: h1 headline, subtitle paragraph, two CTA buttons (Get Started → /sign-in, View Pricing → /pricing)
// Uses Tailwind for styling, Link from next/link for navigation
// Responsive: stack vertically on mobile, side-by-side CTAs on desktop
```

2. `smart-apply-web/src/components/landing/feature-grid.tsx` — CREATE

```typescript
// Server component
// 6-item responsive grid (1 col mobile, 2 col tablet, 3 col desktop)
// Features: ATS Scoring, AI Cover Letters, One-Click Autofill, Resume Templates, Zero-Storage Privacy, Application Tracking
// Each item: icon (lucide-react), title, 1-sentence description
// Use existing Card component from shadcn/ui if available, otherwise simple div with border
```

3. `smart-apply-web/src/components/landing/how-it-works.tsx` — CREATE

```typescript
// Server component
// 3 numbered steps in a horizontal layout (vertical on mobile):
// 1. Import Your Profile — "Import from LinkedIn or upload your resume"
// 2. Optimize & Score — "AI tailors your resume to each JD with 5-dimension ATS scoring"
// 3. Apply with Confidence — "Download PDF, auto-fill applications, track your pipeline"
```

4. MODIFY `smart-apply-web/src/app/page.tsx` — Replace current simple landing with full marketing page:

```typescript
// Remove 'export const dynamic = "force-dynamic"' (use SSG for performance)
// Import and compose: HeroSection, FeatureGrid, HowItWorks
// Add Next.js metadata export with:
//   title: 'Smart Apply — AI-Powered Resume Optimization & Job Application Assistant'
//   description: 'Tailor your resume for every job description with 5-dimension ATS scoring, AI cover letters, one-click autofill, and zero-storage privacy.'
//   openGraph: { title, description, type: 'website', url: 'https://smart-apply.app' }
//   twitter: { card: 'summary_large_image', title, description }
// Add JSON-LD SoftwareApplication structured data via <script type="application/ld+json">
// Footer with links: Pricing, Sign In, GitHub
```

5. MODIFY `smart-apply-web/src/middleware.ts` — Add `/pricing(.*)` and `/examples(.*)` to `isPublicRoute`:

```typescript
const isPublicRoute = createRouteMatcher([
  '/sign-in(.*)',
  '/sign-up(.*)',
  '/api/webhooks(.*)',
  '/',
  '/not-found',
  '/pricing(.*)',   // NEW
  '/examples(.*)',  // NEW
]);
```

6. `smart-apply-web/src/app/robots.ts` — CREATE

```typescript
import type { MetadataRoute } from 'next';

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: '*',
      allow: '/',
      disallow: ['/dashboard', '/optimize', '/settings', '/profile', '/interview-prep'],
    },
    sitemap: 'https://smart-apply.app/sitemap.xml',
  };
}
```

7. `smart-apply-web/src/app/sitemap.ts` — CREATE

```typescript
import type { MetadataRoute } from 'next';

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    { url: 'https://smart-apply.app', lastModified: new Date(), changeFrequency: 'weekly', priority: 1 },
    { url: 'https://smart-apply.app/pricing', lastModified: new Date(), changeFrequency: 'monthly', priority: 0.7 },
  ];
}
```

**Run:** `npm -w @smart-apply/web run test`

---

### Step 8: Interview Prep Page (Web)

**Test first:**
- `smart-apply-web/test/interview-prep.spec.tsx`

```typescript
// describe('Interview Prep Page')
//   describe('QuestionCard')
//     - should render question text and category badge
//     - should render textarea for answer input
//     - should render submit button
//     - should display feedback panel when feedback is provided
//     - should show strengths and improvements in feedback
//     - should show STAR suggestion in feedback
//     - should show score badge
//   describe('SessionList')
//     - should render list of sessions with job title, company, date
//     - should show answered count and average score
//     - should show empty state when no sessions
```

**Then implement:**

1. `smart-apply-web/src/components/interview/question-card.tsx` — CREATE

```typescript
'use client';
// Props: question: InterviewQuestion, feedback: InterviewFeedback | null,
//        onSubmitAnswer: (answer: string) => void, isLoading: boolean
// Renders:
//   - Category badge (behavioral/technical/situational) with color coding
//   - Question text
//   - Textarea for answer (min 10 chars)
//   - Submit button (disabled while loading)
//   - Feedback panel (shown after evaluation):
//     - Score badge (1-5 with color)
//     - Strengths list (green bullets)
//     - Improvements list (amber bullets)
//     - STAR suggestion accordion/collapsible
// All interactive elements keyboard-accessible with visible focus indicators
```

2. `smart-apply-web/src/components/interview/session-list.tsx` — CREATE

```typescript
'use client';
// Props: sessions: InterviewSessionSummary[], onSelect: (id: string) => void
// Renders:
//   - Sorted list of past sessions
//   - Each item shows: job_title @ company_name, date, answered/total, avg score
//   - Click/Enter navigates to session detail
//   - Empty state: "No interview practice sessions yet. Start one above!"
```

3. `smart-apply-web/src/app/interview-prep/page.tsx` — CREATE

```typescript
'use client';
// Full interview prep page with:
// 1. JD input form (textarea + company + job title fields)
//    OR: "Select from saved applications" dropdown (fetch from /api/applications)
// 2. "Generate Questions" button → POST /api/interview/generate-questions
//    Handle 403 (upgrade_required) → show UpgradePrompt
//    Handle loading state
// 3. Question navigation: show questions one at a time with prev/next
// 4. Answer submission → POST /api/interview/evaluate-answer → show feedback
// 5. Session completion summary
// 6. Below: SessionList showing past sessions (GET /api/interview/sessions)
// Use apiFetch from lib/api-client.ts
// Use useAuth() from @clerk/nextjs for token
```

**Run:** `npm -w @smart-apply/web run test`

---

### Step 9: Resume Examples Page (Web)

**Create:** `smart-apply-web/src/app/examples/page.tsx`

```typescript
// SSG page (no 'use client')
// Metadata: title "Resume Examples — Smart Apply", description for SEO
// Content:
//   - h1: "Resume Examples by Industry"
//   - Grid of 6 industry cards: Software Engineering, Marketing, Finance, Healthcare, Education, Design
//   - Each card: industry name, brief description, "Example tips" list
//   - CTA at bottom: "Ready to optimize your resume? Get Started" → /sign-in
// This is a content page for SEO — no dynamic data, no API calls
```

**Run:** `npm -w @smart-apply/web run test`

---

## Acceptance Verification

After all 9 steps, run the full test suite:

```bash
npm -w @smart-apply/shared run build
npm -w @smart-apply/shared run test
npm -w @smart-apply/api run test
npm -w @smart-apply/extension run test
npm -w @smart-apply/web run test
```

All tests must pass. Zero regressions in existing test files.

### Manual Verification Checklist

- [ ] `POST /api/interview/generate-questions` returns 5–10 questions (Premium user)
- [ ] `POST /api/interview/generate-questions` returns 403 for Free/Pro users
- [ ] `POST /api/interview/evaluate-answer` returns structured feedback with STAR
- [ ] `GET /api/interview/sessions` returns session list ordered by date
- [ ] Extension auto-apply toggle persists in chrome.storage
- [ ] Auto-apply countdown overlay appears and can be cancelled
- [ ] Auto-apply respects daily limit
- [ ] Landing page renders with hero, features, how-it-works sections
- [ ] Landing page has Open Graph meta tags and JSON-LD
- [ ] `/pricing` accessible without auth
- [ ] `robots.txt` and `sitemap.xml` served correctly
- [ ] Interview prep page loads and generates questions
- [ ] All interactive elements keyboard-accessible

---

## Constraints

- Do NOT add libraries not listed in LLD-MVP-P06B §9 (Dependency Notes)
- Do NOT modify files not listed in the File-Level Change Manifest
- Use existing design-system components (shadcn/ui) — do not introduce new UI libraries
- All interactive elements must be keyboard-accessible with visible focus indicators
- Validate all API inputs at the boundary with Zod
- Handle loading, error, and empty states in UI components
- TypeScript strict mode — no `any` types, no `@ts-ignore`
- Interview prep and auto-apply are Premium-tier features — enforce at API boundary
- After modifying shared types, always rebuild: `npm -w @smart-apply/shared run build`
