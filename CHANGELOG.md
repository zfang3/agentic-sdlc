# Changelog

## [Unreleased]

### Fixed

- **`tmp/verify/` is now actually gitignored in downstream projects.** Both `verification.md` (template) and `/start-verify` claimed `tmp/verify/` was "gitignored via the bootstrap template," but the entry was never present in `templates/gitignore-additions.txt`. Pre-existing documentation lie since the verify skill landed; the raw gate logs and task-artifact captures could end up tracked unless a project added the entry by hand. The template now lists `tmp/verify/`, so any project that re-runs `/start-bootstrap` picks it up.

### Changed

- **`templates/gitignore-additions.txt` is now a flat list of entries — no markers, no comments.** Reported pain point: projen-managed projects (and similar synth-driven setups that override Step 3 of `/start-bootstrap` to mirror the template through `project.gitignore.exclude(...)`) had to either ignore the verbose explanatory comments and the marker pair (`# --- agentic-sdlc --- ... # --- end agentic-sdlc ---`), or render them via awkward `addPatterns(...)` calls. The template now contains only the five gitignore patterns, so projen mirrors collapse to one clean `exclude(...)` call. The philosophy and rationale that lived in those comments now live in `templates/docs/README.md`, this CHANGELOG, and the plugin README — reachable from a single canonical place rather than copy-pasted into every downstream project's `.gitignore`.

- **`/start-bootstrap` Step 3 rewritten for the markerless template.** Detection and reconciliation no longer rely on a marker-bracketed block; instead, Step 3 walks each line of the template and ensures it appears as a verbatim line in the host's `.gitignore`, appending any missing entries with a leading blank line for readability. Re-runs are idempotent (entries already present are skipped) and never duplicate. Migration: projects bootstrapped on ≤ v0.1.3 carry an old marker-bracketed block; the skill detects the legacy `# --- agentic-sdlc ---` line and surfaces a one-time hint suggesting the user can safely delete the old markers and in-block comments at their convenience — entries inside the old block remain valid wherever they live. The skill never deletes lines from the host's `.gitignore`; CHANGELOG entries call out any future entry removals so users know to clean up manually if they wish. Detection in partial mode and "already scaffolded" routing are updated to use the same per-line presence check.

- **`docs/sessions/<date>-<slug>/` is now tracked by default in downstream projects.** Reverses the v0.1.1 decision to gitignore the whole tree. Spec, plan, verification contract, verify results, and review/debug logs authored by the `/start-*` skills are durable decision records — the team's reviewable SDLC trail, including the pivots and amendments that show *why* a design landed where it did. Aligns the plugin with the dominant 2025-26 convention (GitHub Spec Kit's `.specify/specs/<feature>/`, AGENTS.md, and Agent Decision Records) of version-controlling spec-driven artifacts as institutional memory alongside code. The escape hatch for genuinely throwaway scratch is the new opt-in path `docs/sessions/.local/`, which remains gitignored. The change is in `templates/gitignore-additions.txt` (what end-user projects receive via `/start-bootstrap`); the plugin's own `.gitignore` is unchanged because the plugin repo is plugin source, not a project that runs through the SDLC. Existing downstream projects that re-run `/start-bootstrap` will be prompted about the legacy `docs/sessions/` entry in their block (Step 3's "found in your block but not in the current template — keep, or remove?" question); answering *remove* moves their team to the new default.

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
