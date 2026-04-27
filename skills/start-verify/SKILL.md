---
name: start-verify
description: Execute the plan's verification.md contract end-to-end — gates, task artifacts, cross-task assertions — and fork a review pass over the captured evidence. Use before /start-ship or any time you're claiming something is done. Verifies artifacts, not claims. Requires a contract authored by /start-plan.
category: sdlc
disable-model-invocation: true
---

# Verify

## Overview

Executes the plan's verification contract (`docs/sessions/<session>/verification.md`) item by item. Gates, task artifacts, cross-task assertions — every item runs, every artifact is captured under `tmp/verify/`, every outcome compared to the declared expectation. A forked subagent then reviews the evidence for issues the contract did not cover. The agent that built the code never grades its own homework.

The principle: **verify artifacts, not claims.** "All tests pass" is a claim. The contract names the artifacts that would prove the claim; this skill produces them, records them, and lets the user inspect them.

## Hard gate

```
Do NOT execute any check that is not declared in the plan's verification.md contract.
Do NOT mark any contract item "skipped" or "not applicable" unless it appears under the
contract's `## Declared exclusions` with a written rationale. There is no silent default,
no commit-message skip, and no verdict of PASS against a partial run.
```

## Prerequisite

The session directory at `docs/sessions/<YYYY-MM-DD>-<slug>/` must contain all three of:

- `spec.md` — what was being built
- `plan.md` — how it was broken down
- `verification.md` — the contract `/start-verify` executes

If any is missing, `/start-verify` refuses to run. Tell the user exactly which file is missing and what to run to produce it (`/start-spec`, `/start-plan`). Do not improvise checks against an absent contract.

Similarly refuse if `docs/architecture/verification.md` is missing, still contains template placeholders, or has `<unknown>` markers for primitives the contract references. Running against unfilled primitives is running against claims, not artifacts.

## When to Use

- Before calling a deliverable done
- Before running `/start-ship`
- After `/start-build` completes all tasks
- When re-verifying after fixes from a previous verify round
- When you want evidence — not just intuition — that something works

**When NOT to use:**
- Mid-implementation (that's `/start-test` territory)
- Early exploration / spikes (nothing to verify against yet)
- Trivial changes where the deterministic gate alone is enough

## The Process

Runs in six phases driven by the plan's contract. Phases 3 and 4 fork to a subagent for isolation.

### Phase 0 — Read project conventions, load the contract, resolve the runtime

First, read `docs/skills/start-verify.md` if present. Its contents are additional project guidance for this skill (extra review axes, severity tuning, verdict thresholds, mandatory post-runtime checks). Layer them on the defaults below — they do NOT replace the contract or primitives.

If the file is missing or only contains the stub template, tell the user:

> No project conventions declared at `docs/skills/start-verify.md`. Proceeding with built-in defaults. Run `/start-sync` to scaffold a stub if your team wants to capture conventions.

Then read the plan's `verification.md` and the project's `docs/architecture/verification.md`.

1. **Runtime selection**: read the contract's `## Runtime selection`. If the stanza is absent, stop and report — a contract without explicit runtime selection is a silent default, which this skill refuses.
2. **Runtime resolution**: find the matching `### Runtime: <name>` block in `docs/architecture/verification.md`. If no match, stop — the contract references a runtime that doesn't exist. Do NOT fall back to `local` or any other runtime.
3. **Primitive scoping**: every runtime primitive (`start`, `ready-check`, `teardown`, `invoke`, `inspect`, `precondition`) resolves against the selected runtime's block only. Gates (`compile`, `lint`, etc.) are project-level and resolve against the top-level `## Gate primitives` section regardless of runtime.
4. **Precondition gate**: run the selected runtime's `precondition` (if declared and not `none`). A non-zero exit stops the iteration with a clear, actionable message (e.g. "no PR open for runtime `pr-preview`; open a PR or switch the contract to `local`"). A failing precondition is not a FAIL in the report — it's a refusal to start, because the environment isn't ready for what the contract asked.
5. **Command existence check**: resolve every other command the contract will execute (gates, task artifacts, cross-task assertions). If any is undefined or the backing binary is not installed, stop and report — the contract has drifted from the primitives library or the local environment violates `## Declared assumptions`.

