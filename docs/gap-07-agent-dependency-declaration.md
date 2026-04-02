# GAP-07: No Agent Dependency Declaration

**Status:** Platform Constraint — Cannot Fix  
**Priority:** Low (IDE tooling concern)  
**Affects:** Claude Code pipeline only

---

## Description

The Copilot pipeline declares inter-agent dependencies in each agent's YAML frontmatter via an `agents:` field:

```yaml
# TaskImpl.agent.md
agents: [Review Agent]

# Bugfix.agent.md
agents: [Review Agent]

# Pipeline.agent.md
agents: [Classifier Agent, PRD Agent, TechSpec Agent, Tasks Agent, Task Implementation Agent, QA Agent, Bugfix Agent]
```

This allows VS Code to:
- Understand the dependency graph at install time
- Validate that referenced agents are installed before a run begins
- Potentially pre-warm agent contexts
- Surface dependency relationships in the UI

The Claude Code pipeline has no equivalent. The pipeline's sub-agent invocations are implicit — discovered only by reading the command file's prose at runtime.

## Impact

**Low.** This is purely an IDE tooling and developer experience concern. The Claude Code pipeline works correctly without declared dependencies. If a referenced command file is missing, the error surfaces at runtime when the pipeline attempts to read it, not at startup. The error messages are actionable and include re-run instructions.

## Why It Cannot Be Fixed

The Claude Code command format does not support frontmatter or any structured metadata. The `.md` files are flat markdown documents. Dependency relationships can only be expressed as prose inside the document.

## Documentation Mitigation

The `CLAUDE.md` at the repo root documents the full pipeline architecture and which commands call which. This serves as the human-readable dependency graph. It does not give any IDE-level validation guarantees, but it ensures developers understand the invocation structure without reading every command file.
