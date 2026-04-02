# GAP-05: Review Agent Path Has No Global Fallback

**Status:** Done  
**Priority:** Medium  
**Affects:** Claude Code pipeline only

---

## Description

`pipeline.md` reads every sub-command file with a local-then-global fallback:
```
Read .claude/commands/criar-prd.md; if not found, read ~/.claude/commands/criar-prd.md
```

However, `executar-task.md` and `executar-bugfix.md` — which spawn the review agent internally — only read:
```
Read the full content of `.claude/commands/executar-review.md`
```

There is **no fallback** to `~/.claude/commands/executar-review.md`.

## Affected Files

| File | Reads review agent at |
|---|---|
| `executar-task.md` | `.claude/commands/executar-review.md` (no fallback) |
| `executar-bugfix.md` | `.claude/commands/executar-review.md` (no fallback) |

## Impact

**Medium.** Users who install commands globally to `~/.claude/commands/` and run them against repos without a local `.claude/` directory will hit a file-not-found error at the review step. The implementation reaches Step 9 (or Step 7 for bugfixes) successfully, then silently fails to load the review agent. The review cycle never executes.

This is a real failure mode for the recommended global install pattern documented in `install.sh`.

## Fix

In both `executar-task.md` (Step 9) and `executar-bugfix.md` (Step 7), replace the single-path read with the same fallback pattern used by `pipeline.md`:

```
Read .claude/commands/executar-review.md.
If not found, read ~/.claude/commands/executar-review.md.
If neither exists, stop:
  TASK BLOCKED: {task-id} — executar-review.md not found in .claude/commands/ or ~/.claude/commands/
```

## Copilot Reference

Copilot agents invoke the `Review Agent` by registered name via the VS Code agent runtime — path resolution is handled by the platform and always succeeds if the agent is installed. No equivalent fragility exists.
