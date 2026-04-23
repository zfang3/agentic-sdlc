---
name: start-ship
description: Create a PR from the current branch, wait for CI, address review feedback, and merge. Use after /start-verify passes and the change is ready for review. Orchestrates the whole PR lifecycle.
category: sdlc
disable-model-invocation: true
allowed-tools: Bash(git *) Bash(gh *)
---

# Ship

## Overview

The full PR lifecycle: create (or update) the PR, wait for CI, address review feedback, merge. Runs from the current branch after `/start-verify` has passed. Each phase has clear exit criteria so nothing slips through.

The principle: **faster is safer.** Smaller changes and more frequent merges reduce risk, not increase it. A PR that's open for three days accumulates merge conflicts and context loss.

## Prerequisite

- `/start-verify` ran and the **latest iteration** in `docs/sessions/<session>/verify.md` shows verdict `PASS` — or `PASS_WITH_CONCERNS` only if the user has explicitly accepted the remaining concerns on record inside the session
- Every contract item in that iteration is ✓ (or EXCLUDED with rationale from the contract's `## Declared exclusions`)
- The latest verify iteration is newer than the latest commit on this branch (a stale verify is a claim, not an artifact)
- If `docs/sessions/<session>/address-review.md` exists, its latest iteration's verdict is `ALL_RESOLVED` (no pending threads, rebuttals, or clarifications)
- Current branch has commits ahead of main
- All changes are committed (no uncommitted work)

If the latest verify iteration is `NEEDS_FIXES`, `FAIL`, or stale — or if any contract item shows `FAIL` or `ERROR` without a matching declared exclusion — tell the user and stop. Do not ship against a partial or failing contract; that's shipping claims, not verified artifacts.

If review threads are open (latest address-review iteration isn't `ALL_RESOLVED`), stop and tell the user to run `/start-address-review`. Do not merge around open threads.

## The Process

### Phase 0 — Read project conventions and preflight

First, read `docs/skills/start-ship.md` if present. Its contents are additional project guidance for this skill (PR body template, merge strategy, required approvers, post-merge actions). Follow them alongside the defaults below.

If the file is missing or only contains the stub template, tell the user:

> No project conventions declared at `docs/skills/start-ship.md`. Proceeding with built-in defaults. Run `/start-sync` to scaffold a stub if your team wants to capture conventions.

Then check the working tree:

```
git status --short              # must be empty
git log --oneline main..HEAD    # must have ≥1 commit
git rev-parse --abbrev-ref HEAD # must not be main
```

Then check the verify state — read the latest `## Iteration N — <timestamp>` section in `docs/sessions/<session>/verify.md`:

- Verdict must be `PASS` (or `PASS_WITH_CONCERNS` only with explicit recorded acceptance)
- Every gate, task artifact, and cross-task assertion must be ✓ or `EXCLUDED` with a rationale linking to the contract
- Iteration timestamp must be after the latest commit on this branch — otherwise the verify is stale

Then check the address-review state (if any reviews have happened):

- If `docs/sessions/<session>/address-review.md` does not exist: no reviews yet, proceed.
- If it exists, read the latest `## Iteration N — <timestamp>` section. The verdict must be `ALL_RESOLVED` to proceed. If it is `AWAITING_VERIFY`, `PENDING_USER`, or `PENDING_REVIEWER`, stop and tell the user what to do to close it out (run `/start-verify`, approve drafts, or wait for reviewer respectively), then re-invoke `/start-address-review`.

Fail fast with a specific message if any check fails. Do not paper over by invoking `/start-verify` or `/start-address-review` inline; tell the user what is missing and let them run it explicitly so they see the evidence.

### Phase 1 — Create or update the PR

```
gh pr view --json number,state,url 2>/dev/null
```

**If no PR exists:**

```
git push -u origin HEAD
gh pr create --draft
```

Use the project's PR template if one exists at `.github/pull_request_template.md`. Fill in from the spec + plan:

- **Summary**: 1-3 bullet points from the spec
- **Acceptance criteria**: from the spec (checked off per contract execution)
- **Test plan**: from the plan
- **Verification**: quote the latest verify iteration's verdict and review score, plus the list of contract items (all ✓ or `EXCLUDED` with rationale). Link to `docs/sessions/<session>/verify.md` and `docs/sessions/<session>/verification.md`.
- **Breaking changes**: if any (from spec non-goals / architecture)
- **Deployment notes**: if infra changed

**If a draft PR exists:**

```
git push origin HEAD
gh pr edit <n> --body "<updated body>"
```

Update the body to reflect the latest state.

**If a ready PR exists** and you're re-shipping after addressing review:

```
git push origin HEAD   # pushes new commits; review-comment thread stays open
```

Skip to Phase 3 (wait for CI) — no body changes unless significant scope changed.

### Phase 2 — Mark ready for review (if still draft)

Ask the user first:

> PR is in draft. Mark it ready for review? (The reviewers you'll tag
> can be chosen now or left to the PR template.)

On confirmation:

```
gh pr ready <n>
```

If a reviewer group is known (e.g. from a `CODEOWNERS` file or the project's contribution docs), request review:

```
gh pr edit <n> --add-reviewer <user-or-team>
```

### Phase 3 — Wait for CI

Poll every 60 seconds, up to 20 minutes (20 iterations):

```
gh pr checks <n> --json name,state,bucket
```

Classify results:

- All checks have `bucket: "pass"` → **ALL_PASS**
- Any check has `bucket: "fail"` → **HAS_FAILURES**
- Any check has `bucket: "pending"` → **STILL_RUNNING** (keep polling)

Print a status line each iteration:

```
[3/20] 4 checks running, 2 passed...
```

**If ALL_PASS**: proceed to Phase 4.

**If HAS_FAILURES**:
- Capture the failing check names and their URLs
- Report to the user:
  - Fix and re-push (re-run `/start-ship`)
  - Investigate with `/start-debug`
  - Override and continue (rare, asks for confirmation)

**If TIMEOUT**:
- Ask: keep waiting, proceed anyway, or re-request review after manual CI check

### Phase 4 — Delegate to `/start-address-review`

After CI passes, check for unresolved reviewer activity:

```
gh pr view <n> --json reviews,comments
gh api repos/:owner/:repo/pulls/<n>/comments --jq '[.[] | select(.in_reply_to_id == null)] | length'
```

If zero unresolved threads, skip to Phase 5 (Merge).

If any unresolved thread exists, **stop**. `/start-ship` does not handle review feedback inline — addressing reviews has its own pipeline (verifier subagent per thread, triage, fix-or-rebut-or-clarify, batched reply drafting, append-only session log). Tell the user:

> `<N>` unresolved review thread(s) on PR #`<n>`. Run `/start-address-review` to process them. That skill will fetch, verify each with a forked subagent, triage, fix with TDD, re-run `/start-verify`, draft replies, and post on your approval. It appends an iteration to `docs/sessions/<session>/address-review.md`.
>
> When `/start-address-review` returns with verdict `ALL_RESOLVED`, re-run `/start-ship` to continue toward merge.

Exit `/start-ship` here. Do not partially process threads, do not merge, do not advance phases. The next `/start-ship` invocation will re-enter Phase 0 preflight (verify state fresh, CI green, address-review log's latest iteration = `ALL_RESOLVED`) and either advance to Phase 5 or re-delegate if new threads arrived.

**Why the delegation**: `/start-address-review` runs the full uniform pipeline for every thread — nit, bug, rebuttal, clarification. Inlining that pipeline here would duplicate ~300 lines of skill logic and encourage shortcuts that branch the process by perceived size. Separation keeps `/start-ship` focused on the PR → CI → merge lifecycle and lets address-review own its rhythm (which is iterative — multiple review rounds land over a PR's lifetime).

### Phase 5 — Merge

Only merge after:
- CI passes
- All review threads resolved or the user explicitly accepted deferred items
- Approval count meets the project's policy (check branch protection if unclear)

Merge strategy: follow the project's convention. Default to squash merge:

```
gh pr merge <n> --squash --delete-branch
```

After merge:

```
git checkout main
git pull
```

### Phase 6 — Post-merge

1. Confirm the merge is visible on main.
2. Suggest the next step:

> PR #<n> merged. Next: `/start-sync` if the change affected docs, or start the next
> ticket with `/start-plan <next>`.

3. Ask if the user wants to run `/start-sync` now.

## Error handling

### CI fails persistently

After two fix-push-wait cycles that still fail:
- Ask the user whether to keep iterating or stop
- Consider that the plan may be wrong, not the implementation

### Reviewer requests significant scope change

If a reviewer asks for something the spec doesn't cover:
- Treat as a spec change — stop shipping
- Return to `/start-spec` to update the spec first
- Re-run `/start-plan` for the new scope
- Then re-run `/start-build`

Don't silently expand scope to satisfy a review.

### Merge conflict

If the PR has conflicts:
- Rebase on main: `git pull --rebase origin main`
- Resolve conflicts
- Force-push (only on your own branch): `git push --force-with-lease`
- Or merge main into the PR branch if the team prefers merge commits

Conflicts should be rare if PRs are small and short-lived.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll skip /start-verify, it's just a small change" | Small changes break things. /start-verify is the artifact gate. |
| "The last verify iteration was NEEDS_FIXES but I cleaned that up" | Re-run `/start-verify`. Cleanup that hasn't been re-verified is a claim, not an artifact. The latest iteration is what gates the ship. |
| "One contract item FAILed but it's unrelated to this PR" | If it's unrelated, it belongs under `## Declared exclusions` in the contract with rationale — amend the plan. If it's related, it blocks shipping. Either way not shippable as-is. |
| "Verify was green yesterday, branch hasn't meaningfully changed" | "Meaningfully" is a claim. If any commit landed after the latest verify iteration, run it again. |
| "I'll reply to the review comments after merging" | Review replies gate the merge. Posting replies is part of `/start-address-review`'s pipeline; skipping them means the address-review log isn't `ALL_RESOLVED` and `/start-ship` won't proceed. That's by design. |
| "I'll inline a quick fix for this one nit instead of going through `/start-address-review`" | Uniform pipeline for every comment. Inline fixes skip the verifier fork, the log entry, and the reply draft — exactly the discipline `/start-address-review` enforces. |
| "I'll merge without review, nobody else is available" | Then wait, or ask the team. Merging unreviewed code is how regressions ship. |
| "The CI flake is unrelated, override" | Flakes hide real issues. Investigate first. |
| "I can address review after merging" | Reviewer will close future PRs if you don't respect theirs. Fix before merge. |
| "Force-merge to main, we're in a hurry" | Emergencies have a process (hotfix, cherry-pick). Bypassing review should be explicit and rare. |
| "Squash loses history" | Individual commits are already in the branch history; squash keeps main clean. Use what the team prefers. |
| "I'll reply to review comments later" | Review threads without replies accumulate. Reply same-day, even if the reply is "will address in follow-up PR #N". |

## Red Flags

- Shipping without `/start-verify`
- Shipping when the latest verify iteration is `NEEDS_FIXES` or `FAIL`
- Shipping while any contract item shows `FAIL` or `ERROR` without a matching declared exclusion
- Shipping with a verify iteration older than the latest commit on the branch
- Shipping while the latest address-review iteration is `AWAITING_VERIFY`, `PENDING_USER`, or `PENDING_REVIEWER`
- Handling any review comment inline inside `/start-ship` instead of delegating to `/start-address-review`
- Force-pushing to main
- Merging with CI failing (`--admin` override)
- Ignoring review comments
- Silently expanding scope during review fixes
- Opening a PR with no description / empty body
- Mixing unrelated changes in the PR (split it)
- Pushing direct to main instead of going through PR

## Verification

At each phase:

- [ ] Phase 0: working tree clean, on feature branch
- [ ] Phase 1: PR exists with a filled-in body
- [ ] Phase 2: PR ready for review (if user confirmed)
- [ ] Phase 3: CI passed (all green, no pending)
- [ ] Phase 4: every review thread addressed or explicitly deferred
- [ ] Phase 5: merge succeeded, branch deleted
- [ ] Phase 6: working tree back on main, up to date
