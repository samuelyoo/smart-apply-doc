# IMPL-LLD-P05 — Test Coverage Completion

> **Phase:** P05 — Test Coverage Completion
> **Source:** Approved LLD-MVP-P05.md (R2)
> **Target:** 35 new tests + 1 CORS extraction refactor

---

## Context

### Project State

- **Monorepo root:** `/Users/syoo/Documents/code/smart-apply`
- **Packages affected:** smart-apply-backend, smart-apply-web, smart-apply-extension
- **Baseline tests:** 66 passing (23 backend, 17 extension, 26 web)
- **Target total:** ≥ 101 tests

### Existing Files to Read First

| File | Why |
|:---|:---|
| `smart-apply-backend/src/main.ts` | CORS callback to extract |
| `smart-apply-backend/test/webhooks.controller.spec.ts` | Extend with audit tests |
| `smart-apply-extension/test/service-worker.spec.ts` | Extend with OPTIMIZE_JD tests |
| `smart-apply-extension/src/lib/pdf-generator.ts` | Function under test |
| `smart-apply-web/test/setup.ts` | Test setup for web (imports `@testing-library/jest-dom/vitest`) |
| `smart-apply-web/vitest.config.ts` | Needs `resolve.alias` for `@/` |
| `smart-apply-web/src/lib/api-client.ts` | Mocked in all web tests |
| `smart-apply-web/src/components/optimize/optimize-form.tsx` | Component under test |
| `smart-apply-web/src/components/optimize/optimize-results.tsx` | Component under test |
| `smart-apply-web/src/components/dashboard/dashboard-shell.tsx` | Component under test |
| `smart-apply-web/src/components/profile/profile-editor.tsx` | Component under test |
| `smart-apply-web/src/components/settings/settings-page.tsx` | Component under test |

### Shared Schemas to Import

From `@smart-apply/shared`:
- `OptimizeResponse`, `SuggestedChange`, `ExtractedRequirements`, `OptimizedResume`
- `MasterProfile`, `ExperienceItem`
- `ListApplicationsResponse`, `ApplicationHistoryItem`
- `UpdateProfileRequest`

### Key Signatures

```typescript
// smart-apply-web/src/lib/api-client.ts
export async function apiFetch<T>(path: string, token: string, options?: RequestInit): Promise<T>

// smart-apply-extension/src/lib/api-client.ts
export async function apiFetch<T>(path: string, init?: RequestInit): Promise<T>

// smart-apply-extension/src/lib/pdf-generator.ts
interface ResumeData {
  name: string; email: string; phone: string; summary: string;
  experience: Array<{ title: string; company: string; dates: string; bullets: string[] }>;
  skills: string[];
}
export async function generateResumePDF(data: ResumeData): Promise<Uint8Array>
```

### What This Phase Builds

35 new test cases covering the 5 untested web components, the extension PDF generator and OPTIMIZE_JD handler, backend webhook audit assertions, and a new CORS origin validator extracted from the inline `main.ts` callback. The only production code change is extracting the CORS logic into a pure `validateCorsOrigin()` function.

---

## Step 1: Write Tests (TDD — Red Phase)

Write ALL test files BEFORE any implementation code. Run tests — they should all **FAIL** (Red phase).

### Pre-requisite: Update `smart-apply-web/vitest.config.ts`

The web vitest config needs a `resolve.alias` so that `@/` paths resolve correctly in test files. This is a config change, not production code.

**File:** `smart-apply-web/vitest.config.ts`
**Action:** MODIFY — add `resolve.alias` and `path` import

```typescript
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  test: {
    root: '.',
    include: ['test/**/*.spec.{ts,tsx}'],
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./test/setup.ts'],
  },
});
```

---

### Test File 1: `smart-apply-backend/test/cors.spec.ts`

**Action:** CREATE

