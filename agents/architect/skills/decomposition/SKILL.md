---
name: decomposition
description: How to break down complex issues into atomic, independently implementable pieces
tools: []
---

# Decomposition

You break hard problems into small, solvable ones. This is the most valuable
thing a tech lead does — not writing code, but making code writable.

## The Atomic Issue Test

Every sub-issue you create must pass ALL of these:

1. **One session** — a build agent can complete it in under 40 minutes
2. **≤5 files** — if it touches more, it's too big
3. **Independent build** — `build && lint && test` passes after just this issue,
   without needing the other sub-issues to land first
4. **Clear done** — acceptance criteria are mechanical, not subjective
   ("zero import fs in search.ts" not "refactored properly")

## Splitting Strategies

**By file** — when the same operation needs to happen across multiple files,
split one issue per file. This is the most common and safest split.

**By layer** — when a change spans layers (interface → implementation → callers),
split by layer. Interface first, then implementation, then migration of callers.

**By dependency** — when A depends on B, make B its own issue. Note the
dependency explicitly in the issue body.

**By risk** — separate the mechanical/safe changes from the tricky ones.
Let the build agent knock out the easy wins while you think about the hard part.

## Diagnosing Why Build Failed

Read the failed diffs carefully. Common patterns:

**Shallow fix** — the agent wrapped things in no-op functions instead of doing
the actual refactor. Fix: rewrite with explicit "you must remove X and replace
with Y" instructions.

**Cascade failure** — changing one function signature broke 20 callers, tests
failed, fix agent couldn't keep up. Fix: split so each issue has a bounded
blast radius.

**Wrong approach** — the agent tried approach A but the codebase needs approach B.
Fix: rewrite the issue with the correct approach spelled out.

**Missing prerequisite** — the issue assumes something exists that doesn't yet.
Fix: create the prerequisite as issue #1, then this becomes issue #2.

**Test mismatch** — the refactor is correct but tests assert the old behavior.
Fix: include "update test X to use new API" in acceptance criteria.

## Writing Sub-Issues

Each sub-issue body must include:
- **Context** — why this exists (reference the parent issue)
- **Requirements** — specific, mechanical changes (not vague goals)
- **Files Involved** — exact paths and what changes in each
- **Acceptance Criteria** — build passes + specific grep/check commands
- **Size Estimate** — small or medium (never large)

Bad: "Refactor the storage layer"
Good: "Remove `import fs` from search.ts, replace with StorageProvider.readFile()"

## When NOT to Split

- The issue is already small but the build agent just made a mistake → REWRITE
- The approach is fundamentally wrong → CLOSE and file a new issue with the right approach
- The issue depends on external work (human setup, third-party API) → leave BLOCKED
