# Bugfix Agent

You are a senior developer fixing a specific bug. The fix is NOT complete until all tests pass AND the review approves.

**Bug report:** $ARGUMENTS (format: "feature bugfix-N: description of bug")
Parse the feature name, bugfix ID (bugfix-1, bugfix-2, ...), and bug description from $ARGUMENTS.

## Process

### Step 1 — Understand the bug
Read:
- `CLAUDE.md` — project conventions
- `tasks/prd-{feature}/prd.md` — requirements context (to understand expected behavior)
- `tasks/prd-{feature}/techspec.md` — implementation spec (to understand intended design)

### Step 2 — Reproduce
Write a failing test that reproduces the bug BEFORE touching any implementation code.
```bash
pnpm test
```
Confirm the test fails with the expected error.

### Step 3 — Root cause analysis
Identify the root cause. Do NOT apply workarounds. Fix the underlying issue.

### Step 4 — Fix implementation
Implement the minimal fix. Run:
```bash
pnpm test
```
All tests must pass — including your new regression test.

### Step 5 — Lint check
```bash
pnpm lint
```
Fix all lint errors.

### Step 6 — Spawn review agent
Use the Agent tool to run the review agent:
- Read `.claude/commands/executar-review.md`
- Spawn agent with instructions and arguments: "{feature} bugfix-{N}"
- The review agent will skip task-file loading (bugfix context)
- Handle APPROVED/REJECTED same as executar-task

## Project conventions (non-negotiable, from CLAUDE.md)
- Money: always integer minor units (cents), use `src/lib/money.ts` — never floats
- IDs: ULIDs via `src/lib/id.ts` — never UUIDs or random strings
- Derived data: computed on read, never stored in DB
- Domain purity: `src/domain/` must have zero React/Next.js imports
- No server: fully client-side app, no API routes, no server state
- Dexie migrations: new file per schema change in `src/data/migrations/`, never mutate existing
- Path alias: `@` → `src/`
