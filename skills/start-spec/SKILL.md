---
name: start-spec
description: Write or refine a product spec before any code is written. Use when starting a new feature, a significant change, or anything whose scope isn't trivially obvious. NOT for single-line fixes, typos, or changes covered by an existing spec.
category: sdlc
argument-hint: [topic]
---

# Spec

## Overview

Turns a rough idea into a short, specific document that both you and the agent can build from. Every skill downstream (`/start-plan`, `/start-build`, `/start-verify`) reads the spec. If the spec is wrong, everything built from it is wrong.

The principle: **code without a spec is guessing.** A 15-minute spec prevents hours of rework. Even "obvious" features benefit from a single page that names the problem, the user, the acceptance criteria, and the non-goals.

## Hard gate

```
Do NOT invoke /start-plan, /start-build, or any implementation skill until a spec exists
AND the user has approved it. This rule has no exceptions.
```

Even trivial features get a two-paragraph spec. The discipline is that there *is* a spec, not that every spec is long.

## When to Use

- Starting a new feature
- Significant change to existing behavior
- Anything where scope, users, or success criteria are unclear
- When a ticket is terse and needs unpacking before planning
- When you suspect the ask is bigger than it sounds

**When NOT to use:**
- Typo fixes, formatting, trivial lint fixes
- Changes whose spec is already complete in an existing ticket or design doc
- Refactoring that doesn't change behavior (use `/start-simplify` instead)

## The Process

### Step 0 — Read project conventions

Read `docs/skills/start-spec.md` if present. Its contents are additional project guidance for this skill (mandatory sections, preferred AC style, standing non-goals, examples to emulate). Follow them alongside the defaults below.

If the file is missing or only contains the stub template, tell the user:

> No project conventions declared at `docs/skills/start-spec.md`. Proceeding with built-in defaults. Run `/start-sync` to scaffold a stub if your team wants to capture conventions.

Then proceed to Step 1.

### Step 1 — Surface assumptions

Before asking clarifying questions, list every assumption you're about to make and flag them explicitly. Examples:

```
ASSUMPTIONS I'M MAKING (flag any that are wrong):
- Stack: whatever docs/architecture/overview.md says
- Users: existing authenticated users only (not anonymous)
- Scope: feature is net-new, not modifying any existing endpoint
- Timeline: no hard deadline
```

Don't skip this step. Silent assumptions cause wrong specs.

### Step 2 — Clarify one question at a time

Ask about purpose, constraints, and success criteria. Multiple choice when possible. Never dump a form of five questions.

Core questions (always ask):

1. **Who is the user of this feature?** (Role, workflow, what they do before/after using it)
2. **What problem does this solve?** (Specifically — not "improve UX")
3. **What does done look like?** (How will you know it works)

Situational questions (ask when relevant):

- What's the expected data scale? (100 items? 100k?)
- What's the interaction — CLI, API, UI, batch job?
- Is there an existing flow this changes? Backward compatibility required?
- What's explicitly out of scope?
- Who else besides the direct user is affected?

### Step 3 — Present a draft spec in sections

Never dump a full spec and ask for approval at the end. Present section by section, asking "does this look right so far?" after each. Sections:

```markdown
# Spec: <one-line title>

## Problem
<one paragraph: who has what problem, why it matters now>

## Users
<who triggers this, who consumes it, who else sees the effect>

## What we're building
<one paragraph, concrete. "A POST /api/x that…" not "an endpoint that…">

## Acceptance criteria
- [ ] <testable statement>
- [ ] <testable statement>
- [ ] <testable statement>

## Non-goals
- <out-of-scope item>
- <out-of-scope item>

## Open questions
<anything you couldn't resolve in this round>
```

Get approval on each section before writing the next.

### Step 4 — Self-review before saving

Before writing the spec to disk, check:

1. **Placeholder scan**: any `TBD`, `TODO`, `<...>`, or vague wording? Fix before saving.
2. **Contradiction check**: do any sections contradict each other? Does "Users" match "What we're building"?
3. **Scope check**: is this one spec or does it really need to be broken into sub-specs? Multi-subsystem features must be decomposed.
4. **Checkability check**: every acceptance criterion must be falsifiable AND mechanically checkable against an artifact. "The system is fast" fails both; "p95 latency < 200ms for the new endpoint, measured from `tmp/verify/latency.json` after 100 requests" passes both. `/start-plan` will translate each AC into a verification-contract item; if an AC is too abstract to point at an observable artifact, the contract cannot be written.

Fix issues inline. No need to re-present to the user unless the scope check forces decomposition.

### Step 5 — Save and commit

Derive a slug from the topic. Save to:

```
docs/sessions/<YYYY-MM-DD>-<slug>/spec.md
```

Examples of slug derivation:
- `/start-spec PROJ-123` → slug `proj-123`
- `/start-spec "add retry logic to ingestion"` → slug `add-retry-logic-to-ingestion`

If a spec for this topic already exists at the same path from an earlier date, ask whether to update it or create a new one.

Show the user the final spec and suggest the next step:

> Spec saved to `docs/sessions/<YYYY-MM-DD>-<slug>/spec.md`. Next: `/start-plan` to break this into atomic tasks.

## Decomposition: when a spec is too big

If the feature touches multiple independent subsystems (e.g. "build a marketplace with payments, messaging, and analytics"), do not force it into one spec. Instead:

1. Flag the decomposition explicitly: "This spans N subsystems. I'd like to split into N sub-specs."
2. Propose the split with a one-sentence description of each sub-spec and how they relate.
3. After user confirmation, write one sub-spec at a time using the normal flow.
4. Add a cross-reference at the top of each sub-spec linking to siblings.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The ticket description is good enough" | Tickets are for tracking; specs are for building. Copy what's useful into a real spec. |
| "This is too simple to spec" | Simple specs are fast to write and prevent the "wait, did we mean X or Y?" moment on day three. |
| "I'll skip non-goals, they're obvious" | They're never obvious. The moment you skip them, someone implements the thing you didn't want. |
| "The users field is obvious — it's the user" | Name the role and their workflow. "Authenticated admin approving a pending claim" is useful; "the user" is not. |
| "We can figure out acceptance criteria during review" | Review without AC is preference. Write them first so review is verification. |
| "The AC is abstract, `/start-verify` will figure out what to check" | `/start-verify` executes a contract that `/start-plan` authored from these AC. If an AC does not map to an observable artifact, the contract cannot be written and the change cannot be verified. Concreteness here is what makes the whole chain executable. |
| "I'll present the whole spec at once, faster" | Tested: section-by-section catches more wrong assumptions. Dumping a full spec gets rubber-stamped. |

## Red Flags

- Acceptance criteria that aren't testable ("improve performance", "handle errors well")
- Acceptance criteria that can't be mapped to an observable artifact (e.g. a response body, a log line, a file on disk, a DB row) — the downstream verification contract has nothing to check
- No "Users" section, or users described in the abstract ("the user")
- Non-goals missing entirely
- Open questions left empty when they clearly exist
- A spec longer than one page for a feature that should be one small change
- Writing a spec that contradicts the existing architecture without flagging the conflict
- Any phrase like "we'll figure that out during implementation" — resolve or record as an open question

## Verification

Before claiming the spec is done:

- [ ] Problem, Users, What we're building, Acceptance Criteria, Non-goals, and Open Questions are all filled
- [ ] Every acceptance criterion is testable
- [ ] No placeholders (`TBD`, `<...>`, `TODO`)
- [ ] User has approved every section
- [ ] File saved to `docs/sessions/<YYYY-MM-DD>-<slug>/spec.md`
- [ ] Next step (`/start-plan`) was suggested
