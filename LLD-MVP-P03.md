# LLD-MVP-P03 — P2 Could-Have Enhancements

**Version:** 1.0  
**Date:** 2026-03-28  
**Input:** HLD-MVP-P03.md + architecture.md  
**Phase:** P2 (Could-Have)

---

## 1. File-Level Change Manifest

| # | File Path | Action | REQ | Purpose |
|:--|:---|:---|:---|:---|
| 1 | `smart-apply-extension/src/content/dom-utils.ts` | MODIFY | REQ-01-16 | Expand registry, add version field, add `reportSelectorFailure()` |
| 2 | `smart-apply-extension/src/content/linkedin-profile.ts` | MODIFY | REQ-01-16 | Migrate to `queryWithFallback()` |
| 3 | `smart-apply-extension/src/content/jd-detector.ts` | MODIFY | REQ-01-16 | Migrate to `queryWithFallback()` |
| 4 | `smart-apply-extension/src/content/autofill.ts` | MODIFY | REQ-01-12,16 | Extended field map, Easy Apply modal, file upload, clipboard fallback, registry selectors |
| 5 | `smart-apply-extension/src/lib/storage.ts` | MODIFY | REQ-01-12 | Add `last_pdf_bytes` to StorageSchema |
| 6 | `smart-apply-extension/src/ui/popup/App.tsx` | MODIFY | REQ-01-12 | Cache PDF bytes after generation |
| 7 | `smart-apply-extension/src/background/service-worker.ts` | MODIFY | REQ-01-12,16 | Add SELECTOR_FAILURE handler, enhance AUTOFILL handler |
| 8 | `smart-apply-web/src/app/optimize/page.tsx` | CREATE | REQ-01-13 | Web optimize route page |
| 9 | `smart-apply-web/src/components/optimize/optimize-form.tsx` | CREATE | REQ-01-13 | JD input form |
| 10 | `smart-apply-web/src/components/optimize/optimize-results.tsx` | CREATE | REQ-01-13 | ATS scores + suggested changes + PDF download |
| 11 | `smart-apply-web/src/app/settings/page.tsx` | CREATE | REQ-01-14 | Settings route page |
| 12 | `smart-apply-web/src/components/settings/settings-page.tsx` | CREATE | REQ-01-14 | Account info + integrations + deletion |
| 13 | `smart-apply-backend/src/modules/account/account.module.ts` | CREATE | REQ-01-14 | NestJS module for account operations |
| 14 | `smart-apply-backend/src/modules/account/account.controller.ts` | CREATE | REQ-01-14 | DELETE /api/account endpoint |
| 15 | `smart-apply-backend/src/modules/account/account.service.ts` | CREATE | REQ-01-14 | Clerk user deletion logic |
| 16 | `smart-apply-backend/src/app.module.ts` | MODIFY | REQ-01-14 | Register AccountModule |
| 17 | `smart-apply-web/src/components/profile/profile-upload.tsx` | CREATE | REQ-01-15 | File upload + paste textarea component |
| 18 | `smart-apply-web/src/app/profile/page.tsx` | MODIFY | REQ-01-15 | Add ProfileUpload component |

---

## 2. Detailed Design Per File

### 2.1 DOM Selector Hardening (REQ-01-16)

#### File 1: `smart-apply-extension/src/content/dom-utils.ts` — MODIFY

**Changes:**
1. Add `version` field to `SelectorEntry` interface.
2. Expand registry from 3 entries to 12+ entries covering all hardcoded selectors.
3. Add `reportSelectorFailure()` function.
4. Add `queryAllWithFallback()` for multi-element queries.

```typescript
export interface SelectorEntry {
  primary: string;
  fallbacks: string[];
  version: number;
}

const SELECTOR_REGISTRY: Record<string, SelectorEntry> = {
  // LinkedIn profile
  'linkedin.profile.main': {
    primary: 'main.scaffold-layout__main',
    fallbacks: ['main', '#main-content'],
    version: 1,
  },
  // LinkedIn JD
  'linkedin.jd.content': {
    primary: '.jobs-description__content',
    fallbacks: ['.jobs-description', '[class*="description"]'],
    version: 1,
  },
  'linkedin.jd.company': {
    primary: '.job-details-jobs-unified-top-card__company-name',
    fallbacks: ['.jobs-unified-top-card__company-name', '[class*="company-name"]'],
    version: 1,
  },
  'linkedin.jd.title': {
    primary: '.job-details-jobs-unified-top-card__job-title',
    fallbacks: ['.jobs-unified-top-card__job-title', 'h1[class*="job-title"]'],
    version: 1,
  },
  // LinkedIn Easy Apply modal
  'linkedin.easyapply.modal': {
    primary: '.jobs-easy-apply-modal',
    fallbacks: ['[class*="easy-apply"]', '[aria-label*="Easy Apply"]'],
    version: 1,
  },
  'linkedin.easyapply.file-input': {
    primary: 'input[type="file"][name*="resume"]',
    fallbacks: ['input[type="file"]', '.jobs-document-upload input[type="file"]'],
    version: 1,
  },
  // Indeed JD
  'indeed.jd.content': {
    primary: '#jobDescriptionText',
    fallbacks: ['.jobsearch-jobDescriptionText'],
    version: 1,
  },
  'indeed.jd.company': {
    primary: '[data-company-name]',
    fallbacks: ['.jobsearch-InlineCompanyRating-companyHeader'],
    version: 1,
  },
  'indeed.jd.title': {
    primary: '.jobsearch-JobInfoHeader-title',
    fallbacks: ['h1.jobsearch-JobInfoHeader-title', 'h1[class*="JobInfo"]'],
    version: 1,
  },
  // Form autofill
  'form.inputs': {
    primary: 'input:not([type="hidden"]):not([type="submit"]), textarea, select',
    fallbacks: ['input, textarea, select'],
    version: 1,
  },
};

export function queryWithFallback(registryKey: string): Element | null {
  const entry = SELECTOR_REGISTRY[registryKey];
  if (!entry) return null;

  const primary = document.querySelector(entry.primary);
  if (primary) return primary;

  for (const fallback of entry.fallbacks) {
    const el = document.querySelector(fallback);
    if (el) {
      reportSelectorFailure(registryKey, entry.primary, fallback);
      return el;
    }
  }

  reportSelectorFailure(registryKey, entry.primary, null);
  return null;
}

export function queryAllWithFallback(registryKey: string): Element[] {
  const entry = SELECTOR_REGISTRY[registryKey];
  if (!entry) return [];

  const primary = document.querySelectorAll(entry.primary);
  if (primary.length > 0) return Array.from(primary);

  for (const fallback of entry.fallbacks) {
    const els = document.querySelectorAll(fallback);
    if (els.length > 0) {
      reportSelectorFailure(registryKey, entry.primary, fallback);
      return Array.from(els);
    }
  }

  reportSelectorFailure(registryKey, entry.primary, null);
  return [];
}

function reportSelectorFailure(
  key: string,
  failedSelector: string,
  usedFallback: string | null,
): void {
  try {
    const entry = SELECTOR_REGISTRY[key];
    chrome.runtime.sendMessage({
      type: 'SELECTOR_FAILURE',
      payload: {
        key,
        failedSelector,
        usedFallback,
        hostname: window.location.hostname,
        timestamp: new Date().toISOString(),
        version: entry?.version ?? 0,
      },
    });
  } catch {
    // Content script may be disconnected; fail silently
  }
}

export function getRegistryVersion(key: string): number {
  return SELECTOR_REGISTRY[key]?.version ?? 0;
}
```

