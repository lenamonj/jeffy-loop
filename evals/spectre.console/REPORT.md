# Jeffy eval: spectreconsole/spectre.console

**Target**: [spectreconsole/spectre.console](https://github.com/spectreconsole/spectre.console) (11,567 stars) at master tip `0acc92fa`, .NET SDK 10.0.302 with net8.0/net9.0/net10.0 test legs - run in a local clone; nothing was pushed upstream. The eighth language in this set.

**The headline**: one run, eight iterations, converged. **One genuine Medium finding, found and fixed**: `Panel` silently drops a header that is wider than its content, so `new Panel("x").Header("HDR")` renders a panel with **no header at all** - not truncated, absent. The shipped change is **14 insertions and 1 deletion in one file**, and it is verified here against pristine upstream: the regression test fails on `0acc92fa` and passes with the patch applied, with **753 tests green and not one existing snapshot altered**.

| Finding | Severity | Behavior at HEAD |
|---|---|---|
| `Panel.Measure` ignores header width (JEF-1) | Medium (correctness) | A header wider than the panel's content is dropped entirely from the rendered output |

## Why the bug survives a 3,618-test suite

`Panel.Measure` returned the child content's width plus the border edges, never considering the header. The header is then rendered through a `Rule`, which drops a title that does not fit the width it is given. The two behaviors compose into silent data loss: the panel measures itself too narrow for its own header, then the header is discarded without warning or ellipsis.

The suite covers headers thoroughly - left, centered and right alignment, and a deliberate `Render_Header_Collapse` case - but every one of those tests uses content wider than the header, or a constrained width where truncation is the intended result. The unconstrained case where the *header* is the widest element had no test, and that is exactly where the loop's surface inventory pointed it.

The fix grows only the natural maximum width, and only when the caller has not pinned one: an explicit `Width`, `Expand = true`, or a narrower parent `maxWidth` all still collapse the header exactly as before. That boundary matters, because `Render_Header_Collapse` asserts the collapse behavior and it passes unchanged.

**Independent verification of the fix** (run for this receipt against a clean clone of upstream, not the loop's tree):

- Red on pristine `0acc92fa`: a test asserting `new Panel("x").Header("HDR")` on a 40-column console contains `HDR` fails - the rendered output contains no header.
- Green with [fixes.patch](fixes.patch) applied: the same test passes, and the full test project reports **753 passed, 0 failed** - the 752 upstream tests plus the new one, with no snapshot updates.

## What the run did

1. **Audits** (iters 1-5) - breadth-first sweeps building a 23-row surface inventory, each row closed with a committed known-answer battery under `.jeffy/probes/` (22 batteries by the end: markup and color, ANSI detection and writer, emoji data, enrichment profiles, prompts, live display, tables, trees, charts, the ImageSharp and Json extensions, the testing library). Iteration 5's replenishment audit filed JEF-1, reproduced by a probe that was proven able to fail before the fix existed.
2. **JEF-1** (iter 6) - the `Panel.Measure` fix, with the contract stated explicitly in the journal: explicit width still wins, `Expand` unchanged, constrained `maxWidth` still collapses. The two inventory rows whose code changed were flipped back to unswept in the same iteration, per the engine's change discipline.
3. **Closing audit** (iter 7) - full fresh-evidence pass, all 23 rows swept, zero High and zero Medium.
4. **Evaluator gate + declaration** (iter 8) - the adversarial evaluator re-ran the verify command, all 21 batteries, and the acceptance check, reviewed the one-file source diff critically, and ran **19 additional edge probes of its own** (markup headers, CJK width, explicit width, `Expand`, constrained parent, `NoBorder`, boundary-fit headers) before passing it. `Converged: 35e6bd76`.

Full record: [journal.md](journal.md). Product diff: [fixes.patch](fixes.patch).

## The limits, stated plainly

- One Medium in a widely used library is a thin yield, and the receipt does not inflate it. The remaining 22 inventory rows came back clean against their own batteries.
- The verify gate runs the library's own suite across three target frameworks; it does not run the source generator's analyzer tests or the ImageSharp extension against real image files beyond what upstream already covers.
- The fix changes rendered output for one previously-broken case. That is a behavior change by definition, and the journal records the preserved contract rather than claiming the change is invisible.

**Status**: fixes live in this eval's artifacts. Nothing was pushed upstream. The finding was disclosed upstream with the rendered before/after evidence and a PR offer in [spectreconsole/spectre.console#2184](https://github.com/spectreconsole/spectre.console/issues/2184) (2026-07-31), raised as an issue first because the project's CONTRIBUTING asks for maintainer buyoff before a pull request.
