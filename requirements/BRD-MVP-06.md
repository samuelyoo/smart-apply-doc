---
title: BRD — MVP 06
description: Business Requirements Document for MVP Phase 6 — Post-Release Growth & Competitive Positioning, incorporating competitive analysis of AIApply.co and defining the next feature wave for Smart Apply.
hero_eyebrow: Business requirements
hero_title: BRD for MVP 06
hero_summary: Defines the post-release feature roadmap driven by competitive analysis (AIApply.co), user value gaps, and monetisation requirements to evolve Smart Apply from a functional MVP into a market-competitive product.
permalink: /brd-mvp-06/
---

# Business Requirements Document — MVP 06

**Version:** 1.0  
**Date:** 2026-03-31  
**Source:** Application review, competitive analysis (aiapply.co), BRD-MVP-01 through BRD-MVP-05  
**Author:** Business Analyst Agent  

---

## 1. Executive Summary

Smart Apply has reached release-gate readiness (BRD-MVP-05 / P7), with a functionally complete MVP across four packages: web portal, NestJS backend, Chrome extension, and shared type library. 281 tests pass, coverage targets are met, and core user journeys — profile import → AI optimization → ATS scoring → approved PDF generation → Google Drive upload → application tracking — work end to end on both web and extension surfaces.

This BRD addresses the **next horizon**: closing the feature and market-positioning gap between Smart Apply and established competitors. A detailed competitive analysis of **AIApply.co** (1,166,000+ users, Google Cloud partner, 4.7★ Trustpilot) reveals six product areas where Smart Apply must invest to achieve market parity and three areas where Smart Apply already holds a differentiation advantage.

### Smart Apply's Current Differentiators (Strengths to Preserve)
1. **Human-in-the-loop approval** — Users explicitly approve each AI suggestion before it enters the PDF. AIApply applies changes automatically with no granular control.
2. **Zero-storage privacy model** — Resumes are never stored server-side; PDFs exist only in the user's Google Drive. AIApply stores user data on their servers.
3. **ATS scoring transparency** — 5-dimension before/after scoring (hard skills, soft skills, keyword density, role relevance, seniority alignment). AIApply shows a single match percentage without breakdown.

### Competitive Gaps (Addressed in This BRD)
1. **AI Cover Letter Generation** — AIApply's top feature; Smart Apply has no cover letter support.
2. **AI Interview Preparation** — AIApply offers mock interviews and a real-time "Interview Buddy"; Smart Apply has nothing.
3. **Auto-Apply Automation** — AIApply's flagship differentiator (372,000+ roles applied to); Smart Apply only autofills forms but doesn't submit.
4. **Resume Templates & Builder** — AIApply has a visual resume builder with multiple templates; Smart Apply generates a single-format PDF.
5. **Monetisation & Pricing** — AIApply has tiered subscription plans (Free, Pro, Premium); Smart Apply has no payment model.
6. **Content Marketing & SEO** — AIApply has resume examples, cover letter examples, blog content, and a job board; Smart Apply has none.

---

## 2. Competitive Analysis — AIApply.co

### 2.1 Company Profile

| Attribute | AIApply.co |
|:---|:---|
| Users | 1,166,440+ |
| Rating | 4.7★ (387 ratings on Trustpilot) |
| Founded | ~2023 |
| Infrastructure | Google Cloud Partner, GPT-4 + Azure AI |
| Platforms | Web application (SaaS) |
| Global Reach | 50+ language support for resume translation |

### 2.2 Feature Comparison Matrix