#### File 2: `smart-apply-extension/src/content/linkedin-profile.ts` — MODIFY

**Changes:** Replace hardcoded `document.querySelector('main.scaffold-layout__main')` with `queryWithFallback()`.

```typescript
import { queryWithFallback } from './dom-utils';

function extractProfileText(): string | null {
  const mainSection = queryWithFallback('linkedin.profile.main');
  return mainSection?.textContent?.trim() ?? null;
}
```

Rest of the file stays the same.

#### File 3: `smart-apply-extension/src/content/jd-detector.ts` — MODIFY

**Changes:** Replace all hardcoded selectors with `queryWithFallback()`.

```typescript
import { queryWithFallback } from './dom-utils';

function extractJDText(): string | null {
  const linkedInJD = queryWithFallback('linkedin.jd.content');
  if (linkedInJD) return linkedInJD.textContent?.trim() ?? null;

  const indeedJD = queryWithFallback('indeed.jd.content');
  if (indeedJD) return indeedJD.textContent?.trim() ?? null;

  return null;
}

function extractJobMeta(): { company: string; jobTitle: string } {
  // LinkedIn
  const linkedInCompany = queryWithFallback('linkedin.jd.company');
  const linkedInTitle = queryWithFallback('linkedin.jd.title');

  if (linkedInCompany && linkedInTitle) {
    return {
      company: linkedInCompany.textContent?.trim() ?? '',
      jobTitle: linkedInTitle.textContent?.trim() ?? '',
    };
  }

  // Indeed
  const indeedCompany = queryWithFallback('indeed.jd.company');
  const indeedTitle = queryWithFallback('indeed.jd.title');

  return {
    company: indeedCompany?.textContent?.trim() ?? '',
    jobTitle: indeedTitle?.textContent?.trim() ?? '',
  };
}
```

Rest of the file (URL detection functions, button injection, listeners) stays the same.

---

### 2.2 Extended Autofill (REQ-01-12)

#### File 4: `smart-apply-extension/src/content/autofill.ts` — MODIFY

**Major changes:**
1. Expand `fieldMap` from 4 to 13 fields.
2. Add LinkedIn Easy Apply modal detection via `MutationObserver`.
3. Add resume file upload via `DataTransfer` API.
4. Add clipboard fallback buttons for unsupported fields.
5. Use registry selectors for form inputs.

