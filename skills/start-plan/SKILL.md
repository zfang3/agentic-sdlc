---
name: start-plan
description: Break an approved spec into small verifiable tasks with acceptance criteria and dependency ordering. Use when you have a spec, a ticket, or a clear topic to implement. Produces a plan.md the implementer follows.
category: sdlc
argument-hint: [ticket-or-topic]
---

# Plan

## Overview

Decomposes a spec into implementable units: small, testable tasks with explicit dependencies, acceptance criteria, and verification commands. The plan is the contract between intent and execution — if it's vague, implementation will drift.

The principle: **small, verifiable tasks beat one big implementation.** Each task should be implementable, testable, and verifiable in a single focused session. If a task needs two sessions, it's too big.

## Prerequisite

A spec must exist. If the argument is a topic and no spec file is found, run `/start-spec <topic>` first. If the argument is a ticket ID, check whether the ticket description counts as a spec — if it's detailed enough (users, AC, non-goals), proceed; otherwise tell the user to run `/start-spec` first.

## When to Use

- A spec exists and you're about to start building
- A ticket has been refined and you need to decompose it
- A feature is too big for a single session and needs staging

**When NOT to use:**
- Single-file trivial changes — just implement
- Spikes or exploratory work where the answer is unknown (do research first, not planning)
- Changes already broken down by a ticket system into atomic steps

## The Process

### Step 0 — Read project conventions

Read `docs/skills/start-plan.md` if present. Its contents are additional project guidance for this skill (task size ceilings, naming conventions, standing checkpoints, dependency rules). Follow them alongside the defaults below.

If the file is missing or only contains the stub template, tell the user:

> No project conventions declared at `docs/skills/start-plan.md`. Proceeding with built-in defaults. Run `/start-sync` to scaffold a stub if your team wants to capture conventions.

Then proceed to Step 1.

### Step 1 — Read-only mode

Before writing anything, gather context. Do not edit files during this phase.

1. Read the spec: `docs/sessions/<YYYY-MM-DD>-<slug>/spec.md`
2. Read `docs/architecture/overview.md` for stack, core concepts, and key files
3. Read `docs/architecture/verification.md` for the primitives the verification contract will reference. If this file is missing or still contains template placeholders, **stop** and run `/start-bootstrap` to fill it — `/start-plan` cannot produce a valid contract against absent primitives.
4. Read the relevant code area — follow the "key files" list from the project guide, expand as needed
5. Read the acceptance criteria from the spec
6. Note any recent ADRs under `docs/architecture/decisions/` that affect this work
7. If the repo has tests, read the existing test patterns for the area

For heavy codebase exploration (many files across many directories), fork to a `general-purpose` subagent with a tight "find X" prompt. Keep main context clean.

### Step 2 — Identify dependencies

Produce a dependency graph in your head (or sketch as text):

```
[Migration] → [Model] → [Service] → [Handler] → [Tests]
                   ↘ [Fixture]  ↗
```

Rules:

- Foundations before features
- Shared types/constants before consumers
- Stubs before implementations when two things cross-depend
- Tests can be parallel with the thing they test (TDD)

### Step 3 — Slice vertically, not horizontally

**Vertical slice** = user-visible behavior end-to-end:

> Task 1: User can create a thing (model + service + endpoint + basic test)
> Task 2: User can list their things (endpoint + test, reusing model)
> Task 3: User can delete a thing (endpoint + test)

**Horizontal slice** = one layer at a time, deferring user value:

> Task 1: All models for the whole feature
> Task 2: All services
> Task 3: All endpoints
> Task 4: All tests

Always vertical. Vertical slices let you test, demo, and revert individually.

### Step 4 — Write each task with a fixed shape

Every task in the plan follows this shape (see the [plan template](references/plan-template.md) for the full form):

```markdown
### Task N: <title>

**Summary**: One sentence about what changes.

**Files**:
- `path/to/file.ext` (new | modify)
- `path/to/start-tests/start-test_file.ext` (new)

**Acceptance criteria** (from spec):
- [ ] <testable>
- [ ] <testable>

**Steps**:
1. <action, with exact file path>
2. <action, with exact file path>

**Verify**:
```
<command that proves this task works, e.g. `pytest tests/path -k test_name`>
```

**Dependencies**: Task K, Task M (or "none")

**Size**: XS | S | M | L (if L, decompose further)
```

Task size guide:

| Size | Files | Scope |
|---|---|---|
| XS | 1 | A single function, constant, or config line |
| S | 1-2 | One endpoint, one component, one migration |
| M | 3-5 | One vertical slice of a feature |
| L | 5-8 | Multi-slice feature; usually should be two tasks |
| XL | 8+ | Always break down further |

