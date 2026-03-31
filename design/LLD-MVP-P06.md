---
title: "LLD-MVP-P06 — Cross-Site Autofill & Dashboard Enrichment"
permalink: /design/lld-mvp-p06/
---

# LLD-MVP-P06 — Cross-Site Autofill & Dashboard Enrichment

**Version:** 1.0  
**Date:** 2026-03-30  
**Phase:** Cross-Site Autofill Activation & Web Dashboard Enrichment  
**Source:** HLD-MVP-P06.md, BRD-MVP-04.md  
**Prerequisite:** HLD-MVP-P06 approved.

---

## 1. File-Level Change Manifest

### 1.1 Extension — Cross-Site Autofill (REQ-04-01, REQ-04-02, REQ-04-03)

| File | Action | Purpose | Dependencies | Est. Lines |
|:---|:---|:---|:---|:---|
| `smart-apply-extension/src/manifest.ts` | **MODIFY** | Add `scripting`, `tabs`, `webNavigation` permissions | — | ~3 changed |
| `smart-apply-extension/src/background/service-worker.ts` | **MODIFY** | Add autofill injection logic, JD_PAGE_DETECTED handler, webNavigation listener, storage change listener | autofill.ts path, chrome APIs | ~80 added |
| `smart-apply-extension/src/content/jd-detector.ts` | **MODIFY** | Send JD_PAGE_DETECTED message to service worker | — | ~5 added |
| `smart-apply-extension/src/content/autofill.ts` | **MODIFY** | Add idempotency guard to `injectAutofillButton()` (already exists), export module check for programmatic injection | — | ~3 changed |
| `smart-apply-extension/src/ui/popup/App.tsx` | **MODIFY** | Add autofill toggle switch on dashboard screen | chrome.storage | ~25 added |

### 1.2 Shared — Profile Completeness (REQ-04-06)

| File | Action | Purpose | Dependencies | Est. Lines |
|:---|:---|:---|:---|:---|
| `smart-apply-shared/src/profile-completeness.ts` | **CREATE** | Pure function `calculateProfileCompleteness()` | MasterProfile type | ~55 |
| `smart-apply-shared/src/index.ts` | **MODIFY** | Add export for profile-completeness module | — | ~1 added |

### 1.3 Web Dashboard — Enrichment (REQ-04-04 through REQ-04-08)

| File | Action | Purpose | Dependencies | Est. Lines |
|:---|:---|:---|:---|:---|
| `smart-apply-web/src/components/dashboard/onboarding-checklist.tsx` | **CREATE** | Checklist widget for new users | MasterProfile, applications count | ~90 |
| `smart-apply-web/src/components/dashboard/quick-actions.tsx` | **CREATE** | Quick action buttons bar | next/link, shadcn Button | ~45 |
| `smart-apply-web/src/components/dashboard/profile-completeness.tsx` | **CREATE** | Profile completeness meter widget | calculateProfileCompleteness, MasterProfile | ~65 |
| `smart-apply-web/src/components/dashboard/pipeline-view.tsx` | **CREATE** | Kanban-style grouped status columns | ApplicationHistoryItem, useMutation, apiFetch | ~120 |
| `smart-apply-web/src/components/dashboard/dashboard-shell.tsx` | **MODIFY** | Integrate new widgets, add profile query, add view toggle | New widget components | ~50 changed |
| `smart-apply-web/src/components/optimize/optimize-results.tsx` | **MODIFY** | Save application after PDF download | apiFetch, CreateApplicationRequest | ~30 added |

### 1.4 Test Files

| File | Action | Purpose | Est. Lines |
|:---|:---|:---|:---|
| `smart-apply-shared/test/profile-completeness.spec.ts` | **CREATE** | Unit tests for calculateProfileCompleteness | ~80 |
| `smart-apply-extension/test/autofill-injection.spec.ts` | **CREATE** | Unit tests for injection logic, toggle persistence, auto-activate | ~100 |
| `smart-apply-web/test/components/onboarding-checklist.spec.tsx` | **CREATE** | Component tests for OnboardingChecklist | ~75 |
| `smart-apply-web/test/components/quick-actions.spec.tsx` | **CREATE** | Component tests for QuickActions | ~40 |
| `smart-apply-web/test/components/profile-completeness.spec.tsx` | **CREATE** | Component tests for ProfileCompleteness | ~60 |
| `smart-apply-web/test/components/pipeline-view.spec.tsx` | **CREATE** | Component tests for PipelineView | ~90 |
| `smart-apply-web/test/components/optimize-results-save.spec.tsx` | **CREATE** | Tests for application save after PDF download | ~50 |

