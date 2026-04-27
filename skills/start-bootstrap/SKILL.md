---
name: start-bootstrap
description: Scaffold a new project's agentic-sdlc documentation skeleton. Use when starting fresh in an empty repo or completing a partially-scaffolded one. NOT for onboarding a teammate — cloning the repo is the onboarding; every /start-* skill auto-loads the docs. NOT for adding docs mid-project — use /start-sync.
category: sdlc
disable-model-invocation: true
---

# Bootstrap

## Overview

Scaffolds a minimal documentation skeleton for a new agentic-sdlc project and asks targeted questions to populate it. Runs only on empty repos or repos with partial scaffolding. If `docs/` is already complete, the skill exits politely and points the user at the right tool for what they actually want.

The principle: **cloning a project is the onboarding.** Every SDLC skill auto-loads `docs/architecture/overview.md` and `docs/architecture/verification.md` at the start of its flow; `/start-sync` reads the whole `docs/` tree. A dedicated onboarding command would duplicate that. Newcomers clone, install agentic-sdlc, and start working — they can ask Claude for a plain-English briefing anytime, or run `/start-sync` first to check whether the docs have drifted from the code.

## When to Use

- Empty repo with no `docs/` directory — initialize mode
- Repo with partial scaffolding (template placeholders still in key files) — partial mode asks whether to complete

**When NOT to use:**

- Onboarding a new teammate — not needed. Clone the repo, install agentic-sdlc, and start working; every `/start-*` skill auto-loads the docs. Ask Claude for a plain-English briefing if one is wanted, or run `/start-sync` first to surface any doc drift before picking up a ticket.
- Adding new docs mid-project — use `/start-sync` to align docs with current code
- Rewriting existing architecture docs — use `/start-spec` for significant changes and update the relevant doc files directly

## Detection

Before asking any questions, run two checks against the host repo and the current `${CLAUDE_PLUGIN_ROOT}/templates/`:

1. **`docs/` state** — absent, partially populated (template residue / missing template files), or fully populated.
2. **`.gitignore` agentic-sdlc block state** — absent (no `# --- agentic-sdlc ---` marker), in sync (every non-blank, non-comment entry from `templates/gitignore-additions.txt` is also inside the host's block), or stale (host's block is missing at least one entry from the current template). Skip the in-sync check if the host has no `.gitignore` at all — that case routes to initialize mode.

Routing:

- `./docs/README.md` absent OR `./docs/` absent → **initialize mode** (which also creates/syncs the `.gitignore` block via Step 3).
- Any of:
  - `./docs/` key files (`architecture/overview.md`, `architecture/verification.md`) still contain template residue (`<angle-bracket>` markers, template-derived `TODO`s, or byte-identical-to-template content), OR
  - `./docs/skills/` is missing entirely (e.g. the repo was bootstrapped before skills-conventions existed), OR
  - the host has a `.gitignore` and the agentic-sdlc block is **stale or absent** (this is the v0.1.0 → v0.1.1 upgrade path)
  → **partial mode**.
- `./docs/` exists, key files are populated, `./docs/skills/` exists (empty stub files are fine), AND the `.gitignore` block is in sync → **already scaffolded** — exit politely.

"Already scaffolded" is not an error. Tell the user exactly:

> This repo already has its agentic-sdlc scaffolding. There is nothing to bootstrap.
> - For a plain-English project briefing, just ask — Claude will read `docs/` and summarize.
> - To check whether the docs have drifted from the code before picking up work, run `/start-sync`.

Then exit the skill. Do not read the docs, do not produce a briefing, do not flag stale content — those concerns belong to the commands above.

## Initialize mode (fresh repo)

### Step 1 — Confirm project shape

Ask three short questions, one at a time:

1. **What is the project?** One sentence. This populates `docs/architecture/overview.md`.
2. **What kind of system is it?** Offer a short menu: web application, backend service or API, CLI tool, library or SDK, data pipeline, infrastructure, or other with free text.
3. **Is there an existing spec or PRD to port in?** If yes, note the location; the user may choose to paste it into `docs/product/spec.md` later.

### Step 2 — Copy the template skeleton

Copy everything under `${CLAUDE_PLUGIN_ROOT}/templates/docs/` into the project's `./docs/`. This includes `architecture/overview.md`, `architecture/verification.md`, `architecture/decisions/`, `product/spec.md`, `product/roadmap.md`, AND `skills/*.md` — one conventions stub per `/start-*` SDLC skill (except `start-bootstrap` itself: `start-spec`, `start-plan`, `start-build`, `start-test`, `start-debug`, `start-verify`, `start-review`, `start-simplify`, `start-ship`, `start-address-review`, `start-sync`), which teams fill in over time as they develop project-specific guidance.

