---
name: api-and-interface-design
description: Design stable, well-documented public interfaces — REST, GraphQL, MCP tools, module boundaries, component props. Use when creating or changing any contract between parts of the system. NOT for internal helper functions.
category: technique
user-invocable: false
---

# API and Interface Design

## Overview

Design interfaces that are hard to misuse. Good interfaces make the right thing easy and the wrong thing hard. This applies to REST APIs, GraphQL schemas, MCP tool contracts, module boundaries, component props — anywhere one piece of code talks to another.

The principle: **every observable behavior becomes a contract once users depend on it.** Hyrum's Law — if it's visible, somebody will depend on it. Design intentionally about what you expose.

## When to Use

- Designing new API endpoints
- Defining module boundaries or contracts between teams
- Creating component prop interfaces
- Defining MCP tool schemas
- Establishing database schema that informs API shape
- Changing any existing public interface

**When NOT to use:**
- Purely internal helper functions (still good to have clean signatures, but no contract discipline needed)
- One-off scripts
- Test-only code

## Core principles

### 1. Hyrum's Law

> With a sufficient number of users of an API, all observable behaviors of your system will be depended on by somebody, regardless of what you promise in the contract.

Implications:

- **Be intentional about what you expose.** Every observable behavior is a potential commitment.
- **Don't leak implementation details.** If users can observe it, they will depend on it.
- **Plan for deprecation at design time.** See the deprecation section below.
- **Tests aren't enough.** Even with perfect contract tests, Hyrum's Law means "safe" changes can break real users who depend on undocumented behavior.

### 2. The one-version rule

Avoid forcing consumers to choose between multiple versions of the same dependency or API. Diamond dependency problems arise when different consumers need different versions. Design for a world where only one version exists at a time — extend rather than fork.

### 3. Contract first

Define the interface before implementing. The contract is the spec — implementation follows.

```
# Define the contract first
interface TaskAPI {
  # Creates a task and returns it with server-generated fields
  createTask(input: CreateTaskInput): Promise<Task>;

  # Returns paginated tasks matching filters
  listTasks(params: ListTasksParams): Promise<PaginatedResult<Task>>;

  # Returns a task, or throws NotFoundError
  getTask(id: string): Promise<Task>;

  # Partial update — only provided fields change
  updateTask(id: string, input: UpdateTaskInput): Promise<Task>;

  # Idempotent delete — succeeds even if already deleted
  deleteTask(id: string): Promise<void>;
}
```

### 4. Consistent error semantics

Pick one error strategy and use it everywhere.

```
# REST: HTTP status + structured body
interface APIError {
  error: {
    code: string;        # machine-readable: "VALIDATION_ERROR"
    message: string;     # human-readable: "Email is required"
    details?: unknown;   # additional context when helpful
  };
}

# Status codes (pick a subset and stick to it)
# 400 Bad Request — client sent invalid data
# 401 Unauthorized — not authenticated
# 403 Forbidden — authenticated but not authorized
# 404 Not Found — resource doesn't exist
# 409 Conflict — duplicate or version mismatch
# 422 Unprocessable — validation failed
# 500 Internal — server error (never leak details)
```

**Don't mix patterns.** If some endpoints throw, others return null, and others return `{ error }`, consumers can't predict behavior.

### 5. Validate at boundaries

Trust internal code. Validate at system edges where external input enters.

```
# API handler
app.post('/api/tasks', async (req, res) => {
  const result = CreateTaskSchema.safeParse(req.body);
  if (!result.success) {
    return res.status(422).json({
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Invalid task data',
        details: result.error.flatten(),
      },
    });
  }

  # After validation, internal code trusts the types
  const task = await taskService.create(result.data);
  return res.status(201).json(task);
});
```

**Where validation belongs:**
- API route handlers (user input)
- Form submission handlers (user input)
- External service response parsing (always untrusted)
- Environment variable loading
- Message queue payloads

**Where validation does NOT belong:**
- Between internal functions that share type contracts
- Utility functions called by already-validated code
- Data that came from your own database (unless multi-writer)

Third-party API responses are untrusted data. Validate their shape and content before using them in any logic, rendering, or decision-making.

### 6. Prefer addition over modification

Extend interfaces without breaking existing consumers.

```
# Good — optional additions
interface CreateTaskInput {
  title: string;
  description?: string;
  priority?: 'low' | 'medium' | 'high';   # added later, optional
  labels?: string[];                       # added later, optional
}

# Bad — change existing field types or remove fields
interface CreateTaskInput {
  title: string;
  # description: string;    # removed — breaks existing consumers
  priority: number;          # type changed — breaks existing consumers
}
```

### 7. Predictable naming

| Pattern | Convention | Example |
|---|---|---|
| REST endpoints | Plural nouns, no verbs | `GET /api/tasks`, `POST /api/tasks` |
| Query params | camelCase or snake_case (pick one) | `?sortBy=createdAt&pageSize=20` |
| Response fields | match the query-param casing | `{ createdAt, updatedAt, taskId }` |
| Boolean fields | `is/has/can` prefix | `isComplete`, `hasAttachments` |
| Enum values | UPPER_SNAKE or exact-casing, consistent | `"IN_PROGRESS"`, `"COMPLETED"` |
| Timestamps | ISO 8601, UTC | `"2026-04-22T14:30:00Z"` |

