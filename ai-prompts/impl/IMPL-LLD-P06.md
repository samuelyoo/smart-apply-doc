# IMPL-LLD-P06 — Cross-Site Autofill & Dashboard Enrichment

> **Phase:** P06 — Cross-Site Autofill Activation & Web Dashboard Enrichment
> **Source:** Approved LLD-MVP-P06.md
> **Target:** 17 files (6 create, 11 modify) + 7 new test files

---

## Context

### Project State

- **Monorepo root:** `/Users/syoo/Documents/code/smart-apply`
- **Workspace packages:** smart-apply-shared, smart-apply-backend, smart-apply-web, smart-apply-extension
- **Test framework:** Vitest across all packages; web uses jsdom + @testing-library/react; extension uses custom chrome-mock
- **UI library:** shadcn/ui (web), Tailwind CSS (web + extension)

### Existing Files to Read First

| File | Why |
|:---|:---|
| `smart-apply-shared/src/types/profile.ts` | MasterProfile type — input for `calculateProfileCompleteness` |
| `smart-apply-shared/src/types/application.ts` | ApplicationHistoryItem, ApplicationStatus, CreateApplicationRequest, APPLICATION_STATUSES |
| `smart-apply-shared/src/index.ts` | Export barrel — add new export |
| `smart-apply-extension/src/manifest.ts` | Add permissions |
| `smart-apply-extension/src/background/service-worker.ts` | Add injection logic + listeners |
| `smart-apply-extension/src/content/jd-detector.ts` | Add JD_PAGE_DETECTED message |
| `smart-apply-extension/src/content/autofill.ts` | Verify idempotency guard |
| `smart-apply-extension/src/ui/popup/App.tsx` | Add autofill toggle |
| `smart-apply-extension/test/chrome-mock.ts` | Extend with scripting + webNavigation mocks |
| `smart-apply-web/src/components/dashboard/dashboard-shell.tsx` | Integrate all new widgets |
| `smart-apply-web/src/components/optimize/optimize-results.tsx` | Add save-application logic |
| `smart-apply-web/src/components/optimize/optimize-form.tsx` | Pass jobTitle prop |
| `smart-apply-web/src/lib/api-client.ts` | apiFetch<T>(path, token, options?) |
| `smart-apply-web/test/setup.ts` | Test setup (imports jest-dom/vitest) |

### Shared Schemas to Import

From `@smart-apply/shared`:
- `MasterProfile`, `ExperienceItem`, `EducationItem`
- `ApplicationHistoryItem`, `ApplicationStatus`, `APPLICATION_STATUSES`
- `CreateApplicationRequest`, `CreateApplicationResponse`
- `ListApplicationsResponse`
- `OptimizeResponse`, `SuggestedChange`

### Key Signatures

```typescript
// smart-apply-web/src/lib/api-client.ts
export async function apiFetch<T>(path: string, token: string, options?: RequestInit): Promise<T>

// smart-apply-extension/src/lib/api-client.ts
export async function apiFetch<T>(path: string, init?: RequestInit): Promise<T>

// chrome-mock.ts helpers
export function resetChromeMock(): void
export function seedStorage(data: Record<string, unknown>): void
```

### What This Phase Builds

Two workstreams: (A) Extension cross-site autofill — toggle in popup, programmatic injection via `chrome.scripting.executeScript`, auto-activate on job-page-to-external-portal redirect; (B) Web dashboard enrichment — 4 new widgets (onboarding checklist, quick actions, profile completeness, pipeline view) + application save after web optimize PDF download.

---

## Step 1: Write Tests (TDD — Red Phase)

Write ALL test files BEFORE any implementation code. Run tests — they should all **FAIL** (Red phase).

### Pre-requisite: Extend chrome-mock.ts

**File:** `smart-apply-extension/test/chrome-mock.ts`
**Action:** MODIFY — add `scripting`, `webNavigation` mocks

After the existing `downloads` mock and before `Object.defineProperty`, add:

```typescript
  scripting: {
    executeScript: vi.fn(() => Promise.resolve([{ result: undefined }])),
  },
  webNavigation: {
    onCompleted: {
      addListener: vi.fn(),
      removeListener: vi.fn(),
    },
  },
  tabs: {
    ...chromeMock.tabs,  // keep existing query, sendMessage, create
    onUpdated: {
      addListener: vi.fn(),
      removeListener: vi.fn(),
    },
  },
```

Also update the existing `tabs` block to include `onUpdated`.

---

### Test File 1: `smart-apply-shared/test/profile-completeness.spec.ts`

```typescript
import { describe, it, expect } from 'vitest';
import { calculateProfileCompleteness } from '../src/profile-completeness';

describe('calculateProfileCompleteness', () => {
  it('returns 0 for null profile', () => {
    const result = calculateProfileCompleteness(null);
    expect(result.score).toBe(0);
    expect(result.missingSections).toHaveLength(6);
    expect(result.missingSections).toEqual(
      expect.arrayContaining(['full_name', 'email', 'summary', 'base_skills', 'experiences', 'education']),
    );
  });

  it('returns 100 for fully complete profile', () => {
    const result = calculateProfileCompleteness({
      full_name: 'Jane Doe',
      email: 'jane@example.com',
      summary: 'A seasoned developer with extensive experience in building scalable applications.',
      base_skills: ['TypeScript', 'React', 'Node.js'],
      experiences: [{ company: 'Acme', role: 'Engineer', description: ['Built features'] }],
      education: [{ school: 'MIT', degree: 'BS CS' }],
    });
    expect(result.score).toBe(100);
    expect(result.missingSections).toHaveLength(0);
  });

  it('returns 15 when only full_name is present', () => {
    const result = calculateProfileCompleteness({
      full_name: 'Jane',
      email: null,
      summary: null,
      base_skills: [],
      experiences: [],
      education: [],
    });
    expect(result.score).toBe(15);
    expect(result.missingSections).not.toContain('full_name');
    expect(result.missingSections).toContain('email');
    expect(result.missingSections).toContain('summary');
  });

  it('requires summary >= 50 chars', () => {
    const short = calculateProfileCompleteness({
      full_name: null, email: null, summary: 'short', base_skills: [], experiences: [], education: [],
    });
    expect(short.missingSections).toContain('summary');

    const long = calculateProfileCompleteness({
      full_name: null, email: null,
      summary: 'A professional with deep expertise in modern web development technologies.',
      base_skills: [], experiences: [], education: [],
    });
    expect(long.missingSections).not.toContain('summary');
  });

  it('requires >= 3 skills', () => {
    const twoSkills = calculateProfileCompleteness({
      full_name: null, email: null, summary: null, base_skills: ['A', 'B'], experiences: [], education: [],
    });
    expect(twoSkills.missingSections).toContain('base_skills');

    const threeSkills = calculateProfileCompleteness({
      full_name: null, email: null, summary: null, base_skills: ['A', 'B', 'C'], experiences: [], education: [],
    });
    expect(threeSkills.missingSections).not.toContain('base_skills');
  });

  it('requires >= 1 experience with role, company, and description', () => {
    const empty = calculateProfileCompleteness({
      full_name: null, email: null, summary: null, base_skills: [], experiences: [], education: [],
    });
    expect(empty.missingSections).toContain('experiences');

    const valid = calculateProfileCompleteness({
      full_name: null, email: null, summary: null, base_skills: [],
      experiences: [{ company: 'Acme', role: 'Dev', description: ['Did things'] }],
      education: [],
    });
    expect(valid.missingSections).not.toContain('experiences');
  });

  it('returns correct sectionScores breakdown', () => {
    const result = calculateProfileCompleteness({
      full_name: 'Jane', email: 'j@e.com', summary: null, base_skills: [], experiences: [], education: [],
    });
    expect(result.sectionScores.full_name).toEqual({ weight: 15, earned: 15 });
    expect(result.sectionScores.email).toEqual({ weight: 10, earned: 10 });
    expect(result.sectionScores.summary).toEqual({ weight: 20, earned: 0 });
    expect(result.score).toBe(25);
  });
});
```

