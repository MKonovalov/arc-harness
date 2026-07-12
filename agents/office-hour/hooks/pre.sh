#!/bin/bash
# office-hour pre-hook: fetch triage and ready issues.
# Exports: TRIAGE_ISSUES, TRIAGE_COUNT, READY_ISSUES, READY_COUNT

parse_decision_args "${AGENT_ARGS:-}"
if [ "$DECISION_MODE" = "true" ]; then
    fetch_decision_context "$DECISION_ISSUE_NUMBER" "Office Hour"
fi

echo "→ Fetching triage issues..."
export TRIAGE_ISSUES=""
export TRIAGE_COUNT=0
if command -v gh &>/dev/null; then
    TRIAGE_ISSUES=$(gh issue list --repo "$REPO" --state open \
        --label "triage" --limit 10 \
        --json number,title,body,labels,author \
        --jq '.[] | "### Issue #\(.number)\n**Title:** \(.title)\n**Author:** \(.author.login)\n**Labels:** \(.labels | map(.name) | join(", "))\n\(.body | .[0:800])\n---"' 2>/dev/null || true)
    TRIAGE_COUNT=$(printf "%s\n" "$TRIAGE_ISSUES" | grep -c '^### Issue' 2>/dev/null || true)
    echo "  $TRIAGE_COUNT triage issues found."
fi

echo "→ Fetching ready issues..."
export READY_ISSUES=""
export READY_COUNT=0
if command -v gh &>/dev/null; then
    READY_ISSUES=$(gh issue list --repo "$REPO" --state open \
        --label "ready" --limit 10 \
        --json number,title,labels \
        --jq '.[] | "#\(.number) [\(.labels | map(.name) | join(","))] \(.title)"' 2>/dev/null || true)
    READY_COUNT=$(printf "%s\n" "$READY_ISSUES" | grep -c '^#' 2>/dev/null || true)
    echo "  $READY_COUNT ready issues."
fi

if [ "$DECISION_MODE" != "true" ] && [ "$TRIAGE_COUNT" -eq 0 ] 2>/dev/null; then
    echo "No triage issues to process. Done."
    exit 0
fi
