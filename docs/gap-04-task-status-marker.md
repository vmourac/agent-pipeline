# GAP-04: Task Status Marker Format Inconsistency

**Status:** Done  
**Priority:** Low  
**Affects:** Claude Code pipeline only

---

## Description

When a task implementation is approved, the agent marks it complete in `tasks/prd-{feature}/tasks.md`. The two pipelines use different marker formats:

| Pipeline | Marker used |
|---|---|
| Claude Code (`executar-task.md`) | `[DONE]` (plain text, non-standard) |
| Copilot (`TaskImpl.agent.md`) | `[x]` (standard markdown checkbox) |

The initial task file produced by `criar-tasks.md` / `Tasks.agent.md` uses `[ ]` (unchecked markdown checkbox) in both pipelines. Completion diverges.

## Example

Initial state (identical in both pipelines):
```markdown
| 2.0 | Add badge component | 1.0 | [ ] |
```

After task completion — Claude Code:
```markdown
| 2.0 | Add badge component | 1.0 | [DONE] |
```

After task completion — Copilot:
```markdown
| 2.0 | Add badge component | 1.0 | [x] |
```

## Impact

**Low.** The pipeline's own signal parsing relies on `TASK COMPLETE: {task-id}` output (not the marker in tasks.md), so neither behavior breaks the pipeline. However:

- Any tooling, scripts, or GitHub Actions that parse task completion using standard markdown checkbox syntax (`[x]`) will miss `[DONE]` entries.
- Users who alternate between Copilot and Claude Code on the same feature get inconsistent task file state.
- The `[DONE]` format cannot be rendered by standard markdown renderers as a checked checkbox.

## Fix

In `executar-task.md`, Step 10 (APPROVED handling):

**Current:**
```
Mark task complete in `tasks/prd-{feature}/tasks.md` by adding `[DONE]` next to the task entry.
```

**Replace with:**
```
Mark task complete in `tasks/prd-{feature}/tasks.md` by changing `[ ]` to `[x]` on the task's row.
```
