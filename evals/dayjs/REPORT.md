# Jeffy eval: iamkun/dayjs

**Target**: [iamkun/dayjs](https://github.com/iamkun/dayjs) (48,657 stars, verified via `gh api repos/iamkun/dayjs --jq '.stargazers_count'` on 2026-07-29) at upstream HEAD `98364bcebc047529345cc8c2bbcc44a6a8c18e79` (branch `dev`, 2026-06-30), 63 million npm downloads a week, Node v22.18.0 on Windows 11, in a local clone. Nothing was pushed upstream. This is the 2kB date library half the JavaScript ecosystem formats its dates with.

**This is a full `/jeffy` loop run that reached machine-checked convergence.** Eight budgeted runs, 74 iterations: **45 findings filed and closed (10 High, 22 Medium, 13 Low)**, plus one loop-state finding closed at the gate itself. Converged at `781c57adb77e634da4208c5c7035bf65219e680f` on 2026-07-29 with every closing condition independently re-verified for this receipt: empty ledger, all 41 surface-inventory rows swept, only state files changed past the Converged commit, and the five-pass verify chain re-run fresh at exit 0 - **1,230 tests across 101 suites with the 100 percent line-coverage threshold held**, up from 773 tests at baseline. Product diff against upstream: 95 files, **+1,298/-190** across `src/` and `types/`; tests **+3,245/-15** across 25 files.

## What the loop found

Nine of the ten High findings are upstream defects a 63M-download library is shipping today:

- **F1** - the core parser reads ISO fractional seconds as an integer count of milliseconds: `substring(0, 3)` with no right-padding, so `.5` parses as **5ms instead of 500ms**. One line in `src/index.js`.
- **F19** - **a failed build reports success**: both build scripts caught every error, logged it, and exited 0, and the release workflow runs `npm run build && npm run babel` and **publishes immediately after**, inspecting nothing in between.
- **F23** - `src/locale/si.js` ships the traditional Sinhala **lunar** month names, so every Sinhala date names a different month than the date denoted.
- **F38** - `matchIndex % 12 || matchIndex` returns 24 for a format-arm December, so December parsed in one of the 12 two-arm-meridiem locales silently lands in **December of the following year**.
- **F34** - `meridiemMatch` inferred AM/PM from a probe hour's index rather than from which arm matched, so a time formatted by dayjs and parsed straight back came out **12 hours off**.
- **F3** - `localeData().meridiem` was `undefined` for **123 of 143 locales** including default `en`; the documented call threw where the shipped `.d.ts` promises a string.
- **F18** - `dayjs.locale(require('dayjs/locale/ku'))` silently switched nothing: the one rollup entry of 181 with a named export beside its default emitted a reshaped UMD artifact.
- **F2** - `quarterOfYear` coerced its `add` argument with `Number()` before delegating, so objectSupport objects became NaN and returned Invalid Date.
- **F12** - `devHelper` tested the bare global `process`, throwing `ReferenceError` in every browser instead of installing its warnings.

The tenth High, F43, was the run's own - stated plainly below. Fourteen defect classes were settled class-complete with enumerating checks: all 143 locales for hardcoded-English `relativeTime`, bare-number `Do` rendering, and format tokens core does not implement; all 181 rollup entries for the named-export reshape; **all 40 shipped `.d.ts` files, which no compiler had ever checked**; all 6 build-script sites whose failure did not fail the build; every plugin that replaces a core prototype method instead of wrapping it. The suite's growth from 773 to 1,230 tests includes an 858-parse negative corpus, because a parser change verified only on a positive corpus can pass by accepting everything.

## The gate earned its name, three times over

The adversarial evaluator ran **seven times across the conversion: three REJECTs, four PASSes**. The sharpest rejection is run 7's: it surfaced **a High and a Medium that six iterations of self-checking had missed - both regressions introduced by the run's own earlier fixes** (F43: a rewrite dropped the accidental rejection of unparseable `Do` input, so `dayjs('garbage', 'Do')` returned today's date; F44: a derived short weekday name is a prefix of the full name it came from, so `ddd` captured `Mon` out of `Monday` and the default locale stopped accepting a full weekday name it used to accept). That run's parting advice - spend an evaluator invocation early - became the next run's opening move: its audit reversed the previous run's wrong "blocked" verdict on F45 with a deterministic instrument (a counting `ordinal` that prices a cache rebuild at 62 calls against 31 for a hit) before any budget was spent.

The Stop hook then rejected the first convergence declaration outright: markdown backticks on the plan's Command line become command substitution under `bash -c` and exit 127 - the second project in a row to hit this trap at the first mechanically-checked convergence of its life. The run reproduced the mechanism with the hook's own extraction, fixed the line, and re-declared on a byte-identical code tree with the evaluator's PASS standing.

## Compared with the manual audit - the starkest boundary yet

The earlier audit of the same commit went deep on one subsystem - the `timezone` and `utc` plugins - with two instruments the loop never used: an eight-host-zone matrix and moment-timezone as an independent oracle. Its five-check repro, run today against the converged tree, scores **1 of 5 - the identical score pristine upstream HEAD gets**. The loop changed neither plugin; both inventory rows were swept once, at the baseline commit, with single-host known-answer probes - and host-environment defects are invisible to a single-host probe by construction. All three of the audit's High findings stand at the converged tree: `dayjs.tz()` returning host-dependent answers (on a Whitehorse host, `format()` and `valueOf()` describe instants an hour apart), DST ambiguity resolved from `Date.now()` (the same call returns a different instant in January than in July), and frozen offsets after `.tz()` arithmetic (upstream issue [#1260](https://github.com/iamkun/dayjs/issues/1260), open since 2020).

Measured directly at the converged tree under real host zones, driven through `cmd` so `TZ` actually applies on Windows: **America/Whitehorse fails exactly the 4 `plugin/timezone` tests it fails at upstream HEAD; Pacific/Auckland fails exactly the 3 timezone-fragile fixture files the loop's own host zone never exposed.** The loop repaired the two fragile fixtures its New York host revealed and missed the three only Auckland shows: the loop fixes what its environment can show it. One further disclosure this receipt owes: the verify chain's `TZ=America/...` legs are inert under Git Bash on Windows - MSYS2 strips a TZ value containing a slash, proven directly (`process.env.TZ` arrives undefined) - so the chain's real force on this host was the full suite under the host zone and under UTC with the coverage threshold. The three-zone matrix binds only on hosts where TZ propagates.

The reverse direction is equally one-sided: the audit never touched the territory of the loop's 45 findings - not the core fractional-seconds defect, not the locale-data classes, not the build-and-publish integrity class, not the unchecked type declarations. After quantstats (convention defects) and PyPortfolioOpt (distributional defects), dayjs names the third boundary class: **host-environment defects**. A contract that certifies with known answers on one machine certifies exactly what that machine can express.

**Convergence is therefore a claim about a contract, not about perfection**: under Jeffy's severity rubric, envelope, and sweep contract as they stood, a full fresh-evidence audit found nothing High or Medium left on a fully swept 41-row surface, and the adversarial evaluator countersigned. Three known host-environment defects stand outside that contract's reach, named above, still live at upstream HEAD and here.

## Honest caveats

- F43 (High) and F44 (Medium) were regressions introduced by the run's own fixes and caught by the evaluator gate, not by the run.
- `src/plugin/customParseFormat/index.js` is the largest single product change (a 271-line delta): three genuine upstream defects and both of the run's own regressions landed there, and it now carries the paired positive and negative corpora that keep it honest.
- The audit's timezone fixes (DAYJS-1, DAYJS-2, the fixture repairs, the widened CI matrix) are not in the loop's tree; they live in this eval's git history with the pre-conversion receipt.
- `repro.js` is kept exactly as the audit shipped it: the three defects it demonstrates remain live at upstream HEAD and at this tree, so it is current evidence, not a superseded artifact.

**Status**: the work lives in this eval's `fixes.patch` (130 files, +5,483/-696, applies to pristine `98364bc`), `journal.md` (all 81 entries across the eight runs, as written), and `repro.js` (the audit's five-check instrument, scoring 1/5 here and at upstream HEAD alike). Findings were not disclosed upstream as of 2026-07-29.
