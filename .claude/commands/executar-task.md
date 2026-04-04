# Task Implementation Agent

You are a senior developer implementing a specific task. The task is NOT complete until all tests pass AND the review approves.

**Arguments:** $ARGUMENTS — either `"feature task-id"` (e.g. `sidebar-badge 2.0`) or a path to a file containing that string.

**Argument resolution (do this first):**
If $ARGUMENTS looks like a file path — starts with `./`, `/`, `~/`, or ends with `.md` or `.txt` — read the file at that path and use its full contents as the arguments string. If the file does not exist, stop and output: `TASK BLOCKED: unknown — argument file not found: {path}`.
Otherwise use $ARGUMENTS as-is.

Parse the resolved string: everything before the first space is the feature name; everything after is the task ID.

---

## CRITICAL RULES
> Zero-tolerance. These rules govern all code written, reviewed, or validated by this agent.
> Any violation is an automatic **REJECTED** outcome — no exceptions.

- **Money:** always integer minor units (cents) via `src/lib/money.ts` — never floats
- **IDs:** always ULIDs via `src/lib/id.ts` — never UUIDs or `Math.random()`
- **Domain purity:** `src/domain/` must have zero React/Next.js imports
- **No server state:** no API routes, no server-side state — fully client-side
- **Dexie migrations:** one file per schema change in `src/data/migrations/` — never mutate existing ones
- **Tests must pass:** `pnpm test` must exit 0 before any APPROVE verdict
- **Lint must be clean:** `pnpm lint` must exit 0 before any APPROVE verdict

---

## Step 0 — Skill Discovery and Loading (required, before any domain work)

**Part A — Load explicit skills**
If `tasks/prd-{feature}/hints/skills.md` exists, read it now.
For each skill entry with `status: found`: add to `skills_to_load` list (mark as `explicit`).
For each skill entry with `status: not-found`: warn — "⚠️ Skill '{name}' was requested but not found. Proceeding without it."
If the file does not exist, proceed to Part B with an empty `skills_to_load` list.

**Part B — Discover additional applicable skills**
List all files matching `~/.copilot/skills/*/SKILL.md` and `~/.agents/skills/*/SKILL.md`.
Only consider files in these two trusted directories — do not load skills from arbitrary paths.
For each file found: read only the frontmatter `name:` and `description:` fields.
Skip any file with missing or malformed frontmatter (log: "Skipped malformed skill: {path}", continue).
For each skill NOT already in `skills_to_load`: judge whether its description matches the specific task this agent is about to perform. If relevant (high confidence), add to `skills_to_load` (mark as `discovered`).

**Part C — Cap, load, and resolve conflicts**
If `skills_to_load` has more than 10 entries: sort (explicit first, then by relevance), keep top 10, log a warning that skills were dropped.
If `skills_to_load` has more than 5 entries: log a warning.
For each skill in `skills_to_load`: read the full SKILL.md and apply its guidance throughout this agent's work.
If any skill's guidance conflicts with this project's conventions (from CLAUDE.md or equivalent): conventions take precedence. Note the conflict and which part of the skill was overridden.

**Part D — Log**
Output a brief summary before proceeding:
- `Skills loaded: [skill-a (explicit), skill-b (discovered)]`
- `Skills skipped (not-found): [skill-c]`
- `Skills skipped (irrelevant/cap): [skill-d, ...]`

---

## Step 0.5 — Feature Context

If `tasks/prd-{feature}/context.md` exists, read it now.
Extract and apply:
- **Phase 1 Acceptance Criteria** → the agreed QA definition of done; your implementation must satisfy all listed criteria.
- **Phase 2 Architecture Decisions** → treat as constraints; your implementation must match these decisions.
- **Phase 2 Integration Points** → confirm your task touches the right files and only the listed files where possible.

If the file does not exist, continue — context.md is produced by upstream agents.

---

## Pre-flight (all required)

