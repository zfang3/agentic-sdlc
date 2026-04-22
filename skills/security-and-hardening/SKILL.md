---
name: security-and-hardening
description: Apply security-first patterns when handling user input, authentication, authorization, secrets, file uploads, or external integrations. Use during any change that touches user data or system boundaries.
category: technique
user-invocable: false
---

# Security and Hardening

## Overview

Security isn't a phase you add before shipping. It's a constraint on every line of code that handles user data, auth, or external systems. Three tiers: always do, ask first, never do.

The principle: **treat every input as malicious until validated, and every output as public until encoded.**

## When to Use

- Handling user input (forms, API bodies, query params, headers, file uploads)
- Authentication or authorization changes
- Storing or transmitting sensitive data
- Integrating with external services
- Writing infrastructure (IAM, network, storage config)
- Before committing code that touches any of the above

**When NOT to use:**
- Pure computation with no external input
- Tests that don't involve real credentials
- Internal tooling that never touches user data

If unsure, err toward applying the skill — security issues are asymmetric.

## Three-tier boundary system

### Always do (no exceptions)

- Validate all external input at system boundaries
- Parameterize database queries (never concatenate user input into SQL)
- Encode output to prevent XSS (use framework auto-escape)
- Use HTTPS for all external communication
- Hash passwords with bcrypt / scrypt / argon2 (≥12 rounds for bcrypt)
- Set security headers (CSP, HSTS, X-Content-Type-Options, X-Frame-Options)
- Use httpOnly + secure + sameSite cookies for sessions
- Run `npm audit` / `pip-audit` / `cargo audit` before every release
- Rate-limit authentication endpoints
- Log auth events (successful + failed) without logging credentials

### Ask first (requires human approval)

- New authentication flows or auth logic changes
- Storing new categories of sensitive data (PII, health, financial)
- New external service integrations
- CORS configuration changes
- File upload handlers
- Permission or role elevation
- Changes to rate limits
- Changes to audit / compliance logging

### Never do

- Commit secrets to version control
- Log sensitive data (passwords, tokens, full card numbers, health records)
- Trust client-side validation as a security boundary
- Disable security headers for convenience
- Use `eval()` / `exec()` / `innerHTML` with user data
- Store auth tokens in client-accessible storage (localStorage, non-httpOnly cookies)
- Expose stack traces or internal error details to users
- Use weak crypto (MD5, SHA-1 for passwords, DES, ECB mode)

## OWASP Top 10 prevention

### 1. Broken access control

Every protected endpoint verifies:

```
# Authentication — is this request from a logged-in user?
# Authorization — does this user have permission for THIS resource?

@router.get("/tasks/{task_id}")
async def get_task(task_id: str, user: User = Depends(get_current_user)):
    task = await db.get_task(task_id)
    if task is None:
        raise HTTPException(404, "Not found")
    # IDOR prevention — ownership check
    if task.owner_id != user.id and not user.is_admin:
        raise HTTPException(404, "Not found")  # same as missing, on purpose
    return task
```

Return 404 (not 403) for resources the user isn't allowed to see. 403 leaks existence.

### 2. Cryptographic failures

- **HTTPS everywhere** — HSTS header with `max-age=31536000; includeSubDomains`
- **Password hashing** — bcrypt (cost ≥12), scrypt, or argon2. Never MD5, SHA-1, SHA-256 (too fast)
- **Secrets** — environment variables or secret manager, never hardcoded
- **Key rotation** — plan for it at design time

### 3. Injection

**SQL**:

```
# Never
query = f"SELECT * FROM users WHERE email = '{email}'"

# Parameterized
query = "SELECT * FROM users WHERE email = %s"
cursor.execute(query, (email,))

# ORM (usually safe by default)
user = session.query(User).filter_by(email=email).first()
```

**Command injection**:

```
# Never
os.system(f"convert {user_file} out.png")

# Use argv
subprocess.run(["convert", user_file, "out.png"], check=True)
```

**XSS**:

```
# Framework auto-escape — usually safe
<div>{userInput}</div>

# Never with user input
dangerouslySetInnerHTML={{ __html: userInput }}
# If you must render HTML, sanitize with DOMPurify / Bleach
```

### 4. Insecure design

- Threat-model at design time, not after
- Least privilege by default; elevate only where needed
- Fail closed (deny by default); fail open only with explicit rationale

### 5. Security misconfiguration

Security headers:

```
Content-Security-Policy: default-src 'self'; script-src 'self'
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=()
```

CORS — restrict to known origins:

```
# Good
cors({
  origin: ['https://app.example.com'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
})

# Never
cors({ origin: '*' })
```

### 6. Vulnerable components

```
npm audit
npm audit fix
pip-audit
cargo audit
```

