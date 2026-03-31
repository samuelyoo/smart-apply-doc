---
title: BRD — MVP 04
description: Business Requirements Document for MVP Phase 4, driven by local testing feedback in MVP_status_review_02 §9.
hero_eyebrow: Business requirements
hero_title: BRD for MVP 04
hero_summary: Translates hands-on local testing gaps — extension autofill cross-site activation and empty web dashboard — into prioritised business requirements for the next development phase.
permalink: /brd-mvp-04/
---

# Business Requirements Document — MVP 04

**Version:** 1.0  
**Date:** 2026-03-30  
**Source:** MVP_status_review_02.md (§9 — Local Testing Feedback)  
**Author:** Business Analyst Agent  

---

## 1. Executive Summary

The MVP is now technically healthy: all packages build, 85+ tests pass, core user journey (sign in → sync profile → optimize → approve → generate PDF → save application) works across both web and extension, and deployment scaffolding is in place. However, hands-on local testing revealed two significant product gaps that weaken the real-world usability of the product.

**Gap 1 — Extension autofill only works on five hardcoded domains.** In practice, ~80% of LinkedIn and Indeed job postings redirect to the company's own career portal (Workday, Greenhouse, Lever, and thousands of custom ATS portals). Once the user navigates to these external sites, the autofill content script is not injected and there is no mechanism to activate it. The extension lacks an on/off toggle and has no ability to follow the user's application flow across domains. This effectively breaks the core "Smart Auto-fill" promise from PRD §3.4 for the majority of real-world applications.

**Gap 2 — Web dashboard is an empty shell.** The dashboard renders only an applications history table and stats cards. For new users with no applications, it shows a near-empty placeholder. There is no onboarding guidance, no quick actions, no profile completeness feedback, and no reason for users to return to the dashboard regularly. The PRD §5 Step 6 envisions the dashboard as the central tracking and status hub, but the current implementation falls short of that vision.

This BRD defines the requirements to close both gaps, transforming the extension into a genuine "apply assistant" that follows users across portals and the dashboard into a useful home base that drives engagement and activation.

---

## 2. Stakeholder Goals

| Stakeholder | Goal | Success Metric |
|:---|:---|:---|
| Job Seeker (primary user) | Auto-fill job application forms on any career portal, not just the five hardcoded domains | Autofill activates on ≥3 external company portals beyond LinkedIn/Indeed/Workday/Greenhouse/Lever during manual QA |
| Job Seeker (primary user) | See a useful, actionable dashboard upon signing in — especially as a new user | New user sees onboarding checklist with ≥3 actionable steps; returning user sees quick actions and activity within 1 second of page load |
| Product Owner | Deliver the "Smart Auto-fill" value proposition promised in the PRD across the real-world application flow | Extension can inject autofill into the destination page after a user clicks "Apply" on a job posting that redirects externally |
| Product Owner | Increase web dashboard engagement and reduce churn after first sign-in | Dashboard bounce rate < 50% (future metric); users interact with ≥1 dashboard action per session |
| Engineering Team | Implement cross-site autofill injection without compromising extension security posture | Use `chrome.scripting.executeScript` with `activeTab` permission rather than blanket `<all_urls>` content script injection |

---

## 3. Previous Phase Outcomes

### 3.1 Requirements Closed (from BRD-MVP-03 / Phase P05)

| REQ ID | Title | Status |
|:---|:---|:---|
| REQ-03-01 | Web Component Test Coverage — OptimizeForm | ✅ PASS — closing |
| REQ-03-02 | Web Component Test Coverage — OptimizeResults | ✅ PASS — closing |
| REQ-03-03 | Web Component Test Coverage — DashboardShell | ✅ PASS — closing |
| REQ-03-04 | Web Component Test Coverage — ProfileEditor | ✅ PASS — closing |
| REQ-03-05 | Web Component Test Coverage — SettingsPage | ✅ PASS — closing |
| REQ-03-06 | Extension PDF Generator Tests | ✅ PASS — closing |
| REQ-03-07 | Extension OPTIMIZE_JD Handler Tests | ✅ PASS — closing |
| REQ-03-08 | CORS Unit Tests | ✅ PASS — closing |
| REQ-03-09 | Audit Log Assertion Tests | ✅ PASS — closing |

### 3.2 Requirements Carried Forward

