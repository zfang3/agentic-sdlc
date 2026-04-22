# <Project Name> — Documentation

> This project uses [agentic-sdlc](https://github.com/zfang3/agentic-sdlc).
> The docs below are persistent memory for both humans and Claude Code.

## What lives where

- [`architecture/overview.md`](architecture/overview.md) — what the system is, its core concepts, and the files an agent should read first.
- [`architecture/decisions/`](architecture/decisions/) — Architecture Decision Records capturing the *why* behind significant technical choices.
- [`product/spec.md`](product/spec.md) — the product spec: problem, users, acceptance criteria, non-goals.
- [`product/roadmap.md`](product/roadmap.md) — current phase, next milestones, completed work.

## Growing the documentation

This skeleton is intentionally minimal. Add new files when the project needs them, not preemptively:

- Per-feature specs and plans live under `sessions/<YYYY-MM-DD>-<slug>/`, produced by `/start-spec` and `/start-plan`.
- New architectural decisions become ADRs in `architecture/decisions/`.
- If the project accumulates runbooks, SOPs, or design documents, create `runbooks/`, `sops/`, or `designs/` subdirectories as needed. No structural migration required.

## Maintaining the docs

After significant code changes, run `/start-sync` to detect and fix drift between code and docs. After solving a non-obvious problem, run `/compound-learn` to capture the insight as a project skill. Periodically, run `/compound-evolve` to let session experience improve the skill library.

## For teammates joining the project

Install agentic-sdlc and run `/start-bootstrap` in the project root. Because the documentation already exists, `/start-bootstrap` switches to onboard mode: it reads these files and produces a short orientation.