---

### Test File 2: `smart-apply-extension/test/autofill-injection.spec.ts`

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { resetChromeMock, seedStorage } from './chrome-mock';

// We test the functions that will be exported from service-worker for testability.
// Import after chrome mock is set up.

describe('Autofill Injection Logic', () => {
  beforeEach(() => {
    resetChromeMock();
  });

  describe('injectAutofillOnTab', () => {
    it('calls chrome.scripting.executeScript with correct args', async () => {
      const { injectAutofillOnTab } = await import('../src/background/autofill-injection');
      chrome.scripting.executeScript.mockResolvedValueOnce([{ result: undefined }]);

      const result = await injectAutofillOnTab(123);
      expect(chrome.scripting.executeScript).toHaveBeenCalledWith({
        target: { tabId: 123 },
        files: ['src/content/autofill.ts'],
      });
      expect(result.success).toBe(true);
    });

    it('returns error for restricted pages', async () => {
      const { injectAutofillOnTab } = await import('../src/background/autofill-injection');
      chrome.scripting.executeScript.mockRejectedValueOnce(new Error('Cannot access'));

      const result = await injectAutofillOnTab(456);
      expect(result.success).toBe(false);
      expect(result.error).toBeDefined();
    });
  });

  describe('tabs.onUpdated injection', () => {
    it('injects when autofill_enabled is true', async () => {
      seedStorage({ autofill_enabled: true });
      const { handleTabUpdated } = await import('../src/background/autofill-injection');
      chrome.scripting.executeScript.mockResolvedValueOnce([{ result: undefined }]);

      await handleTabUpdated(1, { status: 'complete' }, { id: 1, url: 'https://careers.example.com/apply' } as chrome.tabs.Tab);
      expect(chrome.scripting.executeScript).toHaveBeenCalled();
    });

    it('does NOT inject when autofill_enabled is false', async () => {
      seedStorage({ autofill_enabled: false });
      const { handleTabUpdated } = await import('../src/background/autofill-injection');

      await handleTabUpdated(1, { status: 'complete' }, { id: 1, url: 'https://careers.example.com' } as chrome.tabs.Tab);
      expect(chrome.scripting.executeScript).not.toHaveBeenCalled();
    });

    it('skips chrome:// URLs', async () => {
      seedStorage({ autofill_enabled: true });
      const { handleTabUpdated } = await import('../src/background/autofill-injection');

      await handleTabUpdated(1, { status: 'complete' }, { id: 1, url: 'chrome://extensions' } as chrome.tabs.Tab);
      expect(chrome.scripting.executeScript).not.toHaveBeenCalled();
    });
  });

  describe('webNavigation auto-activate', () => {
    it('auto-activates on cross-domain redirect within 60s', async () => {
      const { handleWebNavigationCompleted, setLastJdPage } = await import('../src/background/autofill-injection');
      chrome.scripting.executeScript.mockResolvedValueOnce([{ result: undefined }]);

      setLastJdPage({ hostname: 'www.linkedin.com', timestamp: Date.now() });

      await handleWebNavigationCompleted({
        tabId: 10, url: 'https://careers.acme.com/apply', frameId: 0,
        timeStamp: Date.now(), documentId: '', documentLifecycle: 'active' as chrome.webNavigation.DocumentLifecycle,
        processId: 0,
      });

      expect(chrome.storage.local.set).toHaveBeenCalledWith(
        expect.objectContaining({ autofill_enabled: true }),
        expect.any(Function),
      );
      expect(chrome.scripting.executeScript).toHaveBeenCalled();
    });

    it('does NOT auto-activate after 60s timeout', async () => {
      const { handleWebNavigationCompleted, setLastJdPage } = await import('../src/background/autofill-injection');

      setLastJdPage({ hostname: 'www.linkedin.com', timestamp: Date.now() - 70_000 });

      await handleWebNavigationCompleted({
        tabId: 10, url: 'https://careers.acme.com/apply', frameId: 0,
        timeStamp: Date.now(), documentId: '', documentLifecycle: 'active' as chrome.webNavigation.DocumentLifecycle,
        processId: 0,
      });

      expect(chrome.scripting.executeScript).not.toHaveBeenCalled();
    });
  });

  describe('JD_PAGE_DETECTED handler', () => {
    it('stores hostname and timestamp', async () => {
      const { handleJdPageDetected, getLastJdPage } = await import('../src/background/autofill-injection');

      handleJdPageDetected({ hostname: 'www.linkedin.com', url: 'https://www.linkedin.com/jobs/view/123' });

      const stored = getLastJdPage();
      expect(stored).not.toBeNull();
      expect(stored!.hostname).toBe('www.linkedin.com');
      expect(stored!.timestamp).toBeGreaterThan(0);
    });
  });
});
```

---

### Test File 3: `smart-apply-web/test/components/onboarding-checklist.spec.tsx`

```tsx
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { OnboardingChecklist } from '@/components/dashboard/onboarding-checklist';
import type { MasterProfile } from '@smart-apply/shared';

// Mock next/link
vi.mock('next/link', () => ({
  default: ({ children, href }: { children: React.ReactNode; href: string }) => <a href={href}>{children}</a>,
}));

const mockProfile: MasterProfile = {
  id: '1', clerk_user_id: 'u1', full_name: 'Jane Doe', email: 'jane@e.com',
  phone: null, location: null, linkedin_url: null, portfolio_url: null,
  summary: null, base_skills: [], certifications: [], experiences: [], education: [],
  raw_profile_source: null, profile_version: 1, created_at: '', updated_at: '',
};