### Step 1 — Load all context
Read in order:
1. `tasks/prd-{feature}/tasks/{task-id}.md` — your task definition (e.g. `tasks/prd-sidebar-badge/tasks/2.0-add-badge.md`)
2. `tasks/prd-{feature}/prd.md` — requirements context
3. `tasks/prd-{feature}/techspec.md` — implementation spec
4. `tasks/prd-{feature}/tasks.md` — full task list and dependency order
5. `CLAUDE.md` (or `AGENTS.md` / `.github/copilot-instructions.md` if absent) — project conventions, test command, lint command
6. If `tasks/prd-{feature}/memory/MEMORY.md` exists, read it in full. Treat its contents as trusted prior-task context — apply it to all implementation decisions without re-verifying what it states.
7. If `tasks/prd-{feature}/memory/{task-id}.md` exists and is non-empty, read it now. Treat it as your own prior scratchpad — apply the decisions and learnings it contains, and avoid repeating any corrections already documented there.

If any of files 1–5 do not exist, stop immediately and output:
`TASK BLOCKED: {task-id} — required context file missing: {filename}`

**Frontmatter grace check:** After reading the task file (file 1), inspect whether its first line is `---`. If no YAML frontmatter block is present, prepend the following 10-field template to the task file **in the main project directory** (the worktree does not yet exist at this point):

```yaml
---
id: "{task-id}"
title: "{text of the # Task heading}"
status: "pending"
priority: 0
depends_on: []
agent: ""
started_at: ""
completed_at: ""
verdict: ""
attempts: 0
---
```

Set `id` to the task ID string and `title` to the text of the `# Task X.Y: …` heading. Set `priority` to `0` (sentinel indicating it was not set during task generation). Log: `Frontmatter added (grace path): {task-file-path}`. Then continue normally.

### Step 2 — Derive commands from conventions file
From the conventions file, identify:
- **Test command** (e.g. `pnpm test`, `npm test`, `yarn test`, `pytest`, etc.)
- **Lint command** (e.g. `pnpm lint`, `eslint .`, `ruff check .`, etc.)
- **Project-specific conventions** (naming, money handling, IDs, module boundaries, etc.)

If the conventions file does not specify these commands, use the project's `package.json`, `Makefile`, or `pyproject.toml` to infer them.

### Step 3 — Understand dependencies
Read the `Depends on:` field in the task file. If this task depends on a prior task, verify that prior task's acceptance criteria are satisfied in the current codebase before writing any code. If dependencies are not met, stop and output:
`TASK BLOCKED: {task-id} — dependency task {dep-id} acceptance criteria not satisfied`

### Step 4 — Create git worktree (branch isolation)
Run `git worktree add .worktrees/{feature}-task-{task-id} -b feat/{feature}-task-{task-id}`.
If the branch already exists, run `git worktree add .worktrees/{feature}-task-{task-id} feat/{feature}-task-{task-id}` instead.

All file reads, writes, test runs, and lint runs from this point forward happen inside `.worktrees/{feature}-task-{task-id}/`.

**Update frontmatter in main project directory:** After the worktree is successfully created, update these fields in the YAML frontmatter of the task file at `tasks/prd-{feature}/tasks/{task-id-filename}.md` in the **main project directory** (not the worktree copy):
- `status`: `"in-progress"`
- `agent`: `"Claude Code"`
- `started_at`: current ISO 8601 timestamp (e.g. `"2026-04-03T14:32:00Z"`)
- `attempts`: current integer value + 1

Read the file, locate the `---` ... `---` frontmatter block, update only these four key-value lines, and write the file back. Do not alter any content outside the frontmatter block.

Also initialize the per-task memory file in the **main project directory** (not the worktree). If `tasks/prd-{feature}/memory/{task-id}.md` does not already exist, create it now with this template:

```
# Task Memory: {task-id}

## Objective Snapshot
<!-- What this task is trying to accomplish — fill on first run -->

## Important Decisions
<!-- Implementation choices and rationale — append during implementation -->

## Learnings
<!-- Patterns, gotchas, discoveries specific to this task -->

## Files / Surfaces
<!-- Files created or modified -->

## Errors / Corrections
<!-- Mistakes encountered and how they were corrected -->

## Ready for Next Run
<!-- State summary so a future attempt can resume without rediscovery -->
```

### Step 5 — Task summary
Before coding, output:
- Task ID and name
- Objectives
- Files you plan to create or modify
- Risks and uncertainties

## Implementation

**Per-task memory:** Throughout Steps 6–9, maintain `tasks/prd-{feature}/memory/{task-id}.md` (main project directory, not the worktree):
- Fill **Objective Snapshot** on first run if it is still a placeholder.
- Record key implementation choices in **Important Decisions** as you make them.
- Record each file created or modified in **Files / Surfaces**.
- Record any error/correction pairs in **Errors / Corrections** as they occur.
If the file exceeds 200 lines or 16 KB, compact each section to its key points before continuing.