If `docs/` already exists, ask before overwriting any file. Never overwrite an existing file without explicit confirmation.

### Step 3 — Sync `.gitignore` (idempotent)

Reconcile the host project's `.gitignore` with `${CLAUDE_PLUGIN_ROOT}/templates/gitignore-additions.txt`. Re-running this step on an already-bootstrapped repo must never duplicate entries.

The template file is bracketed by markers:

```
# --- agentic-sdlc ---
...plugin-managed entries...
# --- end agentic-sdlc ---
```

Procedure:

1. If the host has no `.gitignore`, create one and append the entire template. Done.
2. If the host's `.gitignore` does not contain `# --- agentic-sdlc ---`, append the entire template (markers and all) at the end of the file with a leading blank line. Done.
3. Otherwise the markers exist. Locate the block (the lines between `# --- agentic-sdlc ---` and `# --- end agentic-sdlc ---`, exclusive of the markers themselves). Compare the **non-blank, non-comment** entries inside the block against the same in the template:
   - For each template entry **missing** from the host's block: insert it just before the `# --- end agentic-sdlc ---` line.
   - **Never delete** entries the host has inside the block that aren't in the template — they may be the user's intentional additions or hold-overs from an older plugin version. Surface them to the user with a one-line "found in your block but not in the current template — keep, or remove?" question.
   - **Never modify** anything outside the markers.
4. Report exactly what changed: which entries were added, which extras were kept, which the user chose to remove (if any).

If the user's `.gitignore` had a pre-marker `agentic-sdlc` block from a much-older plugin version that didn't use markers (recognizable by the leading `# --- agentic-sdlc ---` header without a closing marker), tell the user, do not modify it, and ask whether to migrate by hand. Do not attempt automatic migration of unmarked legacy blocks — too easy to lose user customizations.

### Step 4 — Populate the overview

Open `docs/architecture/overview.md` and fill in one section at a time. Start with the project description from Step 1. Then ask: what are the three to five core concepts a new engineer must understand? Then ask: what are the two or three most important files or modules? Write each answer directly into the file. Keep the conversation one question at a time — do not dump a form.

### Step 5 — Populate verification primitives

Open `docs/architecture/verification.md` and fill in one section at a time. This file is the primitives library every future session's verification contract will reference — if the commands here are wrong or missing, `/start-plan` cannot author a valid contract and `/start-verify` has nothing real to execute.

Walk through these questions one at a time:

1. **What is the project type?** Map to the `## Project shape` options (library, cli, web-service, data-pipeline, iac, plugin, other). The type decides whether Runtime primitives apply.
2. **What command compiles or type-checks this project?** Fill the `compile` primitive. If none (pure interpreted language, no type checker), write `not applicable` and note why under `## Declared assumptions`.
3. **Lint, typecheck, unit, integration** — one at a time, ask for the exact command this project uses today. If a gate does not exist yet, write `not applicable` rather than inventing a command; flag that adding the gate is a candidate for a later plan.
4. **If `Has runtime: true`**: ask which runtimes the project uses. Minimum is `local`; common additions are `pr-preview` (ephemeral per-PR), `staging`, `integration`, `localstack`, etc. For EACH runtime the user selects, walk through its full block (`precondition`, `start`, `ready-check`, `teardown`, `invoke`, `inspect`) one field at a time under a `### Runtime: <name>` sub-section. Then ask which runtime should be the project's `Default runtime` (usually `local`). Fill `Defined runtimes` and `Default runtime` in the `## Project shape` stanza accordingly. For any primitive the user cannot state concretely, leave `<unknown — resolve before next /start-plan>` and surface the gap explicitly.
5. **Declared assumptions** — ask: "what must be true on the machine for these commands to work?" Fill in environment files, required services, reserved ports. Skip the section only if there is genuinely nothing special.

Never invent a command. A wrong primitive is worse than an absent one, because the next session's `/start-verify` will trust it.

### Step 6 — Commit the scaffolding

Show the user the full list of files that will be committed, with a one-line summary of each. Ask for confirmation. On approval, the user commits — this skill never runs git commands automatically.

### Step 7 — Suggest the next step

Tell the user that scaffolding is in place and mention:

- `docs/skills/*.md` are stub conventions files, one per SDLC skill. They start blank — the relevant skill falls back to plugin defaults when the file is empty. Fill them over time as team conventions emerge (commit-message format, PR template, review axes, etc.); the corresponding skill reads its file at the start of every run.
- Next step suggestion: `/start-spec <feature>` to define their first feature, or `/start-plan <ticket-id>` if they already have a ticket with enough detail to skip the spec step.

