---
title: Architecture Update from Current Status
description: Prompt for updating architecture.md to reflect the actual state of the codebase based on git status and file inspection.
hero_eyebrow: Prompt guides
hero_title: Architecture update prompt
hero_summary: Inspects the repository's current state (git diff, new files, removed files) and produces an updated architecture.md that accurately reflects the implemented system.
permalink: /ai-prompts/architecture-update/
---

# Architecture Update from Current Status — Prompt

> **Purpose:** Keep `architecture.md` in sync with what has actually been built by inspecting the repo and updating every section that has drifted.
> **Input:** The current `smart-apply-doc/architecture.md` + live repository state (git status, file tree, key source files).
> **Output:** An updated `smart-apply-doc/architecture.md` with changes applied in-place (not a new file).

---

## When To Use This Prompt

- After completing one or more implementation phases — when new modules, routes, pages, or infrastructure have been added.
- Before starting the next development phase — so the Architect Agent works from an accurate baseline.
- Before generating or updating HLD/LLD documents that cross-reference `architecture.md`.
- After any structural refactoring (renaming packages, adding deployment configs, changing auth flows).

---

## Ready-To-Use Prompt

```text
You are a Solutions Architect maintaining the Smart Apply project's architecture
documentation.

## Task
Inspect the current repository state and update `smart-apply-doc/architecture.md`
so it accurately reflects the implemented system. Do NOT rewrite from scratch —
preserve the existing structure and voice, and make surgical updates only where
the document has drifted from reality.

## Step 0 — Gather Current State

Run these commands and read the outputs before making any changes:

1. `git status` — identify all new, modified, and deleted files.
2. `git diff --stat HEAD` — quantify the scope of change.
3. `find . -name '*.ts' -path '*/modules/*' | sort` — list all backend modules.
4. `ls smart-apply-web/src/app/` — list all web app routes/pages.
5. `ls smart-apply-extension/src/` — list extension source layout.
6. `ls -d supabase/ .github/ 2>/dev/null` — check for new infra folders.
7. Read the current `smart-apply-doc/architecture.md` in full.

## Step 1 — Diff Analysis

Compare the gathered state against each section of architecture.md and build a
change log:

| Section | Current Content | Actual State | Action Needed |
|:---|:---|:---|:---|
| §2 Repository Structure | {what it says} | {what exists} | {add/update/none} |
| §3 Architecture Diagram | {components shown} | {components implemented} | {add/update/none} |
| §4 Data Flow Diagrams | {flows documented} | {flows working} | {add/update/none} |
| §5 Auth Flow | {what it says} | {what is wired} | {add/update/none} |
| §6 Data Model | {tables listed} | {migrations/schema present} | {add/update/none} |
| §7 Component Responsibilities | {components listed} | {actual modules/pages} | {add/update/none} |
| §8 Deployment Architecture | {what it says} | {configs present} | {add/update/none} |
| §9 ATS Scoring Engine | {what it says} | {what scoring.service.ts does} | {add/update/none} |
| §10 AI Orchestration | {what it says} | {what llm.service.ts does} | {add/update/none} |
| §11 Security Architecture | {what it says} | {what is implemented} | {add/update/none} |
| §12 Development Phases | {phase status} | {actual progress} | {add/update/none} |

## Step 2 — Update Rules

Apply these rules when editing architecture.md:

### General
- Preserve the YAML frontmatter exactly as-is unless the title or description
  needs factual correction.
- Keep the existing Mermaid diagram syntax and styling classes.
- Do NOT remove sections — mark any deprecated content with a note about what
  replaced it.
- Do NOT add implementation details (code snippets, file paths) — keep the
  document at architecture level. Reference files only when naming a module or
  component.
- Maintain the current Mermaid classDef colour scheme for consistency.

### §2 Repository Structure
- Add any new top-level folders (e.g. `supabase/`, `.github/`).
- Update the one-line descriptions if a package's role has expanded.

### §3 Architecture Diagram (Mermaid)
- Add new backend modules as nodes (e.g. Account Service, Webhooks).
- Add new web portal pages if they represent a significant surface (e.g. Optimize
  page, Settings page).
- Add new extension components (e.g. Google Drive uploader, config module).
- Update connection arrows if data flows have changed.

### §4 Data Flow Diagrams
- If a flow now works end-to-end that was previously theoretical, update the
  sequence diagram to match the implemented message types and endpoints.
- If a new significant flow was added (e.g. account deletion, web-based optimize),
  add a new subsection.

### §5 Authentication Flow
- If the extension auth bridge is now complete or changed, update the flow.
- If webhook-based auth (e.g. Clerk webhooks) was added, document it.

### §6 Data Model
- If the migration folder now exists, note that schema is migration-managed.
- If new tables or columns were added, update the ER diagram.
- If RLS policies are now applied, note their status.

### §7 Component Responsibilities
- Add new backend modules to the table (e.g. Account, Webhooks).
- Add new web pages/components (e.g. Optimize page, Settings, Profile Upload).
- Add new extension libraries (e.g. google-drive.ts, config.ts).
- Update tech stack versions if they changed.

### §8 Deployment Architecture
- If deployment configs now exist (Dockerfile, vercel.json, GitHub Actions),
  update the diagram and note their presence.
- Move from aspirational ("can be hosted on") to factual ("deployed via").

### §9 ATS Scoring Engine
- If role relevance or seniority scoring are now implemented (were previously
  returning fixed values), update the description.
- Note any new scoring dimensions or caps.

### §10 AI Orchestration Pipeline
- If LLM methods are now implemented (were previously stubs), update the
  pipeline description.
- If new LLM methods were added, document them.

### §11 Security Architecture
- If webhook signature verification was added, note it.
- If account deletion cascade is implemented, update the row.
- If new security measures were added (e.g. input validation, CORS changes),
  add them.

### §12 Development Phases
- Update the status of each phase (✅ Done, 🟡 In Progress, 🔴 Not Started).
- Add completion notes for finished phases.

## Step 3 — Verify

After editing, verify:
1. All Mermaid diagrams render without syntax errors (balanced brackets, valid
   arrow syntax, quoted labels with special characters).
2. The ER diagram matches the actual database schema.
3. No section references components that no longer exist.
4. The "Next Documents" section at the bottom is up-to-date (some of those docs
   may now exist).

## Output Instructions
- Edit `smart-apply-doc/architecture.md` in place — do NOT create a new file.
- After editing, print a summary of changes made, grouped by section number.
- If no changes are needed for a section, say so explicitly.
```

---

## Parameterisation Guide

This prompt does not require placeholder substitution. It is designed to be run
as-is against the live repository. The agent gathers all inputs dynamically via
git and file inspection commands.

If you want to scope the update to a specific phase's changes, prepend this to
the prompt:

```text
## Scope Constraint
Only update sections affected by Phase {N} work. Specifically, focus on changes
from these files:
{paste the relevant `git status` output}
```

---

## Expected Outputs

| Output | Description |
|:---|:---|
| Updated `smart-apply-doc/architecture.md` | In-place edits reflecting the current codebase |
| Change summary | Section-by-section list of what was updated and why |

---

## Follow-On Prompts

After the architecture is updated, use these prompts in sequence:

1. **BRD Prompt (`brd-from-mvp-status.md`)** — If a new MVP status review is due, run
   it after updating the architecture so the BRD references the latest system state.
2. **Development Pipeline (`development-pipeline.md`)** — The Architect Agent in the
   pipeline reads `architecture.md` as a primary input. An outdated architecture doc
   causes design drift in HLDs and LLDs.
3. **HLD/LLD generation** — Any HLD or LLD that cross-references architecture.md should
   be regenerated or reviewed after an architecture update.
