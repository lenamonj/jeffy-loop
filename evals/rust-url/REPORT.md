# Jeffy eval: servo/rust-url

**Target**: [servo/rust-url](https://github.com/servo/rust-url) (1,570 stars, verified via `gh api repos/servo/rust-url --jq '.stargazers_count'` on 2026-08-09) at `00a6ce58d02f4e0d43c5ca0702c0bedb8b1ebf3a`, dual MIT / Apache-2.0. Rust, in a local clone; the loop's work was never pushed anywhere. `rust-url` is the URL implementation underneath most of the Rust ecosystem, including cargo, reqwest, hyper clients and Servo itself.

The base commit is **still the tip of upstream `main`** at the time this receipt was written, and it is itself [#1127](https://github.com/servo/rust-url/pull/1127), "Fix hostname preservation in file: URLs that contain drive letters", merged 2026-07-31. The loop was pointed at a repository nine days after a drive-letter fix landed, and found the same area still wrong in ten places.

**This is a full `/jeffy` loop run that reached machine-checked convergence, in three runs of 30 iterations.** **20 findings filed and closed (10 High, 5 Medium, 5 Low)**, none declined, of which the shipped-code change is **6 files, +642/-103** under `url/src`, `data-url/src`, `form_urlencoded/src` and `percent_encoding/src`. Converged at `f5c85511d99814e6a2f66148a5f8e7490eaa6d16` on 2026-08-09: empty ledger, all **19 surface-inventory rows swept**, and the adversarial evaluator's PASS on record after **three rejections**.

It is the first target to converge on engine v1.8.0, and the run exercises two things that release shipped. It is also the fourth target selected under the cold-cohort rule of an oracle the loop cannot rewrite into agreement, and the first one where that rule was **specified as a check to run afterwards** rather than assumed.

## The oracle, and the integrity check that was written before the run

`url/tests/wpt.rs` runs the web-platform-tests URL corpus vendored in-tree: `urltestdata.json` and `setters_tests.json`, **1,143 cases**, re-derived here from the harness's own verdict lines rather than counted from the files.

Alongside it sits `url/tests/expected_failures.txt`, an allowlist of **67 named cases the library did not pass** at the base commit. Documented divergences from the WHATWG URL Standard, published in the repository before the loop started. The headroom was not hypothetical.

**And the allowlist is a file the loop can edit.** That is the property under measurement, and the target brief written before iteration 1 said so, along with what the receipt would have to do about it:

> A run can raise conformance by fixing the parser, or it can appear to by growing `expected_failures.txt`. Both leave the suite green. Which one happened is settled by diffing the vendored corpus and the failure list against pristine upstream at the base commit, and the receipt must do exactly that before publishing any conformance claim.

Run against the converged tree:

| Check | Result |
|:---|:---|
| `urltestdata.json` vs pristine upstream | **byte-identical**, blob `161072d` |
| `setters_tests.json` vs pristine upstream | **byte-identical**, blob `5feffff` |
| `wpt.rs`, the harness itself | **unchanged**, blob `19796ad` |
| lines **added** to the allowlist | **0** |
| lines removed from the allowlist | **1**, `<file:///w|/m>` |
| `#[ignore]` markers across the workspace | **1 before, 1 after**, none added or removed in the diff |
| `#[cfg]` attributes added / removed | **13 / 0**, every addition inside a test the run wrote, none gating an existing test |

The allowlist went **67 to 66** in the only direction it can honestly go. The harness grades both ways, so a case the crate starts passing has to leave the list or the suite fails as an unexpected success; that is the mechanism, and it was confirmed by execution rather than by reading, in all four quadrants.

The corresponding failure the corpus already records is go-yaml, whose receipt had to disclose late that its conformance leg never ran at all. Here the check was specified in advance and it passes.

## What was fixed, and how much of it is one root cause

Ten Highs:

- **`make_relative` returning a reference that does not resolve back to the target** (URL-3, URL-5, URL-6, URL-11, URL-13). The function is documented as the inverse of `join` and was not, across five distinct causes: it ignored userinfo so a reference re-resolved to the base's credentials; it emitted `..` past a `file:` URL's Windows drive letter, which resolution will not climb; it accepted a cannot-be-a-base target and ate the first byte of its path; and its authority gate compared scheme, host, port, username and password but never whether an authority is *present*, so `foo:/a` and `foo:///a` were treated as the same URL.
- **`Url::set_host(None)` rewriting the serialization and every offset but never clearing the parsed host** (URL-2).
- **`Position::BeforePassword` and `Position::AfterPassword` mishandling a URL with a username and no password** (URL-1).
- **A relative reference popping past a Windows drive letter tripping a debug assertion in the parser** (URL-7), returning an unshortened path in release.
- **Two regressions the run introduced into its own fixes** (URL-12, URL-17), both filed by the evaluator gate rather than by the run. See below.

Five Mediums and five Lows cover a `data-url` percent-escape split by a tab or newline decoding to its literal bytes, a reference one trailing slash too long at the resolution floor, an enumeration that could not reach three of the causes it claimed to close, dead code in `shorten_path`, and documentation gaps in `parse_with_params`, `AsciiSet::add`/`remove` and `Serializer::extend_keys_only`.

**Four of the twenty share one root cause**, and it is the one that went upstream. `url/src/parser.rs` decided "is this segment `path[0]`?" by testing `segment_start == path_start + 1`. That assumption holds when the serialization carries a single slash at `path_start` and fails when it carries a run of them, which is what a hostless `file:` URL produces. It broke drive-letter protection on one entrance while working on the other (URL-12), and it stopped the `C|`-to-`C:` rewrite from ever firing for `file:///C|/a` (URL-14).

## One finding went upstream, and only one

**[servo/rust-url#1147](https://github.com/servo/rust-url/pull/1147)**, +12/-2, opened 2026-08-09 against the same commit the run started from. It fixes **[#889](https://github.com/servo/rust-url/issues/889)**, "Incorrect parsing of Windows drive letter quirk", open since 2023-12-11 with no replies.

The reason it is the only one is worth stating plainly, because it is a limit on this receipt and not a modesty note.

**Nineteen of the twenty findings rest on tests the loop wrote.** They are real, they are reproduced, and the adversarial gate re-ran every one of them. But a maintainer reviewing them is being asked to accept our judgement about what `make_relative` ought to return, and `make_relative` has no specification: it is this crate's own convenience function, not a WHATWG algorithm. URL-14 is different. Its evidence is a case in the project's own vendored conformance corpus, which fails on their master and passes with the change, and which nobody here wrote or can edit without it showing in the diff. That is the whole selection rule for what to file upstream, and applying it honestly leaves exactly one candidate.

The PR is deliberately smaller than the run's own commit for the same defect. The loop's version leans on a helper introduced two iterations earlier and bundles a `make_relative` change; the PR carries a ten-line minimal form built on a clean clone. That form was checked against the converged tree over a grid of 410 `file:` inputs and `join` pairs and the two agree on **every one**, so the smaller patch is not an approximation.

Also stated, because the PR body says it: three of the twenty findings changed observable public behaviour and sit in `BACKLOG.md` under **Proposed**, awaiting a semver decision that is the maintainer's to make and not the loop's.

## The class was settled three times before it stuck

This is the part of the run worth reading, and the reason the engine's convergence gate earns its cost.

`make_relative` was declared **fixed class-complete** at iteration 9 of run 1. The evaluator gate withdrew it. It was declared again at iteration 7 of run 2. The run's own closing audit withdrew it. It was declared a third time at iteration 10 of run 2. That run's gate withdrew it too, reproducing two further causes. It held at the fourth attempt, iteration 3 of run 3, with eleven causes closed.

Every withdrawal came from a shape the *enumeration* could not express, never from a flaw in a fix. The grids crossed two schemes with no credentials, no `file:` URLs and no empty-path URLs; then they lacked the `|` spelling of a drive letter; then they lacked the authority-presence dimension. What is different at the fourth attempt is the enumeration, not the confidence.

A run that had converged at any of the first three points would have published a false class-complete claim with a green suite behind it. Three separate gates caught it. That is the honest headline of this receipt, and it argues for the gate rather than for the loop.

## The gate rejected three times and every rejection was a real defect

| Run | Iterations | Evaluator | Ended |
|:---|---:|:---|:---|
| `1acdc3d6-030930` | 10 | reject | budget spent |
| `1e2f368f-051736` | 10 | reject | budget spent |
| `145adc39-071520` | 10 | reject, **PASS** | **converged** |

Counts derived from the run journals by script, not transcribed: 3 runs, 30 iterations as the sum of per-run maxima, 49 journal entries of which 30 are primary and the rest rotation bookkeeping, 4 evaluator invocations returning 3 rejections and 1 PASS. No run ended blocked; the two that did not converge spent their budget with the gate's findings freshly on the ledger.

Two of the three rejections filed a **High that the run had just introduced**: URL-12, a regression in the URL-7 fix from two iterations earlier, and URL-17, an ASCII tab, LF or CR after a leading drive letter changing how a `file:` URL parses. The third withdrew the class settlement described above. None of them was a style objection, and none was wrong.

Run 3 is where v1.8.0 shows. Its gate ran at **iteration 8 of 10**, not at the declaration, and the journal states why:

> run here rather than at the declaration because the ledger emptied with a clean audit on record and three iterations remained - a REJECT needs budget to answer in.

It rejected. Iteration 9 fixed what it found. Iteration 10 re-invoked as invocation 2 and passed. Under the engine's previous rules that first rejection would have ended the run with the work unanswered; the 1.8.0 change that a rejection holding an invocation files its findings and continues is the whole reason this run converged rather than becoming a fourth attempt. The two invocations are on disk as `.jeffy/evaluator/145adc39-071520-1.md` and `-2.md`, which is the ordinal artifact contract the same release shipped, and the second one records that it was told not to defer to the first, which had got the mechanism of its own finding partly wrong.

By its own record in the journal, the gate's work on the passing invocation was substantially wider than the run's: a 5,669-URL corpus, 265,560 tab, LF and CR insertions, and three million random ordered pairs through `make_relative`. It also checked the drive-letter guard from the direction the run had not, forcing its condition false and reporting that 757 answers change, so the guard is not a disguised deletion. Those are the gate's figures, not ones re-derived for this receipt; what was re-derived is everything in the verification section below.

## The tests went into the project's own harness

`url/tests/unit.rs` went from **72 to 77 test functions and +612 lines**; the five new ones are grid generators driving thousands of ordered pairs rather than single cases. The project's own suite went from **14,098 passed** at the base commit to **14,111 passed**, 0 failed and 1 ignored at both ends, that one being upstream's own `idna::punycode::huge_encode`.

**No test was deleted or weakened anywhere in the run.** `git diff --numstat` over the whole span against every test path returns exactly two rows: `url/tests/unit.rs` +612/-0, and `url/tests/expected_failures.txt` +0/-1, the allowlist entry that had to go.

Nineteen probe batteries under `.jeffy/probes/` carry the class-completeness enumerations on top of that. They are the run's own instrument and are not counted as the project's tests. Their build output reached 488 MB and none of it is tracked, which is worth recording only because a sibling target in this corpus did commit a build artifact.

## Verification done for this receipt, not inherited from the run

Every one of these was run here, on the published tree, rather than taken from the journal:

- **Clone test.** A fresh clone of `f5c8551`, running the run's own declared Verify command verbatim: `cargo fmt --all --check`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo test --workspace`, `cargo test --workspace --features "url/serde,url/expose_internals"`, `cargo test --workspace --no-default-features --features=alloc`. **All five exit 0.** The toolchain matches the declared environment fingerprint exactly, cargo and rustc both 1.90.0.
- **`fixes.patch` applies clean to pristine `00a6ce5`** and the patched base runs to the same 14,111 passing.
- **The Converged hash is reachable from HEAD**, and the one commit above it is bookkeeping: its product-file diff is empty.
- **The oracle integrity check** tabulated above.
- **The upstream red-green**, four quadrants, on the PR branch in exactly its published form.

## What this run did not do

The allowlist still holds **66 published conformance defects**. The loop fixed one of the 67. The other 66 are upstream product decisions this run did not touch and filed nothing against, which the backlog states in its own words.

**Fourteen of the twenty findings sit in `make_relative` or in `file:` URL drive-letter handling** - eight in the first, seven in the second, with URL-14 in both. The remaining six are spread across `Position` slicing, `set_host`, `data-url` and three documentation gaps. That concentration is real and it is a limit: all 19 surface-inventory rows were swept, but the run went deep on one neighbourhood rather than broad across the workspace. A reader should take this as evidence about that neighbourhood and about the gate, not as a survey of `rust-url`.

## Reproducing

```
git clone https://github.com/servo/rust-url
cd rust-url
git checkout 00a6ce58d02f4e0d43c5ca0702c0bedb8b1ebf3a
git apply /path/to/fixes.patch
cargo test --workspace
```

`journal.md` is the run's own journal, both the rotated archive and the live file, unedited.

**Convergence standard**: evaluator countersigned. The adversarial evaluator's verdict for this run is in the narrative above; the standard each target met is recorded in [evals/ATTEMPTS.md](../ATTEMPTS.md).
