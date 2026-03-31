---
title: TRD - Resume-Flow AI
description: Technical requirements, architecture, interfaces, and engineering decisions for Smart Apply.
hero_eyebrow: Technical requirements
hero_title: TRD for Resume-Flow AI
hero_summary: The implementation-facing technical requirements document for Smart Apply's backend, extension, AI pipeline, and platform operations.
permalink: /trd/
---

# 📘 [TRD] Resume-Flow AI: Technical Requirements Document

**Version:** 1.0  
**Based on:** PRD v2.1  
**Status:** Draft for Engineering Kickoff  
**Document Goal:** Translate the PRD into implementation-ready technical requirements, system design, data flows, API contracts, security policy, and deployment strategy.

---

## 1. Document Purpose

This document is based on the **Resume-Flow AI** PRD and defines the following so the engineering team can move directly into design and development:

- Component-level responsibilities
- Technical architecture and data flow
- Database schema and authentication/authorization model
- Chrome Extension structure
- Backend API interfaces
- AI processing pipeline and prompt input/output contracts
- Security, performance, and operational requirements
- MVP priorities and development phases

---

## 2. Technical Goals

### 2.1 Core Technical Goals
1. **Job description-driven resume optimization**
2. **ATS match score calculation and improvement visualization**
3. **In-browser PDF generation**
4. **Google Drive upload**
5. **Job application form autofill**
6. **Minimal user data retention with strong security guarantees**

### 2.2 Technical Principles
- **Client-first processing**: scraping, PDF rendering, and form filling should happen in the extension/client whenever possible
- **Server-side intelligence**: AI reasoning, score calculation, and orchestration should live in the backend
- **Zero resume file storage**: generated PDF binaries must never be stored permanently on the server
- **Explicit user approval**: AI edits and final submission must always require user approval
- **Modular architecture**: separate the Chrome Extension, Web Portal, API, AI engine, and storage layers

---

## 3. System Overview

### 3.1 High-Level Architecture

```text
[Chrome Extension]
  ├─ Content Script
  ├─ Background Service Worker
  ├─ Popup UI / Side Panel UI
  └─ Local State Cache
          │
          ▼
[Backend API - NestJS]
  ├─ Auth Verification
  ├─ JD Parser
  ├─ ATS Scoring Engine
  ├─ Resume Optimization Orchestrator
  └─ Audit / Metadata Writer
          │
          ├────────► [LLM Provider]
          │
          ├────────► [Supabase Postgres]
          │
          └────────► [Google Drive API]

[Web Portal - Next.js]
  ├─ Dashboard
  ├─ Application History
  ├─ Master Profile Editor
  └─ Settings / Consent / Integrations
```

---

## 4. Component Technical Requirements

### 4.1 Chrome Extension

#### Responsibilities
- Read the DOM of LinkedIn and job description pages
- Extract the user's profile and experience text
- Extract job description text
- Display ATS results and change diffs
- Generate the final PDF in the browser
- Autofill job board forms
- Provide clipboard fallback when needed

#### Recommended Structure
```text
extension/
  ├─ manifest.json
  ├─ background/
  │   └─ service-worker.ts
  ├─ content/
  │   ├─ linkedin-profile.ts
  │   ├─ jd-detector.ts
  │   ├─ autofill.ts
  │   └─ dom-utils.ts
  ├─ ui/
  │   ├─ popup/
  │   ├─ sidepanel/
  │   └─ shared/
  ├─ lib/
  │   ├─ api-client.ts
  │   ├─ pdf-generator.ts
  │   ├─ auth.ts
  │   ├─ storage.ts
  │   └─ message-bus.ts
  └─ types/
```

#### Tech Stack
- React
- Tailwind CSS
- TypeScript
- Chrome Extension Manifest V3
- pdf-lib
- Clerk session integration
- Chrome storage API

#### Required Features
- Detect LinkedIn profile pages
- Detect job description pages, starting with LinkedIn and Indeed
- Support content script, background, and popup/sidepanel communication
- Confirm login state and inject tokens
- Show a final JSON-based resume preview
- Provide a user approval checklist
- Trigger Drive upload
- Autofill application forms

