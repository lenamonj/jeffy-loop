# Jeffy eval: nlohmann/json

The most-used JSON library in C++ at 50,489 stars, shipping the core parser
plus four binary codecs (CBOR, MessagePack, BSON, UBJSON). Run 2026-08-31
as wave 4 of the merged-PR campaign (COHORT-WAVE4.md). **1 run, 10
iterations, converged** at `3752fbae00821f837371a52e564785b833c05f6f`, in
round 1 of a **pre-registered budget of 5 rounds of 10**.

Pre-registered as the campaign's hardest target - a spec-implementation
shape (four binary formats) and the largest surface inventory in the corpus
at 29 rows, the class that defeated `BurntSushi/toml` and `eemeli/yaml`. It
converged fastest of any wave-3/4 target. The prediction was written down
before launch and is published here because it was wrong.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `35705d79d878db5ca1a282ec0f8243a80010d24e` (develop; upstream CI 72 success + 26 skipped, plus 2 failures that are a PR-comment bot job, declared before launch) |
| Findings closed | **4** - 1 High, 3 Medium |
| Shipped-code change | 8 files, **+83 / -6** |
| Surface inventory | **29 of 29 rows swept** |
| Ledger at convergence | 3 Lows carried |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | 109 CTest tests green (~200 s) |

## What the loop found

- **`J-005` (High)** - `BUILD.bazel`'s `hdrs` list omitted
  `include/nlohmann/detail/meta/logic.hpp`, which
  `include/nlohmann/detail/conversions/from_json.hpp` includes. A Bazel
  consumer compiling in a sandbox that stages only the declared headers
  cannot resolve it, so the declared build graph does not describe the real
  one.
- **`J-001` (Medium)** - `json_pointer`'s `array_index()` reported a
  non-numeric array index as `out_of_range.404` for some tokens where the
  documentation specifies `parse_error.109`, so a caller dispatching on the
  documented error code took the wrong branch.
- **`J-002` (Medium)** - the project's own CPack configuration packaged the
  entire working tree as "source", because `CPACK_SOURCE_IGNORE_FILES` was
  left at CMake's default of VCS metadata only. The eleventh packaging
  channel caught in the corpus.
- **`J-004` (Medium)** - the CBOR serialization table in `cbor.md` stated
  four negative-integer ranges the encoder does not produce.

## Environment

WSL2 x86_64, cmake + gcc, CTest. Engine 1.20.0 on Claude Code 2.1.232,
model `opus[1m]`. Oracle sabotage-proven before launch: the parser's
`literal_true` case made to emit `false` reddened **16 of 109 tests**, with
green restored on revert and a rebuild forced on both sides - the first
sabotage attempt targeted a string that did not exist in the file and was
caught by its own precondition assertion rather than being read as a pass.
Flake gate 10/10 green.

Full iteration record: [journal.md](journal.md). Complete shipped diff:
[fixes.patch](fixes.patch).
