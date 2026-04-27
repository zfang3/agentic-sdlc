---
name: start-review
description: Run a five-axis review on the current diff or an external PR — correctness, readability, architecture, security, performance. Use before merging any change, or when reviewing someone else's PR.
category: sdlc
context: fork
agent: general-purpose
argument-hint: [pr-url-or-branch]
---

# Review

## Overview

A thorough code review across five axes: correctness, readability, architecture, security, performance. Forks to an isolated subagent so the reviewer isn't the agent that wrote the code — different context, fresh eyes, better signal.

The principle: **approve a change when it definitely improves overall code health, even if it isn't perfect.** Review is a net-improvement gate, not a perfection gate. But findings are categorized so nothing critical slips through while also-noted nits aren't treated as blockers.

## When to Use

- Before merging any change you produced (self-review pass)
- Reviewing a teammate's PR
- Reviewing an external PR in another repo you depend on
- After `/start-verify` when you want a second, independent opinion
- After a refactor that preserved behavior but changed a lot of lines

**When NOT to use:**
- Mid-implementation (too early — not stable)
- Trivial formatting-only changes
- Docs-only changes (run `/start-sync` instead)

## The Process

### Step 0 — Read project conventions and determine what to review

First, read `docs/skills/start-review.md` if present. Its contents are additional project guidance for this skill (review axes beyond the defaults, severity conventions, dependency policy, required reviewers). Follow them alongside the defaults below.

If the file is missing or only contains the stub template, tell the user:

> No project conventions declared at `docs/skills/start-review.md`. Proceeding with built-in defaults. Run `/start-sync` to scaffold a stub if your team wants to capture conventions.

Then determine the review scope:

```
With an argument:
  /start-review <pr-url>         → review that PR
  /start-review <branch-name>    → review that branch vs main

Without an argument:
  /start-review                  → review current branch's diff vs main
```

If the PR is in an external repo, fetch:
- The diff
- The PR description and AC
- The linked ticket (if any) for spec context
- The changed files' full contents (not just the diff — need surrounding context)

### Step 1 — Read the tests first

Tests reveal intent and coverage. Start there.

- Do tests exist for the change?
- Do they test behavior or implementation details?
- Are edge cases covered?
- Do the test names describe what they verify?
- Would the tests catch a regression if the code under test silently changed?

If tests are thin, that's a finding. If tests are missing entirely, that's a CRITICAL finding unless the change doesn't add behavior.

### Step 2 — Five-axis review on the diff

See [review-checklist.md](references/review-checklist.md) for the full checklist.

**1. Correctness**
- Does the code do what the spec / AC / ticket says it should?
- Are edge cases handled (null, empty, boundary, error)?
- Are there off-by-one errors, race conditions, wrong operators?
- Does it handle failure modes, not just the happy path?