---

## 2. Interface & Type Definitions

### 2.1 Shared Types Referenced

| Type | Package | Location |
|:---|:---|:---|
| `MasterProfile` | @smart-apply/shared | src/types/profile.ts |
| `ApplicationHistoryItem` | @smart-apply/shared | src/types/application.ts |
| `ApplicationStatus` | @smart-apply/shared | src/types/application.ts |
| `APPLICATION_STATUSES` | @smart-apply/shared | src/types/application.ts |
| `ListApplicationsResponse` | @smart-apply/shared | src/types/application.ts |
| `CreateApplicationRequest` | @smart-apply/shared | src/types/application.ts |
| `CreateApplicationResponse` | @smart-apply/shared | src/types/application.ts |
| `OptimizeResponse` | @smart-apply/shared | src/types/optimization.ts |

### 2.2 New Shared Type — ProfileCompletenessResult

```typescript
// smart-apply-shared/src/profile-completeness.ts

export interface ProfileSectionScore {
  weight: number;
  earned: number;
}

export interface ProfileCompletenessResult {
  score: number;                                    // 0–100, integer
  missingSections: string[];                        // e.g., ['summary', 'base_skills']
  sectionScores: Record<string, ProfileSectionScore>;
}
```

### 2.3 New Extension Message Types

Add to existing `MessageType` union in `service-worker.ts`:

```typescript
| { type: 'JD_PAGE_DETECTED'; payload: { hostname: string; url: string } }
| { type: 'INJECT_AUTOFILL'; payload: { tabId: number } }
```

### 2.4 New Component Props

```typescript
// OnboardingChecklist
interface OnboardingChecklistProps {
  profile: MasterProfile | null;
  applicationsCount: number;
  extensionDetected?: boolean;
}

// QuickActions
// No props — routes are hardcoded

// ProfileCompleteness
interface ProfileCompletenessProps {
  profile: MasterProfile | null;
}

// PipelineView
interface PipelineViewProps {
  items: ApplicationHistoryItem[];
  onStatusChange: (applicationId: string, newStatus: ApplicationStatus) => void;
}
```

---

## 3. Function-Level Design

### 3.1 calculateProfileCompleteness (NEW — smart-apply-shared)

```
Function: calculateProfileCompleteness
Location: smart-apply-shared/src/profile-completeness.ts
Signature: (profile: Pick<MasterProfile, 'full_name' | 'email' | 'summary' | 'base_skills' | 'experiences' | 'education'> | null) => ProfileCompletenessResult

Logic:
  1. If profile is null → return { score: 0, missingSections: all sections, sectionScores: all zeros }
  2. Define SECTIONS:
     - full_name: weight 15, condition: non-null & non-empty
     - email: weight 10, condition: non-null & non-empty
     - summary: weight 20, condition: non-null & length ≥ 50
     - base_skills: weight 20, condition: array.length ≥ 3
     - experiences: weight 25, condition: array.length ≥ 1 && first item has role + company + description.length > 0
     - education: weight 10, condition: array.length ≥ 1
  3. For each section: evaluate condition → earned = condition ? weight : 0
  4. Sum earned weights → score
  5. Collect sections where earned === 0 → missingSections
  6. Return { score, missingSections, sectionScores }

Error Cases: None — pure function, null profile handled

Side Effects: None
```

### 3.2 injectAutofillOnTab (NEW — service-worker.ts)