| REQ ID | Original Priority | New Priority | Change Reason |
|:---|:---|:---|:---|
| From MVP Review §3 | — | P1 | Dashboard lacks status update actions even though backend supports them |
| From MVP Review §3 | — | P1 | Web optimize flow stops at PDF download; does not save application record from web |
| From MVP Review §4 | — | P2 | No backend deployment target beyond Dockerfile |
| From MVP Review §4 | — | P2 | Health checks too shallow (no Supabase/LLM connectivity check) |
| From MVP Review §4 | — | P2 | No application detail pages, resume history views, or in-web status editing |

---

## 4. Delivered Capabilities (Foundation)

| # | Capability | Business Value |
|:---|:---|:---|
| 1 | Autofill content script injected on LinkedIn, Indeed, Workday, Greenhouse, Lever | Users can auto-fill on the five most common job platforms |
| 2 | Heuristic field matching by label/name/placeholder/aria-label | Autofill works on standard HTML forms without platform-specific adapters |
| 3 | LinkedIn Easy Apply file attachment support | Resume PDF is auto-attached in LinkedIn's modal flow |
| 4 | Clipboard fallback buttons for unsupported fields | Users are never completely blocked from filling a form |
| 5 | Floating "Auto-fill with Smart Apply" button injected on form pages | Visible, accessible entry point for autofill |
| 6 | Dashboard with StatsCards and ApplicationsTable | Returning users can see application history and aggregate metrics |
| 7 | Dashboard handles loading, error, and empty states | UI is resilient and informative across all data scenarios |
| 8 | Quick link to profile editor from dashboard | Users can navigate to profile management in one click |
| 9 | Full optimize → approve → PDF → Drive → save flow in extension | Core product value chain is complete in the extension surface |
| 10 | Web optimize flow with selectable changes and PDF download | Web users can optimize and download resumes without the extension |

---

## 5. Functional Requirements

### 5.1 Must-Have (P0 — Launch Blockers)

```
REQ-04-01
Title: Extension Autofill Toggle in Popup
User Story: As a job seeker, I want to toggle autofill on/off from the extension
  popup so that I control when Smart Apply injects form-filling on the current page.
Current State: MISSING — The popup has no autofill toggle. Autofill is only
  available on pages where the content script is statically injected via manifest.
Required State: The extension popup displays an "Auto-fill" toggle switch. When
  enabled, the autofill script is injected into the active tab on demand. The
  toggle state persists across popup open/close in chrome.storage.local.
Acceptance Criteria:
  - Given the popup is open, then an "Auto-fill" toggle is visible on the
    dashboard screen.
  - Given the toggle is switched on, when the user is on any webpage with a
    form, then the autofill content script is injected into the active tab and
    the floating "Auto-fill with Smart Apply" button appears.
  - Given the toggle is switched off, then no autofill injection occurs on
    pages outside the default manifest content_scripts hosts.
  - Given the toggle was enabled and the popup is closed and reopened, then the
    toggle reflects the persisted state.
Dependencies: REQ-04-02 (programmatic script injection)
```

```
REQ-04-02
Title: Programmatic Autofill Script Injection on Any Domain
User Story: As a job seeker, I want Smart Apply to auto-fill forms on any company
  career portal I'm redirected to so that I don't have to manually fill the same
  information on every external application site.
Current State: MISSING — The autofill content script is only injected on five
  hardcoded host patterns in manifest.ts (linkedin.com, indeed.com,
  myworkdayjobs.com, greenhouse.io, lever.co). When the user is redirected to
  another domain (e.g., careers.somecompany.com), the script is not present.
Required State: The extension can inject the autofill content script into any
  active tab on demand using chrome.scripting.executeScript. The manifest adds
  the "scripting" permission. Injection is gated by the user-controlled toggle
  (REQ-04-01) or by automatic activation (REQ-04-03).
Acceptance Criteria:
  - Given the autofill toggle is on and the user navigates to an arbitrary
    career portal (e.g., careers.example.com), when the page has a form, then
    the autofill content script is injected and the floating button appears
    within 2 seconds of page load.
  - Given the user is on a page with no form elements, then no visible autofill
    UI is injected (script may load but button does not appear).
  - Given the "scripting" permission is declared in the manifest, then
    chrome.scripting.executeScript succeeds on the active tab.
  - Given the user has not enabled the toggle and is not on a default
    content_scripts host, then no injection occurs (preserving current behavior
    as baseline).
Dependencies: Manifest update (add "scripting" permission)
```

