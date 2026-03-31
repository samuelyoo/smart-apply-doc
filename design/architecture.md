---
title: High-Level Architecture
description: System architecture, polyrepo boundaries, and data flow for Smart Apply.
version: 2.0
hero_eyebrow: System design
hero_title: Smart Apply architecture
hero_summary: A high-level view of the client, backend, shared package, and documentation surfaces that make up Smart Apply.
permalink: /architecture/
---

# Smart Apply — High-Level Architecture

> Based on **PRD v2.1** and **TRD v1.0**
> This document defines the system-level architecture, component responsibilities, and data flows.
> Business Requirements Document (BRD), Detailed HLD, and LLD will follow.

---

## 1. System Context

Smart Apply is a semi-automated AI assistant that helps job seekers tailor resumes for specific job descriptions, calculate ATS compatibility scores, generate PDF resumes, and auto-fill application forms — all while keeping the human in the loop.

### Core Principles
- **Client-first processing** — scraping, PDF rendering, and form fill happen in the browser
- **Server-side intelligence** — AI reasoning, scoring, and orchestration run on the backend
- **Zero resume file storage** — generated PDFs live in the user's Google Drive, never on our servers
- **Explicit user approval** — AI suggestions and final submission always require human confirmation

---

## 2. Repository Structure (Polyrepo)

```
smart-apply-shared/       Zod schemas + TypeScript types (npm package)
smart-apply-backend/      NestJS API — auth, scoring, LLM orchestration, webhooks
smart-apply-web/          Next.js web portal — dashboard, profile, optimize, settings
smart-apply-extension/    Chrome Extension (Manifest V3) — scraping, PDF, autofill
smart-apply-doc/          PRD, TRD, BRD, HLD, LLD, OpenAPI spec, architecture docs
supabase/                 Database migrations and Supabase local config
```

Each repo is independently buildable and deployable. `smart-apply-shared` is consumed via `file:` references in development and published as an npm package for CI/CD.

---

## 3. High-Level Architecture Diagram

```mermaid
graph TB
    subgraph Client["Browser (Chrome Extension)"]
        CS_LP["Content Script<br/>LinkedIn Profile Parser"]
        CS_JD["Content Script<br/>JD Detector"]
        CS_AF["Content Script<br/>Form Autofill"]
        BG["Background<br/>Service Worker"]
        POPUP["Popup / Side Panel UI"]
        PDF["PDF Generator<br/>(pdf-lib)"]
        CFG["Config Module"]
        GDRIVE_LIB["Google Drive<br/>Uploader"]
    end

    subgraph WebPortal["Web Portal (Next.js)"]
        DASH["Dashboard"]
        PROFILE["Profile Editor"]
        HISTORY["Application History"]
        OPT_PAGE["Optimize Page"]
        SETTINGS["Settings Page"]
        AUTH_CB["Auth Extension<br/>Callback"]
    end

    subgraph Backend["Backend API (NestJS)"]
        AUTH["Auth Guard<br/>(Clerk JWT)"]
        PROF_SVC["Profiles Service"]
        OPT_SVC["Optimize Orchestrator"]
        SCORE["ATS Scoring Engine"]
        APP_SVC["Applications Service"]
        JD_PARSE["JD Parser /<br/>Requirements Extractor"]
        ACCT_SVC["Account Service"]
        WH_SVC["Webhooks Controller"]
    end

    subgraph External["External Services"]
        CLERK["Clerk<br/>Auth Provider"]
        SUPA["Supabase<br/>PostgreSQL + RLS"]
        LLM["LLM Provider<br/>(OpenAI / Anthropic)"]
        GDRIVE["Google Drive<br/>API"]
    end

    %% Extension → Backend
    CS_LP -->|raw profile text| BG
    CS_JD -->|JD text + metadata| BG
    BG -->|API calls| AUTH
    CFG -.->|runtime config| BG

    %% Auth flow
    CLERK -.->|JWT verification| AUTH
    CLERK -->|webhook events| WH_SVC
    POPUP -->|login / token| CLERK
    AUTH_CB -->|token relay| BG

    %% Backend internal
    AUTH --> PROF_SVC
    AUTH --> OPT_SVC
    AUTH --> APP_SVC
    AUTH --> ACCT_SVC
    OPT_SVC --> JD_PARSE
    OPT_SVC --> SCORE
    OPT_SVC --> LLM
    PROF_SVC --> SUPA
    APP_SVC --> SUPA
    OPT_SVC --> SUPA
    ACCT_SVC --> CLERK
    WH_SVC --> SUPA

    %% Web Portal → Backend
    DASH -->|fetch applications| AUTH
    PROFILE -->|read/update profile| AUTH
    HISTORY -->|status updates| AUTH
    OPT_PAGE -->|optimize request| AUTH
    SETTINGS -->|account management| AUTH

    %% Client-side outputs
    BG -->|optimized JSON| POPUP
    POPUP -->|approved resume| PDF
    PDF -->|upload PDF| GDRIVE_LIB
    GDRIVE_LIB -->|upload PDF| GDRIVE
    PDF -->|save metadata| BG
    BG -->|save application| AUTH

    %% Autofill
    BG -->|profile data| CS_AF
    CS_AF -->|fill form fields| CS_AF

    classDef client fill:#dbeafe,stroke:#2563eb,color:#1e3a5f
    classDef web fill:#dcfce7,stroke:#16a34a,color:#14532d
    classDef backend fill:#fef3c7,stroke:#d97706,color:#78350f
    classDef external fill:#f3e8ff,stroke:#9333ea,color:#581c87

    class CS_LP,CS_JD,CS_AF,BG,POPUP,PDF,CFG,GDRIVE_LIB client
    class DASH,PROFILE,HISTORY,OPT_PAGE,SETTINGS,AUTH_CB web
    class AUTH,PROF_SVC,OPT_SVC,SCORE,APP_SVC,JD_PARSE,ACCT_SVC,WH_SVC backend
    class CLERK,SUPA,LLM,GDRIVE external
```

