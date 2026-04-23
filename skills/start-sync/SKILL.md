---
name: start-sync
description: Detect stale docs after code changes and propose fixes. Use before creating a PR, after merging a significant change, or when you notice drift between code and docs. Asks the user before making any doc edit.
category: sdlc
---

# Sync

## Overview

Reads recent changes, compares them to the project's documentation, and surfaces what's stale. The fix pattern is the article's principle: **when something is wrong, fix the doc, not the code.** Docs are loaded into every future session's context — a stale doc poisons the agent's assumptions until someone fixes it.

The principle: **the doc is the input; the code is the output.** If the agent keeps producing wrong output, don't patch the output. Update the doc it reads on startup.

## When to Use

- Before creating a PR, if the change affected architecture, APIs, or configuration
- After merging a significant change
- When you notice the agent making a mistake that the right doc would have prevented
- Periodically (monthly? per sprint?) to catch accumulated drift

**When NOT to use:**
- Tiny changes (bumping a dependency version, fixing a typo)
- Mid-implementation — wait until the change settles
- When docs don't exist yet — use `/start-bootstrap` first

## The Process

### Step 0 — Read project conventions

Read `docs/skills/start-sync.md` if present. Its contents are additional project guidance for this skill (freshness SLAs, priority docs, cadence, etc.). Follow them alongside the defaults below.

If the file is missing or only contains the stub template, tell the user:

> No project conventions declared at `docs/skills/start-sync.md`. Proceeding with built-in defaults. Fill the stub if your team has sync-specific conventions to capture.

Then proceed to Step 1.

### Step 1 — Gather the delta

```
git log --oneline main..HEAD           # commits to analyze
git diff main...HEAD --stat            # files changed
git diff main...HEAD --name-only       # raw file list
```

If on main (already merged), compare to the previous tag or a specific commit:

```
git log --oneline <prev-tag>..HEAD
```

### Step 2 — Read all docs

Read the contents of every file under `docs/` (including all `docs/skills/*.md`), plus `CLAUDE.md` if the project has one. Don't skim — actually read. You need to know what each doc claims so you can notice when it's wrong.

For large doc trees, fork to a `general-purpose` subagent with the instruction: "Read every file under docs/ and return a structured summary of claims each one makes about the code."

**Also check for missing conventions files**: for each SDLC skill (`start-spec`, `start-plan`, `start-build`, `start-test`, `start-debug`, `start-verify`, `start-review`, `start-simplify`, `start-ship`, `start-address-review`, `start-sync`), confirm `docs/skills/<name>.md` exists. If any is missing, add "scaffold missing conventions file" as a proposed fix in Step 4 — a gap here means the corresponding skill has been running with no opportunity for project-specific guidance.

### Step 3 — Identify drift

For each doc, compare its claims against the current code:

- **Wrong file paths** — docs reference files that have been renamed, moved, or deleted
- **Wrong type / field names** — docs describe a schema that has changed
- **Wrong nullability or defaults** — docs say a field is required when it isn't
- **Stale implementation statuses** — docs say "planned" for something that's been built
- **Missing new capabilities** — docs don't mention a feature that now exists
- **Removed capabilities still documented** — docs mention a feature that's been deleted
- **Outdated counts / totals / summaries** — "three event types" when there are now five
- **Outdated architecture descriptions** — the data flow diagram doesn't match reality
- **Broken cross-references** — links to other files that have moved or changed section names
- **Phantom dependencies** — docs claiming to depend on things that have been removed
- **Residual template placeholders** — docs that still contain `<angle-bracket>` markers, template-derived `TODO`s, or content byte-identical to a file in `templates/docs/` under the plugin root. Unfinished scaffolding from `/start-bootstrap` reads as authoritative while teaching the agent nothing.
- **Missing conventions file** — `docs/skills/<name>.md` is absent for an SDLC skill that ships with the plugin. Empty is fine (defaults apply); missing means the file was never scaffolded and the skill has no opportunity to absorb project-specific guidance.
- **Conventions referencing removed symbols** — a `docs/skills/*.md` file mentions files, functions, or patterns that have been renamed or removed. The skill will read stale guidance and potentially apply rules that no longer make sense.
- **Verification primitive drift** — commands in `docs/architecture/verification.md` that no longer exist (renamed binary, removed Makefile target, dropped dependency) or that have changed semantics (different default flags, different output format)
- **Missing runtime** — an open session's contract names a runtime (`## Runtime selection`) that is no longer defined in the project-level `## Runtime primitives`, or whose block has been renamed
- **Default runtime drift** — the project-level `Default runtime` points at a runtime that was renamed or removed from the `### Runtime:` sub-sections
- **Orphaned contract references** — an open session's `verification.md` that references primitives no longer present in the project-level primitives file (under the selected runtime or at the top-level gates)
- **Declared-assumption drift** — the project-level `## Declared assumptions` mention services, env files, or ports that have been restructured

For each issue found, note:

- **Doc file** — exact path
- **Claim** — what the doc says
- **Reality** — what the code actually does, with a file:line reference
- **Severity** — CRITICAL (misleads agent on every session), IMPORTANT (occasionally misleads), NIT (cosmetic drift)
- **Proposed fix** — specific text to change or add

### Step 4 — Present findings

Show the user a summary:

```markdown
## Sync findings

### CRITICAL (affects agent behavior on most sessions)

1. **docs/architecture/overview.md** — Core Concepts section references `UserProfile`
   class at `src/models/user.py:45`, but that class was renamed to `AccountProfile`
   in commit abc123. Agent will fail to find `UserProfile` on every session.
   **Fix**: rename `UserProfile` → `AccountProfile` throughout Core Concepts.

2. ...

### IMPORTANT

- **docs/product/roadmap.md** — Phase 2 is marked "in progress" but all its
  deliverables were merged last sprint.
  **Fix**: move Phase 2 to "complete" and promote Phase 3 to "in progress".

### NIT

- **docs/product/roadmap.md** — uses the old project code name in the "Status" section.

---

Would you like me to apply these fixes? (all / select / skip)
```

### Step 5 — Apply approved fixes

For each fix the user approves:

1. Read the target file
2. Make the minimal edit described in the fix
3. Re-read to confirm the edit looks right
4. DO NOT commit — let the user commit as part of their current work

Group all doc edits into one task so the resulting diff is coherent.

### Step 6 — Check the high-impact architecture docs specifically

Two files shape every session's behavior: `docs/architecture/overview.md` (loaded at the start of most SDLC skills) and `docs/architecture/verification.md` (loaded by `/start-plan` and `/start-verify`). Check each explicitly before declaring sync complete.

**overview.md**:

- The "Key files" section still names the files an agent should read first.
- The "Tech stack" list matches current dependencies.
- The "Core concepts" terms still appear in the code with the same meaning.

**verification.md**:

- Every gate primitive still runs successfully from a fresh clone.
- For every declared runtime (`### Runtime: <name>`), its `precondition` still succeeds when the runtime should be available (local: always; pr-preview: when a PR is open; etc.), and its `start` / `ready-check` / `teardown` / `invoke` / `inspect` commands still work.
- `Defined runtimes` and `Default runtime` in `## Project shape` match the `### Runtime:` sub-sections that actually exist.
- Every declared assumption (env files, services, ports) is still accurate.
- No `<unknown — resolve before next /start-plan>` placeholders remain from `/start-bootstrap`.
- Open sessions' contracts reference only runtimes and primitives that still exist here.

Stale content in either file is the highest-impact drift. Fix first.

### Step 7 — Detect patterns that should become skills

If during `/start-sync` you notice the same manual correction needed repeatedly (e.g., "every time someone adds a new event, they forget to update the catalog"), that's a signal for a project skill. Suggest:

> I noticed <pattern>. Consider capturing this with `/compound-learn` so future sessions
> don't re-make the mistake.

## Special cases

### When docs and code conflict and both seem valid

Ask the user which is the truth. Don't guess. The doc might be aspirational (correct intent, code hasn't caught up) or historical (correct at one time, code has moved on).

### When a doc section is entirely obsolete

Don't silently delete. Flag it:

> docs/architecture/legacy-migration.md appears to describe a flow that no
> longer exists. Proposed: archive to docs/architecture/archived/ with a note,
> or delete. Your call.

Archiving preserves context; deletion is fine if version control has the history.

### When the roadmap is out of sync with tickets

Don't try to re-derive truth from the ticket system. Ask whether the ticket system or the roadmap is authoritative. If tickets are authoritative, point the roadmap at them with links rather than duplicating status.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll update docs later, let me ship first" | Later never comes. Doc debt compounds — and the next agent session starts from wrong context. |
| "The code is self-documenting, docs are redundant" | Code documents what. Docs document why, what's coming, what's not in scope, and what's risky. |
| "Only the public API needs docs" | The agent reads all docs. Internal docs (architecture, gotchas) shape its behavior on every session. |
| "Stale docs aren't dangerous, they're just out of date" | Stale docs are more dangerous than no docs — they look authoritative and teach the agent wrong things. |
| "Small doc changes don't need approval" | The user owns the docs. Show proposed changes even if small. |
| "I'll fix the code instead of the doc" | If the doc was right and code drifted, fix the code. If the code is right and doc drifted, fix the doc. Don't confuse the two. |

## Red Flags

- Editing docs without showing the user first
- Making "small" edits that change the meaning of a doc
- Adding docs for features that don't exist (aspirational docs pollute the agent's assumptions)
- Deleting docs without archiving history or flagging
- Ignoring drift in `docs/architecture/overview.md` because "it's just docs"
- Skipping the verification-primitives check because "nothing obviously changed" — primitives go stale the moment a dependency is bumped or a script renamed
- Letting open-session contracts reference removed primitives — every future `/start-verify` on that session will refuse to run
- Assuming the roadmap is always the source of truth (tickets often are)
- Syncing the code to match wrong docs instead of fixing the docs

## Verification

- [ ] Every changed file in the commit range was compared to relevant docs
- [ ] Findings classified by severity
- [ ] User approved every doc edit before it was applied
- [ ] No doc edits committed automatically — left staged for the user
- [ ] `docs/architecture/overview.md` checked specifically
- [ ] `docs/architecture/verification.md` checked specifically — every primitive still executes, every declared runtime still resolves, no stale assumptions
- [ ] `Defined runtimes` and `Default runtime` match the `### Runtime:` sub-sections actually present
- [ ] Open-session contracts (`docs/sessions/*/verification.md`) reference only runtimes and primitives that still exist
- [ ] Every SDLC skill has a `docs/skills/<name>.md` file (empty is fine; missing is not)
- [ ] Each populated `docs/skills/*.md` only references files / functions / patterns that still exist
- [ ] Recurring corrections flagged as skill candidates