```typescript
import { describe, it, expect } from 'vitest';
import { validateCorsOrigin } from '../src/cors';

describe('validateCorsOrigin', () => {
  it('allows requests from configured web origin', () => {
    const result = validateCorsOrigin(
      'http://localhost:3000',
      ['http://localhost:3000'],
      undefined,
      false,
    );
    expect(result).toEqual({ allowed: true });
  });

  it('allows configured chrome extension ID', () => {
    const result = validateCorsOrigin(
      'chrome-extension://abcdef123',
      [],
      'abcdef123',
      true,
    );
    expect(result).toEqual({ allowed: true });
  });

  it('rejects unknown chrome extension in production', () => {
    const result = validateCorsOrigin(
      'chrome-extension://unknown',
      [],
      'abcdef123',
      true,
    );
    expect(result).toEqual({ allowed: false, error: 'CORS not allowed' });
  });

  it('allows any extension in dev mode without CHROME_EXTENSION_ID', () => {
    const result = validateCorsOrigin(
      'chrome-extension://anything',
      [],
      undefined,
      false,
    );
    expect(result).toEqual({ allowed: true });
  });

  it('rejects extensions in production without CHROME_EXTENSION_ID', () => {
    const result = validateCorsOrigin(
      'chrome-extension://anything',
      [],
      undefined,
      true,
    );
    expect(result).toEqual({ allowed: false, error: 'CORS not allowed' });
  });

  it('allows same-origin (undefined origin)', () => {
    const result = validateCorsOrigin(
      undefined,
      ['http://localhost:3000'],
      undefined,
      true,
    );
    expect(result).toEqual({ allowed: true });
  });
});
```

---

### Test File 2: `smart-apply-backend/test/webhooks.controller.spec.ts` — EXTEND

**Action:** MODIFY — Add a new `describe('Webhook Audit Events', ...)` block at the end of the existing file, inside the outer `describe`.

Append before the final closing `});`:

```typescript
  describe('Webhook Audit Events', () => {
    it('inserts audit_events row after user deletion', async () => {
      (service as any).wh = {
        verify: vi.fn().mockReturnValue({
          type: 'user.deleted',
          data: { id: 'user_to_delete' },
        }),
      };

      const mockEq = vi.fn().mockReturnValue({ error: null });
      const mockDeleteFn = vi.fn().mockReturnValue({ eq: mockEq });
      const mockInsert = vi.fn().mockReturnValue({ error: null });
      mockSupabase.admin.from.mockReturnValue({ delete: mockDeleteFn, insert: mockInsert });

      const rawBody = Buffer.from('{"type":"user.deleted","data":{"id":"user_to_delete"}}');
      const req = {
        headers: {
          'webhook-id': 'wh_123',
          'webhook-timestamp': '1234567890',
          'webhook-signature': 'v1,sig',
        },
        rawBody,
      } as any;

      await controller.handleClerk(req);
      expect(mockSupabase.admin.from).toHaveBeenCalledWith('audit_events');
      expect(mockInsert).toHaveBeenCalledWith({
        clerk_user_id: 'user_to_delete',
        event_type: 'user.deleted',
        metadata: {},
      });
    });

    it('audit event contains clerk_user_id and event_type', async () => {
      (service as any).wh = {
        verify: vi.fn().mockReturnValue({
          type: 'user.deleted',
          data: { id: 'user_audit_check' },
        }),
      };

      const mockEq = vi.fn().mockReturnValue({ error: null });
      const mockDeleteFn = vi.fn().mockReturnValue({ eq: mockEq });
      const mockInsert = vi.fn().mockReturnValue({ error: null });
      mockSupabase.admin.from.mockReturnValue({ delete: mockDeleteFn, insert: mockInsert });

      const rawBody = Buffer.from('{"type":"user.deleted","data":{"id":"user_audit_check"}}');
      const req = {
        headers: {
          'webhook-id': 'wh_789',
          'webhook-timestamp': '1234567890',
          'webhook-signature': 'v1,sig',
        },
        rawBody,
      } as any;

      await controller.handleClerk(req);
      const insertArg = mockInsert.mock.calls[0][0];
      expect(insertArg).toMatchObject({
        clerk_user_id: 'user_audit_check',
        event_type: 'user.deleted',
      });
    });

    it('does not block deletion if audit insert fails', async () => {
      (service as any).wh = {
        verify: vi.fn().mockReturnValue({
          type: 'user.deleted',
          data: { id: 'user_audit_fail' },
        }),
      };

      const mockEq = vi.fn().mockReturnValue({ error: null });
      const mockDeleteFn = vi.fn().mockReturnValue({ eq: mockEq });
      const mockInsert = vi.fn().mockReturnValue({ error: { message: 'DB error' } });
      mockSupabase.admin.from.mockReturnValue({ delete: mockDeleteFn, insert: mockInsert });

      const rawBody = Buffer.from('{"type":"user.deleted","data":{"id":"user_audit_fail"}}');
      const req = {
        headers: {
          'webhook-id': 'wh_audit_fail',
          'webhook-timestamp': '1234567890',
          'webhook-signature': 'v1,sig',
        },
        rawBody,
      } as any;

      const result = await controller.handleClerk(req);
      expect(result).toEqual({ received: true });
      expect(mockDeleteFn).toHaveBeenCalled();
    });
  });
```

---

### Test File 3: `smart-apply-extension/test/pdf-generator.spec.ts`