---

## 4. Core Data Flow Diagrams

### 4.1 Profile Ingestion Flow

```mermaid
sequenceDiagram
    actor User
    participant Ext as Chrome Extension
    participant BG as Background Worker
    participant API as Backend API
    participant LLM as LLM Provider
    participant DB as Supabase

    User->>Ext: Visit LinkedIn profile page
    Ext->>Ext: Content script extracts DOM text
    Ext->>BG: SYNC_PROFILE message
    BG->>API: POST /api/profile/ingest<br/>{source, raw_text, source_url}
    API->>API: Validate & sanitize input
    API->>LLM: Parse raw text → structured profile
    LLM-->>API: {full_name, skills, experiences, ...}
    API->>DB: Upsert master_profiles
    DB-->>API: Profile saved
    API-->>BG: {success, profile}
    BG-->>Ext: Show sync result
    Ext-->>User: ✓ Profile synced
```

### 4.2 Resume Optimization Flow (Core Loop)

```mermaid
sequenceDiagram
    actor User
    participant Ext as Chrome Extension
    participant BG as Background Worker
    participant API as Backend API
    participant Score as ATS Scoring Engine
    participant LLM as LLM Provider
    participant DB as Supabase
    participant Drive as Google Drive

    User->>Ext: Browse job posting page
    Ext->>Ext: Content script detects JD
    Ext->>BG: OPTIMIZE_JD message<br/>{jd_text, company, job_title}
    BG->>API: POST /api/optimize

    rect rgb(255, 249, 219)
        Note over API,LLM: Backend Optimization Pipeline
        API->>DB: Load master_profiles
        DB-->>API: User profile
        API->>API: Extract JD requirements<br/>(hard_skills, soft_skills, certs)
        API->>Score: Calculate ATS score BEFORE
        Score-->>API: ats_score_before (e.g. 48)
        API->>LLM: Optimize resume<br/>{profile, requirements, constraints}
        LLM-->>API: {summary, skills, experience_edits, warnings}
        API->>API: Validate LLM response schema
        API->>Score: Calculate ATS score AFTER
        Score-->>API: ats_score_after (e.g. 86)
    end

    API-->>BG: OptimizeResponse
    BG-->>Ext: Show results in popup

    rect rgb(219, 234, 254)
        Note over User,Drive: User Review & Generation
        Ext-->>User: Display ATS: 48% → 86%<br/>+ diff of suggested changes
        User->>Ext: Review, toggle changes, Approve
        Ext->>Ext: pdf-lib renders PDF
        Ext->>Drive: Upload PDF to<br/>Resume-Flow/{company}/
        Drive-->>Ext: shareable link
    end

    Ext->>BG: Save application metadata
    BG->>API: POST /api/applications<br/>{company, job_title, drive_link, scores, snapshot}
    API->>DB: Insert application_history
    DB-->>API: application_id
    API-->>BG: {success}
```

### 4.3 Form Autofill Flow

