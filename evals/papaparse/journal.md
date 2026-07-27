# Journal: mholt/PapaParse audit

Not a /jeffy loop run and not a sequence of loop iterations. This is a single
agent audit conducted under Jeffy's method: the operating envelope, the severity
rubric and the evidence rule in PLAN.md, applied to a third-party repository in a
scratch clone. Every number below was observed on this machine and pasted from
the terminal, never estimated.

Environment: Windows 11 Pro 10.0.26200, Node v22.18.0, git 2.50.1.windows.1,
npm registry reachable. Date of the audit: 2026-07-27.

Target: `mholt/PapaParse` at `4eb7eaf0ef10aa0f4edd4306a4dd91bc4b60d998`, authored
2026-07-03, `package.json` version 5.5.3. 13,532 stars
(`gh api repos/mholt/PapaParse --jq '.stargazers_count'`).

---

## 1. Harness

`git -c core.autocrlf=false clone https://github.com/mholt/PapaParse.git`, then
`npm install` (341 packages, 23 vulnerabilities reported: 3 low, 3 moderate,
14 high, 3 critical, all in the dev toolchain; the package ships zero runtime
dependencies). Only `npm run test-node` was used. The `test` umbrella script also
runs `test-mocha-headless-chrome`, which pulls puppeteer and headless Chrome, and
that was deliberately never run.

Baseline on the LF checkout:

```
247 passing (32s)
23 pending
1 failing

1) PapaParse
     Pause and resume works (Regression Test for Bug #636):
   Error: Timeout of 30000ms exceeded.
```

`npm run lint` exits 0 at HEAD.

Separately, a DEFAULT Windows clone (`core.autocrlf=true`, no `-c` override) of
the same commit gives:

```
244 passing (34s)
23 pending
4 failing
  1) synchronously parsed CSV should be correctly parsed
  2) Pause and resume works (Regression Test for Bug #636)
  3) asynchronously parsed CSV should be correctly parsed
  4) asynchronously parsed streaming CSV should be correctly parsed
```

Failures 1, 3 and 4 are line endings only: the assertion diff reads
`- "cursor": 1216 / + "cursor": 1209` and `- "linebreak": "\r\n" / + "linebreak": "\n"`
against `tests/long-sample.csv`, which git rewrote to CRLF on checkout. The repo
has no `.gitattributes` (`ls -a | grep -i gitattr` returns nothing). Failure 2 is
the same genuine defect that fails on the LF checkout. These two things are kept
strictly apart in the report: one is a contributor-experience gap in the repo
configuration, the other is a real defect in the library.

## 2. The primary lead, confirmed and then explained

The named test times out because `done()` never runs inside 30 s. It is not a
deadlock. Instrumented run:

```
t=2005ms stepped=126   t=10037ms stepped=630   t=20063ms stepped=1259
```

A steady 63 rows per second, 2001 rows to do, so roughly 32 s: just past the
30 s budget. Counting timers during the same parse gave `400 rows, 399
setTimeout calls, 6291 ms wall, 15.73 ms per row`, which is exactly one
`setTimeout` per resumed row. Measuring the timer itself on this machine:

```
setTimeout(3)  x200 = 3167ms, per=15.84ms
setTimeout(0)  x200 = 3046ms, per=15.23ms
setImmediate  x2000 =   10ms, per= 0.005ms
```

15.6 ms is the default Windows timer resolution. So the whole 32 s is the poll in
`ParserHandle.resume` at papaparse.js:1146, `setTimeout(self.resume, 3)`, paid
once per row.

That poll exists because `resume()` called synchronously from a `step` callback
cannot re-enter the parser: `parseChunk` is still on the stack, so `_halted` is
still false, and re-entering it directly is what produced the
`RangeError: Maximum call stack size exceeded` reported in issue #636.

Honesty check on the lead: upstream CI at this exact commit is green.
`gh api repos/mholt/PapaParse/actions/runs` shows `Node.js CI | master |
completed success | 2026-07-03 | 4eb7eaf`. The workflow runs `ubuntu-latest`
only, where the same poll costs about 3.5 ms and the test finishes in roughly
7 s. The defect is real and platform-independent (a timer per row); the red test
is Windows-specific. Both statements are in the report.

Also checked and corrected: the brief's premise that there has been no release
since 5.4.0 in March 2023 is true only of the GitHub Releases page.
`npm view papaparse time` shows 5.5.0 (2025-01-09) through 5.5.4 (2026-06-19).
The 5.5.4 git tag `af51c9f` is not an ancestor of master HEAD
(`git merge-base --is-ancestor 5.5.4 HEAD` exits non-zero) and `package.json` at
HEAD still reads 5.5.3.

