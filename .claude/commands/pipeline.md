# Feature Development Pipeline Orchestrator

You are an orchestrator. Your job is to coordinate a sequence of specialized agents to take a feature from idea to tested implementation.

**Feature request:** $ARGUMENTS

**Input resolution — do this before anything else:**

**Step 1 — Mode flag:** Scan $ARGUMENTS for `--auto` or `-y`. If found, set `interactive_mode = false` and remove the flag from the string. Otherwise set `interactive_mode = true`. When `interactive_mode = false`, Phase 1 and Phase 2 approval gates are skipped. Phase 3 always prompts regardless of this flag.

**Step 2 — File resolution:** If the stripped input looks like a file path (starts with `./`, `/`, `~/`, or ends with `.md` or `.txt`), read that file now and use its full contents as the feature request. If the file does not exist, stop: `ERROR: argument file not found: {path}`. Otherwise use the stripped input as-is.

**Step 3 — Feature name** (evaluate in order, use the first that matches):
1. Content starts with a short word or phrase followed by a colon (e.g. `weather-app: ...` or `My Feature: ...`) → use everything before the colon, converted to kebab-case.
2. Content contains a Markdown heading (`# Heading text`) → use the first heading's text, converted to kebab-case.
3. Neither → synthesize a concise kebab-case slug (2–4 words) that captures the core topic (e.g. `"Build a budget tracker with charts"` → `budget-tracker`).

**Step 4 — Description:** Use the full resolved content (after removing `--auto`/`-y`) as the description. Pass it verbatim to all downstream agents — do not truncate or summarize.

---

## CRITICAL RULES
> These rules constrain the target project's architecture. Every artifact this agent produces
> must be consistent with them — never design or specify anything that violates them.

- **Money:** always integer minor units (cents) via `src/lib/money.ts` — never floats
- **IDs:** always ULIDs via `src/lib/id.ts` — never UUIDs or `Math.random()`
- **Domain purity:** `src/domain/` must have zero React/Next.js imports
- **No server state:** no API routes, no server-side state — fully client-side
- **Dexie migrations:** one file per schema change in `src/data/migrations/` — never mutate existing ones
- **Tests must pass:** `pnpm test` must exit 0 before any APPROVE verdict
- **Lint must be clean:** `pnpm lint` must exit 0 before any APPROVE verdict

---

## PHASE 0 — Prompt Classification

Read the full content of `.claude/commands/classificar-input.md`. If that file does not exist, read `~/.claude/commands/classificar-input.md` instead. If neither exists:
> ⚠️ classificar-input.md not found. Skipping classification — downstream agents will ask their standard clarification questions.
Continue to Phase 1.

Call the Agent tool with:
- prompt: the full text of `classificar-input.md`, followed by a newline, followed by: `{feature-name}: {description}`
- subagent_type: "general-purpose"

Wait for the agent to return.

Check that `tasks/prd-{feature}/user-context.md` exists. If missing, log a warning and continue — do not stop:
> ⚠️ Classifier did not produce output. Proceeding without hints.

---

## PHASE 1 — PRD Generation

Read the full content of `.claude/commands/criar-prd.md`. If that file does not exist, read `~/.claude/commands/criar-prd.md` instead. If neither exists, stop and tell the user: "ERROR: criar-prd.md not found in .claude/commands/ or ~/.claude/commands/. Run install.sh from the agent-pipeline repo or copy the file manually."

Call the Agent tool with:
- prompt: the full text of `criar-prd.md`, followed by a newline, followed by: `Feature request: {feature-name}: {description}`
- subagent_type: "general-purpose"

Wait for the agent to return before doing anything else.

**File verification:** Check that `tasks/prd-{feature}/prd.md` exists and is non-empty.
- If it does not exist: tell the user "ERROR: PRD agent completed but prd.md was not created. Re-run /criar-prd {feature-name}: {description} manually, then resume the pipeline from Phase 2." Stop.

**APPROVAL GATE — PRD (skip if `interactive_mode = false`):** Ask the user:
> "PRD created at `tasks/prd-{feature}/prd.md`. Review it and confirm to proceed to TechSpec generation. (yes / no)"

