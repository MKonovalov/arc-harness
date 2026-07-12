#!/bin/bash
# lib.sh — Shared library for arc agent scripts.
# Provides config parsing, helpers, and common setup.
#
# Provides:
#   parse_toml_value()         — extract a value from arc.toml
#   parse_toml_section_value() — extract a value from a TOML section
#   parse_toml_array()         — extract an array from arc.toml
#   read_config()              — load all config into env vars
#   parse_decision_args()      — detect decision-discussion mode
#   fetch_decision_context()   — fetch issue context for decision mode

# ── TOML parser (minimal, no external deps) ──

# Parse a simple key = "value" or key = true/false from a TOML file.
parse_toml_value() {
    local file="$1" key="$2" default="${3:-}"
    if [ ! -f "$file" ]; then
        echo "$default"
        return
    fi
    local val
val=$(python3 -c "
import sys, re
content = open(sys.argv[1]).read()
key = re.escape(sys.argv[2])
default = sys.argv[3]
m = re.search(rf'^{key}\s*=\s*(.+?)\s*$', content, re.MULTILINE)
if m:
    val = m.group(1).strip()
    if len(val) >= 2 and val[0] in ('\"', \"'\") and val[-1] == val[0]:
        val = val[1:-1]
    print(val)
else:
    print(default)
" "$file" "$key" "$default" 2>/dev/null || echo "$default")
    echo "$val"
}

# Parse a simple key from a TOML section, e.g. [collaboration] max_rounds = 3.
parse_toml_section_value() {
    local file="$1" section="$2" key="$3" default="${4:-}"
    if [ ! -f "$file" ]; then
        echo "$default"
        return
    fi
    python3 -c "
import sys, re
content = open(sys.argv[1]).read()
section = re.escape(sys.argv[2])
key = re.escape(sys.argv[3])
default = sys.argv[4]
m = re.search(rf'^\[{section}\]\s*\n(.*?)(?=^\[|\Z)', content, re.MULTILINE | re.DOTALL)
if not m:
    print(default)
    sys.exit(0)
body = m.group(1)
kv = re.search(rf'^{key}\s*=\s*(.+?)\s*$', body, re.MULTILINE)
if kv:
    val = kv.group(1).strip()
    if len(val) >= 2 and val[0] in ('\"', \"'\") and val[-1] == val[0]:
        val = val[1:-1]
    print(val)
else:
    print(default)
" "$file" "$section" "$key" "$default" 2>/dev/null || echo "$default"
}

# Parse an array like paths = [".github/", ".arc/arc.toml"]
parse_toml_array() {
    local file="$1" key="$2"
    if [ ! -f "$file" ]; then
        echo ""
        return
    fi
    python3 -c "
import sys, re, ast
content = open(sys.argv[1]).read()
key = re.escape(sys.argv[2])
m = re.search(rf'^{key}\s*=\s*(\[.*?\])', content, re.MULTILINE | re.DOTALL)
if m:
    items = ast.literal_eval(m.group(1))
    print(' '.join(str(i) for i in items))
" "$file" "$key" 2>/dev/null || echo ""
}

# Parse agent enabled status: [agents.NAME] enabled = true/false
parse_agent_enabled() {
    local file="$1" agent="$2" default="${3:-true}"
    if [ ! -f "$file" ]; then
        echo "$default"
        return
    fi
    python3 -c "
import sys, re
content = open(sys.argv[1]).read()
agent = sys.argv[2]
default = sys.argv[3]
# Find [agents.NAME] section and its enabled key
pattern = rf'\[agents\.{agent}\].*?enabled\s*=\s*(\w+)'
m = re.search(pattern, content, re.DOTALL)
if m:
    print(m.group(1))
else:
    print(default)
" "$file" "$agent" "$default" 2>/dev/null || echo "$default"
}

# ── Read project config ──
read_config() {
    local config_file=".arc/arc.toml"

    # Commands
    BUILD_CMD=$(parse_toml_value "$config_file" "build" "pnpm build")
    TEST_CMD=$(parse_toml_value "$config_file" "test" "pnpm test")
    LINT_CMD=$(parse_toml_value "$config_file" "lint" "pnpm lint")

    # Protected paths
    PROTECTED_PATHS=$(parse_toml_array "$config_file" "paths")
    [ -z "$PROTECTED_PATHS" ] && PROTECTED_PATHS=".github/ .arc/arc.toml"

    # Optional multi-agent collaboration config. Defaults preserve legacy behavior.
    COLLABORATION_DECISION_DISCUSSIONS=$(parse_toml_section_value "$config_file" "collaboration" "decision_discussions" "false")
    DECISION_MAX_ROUNDS=$(parse_toml_section_value "$config_file" "collaboration" "max_rounds" "3")

    ENABLED_AGENTS=""
    for agent in pm build review office-hour research architect; do
        if [ "$(parse_agent_enabled "$config_file" "$agent" "true")" = "true" ]; then
            ENABLED_AGENTS="${ENABLED_AGENTS}${ENABLED_AGENTS:+ }${agent}"
        fi
    done

    DECISION_CAPABLE_AGENTS=""
    for agent in pm architect research; do
        if [ "$(parse_agent_enabled "$config_file" "$agent" "true")" = "true" ]; then
            DECISION_CAPABLE_AGENTS="${DECISION_CAPABLE_AGENTS}${DECISION_CAPABLE_AGENTS:+ }${agent}"
        fi
    done

    export BUILD_CMD TEST_CMD LINT_CMD PROTECTED_PATHS
    export COLLABORATION_DECISION_DISCUSSIONS DECISION_MAX_ROUNDS
    export ENABLED_AGENTS DECISION_CAPABLE_AGENTS
}

# Parse args like: decision-discussion issue #75
parse_decision_args() {
    local args="${1:-}"

    export DECISION_MODE="false"
    export DECISION_ISSUE_NUMBER=""

    if [[ "$args" =~ (^|[[:space:]])decision-discussion([[:space:]]|$) ]]; then
        DECISION_MODE="true"
        DECISION_ISSUE_NUMBER=$(printf "%s" "$args" | sed -nE 's/.*issue[[:space:]]+#?([0-9]+).*/\1/p' | head -1)
    fi

    export DECISION_MODE DECISION_ISSUE_NUMBER
}

# Fetch issue title/body/comments for decision-discussion mode.
fetch_decision_context() {
    local issue_number="${1:-}"
    local agent_name="${2:-}"

    export DECISION_AGENT="$agent_name"
    export DECISION_ISSUE_TITLE=""
    export DECISION_ISSUE_BODY=""
    export DECISION_COMMENTS=""
    export DECISION_CURRENT_ROUND="1"
    export DECISION_CONTEXT=""

    if [ -z "$issue_number" ]; then
        echo "ERROR: decision-discussion mode requires an issue number."
        exit 1
    fi

    echo "→ Fetching decision context for issue #$issue_number..."

    if command -v gh &>/dev/null; then
        DECISION_ISSUE_TITLE=$(gh issue view "$issue_number" --repo "$REPO" \
            --json title --jq '.title' 2>/dev/null || echo "Issue $issue_number")
        DECISION_ISSUE_BODY=$(gh issue view "$issue_number" --repo "$REPO" \
            --json body --jq '.body' 2>/dev/null | head -c 5000 || echo "")
        DECISION_COMMENTS=$(gh issue view "$issue_number" --repo "$REPO" \
            --json comments \
            --jq '.comments[] | "### " + .author.login + " at " + .createdAt + "\n" + .body + "\n---"' \
            2>/dev/null | head -c 12000 || echo "")
    fi

    DECISION_CURRENT_ROUND=$(printf "%s\n" "$DECISION_COMMENTS" | python3 -c "
import re, sys
text = sys.stdin.read()
rounds = [int(x) for x in re.findall(r'Decision-Round:\s*(\d+)', text)]
print(max(rounds) if rounds else 1)
" 2>/dev/null || echo "1")

    DECISION_CONTEXT="=== DECISION DISCUSSION CONTEXT ===

Decision mode: ${DECISION_MODE}
Decision issue: #${issue_number}
Decision agent: ${agent_name}
Enabled agents: ${ENABLED_AGENTS}
Decision-capable agents: ${DECISION_CAPABLE_AGENTS}
Max rounds: ${DECISION_MAX_ROUNDS}
Current round: ${DECISION_CURRENT_ROUND}

Issue title: ${DECISION_ISSUE_TITLE}

Issue body:
${DECISION_ISSUE_BODY}

Issue comments:
${DECISION_COMMENTS}
"

    export DECISION_AGENT DECISION_ISSUE_TITLE DECISION_ISSUE_BODY
    export DECISION_COMMENTS DECISION_CURRENT_ROUND DECISION_CONTEXT
}
