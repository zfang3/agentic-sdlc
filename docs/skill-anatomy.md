# Skill Anatomy

Every skill in this plugin follows the same structure.

## File layout

```
skills/
  <skill-name>/
    SKILL.md              required
    references/           optional, loaded on demand
      <reference>.md
```

Skill directory names are lowercase-hyphen-separated. `SKILL.md` is always uppercase.

## Frontmatter

```yaml
---
name: skill-name
description: Use when <trigger condition>. NOT for <exclusion>.
category: sdlc | technique | meta
argument-hint: [optional-args]
allowed-tools: Read Grep Bash(git *)
context: fork
agent: general-purpose
disable-model-invocation: false
user-invocable: true
---
```

- `name` must match the directory name.
- `description` is the most important field — Claude uses it to decide when to load the skill. Start with "Use when" and include explicit "NOT for" exclusions.
- `category` groups skills for human navigation: `sdlc` (user-invocable lifecycle commands), `technique` (auto-loading background knowledge), `meta` (plugin maintenance).
- `disable-model-invocation: true` for skills with side effects (writes files, commits, creates PRs).
- `user-invocable: false` for techniques that auto-load by description match and aren't meant to be typed.
- `context: fork` + `agent: general-purpose` for skills that read a lot and benefit from isolated context.

## Standard sections

Every SKILL.md uses this section order:

```markdown
# <Skill Title>

## Overview
One paragraph — what this skill does and why.

## [Iron Law | Hard Gate]          (optional, for strict process skills)
A single absolute rule in a code block.

## When to Use
Bullet list of triggers. Include "When NOT to use" exclusions.

## The Process
Numbered steps with exact commands. ASCII flowcharts where decision points exist.

## [Domain-specific sections]       (optional)
Code examples, templates, specific patterns.

## Common Rationalizations
Two-column table: the excuse agents use → why the excuse is wrong.

## Red Flags
Observable signs the skill is being violated.

## Verification
Checklist of exit criteria with evidence requirements.
```

## Authoring

Don't hand-author skills. Install Anthropic's [`skill-creator`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/skill-creator) and run `/skill-create`. It enforces the structure above.

See [`../CONTRIBUTING.md`](../CONTRIBUTING.md) for the contribution process.

## Length

Keep `SKILL.md` under 500 lines. Move detailed reference material into `references/` so the main skill stays cheap to load.
