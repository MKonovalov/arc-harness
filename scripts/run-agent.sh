#!/bin/bash
# run-agent.sh — Generic agent runner.
# Reads agent definition from agents/<name>/, assembles skills, runs arc.
#
# Usage: ./run-agent.sh <agent-name> [args...]
# Env: REPO, GH_TOKEN, ANTHROPIC_API_KEY

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-agent.sh"

AGENT_NAME="${1:?Usage: run-agent.sh <agent-name> [args...]}"
shift
export AGENT_ARGS="$*"
AGENT_DIR="$SCRIPT_DIR/../agents/$AGENT_NAME"

# ── Check agent exists ──
if [ ! -d "$AGENT_DIR" ]; then
    echo "ERROR: Agent '$AGENT_NAME' not found at $AGENT_DIR"
    exit 1
fi

# ── Read agent config ──
AGENT_TOML="$AGENT_DIR/agent.toml"
TIMEOUT=$(parse_toml_value "$AGENT_TOML" "timeout" "900")
AGENT_MODEL=$(parse_toml_value "$AGENT_TOML" "model" "$MODEL")
export MODEL="$AGENT_MODEL"

echo "Agent: $AGENT_NAME | Timeout: ${TIMEOUT}s | Model: $AGENT_MODEL"

# ── Check enabled in project config ──
ENABLED=$(parse_agent_enabled ".arc/arc.toml" "$AGENT_NAME" "true")
if [ "$ENABLED" = "false" ]; then
    echo "$AGENT_NAME is disabled in .arc/arc.toml. Exiting."
    exit 0
fi

# ── Run pre-hook (exports context variables for PROMPT.md) ──
if [ -f "$AGENT_DIR/hooks/pre.sh" ]; then
    echo "→ Running pre-hook..."
    source "$AGENT_DIR/hooks/pre.sh"
fi

# ── Assemble skills flags ──
SKILLS_FLAGS=""

# Agent-specific skills (always loaded)
if [ -d "$AGENT_DIR/skills" ]; then
    SKILLS_FLAGS="--skills $AGENT_DIR/skills"
fi

# Shared skills referenced in agent.toml
SHARED=$(parse_toml_array "$AGENT_TOML" "shared_skills")
for SKILL in $SHARED; do
    SKILL_DIR="$SCRIPT_DIR/../skills/$SKILL"
    if [ -d "$SKILL_DIR" ]; then
        SKILLS_FLAGS="$SKILLS_FLAGS --skills $SKILL_DIR"
    else
        echo "  WARNING: Shared skill '$SKILL' not found."
    fi
done

# Evolved skills from arc-evolve (downloaded by setup-agent.sh)
EVOLVED_SKILLS="/tmp/arc-evolved-skills"
if [ -d "$EVOLVED_SKILLS" ]; then
    SKILLS_FLAGS="$SKILLS_FLAGS --skills $EVOLVED_SKILLS"
fi

# Project-local skills are loaded by run_agent() in setup-agent.sh

# ── Build prompt from template ──
if [ ! -f "$AGENT_DIR/PROMPT.md" ]; then
    echo "ERROR: No PROMPT.md found for agent '$AGENT_NAME'"
    exit 1
fi

PROMPT_FILE=$(mktemp)
envsubst < "$AGENT_DIR/PROMPT.md" > "$PROMPT_FILE"

# ── Run agent ──
echo "→ Running $AGENT_NAME agent..."
AGENT_LOG=$(mktemp)
EXIT_CODE=0
run_agent "$TIMEOUT" "$PROMPT_FILE" "$AGENT_LOG" "$SKILLS_FLAGS" || EXIT_CODE=$?
rm -f "$PROMPT_FILE"

export AGENT_EXIT_CODE="$EXIT_CODE"
if [ "$EXIT_CODE" -eq 124 ]; then
    echo "  WARNING: $AGENT_NAME agent timed out."
elif [ "$EXIT_CODE" -ne 0 ]; then
    echo "  WARNING: $AGENT_NAME agent exited with code $EXIT_CODE."
fi

# ── Run post-hook (skip on critical agent failure, allow on timeout) ──
if [ "$EXIT_CODE" -ne 0 ] && [ "$EXIT_CODE" -ne 124 ]; then
    echo "  Skipping post-hook due to agent failure."
elif [ -f "$AGENT_DIR/hooks/post.sh" ]; then
    echo "→ Running post-hook..."
    source "$AGENT_DIR/hooks/post.sh"
fi

rm -f "$AGENT_LOG"
echo "=== $AGENT_NAME session complete ==="
