# GAP-03: Worktree Self-Management Missing in Task and Bugfix Agents

**Status:** Fixable  
**Priority:** Medium (safety/isolation impact for direct invocations)  
**Affects:** Claude Code pipeline only

---

## Description

The Copilot `TaskImpl.agent.md` and `Bugfix.agent.md` agents explicitly create their own git worktrees as part of their execution steps, guaranteeing isolation regardless of how the agent is invoked.

The Claude Code `executar-task.md` and `executar-bugfix.md` commands have **no** `git worktree add` step. They rely entirely on the `isolation: "worktree"` parameter that `pipeline.md` passes to the Agent tool call. This parameter is only set when called from the pipeline orchestrator.

## Consequence

When a user invokes the commands directly:
```
/executar-task sidebar-badge 2.0
/executar-bugfix sidebar-badge bugfix-1: badge NaN
```

…the agent runs with no branch isolation. All code is written directly on whatever branch is currently checked out (typically `main`). There is no protection against:
- Committing implementation code directly to `main`
- Mixing multiple tasks' changes in the same working tree
- Cross-contamination between concurrent invocations

Both commands are user-invocable (no invocability guard exists in Claude Code — see GAP-06), making this a real user-facing risk.

## Copilot Agent Behavior (correct)

From `TaskImpl.agent.md` (Step 4):
```bash
git worktree add .worktrees/{feature}-task-{task-id} -b feat/{feature}-task-{task-id}
```
If the branch already exists:
```bash
git worktree add .worktrees/{feature}-task-{task-id} feat/{feature}-task-{task-id}
```
All subsequent implementation work runs inside `.worktrees/{feature}-task-{task-id}/`.

The same pattern applies to `Bugfix.agent.md` (Step 3) with `{feature}-{bugfix-id}`.

## Fix

Add an explicit worktree creation step to both commands, between the dependency verification step and the implementation plan step.

### For `executar-task.md`

Add after Step 3 (dependency check), before Step 4 (task summary):

```
**Step 4 — Create git worktree (isolation):**

Run:
  git worktree add .worktrees/{feature}-task-{task-id} -b feat/{feature}-task-{task-id}

If the branch already exists (e.g. resuming after interruption), run:
  git worktree add .worktrees/{feature}-task-{task-id} feat/{feature}-task-{task-id}

All file reads, writes, test runs, and lint runs from this point forward must
happen inside `.worktrees/{feature}-task-{task-id}/`.

Output: `BRANCH: feat/{feature}-task-{task-id}`
```

### For `executar-bugfix.md`

Add after Step 2 (derive commands), before Step 3 (reproduce):

```
**Step 3 — Create git worktree (isolation):**

Run:
  git worktree add .worktrees/{feature}-{bugfix-id} -b feat/{feature}-{bugfix-id}

If the branch already exists:
  git worktree add .worktrees/{feature}-{bugfix-id} feat/{feature}-{bugfix-id}

All work from this point forward runs inside `.worktrees/{feature}-{bugfix-id}/`.

Output: `BRANCH: feat/{feature}-{bugfix-id}`
```

The pipeline can continue to pass `isolation: "worktree"` as belt-and-suspenders. The agent's own `git worktree add` is the safety net for direct user invocations.
