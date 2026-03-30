# Skill Discovery — Verification Tests

Use this guide in a **fresh context window** to validate the skill discovery system added in commit `0d97b1f`. Each test is independent and can be run in any order.

## Automation levels

| Test | Automated? | Why |
|---|---|---|
| T1 — Explicit skill, found | ✅ Yes | Assert on file content (`hints/skills.md`) |
| T2 — Explicit skill, not found | ✅ Yes | Assert on file content (`hints/skills.md`) |
| T3 — Auto-discovery | 👁 Semi-manual | Discovery reasoning happens in chat, not on disk |
| T4 — Multiple explicit skills | ✅ Yes | Assert on file content (`hints/skills.md`) |
| T5 — Convention conflict | 👁 Semi-manual | Conflict reasoning and override happen in chat |

**For T1, T2, T4:** A sub-agent (or shell `grep`) can assert the exact content of `hints/skills.md` after invoking the Classifier — no human review needed.

**For T3, T5:** The evidence lives in the agent's Step 0 chat output (Part D summary and Part C conflict note). These require a human to read the agent's response and confirm the correct reasoning. There is no debug file written to disk — that would be clutter for normal pipeline runs. If full automation becomes a priority, the right path is adding an opt-in audit log to the pipeline (a `pipeline-run.md` that every stage appends to), which would have user value beyond just testability.

---

## Prerequisites

A `tasks/` directory at the root of the target project and the following skills installed:

| Path | Name |
|---|---|
| `~/.copilot/skills/prd/SKILL.md` | `prd` |
| `~/.copilot/skills/lint-files/SKILL.md` | `lint-files` |
| `~/.copilot/skills/agentic-eval/SKILL.md` | `agentic-eval` |

All three are already present on this machine.

---

## Test 1 — Explicit skill, file found ✅ automated

**Goal:** Classifier writes `hints/skills.md` with `status: found`; every downstream agent Step 0 loads the skill as `(explicit)`.

**Invoke (Copilot):**
```
@Classifier Agent "weather-app: Build a weather dashboard. Use skill prd."
```
**Or (Claude Code):**
```
/classificar-input "weather-app: Build a weather dashboard. Use skill prd."
```

**Pass criteria (assertable on disk):**
1. Classifier report line reads: `hints/skills.md: created (1 skill(s): prd)`
2. `tasks/prd-weather-app/hints/skills.md` contains:
   ```
   ## prd
   - status: found
   - path: /home/victor/.copilot/skills/prd/SKILL.md
   - source: explicit
   ```

**Pass criteria (chat — verify manually):**
3. When running `@PRD Agent tasks/prd-weather-app/hints/skills.md` (or the full pipeline), the PRD agent Step 0 log includes:
   ```
   Skills loaded: [prd (explicit)]
   ```

**Cleanup:** `rm -rf tasks/prd-weather-app`

---

## Test 2 — Explicit skill, not found ✅ automated

**Goal:** Classifier writes `hints/skills.md` with `status: not-found`; agents warn and continue without crashing.

**Invoke:**
```
@Classifier Agent "weather-app: Build a weather dashboard. Use skill nonexistent-skill."
```

**Pass criteria (assertable on disk):**
1. Classifier report line reads: `hints/skills.md: created (1 skill(s): nonexistent-skill)`
2. `tasks/prd-weather-app/hints/skills.md` contains:
   ```
   ## nonexistent-skill
   - status: not-found
   - path: not found in ~/.copilot/skills/ or ~/.agents/skills/
   - description: n/a
   - source: explicit
   ```

**Pass criteria (chat — verify manually):**
3. When the PRD agent runs, Step 0 Part A logs:
   ```
   ⚠️ Skill 'nonexistent-skill' was requested but not found. Proceeding without it.
   Skills loaded: []
   ```
   (Agent must NOT abort — it should continue into Phase 1–3 normally.)

**Cleanup:** `rm -rf tasks/prd-weather-app`

---

## Test 3 — Auto-discovery 👁 semi-manual

**Goal:** With no `hints/skills.md` present, the PRD agent auto-discovers the `prd` skill via Part B.

**Invoke (run Classifier first so the hints dir exists, but without a skill mention):**
```
@Classifier Agent "weather-app: Build a weather dashboard that shows temperature and forecast."
```
Then run the PRD agent directly:
```
@PRD Agent "weather-app: Build a weather dashboard that shows temperature and forecast."
```