**Action:** CREATE

```typescript
import { describe, it, expect } from 'vitest';
import { generateResumePDF } from '../src/lib/pdf-generator';

const validInput = {
  name: 'John Doe',
  email: 'john@example.com',
  phone: '555-0100',
  summary: 'Experienced full-stack developer.',
  experience: [
    {
      title: 'Engineer',
      company: 'Acme',
      dates: '2020-2023',
      bullets: ['Built APIs', 'Led team'],
    },
  ],
  skills: ['TypeScript', 'React', 'Node.js'],
};

describe('generateResumePDF', () => {
  it('produces non-empty Uint8Array for valid input', async () => {
    const result = await generateResumePDF(validInput);
    expect(result).toBeInstanceOf(Uint8Array);
    expect(result.length).toBeGreaterThan(0);
  });

  it('produces valid PDF header bytes', async () => {
    const result = await generateResumePDF(validInput);
    const header = new TextDecoder().decode(result.slice(0, 5));
    expect(header).toBe('%PDF-');
  });

  it('handles empty experience array', async () => {
    const result = await generateResumePDF({ ...validInput, experience: [] });
    expect(result).toBeInstanceOf(Uint8Array);
    expect(result.length).toBeGreaterThan(0);
  });

  it('handles empty skills array', async () => {
    const result = await generateResumePDF({ ...validInput, skills: [] });
    expect(result).toBeInstanceOf(Uint8Array);
    expect(result.length).toBeGreaterThan(0);
  });
});
```

---

### Test File 4: `smart-apply-extension/test/service-worker.spec.ts` — EXTEND

**Action:** MODIFY — Add a new `describe('OPTIMIZE_JD', ...)` block at the end of the outer describe, before the final `});`.

Use the existing `mockApiFetch`, `mockSetStorage` mocks already declared at file top.

Append:

```typescript
  describe('OPTIMIZE_JD', () => {
    const mockOptimizeResult = {
      ats_score_before: 45,
      ats_score_after: 85,
      extracted_requirements: {
        hard_skills: ['TypeScript'],
        soft_skills: ['leadership'],
        certifications: [],
      },
      suggested_changes: [],
      optimized_resume_json: {
        summary: 'Optimized',
        skills: ['TypeScript'],
        experiences: [],
        warnings: [],
      },
    };

    it('calls /api/optimize with JD payload', async () => {
      mockApiFetch.mockResolvedValueOnce(mockOptimizeResult);

      await new Promise<void>((resolve) => {
        messageHandler(
          {
            type: 'OPTIMIZE_JD',
            payload: {
              jdText: 'We need a TypeScript developer...',
              company: 'Acme',
              jobTitle: 'Engineer',
              sourceUrl: 'https://linkedin.com/jobs/123',
            },
          },
          {},
          (response) => {
            expect(mockApiFetch).toHaveBeenCalledWith('/api/optimize', {
              method: 'POST',
              body: expect.stringContaining('"job_description_text"'),
            });
            resolve();
          },
        );
      });
    });

    it('stores optimize context in storage on success', async () => {
      mockApiFetch.mockResolvedValueOnce(mockOptimizeResult);

      await new Promise<void>((resolve) => {
        messageHandler(
          {
            type: 'OPTIMIZE_JD',
            payload: {
              jdText: 'Looking for a React developer...',
              company: 'TechCo',
              jobTitle: 'Frontend Dev',
              sourceUrl: 'https://indeed.com/jobs/456',
            },
          },
          {},
          () => {
            expect(mockSetStorage).toHaveBeenCalledWith(
              'last_optimize_context',
              expect.objectContaining({ company: 'TechCo', jobTitle: 'Frontend Dev' }),
            );
            expect(mockSetStorage).toHaveBeenCalledWith(
              'last_optimized_at',
              expect.any(String),
            );
            resolve();
          },
        );
      });
    });

    it('returns { success: true, data } on success', async () => {
      mockApiFetch.mockResolvedValueOnce(mockOptimizeResult);

      await new Promise<void>((resolve) => {
        messageHandler(
          {
            type: 'OPTIMIZE_JD',
            payload: {
              jdText: 'Need a Node.js engineer with 5 years exp...',
              company: 'StartupX',
              jobTitle: 'Backend',
              sourceUrl: 'https://linkedin.com/jobs/789',
            },
          },
          {},
          (response: any) => {
            expect(response.success).toBe(true);
            expect(response.data).toMatchObject({
              ats_score_before: 45,
              ats_score_after: 85,
            });
            resolve();
          },
        );
      });
    });
  });
```

---

