# Jeffy eval: RubyMoney/money

The Ruby money library: `Money`, `Money::Currency`, exchange banks and
allocation. Run 2026-09-03 as wave 18 (COHORT-WAVE17.md). **1 run, 10
iterations, converged** in round 1 at
`d05390ed74c718c0970942639bcc6fb64e37b6c4`, within a **pre-registered budget
of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `4f107ecc6447ad9c01b3eb1a852b7c8d0b14d2ac` (main) |
| Findings closed | **6** - 2 High, 4 Medium; 3 Lows carried (see below) |
| Shipped-code change | 8 files, **+174 / -18** |
| Surface inventory | **20 of 20 rows swept** (638 battery checks, each battery observed failing under a mutation before it was trusted) |
| Ledger at convergence | 3 Lows carried, 0 blocked |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | `bundle exec rspec spec`: 508 examples, 0 failures (499 at base) |
| Upstream | two PRs prepared (F001, F009), see below |

## What the loop found

- **`F001`** (High, security) - `Money::Bank::VariableExchange#import_rates(:json, ...)`
  deserialized with `JSON.load`, which honours `json_class` keys and
  instantiates any class carrying a `json_create` hook, while the method's
  own warning offers `:json` as one of the "safe alternatives" to the
  Marshal-based `:ruby` format. It now parses with `JSON.parse`, which never
  consults `json_class`. The regression example stubs a class whose
  `json_create` raises and imports a document that names it.
- **`F009`** (High) - `Money::Currency.reset!` replaced the table and
  cleared two caches but never the memoized key set that `Currency.new`
  gates on. After register, then a lookup, then reset!, the gate still
  admitted the removed id, the table no longer held it, and
  `initialize_data!` dereferenced nil: `NoMethodError` where
  `UnknownCurrency` was due, and `find` rescues only the latter, so it
  escaped. reset! now clears the key set with the other two caches.
- **`F008`** (Medium) - `set_rate` documents its rate as `Numeric` and
  accepts a `Rational`, which then died inside `exchange` at
  `BigDecimal("5/4")`. A `Rational` now converts through `to_d` at
  `Money.conversion_precision`.
- **`F002`** (Medium) - `alias eql? ==` sat above the `def ==` it names, so
  `Currency#eql?` bound to `Comparable#==` and raised `NoMethodError` for
  any argument that is not a Currency, where `==` answered false. The alias
  moved below the definition.
- **`F003`** (Medium) - `Currency.unregister` read the raw `@table` instead
  of the memoizing reader, so the first call in a process raised
  `NoMethodError`; it now reads through `table` and maintains the same
  three caches `register` does.
- **`F004`** (Medium) - `Money::Allocation.generate` documents that the
  parts total the amount, and a negative proportion broke that silently:
  `generate(100, [-1, 2])` summed to 200, `[-5]` turned 100 into 0. A
  negative proportion now raises `ArgumentError`, as a negative part count
  already did.

**Carried Lows (3), not blocking**: `F005` YARD `@example` outputs in the
formatter disagree with what the code returns (EUR decimal mark, AWG symbol
placement, a stale BTC example); `F006` the Rakefile's RSpec task sets
`fail_on_error = false`, so `rake spec` exits 0 over a red suite (CI runs
rspec directly); `F007` the `exponent` docstring still calls MGA an
exception rounded to 1 after the project deliberately made it zero-decimal.

## What the loop got wrong

**Nothing in the product beyond the findings above.** The closing audit
re-scored every dimension with fresh evidence and filed nothing; the gate
re-executed every acceptance check on both trees, ran the run's regression
examples against the base library, and hunted regressions over the touched
code, recording only Low observations.

**Two of its own checks passed on both trees before they were rewritten.**
A spec asserting that a cache was invalidated must force the memoization
first, and one did not; a shell check reported "all batteries green"
through a `grep || echo ok` fallback when the grep itself had errored on
an unsupported backreference. Both are in the journal, with the rewrites.

**Host limits, disclosed**: Ruby 3.3.8 only. CI's Ruby 3.1, 3.2, 3.4, 4.0,
head and JRuby legs were not run.

## Upstream

Two PRs are filed on main `4f107ecc`, [#1227](https://github.com/RubyMoney/money/pull/1227) (F001) and [#1228](https://github.com/RubyMoney/money/pull/1228) (F009): `F001` as
`import-rates-json-parse` and `F009` as `currency-reset-clears-keys`, each
one line of library code plus a spec, verified red-then-green in a fresh
clone with rubocop clean, and each carrying the CHANGELOG and AUTHORS lines
CONTRIBUTING.md asks for. `F002`, `F003`, `F004` and `F008` stay in the
receipt: they change accepted input or raised errors, which is the
maintainers' call.

## Files

- [journal.md](journal.md) - the full loop journal, every iteration
- [fixes.patch](fixes.patch) - the product diff, base to converged HEAD, loop state excluded
