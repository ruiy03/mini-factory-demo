#!/usr/bin/env bash
# PreToolUse hook: fires right before Edit / Write / MultiEdit tools execute.
# Mini-scale port of Software Factory's preventive guard. Blocks edits to
# files that the PRD declares off-limits, and to scenarios.json itself.
#
# Why block scenarios.json: zoning. The agent must not relax the specs to fit
# a weak implementation; tests must adapt to specs, not the other way around.

set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
LOG_DIR="$PROJECT_DIR/.claude/hook_logs"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
INPUT_FILE="$LOG_DIR/pre_tool_use_${TIMESTAMP}.json"

INPUT=$(cat)
echo "$INPUT" > "$INPUT_FILE"

# If jq is missing, let the call through (avoid false positives during smoke tests).
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# Extract tool_input.file_path. Edit / Write / MultiEdit all expose this field.
FILE_PATH=$(echo "$INPUT" | jq -er '.tool_input.file_path // .file_path' 2>/dev/null)
JQ_EXIT=$?

if [ $JQ_EXIT -ne 0 ]; then
  # Field absent = different tool (e.g., Bash). Pass through.
  exit 0
fi

# PRD constraints: lib/mini_factory_demo.rb and version.rb are out of scope.
# Zoning: .claude/scenarios.json must not be edited by the agent.
case "$FILE_PATH" in
  */mini_factory_demo.rb|*/version.rb)
    echo "PreToolUse gate: editing out-of-scope file is blocked" >&2
    echo "The PRD forbids changes to lib/mini_factory_demo.rb and lib/mini_factory_demo/version.rb." >&2
    echo "Allowed targets: lib/mini_factory_demo/user.rb and spec/user_spec.rb only." >&2
    exit 2
    ;;
  */.claude/scenarios.json|.claude/scenarios.json)
    echo "PreToolUse gate: editing scenarios.json is blocked" >&2
    echo "scenarios.json defines the user-satisfaction conditions and must stay outside the agent's edit zone." >&2
    echo "Adjust the implementation (user.rb) so the existing scenarios pass, instead of relaxing them." >&2
    exit 2
    ;;
esac

exit 0
