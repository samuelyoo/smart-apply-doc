# Smart Apply — Release Runbook

**Version:** 1.0  
**Last Updated:** 2025-01-31

---

## 1. Prerequisites

### Accounts Required
- [Supabase](https://supabase.com) — hosted PostgreSQL with RLS
- [Render](https://render.com) — backend Docker hosting
- [Vercel](https://vercel.com) — Next.js web hosting
- [Clerk](https://clerk.com) — authentication provider
- [OpenAI](https://platform.openai.com) — LLM API
- (Optional) [Google Cloud Console](https://console.cloud.google.com) — Drive OAuth

### Tools
- Node.js 20+
- npm 10+
- Docker (for local backend testing)
- Supabase CLI (`npm i -g supabase`)
- Git

---

## 2. Environment Setup

1. Copy `.env.example` to `.env` at the repository root.
2. Fill in all values — see inline comments in `.env.example` for each variable.
3. Obtain secrets from service dashboards:
   - **Clerk:** Dashboard → API Keys → Secret Key + Publishable Key
   - **Supabase:** Project Settings → API → URL + anon key + service_role key
   - **OpenAI:** API Keys → Create new secret key
   - **Google Cloud (optional):** Credentials → OAuth 2.0 Client ID

---

## 3. Deployment Sequence

### Step 1: Database — Supabase Migrations

```bash
# Login to Supabase CLI
supabase login

# Link to your project
supabase link --project-ref <your-project-ref>

# Push migrations
supabase db push
```

**Verify:** In Supabase Dashboard → Table Editor, confirm tables exist:
`master_profiles`, `application_history`, with RLS enabled on both.

### Step 2: Backend — Deploy to Render

1. Connect your GitHub repo to Render.
2. Create a new "Blueprint" from `render.yaml`, or create a Web Service manually:
   - **Docker:** Use `smart-apply-backend/Dockerfile`
   - **Docker context:** Repository root (`.`)
   - **Health check path:** `/health`
3. Set all environment variables in Render Dashboard (see `.env.example`).
4. Deploy.

**Verify:**
```bash
curl https://smart-apply-api.onrender.com/health
# Expected: {"status":"ok","db":"connected","timestamp":"...","version":"..."}
```

### Step 3: Web — Deploy to Vercel

1. Import the repo in Vercel.
2. Set root directory to `smart-apply-web/`.
3. Set environment variables:
   - `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`
   - `CLERK_SECRET_KEY`
   - All other web-required vars
4. Deploy.

**Verify:** Navigate to the deployed URL, confirm sign-in page loads.

### Step 4: Clerk — Register Webhook

1. Clerk Dashboard → Webhooks → Add Endpoint.
2. **URL:** `https://<your-render-url>/api/webhooks/clerk`
3. **Events:** `user.deleted`
4. Copy the **Signing Secret** → set as `CLERK_WEBHOOK_SECRET` in Render env vars.
5. Redeploy backend on Render.

### Step 5: Extension — Production Build

```bash
# From repo root
VITE_API_BASE_URL=https://smart-apply-api.onrender.com \
VITE_WEB_BASE_URL=https://your-app.vercel.app \
VITE_GOOGLE_OAUTH_CLIENT_ID=your-client-id \
npm -w @smart-apply/extension run build
```

Output: `smart-apply-extension/dist/` — load unpacked in `chrome://extensions` or package for Chrome Web Store.

---

## 4. Post-Deploy Verification Checklist

| # | Check | Expected Result |
|:--|:---|:---|
| 1 | `GET /health` on backend URL | `{ "status": "ok", "db": "connected" }` |
| 2 | Sign in on web app | Clerk redirect → dashboard loads |
| 3 | Import profile (extension or web upload) | Profile appears in profile editor |
| 4 | Paste JD → run optimize (web) | ATS scores + suggested changes returned |
| 5 | Approve changes → download PDF | PDF downloads with only approved changes |
| 6 | Check application history on dashboard | New entry with correct snapshot |
| 7 | Delete account in settings | User deleted, redirected to sign-in |

---

## 5. Rollback Procedures

### Backend
- Render Dashboard → Manual Deploy → select previous commit.
- Or: `git revert HEAD && git push origin main`

### Web
- Vercel Dashboard → Deployments → Promote previous deployment to production.

### Database
- Supabase does not support automatic rollback. For schema changes, prepare a reverse migration SQL file before deploying.

### Extension
- Re-build from a previous known-good commit and reload unpacked.
