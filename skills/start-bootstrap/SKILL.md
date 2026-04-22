---
name: start-bootstrap
description: Scaffold a new project with agentic-sdlc documentation, or onboard a new teammate on an existing project. Use when starting fresh in an empty repo OR when joining a team that already uses agentic-sdlc. NOT for adding docs mid-project — use /start-sync for that.
category: sdlc
disable-model-invocation: true
---

# Bootstrap

## Overview

Sets up a project to use agentic-sdlc. First run scaffolds a minimal documentation skeleton and asks targeted questions to populate it. Subsequent runs detect existing docs and switch to onboarding mode — they read what's there and produce a short orientation for a new teammate.

The principle: **cloning a project should be the onboarding.** When a new engineer joins, `git clone` plus `/start-bootstrap` is all they need. The docs already hold the architecture, the spec, and the roadmap. The plugin reads them and catches the newcomer up in minutes.

## When to Use

- Empty repo with no `docs/` directory — initialize mode
- New teammate on a project that already has `docs/` with an architecture overview — onboard mode
- Repo with partial scaffolding — asks whether to complete or leave alone

**When NOT to use:**
- Adding new docs mid-project — use `/start-sync` to align docs with current code
- Rewriting existing architecture docs — use `/start-spec` for significant changes and update the relevant doc files directly

## Detection

Before asking any questions, check whether the project is already scaffolded. If `./docs/README.md` exists and `./docs/architecture/overview.md` contains something beyond the placeholder template, switch to onboard mode. If neither exists, run initialize mode. If docs/ exists but key files are still the placeholder templates, run partial mode.

## Initialize mode (fresh repo)

### Step 1 — Confirm project shape

Ask three short questions, one at a time:

1. **What is the project?** One sentence. This populates `docs/architecture/overview.md`.
2. **What kind of system is it?** Offer a short menu: web application, backend service or API, CLI tool, library or SDK, data pipeline, infrastructure, or other with free text.
3. **Is there an existing spec or PRD to port in?** If yes, note the location; the user may choose to paste it into `docs/product/spec.md` later.

### Step 2 — Copy the template skeleton

Copy everything under `${CLAUDE_PLUGIN_ROOT}/templates/docs/` into the project's `./docs/`. If `docs/` already exists, ask before overwriting any file. Never overwrite an existing file without explicit confirmation.

### Step 3 — Append to `.gitignore`

Append the contents of `${CLAUDE_PLUGIN_ROOT}/templates/gitignore-additions.txt` to the project's `.gitignore`. Create the `.gitignore` if it doesn't exist.

### Step 4 — Populate the overview

Open `docs/architecture/overview.md` and fill in one section at a time. Start with the project description from Step 1. Then ask: what are the three to five core concepts a new engineer must understand? Then ask: what are the two or three most important files or modules? Write each answer directly into the file. Keep the conversation one question at a time — do not dump a form.

### Step 5 — Commit the scaffolding

Show the user the full list of files that will be committed, with a one-line summary of each. Ask for confirmation. On approval, the user commits — this skill never runs git commands automatically.

### Step 6 — Suggest the next step

Tell the user that scaffolding is in place and suggest running `/start-spec <feature>` to define their first feature, or `/start-plan <ticket-id>` if they already have a ticket with enough detail to skip the spec step.

## Onboard mode (already scaffolded)

### Step 1 — Read the persistent memory

Read in this order: `docs/README.md` for the index, `docs/architecture/overview.md` for what the system is and does, `docs/product/spec.md` for what's being built, `docs/product/roadmap.md` for current phase and next deliverables. If `docs/architecture/decisions/` contains ADRs, scan their titles and dates to surface any recent design choices worth mentioning.

### Step 2 — Produce a short orientation

Synthesize a briefing for the newcomer covering: what the project is (one paragraph from the overview), the core concepts (the list from the overview), the current phase (from the roadmap), and the key files a new agent should read first (from the overview's key-files section). End with a recommended next action — either a specific ticket (if one is assigned) or `/start-sync` to check for drift before picking up work.

### Step 3 — Flag anything suspicious

If during reading you spot a file that's still the placeholder template, a stale date, or a `TODO` that's been there a long time, surface it. The newcomer shouldn't assume all docs are current.

## Partial mode (scaffolded but incomplete)

Detect placeholders by scanning for `TODO` strings, angle-bracketed placeholders like `<concept>`, or files that are byte-identical to the template. Report which files still need attention and ask whether to fill them in now (re-runs the relevant initialize steps) or skip.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "This is a small project, skip the docs" | Small projects grow. The cost of bootstrapping is one hour; the cost of no docs compounds session after session. |
| "I'll do it later when the architecture is stable" | Architecture is never stable. Bootstrap on day one and let the docs evolve with the code. |
| "CLAUDE.md is enough" | CLAUDE.md is loaded into every session whether relevant or not. Skills plus docs let you keep context focused and load heavy material only when needed. |
| "The README already says what it is" | A README is for humans reading on GitHub. The agent needs `docs/architecture/overview.md` with depth. |
| "I'll just answer all the questions in one message to save time" | Answering one question at a time produces better docs — each answer clarifies the next question. |

## Red Flags

- User says "just do it, skip the questions" — the questions exist because the answers shape every future session. Don't skip them.
- Copying templates without any adaptation — placeholder docs are worse than no docs because they look authoritative while containing nothing.
- Creating subdirectories the user didn't ask for (like `docs/runbooks/` when there are no runbooks yet) — keep the skeleton minimal; it grows as the project needs.
- Running git commands — this skill never commits. The user reviews and commits.

## Verification

Before reporting done:

- [ ] `docs/README.md` exists and references only files that exist
- [ ] `docs/architecture/overview.md` has a real project description, not the template placeholder
- [ ] `.gitignore` includes the agentic-sdlc additions
- [ ] No existing files were overwritten without confirmation
- [ ] A next-step suggestion was given to the user
