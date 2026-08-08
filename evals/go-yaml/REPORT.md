# Jeffy eval: goccy/go-yaml

**Target**: [goccy/go-yaml](https://github.com/goccy/go-yaml) (2,217 stars, verified via `gh api repos/goccy/go-yaml --jq '.stargazers_count'` on 2026-08-08) at `edee2f91616c6d73112a13e7c0dbde72ce938877`, upstream master at the time of the run. MIT. Go, in a local clone; the loop's work was never pushed anywhere. go-yaml is a widely used YAML parser and encoder for Go, chosen for a property no earlier target in this set had: **it vendors an external conformance corpus**, the 402-case YAML test suite, so its correctness can be judged by something the loop did not write and cannot rewrite into agreement.

**This is a full `/jeffy` loop run that reached machine-checked convergence, in three runs of 29 iterations.** **20 findings filed and closed (6 High, 10 Medium, 4 Low)**, of which the shipped-code change is **13 files, +468/-264**. Converged at `3fa4016d00fbc2f24c80415f1068563efe3c9b43` on 2026-08-08: empty ledger, all **30 surface-inventory rows swept**, the verify command re-run fresh for this receipt at both legs green, and the adversarial evaluator's PASS on record after two rejections.

It is the second Go target in this set, and the first target anywhere in the brownfield arm selected for an oracle outside the loop's reach rather than for its own test suite. Every brownfield run before it was graded by the target's own suite, which is a file the loop is permitted to edit.

## The finding this receipt exists for, and it is not the loop's

**The conformance corpus never ran, in any of the 29 iterations, and the run reported that it had.**

The loop's own verify command was:

```
go test ./... && go test ./testdata -modfile=testdata/go_test.mod
```

The second leg looks like a conformance leg. It is not one: it runs 47 ordinary marshal and unmarshal tests in a separate module that happens to live under `testdata/`, and `TestYAMLTestSuite` is not among them. The only file importing the corpus loader is `yaml_test_suite_test.go`, which carries `//go:build !windows`, so on the Windows host this run executed on, the largest test asset in the repository was never compiled.

Two journal entries state the opposite - "The conformance suite under testdata is green", and "the Verify command exits 0 in both parts, the second part being the yaml-test-suite" - and the adversarial evaluator countersigned both. The engine cannot catch this: the stop hook asks whether the verify command exits 0, and it did.

This receipt is published with that stated first because it is the most informative thing the run produced. The loop did read the corpus - it measured the deepest document in the suite at 5 levels of nesting to justify the depth bound in SEC-01 - so the corpus informed a fix without ever grading one.

**Scored independently for this receipt**, in scratch clones with the build tag removed and one line of the loader corrected (below), at the base commit and at the converged commit:

| Tree | Corpus result |
|:---|:---|
| `edee2f9` (base) | 355 run, 355 passed, 0 failed, 47 excluded by the suite's own known-failure list |
| `3fa4016` (converged) | 355 run, 355 passed, 0 failed, same 47 excluded |

Those two rows are reproducible from published artifacts alone, without this
machine and without the converged tree, which is local and unpublished.
[`reproduce-conformance.sh`](reproduce-conformance.sh) clones pristine
upstream twice, measures the corpus, applies this receipt's `fixes.patch` to
the second copy, and measures again. `fixes.patch` is the run's product diff
with the loop's state files excluded, so the patched clone and the converged
tree are identical everywhere the corpus can see. It takes about a minute and
needs only `git`, `go` and `bash`. It exits nonzero unless both
measurements match the figures published here, so its exit status is itself
the verdict rather than a formality. Its scope is exactly the two rows below:
it re-derives the oracle measurement and nothing else. The 20 findings, the
surface inventory and the evaluator verdicts still rest on the journal and on
`fixes.patch`, and the script does not attempt to re-prove them:

```
tree                ran   passed   failed     exit
base                355      355        0        0
base+fixes          355      355        0        0
```

**The external oracle moved by nothing.** 468 inserted lines of product code changed no conformance outcome in either direction. The 20 findings below may all be real - the evidence for each is in the journal - but none of them was a conformance defect, and the instrument that could have found one was dark for the whole run.

## What the independent check found that the loop did not

Getting a conformance number at all required clearing two defects in the target's own test harness. Neither was found by the loop, and both were found while building an oracle to check it.

**The printed conformance score is not a measurement.** The runner ends with:

```go
total := len(tests)
failed := len(failureTestNames)
passed := total - failed
```

`failed` is the length of a hardcoded list. The test prints `total:[402] passed:[355] failure:[47] passedRate:[88.308456%]` regardless of what the subtests did - it printed exactly that while 389 subtests were failing in front of it.

**The corpus loader hardcodes the path separator.** `testdata/yaml-test-suite/yaml.go` builds each case name with `strings.TrimPrefix(path, dir+"/")`. On Windows `filepath.Walk` supplies backslashes, so the prefix never matches, the following `TrimSuffix` never strips the filename, and every case name becomes an absolute path. Each file then becomes its own map entry, so a case's `in.yaml` is never joined with its `in.json`; the loader's `InYAML == nil` filter discards the orphans, leaving 402 entries with no expected output; and the known-failure lookups never match either. Result: 389 of 402 cases fail. That is why the file is build-tagged off on Windows - **the tag hides a portability bug rather than an incompatibility**.

One line fixes it, `filepath.ToSlash` on both sides of the trim, which is the identity function on other platforms. With it applied the suite passes on Windows for the first time.

**This was filed upstream as [goccy/go-yaml#915](https://github.com/goccy/go-yaml/pull/915)**, and the provenance matters: **it is not a loop finding**. The loop never ran the corpus and never touched that file. It was found during the independent verification of this receipt, and it is counted here as exactly that, never as one of the loop's own results.

## What the loop found

20 findings closed across three runs: **6 High, 10 Medium, 4 Low**. All in code that ships.

The Highs are encoder correctness, and they share a shape - the encoder producing YAML that does not round-trip:

- **BUG-01**: literal block scalar style chosen for strings that style cannot carry unchanged, so `Marshal` emitted documents that either failed to parse or decoded to a different string. Fixed at the style-selection boundary as a class rather than per instance.
- **BUG-02**: `yaml.WithSmartAnchor` emitted unparseable YAML for map values sharing a pointer.
- **BUG-04**: `yaml.UseSingleQuote(true)` emitted Go escape sequences inside single-quoted scalars, which YAML does not interpret, so those documents decoded to different strings. The fix deleted `stdlib_quote.go` (113 lines of vendored standard-library quoting) rather than patching around it.
- **NODE-01**: a scalar node the encoder builds carried the value's quoted rendering instead of the value, so every consumer reading the node rather than its text got the quote characters back as data.
- **SEC-01**: the parser had no nesting bound, so a hostile document could be parsed at a cost the caller never agreed to. The bound is 1000, and the run justified the number by measuring the deepest document in the conformance corpus at 5 rather than by asserting the bound was generous.
- **EVAL-01**: **a regression this run introduced**, and the run says so in those words. `selectorNode.filter` dequoted a mapping key whose first byte was a double quote. That was a compensation for the old encoder behaviour, and it became a corruption the moment NODE-01 made the encoder store raw values. The adversarial evaluator caught it; the loop did not.

The Mediums cover a decoder file-descriptor leak on every `ReferenceFiles` decode, two `Path` traversal gaps (anchors and tags, then aliases), two `ast.SequenceEntryNode` defects behind exported API (`String` was a stub returning empty behind a `// TODO`; `Start` was unmaintained so `GetToken` returned nil for the first entry of every flow sequence), `cmd/ycat` exiting 0 on every failure and writing errors to stdout, context-taking entry points documented in a way a Go caller reads as cancellable when none observes cancellation, and a self-referential cross-reference class in the doc comments.

One Low was **closed as Declined against its own proposed fix**: `ast.CommentGroupNode.Type` reporting `CommentType` rather than `CommentGroupType` turned out to be load-bearing, so the run documented the two constants instead of changing the behaviour and recorded why the filed fix was a regression.

## The evaluator earned the run twice

Three invocations across the three runs, **two REJECT and one PASS**, and the two rejections are the run's best evidence.

The first rejection filed EVAL-01, the loop's own regression, described above. The second rejection produced two Mediums, both reproduced by the loop before being accepted, and one of them is a checkpoint hygiene failure worth naming: **the run had committed a test binary**, `scratch-audit.test.exe`, 5,835,264 bytes, added by an audit iteration's checkpoint and carried in HEAD for four iterations. `go test -c` had dropped it in the working directory and the iteration checkpoint's `git add -A` swept it in. The fix ignores the build-artifact patterns and checks the index rather than trusting it, and the reason is written into `.gitignore` where the next contributor will see it.

Run 1 never reached the gate at all, ending at its budget with a WRAPUP handoff and one High deliberately not started - the run recorded that fixing NODE-01 touches the encode and ast boundary three of its fixes already sat on, and that a change that size could not be verified inside a final iteration. Run 2 was rejected and ran out of budget answering the rejection. Run 3 converged on its ninth iteration of ten.

## Honest caveats

- **The conformance corpus never ran during the run**, and the run twice said it had. That is the first section of this receipt and it is the most important thing in it.
- **The project's own test suite is essentially unchanged**: 144 test functions at the base commit, 144 at the converged commit, with `encode_test.go` the only test file the run touched (+6/-2). All of the run's regression evidence - 23 batteries, 53 files, 6,871 lines - lives in `.jeffy/probes/`, which is loop state rather than the project's harness. A maintainer applying `fixes.patch` therefore receives the fixes with almost none of the tests that prove them, and reproducing that proof means running the batteries out of this receipt's own directory structure.
- **No upstream disclosure of the loop's findings has been made.** The one PR filed against this project, [#915](https://github.com/goccy/go-yaml/pull/915), is the harness fix found by this receipt's verification and is not a loop finding.
- Severity is judged against the operating envelope the run declared in its first audit, which treats YAML input as untrusted and API misuse as out of envelope.
- The run executed entirely on Windows. Platform-specific behaviour on Linux and macOS was not exercised beyond what the project's own suite covers.

## Independently re-verified for this receipt

Every number above was derived from the tree and the journals on 2026-08-08, not copied from the run's own reporting:

- 3 runs and 29 iterations, from 30 journal entries less the one ROTATION entry, cross-checked against 58 checkpoint commits in `git log edee2f9..HEAD`.
- The product diff, `git diff --stat` with the four state files, `.jeffy/` and `.claude/` excluded: 13 files, +468/-264, and `encode_test.go` at +6/-2 within it.
- Test function counts by `git grep -E "^func (Test|Fuzz)"` at both commits: 144 and 144.
- `fixes.patch` applies to a clean clone of pristine upstream `edee2f9`, builds, and passes the project's suite - verified on a fresh `git clone` from GitHub rather than on the loop's tree.
- Both legs of the verify command re-run at the converged tree: exit 0.
- The conformance figures in the table above were produced in scratch clones of both trees, with fixtures confirmed LF, since a `core.autocrlf=true` checkout corrupts 33 cases on its own and would have made those numbers meaningless.

`journal.md` is the run's complete journal, both the rotated archive and the live file, exactly as the loop wrote it.
