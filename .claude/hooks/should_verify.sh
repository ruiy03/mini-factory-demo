#!/usr/bin/env bash
# Decide whether stop.sh should run its verification stages this turn.
# Reads the Stop hook's input JSON from stdin, inspects the transcript at
# transcript_path, and exits 0 ("verify") or 1 ("skip").
#
# "Verify" means: the most recent assistant message contains at least one
# Edit / Write / MultiEdit tool_use whose tool_result is NOT an error.
# Otherwise the response either had no edits at all, or every edit was
# blocked by PreToolUse — re-running rspec / rubocop / judge would only
# loop on the same unchanged baseline.
#
# Fail-open: if transcript_path is missing, the file is absent, or jq is
# unavailable, this script exits 0 (verify) so a legitimate gate is never
# silently skipped.

set -uo pipefail

INPUT=$(cat)

TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

HAS_SUCCESSFUL_EDIT=$(jq -s '
  [.[] | select(.type == "assistant" or .type == "user")] as $msgs |
  ($msgs | to_entries | map(select(.value.type == "assistant")) | last | .key) as $last_idx |
  if $last_idx == null then false
  else
    [$msgs[$last_idx].message.content[]?
     | select(.type == "tool_use"
              and (.name == "Edit" or .name == "Write" or .name == "MultiEdit"))
     | .id] as $edit_ids |
    if ($edit_ids | length) == 0 then false
    else
      [$msgs[($last_idx + 1):][].message.content[]?
       | select(.type == "tool_result"
                and (.tool_use_id as $t | $edit_ids | index($t)))]
      | any((.is_error // false) | not)
    end
  end
' "$TRANSCRIPT_PATH" 2>/dev/null)

if [ "$HAS_SUCCESSFUL_EDIT" = "true" ]; then
  exit 0
fi
exit 1