```
REQ-04-03
Title: Auto-Activate Autofill on External Application Redirect
User Story: As a job seeker, I want Smart Apply to automatically enable autofill
  when I click "Apply" on a job posting and get redirected to the company's own
  application portal so that I don't have to manually toggle it on every time.
Current State: MISSING — The JD detector content script detects job pages on
  LinkedIn/Indeed but does not track outbound navigation. When the user clicks an
  external "Apply" link, the extension loses context entirely.
Required State: When the JD detector or background service worker detects that the
  user is navigating away from a known job posting page to an external domain
  (likely an "Apply" redirect), the extension automatically enables the autofill
  toggle and injects the autofill script into the destination tab.
Acceptance Criteria:
  - Given the user is on a LinkedIn job posting and clicks an external "Apply"
    link that opens a new tab or navigates to an external domain, then the
    autofill script is automatically injected on the destination page.
  - Given the auto-activation occurred, then the popup toggle reflects the
    "on" state.
  - Given the user completes or abandons the application and navigates away
    from the portal, then the autofill toggle remains on until the user
    manually disables it (sticky activation).
  - Given the user has the toggle already on, then auto-activation does not
    duplicate injection or cause errors.
Dependencies: REQ-04-01 (toggle), REQ-04-02 (programmatic injection), JD
  detector content script update
```

### 5.2 Should-Have (P1 — High Value)

```
REQ-04-04
Title: Dashboard Onboarding Checklist
User Story: As a new user, I want to see a step-by-step getting-started guide on
  the dashboard so that I know what to do next and can track my setup progress.
Current State: MISSING — New users see only "No applications yet" with a generic
  message to use the Chrome Extension. No structured onboarding exists.
Required State: The dashboard displays an onboarding checklist widget for users
  who have not completed key setup steps. The checklist dynamically marks steps
  as done based on actual system state (profile exists, extension connected,
  first optimization completed, first application saved).
Acceptance Criteria:
  - Given a new user with no profile, then the dashboard shows an onboarding
    checklist with at least 4 steps: "Import your profile," "Install Chrome
    Extension," "Optimize your first job," "Save your first application."
  - Given the user has imported a profile, then the "Import your profile" step
    is checked off automatically.
  - Given the user has completed all onboarding steps, then the checklist
    collapses or is dismissible.
  - Given the onboarding checklist is visible, then each uncompleted step
    links to the relevant page or action.
Dependencies: Backend profile existence check (GET /api/profile/me), application
  history count
```

```
REQ-04-05
Title: Dashboard Quick Actions Bar
User Story: As a returning user, I want quick-access buttons on the dashboard for
  common actions so that I can navigate to key features without hunting through
  the navigation.
Current State: PARTIAL — Only "Edit Profile" link exists in the dashboard header.
  No other quick actions are surfaced.
Required State: The dashboard includes a prominent quick actions section with
  buttons for: "Optimize a New Job" (→ /optimize), "Edit Profile" (→ /profile),
  "Upload Resume" (→ /profile with upload modal), and "Settings" (→ /settings).
Acceptance Criteria:
  - Given the dashboard is loaded, then a quick actions section is visible with
    at least 4 action buttons.
  - Given the user clicks "Optimize a New Job," then they are navigated to the
    /optimize page.
  - Given the user clicks "Edit Profile," then they are navigated to /profile.
  - Given all buttons are rendered, then each is keyboard-accessible with a
    visible focus indicator.
Dependencies: Existing route pages (/optimize, /profile, /settings)
```

```
REQ-04-06
Title: Dashboard Profile Completeness Meter
User Story: As a user, I want to see how complete my profile is so that I know
  what information to add for better optimization results.
Current State: MISSING — No profile completeness feedback exists anywhere in the
  web app. Users have no visibility into whether their profile data is sufficient
  for effective ATS optimization.
Required State: The dashboard displays a profile completeness score (percentage or
  progress bar) with specific calls-to-action for missing sections (e.g., "Add
  your skills," "Add work experience," "Write a summary").
Acceptance Criteria:
  - Given a user with a partial profile (e.g., name and email only), then the
    completeness meter shows a low percentage with specific missing-field labels.
  - Given a user with a fully populated profile (name, email, summary, skills,
    experiences, education), then the completeness meter shows 100%.
  - Given a missing section is identified, then clicking on it navigates to the
    profile editor with that section highlighted or scrolled into view.
  - Given the profile data changes, then the completeness meter updates on the
    next dashboard visit without requiring a hard refresh.
Dependencies: GET /api/profile/me response data, profile editor page
```

