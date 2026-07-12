#!/bin/bash
# build post-hook: build-fix loop, protected file check, push branch, create PR.
# Expects: ISSUE_NUMBER, ISSUE_TITLE, BRANCH, SESSION_START_SHA, MAX_FIX_ATTEMPTS

# ── Build-fix loop ──
echo "→ Verifying build..."
for ATTEMPT in $(seq 1 $MAX_FIX_ATTEMPTS); do
    if [ -f package.json ]; then
        BUILD_OK=true

        set +o pipefail
        eval "$BUILD_CMD" 2>&1 | tail -5; [ "${PIPESTATUS[0]}" -eq 0 ] || BUILD_OK=false
        eval "$LINT_CMD" 2>&1 | tail -5; [ "${PIPESTATUS[0]}" -eq 0 ] || BUILD_OK=false
        eval "$TEST_CMD" 2>&1 | tail -5; [ "${PIPESTATUS[0]}" -eq 0 ] || BUILD_OK=false
        set -o pipefail

        if $BUILD_OK; then
            echo "  Build: PASS (attempt $ATTEMPT)"
            break
        fi

        if [ "$ATTEMPT" -eq "$MAX_FIX_ATTEMPTS" ]; then
            echo "  Build: FAIL after $MAX_FIX_ATTEMPTS attempts. Reverting."
            git reset --hard "$SESSION_START_SHA"
            gh issue edit "$ISSUE_NUMBER" --repo "$REPO" \
                --remove-label "in-progress" --add-label "ready" 2>/dev/null || true
            gh issue comment "$ISSUE_NUMBER" --repo "$REPO" \
                --body "Build failed after $MAX_FIX_ATTEMPTS fix attempts. Re-queued as ready." 2>/dev/null || true
            git checkout main
            git branch -D "$BRANCH" 2>/dev/null || true
            exit 1
        fi

        echo "  Build: FAIL (attempt $ATTEMPT/$MAX_FIX_ATTEMPTS). Running fix agent..."
        FIX_PROMPT=$(mktemp)
        set +o pipefail
        FIX_ERRORS=$(eval "$BUILD_CMD" 2>&1 | tail -30; eval "$LINT_CMD" 2>&1 | tail -20; eval "$TEST_CMD" 2>&1 | tail -30)
        set -o pipefail
        {
            echo "You are arc, fixing build/lint/test failures. Today is $DATE."
            echo ""
            echo "The build is failing. Fix the errors below. Do NOT add new features — only fix what's broken."
            echo ""
            echo "=== ERRORS ==="
            echo "$FIX_ERRORS"
            echo ""
            echo "Steps:"
            echo "1. Read the failing files"
            echo "2. Fix the specific errors"
            echo "3. Run \`$BUILD_CMD && $LINT_CMD && $TEST_CMD\` to verify"
            echo "4. Commit: \`git add <files> && git commit -m \"arc: fix build errors\"\`"
            echo ""
            echo "Do NOT modify protected files: $PROTECTED_PATHS"
        } > "$FIX_PROMPT"
        FIX_LOG=$(mktemp)
        FIX_TIMEOUT=$((TIMEOUT / 4))
        FIX_EXIT=0
        run_agent "$FIX_TIMEOUT" "$FIX_PROMPT" "$FIX_LOG" || FIX_EXIT=$?
        if [ "$FIX_EXIT" -ne 0 ] && [ "$FIX_EXIT" -ne 124 ]; then
            echo "  ERROR: Fix agent failed (exit $FIX_EXIT). Aborting fix loop."
            break
        fi
        rm -f "$FIX_PROMPT" "$FIX_LOG"
    else
        echo "  No package.json — skipping build check."
        break
    fi
done

# ── Check for protected file modifications ──
PROTECTED=$(check_protected_files "$SESSION_START_SHA")
if [ -n "$PROTECTED" ]; then
    echo "  WARNING: Protected files modified. Reverting and creating human-action blocker."
    echo "  $PROTECTED"
    git reset --hard "$SESSION_START_SHA"
    HUMAN_TITLE="Human action: handle protected files for #$ISSUE_NUMBER"
    HUMAN_BODY="Build agent stopped because issue #$ISSUE_NUMBER requires changes to protected files.

