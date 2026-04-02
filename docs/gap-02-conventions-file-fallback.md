# GAP-02: Conventions File Fallback Chain Missing

**Status:** Done  
**Priority:** Medium  
**Affects:** Claude Code pipeline only

---

## Description

All Copilot agents resolve the project conventions file using a three-step fallback chain:

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.github/copilot-instructions.md`

They read the first file that exists. Claude Code commands only look for `CLAUDE.md`. Projects that follow the GitHub Copilot standard (`AGENTS.md`) or the repository-instructions standard (`.github/copilot-instructions.md`) will silently get no conventions loaded.

## Affected Claude Code Commands

| File | Current behavior |
|---|---|
| `criar-techspec.md` | Reads `CLAUDE.md` only |
| `criar-tasks.md` | Reads `CLAUDE.md` only |
| `executar-task.md` | Reads `CLAUDE.md` only |
| `executar-review.md` | Reads `CLAUDE.md` only |
| `executar-bugfix.md` | Reads `CLAUDE.md` only |

## Impact

**Medium.** Any project relying on `AGENTS.md` or `.github/copilot-instructions.md` as the conventions file will have five agents operating without project conventions. Critical constraints like money-as-cents (never floats), ULIDs (never UUIDs), Dexie migration rules, domain purity, and path aliases are all defined in the conventions file. Silent absence means those constraints are invisible to the agents.

## Fix

In each affected command, replace the single `CLAUDE.md` read with:

```
Read the first of the following files that exists and is non-empty:
1. CLAUDE.md
2. AGENTS.md
3. .github/copilot-instructions.md
If none exist, stop: "ERROR: No project conventions file found."
```

## Copilot Reference

From `TaskImpl.agent.md` (Step 1, item 5):
```
CLAUDE.md or AGENTS.md or .github/copilot-instructions.md
(try each in order, use the first found)
```