**2. Readability & simplicity**
- Can another engineer understand this without the author explaining?
- Names descriptive and consistent with project conventions?
- Control flow straightforward (no deeply nested, no nested ternaries)?
- Code organized logically?
- Fewer lines if possible without harming clarity?
- Abstractions earning their complexity? (Don't generalize until the third use case)
- Comments explaining WHY (keep) vs WHAT (delete)?

**3. Architecture**
- Follows existing patterns, or introduces a new one with justification?
- Module boundaries maintained?
- Dependencies flowing in the right direction?
- Appropriate abstraction level (not over-engineered, not too coupled)?

**4. Security**
- User input validated and sanitized at boundaries?
- Secrets kept out of code, logs, version control?
- Auth checks in place where needed?
- Queries parameterized?
- Output encoded to prevent injection?
- External data treated as untrusted?

**5. Performance**
- Any N+1 patterns?
- Unbounded loops or fetches?
- Synchronous calls that should be async?
- Pagination on list endpoints?
- Unnecessary re-renders / recomputes?

### Step 3 — Change-size check

Small, focused changes are easier to review. Flag size issues:

```
~100 lines  → good, single sitting
~300 lines  → acceptable if one logical change
~1000 lines → too large; recommend splitting
```

Exception: automated refactors or complete file deletions are OK larger because reviewers only verify intent, not every line.

### Step 4 — Categorize every finding

Every comment gets a severity so the author knows what's required vs optional:

| Prefix | Meaning | Author action |
|---|---|---|
| **CRITICAL** | Blocks merge — security, data loss, broken functionality | Must fix |
| **IMPORTANT** | Should fix before merge — wrong abstraction, missing test, poor error handling | Usually must fix |
| **SUGGESTION** | Consider improving — naming, optional optimization | Author decides |
| **Nit** | Minor, optional — formatting, style preference | Author may ignore |
| **FYI** | Informational only | No action needed |

Unprefixed comments are read as CRITICAL. Always prefix.

### Step 5 — Check the verification story

For the author, not just the code:

- What tests were run?
- Did the build pass?
- Was the change verified manually if there's UI?
- Is there a before/after for visual changes?
- Does the PR description match what changed?

Missing verification evidence is a finding.

### Step 6 — Write the review report

```markdown
## Review: <PR title or branch>

**Verdict**: APPROVE | REQUEST_CHANGES | COMMENT

**Overview**: <one paragraph — what the change does, overall assessment>

### CRITICAL
- [<file:line>] <description>. **Fix**: <specific recommendation>

### IMPORTANT
- ...

### SUGGESTIONS
- ...

### Nits
- ...

### What's done well
- <positive observation — always include at least one if merit exists>

### Verification story
- Tests reviewed: <yes/no, observations>
- Build verified: <yes/no>
- Security checked: <yes/no, observations>
```

Save to `docs/sessions/<YYYY-MM-DD>-<slug>/review.md` if self-review on own branch,
or to `.agentic-sdlc/tmp/start-reviews/pr-<n>.md` if reviewing an external PR.

### Step 7 — Present to user

Show verdict prominently + CRITICAL and IMPORTANT items. Ask:

- Post the review as PR comments? (requires `gh pr review`)
- Drop the artifact only (no posting)?
- Iterate on specific findings?

Never post to the PR without user approval.

## Honest review

When reviewing code — yours, an agent's, or a human's:

- **Don't rubber-stamp.** "LGTM" without specifics helps nobody.
- **Don't soften real issues.** "This might be a minor concern" when it's a bug that will hit production is dishonest.
- **Quantify when possible.** "This N+1 adds ~50ms per item in the list" beats "could be slow."
- **Push back on clear problems.** Sycophancy is a failure mode. If there are issues, say so and propose alternatives.
- **Accept override gracefully.** If the author has full context and disagrees, defer to their judgment. Comment on code, not people.

## Dependency discipline

Part of review is dependency review:

Before any new dependency:
1. Does the existing stack solve this? (Often it does.)
2. How large is it? (Bundle impact)
3. Is it actively maintained? (Last commit, open issues)
4. Known vulnerabilities? (`npm audit`, `pip-audit`)
5. License compatible?

Every dependency is a liability. Prefer the standard library.

## Dead code hygiene

After a refactor, check for orphaned code:

1. Find code that's now unreachable or unused
2. List it explicitly
3. **Ask before deleting.** Don't silently remove things.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "It works, that's good enough" | Working code that's unreadable or insecure creates compounding debt. |
| "I wrote it, so I know it's correct" | Authors are blind to their own assumptions. Fresh eyes (or a forked subagent) catch more. |
| "We'll clean it up later" | Later never comes. Review is the quality gate. Require fixes now. |
| "AI-generated code is probably fine" | AI code needs MORE scrutiny. Plausible and confident even when wrong. |
| "The tests pass, so it's good" | Tests are necessary but not sufficient. They miss architecture, security, readability. |
| "Small change, skip review" | Small changes break things too. A 10-second review catches obvious issues. |
| "I already reviewed it when I wrote it" | Reviewing your own output biases toward approval. Fork to a fresh context. |

## Red Flags

- Merging without review
- Review that only checks tests
- LGTM with no evidence of actual reading
- Security-sensitive changes reviewed without a security pass
- "Too big to review properly" — split it
- No regression test with a bug fix
- Comments without severity labels
- Accepting "I'll fix it later"
- Reviewer and author are the same context (no isolation)

## Verification

Before reporting the review complete:

- [ ] All five axes covered
- [ ] Every finding has a severity label
- [ ] Every CRITICAL / IMPORTANT has a specific fix recommendation
- [ ] Verification story checked
- [ ] At least one positive observation noted (if merit exists)
- [ ] Review saved to a stable file path
- [ ] User shown the verdict and given the option to post or iterate
