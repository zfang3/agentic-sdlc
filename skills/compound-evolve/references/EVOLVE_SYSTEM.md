# EVOLVE_SYSTEM — Pipeline Prompts

Detailed prompts used at each stage of `/compound-evolve`. The forked subagent walks through these
in order. Each returns structured data the next stage consumes.

---

## Stage 1 — Summarize session

You are summarizing one agent session for an evolution pipeline. Your job is to
produce a compact but lossless record of what happened.

### Input

- A session directory at `.claude/sessions/<session-id>/`
- All files inside: `spec.md`, `plan.md`, `debug.md`, `verify.md`, any other artifacts

### Output (JSON)

```json
{
  "session_id": "<string>",
  "date": "<YYYY-MM-DD>",
  "goal": "<one sentence: what the user set out to do>",
  "trajectory": "<step-by-step text: which skills were invoked in order, what tools ran, what failed, what succeeded>",
  "summary": "<8-15 sentences: goal, strategy, turning points, skill effectiveness, outcome>",
  "skills_referenced": ["<skill-name>", "..."],
  "outcome": "complete | partial | abandoned",
  "has_tool_errors": true | false,
  "notable_events": ["<short description of anything surprising>"]
}
```

### Guidance

- **Trajectory is lossless** — preserve the sequence of events even if it's noisy. Later stages need to trace causality.
- **Summary is analytical** — identify where things went right or wrong, and why. Don't just restate the trajectory.
- **Skill effectiveness** — for each skill referenced, say whether it helped, hurt, or was neutral. If a skill's guidance was missing or wrong, note it.

---

## Stage 2 — Judge session

You are judging one session on four dimensions. Be honest — grade-inflation
makes the whole pipeline useless.

### Input

- The session summary from Stage 1
- The session artifacts (for verification, not for re-summarizing)

### Output (JSON)

```json
{
  "session_id": "<string>",
  "task_completion": 0.0-1.0,
  "response_quality": 0.0-1.0,
  "efficiency": 0.0-1.0,
  "tool_usage": 0.0-1.0,
  "overall_score": 0.0-1.0,
  "rationale": "<one or two sentences>"
}
```

### Scoring guide

- **task_completion** (weight 0.55): did the session achieve the user's goal? Partial credit for partial completion.
- **response_quality** (weight 0.30): was the final output correct, clear, complete?
- **efficiency** (weight 0.05): unnecessary retries, detours, thrashing?
- **tool_usage** (weight 0.10): appropriate tools, used well?

Overall = 0.55 × task_completion + 0.30 × response_quality + 0.05 × efficiency + 0.10 × tool_usage

### Guidance

- 1.0 = clearly excellent on that dimension
- 0.5 = mixed / uncertain / partial success
- 0.0 = clearly failed
- Distinguish "missing evidence" from "clear failure" — be conservative when signal is weak
- Don't over-penalize startup noise (doc reading, environment setup) unless it materially blocked progress
- Prefer factual correctness over polish

---

## Stage 3 — Aggregate (programmatic, no LLM)

Group the judged sessions by the skills they referenced. Each session may appear in multiple groups. Sessions with no referenced skill go into a `no-skill` bucket — those are candidates for new skills.

```python
groups = {}
for session in sessions:
    for skill in session["skills_referenced"]:
        groups.setdefault(skill, []).append(session)
    if not session["skills_referenced"]:
        groups.setdefault("__no_skill__", []).append(session)
```

Output: `Dict[skill_name, List[session]]`

---

## Stage 4 — Decide action per skill group

You are a skill engineer. For this skill group, decide ONE action based on
the session evidence and the skill's history.

### Input

- Skill name
- Current `SKILL.md` content
- All `history/v*.md` + `history/v*_evidence.md` files (read ALL — mandatory)
- The aggregated sessions for this skill + their scores

### Required: read the full history first

Before deciding, answer:

- What changed in each prior version?
- What evidence justified that change?
- Did later sessions suggest the change helped, hurt, or remained ambiguous?
- What should be preserved vs. revised?