```typescript
import { queryWithFallback } from './dom-utils';

type FieldMapping = Record<string, string>;

function setNativeValue(element: HTMLInputElement | HTMLTextAreaElement, value: string): void {
  // ... existing implementation unchanged ...
}

function findFieldByHeuristic(
  keywords: string[],
): HTMLInputElement | HTMLTextAreaElement | null {
  // ... existing implementation unchanged ...
}

const FIELD_MAP: Record<string, string[]> = {
  full_name: ['name', 'full name', 'first name', 'your name'],
  email: ['email', 'e-mail'],
  phone: ['phone', 'mobile', 'telephone'],
  location: ['city', 'location', 'address'],
  summary: ['summary', 'about', 'objective', 'professional summary', 'cover letter'],
  skills: ['skills', 'expertise', 'competencies'],
  current_title: ['current title', 'job title', 'current role', 'headline'],
  years_experience: ['years of experience', 'years experience', 'experience years'],
  linkedin_url: ['linkedin', 'linkedin url', 'linkedin profile'],
  portfolio_url: ['portfolio', 'website', 'personal website', 'github'],
  education: ['education', 'school', 'university', 'degree', 'college'],
  work_experience: ['work experience', 'employment', 'work history'],
  cover_letter: ['cover letter', 'letter', 'why this role'],
};

function autofillForm(data: FieldMapping): {
  filled: string[];
  failed: string[];
  clipboard: string[];
} {
  const filled: string[] = [];
  const failed: string[] = [];
  const clipboard: string[] = [];

  for (const [field, keywords] of Object.entries(FIELD_MAP)) {
    const value = data[field];
    if (!value) continue;

    const input = findFieldByHeuristic(keywords);
    if (input) {
      setNativeValue(input, value);
      filled.push(field);
    } else {
      failed.push(field);
      clipboard.push(field);
    }
  }

  // Inject clipboard copy buttons for failed fields
  if (clipboard.length > 0) {
    injectClipboardButtons(data, clipboard);
  }

  return { filled, failed, clipboard };
}

function injectClipboardButtons(data: FieldMapping, fields: string[]): void {
  // Remove any existing clipboard buttons
  document.querySelectorAll('.smart-apply-clipboard-btn').forEach((el) => el.remove());

  const container = document.createElement('div');
  container.className = 'smart-apply-clipboard-btn';
  container.style.cssText =
    'position:fixed;bottom:120px;right:20px;z-index:9999;background:#fff;border:1px solid #e5e7eb;border-radius:8px;padding:8px;max-height:200px;overflow-y:auto;box-shadow:0 2px 8px rgba(0,0,0,0.1);';

  const title = document.createElement('p');
  title.textContent = 'Copy to fill manually:';
  title.style.cssText = 'font-size:11px;color:#6b7280;margin:0 0 4px 0;';
  container.appendChild(title);

  for (const field of fields) {
    const value = data[field];
    if (!value) continue;

    const btn = document.createElement('button');
    btn.textContent = `📋 ${field.replace('_', ' ')}`;
    btn.style.cssText =
      'display:block;width:100%;text-align:left;padding:4px 8px;margin:2px 0;background:#f9fafb;border:1px solid #e5e7eb;border-radius:4px;cursor:pointer;font-size:12px;';
    btn.addEventListener('click', () => {
      navigator.clipboard.writeText(value);
      btn.textContent = `✓ Copied!`;
      setTimeout(() => {
        btn.textContent = `📋 ${field.replace('_', ' ')}`;
      }, 1500);
    });
    container.appendChild(btn);
  }

  document.body.appendChild(container);
}

/** Attempt to attach a file to a file input (LinkedIn Easy Apply resume upload) */
async function attachResumeFile(): Promise<boolean> {
  const fileInput = queryWithFallback('linkedin.easyapply.file-input') as HTMLInputElement | null;
  if (!fileInput || fileInput.type !== 'file') return false;

  try {
    // Get cached PDF bytes from last generation
    const result = await new Promise<{ last_pdf_bytes?: string }>((resolve) => {
      chrome.storage.local.get('last_pdf_bytes', resolve);
    });

    if (!result.last_pdf_bytes) return false;

    // Decode base64 to binary
    const binaryStr = atob(result.last_pdf_bytes);
    const bytes = new Uint8Array(binaryStr.length);
    for (let i = 0; i < binaryStr.length; i++) {
      bytes[i] = binaryStr.charCodeAt(i);
    }

    const file = new File([bytes], 'resume.pdf', { type: 'application/pdf' });
    const dataTransfer = new DataTransfer();
    dataTransfer.items.add(file);
    fileInput.files = dataTransfer.files;
    fileInput.dispatchEvent(new Event('change', { bubbles: true }));
    return true;
  } catch {
    return false;
  }
}

/** Watch for LinkedIn Easy Apply modal step changes */
function observeEasyApplyModal(): void {
  const observer = new MutationObserver((mutations) => {
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (!(node instanceof HTMLElement)) continue;
        if (
          node.matches?.('.jobs-easy-apply-modal') ||
          node.querySelector?.('.jobs-easy-apply-modal')
        ) {
          // Modal appeared or step changed — trigger autofill
          setTimeout(() => {
            chrome.runtime.sendMessage({ type: 'AUTOFILL', payload: {} });
          }, 300); // Small delay for DOM to settle
        }
      }
    }
  });

  observer.observe(document.body, { childList: true, subtree: true });
}

function injectAutofillButton(): void {
  // ... existing implementation unchanged ...
}

// Listen for autofill data from background
chrome.runtime.onMessage.addListener(
  (message: { type: string; payload?: FieldMapping }) => {
    if (message.type === 'DO_AUTOFILL' && message.payload) {
      const result = autofillForm(message.payload);
      console.log('Smart Apply autofill result:', result);
      // Also attempt resume file attachment
      attachResumeFile().then((attached) => {
        if (attached) console.log('Smart Apply: Resume file attached');
      });
    }
  },
);

// Start Easy Apply modal observer on LinkedIn pages
if (window.location.hostname.includes('linkedin.com')) {
  observeEasyApplyModal();
}
```

#### File 5: `smart-apply-extension/src/lib/storage.ts` — MODIFY

**Change:** Add `last_pdf_bytes` key to `StorageSchema`.

Add to `StorageSchema` interface:
```typescript
last_pdf_bytes: string; // base64-encoded PDF bytes
```

#### File 6: `smart-apply-extension/src/ui/popup/App.tsx` — MODIFY

**Change:** After PDF generation, cache the base64-encoded PDF bytes in storage.

In `handleGeneratePdf`, after the `generateResumePDF()` call:
```typescript
// Cache PDF bytes for autofill resume upload (base64 for storage)
const base64 = btoa(String.fromCharCode(...new Uint8Array(pdfBytes as ArrayBuffer)));
chrome.storage.local.set({ last_pdf_bytes: base64 });
```

#### File 7: `smart-apply-extension/src/background/service-worker.ts` — MODIFY

**Changes:**
1. Add `SELECTOR_FAILURE` case to message listener (log structured event).
2. Enhance `handleAutofill` to send expanded profile data.

Add to `MessageType` union:
```typescript
| { type: 'SELECTOR_FAILURE'; payload: { key: string; failedSelector: string; usedFallback: string | null; hostname: string; timestamp: string; version: number } }
```

Add case in switch:
```typescript
case 'SELECTOR_FAILURE':
  console.warn('[Smart Apply Selector Failure]', JSON.stringify(message.payload));
  break;
```

