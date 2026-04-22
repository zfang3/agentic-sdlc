---
name: start-simplify
description: Reduce complexity in working code without changing behavior. Use after a feature is working but the implementation feels heavier than it needs to be, or after a review flags complexity issues. NOT for adding features or fixing bugs.
category: sdlc
---

# Simplify

## Overview

Simplifies code by reducing complexity while preserving exact behavior. The goal is not fewer lines — it's code that's easier to read, understand, modify, and debug. Every simplification must pass a simple test: "Would a new team member understand this faster than the original?"

The principle: **clarity over cleverness.** A 5-line if/else beats a 1-line nested ternary when the ternary requires a mental pause.

## When to Use

- Feature is working + tests pass, but implementation feels heavier than needed
- Code review flagged readability or complexity issues
- You see deeply nested logic, long functions, unclear names
- Consolidating related logic scattered across files
- After merging changes that introduced duplication or inconsistency

**When NOT to use:**
- Code is already clean — don't simplify for the sake of it
- You don't understand the code yet — comprehend before you simplify
- Performance-critical code where "simpler" would be measurably slower
- You're about to rewrite the whole module

## The Five principles

### 1. Preserve behavior exactly

Don't change what the code does — only how it expresses it. All inputs, outputs, side effects, error paths, and edge cases must remain identical. If uncertain, don't make the change.

Ask before every change:
- Same output for every input?
- Same error behavior?
- Same side effects and ordering?
- All existing tests pass without modification?

### 2. Follow project conventions

Simplification means making code more consistent with the codebase, not imposing external preferences.

Before simplifying:
1. Read `docs/architecture/overview.md` and any CLAUDE.md
2. Study how neighboring code handles similar patterns
3. Match the project's style for imports, function declarations, naming, error handling, type annotations

Simplification that breaks project consistency is not simplification — it's churn.

### 3. Prefer clarity over cleverness

Explicit code beats compact code when the compact version requires a mental pause.

```
# Unclear — dense ternary chain
const label = isNew ? 'New' : isUpdated ? 'Updated' : isArchived ? 'Archived' : 'Active';

# Clear — readable mapping
function getStatusLabel(item) {
  if (item.isNew) return 'New';
  if (item.isUpdated) return 'Updated';
  if (item.isArchived) return 'Archived';
  return 'Active';
}
```

### 4. Watch for over-simplification

Simplification has a failure mode:

- **Inlining too aggressively** — removing a helper that named a concept makes the call site harder to read
- **Combining unrelated logic** — two simple functions merged into one complex one is not simpler
- **Removing "unnecessary" abstraction** — some abstractions exist for testability or extensibility, not complexity
- **Optimizing for line count** — fewer lines is not the goal

### 5. Scope to what changed

Default to simplifying recently modified code. Avoid drive-by refactors of unrelated code unless explicitly asked. Unscoped simplification creates noisy diffs and risks unintended regressions.

## The Process

### Step 1 — Understand before touching (Chesterton's Fence)

Before changing or removing anything, understand why it exists. If you see a fence across a road and don't understand why, don't tear it down.

For the target code, answer:
- What is its responsibility?
- What calls it? What does it call?
- What are the edge cases and error paths?
- Are there tests that define expected behavior?
- Why might it have been written this way? (Performance? Platform constraint? History?)
- Check `git blame`: what was the original context?

If you can't answer these, you're not ready to simplify.

### Step 2 — Identify opportunities

Scan for these patterns. Each is a concrete signal, not a vague smell.

**Structural complexity**

| Pattern | Signal | Simplification |
|---|---|---|
| Deep nesting (3+ levels) | Hard to follow control flow | Guard clauses or extracted helpers |
| Long functions (50+ lines) | Multiple responsibilities | Split into focused functions |
| Nested ternaries | Mental stack to parse | Replace with if/else, switch, or lookup |
| Boolean parameter flags | `doThing(true, false, true)` | Options object or separate functions |
| Repeated conditionals | Same check in many places | Extract to a well-named predicate |

**Naming and readability**

| Pattern | Signal | Simplification |
|---|---|---|
| Generic names | `data`, `result`, `temp` | Describe the content |
| Abbreviations | `usr`, `cfg`, `btn` | Full words unless universal |
| Misleading names | `get` that also mutates | Rename to reflect behavior |
| Comments explaining what | `// increment counter` | Delete — code is clear |
| Comments explaining why | `// retry because flaky under load` | Keep |

**Redundancy**

| Pattern | Signal | Simplification |
|---|---|---|
| Duplicated logic | Same 5+ lines in multiple places | Extract to shared function |
| Dead code | Unreachable branches, unused vars | Remove (after confirming dead) |
| Unnecessary abstractions | Wrapper that adds nothing | Inline |
| Over-engineered patterns | Factory-for-a-factory | Direct approach |
| Redundant type assertions | Casting to already-inferred type | Remove |

### Step 3 — Apply incrementally

Make one simplification at a time. Run tests after each.

```
For each simplification:
  1. Make the change
  2. Run the test suite
  3. If tests pass → commit (or proceed)
  4. If tests fail → revert and reconsider
```

Don't batch multiple simplifications into one untested change. If something breaks, you need to know which simplification caused it.

**Rule of 500**: if a simplification would touch >500 lines, invest in automation (codemods, sed, AST transforms) rather than doing it by hand. Manual edits at that scale are error-prone.

### Step 4 — Separate refactor from feature work

**Submit simplification PRs separately from feature PRs.** A PR that refactors and adds behavior is two PRs. Split them:

- Commit 1: "refactor: extract X helper, no behavior change"
- Commit 2: "feat: add new behavior using X"

Mixed commits are harder to review, revert, and understand in history.

### Step 5 — Verify the result

After all simplifications, compare before and after:

- Genuinely easier to understand?
- Introduced new patterns inconsistent with the codebase?
- Diff clean and reviewable?
- Would a teammate approve this?

If the "simplified" version is harder to understand or review, revert. Not every simplification succeeds.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "It's working, no need to touch it" | Working code that's hard to read will be hard to fix when it breaks. |
| "Fewer lines is always simpler" | A 1-line nested ternary is not simpler than a 5-line if/else. Comprehension speed matters, not count. |
| "I'll quickly simplify this unrelated code too" | Unscoped simplification creates noisy diffs and risks regressions. Stay focused. |
| "Types make it self-documenting" | Types document structure, not intent. A good name explains *why* better than a type explains *what*. |
| "This abstraction might be useful later" | Don't preserve speculative abstractions. Remove and re-add when needed. |
| "The original author had a reason" | Maybe — check git blame. But accumulated complexity often has no reason beyond iteration under pressure. |
| "I'll refactor while adding this feature" | Separate them. Mixed changes are harder to review, revert, and understand. |

## Red Flags

- Simplification that requires modifying tests — you likely changed behavior
- "Simplified" code that's longer and harder to follow
- Renaming to match preferences rather than project conventions
- Removing error handling because "it makes the code cleaner"
- Simplifying code you don't fully understand
- Batching many simplifications into one large, hard-to-review commit
- Refactoring code outside the scope of the current task without being asked

## Verification

After a simplification pass:

- [ ] All existing tests pass without modification
- [ ] Build succeeds with no new warnings
- [ ] Linter/formatter passes
- [ ] Each simplification is a reviewable, incremental change
- [ ] Diff is clean — no unrelated changes mixed in
- [ ] Code follows project conventions
- [ ] No error handling was removed or weakened
- [ ] No dead code left behind
- [ ] A teammate (or review subagent) would approve as a net improvement