### Test File 5: `smart-apply-web/test/components/optimize-form.spec.tsx`

**Action:** CREATE — also create `test/components/` directory.

```tsx
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

// Mock @clerk/nextjs
const mockGetToken = vi.fn().mockResolvedValue('test-token');
vi.mock('@clerk/nextjs', () => ({
  useAuth: () => ({ getToken: mockGetToken }),
}));

// Mock api-client
const mockApiFetch = vi.fn();
vi.mock('@/lib/api-client', () => ({
  apiFetch: (...args: unknown[]) => mockApiFetch(...args),
}));

// Mock OptimizeResults (child component) to isolate
vi.mock('@/components/optimize/optimize-results', () => ({
  OptimizeResults: () => <div data-testid="optimize-results">Results</div>,
}));

import { OptimizeForm } from '../../src/components/optimize/optimize-form';

describe('OptimizeForm', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders JD textarea and submit button', () => {
    render(<OptimizeForm />);
    expect(
      screen.getByPlaceholderText('Paste the full job description here...'),
    ).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Optimize Resume' })).toBeInTheDocument();
  });

  it('submits JD text to optimize API', async () => {
    const user = userEvent.setup();
    mockApiFetch.mockResolvedValueOnce({
      ats_score_before: 45,
      ats_score_after: 82,
      extracted_requirements: { hard_skills: [], soft_skills: [], certifications: [] },
      suggested_changes: [],
      optimized_resume_json: { summary: null, skills: [], experiences: [], warnings: [] },
    });

    render(<OptimizeForm />);

    await user.type(screen.getByLabelText('Company Name'), 'Acme');
    await user.type(screen.getByLabelText('Job Title'), 'Engineer');
    await user.type(
      screen.getByPlaceholderText('Paste the full job description here...'),
      'A'.repeat(60),
    );
    await user.click(screen.getByRole('button', { name: 'Optimize Resume' }));

    await waitFor(() => {
      expect(mockApiFetch).toHaveBeenCalledWith(
        '/api/optimize',
        'test-token',
        expect.objectContaining({ method: 'POST' }),
      );
    });
  });

  it('shows loading state during submission', async () => {
    const user = userEvent.setup();
    let resolveApi!: (value: unknown) => void;
    mockApiFetch.mockReturnValueOnce(new Promise((r) => { resolveApi = r; }));

    render(<OptimizeForm />);

    await user.type(screen.getByLabelText('Company Name'), 'Acme');
    await user.type(screen.getByLabelText('Job Title'), 'Engineer');
    await user.type(
      screen.getByPlaceholderText('Paste the full job description here...'),
      'A'.repeat(60),
    );
    await user.click(screen.getByRole('button', { name: 'Optimize Resume' }));

    await waitFor(() => {
      expect(screen.getByRole('button', { name: 'Optimizing...' })).toBeDisabled();
    });

    // Cleanup: resolve the pending API call
    resolveApi({
      ats_score_before: 0, ats_score_after: 0,
      extracted_requirements: { hard_skills: [], soft_skills: [], certifications: [] },
      suggested_changes: [],
      optimized_resume_json: { summary: null, skills: [], experiences: [], warnings: [] },
    });
  });

  it('shows error message on API failure', async () => {
    const user = userEvent.setup();
    mockApiFetch.mockRejectedValueOnce(new Error('Server error'));

    render(<OptimizeForm />);

    await user.type(screen.getByLabelText('Company Name'), 'Acme');
    await user.type(screen.getByLabelText('Job Title'), 'Engineer');
    await user.type(
      screen.getByPlaceholderText('Paste the full job description here...'),
      'A'.repeat(60),
    );
    await user.click(screen.getByRole('button', { name: 'Optimize Resume' }));

    await waitFor(() => {
      expect(screen.getByText('Server error')).toBeInTheDocument();
    });
  });
});
```

---

### Test File 6: `smart-apply-web/test/components/optimize-results.spec.tsx`

**Action:** CREATE

