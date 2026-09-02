# Jeffy eval: console-rs/console

The terminal abstraction under indicatif and much of Rust's CLI
ecosystem - styling, ANSI parsing, cursor and screen control, key
input, and the width-aware text helpers everything else builds on. Run
2026-09-01 as wave 8 of the campaign (COHORT-WAVE8.md). **1 run, 12
iterations, converged** in round 1 at
`ba9c9aece66a2a612eeacb5ac2e81343be3e31ea`, within a **pre-registered
budget of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `ac3cb733330405349e1c05313a5b4dddcb17afdb` (v0.16.5) |
| Findings closed | **5** - 3 High, 2 Medium (plus 2 filed by the gate and closed in the same run) |
| Shipped-code change | 5 files, **+47 / -38** |
| Surface inventory | **17 of 17 reachable rows swept** |
| Ledger at convergence | 2 Lows carried |
| Evaluator | **2 invocations: REJECT, PASS** |
| Suite at convergence | green through the verify gate, 7 batteries with 7 discriminating mutations |

## What the loop found

Three Highs, and they are one class seen at three sites: **a byte
length used where a character index or a display column was meant.**

- **`H1` (High)** - `Term::read_line_initial_text` mixed
  `initial.len()` (bytes) with a char index, so with any non-ASCII
  initial text **everything the user typed was silently discarded**.
  Reproduced under a real pty: initial text `"Nihon"` in CJK
  characters, user types `abc`, result is the empty string; the same
  probe with initial text `"ab"` returns `"abc"`. The fix removes the
  index rather than correcting it (the char vector now holds only the
  typed suffix), so the class cannot recur at that site. The crate's
  own 0.15.8 notes record two previous repairs to this same prefix
  bookkeeping.
- **`H2` (High)** - with the `ansi-parsing` feature off, `truncate_str`
  indexed the string by `width.saturating_sub(tail.len())`, treating a
  byte offset as a column count, and **panicked mid-character**.
  Closing it exposed a second defect underneath: `char_width` had two
  definitions, and the `not(ansi-parsing)` one returned 1 for every
  character, so it disagreed with `str_width` in exactly the builds
  that ask for unicode widths. Both were fixed together, or the
  truncation would have been silently wrong instead of loud.
- **`H3` (High)** - Windows `read_secure` handled backspace with
  `rv.truncate(rv.len() - 1)`, a byte index into a `String`, so
  **backspacing over any non-ASCII character in a password panicked**.
- **`M1` (Medium)** - `Style::from_dotted_str` had no `"italic"` arm,
  so `red.italic` silently produced red text while every other
  attribute name worked.
- **`M2` (Medium)** - `Cargo.toml`'s `include` patterns were
  unanchored, so the published crate carried this run's own probe
  READMEs. Fixed as a class: every pattern anchored, not the one
  filename that happened to collide.

## What the gate caught

The evaluator rejected at invocation 1, and the reason is worth
publishing: **H3 was closed at High naming a panic no user of the
shipped product can reach.** Working that rejection produced `G1`
(Medium) - the Windows `read_secure` backspace arm matched
`Key::Char('\x08')`, which the key reader never emits, so the backspace
key fell through to `_ => {}` and was discarded entirely. A driver over
the real match blocks, fed the key sequence `read_single_key` actually
produces, returned `"pwd"` where the user typed `pw`, backspace, `d`.
So the site was genuinely broken, just not in the way the run first
claimed, and the gate is what forced the distinction. Invocation 2
passed.

## Upstream

`H2` was filed as
[PR #296](https://github.com/console-rs/console/pull/296), chosen over H1
and H3 deliberately: one PR rather than a slate, and a pure function a
reviewer can verify in one command with no terminal and no
platform-specific code. Reachability was proven from a dependent crate
rather than in-tree, after establishing that `mod utils` is gated on the
`std` feature: the configuration that reaches the bug is
`default-features = false, features = ["std", "unicode-width"]`, where
upstream panics with `end byte index 5 is not a char boundary` and the
fix returns the correct string. H1 and H3 are described in the PR body as
offered follow-ups.

**The first push of that PR went red on CI, and the failure was ours.**
The regression test asserted display-width values unconditionally, while
`char_width` returns 1 per character when the `unicode-width` feature is
off by design, so it failed in every build without that feature. The fix
itself was never in question. The cause was a verification shortcut: three
feature configurations were checked where the project's own `Makefile`
test target runs seven, which is what CI runs. The test is now gated the
way its neighbours in that file are - one form per feature state, both
still failing on `main` with the original panic - and all seven
configurations plus fmt and clippy are green. The correction was posted as
a comment on the thread rather than force-pushed quietly.

**Merged 2026-09-02** by the maintainer as `abf0358`, after one review
round: the description and comments were cut to the facts, the loop over
`chars()` with a running byte count became `char_indices()`, and the
bindings were renamed to say which of them count columns and which count
bytes. The fix's logic did not change between the first push and the merge.
