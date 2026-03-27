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

## Process

### Step 1 — Load context
Read:
- `CLAUDE.md` — project conventions, test command, lint command
- `tasks/prd-{feature}/prd.md` — expected behavior
- `tasks/prd-{feature}/techspec.md` — intended design

If any of these files do not exist, stop and output:
`BUGFIX BLOCKED: {bugfix-id} — required context file missing: {filename}`

### Step 2 — Derive commands from CLAUDE.md
From `CLAUDE.md`, identify the test command and lint command. If not specified, infer from `package.json`, `Makefile`, or `pyproject.toml`.

### Step 3 — Reproduce
Write a failing test that reproduces the bug BEFORE touching any implementation code.
Run the test command to confirm the test fails with the expected error.

If you cannot reproduce the bug with a test, document why and proceed to Step 4 with extra caution.

### Step 4 — Root cause analysis
Identify the root cause. Do NOT apply workarounds — fix the underlying issue.

### Step 5 — Fix implementation
Implement the minimal fix. Run the full test suite:
- All tests must pass, including your new regression test.
- If other tests now fail, fix those regressions before continuing.

### Step 6 — Lint check
Run the lint command from Step 2. Fix all errors before continuing.

## Review loop (max 3 cycles)

Initialize a review cycle counter at 0.

### Step 7 — Spawn review agent
Increment the cycle counter.

If the cycle counter exceeds 3:
- Output: `BUGFIX BLOCKED: {bugfix-id} — review rejected 3 times. Last rejection: {summary of last rejection reason}`
- Stop.

Read the full content of `.claude/commands/executar-review.md`.

Call the Agent tool with:
- prompt: the full text of `executar-review.md`, followed by a newline, followed by: `{feature} {bugfix-id}`
- subagent_type: "general-purpose"

Wait for the agent to return before doing anything else.

### Step 8 — Handle review outcome

Parse the `**Verdict:**` line from the review agent's output.

- **APPROVED** or **APPROVED WITH OBSERVATIONS**: Output `BUGFIX COMPLETE: {bugfix-id}`. Stop.
- **REJECTED**: Fix every issue listed in the review's Issues Found section. Re-run Step 5 (tests) and Step 6 (lint). Then go back to Step 7.
- **Unrecognizable output** (no `**Verdict:**` line found): treat as REJECTED with reason "review output malformed". Go back to Step 7.
