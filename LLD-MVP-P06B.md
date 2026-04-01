---
title: LLD-MVP-P06B — Post-Release Growth Phase B (Competitive Parity)
description: Low-Level Design for MVP Phase 6B — AI Interview Preparation, Auto-Apply Job Submission, and Landing Page & SEO Foundation.
hero_eyebrow: Low-level design
hero_title: LLD for MVP Phase 6B
hero_summary: File-level change manifest, interface definitions, function-level design, and database operations for the three P1 requirements.
permalink: /lld-mvp-p06b/
---

# LLD-MVP-P06B — Post-Release Growth Phase B (Competitive Parity)

**Version:** 1.0  
**Date:** 2026-03-31  
**Input:** HLD-MVP-P06B.md + architecture.md  
**Phase:** P06B (Should-Have — Competitive Parity)

---

## 1. File-Level Change Manifest

| # | File Path | Action | REQ | Purpose |
|:--|:---|:---|:---|:---|
| 1 | `smart-apply-shared/src/types/interview.ts` | CREATE | REQ-06-04 | Interview session types, question/feedback interfaces |
| 2 | `smart-apply-shared/src/schemas/interview.schema.ts` | CREATE | REQ-06-04 | Zod schemas for interview API request/response validation |
| 3 | `smart-apply-shared/src/types/auto-apply.ts` | CREATE | REQ-06-05 | Auto-apply config & status types |
| 4 | `smart-apply-shared/src/types/application.ts` | MODIFY | REQ-06-05 | Add `'auto-applied'` to `APPLICATION_STATUSES` |
| 5 | `smart-apply-shared/src/schemas/application.schema.ts` | MODIFY | REQ-06-05 | Add `'auto-applied'` to `applicationStatusSchema` |
| 6 | `smart-apply-shared/src/index.ts` | MODIFY | REQ-06-04,05 | Export new interview and auto-apply modules |
| 7 | `supabase/migrations/00005_interview_sessions.sql` | CREATE | REQ-06-04 | Interview sessions table with RLS + indexes |
| 8 | `smart-apply-backend/src/infra/llm/llm.service.ts` | MODIFY | REQ-06-04 | Add `generateInterviewQuestions()` and `evaluateInterviewAnswer()` |
| 9 | `smart-apply-backend/src/modules/interview/interview.module.ts` | CREATE | REQ-06-04 | NestJS module for interview feature |
| 10 | `smart-apply-backend/src/modules/interview/interview.controller.ts` | CREATE | REQ-06-04 | REST endpoints for question gen, answer eval, sessions |
| 11 | `smart-apply-backend/src/modules/interview/interview.service.ts` | CREATE | REQ-06-04 | Business logic for interview sessions |
| 12 | `smart-apply-backend/src/app.module.ts` | MODIFY | REQ-06-04 | Register InterviewModule |
| 13 | `smart-apply-extension/src/lib/storage.ts` | MODIFY | REQ-06-05 | Add auto-apply storage fields |
| 14 | `smart-apply-extension/src/lib/message-bus.ts` | MODIFY | REQ-06-05 | Add AUTO_APPLY message types |
| 15 | `smart-apply-extension/src/content/auto-apply.ts` | CREATE | REQ-06-05 | Submit button detection, countdown overlay, auto-submit logic |
| 16 | `smart-apply-extension/src/ui/popup/AutoApplySettings.tsx` | CREATE | REQ-06-05 | Auto-apply toggle, daily limit config, status display |
| 17 | `smart-apply-extension/src/background/service-worker.ts` | MODIFY | REQ-06-05 | Handle AUTO_APPLY_RESULT message, log applications |
| 18 | `smart-apply-extension/src/ui/popup/App.tsx` | MODIFY | REQ-06-05 | Integrate AutoApplySettings component |
| 19 | `smart-apply-web/src/app/page.tsx` | MODIFY | REQ-06-06 | Replace basic landing with full marketing page |
| 20 | `smart-apply-web/src/app/examples/page.tsx` | CREATE | REQ-06-06 | Resume examples SSG page |
| 21 | `smart-apply-web/src/app/interview-prep/page.tsx` | CREATE | REQ-06-04 | Interview preparation page route |
| 22 | `smart-apply-web/src/components/interview/question-card.tsx` | CREATE | REQ-06-04 | Question display + answer input + feedback panel |
| 23 | `smart-apply-web/src/components/interview/session-list.tsx` | CREATE | REQ-06-04 | Past interview sessions list |
| 24 | `smart-apply-web/src/components/landing/hero-section.tsx` | CREATE | REQ-06-06 | Landing page hero with CTA |
| 25 | `smart-apply-web/src/components/landing/feature-grid.tsx` | CREATE | REQ-06-06 | Feature highlights grid |
| 26 | `smart-apply-web/src/components/landing/how-it-works.tsx` | CREATE | REQ-06-06 | 3-step explanation section |
| 27 | `smart-apply-web/src/app/layout.tsx` | MODIFY | REQ-06-06 | Enhanced metadata with Open Graph + JSON-LD |
| 28 | `smart-apply-web/src/app/robots.ts` | CREATE | REQ-06-06 | robots.txt via Next.js convention |
| 29 | `smart-apply-web/src/app/sitemap.ts` | CREATE | REQ-06-06 | sitemap.xml via Next.js convention |