| Feature | AIApply.co | Smart Apply (Current) | Gap |
|:---|:---|:---|:---|
| **AI Resume Optimization** | ✅ ATS-optimized per JD | ✅ ATS-optimized per JD with 5-dim scoring | **Smart Apply leads** — granular scoring & human approval |
| **Resume Builder / Templates** | ✅ Multiple visual templates, inline editing | ⚠️ Single PDF format (pdf-lib) | **Gap** — No template selection |
| **AI Cover Letter Generator** | ✅ Personalized per JD | ❌ Not available | **Critical Gap** |
| **Auto-Apply to Jobs** | ✅ Automated submission to 100s of jobs daily | ⚠️ Autofill only, no auto-submit | **Major Gap** |
| **Mock Interview Practice** | ✅ AI-simulated role-specific interviews | ❌ Not available | **Gap** |
| **Interview Buddy (Real-time)** | ✅ Live AI coaching during interviews | ❌ Not available | **Gap** |
| **Resume Translation** | ✅ 50+ languages | ❌ Not available | **Gap** |
| **LinkedIn Import** | ✅ LinkedIn to Resume converter | ✅ Chrome extension DOM scraping | **Parity** |
| **Application Tracking** | ✅ Basic — shows applied/pending status | ✅ Dashboard with pipeline view, stats, status updates | **Smart Apply leads** |
| **Google Drive Integration** | ❌ Not mentioned | ✅ Auto-upload to user's Drive | **Smart Apply leads** |
| **Chrome Extension** | ❌ Web-only SaaS | ✅ Full Chrome extension with in-page autofill | **Smart Apply leads** |
| **Privacy / Zero-Storage** | ❌ Stores user data server-side | ✅ Zero-storage; PDF in user's Drive only | **Smart Apply leads** |
| **Human-in-the-Loop** | ❌ AI applies changes automatically | ✅ User selects which changes to accept | **Smart Apply leads** |
| **Job Board** | ✅ Integrated job listings | ❌ Not available | **Gap** |
| **Blog / SEO Content** | ✅ Extensive (interview tips, resume guides) | ❌ Not available | **Gap** |
| **Free Tier** | ✅ Limited free features | ❌ No pricing model at all | **Gap** |
| **Subscription Plans** | ✅ Tiered pricing (Free/Pro/Premium) | ❌ No monetisation | **Critical Gap** |
| **White Label / Affiliate** | ✅ Partner and influencer programs | ❌ Not available | **Gap** (future) |
| **Student Discount** | ✅ Available | ❌ Not available | **Gap** (future) |

### 2.3 AIApply Strengths
- **Scale**: 1.16M+ users create strong social proof and network effects
- **Full lifecycle coverage**: Covers resume → apply → interview → get hired
- **Auto-Apply automation**: Key differentiator that saves users significant time (users report 100+ jobs applied in 48 hours)
- **Content marketing engine**: Blog, resume examples, cover letter examples drive organic traffic
- **Multi-language support**: 50+ language resume translation for global market

### 2.4 AIApply Weaknesses (Smart Apply Opportunities)
- **No transparency in AI changes**: Users can't see or approve individual modifications — "black box" output
- **No Chrome extension**: Web-only workflow requires constant tab switching
- **Data stored server-side**: Privacy-conscious users have no guarantee of data ownership
- **Generic templates**: Despite multiple designs, optimization is less granular than Smart Apply's 5-dimension scoring
- **No Google Drive integration**: Users must manually manage downloaded files

---

## 3. Stakeholder Goals

| Stakeholder | Goal | Success Metric |
|:---|:---|:---|
| Job Seeker (primary) | Get a complete job application package (resume + cover letter) optimized for each role | ≥80% of users who optimize a resume also generate a cover letter |
| Job Seeker (primary) | Practice and prepare for interviews with AI assistance | Interview prep feature used by ≥30% of active users |
| Job Seeker (primary) | Choose a resume design that fits their industry and preference | ≥3 template options available |
| Product Owner | Establish revenue stream through subscription model | Paid conversion rate ≥5% of registered users within 90 days |
| Product Owner | Achieve feature parity with top competitors in core areas | Cover letter + interview prep launched within 2 release cycles |
| Product Owner | Differentiate on privacy, transparency, and user control | Zero-storage and human-in-the-loop maintained across all new features |
| Engineering Team | Ship features incrementally without regression | 281+ tests maintained; coverage targets held across all new modules |
| Marketing | Drive organic user acquisition | Landing pages, resume examples, and blog content generating traffic |

