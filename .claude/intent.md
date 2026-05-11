# PRD: User class extension (3-spec backlog)

## Goal

Add three methods to `MiniFactoryDemo::User`, working through them as a
**backlog (one spec at a time, in order)**. The mini Software Factory's outer
loop consumes specs in this list; the inner loop converges each spec by
running rspec / rubocop / LLM judge until everything passes.

1. `User#full_name` (already implemented in spec 1)
2. `User#email_address` (spec 2 — to implement)
3. `User#age_in_years` (spec 3 — to implement)

## Spec 1: `full_name` (already implemented)

Returns the user's full name from `first_name` and `last_name`, joined by a
single ASCII space. ASCII whitespace is trimmed from each part.

| # | Input | Expected output |
|---|---|---|
| 1 | `User.new(first_name: "Alice", last_name: "Smith")` | `"Alice Smith"` |
| 2 | `User.new(first_name: "Alice")` (last_name nil) | `"Alice"` |
| 3 | `User.new(last_name: "Smith")` (first_name nil) | `"Smith"` |
| 4 | `User.new` (both nil) | `""` |
| 5 | `User.new(first_name: "  Alice  ", last_name: "Smith")` | `"Alice Smith"` |

## Spec 2: `email_address` (to implement)

Returns a normalized email address from `email`: **lowercased and
ASCII-whitespace-trimmed**. Returns `nil` when `email` is `nil`.

| # | Input | Expected output |
|---|---|---|
| 6 | `User.new(email: "alice@example.com")` | `"alice@example.com"` |
| 7 | `User.new(email: "Alice@Example.COM")` | `"alice@example.com"` |
| 8 | `User.new(email: "  alice@example.com  ")` | `"alice@example.com"` |
| 9 | `User.new(email: nil)` | `nil` |

### Assumptions
- `email` is `String` or `nil`. **Format validation is out of scope** — assume
  the input is well-formed.

## Spec 3: `age_in_years` (to implement)

Returns an integer age in years from `birthdate` (a `Date`), relative to a
reference date (`today`). Returns `nil` when `birthdate` is `nil`. The age
must be **decremented by 1 if the birthday hasn't occurred yet this year**.

Signature: `User#age_in_years(today: Date.today)` — `today` defaults to
`Date.today` and can be overridden for deterministic tests.

(reference today for the table below: `Date.new(2026, 5, 10)`)

| # | Input | Expected output |
|---|---|---|
| 10 | `birthdate: Date.new(2000, 1, 1)` (past this year) | `26` |
| 11 | `birthdate: Date.new(2000, 6, 1)` (later this year) | `25` |
| 12 | `birthdate: Date.new(2000, 5, 10)` (today is the birthday) | `26` |
| 13 | `birthdate: nil` | `nil` |

### Assumptions
- `birthdate` is `Date` or `nil`.
- Use `Date`, not `DateTime`. Time-zone is out of scope.

## Constraints

- Modify only `lib/mini_factory_demo/user.rb` and `spec/user_spec.rb`.
- Do **NOT** modify `lib/mini_factory_demo.rb` or `lib/mini_factory_demo/version.rb`.
- Do **NOT** modify `.claude/scenarios.json` (zoning: tests must adapt to specs,
  specs must not be relaxed to fit a weak implementation).
- All tests must pass under `bundle exec rspec`.
- `bundle exec rubocop` must remain at 0 offenses.
- Total change size for spec 2 + spec 3 should stay under ~80 added lines.

## Out of scope

- Internationalization (i18n)
- Email format validation (assume well-formed input)
- Time-zone handling for age (use `Date`)
- Title prefixes / middle names / nickname handling
- Persistence (no DB / file storage)
