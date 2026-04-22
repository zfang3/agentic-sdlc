# Contributing

This plugin ships generic SDLC skills. Project-specific skills (your stack, your team's conventions, framework-specific workflows) belong in your project's `.claude/skills/` via `/compound-learn`.

## Authoring skills

Use Anthropic's [`skill-creator`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/skill-creator) plugin. Install it with `/plugin install skill-creator@claude-plugins-official`, then run `/skill-create`. The structure it produces matches [`docs/skill-anatomy.md`](docs/skill-anatomy.md).

## Pull requests

- One logical change per PR
- Update `CHANGELOG.md`

## Getting help

- [Issues](https://github.com/zfang3/agentic-sdlc/issues) for bugs and feature requests
- [Discussions](https://github.com/zfang3/agentic-sdlc/discussions) for open questions

Contributions are licensed under [MIT](LICENSE).