---

## 4. Previous Phase Outcomes

### 4.1 All Phases Complete (BRD-MVP-01 through BRD-MVP-05)

| Phase | BRD | Status | Key Deliverables |
|:---|:---|:---|:---|
| P0 | BRD-MVP-01 | ✅ COMPLETE | Web build, auth bridge, message flow, approved changes, URL externalization |
| P1 | BRD-MVP-02 | ✅ COMPLETE | Drive upload, ATS scoring, migrations, webhooks, deployment config, tests |
| P2 | BRD-MVP-03 | ✅ COMPLETE | Extended autofill, web optimize, settings, profile upload, DOM hardening |
| P3–P4 | BRD-MVP-04 | ✅ COMPLETE | Dashboard enhancements (6 sections), autofill toggle, cross-domain injection |
| Test P1–P2 | BRD-TEST-P1/P2 | ✅ COMPLETE | 281 tests, coverage targets met (backend 93%, web 91%, extension 83%) |
| P7 | BRD-MVP-05 | ✅ COMPLETE | Snapshot fix, CI backend build, env docs, Render config, health checks, runbook |

### 4.2 Delivered Capabilities (Foundation)

| # | Capability | Status |
|:---|:---|:---|
| 1 | Auth across web (Clerk), backend (JWT guard), extension (auth bridge) | ✅ |
| 2 | Profile import: LinkedIn (extension) + PDF/text upload (web) | ✅ |
| 3 | LLM-powered optimization with 5-dimension ATS scoring (before/after) | ✅ |
| 4 | Selectable change approval + client-side PDF generation (pdf-lib) | ✅ |
| 5 | Application tracking with table + pipeline views, stats, status updates | ✅ |
| 6 | Dashboard: onboarding checklist, profile completeness, quick actions | ✅ |
| 7 | Cross-domain autofill injection with toggle and auto-activation | ✅ |
| 8 | Google Drive upload (extension, best-effort) | ✅ |
| 9 | Account deletion with Clerk webhook cascade | ✅ |
| 10 | 281 tests, CI pipeline, Docker deployment, release runbook | ✅ |

---

## 5. Functional Requirements

### 5.1 Must-Have (P0 — Next Release)

```
REQ-06-01
Title: AI Cover Letter Generation
Priority: P0
User Story: As a job seeker, I want to generate a tailored cover letter for each
  job I apply to, so that I have a complete application package (resume + cover
  letter) without manually writing each one.
Current State: MISSING — No cover letter generation exists. The optimize flow
  produces only a resume. AIApply.co lists AI Cover Letter as one of its top 3
  features.
Required State: After optimizing a resume against a job description, the user
  can generate a matching cover letter. The cover letter uses profile data, the
  job description, and the optimized resume context to produce a personalized
  letter. Users can edit the generated letter before downloading.
Acceptance Criteria:
  - Given a user has optimized their resume for a JD, when they click "Generate
    Cover Letter," then the system produces a personalized cover letter within
    10 seconds.
  - Given the cover letter is generated, then it references specific skills and
    experience from the user's profile that match the JD requirements.
  - Given the generated letter, when the user edits text inline, then the
    modified version is used for PDF download.
  - Given the user downloads the cover letter, then it is saved as a PDF with
    professional formatting.
  - Given the extension flow, when the cover letter is generated, then it is
    uploaded to Google Drive in the same folder as the corresponding resume.
  - Given the application record is saved, then it includes a reference to the
    cover letter (Drive link or inline snapshot).
Dependencies: Existing LLM service (extend with cover letter prompt template),
  existing PDF generation pipeline (extend for letter format)
Competitive Reference: AIApply.co AI Cover Letter Generator
```