### Step 5 — Order and add checkpoints

Order tasks by dependency (topological). Insert checkpoints between major sections:

```
Tasks 1-3: Foundation (model, migration, base service)
  ── Checkpoint: run full test suite, verify migration applies cleanly ──
Tasks 4-6: User-facing paths (endpoints + UI if applicable)
  ── Checkpoint: end-to-end smoke test ──
Tasks 7-8: Edge cases + error handling
  ── Checkpoint: /start-verify against the full spec ──
```

Checkpoints force the implementer to stop and prove correctness before continuing.

### Step 6 — Parallelism guidance

Mark tasks that can run in parallel (no shared files, no ordering dependency):

```
Tasks 2 and 3 are independent — can run in parallel.
Task 4 depends on Task 1 and Task 2.
```

`/start-build` uses these markers to decide whether to dispatch implementers serially or concurrently.

### Step 7 — Author the verification contract

With tasks drafted, produce `docs/sessions/<YYYY-MM-DD>-<slug>/verification.md` alongside the plan. Follow the shape in [verification-contract-template.md](references/verification-contract-template.md). The contract is authored during planning — not during or after build — because the contract IS the definition of done.

This is not a mechanical restatement of the plan's per-task `Verify` commands. Those are narrow gates for `/start-build` to check one task at a time. The contract is the comprehensive, artifact-anchored proof that the whole change works against the spec, executed by `/start-verify` at the end.

**Before per-task items, select the runtime**:

0. Read `docs/architecture/verification.md` → `## Runtime primitives` to see which runtimes exist. Pick exactly one for this contract. Default to the project-level `Default runtime` unless the spec implies otherwise (e.g. "verify against the PR preview", "run the e2e smoke in staging"). Write the selection into the contract's `## Runtime selection` stanza with a one-sentence rationale. Never leave this stanza absent — "the usual one" is a silent default and silent defaults are not allowed.

If the spec needs verification against a runtime that does not exist yet, do NOT invent one here. Add a task to this plan that updates `docs/architecture/verification.md` with the new runtime block, then author the contract against it.

For each task that produces observable behavior:

1. **Name the artifact**: pick a file path under `tmp/verify/` the task will produce. One artifact per task unless a split is necessary.
2. **Describe how to produce it**: reference primitives from `docs/architecture/verification.md` with parameters, OR write the exact command sequence. Never "run the tests and see."
3. **State the expectation mechanically**: `HTTP 200 and body contains "status": "ok"` — not "looks reasonable." An agent must be able to compare output to expectation without human judgment.
4. **Trace back to spec AC**: every spec acceptance criterion must appear in at least one task's expectation, OR be listed under `## Declared exclusions` with a written rationale.

For the `## Gates` section:

5. Select which gate primitives from `docs/architecture/verification.md` apply. All gates the project defines apply by default; exclude one only by an explicit `## Declared exclusions` entry with rationale.

For the `## Cross-task assertions` section:

6. Add diff-level invariants that span the whole change: no TODO/FIXME, no hardcoded secrets, no debug artifacts. Plus any spec-level invariant (e.g. "every new endpoint is authenticated").

For the `## Declared exclusions` section:

7. Document every intentional omission with a written rationale. An empty rationale is not allowed. If the section is truly empty, write the literal text `None — every contract item is enforced.`

If a needed primitive is missing from `docs/architecture/verification.md`, pause. Either add a task to this plan that updates the primitives file, or decompose the offending task so it uses only existing primitives. Never inline an undefined primitive into the contract — `/start-verify` will reject it.

### Step 8 — Self-review before saving

Read the whole plan AND the contract, and check:

**Plan**:

- [ ] Every task has testable acceptance criteria (from the spec)
- [ ] Every task has a Verify command that can actually be run
- [ ] No task is L or XL without a decomposition note
- [ ] No "TBD", "similar to", "as appropriate", or "figure out during implementation"
- [ ] File paths are real (checked against the current code) — if you invented one, say so
- [ ] Dependency order is consistent — no task references a later task's output
- [ ] Checkpoints exist between phases

**Contract**:

- [ ] `## Runtime selection` names an existing runtime from `docs/architecture/verification.md` with a written rationale
- [ ] Every task with observable behavior has a contract item with artifact path, production steps, and mechanically checkable expectation
- [ ] Every gate defined in `docs/architecture/verification.md` appears in the `## Gates` section or is under `## Declared exclusions` with rationale
- [ ] Every primitive referenced resolves to a definition in `docs/architecture/verification.md` under the selected runtime
- [ ] Every spec AC maps to at least one contract item's expectation, or to a declared exclusion with rationale
- [ ] No `<placeholder>`, `TBD`, or "figure out during build" in the contract
- [ ] `## Declared exclusions` is either the literal text `None — every contract item is enforced.` or lists each exclusion with a written rationale

Fix anything inline. Do not save a plan with known gaps.

### Step 9 — Save and announce

Save both files together:

```
docs/sessions/<YYYY-MM-DD>-<slug>/plan.md
docs/sessions/<YYYY-MM-DD>-<slug>/verification.md
```

(Same slug as the spec. Spec, plan, and contract all sit in the same session directory.)

Show the user:

- Plan location
- Contract location
- Task count by size
- Count of contract items (gates + task artifacts + cross-task assertions)
- Declared exclusions — read each one aloud with its rationale; exclusions are the easiest place for silent gaps to hide
- Any open questions that need their input
- Suggest next step: `/start-build`

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll figure out the steps during implementation" | You'll lose context every time you switch sessions. A written plan survives session boundaries. |
| "The task is too small for acceptance criteria" | Acceptance criteria take 30 seconds to write and save the rework loop when the implementation drifts. |
| "I'll do horizontal slices, it's cleaner" | Horizontal slices defer all user value to the end and make rollback impossible mid-feature. |
| "Tasks with 10 files are fine if they're all simple" | Tasks with 10 files can't be reviewed or reverted atomically. Split. |
| "Dependencies are obvious from the order" | Obvious to you now. Not to the implementer at 4pm three days later. Write them down. |
| "Checkpoints slow down the build" | Checkpoints prevent the "we built six tasks on a broken foundation" situation, which is far slower. |
| "I'll write Verify commands once I know the test framework" | Read `docs/architecture/overview.md` and the project's test files. Find out now. A plan without Verify commands is a wish list. |
| "The contract duplicates the per-task Verify commands" | Task `Verify` is a narrow per-task gate for `/start-build`. The contract is the artifact-level proof of the whole change for `/start-verify`. Different jobs, different granularity, both needed. |
| "This task is trivial, skip the contract item" | Every task with observable behavior produces an artifact someone could inspect. If you cannot name the artifact, the task's value is unobservable — push back on the task, not the contract. |
| "I'll add the missing primitive to `verification.md` after shipping" | Ship-then-backfill is how primitives get inconsistent. Add the primitive as a task in this plan, or decompose to avoid needing it. |

## Red Flags

- A plan with one big "implement the feature" task
- Task acceptance criteria that are just the task title restated
- File paths that don't exist in the repo and aren't marked as new
- "Similar to how X works" without naming the pattern to follow
- No Verify command on any task
- Tasks that mix refactoring and new behavior (split them)
- Plan longer than 20 tasks — either the spec is too big (decompose) or the tasks are too small (aggregate)
- Parallelism claimed but the "parallel" tasks touch the same files
- No `verification.md` written alongside `plan.md`
- `## Runtime selection` absent, empty, or naming a runtime that isn't defined in `docs/architecture/verification.md`
- Contract items that don't name an artifact path under `tmp/verify/`
- Contract that references primitives not defined in `docs/architecture/verification.md` under the selected runtime
- `## Declared exclusions` entries with empty or hand-wavy rationale
- Spec AC not traceable to a contract item or a declared exclusion

## Verification

- [ ] `docs/sessions/<YYYY-MM-DD>-<slug>/plan.md` exists
- [ ] `docs/sessions/<YYYY-MM-DD>-<slug>/verification.md` exists alongside the plan
- [ ] Contract's `## Runtime selection` names a runtime defined in `docs/architecture/verification.md` with a written rationale
- [ ] Every task has: summary, files, AC, steps, Verify, dependencies, size
- [ ] Every task with observable behavior has a matching contract item
- [ ] Every gate from `docs/architecture/verification.md` is in the contract or declared-excluded with rationale
- [ ] Every primitive referenced in the contract resolves to a definition under the selected runtime in `docs/architecture/verification.md`
- [ ] Every spec AC maps to a contract item or a declared exclusion
- [ ] No L/XL tasks left undecomposed
- [ ] No placeholders (`TBD`, `TODO`, `<...>`)
- [ ] Checkpoints inserted between phases
- [ ] Dependency order is consistent
- [ ] Open questions (if any) are flagged with what was checked to resolve them
- [ ] User has been shown both files and given the next step
