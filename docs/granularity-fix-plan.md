# Plan: Fix Pipeline Task Granularity & TDD Regression

**Date:** April 4, 2026  
**Status:** Ready to implement  
**Reference sessions:** `weather-app-copilot-5-SESSION.md` (10 tasks, 138 tests) vs `weather-app-copilot-6-SESSION.md` (6 tasks, 24 tests)

---

## Root Cause

The Prompt Refiner (Phase -0.5) enriched the spec well — FR-XX, acceptance criteria, design guidance — but provided **zero guidance on task granularity or inline testing strategy**. The Tasks Agent responded by condensing 10 tasks → 6, bundling 24 files into a single UI task ("Task 5.0 — UI Components"), and adding a dedicated final test task (6.0 — E2E Tests). The Review Agent had no rule to reject this. The QA Agent only validated AC pass/fail, not test distribution. All 12 ACs passed, masking the regression.

**5 compounding gaps:**

| # | Agent | Gap |
|---|-------|-----|
| 1 | Tasks Agent | No file count limit, no layer-first rule, no anti-final-test-task rule |
| 2 | Review Agent | No explicit rejection for domain/hooks/data logic without unit tests |
| 3 | PromptRefiner | No Section 8 "Task Decomposition Guidance"; `### Tasks Agent` block conditional on skills discovery |
| 4 | Pipeline gate | Binary yes/no; no revision loop; no pre-gate task count warning |
| 5 | QA Agent | No test distribution check — E2E-only not flagged as a concern |

---

## Fix Layers (Priority Order)

### Layer 1 — Tasks Agent: Granularity + Inline TDD
**Files:** `.copilot/agents/Tasks.agent.md` + `.claude/commands/criar-tasks.md`

Add **"Task Sizing Rules (Mandatory)"** section after the Phase 2 bullet list:

```
### Task Sizing Rules (Mandatory)
- **File count limit:** Each task must touch ≤4-5 NEW source files (excluding config/infra stubs).
  Scaffolding tasks may exceed this if files are small stubs (e.g., initial migration files).
  Any task requiring >6 new src/ files should be split immediately.
- **Layer-first decomposition:** Do not bundle domain types, business logic, UI components,
  and hooks in a single task. Organize strictly by layer:
    1. Scaffold (type definitions, constants, migrations)
    2. Domain logic (src/domain/)
    3. Data persistence (src/data/)
    4. Hooks (src/hooks/)
    5. UI components (src/components/) — max 1-2 per task
    6. Integration & routing — last
- **Unit tests are mandatory in the implementation task:** A dedicated test-only final task
  is an anti-pattern. Each task must include inline unit tests authored in the same task.
  Tests are not deferred to a later task.
  Exception: a dedicated E2E test task is allowed only if the TechSpec explicitly defines it.
```

---

### Layer 2 — Review Agent: Enforce Unit Tests for Logic Files
**Files:** `.copilot/agents/Review.agent.md` + `.claude/commands/executar-review.md`

Add after Step 4 (project conventions) checklist:

```
**Additionally, verify test coverage by file type:**
- **Domain/lib/hooks/data files:** If the task introduces new .ts files in src/domain/,
  src/lib/, src/hooks/, or src/data/, check for corresponding *.test.ts or
  __tests__/*.test.ts files. Missing unit tests for logic-bearing files is a MAJOR issue → REJECTED.
- **Pure UI/rendering components:** Unit tests are optional if E2E tests provide coverage.
  Only flag if acceptance criteria explicitly require unit tests.
- **Test-only final task anti-pattern:** If this task contains ONLY test files with NO
  corresponding new implementation files, flag as CRITICAL → REJECTED.
  Exception: if the TechSpec explicitly defines this as an E2E test task.
```

---

### Layer 3 — Pipeline: Pre-Gate Warning + Revision Loop
**Files:** `.copilot/agents/Pipeline.agent.md` + `.claude/commands/pipeline.md`

**Pre-gate validation** (before showing task list):
Count FR-XX items from `prd.md` and tasks from `tasks.md`. If `task_count < 4` AND `fr_count ≥ 4`, display:
```
⚠️ Warning: {task_count} tasks detected for a {fr_count}-FR feature.
   Consider requesting more granular decomposition.
```

**Upgrade Phase 3 gate** from binary yes/no to 3-option with revision loop (max 2 cycles):
```
How would you like to proceed?
- yes — proceed to Phase 4 implementation
- revise: {feedback} — re-run the Tasks Agent with your feedback appended (revision N/2)
- no — stop (planning artifacts remain in tasks/prd-{feature}/ for future use)
```

Revision loop logic:
- Increment `revision_attempt` counter (cap: 2)
- Re-invoke Tasks Agent with original inputs + `**REVISION {N}:** User feedback: {feedback}` appended
- Show updated task list with "(revision {N})" label and new task count vs. previous
- Loop back to gate

---

### Layer 4 — PromptRefiner: Always Generate Task Decomposition Section
**Files:** `.copilot/agents/PromptRefiner.agent.md` + `.claude/commands/refinar-prompt.md`

**In Step 4 (Analyze), add Section 8 analysis** (always — not conditional on skills):
```
8. Task Decomposition Guidance — generate ALWAYS. Structure:
   - Count the FR-XX items: "This feature has {N} functional requirements."
   - Recommend layer-based task structure: scaffold → domain → data → hooks →
     UI (1-2 components per task)
   - Inline testing requirement: "Each task must include inline unit tests.
     Do not create a dedicated final test task."
   - Concrete task count range: "Recommend {N}–{M} tasks total"
   - Ordering constraint: "Tasks must be completed sequentially"
```

