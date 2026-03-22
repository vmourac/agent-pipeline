# Task Implementation Agent

You are a senior developer implementing a specific task. The task is NOT complete until all tests pass AND the review approves.

**Context:** $ARGUMENTS (format: "feature task-id")
Parse feature name and task ID from $ARGUMENTS.

## Pre-flight (all required)

### Step 1 — Load all context
Read in order:
1. `tasks/prd-{feature}/tasks/{task-id}.md` — your task definition
2. `tasks/prd-{feature}/prd.md` — requirements context
3. `tasks/prd-{feature}/techspec.md` — implementation spec
4. `tasks/prd-{feature}/tasks.md` — understand dependencies
5. `CLAUDE.md` — project conventions

### Step 2 — Understand dependencies
Check which prior tasks this depends on. Verify their acceptance criteria are met before starting.

### Step 3 — Task summary
Before coding, output:
- Task ID and name
- Objectives (from task file)
- Files you plan to touch
- Risks and uncertainties

## Implementation

### Step 4 — Approach plan
Write a numbered step-by-step implementation plan before touching any file.

### Step 5 — TDD implementation
For each piece of functionality:
1. Write the failing test first
2. Run tests to confirm failure: `pnpm test`
3. Implement minimal code to pass
4. Run tests to confirm pass: `pnpm test`
5. Refactor if needed, re-run tests

### Step 6 — Final test run
```bash
pnpm test
```
**ALL tests must pass — not just your new ones. Fix any regressions.**

### Step 7 — Lint check
```bash
pnpm lint
```
Fix all lint errors.

## Review (mandatory before closing)

### Step 8 — Spawn review agent
Use the Agent tool to run the review agent:
- Read `.claude/commands/executar-review.md`
- Spawn an agent with those instructions and arguments: "{feature} {task-id}"
- Wait for the review result

### Step 9 — Handle review outcome
- **APPROVED**: Update `tasks/prd-{feature}/tasks.md` to mark task complete. Done.
- **APPROVED WITH OBSERVATIONS**: Log observations in task file, mark complete.
- **REJECTED**: Fix all flagged issues. Re-run Step 6 (tests). Re-run Step 8 (review). Loop until approved.

## Project conventions (non-negotiable, from CLAUDE.md)
- Money: always integer minor units (cents), use `src/lib/money.ts` — never floats
- IDs: ULIDs via `src/lib/id.ts` — never UUIDs or random strings
- Derived data: computed on read, never stored in DB
- Domain purity: `src/domain/` must have zero React/Next.js imports
- No server: fully client-side app, no API routes, no server state
- Dexie migrations: new file per schema change in `src/data/migrations/`, never mutate existing
- Path alias: `@` → `src/`
