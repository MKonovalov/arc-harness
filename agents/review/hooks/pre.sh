#!/bin/bash
# review pre-hook: fetch PR details, diff, linked issue, checkout branch.
# Exports: PR_NUMBER, PR_TITLE, PR_BODY, PR_BRANCH, PR_AUTHOR, PR_DIFF,
#          LINKED_ISSUE, ISSUE_BODY, BUILD_RESULT, PROTECTED_VIOLATIONS

export PR_NUMBER="${AGENT_ARGS:?Usage: run-agent.sh review <pr_number>}"

echo "→ Reviewing PR #$PR_NUMBER..."

# ── Fetch PR details ──
PR_JSON=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json title,body,headRefName,baseRefName,files,commits,author 2>/dev/null || true)
if [ -z "$PR_JSON" ] || [ "$PR_JSON" = "null" ]; then
    echo "  ERROR: Could not fetch PR #$PR_NUMBER."
    exit 1
fi

export PR_TITLE=$(echo "$PR_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('title',''))" 2>/dev/null || echo "")
export PR_BODY=$(echo "$PR_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('body','')[:3000])" 2>/dev/null || echo "")
export PR_BRANCH=$(echo "$PR_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('headRefName',''))" 2>/dev/null || echo "")
export PR_AUTHOR=$(echo "$PR_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('author',{}).get('login',''))" 2>/dev/null || echo "")

echo "  Title: $PR_TITLE"
echo "  Branch: $PR_BRANCH"
echo "  Author: $PR_AUTHOR"

# ── Get the diff ──
export PR_DIFF=$(gh pr diff "$PR_NUMBER" --repo "$REPO" 2>/dev/null | head -c 15000 || true)

# ── Find linked issue ──
export LINKED_ISSUE=""
export ISSUE_BODY=""
if echo "$PR_BODY" | grep -qiE '[Cc]loses?\s+#[0-9]+'; then
    LINKED_ISSUE=$(echo "$PR_BODY" | grep -oiE '[Cc]loses?\s+#[0-9]+' | head -1 | grep -oE '[0-9]+')
    ISSUE_BODY=$(gh issue view "$LINKED_ISSUE" --repo "$REPO" --json body --jq '.body' 2>/dev/null | head -c 3000 || true)
    echo "  Linked issue: #$LINKED_ISSUE"
fi

# ── Check if build passes on the branch ──
echo "→ Checking out PR branch for build verification..."
CHECKOUT_OK=false
if git fetch origin "$PR_BRANCH" 2>&1; then
    if git checkout "origin/$PR_BRANCH" 2>&1; then
        CHECKOUT_OK=true
    fi
fi

export BUILD_RESULT="not checked"
if $CHECKOUT_OK && [ -f package.json ]; then
    pnpm install --frozen-lockfile 2>/dev/null || pnpm install 2>/dev/null || true
    if eval "$BUILD_CMD" > /tmp/build-output 2>&1; then
        BUILD_RESULT="passing"
    else
        BUILD_RESULT="failing"
    fi
    rm -f /tmp/build-output
elif ! $CHECKOUT_OK; then
    echo "  WARNING: Could not checkout PR branch. Build verification skipped."
    BUILD_RESULT="could not checkout branch"
fi

# ── Check for protected file modifications ──
PROTECTED_IN_DIFF=$(echo "$PR_DIFF" | grep -E '^\+\+\+ b/' | sed 's|^\+\+\+ b/||' || true)
export PROTECTED_VIOLATIONS=""
for PATH_PATTERN in $PROTECTED_PATHS; do
    MATCH=$(echo "$PROTECTED_IN_DIFF" | grep "^${PATH_PATTERN}" || true)
    [ -n "$MATCH" ] && PROTECTED_VIOLATIONS="${PROTECTED_VIOLATIONS}${MATCH}\n"
done

# ── Build template sections for PROMPT.md (envsubst can't do conditionals) ──
export PROTECTED_SECTION=""
if [ -n "$PROTECTED_VIOLATIONS" ]; then
    PROTECTED_SECTION="**PROTECTED FILE VIOLATIONS:**
${PROTECTED_VIOLATIONS}"
fi

export LINKED_ISSUE_SECTION=""
export REQUEUE_SECTION=""
if [ -n "$LINKED_ISSUE" ]; then
    LINKED_ISSUE_SECTION="**Linked Issue #${LINKED_ISSUE}:**
${ISSUE_BODY}"
    REQUEUE_SECTION="Then re-queue the linked issue with machine-readable retry context:
\`\`\`
gh issue edit ${LINKED_ISSUE} --repo ${REPO} --remove-label \"in-progress\" --add-label \"ready\"
gh issue comment ${LINKED_ISSUE} --repo ${REPO} --body \"<!-- arc-review-retry
pr: ${PR_NUMBER}
issue: ${LINKED_ISSUE}
verdict: changes_requested
-->
Review requested changes on PR #${PR_NUMBER}. Build retry requested.

Required changes:
- <specific file and behavior change>
- <specific test or verification update>\"
\`\`\`"
fi