**In Step 5 template**, add `## Task Decomposition Guidance` section (always present, never omitted).

**Update Step 6 (Agent Instructions)**:
- `### Tasks Agent` block is **always** generated (not conditional on skills)
- Contains granularity rules from Section 8

**Update omission rules**: `## Task Decomposition Guidance` is NEVER omitted.

**Update completeness check** to include:
```
- [ ] Task Decomposition Guidance recommends layer-based structure with explicit
      test-per-task rule and sequential ordering
- [ ] Agent Instructions includes ### Tasks Agent block with granularity guidance
```

---

### Layer 5 — Classifier: Route Task Decomposition Hints
**Files:** `.copilot/agents/Classifier.agent.md` + `.claude/commands/classificar-input.md`

**Expand the Tasks domain row** in the routing table:
```
Before: | Tasks | hints/tasks-hints.md | Test setup guidance, mocking strategies,
          test scenarios to cover, environment setup instructions |

After:  | Tasks | hints/tasks-hints.md | Test setup guidance, mocking strategies,
          test scenarios to cover, environment setup instructions,
          task granularity guidance, layer decomposition advice,
          recommended task count, testing strategy (inline per-task vs. final test task) |
```

**Add new routing row:**
```
| Task Decomposition Guidance | hints/tasks-hints.md |
  Content from ## Task Decomposition Guidance section in refined-prompt.md —
  task count range, layer-based structure, inline testing strategy |
```

---

### Layer 6 — QA Agent: Test Distribution Observability
**Files:** `.copilot/agents/QA.agent.md` + `.claude/commands/executar-qa.md`

Add **Step 2.5** between Steps 2 (environment check) and 3 (functional E2E testing):

```markdown
### Step 2.5 — Test Distribution Check

Scan the project for logic files missing unit tests. List all .ts files in:
src/domain/, src/lib/, src/hooks/, src/data/ (excluding .d.ts and .test.ts files).

For each: check for a corresponding *.test.ts or __tests__/*.test.ts file.
Collect unmatched files → ununit_files list.

Check if ANY .test.ts file exists anywhere in src/.
If none found: is_e2e_only = true.

Record for Step 7 report:
- If ununit_files: "OBSERVATION: Logic files without unit tests: {list}"
- If is_e2e_only: "🔴 MAJOR CONCERN: All tests are E2E-only. No unit tests found in src/.
  Code maintainability and regression risk are elevated."
```

This is **observability only** (not a FAIL gate) — it surfaces the pattern without blocking QA.

---

## Files to Modify

| Priority | File (Copilot) | File (Claude Code) | Change |
|----------|----------------|--------------------|--------|
| 1 | `.copilot/agents/Tasks.agent.md` | `.claude/commands/criar-tasks.md` | Add Task Sizing Rules |
| 2 | `.copilot/agents/Review.agent.md` | `.claude/commands/executar-review.md` | Add unit test enforcement |
| 3 | `.copilot/agents/Pipeline.agent.md` | `.claude/commands/pipeline.md` | Pre-gate warning + 3-option gate |
| 4 | `.copilot/agents/PromptRefiner.agent.md` | `.claude/commands/refinar-prompt.md` | Section 8 + always Tasks Agent block |
| 5 | `.copilot/agents/Classifier.agent.md` | `.claude/commands/classificar-input.md` | Expand Tasks routing + decomp row |
| 6 | `.copilot/agents/QA.agent.md` | `.claude/commands/executar-qa.md` | Add Step 2.5 |

Each Copilot `.agent.md` file has a parallel `.claude/commands/` counterpart — changes must be mirrored in both.

---

## Verification Checklist

- [ ] Run pipeline with a 6-FR feature → task count ≥ 6 (Layer 1 enforced)
- [ ] Submit task with `src/hooks/*.ts` and no `*.test.ts` → Review **REJECTED** (Layer 2)
- [ ] At Phase 3 gate, say `"revise: split UI into separate tasks"` → Tasks Agent re-runs, updated list shows "(revision 1)" with new count (Layer 3)
- [ ] Run PromptRefiner on any feature → `refined-prompt.md` always contains `## Task Decomposition Guidance` (Layer 4)
- [ ] Run QA against a project with only E2E tests → Step 2.5 report shows MAJOR CONCERN (Layer 6)

---

## Key Design Decisions

1. **All 6 layers recommended together** — they address different failure modes and are non-overlapping. Layers 1–2 prevent the problem. Layer 3 adds a human safety net. Layers 4–5 push guidance upstream. Layer 6 makes regressions visible.

2. **E2E task exception:** Review's CRITICAL rejection for test-only final tasks includes an explicit exception when the TechSpec defines the task as an E2E test task — prevents false positives on intentionally planned test tasks.

3. **Scaffold exemption in file count rule:** Tasks like "project scaffold" legitimately touch many config files (vite.config, tsconfig, package.json, tokens.css…). Rule only counts new `src/` source files.

4. **QA is observability, not a gate:** Step 2.5 is a MAJOR CONCERN note, not a FAIL. The fix enforcement happens upstream (Layers 1–2). QA surfaces the issue if it slips through.

5. **Revision loop cap at 2:** Beyond 2 revision cycles the gate prompts the user to either accept the current list or stop — avoids infinite loops with conflicting feedback.
