#!/bin/bash
# pm pre-hook: fetch existing issues, blocked issues, check build state.
# Exports: EXISTING_ISSUES, BLOCKED_ISSUES, BUILD_STATUS, FOCUS

parse_decision_args "${AGENT_ARGS:-}"
if [ "$DECISION_MODE" = "true" ]; then
    fetch_decision_context "$DECISION_ISSUE_NUMBER" "PM"
    export FOCUS="decision-discussion issue #$DECISION_ISSUE_NUMBER"
    export FOCUS_LINE="**Decision discussion:** issue #$DECISION_ISSUE_NUMBER"
    export EXISTING_ISSUES=""
    export BLOCKED_ISSUES=""
    export BUILD_STATUS="not checked in decision mode"
    return 0
fi

export FOCUS="${AGENT_ARGS:-}"
export FOCUS_LINE=""
if [ -n "$FOCUS" ]; then
    FOCUS_LINE="**Priority focus area:** $FOCUS"
fi

echo "→ Fetching existing issues..."
export EXISTING_ISSUES=""
if command -v gh &>/dev/null; then
    EXISTING_ISSUES=$(gh issue list --repo "$REPO" --state open --limit 30 \
        --json number,title,labels \
        --jq '.[] | "#\(.number) [\(.labels | map(.name) | join(","))] \(.title)"' 2>/dev/null || true)
    echo "  $(echo "$EXISTING_ISSUES" | grep -c '^#' 2>/dev/null || echo 0) open issues."
fi

echo "→ Fetching blocked issues..."
export BLOCKED_ISSUES=""
if command -v gh &>/dev/null; then
    BLOCKED_ISSUES=$(gh issue list --repo "$REPO" --state open \
        --label "blocked" --limit 20 \
        --json number,title,body \
        --jq '.[] | "### #\(.number) \(.title)\n\(.body | .[0:500])\n---"' 2>/dev/null || true)
    BLOCKED_COUNT=$(echo "$BLOCKED_ISSUES" | grep -c '^### #' 2>/dev/null || echo 0)
    echo "  $BLOCKED_COUNT blocked issues to reassess."
fi

echo "→ Checking build state..."
export BUILD_STATUS="unknown"
if [ -f package.json ]; then
    if eval "$BUILD_CMD" > /tmp/build-output 2>&1; then
        BUILD_STATUS="passing"
    else
        BUILD_STATUS="failing"
    fi
    rm -f /tmp/build-output
else
    BUILD_STATUS="no build system detected"
fi
echo "  Build: $BUILD_STATUS"
