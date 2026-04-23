# Address Review Log Template

`/start-address-review` writes (and on subsequent runs, appends to) `docs/sessions/<YYYY-MM-DD>-<slug>/address-review.md`. Each invocation appends a new `## Iteration <N>` section — never overwrite previous iterations. Resolved threads drop off in subsequent iterations; new threads (including reopened ones with fresh comments) appear fresh.

**Location**: `docs/sessions/<YYYY-MM-DD>-<slug>/address-review.md`

**Rules**:

1. Append-only. Iterations accumulate; prior content is immutable.
2. Every thread that appeared in Phase 1's fetch has a section, even if the final action was "no change, posted clarifying question."
3. Every field filled or explicitly noted `n/a` — blanks are a red flag.
4. Every triage override from the verifier's verdict has a written reason.
5. Reply drafts live in the log regardless of posted state; un-posted drafts roll into the next iteration's pickup list.

```markdown
# Address Review — <session>

> `/start-address-review` iteration log for `docs/sessions/<YYYY-MM-DD>-<slug>/`.
> Append-only. See `skills/start-address-review/SKILL.md` for the pipeline.

## Iteration <N> — <ISO 8601 timestamp>

**PR**: <url>
**Threads fetched**: <n> (inline: <m>, PR-level: <k>, skipped: <reasons summary>)
**Verdict**: ALL_RESOLVED | AWAITING_VERIFY | PENDING_REVIEWER | PENDING_USER

### Thread #<id> — <author>

- **Location**: `<file:line>` or `PR-level`
- **Comment**:
  > <reviewer comment verbatim, including any code snippets or quotes>

- **Verifier** (forked subagent, `general-purpose`):
  - Verdict: VALID | INVALID | NEED_MORE_INFO
  - Reasoning: <one paragraph — why the reviewer is or isn't correct, grounded in file:line or spec/contract reference>
  - Evidence: `<file:line>`, `<file:line>`
  - Counter-points (if INVALID): <text with citations>
  - Clarification needed (if NEED_MORE_INFO): <the specific question that would resolve the ambiguity>

- **Triage**: AGREE | DISAGREE | CLARIFY
  - Override reasoning (if verifier verdict overridden): <text — required when triage does not match verifier>

- **Action plan**:
  - For AGREE: <what changes, which files, behavior (TDD) or doc>
  - For DISAGREE: <rebuttal summary>
  - For CLARIFY: <the clarifying question>

- **Implementation** (AGREE only):
  - Commit: `<SHA>` — `<commit subject>`
  - Re-verify: `docs/sessions/<session>/verify.md` iteration <M> — verdict <PASS>

- **Reply draft**:
  > <full text of the reply that will be posted on user approval>

- **Reply status**:
  - Drafted: yes
  - User-approved: yes | no (pending) | edited (<details>)
  - Posted: yes (<url>) | no
  - Posted-at: <ISO timestamp or "n/a">

- **Thread status**: RESOLVED | AWAITING_VERIFY | AWAITING_USER | AWAITING_REVIEWER | ERRORED

### Thread #<id> — <author>

(...repeat per thread...)

---

## Iteration <N+1> — <ISO timestamp>

(triggered when the user re-invokes `/start-address-review` after new reviewer activity, pending-user items resolving, or CI finishing)

**PR**: <url>
**Threads fetched**: ...

### Thread #<new-id> — <author>

(a new comment from this round)
...
```

## Thread status reference

| Status | Meaning |
|---|---|
| `RESOLVED` | Fix committed, verify PASS, reply posted, reviewer hasn't reopened |
| `AWAITING_VERIFY` | Fix committed locally but `/start-verify` not yet re-run with PASS verdict |
| `AWAITING_USER` | Draft exists but user hasn't approved yet, OR override reasoning needed |
| `AWAITING_REVIEWER` | Rebuttal or clarifying question posted, waiting for reviewer's response |
| `ERRORED` | Something went wrong (verify failed, gh post errored, etc.); see notes in the entry |

## Iteration verdict reference

| Verdict | Condition | What the user should do next |
|---|---|---|
| `ALL_RESOLVED` | Every thread this iteration is RESOLVED | Run `/start-ship` to resume toward merge |
| `AWAITING_VERIFY` | At least one thread is AWAITING_VERIFY (AGREE fixes committed locally, verify not yet PASS) | Run `/start-verify` locally; when the new iteration is PASS, re-invoke `/start-address-review` |
| `PENDING_USER` | At least one thread is AWAITING_USER | User edits drafts or provides override reasoning; re-invoke |
| `PENDING_REVIEWER` | At least one thread is AWAITING_REVIEWER | Pause. Re-invoke when reviewer responds or a new review round arrives |
