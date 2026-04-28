# <Project Name> — Documentation

> This project uses [agentic-sdlc](https://github.com/zfang3/agentic-sdlc).
> The docs below are persistent memory for both humans and Claude Code.

## What lives where

- [`architecture/overview.md`](architecture/overview.md) — what the system is, its core concepts, and the files an agent should read first.
- [`architecture/verification.md`](architecture/verification.md) — how this project is compiled, tested, started, exercised, and torn down; the primitives every session's verification contract references.
- [`architecture/decisions/`](architecture/decisions/) — Architecture Decision Records capturing the *why* behind significant technical choices.
- [`skills/`](skills/) — one file per `/start-*` SDLC skill with project-specific conventions the skill reads at the start of every run. Layer on top of the skill's built-in defaults; leave blank to use defaults as-is.
- [`product/spec.md`](product/spec.md) — the product spec: problem, users, acceptance criteria, non-goals.
- [`product/roadmap.md`](product/roadmap.md) — current phase, next milestones, completed work.

## Growing the documentation

This skeleton is intentionally minimal. Add new files when the project needs them, not preemptively:

- Per-feature SDLC artifacts live under `sessions/<YYYY-MM-DD>-<slug>/` — `spec.md`, `plan.md`, `verification.md`, `verify.md`, plus any review/debug logs. Produced by `/start-spec`, `/start-plan`, `/start-verify`, and friends. **These are committed**, not transient: spec/plan/contract/verify-result are the team's reviewable trail of *why* each change happened, including pivots and amendments. The escape hatch for genuinely throwaway scratch is the opt-in `sessions/.local/` subdir, which is gitignored.
- New architectural decisions become ADRs in `architecture/decisions/`.
- If the project accumulates runbooks, SOPs, or design documents, create `runbooks/`, `sops/`, or `designs/` subdirectories as needed. No structural migration required.

## Maintaining the docs

After significant code changes, run `/start-sync` to detect and fix drift between code and docs. After solving a non-obvious problem, run `/compound-learn` to capture the insight as a project skill. Periodically, run `/compound-evolve` to let session experience improve the skill library.

## For teammates joining the project

Clone the repo, install agentic-sdlc, and start working. Every `/start-*` skill auto-loads the documentation in this directory at the beginning of its flow, so context is populated on first use. If you want a plain-English briefing before picking up a ticket, ask Claude — it will read these files and summarize. If you want to check whether the docs are stale relative to the code before starting, run `/start-sync`.