---

## 2. Interface & Type Definitions

### 2.1 Interview Types — `smart-apply-shared/src/types/interview.ts`

```typescript
export const INTERVIEW_QUESTION_CATEGORIES = [
  'behavioral',
  'technical',
  'situational',
] as const;

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
  answers: Record<string, InterviewAnswerEntry>; // keyed by question_id
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

### 2.2 Interview Schemas — `smart-apply-shared/src/schemas/interview.schema.ts`

```typescript
import { z } from 'zod';

export const interviewQuestionCategorySchema = z.enum([
  'behavioral',
  'technical',
  'situational',
]);

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

### 2.3 Auto-Apply Types — `smart-apply-shared/src/types/auto-apply.ts`

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

### 2.4 Application Status Extension

**File:** `smart-apply-shared/src/types/application.ts`

Add `'auto-applied'` to `APPLICATION_STATUSES`:

```typescript
export const APPLICATION_STATUSES = [
  'draft',
  'generated',
  'applied',
  'auto-applied',
  'interviewing',
  'offer',
  'rejected',
  'withdrawn',
] as const;
```

**File:** `smart-apply-shared/src/schemas/application.schema.ts`

Add `'auto-applied'` to `applicationStatusSchema`:

```typescript
export const applicationStatusSchema = z.enum([
  'draft',
  'generated',
  'applied',
  'auto-applied',
  'interviewing',
  'offer',
  'rejected',
  'withdrawn',
]);
```

---

## 3. Function-Level Design

### 3.1 LLM Service Extensions

#### `generateInterviewQuestions()`

**Location:** `smart-apply-backend/src/infra/llm/llm.service.ts`

```typescript
async generateInterviewQuestions(
  profileSummary: string,
  jobDescriptionText: string,
  jobTitle: string,
  companyName: string,
): Promise<Array<{ id: number; text: string; category: string }>>
```

**Logic:**
1. Construct system prompt instructing the LLM to generate 5–10 interview questions with category tags.
2. Include the job title, company name, JD, and profile summary in the user prompt.
3. Call `chatCompletion()` with `temperature: 0.8` for variety.
4. Parse and validate the JSON response against `interviewQuestionsArraySchema`.
5. Return the validated array.

**System Prompt:**
```
You are an expert interviewer preparing role-specific questions.
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

Return ONLY a valid JSON array.
```

**Error Cases:**
- LLM returns invalid JSON → throw `InternalServerErrorException`
- LLM returns <5 or >10 questions → re-parse with `.min(5).max(10)` validation, throw if fail

#### `evaluateInterviewAnswer()`

**Location:** `smart-apply-backend/src/infra/llm/llm.service.ts`

```typescript
async evaluateInterviewAnswer(
  questionText: string,
  answerText: string,
  jobDescriptionText: string,
  profileSummary?: string,
): Promise<{ strengths: string[]; improvements: string[]; star_suggestion: { situation: string; task: string; action: string; result: string }; score: number }>
```

