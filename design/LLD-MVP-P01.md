---
title: "LLD-MVP-P01 — P0 Critical Fixes (Detailed Design)"
permalink: /design/lld-mvp-p01/
---

# LLD-MVP-P01 — P0 Critical Fixes (Detailed Design)

**Phase:** P0 Launch Blockers
**Version:** 1.0
**Date:** 2026-03-28
**Input:** HLD-MVP-P01.md + architecture.md

---

## 1. File-Level Change Manifest

| # | File | Action | Purpose |
|---|---|---|---|
| 1 | `smart-apply-backend/src/main.ts` | MODIFY | Externalize CORS origins |
| 2 | `smart-apply-backend/.env.example` | MODIFY | Add `ALLOWED_ORIGINS` |
| 3 | `smart-apply-extension/src/lib/api-client.ts` | MODIFY | Use `VITE_API_BASE_URL` env var |
| 4 | `smart-apply-extension/src/lib/config.ts` | CREATE | Centralized extension config |
| 5 | `smart-apply-extension/src/ui/popup/App.tsx` | MODIFY | Use config URLs; apply approved changes; handle TRIGGER messages via background |
| 6 | `smart-apply-extension/src/background/service-worker.ts` | MODIFY | Add external message listener for auth; relay popup→content triggers |
| 7 | `smart-apply-extension/src/content/jd-detector.ts` | MODIFY | Add TRIGGER_OPTIMIZE listener |
| 8 | `smart-apply-extension/src/content/linkedin-profile.ts` | MODIFY | Add TRIGGER_SYNC listener |
| 9 | `smart-apply-extension/src/manifest.ts` | MODIFY | Add `externally_connectable` for web→ext messaging |
| 10 | `smart-apply-extension/.env.example` | CREATE | Document env vars |
| 11 | `smart-apply-web/src/app/auth/extension-callback/page.tsx` | CREATE | Auth bridge callback page |
| 12 | `smart-apply-web/src/middleware.ts` | MODIFY | Allow `/auth/extension-callback` as protected route |

---

## 2. Detailed Design Per File

### 2.1 Backend: `main.ts` — Externalize CORS (REQ-01-05)

**Change:** Read `ALLOWED_ORIGINS` from env, split by comma, fallback to dev defaults.

```typescript
const allowedOrigins = config.get<string>('ALLOWED_ORIGINS', 'http://localhost:3000')
  .split(',')
  .map(o => o.trim());

app.enableCors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes(origin) || /^chrome-extension:\/\//.test(origin ?? '')) {
      callback(null, true);
    } else {
      callback(new Error('CORS not allowed'));
    }
  },
  credentials: true,
});
```

### 2.2 Extension: `config.ts` — Centralized Config (REQ-01-05)

**New file:** Single source of truth for all environment-configured URLs.

```typescript
export const config = {
  apiBaseUrl: import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:3001',
  webBaseUrl: import.meta.env.VITE_WEB_BASE_URL ?? 'http://localhost:3000',
} as const;
```

### 2.3 Extension: `api-client.ts` — Use Config (REQ-01-05)

**Change:** Import `config.apiBaseUrl` instead of hardcoded string.

### 2.4 Extension: `App.tsx` — Multiple Fixes

#### 2.4.1 URL Externalization (REQ-01-05)
Replace `http://localhost:3000` references with `config.webBaseUrl`.

#### 2.4.2 Auth Bridge (REQ-01-02)
Change sign-in button to open `{webBaseUrl}/auth/extension-callback`.

#### 2.4.3 Message Flow Fix (REQ-01-03)
Change TRIGGER_SYNC and TRIGGER_OPTIMIZE to send to **background** instead of content script:
```typescript
// Before (broken): chrome.tabs.sendMessage(tabs[0].id, { type: 'TRIGGER_SYNC' })
// After: chrome.runtime.sendMessage({ type: 'TRIGGER_SYNC' })
```
Background then relays to content script.

#### 2.4.4 Apply Approved Changes (REQ-01-04)
In `handleGeneratePdf`, build a merged resume from selected changes:

