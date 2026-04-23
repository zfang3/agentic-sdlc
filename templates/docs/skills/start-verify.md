# /start-verify conventions

> Project-specific guidance for `/start-verify`. Read by the skill at the start of every run — layered on top of, not instead of, `docs/architecture/verification.md` primitives and the session's verification contract. Leave blank to use the skill's built-in defaults.

## Notes for this project

*Common additions for `/start-verify`:*
*- Additional review-pass axes beyond the defaults (accessibility, i18n, observability, data privacy)*
*- Severity tuning — what the team treats as CRITICAL vs HIGH for this codebase*
*- Verdict thresholds tighter or looser than defaults (e.g. "ship only on PASS; never on PASS_WITH_CONCERNS")*
*- Mandatory post-runtime checks (e.g. "after runtime verification, check Sentry for new error signatures")*
*- Conventions for handling flaky contract items (e.g. "runtime artifacts that have flaked twice go to Declared exclusions with rationale pointing at a tracked issue")*

*(Delete the italicized hints above once you have real content. Leave the section blank to stick with plugin defaults.)*