```
REQ-06-02
Title: Subscription & Payment Model (Freemium)
Priority: P0
User Story: As a product owner, I want to offer a tiered subscription model so
  that the product generates revenue while maintaining a free tier for user
  acquisition.
Current State: MISSING — No payment model, no Stripe integration, no feature
  gating. All features are available to all authenticated users.
Required State: A 3-tier subscription model is implemented:
  - **Free**: 3 resume optimizations/month, 1 cover letter/month, ATS scoring,
    basic PDF template
  - **Pro** ($X/month): Unlimited optimizations, unlimited cover letters,
    all templates, Google Drive integration, priority LLM processing
  - **Premium** ($X/month): Everything in Pro + interview prep, auto-apply
    assistance, priority support
  Feature gating enforced at the API boundary. Stripe Checkout for payment.
  Clerk user metadata stores subscription tier.
Acceptance Criteria:
  - Given an unauthenticated user, when they sign up, then they are assigned
    the Free tier by default.
  - Given a Free-tier user has used 3 optimizations this month, when they
    attempt a 4th, then they see an upgrade prompt instead of the optimize flow.
  - Given a user clicks "Upgrade to Pro," then they are redirected to Stripe
    Checkout with the correct plan pre-selected.
  - Given Stripe sends a checkout.session.completed webhook, then the user's
    Clerk metadata is updated to "pro" and they immediately gain access to
    Pro features.
  - Given a user cancels their subscription, then they retain access until
    the end of the billing period, after which they revert to Free tier.
  - Given API endpoints, then each checks the user's tier and returns HTTP 403
    with a clear message if the feature is not available on their plan.
Dependencies: Stripe account setup, Clerk metadata configuration, webhook
  endpoint for Stripe events
Competitive Reference: AIApply.co tiered pricing model
```

```
REQ-06-03
Title: Resume Template Selection
Priority: P0
User Story: As a job seeker, I want to choose from multiple resume templates so
  that my resume design matches my industry and personal preference.
Current State: PARTIAL — PDF generation uses a single hardcoded layout in
  pdf-lib. No template selection UI exists.
Required State: Users can select from at least 3 professionally designed resume
  templates before generating their PDF. Templates vary in layout, typography,
  and visual style (e.g., "Classic," "Modern," "Minimal"). Template selection
  persists in user preferences.
Acceptance Criteria:
  - Given the optimize flow, when the user reaches the PDF generation step,
    then they see a template picker with at least 3 options and a live preview.
  - Given a selected template, when the PDF is generated, then the layout,
    fonts, and spacing match the template preview.
  - Given a user has selected a preferred template, when they return for a
    subsequent optimization, then their preference is pre-selected.
  - Given any template, then the PDF remains ATS-parseable (no images for text,
    correct reading order, standard fonts).
Dependencies: PDF generation library (evaluate pdf-lib extensions or
  @react-pdf/renderer for richer layouts)
Competitive Reference: AIApply.co multi-template resume builder
```

### 5.2 Should-Have (P1 — Follow-On Release)

```
REQ-06-04
Title: AI Interview Preparation
Priority: P1
User Story: As a job seeker, I want to practice answering interview questions
  specific to the role I'm applying for so that I feel confident and prepared.
Current State: MISSING — No interview preparation feature exists. AIApply.co
  offers both mock interviews and a real-time "Interview Buddy."
Required State: A web-based interview practice module where:
  - The system generates role-specific interview questions based on the JD and
    the user's profile/resume.
  - The user records or types their answers.
  - The AI provides feedback on answer quality, structure (STAR method), and
    areas for improvement.
  - Session history is available for review.
Acceptance Criteria:
  - Given a user has a saved JD, when they click "Practice Interview," then
    the system generates 5–10 role-specific questions within 5 seconds.
  - Given the user types an answer, when they submit it, then the AI provides
    structured feedback (strengths, improvements, suggested STAR structure)
    within 5 seconds.
  - Given a completed practice session, then the user can review all Q&A pairs
    and feedback in their dashboard.
  - Given the feedback, then it references specific elements from the user's
    profile and the JD to make it contextual.
Dependencies: LLM service extension, new web routes (/interview-prep), new
  backend module (interview)
Competitive Reference: AIApply.co AI Interview Practice + Interview Buddy
```

