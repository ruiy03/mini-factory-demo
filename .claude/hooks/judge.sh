#!/usr/bin/env bash
# LLM judge hook: ask Claude how well the current implementation satisfies
# each scenario in scenarios.json (0-100), averaged across N_TRIALS runs per
# scenario id. Exit 2 if any scenario's average drops below the threshold.
#
# Mini-scale port of Software Factory's `scenarios + satisfaction`. The real
# thing observes a probability distribution across many trajectories; here we
# call `claude --print` N_TRIALS times (default 3) on the same implementation
# and average the satisfaction scores to absorb LLM output jitter. Multi-point
# observation instead of a single point.
#
# Note: invoking `claude --print` from inside a hook is not documented as a
# supported pattern. On any failure we only warn and exit 0 (skip) so the
# Stop hook still completes for users without a working `claude` CLI.

set -uo pipefail

N_TRIALS=${MFD_JUDGE_TRIALS:-3}

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR" || exit 1

if ! command -v jq >/dev/null 2>&1; then
  echo "judge gate: jq is not installed, skipping LLM judge" >&2
  exit 0
fi
if ! command -v claude >/dev/null 2>&1; then
  echo "judge gate: claude CLI is not on PATH, skipping LLM judge" >&2
  exit 0
fi

SCENARIOS=$(cat .claude/scenarios.json)
THRESHOLD=$(echo "$SCENARIOS" | jq -r '.satisfaction_threshold')
TARGET_FILE=$(echo "$SCENARIOS" | jq -r '.target_file')
TARGET_SRC=$(cat "$TARGET_FILE")

PROMPT="You are the scenario-satisfaction judge for a mini Software Factory.

Read the scenarios and the Ruby implementation below. For each scenario,
score how well the implementation satisfies the intent on a 0-100 scale.
Return ONLY this JSON shape, with no surrounding prose or markdown fences:
{\"scenarios\": [{\"id\": 1, \"satisfaction\": 95, \"reason\": \"short reason\"}, ...]}

=== scenarios.json ===
${SCENARIOS}

=== current ${TARGET_FILE} ===
${TARGET_SRC}
"

# Accumulate per-trial JSON results in a temp file.
RESULTS_FILE=$(mktemp)
trap 'rm -f "$RESULTS_FILE"' EXIT
echo '[]' > "$RESULTS_FILE"

for trial in $(seq 1 "$N_TRIALS"); do
  # --setting-sources user makes claude ignore this project's settings.json
  # (and therefore this Stop hook). Without it, the inner `claude --print`
  # re-fires the Stop hook and recurses for 10+ minutes per trial.
  # --no-session-persistence keeps these helper sessions out of resume history.
  JUDGE_OUTPUT=$(echo "$PROMPT" | claude --print --no-session-persistence --setting-sources user 2>/dev/null)
  JUDGE_EXIT=$?

  if [ $JUDGE_EXIT -ne 0 ] || [ -z "$JUDGE_OUTPUT" ]; then
    echo "judge gate: claude --print failed or returned empty on trial ${trial} (possible hook recursion); skipping LLM judge" >&2
    exit 0
  fi

  # Pull the JSON object out of whatever wrapping Claude returned.
  JSON_PART=$(echo "$JUDGE_OUTPUT" | sed -n '/{/,/}/p' | tr -d '\n' | sed -E 's/.*(\{[^{}]*"scenarios"[^{}]*\[.*\].*\}).*/\1/')

  if [ -z "$JSON_PART" ] || ! echo "$JSON_PART" | jq -e '.scenarios | length > 0' >/dev/null 2>&1; then
    echo "judge gate: could not extract JSON from LLM response on trial ${trial}; skipping LLM judge" >&2
    echo "(response head): $(echo "$JUDGE_OUTPUT" | head -c 200)" >&2
    exit 0
  fi

  # Append this trial's scenarios to the results array.
  CURRENT=$(cat "$RESULTS_FILE")
  echo "$CURRENT" | jq --argjson new "$JSON_PART" '. + [$new]' > "$RESULTS_FILE"
done

# Group satisfaction values by scenario id, average them, list anything that
# fell below the threshold.
AVERAGES=$(jq '
  reduce .[] as $r ({};
    reduce $r.scenarios[] as $s (.;
      .[($s.id|tostring)] = ((.[($s.id|tostring)] // []) + [$s.satisfaction])
    )
  )
  | to_entries
  | map({
      id: (.key | tonumber),
      avg: ((.value | add) / (.value | length) | floor),
      values: .value
    })
  | sort_by(.id)
' "$RESULTS_FILE")

LOW=$(echo "$AVERAGES" | jq -r --argjson t "$THRESHOLD" '.[] | select(.avg < $t) | "  - id=" + (.id|tostring) + " avg=" + (.avg|tostring) + "% (trials: " + (.values|tostring) + ")"')

if [ -n "$LOW" ]; then
  echo "judge gate: average satisfaction across ${N_TRIALS} trials is below ${THRESHOLD}% for one or more scenarios" >&2
  echo "$LOW" >&2
  exit 2
fi

PASSED_COUNT=$(echo "$AVERAGES" | jq -r 'length')
echo "judge gate: all ${PASSED_COUNT} scenarios pass at >= ${THRESHOLD}% average satisfaction across ${N_TRIALS} trials" >&2
echo "$AVERAGES" | jq -r '.[] | "  - id=" + (.id|tostring) + " avg=" + (.avg|tostring) + "% (trials: " + (.values|tostring) + ")"' >&2
exit 0