```
Function: injectAutofillOnTab
Location: smart-apply-extension/src/background/service-worker.ts
Signature: (tabId: number) => Promise<{ success: boolean; error?: string }>

Logic:
  1. Try chrome.scripting.executeScript({ target: { tabId }, files: ['src/content/autofill.ts'] })
  2. On success → return { success: true }
  3. On error (e.g., restricted page chrome://) → return { success: false, error: 'Cannot inject on this page' }

Error Cases:
  - Restricted page (chrome://, chrome-extension://) → catch error, return failure message
  - Tab doesn't exist → catch error, return failure

Side Effects: Injects content script into target tab
```

### 3.3 setupAutofillListeners (NEW — service-worker.ts)

```
Function: setupAutofillListeners
Location: smart-apply-extension/src/background/service-worker.ts
Signature: () => void

Logic:
  1. Declare module-scoped: let lastJdPage: { hostname: string; timestamp: number } | null = null
  2. Listen chrome.storage.onChanged:
     - If autofill_enabled changed to true → log state change
     - If autofill_enabled changed to false → log state change
  3. Listen chrome.tabs.onUpdated:
     - If status === 'complete' and url defined:
       a. Read autofill_enabled from chrome.storage.local
       b. Check url is not chrome:// or chrome-extension://
       c. If autofill_enabled === true → call injectAutofillOnTab(tabId)
  4. Listen chrome.webNavigation.onCompleted:
     - If lastJdPage exists AND (Date.now() - lastJdPage.timestamp) < 60_000:
       a. Parse new URL hostname
       b. If hostname !== lastJdPage.hostname:
          - Set autofill_enabled = true in chrome.storage.local
          - Call injectAutofillOnTab(tabId)
          - Clear lastJdPage

Error Cases:
  - webNavigation event on restricted page → skip injection

Side Effects: Registers Chrome API listeners, injects scripts
```

### 3.4 handleJdPageDetected (NEW — service-worker.ts)

```
Function: handleJdPageDetected (inline in message handler)
Location: smart-apply-extension/src/background/service-worker.ts

Logic:
  1. Receive { hostname, url } from JD detector content script
  2. Store in module-scoped variable: lastJdPage = { hostname, timestamp: Date.now() }
  3. Return { success: true }

Side Effects: Updates module-scoped lastJdPage variable
```

### 3.5 Dashboard Widget: OnboardingChecklist (NEW — web)

```
Function: OnboardingChecklist (React component)
Location: smart-apply-web/src/components/dashboard/onboarding-checklist.tsx

Props: { profile: MasterProfile | null; applicationsCount: number }

State:
  - dismissed: boolean (localStorage key: 'onboarding_dismissed')

Logic:
  1. Define checklist steps:
     - "Import your profile" → completed if profile !== null && profile.full_name
     - "Install Chrome Extension" → always show link (cannot detect from web)
     - "Optimize your first job" → completed if applicationsCount ≥ 1 (implies at least one optimization)
     - "Save your first application" → completed if applicationsCount ≥ 1
  2. Count completed steps
  3. If all completed OR dismissed → return null (render nothing)
  4. Render Card with progress indicator and list of steps
  5. Each uncompleted step links to relevant page (/profile, chrome web store URL, /optimize)
  6. "Dismiss" button sets dismissed=true in localStorage

Children: Card, CardContent, CardHeader (shadcn/ui), Link (next/link)
Accessibility: Checklist items use <li> in <ul>, links have descriptive text, dismiss button is keyboard-accessible
```

### 3.6 Dashboard Widget: QuickActions (NEW — web)

```
Function: QuickActions (React component)
Location: smart-apply-web/src/components/dashboard/quick-actions.tsx

Props: None

Logic:
  1. Render 4 action buttons in a responsive grid:
     - "Optimize a New Job" → href="/optimize"
     - "Edit Profile" → href="/profile"
     - "Upload Resume" → href="/profile" (profile page handles upload)
     - "Settings" → href="/settings"
  2. Each button uses shadcn Button variant="outline" wrapped in Link

Children: Button (shadcn/ui), Link (next/link)
Accessibility: All buttons keyboard-accessible, visible focus indicators via shadcn defaults
```

### 3.7 Dashboard Widget: ProfileCompleteness (NEW — web)

