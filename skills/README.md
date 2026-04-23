# Skills Index

All skills in agentic-sdlc live in this directory. They fall into three categories by purpose. The split is for humans — Claude Code loads all skills uniformly and decides which to apply based on each skill's `description`.

## SDLC — user-driven lifecycle (12)

Type any of these as a slash command. Each drives one phase of the lifecycle.

Start a project with [`/start-bootstrap`](start-bootstrap/SKILL.md): scaffold the documentation skeleton. Cloning an already-scaffolded repo is the onboarding — every other `/start-*` skill auto-loads the docs. Define what to build with [`/start-spec`](start-spec/SKILL.md): spec before code. Break it into atomic tasks with [`/start-plan`](start-plan/SKILL.md). Implement task-by-task with [`/start-build`](start-build/SKILL.md): one vertical slice at a time. Root-cause failures with [`/start-debug`](start-debug/SKILL.md): cause before fix. Prove it works with [`/start-test`](start-test/SKILL.md): tests are proof. Verify before shipping with [`/start-verify`](start-verify/SKILL.md): verify artifacts, not claims. Review the diff with [`/start-review`](start-review/SKILL.md): improve code health. Reduce complexity with [`/start-simplify`](start-simplify/SKILL.md): clarity over cleverness. Ship it with [`/start-ship`](start-ship/SKILL.md): faster is safer. Address every open review thread with [`/start-address-review`](start-address-review/SKILL.md): each thread through the same pipeline, verifier-subagent-grounded triage, append-only log. Keep docs aligned with [`/start-sync`](start-sync/SKILL.md): fix the docs, not the code.

## Techniques — model-invoked knowledge (3)

These auto-load when Claude is doing matching work. Not meant for manual invocation — they're guidance that applies inside other workflows.

- [`source-driven-development`](source-driven-development/SKILL.md) — cite official docs before writing framework-specific code.
- [`api-and-interface-design`](api-and-interface-design/SKILL.md) — contract-first, Hyrum's Law, boundary validation.
- [`security-and-hardening`](security-and-hardening/SKILL.md) — OWASP patterns, secrets hygiene, three-tier boundary.

## Meta — grow the library (2)

Not part of the SDLC — these maintain the skill library itself.

- [`/compound-learn`](compound-learn/SKILL.md) — capture one insight from the current session as a project skill.
- [`/compound-evolve`](compound-evolve/SKILL.md) — run the full evolution pipeline across recent sessions.

## Adding a skill

Don't hand-author skills. Install Anthropic's official [`skill-creator`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/skill-creator) plugin, then run `/skill-create`. It enforces structure and pressure-tests drafts.

See [`../CONTRIBUTING.md`](../CONTRIBUTING.md) for the contribution bar.

## File layout convention

Each skill lives in its own directory:

```
skills/
  <skill-name>/
    SKILL.md                  required
    references/               optional — loaded on demand
      <reference>.md
```

The `SKILL.md` has YAML frontmatter and the main body. It must stay tight — detailed reference material moves into `references/` so the entry-point load stays cheap. The `references/` directory contains supplementary files the skill explicitly links to. Claude loads these only when the skill directs it to.

## Scope convention

Plugin skills live here — generic, cross-project, and slow-evolving. Project skills live in each project's `.claude/skills/<name>/`, accumulated via `/compound-learn` and `/compound-evolve`. Those evolve per-project; this plugin doesn't touch them.