## Partial mode (scaffolded but incomplete)

Detect three kinds of incompleteness:

1. **Placeholders** — scan `docs/` for `TODO` strings, angle-bracketed placeholders like `<concept>`, or files that are byte-identical to a file in `templates/docs/`. These indicate scaffolding questions that were never answered.
2. **Missing template files** — compare the contents of `${CLAUDE_PLUGIN_ROOT}/templates/docs/` against the project's `docs/`. Any template file or directory that exists in the template set but not in the project is a gap (e.g. `docs/skills/` added in a later plugin version). Copy missing files before re-running the relevant initialize steps.
3. **Stale `.gitignore` block** — compare non-blank, non-comment entries in `${CLAUDE_PLUGIN_ROOT}/templates/gitignore-additions.txt` against the host's `.gitignore` agentic-sdlc block (between `# --- agentic-sdlc ---` and `# --- end agentic-sdlc ---`). Any template entry not present in the host's block is a gap — the plugin added it in a later version. Do NOT detect this as a gap if the host has no `.gitignore` or no markers at all (that case falls through to Step 3 of initialize mode, which handles fresh adds).

Report what's missing or placeholder-ridden and ask whether to fill them in now (re-runs the relevant initialize steps) or skip. Empty `docs/skills/*.md` files are NOT placeholder-ridden — they are the intended default state (no project conventions declared); do not flag them.

For a stale `.gitignore` block, the prompt is a single yes/skip question — re-running Step 3 of initialize mode handles the rest idempotently.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "This is a small project, skip the docs" | Small projects grow. The cost of bootstrapping is one hour; the cost of no docs compounds session after session. |
| "I'll do it later when the architecture is stable" | Architecture is never stable. Bootstrap on day one and let the docs evolve with the code. |
| "CLAUDE.md is enough" | CLAUDE.md is loaded into every session whether relevant or not. Skills plus docs let you keep context focused and load heavy material only when needed. |
| "The README already says what it is" | A README is for humans reading on GitHub. The agent needs `docs/architecture/overview.md` with depth. |
| "I'll just answer all the questions in one message to save time" | Answering one question at a time produces better docs — each answer clarifies the next question. |
| "Verification commands can wait until the first real plan" | `/start-plan` cannot author a verification contract without primitives. Without primitives it either blocks or, worse, invents commands that `/start-verify` will then trust. Primitives are input to planning, not output from it. |
| "One runtime is enough — skip the PR preview block" | When a PR preview exists, some bugs only show against it (real secrets, real CDN, real DNS, real third-party APIs). Declaring it as a runtime lets contracts opt in. Omitting it forces agents to improvise when a spec needs preview verification, which is where this whole pipeline breaks down. |

## Red Flags

- User says "just do it, skip the questions" — the questions exist because the answers shape every future session. Don't skip them.
- Copying templates without any adaptation — placeholder docs are worse than no docs because they look authoritative while containing nothing.
- Creating subdirectories the user didn't ask for (like `docs/runbooks/` when there are no runbooks yet) — keep the skeleton minimal; it grows as the project needs.
- Running git commands — this skill never commits. The user reviews and commits.

## Verification

Checks depend on which mode ran.

**Initialize mode** (all of these):

- [ ] `docs/README.md` exists and references only files that exist
- [ ] `docs/architecture/overview.md` has a real project description, not the template placeholder
- [ ] `docs/architecture/verification.md` has real gate primitives (or explicit `not applicable` with a declared reason); any `<unknown>` placeholder was surfaced to the user
- [ ] If `Has runtime: true`, at least one `### Runtime: <name>` sub-section is filled; `Defined runtimes` and `Default runtime` in `## Project shape` match the sub-sections
- [ ] `docs/skills/` directory exists with one stub file per SDLC skill (except start-bootstrap). Stubs are allowed to be empty — that is the default state.
- [ ] `.gitignore` includes the agentic-sdlc additions
- [ ] No existing files were overwritten without confirmation
- [ ] A next-step suggestion was given to the user

**Partial mode**:

- [ ] Every placeholder the user asked to fill is now populated
- [ ] User approved any file overwrites
- [ ] A next-step suggestion was given to the user

**Already scaffolded**:

- [ ] User was told the repo is already scaffolded
- [ ] User was pointed at `/start-sync` and at asking Claude for a briefing
- [ ] No files read; no briefing produced; skill exited