describe('OnboardingChecklist', () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it('renders 4 checklist steps for a new user with null profile', () => {
    render(<OnboardingChecklist profile={null} applicationsCount={0} />);
    const items = screen.getAllByRole('listitem');
    expect(items).toHaveLength(4);
  });

  it('marks "Import your profile" as complete when profile has full_name', () => {
    render(<OnboardingChecklist profile={mockProfile} applicationsCount={0} />);
    expect(screen.getByText(/import your profile/i).closest('li')).toHaveAttribute('data-completed', 'true');
  });

  it('marks optimization/application steps complete when applicationsCount >= 1', () => {
    render(<OnboardingChecklist profile={null} applicationsCount={1} />);
    expect(screen.getByText(/optimize your first job/i).closest('li')).toHaveAttribute('data-completed', 'true');
    expect(screen.getByText(/save your first application/i).closest('li')).toHaveAttribute('data-completed', 'true');
  });

  it('hides checklist when all steps complete', () => {
    const { container } = render(<OnboardingChecklist profile={mockProfile} applicationsCount={1} />);
    expect(container.firstChild).toBeNull();
  });

  it('dismiss button hides checklist and persists in localStorage', () => {
    const { container } = render(<OnboardingChecklist profile={null} applicationsCount={0} />);
    const dismissBtn = screen.getByRole('button', { name: /dismiss/i });
    fireEvent.click(dismissBtn);
    expect(container.firstChild).toBeNull();
    expect(localStorage.getItem('onboarding_dismissed')).toBe('true');
  });

  it('uncompleted steps link to correct routes', () => {
    render(<OnboardingChecklist profile={null} applicationsCount={0} />);
    expect(screen.getByText(/import your profile/i).closest('a')).toHaveAttribute('href', '/profile');
    expect(screen.getByText(/optimize your first job/i).closest('a')).toHaveAttribute('href', '/optimize');
  });
});
```

---

### Test File 4: `smart-apply-web/test/components/quick-actions.spec.tsx`

```tsx
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { QuickActions } from '@/components/dashboard/quick-actions';

vi.mock('next/link', () => ({
  default: ({ children, href }: { children: React.ReactNode; href: string }) => <a href={href}>{children}</a>,
}));

describe('QuickActions', () => {
  it('renders 4 action buttons', () => {
    render(<QuickActions />);
    const links = screen.getAllByRole('link');
    expect(links.length).toBeGreaterThanOrEqual(4);
  });

  it('"Optimize a New Job" links to /optimize', () => {
    render(<QuickActions />);
    expect(screen.getByText(/optimize a new job/i).closest('a')).toHaveAttribute('href', '/optimize');
  });

  it('"Edit Profile" links to /profile', () => {
    render(<QuickActions />);
    expect(screen.getByText(/edit profile/i).closest('a')).toHaveAttribute('href', '/profile');
  });

  it('"Settings" links to /settings', () => {
    render(<QuickActions />);
    expect(screen.getByText(/settings/i).closest('a')).toHaveAttribute('href', '/settings');
  });
});
```

---

### Test File 5: `smart-apply-web/test/components/profile-completeness.spec.tsx`

```tsx
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { ProfileCompleteness } from '@/components/dashboard/profile-completeness';
import type { MasterProfile } from '@smart-apply/shared';

vi.mock('next/link', () => ({
  default: ({ children, href }: { children: React.ReactNode; href: string }) => <a href={href}>{children}</a>,
}));

const fullProfile: MasterProfile = {
  id: '1', clerk_user_id: 'u1', full_name: 'Jane Doe', email: 'jane@e.com',
  phone: null, location: null, linkedin_url: null, portfolio_url: null,
  summary: 'A seasoned developer with extensive experience in building scalable applications.',
  base_skills: ['TypeScript', 'React', 'Node.js'], certifications: [],
  experiences: [{ company: 'Acme', role: 'Dev', description: ['Built things'] }],
  education: [{ school: 'MIT', degree: 'BS CS' }],
  raw_profile_source: null, profile_version: 1, created_at: '', updated_at: '',
};

describe('ProfileCompleteness', () => {
  it('shows 0% for null profile', () => {
    render(<ProfileCompleteness profile={null} />);
    expect(screen.getByText('0%')).toBeInTheDocument();
  });

  it('shows 100% for complete profile with "complete" message', () => {
    render(<ProfileCompleteness profile={fullProfile} />);
    expect(screen.getByText('100%')).toBeInTheDocument();
    expect(screen.getByText(/complete/i)).toBeInTheDocument();
  });

  it('shows missing sections as links to /profile', () => {
    const partial: MasterProfile = { ...fullProfile, summary: null, base_skills: [], education: [] };
    render(<ProfileCompleteness profile={partial} />);
    const links = screen.getAllByRole('link');
    expect(links.some((l) => l.getAttribute('href') === '/profile')).toBe(true);
  });

  it('progress bar has correct aria attributes', () => {
    render(<ProfileCompleteness profile={null} />);
    const bar = screen.getByRole('progressbar');
    expect(bar).toHaveAttribute('aria-valuenow', '0');
    expect(bar).toHaveAttribute('aria-valuemin', '0');
    expect(bar).toHaveAttribute('aria-valuemax', '100');
  });
});
```

---

### Test File 6: `smart-apply-web/test/components/pipeline-view.spec.tsx`

```tsx
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { PipelineView } from '@/components/dashboard/pipeline-view';
import type { ApplicationHistoryItem } from '@smart-apply/shared';

const makeItem = (overrides: Partial<ApplicationHistoryItem> = {}): ApplicationHistoryItem => ({
  id: '1', clerk_user_id: 'u1', company_name: 'Acme', job_title: 'Engineer',
  source_platform: 'linkedin', source_url: null, job_description_hash: null,
  drive_link: null, ats_score_before: 50, ats_score_after: 80,
  applied_resume_snapshot: null, status: 'applied',
  created_at: '2026-01-01', applied_at: '2026-01-01', updated_at: '2026-01-01',
  ...overrides,
});