```
REQ-06-05
Title: Auto-Apply Job Submission
Priority: P1
User Story: As a job seeker, I want the extension to automatically submit job
  applications on my behalf so that I can apply to more positions without
  manual effort.
Current State: PARTIAL — The extension can autofill form fields but does not
  click submit. Users must manually review and submit each application.
  AIApply.co reports 372,000+ auto-applied roles.
Required State: The extension can optionally auto-submit applications after
  autofill, with safeguards:
  - User must explicitly enable auto-apply per session (opt-in, not default).
  - A confirmation dialog shows what will be submitted before the first auto-submit.
  - Each auto-applied job is logged in application history with "auto-applied" status.
  - User can set daily limits (e.g., max 50 applications/day).
  - A review queue shows pending auto-applies before submission.
Acceptance Criteria:
  - Given auto-apply is enabled, when the extension detects a filled application
    form, then it shows a 5-second countdown before submitting (user can cancel).
  - Given a successful submission, then the application record is saved with
    status "auto-applied" and includes the job title, company, and URL.
  - Given the daily limit is reached, then auto-apply pauses and notifies the user.
  - Given auto-apply is disabled (default), then the extension only autofills
    without submitting.
  - Given the review queue, then the user can approve or reject pending
    applications before bulk submission.
Dependencies: REQ-06-02 (Premium tier feature), autofill infrastructure
  (existing), application history API (existing)
Competitive Reference: AIApply.co Auto Apply (flagship feature)
```

```
REQ-06-06
Title: Landing Page & SEO Foundation
Priority: P1
User Story: As a product owner, I want a public-facing landing page with SEO-
  optimized content so that the product can acquire users through organic search.
Current State: MISSING — The web app only has authenticated dashboard pages.
  No public marketing pages, resume examples, or blog content exist.
  AIApply.co has extensive SEO content (resume examples, cover letter examples,
  interview guides, blog posts).
Required State: A public-facing section of the web app that includes:
  - Landing/home page with product value proposition, feature highlights,
    social proof, and CTA to sign up.
  - Resume examples page (at least 6 industry-specific examples).
  - Basic blog infrastructure for future SEO content.
  - Open Graph / meta tags for social sharing.
Acceptance Criteria:
  - Given an unauthenticated user visits the root URL, then they see the
    landing page (not a login redirect).
  - Given the landing page, then it loads in under 2 seconds (Lighthouse
    performance score ≥90).
  - Given search engine crawlers, then all public pages have proper meta tags,
    Open Graph tags, and structured data (JSON-LD).
  - Given the resume examples page, then it displays at least 6 examples
    categorized by industry with relevant keywords.
Dependencies: Next.js static/ISR pages (no auth required), content creation
Competitive Reference: AIApply.co resume examples, cover letter examples, blog
```

### 5.3 Nice-to-Have (P2 — Future Roadmap)

```
REQ-06-07
Title: Resume Translation (Multi-Language)
Priority: P2
User Story: As a job seeker applying internationally, I want to translate my
  resume into other languages so that I can apply to roles in non-English markets.
Current State: MISSING — All content is English-only.
Required State: Users can translate their optimized resume into at least 10
  major languages while preserving formatting and professional tone.
Acceptance Criteria:
  - Given an optimized resume, when the user selects "Translate" and picks a
    target language, then the system produces a translated version within
    15 seconds.
  - Given the translation, then professional terminology and formatting are
    preserved (no literal translations of industry terms).
  - Given the translated resume, then the user can download it as a PDF using
    any selected template.
Dependencies: LLM service extension with translation prompts, font support
  for non-Latin scripts in PDF generation
Competitive Reference: AIApply.co Resume Translator (50+ languages)
```

