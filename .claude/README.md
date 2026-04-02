# Agent Pipeline — Claude Code

This folder contains the Claude Code implementation of the agent pipeline. Each phase is a slash command (`.md` file) invoked via `/command-name` in Claude Code.

## Workflow

```mermaid
flowchart TD
    User(["User<br>/pipeline 'feature-name: description'"])

    subgraph Phase0["Phase 0 — Classify Input"]
        CLASSIFY["classificar-input<br>arg: 'feature-name: description'<br>→ tasks/prd-{f}/hints/*.md"]
    end

    subgraph Phase1["Phase 1 — PRD"]
        PRD["criar-prd<br>arg: 'feature-name: description'<br>→ tasks/prd-{f}/prd.md"]
    end

    subgraph Phase2["Phase 2 — TechSpec"]
        TECH["criar-techspec<br>arg: tasks/prd-{f}/prd.md<br>→ tasks/prd-{f}/techspec.md"]
    end

    subgraph Phase3["Phase 3 — Tasks"]
        TASKS["criar-tasks<br>arg: 'prd.md techspec.md'<br>→ tasks/prd-{f}/tasks/*.md"]
        GATE{{"APPROVAL<br>GATE"}}
    end

    subgraph Phase4["Phase 4 — Implementation (sequential)"]
        TASK["executar-task<br>arg: 'feature task-id'<br>isolation: worktree"]
        REVIEW["executar-review<br>arg: 'feature task-id'<br>→ APPROVED / REJECTED"]
        LOOP{{"REJECTED?<br>(max 3 cycles)"}}
        BLOCKED(["TASK BLOCKED<br>→ stop pipeline"])
        MERGE["git merge branch → main"]
        NEXT{{"More<br>tasks?"}}
    end

    subgraph Phase5["Phase 5 — QA"]
        QA["executar-qa<br>arg: 'feature'<br>→ PASSED / FAILED"]
    end

    subgraph Phase6["Phase 6 — Bugfix (if needed, max 3 rounds)"]
        BUGFIX["executar-bugfix<br>arg: 'feature bugfix-N: desc'<br>isolation: worktree"]
        BREVIEW["executar-review<br>arg: 'feature bugfix-N'"]
        BMERGE["git merge branch → main"]
        REQA["Re-run QA<br>(round counter++)"]
        MAXQA{{"Round 3<br>reached?"}}
    end

    DONE(["Pipeline Complete<br>feature merged to main"])
    MANUAL(["Manual intervention<br>required"])

    User --> Phase0
    Phase0 --> Phase1
    Phase1 --> Phase2
    Phase2 --> Phase3
    TASKS --> GATE
    GATE -- "yes" --> Phase4
    GATE -- "no" --> MANUAL

    TASK --> REVIEW
    REVIEW --> LOOP
    LOOP -- "APPROVED" --> MERGE
    LOOP -- "REJECTED" --> TASK
    LOOP -- "3rd rejection" --> BLOCKED
    BLOCKED --> MANUAL
    MERGE --> NEXT
    NEXT -- "yes" --> TASK
    NEXT -- "no" --> Phase5

    QA -- "PASSED" --> DONE
    QA -- "FAILED" --> Phase6

    BUGFIX --> BREVIEW
    BREVIEW -- "APPROVED" --> BMERGE
    BREVIEW -- "REJECTED" --> BUGFIX
    BMERGE --> REQA
    REQA --> MAXQA
    MAXQA -- "no, QA passed" --> DONE
    MAXQA -- "no, bugs remain" --> BUGFIX
    MAXQA -- "yes" --> MANUAL
```

## Differences from the Copilot version

| Aspect | Claude Code | Copilot (VS Code) |
|--------|-------------|-------------------|
| **Entry point** | `/pipeline "..."` slash command in any terminal | Select **Pipeline** agent mode in Copilot Chat (`Ctrl+Alt+I`) |
| **Sub-agent spawning** | `Agent` tool with `isolation: "worktree"` primitive | `agents:` frontmatter field; Pipeline invokes sub-agents via `runSubagent` |
| **Worktree isolation** | First-class `isolation: "worktree"` flag on the agent invocation | Explicit `git worktree add .worktrees/{feature}-task-{id}` terminal commands inside each agent |
| **Context isolation** | Enforced by the Claude Code runtime | Enforced by sub-agent boundary — each agent only sees files it reads from disk |
| **Command naming** | `/classificar-input`, `/criar-prd`, `/criar-techspec`, `/criar-tasks`, `/executar-task`, `/executar-review`, `/executar-qa`, `/executar-bugfix` | `Classifier Agent` (internal), `PRD Agent`, `TechSpec Agent`, `Tasks Agent`, `Task Implementation Agent`, `Review Agent`, `QA Agent`, `Bugfix Agent` |
| **Command files** | `.claude/commands/*.md` → installed to `~/.claude/commands/` | `.copilot/agents/*.agent.md` → installed to `~/.vscode-server/data/User/prompts/` (Linux) |
| **Self-reading commands** | Each orchestrator reads sub-command files at runtime to stay in sync | Sub-agents are referenced by name in `agents:` frontmatter; the runtime resolves them |
| **Phase 4 sequencing** | Strictly sequential, enforced by orchestrator loop | Strictly sequential, enforced by Pipeline agent loop (explicitly documented as critical) |
| **Phase 6 bugfix branching** | Each bugfix gets its own worktree via the `isolation: "worktree"` flag | Each bugfix explicitly runs `git worktree add .worktrees/{feature}-bugfix-{N}` before fixing |
| **Review max cycles** | 3 cycles before BLOCKED | 3 cycles before BLOCKED (identical logic) |
| **QA max rounds** | 3 total QA rounds | 3 total QA rounds (identical logic) |
| **Conventions file** | `CLAUDE.md` | `CLAUDE.md`, `AGENTS.md`, or `.github/copilot-instructions.md` (tries all three) |
| **Model** | Claude (depends on config) | `Auto (copilot)` — uses whatever model Copilot has active |

## Commands

| Command | File | User-invocable? | Description |
|---------|------|-----------------|-------------|
| `/pipeline` | `pipeline.md` | ✅ | Full orchestrated pipeline: PRD → TechSpec → Tasks → Implement → QA |
| `/classificar-input` | `classificar-input.md` | ✅ | Pre-process input into per-domain hint files for downstream agents |
| `/criar-prd` | `criar-prd.md` | ✅ | Generate a PRD with clarification questions |
| `/criar-techspec` | `criar-techspec.md` | ✅ | Generate a TechSpec from a PRD |
| `/criar-tasks` | `criar-tasks.md` | ✅ | Decompose PRD+TechSpec into ordered tasks |
| `/executar-task` | `executar-task.md` | ✅ | Implement a single task with TDD + internal review loop |
| `/executar-review` | `executar-review.md` | ✅ | Code review against PRD/TechSpec/CLAUDE.md conventions |
| `/executar-qa` | `executar-qa.md` | ✅ | E2E QA via Playwright MCP |
| `/executar-bugfix` | `executar-bugfix.md` | ✅ | Reproduce, fix, test, and review a bug |

## Requirements

- A `CLAUDE.md` in the target project documenting conventions, test command, and lint command
- Playwright MCP configured for `/executar-qa`
- Dev server running locally when QA is executed

## Installation

From the repo root:

```bash
./install.sh
```

Commands are installed to `~/.claude/commands/` and become available as slash commands globally in Claude Code. Re-run at any time to update.