describe('PipelineView', () => {
  it('renders status columns: applied, interviewing, offer, rejected, withdrawn', () => {
    render(<PipelineView items={[]} onStatusChange={vi.fn()} />);
    expect(screen.getByText(/applied/i)).toBeInTheDocument();
    expect(screen.getByText(/interviewing/i)).toBeInTheDocument();
    expect(screen.getByText(/offer/i)).toBeInTheDocument();
    expect(screen.getByText(/rejected/i)).toBeInTheDocument();
    expect(screen.getByText(/withdrawn/i)).toBeInTheDocument();
  });

  it('groups applications by status into correct columns', () => {
    const items = [
      makeItem({ id: '1', status: 'applied' }),
      makeItem({ id: '2', status: 'interviewing' }),
      makeItem({ id: '3', status: 'rejected' }),
    ];
    render(<PipelineView items={items} onStatusChange={vi.fn()} />);
    // Each item should appear
    const cards = screen.getAllByText('Acme');
    expect(cards).toHaveLength(3);
  });

  it('renders application card with company, job title, ATS score', () => {
    render(<PipelineView items={[makeItem()]} onStatusChange={vi.fn()} />);
    expect(screen.getByText('Acme')).toBeInTheDocument();
    expect(screen.getByText('Engineer')).toBeInTheDocument();
  });

  it('status dropdown calls onStatusChange with correct args', () => {
    const handler = vi.fn();
    render(<PipelineView items={[makeItem({ id: 'abc' })]} onStatusChange={handler} />);
    const select = screen.getByLabelText(/change status/i);
    fireEvent.change(select, { target: { value: 'interviewing' } });
    expect(handler).toHaveBeenCalledWith('abc', 'interviewing');
  });

  it('groups draft/generated items into applied column', () => {
    const items = [makeItem({ id: '1', status: 'generated' })];
    render(<PipelineView items={items} onStatusChange={vi.fn()} />);
    // The item should be in the applied column group
    const appliedGroup = screen.getByLabelText(/applied applications/i);
    expect(appliedGroup).toContainElement(screen.getByText('Acme'));
  });

  it('status select has accessible aria-label', () => {
    render(<PipelineView items={[makeItem({ company_name: 'Corp', job_title: 'Dev' })]} onStatusChange={vi.fn()} />);
    expect(screen.getByLabelText(/change status for Corp/i)).toBeInTheDocument();
  });
});
```

---

### Test File 7: `smart-apply-web/test/components/optimize-results-save.spec.tsx`

```tsx
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import type { OptimizeResponse, MasterProfile } from '@smart-apply/shared';

// Mock dependencies
const mockGetToken = vi.fn(() => Promise.resolve('mock-token'));
vi.mock('@clerk/nextjs', () => ({
  useAuth: () => ({ getToken: mockGetToken }),
}));

vi.mock('@/lib/api-client', () => ({
  apiFetch: vi.fn(),
}));

vi.mock('pdf-lib', () => ({
  PDFDocument: {
    create: vi.fn(() => Promise.resolve({
      embedFont: vi.fn(() => Promise.resolve({ widthOfTextAtSize: () => 100 })),
      addPage: vi.fn(() => ({
        drawText: vi.fn(),
      })),
      save: vi.fn(() => Promise.resolve(new Uint8Array([1, 2, 3]))),
    })),
  },
  StandardFonts: { Helvetica: 'Helvetica', HelveticaBold: 'HelveticaBold' },
  rgb: vi.fn(() => ({})),
}));

const mockProfile: MasterProfile = {
  id: '1', clerk_user_id: 'u1', full_name: 'Jane Doe', email: 'j@e.com',
  phone: '555-0100', location: 'NYC', linkedin_url: null, portfolio_url: null,
  summary: 'Senior dev', base_skills: ['TS'], certifications: [],
  experiences: [{ company: 'Acme', role: 'Dev', description: ['Built'] }],
  education: [{ school: 'MIT', degree: 'BS' }],
  raw_profile_source: null, profile_version: 1, created_at: '', updated_at: '',
};

const mockResult: OptimizeResponse = {
  ats_score_before: 50,
  ats_score_after: 85,
  suggested_changes: [],
  extracted_requirements: { hard_skills: [], soft_skills: [], experience_keywords: [], education_level: null },
  optimized_resume_json: {} as Record<string, unknown>,
};

import { apiFetch } from '@/lib/api-client';
const mockedApiFetch = vi.mocked(apiFetch);

// Import component after mocks
import { OptimizeResults } from '@/components/optimize/optimize-results';

function renderWithQueryClient(ui: React.ReactElement) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  // Pre-populate profile query
  queryClient.setQueryData(['profile'], mockProfile);
  return render(<QueryClientProvider client={queryClient}>{ui}</QueryClientProvider>);
}

describe('OptimizeResults Application Save', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    // Mock URL.createObjectURL
    global.URL.createObjectURL = vi.fn(() => 'blob:mock');
    global.URL.revokeObjectURL = vi.fn();
  });

  it('calls POST /api/applications after successful PDF download', async () => {
    mockedApiFetch.mockResolvedValueOnce({ success: true, application_id: 'app-1' });

    renderWithQueryClient(
      <OptimizeResults result={mockResult} companyName="Acme" jobTitle="Engineer" onBack={vi.fn()} />,
    );

    fireEvent.click(screen.getByText(/download optimized pdf/i));

    await waitFor(() => {
      expect(mockedApiFetch).toHaveBeenCalledWith(
        '/api/applications',
        'mock-token',
        expect.objectContaining({ method: 'POST' }),
      );
    });
  });

  it('includes correct payload in save request', async () => {
    mockedApiFetch.mockResolvedValueOnce({ success: true, application_id: 'app-1' });

    renderWithQueryClient(
      <OptimizeResults result={mockResult} companyName="Acme" jobTitle="SDE" onBack={vi.fn()} />,
    );

    fireEvent.click(screen.getByText(/download optimized pdf/i));

    await waitFor(() => {
      const call = mockedApiFetch.mock.calls.find((c) => c[0] === '/api/applications');
      expect(call).toBeDefined();
      const body = JSON.parse((call![2] as RequestInit).body as string);
      expect(body.company_name).toBe('Acme');
      expect(body.job_title).toBe('SDE');
      expect(body.status).toBe('generated');
      expect(body.ats_score_before).toBe(50);
      expect(body.ats_score_after).toBe(85);
    });
  });

  it('PDF still downloads when save fails', async () => {
    mockedApiFetch.mockRejectedValueOnce(new Error('Save failed'));

    renderWithQueryClient(
      <OptimizeResults result={mockResult} companyName="Acme" jobTitle="SDE" onBack={vi.fn()} />,
    );

    fireEvent.click(screen.getByText(/download optimized pdf/i));

    await waitFor(() => {
      expect(global.URL.createObjectURL).toHaveBeenCalled();
    });
  });
});
```

### Verify Red Phase

```bash
# Shared
cd smart-apply-shared && npx vitest run --reporter=verbose 2>&1 | tail -10

# Extension
cd smart-apply-extension && npx vitest run --reporter=verbose 2>&1 | tail -10

