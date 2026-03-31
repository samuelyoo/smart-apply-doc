---
title: Reorganize Doc Folder Prompt
description: Prompt for reorganizing the smart-apply-doc folder into a well-structured, navigable documentation site with proper subfolder hierarchy.
hero_eyebrow: Maintenance
hero_title: Documentation reorganization pipeline
hero_summary: A structured prompt to reorganize the flat smart-apply-doc folder into categorized subfolders, update all Jekyll permalinks, fix GitHub Pages navigation, and produce a README that orients future AI agents and human contributors.
permalink: /ai-prompts/reorganize-doc-folder/
---

# Smart Apply — Reorganize Documentation Folder

> **Purpose:** Transform the flat `smart-apply-doc/` folder into a well-organized, categorized directory structure while preserving all GitHub Pages permalinks and adding clear documentation for future contributors.
> **Constraint:** All existing GitHub Pages URLs must continue to work after reorganization. No content deletion.
> **Output:** Reorganized folder structure, updated `_config.yml`, updated `index.md`, updated `README.md`, verified GitHub Pages build.

---

## Table of Contents

1. [Context & Current State](#1-context--current-state)
2. [Problems With Current Structure](#2-problems-with-current-structure)
3. [Target Folder Structure](#3-target-folder-structure)
4. [Document Classification](#4-document-classification)
5. [Step-by-Step Execution Plan](#5-step-by-step-execution-plan)
6. [GitHub Pages Link Sync Rules](#6-github-pages-link-sync-rules)
7. [README Structure Requirements](#7-readme-structure-requirements)
8. [Validation Checklist](#8-validation-checklist)

---

## 1. Context & Current State

### 1.1 Repository Setup

- `smart-apply-doc/` is a standalone Jekyll site deployed to GitHub Pages
- URL: `https://samuelyoo.github.io/smart-apply-doc/`
- Build: GitHub Actions (`.github/workflows/deploy-pages.yml`) → Jekyll → `_site/`
- Layout: single `_layouts/default.html` with hardcoded nav (Home, Architecture, PRD, TRD, AI Prompts)
- All `.md` files with `permalink:` frontmatter are published as pages
- Files without `permalink:` are still built by Jekyll at their default path

### 1.2 Current File Inventory (39 files flat + ai-prompts/)

**Top-level markdown files (30):**
```
PRD_Resume_Flow_AI.md          (permalink: /prd/)
TRD_Resume_Flow_AI.md          (permalink: /trd/)
architecture.md                (permalink: /architecture/)
ai-architecture.md             (permalink: /ai-architecture/)
implementation-plan.md         (permalink: /implementation-plan/)
BRD-MVP-01.md                  (permalink: /brd-mvp-01/)
BRD-MVP-02.md                  (permalink: /brd-mvp-02/)
BRD-MVP-03.md                  (permalink: /brd-mvp-03/)
BRD-MVP-04.md                  (permalink: /brd-mvp-04/)
BRD_enhance_unit_test_2026-03-30.md       (permalink: /brd-enhance-unit-test/)
BRD_enhance_unit_test_phase2_2026-03-30.md (permalink: /brd-enhance-unit-test-phase2/)
HLD-MVP-P01.md                 (no permalink)
HLD-MVP-P02.md                 (no permalink)
HLD-MVP-P03.md                 (no permalink)
HLD-MVP-P04.md                 (no permalink)
HLD-MVP-P05.md                 (no permalink)
HLD-MVP-P06.md                 (no permalink)
HLD-TEST-P01.md                (no permalink)
HLD-TEST-P02.md                (no permalink)
LLD-MVP-P01.md                 (no permalink)
LLD-MVP-P02.md                 (no permalink)
LLD-MVP-P03.md                 (no permalink)
LLD-MVP-P04.md                 (no permalink)
LLD-MVP-P05.md                 (no permalink)
LLD-MVP-P06.md                 (no permalink)
LLD-TEST-P01.md                (no permalink)
LLD-TEST-P02.md                (no permalink)
QA-Report-01.md                (permalink: /qa-report-01/)
Arch-Review-QA-01.md           (permalink: /arch-review-qa-01/)
REVIEW-P05.md                  (no permalink)
REVIEW-P06.md                  (no permalink)
REVIEW-TEST-P01.md             (no permalink)
REVIEW-TEST-P02.md             (no permalink)
```

**Non-markdown top-level files (4):**
```
openapi.yaml                   (API spec)
resume_flow_schema.sql         (DB schema)
index.md                       (homepage)
README.md                      (repo README)
```

**ai-prompts/ subfolder (12 files):**
```
README.md                      (permalink: /ai-prompts/)
bootstrap.md                   (permalink: /ai-prompts/bootstrap/)
development-pipeline.md        (permalink: /ai-prompts/development-pipeline/)
qa-pipeline.md                 (permalink: /ai-prompts/qa-pipeline/)
brd-from-mvp-status.md         (permalink: /ai-prompts/brd-from-mvp-status/)
brd-from-qa-report.md          (permalink: /ai-prompts/brd-from-qa-report/)
architecture-update.md         (permalink: /ai-prompts/architecture-update/)
IMPL-LLD-P04.md               (no permalink — raw prompt, not a Jekyll page)
IMPL-LLD-P05.md               (no permalink)
IMPL-LLD-P06.md               (no permalink)
IMPL-LLD-TEST-P01.md          (no permalink)
IMPL-LLD-TEST-P02.md          (no permalink)
```

**Config / layout / assets:**
```
_config.yml
_layouts/default.html
assets/css/style.css
.github/workflows/deploy-pages.yml
.gitignore
```

### 1.3 Document Lifecycle — How Files Are Created

Documents follow a pipeline lineage. Understanding this is critical for organizing them:

```
MVP Status Review (root workspace)
    ↓ brd-from-mvp-status.md prompt
BRD-MVP-{NN}.md
    ↓ development-pipeline.md prompt (Architect Agent)
HLD-MVP-P{NN}.md
    ↓ development-pipeline.md prompt (Senior Dev Agent)
LLD-MVP-P{NN}.md
    ↓ development-pipeline.md prompt (Context Eng Agent)
IMPL-LLD-P{NN}.md (in ai-prompts/)
    ↓ Implementation executed → Code changes
REVIEW-P{NN}.md (Architect reviews implementation)
    ↓ qa-pipeline.md prompt
QA-Report-{NN}.md
    ↓ brd-from-qa-report.md prompt
Arch-Review-QA-{NN}.md + next BRD-MVP-{NN}.md
```

**Test Enhancement side-chain:**
```
BRD_enhance_unit_test_*.md → HLD-TEST-P{NN}.md → LLD-TEST-P{NN}.md → IMPL-LLD-TEST-P{NN}.md → REVIEW-TEST-P{NN}.md
```

### 1.4 Which Files Are Actively Changing vs Stable

**Stable (reference, unlikely to change):**
- PRD_Resume_Flow_AI.md, TRD_Resume_Flow_AI.md — foundational product/tech requirements
- architecture.md — updated periodically but stable between phases
- implementation-plan.md — original plan, now mostly historical
- openapi.yaml, resume_flow_schema.sql — updated when API/DB changes
- All ai-prompts/ pipeline prompt files — reusable templates
- _layouts/default.html, assets/css/style.css, _config.yml — site infrastructure

**Growing (new files added per phase):**
- BRD-MVP-{NN}.md — new one per development cycle
- HLD-MVP-P{NN}.md, LLD-MVP-P{NN}.md — new pair per phase
- REVIEW-P{NN}.md — new one per phase
- IMPL-LLD-P{NN}.md — new one per phase
- QA-Report-{NN}.md, Arch-Review-QA-{NN}.md — new ones per QA cycle
- BRD_enhance_unit_test_*.md, HLD-TEST-P{NN}.md, LLD-TEST-P{NN}.md — test enhancement phases

---

## 2. Problems With Current Structure

1. **Flat dump** — 30+ markdown files at root with no categorization; hard to scan
2. **Inconsistent naming** — `BRD-MVP-01.md` vs `BRD_enhance_unit_test_2026-03-30.md` vs `Arch-Review-QA-01.md`
3. **Missing permalinks** — HLD, LLD, and REVIEW files have no `permalink:` frontmatter, so Jekyll generates paths from filenames (e.g., `/HLD-MVP-P01/` or `/HLD-MVP-P01.html` depending on `permalink: pretty`)
4. **No discoverability** — `index.md` only links to PRD, TRD, architecture, AI prompts, openapi, and schema; BRDs/HLDs/LLDs/Reviews are invisible from the homepage
5. **IMPL files mixed with prompts** — IMPL-LLD-*.md are phase-specific generated outputs sitting alongside reusable prompt templates in ai-prompts/
6. **No document lifecycle explanation** — README.md lists files but doesn't explain the pipeline that creates them or how they relate
7. **Navigation is static** — `_layouts/default.html` hardcodes 5 nav links; no sidebar or index for the 20+ phase documents

---

## 3. Target Folder Structure

```
smart-apply-doc/
├── _config.yml                          # (update: add collections or defaults for subfolders)
├── _layouts/
│   └── default.html                     # (update: add secondary nav or sidebar for categories)
├── assets/
│   └── css/
│       └── style.css                    # (update: styles for new nav elements if needed)
├── .github/
│   └── workflows/
│       └── deploy-pages.yml             # (no change — builds from ./ )
│
├── index.md                             # (update: link to all category index pages)
├── README.md                            # (rewrite: full structure guide for AI agents & humans)
│
├── requirements/                        # Product & business requirements
│   ├── PRD_Resume_Flow_AI.md            #   permalink: /prd/               (unchanged)
│   ├── TRD_Resume_Flow_AI.md            #   permalink: /trd/               (unchanged)
│   ├── BRD-MVP-01.md                    #   permalink: /brd-mvp-01/        (unchanged)
│   ├── BRD-MVP-02.md                    #   permalink: /brd-mvp-02/        (unchanged)
│   ├── BRD-MVP-03.md                    #   permalink: /brd-mvp-03/        (unchanged)
│   ├── BRD-MVP-04.md                    #   permalink: /brd-mvp-04/        (unchanged)
│   ├── BRD_enhance_unit_test_2026-03-30.md        #   (keep permalink)
│   └── BRD_enhance_unit_test_phase2_2026-03-30.md #   (keep permalink)
│
├── design/                              # Architecture & high/low-level design docs
│   ├── architecture.md                  #   permalink: /architecture/      (unchanged)
│   ├── ai-architecture.md               #   permalink: /ai-architecture/   (unchanged)
│   ├── implementation-plan.md           #   permalink: /implementation-plan/ (unchanged)
│   ├── HLD-MVP-P01.md                   #   ADD permalink: /design/hld-mvp-p01/
│   ├── HLD-MVP-P02.md                   #   ADD permalink: /design/hld-mvp-p02/
│   ├── HLD-MVP-P03.md                   #   ADD permalink: /design/hld-mvp-p03/
│   ├── HLD-MVP-P04.md                   #   ADD permalink: /design/hld-mvp-p04/
│   ├── HLD-MVP-P05.md                   #   ADD permalink: /design/hld-mvp-p05/
│   ├── HLD-MVP-P06.md                   #   ADD permalink: /design/hld-mvp-p06/
│   ├── HLD-TEST-P01.md                  #   ADD permalink: /design/hld-test-p01/
│   ├── HLD-TEST-P02.md                  #   ADD permalink: /design/hld-test-p02/
│   ├── LLD-MVP-P01.md                   #   ADD permalink: /design/lld-mvp-p01/
│   ├── LLD-MVP-P02.md                   #   ADD permalink: /design/lld-mvp-p02/
│   ├── LLD-MVP-P03.md                   #   ADD permalink: /design/lld-mvp-p03/
│   ├── LLD-MVP-P04.md                   #   ADD permalink: /design/lld-mvp-p04/
│   ├── LLD-MVP-P05.md                   #   ADD permalink: /design/lld-mvp-p05/
│   ├── LLD-MVP-P06.md                   #   ADD permalink: /design/lld-mvp-p06/
│   ├── LLD-TEST-P01.md                  #   ADD permalink: /design/lld-test-p01/
│   └── LLD-TEST-P02.md                  #   ADD permalink: /design/lld-test-p02/
│
├── reviews/                             # QA reports, arch reviews, implementation reviews
│   ├── QA-Report-01.md                  #   permalink: /qa-report-01/      (unchanged)
│   ├── Arch-Review-QA-01.md             #   permalink: /arch-review-qa-01/ (unchanged)
│   ├── REVIEW-P05.md                    #   ADD permalink: /reviews/review-p05/
│   ├── REVIEW-P06.md                    #   ADD permalink: /reviews/review-p06/
│   ├── REVIEW-TEST-P01.md              #   ADD permalink: /reviews/review-test-p01/
│   └── REVIEW-TEST-P02.md              #   ADD permalink: /reviews/review-test-p02/
│
├── api/                                 # Integration assets & schemas
│   ├── openapi.yaml                     #   (update index.md link if needed)
│   └── resume_flow_schema.sql           #   (update index.md link if needed)
│
└── ai-prompts/                          # Reusable AI pipeline prompts ONLY
    ├── README.md                        #   permalink: /ai-prompts/        (unchanged)
    ├── bootstrap.md                     #   (unchanged)
    ├── development-pipeline.md          #   (unchanged)
    ├── qa-pipeline.md                   #   (unchanged)
    ├── brd-from-mvp-status.md           #   (unchanged)
    ├── brd-from-qa-report.md            #   (unchanged)
    ├── architecture-update.md           #   (unchanged)
    ├── reorganize-doc-folder.md         #   THIS FILE (unchanged)
    └── impl/                            # Phase-specific generated implementation prompts
        ├── IMPL-LLD-P04.md             #   (no permalink — working artifact)
        ├── IMPL-LLD-P05.md
        ├── IMPL-LLD-P06.md
        ├── IMPL-LLD-TEST-P01.md
        └── IMPL-LLD-TEST-P02.md
```

---

## 4. Document Classification

Use this table to decide where each file belongs. When new files are created in the pipeline, place them according to this classification.

| Category | Folder | File Pattern | Lifecycle | Jekyll Page? |
|----------|--------|-------------|-----------|-------------|
| Product requirements | `requirements/` | `PRD_*.md`, `TRD_*.md` | Stable | Yes (has permalink) |
| Business requirements | `requirements/` | `BRD-MVP-*.md`, `BRD_*.md` | Growing — one per cycle | Yes (has permalink) |
| Architecture & design | `design/` | `architecture.md`, `ai-architecture.md`, `implementation-plan.md` | Stable | Yes (has permalink) |
| High-level design | `design/` | `HLD-MVP-P*.md`, `HLD-TEST-P*.md` | Growing — one per phase | Yes (add permalink) |
| Low-level design | `design/` | `LLD-MVP-P*.md`, `LLD-TEST-P*.md` | Growing — one per phase | Yes (add permalink) |
| QA reports | `reviews/` | `QA-Report-*.md` | Growing — one per QA cycle | Yes (has permalink) |
| Architecture reviews | `reviews/` | `Arch-Review-QA-*.md` | Growing — one per QA cycle | Yes (has permalink) |
| Implementation reviews | `reviews/` | `REVIEW-P*.md`, `REVIEW-TEST-P*.md` | Growing — one per phase | Yes (add permalink) |
| API & schemas | `api/` | `openapi.yaml`, `*.sql` | Updated with API changes | Linked from index |
| Reusable prompts | `ai-prompts/` | `*.md` (not IMPL-*) | Stable templates | Yes (has permalink) |
| Implementation prompts | `ai-prompts/impl/` | `IMPL-LLD-*.md` | Growing — one per phase | No (working artifacts) |

---

## 5. Step-by-Step Execution Plan

### Phase A — Preparation (Read-Only)

1. **Git status check** — Ensure working tree is clean. Commit or stash any in-progress changes.
2. **Build baseline** — Run `cd smart-apply-doc && bundle exec jekyll build` (or push to trigger GitHub Actions) to confirm the current site builds successfully. Save the list of generated URLs.
3. **Inventory current permalinks** — Grep all `.md` files for `permalink:` frontmatter. Record every existing URL.

### Phase B — Create Subfolder Structure

4. **Create folders:**
   ```bash
   cd smart-apply-doc
   mkdir -p requirements design reviews api ai-prompts/impl
   ```

5. **Move files** (use `git mv` to preserve history):
   ```bash
   # Requirements
   git mv PRD_Resume_Flow_AI.md requirements/
   git mv TRD_Resume_Flow_AI.md requirements/
   git mv BRD-MVP-01.md BRD-MVP-02.md BRD-MVP-03.md BRD-MVP-04.md requirements/
   git mv BRD_enhance_unit_test_2026-03-30.md requirements/
   git mv BRD_enhance_unit_test_phase2_2026-03-30.md requirements/

   # Design
   git mv architecture.md ai-architecture.md implementation-plan.md design/
   git mv HLD-MVP-P01.md HLD-MVP-P02.md HLD-MVP-P03.md design/
   git mv HLD-MVP-P04.md HLD-MVP-P05.md HLD-MVP-P06.md design/
   git mv HLD-TEST-P01.md HLD-TEST-P02.md design/
   git mv LLD-MVP-P01.md LLD-MVP-P02.md LLD-MVP-P03.md design/
   git mv LLD-MVP-P04.md LLD-MVP-P05.md LLD-MVP-P06.md design/
   git mv LLD-TEST-P01.md LLD-TEST-P02.md design/

   # Reviews
   git mv QA-Report-01.md reviews/
   git mv Arch-Review-QA-01.md reviews/
   git mv REVIEW-P05.md REVIEW-P06.md reviews/
   git mv REVIEW-TEST-P01.md REVIEW-TEST-P02.md reviews/

   # API & schemas
   git mv openapi.yaml api/
   git mv resume_flow_schema.sql api/

   # IMPL prompts to subfolder
   git mv ai-prompts/IMPL-LLD-P04.md ai-prompts/impl/
   git mv ai-prompts/IMPL-LLD-P05.md ai-prompts/impl/
   git mv ai-prompts/IMPL-LLD-P06.md ai-prompts/impl/
   git mv ai-prompts/IMPL-LLD-TEST-P01.md ai-prompts/impl/
   git mv ai-prompts/IMPL-LLD-TEST-P02.md ai-prompts/impl/
   ```

### Phase C — Add/Verify Permalinks

6. **Files that already have permalinks** — Verify they are unchanged after the move. Jekyll resolves `permalink:` regardless of file path, so existing URLs remain stable.

7. **Files that need new permalinks** — Add `permalink:` frontmatter to every HLD, LLD, and REVIEW file. Pattern:

   ```yaml
   ---
   title: "HLD — Phase 1: Foundation & Auth Wiring"
   permalink: /design/hld-mvp-p01/
   ---
   ```

   Use lowercase-kebab-case matching the filename. Prefix with category folder for new permalinks.

   **Full list of files needing `permalink:` added:**
   - `design/HLD-MVP-P01.md` → `/design/hld-mvp-p01/`
   - `design/HLD-MVP-P02.md` → `/design/hld-mvp-p02/`
   - `design/HLD-MVP-P03.md` → `/design/hld-mvp-p03/`
   - `design/HLD-MVP-P04.md` → `/design/hld-mvp-p04/`
   - `design/HLD-MVP-P05.md` → `/design/hld-mvp-p05/`
   - `design/HLD-MVP-P06.md` → `/design/hld-mvp-p06/`
   - `design/HLD-TEST-P01.md` → `/design/hld-test-p01/`
   - `design/HLD-TEST-P02.md` → `/design/hld-test-p02/`
   - `design/LLD-MVP-P01.md` → `/design/lld-mvp-p01/`
   - `design/LLD-MVP-P02.md` → `/design/lld-mvp-p02/`
   - `design/LLD-MVP-P03.md` → `/design/lld-mvp-p03/`
   - `design/LLD-MVP-P04.md` → `/design/lld-mvp-p04/`
   - `design/LLD-MVP-P05.md` → `/design/lld-mvp-p05/`
   - `design/LLD-MVP-P06.md` → `/design/lld-mvp-p06/`
   - `design/LLD-TEST-P01.md` → `/design/lld-test-p01/`
   - `design/LLD-TEST-P02.md` → `/design/lld-test-p02/`
   - `reviews/REVIEW-P05.md` → `/reviews/review-p05/`
   - `reviews/REVIEW-P06.md` → `/reviews/review-p06/`
   - `reviews/REVIEW-TEST-P01.md` → `/reviews/review-test-p01/`
   - `reviews/REVIEW-TEST-P02.md` → `/reviews/review-test-p02/`

### Phase D — Update index.md

8. **Rewrite `index.md`** to include all document categories with links. The new homepage should have sections for:
   - Core documents (PRD, TRD, Architecture) — existing section, update `href` paths
   - Business requirements — new section listing all BRDs
   - Design documents — new section with HLD/LLD index
   - Reviews & QA — new section listing QA reports, arch reviews, implementation reviews
   - AI prompt guides — existing section (unchanged)
   - Integration assets — existing section, update `href` to `/api/openapi.yaml` and `/api/resume_flow_schema.sql`

9. **Update `{{ '/openapi.yaml' | relative_url }}`** → `{{ '/api/openapi.yaml' | relative_url }}`
   **Update `{{ '/resume_flow_schema.sql' | relative_url }}`** → `{{ '/api/resume_flow_schema.sql' | relative_url }}`

### Phase E — Update Navigation (Optional Enhancement)

10. **Consider updating `_layouts/default.html`** to add a secondary navigation bar or sidebar that lists document categories. The current hardcoded nav only has: Home, Architecture, PRD, TRD, AI Prompts. At minimum add:
    - Requirements (linking to a requirements index or first BRD)
    - Design (linking to architecture.md as entry point)
    - Reviews (linking to latest QA report)

### Phase F — Update README.md

11. **Rewrite `README.md`** following the structure in [Section 7](#7-readme-structure-requirements).

### Phase G — Validation

12. Execute the validation checklist in [Section 8](#8-validation-checklist).

---

## 6. GitHub Pages Link Sync Rules

### Rule 1: Permalink = URL identity
Jekyll resolves the `permalink:` frontmatter value as the page URL, **regardless of the file's physical path**. Moving a file to a subfolder does NOT break its URL as long as its `permalink:` is unchanged.

### Rule 2: Files without permalink
Files without `permalink:` get a default URL derived from their file path + the `permalink: pretty` setting in `_config.yml`. For example:
- `HLD-MVP-P01.md` at root → `/HLD-MVP-P01/`
- `design/HLD-MVP-P01.md` after move → `/design/HLD-MVP-P01/`

This is a **breaking change** if anyone has bookmarked the old URL. To prevent breakage, **add explicit `permalink:` to every moved file that didn't have one**.

### Rule 3: Non-markdown files
`openapi.yaml` and `resume_flow_schema.sql` are served at their file path. Moving them to `api/` changes their URL from `/openapi.yaml` to `/api/openapi.yaml`. Update all links in `index.md`.

### Rule 4: IMPL files in ai-prompts/impl/
These files have no frontmatter and are raw markdown. Jekyll will still process them. If they should NOT be published as pages, either:
- Add them to `exclude:` in `_config.yml`, OR
- Add `published: false` frontmatter to each

### Rule 5: Validation
After moving files and updating permalinks, run a Jekyll build locally and verify:
```bash
bundle exec jekyll build
# Then check _site/ for expected URL paths
find _site -name "*.html" | sort
```

Or after pushing, check the deployed site page-by-page.

---

## 7. README Structure Requirements

The new `README.md` should serve two audiences: **AI agents** and **human contributors**. It should explain:

```markdown
# smart-apply-doc

Documentation hub for Smart Apply — product requirements, system design, QA reports, and AI development prompts.

## Quick Navigation

| Section | Path | What's Inside |
|---------|------|---------------|
| Requirements | `requirements/` | PRD, TRD, and all BRDs (business requirements per development cycle) |
| Design | `design/` | Architecture, implementation plan, HLDs, and LLDs per phase |
| Reviews | `reviews/` | QA reports, architecture reviews, and implementation reviews |
| API & Schemas | `api/` | OpenAPI spec and database schema SQL |
| AI Prompts | `ai-prompts/` | Reusable pipeline prompts for development, QA, and BRD generation |
| Implementation Prompts | `ai-prompts/impl/` | Phase-specific implementation guides (generated, not templates) |

## Document Lifecycle

Documents are created through a repeatable AI-assisted pipeline. Understanding this
lifecycle helps you know where to find context and where to put new documents.

### Pipeline Flow

1. **MVP Status Review** (root workspace) — Human or AI assesses current state
2. **BRD** (`requirements/BRD-MVP-{NN}.md`) — Business requirements generated from status review
3. **HLD** (`design/HLD-MVP-P{NN}.md`) — High-level design by Architect Agent from BRD
4. **LLD** (`design/LLD-MVP-P{NN}.md`) — Low-level design by Senior Dev Agent from HLD
5. **IMPL** (`ai-prompts/impl/IMPL-LLD-P{NN}.md`) — Implementation prompt generated from LLD
6. **Code changes** — Implementation executed in codebase
7. **REVIEW** (`reviews/REVIEW-P{NN}.md`) — Architect reviews implementation against HLD
8. **QA Report** (`reviews/QA-Report-{NN}.md`) — QA pipeline assesses quality
9. **Arch Review** (`reviews/Arch-Review-QA-{NN}.md`) — Architect reviews QA findings
10. **Next BRD** — Cycle repeats

### Test Enhancement Side-Chain

Test-specific documents follow the same pattern with `-TEST-` in filenames:
`BRD_enhance_*` → `HLD-TEST-P{NN}` → `LLD-TEST-P{NN}` → `IMPL-LLD-TEST-P{NN}` → `REVIEW-TEST-P{NN}`

## Naming Conventions

| Pattern | Example | Where |
|---------|---------|-------|
| `BRD-MVP-{NN}.md` | `BRD-MVP-01.md` | `requirements/` |
| `HLD-MVP-P{NN}.md` | `HLD-MVP-P01.md` | `design/` |
| `LLD-MVP-P{NN}.md` | `LLD-MVP-P01.md` | `design/` |
| `REVIEW-P{NN}.md` | `REVIEW-P05.md` | `reviews/` |
| `QA-Report-{NN}.md` | `QA-Report-01.md` | `reviews/` |
| `Arch-Review-QA-{NN}.md` | `Arch-Review-QA-01.md` | `reviews/` |
| `IMPL-LLD-P{NN}.md` | `IMPL-LLD-P04.md` | `ai-prompts/impl/` |

## Adding New Documents

When a new phase produces documents:
1. Place BRDs in `requirements/`
2. Place HLDs and LLDs in `design/`
3. Place reviews and QA reports in `reviews/`
4. Place IMPL prompts in `ai-prompts/impl/`
5. Add `permalink:` frontmatter following the pattern: `/<category>/<filename-lowercase>/`
6. Update `index.md` to include links to new documents
7. Commit and push — GitHub Actions deploys automatically

## GitHub Pages

- **Site URL:** https://samuelyoo.github.io/smart-apply-doc/
- **Build:** Jekyll via GitHub Actions (`.github/workflows/deploy-pages.yml`)
- **Permalink convention:** All pages use `permalink:` frontmatter for stable URLs
- **Navigation:** `_layouts/default.html` provides site header nav

## When To Read This Folder

- **Product intent** → `requirements/PRD_Resume_Flow_AI.md`
- **Technical constraints** → `requirements/TRD_Resume_Flow_AI.md`
- **System architecture** → `design/architecture.md`
- **Phase-specific design** → `design/HLD-MVP-P{NN}.md` + `design/LLD-MVP-P{NN}.md`
- **Quality assessment** → `reviews/QA-Report-{NN}.md`
- **API contract** → `api/openapi.yaml`
- **Database schema** → `api/resume_flow_schema.sql`
- **Development workflow** → `ai-prompts/development-pipeline.md`

## Notes

- This folder is reference material, not the source of truth for runtime code.
- If a doc and implementation disagree, verify the current code before changing behavior.
- When you make a meaningful architecture or workflow change, update the relevant docs here.
```

---

## 8. Validation Checklist

Run through this checklist after completing the reorganization:

### File Structure
- [ ] All `.md` files are in their correct category subfolder
- [ ] No orphan `.md` files remain at the doc root (except `index.md` and `README.md`)
- [ ] `ai-prompts/impl/` contains only IMPL-LLD-*.md files
- [ ] `api/` contains `openapi.yaml` and `resume_flow_schema.sql`

### Permalinks
- [ ] Every file that had a `permalink:` before the move still has the same `permalink:`
- [ ] Every HLD, LLD, and REVIEW file now has a `permalink:` in frontmatter
- [ ] No two files share the same `permalink:` value

### GitHub Pages Build
- [ ] Jekyll builds without errors: `bundle exec jekyll build`
- [ ] Or: push to a branch and verify GitHub Actions build succeeds

### URL Verification (compare against baseline from Phase A step 2)
- [ ] `https://samuelyoo.github.io/smart-apply-doc/` — homepage loads
- [ ] `/prd/` — PRD page loads
- [ ] `/trd/` — TRD page loads
- [ ] `/architecture/` — Architecture page loads
- [ ] `/ai-architecture/` — AI Architecture loads
- [ ] `/implementation-plan/` — Implementation plan loads
- [ ] `/brd-mvp-01/` through `/brd-mvp-04/` — All BRD pages load
- [ ] `/brd-enhance-unit-test/` and `/brd-enhance-unit-test-phase2/` — Test BRDs load
- [ ] `/qa-report-01/` — QA report loads
- [ ] `/arch-review-qa-01/` — Arch review loads
- [ ] `/ai-prompts/` — AI prompts index loads
- [ ] `/ai-prompts/bootstrap/` — Bootstrap prompt loads
- [ ] `/ai-prompts/development-pipeline/` — Dev pipeline loads
- [ ] `/design/hld-mvp-p01/` through `/design/hld-mvp-p06/` — All HLD pages load
- [ ] `/design/lld-mvp-p01/` through `/design/lld-mvp-p06/` — All LLD pages load
- [ ] `/design/hld-test-p01/`, `/design/hld-test-p02/` — Test HLDs load
- [ ] `/design/lld-test-p01/`, `/design/lld-test-p02/` — Test LLDs load
- [ ] `/reviews/review-p05/`, `/reviews/review-p06/` — Reviews load
- [ ] `/reviews/review-test-p01/`, `/reviews/review-test-p02/` — Test reviews load
- [ ] `/api/openapi.yaml` — OpenAPI spec accessible
- [ ] `/api/resume_flow_schema.sql` — DB schema accessible

### Cross-References
- [ ] `index.md` links all point to valid permalinks
- [ ] `_layouts/default.html` nav links still work
- [ ] `ai-prompts/README.md` internal links still work

### README
- [ ] `README.md` explains folder structure with table
- [ ] `README.md` explains document lifecycle pipeline
- [ ] `README.md` explains naming conventions
- [ ] `README.md` explains how to add new documents
- [ ] `README.md` explains GitHub Pages setup

### Git
- [ ] All moves done with `git mv` (history preserved)
- [ ] Commit message: `docs: reorganize smart-apply-doc into categorized subfolders`
- [ ] No untracked files left behind

---

## Appendix: Future Naming Convention Recommendation

For consistency, consider standardizing all BRD filenames to match the `BRD-MVP-{NN}` pattern:

| Current | Proposed Rename |
|---------|----------------|
| `BRD_enhance_unit_test_2026-03-30.md` | `BRD-TEST-01.md` |
| `BRD_enhance_unit_test_phase2_2026-03-30.md` | `BRD-TEST-02.md` |

This is optional and would require updating their permalinks. Only do this if the team agrees on the naming convention going forward.
