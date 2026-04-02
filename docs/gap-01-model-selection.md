# GAP-01: Model Selection Per Agent

**Status:** Platform Constraint — Cannot Fix  
**Priority:** High (quality impact)  
**Affects:** Claude Code pipeline only

---

## Description

The Copilot pipeline assigns specific models to individual agents via a `model:` field in each agent's YAML frontmatter. The Claude Code pipeline has no equivalent mechanism and uses whatever model the session defaults to.

## Model Assignments in Copilot Pipeline

| Agent | Model | Rationale |
|---|---|---|
| Pipeline | Claude Sonnet 4.6 | Orchestration only, no deep reasoning |
| Classifier | Claude Sonnet 4.6 | Lightweight text classification |
| **PRD** | **Claude Opus 4.6** | Deep clarification + requirements reasoning |
| **TechSpec** | **Claude Opus 4.6** | Architectural decisions from codebase exploration |
| Tasks | Claude Sonnet 4.6 | Structured decomposition, template-driven |
| TaskImpl | Claude Sonnet 4.6 | Code generation with strict TDD protocol |
| **Review** | **Claude Opus 4.6** | Security + convention enforcement, no false negatives |
| QA | Claude Sonnet 4.6 | Browser automation + structured reporting |
| Bugfix | Claude Sonnet 4.6 | Code generation with reproduce-first protocol |

Opus is used for the three agents that do the deepest reasoning: PRD (ambiguity resolution, requirement quality), TechSpec (architectural coherence from real codebase), and Review (security analysis, convention strictness).

## Impact

**High.** If the Claude Code session default is Sonnet, the PRD Agent may produce less thorough functional requirements, the TechSpec Agent may miss architectural edge cases or codebase integration issues, and the Review Agent may pass code with subtle convention violations or security issues that Opus would catch.

There is no workaround in Claude Code's command file format — `model:` metadata in `.md` command files is not a supported feature.

## Why It Cannot Be Fixed

The Claude Code slash command format (`/command`) does not support frontmatter or any per-command model selection directive. Model selection is a session-level setting, not a command-level setting.

## Mitigation (Manual)

Users running the Claude Code pipeline can manually switch to a more capable model before running `/criar-prd`, `/criar-techspec`, and `/executar-review` directly. There is no way to automate this for the orchestrated `/pipeline` flow.

## Copilot Reference

```yaml
# PRD.agent.md, TechSpec.agent.md, Review.agent.md
model: Claude Opus 4.6
```

```yaml
# All other agent files
model: Claude Sonnet 4.6
```
