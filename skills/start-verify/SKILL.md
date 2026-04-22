---
name: start-verify
description: Verify a completed deliverable against its spec before shipping. Runs a deterministic gate plus multiple parallel review passes. Use before /start-ship or at any point you're claiming something is done. Verifies artifacts, not claims.
category: sdlc
disable-model-invocation: true
---

# Verify

## Overview

Runs the checks that separate "tests pass" from "this is actually done." A deterministic gate first (compile, lint, run tests, grep for anti-patterns), then parallel verification passes in an isolated subagent. The agent that built the code never grades its own homework.

The principle: **verify artifacts, not claims.** "All tests pass" is a claim. Test output, a green build, a working sandbox deployment — those are artifacts.

## Prerequisite

A session directory with a spec + plan exists at `docs/sessions/<YYYY-MM-DD>-<slug>/`. If you're verifying without a plan, flag that — verification without a spec to verify against is just "does it run".

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

Runs in three phases: deterministic gate → parallel review → aggregate. Phases 2 and 3 fork to a subagent for isolation.

### Phase 1 — Deterministic gate (main context)

Zero ambiguity — commands either pass or fail. No agent can override.

Run in order and stop on the first failure:

1. **Import / compile check** — project-specific (`python -c "import <pkg>"`, `tsc --noEmit`, `cargo check`, `go build ./...`)
2. **Lint / format check** — per project convention (`ruff check`, `eslint`, `rustfmt --check`, etc.)
3. **Type check** — if separate from compile (`mypy`, `tsc`, `pyright`)
4. **Unit test suite** — full suite, not just new tests
5. **Integration test suite** — if the project has one
6. **Anti-pattern grep** — run these always:

   ```
   # On the diff vs main:
   git diff main...HEAD | grep -n "TODO\|FIXME\|XXX"    # incomplete work
   git diff main...HEAD | grep -n "/Users/\|/home/"      # hardcoded paths
   git diff main...HEAD | grep -niE "api[_-]?key|secret|password" # secrets
   git diff main...HEAD | grep -n "console\.log\|pdb\.set_trace\|debugger;"  # debug artifacts
   ```

7. **Secrets scan** — if available (`gitleaks detect`, `trufflehog`, etc.)

If any gate fails, stop. Report the failure and suggest running `/start-debug`. Do NOT proceed to Phase 2 — agent passes on broken code waste tokens.

### Phase 2 — Parallel review (forked subagent)

Fork a `general-purpose` subagent. Give it the verification checklist and these inputs:

- `docs/sessions/<session>/spec.md`
- `docs/sessions/<session>/plan.md`
- `git diff main...HEAD` (or the full change if no main)
- `docs/architecture/overview.md`
- `CLAUDE.md` if present in the project root

Ask the subagent to run four passes in parallel and return a structured report:

1. **Spec compliance** — every acceptance criterion in the spec, checked against the actual code and tests
2. **Codebase consistency** — patterns, naming, error handling, imports, test style
3. **Data integrity and boundaries** — field-by-field, type conversions, null handling, validation at edges
4. **Self-check** — adversarially review passes 1-3, filter false positives, surface anything they missed

See [verification-checklist.md](references/verification-checklist.md) for the full checklist.

### Phase 3 — Aggregate and score

Subagent returns findings by severity:

- **CRITICAL** — will cause data loss, security breach, or system failure
- **HIGH** — incorrect behavior users/agents will notice
- **MEDIUM** — works but inconsistent, fragile, or incomplete
- **LOW** — style, naming, minor improvements
- **PASS** — verified correct

Score: `100 − (25 × CRITICAL) − (15 × HIGH) − (5 × MEDIUM)`

Verdict:
- **PASS (90+)** — ready to ship
- **PASS_WITH_CONCERNS (70-89)** — minor fixes recommended before ship
- **NEEDS_FIXES (50-69)** — must fix before ship
- **FAIL (<50)** — significant gaps; may need to re-plan

### Phase 4 — Write the report

Save to `docs/sessions/<session>/verify.md`:

```markdown
# Verify report — <session>

**Score**: N
**Verdict**: PASS | PASS_WITH_CONCERNS | NEEDS_FIXES | FAIL
**Deterministic gate**: passed | failed at step N
**Timestamp**: <ISO 8601>

## Summary

<one paragraph: what was verified, what was found>

## Findings

### CRITICAL
- [<path:line>] <description>. <recommended fix>

### HIGH
- ...

### MEDIUM
- ...

### LOW
- ...

### PASS (verified working)
- <assertion>: <evidence>

## Recommended action

- PASS: `/start-ship`
- PASS_WITH_CONCERNS: fix listed items or accept risk; then `/start-ship`
- NEEDS_FIXES: update the plan with the fixes, re-run `/start-build`, then `/start-verify` again
- FAIL: return to `/start-plan` — the approach is wrong
```

### Phase 5 — Report to user

Show the user the verdict prominently, followed by CRITICAL and HIGH items with file:line refs. Suggest the specific next step based on verdict.

## Runtime / sandbox verification (optional but recommended for infra changes)

Unit and integration tests don't catch everything. For changes that touch infrastructure, deployment, or external integrations, add a runtime pass:

- If a PR environment exists: fork a subagent that makes real calls against it (HTTP, DB, queue) and verifies the behavior end-to-end
- If the change is IaC: verify resources exist with expected configuration via the cloud provider's CLI
- Write the verification script to `docs/sessions/<session>/start-verify-runtime.<ext>` so it's re-runnable

Include runtime results in the main verify report under a separate section.

## Iteration cap

If `verify.md` already exists in this session, check the iteration count. After 3 verify rounds, diminishing returns sets in. Surface to the user:

> This is the 3rd verify iteration. Further rounds often produce the same findings.
> Consider either accepting remaining concerns or returning to `/start-plan` to revise the
> approach.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Tests pass, so it's done" | Tests check the tests you wrote. Spec compliance checks what you should have built. Different checks. |
| "CI already runs the deterministic gate, skip Phase 1" | CI catches what CI is configured to catch. Local re-run surfaces issues fast. |
| "I wrote it, I know it's right" | Authors are blind to their own assumptions. That's why Phase 2 forks to a fresh context. |
| "No critical findings = ship" | Verdict is a score, not a count. A pile of mediums is still debt. |
| "This finding is a false positive" | Verify it IS false before dismissing. The reviewer's other findings stop being credible the moment you accept unverified dismissals. |
| "Runtime verification is overkill" | Unit tests miss deployment issues. For anything that touches infra, runtime verification is the only artifact that proves it works. |
| "I can skip the self-check pass" | Self-check removes false positives and catches what the focused passes missed. Skipping it inflates findings and wastes fix cycles. |
| "I'll fix the mediums later" | "Later" is a bucket that fills and never empties. Fix or explicitly defer with a ticket. |

## Red Flags

- Claiming verify passed without running the deterministic gate
- Running verify in the same agent that did the build (no isolation)
- Reporting PASS when deterministic gate failed
- Dismissing a CRITICAL finding without evidence it's wrong
- Running verify before the full test suite is green
- Verify report that only lists what passed, not what was found
- Skipping runtime verification for infra changes because "unit tests pass"
- Changing the score formula because the number looked bad

## Verification (of verify itself)

Before closing out:

- [ ] Deterministic gate ran to completion
- [ ] Phase 2 subagent forked to isolated context
- [ ] All four passes (spec, consistency, integrity, self-check) completed
- [ ] `verify.md` saved with score, verdict, findings, recommended action
- [ ] User shown the verdict and at least the CRITICAL/HIGH findings
- [ ] Next step recommended based on verdict
