#!/usr/bin/env bash
# Stop hook: fires the moment Claude (the main session) finishes a response.
# Mini-scale port of Software Factory's goal_gate: four checks that the
# acceptance criteria for the current backlog are met.
#
# Stages:
#   1. rspec (--format json, summarized per acceptance criterion)
#   2. rubocop (must report 0 offense)
#   3. surface check (each spec method declaration is present in user.rb)
#   4. LLM judge (judge.sh asks Claude for the scenarios.json satisfaction
#      across multiple trials and averages them)
#
# Any failing stage exits 2 to block completion and writes a concrete failure
# message to stderr.

set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
LOG_DIR="$PROJECT_DIR/.claude/hook_logs"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
INPUT_FILE="$LOG_DIR/stop_${TIMESTAMP}.json"

INPUT=$(cat)
echo "$INPUT" > "$INPUT_FILE"

# Skip verification when the last response had no successful in-scope edit
# (e.g. every edit was blocked by PreToolUse, or Claude only replied with
# text). Without this guard, baseline failures would loop forever on such
# turns because nothing has changed since the previous gate run.
if ! echo "$INPUT" | "$(dirname "$0")/should_verify.sh"; then
  exit 0
fi

cd "$PROJECT_DIR" || exit 1

# Stage 1: rspec via --format json (so we can call out which acceptance
# criterion failed instead of just "rspec is red").
RSPEC_JSON=$(bundle exec rspec --format json 2>/dev/null)
RSPEC_EXIT=$?

if [ $RSPEC_EXIT -ne 0 ] && [ -z "$RSPEC_JSON" ]; then
  echo "Stop gate: rspec itself failed to run" >&2
  bundle exec rspec 2>&1 | tail -15 >&2
  exit 2
fi

if command -v jq >/dev/null 2>&1; then
  TOTAL=$(echo "$RSPEC_JSON" | jq -r '.summary.example_count' 2>/dev/null)
  FAILED=$(echo "$RSPEC_JSON" | jq -r '.summary.failure_count' 2>/dev/null)

  if [ -n "$FAILED" ] && [ "$FAILED" != "0" ] && [ "$FAILED" != "null" ]; then
    echo "Stop gate: rspec ${TOTAL} examples, ${FAILED} failed" >&2
    echo "$RSPEC_JSON" | jq -r '.examples[] | select(.status != "passed") | "  - " + .full_description + " (" + .status + ")"' >&2
    exit 2
  fi
fi

# Stage 2: rubocop must be clean.
if ! bundle exec rubocop >/dev/null 2>&1; then
  echo "Stop gate: rubocop failed" >&2
  bundle exec rubocop 2>&1 | tail -10 >&2
  exit 2
fi

# Stage 3: every backlog spec must declare its method (surface check).
# Method names and target_file are read from scenarios.json — the source of
# truth that the LLM judge also scores against. Skipped if jq is unavailable;
# rspec still catches missing methods.
if command -v jq >/dev/null 2>&1; then
  TARGET_FILE=$(jq -r '.target_file' .claude/scenarios.json 2>/dev/null)
  METHODS=$(jq -r '[.scenarios[].spec] | unique[]' .claude/scenarios.json 2>/dev/null)
  for method in $METHODS; do
    if ! grep -q "def $method" "$TARGET_FILE"; then
      echo "Stop gate: \`def $method\` is missing from ${TARGET_FILE}" >&2
      echo "The PRD's backlog requires User#${method} (see .claude/intent.md)." >&2
      exit 2
    fi
  done
fi

# Stage 4: LLM judge across the scenarios.
.claude/hooks/judge.sh
JUDGE_EXIT=$?
if [ $JUDGE_EXIT -ne 0 ]; then
  exit $JUDGE_EXIT
fi

exit 0