**Logic:**
1. Construct system prompt instructing STAR framework evaluation.
2. Include question, answer, JD context, and optionally profile summary.
3. Call `chatCompletion()` with `temperature: 0.3` for consistent evaluation.
4. Parse and validate against `interviewFeedbackSchema`.
5. Return validated feedback object.

**System Prompt:**
```
You are an interview coach evaluating a candidate's practice answer using the STAR method.

Evaluate the answer and provide:
- strengths: array of 1-3 specific things done well
- improvements: array of 1-3 specific areas for improvement
- star_suggestion: a structured STAR framework suggestion (situation, task, action, result) showing how the answer could be restructured
- score: integer 1-5 (1=poor, 2=below average, 3=average, 4=good, 5=excellent)

Be specific — reference actual content from the candidate's answer.
Consider the job description context when evaluating relevance.

Return ONLY valid JSON.
```

**Error Cases:**
- LLM returns invalid JSON → throw `InternalServerErrorException`
- Score out of 1–5 range → clamp to bounds

### 3.2 Interview Service

**Location:** `smart-apply-backend/src/modules/interview/interview.service.ts`

#### `generateQuestions()`

```typescript
async generateQuestions(
  userId: string,
  request: GenerateQuestionsRequest,
): Promise<GenerateQuestionsResponse>
```

**Logic:**
1. Call `LlmService.generateInterviewQuestions()` with request fields.
2. Insert row into `interview_sessions` via Supabase: `clerk_user_id = userId`, `questions = JSON`, `answers = {}`, `feedback = {}`.
3. Return `{ session_id, questions }`.

#### `evaluateAnswer()`

```typescript
async evaluateAnswer(
  userId: string,
  request: EvaluateAnswerRequest,
): Promise<EvaluateAnswerResponse>
```

**Logic:**
1. Fetch session from `interview_sessions` where `id = request.session_id` and `clerk_user_id = userId`.
2. If not found → throw `NotFoundException`.
3. Call `LlmService.evaluateInterviewAnswer()`.
4. Update session row: set `answers[question_id] = { question_id, answer_text, feedback }` and `feedback[question_id] = feedback`.
5. Return `{ feedback }`.

#### `listSessions()`

```typescript
async listSessions(userId: string): Promise<InterviewSessionSummary[]>
```

**Logic:**
1. Query `interview_sessions` where `clerk_user_id = userId`, order by `created_at DESC`.
2. Map each row to `InterviewSessionSummary` computing `answered_count` from `answers` JSONB keys and `average_score` from feedback scores.

#### `getSession()`

```typescript
async getSession(userId: string, sessionId: string): Promise<InterviewSession>
```

**Logic:**
1. Fetch row where `id = sessionId` and `clerk_user_id = userId`.
2. If not found → throw `NotFoundException`.
3. Return mapped `InterviewSession`.

### 3.3 Interview Controller

**Location:** `smart-apply-backend/src/modules/interview/interview.controller.ts`

```typescript
@Controller('api/interview')
@UseGuards(ClerkAuthGuard)
export class InterviewController {
  constructor(private readonly service: InterviewService) {}

  @Post('generate-questions')
  @UseGuards(SubscriptionGuard)
  @RequiresTier('premium')
  async generateQuestions(
    @Req() req: { userId: string },
    @Body() body: GenerateQuestionsRequest,
  ): Promise<GenerateQuestionsResponse>

  @Post('evaluate-answer')
  @UseGuards(SubscriptionGuard)
  @RequiresTier('premium')
  async evaluateAnswer(
    @Req() req: { userId: string },
    @Body() body: EvaluateAnswerRequest,
  ): Promise<EvaluateAnswerResponse>

  @Get('sessions')
  async listSessions(
    @Req() req: { userId: string },
  ): Promise<{ sessions: InterviewSessionSummary[] }>

  @Get('sessions/:id')
  async getSession(
    @Req() req: { userId: string },
    @Param('id') id: string,
  ): Promise<InterviewSession>
}
```

### 3.4 Auto-Apply Content Script

**Location:** `smart-apply-extension/src/content/auto-apply.ts`

#### `detectSubmitButton()`

```typescript
function detectSubmitButton(): HTMLButtonElement | HTMLInputElement | null
```