```
Function: ProfileCompleteness (React component)
Location: smart-apply-web/src/components/dashboard/profile-completeness.tsx

Props: { profile: MasterProfile | null }

Logic:
  1. Call calculateProfileCompleteness(profile) from @smart-apply/shared
  2. Render Card with:
     - Circular or linear progress bar showing score%
     - If score < 100: list of missingSections with links to /profile
     - If score === 100: "Profile complete!" message
  3. Missing section display names: { full_name: 'Full Name', email: 'Email', summary: 'Professional Summary', base_skills: 'Skills (3+)', experiences: 'Work Experience', education: 'Education' }

Children: Card (shadcn/ui), Progress bar (native div with CSS)
Accessibility: Progress element uses role="progressbar" with aria-valuenow, aria-valuemin, aria-valuemax
```

### 3.8 Dashboard Widget: PipelineView (NEW — web)

```
Function: PipelineView (React component)
Location: smart-apply-web/src/components/dashboard/pipeline-view.tsx

Props: { items: ApplicationHistoryItem[]; onStatusChange: (id: string, status: ApplicationStatus) => void }

Logic:
  1. Define STATUS_COLUMNS: ['applied', 'interviewing', 'offer', 'rejected', 'withdrawn']
  2. Group items by status: Map<ApplicationStatus, ApplicationHistoryItem[]>
  3. Render columns in a horizontal scrollable grid (responsive: stack on mobile)
  4. Each column header shows status name + count
  5. Each card shows: company_name, job_title, ATS score after, applied date
  6. Each card has a <select> dropdown for status change
     - onChange → call onStatusChange(item.id, newStatus)
  7. Items with status 'draft' or 'generated' are grouped into the 'applied' column

Children: Card (shadcn/ui), Badge, Select
Accessibility:
  - Columns use role="group" with aria-label
  - Status select has aria-label "Change status for {company} - {jobTitle}"
  - Cards are keyboard-navigable
```

### 3.9 DashboardShell Modification

```
Function: DashboardShell (MODIFY)
Location: smart-apply-web/src/components/dashboard/dashboard-shell.tsx

New State:
  - viewMode: 'table' | 'pipeline' (persisted in localStorage key: 'dashboard_view_mode')

New Queries:
  - profileQuery: useQuery({ queryKey: ['profile'], queryFn: fetch /api/profile/me })

New Logic:
  1. Import all new widget components
  2. Add profile query alongside existing applications query
  3. Add view mode toggle button (Table | Pipeline)
  4. Add status change handler:
     - useMutation for PATCH /api/applications/:id/status
     - onMutate: optimistic update in query cache
     - onError: rollback + toast
     - onSuccess: invalidate applications query
  5. Render order:
     a. OnboardingChecklist (if profile null or applicationsCount === 0)
     b. QuickActions (always)
     c. ProfileCompleteness (always)
     d. StatsCards (when data exists)
     e. View toggle + PipelineView | ApplicationsTable (when data exists)

Error Cases:
  - Profile fetch failure → ProfileCompleteness shows 0% with generic message
  - Status PATCH failure → rollback optimistic update, show error toast
```

### 3.10 OptimizeResults — Save Application (MODIFY)

```
Function: handleDownloadPdf (MODIFY)
Location: smart-apply-web/src/components/optimize/optimize-results.tsx

New Logic (appended after PDF download trigger):
  1. After successful PDF blob download:
     a. Call POST /api/applications via apiFetch with:
        - company_name: companyName (from props)
        - job_title: result.extracted_requirements context (or from parent)
        - source_platform: 'other'
        - ats_score_before: result.ats_score_before
        - ats_score_after: result.ats_score_after
        - status: 'generated'
        - applied_resume_snapshot: result.optimized_resume_json
     b. Show success toast
  2. On save error:
     - Show error toast with retry
     - PDF download still succeeds (save failure is non-blocking for PDF)

New Props Needed:
  - Add `jobTitle: string` to OptimizeResultsProps (passed from OptimizeForm)

Changes to OptimizeForm:
  - Pass `jobTitle` prop to <OptimizeResults>
```

---

## 4. Database Operations

No database changes. All operations use existing endpoints:

| Operation | Endpoint | Supabase Query |
|:---|:---|:---|
| Fetch profile | GET /api/profile/me | `select * from master_profiles where clerk_user_id = ?` |
| List applications | GET /api/applications | `select * from application_history where clerk_user_id = ? order by created_at desc` |
| Create application | POST /api/applications | `insert into application_history (...)` |
| Update status | PATCH /api/applications/:id/status | `update application_history set status = ? where id = ? and clerk_user_id = ?` |

All queries are scoped by RLS (`clerk_user_id`).

---

## 5. Test Specification

### 5.1 Profile Completeness Unit Tests — `smart-apply-shared/test/profile-completeness.spec.ts`

```
Suite: calculateProfileCompleteness
Test File: smart-apply-shared/test/profile-completeness.spec.ts
Mocks Required: None (pure function)

Cases:
  - it("returns 0 for null profile")
    → assert score === 0, missingSections.length === 6

  - it("returns 100 for fully complete profile")
    → assert score === 100, missingSections.length === 0

  - it("returns 15 when only full_name is present")
    → assert score === 15, missingSections includes all except 'full_name'

  - it("requires summary ≥ 50 chars")
    → profile with summary 'short' → summary still in missingSections
    → profile with summary of 50+ chars → summary not in missingSections

  - it("requires ≥ 3 skills")
    → profile with 2 skills → base_skills in missingSections
    → profile with 3 skills → base_skills not in missingSections

  - it("requires ≥ 1 experience with role, company, and description")
    → empty experiences → in missingSections
    → experience with role+company+description → not in missingSections

  - it("returns correct sectionScores breakdown")
    → verify each section's weight and earned values
```

### 5.2 Autofill Injection Tests — `smart-apply-extension/test/autofill-injection.spec.ts`

```
Suite: Autofill Injection Logic
Test File: smart-apply-extension/test/autofill-injection.spec.ts
Mocks Required: chrome.scripting, chrome.storage, chrome.tabs, chrome.webNavigation

Cases:
  - it("injectAutofillOnTab calls chrome.scripting.executeScript with correct args")
    → mock chrome.scripting.executeScript to resolve
    → assert called with { target: { tabId: 123 }, files: [...] }

  - it("injectAutofillOnTab returns error for restricted pages")
    → mock chrome.scripting.executeScript to reject
    → assert returns { success: false, error: string }

  - it("tabs.onUpdated injects when autofill_enabled is true")
    → set chrome.storage.local autofill_enabled = true
    → simulate tabs.onUpdated with status 'complete'
    → assert chrome.scripting.executeScript called

  - it("tabs.onUpdated does NOT inject when autofill_enabled is false")
    → set chrome.storage.local autofill_enabled = false
    → simulate tabs.onUpdated
    → assert chrome.scripting.executeScript NOT called

  - it("tabs.onUpdated skips chrome:// URLs")
    → simulate tabs.onUpdated with url 'chrome://extensions'
    → assert chrome.scripting.executeScript NOT called

  - it("webNavigation auto-activates on cross-domain redirect within 60s")
    → set lastJdPage with recent timestamp
    → simulate webNavigation.onCompleted with different hostname
    → assert autofill_enabled set to true
    → assert chrome.scripting.executeScript called

  - it("webNavigation does NOT auto-activate after 60s timeout")
    → set lastJdPage with old timestamp (> 60s ago)
    → simulate webNavigation.onCompleted
    → assert chrome.scripting.executeScript NOT called

  - it("JD_PAGE_DETECTED message stores hostname and timestamp")
    → send message { type: 'JD_PAGE_DETECTED', payload: { hostname: 'linkedin.com', url: '...' } }
    → verify internal state updated
```

### 5.3 OnboardingChecklist Tests — `smart-apply-web/test/components/onboarding-checklist.spec.tsx`

```
Suite: OnboardingChecklist
Test File: smart-apply-web/test/components/onboarding-checklist.spec.tsx
Mocks Required: next/navigation (useRouter), localStorage

Cases:
  - it("renders 4 checklist steps for a new user with null profile")
    → render with profile=null, applicationsCount=0
    → assert 4 list items visible

  - it("marks 'Import your profile' as complete when profile has full_name")
    → render with profile.full_name='John'
    → assert step has checkmark/completed style

  - it("marks optimization/application steps complete when applicationsCount ≥ 1")
    → render with applicationsCount=1
    → assert both steps checked

  - it("hides checklist when all steps complete")
    → render with complete profile and applicationsCount=1
    → assert component renders null

  - it("dismiss button hides checklist and persists in localStorage")
    → click dismiss
    → assert component disappears
    → assert localStorage('onboarding_dismissed') === 'true'

  - it("uncompleted steps link to correct routes")
    → assert 'Import your profile' links to /profile
    → assert 'Optimize your first job' links to /optimize
```