Create `tmp/verify/` if it does not exist (gitignored via the bootstrap template). Iteration N's artifacts land under `tmp/verify/` with names that include the iteration number to avoid overwriting earlier runs.

### Phase 1 — Execute gates and cross-task assertions

For each item under the contract's `## Gates` section, run the resolved command. Capture stdout AND stderr to `tmp/verify/<iter>-gate-<name>.log`. Stop on first non-zero exit.

Then run every item under `## Cross-task assertions`. Capture output per assertion to `tmp/verify/<iter>-xta-<name>.log`. An anti-pattern grep returning non-empty is a failure; log the matching lines.

If any gate OR any cross-task assertion fails, stop. Record the failure (with the log path) for the report and suggest `/start-debug` to the user. Do NOT proceed to Phase 2 or Phase 3 — running review passes over broken code produces noise.

### Phase 2 — Produce every task artifact

For each item under the contract's `## Task artifacts`:

1. If the selected runtime's `start` is a real command (not `not applicable`) and this is the first runtime-requiring artifact this iteration, run `start`. Poll `ready-check` until exit 0 or timeout. A timeout is ERROR for every runtime artifact. If `start` is `not applicable` (the runtime is managed externally — e.g. `pr-preview` provisioned by CI), skip `start` and run `ready-check` directly; a failing `ready-check` is ERROR.
2. Run the artifact's production steps (resolved against the selected runtime's primitives or literal commands in the contract). Capture the artifact to its declared path under `tmp/verify/`.
3. Compare the artifact to the declared expectation. Record PASS, FAIL (with the specific mismatch), or ERROR (execution failed before the artifact could be produced).
4. After the last task artifact, run the selected runtime's `teardown` if it's a real command (not `not applicable`) — even on failure. Teardown's exit code does not affect the verdict.

**Do not skip a task artifact because "looks unchanged since last iteration."** Every iteration re-runs the full contract; skipping is silent default.

**If a task artifact is under `## Declared exclusions`**, it is not run this iteration. Record `EXCLUDED` with a pointer to the exclusion's rationale. Exclusions declared at plan time are the only form of skip allowed.

### Phase 3 — Review passes (forked subagent)

Fork a `general-purpose` subagent. Give it these inputs:

- `docs/sessions/<session>/spec.md`
- `docs/sessions/<session>/plan.md`
- `docs/sessions/<session>/verification.md` (the contract)
- The Phase 1 and Phase 2 artifacts under `tmp/verify/` (by path; subagent reads them)
- `git diff main...HEAD` (or the full change if no main)
- `docs/architecture/overview.md`
- `docs/architecture/verification.md`
- `CLAUDE.md` if present in the project root

Ask the subagent to run four passes in parallel and return a structured report:

1. **Contract coverage** — every contract item was executed; every spec AC maps to a contract item that passed or to a declared exclusion. **Produce an explicit trace table** mapping each `plan.md` acceptance criterion (per-task ACs and the plan-level `## Acceptance (for the whole plan)` checklist) to the contract item that backs it and that item's verify result. Flag any plan AC that has no traceable contract item — that's a coverage gap from planning, not an implementation defect; surface it in Review findings under HIGH so the verdict reflects it.
2. **Codebase consistency** — patterns, naming, error handling, imports, test style
3. **Data integrity and boundaries** — field-by-field, type conversions, null handling, validation at edges
4. **Self-check** — adversarially review passes 1-3, filter false positives, surface anything they missed

See [verification-checklist.md](references/verification-checklist.md) for the full checklist.

### Phase 4 — Aggregate and score

Contract-driven verdict is primary; review findings are secondary and cannot override a contract failure.

**Contract state**:

- All items PASS (or EXCLUDED with rationale): contract passes
- Any FAIL: contract fails
- Any ERROR: contract errored

**Review findings** (from Phase 3), by severity:

- **CRITICAL** — will cause data loss, security breach, or system failure
- **HIGH** — incorrect behavior users/agents will notice
- **MEDIUM** — works but inconsistent, fragile, or incomplete
- **LOW** — style, naming, minor improvements

