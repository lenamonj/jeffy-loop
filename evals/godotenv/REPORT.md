# Jeffy eval: joho/godotenv

The Go port of Ruby's dotenv, the library a large share of Go services use
to read their `.env` file at startup, and one of five targets the 2026-08-22
cohort chose for the shape that converges: one job, a decidable oracle, a
suite that runs in a second. **2 runs, 19 iterations, converged** at
`512f08582392203f3b0d41fba3a30622684592bb`, against a **pre-registered
budget of 1 run of 10 iterations, with a second round of 10 granted on the
cohort's written rule** (a complete map at the end of round 1 earns one more
round; the grant and its reason are recorded in the cohort file before the
relaunch).

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `97a2850142438b3c357c1d3439e325181afdcc1d`, merge of PR #265 |
| Upstream CI on the base | **172 of 173 check-runs green**; the one red is an `Upload Release Assets` job, not the suite |
| Findings closed | **14** - 4 High, 10 Medium |
| Shipped-code change | 8 files, **+1,068 / -42** (library, CLI, CI workflow, README, and the tests that pin each fix) |
| Surface inventory | **11 of 11 rows swept** |
| Ledger at convergence | **5 Lows carried**, listed below; 3 items awaiting the maintainer under Proposed |
| Evaluator | **1 invocation, PASS** |

## What the loop found

A small, widely depended-on parser with four Highs behind a green suite:

- **`T1`** - a value opening with `#` panicked with an index out of range:
  the comment scan read `line[i-1]` at `i = 0`. The envelope classes `Parse`
  as adversarial - the README's own example feeds a remote file's contents
  in - so a hand-crafted `.env` was a crash, and a denial of service, from
  outside.
- **`T2`** - `expandVariables` had drifted from the Ruby regex it ports:
  the case-insensitive flag was gone and the command-substitution guard
  tested the wrong submatch, so `b=${a}` was left as the literal `${a}` and
  `${A.B}` came back as `.B}`.
- **`T13`** - `Read`'s doc comment claimed `Load`'s cross-file semantics
  while its code applied the opposite precedence; the false claim is gone
  and all three precedence rules are now documented and pinned. Aligning
  the behaviour itself is a breaking change to a library that declares
  itself closed to them, so that half is a Proposed item for the maintainer.
- **`T15`** - a quoted value whose last character before the closing quote
  was an escaped quote lost it, and the library's own Marshal-to-Unmarshal
  round trip was broken by the same line. Found by the second run's fresh
  audit after the first run's audit had scored the parser clean.

The ten Mediums: `T17`, where `Write` created env files through `os.Create`
at 0666, which lands at **0644 under the common umask - a credentials file
readable by every account on the machine** - now 0600 and pinned;
`T16`, where CI ran a bare `go test` that grades only the root package, so
the CLI's tests and the autoload tests ran on no CI machine at all; `T7`,
the `autoload` package carrying no test files; `T6`, a UTF-8 byte order mark
failing to parse; `T14`, the key-charset check judging one byte at a time
and naming a character the file never contained; `T3`, `loadFile`
discarding `os.Setenv`'s error so `Load` reported success on a file it had
failed to apply; `T4`, keys accepted outside the documented charset; `T5`,
the CLI collapsing every child exit status to 1; `T12`, a braced reference
to a key containing `.` or `-` mangled rather than resolved; and `T8`,
`Load` applying every file before a later one fails with nothing in the
documentation saying so. One Low, `T11` (the README documented no expansion
behaviour at all), closed inside `T12`'s iteration under change discipline
and is not counted above.

## The gate

The single evaluator invocation ran every acceptance check in both
directions against the pre-fix code restored in a scratch copy, enumerated
the run's behaviour changes by differential against the pre-run parser over
25,465 inputs and found exactly the two intended classes and nothing else,
drove the parser against node dotenv 17.4.2 and ruby dotenv 3.2.0 over a
69-case corpus and a 3,898-case quoted-value corpus, fuzzed 600,000 inputs
for panics (0) and 20,000 values for round-trip mismatches (0), and re-ran
the suite uncached and shuffled three times. It recorded five observations
that were not REJECT reasons; the run filed three of them as Lows rather
than fix after a PASS, which is the rule, and carried them.

## Five Lows carried at convergence

Published rather than dropped, per the severity floor: `T9`
(`ErrZeroLengthString` became reachable when `T4` made a separator-less
statement an error, and no test pins it), `T10` (the comment-scan loop tests
`i < endOfVar` in its body as well as its header), `T18` (three battery
`paths` files do not declare `parser.go` although those batteries execute
it), `T19` (the charset error names U+FFFD for invalid UTF-8 bytes while the
README says it names the character found), and `T20` (the autoload test's
child `go.mod` declares `go 1.22` against a module declaring `go 1.13`; no
CI cell is affected).

## Declared limits

- The Verify command is the project's own bare `go test ./...`. Go caches
  test results by input hash, so the gate re-ran it with `-count=1` and
  `-shuffle=on` itself; the next run should write `-count=1` into the
  Command line per `P1-42`.
- Three of the carried Lows are the gate's own observations, filed by the
  declaring iteration rather than fixed inside the convergence sequence.
- Graded on go1.26.2, linux/amd64 under WSL2, run headless by `claude -p`
  on **claude-opus-5 (1M context) at xhigh effort**.

## Nothing was sent upstream

Every finding rests on tests this loop wrote; no existing test was deleted,
disabled or weakened - `T4` stopped at the half the suite does not pin
because `TestParsing` asserts the empty key on purpose, and that assertion
is the maintainer's to remove, so it sits under Proposed. Whether any of
this goes upstream is a separate decision, made one finding at a time.
