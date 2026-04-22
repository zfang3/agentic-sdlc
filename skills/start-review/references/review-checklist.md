# Review Checklist

The reviewer works through these five axes. Every finding gets a severity
(CRITICAL / IMPORTANT / SUGGESTION / Nit / FYI) and a file:line reference.

## 1. Correctness

- [ ] Implementation matches the spec or ticket AC
- [ ] Edge cases handled: null/None, empty collections, zero, negative, max boundary
- [ ] Error paths handled (not just the happy path)
- [ ] Off-by-one errors checked (loops, indexing, ranges)
- [ ] Race conditions considered (concurrent requests, async ordering)
- [ ] State transitions valid (no invalid state reachable)
- [ ] Resource cleanup on error (no leaks when things fail)
- [ ] Tests cover the change and would catch regressions
- [ ] Tests assert behavior, not implementation details
- [ ] Tests have descriptive names

## 2. Readability & simplicity

- [ ] Names are descriptive and consistent with project conventions
  - No generic names (`data`, `result`, `temp`, `x`) without surrounding context
  - No abbreviations that aren't universal (`usr`, `cfg`, `btn` — bad; `id`, `url`, `api` — OK)
- [ ] Control flow is straightforward
  - No deeply nested conditionals (>3 levels)
  - No nested ternaries
  - Guard clauses used to reduce nesting
- [ ] Functions are focused (one clear purpose, <~50 lines)
- [ ] Files are focused (<~500 lines unless generated)
- [ ] Could this be done in fewer lines without hurting clarity?
- [ ] Abstractions earn their complexity (rule of three — don't generalize until used 3x)
- [ ] Comments explain WHY, not WHAT
  - Good: `// Rate limit uses sliding window to prevent burst attacks at edges`
  - Bad: `// Increment counter by 1`
- [ ] No dead code: unreachable branches, unused variables, commented-out blocks
- [ ] No `_unused` variables or `// removed` comments — delete instead

## 3. Architecture

- [ ] Follows existing patterns, or justifies the new one
- [ ] Module boundaries respected (no cross-module internals accessed)
- [ ] No circular dependencies introduced
- [ ] Dependencies flow in the right direction (high-level doesn't depend on low-level specifics)
- [ ] Appropriate abstraction level (not over-engineered, not too coupled)
- [ ] No speculative generality — abstraction introduced only for actual need
- [ ] Side effects at the edges (pure functions in the middle)
- [ ] Configuration separated from logic (no hardcoded values that belong in config)

## 4. Security

### Input handling
- [ ] All external input validated at system boundaries
- [ ] Validation uses allowlists, not denylists
- [ ] String lengths constrained
- [ ] Numeric ranges validated
- [ ] File uploads: type + size + content verified
- [ ] URLs validated before redirect (prevent open redirect)

### Injection prevention
- [ ] SQL queries parameterized (no string concatenation with user input)
- [ ] HTML output encoded (framework auto-escape used, or explicit escape)
- [ ] Shell commands parameterized (no `shell=True` with user input)
- [ ] File paths validated (no `../` traversal)

### Authentication & authorization
- [ ] Every protected endpoint checks authentication
- [ ] Every resource access checks ownership/role (prevents IDOR)
- [ ] Admin endpoints verify admin role
- [ ] Tokens validated (signature, expiration, issuer)

### Secrets
- [ ] No secrets in code
- [ ] No secrets in logs
- [ ] No secrets in error responses
- [ ] Secrets loaded from secret manager, not env-baked at build time

### Headers & CORS (when applicable)
- [ ] Security headers set (CSP, HSTS, X-Frame-Options, X-Content-Type-Options)
- [ ] CORS restricted to known origins (not wildcard)
- [ ] Session cookies: httpOnly, secure, sameSite

### Dependencies
- [ ] No new dependencies with known critical/high vulnerabilities
- [ ] New dependencies are actively maintained
- [ ] License compatible with the project

## 5. Performance

- [ ] No N+1 query patterns
- [ ] No unbounded loops or data fetches
- [ ] Pagination on list endpoints
- [ ] Async used where appropriate (no sync calls blocking event loops)
- [ ] Indexes exist for new queries
- [ ] Large payloads streamed, not loaded
- [ ] Hot paths avoid unnecessary allocations
- [ ] Cache use justified (and invalidation considered)

## Verification story

- [ ] Tests listed in the PR description actually ran
- [ ] Build passed
- [ ] For UI: screenshots or description of manual test
- [ ] For infra: verified resources exist with expected config
- [ ] PR description matches what the diff actually changes

## Change sizing

- [ ] ≤100 lines: good, single-sitting review
- [ ] 100-300 lines: acceptable if one logical change
- [ ] 300-1000 lines: split unless automated refactor or file deletions
- [ ] >1000 lines: split (unless pure deletions or auto-generated)
- [ ] Refactoring and feature work NOT mixed in the same diff

## Dead code hygiene

After a refactor:
- [ ] No orphaned functions, classes, files
- [ ] No unused imports
- [ ] No feature-flagged branches that are now dead
- [ ] Old implementations deleted (not kept as `_old` or `_legacy` versions)