Enhance `handleAutofill` to include additional profile fields:
```typescript
async function handleAutofill(tabId?: number) {
  if (!tabId) return { success: false, error: 'No active tab' };
  const profile = await getStorage('cached_profile');
  if (!profile) return { success: false, error: 'No cached profile' };

  const autofillData: Record<string, string> = {
    full_name: (profile.full_name as string) ?? '',
    email: (profile.email as string) ?? '',
    phone: (profile.phone as string) ?? '',
    location: (profile.location as string) ?? '',
    summary: (profile.summary as string) ?? '',
    skills: ((profile.base_skills as string[]) ?? []).join(', '),
    current_title: '',
    linkedin_url: (profile.linkedin_url as string) ?? '',
    portfolio_url: (profile.portfolio_url as string) ?? '',
  };

  // Derive current title from most recent experience
  const experiences = (profile.experiences as Array<{ role?: string }>) ?? [];
  if (experiences.length > 0 && experiences[0].role) {
    autofillData.current_title = experiences[0].role;
  }

  chrome.tabs.sendMessage(tabId, { type: 'DO_AUTOFILL', payload: autofillData });
  return { success: true };
}
```

---

### 2.3 Web-Based Optimise Flow (REQ-01-13)

#### File 8: `smart-apply-web/src/app/optimize/page.tsx` — CREATE

```typescript
import { auth } from '@clerk/nextjs/server';
import { redirect } from 'next/navigation';
import { OptimizeForm } from '@/components/optimize/optimize-form';

export const dynamic = 'force-dynamic';

export default async function OptimizePage() {
  const { userId } = await auth();
  if (!userId) redirect('/sign-in');

  return (
    <main className="container mx-auto max-w-4xl py-8 px-4">
      <h1 className="mb-6 text-3xl font-bold">Optimize Resume</h1>
      <p className="mb-6 text-gray-600">
        Paste a job description below to optimize your resume for ATS compatibility.
      </p>
      <OptimizeForm />
    </main>
  );
}
```

#### File 9: `smart-apply-web/src/components/optimize/optimize-form.tsx` — CREATE

Client component with:
- JD textarea (required, min 50 chars)
- Company name input (required)
- Job title input (required)
- Source platform select (optional, defaults to 'other')
- Source URL input (optional)
- Submit button with loading state
- On success, renders `<OptimizeResults>`

```typescript
'use client';

import { useState } from 'react';
import { useAuth } from '@clerk/nextjs';
import { apiFetch } from '@/lib/api-client';
import type { OptimizeResponse } from '@smart-apply/shared';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { OptimizeResults } from './optimize-results';

export function OptimizeForm() {
  const { getToken } = useAuth();
  const [jdText, setJdText] = useState('');
  const [companyName, setCompanyName] = useState('');
  const [jobTitle, setJobTitle] = useState('');
  const [sourcePlatform, setSourcePlatform] = useState('other');
  const [sourceUrl, setSourceUrl] = useState('');
  const [status, setStatus] = useState<'idle' | 'loading' | 'success' | 'error'>('idle');
  const [result, setResult] = useState<OptimizeResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (jdText.length < 50) return;

    setStatus('loading');
    setError(null);
    try {
      const token = await getToken();
      if (!token) throw new Error('Not authenticated');
      const response = await apiFetch<OptimizeResponse>('/api/optimize', token, {
        method: 'POST',
        body: JSON.stringify({
          job_description_text: jdText,
          job_title: jobTitle,
          company_name: companyName,
          source_platform: sourcePlatform,
          source_url: sourceUrl || null,
        }),
      });
      setResult(response);
      setStatus('success');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Optimization failed');
      setStatus('error');
    }
  };

  if (status === 'success' && result) {
    return (
      <OptimizeResults
        result={result}
        companyName={companyName}
        onBack={() => { setStatus('idle'); setResult(null); }}
      />
    );
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Job Details</CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <div>
              <Label htmlFor="company">Company Name</Label>
              <Input id="company" value={companyName} onChange={(e) => setCompanyName(e.target.value)} required />
            </div>
            <div>
              <Label htmlFor="title">Job Title</Label>
              <Input id="title" value={jobTitle} onChange={(e) => setJobTitle(e.target.value)} required />
            </div>
          </div>
          <div>
            <Label htmlFor="jd">Job Description</Label>
            <Textarea
              id="jd"
              value={jdText}
              onChange={(e) => setJdText(e.target.value)}
              placeholder="Paste the full job description here..."
              rows={12}
              required
              minLength={50}
            />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <Label htmlFor="platform">Source Platform</Label>
              <select
                id="platform"
                value={sourcePlatform}
                onChange={(e) => setSourcePlatform(e.target.value)}
                className="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm"
              >
                <option value="other">Other</option>
                <option value="linkedin">LinkedIn</option>
                <option value="indeed">Indeed</option>
              </select>
            </div>
            <div>
              <Label htmlFor="url">Source URL (optional)</Label>
              <Input id="url" value={sourceUrl} onChange={(e) => setSourceUrl(e.target.value)} type="url" />
            </div>
          </div>
          {error && (
            <div className="rounded-md bg-red-50 border border-red-200 p-3 text-sm text-red-800">
              {error}
            </div>
          )}
          <Button type="submit" disabled={status === 'loading' || jdText.length < 50}>
            {status === 'loading' ? 'Optimizing...' : 'Optimize Resume'}
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}
```

#### File 10: `smart-apply-web/src/components/optimize/optimize-results.tsx` — CREATE

Client component mirroring extension popup results UI but for web:
- ATS score before/after bars
- Toggleable suggested changes list
- "Download PDF" button (using pdf-lib in-browser)
- "Back" button to return to form