#### Non-Functional Requirements
- Content scripts must minimize page performance impact
- The extension must degrade gracefully when DOM selectors fail
- Use a selector registry/versioning model to handle site layout changes

---

### 4.2 Backend API (NestJS)

#### Responsibilities
- Verify Clerk JWTs
- Load and save user master profiles
- Parse job descriptions
- Calculate ATS scores
- Orchestrate LLM calls
- Produce optimized resume JSON
- Save `application_history` metadata

#### Example Module Structure
```text
backend/
  ├─ modules/
  │   ├─ auth/
  │   ├─ profiles/
  │   ├─ jobs/
  │   ├─ optimize/
  │   ├─ scoring/
  │   ├─ applications/
  │   └─ integrations/
  ├─ common/
  │   ├─ guards/
  │   ├─ interceptors/
  │   ├─ dto/
  │   └─ utils/
  └─ infra/
      ├─ llm/
      ├─ supabase/
      └─ google/
```

#### Requirements
- All APIs require authentication except public health endpoints
- Request and response schema validation is mandatory
- Account for timeouts, retries, and idempotency
- Use structured logging
- Validate AI responses against a strict JSON schema

---

### 4.3 Web Portal (Next.js)

#### Responsibilities
- Application history dashboard
- Master profile editing UI
- Connected Google Drive and consent status
- Resume generation history metadata
- Status updates such as `applied`, `interviewing`, and `rejected`

#### Requirements
- SSR/CSR authentication flow integrated with Clerk
- Supabase RLS-backed data access
- Read-heavy MVP, with editing focused on master profile and status updates
- Desktop-first initially, with mobile responsiveness as a later priority

---

### 4.4 Supabase (Postgres)

#### Responsibilities
- Store master profiles
- Store application metadata
- Retain only minimal operational data
- Enforce row-level access through RLS

#### Requirements
- Use `clerk_user_id` as the ownership key
- Never store resume PDFs directly
- Minimize sensitive data even in audit/log-style records
- Prefer hard delete over soft delete when aligning with privacy policy

---

## 5. Authentication and Authorization Design

### 5.1 Authentication Model
- Use **Clerk** as the single authentication provider
- Both the extension and web portal use Clerk sessions
- The backend API receives Bearer JWTs and validates them using Clerk issuer/public keys
- Supabase access can use Clerk JWTs directly or backend service-role mediated access

### 5.2 Authorization Model
- Users can only access their own profile and application rows
- Backend admin/service roles are only used for internal server operations
- Request only the `drive.file` Google Drive scope
- Full-drive listing access must be prohibited

### 5.3 Recommended Authentication Flow
1. User logs in via Clerk
2. Extension obtains session token
3. Extension sends token to backend
4. Backend verifies token and extracts `clerk_user_id`
5. Backend accesses DB with user context or service role + explicit ownership checks

---

## 6. Data Model

### 6.1 master_profiles