```
REQ-04-07
Title: Dashboard Application Status Pipeline View
User Story: As a user tracking multiple job applications, I want to see my
  applications organized by status (applied, interviewing, offered, rejected) so
  that I can manage my job search pipeline at a glance.
Current State: PARTIAL — ApplicationsTable renders a flat list. The backend
  supports status updates via PATCH /api/applications/:id/status, but the
  dashboard does not expose any status-change controls.
Required State: The dashboard offers an alternative pipeline/Kanban-style view
  where applications are grouped by status column. Users can update application
  status directly from the dashboard (e.g., via dropdown or drag-and-drop).
Acceptance Criteria:
  - Given the user has applications in multiple statuses, then the pipeline view
    groups them into columns by status (applied, interviewing, offered, rejected).
  - Given the user changes an application's status via dropdown or drag, then the
    status is updated via PATCH /api/applications/:id/status and the UI reflects
    the change immediately (optimistic update).
  - Given the user prefers the table view, then a toggle between table and
    pipeline view is available and the preference persists.
  - Given the pipeline view is displayed, then it is responsive on desktop and
    degrades gracefully to a stacked layout on mobile.
Dependencies: PATCH /api/applications/:id/status (exists), ListApplicationsResponse
```

```
REQ-04-08
Title: Web Optimize Flow — Save Application Record
User Story: As a user who optimizes and downloads a resume from the web app, I
  want the application to be automatically saved to my history so that I don't
  lose track of jobs I've applied to through the web flow.
Current State: PARTIAL — The web optimize flow at /optimize allows JD submission,
  displays results with selectable changes, and offers PDF download. But it does
  NOT save an application record to the backend. Only the extension flow saves
  application history.
Required State: After the user approves changes and downloads/generates the PDF
  from the web optimize flow, the web app calls POST /api/applications with the
  optimization metadata (company, job title, scores, snapshot) so the application
  appears in the dashboard history.
Acceptance Criteria:
  - Given the user completes the web optimize flow and clicks "Download PDF,"
    then an application record is saved via POST /api/applications.
  - Given the application is saved, then it appears in the dashboard on the
    next visit.
  - Given the save fails (network error), then an error message is shown and
    the user can retry.
  - Given the application was saved, then ATS scores (before/after) are included
    in the record.
Dependencies: POST /api/applications (exists), web optimize flow
```

### 5.3 Could-Have (P2 — Nice To Have)

```
REQ-04-09
Title: Dashboard Recent Activity Feed
User Story: As a returning user, I want to see a timeline of my recent actions
  (optimizations, profile updates, applications) so that I can quickly recall
  what I did last.
Current State: MISSING — No activity feed or event log is surfaced in the UI.
Required State: A compact activity feed widget on the dashboard shows recent
  events with timestamps (e.g., "Optimized resume for Backend Engineer at Acme —
  2 hours ago"). Data source can be application_history plus profile updated_at.
Acceptance Criteria:
  - Given the user has recent activity, then the feed shows the last 5–10 events
    in reverse chronological order.
  - Given no activity exists, then the feed shows an appropriate empty state.
Dependencies: Application history data, profile updated_at timestamp
```

```
REQ-04-10
Title: Dashboard Extension Connection Status
User Story: As a user, I want to see on the dashboard whether my Chrome extension
  is installed and connected so that I can troubleshoot setup issues.
Current State: MISSING — No extension detection exists on the web portal.
Required State: The dashboard includes a small status indicator showing whether
  the Smart Apply Chrome extension is detected (via externally_connectable
  messaging or a known extension ID ping).
Acceptance Criteria:
  - Given the extension is installed and the web page can communicate with it,
    then a "Connected" badge is shown.
  - Given the extension is not installed, then an "Install Extension" link is
    shown with a link to the Chrome Web Store listing.
Dependencies: Extension externally_connectable config (exists), Chrome Web Store
  listing URL
```

