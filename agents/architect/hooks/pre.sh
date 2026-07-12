#!/bin/bash
# architect pre-hook: find issues needing design or rescue, gather context.
# Exports: ISSUE_NUMBER, ISSUE_TITLE, ISSUE_BODY, ARCHITECT_MODE,
#          FAILURE_SECTION, FAILURE_HISTORY, FAILED_DIFFS

parse_decision_args "${AGENT_ARGS:-}"
if [ "$DECISION_MODE" = "true" ]; then
    fetch_decision_context "$DECISION_ISSUE_NUMBER" "Architect"
    export ISSUE_NUMBER="$DECISION_ISSUE_NUMBER"
    export ISSUE_TITLE="$DECISION_ISSUE_TITLE"
    export ISSUE_BODY="$DECISION_ISSUE_BODY"
    export ARCHITECT_MODE="DECISION"
    export FAILURE_HISTORY=""
    export FAILED_DIFFS=""
    export FAILURE_SECTION=""
    return 0
fi

export ISSUE_NUMBER="${AGENT_ARGS:-}"
export ARCHITECT_MODE=""

# ── Find an issue: prioritize design (needs-architecture), then rescue (help-wanted) ──
if [ -z "$ISSUE_NUMBER" ]; then
    echo "→ Looking for issues needing architecture..."
    ISSUE_NUMBER=$(gh issue list --repo "$REPO" --state open \
        --label "needs-architecture" --limit 1 \
        --json number --jq '.[0].number' 2>/dev/null || true)
    if [ -n "$ISSUE_NUMBER" ] && [ "$ISSUE_NUMBER" != "null" ]; then
        ARCHITECT_MODE="DESIGN"
    fi
fi

if [ -z "$ISSUE_NUMBER" ] || [ "$ISSUE_NUMBER" = "null" ]; then
    echo "→ Looking for issues needing rescue..."
    ISSUE_NUMBER=$(gh issue list --repo "$REPO" --state open \
        --label "agent-help-wanted" --limit 1 \
        --json number --jq '.[0].number' 2>/dev/null || true)
    if [ -n "$ISSUE_NUMBER" ] && [ "$ISSUE_NUMBER" != "null" ]; then
        ARCHITECT_MODE="RESCUE"
    fi
fi

if [ -z "$ISSUE_NUMBER" ] || [ "$ISSUE_NUMBER" = "null" ]; then
    echo "No issues need architect attention. Done."
    exit 0
fi

# ── Auto-detect mode if issue was passed as arg ──
if [ -z "$ARCHITECT_MODE" ]; then
    LABELS=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json labels \
        --jq '.labels | map(.name) | join(",")' 2>/dev/null || echo "")
    if echo "$LABELS" | grep -q "needs-architecture"; then
        ARCHITECT_MODE="DESIGN"
    else
        ARCHITECT_MODE="RESCUE"
    fi
fi

export ARCHITECT_MODE
echo "→ Architect mode: $ARCHITECT_MODE for issue #$ISSUE_NUMBER"

# ── Fetch issue details ──
export ISSUE_TITLE=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json title --jq '.title' 2>/dev/null || echo "Issue $ISSUE_NUMBER")
export ISSUE_BODY=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json body --jq '.body' 2>/dev/null | head -c 5000 || echo "")

echo "  Issue: #$ISSUE_NUMBER — $ISSUE_TITLE"

# ── Gather failure context (only in RESCUE mode) ──
export FAILURE_HISTORY=""
export FAILED_DIFFS=""
export FAILURE_SECTION=""

if [ "$ARCHITECT_MODE" = "RESCUE" ]; then
    FAILURE_HISTORY=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json comments \
        --jq '[.comments[] | select(.body | test("failed|Re-queued|rejected|no changes")) | .body] | join("\n---\n")' 2>/dev/null | head -c 5000 || echo "")

    FAILURE_COUNT=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json comments \
        --jq '[.comments[] | select(.body | test("Re-queued|Build failed|Implementation attempted|made no changes|failed to push"; "i"))] | length' 2>/dev/null || echo 0)
    echo "  Failed attempts: $FAILURE_COUNT"

    # Find failed PRs
    FAILED_PRS=$(gh pr list --repo "$REPO" --state all --search "issue $ISSUE_NUMBER" --limit 3 \
        --json number,title,state --jq '.[] | select(.state != "MERGED") | .number' 2>/dev/null || true)

    for PR in $FAILED_PRS; do
        DIFF=$(gh pr diff "$PR" --repo "$REPO" 2>/dev/null | head -c 3000 || true)
        if [ -n "$DIFF" ]; then
            FAILED_DIFFS="${FAILED_DIFFS}
--- PR #${PR} (failed/closed) ---
${DIFF}
---"
        fi
    done

    if [ -n "$FAILED_DIFFS" ]; then
        echo "  Found diffs from failed PRs."
    fi

    FAILURE_SECTION="=== FAILURE HISTORY ===

${FAILURE_HISTORY}

=== FAILED DIFFS (what the build agent tried) ===

${FAILED_DIFFS}"
fi
