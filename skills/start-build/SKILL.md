---
name: start-build
description: Execute an approved plan step by step with TDD, with spec-compliance and code-quality review after each task. Use when you have an approved plan.md and want to implement the feature. Commits after each task.
category: sdlc
disable-model-invocation: true
---

# Build

## Overview

Walks through an approved plan, implementing one task at a time with red-green-refactor TDD, then verifying each task against the spec and project conventions before moving on. The goal is small, reviewable commits with evidence — not one giant PR you can't roll back.

The principle: **one vertical slice at a time, with evidence at every step.** If task N fails verification, you don't start task N+1 — you fix N or stop and report.

## Prerequisite

A plan must exist at `docs/sessions/<YYYY-MM-DD>-<slug>/plan.md` with status `approved` or `draft`. If no plan exists, run `/start-plan` first.

## When to Use

- A plan exists and the user says "build"
- After `/start-verify` found issues and they've been plan-updated — you're re-running build on the revised plan

**When NOT to use:**
- Exploratory coding with no plan — do the exploration first, then plan, then build
- Single-line fixes — just edit and commit
- Anything whose spec is still open

## The Process

### Step 0 — Read project conventions and load context

First, read `docs/skills/start-build.md` if present. Its contents are additional project guidance for this skill (commit message format, TDD strictness, off-limits code, preferred fixtures). Follow them alongside the defaults below.

If the file is missing or only contains the stub template, tell the user:

> No project conventions declared at `docs/skills/start-build.md`. Proceeding with built-in defaults. Run `/start-sync` to scaffold a stub if your team wants to capture conventions.

Then load context in this order:

1. The plan: `docs/sessions/<YYYY-MM-DD>-<slug>/plan.md`
2. The verification contract: `docs/sessions/<YYYY-MM-DD>-<slug>/verification.md` — authoritative definition of done for every task; name the artifact each task must produce
3. The spec: `docs/sessions/<YYYY-MM-DD>-<slug>/spec.md`
4. `docs/architecture/overview.md` — stack, core concepts, key files, architectural constraints
5. `docs/architecture/verification.md` — primitives the contract references; know how to produce each artifact before implementing

This is required even if the plan mentions these — the plan may reference patterns the spec adds context to, and the contract is the binding definition of done that downstream `/start-verify` will execute.

### Step 1 — Branch

If not already on a feature branch, create one:

```
git checkout -b <slug>
```

Never build on main/master unless the user explicitly insists.

### Step 2 — Pick the next task

From the plan, select the first task that is:
- status: not started
- all dependencies: complete

If multiple tasks are eligible and they're marked parallelizable, pick the smallest one first (reduces risk of early failure cascading).

If no task is eligible, you're done — jump to Step 8 (final verify).

### Step 3 — TDD for this task

Follow `/start-test` methodology inline. Short version:

**RED**: write the test(s) that encode this task's acceptance criteria.
- Run them. They must fail. If they pass, either the feature exists or the test is wrong.

**GREEN**: write the minimum code to pass.
- Run the test again. It must pass now.
- Run the full test suite. Must still pass.

**REFACTOR**: improve the code without changing behavior.
- Rename, dedupe, extract.
- Run the full suite after each refactor step.

Keep each loop small. If you wrote 100 lines of code before running tests, you've already lost — step back and write a test.

### Step 4 — Spec and contract self-check

Before considering the task done, verify it matches both the spec AND the contract:

1. Re-read the task's acceptance criteria.
2. For each AC, point to the exact test (by name) or code line that satisfies it.
3. If any AC doesn't have a satisfying test or code line, the task isn't done.
4. Re-read the contract item for this task in `docs/sessions/<session>/verification.md`. Can you produce the declared artifact right now with the declared commands? If no (missing fixture, service not starting, primitive not yet implemented), the task is not done — the contract item is the agreed definition of done.
5. **Actually produce the artifact once**: run the contract's commands, capture output to the declared `tmp/verify/` path, read it, and confirm it matches the expectation. This is your per-task smoke check; `/start-verify` will re-run the full contract at the end of the plan.

Do NOT invoke `/start-verify` yet — that's for the end of the whole plan. This is a lightweight self-check that catches contract/implementation drift task-by-task before it compounds.

### Step 5 — Code-quality self-check

Skim the diff:

- Does it only change what the task said it would change?
- Are there comments explaining things that would be obvious from reading the code? Remove them.
- Are there comments explaining *why* something non-obvious was done? Keep them.
- Did refactor introduce unrelated changes? Split them into a separate commit, or revert.
- Does the code match the project's existing patterns? (Imports, error handling, naming, test style)

