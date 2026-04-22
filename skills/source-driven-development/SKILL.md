---
name: source-driven-development
description: Ground framework-specific code decisions in official documentation before writing them. Use when writing code that depends on a specific version of a framework, library, or platform API. NOT for pure logic that works identically across versions.
category: technique
user-invocable: false
---

# Source-Driven Development

## Overview

Every framework-specific code decision must be backed by official documentation. Don't implement from memory — verify, cite, and let the user see your sources. Training data goes stale, APIs get deprecated, best practices evolve. This skill ensures the user gets code they can trust because every pattern traces back to an authoritative source they can check.

The principle: **confidence is not evidence.** An agent will confidently produce a deprecated API signature that looks correct and breaks in production. One doc fetch prevents hours of rework.

## When to Use

- Writing code that uses a specific framework or library (React, Django, Rails, FastAPI, AWS SDK, etc.)
- The user asks for code that follows "current best practices" for some stack
- Building boilerplate that will be copied across a project
- Implementing features where the framework's recommended approach matters (forms, routing, data fetching, state, auth)
- Reviewing or improving code that uses framework-specific patterns
- About to write framework-specific code from memory

**When NOT to use:**
- Pure logic that works the same across all versions (loops, conditionals, data structures)
- Renaming variables or fixing typos
- The user explicitly asks for speed over verification ("just do it quickly")

## The Process

```
DETECT ──→ FETCH ──→ IMPLEMENT ──→ CITE
  │          │           │           │
  ▼          ▼           ▼           ▼
 What     Get the    Follow the   Show your
 stack?   relevant   documented   sources
          docs       patterns
```

### Step 1 — Detect stack and versions

Read the project's dependency file to find exact versions:

```
package.json / yarn.lock      → Node, React, Vue, Angular, Svelte
pyproject.toml / poetry.lock  → Python, Django, FastAPI, etc.
go.mod                        → Go + direct deps
Cargo.toml                    → Rust
Gemfile.lock                  → Ruby, Rails
pom.xml / build.gradle        → Java, Kotlin
composer.json                 → PHP, Symfony, Laravel
```

State what you found explicitly:

```
STACK DETECTED
- Python 3.11 (pyproject.toml)
- FastAPI 0.109.0
- SQLModel 0.0.14
- AWS CDK 2.110.0
→ Fetching official docs for the relevant patterns.
```

If versions are missing or ambiguous, **ask the user** — don't guess. The version determines which patterns are correct.

### Step 2 — Fetch official documentation

Fetch the specific documentation page for the feature you're implementing. Not the homepage. Not the full docs. The relevant page.

**Source hierarchy** (most to least authoritative):

| Priority | Source | Example |
|---|---|---|
| 1 | Official documentation | `react.dev`, `docs.djangoproject.com`, `fastapi.tiangolo.com` |
| 2 | Official blog / changelog | `react.dev/blog`, `docs.aws.amazon.com/whats-new` |
| 3 | Web standards / runtime | MDN, `web.dev`, caniuse.com, node.green |
| 4 | Type definitions | The library's `.d.ts` or `py.typed` stubs |

**Not authoritative — never cite as primary:**

- Stack Overflow answers
- Blog posts or tutorials (even popular ones)
- AI-generated docs or summaries
- Your own training data — that's the whole point, verify it

**Be precise with what you fetch:**

```
BAD:  Fetch the React homepage
GOOD: Fetch react.dev/reference/react/useActionState

BAD:  Search "FastAPI authentication best practices"
GOOD: Fetch fastapi.tiangolo.com/tutorial/security/oauth2-jwt/
```

After fetching, extract the key patterns and note any deprecation warnings or migration guidance.

If official sources conflict with each other (migration guide contradicts the API reference), surface the discrepancy to the user and verify against the detected version.

### Step 3 — Implement following documented patterns

Write code that matches what the documentation shows:

- Use API signatures from the docs, not from memory
- If the docs show a new way, use the new way
- If the docs deprecate a pattern, don't use it
- If the docs don't cover something, flag it as unverified

