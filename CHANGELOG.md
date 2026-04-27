# Changelog

## [0.1.1] — 2026-04-24

### Added

- **Automatic skill capture.** Two hooks distil every session in the background — SessionEnd queues a trace, SessionStart drains it, runs the new `skill-distiller` subagent, and wakes the model with a system reminder when a fresh candidate appears in `.agentic-sdlc/pending/<slug>/`. Most sessions are skipped; only genuinely reusable patterns produce a draft.
- **`/compound-promote`** — slash command that opens a PR for a pending candidate. PR-based counterpart to `/compound-learn`'s local-commit flow.

### Changed

- Plugin-produced state (trace queue, hook logs, pending candidates) moved from `.claude/tmp/` and `.claude/skills/pending/` to `.agentic-sdlc/`. `.claude/` stays reserved for CC config and the final promoted-skill destination (`.claude/skills/<name>/`).
- `/start-bootstrap` Step 3 (`.gitignore` sync) is now idempotent. Re-run it after a plugin update and only the new entries are added — bracketed by `# --- agentic-sdlc ---` markers so any custom ignores you place outside the block are untouched.

## [0.1.0] — 2026-04-22

Initial release. Sixteen skills: eleven `/start-*` SDLC commands, three auto-loading technique skills (source-driven development, API design, security), and two `/compound-*` skills for the self-evolution loop. Ships a minimal documentation template used by `/start-bootstrap`.