```
REQ-06-08
Title: Job Board Integration
Priority: P2
User Story: As a job seeker, I want to discover relevant job listings directly
  within Smart Apply so that I don't need to switch between platforms.
Current State: MISSING — Users must find job listings externally and paste the
  JD into Smart Apply.
Required State: An integrated job search feature that aggregates listings from
  public job APIs (e.g., LinkedIn, Indeed, Glassdoor public feeds) and allows
  users to optimize and apply directly from within Smart Apply.
Acceptance Criteria:
  - Given the user enters a job title and location, then the system returns
    relevant listings from at least 2 sources within 3 seconds.
  - Given a listing, when the user clicks "Optimize for this job," then the JD
    is auto-populated in the optimize flow.
  - Given the user applies through the integrated listing, then the application
    is tracked in their history.
Dependencies: Job listing API integrations, search infrastructure
Competitive Reference: AIApply.co Job Board
```

```
REQ-06-09
Title: Real-Time Interview Coaching (Interview Buddy)
Priority: P2
User Story: As a job seeker in a live interview, I want real-time AI-suggested
  answers so that I can respond more effectively to unexpected questions.
Current State: MISSING — No real-time interview assistance.
Required State: A browser-based tool that listens to interview audio (with user
  consent), transcribes questions, and provides suggested talking points in
  real-time via a discreet overlay or separate window.
Acceptance Criteria:
  - Given the user starts an interview session, then the tool begins
    transcribing audio input within 2 seconds.
  - Given a detected question, then the AI provides 2–3 bullet-point suggestions
    within 3 seconds.
  - Given the suggestions, then they incorporate the user's profile data and
    the specific JD for contextual relevance.
  - Given the session ends, then a summary of Q&A pairs and suggested answers
    is saved for review.
Dependencies: Web Speech API or equivalent, LLM streaming, significant UX
  design work
Competitive Reference: AIApply.co Interview Buddy (4.7★, 387 ratings)
Note: Ethical considerations — must clearly disclose AI assistance to
  interviewers if required by company policy. Feature should include a
  disclaimer.
```

```
REQ-06-10
Title: Analytics Dashboard for Job Search Insights
Priority: P2
User Story: As a job seeker, I want to see analytics about my job search
  (application response rates, scoring trends, most-used skills) so that I can
  refine my strategy.
Current State: PARTIAL — Dashboard shows basic stats (total applications,
  status counts). No trend analysis or insights.
Required State: An analytics section in the dashboard showing:
  - Application response rate over time (applied → interview → offer pipeline)
  - Average ATS score trends across optimizations
  - Most frequently matched skills (from JD analysis)
  - Weekly/monthly application volume charts
Acceptance Criteria:
  - Given a user with ≥10 applications, then the analytics section displays
    at least 3 chart types (line, bar, or pie).
  - Given the charts, then they render with the existing design system
    (no new charting library without approval).
  - Given a user with <10 applications, then the analytics section shows
    an encouraging message with a CTA to optimize more resumes.
Dependencies: Application history data (existing), charting component
```

---

## 6. Non-Functional Requirements

### 6.1 Performance

| Metric | Target | Current |
|:---|:---|:---|
| Cover letter generation time | < 10 seconds | N/A (new feature) |
| Interview question generation | < 5 seconds | N/A (new feature) |
| Template preview rendering | < 500ms | N/A (new feature) |
| Landing page Lighthouse score | ≥ 90 (Performance) | N/A (no landing page) |
| Stripe checkout redirect | < 2 seconds | N/A (new feature) |

### 6.2 Security

| Requirement | Detail |
|:---|:---|
| Payment data | Never touches Smart Apply servers; Stripe Checkout handles all PCI compliance |
| Subscription tier enforcement | Enforced at API boundary (backend guard), not client-side only |
| Stripe webhook verification | Signature verification using Stripe's signing secret (same pattern as Clerk webhooks) |
| Interview audio (if implemented) | Processed client-side only; no audio stored server-side; user consent required |
| Feature gating | Cannot be bypassed by direct API calls; backend validates tier on every request |

