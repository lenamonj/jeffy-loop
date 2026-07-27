# Jeffy eval: mholt/PapaParse

**Target**: [mholt/PapaParse](https://github.com/mholt/PapaParse) (13,532 stars, verified) at HEAD `4eb7eaf0ef10aa0f4edd4306a4dd91bc4b60d998`, authored 2026-07-03, `package.json` 5.5.3, Node 22.18.0 on Windows 11 - run in a local clone; nothing was pushed upstream.

This is an agent audit conducted under Jeffy's method, not a /jeffy loop run. The envelope, the severity rubric and the evidence rule from PLAN.md were applied to a third-party repository in a scratch clone.

**The headline**: PapaParse served 14,307,582 npm downloads in the week of 2026-07-18 to 2026-07-24, and its streaming path is where the defects are. The lead was a genuinely red regression test at HEAD. It reproduced, and running it down led into the pause, resume and chunk-boundary state machine, where the audit found four ways a streaming parse silently returns wrong data or dies. The quoted-field chunk-boundary path, tested exhaustively, is correct and was left alone.

| Finding | Severity | Behavior at HEAD |
|---|---|---|
| Multi-byte character split by a chunk boundary | High (correctness) | Both halves decode to U+FFFD; the field is silently corrupted |
| Line ending guessed from a truncated first chunk | High (correctness) | Stray `\r` on every last field and the last header key of a CRLF file; no error, correct row count |
| Header de-duplication re-run after resume | High (correctness) | Data rows rewritten in place: `"foo, bar"` becomes `"foo, bar_1"`, empty trailing fields become `"_1"` |
| `pause()` applies no backpressure | High (performance) | 100 percent of a 22 MB stream buffered in memory while paused; a 400 MB stream dies with `FATAL ERROR: JavaScript heap out of memory` |
| `resume()` polls with a timer per row | Medium (performance) | The project's own regression test for bug #636 needs about 32 s against a 30 s budget and fails |
| `meta.cursor` restarts after resume | Medium (correctness) | Cursor goes backwards and never reaches the end of the input |
| Stream errors dropped with no `error` callback | Medium (error handling) | Parse stops with no rows, no `complete`, no diagnostic, exit code 0 |
| No `.gitattributes` | Medium (developer experience) | A default Windows clone reddens three tests on line endings alone. **Not a parser defect** |
| `StringStreamer.prototype` self-assignment | Low (code quality) | Inert today; breaks any future `ChunkStreamer.prototype` method |

**Suite state**: 247 passing, 23 pending, 1 failing before. 248 passing, 23 pending, 0 failing after. The extra pass is the previously failing #636 regression test. Wall time for `npm run test-node` fell from 32 s to 2 s. `npm run lint` and `npm run build` exit 0 on both sides.

## Two premises in the brief, corrected before anything was filed

**The shipped artifact is not three years behind.** The GitHub Releases page stops at 5.4.0 (2023-03-02), but `npm view papaparse time` shows 5.5.0 through 5.5.4, the last published 2026-06-19. What is genuinely odd, and is routed to the owner below rather than treated as a finding: the `5.5.4` tag (`af51c9f`) is not an ancestor of master HEAD, and `package.json` at HEAD still reads 5.5.3.

**The red test is Windows-specific.** `gh api repos/mholt/PapaParse/actions/runs` shows `Node.js CI | master | completed success` at exactly `4eb7eaf`. That workflow runs `ubuntu-latest` only. The underlying defect is platform-independent, one timer per resumed row; the timer costs about 3.5 ms on Linux and 15.8 ms on this Windows box, which is the difference between roughly 7 s and roughly 32 s for a 2,001 row test with a 30 s budget. The defect is reported at the severity its consequence earns, not at the severity the red test suggests.

## Findings

**PAPA-1 (High, correctness)** - `ReadableStreamStreamer` decodes each Buffer chunk on its own, `papaparse.js:891`, so a UTF-8 sequence straddling a chunk boundary is destroyed. Driving a stream so the split lands one byte into a three-byte character turns both halves into U+FFFD; the row count and the error list stay clean, so nothing signals it. Fixed by holding one `string_decoder.StringDecoder` for the life of the stream and flushing it in `_streamEnd`. The decode path is guarded by the project's existing `typeof PAPA_BROWSER_CONTEXT === 'undefined'` idiom, so the browser bundle drops it: `grep -c string_decoder papaparse.min.js` returns 0 after `npm run build`.

**PAPA-2 (High, correctness)** - the line-ending guess is taken from whatever the first chunk happens to hold and then cached for the whole file, `papaparse.js:1091`. Reproduced with ordinary parameters, not pathological ones: a CRLF file, the documented `chunkSize: 1024`, and a 40 column header row of 1,589 characters, so the first chunk contains no line break. Result is 51 rows both ways, zero errors, and every last field plus the last header key carrying a stray CR (`"column_name_number_39_padded_to_be_long\r": "v0_39\r"`). The same guess also misfires when a chunk ends between the CR and the LF of a CRLF pair. Fixed with a `completeLines()` helper: both guessers see only whole lines, and the line ending is cached only once the sample actually contained one.

**PAPA-3 (High, correctness)** - `if (config.header && !baseIndex && data.length && !headerParsed)` at `papaparse.js:1750` decides "this is the first chunk" from `baseIndex`, which never advances while the caller is paused because the paused early return at `papaparse.js:539` exits before the bookkeeping at `papaparse.js:546-550`. A fresh `Parser` is built on every resumed call, `papaparse.js:1117`, so `headerParsed` resets too. Every resumed row is therefore de-duplicated as if it were a header row and rewritten in place. This is upstream issue #998 (`"foo, bar"` becomes `"foo, bar_1"`, with `console.warn('Duplicate headers found and renamed.')` once per row) and upstream issue #985 (empty trailing fields become `"_1"`, `"_2"`). Fixed by `parserConfig.header = needsHeaderRow()`: the handle already knows whether it has captured a header, so the core parser stops guessing from an offset.

**PAPA-4 (High, performance)** - `ReadableStreamStreamer.pause` and `.resume`, `papaparse.js:846-856`, call `ChunkStreamer.prototype.pause.apply` and `.resume.apply`, but `ChunkStreamer` assigns every method to `this` and leaves its prototype empty, so both throw `TypeError: Cannot read properties of undefined (reading 'apply')`. Nothing calls them anyway, so `pause()` never throttled the source. Measured: with the parser paused after the first row, 100 percent of a 22,177,786 byte file was buffered within 2 s and RSS went from 42.9 MB to 85.4 MB. Pushed to a crash, a 400 MB stream under `--max-old-space-size=128` dies with `FATAL ERROR: JavaScript heap out of memory`, exit 134, while the same stream and heap cap with no pause completes at RSS 78 MB and exit 0. So the crash is caused by using the documented `pause()` API, not by input size. Fixed by giving `ChunkStreamer.prototype` real no-op `pause`/`resume` hooks, pointing `StringStreamer.prototype` at `ChunkStreamer.prototype`, and wiring `ParserHandle.pause`/`resume` to call them. After the fix the source pushes 0.0 MB more while paused.

**PAPA-5 (Medium, performance)** - the primary lead. `ParserHandle.resume` cannot re-enter the parser when it is called synchronously from a `step` callback, because `parseChunk` is still on the stack, so it polls with `setTimeout(self.resume, 3)` at `papaparse.js:1146`: one timer per resumed row. Measured on this machine, `setTimeout(3)` costs 15.84 ms against the default Windows timer resolution, so the project's own `Pause and resume works (Regression Test for Bug #636)` needs about 32 s and times out at 30 s. Instrumented: 2001 rows, 2001 `setTimeout` calls, 34,686 ms. Direct re-entry is not an option; it is what produced the `RangeError: Maximum call stack size exceeded` in issue #636. Fixed by recording the request in `_resumeRequested` and continuing in a loop when `parseChunk` unwinds, so resume is never recursive and never waits on a timer: 2001 rows, 0 `setTimeout` calls, 57 ms.

**PAPA-6 (Medium, correctness)** - the same missed bookkeeping behind PAPA-3 also breaks `meta.cursor`, the documented progress offset. `pause()` re-slices `_input` at `papaparse.js:1135` without moving the streamer's `_baseIndex`, so `lastCursor + baseIndex` restarts inside the remainder. Over a 4,286 byte input and 301 rows, plain streaming ends at cursor 4286 and is monotonic; pause and resume ends at cursor 15 and is not. This is the "loses its place" half of issue #985. Fixed by advancing `self.streamer._baseIndex` by the consumed character count inside `pause()`.

**PAPA-7 (Medium, error handling)** - `ReadableStreamStreamer._streamData` wraps `parseChunk` in `try/catch` and routes everything to `_streamError`, which calls `_sendError` at `papaparse.js:593-605`. With no `error` callback configured and outside a worker, `_sendError` does nothing at all: the parse stops, `complete` never fires, and the process exits 0 with no diagnostic. Found by accident when an instrumented probe threw and vanished. Fixed by rethrowing when there is no error callback and no worker. This is a deliberate observable behavior change and is listed under limitations.

**PAPA-8 (Medium, developer experience)** - the repository has no `.gitattributes`, so a default Windows clone (`core.autocrlf=true`) rewrites `tests/*.csv` to CRLF and reddens three tests that compare fixtures byte for byte: 244 passing, 23 pending, 4 failing, with diffs reading `- "linebreak": "\r\n" / + "linebreak": "\n"` and `- "cursor": 1216 / + "cursor": 1209`. **This is not a parser defect.** It is the first thing a Windows contributor sees, and it hides the one genuine failure among three false ones. Fixed by adding `.gitattributes` with `* text=auto eol=lf`. Verified rather than asserted: the patched tree was committed locally and re-cloned with `core.autocrlf=true`; the clone reports `autocrlf: true`, the CSV fixtures have no CRLF, and the suite is 248 passing, 23 pending, 0 failing.

**PAPA-9 (Low, code quality)** - `StringStreamer.prototype = Object.create(StringStreamer.prototype)` at `papaparse.js:832` is self-referential and should name `ChunkStreamer.prototype`. Inert while `ChunkStreamer.prototype` is empty, and load-bearing the moment anything is put on it, which PAPA-4's fix does. Fixed as part of PAPA-4.

## What the audit did not find, and says so

The quoted-field chunk-boundary path is **correct**. Every chunk size from 1 to the input length was swept over four corpora containing embedded delimiters, embedded newlines and escaped quotes, with `newline` and `delimiter` pinned so the guessers could not be the cause, and compared against a whole-input parse: zero mismatches. That result is now check 8 in `repro.js`, a guard rather than a finding, so a future fix that breaks it fails loudly. The corruption in this area comes from the guessers being fed a truncated sample and from Buffer decoding, not from the quote state machine.

## Prior art

None of these defects are new discoveries, and this receipt does not pretend otherwise. Open upstream pull requests at HEAD, none merged: #1099 (2025-07-09) and #909 (2022-01-04) target the multi-byte defect; #1107 (2025-09-02), #989 (2023-03-24), #1017 (2023-08-22) and #1131 (2026-07-16) target the header de-duplication defect. Issues #985 (open since 2023-03-23, 15 comments) and #998 (open since 2023-04-19, 28 comments) are both still open. What this audit contributes is a reproduction at HEAD, the root cause shared by four separate symptoms, and one patch that closes all of them with the suite green.

## Artifacts

- [repro.js](repro.js) - offline and self-contained, no network and no fixture files. Drop it into a clone and run it: 8 BUG and 1 OK against HEAD, exit 1; 9 OK after the patch, exit 0.
- [fixes.patch](fixes.patch) - 2 files, 143 insertions, 13 deletions. Applies cleanly to `4eb7eaf` with `git apply`. `papaparse.min.js` is a committed build artifact and is excluded; `npm run build` regenerates it.
- [journal.md](journal.md) - the full record with every command output.

**Routed to the owner under Proposed, not seized**:
- The release picture is inconsistent and only the owner can settle it: npm latest is 5.5.4 (published 2026-06-19), the `5.5.4` tag `af51c9f` is not an ancestor of master HEAD, `package.json` at HEAD reads 5.5.3, and the GitHub Releases page stops at 5.4.0. No tagging or publishing action was taken.
- CI runs `ubuntu-latest` only. A Windows job would have caught PAPA-5. Adding one is a maintainer cost decision, so it is proposed rather than committed.
- `npm install` reports 23 vulnerabilities (3 low, 3 moderate, 14 high, 3 critical), every one of them in the dev toolchain: eslint 4.x, mocha 5.x, grunt, puppeteer 13. The package itself ships zero runtime dependencies. Modernising that toolchain is churn with real risk and is not this audit's call.
- PAPA-3's fix moves the decision about when the core `Parser` looks for a header row from the parser to the handle. Open PR #1100 ("V6") may want that ownership drawn differently. The narrow fix was made; the refactor was not.

**Disclosed limitation**:
- Only `npm run test-node` was run. The browser suite (`npm run test-mocha-headless-chrome`) pulls puppeteer and headless Chrome and was deliberately never run, so the 23 pending browser-only cases were not exercised before or after. `NetworkStreamer` and `FileStreamer`, which are browser paths, were not tested at all.
- Everything was observed on Windows 11 with Node 22.18.0. The timer measurements in PAPA-5 are machine-specific by nature; the Linux figure is inferred from upstream CI being green at the same commit, not measured here.
- PAPA-7's fix changes observable behavior. A stream or network error with no `error` callback configured now throws instead of stopping in silence. That is the point of the fix, but it is a breaking change for anyone who depended on the silence.
- The delimiter guess is cached exactly the way the line-ending guess was. It was given the same complete-lines sample as part of PAPA-2's fix, but no independent delimiter failure was reproduced, so no claim is made about it.
- PAPA-4's crash was demonstrated under a deliberately constrained heap (`--max-old-space-size=128`) against a 400 MB stream. Under a default heap the same defect needs a proportionally larger input; what was measured directly is that 100 percent of the input is buffered while paused.

**Independently verified**: the red-green cycle was re-run from a clean LF clone at `4eb7eaf0` on Node 22.18.0. Unpatched, `repro.js` reports 8 checks reproducing a defect; after `git apply fixes.patch` it reports all checks OK, and `npm run test-node` is 248 passing, 23 pending, 0 failing. Clone with `git -c core.autocrlf=false` or three unrelated tests redden on line endings alone.

**Status**: fixes live in this eval's artifacts; nothing was pushed upstream. Upstream disclosure pending review.