If no: stop. Tell the user: "PRD artifact saved at `tasks/prd-{feature}/prd.md`. Edit it as needed and re-run from Phase 2 with `/criar-techspec tasks/prd-{feature}/prd.md`."

---

## PHASE 2 — TechSpec Generation

Read the full content of `.claude/commands/criar-techspec.md`. If that file does not exist, read `~/.claude/commands/criar-techspec.md` instead. If neither exists, stop and report the missing file to the user.

Call the Agent tool with:
- prompt: the full text of `criar-techspec.md`, followed by a newline, followed by: `tasks/prd-{feature}/prd.md`
- subagent_type: "general-purpose"

Wait for the agent to return before doing anything else.

**File verification:** Check that `tasks/prd-{feature}/techspec.md` exists and is non-empty.
- If it does not exist: tell the user "ERROR: TechSpec agent completed but techspec.md was not created. Re-run /criar-techspec tasks/prd-{feature}/prd.md manually, then resume from Phase 3." Stop.

**APPROVAL GATE — TechSpec (skip if `interactive_mode = false`):** Ask the user:
> "TechSpec created at `tasks/prd-{feature}/techspec.md`. Review it and confirm to proceed to task decomposition. (yes / no)"

If no: stop. Tell the user: "TechSpec artifact saved at `tasks/prd-{feature}/techspec.md`. Edit it as needed and re-run from Phase 3 with `/criar-tasks tasks/prd-{feature}/prd.md tasks/prd-{feature}/techspec.md`."

---

## PHASE 3 — Task Decomposition + Human Approval Gate

Read the full content of `.claude/commands/criar-tasks.md`. If that file does not exist, read `~/.claude/commands/criar-tasks.md` instead. If neither exists, stop and report the missing file to the user.

Call the Agent tool with:
- prompt: the full text of `criar-tasks.md`, followed by a newline, followed by: `tasks/prd-{feature}/prd.md tasks/prd-{feature}/techspec.md`
- subagent_type: "general-purpose"

Wait for the agent to return before doing anything else.

**File verification:**
- Check that `tasks/prd-{feature}/tasks.md` exists and is non-empty.
- Check that `tasks/prd-{feature}/tasks/` directory contains at least one `.md` file.
- If either check fails: tell the user "ERROR: Tasks agent completed but task files are missing. Re-run /criar-tasks manually, then resume from the approval gate below." Stop.

Read `tasks/prd-{feature}/tasks.md` and present the full task list to the user.

**Pre-gate validation:** Before presenting the approval prompt, count:
- `fr_count` = number of FR-XX items in `tasks/prd-{feature}/prd.md`
- `task_count` = number of tasks listed in `tasks/prd-{feature}/tasks.md`

Always display the ratio before the approval prompt:
```
📋 Task plan: {task_count} tasks for {fr_count} functional requirements.
```

If `task_count < fr_count`, display a warning (too few tasks — likely over-bundling):
```
⚠️ Warning: {task_count} tasks for {fr_count} FRs — fewer tasks than requirements suggests over-bundling.
    Consider requesting more granular decomposition (target: {fr_count}–{fr_count * 2} tasks).
```

If `task_count > fr_count * 3` AND `fr_count >= 3`, display a warning (too many tasks — likely over-splitting):
```
⚠️ Warning: {task_count} tasks for {fr_count} FRs — more than 3× the FR count suggests over-splitting.
    Consider merging tasks that only define types or empty stubs with the layer that uses them.
```

**APPROVAL GATE (authoritative — 3-option with revision loop, max 2 revision cycles):**

Initialize `revision_attempt = 0`.

Ask the user:
> "The task list above will now be implemented one task at a time. Each task runs in an isolated git worktree with a fresh context window, and must pass all tests and a code review before the next task starts. After each task is approved, its branch is merged to main so the next task builds on it.
>
> How would you like to proceed?
> - **yes** — proceed to Phase 4 implementation
> - **revise: {feedback}** — re-run the Tasks Agent with your feedback (revision {revision_attempt+1}/2)
> - **no** — stop (planning artifacts remain in `tasks/prd-{feature}/` for future use)"

