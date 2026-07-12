#!/bin/bash
# build pre-hook: claim issue, create branch, fetch details.
# Exports: ISSUE_NUMBER, ISSUE_TITLE, ISSUE_LABELS, SAFE_BODY, BRANCH, SESSION_START_SHA

MAX_FIX_ATTEMPTS=5
export MAX_FIX_ATTEMPTS

# ── Claim an issue ──
export ISSUE_NUMBER="${AGENT_ARGS:-}"

if [ -z "$ISSUE_NUMBER" ]; then
    echo "→ Finding highest-priority ready issue..."
    for PRIORITY in p0-critical p1-high p2-medium p3-low; do
        ISSUE_NUMBER=$(gh issue list --repo "$REPO" --state open \
            --label "ready" --label "$PRIORITY" --limit 1 \
            --json number --jq '.[0].number' 2>/dev/null || true)
        [ -n "$ISSUE_NUMBER" ] && [ "$ISSUE_NUMBER" != "null" ] && break
        ISSUE_NUMBER=""
    done
    # Fallback: any ready issue
    if [ -z "$ISSUE_NUMBER" ]; then
        ISSUE_NUMBER=$(gh issue list --repo "$REPO" --state open \
            --label "ready" --limit 1 \
            --json number --jq '.[0].number' 2>/dev/null || true)
    fi
fi

if [ -z "$ISSUE_NUMBER" ] || [ "$ISSUE_NUMBER" = "null" ]; then
    echo "No ready issues to work on. Done."
    exit 0
fi

# ── Check retry count (stop spinning on hard issues) ──
MAX_ISSUE_RETRIES=3
ISSUE_COMMENTS_JSON=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json comments 2>/dev/null || echo '{"comments":[]}')
REVIEW_RETRY_BODY=$(printf "%s" "$ISSUE_COMMENTS_JSON" | python3 -c '
import json
import sys

try:
    comments = json.load(sys.stdin).get("comments", [])
except Exception:
    comments = []

for comment in reversed(comments):
    body = comment.get("body") or ""
    if "<!-- arc-review-retry" in body:
        print(body)
        break
' 2>/dev/null || true)
RETRY_COUNT=$(printf "%s" "$ISSUE_COMMENTS_JSON" | python3 -c '
import json
import re
import sys

try:
    comments = json.load(sys.stdin).get("comments", [])
except Exception:
    comments = []

last_retry = -1
for index, comment in enumerate(comments):
    if "<!-- arc-review-retry" in (comment.get("body") or ""):
        last_retry = index

failure = re.compile(r"Re-queued|Build failed|Implementation attempted|made no changes|failed to push", re.I)
count = 0
for index, comment in enumerate(comments):
    if index <= last_retry:
        continue
    body = comment.get("body") or ""
    if failure.search(body):
        count += 1
print(count)
' 2>/dev/null || echo 0)

if [ "$RETRY_COUNT" -ge "$MAX_ISSUE_RETRIES" ]; then
    echo "  Issue #$ISSUE_NUMBER has failed $RETRY_COUNT times. Escalating."
    gh issue edit "$ISSUE_NUMBER" --repo "$REPO" \
        --remove-label "ready" --add-label "blocked" --add-label "agent-help-wanted" 2>&1 || true
    gh issue comment "$ISSUE_NUMBER" --repo "$REPO" \
        --body "Build agent failed or re-queued this issue $RETRY_COUNT times. Marking as blocked — may need to be split, rewritten, or handled by a human-action issue." 2>&1 || true
    exit 0
fi

echo "→ Claiming issue #$ISSUE_NUMBER..."

# Atomic claim: swap ready → in-progress (must succeed to prevent duplicate work)
if ! gh issue edit "$ISSUE_NUMBER" --repo "$REPO" \
    --remove-label "ready" --add-label "in-progress" 2>&1; then
    echo "ERROR: Failed to claim issue #$ISSUE_NUMBER (label swap failed). Aborting."
    exit 1
fi

# Fetch issue details
export ISSUE_TITLE=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json title --jq '.title' 2>/dev/null || echo "Issue $ISSUE_NUMBER")
ISSUE_BODY=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json body --jq '.body' 2>/dev/null | head -c 3000 || echo "")
export ISSUE_LABELS=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json labels --jq '.labels | map(.name) | join(", ")' 2>/dev/null || echo "")

echo "  Issue: #$ISSUE_NUMBER — $ISSUE_TITLE"
echo "  Labels: $ISSUE_LABELS"

# ── Create branch ──
export BRANCH="arc/issue-${ISSUE_NUMBER}"
git checkout -b "$BRANCH" origin/main 2>/dev/null || git checkout -b "$BRANCH"
echo "  Branch: $BRANCH"

export SESSION_START_SHA=$(git rev-parse HEAD)

# ── Sanitize issue body ──
export SAFE_BODY=$(echo "$ISSUE_BODY" | sanitize_issue_content)

# ── Include latest structured review retry, if any ──
export REVIEW_RETRY_SECTION=""
if [ -n "$REVIEW_RETRY_BODY" ]; then
    SAFE_RETRY=$(printf "%s" "$REVIEW_RETRY_BODY" | sanitize_issue_content | head -c 4000)
    REVIEW_RETRY_SECTION="=== REVIEW RETRY ===

The previous PR review requested changes. Address this feedback before opening
another PR:

${SAFE_RETRY}"
fi