## 3. Issues 985 and 998

Reproduced #998 verbatim from its own CSV and script: with `header: true` and
`pause()`/`resume()` inside `step`, rows 2 onward come back with
`"c2": "foo, bar_1"` and `console.warn('Duplicate headers found and renamed.')`
fires once per row. #985's shape is the same defect with empty values: trailing
empty fields come back as `["", "_1"]`.

Root cause found at papaparse.js:1750,
`if (config.header && !baseIndex && data.length && !headerParsed)`. `baseIndex`
is the streamer's `_baseIndex`, and the paused early return at papaparse.js:539
to 542 exits before `this._baseIndex = lastIndex` ever runs, so `baseIndex` stays
0 for the whole first chunk. A fresh `Parser` is constructed on every resumed
call (papaparse.js:1117), so `headerParsed` resets to false each time. Every
resumed row is therefore treated as a header row and de-duplicated in place.

The second half of #985's title, "loses its place", is a separate consequence of
the same missed bookkeeping: `meta.cursor` is `lastCursor + baseIndex`, and with
`_baseIndex` frozen at 0 while `_input` is re-sliced on each pause, the cursor
restarts inside the remainder. Measured on a 4,286 byte input, 301 rows:
plain streaming ends at cursor 4286 and is monotonic; pause and resume ends at
cursor 15 and is not.

## 4. The class: streaming and chunking as a whole

Transitions enumerated from the code: `ChunkStreamer.parseChunk` has two halt
points (papaparse.js:539 for a `step` pause or abort, papaparse.js:568 for a
`chunk` pause or abort). The first returns before the `_partialLine` and
`_baseIndex` bookkeeping; the second returns after it. `ParserHandle.pause`
aborts the parser and re-slices `_input`; `ParserHandle.resume` re-enters
`parseChunk` with `isFakeChunk` true; `ParserHandle.abort` calls the user's
`complete` itself and clears `_input`. Sources feed this through four streamers
(Network, File, String, ReadableStream) plus a Duplex wrapper.

Three chunk-boundary hazards were tested against a whole-input parse as oracle.

Boundary inside a quoted field: swept every chunk size from 1 to the input length
over four corpora containing embedded delimiters, embedded newlines and escaped
quotes, with `newline` and `delimiter` pinned. Zero mismatches. This path is
sound and is now a guard in `repro.js` rather than a finding.

Boundary at a newline: not sound. With the guessers unpinned, the line-ending
guess is taken from whatever the first chunk happens to be and then cached in
`_config.newline` for the entire file (papaparse.js:1091). Reproduced with
ordinary parameters, not pathological ones: a CRLF file, the documented
`chunkSize: 1024` option, and a header row of 1,589 characters, so the first
chunk contains no line break at all. Result: 51 rows both ways, no error raised,
and every last field plus the last header key carries a stray `\r`
(`"column_name_number_39_padded_to_be_long\r": "v0_39\r"`). The same guess also
misfires when a chunk ends between the CR and the LF of a CRLF pair.

Boundary inside a multi-byte character: not sound. `ReadableStreamStreamer`
decodes each Buffer independently at papaparse.js:891,
`chunk.toString(this._config.encoding)`. Driving a stream so the split lands one
or two bytes into a three-byte UTF-8 sequence turns both halves into U+FFFD:

```
shift=0 byteAt65535=78 byteAt65536=e4  kTail="xx<CJK>"    OK
shift=1 byteAt65535=e4 byteAt65536=b8  kTail="���<CJK2>" CORRUPT
shift=2 byteAt65535=b8 byteAt65536=ad  kTail="x��<CJK2>"      CORRUPT
shift=3 byteAt65535=ad byteAt65536=e6  kTail="xx<CJK>"    OK
```

## 5. Backpressure

`ReadableStreamStreamer.pause` and `.resume` (papaparse.js:846 to 856) call
`ChunkStreamer.prototype.pause.apply` and `.resume.apply`. `ChunkStreamer`
assigns every one of its methods to `this` and puts nothing on its prototype, so
both of those are `undefined`. Calling either throws
`TypeError: Cannot read properties of undefined (reading 'apply')`, confirmed
directly. Nothing in the library calls them anyway, so pausing the parser never
throttled the source.

Measured consequence, 22,177,786 byte file, parser paused after the first row:

```
bytes read at pause   = 65536
bytes read while paused (2s) = 22112250
percent of file buffered while paused = 100.0%
rss at pause = 42.9 MB, rss after 2s paused = 85.4 MB
```