```typescript
'use client';

import { useState, useCallback } from 'react';
import { useAuth } from '@clerk/nextjs';
import { useQuery } from '@tanstack/react-query';
import { apiFetch } from '@/lib/api-client';
import type { OptimizeResponse, SuggestedChange, MasterProfile, ExperienceItem } from '@smart-apply/shared';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';

interface OptimizeResultsProps {
  result: OptimizeResponse;
  companyName: string;
  onBack: () => void;
}

function buildApprovedResume(
  profile: MasterProfile,
  result: OptimizeResponse,
  selectedChanges: Set<number>,
): { summary: string; skills: string[]; experiences: ExperienceItem[] } {
  let summary = profile.summary ?? '';
  let skills = [...(profile.base_skills ?? [])];
  const experiences: ExperienceItem[] = JSON.parse(JSON.stringify(profile.experiences ?? []));

  result.suggested_changes.forEach((change, index) => {
    if (!selectedChanges.has(index)) return;
    switch (change.type) {
      case 'summary_update':
        if (change.after) summary = change.after;
        break;
      case 'skills_insertion':
        if (change.after) {
          const newSkills = change.after.split(', ').filter(Boolean);
          skills = [...new Set([...skills, ...newSkills])];
        }
        break;
      case 'bullet_injection':
        for (const exp of experiences) {
          const bulletIdx = exp.description.findIndex((b) => b === change.before);
          if (bulletIdx !== -1 && change.after) {
            exp.description[bulletIdx] = change.after;
            break;
          }
        }
        break;
    }
  });
  return { summary, skills, experiences };
}

export function OptimizeResults({ result, companyName, onBack }: OptimizeResultsProps) {
  const { getToken } = useAuth();
  const [selectedChanges, setSelectedChanges] = useState<Set<number>>(() => {
    const defaults = new Set<number>();
    result.suggested_changes.forEach((c, i) => {
      if (c.confidence !== null && c.confidence >= 0.6) defaults.add(i);
    });
    return defaults;
  });
  const [generatingPdf, setGeneratingPdf] = useState(false);

  const { data: profile } = useQuery({
    queryKey: ['profile'],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error('Not authenticated');
      return apiFetch<MasterProfile>('/api/profile/me', token);
    },
  });

  const toggleChange = useCallback((index: number) => {
    setSelectedChanges((prev) => {
      const next = new Set(prev);
      if (next.has(index)) next.delete(index);
      else next.add(index);
      return next;
    });
  }, []);

  const handleDownloadPdf = useCallback(async () => {
    if (!profile) return;
    setGeneratingPdf(true);
    try {
      // Dynamic import for code splitting
      const { PDFDocument, StandardFonts, rgb } = await import('pdf-lib');
      const approved = buildApprovedResume(profile, result, selectedChanges);

      const pdfDoc = await PDFDocument.create();
      const font = await pdfDoc.embedFont(StandardFonts.Helvetica);
      const boldFont = await pdfDoc.embedFont(StandardFonts.HelveticaBold);
      const page = pdfDoc.addPage([612, 792]); // Letter size

      let y = 750;
      const margin = 50;
      const lineHeight = 14;

      // Name
      page.drawText(profile.full_name ?? '', { x: margin, y, font: boldFont, size: 18 });
      y -= 22;
      // Contact line
      const contact = [profile.email, profile.phone, profile.location].filter(Boolean).join(' | ');
      page.drawText(contact, { x: margin, y, font, size: 9, color: rgb(0.4, 0.4, 0.4) });
      y -= 20;

      // Summary
      if (approved.summary) {
        page.drawText('SUMMARY', { x: margin, y, font: boldFont, size: 11 });
        y -= lineHeight;
        // Simple word-wrap for summary
        const words = approved.summary.split(' ');
        let line = '';
        for (const word of words) {
          const test = line ? `${line} ${word}` : word;
          if (font.widthOfTextAtSize(test, 10) > 512) {
            page.drawText(line, { x: margin, y, font, size: 10 });
            y -= lineHeight;
            line = word;
          } else {
            line = test;
          }
        }
        if (line) { page.drawText(line, { x: margin, y, font, size: 10 }); y -= lineHeight; }
        y -= 8;
      }

      // Skills
      if (approved.skills.length > 0) {
        page.drawText('SKILLS', { x: margin, y, font: boldFont, size: 11 });
        y -= lineHeight;
        page.drawText(approved.skills.join(', '), { x: margin, y, font, size: 10 });
        y -= lineHeight + 8;
      }

      // Experience
      if (approved.experiences.length > 0) {
        page.drawText('EXPERIENCE', { x: margin, y, font: boldFont, size: 11 });
        y -= lineHeight;
        for (const exp of approved.experiences) {
          page.drawText(`${exp.role} — ${exp.company}`, { x: margin, y, font: boldFont, size: 10 });
          y -= lineHeight;
          const dates = [exp.start_date, exp.end_date].filter(Boolean).join(' – ');
          if (dates) { page.drawText(dates, { x: margin, y, font, size: 9, color: rgb(0.4, 0.4, 0.4) }); y -= lineHeight; }
          for (const bullet of exp.description) {
            page.drawText(`• ${bullet}`, { x: margin + 10, y, font, size: 9 });
            y -= lineHeight;
            if (y < 50) { /* Would need new page for production; MVP truncates */ break; }
          }
          y -= 6;
        }
      }

      const pdfBytes = await pdfDoc.save();
      const blob = new Blob([pdfBytes], { type: 'application/pdf' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `resume-${companyName}-${new Date().toISOString().slice(0, 10)}.pdf`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (err) {
      console.error('PDF generation failed:', err);
    } finally {
      setGeneratingPdf(false);
    }
  }, [profile, result, selectedChanges, companyName]);

  return (
    <div className="space-y-6">
      {/* ATS Score Comparison */}
      <Card>
        <CardHeader><CardTitle>ATS Score</CardTitle></CardHeader>
        <CardContent>
          <div className="flex items-center gap-6">
            <div className="flex-1">
              <p className="text-sm text-gray-500 mb-1">Before</p>
              <div className="relative h-5 bg-gray-200 rounded-full overflow-hidden">
                <div className="absolute h-full bg-red-400 rounded-full" style={{ width: `${result.ats_score_before}%` }} />
              </div>
              <p className="text-lg font-semibold mt-1">{result.ats_score_before}%</p>
            </div>
            <span className="text-2xl text-gray-400">→</span>
            <div className="flex-1">
              <p className="text-sm text-gray-500 mb-1">After</p>
              <div className="relative h-5 bg-gray-200 rounded-full overflow-hidden">
                <div className="absolute h-full bg-green-500 rounded-full" style={{ width: `${result.ats_score_after}%` }} />
              </div>
              <p className="text-lg font-semibold mt-1">{result.ats_score_after}%</p>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Suggested Changes */}
      <Card>
        <CardHeader><CardTitle>Suggested Changes</CardTitle></CardHeader>
        <CardContent className="space-y-3">
          {result.suggested_changes.map((change: SuggestedChange, i: number) => {
            if (change.type === 'warning') {
              return (
                <div key={i} className="p-3 bg-yellow-50 border border-yellow-200 rounded-md text-sm text-yellow-800">
                  ⚠️ {change.reason}
                </div>
              );
            }
            return (
              <label key={i} className="flex items-start gap-3 p-3 border rounded-lg cursor-pointer hover:bg-gray-50">
                <input type="checkbox" checked={selectedChanges.has(i)} onChange={() => toggleChange(i)} className="mt-1" />
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-1">
                    <Badge variant="outline" className="capitalize text-xs">{change.type.replace(/_/g, ' ')}</Badge>
                    {change.confidence !== null && (
                      <Badge variant={change.confidence >= 0.8 ? 'default' : 'secondary'} className="text-xs">
                        {Math.round(change.confidence * 100)}%
                      </Badge>
                    )}
                  </div>
                  <p className="text-sm text-gray-600">{change.reason}</p>
                  {change.before && <p className="text-sm line-through text-red-500 mt-1">{change.before}</p>}
                  {change.after && <p className="text-sm text-green-600 mt-1">{change.after}</p>}
                </div>
              </label>
            );
          })}
        </CardContent>
      </Card>

      {/* Actions */}
      <div className="flex gap-3">
        <Button onClick={handleDownloadPdf} disabled={generatingPdf || !profile}>
          {generatingPdf ? 'Generating PDF...' : 'Download Optimized PDF'}
        </Button>
        <Button variant="outline" onClick={onBack}>Back to Form</Button>
      </div>
    </div>
  );
}
```

