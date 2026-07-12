---
name: gh-cli
description: GitHub CLI patterns for issues, PRs, and labels
tools: [bash]
---

# GitHub CLI

Use `gh` for all GitHub operations. Always include `--repo $REPO`.

## Issues

```bash
# Create
gh issue create --repo $REPO --title "..." --body "..." --label "label1" --label "label2"

# Edit labels
gh issue edit <N> --repo $REPO --remove-label "old" --add-label "new"

# Comment
gh issue comment <N> --repo $REPO --body "..."

# Close
gh issue close <N> --repo $REPO --comment "Reason"

# List
gh issue list --repo $REPO --state open --label "ready" --limit 10 \
  --json number,title,body,labels --jq '...'
```

## Pull Requests

```bash
# Create
gh pr create --repo $REPO --base main --head branch --title "..." --body "..."

# Comment (for approval — same identity can't use --approve on own PRs)
gh pr comment <N> --repo $REPO --body "Review passed. ..."

# Request changes
gh pr review <N> --repo $REPO --request-changes --body "..."

# Merge
gh pr merge <N> --repo $REPO --squash --auto

# View diff
gh pr diff <N> --repo $REPO
```

## Label Conventions

| Dimension | Labels |
|-----------|--------|
| **Status** | `triage`, `ready`, `in-progress`, `blocked` |
| **Priority** | `p0-critical`, `p1-high`, `p2-medium`, `p3-low` |
| **Source** | `agent-input`, `agent-self`, `agent-research` |
| **Type** | `bug`, `feature`, `refactor`, `docs` |

## Rules

- Always use `--repo $REPO` (never assume CWD matches)
- Never create labels — assume they exist
- Body text in commands must be properly quoted
- Use `2>/dev/null || true` for non-critical operations that might fail