Process the response:
- **yes** — proceed to Phase 4.
- **no** — stop. Planning artifacts remain in `tasks/prd-{feature}/` for future use.
- **revise: {feedback}** — execute the revision loop:
  - If `revision_attempt >= 2`: tell the user "Maximum of 2 revision cycles reached. Accept the current task list (yes) or stop (no)." Re-prompt with only yes/no options.
  - Otherwise: increment `revision_attempt`. Re-read the full content of `.claude/commands/criar-tasks.md` (or `~/.claude/commands/criar-tasks.md`). Call the Agent tool with:
    - prompt: the full text of `criar-tasks.md`, followed by a newline, followed by:
      `tasks/prd-{feature}/prd.md tasks/prd-{feature}/techspec.md`
      `**REVISION {revision_attempt}:** User feedback: {feedback}`
    - subagent_type: "general-purpose"
  - Wait for the agent to finish. Re-run pre-gate validation with updated counts.
  - Display the updated task list with "(revision {revision_attempt})" label and new vs. previous task count.
  - Loop back to the APPROVAL GATE prompt.

---

## PHASE 4 — Task Implementation (one agent per task, sequential, worktree isolated)

**Update `tasks/prd-{feature}/_meta.md`:** Set the Implementation row: `Status` → `in-progress`, `Timestamp` → current ISO 8601 timestamp.

Parse the ordered task list from `tasks/prd-{feature}/tasks.md`. Extract each task ID in dependency order (e.g. 1.0, 2.0, 3.0).

Read the full content of `.claude/commands/executar-task.md`. If that file does not exist, read `~/.claude/commands/executar-task.md` instead. If neither exists, stop and report the missing file to the user. Reuse this content for all tasks — do not re-read the file per task.

**CRITICAL: Process tasks one at a time. Do NOT call the Agent tool for task N+1 until task N has fully completed and its branch has been merged. This is a hard sequential requirement — parallelism will cause dependency failures.**

For each task, execute these steps **in order, waiting for each to complete before starting the next**:

**Step A — Spawn implementation agent:**
Call the Agent tool with:
- prompt: the full text of `executar-task.md`, followed by a newline, followed by: `{feature} {task-id}`
- subagent_type: "general-purpose"
- isolation: "worktree"

Wait for this agent to return a result. Do not proceed until it does.

**Step B — Evaluate result:**

The agent's final output will contain one of:
- `TASK COMPLETE: {task-id}` — success
- `TASK BLOCKED: {task-id} — {reason}` — the review loop exhausted retries; needs human intervention

If `TASK BLOCKED`:
- Report to user: "Task {task-id} is blocked after maximum review cycles. Reason: {reason}. Fix the issues manually or adjust the task definition, then re-run the pipeline from this task."
- Stop the pipeline. Do not proceed to the next task.

If the agent crashes, errors, or returns no recognizable output:
- Report to user: "Task {task-id} agent failed unexpectedly. Check the worktree branch for partial changes. Resolve manually and re-run the pipeline from this task."
- Stop the pipeline.

**Step C — Merge task branch to main:**

The worktree result includes the branch name. Run:
```bash
git merge {branch-name} --no-ff -m "feat: complete task {task-id} ({feature})"
```

If the merge fails (conflicts):
- Report to user: "Merge conflict merging task {task-id} branch. Resolve conflicts manually, complete the merge, then resume the pipeline from the next task."
- Stop.

After successful merge, report: ✅ `Task {task-id} complete and merged to main`

Then proceed to the next task.

> **Why sequential + merge?** Tasks are dependency-ordered. Task 2.0 may import types or use modules created in Task 1.0. Each new worktree branches from main, so Task 1.0 must be merged before Task 2.0's worktree is created.

**Update `tasks/prd-{feature}/_meta.md`:** All tasks implemented and merged. Set the Implementation row: `Status` → `complete`, `Timestamp` → current ISO 8601 timestamp.

---

## PHASE 5 — QA Validation

**Update `tasks/prd-{feature}/_meta.md`:** Set the QA row: `Status` → `in-progress`, `Timestamp` → current ISO 8601 timestamp.

Read the full content of `.claude/commands/executar-qa.md`. If that file does not exist, read `~/.claude/commands/executar-qa.md` instead. If neither exists, stop and report the missing file to the user.