**Dependency:** Add `pdf-lib` to `smart-apply-web/package.json`:
```
npm -w smart-apply-web install pdf-lib
```

---

### 2.4 Settings & Account Management (REQ-01-14)

#### File 11: `smart-apply-web/src/app/settings/page.tsx` — CREATE

```typescript
import { auth } from '@clerk/nextjs/server';
import { redirect } from 'next/navigation';
import { SettingsPage } from '@/components/settings/settings-page';

export const dynamic = 'force-dynamic';

export default async function Settings() {
  const { userId } = await auth();
  if (!userId) redirect('/sign-in');

  return (
    <main className="container mx-auto max-w-4xl py-8 px-4">
      <h1 className="mb-6 text-3xl font-bold">Settings</h1>
      <SettingsPage />
    </main>
  );
}
```

#### File 12: `smart-apply-web/src/components/settings/settings-page.tsx` — CREATE

Client component with three sections:
1. **Account Info** — Display from Clerk `useUser()`.
2. **Connected Integrations** — Google Drive status (extension-dependent CTA).
3. **Danger Zone** — Delete account with two-step confirmation.

```typescript
'use client';

import { useState } from 'react';
import { useUser, useAuth } from '@clerk/nextjs';
import { apiFetch } from '@/lib/api-client';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';

export function SettingsPage() {
  const { user } = useUser();
  const { getToken, signOut } = useAuth();
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [deleteInput, setDeleteInput] = useState('');
  const [deleteStatus, setDeleteStatus] = useState<'idle' | 'deleting' | 'error'>('idle');
  const [deleteError, setDeleteError] = useState<string | null>(null);

  const handleDeleteAccount = async () => {
    if (deleteInput !== 'DELETE') return;
    setDeleteStatus('deleting');
    setDeleteError(null);
    try {
      const token = await getToken();
      if (!token) throw new Error('Not authenticated');
      await apiFetch('/api/account', token, { method: 'DELETE' });
      await signOut();
    } catch (err) {
      setDeleteError(err instanceof Error ? err.message : 'Failed to delete account');
      setDeleteStatus('error');
    }
  };

  return (
    <div className="space-y-6">
      {/* Account Info */}
      <Card>
        <CardHeader><CardTitle>Account Information</CardTitle></CardHeader>
        <CardContent className="space-y-3">
          <div className="flex justify-between">
            <span className="text-sm text-gray-500">Name</span>
            <span className="text-sm font-medium">{user?.fullName ?? '—'}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-sm text-gray-500">Email</span>
            <span className="text-sm font-medium">{user?.primaryEmailAddress?.emailAddress ?? '—'}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-sm text-gray-500">Member since</span>
            <span className="text-sm font-medium">{user?.createdAt ? new Date(user.createdAt).toLocaleDateString() : '—'}</span>
          </div>
        </CardContent>
      </Card>

      {/* Connected Integrations */}
      <Card>
        <CardHeader><CardTitle>Connected Integrations</CardTitle></CardHeader>
        <CardContent className="space-y-3">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium">Google Drive</p>
              <p className="text-xs text-gray-500">Resume PDFs are uploaded via the browser extension</p>
            </div>
            <Badge variant="secondary">Extension Required</Badge>
          </div>
        </CardContent>
      </Card>

      {/* Danger Zone */}
      <Card className="border-red-200">
        <CardHeader><CardTitle className="text-red-600">Danger Zone</CardTitle></CardHeader>
        <CardContent>
          {!showDeleteConfirm ? (
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium">Delete Account</p>
                <p className="text-xs text-gray-500">
                  Permanently delete your account and all associated data. This action cannot be undone.
                </p>
              </div>
              <Button variant="outline" className="text-red-600 border-red-300 hover:bg-red-50"
                onClick={() => setShowDeleteConfirm(true)}>
                Delete Account
              </Button>
            </div>
          ) : (
            <div className="space-y-3">
              <p className="text-sm text-red-600">
                This will permanently delete your profile, application history, and all associated data.
                Type <strong>DELETE</strong> to confirm.
              </p>
              <Input
                value={deleteInput}
                onChange={(e) => setDeleteInput(e.target.value)}
                placeholder="Type DELETE to confirm"
                className="max-w-xs"
              />
              {deleteError && (
                <p className="text-sm text-red-600">{deleteError}</p>
              )}
              <div className="flex gap-2">
                <Button
                  variant="destructive"
                  disabled={deleteInput !== 'DELETE' || deleteStatus === 'deleting'}
                  onClick={handleDeleteAccount}
                >
                  {deleteStatus === 'deleting' ? 'Deleting...' : 'Permanently Delete Account'}
                </Button>
                <Button variant="outline" onClick={() => { setShowDeleteConfirm(false); setDeleteInput(''); }}>
                  Cancel
                </Button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
```

