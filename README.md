# mini-factory-demo

A miniature [Software Factory](https://factory.strongdm.ai/) (inspired by
StrongDM [Attractor](https://github.com/strongdm/attractor)) implemented with
[Claude Code](https://code.claude.com/) Hooks. Companion repository for the
Zenn article *"RubyKaigi 2026 で聞いた Software Factory を Claude Code Hook
で部分的に再現してみた"*.

## What it does

A 3-spec Ruby backlog (`User#full_name` / `User#email_address` /
`User#age_in_years`) plus Claude Code Hooks that act as the goal gate:

- **`PreToolUse`** blocks edits to off-limits files (`mini_factory_demo.rb` /
  `version.rb` / `scenarios.json`). Prevents the agent from relaxing the
  specs to fit a weak implementation.
- **`Stop`** runs `rspec` (with `--format json` for per-example reporting),
  `rubocop`, a surface check, and an **LLM judge** (`judge.sh`) after every
  response that successfully edited an in-scope file (gated by
  `should_verify.sh`).
- The LLM judge runs **3 trials (default)** of `claude --print` per response,
  averages the satisfaction across the scenarios in `.claude/scenarios.json`,
  and exits 2 if any scenario falls below the 70% threshold.

The `Stop` hook is a miniature port of Software Factory's `goal_gate` and
`scenarios + satisfaction` layers.

## Try it

Requires the `claude` CLI (Claude Code), Ruby 3.1+ with `bundle`, and `jq` on PATH.

```bash
git clone https://github.com/ruiy03/mini-factory-demo.git
cd mini-factory-demo
bundle install

# Confirm the start state: spec 1 passes, specs 2 and 3 fail.
bundle exec rspec
# => 16 examples, 8 failures
#    (email_address and age_in_years are unimplemented TODO comments)
```

`bundle exec rake` runs rspec + rubocop in one go.

Then run Claude Code in this directory:

```bash
claude
```

In the Claude prompt, type:

> Read `.claude/intent.md` and implement the unimplemented spec 2
> (`User#email_address`) and spec 3 (`User#age_in_years`).

What happens automatically:

1. `pre_tool_use.sh` runs before every Edit / Write / MultiEdit and blocks
   out-of-scope file changes.
2. After each response, `stop.sh` runs `rspec` / `rubocop` / a surface check,
   then defers to `judge.sh` (LLM judge).
3. If any stage fails, the hook exits 2 and writes a concrete failure
   message to stderr. Claude continues the conversation and reacts to that
   message in the next turn.
4. If every stage passes, `stop.sh` exits 0 silently — Claude Code does not
   surface stderr from successful hooks, so the session just continues.

The default prompt above runs the happy path silently. To watch a hook
block visibly inside the session, try a prompt that targets an
out-of-scope file:

> Bump the VERSION constant in lib/mini_factory_demo/version.rb to 0.2.0.

The PreToolUse hook exits 2, the block message surfaces in the Claude
session as feedback, and Claude adapts in the next turn (typically by
explaining the block and asking what to do).

For a fuller manual sweep covering the rspec / rubocop / LLM-judge
failure paths and the full-pass message, see
[`docs/hook-verification.md`](./docs/hook-verification.md).

## Repository layout

```
mini-factory-demo/
├── lib/mini_factory_demo/user.rb      # Implementation target (3 methods, 1 done)
├── spec/user_spec.rb                  # 15 rspec examples (1 more in mini_factory_demo_spec.rb)
├── docs/hook-verification.md          # Manual verification of the 6 hook cases
└── .claude/
    ├── intent.md                      # PRD (3-spec backlog)
    ├── scenarios.json                 # LLM judge satisfaction definitions
    ├── settings.json                  # PreToolUse + Stop hook registration
    └── hooks/
        ├── pre_tool_use.sh            # Block scope-violating edits
        ├── stop.sh                    # Calls should_verify.sh, then runs the 4 gates
        ├── should_verify.sh           # Skip when last response had no successful edit
        └── judge.sh                   # 3-trial average via `claude --print`
```

## Key design notes

- **`--setting-sources user`** is passed to the inner `claude --print` call
  in `judge.sh`. Without it the nested Claude Code reads the same
  `.claude/settings.json` and re-fires the Stop hook recursively, pushing one
  trial to 10+ minutes. With it, one trial finishes in ~9 seconds (3 trials
  in ~30 seconds).
- The LLM judge runs **3 trials (default)** to average out judge jitter.
  Software Factory's real `scenarios + satisfaction` layer observes many more
  trajectories; this is the miniature version. Override with
  `MFD_JUDGE_TRIALS=1` for ~10 s iterations instead of ~30 s.
- **Best-effort LLM judge**: if `jq` or the `claude` CLI is missing,
  `judge.sh` skips silently (exit 0). The other 3 stages (rspec / rubocop /
  surface check) still run.
- **Skip on no-op turns**: `stop.sh` defers to `should_verify.sh`, which
  parses the transcript and skips verification when the last response had
  no successful Edit / Write / MultiEdit (text-only reply, or every edit
  blocked by PreToolUse). Without this guard, baseline failures would
  loop forever on turns where nothing has changed.
- Hooks used here (`PreToolUse`, `Stop`) are **stable** Claude Code
  features. No `experimental` flags or `agent-teams` mode required.

## Security note

Project-scoped hooks in `.claude/settings.json` execute **immediately** when
you run `claude` inside the project directory — there is no per-hook
approval prompt. Read `.claude/hooks/*.sh` before running this on your
machine.

## License

Copyright © 2026 Rui Yang. Licensed under [Apache License 2.0](./LICENSE).

Vibe-coded with [Claude Code](https://code.claude.com/).
