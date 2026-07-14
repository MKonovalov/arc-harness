#!/bin/bash
# setup-agent.sh — Shared setup for all arc agent scripts.
# Source this at the top of each agent script:
#   source "$(dirname "$0")/setup-agent.sh"
#
# Provides:
#   $REPO, $MODEL, $DATE, $SESSION_TIME, $BOT_LOGIN, $BOT_SLUG
#   $SYSTEM_FILE, $SHARED_SKILLS, $TIMEOUT_CMD
#   $BUILD_CMD, $TEST_CMD, $LINT_CMD, $PROTECTED_PATHS
#   run_agent()              — run arc with identity + skills
#   check_protected_files()  — detect modifications to protected files
#   sanitize_issue_content() — strip HTML comments + boundary markers
#   commit_and_push_journal() — commit and push journal changes

set -euo pipefail

export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# ── Auto-detect repo from git remote ──
if [ -z "${REPO:-}" ]; then
    REPO=$(git remote get-url origin 2>/dev/null | sed -E 's|.*github\.com[:/]||;s|\.git$||' || echo "")
    if [ -z "$REPO" ]; then
        echo "ERROR: Could not detect REPO. Set REPO env var."
        exit 1
    fi
fi

MODEL="${MODEL:-claude-opus-4-6}"
BOT_LOGIN="${BOT_LOGIN:-arc[bot]}"
BOT_SLUG="${BOT_SLUG:-arc}"
DATE=$(date -u +%Y-%m-%d)
SESSION_TIME=$(date -u +%H:%M)
JOURNAL_BASE_SHA=$(git rev-parse HEAD 2>/dev/null || echo "")
export JOURNAL_BASE_SHA

# Security nonce for content boundary markers
BOUNDARY_NONCE=$(python3 -c "import os; print(os.urandom(16).hex())") || {
    echo "ERROR: python3 required for security nonce generation."
    exit 1
}
BOUNDARY_BEGIN="[BOUNDARY-${BOUNDARY_NONCE}-BEGIN]"
BOUNDARY_END="[BOUNDARY-${BOUNDARY_NONCE}-END]"

# ── Read project config ──
read_config

# ── Preflight: check arc binary ──
if ! command -v arc &>/dev/null; then
    echo "ERROR: arc binary not found on PATH."
    exit 1
fi

# ── Load identity ──
# Identity is baked into the Docker image at /opt/arc/identity/
# Also check for project-local identity override
SYSTEM_FILE=""
if [ -f ".arc/identity/SOUL.md" ]; then
    SYSTEM_FILE=".arc/identity/SOUL.md"
elif [ -f "/opt/arc/identity/SOUL.md" ]; then
    SYSTEM_FILE="/opt/arc/identity/SOUL.md"
fi

# Always try downloading arc-evolve so evolved skills are available even when
# identity is already baked into the harness image.
ARC_EVOLVE_DIR="/tmp/arc-evolve"
rm -rf "$ARC_EVOLVE_DIR" /tmp/arc-evolve.tar.gz
mkdir -p "$ARC_EVOLVE_DIR"

echo "→ Downloading arc-evolve context..."
if gh api "repos/MKonovalov/arc-evolve/tarball/main" > /tmp/arc-evolve.tar.gz 2>/dev/null; then
    tar xzf /tmp/arc-evolve.tar.gz -C "$ARC_EVOLVE_DIR" --strip-components=1
    rm -f /tmp/arc-evolve.tar.gz

    # If no pre-built identity exists, generate one from arc-evolve.
    if [ -z "$SYSTEM_FILE" ]; then
        mkdir -p ".arc/identity"
        if [ -f "$ARC_EVOLVE_DIR/scripts/arc_context.sh" ]; then
            arc_REPO="$ARC_EVOLVE_DIR" source "$ARC_EVOLVE_DIR/scripts/arc_context.sh"
            echo "$arc_CONTEXT" > ".arc/identity/SOUL.md"
            SYSTEM_FILE=".arc/identity/SOUL.md"
            echo "  Identity loaded ($(wc -l < "$SYSTEM_FILE" | tr -d ' ') lines)"
        fi
    fi

    # Extract evolved skills into the shared pool.
    if [ -d "$ARC_EVOLVE_DIR/skills" ]; then
        EVOLVED_SKILLS="/tmp/arc-evolved-skills"
        rm -rf "$EVOLVED_SKILLS"
        cp -r "$ARC_EVOLVE_DIR/skills" "$EVOLVED_SKILLS"
        SKILL_COUNT=$(find "$EVOLVED_SKILLS" -name "SKILL.md" | wc -l | tr -d ' ')
        echo "  Evolved skills loaded ($SKILL_COUNT skills from arc-evolve)"
    fi
    rm -rf "$ARC_EVOLVE_DIR"
else
    if [ -z "$SYSTEM_FILE" ]; then
        echo "  WARNING: Failed to download identity. Running without system prompt."
    else
        echo "  WARNING: Failed to download evolved skills."
    fi
    rm -rf "$   " /tmp/arc-evolve.tar.gz
fi

# ── Legacy: shared skills from Docker image (unused with run-agent.sh) ──
SHARED_SKILLS=""
if [ -d "/opt/arc/skills" ]; then
    SHARED_SKILLS="/opt/arc/skills"
fi

# ── Timeout command (cross-platform) ──
TIMEOUT_CMD="timeout"
if ! command -v timeout &>/dev/null; then
    if command -v gtimeout &>/dev/null; then
        TIMEOUT_CMD="gtimeout"
    else
        TIMEOUT_CMD=""
        echo "WARNING: No timeout command found. Agent calls will have no time limit."
    fi
fi

