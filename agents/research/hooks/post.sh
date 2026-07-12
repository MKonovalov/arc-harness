#!/bin/bash
# research post-hook: ensure a journal entry exists, then commit + push it.
#
# A research run must leave an advantage brief even when it files 0 issues. The
# agent is instructed to append one as its final step. If it forgot, we DON'T
# fail the whole run (the scan already happened, and a hard failure loses it and
# pages a human) — instead we degrade gracefully: append a minimal honest stub
# so the journal is never silently empty, and surface a warning so the omission
# stays visible. A run should always leave a journal entry behind.

JOURNAL_DIRTY=false
JOURNAL_COMMITTED=false

if [ -f .arc/journal.md ] && ! git diff --quiet -- .arc/journal.md 2>/dev/null; then
    JOURNAL_DIRTY=true
fi

if [ -n "${RESEARCH_START_SHA:-}" ] && ! git diff --quiet "$RESEARCH_START_SHA"..HEAD -- .arc/journal.md 2>/dev/null; then
    JOURNAL_COMMITTED=true
fi

if [ "$JOURNAL_DIRTY" = "false" ] && [ "$JOURNAL_COMMITTED" = "false" ]; then
    echo "::warning::Research agent exited without authoring a journal brief; writing a fallback stub so the run still leaves an entry."
    mkdir -p .arc
    printf '\n## %s (research scan)\n\n_Scan completed, but the agent exited before authoring an advantage brief — this is an auto-generated fallback so the journal is never silently empty. No issues filed this scan; see the GitHub Actions run log for the full trace._\n' "$DATE" >> .arc/journal.md
    JOURNAL_DIRTY=true
fi

if [ "$JOURNAL_DIRTY" = "true" ] || [ "$JOURNAL_COMMITTED" = "true" ]; then
    commit_and_push_journal "arc: weekly research scan ($DATE)"
fi