### 6.3 Privacy (Maintain Zero-Storage Principle)

| Requirement | Detail |
|:---|:---|
| Cover letters | Generated on-demand; stored only in user's Google Drive (extension) or downloaded (web) |
| Interview practice sessions | Stored in Supabase only as text Q&A pairs (no audio recording stored) |
| Payment data | Managed entirely by Stripe; Smart Apply stores only subscription tier and Stripe customer ID |
| Analytics data | Derived from existing application history; no new PII collection required |

### 6.4 Accessibility

| Requirement | Detail |
|:---|:---|
| Template picker | Keyboard navigable with visible focus indicators |
| Cover letter editor | Standard textarea with screen reader labels |
| Interview practice | Keyboard-accessible question navigation and answer submission |
| Payment flows | All Stripe Checkout accessibility standards inherited |

### 6.5 Compatibility

| Requirement | Detail |
|:---|:---|
| Resume templates | All templates must produce ATS-parseable PDFs (no text-as-image) |
| Cover letter PDFs | Standard PDF format, parseable by ATS systems |
| Chrome extension auto-apply | Must degrade gracefully on unsupported career portals |

---

## 7. Monetisation Model

### 7.1 Tier Definitions

| Feature | Free | Pro | Premium |
|:---|:---|:---|:---|
| Resume optimizations | 3/month | Unlimited | Unlimited |
| Cover letter generation | 1/month | Unlimited | Unlimited |
| ATS scoring (5-dim) | ✅ | ✅ | ✅ |
| Resume templates | 1 (Classic) | All (3+) | All (3+) |
| Google Drive upload | ❌ | ✅ | ✅ |
| Interview preparation | ❌ | ❌ | ✅ |
| Auto-apply assistance | ❌ | ❌ | ✅ |
| Priority LLM processing | ❌ | ✅ | ✅ |
| Application tracking | ✅ (basic) | ✅ (full pipeline) | ✅ (full pipeline + analytics) |

### 7.2 Implementation Strategy

1. **Stripe Integration** — Use Stripe Checkout for payment, Stripe Webhooks for subscription lifecycle events.
2. **Clerk Metadata** — Store `subscriptionTier` ("free" | "pro" | "premium") and `stripeCustomerId` in Clerk user public metadata.
3. **Backend Guard** — Create a `SubscriptionGuard` (NestJS) that reads the user's tier from the JWT claims and enforces feature access.
4. **Usage Tracking** — Track monthly usage counts in Supabase (`user_usage` table: `clerk_user_id`, `month`, `optimizations_count`, `cover_letters_count`).
5. **Client-Side Gating** — Display upgrade prompts when limits are reached; do not rely on client-side checks alone.

---

## 8. Prioritised Roadmap

### Phase 6A — Core Growth (P0 requirements)

| REQ | Title | Effort | Dependencies |
|:---|:---|:---|:---|
| REQ-06-01 | AI Cover Letter Generation | M | LLM service, PDF pipeline |
| REQ-06-02 | Subscription & Payment Model | L | Stripe, Clerk metadata |
| REQ-06-03 | Resume Template Selection | M | PDF generation refactor |

### Phase 6B — Competitive Parity (P1 requirements)

| REQ | Title | Effort | Dependencies |
|:---|:---|:---|:---|
| REQ-06-04 | AI Interview Preparation | L | New backend module, web routes |
| REQ-06-05 | Auto-Apply Job Submission | L | Extension autofill, Premium tier |
| REQ-06-06 | Landing Page & SEO Foundation | M | Next.js public routes, content |

### Phase 6C — Market Expansion (P2 requirements)

