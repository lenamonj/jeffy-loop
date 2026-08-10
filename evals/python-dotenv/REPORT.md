# Jeffy eval: theskumar/python-dotenv

**Target**: [theskumar/python-dotenv](https://github.com/theskumar/python-dotenv) (8,830 stars) at master tip `751f8c14`, Python 3.14 on Linux - run in a local clone. One finding was later disclosed upstream as a pull request; nothing else was pushed.

**This is a loop run, and it is the longest in this set.** Eight `/jeffy` runs, **73 iterations**, ending in a machine-checked convergence at `1a4e4d0` with the adversarial evaluator's countersignature. **48 findings closed, none declined, 13 defect classes settled.** The test suite went from **220 passing to 511**. The shipped diff is 13 files, +2,185/-143.

**This receipt replaces one that said the run had not converged, and the earlier version was not wrong when it was written.** Through four runs and 25 findings this eval was published here as a failure, on the front page and in this file, because every full audit it ran kept finding something new. That record is kept below rather than deleted, because a method that only publishes its successes is not being measured. The four runs that receipt described are runs 1 to 4 of the eight below.

## The eight runs

Iterations are per-run maxima taken from the journal, not journal entry counts - a single iteration emits extra entries for `AUDIT`, `EVALUATOR` and `ROTATION`, which is how the previous version of this receipt came to state 38.

| Run | Iterations | Findings closed | Ended because |
|---|---|---|---|
| 1 | 9 / 10 | 8 (F1-F8) | budget spent; closing audit filed F9 |
| 2 | 10 / 10 | 8 (F9-F16) | budget spent; two rows stale from its own final fixes |
| 3 | 12 / 12 | 7 (F17-F23) | budget spent, after the one-time +2 closing extension |
| 4 | 5 / 12 | 2 (F24-F25) | stopped by the operator; the audit had just filed F25 |
| 5 | 8 / 8 | 5 (F26-F29, F32) | budget spent; evaluator invoked once, returned an audit |
| 6 | 10 / 10 | 7 (F30, F31, F33-F36, F38) | **blocked** - second evaluator REJECT, no invocation left |
| 7 | 10 / 10 | 5 (F41-F45) | budget spent; evaluator invoked once, returned an audit |
| 8 | 9 / 10 | 6 (F46-F51) | **converged** on the first evaluator invocation |

Findings do not close in the run that files them, which is why the identifiers interleave from run 5 onward. Three identifiers never get a closing entry of their own: **F37, F39 and F40**. F39 and F40 are the two rewrite failure sites the run-6 evaluator found, and the three-strike rule ended instance work on that class, so both were closed at a boundary rather than one at a time. F37 went the same way, one file over. Nothing was declined.

Eighteen full audits ran across the eight runs. In seven runs a full audit still found something. In the eighth, the audit at iteration 8 scored **zero High, zero Medium and zero Low** and began closeout, and the evaluator gate at iteration 9 returned PASS.

Run 6 is the one worth sitting with. Every closing condition held at its final iteration - empty ledger, 10 of 10 inventory rows swept and none stale, a clean audit, a clean tree, Verify green at 470 passed. The evaluator rejected it anyway, for the second time that run, which the closing rule makes a hard blocker, and the cap of two invocations was already spent. The run ended **blocked**, out of budget to answer three fresh findings it had just been handed, two of them Medium. Convergence landed one run later.

## Convergence, condition by condition

Declared at `1a4e4d0`, iteration 9 of a 10-iteration budget, on evaluator invocation 1 of the 2 available - a run that ended with an iteration and a gate invocation unspent.

- **A full fresh-evidence audit scored zero High and zero Medium in-envelope.** Iteration 8 of run 8, which then began closeout.
- **The Surface inventory listed 10 of 10 rows swept with none stale.** The evaluator re-derived staleness from scratch, mapping changed lines to their enclosing definitions rather than trusting the file, and agreed with all ten.
- **Now, Next and Later were empty**, nothing blocked, nothing declined, and no Proposed item awaiting a decision.
- **Verify exited 0 at 511 passed**, re-run in the declaring iteration after the evaluator had swapped sources around, with the tree confirmed clean and no `__pycache__` left behind.
- **The evaluator returned PASS**, and reported real output rather than agreement.

What the evaluator actually did is the part that matters, because a gate that only re-reads a diff certifies nothing. It re-ran every kept instrument to exit 0 and recounted every number quoted in the run's own entries from the commands that produce them: battery 335 checks with the per-row split matching all nine PLAN.md rows that state one, rewrite fidelity at 40 shapes and 2,880 generated inputs and 321 checks, the write-failure register at 12 steps and 17 provocations, the environment gate at 951 checks, documentation at 82 claims, state claims at 30. Then it went past the run's work entirely:

- an exhaustive **911,250-case differential** between the pre-fix and current `resolve_variables`, over three-binding files crossing every name permutation with fifteen value shapes, five environment seeds and both values of `override` - **zero mismatches**;
- **30,924 generated inputs** through the parser hunting a `_is_byte_order_mark` misfire, finding none, every True being index 0 of a file that really does begin with the mark;
- a 144-shape `set_key` fuzz over mark, terminator and unparseable-line combinations, with no fused key and no lost binding;
- F49's discriminator checked on every reachable route in both directions, including closed stdout, `EBADF` and `NotADirectoryError`, with no misclassification either way.

**The falsification is the number this whole grind rests on.** With the run's three source files restored to the base commit, **exactly 10 tests fail, and all 10 are that run's own new tests. 501 still pass, with no unrelated regressions, and `git diff` shows zero deletions anywhere under `tests/`.** Nothing was weakened to reach green. The single probe deletion is F48's fidelity check, whose replacement strictly strengthens it.

## The findings

Selected, most severe first. The full record with acceptance checks and red-green evidence for each is in [journal.md](journal.md).

- **F1 (High) - `set_key(quote_mode="never")` silently writes a different value than it reports.** The value is interpolated raw, so `#`, leading or trailing whitespace, a leading quote, or an embedded newline all read back as something else while the call returns `(True, key, value)`. A 4,000-value seeded fuzz measured **927 round-trip failures in `never` mode against 1 in `always` and 1 in `auto`**, and every one of the 927 returned `(True, key, value)`. The same corpus against the converged tree gives zero in all three modes, because an unrepresentable value now raises rather than being written. That measurement is [repro.py](repro.py) and it is meant to be re-run, not taken on trust. The newline case is a `.env` **injection primitive**: `set_key(p, 'A', 'x\nADMIN=true', quote_mode='never')` produces a file that parses to `{'A': 'x', 'ADMIN': 'true'}`, and reports success.
- **F44 (High) - a UTF-8 byte-order mark was silently deleted from every file the library rewrote.** The fix went in at the invariant rather than at the byte: the parser now yields the mark as a binding of its own, so joining every binding's original reconstructs the input exactly.
- **F42 (High) - the io layer, not the parser, was deciding what a line ending is.** Python's default newline translation destroyed CRLF inside quoted values, where a CR is data, and rewrote whole files to LF. Closed at all four stream boundaries, with the rule that a new binding inherits the file's own terminator.
- **F22 (High) - an undecodable `.env` killed four of five CLI subcommands** with a raw Python traceback rather than a diagnostic.
- **F40 (Medium) - on a full or quota-limited filesystem, `set_key` raised `OSError` with `filename=None`**, naming nothing at all, and left a temporary file at mode 0600 holding a partial copy of the secrets it was rewriting.
- **F46 (Medium) - the CLI reported the wrong subject entirely.** `dotenv run ./script.sh` on a non-executable printed `Error accessing env file`, sending the user to fix a file that was fine. The fix separated the two by asking whether the error names the env file - a discriminator the library's own error-renaming work had already made true - then executed it over five spellings of the same path.
- **F9 (Medium) - `set_key` validated the value and never the key.** `set_key(p, "a=b", "x")` writes `a=b='x'`, which parses back as `{"a": "b='x'"}` - a different key holding a different value, reported as success. This is the one disclosed upstream.
- **F11 (Medium) - `dotenv list --format=export` and `--format=shell` emitted shell syntax a shell cannot evaluate**, because the value went through `shlex.quote` and the key was interpolated raw.
- Plus 40 more across correctness, security, error handling, testing, typing, documentation and developer experience.

## Classes closed, not instances patched

Thirteen defect classes were settled, each with an enumerating check that fails against the pre-fix code and keeps failing if the class reopens. The full text of each is in `BACKLOG.md` in the run's tree; the shape is what matters here:

`rewrite-drops-a-byte-no-binding-carried` - `io-layer-decides-the-line-endings` - `failure-inside-rewrite-misnames-its-path-or-leaks-its-temporary` - `written-line-does-not-round-trip` - `annotation-wider-than-reality` - `unreachable-code and battery-only-coverage` - `parsed-value-reaches-an-environment-unchecked` - `documented-command-line-nobody-ran` - `test-leaves-process-global-state-changed` - `falsy-string-treated-as-absent` - `error-not-about-the-env-file-reported-against-it` - `spawn-failure-blamed-on-the-env-file` - `state-file-claim-that-drifts-from-its-own-command`

Two of these are worth naming for how they were enumerated rather than for what they found. The write-failure register is built from `rewrite`'s **code object**, not from its source text: every line the function compiles to must be registered either as a step that can fail or as inert with a reason, and a registration whose text no longer compiles fails the probe. The documentation class parses the `$ ...` session out of README and runs each command against the real console script, comparing stdout with the output printed beneath it - then extends the same treatment to CHANGELOG entries, which are falsified by history rather than by mutation: run against the parent commit of the fix each entry describes, 6 of 8 claims fail before F42 and exactly 1 before F45, and none fail against the current tree.

## Independent verification, and one finding this receipt retracts

Findings were re-verified against a clean clone of upstream by agents that never read the loop's tree, each followed by an adversarial pass whose job was to refute. Their disposition is not uniform, and saying so is the point of this section.

- **F9 survived refutation** and is the one disclosed upstream. No prior art in their tracker, no test asserts the behaviour, nothing documents it, it is reachable straight from the CLI, and a strict round-trip check on the key keeps all 220 upstream tests green.
- **F1 is real but was not filed**, because upstream [issue #218](https://github.com/theskumar/python-dotenv/issues/218) is this defect verbatim, reported in 2020 and closed as completed in 2021 after PR #330 deliberately fixed `always`/`auto` and left `never` writing raw. Refiling it re-litigates a decision the maintainer already made. The verification also corrected the loop: embedded quotes round-trip fine, only a *leading* quote breaks.
- **F3's stated premise is withdrawn.** The loop filed it as `${VAR:-default}` contradicting the README's documented precedence. It does not. The README defines `FOO=` as "associated with the empty string", so a bare declaration is a value in the file, the first item of the precedence list legitimately wins, and skipping the default is what the documented order prescribes. The behaviour difference from POSIX shells is real and the maintainer has already declined that argument twice; the *contradiction* claim was wrong, and it is retracted here rather than quietly dropped.
- **F5 survived refutation** but was not filed: comparable fixes sit unreviewed in their PR queue since 2022.
- **F1's headline number is corrected here rather than carried forward.** The earlier version of this receipt reported the fuzz as 775 round-trip failures in `never` mode against 211 in `always`/`auto`. That measurement was run once and its corpus was never preserved, so nobody could re-run it - and the `always` figure does not survive inspection either, since that mode quotes the value and a re-measurement finds one failure in four thousand, not 211. The claim is now a committed, seeded harness anyone can execute against upstream's own base commit, and the result it produces is the one printed above.

## Two engine lessons, neither flattering

**Run 3 was the first live firing of the one-time +2 closing extension on a public target, and it exposed the flaw.** The extension is granted at exact budget exhaustion when the ledger is empty and the inventory is swept, on the premise that only the closing ceremony remains. Here the audit *inside* the extension window filed a new Medium, iteration 12 fixed it, and the evaluator gate was never reached. The +2 bought work rather than ceremony. That is recorded as an engine defect, not as a run that misbehaved.

**The run-6 rejection taught the sharper one**, in the loop's own words: *an enumeration of the sites where a defect class lives must be built from what can fail, not from what is written in the source.* F34 and F36 had enumerated the rewrite failure sites by grepping for the temporary file's name. That found the three sites that mention it and missed both the `open` above them, which by then holds the resolved symlink target, and the implicit close at the `with` exit, which has no syscall written anywhere and raises with `filename=None`. The checks written from that grep certified a class that was half open. Run 7 rebuilt the register from the function's code object instead - 45 compiled lines and 11 failing steps - and immediately found a twelfth nobody had listed, the `os.getcwd()` inside `os.path.abspath`.

## Honest caveats

- **Convergence is a statement about this tree under this envelope, not a certificate that the library is now correct.** It says one full fresh-evidence audit filed nothing and an adversarial evaluator failed to break that result. It does not say there is nothing left.
- The suite grew from 220 to 511, and **291 of those tests are the loop's own**. They are falsifiable - restoring the source files fails exactly the 10 that pin this run's fixes - but they were written by the same process that wrote the fixes.
- Only F9's fix has been re-proven independently against pristine upstream. The rest are verified by the project's own suite plus the run's instruments.
- This receipt was published as *not converged* for four runs before it converged. If the standard here is worth anything, that period is evidence rather than embarrassment.

**Convergence standard**: evaluator countersigned. The adversarial evaluator's verdict for this run is in the narrative above; the standard each target met is recorded in [evals/ATTEMPTS.md](../ATTEMPTS.md).

**Status**: fixes live in this eval's artifacts. F9 was disclosed upstream as [theskumar/python-dotenv#678](https://github.com/theskumar/python-dotenv/pull/678), a 51-line pull request cut independently from upstream `main` rather than lifted from this run's tree: the two added tests, applied alone to unmodified `main`, give 8 failures against the 8 rejection cases and 7 passes against the control keys that already round-trip, and the change takes the suite from 220 to 235 passing with `ruff` and `mypy` clean. Its scope is deliberately the key only; the value-side sibling is upstream #218, closed in 2021, and this run does not reopen it.
