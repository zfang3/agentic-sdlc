---
name: start-test
description: Drive development with tests — write a failing test first, implement, watch it pass. Use when implementing any logic, fixing any bug, or changing any behavior. NOT for config-only changes with no behavioral impact.
category: sdlc
---

# Test

## Iron law

```
NEVER WRITE PRODUCTION CODE WITHOUT A FAILING TEST FIRST.
This is not optional. This is not negotiable.
```

The test encodes the intent. Writing code first means building something and then checking if it's what was asked — which is how spec deviations happen.

## When to Use

- Implementing any new logic or behavior
- Fixing any bug — write a test that reproduces it first (the Prove-It pattern)
- Modifying existing functionality where behavior could shift
- Adding edge-case handling
- Any change that could break existing behavior

**When NOT to use:**
- Pure configuration changes with no behavioral impact (e.g. bumping a timeout from 30s to 60s where tests don't assert on the value)
- Documentation-only changes
- Static content changes (README, license)

If you're unsure, err toward writing a test.

## The Process

### Step 0 — Read project conventions

Read `docs/skills/start-test.md` if present. Its contents are additional project guidance for this skill (preferred frameworks, fixture conventions, naming convention, coverage thresholds, mock vs real policies). Follow them alongside the defaults below.

If the file is missing or only contains the stub template, tell the user:

> No project conventions declared at `docs/skills/start-test.md`. Proceeding with built-in defaults. Run `/start-sync` to scaffold a stub if your team wants to capture conventions.

Then proceed to the RED → GREEN → REFACTOR cycle.

### RED — write a failing test

Derive the test from a spec's acceptance criterion. One AC, one test (sometimes more, never fewer).

```
# Write the test
# Run it. It MUST fail.
<test-command> -k <test-name>
# Expected: FAILED (function doesn't exist yet, or returns wrong value)
```

**Good RED test**:
- Asserts specific behavior from the spec
- Self-contained (reader understands it without tracing through helpers)
- Fails for a named reason

**Bad RED test**:
- Passes on the first run (either the feature exists, or the test is wrong)
- Asserts vague things like "result is not null"
- Tests implementation details instead of observable behavior

Rules:

- Test must fail before production code is written. If it passes, something is wrong.
- Test asserts BEHAVIOR, not implementation. Don't mock your way into asserting the call sequence.
- One test per acceptance criterion. Don't bundle multiple ACs into one test.
- Use existing fixtures when possible. Create new ones only when needed.

### GREEN — minimum code to pass

Write the minimum production code that makes the failing test pass. Not the elegant version. Not the complete version. The minimum.

```
<test-command> -k <test-name>
# Expected: PASSED
```

Rules:

- Change ONLY what's needed to pass the RED test.
- Don't add features, helpers, or abstractions "while you're here."
- Don't refactor during GREEN. That's next.
- If the test still fails, fix the code — don't weaken the test.

### REFACTOR — clean up, keep green

With the test passing, improve the code without changing behavior.

```
<test-command>       # full suite — everything must still pass
```

Rules:

- Tests MUST stay green. If a test breaks, your refactor changed behavior.
- Extract shared logic, improve names, remove duplication.
- Don't add new behavior during refactor — that's a new RED test.

### Repeat

Next acceptance criterion → next RED → GREEN → REFACTOR.

## The Prove-It pattern (bug fixes)

When a bug is reported, DO NOT start with the fix. Start with a test that reproduces it.

```
Bug reported
     │
     ▼
Write a test that demonstrates the bug
     │
     ▼
Run it. Test FAILS — bug confirmed.
     │
     ▼
Implement the fix.
     │
     ▼
Run it. Test PASSES — fix verified.
     │
     ▼
Run the full suite. No regressions.
```

Without the failing test, you can't verify the fix actually addresses the bug. You might fix a different issue that looks similar and declare victory on the original.

## The test pyramid

Invest testing effort according to layer. Most tests small and fast:

```
          ╱╲
         ╱  ╲          E2E (~5%)
        ╱    ╲         Full user flows, real browser
       ╱──────╲
      ╱        ╲       Integration (~15%)
     ╱          ╲      Component interactions, API boundaries
    ╱────────────╲
   ╱              ╲    Unit (~80%)
  ╱                ╲   Pure logic, isolated, milliseconds
 ╱──────────────────╲
```

### Test size by resource use

| Size | Constraint | Speed | Examples |
|---|---|---|---|
| Small | Single process, no I/O | ms | Pure functions, data transforms |
| Medium | localhost only, test DB OK | seconds | API tests, component tests |
| Large | External services allowed | minutes | E2E, staging integration |

Small tests should be the vast majority. They're fast, reliable, and easy to debug.

### Decision guide

```
Pure logic, no side effects?
  → Unit (small)

Crosses a boundary (API, DB, filesystem)?
  → Integration (medium)

Critical user flow that must work end-to-end?
  → E2E (large; limit to critical paths)
```

## Writing good tests

### Test behavior, not implementation

```
# Good: tests what the function does
it('returns tasks sorted by creation date, newest first', async () => {
  const tasks = await listTasks({ sortBy: 'createdAt', sortOrder: 'desc' });
  expect(tasks[0].createdAt.getTime()).toBeGreaterThan(tasks[1].createdAt.getTime());
});

# Bad: tests how the function works internally
it('calls db.query with ORDER BY created_at DESC', async () => {
  await listTasks(...);
  expect(db.query).toHaveBeenCalledWith(expect.stringContaining('ORDER BY'));
});
```

The first survives refactors; the second breaks the moment you change the SQL even though behavior is identical.

### DAMP over DRY in tests

In production code, DRY (don't repeat yourself) is usually right. In tests, **DAMP** (descriptive and meaningful phrases) is better. A test should read like a specification — each test tells a complete story without tracing through shared helpers.

Duplication in tests is acceptable when it makes each test independently understandable.

### Prefer real implementations over mocks

Preference order (most to least):

1. **Real implementation** — highest confidence
2. **Fake** — in-memory version (e.g. fake DB)
3. **Stub** — returns canned data, no behavior
4. **Mock (interaction)** — verifies calls, use sparingly

Mock only at boundaries where real deps are slow, non-deterministic, or have side effects you can't control (external APIs, email sending). Over-mocking creates tests that pass while production breaks.

### Arrange-Act-Assert

```
it('marks tasks as overdue when deadline has passed', () => {
  // Arrange
  const task = createTask({ deadline: new Date('2025-01-01') });

  // Act
  const result = checkOverdue(task, new Date('2025-01-02'));

  // Assert
  expect(result.isOverdue).toBe(true);
});
```

### One concept per test

```
# Good — three focused tests
it('rejects empty titles', ...);
it('trims whitespace from titles', ...);
it('enforces maximum title length', ...);

# Bad — one tangled test
it('validates titles correctly', () => {
  expect(() => createTask({ title: '' })).toThrow();
  expect(createTask({ title: '  hello  ' }).title).toBe('hello');
  expect(() => createTask({ title: 'a'.repeat(256) })).toThrow();
});
```

### Name tests descriptively

```
# Good — reads like spec
describe('TaskService.completeTask', () => {
  it('sets status to completed and records timestamp', ...);
  it('throws NotFoundError for non-existent task', ...);
  it('is idempotent — completing an already-completed task is a no-op', ...);
});

# Bad — vague
describe('TaskService', () => {
  it('works', ...);
  it('handles errors', ...);
});
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll write the test after" | You won't. And if you do, you'll write a test that passes your code, not one that encodes the spec. |
| "This is too simple to test" | Simple code with no test is simple code with no proof. Tests also document intent. |
| "I need to get the structure right first" | Structure without a test is speculation. The test grounds you. |
| "The plan describes what to build, that's enough" | The plan describes intent. The test ENCODES intent as executable verification. |
| "I'll TDD the hard parts" | You can't predict which parts are hard. TDD everything. |
| "Tests slow me down" | Tests slow the immediate loop. Debugging after shipping is 10x slower. |
| "I know this code works" | You know it does what you think it should do. The test proves it does what the spec says. |
| "It's just a config change" | Config changes break things too. Write a test that loads the config and asserts the values. |
| "Manual testing was enough" | Manual testing doesn't persist. Tomorrow's change breaks it with no way to know. |
| "The code is self-explanatory" | Tests ARE the specification. They document what should be, not what is. |

## Red Flags

- Production code written without a corresponding test
- Tests that pass on the first run (may not be testing what you think)
- "All tests pass" with no evidence the tests were actually run
- Bug fixes without reproduction tests
- Tests that mirror implementation (break on any refactor)
- Test names that don't describe behavior ("test1", "works")
- Skipped or disabled tests that stay that way
- Mocking everything (production breaks but tests pass)
- Asserting only truthiness (`toBeTruthy()`) or non-nullness without further checks

## Verification

After completing a test cycle:

- [ ] The RED test failed before the production code existed
- [ ] The GREEN test passes now
- [ ] Full test suite passes (no regressions)
- [ ] Bug fixes have a reproduction test that failed before the fix
- [ ] Test names describe behavior, not methods
- [ ] No tests skipped or disabled
- [ ] Coverage hasn't decreased (if tracked)