# Web
cd smart-apply-web && npx vitest run --reporter=verbose 2>&1 | tail -10
```

**Expected:** New tests all FAIL (modules/components not yet created).

---

## Step 2: Implement (TDD — Green Phase)

Implement the minimum code to make all tests pass. Follow this EXACT order.

---

### 2.1 Shared: `profile-completeness.ts` (CREATE)

**File:** `smart-apply-shared/src/profile-completeness.ts`
**Action:** CREATE

```typescript
export interface ProfileSectionScore {
  weight: number;
  earned: number;
}

export interface ProfileCompletenessResult {
  score: number;
  missingSections: string[];
  sectionScores: Record<string, ProfileSectionScore>;
}

interface ProfileInput {
  full_name: string | null;
  email: string | null;
  summary: string | null;
  base_skills: string[];
  experiences: Array<{ company: string; role: string; description: string[] }>;
  education: Array<{ school: string; degree: string }>;
}

const SECTIONS: Array<{ key: string; weight: number; check: (p: ProfileInput) => boolean }> = [
  { key: 'full_name', weight: 15, check: (p) => !!p.full_name && p.full_name.length > 0 },
  { key: 'email', weight: 10, check: (p) => !!p.email && p.email.length > 0 },
  { key: 'summary', weight: 20, check: (p) => !!p.summary && p.summary.length >= 50 },
  { key: 'base_skills', weight: 20, check: (p) => p.base_skills.length >= 3 },
  {
    key: 'experiences',
    weight: 25,
    check: (p) =>
      p.experiences.length >= 1 &&
      !!p.experiences[0].role &&
      !!p.experiences[0].company &&
      p.experiences[0].description.length > 0,
  },
  { key: 'education', weight: 10, check: (p) => p.education.length >= 1 },
];

export function calculateProfileCompleteness(
  profile: ProfileInput | null,
): ProfileCompletenessResult {
  if (!profile) {
    const sectionScores: Record<string, ProfileSectionScore> = {};
    const missingSections: string[] = [];
    for (const s of SECTIONS) {
      sectionScores[s.key] = { weight: s.weight, earned: 0 };
      missingSections.push(s.key);
    }
    return { score: 0, missingSections, sectionScores };
  }

  const sectionScores: Record<string, ProfileSectionScore> = {};
  const missingSections: string[] = [];
  let score = 0;

  for (const s of SECTIONS) {
    const passed = s.check(profile);
    const earned = passed ? s.weight : 0;
    sectionScores[s.key] = { weight: s.weight, earned };
    if (!passed) missingSections.push(s.key);
    score += earned;
  }

  return { score, missingSections, sectionScores };
}
```

---

### 2.2 Shared: `index.ts` (MODIFY)

**File:** `smart-apply-shared/src/index.ts`
**Action:** MODIFY — add export line at end

Add this line:
```typescript
export * from './profile-completeness';
```

**Verify:** `cd smart-apply-shared && npx vitest run`
Expected: profile-completeness tests PASS.

---

### 2.3 Extension: `manifest.ts` (MODIFY)

**File:** `smart-apply-extension/src/manifest.ts`
**Action:** MODIFY — add permissions

Change:
```typescript
permissions: ['storage', 'activeTab', 'identity'],
```
To:
```typescript
permissions: ['storage', 'activeTab', 'identity', 'scripting', 'tabs', 'webNavigation'],
```

---

### 2.4 Extension: `autofill-injection.ts` (CREATE)

**File:** `smart-apply-extension/src/background/autofill-injection.ts`
**Action:** CREATE — testable module for autofill injection logic

```typescript
/**
 * Autofill injection logic — extracted for testability.
 * Called by service-worker.ts via setupAutofillListeners().
 */

let lastJdPage: { hostname: string; timestamp: number } | null = null;

export function getLastJdPage() {
  return lastJdPage;
}

export function setLastJdPage(value: { hostname: string; timestamp: number } | null) {
  lastJdPage = value;
}

export async function injectAutofillOnTab(
  tabId: number,
): Promise<{ success: boolean; error?: string }> {
  try {
    await chrome.scripting.executeScript({
      target: { tabId },
      files: ['src/content/autofill.ts'],
    });
    return { success: true };
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Injection failed';
    return { success: false, error: message };
  }
}

function isRestrictedUrl(url: string): boolean {
  return url.startsWith('chrome://') || url.startsWith('chrome-extension://') || url.startsWith('about:');
}

export async function handleTabUpdated(
  tabId: number,
  changeInfo: chrome.tabs.TabChangeInfo,
  tab: chrome.tabs.Tab,
): Promise<void> {
  if (changeInfo.status !== 'complete') return;
  if (!tab.url || isRestrictedUrl(tab.url)) return;

  const result = await chrome.storage.local.get('autofill_enabled');
  if (result.autofill_enabled !== true) return;

  await injectAutofillOnTab(tabId);
}

export async function handleWebNavigationCompleted(
  details: chrome.webNavigation.WebNavigationFramedCallbackDetails,
): Promise<void> {
  if (details.frameId !== 0) return; // only top-level frame
  if (!lastJdPage) return;
  if (Date.now() - lastJdPage.timestamp >= 60_000) return;

  let hostname: string;
  try {
    hostname = new URL(details.url).hostname;
  } catch {
    return;
  }

  if (hostname === lastJdPage.hostname) return;
  if (isRestrictedUrl(details.url)) return;

  // Cross-domain redirect within 60s of JD page — auto-activate
  chrome.storage.local.set({ autofill_enabled: true }, () => {});
  await injectAutofillOnTab(details.tabId);
  lastJdPage = null; // consumed
}

export function handleJdPageDetected(payload: { hostname: string; url: string }): void {
  lastJdPage = { hostname: payload.hostname, timestamp: Date.now() };
}

/**
 * Register Chrome API listeners. Called once from service-worker.ts at module level.
 */
export function setupAutofillListeners(): void {
  chrome.tabs.onUpdated.addListener(handleTabUpdated);
  chrome.webNavigation.onCompleted.addListener(handleWebNavigationCompleted);
}
```

---

### 2.5 Extension: `service-worker.ts` (MODIFY)

**File:** `smart-apply-extension/src/background/service-worker.ts`
**Action:** MODIFY — import and wire autofill-injection module, add JD_PAGE_DETECTED handler

**Change 1:** Add import at top (after existing imports):
```typescript
import { setupAutofillListeners, handleJdPageDetected } from './autofill-injection';
```

**Change 2:** Add to `MessageType` union:
```typescript
  | { type: 'JD_PAGE_DETECTED'; payload: { hostname: string; url: string } }
```

**Change 3:** Add case in the `switch` block (before `default`):
```typescript
    case 'JD_PAGE_DETECTED':
      handleJdPageDetected(message.payload);
      sendResponse({ success: true });
      break;