```
REQ-04-11
Title: ATS Score Trend Chart
User Story: As a user who has optimized multiple resumes, I want to see a chart
  of my ATS score improvements over time so that I can gauge how effective my
  optimizations have been.
Current State: MISSING — No visualization of historical ATS scores exists.
Required State: The dashboard includes a simple sparkline or bar chart showing
  before/after ATS scores from the user's application history over time.
Acceptance Criteria:
  - Given the user has ≥3 applications with ATS scores, then a trend chart
    is rendered showing before (red) and after (green) scores.
  - Given fewer than 3 data points, then the chart is hidden or replaced with
    a "Not enough data" placeholder.
Dependencies: Application history with ats_score_before/ats_score_after fields
```

---

## 6. Non-Functional Requirements

| # | Category | Requirement | Source |
|:---|:---|:---|:---|
| NFR-01 | Performance | Autofill script injection via `chrome.scripting.executeScript` must complete within 1 second of trigger | TRD §16.1 |
| NFR-02 | Performance | Dashboard page load (including API calls for profile + applications) must render meaningful content within 2 seconds | TRD §16.1 |
| NFR-03 | Security | Programmatic script injection must only occur when explicitly enabled by the user (toggle on) or triggered by a detected apply-redirect flow; never blanket-inject on all pages | TRD §15 |
| NFR-04 | Security | The autofill content script must not read or exfiltrate form data from the page; it only writes profile data into fields | TRD §15.1 |
| NFR-05 | Privacy | Zero server-side PDF storage policy remains in effect — dashboard features must not require storing resume files on the server | PRD §1 |
| NFR-06 | Accessibility | All new dashboard widgets and extension popup controls must be keyboard-accessible with visible focus indicators | PRD §3, copilot-instructions.md |
| NFR-07 | Accessibility | Dashboard layout must be responsive across mobile, tablet, and desktop viewports | copilot-instructions.md |
| NFR-08 | Reliability | If programmatic script injection fails (e.g., restricted page like chrome://), the extension must show a user-friendly message rather than a silent failure | TRD §17.3 |

---

## 7. Out of Scope

| Item | Reason |
|:---|:---|
| Platform-specific autofill adapters for individual ATS vendors (e.g., custom Workday step handling) | Deferred to v1.5 per PRD §7; heuristic matching is sufficient for MVP |
| Batch/bulk apply ("cart" system for multiple JDs) | Deferred to v2.0 per PRD §7 |
| AI-driven interview prep | Deferred to v3.0 per PRD §7 |
| Structured server-side logging and observability | Deferred from BRD-MVP-03 (REQ-02-12); not a launch blocker |
| Production deployment automation (backend hosting, CD pipeline) | Important but tracked separately from product feature requirements |
| Google Drive OAuth token management on backend | MVP uses extension-side upload per TRD §13.2; server-side token storage is out of scope |
| Resume template selection (multiple PDF layouts) | MVP ships with single ATS-friendly template per TRD §12.3 |

---

## 8. Open Questions

| # | Question | Owner | Due |
|:---|:---|:---|:---|
| 1 | Should the autofill toggle auto-disable after a configurable timeout (e.g., 30 minutes) to prevent accidental injection on non-application pages? | Product Owner | Phase P06 planning |
| 2 | Should the onboarding checklist include "Connect Google Drive" as a step, given Drive upload is best-effort and optional? | Product Owner | Phase P06 planning |
| 3 | For the application pipeline view, should drag-and-drop status changes be included in MVP or deferred to a later iteration? | Engineering Team | Phase P06 planning |
| 4 | What is the minimum set of dashboard widgets needed to ship vs. what can be iterated post-launch? | Product Owner | Phase P06 planning |
| 5 | Should the extension auto-activate autofill only on tab navigation from a job posting, or also on same-tab redirects (e.g., window.location change)? | Engineering Team | Phase P06 planning |
| 6 | How should the dashboard determine "extension connected" — via `chrome.runtime.sendMessage` from the web page, or by checking a backend flag set during extension auth? | Engineering Team | Phase P06 planning |

---

## 9. Approval Checklist

- [x] All P0 requirements have at least two acceptance criteria
- [x] Every requirement references a user story
- [x] No requirement contradicts the Zero-Storage Policy (PRD §1)
- [x] No requirement contradicts Clerk auth model
- [x] NFRs traceable to TRD sections
- [x] Out-of-scope list reviewed to prevent unintended inclusions
