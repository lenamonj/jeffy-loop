# Jeffy eval: rack/rack

The HTTP server interface under Rails, Sinatra and most of the Ruby web
stack. Run 2026-08-31 in wave 3 of the merged-PR campaign
(COHORT-WAVE3.md). **3 runs, 26 iterations, converged** at
`10a30a38529432b1e8620299a9a8de4cd27fa42c`, in round 3 of a
**pre-registered budget of 5 rounds of 10** - the only wave-3 target that
needed more than one round, and the one that drew two gate rejections.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `8bf4eb078498edc9105fb04add80d89c5340e60b` (main; upstream CI 18 success + 1 cancelled on this exact commit) |
| Findings closed | **11** - 7 Medium, 4 Low |
| Shipped-code change | 19 files, **+553 / -61** |
| Surface inventory | **30 of 30 rows swept** |
| Ledger at convergence | 2 Lows carried |
| Evaluator | **3 invocations: REJECT, REJECT, PASS** |
| Suite at convergence | `bundle exec rake ci` green across 40 per-file processes |
| Runs that ended blocked | 1 |

## What the loop found

- **`T7` (Medium)** - both multipart limits were off by one against their
  own documented promise: `check_file_part_limit` and
  `check_total_part_limit` compared `count + 1` with `>=`, so the
  documented 128-file default admitted only 127.
- **`T4` + `T8` (Medium, closed as a class)** - media-type parameter
  parsing ignored quoted strings. T4 fixed the two reported symptoms; the
  three-strike rule then forced T8 to close the class structurally - one
  quoted-aware tokeniser shared by every header-parameter site, rather than
  three separate patches.
- **`T1` (Medium)** - `QueryParser#new_depth_limit` rebuilt the parser with
  positional arguments only, so setting `Rack::Utils.param_depth_limit=`
  silently reset a configured `bytesize_limit` and `params_limit` back to
  environment defaults.
- **`T6` (Medium)** - `Multipart::Generator#flattened_params` recursed into
  an Array value assuming every element is a Hash, so an array of plain
  scalars raised `NoMethodError`.
- **`T2` (Medium)** - two publication channels carried the loop's own state
  files: `git archive HEAD` (what `rake dist` packs) and the built gem.
  The tenth packaging channel caught in the corpus.
- **`T3`, `T5` (Low)** - a caller-supplied query separator interpolated
  straight into a regex character class, so `"^"` raised a bare
  `RegexpError` no `Rack::BadRequest` rescue caught; and
  `Rack::Reloader.new(app, nil)` raised `TypeError` at boot because
  `initialize` computed `Time.now - cooldown` before the `if @cooldown`
  guard could ever apply.

## What the gate caught, including the run's own regression

The evaluator rejected twice before passing, and **the second rejection was
the run's own bug**: the T10 fast path used `String#split`, which drops
trailing empty fields, so a separator-only header split to `[]` where the
previous character scanner returned `[""]`, and `type` then called
`nil.rstrip!`. The run filed that against itself as `T11` (High), fixed it,
and the journal records the cause in the first person - *"The cause is mine
and it is the fast path from T10, one iteration old."* Run 2 ended blocked
when its second rejection landed after the invocation cap; run 3 carried
the fix through to a PASS.

No finding here went upstream: T11 was self-inflicted and the rest are
Mediums, below the bar for an unsolicited PR.

## Environment

WSL2, ruby 3.3 with bundler. Engine 1.20.0 on Claude Code 2.1.232, model
`opus[1m]`. **Oracle notes**: `rake test` runs 3 tests - the real suite is
`rake ci`, and each per-file process prints its own summary, so the honest
total is the sum across files (measured 175,918 to 238,347 across 10 probe
runs, since parts of the suite are generative). The gradeable invariant is
"40 files clean, 0 failures, 0 errors", never the run total. The sabotage
proof for this target was cut short when the wave was launched early; the
flake gate passed 10/10 all-files-clean.

Full iteration record: [journal.md](journal.md). Complete shipped diff:
[fixes.patch](fixes.patch).
