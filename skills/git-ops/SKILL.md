---
name: git-ops
description: Git operations — branch, commit, push, rebase patterns
tools: [bash]
---

# Git Operations

## Branch Management

```bash
# Create feature branch from main
git checkout -b arc/issue-<N> origin/main

# Push branch
git push -u origin arc/issue-<N>
```

## Commits

```bash
# Atomic commit with issue reference
git add <specific-files>
git commit -m "arc: <description> (closes #<N>)"
```

Rules:
- Commit message starts with "arc: "
- Include "closes #N" for issue auto-close
- Add specific files, never `git add -A` or `git add .`
- Each commit should be independently buildable

## Rebase and Conflicts

```bash
# Update branch from main
git pull --rebase origin main

# Force push after rebase (only on arc/ branches)
git push --force-with-lease
```

## Protected Files

Never modify files matching PROTECTED_PATHS. If a task requires it:
1. Stop implementation
2. Comment on the issue explaining why
3. Re-queue the issue as "ready"

## Safety

- Never force-push to main
- Never delete branches you didn't create
- Never modify commits that are already in main
- Always use --force-with-lease (not --force) when force-pushing
