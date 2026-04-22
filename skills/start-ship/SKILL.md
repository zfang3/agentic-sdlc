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

- `/start-verify` has passed recently (score 90+) — check `docs/sessions/<session>/verify.md`
- Current branch has commits ahead of main
- All changes are committed (no uncommitted work)

If verify hasn't run or score is below threshold, tell the user and stop. Don't ship unverified work.

## The Process

### Phase 0 — Preflight

Check the working tree:

```
git status --short              # must be empty
git log --oneline main..HEAD    # must have ≥1 commit
git rev-parse --abbrev-ref HEAD # must not be main
```

Fail fast with a specific message if any check fails.

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
- **Acceptance criteria**: from the spec (checked off per verification)
- **Test plan**: from the plan
- **Verification**: quote verify.md score and findings summary
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

### Phase 4 — Handle review feedback (if any)

After CI passes, check for reviewer activity:

```
gh pr view <n> --json reviews,comments
```

If there are unresolved review threads, don't merge. Address them:

#### 4a — Collect feedback

Fetch all open review threads and PR-level comments. Filter out:
- Resolved threads
- Outdated threads (pointing at code that's since changed)
- Author's own comments
- Bot comments (unless they flag something)

#### 4b — Triage each finding

| Category | Action |
|---|---|
| **CODE_FIX** | Needs a code change — full pipeline |
| **DOC_FIX** | Needs a doc change — full pipeline (smaller scope) |
| **QUESTION** | Draft a factual answer from the code |
| **DISCUSSION** | Needs human judgment — surface to user |

For CODE_FIX / DOC_FIX:
1. Read the cited file(s) to understand current state
2. Plan the fix (what exactly to change)
3. Apply the fix (follow `/start-build` TDD if it's code)
4. Commit with message `fix: address review feedback on <topic>`

For QUESTION:
1. Research the answer from actual code (not memory)
2. Draft a reply
3. Show user for approval before posting

For DISCUSSION:
1. Surface to user with the reviewer's comment quoted
2. Wait for user direction
3. Convert to CODE_FIX / QUESTION based on direction, or mark "will discuss offline"

#### 4c — Push fixes

After addressing all non-DISCUSSION items:

```
git push origin HEAD
```

Return to Phase 3 (wait for CI).

#### 4d — Post replies

After user approval:

```
gh pr review <n> --comment --body "<reply text>"
# OR reply to specific thread:
gh api repos/:owner/:repo/pulls/:n/comments/:id/replies -f body="<reply>"
```

#### 4e — Re-request review

```
gh pr edit <n> --add-reviewer <user>
```

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
| "I'll merge without review, nobody else is available" | Then wait, or ask the team. Merging unreviewed code is how regressions ship. |
| "The CI flake is unrelated, override" | Flakes hide real issues. Investigate first. |
| "I can address review after merging" | Reviewer will close future PRs if you don't respect theirs. Fix before merge. |
| "Force-merge to main, we're in a hurry" | Emergencies have a process (hotfix, cherry-pick). Bypassing review should be explicit and rare. |
| "Squash loses history" | Individual commits are already in the branch history; squash keeps main clean. Use what the team prefers. |
| "I'll reply to review comments later" | Review threads without replies accumulate. Reply same-day, even if the reply is "will address in follow-up PR #N". |

## Red Flags

- Shipping without `/start-verify`
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