**Logic:**
1. Query all `button[type="submit"], input[type="submit"]` elements.
2. If found, check text content does NOT match `save draft|cancel|back|previous` (case-insensitive).
3. If no type=submit found, search all buttons for text matching `submit|apply now|send application|apply for this job` (case-insensitive).
4. Return the first valid match or null.

#### `showCountdownOverlay()`

```typescript
function showCountdownOverlay(
  seconds: number,
  onComplete: () => void,
  onCancel: () => void,
): void
```

**Logic:**
1. Create a fixed-position overlay at the bottom of the page with countdown text and cancel button.
2. Decrement counter every 1 second.
3. On countdown complete → call `onComplete()` and remove overlay.
4. On cancel click → call `onCancel()` and remove overlay.
5. Overlay styled with z-index: 999999, dark background, white text.

#### `executeAutoApply()`

```typescript
async function executeAutoApply(
  filledFieldCount: number,
  totalFieldCount: number,
): Promise<AutoApplyResult>
```

**Logic:**
1. Check fill success rate: if `filledFieldCount / totalFieldCount < 0.8` → abort, return failure.
2. Detect submit button. If not found → return failure with error "Submit button not found".
3. Check daily limit from storage. If reached → return failure with error "Daily limit reached".
4. Show countdown overlay (5 seconds).
5. If user cancels → return failure with "Cancelled by user".
6. If countdown completes → click submit button.
7. Wait 2 seconds for navigation/confirmation.
8. Increment daily count in storage.
9. Return success with job details extracted from JD detector.

### 3.5 Landing Page Components

#### `hero-section.tsx`

Renders: headline, subtitle, CTA buttons (Sign Up, Learn More), decorative gradient.

```typescript
export function HeroSection(): JSX.Element
```

#### `feature-grid.tsx`

Renders: 6-item grid with icon, title, description for each feature (ATS Scoring, Cover Letters, Autofill, Templates, Privacy, Tracking).

```typescript
export function FeatureGrid(): JSX.Element
```

#### `how-it-works.tsx`

Renders: 3 numbered steps (Import Profile → Optimize & Score → Apply).

```typescript
export function HowItWorks(): JSX.Element
```

---

## 4. Database Operations

### 4.1 Interview Sessions CRUD

**Insert session:**
```typescript
const { data, error } = await supabase
  .from('interview_sessions')
  .insert({
    clerk_user_id: userId,
    job_title: request.job_title,
    company_name: request.company_name,
    job_description_text: request.job_description_text,
    questions: questions, // JSONB
    answers: {},
    feedback: {},
  })
  .select('id')
  .single();
```

**Update session (append answer + feedback):**
```typescript
// First fetch current answers/feedback
const { data: session } = await supabase
  .from('interview_sessions')
  .select('answers, feedback')
  .eq('id', sessionId)
  .eq('clerk_user_id', userId)
  .single();

// Merge new answer
const updatedAnswers = {
  ...session.answers,
  [questionId]: { question_id: questionId, answer_text: answerText, feedback: feedbackObj },
};
const updatedFeedback = { ...session.feedback, [questionId]: feedbackObj };

const { error } = await supabase
  .from('interview_sessions')
  .update({ answers: updatedAnswers, feedback: updatedFeedback })
  .eq('id', sessionId)
  .eq('clerk_user_id', userId);
```

**List sessions (summary):**
```typescript
const { data, error } = await supabase
  .from('interview_sessions')
  .select('id, job_title, company_name, questions, answers, feedback, created_at')
  .eq('clerk_user_id', userId)
  .order('created_at', { ascending: false });
```

**Get single session:**
```typescript
const { data, error } = await supabase
  .from('interview_sessions')
  .select('*')
  .eq('id', sessionId)
  .eq('clerk_user_id', userId)
  .single();
```

### 4.2 Application Status Enum Update

```sql
-- Migration 00005
ALTER TYPE application_status ADD VALUE IF NOT EXISTS 'auto-applied' AFTER 'applied';
```

Note: If the enum is managed in application code (not Postgres enum), this is handled by the shared type change only.

---

## 5. Extension Storage Schema Changes