```mermaid
sequenceDiagram
    actor User
    participant Ext as Chrome Extension
    participant AF as Autofill Content Script
    participant BG as Background Worker

    User->>Ext: Open job application form
    AF->>AF: Detect form inputs<br/>(label, name, placeholder, aria-label)
    AF->>AF: Inject "Auto-fill" button
    User->>AF: Click Auto-fill
    AF->>BG: Request profile + optimized data
    BG-->>AF: {name, email, phone, summary, skills, ...}
    AF->>AF: Map fields → inputs<br/>Native value setter + event dispatch
    AF-->>User: Form populated

    alt Unsupported fields detected
        AF-->>User: Show "Copy to Clipboard" buttons
    end

    Note over User: User reviews & submits manually
```

### 4.4 Web-Based Resume Optimization Flow

```mermaid
sequenceDiagram
    actor User
    participant Web as Web Portal
    participant API as Backend API
    participant Score as ATS Scoring Engine
    participant LLM as LLM Provider
    participant DB as Supabase

    User->>Web: Navigate to /optimize
    Web->>Web: Render OptimizeForm
    User->>Web: Enter company, job title, paste JD
    Web->>API: POST /api/optimize<br/>{jd_text, company, job_title}

    rect rgb(255, 249, 219)
        Note over API,LLM: Same Backend Pipeline as Extension
        API->>DB: Load master_profiles
        API->>LLM: Extract requirements + optimize
        API->>Score: ATS score before & after
    end

    API-->>Web: OptimizeResponse
    Web->>Web: Display before/after scores,<br/>suggested changes with confidence badges
    User->>Web: Review and download PDF
```

### 4.5 Account Deletion Flow (Webhook Cascade)

```mermaid
sequenceDiagram
    actor User
    participant Web as Web Portal / Settings
    participant API as Backend API
    participant Clerk as Clerk
    participant WH as Webhooks Controller
    participant DB as Supabase

    User->>Web: Click "Delete Account"<br/>(type DELETE to confirm)
    Web->>API: DELETE /api/account
    API->>Clerk: Delete user via Clerk Admin API
    Clerk-->>API: User deleted
    API-->>Web: {success}

    Note over Clerk,WH: Asynchronous webhook
    Clerk->>WH: POST /api/webhooks/clerk<br/>(user.deleted event)
    WH->>WH: Verify Svix signature
    WH->>DB: Delete master_profiles<br/>(cascades to application_history,<br/>user_integrations)
    DB-->>WH: Rows deleted
```

---

## 5. Authentication & Authorization Flow

```mermaid
flowchart LR
    subgraph Clients
        EXT[Chrome Extension]
        WEB[Web Portal]
    end

    subgraph Auth
        CLERK[Clerk]
    end

    subgraph Backend
        GUARD[Auth Guard]
        API[API Routes]
    end

    subgraph Data
        SUPA[Supabase + RLS]
    end

    EXT -->|1. Login| CLERK
    WEB -->|1. Login| CLERK
    CLERK -->|2. JWT issued| EXT
    CLERK -->|2. JWT issued| WEB
    EXT -->|3. Bearer JWT| GUARD
    WEB -->|3. Bearer JWT| GUARD
    GUARD -->|4. verify token| CLERK
    GUARD -->|5. Extract clerk_user_id| API
    API -->|6. Query with user context| SUPA
```

**Key Rules:**
- Extension stores token in `chrome.storage.local`
- Web portal uses Clerk's built-in Next.js middleware
- Extension auth bridge: web portal hosts `/auth/extension-callback` that relays Clerk tokens to the extension via `chrome.runtime.sendMessage`
- Backend verifies JWT using `@clerk/backend` `verifyToken()`
- Clerk webhooks (user.deleted) are received by the backend Webhooks Controller with Svix signature verification
- Supabase enforces row-level security: `clerk_user_id = auth.jwt()->>'sub'`
- Google Drive scope limited to `drive.file` (only files created by app)

---

## 6. Data Model Overview

```mermaid
erDiagram
    master_profiles {
        uuid id PK
        text clerk_user_id UK
        text full_name
        text email
        text phone
        text location
        text linkedin_url
        text summary
        jsonb base_skills
        jsonb certifications
        jsonb experiences
        jsonb education
        text raw_profile_source
        int profile_version
        timestamptz created_at
        timestamptz updated_at
    }

    application_history {
        uuid id PK
        text clerk_user_id FK
        text company_name
        text job_title
        text source_platform
        text source_url
        text job_description_hash
        text drive_link
        int ats_score_before
        int ats_score_after
        jsonb applied_resume_snapshot
        text status
        timestamptz created_at
        timestamptz applied_at
        timestamptz updated_at
    }

    user_integrations {
        uuid id PK
        text clerk_user_id FK
        text provider
        text provider_account_email
        text access_scope
        text refresh_token_encrypted
        timestamptz created_at
        timestamptz updated_at
    }

    master_profiles ||--o{ application_history : "clerk_user_id"
    master_profiles ||--o{ user_integrations : "clerk_user_id"
```