```

**Change 4:** Call `setupAutofillListeners()` at module level (after `chrome.runtime.onInstalled.addListener`):
```typescript
setupAutofillListeners();
```

---

### 2.6 Extension: `jd-detector.ts` (MODIFY)

**File:** `smart-apply-extension/src/content/jd-detector.ts`
**Action:** MODIFY — send JD_PAGE_DETECTED message

After the existing `if (isLinkedInJobPage() || isIndeedJobPage()) { injectOptimizeButton(); }` block, add:

```typescript
// Notify service worker that we're on a JD page (for cross-site auto-activate)
if (isLinkedInJobPage() || isIndeedJobPage()) {
  chrome.runtime.sendMessage({
    type: 'JD_PAGE_DETECTED',
    payload: {
      hostname: window.location.hostname,
      url: window.location.href,
    },
  });
}
```

---

### 2.7 Extension: `App.tsx` (MODIFY)

**File:** `smart-apply-extension/src/ui/popup/App.tsx`
**Action:** MODIFY — add autofill toggle switch on dashboard screen

**Change 1:** Add state for toggle (in the App component, alongside existing state):
```typescript
const [autofillEnabled, setAutofillEnabled] = useState(false);
```

**Change 2:** Add effect to read initial toggle state (in useEffect section):
```typescript
useEffect(() => {
  chrome.storage.local.get('autofill_enabled', (result) => {
    setAutofillEnabled(result.autofill_enabled === true);
  });
}, []);
```

**Change 3:** Add toggle handler:
```typescript
const handleAutofillToggle = useCallback(() => {
  const newValue = !autofillEnabled;
  setAutofillEnabled(newValue);
  chrome.storage.local.set({ autofill_enabled: newValue });
}, [autofillEnabled]);
```

**Change 4:** In the dashboard screen JSX (the section that renders "Sync Profile", "Optimize for This Job", etc.), add the toggle UI. After the existing action buttons, add:

```tsx
<div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
  <div>
    <p className="text-sm font-medium">Auto-fill on any page</p>
    <p className="text-xs text-gray-500">Fill job applications on any career portal</p>
  </div>
  <button
    role="switch"
    aria-checked={autofillEnabled}
    onClick={handleAutofillToggle}
    className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
      autofillEnabled ? 'bg-green-500' : 'bg-gray-300'
    }`}
  >
    <span
      className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
        autofillEnabled ? 'translate-x-6' : 'translate-x-1'
      }`}
    />
  </button>
</div>
```

**Verify:** `cd smart-apply-extension && npx vitest run`
Expected: autofill-injection tests PASS.

---

### 2.8 Web: `onboarding-checklist.tsx` (CREATE)

**File:** `smart-apply-web/src/components/dashboard/onboarding-checklist.tsx`
**Action:** CREATE

```tsx
'use client';

import { useState } from 'react';
import Link from 'next/link';
import type { MasterProfile } from '@smart-apply/shared';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';

interface OnboardingChecklistProps {
  profile: MasterProfile | null;
  applicationsCount: number;
}

interface ChecklistStep {
  label: string;
  completed: boolean;
  href: string;
}

export function OnboardingChecklist({ profile, applicationsCount }: OnboardingChecklistProps) {
  const [dismissed, setDismissed] = useState(() => localStorage.getItem('onboarding_dismissed') === 'true');

  const steps: ChecklistStep[] = [
    {
      label: 'Import your profile',
      completed: !!profile?.full_name,
      href: '/profile',
    },
    {
      label: 'Install Chrome Extension',
      completed: false, // cannot detect from web
      href: 'https://chrome.google.com/webstore',
    },
    {
      label: 'Optimize your first job',
      completed: applicationsCount >= 1,
      href: '/optimize',
    },
    {
      label: 'Save your first application',
      completed: applicationsCount >= 1,
      href: '/optimize',
    },
  ];

  const completedCount = steps.filter((s) => s.completed).length;

  if (completedCount === steps.length || dismissed) return null;

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center justify-between">
          <span>Getting Started ({completedCount}/{steps.length})</span>
          <Button
            variant="ghost"
            size="sm"
            aria-label="Dismiss onboarding checklist"
            onClick={() => {
              setDismissed(true);
              localStorage.setItem('onboarding_dismissed', 'true');
            }}
          >
            Dismiss
          </Button>
        </CardTitle>
      </CardHeader>
      <CardContent>
        <ul role="list" className="space-y-2">
          {steps.map((step) => (
            <li key={step.label} data-completed={step.completed ? 'true' : 'false'} className="flex items-center gap-2">
              <span className={`text-lg ${step.completed ? 'text-green-500' : 'text-gray-300'}`}>
                {step.completed ? '✓' : '○'}
              </span>
              {step.completed ? (
                <span className="text-sm text-muted-foreground line-through">{step.label}</span>
              ) : (
                <Link href={step.href} className="text-sm text-primary hover:underline">
                  {step.label}
                </Link>
              )}
            </li>
          ))}
        </ul>
      </CardContent>
    </Card>
  );
}
```

---

### 2.9 Web: `quick-actions.tsx` (CREATE)

**File:** `smart-apply-web/src/components/dashboard/quick-actions.tsx`
**Action:** CREATE

```tsx
'use client';

import Link from 'next/link';
import { Button } from '@/components/ui/button';

export function QuickActions() {
  return (
    <nav aria-label="Quick actions" className="grid grid-cols-2 gap-3 sm:grid-cols-4">
      <Link href="/optimize">
        <Button variant="outline" className="w-full">Optimize a New Job</Button>
      </Link>
      <Link href="/profile">
        <Button variant="outline" className="w-full">Edit Profile</Button>
      </Link>
      <Link href="/profile">
        <Button variant="outline" className="w-full">Upload Resume</Button>
      </Link>
      <Link href="/settings">
        <Button variant="outline" className="w-full">Settings</Button>
      </Link>
    </nav>
  );
}
```

---

### 2.10 Web: `profile-completeness.tsx` (CREATE)

**File:** `smart-apply-web/src/components/dashboard/profile-completeness.tsx`
**Action:** CREATE

```tsx
'use client';

import Link from 'next/link';
import type { MasterProfile } from '@smart-apply/shared';
import { calculateProfileCompleteness } from '@smart-apply/shared';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';

interface ProfileCompletenessProps {
  profile: MasterProfile | null;
}

const SECTION_LABELS: Record<string, string> = {
  full_name: 'Full Name',
  email: 'Email',
  summary: 'Professional Summary',
  base_skills: 'Skills (3+)',
  experiences: 'Work Experience',
  education: 'Education',
};

