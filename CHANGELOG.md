# Changelog

## [Unreleased]

### Fixed

- **`tmp/verify/` is now actually gitignored in downstream projects.** Both `verification.md` and `/start-verify` claimed it was, but the entry was never in `templates/gitignore-additions.txt`. Now genuinely covered.

### Changed

- **`docs/sessions/<date>-<slug>/` is tracked by default in downstream projects.** Reverses the v0.1.1 decision; spec / plan / verification / verify / review logs are durable decision records, aligned with GitHub Spec Kit + AGENTS.md + ADR conventions. Escape hatch: opt-in `docs/sessions/.local/` for throwaway scratch.
- **`templates/gitignore-additions.txt` is now a flat list — no markers, no comments.** Projen-managed projects can mirror it via a single `project.gitignore.exclude(...)` call. The rationale that lived in the in-block comments is now in `templates/docs/README.md` and the plugin README.
- **`/start-bootstrap` Step 3 rewritten for the markerless template.** Detection uses per-line presence checks instead of marker-block diffing; re-runs are idempotent. Projects bootstrapped on ≤ v0.1.3 carry an old marker block; the skill surfaces a one-time hint that markers can be safely deleted and never auto-strips them.
- **README: new "Project layout in your repo" section** with an ASCII tree diagram showing every directory the plugin reads or writes, tracked vs ignored status, and three mental-model bullets covering `docs/`, `.claude/`, and `.agentic-sdlc/`.

## [0.1.3] — 2026-04-27

### Added

- **`/start-verify` plan-acceptance signoff.** Phase 3's contract-coverage review pass now produces an explicit trace table mapping each `plan.md` AC (per-task and the plan-level `## Acceptance (for the whole plan)` checklist) to the contract item that backs it and that item's verify result. The table lands in `verify.md` under a new `### Plan acceptance signoff` section so reviewers can confirm AC coverage without manually cross-referencing three files. Plan ACs with no traceable contract item surface as HIGH coverage-gap findings.
- **`/start-bootstrap` self-conventions.** The skill now has its own `docs/skills/start-bootstrap.md` override stub (created on initialize, loaded at the top of every run). Lets projects encode bootstrap-specific conventions — most notably, redirecting Step 3's `.gitignore` sync through a generator's API (e.g. projen's `project.gitignore.exclude(...)`) instead of editing `.gitignore` directly.
- **`/compound-promote` project conventions.** Same override pattern: load `docs/skills/compound-promote.md` if present. Projects can override branch naming (default `skill/compound-promote-<slug>`), commit-message format, PR body template, and reviewer routing.
- **`SKILL_DISTILLER_MIN_TURNS` env var.** Configures the drain hook's low-signal threshold (default `2` user-turns); was previously hardcoded.
- **`CLAUDE_BIN` env var override** in the drain hook's `claude` lookup, plus broader fallback paths (`/usr/bin`, `/snap/bin`, NixOS, bun, asdf). Linux installs that don't match the Homebrew-flavored default no longer silently fail with "claude-not-found."

### Fixed

- **`/start-bootstrap` upgrade-path detection.** Previously, a fully-scaffolded v0.1.0 repo upgrading to a newer plugin version always hit the "already scaffolded" early exit, so newly-added gitignore entries (and template stubs) never got synced. Detection now runs both `docs/` and `.gitignore` block checks and routes to partial mode if either is stale.

### Internal

- `/start-bootstrap` Step 2 broadened to copy whatever stubs live under `templates/docs/skills/` rather than enumerating per-skill — future plugin versions that add new override hooks propagate to existing projects automatically on the next re-bootstrap.

## [0.1.1] — 2026-04-24

### Added

- **Automatic skill capture.** Two hooks distil every session in the background — SessionEnd queues a trace, SessionStart drains it, runs the new `skill-distiller` subagent, and wakes the model with a system reminder when a fresh candidate appears in `.agentic-sdlc/pending/<slug>/`. Most sessions are skipped; only genuinely reusable patterns produce a draft.
- **`/compound-promote`** — slash command that opens a PR for a pending candidate. PR-based counterpart to `/compound-learn`'s local-commit flow.

### Changed

- Plugin-produced state (trace queue, hook logs, pending candidates) moved from `.claude/tmp/` and `.claude/skills/pending/` to `.agentic-sdlc/`. `.claude/` stays reserved for CC config and the final promoted-skill destination (`.claude/skills/<name>/`).
- `/start-bootstrap` Step 3 (`.gitignore` sync) is now idempotent. Re-run it after a plugin update and only the new entries are added — bracketed by `# --- agentic-sdlc ---` markers so any custom ignores you place outside the block are untouched.

## [0.1.0] — 2026-04-22

Initial release. Sixteen skills: eleven `/start-*` SDLC commands, three auto-loading technique skills (source-driven development, API design, security), and two `/compound-*` skills for the self-evolution loop. Ships a minimal documentation template used by `/start-bootstrap`.
