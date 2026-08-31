# Jeffy eval: rouge-ruby/rouge

The syntax highlighter behind GitLab, Jekyll and much of the Ruby
documentation toolchain - 544 lexer files. Run 2026-08-31 in wave 3 of the
merged-PR campaign (COHORT-WAVE3.md). **1 run, 11 iterations, converged**
at `429c51f9721845ea689febe0c47df1b988b04b8f`, in round 1 of a
**pre-registered budget of 5 rounds of 10**.

The wave's predicted budget risk, on the theory that 544 lexers would
explode the surface inventory. They did not: the audit mapped 23 rows by
treating lexers as a class, and the run closed first time. Recorded here
because the prediction was written down before launch and was wrong.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `16e6ecdb3bc4248cead78375e1b24580ee2352a1` (main; upstream CI 10 success on this exact commit) |
| Findings closed | **5** - 2 High, 3 Medium |
| Shipped-code change | 8 files, **+154 / -14** |
| Surface inventory | **23 of 23 rows swept** |
| Ledger at convergence | 5 Lows carried, named in the closing entry |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | `bundle exec rake check:specs` green, 1,324 runs / 5,802 assertions |

## What the loop found

- **`R-1` (High)** - `rougify highlight -t <unknown-theme>` died with an
  unhandled `NoMethodError` instead of the `unknown theme <name>` message
  the code already contained: `Theme.find(opts[:theme]).new or error! ...`
  sends `.new` to the nil lookup result before `or` is ever evaluated, so
  the intended message is unreachable. Filed upstream as
  [rouge-ruby/rouge#2332](https://github.com/rouge-ruby/rouge/pull/2332).
- **`R-2` (High)** - `rougify highlight <missing-file>` printed its clean
  `unable to open ...` line and then crashed with an unhandled
  `Errno::ENOENT` backtrace, because `FileReader#file` opened a fresh
  handle on every call, so the `ensure file.close` never closed the handle
  the error came from.
- **`R-3` (Medium)** - the Lua lexer's two documented options were inert on
  the documented paths: it read them with `opts.delete(:function_highlighting)`
  on the raw hash instead of the `bool_option`/`list_option` accessors every
  sibling uses, so a string key was missed entirely.
- **`R-6` (Medium)** - `rougify help highlight` documented
  `--formatter-opts|-F`, which the parser never handled: the long form
  exited 1 with `unknown option`, and the short form fell through to the
  bare-argument branch and was taken as the input filename.
- **`R-4` (Medium)** - `Formatters::HTMLTable` yielded its trailing
  whitespace span to the output stream *before* the `<table>` element was
  opened, so every input not ending in a newline - including empty input -
  emitted a stray `<span class="w">` outside the table.

## Environment

WSL2, ruby 3.3 with bundler. Engine 1.20.0 on Claude Code 2.1.232, model
`opus[1m]`. **Oracle note that would have broken the run**: rouge's default
`rake` task is RuboCop lint only - the real oracle is `rake check:specs`,
and a run graded on bare `rake` would have certified nothing. The sabotage
proof for this target was cut short when the wave was launched early; the
flake gate passed 10/10 at exactly 1,324 runs / 5,802 assertions.

Full iteration record: [journal.md](journal.md). Complete shipped diff:
[fixes.patch](fixes.patch).
