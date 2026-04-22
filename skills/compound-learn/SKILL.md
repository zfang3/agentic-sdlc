---
name: compound-learn
description: Capture one insight from the current session as a durable project skill. Use after solving a non-trivial problem that's likely to recur. Fast path — single session in, one skill out. For full evolution across many sessions, use /compound-evolve.
category: meta
disable-model-invocation: true
context: fork
agent: general-purpose
---

# Learn

## Overview

Single-session insight capture. When you solve a non-trivial problem — a debugging technique, a workaround, a pattern the codebase uses, a gotcha with a library — this skill pulls that insight into a durable project skill that future sessions inherit.

The fast path vs `/compound-evolve`: `/compound-learn` is **one session → one skill**. `/compound-evolve` is **many sessions → many skill updates**. Use `/compound-learn` the moment the insight is fresh; use `/compound-evolve` periodically to aggregate patterns across sessions.

The principle: **each ticket should leave the system a little better than it found it.** `/compound-learn` is how.

## When to Use

- You just solved a non-obvious bug and the fix was non-obvious
- You discovered a pattern in the codebase that wasn't documented
- You found a library quirk, version-specific gotcha, or workaround
- You made a decision during implementation that should bind future work
- A checklist or sequence kept appearing across multiple recent sessions
- The user says "remember this" or "we shouldn't hit this again"

**When NOT to use:**
- Trivial fixes (typos, syntax errors) — not reusable
- One-time issues (API outage last Tuesday) — won't recur
- Things better captured as an ADR than a skill (permanent architectural decisions go in `docs/architecture/decisions/`)
- Team-specific process that belongs in a runbook, not an agent skill
- Anything generic enough to belong in the plugin — propose a plugin PR instead

## The Process

This skill runs forked to `general-purpose`. The forked agent reads the current session's artifacts (the spec, plan, any commits, debug notes, test output), extracts one insight, pressure-tests a draft skill, and returns a candidate for user approval.

### Step 1 — Gather session context

Find the current session:

```
ls .claude/sessions/ | tail -1
```

Read everything in that directory:

- `spec.md` (if present) — what was being built
- `plan.md` (if present) — how it was broken down
- `debug.md` (if present) — what went wrong and the root cause
- `verify.md` (if present) — what was checked, what failed

If no session directory exists (ad-hoc work), ask the user for the topic and use the current conversation history as the source.

### Step 2 — Identify the insight

Ask the user (one question):

> What was the reusable lesson from this session? A debugging technique, a
> pattern, a gotcha, a decision? One sentence is enough; I'll draft from there.

Wait for an answer. Don't try to infer — the user knows which insight is worth capturing.

### Step 3 — Classify the insight

Based on the answer, classify:

| Type | Skill shape | Example |
|---|---|---|
| **Technique** | "Use when X → do Y" | "Use when debugging flaky tests → run with randomized seed and bisect the order" |
| **Pattern** | "In this codebase, we do X by doing Y" | "In this codebase, new DB migrations must update both the Alembic version and the test fixture" |
| **Gotcha** | "Watch out for X — Y happens" | "Pydantic v2 with `use_enum_values=True` makes enum fields strings at runtime; don't call `.value`" |
| **Decision** | "We decided X because Y" | Better captured as an ADR — offer to file one instead |
| **Checklist** | "Before doing X, check Y, Z, W" | "Before merging DB migrations: run against prod-size dataset, verify rollback works" |

If the insight is a Decision, suggest an ADR instead of a skill:

> This sounds like an architectural decision. I'll draft an ADR in
> `docs/architecture/decisions/` instead of a skill. Is that right?

### Step 4 — Draft the skill

Follow the standard anatomy (see `docs/skill-anatomy.md`):

```markdown
---
name: <kebab-case-name>
description: <Use when... — specific triggering conditions. NOT for... — exclusions.>
category: <technique | pattern | gotcha | checklist>
---

# <Title>

## Overview
<one paragraph — the core insight>

## When to Use
<bullet list of triggers>

**When NOT to use:**
<exclusions>

## <Core process / pattern / gotcha details>
<the actual technique, with examples>

## Common Rationalizations
<if the agent might skip this in the future, list the rationalizations>

## Red Flags
<observable signs this is being violated>

## Verification
<what done looks like>
```