export function ProfileCompleteness({ profile }: ProfileCompletenessProps) {
  const { score, missingSections } = calculateProfileCompleteness(profile);

  return (
    <Card>
      <CardHeader>
        <CardTitle>Profile Completeness</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="mb-3 flex items-center gap-3">
          <div
            role="progressbar"
            aria-valuenow={score}
            aria-valuemin={0}
            aria-valuemax={100}
            className="relative h-4 flex-1 overflow-hidden rounded-full bg-gray-200"
          >
            <div
              className="h-full rounded-full bg-primary transition-all"
              style={{ width: `${score}%` }}
            />
          </div>
          <span className="text-sm font-semibold">{score}%</span>
        </div>
        {score === 100 ? (
          <p className="text-sm text-green-600">Profile complete!</p>
        ) : (
          <div className="space-y-1">
            <p className="text-sm text-muted-foreground">Missing sections:</p>
            <ul className="space-y-1">
              {missingSections.map((key) => (
                <li key={key}>
                  <Link href="/profile" className="text-sm text-primary hover:underline">
                    {SECTION_LABELS[key] ?? key}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
```

---

### 2.11 Web: `pipeline-view.tsx` (CREATE)

**File:** `smart-apply-web/src/components/dashboard/pipeline-view.tsx`
**Action:** CREATE

```tsx
'use client';

import type { ApplicationHistoryItem, ApplicationStatus } from '@smart-apply/shared';
import { APPLICATION_STATUSES } from '@smart-apply/shared';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';

interface PipelineViewProps {
  items: ApplicationHistoryItem[];
  onStatusChange: (applicationId: string, newStatus: ApplicationStatus) => void;
}

const PIPELINE_COLUMNS: ApplicationStatus[] = ['applied', 'interviewing', 'offer', 'rejected', 'withdrawn'];

function mapToPipelineStatus(status: ApplicationStatus): ApplicationStatus {
  if (status === 'draft' || status === 'generated') return 'applied';
  return status;
}

export function PipelineView({ items, onStatusChange }: PipelineViewProps) {
  const grouped = new Map<ApplicationStatus, ApplicationHistoryItem[]>();
  for (const col of PIPELINE_COLUMNS) grouped.set(col, []);
  for (const item of items) {
    const col = mapToPipelineStatus(item.status);
    grouped.get(col)?.push(item);
  }

  return (
    <div className="grid grid-cols-1 gap-4 overflow-x-auto sm:grid-cols-5">
      {PIPELINE_COLUMNS.map((col) => {
        const colItems = grouped.get(col) ?? [];
        return (
          <div key={col} role="group" aria-label={`${col} applications`} className="min-w-[200px]">
            <div className="mb-2 flex items-center gap-2">
              <h3 className="text-sm font-semibold capitalize">{col}</h3>
              <Badge variant="secondary" className="text-xs">{colItems.length}</Badge>
            </div>
            <div className="space-y-2">
              {colItems.map((item) => (
                <Card key={item.id}>
                  <CardContent className="p-3">
                    <p className="text-sm font-medium">{item.company_name}</p>
                    <p className="text-xs text-muted-foreground">{item.job_title}</p>
                    {item.ats_score_after != null && (
                      <p className="text-xs text-muted-foreground mt-1">ATS: {item.ats_score_after}%</p>
                    )}
                    <select
                      value={item.status}
                      aria-label={`Change status for ${item.company_name} - ${item.job_title}`}
                      onChange={(e) => onStatusChange(item.id, e.target.value as ApplicationStatus)}
                      className="mt-2 w-full rounded border px-2 py-1 text-xs"
                    >
                      {APPLICATION_STATUSES.map((s) => (
                        <option key={s} value={s}>{s}</option>
                      ))}
                    </select>
                  </CardContent>
                </Card>
              ))}
              {colItems.length === 0 && (
                <p className="py-4 text-center text-xs text-muted-foreground">No applications</p>
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
}
```

---

### 2.12 Web: `dashboard-shell.tsx` (MODIFY)

**File:** `smart-apply-web/src/components/dashboard/dashboard-shell.tsx`
**Action:** MODIFY — integrate all new widgets, add profile query + view toggle + status mutation

Replace the entire file with:

```tsx
'use client';

import { useState, useCallback } from 'react';
import { useAuth } from '@clerk/nextjs';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiFetch } from '@/lib/api-client';
import type { ListApplicationsResponse, MasterProfile, ApplicationStatus } from '@smart-apply/shared';
import { ApplicationsTable } from './applications-table';
import { StatsCards } from './stats-cards';
import { OnboardingChecklist } from './onboarding-checklist';
import { QuickActions } from './quick-actions';
import { ProfileCompleteness } from './profile-completeness';
import { PipelineView } from './pipeline-view';
import { Button } from '@/components/ui/button';

type ViewMode = 'table' | 'pipeline';

export function DashboardShell() {
  const { getToken } = useAuth();
  const queryClient = useQueryClient();
  const [viewMode, setViewMode] = useState<ViewMode>(
    () => (typeof window !== 'undefined' ? (localStorage.getItem('dashboard_view_mode') as ViewMode) : null) ?? 'table',
  );

  const { data, isLoading, error } = useQuery({
    queryKey: ['applications'],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error('Not authenticated');
      return apiFetch<ListApplicationsResponse>('/api/applications', token);
    },
  });

  const { data: profile } = useQuery({
    queryKey: ['profile'],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error('Not authenticated');
      return apiFetch<MasterProfile>('/api/profile/me', token);
    },
  });

  const statusMutation = useMutation({
    mutationFn: async ({ id, status }: { id: string; status: ApplicationStatus }) => {
      const token = await getToken();
      if (!token) throw new Error('Not authenticated');
      return apiFetch<{ success: boolean }>(`/api/applications/${id}/status`, token, {
        method: 'PATCH',
        body: JSON.stringify({ status }),
      });
    },
    onMutate: async ({ id, status }) => {
      await queryClient.cancelQueries({ queryKey: ['applications'] });
      const prev = queryClient.getQueryData<ListApplicationsResponse>(['applications']);
      if (prev) {
        queryClient.setQueryData<ListApplicationsResponse>(['applications'], {
          items: prev.items.map((item) => (item.id === id ? { ...item, status } : item)),
        });
      }
      return { prev };
    },
    onError: (_err, _vars, context) => {
      if (context?.prev) queryClient.setQueryData(['applications'], context.prev);
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['applications'] });
    },
  });

  const handleStatusChange = useCallback(
    (id: string, status: ApplicationStatus) => {
      statusMutation.mutate({ id, status });
    },
    [statusMutation],
  );

  const handleViewModeChange = useCallback((mode: ViewMode) => {
    setViewMode(mode);
    localStorage.setItem('dashboard_view_mode', mode);
  }, []);

  return (
    <main className="container mx-auto max-w-6xl py-8 px-4 space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold">Dashboard</h1>
      </div>

      <OnboardingChecklist profile={profile ?? null} applicationsCount={data?.items.length ?? 0} />

      <QuickActions />

      <ProfileCompleteness profile={profile ?? null} />

      {error ? (
        <div className="rounded-lg border border-destructive/50 bg-destructive/10 p-4 text-destructive">
          Failed to load applications: {error.message}
        </div>
      ) : isLoading ? (
        <div className="flex items-center justify-center py-12 text-muted-foreground">
          Loading applications...
        </div>
      ) : data && data.items.length === 0 ? (
        <div className="flex flex-col items-center justify-center rounded-lg border border-dashed py-12">
          <p className="text-muted-foreground">No applications yet.</p>
          <p className="mt-1 text-sm text-muted-foreground">
            Use the Chrome Extension or the Optimize page to get started.
          </p>
        </div>
      ) : data ? (
        <>
          <StatsCards items={data.items} />
          <div className="flex items-center gap-2">
            <Button
              variant={viewMode === 'table' ? 'default' : 'outline'}
              size="sm"
              onClick={() => handleViewModeChange('table')}
            >
              Table
            </Button>
            <Button
              variant={viewMode === 'pipeline' ? 'default' : 'outline'}
              size="sm"
              onClick={() => handleViewModeChange('pipeline')}
            >
              Pipeline
            </Button>
          </div>
          {viewMode === 'pipeline' ? (
            <PipelineView items={data.items} onStatusChange={handleStatusChange} />
          ) : (
            <ApplicationsTable items={data.items} />
          )}
        </>
      ) : null}
    </main>
  );
}
```

---

### 2.13 Web: `optimize-results.tsx` (MODIFY)

**File:** `smart-apply-web/src/components/optimize/optimize-results.tsx`
**Action:** MODIFY — add `jobTitle` prop, save application after PDF download

**Change 1:** Update interface:
```typescript
interface OptimizeResultsProps {
  result: OptimizeResponse;
  companyName: string;
  jobTitle: string;
  onBack: () => void;
}
```

**Change 2:** Update component signature:
```typescript
export function OptimizeResults({ result, companyName, jobTitle, onBack }: OptimizeResultsProps) {
```

**Change 3:** In `handleDownloadPdf`, after the `URL.revokeObjectURL(url)` line and before the `catch`, add:

```typescript
      // Save application record (non-blocking for PDF download)
      try {
        const token = await getToken();
        if (token) {
          await apiFetch<{ success: boolean; application_id: string }>('/api/applications', token, {
            method: 'POST',
            body: JSON.stringify({
              company_name: companyName,
              job_title: jobTitle,
              source_platform: 'other',
              ats_score_before: result.ats_score_before,
              ats_score_after: result.ats_score_after,
              status: 'generated',
              applied_resume_snapshot: result.optimized_resume_json,
            }),
          });
        }
      } catch (saveErr) {
        console.error('Failed to save application:', saveErr);
      }
```

**Change 4:** Add `jobTitle` to the `useCallback` dependency array.

---

### 2.14 Web: `optimize-form.tsx` (MODIFY)

**File:** `smart-apply-web/src/components/optimize/optimize-form.tsx`
**Action:** MODIFY — pass `jobTitle` prop to `OptimizeResults`

Change:
```tsx
      <OptimizeResults
        result={result}
        companyName={companyName}
        onBack={() => { setStatus('idle'); setResult(null); }}
      />
```
To:
```tsx
      <OptimizeResults
        result={result}
        companyName={companyName}
        jobTitle={jobTitle}
        onBack={() => { setStatus('idle'); setResult(null); }}
      />
```

---

### 2.15 Extension: `chrome-mock.ts` (MODIFY)

**File:** `smart-apply-extension/test/chrome-mock.ts`
**Action:** MODIFY — add scripting + webNavigation + tabs.onUpdated mocks

Add to the `chromeMock` object, after the `downloads` property:

```typescript
  scripting: {
    executeScript: vi.fn(() => Promise.resolve([{ result: undefined }])),
  },
  webNavigation: {
    onCompleted: {
      addListener: vi.fn(),
      removeListener: vi.fn(),
    },
  },
```

And extend the existing `tabs` object to include:
```typescript
    onUpdated: {
      addListener: vi.fn(),
      removeListener: vi.fn(),
    },
```

### Verify Green Phase

```bash
cd smart-apply-shared && npx vitest run
cd smart-apply-extension && npx vitest run
cd smart-apply-web && npx vitest run
```

Expected: ALL new tests PASS + no regressions.

---

## Step 3: Refactor

Review implementation for:
- [ ] Duplicated code → No duplication expected; `calculateProfileCompleteness` is shared
- [ ] Long functions → `autofill-injection.ts` functions are focused and short
- [ ] Missing error messages → Add descriptive errors where appropriate
- [ ] Console.log statements → Remove debug logs, keep only `console.error` or `console.warn`

### Verify After Refactor

```bash
cd smart-apply-shared && npx vitest run
cd smart-apply-extension && npx vitest run
cd smart-apply-web && npx vitest run
```

Expected: ALL tests still pass.

---

## Step 4: Integration Check

### Manual Verification Steps

1. **Shared build:** `cd smart-apply-shared && npx tsc --noEmit` → no errors
2. **Extension build:** `cd smart-apply-extension && npm run build` → builds successfully
3. **Web build:** `cd smart-apply-web && npm run build` → builds successfully
4. **Load extension in Chrome:** Load unpacked → popup shows autofill toggle
5. **Toggle ON:** Navigate to any job portal → floating autofill button appears
6. **Auto-activate:** View LinkedIn job listing → click Apply → external portal opens → autofill button auto-appears
7. **Dashboard:** Sign in → navigate to /dashboard → see onboarding checklist, quick actions, profile completeness meter
8. **Pipeline view:** Click "Pipeline" toggle → see applications grouped by status columns
9. **Status change:** Change dropdown → card moves to new column instantly
10. **Web optimize save:** Go to /optimize → submit job → download PDF → check /dashboard → new application appears

### Cross-Phase Verification

- Verify Phase P05 tests still pass: `npm test` from monorepo root
- Verify shared schema compatibility: `cd smart-apply-shared && npm run build`
- Verify existing extension autofill on LinkedIn/Indeed still works (content_scripts unchanged)

---

## Rollback Plan

If implementation breaks existing functionality:
1. `git stash` current changes
2. Verify existing tests pass: run test suites in each package
3. Re-read the specific LLD section for the failing component
4. Identify the breaking change and fix incrementally
5. If shared package changes break consumers: revert `index.ts` export, fix type signature

---

## End of IMPL-LLD-P06
