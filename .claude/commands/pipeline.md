# Feature Development Pipeline Orchestrator

You are an orchestrator. Your job is to coordinate a sequence of specialized agents to take a feature from idea to tested implementation.

**Feature request:** $ARGUMENTS
(Format: "feature-name: description of what to build")
Parse the feature name (kebab-case, e.g. `sidebar-badge`) and description from $ARGUMENTS.

---

## PHASE 1 — PRD Generation

Read the full content of `.claude/commands/criar-prd.md`.

Use the Agent tool to spawn the PRD agent:
```
Agent(
  prompt: "[full content of criar-prd.md]\n\nFeature request: {feature-name}: {description}",
  subagent_type: "general-purpose"
)
```

Wait for the agent to complete. Verify `tasks/prd-{feature}/prd.md` exists before continuing.

---

## PHASE 2 — TechSpec Generation

Read the full content of `.claude/commands/criar-techspec.md`.

Use the Agent tool to spawn the TechSpec agent:
```
Agent(
  prompt: "[full content of criar-techspec.md]\n\nArguments: tasks/prd-{feature}/prd.md",
  subagent_type: "general-purpose"
)
```

Wait for completion. Verify `tasks/prd-{feature}/techspec.md` exists before continuing.

---

## PHASE 3 — Task Decomposition + Human Approval Gate

Read the full content of `.claude/commands/criar-tasks.md`.

Use the Agent tool to spawn the Tasks agent:
```
Agent(
  prompt: "[full content of criar-tasks.md]\n\nArguments: tasks/prd-{feature}/prd.md tasks/prd-{feature}/techspec.md",
  subagent_type: "general-purpose"
)
```

After the agent completes, verify:
- `tasks/prd-{feature}/tasks.md` exists
- `tasks/prd-{feature}/tasks/` directory contains individual task files

Read `tasks/prd-{feature}/tasks.md` and present the full task list to the user.

**APPROVAL GATE (authoritative):** Ask the user:
> "The task list above will now be implemented one task at a time in isolated git branches (one branch per task). Each task runs in a clean context window and must pass all tests and a code review before the next task starts.
>
> Proceed with implementation? (yes / no)"

If no: stop the pipeline here. The planning artifacts remain in `tasks/prd-{feature}/` for future use.

---

## PHASE 4 — Task Implementation (one agent per task, worktree isolated)

Parse the ordered task list from `tasks/prd-{feature}/tasks.md`.

Read the full content of `.claude/commands/executar-task.md` once (reuse for all tasks).

For each task **sequentially** (respect dependency order — do not parallelize):

1. Spawn implementation agent in isolated worktree:
```
Agent(
  prompt: "[full content of executar-task.md]\n\nArguments: {feature} {task-id}",
  subagent_type: "general-purpose",
  isolation: "worktree"
)
```

2. Wait for the agent to complete (it will internally spawn the review agent and loop until approved).

3. Report result to user:
   - ✅ `Task {task-id} complete — branch ready for merge`
   - ❌ `Task {task-id} failed — stopping pipeline`

4. If failed: stop. Do not proceed to next task. Report the error.

5. After success: proceed to next task.

> **Why sequential?** Tasks are ordered by dependency. Task 2.0 may import types or modules created in Task 1.0. Parallel execution would cause import failures and file conflicts.

---

## PHASE 5 — QA Validation

Read the full content of `.claude/commands/executar-qa.md`.

Spawn the QA agent (no worktree — runs against merged main):
```
Agent(
  prompt: "[full content of executar-qa.md]\n\nFeature: {feature}",
  subagent_type: "general-purpose"
)
```

Read the QA report output.

- If **PASSED** or **PASSED WITH ISSUES (low severity only)**: proceed to pipeline summary.
- If **FAILED** or **REQUIRES BUGFIX**: list all bugs and proceed to Phase 6.

---

## PHASE 6 — Bug Fixes (if needed, worktree isolated per bug)

Read the full content of `.claude/commands/executar-bugfix.md` once.

For each bug identified in the QA report (assign IDs: bugfix-1, bugfix-2, ...):

```
Agent(
  prompt: "[full content of executar-bugfix.md]\n\nArguments: {feature} bugfix-{N}: {bug-description}",
  subagent_type: "general-purpose",
  isolation: "worktree"
)
```

After all bugs are fixed, re-run Phase 5 (QA) to confirm resolution.

---

## Pipeline Summary

Report to user:
```
## Pipeline Complete: {feature}

Phase 1 PRD:      ✅ tasks/prd-{feature}/prd.md
Phase 2 TechSpec: ✅ tasks/prd-{feature}/techspec.md
Phase 3 Tasks:    ✅ {N} tasks defined and approved
Phase 4 Impl:     ✅ {N}/{N} tasks implemented
Phase 5 QA:       ✅ PASSED / ⚠️ {N} bugs found and fixed
Phase 6 Bugfix:   ✅ {N} bugs resolved (or N/A)

All task branches are ready for review and merge.
```
