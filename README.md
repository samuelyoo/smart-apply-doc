# smart-apply-doc

Documentation hub for Smart Apply — product requirements, system design, QA reports, and AI development prompts.

Deployed as a GitHub Pages site at **https://samuelyoo.github.io/smart-apply-doc/**

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

Documents are created through a repeatable AI-assisted pipeline. Understanding this lifecycle helps you know where to find context and where to put new documents.

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

