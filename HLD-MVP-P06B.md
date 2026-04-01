---
title: HLD-MVP-P06B — Post-Release Growth Phase B (Competitive Parity)
description: High-Level Design for MVP Phase 6B — AI Interview Preparation, Auto-Apply Job Submission, and Landing Page & SEO Foundation.
hero_eyebrow: High-level design
hero_title: HLD for MVP Phase 6B
hero_summary: Translates BRD-MVP-06 P1 requirements (REQ-06-04, REQ-06-05, REQ-06-06) into architecture decisions, data flows, and acceptance criteria to close competitive gaps with established players.
permalink: /hld-mvp-p06b/
---

# HLD-MVP-P06B — Post-Release Growth Phase B (Competitive Parity)

**Version:** 1.0  
**Date:** 2026-03-31  
**Phase:** P06B (Should-Have — Competitive Parity)  
**Source:** BRD-MVP-06.md §5.2 (REQ-06-04, REQ-06-05, REQ-06-06)  
**Prerequisite:** All prior phases (P01–P07, Test P1–P2, P06A) complete and verified. 372 tests passing.

---

## 1. Phase Objective

### Business Goal

Close the competitive feature gap with AIApply.co in three high-impact areas: interview preparation (AIApply's mock interview + Interview Buddy), automated job submission (AIApply's flagship auto-apply with 372,000+ roles reported), and organic user acquisition through public-facing content (AIApply's landing page, resume examples, blog).

### User-Facing Outcome After This Phase

- Users can generate role-specific interview questions from any saved JD and receive AI feedback on their practice answers using the STAR method framework.
- The Chrome extension can auto-submit job applications after autofill, with opt-in controls, daily limits, and a countdown-cancel mechanism.
- Unauthenticated visitors see a professional landing page with feature highlights, social proof, resume examples, and a clear call to action, all optimized for search engine discovery.

---

## 2. Component Scope

### Repos Affected

| Repo | Changes |
|:---|:---|
| `smart-apply-backend` | New `InterviewModule` (controller + service), extend `LlmService` with interview methods |
| `smart-apply-web` | New `/interview-prep` route, new public pages (`/`, `/examples`), Next.js metadata/SEO config |
| `smart-apply-extension` | Auto-apply submission logic, countdown UI, daily limit tracking, new message types |
| `smart-apply-shared` | Interview schemas/types, auto-apply schemas/types |
| `smart-apply-doc` | This HLD + LLD + IMPL |
| `supabase` | New `interview_sessions` table migration |

### REQ Mapping

| REQ | Title | Priority | Status at Start | In Scope |
|:---|:---|:---|:---|:---|
| REQ-06-04 | AI Interview Preparation | P1 | ❌ Missing | ✅ Yes |
| REQ-06-05 | Auto-Apply Job Submission | P1 | ⚠️ Autofill only | ✅ Yes |
| REQ-06-06 | Landing Page & SEO Foundation | P1 | ❌ Missing | ✅ Yes |

### Explicitly Out of Scope

- Real-time Interview Buddy (REQ-06-09) — requires audio transcription, P2
- Resume Translation (REQ-06-07) — P2
- Job Board Integration (REQ-06-08) — P2
- Analytics Dashboard (REQ-06-10) — P2
- Voice recording for interview practice — text-only for this phase
- Blog CMS or dynamic content management — static pages only
- Charting libraries — no new UI dependencies without approval

---

## 3. Architecture Decisions

### AD-01: AI Interview Preparation Module (REQ-06-04)

**Decision:** Create an `InterviewModule` in the backend with two endpoints: `POST /api/interview/generate-questions` (generates 5–10 role-specific questions from JD + profile) and `POST /api/interview/evaluate-answer` (provides STAR-structured feedback on a user's answer). Add two new LLM methods: `generateInterviewQuestions()` and `evaluateInterviewAnswer()`. Interview sessions are persisted in a new `interview_sessions` table in Supabase.

**Rationale:** The LLM service already handles structured prompt/response patterns (extractRequirements, optimizeResume, generateCoverLetter). Interview question generation and answer evaluation follow the same pattern — structured system prompt, user context, JSON-validated response. Storing sessions in Supabase allows users to review past practice from their dashboard. The interview module is gated behind the Premium subscription tier (per BRD §7.1).

**Key Design:**
- `generateInterviewQuestions()` receives profile + JD + job title and returns an array of 5–10 questions with category tags (behavioral, technical, situational).
- `evaluateInterviewAnswer()` receives the question, user's answer, profile context, and JD, then returns structured feedback: strengths, improvements, suggested STAR structure, overall score (1–5).
- `interview_sessions` table stores: `id`, `clerk_user_id`, `job_title`, `company_name`, `questions` (JSONB), `answers` (JSONB), `feedback` (JSONB), `created_at`, `updated_at`.
- Premium-tier gating enforced via `SubscriptionGuard` on both endpoints.
- Web UI: new `/interview-prep` route with question display, answer textarea, feedback panel, and session history.

**Reference:** BRD-MVP-06 REQ-06-04, existing LlmService patterns, SubscriptionGuard.

### AD-02: Auto-Apply Job Submission (REQ-06-05)

**Decision:** Extend the Chrome extension's autofill system with an optional auto-submit capability. Auto-apply is implemented entirely in the extension (content script + service worker) with no new backend endpoints. Applications are logged via the existing `POST /api/applications` endpoint.

**Rationale:** The current autofill system (`autofill.ts`) populates form fields but never submits. Auto-apply adds a submit step after autofill completion. This is a high-risk feature (anti-bot detection, incorrect submissions), so it must be strictly opt-in with multiple safety mechanisms: explicit session enable, 5-second countdown with cancel, daily limit tracking, and application logging. The feature is gated to Premium tier (checked via the subscription status API).

**Key Design:**
- **Opt-in activation:** User toggles "Auto-Apply Mode" in the popup. Stored in `chrome.storage.local` as `auto_apply_enabled: boolean`.
- **Countdown mechanism:** After autofill completes successfully, inject a 5-second countdown overlay at the bottom of the page. User can cancel. If countdown reaches zero, click the submit button.
- **Submit button detection:** Heuristic matching on `button[type="submit"]`, `input[type="submit"]`, or buttons with text matching `submit|apply|send application` (case-insensitive). Never submit if the detected button also matches "save draft" or "cancel" patterns.
- **Daily limit:** Tracked in `chrome.storage.local` as `{ auto_apply_date: string, auto_apply_count: number }`. Default limit: 50/day. User-configurable in popup settings (10–100 range).
- **Application logging:** After successful submission, the service worker sends `POST /api/applications` with status `auto-applied`, adding the source URL, job title, and company (from JD detector).
- **Failure handling:** If submit button not found or click fails, log as `draft` status and show notification.
- **Tier gating:** Before enabling auto-apply, check `GET /api/subscription/status`. If not Premium, show upgrade prompt.

**Reference:** BRD-MVP-06 REQ-06-05, existing autofill.ts, service-worker.ts message bus.

### AD-03: Landing Page & SEO Foundation (REQ-06-06)

**Decision:** Convert the web app's root route (`/`) from an authenticated dashboard redirect to a public landing page. Add a `/examples` route for resume examples. Use Next.js 15 static generation (SSG) for public pages and configure metadata, Open Graph tags, and JSON-LD structured data.

**Rationale:** Currently, unauthenticated users hitting `/` are redirected to Clerk sign-in. This provides no organic acquisition surface. AIApply.co drives traffic through extensive public content. The minimum viable marketing surface is: (1) a landing page with value proposition, features, and CTA, (2) resume examples for SEO-rich keyword content, (3) proper meta tags for social sharing and search indexing. Using Next.js SSG ensures sub-2-second load times (Lighthouse performance ≥90).

**Key Design:**
- **Landing page (`/`):** Hero section with headline + CTA, feature grid (6 features with icons), "How it works" 3-step section, social proof/stats section, pricing CTA linking to `/pricing`, footer.
- **Resume examples (`/examples`):** Static page with 6 industry-specific example resume sections (Tech, Marketing, Finance, Healthcare, Education, Design). Each example shows a before/after ATS optimization snippet. SSG content — no API calls.
- **SEO configuration:**
  - Root `layout.tsx` metadata: title template, description, keywords, Open Graph image, Twitter card.
  - Per-page `generateMetadata()` for `/examples`.
  - JSON-LD `SoftwareApplication` schema on landing page.
  - `robots.txt` and `sitemap.xml` via Next.js conventions.
- **Routing logic:** Middleware checks auth state. Authenticated users hitting `/` are redirected to `/dashboard`. Unauthenticated users see the landing page.
- **No new UI libraries.** Use existing shadcn/ui components (Button, Card) + Tailwind for layout.

**Reference:** BRD-MVP-06 REQ-06-06, Next.js 15 metadata API, existing shadcn/ui design system.

---

## 4. Data Flow

### 4.1 Interview Practice Flow (REQ-06-04)

```
User navigates to /interview-prep
  → Selects a saved application (company + JD) OR enters a new JD
  → Clicks "Generate Questions"
  → Web sends POST /api/interview/generate-questions
      { job_title, company_name, job_description_text, profile_summary }
  → SubscriptionGuard checks Premium tier ← if free/pro → 403 + upgrade prompt
  → InterviewService calls LlmService.generateInterviewQuestions()
  → LLM returns 5–10 questions with categories
  → InterviewService creates interview_sessions row (status: in_progress)
  → Response: { session_id, questions: [{id, text, category}] }

User selects question, types answer, clicks "Get Feedback"
  → Web sends POST /api/interview/evaluate-answer
      { session_id, question_id, answer_text }
  → InterviewService calls LlmService.evaluateInterviewAnswer()
  → LLM returns { strengths[], improvements[], star_suggestion, score }
  → InterviewService updates session row (appends Q&A + feedback to JSONB)
  → Response: { feedback }

User reviews all Q&A pairs on session completion
  → Web calls GET /api/interview/sessions (list) or GET /api/interview/sessions/:id
  → Rendered in /interview-prep with expandable Q&A cards
```

### 4.2 Auto-Apply Flow (REQ-06-05)

```
User enables "Auto-Apply Mode" in extension popup
  → Extension checks GET /api/subscription/status
  → If not Premium → show upgrade prompt, block toggle
  → If Premium → store auto_apply_enabled = true in chrome.storage.local

User navigates to a job posting page
  → JD detector extracts job description, title, company
  → User clicks "Autofill" (existing flow)
  → autofill.ts fills form fields (existing)
  → autofill.ts checks auto_apply_enabled
  → If enabled:
    → Detect submit button via heuristic matching
    → If no submit button found → notify user, log as draft
    → If found:
      → Inject countdown overlay (5 seconds, cancel button)
      → If user cancels → stop, log as draft
      → If countdown reaches 0:
        → Click submit button
        → Wait 2 seconds for navigation/confirmation
        → Send SAVE_APPLICATION message to service worker with status "auto-applied"
        → Increment auto_apply_count in chrome.storage.local
        → Check daily limit → if reached, disable auto-apply for today

  → If disabled: nothing (current behavior)
```

### 4.3 Landing Page Flow (REQ-06-06)

```
Unauthenticated user visits /
  → Next.js middleware detects no auth token
  → Serves static landing page (SSG)
  → User clicks "Get Started" → redirect to /auth/sign-in
  → After sign-in → redirect to /dashboard

Authenticated user visits /
  → Next.js middleware detects auth token
  → Redirect to /dashboard

Search engine crawler visits /
  → Receives SSG HTML with proper meta tags, JSON-LD, Open Graph
  → Follows internal links to /examples, /pricing
```

---

## 5. API Contracts

### 5.1 New Endpoints

#### POST /api/interview/generate-questions

**Auth:** Bearer token (ClerkAuthGuard) + SubscriptionGuard (Premium)

**Request:**
```json
{
  "job_title": "Senior Frontend Engineer",
  "company_name": "Acme Corp",
  "job_description_text": "We are looking for...",
  "profile_summary": "Experienced engineer with..."
}
```

**Response (200):**
```json
{
  "session_id": "uuid",
  "questions": [
    { "id": 1, "text": "Tell me about a time you led a frontend migration...", "category": "behavioral" },
    { "id": 2, "text": "How would you implement lazy loading for...", "category": "technical" }
  ]
}
```

**Errors:** 401 (unauthorized), 403 (not Premium tier), 422 (validation), 500 (LLM failure)

#### POST /api/interview/evaluate-answer

**Auth:** Bearer token (ClerkAuthGuard) + SubscriptionGuard (Premium)

**Request:**
```json
{
  "session_id": "uuid",
  "question_id": 1,
  "question_text": "Tell me about a time you led a frontend migration...",
  "answer_text": "In my previous role at...",
  "job_description_text": "We are looking for...",
  "profile_summary": "Experienced engineer with..."
}
```

**Response (200):**
```json
{
  "strengths": ["Specific example provided", "Mentioned measurable outcomes"],
  "improvements": ["Could elaborate on team collaboration", "Add more detail on challenges faced"],
  "star_suggestion": {
    "situation": "Describe the project context and your role",
    "task": "Explain the specific migration challenge",
    "action": "Detail the steps you took to lead the migration",
    "result": "Quantify the impact (performance improvement, team velocity)"
  },
  "score": 4
}
```

**Errors:** 401, 403, 404 (session not found), 422, 500

#### GET /api/interview/sessions

**Auth:** Bearer token (ClerkAuthGuard)

**Response (200):**
```json
{
  "sessions": [
    {
      "id": "uuid",
      "job_title": "Senior Frontend Engineer",
      "company_name": "Acme Corp",
      "question_count": 7,
      "answered_count": 5,
      "average_score": 3.8,
      "created_at": "2026-03-31T10:00:00Z"
    }
  ]
}
```

#### GET /api/interview/sessions/:id

**Auth:** Bearer token (ClerkAuthGuard)

**Response (200):**
```json
{
  "id": "uuid",
  "job_title": "Senior Frontend Engineer",
  "company_name": "Acme Corp",
  "questions": [
    {
      "id": 1,
      "text": "Tell me about...",
      "category": "behavioral",
      "answer": "In my previous role...",
      "feedback": {
        "strengths": [],
        "improvements": [],
        "star_suggestion": {},
        "score": 4
      }
    }
  ],
  "created_at": "2026-03-31T10:00:00Z",
  "updated_at": "2026-03-31T10:30:00Z"
}
```

### 5.2 No New Extension-to-Backend Endpoints for Auto-Apply

Auto-apply uses the existing `POST /api/applications` endpoint to log submissions. The only difference is `status: "auto-applied"` instead of `"applied"`.

**Note:** The `status` enum in the shared `ApplicationHistoryItem` type will be extended with `"auto-applied"`.

---

## 6. Security Considerations

### 6.1 Interview Module

| Concern | Mitigation |
|:---|:---|
| LLM prompt injection via JD text | Sanitize input; LLM system prompt explicitly instructs to ignore meta-instructions in user content |
| Excessive API usage | Premium-tier gating + rate limiting (10 sessions/day max) |
| Session data privacy | Sessions stored under `clerk_user_id` with RLS policy; users can only read their own sessions |
| Input validation | All request bodies validated with Zod at the controller boundary |

### 6.2 Auto-Apply

| Concern | Mitigation |
|:---|:---|
| Anti-bot detection on career portals | Randomized delays (100–500ms) between field fills; human-like submit timing; respect robots.txt signals |
| Unintended submission | 5-second countdown with prominent cancel button; opt-in per session (not persistent by default) |
| Rate abuse | Daily limit (default 50, max 100); tracked client-side in chrome.storage.local |
| Incorrect form submission | Only submit if all required fields were successfully filled; abort if fill success rate < 80% |
| Premium gate bypass | Extension checks subscription status on toggle enable; cannot start auto-apply without valid Premium tier |

### 6.3 Landing Page / SEO

| Concern | Mitigation |
|:---|:---|
| XSS in static content | All content is hardcoded (no user input on public pages); Next.js escapes by default |
| Open Graph image abuse | OG image hosted as static asset; no dynamic generation from user input |
| Crawler abuse / DDoS | Vercel edge caching for SSG pages; rate limiting inherited from Vercel infrastructure |

---

## 7. Dependencies & Integration Points

### 7.1 Dependencies from Previous Phases

| Dependency | Phase | Used By |
|:---|:---|:---|
| LlmService (OpenAI) | P01 | Interview question generation + answer evaluation |
| SubscriptionGuard + tiers | P06A | Interview (Premium), Auto-Apply (Premium) |
| ClerkAuthGuard | P01 | All new authenticated endpoints |
| Autofill system | P03 | Auto-apply submission |
| Application history API | P02 | Auto-apply logging |
| JD detector | P01 | Auto-apply job data extraction |
| shadcn/ui components | P01 | Landing page + interview prep UI |
| SupabaseService | P01 | Interview session persistence |

### 7.2 What Future Phases Depend On

| Capability | Future Phase |
|:---|:---|
| Interview sessions data | P06C REQ-06-09 (Real-Time Interview Coaching) |
| Landing page infrastructure | P06C REQ-06-08 (Job Board) — public job search page |
| Auto-apply framework | P06C — extended portal support |
| SEO metadata system | P06C — blog infrastructure |

### 7.3 External Service Integrations

| Service | Usage | New in This Phase |
|:---|:---|:---|
| OpenAI (GPT-4o) | Interview Q&A generation and evaluation | ✅ New LLM methods |
| Supabase | Interview session storage | ✅ New table |
| Clerk | Auth + subscription metadata | Existing |
| Stripe | Subscription checks | Existing |
| Vercel | SSG hosting for public pages | Existing (new page config) |

---

## 8. Acceptance Criteria Summary

### REQ-06-04: AI Interview Preparation

| # | Criterion | Test Type |
|:---|:---|:---|
| AC-1 | Given a saved JD, when user clicks "Practice Interview," system generates 5–10 role-specific questions within 10 seconds | Integration |
| AC-2 | Generated questions include category tags (behavioral, technical, situational) | Unit |
| AC-3 | Given a typed answer, AI provides structured STAR feedback within 10 seconds | Integration |
| AC-4 | Feedback references specific elements from the user's profile and JD | Manual |
| AC-5 | Completed sessions are reviewable from the interview prep page | Unit + Manual |
| AC-6 | Feature is gated to Premium tier; free/pro users see upgrade prompt | Unit |
| AC-7 | Interview sessions are isolated per user (RLS) | Unit |

### REQ-06-05: Auto-Apply Job Submission

| # | Criterion | Test Type |
|:---|:---|:---|
| AC-1 | Auto-apply toggle is disabled by default; requires explicit opt-in | Unit |
| AC-2 | Enabling auto-apply checks Premium subscription; shows upgrade prompt if not Premium | Unit |
| AC-3 | After autofill, shows 5-second countdown before submit; user can cancel | Manual |
| AC-4 | Successful submission saves application with status "auto-applied" | Unit |
| AC-5 | Daily limit (50 default) pauses auto-apply and notifies user when reached | Unit |
| AC-6 | Submit button detection avoids "save draft" / "cancel" patterns | Unit |
| AC-7 | If submit button not found, logs as draft and notifies user | Unit |
| AC-8 | Auto-apply mode does not persist across browser restarts (session-only) | Unit |

### REQ-06-06: Landing Page & SEO Foundation

| # | Criterion | Test Type |
|:---|:---|:---|
| AC-1 | Unauthenticated user visiting `/` sees landing page (not login redirect) | Unit + Manual |
| AC-2 | Authenticated user visiting `/` is redirected to `/dashboard` | Unit |
| AC-3 | Landing page Lighthouse performance score ≥ 90 | Manual |
| AC-4 | All public pages have proper meta tags, Open Graph, and JSON-LD | Unit |
| AC-5 | `/examples` displays 6 industry-specific resume examples | Unit |
| AC-6 | `robots.txt` and `sitemap.xml` are generated | Manual |
| AC-7 | No new UI libraries introduced; uses existing shadcn/ui + Tailwind | Code review |

---

## 9. Database Schema Changes

### 9.1 New Table: `interview_sessions`

```sql
CREATE TABLE interview_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clerk_user_id TEXT NOT NULL,
  job_title TEXT NOT NULL,
  company_name TEXT NOT NULL,
  job_description_text TEXT,
  questions JSONB NOT NULL DEFAULT '[]',
  answers JSONB NOT NULL DEFAULT '{}',
  feedback JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE interview_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY interview_sessions_select ON interview_sessions
  FOR SELECT USING (clerk_user_id = current_clerk_user_id());

CREATE POLICY interview_sessions_insert ON interview_sessions
  FOR INSERT WITH CHECK (clerk_user_id = current_clerk_user_id());

CREATE POLICY interview_sessions_update ON interview_sessions
  FOR UPDATE USING (clerk_user_id = current_clerk_user_id());

-- Trigger
CREATE TRIGGER set_interview_sessions_updated_at
  BEFORE UPDATE ON interview_sessions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Index
CREATE INDEX idx_interview_sessions_clerk_user_id ON interview_sessions (clerk_user_id);
```

### 9.2 Application Status Enum Extension

Add `auto-applied` to the existing `application_status` enum:

```sql
ALTER TYPE application_status ADD VALUE IF NOT EXISTS 'auto-applied';
```

---

## 10. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|:---|:---|:---|:---|
| Auto-apply triggers anti-bot detection | High | Medium | Randomized delays, human-like interaction patterns, user-configurable limits |
| Interview question quality too generic | Medium | Medium | Include full JD + profile + job title for context; post-launch user feedback loop |
| LLM cost increase from interview feature | Medium | Medium | Premium-only gating limits user base; session-level rate limit (10/day) |
| Landing page delays core feature work | Low | Low | SSG pages are simple; no dynamic data fetching required |
| Auto-apply submits wrong form | Medium | High | Require 80% field fill success; countdown cancel; never auto-retry failed submissions |
| SEO content perceived as thin | Medium | Low | Start with 6 quality examples; expand content in P06C |