Triage by severity + reachability. A Critical in unused code path is lower priority than a Medium in the auth flow.

### 7. Authentication failures

- Rate limit login: ≤10 attempts / 15 min / IP
- Password reset tokens: time-limited (≤1 hour), single-use, bound to the user
- MFA supported for sensitive operations
- Session expiration configured
- Logout invalidates the session server-side (not just clearing a cookie)

### 8. Software integrity failures

- Verify integrity of downloaded dependencies (lockfiles + SHA checks)
- Signed commits when the team uses them
- CI artifacts signed or checksummed
- Use trusted package sources (npm, PyPI, crates.io — not random URLs)

### 9. Security logging failures

Log these events (without sensitive payload):

- Authentication success / failure
- Authorization denials
- Admin actions
- Configuration changes
- Data export / bulk access

Don't log:

- Passwords (ever, even hashed)
- Full tokens / API keys
- Full card numbers
- Sensitive PII beyond what's needed for the log line

### 10. SSRF (server-side request forgery)

- Validate / allowlist outbound URLs when the target is user-supplied
- Block internal network ranges (`10.0.0.0/8`, `169.254.0.0/16`, etc.)
- Don't follow redirects automatically to user-supplied URLs

## Input validation

Schema validation at every boundary:

```
# Zod (TS)
const CreateTaskSchema = z.object({
  title: z.string().min(1).max(200),
  description: z.string().max(5000).optional(),
  priority: z.enum(['low', 'medium', 'high']).default('medium'),
});

# Pydantic (Python)
class CreateTaskInput(BaseModel):
    title: Annotated[str, Field(min_length=1, max_length=200)]
    description: Annotated[str, Field(max_length=5000)] | None = None
    priority: Literal['low', 'medium', 'high'] = 'medium'
```

File uploads:

- Restrict MIME types via allowlist
- Check file size limits
- Validate magic bytes for critical operations (not just the filename extension)
- Store outside the web root when possible
- Scan for malware if handling user content at scale

## Secrets management

```
# Never commit
cat << EOF >> .gitignore
.env
.env.local
*.pem
*.key
credentials.json
EOF

# Commit only a template
cp .env .env.example
# Replace values with placeholders in .env.example

# In code, fail closed if missing
api_key = os.environ.get("API_KEY")
if not api_key:
    raise RuntimeError("API_KEY is required")
```

For production: a secret manager (AWS Secrets Manager, HashiCorp Vault, GCP Secret Manager). Rotation is part of the operational plan.

## Pre-deployment checklist

- [ ] No secrets in code (`git log -S "api_key"`, `gitleaks detect`)
- [ ] `npm audit` / `pip-audit` — no Critical or High
- [ ] Input validation on every user-facing endpoint
- [ ] Auth checks on every protected endpoint
- [ ] Security headers configured
- [ ] Rate limiting on auth + expensive endpoints
- [ ] CORS restricted to known origins
- [ ] Error responses don't leak internals
- [ ] Sensitive fields excluded from API responses
- [ ] HTTPS enforced
- [ ] Dependencies from trusted sources

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "It's a low-risk change, skip security review" | Every change that touches input/auth/secrets needs security review. "Low risk" is how vulnerabilities ship. |
| "The dev environment doesn't need TLS" | Dev without TLS teaches habits that leak to prod. |
| "We validate on the frontend, backend validation is redundant" | Frontend validation is UX. Backend validation is security. Both. |
| "This env var is only in CI, committing is fine" | CI env vars become production env vars. Treat all secrets the same. |
| "Users won't find the undocumented endpoint" | Attackers will. Security through obscurity fails. |
| "We'll add rate limiting if we see abuse" | Attackers don't announce themselves. Rate-limit auth from day one. |
| "The framework handles XSS" | Only if you don't bypass it (no `innerHTML`, `dangerouslySetInnerHTML`, `|raw`, etc.) |

## Red Flags

- Hardcoded credentials anywhere
- SQL queries built with string interpolation
- `eval()`, `exec()`, `innerHTML`, `dangerouslySetInnerHTML` with user data
- Missing auth check on a protected endpoint
- CORS `*`
- `TLS 1.0` or `SSL` anywhere
- MD5 / SHA-1 / SHA-256 for password hashing
- Error responses that include stack traces
- "It's just for testing" disabling a security check
- Tokens in URL query strings (leak to logs, referers)

## Verification

- [ ] Input validation at system boundaries
- [ ] SQL queries parameterized
- [ ] Auth enforced where needed
- [ ] Secrets not in code or logs
- [ ] Security headers configured
- [ ] `npm audit` / equivalent passes
- [ ] Rate limiting on auth
- [ ] CORS restricted
- [ ] Error responses sanitized
- [ ] Pre-deployment checklist run

See [security-checklist.md](references/security-checklist.md) for the full checklist.
