---
title: PRD - Resume-Flow AI
description: Product requirements for the Smart Apply assistant and resume optimization flow.
hero_eyebrow: Product requirements
hero_title: PRD for Resume-Flow AI
hero_summary: The product blueprint for Smart Apply's semi-automated application assistant, ATS optimization workflow, and human-in-the-loop experience.
permalink: /prd/
---

# 📄 [PRD] Resume-Flow AI: Smart Job Application Assistant

**Version:** 2.1 (Comprehensive Technical & Product Draft)  
**Status:** Ready for Development  
**Objective:** To eliminate the friction of tailoring resumes and filling out repetitive forms for job seekers applying to 100+ positions, leveraging AI and automation without compromising user privacy or violating platform terms.

---

## 1. Executive Summary
This project is built on three core principles: **Minimum Cost, Maximum Efficiency, and User Trust.** Moving away from reckless "bulk apply" bots, we are building a semi-automated assistant that saves 90% of a job seeker's time while strictly adhering to platform regulations.

**Core Values:**
- **Zero-Storage Policy:** Generated resume PDFs are stored exclusively in the user's Google Drive, never on our servers. This ensures absolute privacy and reduces our cloud storage costs to zero.
- **ATS-Proof Optimization (Core Metric):** The ultimate goal is to bypass Applicant Tracking System (ATS) keyword filters. The AI cross-references the Job Description (JD) with the Master Profile, calculates an "ATS Match Score," and visually demonstrates how targeted keyword injection increases compatibility (e.g., from a 45% to a 92% match) before the user applies.
- **Surgical AI Integration:** Instead of rewriting the entire resume (which risks hallucination and loss of user voice), the AI specifically injects missing JD keywords naturally into existing experience bullets or skill sections.
- **Smart Assistant & Human-in-the-Loop:** Beyond generating files, the Chrome Extension auto-fills application forms on job boards. However, the final "Submit" action and AI edits always require user confirmation (Semi-auto).

---

## 2. System Architecture (The 4 Pillars)

| Component | Role | Tech Stack |
| :--- | :--- | :--- |
| **Chrome Extension** | UI, Client-side DOM scraping (LinkedIn profile & JDs), PDF rendering, Form Auto-fill. | React, Tailwind CSS, pdf-lib |
| **Backend API** | AI Prompt orchestration, Keyword mapping, ATS Scoring calculation. | Node.js (NestJS) |
| **Web Portal & DB** | User dashboard, Master profile DB, Row Level Security (RLS) enforcement. | Next.js, Supabase (PostgreSQL) |
| **Auth & Storage** | Universal identity management, DB access tokens, File storage. | Clerk, Google Drive API |

---

## 3. Core Functional Requirements

### 3.1 Authentication & Master Data Ingestion
- **Clerk Auth:** Users log in via Clerk across both the Extension and Web Portal. Clerk issues a JWT that securely communicates with the Backend and Supabase.
- **Google OAuth:** Acquired during onboarding to request the `drive.file` scope (creating/managing files only created by our app).
- **Client-Side LinkedIn Parsing:** To bypass LinkedIn's strict anti-bot measures, the *Chrome Extension* reads the DOM of the user's logged-in LinkedIn profile, extracts the text, and sends it to the backend to generate the "Master Profile."

### 3.2 AI-Powered Resume Optimization & ATS Scoring (The Engine)
- **Pre- and Post-ATS Match Scoring:**
  - The backend analyzes the raw JD to extract required hard skills, soft skills, and certifications.
  - It calculates a baseline "ATS Compatibility Score" based on the user's original Master Profile.
- **Semantic Inference & Auto-Revise Logic:** The LLM receives the Master Profile and JD. If a JD requires a specific skill (e.g., IIS) and the Master Profile lacks it but indicates related senior experience (e.g., 10 years as a .NET developer), the AI flags this for inclusion.
- **Review UI (Anti-Hallucination):** The extension displays a clear progress metric (e.g., a progress bar showing *Before: 45% -> After: 92%*) along with a quick diff of the text changes. The user can uncheck (reject) any inaccurate additions.

### 3.3 Client-Side PDF Generation & Sync
- **On-the-fly Generation:** Upon user approval of the AI edits, the Extension utilizes `pdf-lib` to map the final JSON data into a clean, pre-designed PDF template directly within the browser.
- **Drive Sync:** The extension (or backend via securely passed tokens) uploads the rendered PDF to the user's Google Drive under `Resume-Flow/[Company_Name]/` and retrieves a shareable link.

