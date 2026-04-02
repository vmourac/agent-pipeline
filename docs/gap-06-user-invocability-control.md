# GAP-06: No User-Invocability Control

**Status:** Platform Constraint — Cannot Fix  
**Priority:** Low (UX concern)  
**Affects:** Claude Code pipeline only

---

## Description

The Copilot pipeline marks the Classifier agent as non-user-invocable via a frontmatter field:

```yaml
# Classifier.agent.md
user-invocable: false
```

This prevents the VS Code Copilot UI from presenting the Classifier as a standalone option that users can run directly. The Classifier is an internal Phase 0 step intended to be called only by the Pipeline orchestrator.

The Claude Code pipeline has no equivalent mechanism. The `/classificar-input` command is equally accessible in the slash command menu as `/pipeline`, `/criar-prd`, or any other command.

## Impact

**Low.** This is a UX/discoverability concern. If a user runs `/classificar-input` directly, it will execute correctly — creating `user-context.md` and hint files. These artifacts have no harmful side effects. However:

- Hint files created by a standalone classifier run will be consumed by subsequent agents as if they came from a full pipeline run, potentially with stale or mismatched context.
- The user may be confused when the Classifier runs but no PRD is produced, expecting it to be part of a larger flow.

## Why It Cannot Be Fixed

The Claude Code command format does not support any `user-invocable`, `hidden`, or visibility metadata. All files in `.claude/commands/` are uniformly exposed as slash commands.

## Potential Workaround

Consider prefixing internal-only commands with an underscore or a namespace to visually distinguish them in the slash command menu. For example, renaming `classificar-input.md` to `_pipeline-classify.md`. This has no technical effect but signals intent to developers reading the commands directory.

This is a convention choice, not a platform feature.