### 5.4 QuickActions Tests — `smart-apply-web/test/components/quick-actions.spec.tsx`

```
Suite: QuickActions
Test File: smart-apply-web/test/components/quick-actions.spec.tsx
Mocks Required: next/link

Cases:
  - it("renders 4 action buttons")
    → assert 4 buttons visible

  - it("'Optimize a New Job' links to /optimize")
    → assert link href

  - it("'Edit Profile' links to /profile")
    → assert link href

  - it("'Settings' links to /settings")
    → assert link href

  - it("all buttons are keyboard-focusable")
    → tab through buttons, assert focus on each
```

### 5.5 ProfileCompleteness Tests — `smart-apply-web/test/components/profile-completeness.spec.tsx`

```
Suite: ProfileCompleteness
Test File: smart-apply-web/test/components/profile-completeness.spec.tsx
Mocks Required: @smart-apply/shared (calculateProfileCompleteness can be real or mocked)

Cases:
  - it("shows 0% for null profile")
    → render with profile=null
    → assert '0%' visible

  - it("shows 100% for complete profile with 'complete' message")
    → render with full profile
    → assert '100%' and 'complete' text

  - it("shows missing sections as links to /profile")
    → render with partial profile
    → assert missing section names visible as links

  - it("progress bar has correct aria attributes")
    → assert role='progressbar', aria-valuenow, aria-valuemin=0, aria-valuemax=100
```

### 5.6 PipelineView Tests — `smart-apply-web/test/components/pipeline-view.spec.tsx`

```
Suite: PipelineView
Test File: smart-apply-web/test/components/pipeline-view.spec.tsx
Mocks Required: none (pure component with callback)

Cases:
  - it("renders status columns: applied, interviewing, offer, rejected, withdrawn")
    → render with empty items
    → assert 5 column headers visible

  - it("groups applications by status into correct columns")
    → render with items: [{status:'applied'}, {status:'interviewing'}, {status:'rejected'}]
    → assert each column has correct count

  - it("renders application card with company, job title, ATS score")
    → assert card content matches item data

  - it("status dropdown calls onStatusChange with correct args")
    → change dropdown value
    → assert onStatusChange(id, newStatus) called

  - it("groups draft/generated items into applied column")
    → render with item.status='generated'
    → assert item appears in 'applied' column

  - it("status select has accessible aria-label")
    → assert aria-label contains company and job title
```

### 5.7 Optimize Results Save Tests — `smart-apply-web/test/components/optimize-results-save.spec.tsx`

```
Suite: OptimizeResults Application Save
Test File: smart-apply-web/test/components/optimize-results-save.spec.tsx
Mocks Required: @clerk/nextjs (useAuth), global.fetch, @tanstack/react-query, pdf-lib

Cases:
  - it("calls POST /api/applications after successful PDF download")
    → mock PDF generation success
    → click 'Download Optimized PDF'
    → assert fetch called with POST /api/applications

  - it("includes correct payload in save request")
    → assert body contains company_name, job_title, ats_score_before, ats_score_after, status='generated'

  - it("shows success toast after save")
    → mock successful POST
    → assert success message visible

  - it("shows error toast when save fails but PDF still downloads")
    → mock POST to reject
    → assert PDF download still triggered
    → assert error message visible
```

---

## 6. Component Design (UI Files)

### 6.1 OnboardingChecklist

