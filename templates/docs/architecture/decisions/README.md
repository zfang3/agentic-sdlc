# Architecture Decision Records (ADRs)

Significant architectural decisions are recorded here. Each ADR captures:

- The decision made
- The context that forced the decision
- The alternatives considered
- The consequences (both good and bad)

## Why ADRs?

Code shows *what*. ADRs show *why*, *when*, and *what else was on the table*. Six
months later, when someone asks "why don't we use a queue here?", the ADR
answers — without re-litigating.

## When to write an ADR

- Choosing a framework, library, or major dependency
- Designing a data model that's hard to change
- Selecting an authentication strategy
- Deciding on API shape (REST vs GraphQL vs tRPC)
- Choosing between build tools, hosting platforms, or infrastructure shapes
- Any decision that would be **expensive to reverse**

Don't write ADRs for tactical choices (variable naming, file layout).

## How to write one

1. Copy [`ADR-0000-template.md`](ADR-0000-template.md) to `ADR-NNNN-<short-slug>.md`, bumping the number.
2. Fill in every section. Be specific.
3. Commit the ADR alongside (or ahead of) the code change that implements it.
4. If a later decision supersedes this one, don't delete it — mark it
   "Superseded by ADR-XXXX" and leave the content intact. ADRs are history,
   not current state.

## Index

*No ADRs yet. Add the first one as `ADR-0001-<slug>.md` and link it here with the date it was accepted. Keep the list in reverse chronological order (newest first).*