## REST API patterns

### Resource design

```
GET    /api/tasks              list tasks (with filter query params)
POST   /api/tasks              create a task
GET    /api/tasks/:id          get a single task
PATCH  /api/tasks/:id          partial update
PUT    /api/tasks/:id          full replacement (rarely what you want)
DELETE /api/tasks/:id          delete

GET    /api/tasks/:id/comments list comments (sub-resource)
POST   /api/tasks/:id/comments add a comment
```

Verbs in URLs (`/api/createTask`) are a smell — pick the HTTP method that matches the action instead.

### Pagination

Every list endpoint paginates:

```
GET /api/tasks?page=1&pageSize=20&sortBy=createdAt&sortOrder=desc

{
  "data": [...],
  "pagination": {
    "page": 1,
    "pageSize": 20,
    "totalItems": 142,
    "totalPages": 8
  }
}
```

Or cursor-based (better for consistency with inserts):

```
GET /api/tasks?cursor=<opaque>&limit=20

{
  "data": [...],
  "nextCursor": "<opaque>",
  "hasMore": true
}
```

### Filtering

Query parameters for filters:

```
GET /api/tasks?status=in_progress&assignee=user123&createdAfter=2025-01-01
```

### Partial updates (PATCH)

PATCH accepts partial objects — only update what's provided:

```
PATCH /api/tasks/123
{ "title": "Updated title" }
```

## Type-level patterns

### Discriminated unions for variants

```
# Good — each variant is explicit
type TaskStatus =
  | { type: 'pending' }
  | { type: 'in_progress'; assignee: string; startedAt: Date }
  | { type: 'completed'; completedAt: Date; completedBy: string }
  | { type: 'cancelled'; reason: string; cancelledAt: Date };

# Consumer gets type narrowing
function getStatusLabel(status: TaskStatus): string {
  switch (status.type) {
    case 'pending':     return 'Pending';
    case 'in_progress': return `In progress (${status.assignee})`;
    case 'completed':   return `Done on ${status.completedAt}`;
    case 'cancelled':   return `Cancelled: ${status.reason}`;
  }
}
```

### Input/output separation

```
# Input: what the caller provides
interface CreateTaskInput {
  title: string;
  description?: string;
}

# Output: what the system returns (includes server-generated fields)
interface Task {
  id: string;
  title: string;
  description: string | null;
  createdAt: Date;
  updatedAt: Date;
  createdBy: string;
}
```

### Branded types for IDs

```
type TaskId = string & { readonly __brand: 'TaskId' };
type UserId = string & { readonly __brand: 'UserId' };

# Prevents accidentally passing a UserId where a TaskId is expected
function getTask(id: TaskId): Promise<Task> { ... }
```

## MCP tool design

MCP tools are APIs the agent calls. Same discipline applies:

- **Name**: verb-first (`search_users`, `create_ticket`), lowercase_snake, short
- **Description**: start with "use when..." — Claude uses this to decide when to call
- **Input schema**: required vs optional; enums where applicable; descriptions on every field
- **Output**: consistent shape; include whatever the agent needs to continue without another call
- **Errors**: return a structured error the agent can reason about, not a bare exception

## Deprecation

Since Hyrum's Law means any change can break consumers, deprecation needs a real process:

1. **Announce** — docs + runtime warning (if possible)
2. **Coexist** — old and new paths work simultaneously
3. **Migrate** — help consumers move (scripts, compatibility shims, direct outreach)
4. **Measure** — verify usage of the old path has dropped to zero
5. **Remove** — only after measured zero usage for a full deprecation window

Announcement without migration help is negligent. Removal without measurement causes outages.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "We'll document the API later" | The types ARE the documentation. Define them first. |
| "We don't need pagination for now" | You will the moment someone has 100+ items. Add from the start. |
| "PATCH is complicated, just use PUT" | PUT requires the full object every time. PATCH is what clients actually want. |
| "We'll version when we need to" | Breaking changes without versioning break consumers. Design for extension from the start. |
| "Nobody uses that undocumented behavior" | Hyrum's Law. Treat every public behavior as a commitment. |
| "We can maintain two versions" | Multiple versions multiply cost and create diamond dependency problems. One version. |
| "Internal APIs don't need contracts" | Internal consumers are still consumers. Contracts prevent coupling and enable parallel work. |

## Red Flags

- Endpoints that return different shapes depending on conditions
- Inconsistent error formats across endpoints
- Validation scattered throughout internal code instead of at boundaries
- Breaking changes to existing fields (type changes, removals)
- List endpoints without pagination
- Verbs in REST URLs
- Third-party API responses used without validation
- "We'll just document it after it's stable" — APIs stabilize faster when documented

## Verification

- [ ] Every endpoint has typed input and output schemas
- [ ] Error responses follow one consistent format
- [ ] Validation happens at system boundaries only
- [ ] List endpoints support pagination
- [ ] New fields are additive and optional (backward compatible)
- [ ] Naming follows consistent conventions across all endpoints
- [ ] API documentation or types are committed alongside the implementation
