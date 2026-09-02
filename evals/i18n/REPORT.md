# Jeffy eval: ruby-i18n/i18n

The 1,031-star Ruby internationalization library, the `I18n` module behind
every Rails application's translations. Run 2026-09-02 as wave 14
(COHORT-WAVE13.md). **2 runs, 14 iterations, converged** in round 2 at
`74fc5dc0fff68d1c75095ecce37c0358452c12d8`, within a **pre-registered budget
of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `547917dd8d41fab781a81880f22687fc4eac5d85` (master, 2 commits past v1.15.2) |
| Findings closed | **6** - 3 High, 3 Medium (a fourth Medium, `I18N-09`, was resolved by the `I18N-11` fix and closed with it) |
| Shipped-code change | 16 files, **+253 / -26** (one line of it is loop housekeeping, see below) |
| Surface inventory | **32 of 32 rows swept** |
| Ledger at convergence | 7 Lows carried, each reproduced and re-scored by the gate (see below) |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | `bundle exec rake`: `1659 runs, 2735 assertions, 0 failures, 0 errors, 0 skips` (1607 runs at base) |
| Upstream | [#751](https://github.com/ruby-i18n/i18n/pull/751) (I18N-11), [#752](https://github.com/ruby-i18n/i18n/pull/752) (I18N-01), filed 2026-09-02 |

## What the loop found

- **`I18N-11`** (High) - a pluralized lookup returned the backend's stored
  String. `Base#translate` dups a String entry before pluralizing, but a
  pluralized entry is a Hash at that point, so the value selected out of it
  was the store's own object: `I18n.t(:apples, count: 1) << '!'` left the
  store reading `apple!` on the next lookup, and `Backend::Metadata` could
  not attach metadata to a pluralized entry loaded from a file because those
  strings are frozen (`I18N-09`). Fixed at all three `pluralize`
  implementations that select a value.
- **`I18N-01`** (High) - `I18n.interpolation_keys` returned
  `[["count", "d"]]` for `%<count>d`, the sprintf format specifier alongside
  the key, because `scan` over the unioned patterns returns every capture
  group. Now returns the first non-nil capture, the rule `interpolate_hash`
  already uses.
- **`I18N-02`** (High) - a translation or default stored as the
  two-positional-argument lambda the `*LAMBDAS*` RDoc documents raised
  `ArgumentError` whenever no interpolation values were passed: Ruby 3 hands
  an empty keyword splat to no argument at all. Fixed by passing the hash
  positionally for that one shape.
- **`I18N-04`** (Medium) - `Backend::InterpolationCompiler` never delivered
  a compiled interpolation through `I18n.translate` for any entry shape: the
  compiled method was a singleton on the stored String, and `translate` dups
  the String, which drops singleton methods. The loop's first fix silently
  changed results for `100%% of %{name}`; its own differential check caught
  it, and forms the compiler cannot represent now stay on the interpreted
  path.
- **`I18N-10`** (Medium) - `GetText::PoParser#parse` began `str.strip!`, so
  it mutated the caller's String and raised `FrozenError` on a frozen one.
- **`I18N-03`** (Medium) - the `*PLURALIZATION*` RDoc of `I18n.translate`
  documented pluralized translations as arrays and stated four return values
  the code does not produce.

## What the loop got wrong

**Round 1 ran its whole budget without a declaration.** Ten iterations
closed the three Highs and `I18N-04`, swept the map, and ended at WRAPUP
with `I18N-10` and `I18N-03` still open. Round 2 closed both, audited fresh,
and declared at iteration 4 on the first evaluator invocation. Two rounds
for six findings is the pattern the corpus keeps showing: the Highs land
early and the second round is mostly ceremony.

**Seven Lows carried, none blocking under the declaration floor**: a
process-global normalized-key cache that never evicts; the `:skip_root` key
of the `:cascade` option changing nothing across the 32 combinations the
loop drove; three README/RDoc claims that do not match the tree (a Tests
section naming directories that do not exist, `Rfc4646.tag` documented to
return `false` where it returns `nil`, Rails support claimed from 6.0 with a
CI floor of 7.0); and two more of the same class. The gate re-scored each
as accurately Low.

**A pre-existing suite order dependence surfaced under the loop's own
verify gate** (`test/i18n/interpolate_test.rb` saved a config value by
reference and mutated it) and was fixed in passing during `I18N-10`; the
gate confirmed it reproduced in both directions on the pre-fix tree, so it
was exposed, not introduced.

**Loop housekeeping in the product diff.** One `.gitignore` line for the
loop's own state file.

## Upstream

`I18N-11` and `I18N-01` are filed as
[#751](https://github.com/ruby-i18n/i18n/pull/751) and
[#752](https://github.com/ruby-i18n/i18n/pull/752), each verified on a
fresh clone at upstream HEAD (`547917dd`, the base): the tests alone red
(17 and 3 failures), the full change green under `bundle exec rake` on
Ruby 3.3.8, the project's CI command. The CI matrix also runs older Rubies
and Rails gemfiles, which CI covers. `I18N-02` is held: the fix
introspects the lambda's parameter list to decide how to call it, and
that is a design call for the maintainers rather than a patch to hand
them.

## Files

- [journal.md](journal.md) - the full loop journal, every iteration of both rounds
- [fixes.patch](fixes.patch) - the product diff, base to converged HEAD, loop state excluded