**Status Lifecycle:** `draft` → `generated` → `applied` → `interviewing` → `offer` / `rejected` / `withdrawn`

**Schema Management:** Database schema is migration-managed via `supabase/migrations/`. RLS policies are active on all tables, scoping data to the authenticated `clerk_user_id` via a `current_clerk_user_id()` SQL function. Cascading deletes are configured: deleting a `master_profiles` row cascades to `application_history` and `user_integrations`.

---

## 7. Component Responsibilities

| Component | Responsibility | Tech Stack |
|:---|:---|:---|
| **smart-apply-extension** | DOM scraping (LinkedIn/Indeed), JD detection, user review UI, PDF rendering (pdf-lib), form autofill, Google Drive upload, runtime config | React, Tailwind, Manifest V3, Vite, pdf-lib |
| **smart-apply-backend** | Auth verification, profile CRUD, JD parsing, ATS scoring, LLM orchestration, application metadata, Clerk webhook handling, account deletion | NestJS 11, Clerk, Supabase, OpenAI, Zod, Vitest |
| **smart-apply-web** | Dashboard, application history, profile editor/upload, optimize page, settings, auth extension callback | Next.js 15, React 19, Clerk, TanStack Query, shadcn/ui, pdfjs-dist |
| **smart-apply-shared** | Shared types, Zod schemas, enums | TypeScript, Zod |
| **smart-apply-doc** | PRD, TRD, BRD, HLD, LLD, OpenAPI, architecture | Markdown |
| **supabase/** | Database migrations, RLS policies, local dev config | Supabase CLI |

---

## 8. Deployment Architecture

```mermaid
graph TB
    subgraph Production
        VERCEL["Vercel<br/>(smart-apply-web)"]
        RENDER["Render / Railway<br/>(smart-apply-backend)"]
        SUPA_CLOUD["Supabase Cloud<br/>(PostgreSQL + RLS)"]
        CWS["Chrome Web Store<br/>(smart-apply-extension)"]
    end

    subgraph CI["CI / CD"]
        GHA["GitHub Actions<br/>(lint, typecheck, test, build)"]
    end

    subgraph External
        CLERK_CLOUD["Clerk Cloud"]
        LLM_API["LLM API<br/>(OpenAI)"]
        GDRIVE_API["Google Drive API"]
    end

    GHA -->|deploy| VERCEL
    GHA -->|build image| RENDER
    CWS -->|API calls| RENDER
    VERCEL -->|API calls| RENDER
    RENDER -->|DB queries| SUPA_CLOUD
    RENDER -->|JWT verify| CLERK_CLOUD
    CLERK_CLOUD -->|webhooks| RENDER
    RENDER -->|AI prompts| LLM_API
    CWS -->|PDF upload| GDRIVE_API
    CWS -->|Auth| CLERK_CLOUD

    classDef prod fill:#dbeafe,stroke:#2563eb
    classDef ext fill:#f3e8ff,stroke:#9333ea
    classDef ci fill:#dcfce7,stroke:#16a34a

    class VERCEL,RENDER,SUPA_CLOUD,CWS prod
    class CLERK_CLOUD,LLM_API,GDRIVE_API ext
    class GHA ci
```

**Deployment Artefacts:**
- **Backend:** Multi-stage Dockerfile (Node 20-alpine), port 3001
- **Web:** `vercel.json` with monorepo build config (`npm -w @smart-apply/web run build`)
- **CI:** GitHub Actions workflow (`ci.yml`) — TypeScript compile check for all 4 workspaces, backend Vitest suite, Next.js production build

---

## 9. ATS Scoring Engine (Heuristic)

```
Total: 100 points
├── Hard Skills Match:      50 pts (exact + synonym matching)
├── Role/Domain Relevance:  20 pts (job title ↔ experience titles)
├── Seniority Alignment:    10 pts (years/level match)
├── Soft Skills & Certs:    10 pts (keyword presence)
└── Keyword Coverage:       10 pts (density across resume sections)
```

Synonym map supports equivalences like `Node` ↔ `Node.js`, `Postgres` ↔ `PostgreSQL`. Keyword spam is capped. Score is labeled as an **internal heuristic**, not a guarantee of ATS passage.

**Section Weighting:** Resume sections contribute differently — skills carry full weight, experience sections are weighted at 80%, and summary at 60%. This prevents over-indexing on summary keyword stuffing.

---

## 10. AI Orchestration Pipeline

```mermaid
graph LR
    A["Master Profile<br/>(JSON)"] --> D["Prompt Builder"]
    B["Raw JD Text"] --> C["Requirements<br/>Extractor"]
    C --> D
    D --> E["LLM Call"]
    E --> F["Schema Validator"]
    F --> G["Optimized Resume<br/>JSON"]

    style D fill:#fef3c7,stroke:#d97706
    style E fill:#f3e8ff,stroke:#9333ea
    style F fill:#dcfce7,stroke:#16a34a
```

**Implementation:** Uses OpenAI GPT-4o via three methods:
- `extractRequirements()` — parses JD text into hard_skills, soft_skills, certifications
- `optimizeResume()` — generates resume edits with per-edit confidence scores (≥ 0.6 threshold)
- `parseProfileText()` — converts raw scraped/uploaded text into structured profile JSON

All outputs are validated with Zod schemas. Failed calls retry once before surfacing an error. Token usage is logged per call.

**LLM Constraints (from TRD §10.3):**
- No fabricated experience or certifications
- Minimal edit over full rewrite
- Infer adjacent skills only with explicit caution
- Low-confidence suggestions flagged in `warnings[]`
- Output validated against strict JSON schema

**LLM Output Contract:**
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

---

## 11. Security Architecture

| Layer | Measure |
|:---|:---|
| **Auth** | Clerk JWT — verified on every API request |
| **Webhook verification** | Clerk webhooks verified via Svix signature; rawBody enabled on backend for signature integrity |
| **Data isolation** | Supabase RLS — `clerk_user_id = auth.jwt()->>'sub'` |
| **Storage** | Zero resume file storage on server; PDFs in user's Drive only |
| **Secrets** | Server-only env vars; extension bundle contains no secrets |
| **CORS** | Backend allows only `localhost:3000` (web) and `chrome-extension://` origins |
| **Input sanitization** | DOM-extracted text sanitized before backend processing |
| **XSS prevention** | No unsafe HTML rendering in diff UI |
| **Account deletion** | Clerk webhook (`user.deleted`) → cascading hard delete in Supabase via admin client |
| **Google Drive** | `drive.file` scope only — cannot access user's other files |
| **PII** | No PII in logs; raw JD stored temporarily only |

---

## 12. Development Phases (from TRD §23)

| Phase | Scope | Status |
|:---|:---|:---|
| **Phase 1** | Clerk auth, Supabase schema + RLS, Web Portal shell, Extension shell + auth bridge | ✅ Done — Auth guard, RLS policies, Next.js/Extension shells, auth callback bridge all wired |
| **Phase 2** | LinkedIn profile parser, profile ingest API, master profile CRUD, web profile upload | ✅ Done — LinkedIn content script, profile service, LLM-powered text parsing, drag-drop upload |
| **Phase 3** | JD extractor, optimize API, ATS scoring engine, LLM response validation, web optimize page | ✅ Done — Full scoring engine with synonym matching, GPT-4o orchestration, web-based optimize form + results |
| **Phase 4** | Review UI, PDF generation, Google Drive upload, application_history | 🟡 In Progress — PDF generation (pdf-lib), Google Drive upload, and application save implemented; extension review UI expanded |
| **Phase 5** | Autofill engine, LinkedIn Easy Apply support, clipboard fallback | 🟡 In Progress — Autofill content script with field detection and native value setter implemented; clipboard fallback present |
| **Phase 6** | Observability, QA hardening, Chrome Web Store release | 🔴 Not Started |

---

## Next Documents

- ~~**BRD** — Business Requirements Document~~ → `BRD-MVP-01.md` ✅
- ~~**HLD** — Detailed High-Level Design per component~~ → `HLD-MVP-P01.md`, `HLD-MVP-P02.md`, `HLD-MVP-P03.md` ✅
- ~~**LLD** — Low-Level Design (class diagrams, API contracts, DB migrations)~~ → `LLD-MVP-P01.md`, `LLD-MVP-P02.md`, `LLD-MVP-P03.md` ✅
- **AI Prompt Spec** — System prompts, few-shot examples, guardrails
- **Deployment Runbook** — Environment setup, CI/CD, monitoring