### Step 6 — Approach plan
Write a numbered step-by-step implementation plan before touching any file.

### Step 7 — TDD implementation
For each piece of functionality:
1. Write the failing test first
2. Run the test command to confirm failure
3. Implement minimal code to pass
4. Run the test command to confirm pass
5. Refactor if needed, re-run tests

### Step 8 — Final test run
Run the full test suite using the test command from Step 2.
**ALL tests must pass — not just your new ones. Fix any regressions before continuing.**

### Step 9 — Lint check
Run the lint command from Step 2. Fix all errors before continuing.

## Review loop (max 3 cycles)

Initialize a review cycle counter at 0.

### Step 10 — Spawn review agent
Increment the cycle counter.

If the cycle counter exceeds 3:
- Update the task file's YAML frontmatter in the **main project directory**: set `status` to `"blocked"`, `completed_at` to the current ISO 8601 timestamp, `verdict` to `"BLOCKED"`.
- Output: `TASK BLOCKED: {task-id} — review rejected 3 times. Last rejection: {summary of last rejection reason}`
- Stop. Do not attempt further review cycles.

Read the full content of `.claude/commands/executar-review.md`. If that file does not exist, read `~/.claude/commands/executar-review.md` instead. If neither exists, output `TASK BLOCKED: {task-id} — executar-review.md not found` and stop.

Call the Agent tool with:
- prompt: the full text of `executar-review.md`, followed by a newline, followed by: `{feature} {task-id}`
- subagent_type: "general-purpose"

Wait for this agent to return before doing anything else.

### Step 11 — Handle review outcome

Parse the `**Verdict:**` line from the review agent's output.

- **APPROVED**: First, update the task file's YAML frontmatter in the **main project directory**: set `status` to `"done"`, `completed_at` to the current ISO 8601 timestamp, `verdict` to `"APPROVED"`. Then update `tasks/prd-{feature}/memory/{task-id}.md` (main project directory): write a 2–3 sentence summary of the final implementation state in the **Ready for Next Run** section, and note any follow-up concerns or caveats for downstream tasks. Then append a `## Task {task-id} — {short task name}` section to `tasks/prd-{feature}/memory/MEMORY.md` (from the main project directory, not the worktree). Include 3–5 bullets covering: what was built, key conventions applied or discovered, any edge cases or gotchas, and files created/modified that downstream tasks should know about. Each bullet must be under 20 words. If MEMORY.md now exceeds 200 lines, delete the oldest `## Task X.Y` section (lowest task number) to stay within the limit. Then mark task complete in `tasks/prd-{feature}/tasks.md` by changing `[ ]` to `[x]` on the task entry line. Output: `TASK COMPLETE: {task-id}`. Stop — you are done.

- **APPROVED WITH OBSERVATIONS**: First, update the task file's YAML frontmatter in the **main project directory**: set `status` to `"done"`, `completed_at` to the current ISO 8601 timestamp, `verdict` to `"APPROVED"`. Then update the **Ready for Next Run** section of `tasks/prd-{feature}/memory/{task-id}.md` (same as APPROVED above). Then append the observations to the Notes section of `tasks/prd-{feature}/tasks/{task-id}.md`. Then append to `tasks/prd-{feature}/memory/MEMORY.md` (same format as APPROVED above; include the observations as one of the bullets). Mark task complete. Output: `TASK COMPLETE: {task-id}`. Stop.

- **REJECTED**: Read `tasks/prd-{feature}/memory/{task-id}.md` to recall prior-attempt decisions and corrections before fixing anything. Then read the Issues Found section of the review. Fix every flagged issue. Update the **Errors / Corrections** section of the per-task memory with the new issue and fix. Re-run Step 8 (full test run) and Step 9 (lint). Then go back to Step 10.

- **Unrecognizable output** (no `**Verdict:**` line found): treat as REJECTED with reason "review output malformed". Go back to Step 10.

---

## Output Format

| Signal | When |
|--------|------|
| `TASK COMPLETE: {task-id}` | Review approved (with or without observations) |
| `TASK BLOCKED: {task-id} — {reason}` | Pre-flight failure, missing files, unmet dependency, or 3× review rejection |
