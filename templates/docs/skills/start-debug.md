# /start-debug conventions

> Project-specific guidance for `/start-debug`. Read by the skill at the start of every run. Leave blank to use the skill's built-in defaults; anything added here layers on top of them.

## Notes for this project

*Common additions for `/start-debug`:*
*- Where to look first: log sources, dashboards, trace tools (Datadog / Honeycomb / Sentry URLs or CLI commands)*
*- Team playbooks for known failure classes (rate-limit hits, migration failures, cache misses, dependency outages)*
*- Debug-mode flags, env vars, or feature toggles that expose extra instrumentation*
*- Patterns that routinely cause false alarms in this codebase (known flaky tests, noisy logs to filter)*
*- How to reach a known-good baseline (last stable tag, a canary env, a local reset script)*

*(Delete the italicized hints above once you have real content. Leave the section blank to stick with plugin defaults.)*
