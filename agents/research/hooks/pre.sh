#!/bin/bash
# research pre-hook: set focus line from args.
# Exports: FOCUS_LINE, RESEARCH_START_SHA

export RESEARCH_START_SHA=$(git rev-parse HEAD)

parse_decision_args "${AGENT_ARGS:-}"
if [ "$DECISION_MODE" = "true" ]; then
    fetch_decision_context "$DECISION_ISSUE_NUMBER" "Research"
    export FOCUS_LINE="**Decision discussion:** issue #$DECISION_ISSUE_NUMBER"
    return 0
fi

export FOCUS_LINE=""
if [ -n "${AGENT_ARGS:-}" ]; then
    FOCUS_LINE="**Priority focus:** $AGENT_ARGS"
fi