```
Component: OnboardingChecklist
File: smart-apply-web/src/components/dashboard/onboarding-checklist.tsx
Props: OnboardingChecklistProps { profile, applicationsCount }
State:
  - dismissed: boolean (initialized from localStorage)
Effects: None
Children: Card, CardContent, CardHeader, CardTitle (shadcn), Link (next/link), CheckCircle/Circle icons
Accessibility:
  - <ul role="list"> for checklist items
  - Completed items show checkmark icon + sr-only "Completed" text
  - Links are descriptive ("Go to Profile page")
  - Dismiss button: type="button", aria-label="Dismiss onboarding checklist"
```

### 6.2 QuickActions

```
Component: QuickActions
File: smart-apply-web/src/components/dashboard/quick-actions.tsx
Props: None
State: None
Effects: None
Children: Button (shadcn), Link (next/link)
Accessibility:
  - Grid uses role="navigation" aria-label="Quick actions"
  - Each button has visible label and focus indicator (shadcn default)
```

### 6.3 ProfileCompleteness

```
Component: ProfileCompleteness
File: smart-apply-web/src/components/dashboard/profile-completeness.tsx
Props: ProfileCompletenessProps { profile }
State: None
Effects: None
Children: Card (shadcn), Link (next/link)
Accessibility:
  - Progress bar: <div role="progressbar" aria-valuenow={score} aria-valuemin={0} aria-valuemax={100}>
  - Missing section links are descriptive
```

### 6.4 PipelineView

```
Component: PipelineView
File: smart-apply-web/src/components/dashboard/pipeline-view.tsx
Props: PipelineViewProps { items, onStatusChange }
State: None (stateless — parent handles mutation)
Effects: None
Children: Card (shadcn), Badge, native <select>
Accessibility:
  - Columns: role="group" aria-label="{Status} applications"
  - Status select: aria-label="Change status for {company} - {jobTitle}"
  - Responsive: horizontal scroll on desktop, stacked on mobile (Tailwind responsive grid)
```

---

## 7. Integration Sequence

### Order of Implementation

1. **smart-apply-shared**: `profile-completeness.ts` + tests → verify with `npm -w @smart-apply/shared test`
2. **smart-apply-extension/manifest.ts**: Add permissions → verify build: `npm -w @smart-apply/extension build`
3. **smart-apply-extension/service-worker.ts**: Add injection logic, listeners, JD_PAGE_DETECTED handler → tests
4. **smart-apply-extension/jd-detector.ts**: Add JD_PAGE_DETECTED message → verify build
5. **smart-apply-extension/popup/App.tsx**: Add toggle → manual test
6. **smart-apply-web/components/dashboard/quick-actions.tsx**: Simplest widget, no data deps → tests
7. **smart-apply-web/components/dashboard/onboarding-checklist.tsx**: Depends on profile + count → tests
8. **smart-apply-web/components/dashboard/profile-completeness.tsx**: Depends on shared function → tests
9. **smart-apply-web/components/dashboard/pipeline-view.tsx**: Most complex widget → tests
10. **smart-apply-web/components/dashboard/dashboard-shell.tsx**: Integrate all widgets → verify compound behavior
11. **smart-apply-web/components/optimize/optimize-results.tsx**: Add save logic → tests

### Build Verification at Each Stage

After each group:
- `npm -w @smart-apply/shared run build && npm -w @smart-apply/shared test` (after step 1)
- `npm -w @smart-apply/extension run build` (after steps 2–5)
- `npm -w @smart-apply/extension test` (after step 3)
- `npm -w @smart-apply/web test` (after each web component step)
- `npm -w @smart-apply/web run build` (after step 11 — final)

---

## 8. Alignment Checklist

- [x] All API inputs validated with Zod at boundaries — existing endpoints already validate; no new endpoints
- [x] Loading, error, empty states handled in UI — OnboardingChecklist handles null profile; ProfileCompleteness handles 0%; PipelineView handles empty columns; DashboardShell has existing loading/error states
- [x] No secrets in client bundles — no new secrets introduced; extension uses chrome.storage for toggle
- [x] Existing design-system components used where possible — shadcn Card, Button, Badge, Link used throughout
- [x] TypeScript strict mode compatibility verified — all new code uses strict types
- [x] architecture.md principles not violated — client-first processing preserved (completeness calc in shared, PDF in browser); zero storage preserved; explicit user approval maintained (toggle is opt-in)

---

## End of LLD-MVP-P06