If you find issues, fix before moving on.

### Step 6 — Commit

Stage only the files the task touched:

```
git add <specific files>
git commit -m "<type>: <task summary>

<optional body with evidence — test counts, key decisions>

Plan: docs/sessions/<session>/plan.md task N
Contract: docs/sessions/<session>/verification.md → tmp/verify/T<N>-<slug>.<ext>"
```

The Contract trailer points reviewers and `/start-verify` at the specific artifact this commit is responsible for producing. If a task has no contract artifact (pure refactor, doc change excluded from the contract), omit the Contract trailer and note "no-artifact task" in the body instead.

Commit types: `feat`, `fix`, `test`, `refactor`, `chore`, `docs`.

Do NOT push yet — push happens in `/start-ship`.

### Step 7 — Check checkpoints

If the plan has a checkpoint after this task:

1. Run the full test suite (not just the task's tests).
2. Check the checkpoint's verification step (e.g. "migration applies cleanly").
3. If the checkpoint fails, stop and report to the user. Don't proceed until the failure is understood.

### Step 8 — Final verification

After the last task:

1. Run the full test suite one more time.
2. Summarize what was built: N tasks, M commits, which files changed, which spec AC are satisfied, which contract items have a locally produced artifact.
3. Suggest next step:

> All N tasks in the plan are complete. Contract artifacts produced locally: `<list paths>`. Next: `/start-verify` to execute the full contract and produce the session verify report.

## Handling blockers

If during a task you discover:

- **The plan is wrong** (file doesn't exist, pattern doesn't apply): stop, report, ask whether to update the plan or abandon the task.
- **A test fails and the fix is non-obvious**: invoke `/start-debug` with the failure details. Don't try random fixes.
- **The spec is ambiguous**: stop, ask the user, record the answer in the spec's Open Questions (for traceability).
- **A task is bigger than it looked**: stop, suggest decomposing in the plan, ask before proceeding.

Never silently paper over a blocker. Surface it with specifics.

## Model selection per task

Use the least powerful model that can do the task reliably. Guidance:

- **Mechanical tasks** (one function, one file, clear spec): `haiku` or `sonnet` if you're forking to a subagent
- **Integration tasks** (multi-file, pattern matching, debugging): `sonnet`
- **Architecture/design tasks** (novel patterns, cross-cutting changes): `opus`

In practice, `/start-build` runs in your current session with whatever model is active. Use `/model` to switch if the plan has mixed-complexity tasks.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll write the test after, this is obvious" | The test catches the invisible assumption. "Obvious" is how bugs ship. |
| "Let me batch these 3 tasks into one commit" | Batched commits can't be reviewed or reverted atomically. One task = one commit. |
| "The plan says X but I found a better way" | Update the plan first, then build to the new plan. "Better way" without updating is improvisation that nobody else can follow. |
| "Full suite is slow, I'll skip it this commit" | Skipped suites hide regressions that explode later. Always run the full suite. |
| "This refactor is unrelated but while I'm here…" | Unrelated refactors belong in separate commits or separate tasks. Mixed diffs are hard to review. |
| "I'll push at the end, not commit per task" | Commits are save points. One giant commit at the end = no rollback. |
| "Tests pass, so I'm done" | `/start-verify` checks spec compliance. Tests only check the tests you wrote. |

## Red Flags

- Writing 50+ lines of production code before running any test
- Committing with the message "WIP" or "fix" (no task reference)
- Editing files the task didn't list as affected (unless you update the plan first)
- Silencing or skipping tests to make the suite pass
- Running `git add -A` without reviewing what's being staged
- Pushing during `/start-build` (that's `/start-ship`'s job)
- Claiming a task is done without pointing to the test that proves each AC
- Committing a task without producing its contract artifact at least once locally
- Omitting the Contract trailer on a commit whose task has an artifact declared in `verification.md`
- Diverging from the contract (different artifact path, weaker expectation) without a visible `verification.md` amendment committed alongside the code

## Verification

After each task:

- [ ] RED test existed and failed before the code was written
- [ ] GREEN test passes now
- [ ] Full test suite passes
- [ ] Task's AC all satisfied (point to test name or code line for each)
- [ ] Task's contract item artifact can be produced locally and matches the declared expectation
- [ ] Diff only touches planned files
- [ ] Commit message references the plan and task number, and (for tasks with artifacts) the contract and artifact path

After the whole plan:

- [ ] Every task committed individually
- [ ] Full suite green
- [ ] Every contract artifact is producible locally (full contract execution is `/start-verify`'s job)
- [ ] Next step suggested: `/start-verify`