Call the Agent tool with:
- prompt: the full text of `executar-qa.md`, followed by a newline, followed by: `{feature}`
- subagent_type: "general-purpose"

Wait for the agent to return before doing anything else.

Parse the QA report from the agent's output. Look for the Overall Status line:
- **PASSED** → update `tasks/prd-{feature}/_meta.md`: QA row `Status` → `complete`, `Timestamp` → current ISO 8601 timestamp. Then proceed to Pipeline Summary.
- **PASSED WITH ISSUES** → if all issues are LOW severity: update `tasks/prd-{feature}/_meta.md`: QA row `Status` → `complete`, `Timestamp` → current ISO 8601 timestamp. Then proceed to Pipeline Summary with a note.
- **FAILED** or **REQUIRES BUGFIX** → extract each BUG-N entry and proceed to Phase 6. (QA status remains `in-progress` until Phase 6 resolves it.)

If the agent's output contains no recognizable QA report:
- Report to user: "QA agent returned no report. Ensure the dev server is running (`{dev-command from CLAUDE.md}`) and re-run /executar-qa {feature}."
- Stop.

---

## PHASE 6 — Bug Fixes (worktree isolated per bug, max 3 QA rounds)

**Update `tasks/prd-{feature}/_meta.md`:** Set the Bugfix row: `Status` → `in-progress`, `Timestamp` → current ISO 8601 timestamp.

Read the full content of `.claude/commands/executar-bugfix.md`. If that file does not exist, read `~/.claude/commands/executar-bugfix.md` instead. If neither exists, stop and report the missing file to the user.

Track QA round count, starting at 1. Maximum 3 QA rounds total (Phase 5 + re-runs here).

For each bug from the QA report (bugfix-1, bugfix-2, ...):

Call the Agent tool with:
- prompt: the full text of `executar-bugfix.md`, followed by a newline, followed by: `{feature} bugfix-{N}: {bug-description}`
- subagent_type: "general-purpose"
- isolation: "worktree"

Wait for the agent to return. The agent will output `BUGFIX COMPLETE: bugfix-{N}` or `BUGFIX BLOCKED: bugfix-{N} — {reason}`.

If `BUGFIX BLOCKED`: record the bug as unresolved and continue with remaining bugs.

After all bugfix agents complete, merge each resolved bugfix branch to main (same pattern as Phase 4 Step C).

**Re-run QA (Phase 5)** to confirm resolution. Increment the QA round counter.

Parse the re-run QA result:
- **PASSED** or **PASSED WITH ISSUES** (all LOW): update `tasks/prd-{feature}/_meta.md`: QA row `Status` → `complete`, Bugfix row `Status` → `complete`, both `Timestamp` → current ISO 8601 timestamp. Then proceed to Pipeline Summary.
- **FAILED** or **REQUIRES BUGFIX**: loop back to spawn bugfix agents for remaining bugs.

If QA round counter reaches 3 and bugs remain:
- Update `tasks/prd-{feature}/_meta.md`: QA row `Status` → `failed`, Bugfix row `Status` → `complete`, both `Timestamp` → current ISO 8601 timestamp.
- Report to user: "Pipeline reached the maximum of 3 QA rounds. The following bugs remain unresolved: {list}. Manual intervention required."
- Stop. Do not loop again.

---

## Pipeline Summary

Report to user:
```
## Pipeline Complete: {feature}

Phase 1 PRD:      ✅ tasks/prd-{feature}/prd.md
Phase 2 TechSpec: ✅ tasks/prd-{feature}/techspec.md
Phase 3 Tasks:    ✅ {N} tasks defined and approved
Phase 4 Impl:     ✅ {N}/{N} tasks implemented and merged
Phase 5 QA:       ✅ PASSED / ⚠️ {N} bugs found and fixed
Phase 6 Bugfix:   ✅ {N} bugs resolved (or N/A)

Feature branch is fully merged to main and ready for PR.
```

---

## Output Format

On success, outputs the Pipeline Summary block above.
On any phase failure, outputs `ERROR: {reason}` or a phase-specific blocked/stop message.
