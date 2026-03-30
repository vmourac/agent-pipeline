# Task Implementation Agent

You are a senior developer implementing a specific task. The task is NOT complete until all tests pass AND the review approves.

**Arguments:** $ARGUMENTS — either `"feature task-id"` (e.g. `sidebar-badge 2.0`) or a path to a file containing that string.

**Argument resolution (do this first):**
If $ARGUMENTS looks like a file path — starts with `./`, `/`, `~/`, or ends with `.md` or `.txt` — read the file at that path and use its full contents as the arguments string. If the file does not exist, stop and output: `TASK BLOCKED: unknown — argument file not found: {path}`.
Otherwise use $ARGUMENTS as-is.

Parse the resolved string: everything before the first space is the feature name; everything after is the task ID.

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

## Pre-flight (all required)

### Step 1 — Load all context
Read in order:
1. `tasks/prd-{feature}/tasks/{task-id}.md` — your task definition (e.g. `tasks/prd-sidebar-badge/tasks/2.0-add-badge.md`)
2. `tasks/prd-{feature}/prd.md` — requirements context
3. `tasks/prd-{feature}/techspec.md` — implementation spec
4. `tasks/prd-{feature}/tasks.md` — full task list and dependency order
5. `CLAUDE.md` — project conventions, test command, lint command

If any of these files do not exist, stop immediately and output:
`TASK BLOCKED: {task-id} — required context file missing: {filename}`

### Step 2 — Derive commands from CLAUDE.md
From `CLAUDE.md`, identify:
- **Test command** (e.g. `pnpm test`, `npm test`, `yarn test`, `pytest`, etc.)
- **Lint command** (e.g. `pnpm lint`, `eslint .`, `ruff check .`, etc.)
- **Project-specific conventions** (naming, money handling, IDs, module boundaries, etc.)

If CLAUDE.md does not specify these commands, use the project's `package.json`, `Makefile`, or `pyproject.toml` to infer them.

### Step 3 — Understand dependencies
Read the `Depends on:` field in the task file. If this task depends on a prior task, verify that prior task's acceptance criteria are satisfied in the current codebase before writing any code. If dependencies are not met, stop and output:
`TASK BLOCKED: {task-id} — dependency task {dep-id} acceptance criteria not satisfied`

### Step 4 — Task summary
Before coding, output:
- Task ID and name
- Objectives
- Files you plan to create or modify
- Risks and uncertainties

## Implementation

### Step 5 — Approach plan
Write a numbered step-by-step implementation plan before touching any file.

### Step 6 — TDD implementation
For each piece of functionality:
1. Write the failing test first
2. Run the test command to confirm failure
3. Implement minimal code to pass
4. Run the test command to confirm pass
5. Refactor if needed, re-run tests

### Step 7 — Final test run
Run the full test suite using the test command from Step 2.
**ALL tests must pass — not just your new ones. Fix any regressions before continuing.**

### Step 8 — Lint check
Run the lint command from Step 2. Fix all errors before continuing.

## Review loop (max 3 cycles)

Initialize a review cycle counter at 0.

### Step 9 — Spawn review agent
Increment the cycle counter.

If the cycle counter exceeds 3:
- Output: `TASK BLOCKED: {task-id} — review rejected 3 times. Last rejection: {summary of last rejection reason}`
- Stop. Do not attempt further review cycles.

Read the full content of `.claude/commands/executar-review.md`.

Call the Agent tool with:
- prompt: the full text of `executar-review.md`, followed by a newline, followed by: `{feature} {task-id}`
- subagent_type: "general-purpose"

Wait for this agent to return before doing anything else.

### Step 10 — Handle review outcome

Parse the `**Verdict:**` line from the review agent's output.

- **APPROVED**: Mark task complete in `tasks/prd-{feature}/tasks.md` by adding `[DONE]` next to the task entry. Output: `TASK COMPLETE: {task-id}`. Stop — you are done.

- **APPROVED WITH OBSERVATIONS**: Append the observations to the Notes section of `tasks/prd-{feature}/tasks/{task-id}.md`. Mark task complete. Output: `TASK COMPLETE: {task-id}`. Stop.

- **REJECTED**: Read the Issues Found section of the review. Fix every flagged issue. Re-run Step 7 (full test run) and Step 8 (lint). Then go back to Step 9.

- **Unrecognizable output** (no `**Verdict:**` line found): treat as REJECTED with reason "review output malformed". Go back to Step 9.
