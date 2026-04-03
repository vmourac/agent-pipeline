# Bugfix Agent

You are a senior developer fixing a specific bug. The fix is NOT complete until all tests pass AND the review approves.

**Arguments:** $ARGUMENTS — either `"feature bugfix-N: description"` or a path to a file containing that string.

**Argument resolution (do this first):**
If $ARGUMENTS looks like a file path — starts with `./`, `/`, `~/`, or ends with `.md` or `.txt` — read the file at that path and use its full contents as the arguments string. If the file does not exist, stop and output: `BUGFIX BLOCKED: unknown — argument file not found: {path}`.
Otherwise use $ARGUMENTS as-is.

Parse the resolved string:
- Everything before the first space: feature name
- The next token (e.g. `bugfix-1`): bugfix ID
- Everything after the colon: bug description

Example: `sidebar-badge bugfix-2: badge count shows NaN when no items exist`

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

## Process

### Step 1 — Load context
Read:
- `CLAUDE.md` (or `AGENTS.md` / `.github/copilot-instructions.md` if absent) — project conventions, test command, lint command
- `tasks/prd-{feature}/prd.md` — expected behavior
- `tasks/prd-{feature}/techspec.md` — intended design
- `tasks/prd-{feature}/memory/MEMORY.md` (if it exists) — apply its architectural context when identifying root causes and selecting fix approaches

If any of the first three files do not exist, stop and output:
`BUGFIX BLOCKED: {bugfix-id} — required context file missing: {filename}`

### Step 2 — Derive commands from conventions file
From the conventions file, identify the test command and lint command. If not specified, infer from `package.json`, `Makefile`, or `pyproject.toml`.

### Step 3 — Create git worktree (branch isolation)
Run `git worktree add .worktrees/{feature}-{bugfix-id} -b feat/{feature}-{bugfix-id}`.
If the branch already exists, run `git worktree add .worktrees/{feature}-{bugfix-id} feat/{feature}-{bugfix-id}` instead.

All file reads, writes, test runs, and lint runs from this point forward happen inside `.worktrees/{feature}-{bugfix-id}/`.

### Step 4 — Reproduce
Write a failing test that reproduces the bug BEFORE touching any implementation code.
Run the test command to confirm the test fails with the expected error.

If you cannot reproduce the bug with a test, document why and proceed to Step 4 with extra caution.

### Step 5 — Root cause analysis
Identify the root cause. Do NOT apply workarounds — fix the underlying issue.

### Step 6 — Fix implementation
Implement the minimal fix. Run the full test suite:
- All tests must pass, including your new regression test.
- If other tests now fail, fix those regressions before continuing.

### Step 7 — Lint check
Run the lint command from Step 2. Fix all errors before continuing.

## Review loop (max 3 cycles)

Initialize a review cycle counter at 0.

### Step 8 — Spawn review agent
Increment the cycle counter.

If the cycle counter exceeds 3:
- Output: `BUGFIX BLOCKED: {bugfix-id} — review rejected 3 times. Last rejection: {summary of last rejection reason}`
- Stop.

Read the full content of `.claude/commands/executar-review.md`. If that file does not exist, read `~/.claude/commands/executar-review.md` instead. If neither exists, output `BUGFIX BLOCKED: {bugfix-id} — executar-review.md not found` and stop.

Call the Agent tool with:
- prompt: the full text of `executar-review.md`, followed by a newline, followed by: `{feature} {bugfix-id}`
- subagent_type: "general-purpose"

Wait for the agent to return before doing anything else.

### Step 9 — Handle review outcome

Parse the `**Verdict:**` line from the review agent's output.

- **APPROVED** or **APPROVED WITH OBSERVATIONS**: Output `BUGFIX COMPLETE: {bugfix-id}`. Stop.
- **REJECTED**: Fix every issue listed in the review's Issues Found section. Re-run Step 6 (tests) and Step 7 (lint). Then go back to Step 8.
- **Unrecognizable output** (no `**Verdict:**` line found): treat as REJECTED with reason "review output malformed". Go back to Step 8.
