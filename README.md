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

All 16 skills live in `skills/`, grouped by purpose via the `category` frontmatter field.

**SDLC skills (11)** — user-invoked, drive the lifecycle. `/start-bootstrap` scaffolds a new project or onboards a teammate on an existing one. `/start-spec` defines what to build before any code is written. `/start-plan` breaks a spec into small, verifiable tasks with acceptance criteria. `/start-build` executes the plan task-by-task with TDD and in-loop review. `/start-debug` roots-causes a failure systematically before fixing. `/start-test` drives development with tests. `/start-verify` runs a deterministic gate plus parallel review passes before shipping. `/start-review` runs five-axis review on the current diff or an external PR. `/start-simplify` reduces complexity without changing behavior. `/start-ship` creates the PR, waits for CI, addresses review feedback, and merges. `/start-sync` detects and fixes drift between code and docs.

**Technique skills (3)** — model-invoked, auto-load when their description matches. `source-driven-development` cites official docs before writing framework-specific code. `api-and-interface-design` enforces contract-first design with Hyrum's Law and boundary validation in mind. `security-and-hardening` applies OWASP patterns and secrets hygiene on any change that touches user input or infrastructure.

**Meta skills (2)** — user-invoked, grow the skill library over time. `/compound-learn` captures one session's insight as a project-scoped skill. `/compound-evolve` runs the full pipeline across recent sessions, proposing skill improvements backed by session evidence.

## Per-project versus per-plugin

The plugin itself provides the machinery: 16 SDLC and technique and meta skills, a minimal doc template skeleton, and the `/compound-evolve` pipeline. It's stable across projects and only changes when the plugin releases a new version.

Each project owns its filled-in `docs/architecture/` and `docs/product/` content, its session history in `.claude/sessions/`, and the project-specific skills it accumulates under `.claude/skills/` via `/compound-learn` and `/compound-evolve`. When a new teammate joins, they `git clone` the project, install agentic-sdlc, and type `/start-bootstrap` — they inherit the plugin's machinery plus the team's accumulated skills plus the project's persistent memory in one shot.

## Adding a skill

Don't hand-author skills. Install Anthropic's [`skill-creator`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/skill-creator) plugin and run `/skill-create`. See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the contribution process.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md).

## License

MIT — see [`LICENSE`](LICENSE).
