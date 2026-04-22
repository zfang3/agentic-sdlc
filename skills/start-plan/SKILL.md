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

### Step 1 — Read-only mode

Before writing anything, gather context. Do not edit files during this phase.

1. Read the spec: `docs/sessions/<YYYY-MM-DD>-<slug>/spec.md`
2. Read `docs/architecture/overview.md` for stack, core concepts, and key files
3. Read the relevant code area — follow the "key files" list from the project guide, expand as needed
4. Read the acceptance criteria from the spec
5. Note any recent ADRs under `docs/architecture/decisions/` that affect this work
6. If the repo has tests, read the existing test patterns for the area

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

### Step 7 — Self-review before saving

Read the whole plan and check:

- [ ] Every task has testable acceptance criteria (from the spec)
- [ ] Every task has a Verify command that can actually be run
- [ ] No task is L or XL without a decomposition note
- [ ] No "TBD", "similar to", "as appropriate", or "figure out during implementation"
- [ ] File paths are real (checked against the current code) — if you invented one, say so
- [ ] Dependency order is consistent — no task references a later task's output
- [ ] Checkpoints exist between phases

Fix anything inline. Do not save a plan with known gaps.

### Step 8 — Save and announce

Save to:

```
docs/sessions/<YYYY-MM-DD>-<slug>/plan.md
```

(Same slug as the spec. The spec and plan sit in the same directory.)

Show the user:
- Plan location
- Task count by size
- Estimated number of vertical slices
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

## Red Flags

- A plan with one big "implement the feature" task
- Task acceptance criteria that are just the task title restated
- File paths that don't exist in the repo and aren't marked as new
- "Similar to how X works" without naming the pattern to follow
- No Verify command on any task
- Tasks that mix refactoring and new behavior (split them)
- Plan longer than 20 tasks — either the spec is too big (decompose) or the tasks are too small (aggregate)
- Parallelism claimed but the "parallel" tasks touch the same files

## Verification

- [ ] `docs/sessions/<YYYY-MM-DD>-<slug>/plan.md` exists
- [ ] Every task has: summary, files, AC, steps, Verify, dependencies, size
- [ ] No L/XL tasks left undecomposed
- [ ] No placeholders (`TBD`, `TODO`, `<...>`)
- [ ] Checkpoints inserted between phases
- [ ] Dependency order is consistent
- [ ] Open questions (if any) are flagged with what was checked to resolve them
- [ ] User has been shown the plan and given the next step