**Review score**: `100 − (25 × CRITICAL) − (15 × HIGH) − (5 × MEDIUM)`

**Final verdict**:

| Contract state | Review score | Verdict |
|---|---|---|
| All pass | ≥ 90 | **PASS** — ready to ship |
| All pass | 70-89 | **PASS_WITH_CONCERNS** — fix recommended |
| All pass | 50-69 | **NEEDS_FIXES** — address review findings |
| Any FAIL | any | **NEEDS_FIXES** at best — fix contract failures first |
| Any ERROR | any | **FAIL** — primitives, environment, or plan is wrong |

### Phase 5 — Append the iteration to the verify report

Write or append to `docs/sessions/<session>/verify.md`. **Append — do not overwrite.** Each iteration is a new `## Iteration N — <ISO timestamp>` section so the history is visible.

```markdown
## Iteration N — <ISO 8601 timestamp>

**Contract**: `docs/sessions/<session>/verification.md`
**Runtime**: <name from the contract's ## Runtime selection>
**Verdict**: PASS | PASS_WITH_CONCERNS | NEEDS_FIXES | FAIL
**Review score**: M
**Contract state**: all pass | <n> FAIL | <n> ERROR | <n> EXCLUDED

### Gates
- [✓] `compile` — `tmp/verify/<iter>-gate-compile.log` exit 0
- [✗] `integration` — `tmp/verify/<iter>-gate-integration.log` exit 1; tests `a::b` and `c::d` failed (log line 47-89)

### Task artifacts
- [✓] T1 — `tmp/verify/T1-schema-diff.txt` matches expectation (line 12)
- [✗] T3 — `tmp/verify/T3-endpoint-replay.json` returned 500, expected 400; see log
- [–] T5 — EXCLUDED: feature flag off in this environment (see contract §Declared exclusions)

### Cross-task assertions
- [✓] no debug artifacts — grep returned empty
- [✓] no secrets — grep returned empty

### Plan acceptance signoff

Trace from `plan.md` ACs → contract items → verify results. This is the explicit closing of the loop the contract was authored to back.

| Plan AC (location)                        | Contract item                | Verify |
|---|---|---|
| Task 2: returns 401 on bad token          | T2-auth-401                  | ✓ |
| Task 5: idempotent retry                  | T5-retry-idem                | ✗ (see Task artifacts) |
| Plan §Acceptance: full test suite passes  | gate.unit + gate.integration | ✓ |
| Plan §Acceptance: /start-verify PASS      | (this iteration)             | ✓ |

If any plan AC has no traceable contract item, list it under "Coverage gaps" instead of in this table:

#### Coverage gaps (plan ACs without contract backing)
- Task 7: handles malformed UTF-8 — no contract item written. Filed as HIGH review finding; either add a contract item and re-run or declare an explicit exclusion in `verification.md`.

### Review findings

#### CRITICAL
- [<path:line>] <description>. <recommended fix>

#### HIGH
- ...

#### MEDIUM
- ...

#### LOW
- ...

### Recommended action
- PASS: `/start-ship`
- PASS_WITH_CONCERNS: fix listed items or accept risk; then `/start-ship`
- NEEDS_FIXES: update the plan (and possibly the contract) with the fixes, re-run `/start-build`, then `/start-verify`
- FAIL: return to `/start-plan` — the approach is wrong
```

Never edit a previous iteration's content. If a finding from iteration N-1 was resolved, iteration N simply does not list it.

### Phase 6 — Report to user

Show the user the verdict prominently, followed by:

- Which contract items FAILed or ERRORed (if any) with their artifact paths
- CRITICAL and HIGH review findings with file:line refs
- The recommended next step based on the verdict

## Iteration cap

If `verify.md` already exists in this session, check the iteration count. After 3 verify rounds, diminishing returns sets in. Surface to the user:

> This is the 3rd verify iteration. Further rounds often produce the same findings.
> Consider either accepting remaining concerns or returning to `/start-plan` to revise the
> approach.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Tests pass, so it's done" | Tests check the tests you wrote. Contract execution checks what you should have built. Different checks. |
| "CI already runs the gates, skip Phase 1" | CI catches what CI is configured to catch. The contract is the agreed check set for THIS plan; run it here regardless. |
| "I wrote it, I know it's right" | Authors are blind to their own assumptions. That's why Phase 3 forks to a fresh context. |
| "No critical findings = ship" | Verdict reflects contract state AND review score. A pile of mediums is still debt. Any contract FAIL caps the verdict regardless of review. |
| "This finding is a false positive" | Verify it IS false before dismissing. The reviewer's other findings stop being credible the moment you accept unverified dismissals. |
| "Runtime verification is overkill for this change" | The contract decides whether runtime applies. If it does and you skip it, the verdict is FAIL. If it shouldn't apply, the contract should have excluded it explicitly during planning. |
| "I can skip the self-check pass" | Self-check removes false positives and catches what the focused passes missed. Skipping it inflates findings and wastes fix cycles. |
| "I'll fix the mediums later" | "Later" is a bucket that fills and never empties. Fix or explicitly defer with a ticket. |
| "The contract item is impractical here, skip it" | The contract was approved alongside the plan. Skipping here is silent default. Amend the contract explicitly (and re-approve via a diff) before skipping anything. |
| "I'll check what I think matters, not the contract" | What you think matters is a claim. The contract is the artifact of agreement. Execute the contract and capture evidence first. |
| "Contract FAIL + clean review = PASS_WITH_CONCERNS" | No. Any contract FAIL caps the verdict at NEEDS_FIXES. Review findings cannot override contract failures — the contract is the primary truth. |
| "Overwrite the previous iteration, it's cleaner" | Overwriting destroys the record of what changed between attempts. Append every iteration; history is how you see whether the fix actually fixed. |

## Red Flags

- Claiming verify passed without executing every contract item
- Running verify in the same agent that did the build (no isolation for Phase 3)
- Reporting PASS when any contract item is FAIL or ERROR
- Dismissing a CRITICAL finding without evidence it's wrong
- Running verify before the full test suite is green
- Verify report that only lists what passed, not what was found
- Executing a check that is not declared in the contract, or skipping one that is
- Treating a local environment mismatch as EXCLUDED — that's a FAIL with a clear fix path
- Overwriting a prior iteration in `verify.md` instead of appending a new one
- Inventing a primitive at verify time rather than amending `docs/architecture/verification.md` in planning
- Declaring a contract exclusion during verify rather than in the plan
- Proceeding without running the selected runtime's `precondition`, or treating a failing `precondition` as a contract FAIL (it's a refusal to start, not a test result)
- Mixing runtimes mid-iteration (e.g. starting `local` then invoking against `pr-preview`) — each iteration uses exactly one runtime

## Verification (of verify itself)

Before closing out:

- [ ] Contract's `## Runtime selection` was resolved to an existing `### Runtime: <name>` block; the selected runtime's `precondition` passed (or was `none`)
- [ ] Contract file exists and every primitive it references resolves to a definition in `docs/architecture/verification.md` under the selected runtime
- [ ] Phase 1 ran every gate and every cross-task assertion; each has a log path recorded
- [ ] Phase 2 produced every task artifact under `tmp/verify/` (or recorded FAIL / ERROR / EXCLUDED with rationale)
- [ ] Phase 3 subagent forked to isolated context, with the contract and artifacts in its inputs
- [ ] All four review passes (contract coverage, consistency, integrity, self-check) completed
- [ ] Plan-AC → contract-item trace table produced; any plan AC without contract backing surfaced as a HIGH coverage-gap finding
- [ ] `verify.md` appended — not overwritten — with a new `## Iteration N` section, including a `### Plan acceptance signoff` table
- [ ] Every path cited in the report exists under `tmp/verify/`
- [ ] Verdict reflects contract state (any FAIL caps at NEEDS_FIXES; any ERROR caps at FAIL)
- [ ] User shown the verdict, contract failures (if any) with artifact paths, and CRITICAL/HIGH review findings
- [ ] Next step recommended based on verdict
