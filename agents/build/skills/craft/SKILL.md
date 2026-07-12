---
name: craft
description: Implementation standards — minimal changes, stop triggers, hard limits
tools: [bash, read_file, write_file, edit_file]
---

# Craft: Implementation Standards

Every changed line must trace directly to the issue's requirements.
If it doesn't trace, revert it.

## Core Principles

From Trail of Bits + Karpathy-style:

1. **No speculative features.** Don't add features, flags, or config the issue didn't ask for.
2. **No premature abstraction.** Don't create a utility until you've written the same code three times.
3. **Explicit over clever.** 10-line obvious fix > 200-line abstraction. 5 seconds choosing, not 5 minutes.
4. **Replace, don't deprecate.** When new code replaces old code, remove the old code entirely. No backward-compatible shims, no commented-out code.
5. **Finish the job.** Handle the edge cases you can see. Clean up what you touched. But don't invent new scope — there's a difference between thoroughness and gold-plating.

## Hard Limits

- ≤100 lines per function
- ≤5 positional parameters
- No commented-out code committed (delete it)
- No console.log / debugging artifacts left in
- No unused imports
- Every error has a name (not generic "handle errors")

## Stop Triggers

Adapted from Liza's behavioral contracts. STOP implementation when:

| Trigger | Action |
|---------|--------|
| Issue requirements contradict each other | Re-queue with comment explaining contradiction |
| Required change would break existing functionality | Re-queue, explain what would break |
| Issue assumes a file/function that doesn't exist | Re-queue, explain what's missing |
| Scope is obviously >5 files | Re-queue, suggest split |
| Same fix attempted twice without new rationale | STOP — you're guessing. Re-queue. |
| Would need to modify protected files | STOP — re-queue, explain why |

From ctoth: "'I'm stuck' is infinitely more valuable than confident-sounding confabulation."
If you can't solve it, say so. Don't fake progress.

## Implementation Checklist

Before your final commit:

- [ ] Every changed line traces to the issue's requirements (no "while I'm here" changes)
- [ ] Follows existing patterns in THIS codebase (consistency > your preferences)
- [ ] Would you want to maintain this in 6 months?
- [ ] No dead code, unused imports, or debugging artifacts
- [ ] Variable names are clear without needing comments
- [ ] Build + lint + test pass

## What "Done" Looks Like

- The issue's acceptance criteria are met — ALL of them
- Build passes
- No unrelated changes in the diff
- Clear commit message: `arc: <what> (closes #N)`
- If something was impossible or skipped, it's noted in a comment on the issue

## What "Not Done" Looks Like (recognize and stop)

- You're refactoring code the issue didn't mention
- You're adding error handling for impossible scenarios
- You're creating abstractions "for future use"
- You're fixing style issues in files you didn't need to touch
- Your diff is >200 lines for a "small" issue — something is wrong
