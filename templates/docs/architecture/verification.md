# Verification

> **Status**: draft — fill in during `/start-bootstrap` and keep current via `/start-sync`.
>
> This file is the **primitives library** that every session's verification contract
> (`docs/sessions/<YYYY-MM-DD>-<slug>/verification.md`) references. It declares HOW
> this project is compiled, tested, started, exercised, and torn down. It does NOT
> declare WHAT any specific change must verify — that belongs in the session contract,
> authored by `/start-plan` and executed by `/start-verify`.

## Project shape

*These fields gate which stanzas below apply. `/start-verify` uses them to decide what must run.*

- **Type**: \<one of: library | cli | web-service | data-pipeline | iac | plugin | other\>
- **Has runtime**: \<true | false\> — does "running the system" mean something beyond running tests?
- **Defined runtimes**: \<comma-separated names matching the `### Runtime:` sub-sections below, e.g. `local, pr-preview`\> — only filled when `Has runtime: true`
- **Default runtime**: \<one of the above\> — which runtime `/start-verify` uses when a contract does not explicitly name one; typically `local`

## Gate primitives

*Deterministic, fast-feedback commands. Each MUST be runnable in isolation from the repo root and exit non-zero on failure. Session contracts select which of these apply to a given plan.*

- **compile**: `<command>` — compiles or type-checks the whole project
- **lint**: `<command>` — fails on any style / convention violation
- **typecheck**: `<command or "not separate from compile">`
- **unit**: `<command>` — full unit test suite
- **integration**: `<command or "not applicable">`

*If the project adds new gate primitives later (contract tests, schema lint, mutation tests, etc.), add them here with a stable key so session contracts can reference them by name.*

## Runtime primitives

*Commands for bringing the system up, exercising it, and tearing it down. Delete this entire section if `Has runtime: false`.*

*Most projects run against more than one environment — at minimum `local` (docker compose, dev server, local binary) and often one or more remote runtimes (`pr-preview` per PR, `staging`, `integration`). Declare each as a `### Runtime: <name>` sub-block below with its own full set of primitives. Session contracts pick which runtime applies to each verify pass by name. If the project genuinely has only one, keep just `### Runtime: local`.*

### Runtime: local

*Required. The default when a contract does not explicitly name a runtime.*

- **precondition**: `<command or "none">` — verify the runtime is reachable before running anything else; non-zero fails `/start-verify` early with a clear message
- **start**: `<command>` — brings the system up locally; idempotent; blocks until ready (or uses `ready-check` to poll)
- **ready-check**: `<command>` — returns 0 when the system accepts traffic; cheap enough to poll
- **teardown**: `<command>` — brings the system down cleanly; safe to run even if nothing started
- **invoke**: `<command template>` — parameterized invocation (HTTP, CLI, SQL). Name placeholders, e.g. `$URL`, `$OUT_PATH`.
- **inspect**: `<command template>` — parameterized observation (log tail, DB query, file read). Used after `invoke` to check side-effect state.

### Runtime: pr-preview

*Optional. Delete this entire block if the project does not use PR preview environments (Vercel Previews, Netlify Deploy Previews, Fly.io Review Apps, Cloudflare Pages, Railway, Heroku Review Apps, etc.).*

- **precondition**: `<command>` — e.g. `gh pr view --json number --jq .number` returns a PR number; without a PR, this runtime is not usable this session
- **start**: `<command or "not applicable — provisioned by CI on PR open">` — only if the agent can drive provisioning; otherwise the CI pipeline owns this
- **ready-check**: `<command>` — returns 0 when the preview URL is live; typically `curl -sf $PREVIEW_URL/health`
- **teardown**: `<command or "not applicable — destroyed on PR close">`
- **invoke**: `<command template>` — against the preview URL; include `$PREVIEW_URL` as a placeholder the contract binds
- **inspect**: `<command template>` — against the preview's logs / DB / metrics, using whatever tooling the preview platform exposes

### Runtime: \<name\>

*Add more runtimes (e.g. `staging`, `integration`, `localstack`) as needed, each with its own complete block. Session contracts select by name, so runtime names must be unique and stable.*

*Session contracts compose these with plan-specific parameters, e.g. `invoke (runtime=local) URL=http://localhost:8080/health OUT_PATH=tmp/verify/T1-health.json`.*

## Artifact conventions

- **Output directory**: `tmp/verify/` — every verification artifact lands here; this directory is gitignored.
- **One file per artifact**, file name encodes the task and what it captures (e.g. `tmp/verify/T3-endpoint.json`, `tmp/verify/T4-email-log.txt`).
- **Capture stdout AND stderr** — exit code alone is insufficient evidence. A passing command with unexpected stderr is still a finding.
- **Artifacts are the evidence** cited by `docs/sessions/<session>/verify.md`; every PASS/FAIL entry points to a specific file path.

## Declared assumptions

*Project-level invariants the primitives above assume. Surface them upfront so agents don't discover them mid-verification. Remove this section if there are none — empty stanzas are a red flag.*

- \<assumption, e.g. `.env.test` exists at repo root\>
- \<assumption, e.g. Docker daemon running\>
- \<assumption, e.g. local port 5432 free for Postgres\>

## Related documents

- [Architecture overview](overview.md) — what the system is and how it's put together
- Session verification contracts — `docs/sessions/<YYYY-MM-DD>-<slug>/verification.md`, one per plan

## History of change

*Append a dated line when the primitives change materially. Git history is the long-term archive.*

- \<YYYY-MM-DD\> — initial primitives defined during `/start-bootstrap`