```typescript
function buildApprovedResume(
  cachedProfile: Record<string, unknown>,
  optimizeResult: OptimizeResponse,
  selectedChanges: Set<number>,
): { summary: string; skills: string[]; experiences: ExperienceItem[] } {
  let summary = (cachedProfile.summary as string) ?? '';
  let skills = [...(cachedProfile.base_skills as string[] ?? [])];
  let experiences = JSON.parse(JSON.stringify(cachedProfile.experiences ?? []));

  optimizeResult.suggested_changes.forEach((change, index) => {
    if (!selectedChanges.has(index)) return;
    switch (change.type) {
      case 'summary_update':
        summary = change.after ?? summary;
        break;
      case 'skills_insertion':
        if (change.after) skills = [...new Set([...skills, ...change.after.split(', ')])];
        break;
      case 'bullet_injection':
        // Find matching experience bullet and replace
        for (const exp of experiences) {
          const bulletIdx = exp.description.indexOf(change.before);
          if (bulletIdx !== -1) {
            exp.description[bulletIdx] = change.after;
            break;
          }
        }
        break;
    }
  });

  return { summary, skills, experiences };
}
```

### 2.5 Extension: `service-worker.ts` — Handle Triggers & Auth (REQ-01-02, REQ-01-03)

**Add TRIGGER_SYNC handler:** Get active tab → send message to content script to extract → process response.

**Add TRIGGER_OPTIMIZE handler:** Get active tab → send message to content script to extract JD → call optimize API → send result back to popup.

**Add external message listener** for auth token from web callback page:
```typescript
chrome.runtime.onMessageExternal.addListener((message, sender, sendResponse) => {
  if (message.type === 'AUTH_TOKEN' && message.token) {
    chrome.storage.local.set({ auth_token: message.token }, () => {
      sendResponse({ success: true });
    });
  }
  return true;
});
```

### 2.6 Content Scripts: Add TRIGGER Listeners (REQ-01-03)

**jd-detector.ts:** Add listener for `TRIGGER_OPTIMIZE` message from background:
```typescript
chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message.type === 'TRIGGER_OPTIMIZE') {
    const jdText = extractJDText();
    const meta = extractJobMeta();
    sendResponse({ jdText, ...meta, sourceUrl: window.location.href });
  }
  return true;
});
```

**linkedin-profile.ts:** Add listener for `TRIGGER_SYNC` message:
```typescript
chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message.type === 'TRIGGER_SYNC') {
    const text = extractProfileText();
    sendResponse({ rawText: text, sourceUrl: window.location.href });
  }
  return true;
});
```

### 2.7 Extension: `manifest.ts` — External Connectivity (REQ-01-02)

Add `externally_connectable` to allow the web portal to send messages:
```typescript
externally_connectable: {
  matches: ['http://localhost:3000/*', 'https://*.smart-apply.com/*']
}
```

### 2.8 Web: `auth/extension-callback/page.tsx` — Auth Bridge (REQ-01-02)

Client component that:
1. Uses Clerk's `useAuth()` to get the session token
2. Reads `extensionId` from URL search params
3. Sends token to extension via `chrome.runtime.sendMessage(extensionId, ...)`
4. Shows success/failure status

### 2.9 Web: `middleware.ts` — Allow Auth Callback

Already handled — `/auth/extension-callback` is not in the protected matcher (`/dashboard(.*)` and `/profile(.*)`). However, the page itself needs Clerk auth, so it should be protected. The current pattern redirects to sign-in automatically.

Actually — the callback page SHOULD be protected. A user must be signed in to get a token. The current middleware protects `/dashboard` and `/profile`. We need to add `/auth/extension-callback` to the protected routes.

---

## 3. Alignment Checklist

- [x] All API inputs validated with Zod at boundaries (no new endpoints)
- [x] Shared schemas used — `OptimizeResponse`, `SuggestedChange`, `ExperienceItem` from @smart-apply/shared
- [x] Loading, error, empty, and success states in UI (existing, no regression)
- [x] No PII in logs (no new logging added)
- [x] TypeScript strict mode maintained
- [x] architecture.md principles not violated (client-first, zero storage, explicit approval)

---

## Architect Review

**Verdict:** APPROVED

### Summary
The LLD correctly addresses all 5 P0 blockers with minimal changes. The auth bridge via `externally_connectable` + callback page is the standard pattern for Chrome extension ↔ web app token handoff. The `buildApprovedResume` function properly applies only selected changes client-side, honoring the "explicit user approval" principle.

### Notes for Implementation
- Content script TRIGGER listeners must use `sendResponse` synchronously or return `true` for async
- The `externally_connectable` matches list should include the production web URL
- Test the auth flow with `chrome.runtime.sendMessage(extensionId)` — requires the extension to be loaded in Chrome