### 3.4 Smart Auto-fill (The Assistant)
- **Form Detection:** Content scripts detect standard input fields (Name, Email, Phone, Cover Letter, Work Experience) on platforms like LinkedIn Easy Apply or Workday.
- **One-Click Fill:** A floating "Auto-fill" button populates the inputs using the Master Profile and the newly AI-tailored summary.
- **Fallback UX:** If auto-fill fails due to unconventional HTML structures, the extension provides a sidebar with "Copy to Clipboard" buttons for every piece of data.

---

## 4. Data Model & Security Schema

### 4.1 Master Profile Table (`master_profiles`)
*Hosted on Supabase. Strictly governed by RLS.*

```json
{
  "id": "uuid",
  "clerk_user_id": "string (e.g., user_2Qx...)",
  "full_name": "string",
  "email": "string",
  "base_skills": ["C#", ".NET", "SQL"],
  "experiences": [
    {
      "company": "string",
      "role": "string",
      "description": "string"
    }
  ],
  "created_at": "timestamp"
}
```

### 4.2 Application History Table (`application_history`)
Metadata only. No actual resume files are stored here.

```json
{
  "id": "uuid",
  "clerk_user_id": "string",
  "company_name": "string",
  "job_title": "string",
  "drive_link": "string (URL)",
  "status": "enum (applied, interviewing, rejected)",
  "applied_at": "timestamp"
}
```

### 4.3 Database Security (Row Level Security - RLS)
- Supabase is configured to intercept the Clerk JWT.
- Policy logic: `USING (requesting_clerk_user_id() = clerk_user_id)`.
- Result: A user (or any backend query made on their behalf) can only `SELECT`, `INSERT`, `UPDATE`, or `DELETE` rows where the `clerk_user_id` matches their own token. Cross-account data leakage is mathematically impossible at the DB level.

---

## 5. Detailed User Flow
1. **Install & Onboard:** User installs the Chrome Extension, logs in via Clerk, and connects their Google account.
2. **Profile Ingestion:** User visits their own LinkedIn profile; the Extension prompts to "Sync Profile." Master data is saved to Supabase.
3. **Discovery:** User browses a job posting (JD) on LinkedIn or Indeed. The Extension detects the JD and activates the **[Optimize for this Job]** button.
4. **The Optimization & ATS Scoring Loop:**
   - **Extension:** Scrapes JD text -> Sends to Backend.
   - **Backend:** Extracts core requirements -> Calculates baseline ATS Score -> LLM injects missing keywords naturally -> Calculates new ATS Score -> Returns JSON.
   - **Extension UI:** Displays the ATS Match progress (e.g., `50% -> 90%`) along with a quick diff of the text changes.
   - **Action:** User reviews the added keywords and clicks **Approve & Generate**.
   - **Extension:** Renders the ATS-friendly PDF -> Uploads to Google Drive -> Saves metadata to Supabase.
5. **Application:** User clicks "Apply" on the job board. The Extension's Auto-fill button appears, populating all fields.
6. **Tracking:** User checks the Next.js Web Portal dashboard to view application history, statuses, and links to the Drive PDFs.

---

## 6. Non-Functional Requirements
- **Privacy & Compliance (Right to be Forgotten):** If a user deletes their account, a Clerk webhook triggers a cascading hard delete of all their data in Supabase. Drive files remain untouched (user's property).
- **Performance:** The end-to-end process from clicking "Optimize" to the PDF being ready in Google Drive must take under 10 seconds.
- **Cost-Efficiency:** Utilize serverless functions (Vercel/NestJS) and generous free tiers (Supabase, Clerk) to maintain near $0 fixed infrastructure costs during the MVP phase.

---

## 7. Development Roadmap
- **v1.0 (MVP):** Single JD optimization from LinkedIn + ATS Match Scoring + PDF generation + Google Drive upload.
- **v1.5 (The Assistant):** Advanced form auto-fill support for major ATS platforms (Workday, Greenhouse, Lever).
- **v2.0 (Batch Prep):** "Cart" system to save multiple JDs and batch-generate optimized PDFs overnight.
- **v3.0 (Premium):** Subscription model integration, AI-driven interview prep based on the customized resume.

---

## 💡 Next Step
The next helpful step would be either **designing the Chrome extension UI/UX wireframes** or **writing the AI prompts and system prompt contract** for implementation.
