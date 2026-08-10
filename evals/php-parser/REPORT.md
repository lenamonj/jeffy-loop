# Jeffy eval: nikic/PHP-Parser

**Target**: [nikic/PHP-Parser](https://github.com/nikic/PHP-Parser) (17,450 stars, verified via `gh api repos/nikic/PHP-Parser --jq '.stargazers_count'` on 2026-08-09) at `fbd47f7ebcbb450138d92642a0a53b72a5285dda`, BSD-3-Clause. PHP, in a local clone; the loop's work was never pushed anywhere. PHP-Parser is the PHP parser underneath PHPStan, Psalm, Rector, php-cs-fixer and most static analysis in the PHP ecosystem, and the base commit is **still the tip of upstream `master`** at the time this receipt was written.

**This is a full `/jeffy` loop run that reached machine-checked convergence, in three runs of 29 iterations** against a **pre-registered budget of four runs**. **18 findings filed and closed (9 Medium, 9 Low, zero High)**, none declined, of which the shipped-code change is **5 files, +233/-41** under `lib/`. Converged at `6574f88081c2bf0f115d8e52aea710c0f2dffe4e` on 2026-08-09: empty ledger, all **29 surface-inventory rows swept or disclosed**, and the adversarial evaluator's PASS on record after two rejections.

It is the **tenth language** in the corpus, and the first target whose selection brief named a specific thing to watch for and then got an answer.

## The measurement this target was chosen for

The brief written before iteration 1 recorded a hazard: `test_old/run-php-src.sh` runs the parser over an entire php-src release, and it is not in the project's documented test command. It appears in no README, no CONTRIBUTING, and nothing but a CI YAML file. So the question was whether a cold loop, told nothing, would find its own project's largest oracle.

**It found it in iteration 1.** The surface inventory carries the row:

> `conformance-php-src`: `test_old/*.php`, `test_old/*.sh` - swept at `fbd47f7e` - `php test_old/run.php --no-progress --php-version=7.4 PHP ./data/php-src` exited 0 over **14,695 files**, each parsed, cloned, format-preserved, pretty-printed and reparsed.

It downloaded the corpus, ran it, swept the row, and built a probe battery around it. Nobody said the directory existed.

Then it did the part that matters more. The Verify command it declared is `php vendor/bin/phpunit` - the unit suite, not the differential - and the declaration **says so, in its own words**, listing what the gate cannot reach:

> What the command cannot reach: (1) `test_old/run.php` and `test_old/run-php-src.sh`, the php-src integration corpus, which lives outside the single `./test/` suite root - **iteration 1 ran it separately, exit 0 over 14695 files**; (2) `tools/fuzzing/target.php` and `generateCorpus.php`, which need `php-fuzzer.phar`; (3) `php tools/vendor/bin/phpstan` and `php tools/vendor/bin/php-cs-fixer`, the `Makefile` targets, which the command does not invoke - iteration 1 ran phpstan separately, exit 0.

That is the v1.8.0 oracle-declaration gate doing exactly what it shipped for. The engine's previous failure on this axis is on the record in the go-yaml receipt, where a run asserted twice that a 402-case corpus was green while nothing ever executed it.

## The vacuous test suite it found on its own

The strongest single finding is not in the backlog at all. It is in the environment fingerprint.

`Lexer\Emulative` re-implements newer-syntax tokenization for older PHP hosts. `EmulativeTest` exercises it and passes. The loop worked out that on this host it passes **without executing a single emulator body**:

> `Emulative` selects an emulator's `emulate()` body only when the host tokenizer predates the feature, and every emulator targets PHP 8.5 or older while this host is 8.5.4, so `php .jeffy/probes/lexer-emulators-forward/probe.php` reports **0 forward selections across all 9 target versions**. `EmulativeTest` passes here without executing any emulator body, because a target equal to the host selects none and `Emulative::tokenize` takes its no-emulation path; the forward direction is covered only by the CI jobs on PHP 7.4 through 8.4.

It then marked the whole surface `[~]` - unreachable on this host rather than swept - and wrote a probe whose job is to report the number that proves it. That is a green test grading nothing, found unprompted, measured, and disclosed. It is the same defect class the corpus already records as a failure, caught this time by the machinery built in response.

Two inventory rows are `[~]` for this reason and neither is scored as clean: `lexer-emulators-forward` and `token-polyfill`, the latter because `TokenPolyfill`'s body is guarded by `PHP_VERSION_ID >= 80000` and needs a PHP 7.4 host to reach.

## What the loop did not find, stated plainly

`test_old/run.php` has a fail-open the loop ran straight past. Its exit guard at line 245 reads:

```php
if (0 === $parseFail && 0 === $ppFail && 0 === $compareFail) {
    $exit = 0;
    echo "\n\n", 'All tests passed.', "\n";
```

`$fpppFail` - the counter for format-preserving byte mismatches, incremented at line 204 - is absent from that condition. The script prints `All tests passed.` and exits 0 with any number of format-preserving failures, and format preservation is exactly what this library's most delicate code does.

The loop ran the script, took its exit status, and did not audit the exit status itself. The maintainer-side check was pre-registered for this reason and is recorded here: at the converged tree, `test_old/run-php-src.sh 7.4.33` exits 0 over **14,695 files with 0 format-preserving mismatches**, unchanged from the baseline measured before iteration 1. The gate was blind to that class and the class never fired.

## What was fixed

Nine Mediums and nine Lows, no Highs. The spine of the run is one class: **the library's byte offsets and the columns derived from them disagreed with each other and with PHP's own tokenizer.**

- `Error::getEndColumn()` returned **0** for any error range ending on a line terminator (G1), and `NodeDumper` carried a verbatim pre-fix copy of the same offset-to-column arithmetic (A3).
- The unterminated-comment error reported an **exclusive** `endFilePos` where the project's own documentation defines the field as inclusive (T1). This is the finding that went upstream.
- `Internal\Columns::toColumn` rejected one out-of-range side and not the other (B2), and `lastLineTerminatorBefore` searched backwards for `"\r"` without bound (B1).
- A filtered run of the project's own gate printed `OK` and then **exited 255** (S2) - the loop found this while following its own Method rule to run a test module in isolation before scoring Testing clean, and the receipt records that the rule is the only reason it was seen.

Documentation findings account for the rest: a namespace-converter example in `doc/2_Usage_of_basic_components.markdown` that did not work, a visitor call-order listing that was wrong, and this run's own state files shipping inside release archives (T5), fixed by a `.gitattributes` export rule.

## The fixture changes are corrections, and the arithmetic says so

Nine test files changed and several carry deletions, which is the shape a laundered regression takes. These are not that, and it is checkable without taking the run's word.

Parsed by the library at the base commit versus the converged tree:

```
'<?php /*'              8 bytes   base: from 1:7 to 1:9    converged: from 1:7 to 1:8
'<?php /*\n'            9 bytes   base: from 1:7 to 2:1    converged: from 1:7 to 1:8
'<?php $x = 1; /* abc' 20 bytes   base: from 1:15 to 1:21  converged: from 1:15 to 1:20
```

Every changed expectation moves from an impossible value to a possible one. An 8-byte input has no column 9. `nopPositions.test` moved from `Stmt_Nop[3:0 - 3:17]`, a column zero that cannot exist in 1-based columns, to `[3:18 - 3:17]`, a correctly encoded empty span.

**No test was weakened.** The project's own suite went from **1,895 tests / 2,766 assertions** at the base commit to **1,907 / 2,795** at the converged tree. Thirty probe batteries under `.jeffy/probes/` carry the class enumerations on top, running **2,307 checks with 0 failures**; they are the run's own instrument and are not counted as the project's tests.

## Two anti-cheat diffs, both clean

The brief named two ways a run could fake conformance here, and both were checked against the converged tree:

- `test_old/run.php` holds a 21-pattern skip list that suppresses known-bad php-src files. **`git diff` reports the file byte-unchanged**: the skip list never grew.
- `lib/PhpParser/Parser/Php7.php` and `Php8.php` are 197KB tables generated from `grammar/php.y`, and upstream CI never regenerates or diffs them, so a hand-edit would pass every job. **Neither file was touched, and neither was the grammar.**

## The run in three parts

| Run | Iterations | Evaluator | Ended |
|:---|---:|:---|:---|
| `fb65c6fc-055411` | 10 | reject | budget spent |
| `29e4bbb1-072001` | 10 | - | budget spent, never reached the gate |
| `abb98afc-123108` | 9 | reject, **PASS** | **converged** |

Counts derived from the run journals by script, not transcribed: 3 runs, 29 iterations as the sum of per-run maxima, 30 journal entries of which 29 are primary, 3 evaluator invocations returning 2 rejections and 1 PASS, keyed on disk as `abb98afc-123108-1.md`, `-2.md` and `fb65c6fc-055411-1.md`.

Run 2 is worth naming rather than hiding: it spent ten iterations and never reached the evaluator, ending on a wrap-up entry with work still on the ledger. Run 3 ran its gate at iteration 6 rather than at the declaration, was rejected, answered it, and converged at iteration 9 with one budgeted iteration unspent.

## One finding went upstream

**[nikic/PHP-Parser#1162](https://github.com/nikic/PHP-Parser/pull/1162)**, +12/-7 across three files, opened 2026-08-09 against the same commit the run started from.

It is the only one of the eighteen with evidence outside the loop's own judgement. `doc/component/Lexer.markdown` defines `endFilePos` as *"Offset into the code string of the last character that is part of the node"*; `Lexer.php` passed `Token::getEndPos()`, which is `pos + strlen(text)`. Every sibling error site in the library writes the attribute inclusively. The contradiction is between two files in the same repository and is settled by `strlen()`, which is why it is filable and the other seventeen are not.

The PR is deliberately smaller than the run's own commit for the same defect: the loop's version leans on an `Internal\Columns` class it introduced, so the upstream patch was rebuilt standalone on a pristine clone and proven in all four quadrants - upstream untouched is green, the fix alone fails 8 tests, the expectation updates alone fail 8, and together they are green.

## Verification done for this receipt

- **`fixes.patch` applies to pristine `fbd47f7`** and is the product diff only, with loop state excluded.
- **The Converged hash is reachable from HEAD**, and the single commit above it is bookkeeping with an empty product diff.
- **The FPPP maintainer check**, above: exit 0, 14,695 files, 0 mismatches.
- **Both anti-cheat diffs**, above.
- **The base-versus-converged error ranges**, above, run against both trees.

## What this run did not do

No High findings. A reader should weigh that honestly: this is a mature parser maintained by a PHP core developer, with expert outside contributors actively working the same code, and the loop found real defects in position arithmetic and documentation rather than anything a user would call a crash. The brief predicted exactly this and said so before the run started.

## Reproducing

```
git clone https://github.com/nikic/PHP-Parser
cd PHP-Parser
git checkout fbd47f7ebcbb450138d92642a0a53b72a5285dda
git apply /path/to/fixes.patch
COMPOSER_ROOT_VERSION=dev-master composer update --no-progress --prefer-dist
php vendor/bin/phpunit
```

`journal.md` is the run's own journal, both the rotated archive and the live file, unedited.

**Convergence standard**: evaluator countersigned. The adversarial evaluator's verdict for this run is in the narrative above; the standard each target met is recorded in [evals/ATTEMPTS.md](../ATTEMPTS.md).
