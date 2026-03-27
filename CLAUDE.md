# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A collection of Claude Code slash commands that implement an AI-driven feature development pipeline. There is no application code here — only `.claude/commands/` files that define agent behaviors.

## Pipeline architecture

The pipeline is a sequential, multi-agent orchestration:

```
/pipeline
  → PRD agent      (criar-prd)      → tasks/prd-{feature}/prd.md
  → TechSpec agent (criar-techspec) → tasks/prd-{feature}/techspec.md
  → Tasks agent    (criar-tasks)    → tasks/prd-{feature}/tasks/*.md
  → [APPROVAL GATE]
  → Task impl agent × N (executar-task, worktree-isolated, sequential)
      → spawns executar-review internally, loops until APPROVED
  → QA agent       (executar-qa)    → E2E via Playwright MCP
  → Bugfix agent × N (executar-bugfix, worktree-isolated) if QA fails
```

**Key constraint:** Task implementation is strictly sequential — each task may depend on types/modules created by the prior one. The pipeline never parallelizes Phase 4.

**Worktree isolation:** `executar-task` and `executar-bugfix` run with `isolation: "worktree"` so each task gets a clean git context.

## Artifact layout

Planning artifacts are written to the target project (not this repo):

```
tasks/
  prd-{feature}/
    prd.md          # WHAT and WHY (FR-01, FR-02, ...)
    techspec.md     # HOW (architecture, data models, file paths)
    tasks.md        # ordered summary of all tasks
    tasks/
      1.0-name.md   # individual task files
      2.0-name.md
```

## Command design conventions

- **Templates are embedded inline** in each command file — commands have zero external file dependencies and are safe to copy to `~/.claude/commands/` for global use.
- Each command that spawns sub-agents reads the sub-agent's command file at runtime (not hardcoded), so edits to sub-commands are picked up automatically by the orchestrator.
- The `criar-tasks` command has an internal APPROVAL GATE; when called from `/pipeline`, the pipeline's Phase 3 gate is authoritative and the internal one is advisory only (documented inline).

## Target project conventions (enforced by executar-task and executar-review)

These conventions are baked into the implementation and review agents — they apply to whatever project the pipeline is run against:

- **Money:** integer minor units (cents) via `src/lib/money.ts` — never floats
- **IDs:** ULIDs via `src/lib/id.ts` — never UUIDs or random strings
- **Derived data:** computed on read, never stored in DB
- **Domain purity:** `src/domain/` must have zero React/Next.js imports
- **No server:** fully client-side, no API routes, no server state
- **Dexie migrations:** new file per schema change in `src/data/migrations/` — never mutate existing ones
- **Path alias:** `@` → `src/`
- **Tests:** `pnpm test` — all tests must pass before any review can APPROVE
- **Lint:** `pnpm lint` — must be clean before closing any task or bugfix