**File:** `smart-apply-extension/src/lib/storage.ts`

Add to `StorageSchema`:
```typescript
auto_apply_enabled: boolean;
auto_apply_daily_limit: number;
auto_apply_date: string;     // ISO date string (YYYY-MM-DD)
auto_apply_count: number;    // today's count
```

---

## 6. Message Bus Extensions

**File:** `smart-apply-extension/src/background/service-worker.ts` (MessageType union)

Add:
```typescript
| { type: 'AUTO_APPLY_RESULT'; payload: AutoApplyResult }
| { type: 'CHECK_AUTO_APPLY'; payload: {} }
```

**Handler for `AUTO_APPLY_RESULT`:**
If `payload.success`, call `POST /api/applications` with:
```typescript
{
  company_name: payload.company_name,
  job_title: payload.job_title,
  source_platform: derivePlatform(payload.source_url),
  source_url: payload.source_url,
  status: 'auto-applied',
}
```

---

## 7. Web Routing & Middleware

### 7.1 Public vs Protected Routes

| Route | Auth Required | Rendering |
|:---|:---|:---|
| `/` | No | SSG (landing page) |
| `/examples` | No | SSG |
| `/pricing` | No | SSG (already exists) |
| `/auth/sign-in` | No | Client |
| `/dashboard` | Yes | Client |
| `/optimize` | Yes | Client |
| `/interview-prep` | Yes | Client |
| `/profile` | Yes | Client |
| `/settings` | Yes | Client |

### 7.2 Landing Page Route Change

The current `/` page (`smart-apply-web/src/app/page.tsx`) already serves as a basic landing page with Sign In and Dashboard links. It will be expanded with full marketing content (hero, features, how-it-works, CTA) while keeping the same route. Authenticated users clicking the Dashboard link navigate to `/dashboard` as before.

### 7.3 SEO Files

**`robots.ts`:**
```typescript
import type { MetadataRoute } from 'next';
export default function robots(): MetadataRoute.Robots {
  return {
    rules: { userAgent: '*', allow: '/', disallow: ['/dashboard', '/optimize', '/settings', '/profile', '/interview-prep'] },
    sitemap: 'https://smart-apply.app/sitemap.xml',
  };
}
```

**`sitemap.ts`:**
```typescript
import type { MetadataRoute } from 'next';
export default function sitemap(): MetadataRoute.Sitemap {
  return [
    { url: 'https://smart-apply.app', lastModified: new Date(), changeFrequency: 'weekly', priority: 1 },
    { url: 'https://smart-apply.app/examples', lastModified: new Date(), changeFrequency: 'monthly', priority: 0.8 },
    { url: 'https://smart-apply.app/pricing', lastModified: new Date(), changeFrequency: 'monthly', priority: 0.7 },
  ];
}
```

---

## 8. Testing Strategy

### 8.1 New Test Files

| File | Covers | Test Count Est. |
|:---|:---|:---|
| `smart-apply-shared/test/interview.schema.spec.ts` | Interview schema validation | 8–10 |
| `smart-apply-backend/test/interview.controller.spec.ts` | Interview endpoints + guards | 10–12 |
| `smart-apply-backend/test/interview.service.spec.ts` | Interview business logic | 8–10 |
| `smart-apply-extension/test/auto-apply.spec.ts` | Submit detection, countdown, limits | 8–10 |
| `smart-apply-web/test/landing.spec.ts` | Landing page components render | 6–8 |
| `smart-apply-web/test/interview-prep.spec.ts` | Interview prep page components | 6–8 |

### 8.2 Modified Test Files

| File | Changes |
|:---|:---|
| `smart-apply-shared/test/application.schema.spec.ts` | Add test for `auto-applied` status |
| `smart-apply-backend/test/llm.service.spec.ts` | Add tests for new LLM methods |

---

## 9. Dependency Notes

- **No new npm packages** for backend, shared, or extension.
- **No new npm packages** for web — uses existing shadcn/ui, Tailwind, lucide-react.
- **Next.js 15 metadata API** used for SEO (built-in, no additional dependency).
- **JSON-LD** rendered as `<script type="application/ld+json">` in layout — no library needed.