#### File 13: `smart-apply-backend/src/modules/account/account.module.ts` — CREATE

```typescript
import { Module } from '@nestjs/common';
import { AccountController } from './account.controller';
import { AccountService } from './account.service';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [AuthModule],
  controllers: [AccountController],
  providers: [AccountService],
})
export class AccountModule {}
```

#### File 14: `smart-apply-backend/src/modules/account/account.controller.ts` — CREATE

```typescript
import { Controller, Delete, UseGuards } from '@nestjs/common';
import { ClerkAuthGuard } from '../auth/clerk-auth.guard';
import { CurrentUserId } from '../auth/current-user.decorator';
import { AccountService } from './account.service';

@Controller('api/account')
export class AccountController {
  constructor(private readonly accountService: AccountService) {}

  @Delete()
  @UseGuards(ClerkAuthGuard)
  async deleteAccount(@CurrentUserId() userId: string) {
    await this.accountService.deleteAccount(userId);
    return { success: true };
  }
}
```

#### File 15: `smart-apply-backend/src/modules/account/account.service.ts` — CREATE

```typescript
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClerkClient } from '@clerk/backend';

@Injectable()
export class AccountService {
  private readonly clerkClient;

  constructor(private readonly config: ConfigService) {
    this.clerkClient = createClerkClient({
      secretKey: this.config.getOrThrow<string>('CLERK_SECRET_KEY'),
    });
  }

  async deleteAccount(clerkUserId: string): Promise<void> {
    // This triggers a user.deleted webhook event which the existing
    // WebhooksService handles for cascading data deletion.
    await this.clerkClient.users.deleteUser(clerkUserId);
  }
}
```

#### File 16: `smart-apply-backend/src/app.module.ts` — MODIFY

**Change:** Add `AccountModule` import.

```typescript
import { AccountModule } from './modules/account/account.module';

// In @Module imports array, add:
AccountModule,
```

---

### 2.5 Manual Profile Upload UI (REQ-01-15)

#### File 17: `smart-apply-web/src/components/profile/profile-upload.tsx` — CREATE