```tsx
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import type { OptimizeResponse } from '@smart-apply/shared';

// Mock @clerk/nextjs
const mockGetToken = vi.fn().mockResolvedValue('test-token');
vi.mock('@clerk/nextjs', () => ({
  useAuth: () => ({ getToken: mockGetToken }),
}));

// Mock api-client
const mockApiFetch = vi.fn();
vi.mock('@/lib/api-client', () => ({
  apiFetch: (...args: unknown[]) => mockApiFetch(...args),
}));

// Mock pdf-lib (dynamic import in component)
vi.mock('pdf-lib', () => ({
  PDFDocument: {
    create: vi.fn().mockResolvedValue({
      embedFont: vi.fn().mockResolvedValue({ widthOfTextAtSize: vi.fn().mockReturnValue(100) }),
      addPage: vi.fn().mockReturnValue({
        drawText: vi.fn(),
        getSize: vi.fn().mockReturnValue({ width: 612, height: 792 }),
      }),
      save: vi.fn().mockResolvedValue(new Uint8Array([37, 80, 68, 70])),
    }),
  },
  StandardFonts: { Helvetica: 'Helvetica', HelveticaBold: 'Helvetica-Bold' },
  rgb: vi.fn().mockReturnValue({}),
}));

import { OptimizeResults } from '../../src/components/optimize/optimize-results';

const mockResult: OptimizeResponse = {
  ats_score_before: 45,
  ats_score_after: 82,
  extracted_requirements: {
    hard_skills: ['TypeScript'],
    soft_skills: ['leadership'],
    certifications: [],
  },
  optimized_resume_json: {
    summary: 'Optimized summary',
    skills: ['TypeScript', 'React'],
    experiences: [],
    warnings: [],
  },
  suggested_changes: [
    {
      type: 'summary_update',
      target_section: 'summary',
      before: 'Old summary',
      after: 'New summary',
      reason: 'Better keywords',
      confidence: 0.9,
    },
    {
      type: 'skills_insertion',
      target_section: 'skills',
      before: null,
      after: 'React, TypeScript',
      reason: 'Missing skills',
      confidence: 0.7,
    },
    {
      type: 'warning',
      target_section: 'warning',
      before: null,
      after: null,
      reason: 'Company uses ATS filter',
      confidence: null,
    },
  ],
};

function renderWithProviders(ui: React.ReactElement) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={queryClient}>{ui}</QueryClientProvider>,
  );
}

describe('OptimizeResults', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    // Profile query mock
    mockApiFetch.mockResolvedValue({
      id: 'prof-1',
      clerk_user_id: 'user_1',
      full_name: 'Jane Doe',
      email: 'jane@example.com',
      phone: '555-0100',
      location: 'SF',
      linkedin_url: null,
      portfolio_url: null,
      summary: 'Engineer',
      base_skills: ['TypeScript'],
      certifications: [],
      experiences: [],
      education: [],
      raw_profile_source: null,
      profile_version: 1,
      created_at: '2024-01-01T00:00:00Z',
      updated_at: '2024-01-01T00:00:00Z',
    });
  });

  it('displays before and after ATS scores', () => {
    renderWithProviders(
      <OptimizeResults result={mockResult} companyName="Acme" onBack={vi.fn()} />,
    );
    expect(screen.getByText('45%')).toBeInTheDocument();
    expect(screen.getByText('82%')).toBeInTheDocument();
  });

  it('renders suggested changes with checkboxes', () => {
    renderWithProviders(
      <OptimizeResults result={mockResult} companyName="Acme" onBack={vi.fn()} />,
    );
    const checkboxes = screen.getAllByRole('checkbox');
    // 2 non-warning changes have checkboxes
    expect(checkboxes).toHaveLength(2);
  });

  it('toggles change selection on click', async () => {
    const user = userEvent.setup();
    renderWithProviders(
      <OptimizeResults result={mockResult} companyName="Acme" onBack={vi.fn()} />,
    );
    const checkboxes = screen.getAllByRole('checkbox');
    const firstCheckbox = checkboxes[0] as HTMLInputElement;

    // Initial state: checked (confidence 0.9 >= 0.6)
    expect(firstCheckbox.checked).toBe(true);
    await user.click(firstCheckbox);
    expect(firstCheckbox.checked).toBe(false);
  });

  it('displays warning messages', () => {
    renderWithProviders(
      <OptimizeResults result={mockResult} companyName="Acme" onBack={vi.fn()} />,
    );
    expect(screen.getByText(/Company uses ATS filter/)).toBeInTheDocument();
  });

  it('renders confidence badges', () => {
    renderWithProviders(
      <OptimizeResults result={mockResult} companyName="Acme" onBack={vi.fn()} />,
    );
    expect(screen.getByText('90%')).toBeInTheDocument();
    expect(screen.getByText('70%')).toBeInTheDocument();
  });
});
```

---

### Test File 7: `smart-apply-web/test/components/dashboard-shell.spec.tsx`

**Action:** CREATE

