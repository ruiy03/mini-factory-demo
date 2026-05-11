# VERIFICATION

Manual verification commands for the 6 cases described in §4.3 of the
companion Zenn article ── 5 expected failures and 1 expected pass. Each case
is a one-liner that drives a hook directly from the shell, so you can confirm
that the gates fire (or pass) exactly as described.

Run every command from the repository root.

## Setup

```bash
bundle install
```

## Case 1 — PreToolUse: editing an out-of-scope file

```bash
echo '{"tool_input":{"file_path":"lib/mini_factory_demo/version.rb"}}' \
  | .claude/hooks/pre_tool_use.sh
echo "exit=$?"
```

Expected: `exit=2` and stderr starts with
`PreToolUse gate: editing out-of-scope file is blocked`.

## Case 2 — PreToolUse: editing scenarios.json (zoning)

```bash
echo '{"tool_input":{"file_path":".claude/scenarios.json"}}' \
  | .claude/hooks/pre_tool_use.sh
echo "exit=$?"
```

Expected: `exit=2` and stderr starts with
`PreToolUse gate: editing scenarios.json is blocked`.

## Case 3 — Stop: rspec fail (remove `#full_name`)

```bash
git stash push -- lib/mini_factory_demo/user.rb
ruby -i -pe 'gsub(/^\s*def full_name.*?^\s*end\n/m, "")' \
  lib/mini_factory_demo/user.rb
echo '{}' | .claude/hooks/stop.sh
echo "exit=$?"
git stash pop
```

Expected: `exit=2` and stderr lists the failing rspec examples
(`Stop gate: rspec 16 examples, N failed`, then per-example failures).

## Case 4 — Stop: rubocop fail (introduce an unused variable)

```bash
git stash push -- lib/mini_factory_demo/user.rb
sed -i '' '/^\s*def full_name/i\
    unused = 1
' lib/mini_factory_demo/user.rb
echo '{}' | .claude/hooks/stop.sh
echo "exit=$?"
git stash pop
```

Expected: `exit=2` and stderr starts with `Stop gate: rubocop failed`,
followed by the offending file/line from rubocop.

## Case 5 — Stop: LLM judge fail (hardcoded `#full_name`)

Replace the body of `#full_name` with a constant string that ignores the
inputs, so the rspec specs may fail and the scenarios definitely should not
be satisfied.

```bash
git stash push -- lib/mini_factory_demo/user.rb
ruby -i -pe 'gsub(/^(\s*def full_name.*?\n)(.*?)(^\s*end)/m,
  "\\1      \"hardcoded\"\n\\3")' lib/mini_factory_demo/user.rb
echo '{}' | .claude/hooks/stop.sh
echo "exit=$?"
git stash pop
```

Expected: `exit=2`. Depending on which gate trips first you will see either
the rspec failures or, once rspec passes, the LLM judge output
(`judge gate: scenario id=N average satisfaction X% < threshold`).

## Case 6 — Stop: full pass (after specs 2 and 3 are implemented)

The published HEAD ships specs 2 and 3 as TODO comments, so `Stop` will fail
on Case 6 by design. To see the full-pass path, implement
`#email_address` and `#age_in_years` first (either by hand or by asking
Claude to consume `.claude/intent.md`), then:

```bash
echo '{}' | .claude/hooks/stop.sh
echo "exit=$?"
```

### Expected on success

`exit=0` and stderr ends with the summary line
`judge gate: all 13 scenarios pass at >= 70% average satisfaction across 3 trials`
followed by 13 per-scenario lines like
`  - id=1 avg=95% (trials: [95,95,95])`.

### Expected on partial / faulty implementation

`Stop` exits 2 with the first failing gate's message. The three patterns
you can encounter while iterating toward full pass:

- `Stop gate: rspec 16 examples, N failed` — implementation does not match
  the spec (wrong return value, missing nil-handling, etc.). Stage 1.
- `Stop gate: rubocop failed` followed by an offense like
  `Metrics/AbcSize: ... too high` — rspec passed but rubocop's complexity
  metrics did not. Observed in this repo when `#age_in_years` was written
  with an explicit month/day comparison (`today.month > birthdate.month
  || ...`); rewriting it with `Date#>>` (`birthdate >> (age * 12) > today`)
  brings AbcSize back under the limit. Stage 2.
- `judge gate: scenario id=N average satisfaction X% < threshold` — rspec
  and rubocop passed but the LLM judge thinks the implementation does not
  satisfy the user-facing intent. Stage 4.

Re-edit `lib/mini_factory_demo/user.rb` based on the stderr message and
re-run until `exit=0`. This is the bounce-back retry loop that the article
describes — the stderr is what gets fed back to Claude as the next-turn
instruction.

## Notes

- Cases 3–5 use `git stash` to keep the working tree intact. If a case is
  interrupted, restore the file with `git checkout -- lib/mini_factory_demo/user.rb`
  before continuing.
- The LLM judge in Case 5 calls `claude --print` 3 times by default, so it
  takes ~30 seconds. Set `MFD_JUDGE_TRIALS=1` to make it ~10 seconds while
  iterating.