Keep it tight — short, specific, actionable. A good `/compound-learn` skill is 50-200 lines.

### Step 5 — Pressure-test the draft

Before committing, run the draft through two adversarial scenarios:

1. **Time-pressure scenario**: "You're near end of day, tests pass, feature works, the user is waiting. Do you apply this skill?" If the skill's language could be rationalized away, strengthen the trigger/description.

2. **Contradictory-memory scenario**: "Your training data suggests the opposite approach. Do you still follow this skill?" If the skill doesn't cite evidence (a past incident, a specific bug), add it.

Note observed rationalizations in the skill's `Common Rationalizations` table.

### Step 6 — Save as pending

Save the candidate to:

```
.claude/skills/pending/<name>/SKILL.md
.claude/skills/pending/<name>/v0_evidence.md
```

The evidence file records:

```markdown
# v0 evidence — <skill name>

**Created from session**: <session slug>
**Date**: <YYYY-MM-DD>

## What prompted this skill
<one paragraph: the problem the user faced>

## Session references
- spec.md: <relevant quotes>
- debug.md: <the root cause>
- Commits: <SHAs with first-line messages>

## Pressure-test notes
- Time-pressure scenario: <observed behavior with draft; adjustments made>
- Contradictory-memory scenario: <observed behavior; adjustments>

## Open questions for future /compound-evolve cycles
- <anything the draft doesn't fully address>
```

### Step 7 — Show the user, get approval

Present the candidate:

```
Proposed project skill: <name>
Category: <technique / pattern / gotcha / checklist>
Triggered by: <description summary>

<show the full SKILL.md>

Approve? (yes / edit / skip)
```

On **yes**: move from `pending/` to `.claude/skills/<name>/`. Stage for user to commit (don't auto-commit).

On **edit**: the user proposes changes. Apply, re-show, re-ask.

On **skip**: leave in `pending/`. `/compound-evolve` may pick it up later.

### Step 8 — Report

Tell the user:

> Skill captured: `.claude/skills/<name>/SKILL.md` — ready to commit.
> The skill will auto-load in future sessions when <trigger> matches.
>
> Remember to commit so your teammates inherit it:
>   git add .claude/skills/<name>/
>   git commit -m "chore: capture <topic> as project skill"

Don't run git commands yourself.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "This insight is too obvious to capture" | Obvious to you now. Not to a future session that hits the same problem from scratch. |
| "I'll remember this next time" | You won't. Worse, the next agent session definitely won't. |
| "One session isn't enough evidence" | For a pattern, maybe. For a gotcha or technique that just saved an hour of debugging, one session is plenty. |
| "Let me make it more general first" | Start specific. `/compound-evolve` generalizes later if the pattern repeats. Over-generalizing at capture time makes the skill vague. |
| "I'll write it in CLAUDE.md" | CLAUDE.md loads every session whether relevant or not. A skill with a tight trigger loads only when needed. |
| "The code comments explain it" | Code comments are local. A skill is loaded by the agent during planning, before the relevant code is even opened. |

## Red Flags

- Capturing a skill from a trivial fix (typo, syntax error)
- Skills with vague triggers ("use when working on the frontend")
- Skills that duplicate existing project skills or plugin skills
- Skills that encode one person's style preferences as project convention
- Committing the skill without user approval
- Running git automatically

## Verification

- [ ] Forked to `general-purpose` for isolation
- [ ] User identified the insight explicitly (not inferred)
- [ ] Insight classified (technique / pattern / gotcha / checklist / decision)
- [ ] Draft follows the skill anatomy
- [ ] Two pressure-test scenarios run; adjustments made
- [ ] Candidate saved to `.claude/skills/pending/<name>/` with evidence file
- [ ] User approved before promotion to `.claude/skills/<name>/`
- [ ] No git commands run by the skill itself