```tsx
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

// Mock @clerk/nextjs
const mockGetToken = vi.fn().mockResolvedValue('test-token');
vi.mock('@clerk/nextjs', () => ({
  useAuth: () => ({ getToken: mockGetToken }),
}));

// Mock api-client
const mockApiFetch = vi.fn();
vi.mock('@/lib/api-client', () => ({
  apiFetch: (...args: unknown[]) => mockApiFetch(...args),
}));

// Mock child components to isolate DashboardShell
vi.mock('@/components/dashboard/applications-table', () => ({
  ApplicationsTable: ({ items }: { items: unknown[] }) => (
    <div data-testid="applications-table">{items.length} items</div>
  ),
}));
vi.mock('@/components/dashboard/stats-cards', () => ({
  StatsCards: () => <div data-testid="stats-cards">Stats</div>,
}));

import { DashboardShell } from '../../src/components/dashboard/dashboard-shell';

function renderWithProviders(ui: React.ReactElement) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={queryClient}>{ui}</QueryClientProvider>,
  );
}

describe('DashboardShell', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('fetches and renders application history', async () => {
    mockApiFetch.mockResolvedValueOnce({
      items: [
        {
          id: 'app-1',
          clerk_user_id: 'u1',
          company_name: 'Acme',
          job_title: 'Engineer',
          source_platform: 'linkedin',
          source_url: null,
          job_description_hash: null,
          drive_link: null,
          ats_score_before: 45,
          ats_score_after: 82,
          applied_resume_snapshot: null,
          status: 'applied',
          created_at: '2024-01-01T00:00:00Z',
          applied_at: '2024-01-01T00:00:00Z',
          updated_at: '2024-01-01T00:00:00Z',
        },
      ],
    });

    renderWithProviders(<DashboardShell />);

    await waitFor(() => {
      expect(screen.getByTestId('applications-table')).toBeInTheDocument();
    });
  });

  it('shows empty state when no applications', async () => {
    mockApiFetch.mockResolvedValueOnce({ items: [] });

    renderWithProviders(<DashboardShell />);

    await waitFor(() => {
      expect(screen.getByText('No applications yet.')).toBeInTheDocument();
    });
  });

  it('shows loading state while fetching', () => {
    mockApiFetch.mockReturnValueOnce(new Promise(() => {}));

    renderWithProviders(<DashboardShell />);

    expect(screen.getByText('Loading applications...')).toBeInTheDocument();
  });
});
```

---

### Test File 8: `smart-apply-web/test/components/profile-editor.spec.tsx`

**Action:** CREATE

```tsx
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

// Mock @clerk/nextjs
const mockGetToken = vi.fn().mockResolvedValue('test-token');
vi.mock('@clerk/nextjs', () => ({
  useAuth: () => ({ getToken: mockGetToken }),
}));

// Mock api-client
const mockApiFetch = vi.fn();
vi.mock('@/lib/api-client', () => ({
  apiFetch: (...args: unknown[]) => mockApiFetch(...args),
}));

import { ProfileEditor } from '../../src/components/profile/profile-editor';

const mockProfile = {
  id: 'prof-1',
  clerk_user_id: 'user_1',
  full_name: 'Jane Doe',
  email: 'jane@example.com',
  phone: '555-0100',
  location: 'San Francisco, CA',
  linkedin_url: null,
  portfolio_url: null,
  summary: 'Experienced engineer',
  base_skills: ['TypeScript', 'React'],
  certifications: [],
  experiences: [],
  education: [],
  raw_profile_source: null,
  profile_version: 1,
  created_at: '2024-01-01T00:00:00Z',
  updated_at: '2024-01-01T00:00:00Z',
};

function renderWithProviders(ui: React.ReactElement) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={queryClient}>{ui}</QueryClientProvider>,
  );
}

describe('ProfileEditor', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockApiFetch.mockResolvedValue(mockProfile);
  });

  it('loads and displays profile data', async () => {
    renderWithProviders(<ProfileEditor />);

    await waitFor(() => {
      expect(screen.getByText('Jane Doe')).toBeInTheDocument();
    });
    expect(screen.getByText('jane@example.com')).toBeInTheDocument();
  });

  it('submits updated profile on save', async () => {
    const user = userEvent.setup();
    renderWithProviders(<ProfileEditor />);

    await waitFor(() => {
      expect(screen.getByText('Jane Doe')).toBeInTheDocument();
    });

    await user.click(screen.getByRole('button', { name: /edit profile/i }));

    const nameInput = screen.getByLabelText(/full name/i);
    await user.clear(nameInput);
    await user.type(nameInput, 'Jane Smith');
    await user.click(screen.getByRole('button', { name: /save changes/i }));

    await waitFor(() => {
      expect(mockApiFetch).toHaveBeenCalledWith(
        '/api/profile/me',
        'test-token',
        expect.objectContaining({ method: 'PATCH' }),
      );
    });
  });

  it('shows validation errors on invalid input', async () => {
    const user = userEvent.setup();
    renderWithProviders(<ProfileEditor />);

    await waitFor(() => {
      expect(screen.getByText('Jane Doe')).toBeInTheDocument();
    });

    await user.click(screen.getByRole('button', { name: /edit profile/i }));

    const nameInput = screen.getByLabelText(/full name/i);
    await user.clear(nameInput);
    await user.click(screen.getByRole('button', { name: /save changes/i }));

    await waitFor(() => {
      // Zod validation error from zodResolver
      expect(screen.getByText(/required|too short|invalid/i)).toBeInTheDocument();
    });
  });
});
```

