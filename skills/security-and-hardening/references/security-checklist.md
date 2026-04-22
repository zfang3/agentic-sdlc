# Security Checklist

Quick-reference for code and infrastructure review. Use alongside the
`security-and-hardening` skill.

## Pre-commit

- [ ] `git diff --cached | grep -iE 'password|secret|api[_-]?key|token'` — no hits
- [ ] `.gitignore` covers: `.env`, `.env.local`, `*.pem`, `*.key`, `credentials.json`
- [ ] `.env.example` uses placeholder values (not real secrets)

## Authentication

- [ ] Passwords hashed with bcrypt (≥12 rounds), scrypt, or argon2
- [ ] Session cookies: `httpOnly: true`, `secure: true`, `sameSite: 'lax'` (or `strict`)
- [ ] Session expiration configured (reasonable max-age)
- [ ] Rate limiting on login endpoint (≤10 attempts per 15 minutes per IP)
- [ ] Password reset tokens: time-limited (≤1 hour), single-use, bound to user
- [ ] Logout invalidates session server-side
- [ ] MFA supported for sensitive operations (optional but recommended)
- [ ] Account lockout after repeated failures (optional, with notification)

## Authorization

- [ ] Every protected endpoint checks authentication
- [ ] Every resource access checks ownership/role (prevents IDOR)
- [ ] Admin endpoints require admin role verification
- [ ] API keys scoped to minimum necessary permissions
- [ ] JWT tokens validated (signature, expiration, issuer, audience)
- [ ] Return 404 for resources the user can't see (not 403 — don't leak existence)

## Input validation

- [ ] All user input validated at system boundaries
- [ ] Validation uses allowlists, not denylists
- [ ] String lengths constrained (min and max)
- [ ] Numeric ranges validated
- [ ] Email, URL, date formats validated with proper libraries
- [ ] File uploads: type restricted (allowlist), size limited, content verified (magic bytes)
- [ ] SQL queries parameterized (no string concatenation)
- [ ] HTML output encoded (framework auto-escape, or explicit escape)
- [ ] Shell commands use argv arrays (no `shell=True` with user input)
- [ ] URLs validated before redirect (prevent open redirect)
- [ ] File paths validated (no `../` traversal)

## Security headers

```
Content-Security-Policy: default-src 'self'; script-src 'self'
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=()
```

## CORS

```
# Restrictive (recommended)
{
  origin: ['https://yourdomain.com', 'https://app.yourdomain.com'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}

# Never in production
{ origin: '*' }
```

## Data protection

- [ ] Sensitive fields excluded from API responses (passwordHash, resetToken, full card numbers)
- [ ] Sensitive data not in logs (passwords, tokens, PII beyond what's needed)
- [ ] PII encrypted at rest where required by regulation
- [ ] HTTPS for all external communication
- [ ] Database backups encrypted
- [ ] Soft-delete vs hard-delete semantics explicit

## Dependency security

```
npm audit
npm audit fix
npm audit --audit-level=high

pip-audit
pip-audit --fix

cargo audit
```

Triage by severity + reachability. Fix Critical / High before release.

## Error handling

```
# Production: generic, no internals
res.status(500).json({
  error: { code: 'INTERNAL_ERROR', message: 'Something went wrong' }
});

# Never in production
res.status(500).json({
  error: err.message,
  stack: err.stack,       # exposes internals
  query: err.sql,         # exposes database details
});
```

## Rate limiting

- [ ] Login endpoint: ≤10 attempts / 15 min / IP
- [ ] Signup endpoint: rate-limited per IP
- [ ] Password reset: rate-limited per email + per IP
- [ ] Expensive endpoints (search, export): rate-limited per user
- [ ] Global rate limit as a final safety net

## Infrastructure (IaC)

- [ ] No public access on data stores (S3 block-public-access, DB private subnet)
- [ ] IAM policies follow least privilege (no `*` resources or actions)
- [ ] Encryption at rest: S3 SSE, RDS encrypted, EBS encrypted
- [ ] Encryption in transit: TLS 1.2+ only
- [ ] Secrets in secret manager, not in Lambda env vars or ECS task definitions
- [ ] VPC security groups restrict ingress to necessary ports only
- [ ] Logs and metrics enabled (auth events, admin actions)
- [ ] CloudTrail / audit logs retained per policy
- [ ] Resources tagged for cost + compliance
- [ ] DR / backup plan documented and tested

## OWASP Top 10 quick reference

| # | Vulnerability | Prevention |
|---|---|---|
| 1 | Broken access control | Auth check every endpoint, ownership verification |
| 2 | Cryptographic failures | HTTPS, strong hashing, secret manager |
| 3 | Injection | Parameterized queries, allowlist validation |
| 4 | Insecure design | Threat-model at design time |
| 5 | Security misconfiguration | Headers, minimal perms, dep audit |
| 6 | Vulnerable components | Regular audits, minimal deps, trusted sources |
| 7 | Auth failures | Strong passwords, rate limit, session mgmt |
| 8 | Integrity failures | Verify deps, signed artifacts, lockfiles |
| 9 | Logging failures | Log security events, don't log secrets |
| 10 | SSRF | Validate / allowlist outbound URLs |