**When docs conflict with existing project code:**

```
CONFLICT DETECTED
The existing codebase uses manual useState for form loading state,
but React 19 docs recommend useActionState for this pattern.
(Source: react.dev/reference/react/useActionState)

Options:
A) Use the modern pattern (useActionState) — consistent with current docs
B) Match existing code (manual useState) — consistent with codebase

→ Which approach do you prefer?
```

Surface the conflict. Don't silently pick.

### Step 4 — Cite your sources

Every framework-specific pattern gets a citation. The user must be able to verify every decision.

**In code comments** (when the decision is non-obvious):

```
# FastAPI dependency injection for authenticated user
# Source: fastapi.tiangolo.com/tutorial/security/oauth2-jwt/#create-a-get_current_user-dependency
def get_current_user(token: Annotated[str, Depends(oauth2_scheme)]):
    ...
```

**In conversation:**

```
I used FastAPI's OAuth2PasswordBearer with PyJWT instead of the
legacy 'fastapi-jwt-auth' package. The docs recommend the OAuth2
scheme directly since 0.100.x.

Source: https://fastapi.tiangolo.com/tutorial/security/oauth2-jwt/
Quote: "The simplest way to validate JWT tokens is..."
```

**Citation rules:**

- Full URLs, not shortened
- Prefer deep links with anchors (`/useActionState#usage`, not the top-level page) — anchors survive doc restructuring better
- Quote the relevant passage when it supports a non-obvious decision
- Include runtime compatibility data when recommending platform features
- If you cannot find documentation, say so:

```
UNVERIFIED: I could not find official documentation for how to
handle <specific case>. This is based on training data and may
be outdated. Please verify before using in production.
```

Honesty about what you couldn't verify is more valuable than false confidence.

## When to invoke WebFetch vs rely on training

| Situation | Action |
|---|---|
| Writing code against a named framework at a specific version | Always fetch; training data may be stale |
| Using a standard library feature (e.g. `json.loads`) | Training data usually fine; cite MDN / language docs if non-obvious |
| Handling a known gotcha you can explain | Training data OK but cite the source of the gotcha |
| Implementing a security-sensitive pattern | Always fetch — security best practices evolve fastest |
| The user says "just use X" without specifying version | Ask for version first; then fetch |

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'm confident about this API" | Confidence is not evidence. Training data contains outdated patterns that look correct but break against current versions. Verify. |
| "Fetching docs wastes tokens" | Hallucinating an API wastes more. One fetch prevents hours of debugging a function signature that changed. |
| "The docs won't have what I need" | If docs don't cover it, that's valuable information — the pattern may not be officially recommended. Flag and proceed with care. |
| "I'll mention it might be outdated" | A disclaimer doesn't help. Either verify and cite, or clearly flag as unverified. Hedging is the worst option. |
| "This is a simple task, skip the check" | Simple tasks become templates. The user copies your deprecated form handler into ten components. |
| "Training data is recent enough" | "Recent" means nothing for framework APIs that change monthly. Verify. |

## Red Flags

- Writing framework-specific code without checking docs for that version
- Using "I believe" or "I think" about an API instead of citing a source
- Implementing a pattern without knowing which version it applies to
- Citing Stack Overflow / blog posts instead of official docs
- Using deprecated APIs because they appear in training data
- Not reading the dependency file before implementing
- Delivering code without source citations for framework-specific decisions
- Fetching an entire docs site when one page is relevant

## Verification

- [ ] Framework and library versions identified from the dependency file
- [ ] Official documentation fetched for the specific feature
- [ ] All sources are official docs, not blog posts or training data
- [ ] Code follows patterns shown in the current version's documentation
- [ ] Non-trivial decisions include source citations with full URLs
- [ ] No deprecated APIs used (checked against migration guides)
- [ ] Conflicts between docs and existing code surfaced to the user
- [ ] Anything unverifiable explicitly flagged