Protected files:
\`\`\`
$PROTECTED
\`\`\`

Why this needs a human:
- Protected paths are intentionally blocked from build-agent edits.
- A human should either make the protected-file change directly, rewrite #$ISSUE_NUMBER so it avoids protected paths, or explicitly adjust the protected-path policy.

Completion signal: close this issue when the protected-file decision or change is complete."
    HUMAN_ISSUE=$(gh issue list --repo "$REPO" --state open \
        --search "\"$HUMAN_TITLE\" in:title" \
        --json number --jq '.[0].number' 2>/dev/null || true)
    if [ -z "$HUMAN_ISSUE" ] || [ "$HUMAN_ISSUE" = "null" ]; then
        HUMAN_CREATE=$(gh issue create --repo "$REPO" \
            --title "$HUMAN_TITLE" \
            --body "$HUMAN_BODY" \
            --label "human-action" 2>&1) || HUMAN_CREATE=""
        if [ -z "$HUMAN_CREATE" ]; then
            HUMAN_CREATE=$(gh issue create --repo "$REPO" \
                --title "$HUMAN_TITLE" \
                --body "$HUMAN_BODY" 2>&1) || HUMAN_CREATE=""
        fi
        HUMAN_ISSUE=$(printf "%s" "$HUMAN_CREATE" | sed -nE 's#.*/issues/([0-9]+).*#\1#p' | head -1)
    fi

    BLOCKER_LINE=""
    if [ -n "$HUMAN_ISSUE" ] && [ "$HUMAN_ISSUE" != "null" ]; then
        BLOCKER_LINE="Blocked-By: #$HUMAN_ISSUE"
    else
        BLOCKER_LINE="Blocked-By: human protected-file decision"
    fi

    gh issue edit "$ISSUE_NUMBER" --repo "$REPO" \
        --remove-label "in-progress" --remove-label "ready" --add-label "blocked" 2>/dev/null || true
    gh issue comment "$ISSUE_NUMBER" --repo "$REPO" \
        --body "Build stopped because this issue requires protected-file changes.

$BLOCKER_LINE
Blocker-Type: human
Unblock-To: ready

Protected files:
\`\`\`
$PROTECTED
\`\`\`" 2>/dev/null || true
    git checkout main
    git branch -D "$BRANCH" 2>/dev/null || true
    exit 1
fi

# ── Check if any changes were made ──
if git diff --quiet "$SESSION_START_SHA"..HEAD 2>/dev/null; then
    echo "  No changes made. Re-queuing issue."
    gh issue edit "$ISSUE_NUMBER" --repo "$REPO" \
        --remove-label "in-progress" --add-label "ready" 2>/dev/null || true
    gh issue comment "$ISSUE_NUMBER" --repo "$REPO" \
        --body "Build agent made no changes. Re-queued as ready." 2>/dev/null || true
    git checkout main
    git branch -D "$BRANCH" 2>/dev/null || true
    exit 0
fi

# ── Push branch and create PR ──
echo "→ Pushing branch and creating PR..."
if ! git pull --rebase origin main 2>&1; then
    echo "  WARNING: Rebase onto main failed. Pushing without rebase."
    git rebase --abort 2>/dev/null || true
fi
if ! git push --force-with-lease -u origin "$BRANCH" 2>&1; then
    echo "ERROR: Failed to push branch $BRANCH. Re-queuing issue."
    gh issue edit "$ISSUE_NUMBER" --repo "$REPO" \
        --remove-label "in-progress" --add-label "ready" 2>/dev/null || true
    gh issue comment "$ISSUE_NUMBER" --repo "$REPO" \
        --body "Build agent completed but failed to push branch. Re-queued." 2>/dev/null || true
    git checkout main
    git branch -D "$BRANCH" 2>/dev/null || true
    exit 1
fi

COMMITS=$(git log --oneline "$SESSION_START_SHA"..HEAD --format="- %s" || true)

PR_EXIT=0
PR_URL=$(gh pr list --repo "$REPO" \
    --head "$BRANCH" \
    --state open \
    --json url --jq '.[0].url // ""' 2>/dev/null || true)

if [ -z "$PR_URL" ]; then
    PR_URL=$(gh pr create --repo "$REPO" \
        --base main \
        --head "$BRANCH" \
        --title "arc: $ISSUE_TITLE" \
        --body "Closes #$ISSUE_NUMBER

## Changes
$COMMITS

## Verification
- [ ] \`$BUILD_CMD\` passes
- [ ] \`$LINT_CMD\` passes
- [ ] \`$TEST_CMD\` passes" 2>&1) || PR_EXIT=$?
else
    echo "  Existing PR found for $BRANCH: $PR_URL"
fi

if [ "$PR_EXIT" -ne 0 ]; then
    echo "  WARNING: PR creation failed (exit $PR_EXIT): $PR_URL"
    PR_URL="(PR creation failed — branch pushed to $BRANCH)"
fi

echo "  PR: $PR_URL"

# ── Update journal on main ──
git stash 2>/dev/null || true
git checkout main
git pull --rebase origin main 2>/dev/null || true

if [ -f .arc/journal.md ]; then
    COMMITS_INLINE=$(printf "%s" "$COMMITS" | sed ':a;N;$!ba;s/\n/; /g')
    {
        echo ""
        echo "## $DATE $SESSION_TIME — Build opened issue #$ISSUE_NUMBER"
        echo ""
        echo "The build agent turned \"$ISSUE_TITLE\" into code on \`$BRANCH\` after running the configured build, lint, and test checks."
        if [[ "$PR_URL" == http* ]]; then
            echo "The result is ready for review at $PR_URL."
        else
            echo "The branch was pushed, but PR creation did not complete: $PR_URL."
        fi
        echo "The commit trail is: $COMMITS_INLINE."
        echo "That leaves the work waiting on review and merge rather than another build pass."
    } >> .arc/journal.md
    commit_and_push_journal "arc: build session ($DATE) — issue #$ISSUE_NUMBER"
fi