### Output (JSON)

```json
{
  "skill_name": "<string>",
  "action": "improve_skill | optimize_description | create_skill | skip",
  "reason": "<one sentence>",
  "evidence_session_ids": ["...", "..."],
  "proposed_content": "<full SKILL.md content if action is improve_skill or create_skill>",
  "proposed_description": "<new description only if action is optimize_description>",
  "preserved_sections": ["<section names intentionally unchanged>"],
  "open_questions": ["<anything future rounds should monitor>"]
}
```

### Conservative editing (for improve_skill)

- Treat the current skill as **source of truth**.
- Default to **targeted edits**, not rewrites.
- Preserve original structure, heading order, terminology, concrete facts (file paths, API endpoints, tool names).
- Only rewrite an entire section if evidence clearly shows it's materially wrong.
- If a successful session supports a section, don't change it unless failure evidence contradicts.

### When to create vs. improve

- **improve_skill** if the pattern belongs to the existing skill's purpose
- **create_skill** only if the pattern is clearly distinct and cannot be addressed by improving an existing skill

### When to prefer skip

- Evidence is thin (1-2 sessions) and doesn't clearly point at the skill
- Failures were agent misuse rather than skill gaps
- Environment problems (API flake) that aren't recurrent
- Proposed change would remove useful existing content without strong evidence

### Hard constraints

- Do NOT change API contracts, file paths, tool names that are factually correct
- Do NOT remove core capabilities, examples, or citations unrelated to observed failures
- Do NOT turn a skill into a different skill with a different purpose
- Do NOT impose a new template or style unless evidence requires it
- Do NOT add generic best-practice advice

---

## Stage 5 — Verify candidate

You are the publication gate. For this candidate, decide whether it's safe
and worth promoting.

### Input

- The proposed action (improve / optimize_description / create_skill)
- The candidate content
- The current skill (if improving)
- The supporting evidence

### Output (JSON)

```json
{
  "skill_name": "<string>",
  "decision": "accept | reject",
  "score": 0.0-1.0,
  "reason": "<one or two sentences>",
  "checks": {
    "grounded_in_evidence": 0.0-1.0,
    "preserves_existing_value": 0.0-1.0,
    "specificity_and_reusability": 0.0-1.0,
    "safe_to_publish": 0.0-1.0
  }
}
```

### Accept only if ALL are true

- Grounded in the provided evidence (not speculation)
- Preserves useful existing environment-specific facts
- Specific and reusable, not generic agent advice
- Coherent enough to publish immediately without further work

### Reject if ANY is true

- Speculative or weakly supported
- Removes useful existing instructions / endpoints / file paths without reason
- Mostly adds generic best practices instead of environment-specific knowledge
- Needs more evidence before publication

### For `optimize_description`

Only verify whether the new description is a safer and more accurate trigger than the old one.

### For `create_skill`

Verify that the new skill is genuinely distinct from existing skills and generalizable from the evidence.

### Threshold

Overall score < 0.75 → reject. Rejected candidates stay in `.claude/skills/pending/` for next round.

---

## Stage 6 — Promote (programmatic)

For each accepted candidate:

1. If `improve_skill` / `optimize_description`:
   - Copy current `SKILL.md` → `history/v<N>.md`
   - Write `history/v<N>_evidence.md`
   - Overwrite `SKILL.md` with proposed content
2. If `create_skill`:
   - Move `.claude/skills/pending/<name>/` → `.claude/skills/<name>/`
   - Write `history/v0_evidence.md`

Stage all changes for the user to commit. Do NOT run `git commit`.

Update `.claude/evolve-log.md` with the run summary:

```markdown
## <YYYY-MM-DD> — evolve run

Sessions processed: <IDs> (N total)
Mean overall score: 0.XX

Accepted:
- improve_skill <skill>: <reason>
- create_skill <name>: <reason>

Rejected:
- improve_skill <skill>: <reason>

Approved by user: <count>
```
