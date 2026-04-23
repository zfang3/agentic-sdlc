# Verification Contract Template

Use this template for every session's verification contract. `/start-plan` produces one of these as a sibling to `plan.md`; `/start-verify` executes it item by item.

**Location**: `docs/sessions/<YYYY-MM-DD>-<slug>/verification.md`

**Rules**:

1. Every item in the contract must be executable without human interpretation. If an agent can't mechanically run it and compare output to an expectation, rewrite it.
2. Every primitive referenced (`compile`, `lint`, `start`, `invoke`, etc.) must resolve to a definition in `docs/architecture/verification.md`. If a needed primitive is missing there, add it first — do not inline it here.
3. `## Runtime selection` must always be explicit. The named runtime must match a `### Runtime: <name>` block in `docs/architecture/verification.md`. If a needed runtime is missing there, add it first — do not inline a new runtime here.
4. Nothing may be silently skipped. Anything intentionally omitted goes under `## Declared exclusions` with a rationale.
5. The contract is approved alongside the plan. Once approved, it is immutable for this session — if reality changes, amend the plan and the contract together in a visible diff, then re-approve.

```markdown
# Verification contract: <feature or ticket title>

**Session**: `<YYYY-MM-DD>-<slug>`
**Spec**: `docs/sessions/<YYYY-MM-DD>-<slug>/spec.md`
**Plan**: `docs/sessions/<YYYY-MM-DD>-<slug>/plan.md`
**Primitives**: `docs/architecture/verification.md`
**Status**: draft | approved

## Scope

<one or two sentences: what this contract covers — which plan tasks it verifies, which spec acceptance criteria it enforces>

Covers tasks: T1 (<short name>), T2 (<short name>), ...
Covers spec AC: all of them | AC 1, 2, 4 (AC 3 deferred — see Declared exclusions)

## Runtime selection

**Runtime**: <exact name of one runtime from `docs/architecture/verification.md`, e.g. `local` or `pr-preview`>
**Rationale**: <one sentence — why this runtime for this change; e.g. "local is sufficient; no third-party integrations" or "pr-preview required: uses real S3 credentials the local stack cannot simulate">

*Always state the runtime explicitly — even when it is the project default. "The usual one" is a silent default.*

## Gates

Run in order; stop on first non-zero exit. Every gate listed here must pass before the runtime stage is attempted.

- [ ] `compile` — <primitive name from verification.md, or exact command if project-wide primitive is insufficient>
- [ ] `lint` — ...
- [ ] `typecheck` — ...
- [ ] `unit` — ...
- [ ] `integration` — ...

## Task artifacts

For each task in the plan that produces observable behavior, name the artifact that proves it works. Cite the task ID from `plan.md`.

### T<N> — <task title>

- **Produces**: `tmp/verify/T<N>-<slug>.<ext>`
- **How**: <exact command sequence, or named primitive + parameters>
  - e.g. `start` → `invoke URL=http://localhost:8080/<path> OUT_PATH=tmp/verify/T<N>-<slug>.json` → `teardown`
- **Expect**:
  - <concrete, mechanically checkable assertion about the artifact, e.g. "HTTP status 200", "JSON body contains `\"status\": \"ok\"`", "file size > 0 and < 10KB">
  - <additional assertion>
- **On failure**: <optional guidance — link to debug playbook, common causes>

### T<N+1> — ...

*(repeat for every task in the plan)*

## Cross-task assertions

Invariants that span multiple tasks or the whole diff. `/start-verify` checks these after the per-task artifacts.

- [ ] No debug artifacts: `git diff main...HEAD | grep -nE "console\.log|pdb\.set_trace|debugger;"` returns empty
- [ ] No unresolved markers: `git diff main...HEAD | grep -nE "TODO|FIXME|XXX"` returns empty (or each occurrence is accounted for in Declared exclusions)
- [ ] No hardcoded secrets: `git diff main...HEAD | grep -niE "api[_-]?key|secret|password"` returns empty
- [ ] <any spec-level invariant, e.g. "every new public endpoint is authenticated">

## Declared exclusions

*Anything intentionally omitted from verification. Each entry must have a written rationale; an empty rationale is a red flag.*

- **<thing excluded>** — <why: e.g. "docs-only change, no gates apply"; "feature flag off in this environment so runtime path cannot be exercised"; "covered by CI job X, duplicating locally adds no signal">

*If this section is empty, state it explicitly: `None — every contract item is enforced.`*

## Approval

- [ ] `## Runtime selection` names a runtime defined in `docs/architecture/verification.md` with a written rationale
- [ ] Spec acceptance criteria map 1:1 to contract items (or are listed under Declared exclusions)
- [ ] Every gate and task artifact references a primitive defined under the selected runtime in `docs/architecture/verification.md`
- [ ] No placeholder, `TBD`, `<...>`, or "to be decided during build"
- [ ] User has approved alongside `plan.md`
```
