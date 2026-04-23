---
name: start-address-review
description: Address every open review thread on the current PR — fetch, verify each with a forked subagent, triage (AGREE / DISAGREE / CLARIFY), implement fixes with TDD, re-run the session's verification contract, draft replies, and post on user approval. Appends iterations to docs/sessions/<session>/address-review.md. Use after a review arrives or when `/start-ship` Phase 4 detects open threads.
category: sdlc
disable-model-invocation: true
allowed-tools: Bash(git *) Bash(gh *)
---

# Address Review

## Hard gate

```
Every review thread goes through the full pipeline: fetch → forked verifier → triage →
fix-or-rebut-or-clarify → (if fixed) re-run verification contract → reply draft →
user-approved post → log entry. No shortcuts for "nit" or "trivial" comments. One
path, no branches — uniform pipeline is the whole point.
```

## Overview

Owns the review-response phase of the SDLC. `/start-ship` stops at Phase 4 when open threads exist and hands off here. This skill fetches every unresolved thread, forks a verifier subagent per thread to check whether the reviewer's concern is valid against the spec / plan / contract / code, triages each into AGREE / DISAGREE / CLARIFY, implements fixes for AGREE items via TDD, re-runs `/start-verify` once after all fixes land, drafts replies for every thread, and posts on user approval. Every step is captured to `docs/sessions/<session>/address-review.md` as an append-only iteration log.

The principle: **every review thread is evidence to verify, not a directive to obey.** Reviewers are sometimes wrong. The forked verifier grounds triage in artifact + spec + contract, not author reflex. DISAGREE with evidence is a first-class outcome, not an awkward exception.

## Prerequisite

- Current branch has an open PR (`gh pr view` succeeds)
- Session directory at `docs/sessions/<YYYY-MM-DD>-<slug>/` contains `spec.md`, `plan.md`, `verification.md`
- Most recent `verify.md` iteration exists and was PASS — if not, the PR should not have reached review
- `docs/architecture/verification.md` still resolves every primitive the contract references

If any is missing, refuse and tell the user exactly what to run (`/start-plan`, `/start-verify`, `/start-ship` to create the PR).

## When to Use

- A reviewer (human or bot) has left comments on an open PR
- Re-entering after addressing a previous round when new comments have arrived
- Invoked by the user after `/start-ship` Phase 4 detected open threads and stopped

**When NOT to use:**

- PR has zero unresolved comments — return immediately with verdict `ALL_RESOLVED` and point the user back to `/start-ship`
- No open PR — use `/start-ship` to create one first
- The feedback is from the author to themselves during self-review — use `/start-review` or handle inline

## The Process

Runs in nine phases. Phase 2 forks one subagent per thread for isolated verification.

### Step 0 — Read project conventions

Read `docs/skills/start-address-review.md` if present. Its contents are additional project guidance for this skill (review-response tone, rebuttal style, who to CC on specific threads, labels to use). Follow them alongside the defaults below.

If the file is missing or only contains the stub template, tell the user:

> No project conventions declared at `docs/skills/start-address-review.md`. Proceeding with built-in defaults. Run `/start-sync` to scaffold a stub if your team wants to capture conventions.

Then proceed to Phase 1.

### Phase 1 — Fetch open review threads

```
gh pr view <n> --json number,headRefName,url
gh api repos/:owner/:repo/pulls/<n>/comments        # inline review comments
gh api repos/:owner/:repo/issues/<n>/comments       # PR-level discussion comments
gh pr view <n> --json reviews                       # review-level state
```

Filter the raw list:

- Skip threads marked resolved in GitHub's thread state
- Skip outdated threads (anchor line no longer exists in the diff)
- Skip bot comments unless flagged by the user or the bot is on an approved-signal list for this project (see `docs/skills/start-address-review.md` if declared)
- Skip the author's own comments

Open or append the log at `docs/sessions/<session>/address-review.md` with a new `## Iteration <N>` section following [address-review-log-template.md](references/address-review-log-template.md). Record every remaining thread's ID, author, location (file:line or PR-level), full comment text, and parent thread/reply chain.

If zero threads remain, write the iteration's verdict as `ALL_RESOLVED` and exit — tell the user `/start-ship` can resume.

### Phase 2 — Verify each thread (forked subagent per thread)

For every thread, fork a `general-purpose` subagent with these inputs:

- The reviewer's comment verbatim
- The cited file(s) + surrounding context (for file:line comments); full file(s) for PR-level comments
- `docs/sessions/<session>/spec.md`
- `docs/sessions/<session>/plan.md`
- `docs/sessions/<session>/verification.md`
- Latest iteration from `docs/sessions/<session>/verify.md`
- `docs/architecture/overview.md`
- `docs/architecture/verification.md`
- `git diff main...HEAD` for change context

Ask the subagent to return a structured verdict — NOT a fix proposal:

```json
{
  "verdict": "VALID" | "INVALID" | "NEED_MORE_INFO",
  "reasoning": "<one paragraph — why the reviewer is or isn't correct, grounded in file:line or spec/contract reference>",
  "evidence": ["<file:line>", "<file:line>"],
  "counter_points": "<if INVALID: the strongest counter-argument with citations>",
  "clarification_needed": "<if NEED_MORE_INFO: the specific question that would resolve the ambiguity>"
}
```

Forking protects triage from author reflex. The subagent reads fresh; it doesn't know what the author intended. Append each verdict into the log under the corresponding thread entry.

### Phase 3 — Triage each thread

Default triage maps directly from the verifier verdict:

- `VALID` → **AGREE** (fix needed)
- `INVALID` → **DISAGREE** (rebuttal needed)
- `NEED_MORE_INFO` → **CLARIFY** (question to reviewer)

The author MAY override the verifier. Overrides are allowed but must be recorded in the log with reasoning:

> Thread #342 — verifier said INVALID; author triages as AGREE. Reason: the verifier did not have access to internal launch timeline; reviewer is correct that this is shippable before the timeline lands.

Overrides without reasoning are the silent-default failure mode. Refuse to proceed if any override lacks written rationale.

### Phase 4 — Plan actions per triage

For each thread, plan the specific action:

| Triage | Action plan |
|---|---|
| **AGREE** | Name the fix: what changes, which files, is it behavior (TDD required) or doc (no test). Cite the spec AC or contract item that the fix restores or preserves. |
| **DISAGREE** | Draft the rebuttal body: restate the reviewer's concern fairly, cite the verifier's counter-points + concrete evidence (file:line, spec AC, contract item), offer to discuss if they still disagree. Avoid dismissiveness. |
| **CLARIFY** | Draft the question: state what's unclear, what information would resolve it, and what the author currently infers so the reviewer can correct if needed. |

Append every plan to the log.

### Phase 5 — Implement AGREE fixes

For each AGREE item, make the change:

- **Code change** → follow `/start-test` TDD inline: write a RED test that encodes the reviewer's concern as a test, watch it fail, apply the GREEN fix, refactor if needed. The RED test is evidence the reviewer's concern is real and the fix addresses it.
- **Doc change** → edit the doc directly. If the change affects `docs/architecture/overview.md` or any `docs/skills/*.md`, note that `/start-sync` will re-verify consistency on the next run.

Commit per thread (or group closely related threads in one commit) with the message shape:

```
fix: address review thread #<id> — <short summary>

Reviewer (<author>): <one-sentence paraphrase of concern>
Plan: docs/sessions/<session>/plan.md task N (if relevant)
Contract: docs/sessions/<session>/verification.md → <artifact path, if produced>
Log: docs/sessions/<session>/address-review.md iteration <N>
```

Do not push yet — push happens after Phase 6.

Append each commit SHA to its thread entry in the log.

### Phase 6 — If AGREE fixes were committed, stop for re-verification

If Phase 5 committed zero fixes (all threads were DISAGREE or CLARIFY), skip this phase and proceed to Phase 7.

If Phase 5 committed one or more fixes, stop this invocation. The commits are local only — not yet pushed. Tell the user:

> <N> fix commit(s) landed locally on the current branch for this review round. Before drafting replies, run `/start-verify` — it will append a new iteration to `docs/sessions/<session>/verify.md`. When the new iteration's verdict is `PASS`, re-invoke `/start-address-review` and it will resume at Phase 7 (draft replies) with the new verify evidence attached.

Set the current iteration's verdict to `AWAITING_VERIFY` in the log. Do NOT close the iteration — the next invocation continues the same `## Iteration N` section rather than starting a new one.

On re-invocation, detect the resume state before Phase 1:

- If the latest `verify.md` iteration is `PASS` AND its timestamp is after the AGREE fix commits → resume at Phase 7 within this iteration. Record the verify-iteration number in each AGREE thread's log entry so reviewers can trace reply → commit → verify evidence.
- If the latest `verify.md` iteration is `FAIL` or `NEEDS_FIXES` → tell the user to address the verify findings (possibly via `/start-debug`), run `/start-verify` again, then re-invoke `/start-address-review`.
- If no new verify iteration exists (timestamp ≤ fix commits) → remind the user to run `/start-verify` first.

A new `## Iteration N+1` section is only created when genuinely new review activity arrives after a verdict was written. AWAITING_VERIFY means the same review round is still open.

### Phase 7 — Draft replies for every thread

Every thread gets a draft reply, not just AGREE ones:

- **AGREE**: "Fixed in `<commit SHA>` — `<one-sentence summary>`. Verify iteration `<M>` covers this change: `docs/sessions/<session>/verify.md`." Optionally offer to elaborate.
- **DISAGREE**: rebuttal text from Phase 4. End with "If I'm missing context, happy to discuss further."
- **CLARIFY**: the clarifying question from Phase 4. End with "I'll hold on the rest of the thread until we're aligned here."

Append each draft to the log under its thread entry.

### Phase 8 — Push fixes, show drafts to user, post on approval

Push the fix commits:

```
git push origin HEAD
```

Then present all reply drafts to the user in one shot — no trickle, no per-thread approval prompts that fragment the review:

```
Iteration <N> — <K> threads

Thread #<id> (<author>, AGREE):
  <reply draft>

Thread #<id> (<author>, DISAGREE):
  <reply draft>

Thread #<id> (<author>, CLARIFY):
  <reply draft>

Approve? (all / select / edit / none)
```

On approval, post via `gh`:

```
# Inline thread reply
gh api repos/:owner/:repo/pulls/<n>/comments/<thread_id>/replies \
  -f body='<reply>'

# PR-level comment
gh pr comment <n> -b '<reply>'
```

Record `posted_url` or `posted_at` per reply in the log. Drafts the user declined to post stay in the log; a follow-up invocation picks them up.

### Phase 9 — Decide exit state

Write the iteration's overall verdict at the top of the section:

| Verdict | Meaning | Next step |
|---|---|---|
| `ALL_RESOLVED` | Every thread triaged, fixed/rebutted/clarified, replied, posted. No reviewer response pending. | Tell user `/start-ship` can resume toward merge. |
| `AWAITING_VERIFY` | AGREE fixes committed locally, `/start-verify` not yet re-run (or last iteration not PASS). | Tell user to run `/start-verify`; re-invoke `/start-address-review` when the new iteration is PASS. |
| `PENDING_REVIEWER` | DISAGREE/CLARIFY threads waiting for reviewer to respond. | Pause. User re-invokes `/start-address-review` when reviewer replies or a new review round arrives. |
| `PENDING_USER` | Some reply drafts un-approved or need user input (e.g. an override lacks written reasoning). | User edits drafts or provides direction; re-invoke. |

Never merge from this skill — merging is `/start-ship`'s job.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "This nit doesn't need the full pipeline" | Uniform pipeline is the point. The ten-second nit goes through the same flow as the architectural disagreement; branching the process by perceived size is where discipline erodes. |
| "The reviewer is clearly right, skip the verifier fork" | You're right 80% of the time. The 20% — accepting a wrong reviewer "suggestion" — produces regressions the spec explicitly rejected. Fork every time. |
| "I'll just agree to move the PR along" | Sycophantic agreement is a failure mode. If the verifier says INVALID and you have evidence, draft the rebuttal. Merging a worse change to avoid friction is technical debt with social debt on top. |
| "Rebuttals are rude" | Politely-worded rebuttals with evidence are how teams build shared understanding. Agreeing to bad suggestions is the rude act — it wastes everyone's time later. |
| "Reply after fixing, not per-thread" | Every thread gets an explicit reply, even a one-liner. Unreplied threads look ignored and reviewers re-litigate. |
| "Post replies as I approve them, not in one batch" | Batched-approval is a discipline: you see the full shape of the response before it lands. One-at-a-time encourages approving-to-finish. |
| "Skip the verify re-run, the fix is obvious" | The fix that looks obvious broke the contract 30% of the time. Re-run verify. |
| "Overwrite the previous iteration, it's cleaner" | The log is append-only. Iterations are how you see whether a round of fixes actually resolved the thread or produced a new issue. |
| "DISCUSS category lets me punt" | There is no DISCUSS category. Every thread is AGREE, DISAGREE, or CLARIFY. "Let's discuss offline" is a CLARIFY reply draft, not a way to skip triage. |

## Red Flags

- Any triage override without written reasoning in the log
- Skipping the verifier fork for "simple" threads
- Posting a reply before the fix is committed and verify has passed
- Marking a thread resolved without a reply draft in the log
- Overwriting a previous iteration's section
- Invoking `/start-ship` to merge while the latest address-review iteration's verdict is not `ALL_RESOLVED`
- Rebuttals without evidence citations (counter-points must point at file:line, spec AC, or contract item)
- Replies that accept a concern the verifier found INVALID without documented author override
- "Resolve" clicks in GitHub that aren't paired with a recorded reply in the log
- Silently dropping a thread because it "looked resolved" — every thread needs explicit handling

## Verification

Before closing the iteration:

- [ ] Every open thread was fetched and appears in the iteration's log section
- [ ] Every thread has a verifier verdict with reasoning and evidence
- [ ] Every thread is triaged (no "TBD"); any override has written reasoning
- [ ] Every AGREE item has a commit SHA and a reference to the verify iteration that covers it
- [ ] `/start-verify` was re-run after all fixes; its iteration is recorded with verdict PASS
- [ ] Every thread has a reply draft in the log — even nits, even DISAGREEs the user hasn't approved yet
- [ ] User saw every draft in one batch and approved / edited / declined each explicitly
- [ ] Posted replies have their URLs or timestamps recorded
- [ ] The iteration's verdict (`ALL_RESOLVED` / `AWAITING_VERIFY` / `PENDING_REVIEWER` / `PENDING_USER`) is at the top of the section
- [ ] Next step communicated to the user based on verdict
- [ ] No merge performed (that is `/start-ship`'s job)