---

### Test File 9: `smart-apply-web/test/components/settings-page.spec.tsx`

**Action:** CREATE

```tsx
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

// Mock @clerk/nextjs
const mockGetToken = vi.fn().mockResolvedValue('test-token');
const mockSignOut = vi.fn().mockResolvedValue(undefined);
vi.mock('@clerk/nextjs', () => ({
  useUser: () => ({
    user: {
      fullName: 'Jane Doe',
      primaryEmailAddress: { emailAddress: 'jane@example.com' },
      createdAt: new Date('2024-01-15T00:00:00Z'),
    },
  }),
  useAuth: () => ({
    getToken: mockGetToken,
    signOut: mockSignOut,
  }),
}));

// Mock api-client
const mockApiFetch = vi.fn();
vi.mock('@/lib/api-client', () => ({
  apiFetch: (...args: unknown[]) => mockApiFetch(...args),
}));

import { SettingsPage } from '../../src/components/settings/settings-page';

describe('SettingsPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('displays account information', () => {
    render(<SettingsPage />);
    expect(screen.getByText('Jane Doe')).toBeInTheDocument();
    expect(screen.getByText('jane@example.com')).toBeInTheDocument();
  });

  it('shows delete confirmation dialog on button click', async () => {
    const user = userEvent.setup();
    render(<SettingsPage />);

    await user.click(screen.getByRole('button', { name: 'Delete Account' }));

    expect(screen.getByText(/Type/)).toBeInTheDocument();
    expect(screen.getByPlaceholderText('Type DELETE to confirm')).toBeInTheDocument();
  });

  it('enables confirm button when DELETE is typed', async () => {
    const user = userEvent.setup();
    render(<SettingsPage />);

    await user.click(screen.getByRole('button', { name: 'Delete Account' }));
    await user.type(screen.getByPlaceholderText('Type DELETE to confirm'), 'DELETE');

    const confirmBtn = screen.getByRole('button', { name: /permanently delete account/i });
    expect(confirmBtn).not.toBeDisabled();
  });

  it('calls delete API and signs out on confirm', async () => {
    const user = userEvent.setup();
    mockApiFetch.mockResolvedValueOnce(undefined);

    render(<SettingsPage />);

    await user.click(screen.getByRole('button', { name: 'Delete Account' }));
    await user.type(screen.getByPlaceholderText('Type DELETE to confirm'), 'DELETE');
    await user.click(screen.getByRole('button', { name: /permanently delete account/i }));

    await waitFor(() => {
      expect(mockApiFetch).toHaveBeenCalledWith(
        '/api/account',
        'test-token',
        expect.objectContaining({ method: 'DELETE' }),
      );
    });
    await waitFor(() => {
      expect(mockSignOut).toHaveBeenCalled();
    });
  });
});
```

---

### Verify Red Phase

```bash
# Backend (6 CORS tests should fail — cors.ts doesn't exist yet)
cd smart-apply-backend && npx vitest run --reporter=verbose 2>&1 | tail -20

# Extension (PDF + OPTIMIZE_JD tests should pass since they test existing code)
cd smart-apply-extension && npx vitest run --reporter=verbose 2>&1 | tail -20

# Web (all component tests should fail — @/ alias not configured + mocks needed)
cd smart-apply-web && npx vitest run --reporter=verbose 2>&1 | tail -20
```

**Expected:** Backend CORS tests fail (module not found). Extension tests may pass already (testing existing code). Web component tests fail until alias is configured.

---

## Step 2: Implement (TDD — Green Phase)

Implement the minimum code to make all tests pass.

### File 1: `smart-apply-backend/src/cors.ts`

**Action:** CREATE

