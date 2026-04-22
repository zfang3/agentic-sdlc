---
name: compound-evolve
description: Run the full evolution pipeline across recent sessions — summarize, judge, aggregate, decide, verify, and propose skill updates. Use periodically (weekly, per-sprint) to turn accumulated session experience into improved project skills.
category: meta
disable-model-invocation: true
context: fork
agent: general-purpose
---

# Evolve

## Overview

The big brother of `/compound-learn`. Where `/compound-learn` captures one insight from one session, `/compound-evolve` processes many sessions and can propose multiple skill updates — improvements to existing skills, optimizations to descriptions (so they trigger more accurately), or new skills for patterns that weren't covered.

Runs fully forked to `general-purpose` because it reads a lot — every session log plus every existing skill's history. Isolation keeps the main context clean.

The principle: **skills are living infrastructure.** The `/compound-evolve` loop is how they stay current without hand-authoring.

## When to Use

- Weekly, or after completing a sprint / major deliverable
- When you notice the agent making repeated mistakes that a skill should have prevented
- When session count since last `/compound-evolve` reaches a threshold you set (e.g. 10 sessions)
- Before a marketplace release — evolve, review candidates, commit improvements

**When NOT to use:**
- Fewer than 3 sessions since the last run (not enough signal)
- Mid-session (use `/compound-learn` for single-session capture)
- When you haven't reviewed the last `/compound-evolve`'s output yet (don't stack unresolved candidates)

## Prerequisite

Session logs exist under `.claude/sessions/`. Each session should have at least:

- `spec.md` (if a spec was written)
- `plan.md` (if planning was done)
- `verify.md` or `debug.md` (records what happened)

If no sessions exist, `/compound-evolve` has nothing to do. Tell the user.

## The Process

This skill follows a six-stage pipeline:

```
SUMMARIZE → JUDGE → AGGREGATE → DECIDE → VERIFY → PROMOTE
```

See [EVOLVE_SYSTEM.md](references/EVOLVE_SYSTEM.md) for the detailed prompts the subagent uses at each stage.

### Step 1 — Gather sessions

```
# Find sessions to process
ls .claude/sessions/
```

Filter:
- Skip sessions already processed (check `.claude/evolve-log.md` for the last run's timestamp)
- Skip sessions with no artifacts (empty directories)
- Order by date

Report to the user:

> Found N sessions since the last /compound-evolve run (<date>). Processing them now.
> This will take a few minutes.

### Step 2 — Summarize each session (parallel)

For each session, fork one subagent that:

1. Reads all artifacts in the session directory
2. Builds a **trajectory** — a compact step-by-step record of what happened (which skills were invoked, what tools ran, what failed, what succeeded)
3. Writes an **analytical summary** (8-15 sentences): goal, key path, turning points, skill effectiveness, outcome

Output format:

```
{
  "session_id": "<YYYY-MM-DD>-<slug>",
  "trajectory": "...",
  "summary": "...",
  "skills_referenced": ["spec", "plan", "build", "verify"],
  "outcome": "complete | partial | abandoned",
  "has_tool_errors": false,
  "notable_events": ["..."]
}
```

### Step 3 — Judge each session

For each summarized session, score on four dimensions (0.0–1.0):

- **task_completion**: was the goal met?
- **response_quality**: correctness, clarity, coverage
- **efficiency**: avoided unnecessary retries and detours
- **tool_usage**: appropriate and effective

Overall score (weighted):
- task_completion: 0.55
- response_quality: 0.30
- efficiency: 0.05
- tool_usage: 0.10

Add a one-sentence rationale.

### Step 4 — Aggregate by skill

Group sessions by the skills they referenced. Also bucket "no-skill" sessions separately — these are candidates for *new* skills.

```
{
  "spec": [session_1, session_3, session_7],      # sessions that used /start-spec
  "build": [session_1, session_2, session_4],
  "no-skill": [session_5]                          # ad-hoc session, no skill invoked
}
```

### Step 5 — Decide an action per skill group

For each group, read:
- The current `SKILL.md`
- Every entry in `history/v*.md` and `history/v*_evidence.md` (mandatory — don't re-litigate past decisions)
- The aggregated sessions and their scores

Decide one of four actions:

| Action | When to use |
|---|---|
| **improve_skill** | Sessions reveal missing guidance, outdated info, or unclear instructions. Multiple sessions point to the same section being wrong. |
| **optimize_description** | Skill body is fine, but the description causes wrong matching (wrong tasks triggering it, or right tasks missing it). |
| **create_skill** | A recurring pattern in the no-skill bucket isn't covered by any existing skill. |
| **skip** | Skill is working well enough, or evidence is too weak to justify a change. **When in doubt, skip.** |

### Step 6 — Execute the chosen action

**improve_skill / optimize_description:**

1. Copy the current `SKILL.md` to `history/v<N>.md`
2. Write `history/v<N>_evidence.md` with:
   - Which sessions drove this change (IDs, scores, failure patterns)
   - What previous history entries you read and how they informed this edit
   - What sections are being changed and why
   - What is intentionally being preserved
3. Edit `SKILL.md` with targeted changes. **Do NOT rewrite the whole skill.** Treat the current skill as the source of truth; apply minimal edits.

**create_skill:**

1. Create `.claude/skills/pending/<name>/SKILL.md` and `history/v0_evidence.md`
2. In evidence, explain: what sessions motivated the skill, why no existing skill covers it

**skip:** move on.

### Step 7 — Verify each candidate

For every proposed change (improve / optimize / create), run a verification pass:

Gate the candidate on:

- **grounded_in_evidence**: claim connects to actual session data
- **preserves_existing_value**: doesn't remove useful existing content without reason
- **specificity_and_reusability**: specific to this project, reusable across future sessions
- **safe_to_publish**: no secrets, no project-specific paths that won't exist for teammates

Score each 0.0–1.0. If overall below 0.75, mark as **reject** with a reason. Rejected candidates stay in `pending/` — next `/compound-evolve` may revisit.

### Step 8 — Present to user

```markdown
## /compound-evolve results — <YYYY-MM-DD>

Sessions processed: N (dates: <from> to <to>)
Mean session score: 0.XX

### Accepted candidates (M)

1. **improve_skill: build**
   Reason: 3 sessions showed the skill missed guidance on handling
   test fixtures. Evidence: sessions <IDs>.
   [Show diff]

2. **create_skill: handling-migrations**
   Reason: 4 no-skill sessions all involved DB migrations and had
   repeated mistakes. Proposed skill covers the pattern.
   [Show full content]

### Rejected candidates (K)

1. **improve_skill: verify** — rejected for weak evidence
   (only 1 session, score was 0.6)

Approve accepted candidates? (all / select / skip)
```

### Step 9 — Promote approved candidates

On user approval:

- **improve_skill**: the new `SKILL.md` is already in place; stage for commit
- **create_skill**: move from `pending/<name>/` to `.claude/skills/<name>/`; stage for commit

Never commit automatically. Let the user commit with a message they choose.

### Step 10 — Update evolve log

Append to `.claude/evolve-log.md`:

```markdown
## <YYYY-MM-DD> — evolve run

Sessions processed: <IDs>
Mean score: 0.XX
Candidates accepted: M
Candidates rejected: K (reasons)
Approved by user: <count>
```

This is how the next `/compound-evolve` knows where to pick up.

## Conservative editing principles

Critical for `improve_skill`:

- **Treat the current skill as source of truth**, not a rough draft to be rewritten.
- Default to **targeted edits**, not rewrites.
- Preserve original structure, heading order, and terminology.
- Only rewrite an entire section if evidence shows it's materially wrong.
- If a session failed because it didn't *use* the skill's existing guidance, that's an agent problem — do NOT delete the guidance.
- Don't add generic best-practice advice unless the environment has a specific quirk.
- Don't change stable facts (API endpoints, file paths, tool names) unless evidence shows they've changed.

## Distinguishing skill, agent, and environment problems

Not every failure is a skill deficiency:

- **Skill problem** — wrong or missing guidance. Edit the skill.
- **Agent problem** — misused the skill, ignored it, ran out of context. Do NOT bloat the skill to compensate for agent behavior.
- **Environment problem** — API instability, network flake. Mention if recurrent; don't make it the skill's main point.

Anti-pattern: if the skill already contains correct information and the agent failed because it didn't follow it, that's an agent problem. Do NOT delete correct info and replace with "go figure it out".

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll trust the pipeline and skip user review" | Candidate verification catches most bad edits, but not all. User review is the last gate. |
| "Rewrite the skill from scratch, it'll be cleaner" | Rewrites lose hard-won calibrations from past evidence. Targeted edits. |
| "This generic best practice should go in every skill" | Generic advice dilutes specific skills. Keep guidance specific to the trigger. |
| "One session is enough evidence for a change" | One session is enough for `/compound-learn`, not `/compound-evolve`. For evolution, require multiple data points. |
| "Old versions can be deleted from history" | History is the audit trail. Future agents read it to avoid re-making past mistakes. |
| "Reject is rare, accept most candidates" | Wrong — reject is common and healthy. Weak evidence → skip. |
| "Promote to plugin scope while I'm at it" | Project-scope skills live in the project. Promotion to plugin is a separate, deliberate act through a plugin PR. |

## Red Flags

- Running `/compound-evolve` on 1-2 sessions (not enough signal)
- Rewriting skills instead of editing them
- Missing history files (every change should leave `v<N>.md` + `v<N>_evidence.md`)
- Committing candidates without user approval
- Removing concrete information (file paths, API details) from a skill because recent sessions didn't use it
- Accepting every candidate — if nothing is rejected, verification isn't working
- Running the pipeline in the main context (always fork)
- Skipping the history read — past evidence shapes what to change

## Verification

- [ ] Forked to `general-purpose`
- [ ] Every session in scope was summarized and judged
- [ ] Aggregation grouped sessions by referenced skills + no-skill bucket
- [ ] For every skill group, the full `history/` was read before deciding
- [ ] Every change left a `v<N>.md` + `v<N>_evidence.md` trail
- [ ] Every candidate went through the 4-dimension verification gate
- [ ] User approved every accepted candidate
- [ ] `.claude/evolve-log.md` updated
- [ ] No git commands run automatically