Pushed to a crash: a 400 MB synthetic stream under `--max-old-space-size=128`,
paused after one row, dies with
`FATAL ERROR: JavaScript heap out of memory`, exit 134. The control, the same
400 MB stream and the same heap cap with no pause at all, completes with
`rss=78 MB` and exit 0. So the crash is caused by calling `pause()`, not by the
size of the input.

`StringStreamer.prototype = Object.create(StringStreamer.prototype)` at
papaparse.js:832 is self-referential; it should name `ChunkStreamer.prototype`.
Harmless while `ChunkStreamer.prototype` is empty, and load-bearing the moment
anything is put there, which the backpressure fix does.

## 6. Silent failure

Found by accident: an instrumented probe threw inside `parseChunk` and the
process exited 0 with no output at all. `ReadableStreamStreamer._streamData`
wraps `parseChunk` in `try/catch` and routes everything to `_streamError`, which
calls `_sendError` (papaparse.js:593 to 605). With no `error` callback configured
and outside a worker, `_sendError` does nothing. The parse stops, `complete`
never fires, and there is no diagnostic anywhere.

## 7. Fixes

Applied to papaparse.js, plus one new `.gitattributes`. Two files, 143
insertions, 13 deletions.

- Turned `parseChunk` into a thin wrapper over `_parseChunk` that loops while the
  handle has a resume pending, and replaced the `setTimeout(self.resume, 3)` poll
  with a `_resumeRequested` flag plus `resumeRequested()` and `acceptResume()`.
  Loop, not recursion, so the #636 stack overflow cannot come back.
- `parserConfig.header = needsHeaderRow()`, so the core parser only looks for a
  header row while the handle has not yet captured one.
- `pause()` now advances `self.streamer._baseIndex` by the consumed character
  count before re-slicing `_input`.
- `pause()` and `resume()` now call `self.streamer.pause()` and `.resume()`;
  `ChunkStreamer.prototype` gained real no-op `pause`/`resume` so those calls are
  valid for every streamer, and `StringStreamer.prototype` was pointed at
  `ChunkStreamer.prototype`.
- `ReadableStreamStreamer` gained a `_decode` that keeps one `StringDecoder`
  across chunks, and `_streamEnd` flushes it. Guarded by the project's existing
  `typeof PAPA_BROWSER_CONTEXT === 'undefined'` idiom, so the browser build
  drops it: after `npm run build`, `grep -c string_decoder papaparse.min.js`
  returns 0.
- Line-ending and delimiter guessing take a complete-lines sample via a new
  `completeLines()` helper; the line-ending guess is cached only when the sample
  really contained a line ending.
- `_sendError` rethrows when there is no error callback and no worker.

## 8. Verification

On a fresh clone of the same commit with `git apply fixes.patch`:

```
npm run lint    exit 0
npm run test-node   248 passing (2s), 23 pending, 0 failing
npm run build   1 file created 57.3 kB -> 20.2 kB
node repro.js   9 OK, exit 0
```

Before: 247 passing, 23 pending, 1 failing, 32 s.
After: 248 passing, 23 pending, 0 failing, 2 s. The extra pass is the #636
regression test itself. The 23 pending are browser-only cases in
`tests/test-cases.js`; that count is unchanged and none of them were run.

`repro.js` against pristine HEAD: 8 BUG, 1 OK, exit 1. Against the patched tree:
9 OK, exit 0. The per-row timer count in check 7 goes from 2001 timers and
34,686 ms to 0 timers and 57 ms.

The `.gitattributes` fix was verified rather than asserted: the patched tree was
committed to a local repo and re-cloned with `core.autocrlf=true`. The clone
reports `autocrlf: true`, `tests/long-sample.csv` has no CRLF, and the suite is
248 passing, 23 pending, 0 failing.

## 9. Prior art checked before claiming anything

Open upstream pull requests touching the same ground, none merged at HEAD:
#1099 "Automatically resize chunks to prevent splitting UTF-8 characters"
(2025-07-09) and #909 (2022-01-04) cover the multi-byte defect; #1107 (2025-09-02),
#989 (2023-03-24), #1017 (2023-08-22) and #1131 (2026-07-16) cover the header
de-duplication defect. Issues #985 (open, 15 comments, since 2023-03-23) and #998
(open, 28 comments, since 2023-04-19) are both still open. The findings are
reproduced at HEAD and the fixes are this audit's own, but the defects are not
new discoveries and the report says so.

## 10. Nothing was pushed

All work was done in a scratch clone under the session scratchpad. No push, no
issue, no pull request, no comment upstream. The only files written outside the
scratchpad are the four artifacts in this directory.
