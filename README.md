# agentic-sdlc

A Claude Code plugin for running a project through its full software lifecycle. The `/start-*` commands cover each phase — spec, plan, build, test, debug, verify, review, simplify, ship, sync. The `/compound-learn` and `/compound-evolve` commands turn what each session teaches you into project skills your whole team inherits through git.

## Install

From Anthropic's official marketplace (once accepted):

```bash
/plugin install agentic-sdlc@claude-plugins-official
```

Before acceptance, or for local development on the plugin itself, clone the repo and point Claude Code at it:

```bash
git clone https://github.com/zfang3/agentic-sdlc.git
claude --plugin-dir /path/to/agentic-sdlc
```

## Quick start

In a fresh project:

```bash
/start-bootstrap                         # scaffolds the docs/ skeleton
/start-spec "add user authentication"    # spec before code
/start-plan PROJ-123                     # decompose into atomic tasks
/start-build                             # TDD implementation with in-loop review
/start-verify                            # sandbox verification before ship
/start-ship                              # PR → CI → address review → merge
/compound-learn                          # capture what made this session work
```

## What's in the plugin

All 17 skills live in `skills/`, grouped by purpose via the `category` frontmatter field.

**SDLC skills (12)** — user-invoked, drive the lifecycle. `/start-bootstrap` scaffolds a new project's documentation skeleton (including `docs/skills/*.md` conventions stubs for every other SDLC skill); cloning an already-scaffolded repo is the onboarding, since every other `/start-*` skill auto-loads the docs — including its own `docs/skills/<name>.md` for project-specific conventions. `/start-spec` defines what to build before any code is written. `/start-plan` breaks a spec into small, verifiable tasks with acceptance criteria. `/start-build` executes the plan task-by-task with TDD and in-loop review. `/start-debug` roots-causes a failure systematically before fixing. `/start-test` drives development with tests. `/start-verify` runs a deterministic gate plus parallel review passes before shipping. `/start-review` runs five-axis review on the current diff or an external PR. `/start-simplify` reduces complexity without changing behavior. `/start-ship` creates the PR, waits for CI, and merges once review threads are clear. `/start-address-review` owns the review-response phase: fetches every open thread, forks a verifier subagent per thread, triages into AGREE/DISAGREE/CLARIFY, implements fixes with TDD, re-runs verify, drafts replies, and posts on user approval. `/start-sync` detects and fixes drift between code and docs.

**Technique skills (3)** — model-invoked, auto-load when their description matches. `source-driven-development` cites official docs before writing framework-specific code. `api-and-interface-design` enforces contract-first design with Hyrum's Law and boundary validation in mind. `security-and-hardening` applies OWASP patterns and secrets hygiene on any change that touches user input or infrastructure.

**Meta skills (2) + 1 command** — grow the skill library over time. **`/compound-learn`** captures one session's insight as a project-scoped skill — you and Claude pick the lesson together. **`/compound-evolve`** sweeps across many recent sessions and proposes batch updates to existing skills, backed by evidence. **`/compound-promote`** turns a draft skill into a PR. The plugin also runs a **fully automatic** version of `/compound-learn` after every session — see below.

## Per-project versus per-plugin

The plugin itself provides the machinery: 17 SDLC + technique + meta skills, the automatic skill-capture loop and its `/compound-promote` companion, plus a minimal doc template skeleton. It's stable across projects and only changes when the plugin releases a new version.

Each project owns its filled-in `docs/architecture/` and `docs/product/` content, its session history in `.claude/sessions/`, and the project-specific skills it accumulates under `.claude/skills/` via `/compound-learn` and `/compound-evolve`. When a new teammate joins, they `git clone` the project, install agentic-sdlc, and start working — every `/start-*` skill auto-loads the project's documentation at the start of its flow, so they inherit the plugin's machinery plus the team's accumulated skills plus the project's persistent memory in one shot.

## Automatic skill capture

After every session, the plugin quietly looks at what you and Claude worked on and asks: *did we just figure out something a future session would benefit from knowing?* Most of the time the answer is no — a quick question, a one-off fix, an abandoned experiment — and nothing happens.

When the answer is yes — a real, reusable pattern, a non-obvious gotcha, a checklist that came up more than once — the plugin drafts a skill and lets you know about it the next time you open Claude in the project.

### What you'll see

When you start your next session in a project where something was distilled, a short notice appears in Claude's context — something like:

> [skill evolution] Distilled 1 previous session(s) in the background — 1 new candidate(s) in `.agentic-sdlc/pending/` (current pending: `your-new-skill-slug`). Run `/compound-promote` to review.

A *candidate* is a markdown file with the skill already drafted out, plus a few `[TODO: reviewer to fill]` markers where the plugin wasn't confident enough to write something on its own.

To turn it into a real skill:

1. Run **`/compound-promote`**. It lists the pending candidates and asks which one to review.
2. Walk through the draft with Claude — the agent flags every `[TODO]` placeholder and helps you fill them in. Optionally run the two pressure-tests `/compound-learn` would have run: *would this guidance survive end-of-day pressure?* and *does it cite enough evidence to override an opposing instinct?*
3. Confirm. The plugin moves the file into `.claude/skills/<slug>/`, makes a branch, pushes it, and opens a PR via `gh`.
4. Review and merge like any other PR. Once it's merged on `main` and your teammates pull, the skill auto-loads in every future session.

If you'd rather drive things by hand, the three manual commands cover the same ground:

- **`/compound-learn`** — one session in, one skill out, with you choosing the lesson.
- **`/compound-promote`** — open a PR for a pending draft.
- **`/compound-evolve`** — batch across many sessions; proposes updates to existing skills.

All four paths (auto + the three commands) write to the same place, so they don't fight each other.

### How it works

Two hooks do the work. They install with the plugin and run automatically.

- **When a session ends**, the first hook writes a tiny breadcrumb (just the session id and where Claude saved its transcript) to `.agentic-sdlc/tmp/`. It takes well under a second and never makes an LLM call.
- **When the next session starts**, the second hook reads the breadcrumbs in the background, hands each transcript to a `skill-distiller` agent, and surfaces anything worth promoting before you start typing.

The distiller defaults to skipping. It only emits a draft when the session contained something *generalizable* — a "when X, do Y" procedural pattern, not a task-specific detail. Trivial fixes, one-off questions, and aborted work get filtered out before any draft is written.

Drafts land in `.agentic-sdlc/pending/<slug>/` (gitignored — they're per-developer until promoted). Promoted skills land in `.claude/skills/<slug>/` and are committed via PR; that's where Claude Code looks for project-scoped skills, so they auto-load in future sessions once the PR is merged.

### Scope

The loop runs in whichever project has the plugin installed. Each project accumulates its own skills — nothing is shared between projects or developers until you commit and push the promoted ones. Pending candidates stay local; only the PRs you open via `/compound-promote` are visible to teammates.

## Adding a skill

Don't hand-author skills. Install Anthropic's [`skill-creator`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/skill-creator) plugin and run `/skill-create`. See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the contribution process.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md).

## License

MIT — see [`LICENSE`](LICENSE).
