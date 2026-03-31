---
title: BRD from MVP Status Review
description: Prompt for generating a Business Requirements Document from an MVP status review file.
hero_eyebrow: Prompt guides
hero_title: BRD generation prompt
hero_summary: Takes an MVP_status_review document as input and produces a structured Business Requirements Document covering gaps, priorities, and acceptance criteria.
permalink: /ai-prompts/brd-from-mvp-status/
---

# BRD from MVP Status Review — Prompt

> **Purpose:** Generate a Business Requirements Document (BRD) by analysing an MVP status review file.
> **Input:** `MVP_status_review{NN}.md` — a snapshot of what has been built, what is incomplete, and any observed gaps.
> **Output:** `BRD-MVP-{NN}.md` — a structured BRD with stakeholder goals, functional requirements, non-functional requirements, and prioritised acceptance criteria.

---

## When To Use This Prompt

- After completing a round of MVP development and conducting a status review.
- When you need to translate engineering observations (what works / what is missing) into formal business language.
- Before starting the next development phase to ensure business intent is clearly documented.
- When stakeholders need a plain-language requirements document independent of the TRD or implementation plan.

---

## Ready-To-Use Prompt

```text
You are a Business Analyst working on the Smart Apply project.

## Task
Read the MVP status review document provided below and produce a Business
Requirements Document (BRD) that captures:
1. What the business needs that is not yet delivered.
2. What partial functionality needs to be completed or improved.
3. What was delivered successfully and can be used as a foundation.

## Input Document
File: smart-apply-doc/MVP_status_review{NN}.md

Read the entire file before generating any output.

## Reference Documents (read as context)
- smart-apply-doc/PRD_Resume_Flow_AI.md   → original product goals and user journeys
- smart-apply-doc/TRD_Resume_Flow_AI.md   → technical constraints to respect
- smart-apply-doc/implementation-plan.md  → phase-by-phase scope already planned

## Analysis Steps (complete all before writing the BRD)

### Step 1 — Status Classification
For every item in the MVP status review, classify it as:
  - COMPLETE   : fully delivered, tested, and working
  - PARTIAL    : exists but has known gaps or stubs
  - MISSING    : required by the PRD but not yet started
  - DESCOPED   : intentionally removed from MVP scope

### Step 2 — Gap Analysis
Compare PARTIAL and MISSING items against PRD §3 (Core Functional Requirements):
  - What user journeys are blocked?
  - What dependencies are broken because a piece is missing?
  - What workarounds exist (if any)?

### Step 3 — Business Impact Assessment
For each gap, state:
  - Who is affected (end user / operator / administrator)?
  - What business outcome is at risk?
  - What is the priority: P0 (launch blocker) / P1 (high value) / P2 (nice to have)?

## Required BRD Structure

Produce the BRD with exactly these sections:

---

# Business Requirements Document — MVP {NN}

**Version:** 1.0
**Date:** {today's date}
**Source:** MVP_status_review{NN}.md
**Author:** Business Analyst Agent

---

## 1. Executive Summary
One paragraph: current MVP state, critical gaps, and the business outcome this BRD is
designed to unlock.

## 2. Stakeholder Goals
| Stakeholder | Goal | Success Metric |
|:---|:---|:---|
| Job Seeker (primary user) | {goal} | {metric} |
| Product Owner | {goal} | {metric} |
| Engineering Team | {goal} | {metric} |

## 3. Delivered Capabilities (Foundation)
List all COMPLETE items from Step 1 with a one-line description of business value each provides.

## 4. Functional Requirements

### 4.1 Must-Have (P0 — Launch Blockers)
For each P0 gap:
```
REQ-{NN}-{sequential number}
Title: {short name}
User Story: As a {persona}, I want to {action} so that {business outcome}.
Current State: {what exists today — MISSING or PARTIAL}
Required State: {what must be true for this requirement to be met}
Acceptance Criteria:
  - Given {context}, when {action}, then {result}
  - Given {context}, when {action}, then {result}
Dependencies: {other REQs or technical prerequisites}
```

### 4.2 Should-Have (P1 — High Value)
Same format as 4.1.

### 4.3 Could-Have (P2 — Nice To Have)
Same format as 4.1, abbreviated if needed.

## 5. Non-Functional Requirements

| # | Category | Requirement | Source |
|:---|:---|:---|:---|
| NFR-01 | Performance | {requirement} | TRD §16 |
| NFR-02 | Security | {requirement} | TRD §15 |
| NFR-03 | Accessibility | All interactive UI must be keyboard-navigable | PRD §3 |
| NFR-04 | Privacy | Zero server-side PDF storage | PRD §1 (Zero-Storage Policy) |
| NFR-05 | Reliability | {requirement} | TRD §17 |

Add additional rows as needed.

## 6. Out of Scope
Explicitly list what this BRD does NOT cover (to prevent scope creep):
- {item}: {reason it is excluded}

## 7. Open Questions
| # | Question | Owner | Due |
|:---|:---|:---|:---|
| 1 | {question raised by gap analysis} | {role} | {phase} |

## 8. Approval Checklist
- [ ] All P0 requirements have at least two acceptance criteria
- [ ] Every requirement references a user story
- [ ] No requirement contradicts the Zero-Storage Policy (PRD §1)
- [ ] No requirement contradicts Clerk auth model
- [ ] NFRs traceable to TRD sections
- [ ] Out-of-scope list reviewed to prevent unintended inclusions

---

## Output Instructions
- Save as: `smart-apply-doc/BRD-MVP-{NN}.md`
- Use the same YAML frontmatter format as other docs in smart-apply-doc/
- Do NOT copy the prompt structure into the output — produce only the BRD
- After saving, print a one-paragraph summary of the top 3 P0 requirements found
```

---

## Parameterisation Guide

Before pasting the prompt, replace these placeholders:

| Placeholder | What To Put |
|:---|:---|
| `{NN}` | The review number, e.g. `01`, `02` |
| `{today's date}` | Current date in `YYYY-MM-DD` format |
| `{persona}` | e.g. `job seeker`, `returning user`, `admin` |

---

## Expected Outputs

| File | Description |
|:---|:---|
| `smart-apply-doc/BRD-MVP-{NN}.md` | The Business Requirements Document |
| Console summary | Top 3 P0 requirements printed after save |

---

## Follow-On Prompts

After the BRD is generated, use these prompts in sequence:

1. **HLD Prompt (§5–10 of development-pipeline.md)** — Feed the BRD P0 requirements into the Architect Agent to refine the HLD for the next phase.
2. **LLD Prompt (§3, Step 2)** — Senior Dev Agent uses BRD acceptance criteria as the source of truth for test cases.
3. **Implementation review** — Architect Agent verifies implementation against BRD acceptance criteria in addition to HLD.