```typescript
export function validateCorsOrigin(
  origin: string | undefined,
  allowedOrigins: string[],
  extensionId: string | undefined,
  isProd: boolean,
): { allowed: boolean; error?: string } {
  // Same-origin or server-to-server
  if (!origin) {
    return { allowed: true };
  }

  // Configured web origins
  if (allowedOrigins.includes(origin)) {
    return { allowed: true };
  }

  // Known Chrome extension
  if (extensionId && origin === `chrome-extension://${extensionId}`) {
    return { allowed: true };
  }

  // Dev-mode: allow any extension when no ID configured
  if (!isProd && !extensionId && /^chrome-extension:\/\//.test(origin)) {
    return { allowed: true };
  }

  return { allowed: false, error: 'CORS not allowed' };
}
```

### File 2: `smart-apply-backend/src/main.ts`

**Action:** MODIFY — replace the inline CORS callback with a call to `validateCorsOrigin`.

Replace the `app.enableCors(...)` block:

```typescript
import { validateCorsOrigin } from './cors';
```

And update the origin callback to:

```typescript
  app.enableCors({
    origin: (origin: string | undefined, callback: (err: Error | null, allow?: boolean) => void) => {
      const result = validateCorsOrigin(origin, allowedOrigins, extId, isProd);
      if (result.allowed) {
        callback(null, true);
      } else {
        callback(new Error(result.error ?? 'CORS not allowed'));
      }
    },
    credentials: true,
  });
```

### File 3: `smart-apply-web/vitest.config.ts`

**Action:** MODIFY — add `resolve.alias` for `@/` path.

Full file:
```typescript
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  test: {
    root: '.',
    include: ['test/**/*.spec.{ts,tsx}'],
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./test/setup.ts'],
  },
});
```

### Verify Green Phase

```bash
# Backend — all 29 tests pass (23 existing + 6 new CORS)
cd smart-apply-backend && npx vitest run --reporter=verbose

# Extension — all 24 tests pass (17 existing + 4 PDF + 3 OPTIMIZE_JD)
cd smart-apply-extension && npx vitest run --reporter=verbose

# Web — all 29 tests pass (10 existing + 19 new component tests)
cd smart-apply-web && npx vitest run --reporter=verbose
```

**Expected total: ≥ 101 tests (29 + 24 + 29 = 82 + existing beyond test files)**

**Note:** The webhook audit tests (3) are added to the existing webhook test file, so backend total includes those: 23 existing + 6 CORS + 3 audit = 32.

Adjusted totals: **32 backend + 24 extension + 29 web = 85 minimum.**

---

## Step 3: Refactor

Review implementation for:
- [ ] No duplicated code across test files — common mock setup can remain inline since each file needs different mocks
- [ ] `validateCorsOrigin` is a pure function with no side effects ✓
- [ ] No `console.log` in test files
- [ ] No `any` type usage in new test files (minimize — use `as any` only for request mocks in webhooks tests where HTTP request shape is complex)

### Verify After Refactor

```bash
# Run ALL tests across ALL packages
cd smart-apply-backend && npx vitest run
cd smart-apply-extension && npx vitest run
cd smart-apply-web && npx vitest run

# TypeScript check all packages
cd smart-apply-backend && npx tsc --noEmit
cd smart-apply-web && npx tsc --noEmit
cd smart-apply-extension && npx tsc --noEmit
cd smart-apply-shared && npx tsc --noEmit
```

**Expected:** ALL tests still pass, zero TypeScript errors.

---

## Step 4: Integration Check

### Manual Verification Steps

1. **Backend CORS:** Verify the refactored `main.ts` behaves identically:
   - `curl -H "Origin: http://localhost:3000" http://localhost:3001/health` → should return CORS headers
   - Production behavior: only configured origins pass

2. **No production behavior change:** The only production code change is extracting CORS logic into a function. The callback signature and behavior remain identical.

3. **Test count verification:**
   ```bash
   cd smart-apply-backend && npx vitest run 2>&1 | grep "Tests"
   cd smart-apply-extension && npx vitest run 2>&1 | grep "Tests"
   cd smart-apply-web && npx vitest run 2>&1 | grep "Tests"
   ```

### Cross-Phase Verification

- Verify shared package builds: `cd smart-apply-shared && npx tsc --noEmit`
- Verify Phase P04 features still work: all existing 66 tests pass as part of the full suite

---

## Rollback Plan

If implementation breaks existing functionality:

1. `git stash` current changes
2. Verify existing tests pass: run `npx vitest run` in each package
3. Identify the breaking change:
   - If CORS tests fail → check `cors.ts` logic matches original `main.ts` inline callback exactly
   - If web component tests fail → check `resolve.alias` config and mock paths
   - If webhook audit tests fail → check `mockSupabase.admin.from` mock return chain
4. Fix incrementally and re-run the specific failing suite