**Pass criteria (assertable on disk):**
1. Classifier report: `hints/skills.md: skipped (no skill references found)` — file does NOT exist at `tasks/prd-weather-app/hints/skills.md`.

**Pass criteria (chat — verify manually):**
2. PRD agent Step 0 log:
   - Part A: `hints/skills.md not found — proceeding to Part B.`
   - Part B: scans `~/.copilot/skills/*/SKILL.md` and `~/.agents/skills/*/SKILL.md`
   - `prd` skill description matches ("Generate high-quality Product Requirements Documents") → added as `(discovered)`
   - Final log: `Skills loaded: [prd (discovered)]`

**Cleanup:** `rm -rf tasks/prd-weather-app`

---

## Test 4 — Multiple explicit skills ✅ automated

**Goal:** Two skills extracted and loaded.

**Invoke:**
```
@Classifier Agent "weather-app: Build a weather dashboard. Use skill prd. Also apply skill lint-files."
```

**Pass criteria (assertable on disk):**
1. Classifier report: `hints/skills.md: created (2 skill(s): prd, lint-files)`
2. `hints/skills.md` has two `## {name}` blocks, both `status: found`

**Pass criteria (chat — verify manually):**
3. When downstream agents run Step 0, they load both skills:
   ```
   Skills loaded: [prd (explicit), lint-files (explicit)]
   ```
   (`lint-files` guidance is applied if relevant to the current agent's task, otherwise noted as loaded but not applicable.)

**Cleanup:** `rm -rf tasks/prd-weather-app`

---

## Test 5 — Convention conflict 👁 semi-manual

**Goal:** When a skill's guidance contradicts CLAUDE.md conventions, the agent picks conventions and logs the override.

This test requires a skill that recommends something the project conventions forbid. The `lint-files` skill recommends ESLint/Prettier for JS/TS projects, while the project conventions (`CLAUDE.md`) are silent on this topic in the current repo. For a realistic conflict test, use a target project that has a `CLAUDE.md` with an explicit contradictory rule.

**Setup (one-time):**
Create a mock skill with a conflicting rule:
```bash
mkdir -p ~/.copilot/skills/test-conflict
cat > ~/.copilot/skills/test-conflict/SKILL.md << 'EOF'
---
name: test-conflict
description: 'Test skill that conflicts with CLAUDE.md — recommends storing money as floats.'
---
# Test Conflict Skill
Always store monetary values as floating-point numbers (e.g. `amount: number` in TypeScript).
EOF
```

**Invoke (in a project with CLAUDE.md that says "Money: integer minor units via src/lib/money.ts — never floats"):**
```
@Classifier Agent "billing-widget: Add a billing summary widget. Use skill test-conflict."
```
Then run the TechSpec or TaskImpl agent.

**Pass criteria (assertable on disk):**
1. `hints/skills.md` has `test-conflict` with `status: found`

**Pass criteria (chat — verify manually):**
2. The agent's Step 0 Part C logs a conflict note such as:
   ```
   ⚠️ Conflict: test-conflict recommends float money — overridden by CLAUDE.md convention (integer minor units via src/lib/money.ts).
   ```
3. The agent's generated output (TechSpec or code) uses integer minor units, NOT floats.

**Cleanup:**
```bash
rm -rf tasks/prd-billing-widget
rm -rf ~/.copilot/skills/test-conflict
```

---

## Quick smoke test (all in one)

If you want a single fast check that the system is wired end-to-end:

```
@Pipeline "weather-app: Build a simple weather dashboard showing temperature and 5-day forecast. Use skill prd."
```

**Expected Step 0 log in PRD agent output:**
```
Skills loaded: [prd (explicit)]
```

This confirms Classifier → `hints/skills.md` → PRD agent Step 0 Part A is working.

---

## What to look for across all tests

| Check | How | Test(s) |
|---|---|---|
| `hints/skills.md` written/skipped correctly | Read file or `grep` | T1, T2, T4 |
| `status: found \| not-found` per skill | Read `hints/skills.md` | T1, T2, T4 |
| `hints/skills.md` absent when no skill mentioned | `ls hints/` | T3 |
| `(explicit)` vs `(discovered)` labels | Chat — Step 0 Part D | T1, T3, T4 |
| Agent continues after `not-found` warning | Chat — agent produces output normally | T2 |
| CLAUDE.md wins on conflict | Chat — Step 0 Part C override note + artifact | T5 |