# ── Helper: run agent ──
run_agent() {
    local timeout_val="$1"
    local prompt_file="$2"
    local log_file="$3"
    local extra_flags="${4:-}"

    local exit_code=0
    # shellcheck disable=SC2086
    ${TIMEOUT_CMD:+$TIMEOUT_CMD "$timeout_val"} arc \
        --model "$MODEL" \
        ${SYSTEM_FILE:+--system-file "$SYSTEM_FILE"} \
        --skills .arc/skills \
        ${SHARED_SKILLS:+--skills "$SHARED_SKILLS"} \
        $extra_flags \
        < "$prompt_file" 2>&1 | tee "$log_file" || exit_code=$?

    return "$exit_code"
}

# ── Helper: check protected files ──
check_protected_files() {
    local base_sha="$1"
    local protected=""
    # shellcheck disable=SC2086
    protected=$(git diff --name-only "$base_sha"..HEAD -- $PROTECTED_PATHS 2>/dev/null || true)
    local staged
    # shellcheck disable=SC2086
    staged=$(git diff --cached --name-only -- $PROTECTED_PATHS 2>/dev/null || true)
    [ -n "$staged" ] && protected="${protected}${protected:+
}${staged}"
    local unstaged
    # shellcheck disable=SC2086
    unstaged=$(git diff --name-only -- $PROTECTED_PATHS 2>/dev/null || true)
    [ -n "$unstaged" ] && protected="${protected}${protected:+
}${unstaged}"
    echo "$protected"
}

# ── Helper: sanitize issue content ──
sanitize_issue_content() {
    python3 -c "
import sys, re
bb, be = sys.argv[1], sys.argv[2]
text = sys.stdin.read()
text = re.sub(r'<!--.*?-->', '', text, flags=re.DOTALL)
text = text.replace(bb, '[marker-stripped]').replace(be, '[marker-stripped]')
print(text)
" "$BOUNDARY_BEGIN" "$BOUNDARY_END"
}

# ── Helper: commit and push journal changes ──
normalize_journal_dates() {
    [ -f .arc/journal.md ] || return 0

    local diff
    if [ -n "${JOURNAL_BASE_SHA:-}" ]; then
        diff=$(git diff --unified=0 "$JOURNAL_BASE_SHA" -- .arc/journal.md 2>/dev/null || true)
    else
        diff=$(git diff --unified=0 -- .arc/journal.md 2>/dev/null || true)
    fi
    [ -n "$diff" ] || return 0

    local diff_file
    diff_file=$(mktemp)
    printf "%s" "$diff" > "$diff_file"

    local py_status=0
    python3 - "$DATE" "$SESSION_TIME" ".arc/journal.md" "$diff_file" <<'PY' || py_status=$?
import re
import sys

session_date, session_time, path, diff_path = sys.argv[1:5]
with open(diff_path, encoding="utf-8") as f:
    diff = f.read()

changed_lines = set()
current_line = None

for line in diff.splitlines():
    if line.startswith("@@"):
        m = re.search(r"\+(\d+)(?:,(\d+))?", line)
        if not m:
            current_line = None
            continue
        current_line = int(m.group(1))
        continue
    if current_line is None:
        continue
    if line.startswith("+") and not line.startswith("+++"):
        changed_lines.add(current_line)
        current_line += 1
    elif line.startswith("-") and not line.startswith("---"):
        continue
    else:
        current_line += 1

if not changed_lines:
    sys.exit(0)

with open(path, encoding="utf-8") as f:
    lines = f.readlines()

changed = False
heading = re.compile(r"^(## )(\d{4}-\d{2}-\d{2})(?: (\d{2}:\d{2}))?(.*)$")
agent_only_heading = re.compile(r"^(## )\s*(\([^)]+\))(.*)$")

for line_no in sorted(changed_lines):
    if line_no < 1 or line_no > len(lines):
        continue
    raw_line = lines[line_no - 1]
    newline = "\n" if raw_line.endswith("\n") else ""
    line = raw_line[:-1] if newline else raw_line
    m = heading.match(line)
    if not m:
        agent_only = agent_only_heading.match(line)
        if agent_only:
            prefix, agent_suffix, suffix = agent_only.groups()
            replacement = f"{prefix}{session_date} {session_time} {agent_suffix}{suffix}"
            lines[line_no - 1] = replacement + newline
            changed = True
            print(
                f"  Added journal heading date on line {line_no}: "
                f"{line} -> {replacement}",
                file=sys.stderr,
            )
        continue
    prefix, old_date, old_time, suffix = m.groups()
    # Only normalize session headings, not arbitrary markdown dates.
    if not (suffix.startswith(" ") and ("(" in suffix or "—" in suffix)):
        continue
    if old_date == session_date and (old_time is None or old_time == session_time):
        continue
    if old_time is None:
        replacement = f"{prefix}{session_date}{suffix}"
    else:
        replacement = f"{prefix}{session_date} {session_time}{suffix}"
    lines[line_no - 1] = replacement + newline
    changed = True
    print(
        f"  Normalized journal heading date on line {line_no}: "
        f"{old_date}{(' ' + old_time) if old_time else ''} -> "
        f"{session_date}{(' ' + session_time) if old_time else ''}",
        file=sys.stderr,
    )

if changed:
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(lines)
PY
    rm -f "$diff_file"
    return "$py_status"
}

commit_and_push_journal() {
    local message="$1"
    normalize_journal_dates
    git add .arc/journal.md 2>/dev/null || true
    if ! git diff --cached --quiet 2>/dev/null; then
        git commit -m "$message"
        git pull --rebase origin main 2>/dev/null || true
        git push || echo "WARNING: Failed to push journal update"
    fi
}

echo "=== Agent Session ($DATE $SESSION_TIME) ==="
echo "Repo: $REPO | Model: $MODEL"
