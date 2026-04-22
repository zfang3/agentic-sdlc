# Verification Checklist

The subagent spawned in Phase 2 of `/start-verify` works through these four passes in
parallel. Each finding goes on a severity (CRITICAL / HIGH / MEDIUM / LOW / PASS)
with a file:line reference.

## Pass 1 — Spec compliance

Check every acceptance criterion from the spec against the actual code and tests.

- [ ] Every AC in `spec.md` has a corresponding test or code line that satisfies it
- [ ] No AC is partially implemented and claimed complete
- [ ] No AC is silently descoped
- [ ] Non-goals from the spec are actually not implemented (check for scope creep)
- [ ] Open questions from the spec are resolved (or explicitly deferred, with a note)

## Pass 2 — Codebase consistency

Check that new code matches existing patterns.

- [ ] Naming follows project conventions (snake_case vs camelCase, etc.)
- [ ] Imports are organized per project style
- [ ] Error handling matches existing patterns (exceptions vs result types, log levels)
- [ ] Logging follows project format and severity conventions
- [ ] Test file naming and layout match the rest of the repo
- [ ] Tests use existing fixtures/helpers where they exist
- [ ] New configuration uses the existing config mechanism (no new env vars that could be in the config system)
- [ ] No hardcoded values that should be config/constants
- [ ] No commented-out code or debug artifacts left behind
- [ ] Documentation follows existing conventions (docstrings, type hints)

## Pass 3 — Data integrity and boundaries

Trace data end-to-end. Check every transformation.

- [ ] Field names consistent from input to storage to output
- [ ] Field types consistent (no silent coercions that could lose data)
- [ ] Nullable fields handled at every layer (no `None` access crashes)
- [ ] Validation happens at system boundaries (user input, external API responses, config loading)
- [ ] Validation error messages are specific and actionable
- [ ] Required fields are actually required (no silent defaulting that hides missing data)
- [ ] Optional fields have a consistent semantics (None = not applicable, "" = applicable but empty — pick one and stick to it)
- [ ] Enum values serialize/deserialize correctly
- [ ] Datetime fields use a consistent timezone representation
- [ ] IDs/UUIDs are validated before use in queries

### Cross-repo / cross-system (when applicable)

- [ ] Producer and consumer field lists match
- [ ] Producer and consumer type expectations match
- [ ] Nullability agreed between producer and consumer
- [ ] Enum value sets match between producer and consumer
- [ ] Versioning handled if either side can upgrade independently
- [ ] Deployment ordering documented if one side depends on the other shipping first

## Pass 4 — Self-check

Adversarially review passes 1-3.

For each finding raised in passes 1-3:

- [ ] Is the citation accurate? (Re-read the file:line — does it really say that?)
- [ ] Does the finding follow from the evidence? (Not just "looks wrong to me")
- [ ] Is it a real issue or a style preference?
- [ ] Does another context (an ADR or a note in `docs/architecture/overview.md`) explain it?

Then look for what passes 1-3 might have missed:

- [ ] Boundary conditions (0, 1, empty, null, max)
- [ ] Concurrency (two requests hit at once — can state corrupt?)
- [ ] Partial failure (the DB write succeeds but the downstream call fails)
- [ ] Retry behavior (idempotent? will replay cause duplicate side-effects?)
- [ ] Authorization (who is allowed to call this? is that enforced?)
- [ ] Rate limits / resource bounds (unbounded loops? unbounded data fetches?)
- [ ] Error message safety (do they leak internal details or user data?)

## Infrastructure / IaC (when applicable)

- [ ] No public access granted that wasn't explicit in the spec
- [ ] IAM policies follow least-privilege (no `*` resources or actions)
- [ ] Encryption at rest configured for storage
- [ ] Secrets loaded from the project's secret manager, not hardcoded or env-baked
- [ ] Resources have alarms / monitoring for the failure modes the spec cares about
- [ ] Removal policies appropriate for the environment (DESTROY in dev, RETAIN in prod)
- [ ] Changes are backward-compatible with running instances (migrations, gradual rollouts)
- [ ] Cost implications acknowledged (no accidental autoscaling / no unbounded storage)

## Tests

- [ ] Every task's acceptance criterion has at least one test
- [ ] Edge cases mentioned in the plan have tests
- [ ] Error cases have tests (not just happy paths)
- [ ] Tests have descriptive names (a reader can infer intent from the name)
- [ ] Tests don't depend on order of execution
- [ ] Tests don't depend on the clock, network, or filesystem unless explicitly isolated
- [ ] No tests are skipped or disabled

## Performance (when the spec cares)

- [ ] No N+1 query patterns in hot paths
- [ ] No unbounded loops or data fetches
- [ ] Pagination on list endpoints
- [ ] Appropriate indexes on new queries
- [ ] Large payloads streamed, not loaded into memory

## Documentation

- [ ] If a public interface changed, its docs changed
- [ ] If a config option was added, it's documented
- [ ] If a decision was made that's not obvious from the code, there's an ADR in `docs/architecture/decisions/`
- [ ] README or quick-start hasn't gone stale relative to the change