```sql
create table master_profiles (
  id uuid primary key default gen_random_uuid(),
  clerk_user_id text not null unique,
  full_name text,
  email text,
  phone text,
  location text,
  linkedin_url text,
  summary text,
  base_skills jsonb not null default '[]'::jsonb,
  certifications jsonb not null default '[]'::jsonb,
  experiences jsonb not null default '[]'::jsonb,
  education jsonb not null default '[]'::jsonb,
  raw_profile_source text,
  profile_version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

#### Example `experiences` JSON
```json
[
  {
    "company": "CIBC",
    "role": "Backend Developer",
    "start_date": "2024-10",
    "end_date": null,
    "description": [
      "Built backend services using Node.js and SQL",
      "Worked on capital markets internal systems"
    ]
  }
]
```

---

### 6.2 application_history

```sql
create table application_history (
  id uuid primary key default gen_random_uuid(),
  clerk_user_id text not null,
  company_name text not null,
  job_title text not null,
  source_platform text,
  source_url text,
  job_description_hash text,
  drive_link text,
  ats_score_before integer,
  ats_score_after integer,
  applied_resume_snapshot jsonb,
  status text not null default 'applied',
  created_at timestamptz not null default now(),
  applied_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

#### Candidate status enum values
- `draft`
- `generated`
- `applied`
- `interviewing`
- `offer`
- `rejected`
- `withdrawn`

---

### 6.3 user_integrations

```sql
create table user_integrations (
  id uuid primary key default gen_random_uuid(),
  clerk_user_id text not null,
  provider text not null,
  provider_account_email text,
  access_scope text,
  refresh_token_encrypted text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (clerk_user_id, provider)
);
```

> Refresh token storage should be revisited based on the final security policy. For the MVP, if extension-side uploads are preferred, server-side token storage can be omitted.

---

## 7. RLS Policy

### Example Policy Setup
```sql
alter table master_profiles enable row level security;
alter table application_history enable row level security;
alter table user_integrations enable row level security;
```

### Policy Concept
- Validate row ownership based on `auth.jwt()->>'sub'` or the mapped Clerk user ID claim
- Every `SELECT`, `INSERT`, `UPDATE`, and `DELETE` requires `clerk_user_id = current_user_id`

### Example
```sql
create policy "users_can_read_own_profile"
on master_profiles
for select
using (clerk_user_id = auth.jwt()->>'sub');
```

> The exact claim path should be adjusted during implementation to match the final Clerk and Supabase integration method.

---

## 8. Core Data Flows

### 8.1 Profile Ingestion Flow
1. User visits LinkedIn profile page
2. Content script extracts visible profile text
3. Extracted text is sanitized client-side
4. Extension sends raw profile payload to backend
5. Backend normalizes profile with parser/LLM
6. Structured master profile saved to Supabase
7. Extension shows sync result

### 8.2 Resume Optimization Flow
1. User opens JD page
2. Content script extracts JD text + company/job title
3. Extension requests optimization
4. Backend loads master profile
5. Backend extracts keywords/requirements from JD
6. Backend computes ATS score before
7. Backend requests LLM for minimal keyword injection suggestions
8. Backend validates response schema
9. Backend computes ATS score after
10. Response returned to extension
11. User reviews additions/removals
12. User approves
13. Extension generates PDF
14. Drive upload executed
15. Metadata saved in application_history

### 8.3 Autofill Flow
1. User opens apply form
2. Content script detects supported inputs
3. Extension maps profile fields to input fields
4. User clicks Auto-fill
5. Inputs populated
6. Unsupported fields exposed via copy buttons
7. Final submit remains manual

---

## 9. API Specification (MVP)

### 9.1 POST /api/profile/ingest
Convert raw profile text extracted from LinkedIn or another source into a structured master profile

#### Request
```json
{
  "source": "linkedin",
  "raw_text": "Full raw profile text",
  "source_url": "https://linkedin.com/in/...",
  "overwrite": true
}
```

#### Response
```json
{
  "success": true,
  "profile": {
    "full_name": "John Doe",
    "base_skills": ["Node.js", "SQL", "TypeScript"],
    "experiences": []
  }
}
```

---

### 9.2 GET /api/profile/me
Fetch the current user's master profile

#### Response
```json
{
  "id": "uuid",
  "clerk_user_id": "user_xxx",
  "full_name": "John Doe",
  "base_skills": ["Node.js", "SQL"]
}
```

---

### 9.3 POST /api/optimize
Generate an optimized resume draft from the job description and master profile

#### Request
```json
{
  "job_description_text": "We are hiring a backend engineer...",
  "job_title": "Backend Engineer",
  "company_name": "Acme",
  "source_platform": "linkedin",
  "source_url": "https://linkedin.com/jobs/..."
}
```

#### Response
```json
{
  "ats_score_before": 48,
  "ats_score_after": 86,
  "extracted_requirements": {
    "hard_skills": ["Node.js", "SQL", "AWS"],
    "soft_skills": ["communication"],
    "certifications": []
  },
  "suggested_changes": [
    {
      "type": "bullet_injection",
      "target_section": "experience",
      "reason": "AWS keyword missing from resume",
      "before": "Built backend APIs for internal systems",
      "after": "Built backend APIs for internal systems with AWS-integrated deployment workflows"
    }
  ],
  "optimized_resume_json": {
    "summary": "...",
    "skills": [],
    "experiences": []
  }
}
```

---

### 9.4 POST /api/applications
Store metadata for a completed generated result

#### Request
```json
{
  "company_name": "Acme",
  "job_title": "Backend Engineer",
  "source_platform": "linkedin",
  "source_url": "https://linkedin.com/jobs/...",
  "drive_link": "https://drive.google.com/...",
  "ats_score_before": 48,
  "ats_score_after": 86,
  "status": "generated",
  "applied_resume_snapshot": {
    "summary": "...",
    "skills": []
  }
}
```

#### Response
```json
{
  "success": true,
  "application_id": "uuid"
}
```

---

### 9.5 PATCH /api/applications/:id/status
Update application status

#### Request
```json
{
  "status": "interviewing"
}
```

---

## 10. AI Orchestration Design

### 10.1 AI Inputs
- Master Profile (structured JSON)
- Raw JD text
- Extracted requirements
- Optimization policy constraints

### 10.2 AI Output Requirements
The LLM must return JSON that matches the following structure exactly.

```json
{
  "summary": "string",
  "skills": ["string"],
  "experience_edits": [
    {
      "company": "string",
      "original_bullet": "string",
      "revised_bullet": "string",
      "inserted_keywords": ["string"],
      "confidence": 0.91
    }
  ],
  "warnings": ["string"]
}
```

### 10.3 AI Constraints
- Do not fabricate experience
- Do not invent certifications the user does not have
- Do not make technical claims beyond the user's experience range
- Prefer minimal edits over rewrites
- Return low-confidence inferences in `warnings`
- Items below a confidence threshold may be unchecked by default in the UI

### 10.4 AI Prompt Policy
- Enforce “Do not fabricate experience” in the system prompt
- “Only infer adjacent skills with explicit caution”
- “Prefer insertion into existing bullets instead of generating new sections”
- Strictly validate the output schema

---

## 11. ATS Scoring Engine Design

### 11.1 Goal
Quantify resume relevance against a job description and show before/after improvement to the user.

### 11.2 Inputs
- extracted requirements
- original profile / optimized profile

### 11.3 Candidate Scoring Logic
On a 100-point scale:
- Hard skills match: 50
- Role/domain relevance: 20
- Seniority alignment: 10
- Soft skills/certifications: 10
- Keyword coverage density: 10

### 11.4 Example Calculation Rules
- Prioritize exact keyword matches
- Support synonym maps such as `Node` ↔ `Node.js` and `Postgres` ↔ `PostgreSQL`
- Cap repeated keyword spam
- Score both the full job description text and the full resume text using section-aware weighting

### 11.5 Notes
- The UI must clearly state that the score is an internal heuristic, not a guarantee of ATS passage
- Avoid misleading marketing claims

---

## 12. PDF Generation Design

### 12.1 Execution Location
- For the MVP, perform PDF generation **client-side in the Chrome Extension**

### 12.2 Inputs
- optimized resume JSON
- selected template id
- typography/layout config

### 12.3 Requirements
- Prioritize an ATS-friendly single-column template
- Generate text-selectable PDFs
- Minimize icons and images
- Remove unnecessary styling
- Handle page overflow
- Default to US Letter, with A4 as a future option

### 12.4 Implementation Details
- Use `pdf-lib` to position text coordinates
- Add a shared template abstraction
- Add a vertical spacing calculator per section
- Prefer page continuation over aggressive font-size reduction when overflow occurs

---

## 13. Google Drive Integration

### 13.1 Scope
- Upload generated PDFs into the `Resume-Flow/{Company_Name}/` folder structure
- Store files only in the user's own Drive

### 13.2 Recommended Approach
#### MVP Recommendation
- Acquire a Google OAuth access token in the extension and upload directly
- Store only the Drive link on the server
- Do not proxy PDF binaries through the server

#### Alternative
- Backend signed upload orchestration
- This increases token storage and transfer complexity

### 13.3 Example File Naming Convention
```text
Resume-Flow/Acme/John_Doe_Backend_Engineer_2026-03-26.pdf
```

---

## 14. Form Autofill Design

### 14.1 Target Platforms (Priority Order)
1. LinkedIn Easy Apply
2. Workday
3. Greenhouse
4. Lever

### 14.2 Example Input Mapping
- full_name → name
- email → email
- phone → phone
- location → city/state
- summary → professional summary
- experiences → work history fields
- skills → free text skill input

### 14.3 Implementation Strategy
- Combine a DOM selector dictionary with heuristic matching
- Analyze `label`, `name`, `placeholder`, and `aria-label`
- For React-controlled inputs, use native setters plus `input`/`change` event dispatch
- Use dedicated adapters for `textarea` and rich-text editors

### 14.4 Failure Handling
- If field-mapping confidence is low, require preview and manual apply
- Provide copy-to-clipboard fallback
- Never auto-click the submit button

---

## 15. Security Requirements

### 15.1 Sensitive Data Handling
- Never store resume PDFs on the server
- Keep raw job descriptions only in memory or temporary logs for the minimum required period
- Encrypt access tokens and refresh tokens if stored, or avoid storing them entirely
- Do not log PII

### 15.2 XSS / Injection Defense
- Sanitize text extracted from LinkedIn DOM content
- Apply backend validation and escaping
- Normalize data before storing it in the database
- Never use unsafe HTML rendering for UI diff output

### 15.3 Secret Management
- Clerk secrets, Supabase service roles, and LLM API keys must exist only in server environments
- Never bundle secrets into the extension
- Use Google tokens only within the client session context

### 15.4 Account Deletion
- Clerk webhook → backend delete handler → Supabase hard delete
- Delete application history, profile, and integration rows
- Leave Drive files in place because they remain user-owned assets

---

## 16. Performance Requirements

### 16.1 Target SLA
- Click Optimize → show results: **within 5 to 10 seconds**
- PDF generation: **within 2 seconds**
- Autofill: **perceived response within 1 second**

### 16.2 Optimization Levers
- Minimize LLM prompt size
- Compute extracted requirements with rules first to reduce LLM calls
- Prefer resume JSON diff-based review responses
- Cache hashable JD parsing results temporarily
- Run requirements extraction and profile loading in parallel

---

## 17. Observability and Operations Requirements

### 17.1 Logging
- Request ID-based tracing
- Optimize request latency
- LLM error type and schema validation failure counts
- Drive upload success/failure
- Autofill success rates by platform

### 17.2 Metrics
- optimize success rate
- average ATS improvement
- approval rate of AI suggestions
- JD parse failure rate
- form autofill field coverage rate

### 17.3 Error Handling
- LLM timeout → retry once, then use graceful fallback
- Invalid schema → return a safe error
- Drive upload failure → optionally provide local download fallback
- Unsupported job board → switch to clipboard mode

---

## 18. Test Strategy

### 18.1 Unit Tests
- ATS scoring rules
- JD parser
- schema validation
- autofill field mapping
- PDF layout utility

### 18.2 Integration Tests
- Clerk auth → backend guard
- optimize pipeline
- Supabase write/read
- Drive upload mock flow

### 18.3 E2E Tests
- LinkedIn profile sync
- JD optimize → approve → PDF generate
- application history save
- LinkedIn Easy Apply autofill

### 18.4 Manual QA Focus Areas
- DOM selector robustness
- page layout overflow
- rich text inputs
- unsupported custom forms

---

## 19. Deployment Architecture

### 19.1 Web Portal
- Deploy on Vercel

### 19.2 Backend API
- Can be hosted on Render, Railway, Fly.io, or AWS Lambda
- MVP can use either a NestJS server or a serverless hybrid

### 19.3 DB
- Supabase hosted Postgres

### 19.4 Extension
- Chrome Web Store private or unlisted testing → public release

---

## 20. Example Environment Variables

```env
CLERK_SECRET_KEY=
CLERK_PUBLISHABLE_KEY=
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
LLM_API_KEY=
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GOOGLE_REDIRECT_URI=
```

> Only publishable/public keys may be included in the extension. Secrets must remain server-side.

---

## 21. MVP Scope Definition

### In Scope
- LinkedIn profile ingestion
- LinkedIn/Indeed JD optimize
- ATS score before/after
- user approval UI
- client-side PDF generation
- Google Drive upload
- application history dashboard
- LinkedIn Easy Apply basic autofill

### Out of Scope (MVP)
- Full auto apply / auto submit
- Multi-template design marketplace
- Cover letter full generation workflow
- overnight batch generation
- multi-language resume
- interview coach

---

## 22. Key Technical Risks and Mitigations

### 22.1 LinkedIn DOM Changes
- Selector registry abstraction
- Support emergency patch releases
- Parser fallback

### 22.2 LLM Hallucination
- strict prompt + schema validation
- minimal edit only
- user approval mandatory
- low-confidence suggestion default off

### 22.3 Google OAuth Complexity
- MVP should use direct extension upload
- Backend upload is a later priority

### 22.4 ATS Score Misinterpretation
- Clearly label the score as heuristic
- Do not use guarantee language

### 22.5 Chrome Extension Permission Sensitivity
- Request the minimum permissions necessary
- Limit host permissions to supported domains
- Make the privacy policy explicit

---

## 23. Recommended Development Order

### Phase 1
- Clerk auth
- Supabase schema + RLS
- Web Portal foundation
- Extension shell + auth bridge

### Phase 2
- LinkedIn profile parser
- profile ingest API
- Master profile save and retrieval

### Phase 3
- JD extractor
- optimize API
- ATS score engine
- AI response validation

### Phase 4
- review UI
- PDF generation
- Drive upload
- `application_history` persistence

### Phase 5
- autofill engine
- LinkedIn Easy Apply support
- fallback clipboard UX

### Phase 6
- observability
- QA hardening
- Chrome Store release prep

---

## 24. Recommended Directory Structure (Monorepo)

```text
resume-flow-ai/
  ├─ apps/
  │   ├─ web/
  │   ├─ api/
  │   └─ extension/
  ├─ packages/
  │   ├─ shared-types/
  │   ├─ ui/
  │   ├─ scoring-engine/
  │   ├─ prompt-contracts/
  │   └─ config/
  ├─ infra/
  │   ├─ supabase/
  │   └─ scripts/
  ├─ docs/
  │   ├─ PRD_Resume_Flow_AI.md
  │   └─ TRD_Resume_Flow_AI.md
  └─ package.json
```

---

## 25. Open Issues

1. Finalize whether Google Drive tokens should be stored on the server or handled only in the extension
2. Decide whether ATS scoring starts as pure rules only or includes embedding/similarity logic
3. Revisit how much of the optimized snapshot should be stored in `application_history`
4. Finalize whether multi-page PDFs are allowed and define the design standard
5. Design a shared field-mapping abstraction across Workday, Greenhouse, and Lever

---

## 26. Engineering Kickoff Conclusion

The Resume-Flow AI MVP is fully implementable with a **Chrome Extension + NestJS API + Supabase + Clerk + Google Drive** stack.  
The four most important implementation priorities are:

1. **Reliable LinkedIn and job-description DOM parsing**
2. **Minimal-edit optimization that prevents LLM hallucination**
3. **A trustworthy heuristic design for ATS scoring**
4. **A secure, client-first approach for PDF generation, Drive upload, and autofill**

From this TRD, the team can immediately produce the following next artifacts:

- API Swagger draft
- DB migration SQL
- Extension folder scaffold
- System prompt spec
- MVP task breakdown (epic / story / task)

---

## 27. Recommended Next Documents

Helpful documents to produce next:
- **API Spec (`openapi.yaml`)**
- **DB Schema SQL**
- **Chrome Extension Technical Design**
- **AI Prompt Spec**
- **MVP development task list**
