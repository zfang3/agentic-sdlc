# Plan Template

Use this template for every plan produced by `/start-plan`.

```markdown
# Plan: <feature or ticket title>

**Session**: `<YYYY-MM-DD>-<slug>`
**Spec**: `docs/sessions/<YYYY-MM-DD>-<slug>/spec.md`
**Verification contract**: `docs/sessions/<YYYY-MM-DD>-<slug>/verification.md` (sibling; authored alongside this plan)
**Status**: draft | approved | in-progress | complete

## Summary

<2-3 sentences: what this plan accomplishes and why>

## Context gathered

- **Docs read**: <list with paths>
- **Code analyzed**: <key files/modules with line ranges>
- **Related systems**: <any cross-repo or external references>

## Affected files

| File | Change | Description |
|------|--------|-------------|
| `path/to/file.ext` | new | <what this new file does> |
| `path/to/existing.ext` | modify | <what changes and why> |
| `path/to/start-tests/start-test_x.ext` | new | <test coverage added> |

## Dependency graph

```
<text sketch of task dependencies>

Example:
[T1: Migration] → [T2: Model] → [T3: Service] → [T4: Handler] → [T5: Tests]
                       ↘ [T6: Fixture]  ↗
```

## Tasks

### Task 1: <short title>

**Summary**: <one sentence>

**Files**:
- `path/file.ext` (new)
- `path/start-tests/start-test.ext` (new)

**Acceptance criteria** (from spec):
- [ ] <testable statement>
- [ ] <testable statement>

**Steps**:
1. <exact action>
2. <exact action>

**Verify**:
```
<command that proves the task works>
```

**Dependencies**: none

**Size**: XS | S | M | L

---

### Task 2: ...

(repeat)

---

## Checkpoints

- After Task 3: <what to verify before proceeding>
- After Task 6: <what to verify before proceeding>
- Final: `/start-verify` against the full spec

## Edge cases and risks

- <discovered during research; file:line references where possible>
- <discovered during research>

## Test plan

- **Unit tests**: <what to test, which test file, patterns to follow>
- **Integration tests**: <if applicable>
- **Manual verification**: <if applicable>

## Parallelism

- Tasks <N> and <M> are independent and can run concurrently.
- Tasks <X>, <Y>, <Z> must run in order due to <dependency>.

## Open questions

- <anything unresolved; list what was checked to try to resolve it>

## Acceptance (for the whole plan)

- [ ] Every spec AC is covered by at least one task's AC
- [ ] Every task has a Verify command
- [ ] Verification contract (`verification.md`) authored and approved alongside this plan
- [ ] Every task with observable behavior maps to a contract item
- [ ] Every spec AC traces to a contract item or a declared exclusion
- [ ] Full test suite passes after final task
- [ ] `/start-verify` executes the contract end-to-end with a PASS verdict
```