| REQ | Title | Effort | Dependencies |
|:---|:---|:---|:---|
| REQ-06-07 | Resume Translation | M | LLM service, PDF font support |
| REQ-06-08 | Job Board Integration | L | External API integrations |
| REQ-06-09 | Real-Time Interview Coaching | XL | Audio processing, streaming LLM |
| REQ-06-10 | Analytics Dashboard | S | Existing data, charting component |

**Effort Key:** S = Small (1–3 days), M = Medium (1–2 weeks), L = Large (2–4 weeks), XL = Extra Large (1–2 months)

---

## 9. Success Criteria

| Metric | Target | Measurement |
|:---|:---|:---|
| Cover letter adoption | ≥80% of users who optimize a resume also generate a cover letter | Analytics query on application records |
| Paid conversion rate | ≥5% of registered users convert to Pro or Premium within 90 days | Stripe dashboard + Clerk user metadata |
| Interview prep engagement | ≥30% of active users use interview prep at least once | Backend usage tracking |
| Template usage distribution | No single template used by >70% of users (indicating choice matters) | PDF generation logs |
| Landing page organic traffic | ≥1,000 unique visitors/month within 6 months of launch | Web analytics (Vercel Analytics or equivalent) |
| User retention (30-day) | ≥40% of registered users return within 30 days | Clerk login timestamps |
| ATS score improvement maintained | Average post-optimization score improvement ≥15% (existing baseline) | Scoring service logs |

---

## 10. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|:---|:---|:---|:---|
| Stripe integration complexity delays launch | Medium | High | Start with simple Checkout flow; defer subscription management portal to Phase 6B |
| Cover letter quality perceived as generic | Medium | High | Use profile + JD + optimized resume as context; require user editing before download |
| Auto-apply triggers anti-bot detection on career portals | High | Medium | Implement rate limiting, randomized delays, and human-like interaction patterns; disable on portals that explicitly block automation |
| Interview Buddy raises ethical concerns | Medium | Medium | Include prominent disclaimer; make disclosure opt-in; position as "preparation aid" not "cheating tool" |
| Template proliferation increases maintenance burden | Low | Medium | Limit to 3–5 templates; define a template specification that separates data from layout |
| Free tier abuse (account cycling) | Medium | Low | Track usage by Clerk user ID with email verification; rate-limit account creation |
| LLM cost increase with new features | High | Medium | Implement usage-based rate limiting per tier; monitor token consumption; cache common JD patterns |

---

## 11. Appendix

### A. Competitive Landscape Summary

| Competitor | Key Strength | Smart Apply Advantage |
|:---|:---|:---|
| AIApply.co | Auto-Apply automation, 1.16M users, full lifecycle | Human-in-the-loop, zero-storage privacy, Chrome extension, 5-dim ATS scoring |
| Jobscan | ATS score checking | Smart Apply includes optimization, not just scoring |
| Teal | Career management platform | Smart Apply offers deeper AI optimization per JD |
| Kickresume | Resume templates and builder | Smart Apply offers JD-specific optimization, not generic templates |
| Resume.io | Template-focused resume builder | Smart Apply's AI optimization and autofill go beyond template creation |

### B. Technical Architecture Impact

New modules required for Phase 6A:
1. **Backend**: `CoverLetterModule` (controller + service + prompts), `SubscriptionModule` (Stripe webhooks + guards), `SubscriptionGuard`
2. **Web**: `/cover-letter` route, `/pricing` route, `TemplatePickerComponent`, Stripe Checkout integration
3. **Extension**: Cover letter generation trigger, template selection in popup
4. **Shared**: `CoverLetterSchema`, `SubscriptionTier` enum, `UsageLimits` types, template type definitions
5. **Database**: `user_usage` table, `subscription_tier` column on profiles (or Clerk metadata), cover letter reference on `application_history`

### C. Document History

| Version | Date | Author | Changes |
|:---|:---|:---|:---|
| 1.0 | 2026-03-31 | Business Analyst Agent | Initial BRD — competitive analysis, 10 requirements, monetisation model |
