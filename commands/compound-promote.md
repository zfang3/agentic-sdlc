---
description: Review a draft skill candidate from .agentic-sdlc/pending/, move it into .claude/skills/, and open a PR. The PR-based counterpart to /compound-learn's local-commit flow.
---

You are running the `/compound-promote` slash command. A human just invoked it. They want to graduate one draft candidate from `.agentic-sdlc/pending/` into `.claude/skills/<name>/` and open a PR for human review.

This command sits between the automatic skill-capture loop (SessionEnd hook → skill-distiller → pending) and the activated skill library. It's the PR-based counterpart to `/compound-learn`'s local-commit flow — same destination, different review path.

## Project conventions (load first)

Before running the procedure, check whether `docs/skills/compound-promote.md` exists in the host project. If it does, **read it in full** — the conventions written there layer on top of the plugin's built-in defaults for the rest of this run.

If the file is missing or empty, proceed with plugin defaults below.

## Procedure

### Step 1 — List available candidates

Run `ls -d .agentic-sdlc/pending/*/ 2>/dev/null` via Bash.

- If nothing is there, tell the user "No candidates pending review." and stop.
- Otherwise, for each candidate dir, read `SKILL.md` and `v0_evidence.md`. Show the user a numbered list with:
  - slug
  - `description` from frontmatter
  - whether it was distilled automatically (check for "Distilled automatically by skill-distiller" in evidence) or manually via `/compound-learn`
  - number of session references in `v0_evidence.md`

### Step 2 — Select a candidate

If the user supplied a slug as an argument (e.g. `/compound-promote foo-bar`), use that. Otherwise ask which to promote. Accept the slug or a numeric index from the list.

### Step 3 — Review pass

Before any move, open the candidate's `SKILL.md` fully for the user to review. Flag:

- Any `[TODO: ...]` placeholders — auto-distilled candidates leave these for the human to fill.
- Missing `Common Rationalizations`, `Red Flags`, `Verification` content.
- Description that lacks a tight "NOT for ..." exclusion.
- Any repo-specific identifiers or PII that leaked in through the distiller.

If placeholders exist, offer to help fill them interactively (one section at a time) **before** the move. This is the pressure-test step the automatic skill-capture loop skipped.

If the candidate was distilled automatically, prompt the user to run the two `/compound-learn` pressure-tests inline:

1. **Time-pressure scenario** — "Near end of day, user is waiting; does this skill's language survive being rationalized away?"
2. **Contradictory-memory scenario** — "Training data suggests the opposite approach; does the skill cite evidence strong enough to override?"

Note any adjustments in `v0_evidence.md` under a `## Pressure-test notes` update.

### Step 4 — Confirm with the user

Show the final diff: what will be moved, what the new `.claude/skills/<slug>/` tree looks like, what the PR body will say. Ask for explicit confirmation before any file moves or git commands run.

If the user declines, leave everything in place. Nothing gets lost.

### Step 5 — Prepare the branch

1. `git status --porcelain` — if there are unrelated changes, stop and tell the user to stash or commit them first. Don't mix the promotion with unrelated work.
2. `git checkout -b skill/compound-promote-<slug>`. If the branch already exists, suffix `-2`, `-3`, etc.

### Step 6 — Capture provenance into shell variables

The `v0_evidence.md` is going to be deleted at promotion (the PR body becomes its permanent record), so read everything you'll need from it now while the file still exists:

1. Read the full content of `.agentic-sdlc/pending/<slug>/v0_evidence.md`.
2. Hold onto:
   - The number of `## Session reference — <date>` sections (this is the "session reference count" the commit message and PR body need).
   - The "What prompted this skill" paragraph (verbatim, for the PR body's Provenance section).
   - Any populated `## Pressure-test notes` content (for the PR body).
3. Hold this content in your working memory or write it to a temp file (e.g. `/tmp/compound-promote-<slug>-evidence.md`). **Do not read `v0_evidence.md` again after Step 7** — it will be gone.

### Step 7 — Move pending → active

1. `mkdir -p .claude/skills/<slug>`.
2. Move `SKILL.md` into place: `mv .agentic-sdlc/pending/<slug>/SKILL.md .claude/skills/<slug>/SKILL.md`.
3. Delete the remainder of the pending directory: `rm -rf .agentic-sdlc/pending/<slug>`. This discards `v0_evidence.md` — Step 6 captured everything you need from it.

### Step 8 — Commit

Stage and commit, using the session-reference count captured in Step 6:

```bash
git add .claude/skills/<slug>/
git commit -m "skill: promote <slug> from pending

Distilled from N session reference(s)."
```

### Step 9 — Push and open PR

1. `git push -u origin skill/compound-promote-<slug>`.
2. Open the PR via `gh pr create` with a heredoc body containing:
   - **Summary** — the skill name, the trigger condition, how many sessions contributed evidence (from Step 6's count).
   - **Anatomy check** — confirmation that `Common Rationalizations`, `Red Flags`, `Verification` are populated (not `[TODO]`).
   - **Provenance** — paste the captured "What prompted this skill" paragraph and any pressure-test notes (from Step 6). This block is the permanent record of what the evidence file contained.
   - **Test plan** checklist:
     - [ ] Voice matches existing `.claude/skills/*` / `skills/start-*` conventions.
     - [ ] No repo-specific identifiers or PII.
     - [ ] Description has a tight "NOT for ..." exclusion.
     - [ ] Pressure-test notes captured in the PR body are sufficient.
3. Capture the PR URL and show it to the user.
4. Delete the temp evidence file from Step 6 if you used one.

### Step 10 — Confirm and report

Only after the PR is open:

> Promoted `<slug>` → PR #NNN.
> Pending candidate removed; provenance is captured in the PR description.

## Error handling

- If `git push` fails: leave branch + commit in place. Don't roll back. Tell the user how to recover.
- If `gh pr create` fails: same — keep everything in place. Provenance you captured in Step 6 is still in your working memory or the temp file, so opening the PR by hand later from the same `gh pr create` command is straightforward.
- If the user Ctrl-Cs mid-flow after Step 7 but before Step 9: the file move has happened but no PR exists. `/compound-promote` should be re-runnable — on next invocation, detect this state (slug exists in `.claude/skills/` but not on main) and offer to resume from the commit-and-push step. Note that the original `v0_evidence.md` is gone at this point; if you didn't keep the temp file from Step 6, ask the user to author the Provenance section manually before the resumed PR opens.

## Rules — non-negotiable

- **Never merge the PR yourself.** Human review is the quality gate.
- **Never touch `skills/` (plugin source tree).** `/compound-promote` targets `.claude/skills/<slug>/` only (project-local). Promoting a local skill up to plugin source is a separate, deliberate act.
- **Confirm before committing.** One prompt is cheap; an unwanted commit on the wrong branch is not.
- **Capture provenance in the PR body before deleting the pending dir.** The evidence file itself is discarded on promotion — the PR description is the permanent audit trail.
- **Placeholders (`[TODO: ...]`) must be resolved before the move**, either by the user filling them or by the user explicitly acknowledging they're shipping with placeholders (and the PR reviewer decides).