```typescript
'use client';

import { useState, useRef, useCallback } from 'react';
import { useAuth } from '@clerk/nextjs';
import { useQueryClient } from '@tanstack/react-query';
import { apiFetch } from '@/lib/api-client';
import type { ProfileIngestResponse } from '@smart-apply/shared';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';

const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB

export function ProfileUpload() {
  const { getToken } = useAuth();
  const queryClient = useQueryClient();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [mode, setMode] = useState<'idle' | 'paste' | 'uploading'>('idle');
  const [pasteText, setPasteText] = useState('');
  const [status, setStatus] = useState<'idle' | 'loading' | 'success' | 'error'>('idle');
  const [error, setError] = useState<string | null>(null);
  const [dragOver, setDragOver] = useState(false);

  const ingestProfile = useCallback(async (rawText: string, source: 'upload' | 'manual') => {
    setStatus('loading');
    setError(null);
    try {
      const token = await getToken();
      if (!token) throw new Error('Not authenticated');
      await apiFetch<ProfileIngestResponse>('/api/profile/ingest', token, {
        method: 'POST',
        body: JSON.stringify({ source, raw_text: rawText, overwrite: true }),
      });
      setStatus('success');
      setMode('idle');
      setPasteText('');
      queryClient.invalidateQueries({ queryKey: ['profile'] });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Upload failed');
      setStatus('error');
    }
  }, [getToken, queryClient]);

  const extractTextFromPdf = useCallback(async (file: File): Promise<string> => {
    const pdfjsLib = await import('pdfjs-dist');
    pdfjsLib.GlobalWorkerOptions.workerSrc = `https://cdnjs.cloudflare.com/ajax/libs/pdf.js/${pdfjsLib.version}/pdf.worker.min.mjs`;

    const arrayBuffer = await file.arrayBuffer();
    const pdf = await pdfjsLib.getDocument({ data: arrayBuffer }).promise;
    const textParts: string[] = [];

    for (let i = 1; i <= pdf.numPages; i++) {
      const page = await pdf.getPage(i);
      const content = await page.getTextContent();
      const pageText = content.items
        .map((item) => ('str' in item ? item.str : ''))
        .join(' ');
      textParts.push(pageText);
    }

    return textParts.join('\n');
  }, []);

  const handleFile = useCallback(async (file: File) => {
    if (file.size > MAX_FILE_SIZE) {
      setError('File size must be under 5MB');
      return;
    }

    setMode('uploading');
    try {
      let text: string;
      if (file.type === 'application/pdf') {
        text = await extractTextFromPdf(file);
      } else {
        text = await file.text();
      }

      if (text.trim().length < 10) {
        setError('Could not extract meaningful text from this file');
        setMode('idle');
        return;
      }

      await ingestProfile(text, 'upload');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to process file');
      setMode('idle');
    }
  }, [extractTextFromPdf, ingestProfile]);

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(false);
    const file = e.dataTransfer.files[0];
    if (file) handleFile(file);
  }, [handleFile]);

  const handlePasteSubmit = useCallback(async () => {
    if (pasteText.trim().length < 10) return;
    await ingestProfile(pasteText, 'manual');
  }, [pasteText, ingestProfile]);

  return (
    <Card>
      <CardHeader>
        <CardTitle>Import Profile</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {status === 'success' && (
          <div className="rounded-md bg-green-50 border border-green-200 p-3 text-sm text-green-800">
            Profile imported successfully! Review your profile below.
          </div>
        )}

        {error && (
          <div className="rounded-md bg-red-50 border border-red-200 p-3 text-sm text-red-800">
            {error}
          </div>
        )}

        {/* File upload / drag-and-drop */}
        <div
          onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
          onDragLeave={() => setDragOver(false)}
          onDrop={handleDrop}
          className={`border-2 border-dashed rounded-lg p-8 text-center transition-colors ${
            dragOver ? 'border-blue-400 bg-blue-50' : 'border-gray-300'
          }`}
        >
          <input
            ref={fileInputRef}
            type="file"
            accept=".pdf,.txt,.text"
            className="hidden"
            onChange={(e) => {
              const file = e.target.files?.[0];
              if (file) handleFile(file);
            }}
          />
          <p className="text-sm text-gray-600 mb-2">
            Drag and drop a resume file here, or
          </p>
          <Button
            variant="outline"
            disabled={status === 'loading'}
            onClick={() => fileInputRef.current?.click()}
          >
            Choose File (PDF or Text)
          </Button>
          <p className="text-xs text-gray-400 mt-2">Max 5MB</p>
        </div>

        {/* Divider */}
        <div className="relative">
          <div className="absolute inset-0 flex items-center">
            <div className="w-full border-t border-gray-200" />
          </div>
          <div className="relative flex justify-center text-sm">
            <span className="bg-white px-2 text-gray-500">or</span>
          </div>
        </div>

        {/* Paste text */}
        {mode === 'paste' ? (
          <div className="space-y-2">
            <Label htmlFor="paste-text">Paste resume text</Label>
            <Textarea
              id="paste-text"
              rows={8}
              value={pasteText}
              onChange={(e) => setPasteText(e.target.value)}
              placeholder="Paste your resume text here..."
            />
            <div className="flex gap-2">
              <Button
                disabled={pasteText.trim().length < 10 || status === 'loading'}
                onClick={handlePasteSubmit}
              >
                {status === 'loading' ? 'Importing...' : 'Import Text'}
              </Button>
              <Button variant="outline" onClick={() => { setMode('idle'); setPasteText(''); }}>
                Cancel
              </Button>
            </div>
          </div>
        ) : (
          <Button variant="outline" className="w-full" onClick={() => setMode('paste')}>
            Paste Resume Text
          </Button>
        )}

        {mode === 'uploading' && (
          <div className="flex items-center gap-2 text-sm text-gray-500">
            <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-gray-400" />
            Processing file...
          </div>
        )}
      </CardContent>
    </Card>
  );
}
```

**Dependency:** Add `pdfjs-dist` to `smart-apply-web/package.json`:
```
npm -w smart-apply-web install pdfjs-dist
```

#### File 18: `smart-apply-web/src/app/profile/page.tsx` — MODIFY

**Change:** Add `ProfileUpload` component above `ProfileEditor`.

```typescript
import { ProfileUpload } from '@/components/profile/profile-upload';

// In the return JSX, add before <ProfileEditor />:
<ProfileUpload />
<div className="mt-6" />
```

---

## 3. Dependency Summary

| Package | New Dependencies | Install Command |
|:---|:---|:---|
| `smart-apply-web` | `pdf-lib`, `pdfjs-dist` | `npm -w smart-apply-web install pdf-lib pdfjs-dist` |
| `smart-apply-backend` | `@clerk/backend` (may already be installed) | Verify with `npm ls @clerk/backend` |

---

## 4. Test Coverage

Backend tests to add/modify in `smart-apply-backend/test/`:

| Test File | Tests |
|:---|:---|
| `account.service.spec.ts` (CREATE) | 1. Calls `clerkClient.users.deleteUser` with correct userId 2. Propagates Clerk errors |

Frontend verification:
- `tsc --noEmit` for all 4 packages
- Manual verification: web optimize page form + results
- Manual verification: settings page with delete confirmation
- Manual verification: profile upload drag-and-drop + paste

---

## 5. Migration/Data Changes

No database migrations needed. All new functionality uses existing tables and endpoints.

---

## 6. Implementation Order

1. **REQ-01-16** — Selector hardening (Files 1–3, parts of 7)
2. **REQ-01-12** — Extended autofill (Files 4–7)
3. **REQ-01-15** — Profile upload UI (Files 17–18, install pdfjs-dist)
4. **REQ-01-14** — Settings & account (Files 11–16)
5. **REQ-01-13** — Web optimize flow (Files 8–10, install pdf-lib)
