# Jeffy eval: lz4/lz4

The reference implementation of LZ4, the fast compression format inside
kernels, databases and filesystems. Picked with its sibling zstd to give the
study its strongest anti-cheat oracle yet: `decompress(compress(x)) == x`,
bit for bit, for any `x` - an arithmetic identity the loop cannot rewrite,
graded by two seeded differential engines that generate their own test data.
**2 runs, 15 iterations, converged** at
`d6f43e05819d7f1d551926af9f5d4aec4c2b91da`, against a **pre-registered budget
of 4 runs of 10 iterations**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `dev` HEAD `0774d05537f9762f838f7ab541b7765f1a729cb5` (v1.10.0; no release tag carries surviving check-runs, so the green baseline is this exact SHA) |
| Upstream CI on the base | **66 of 66 green** |
| Findings closed | **7** - 1 High, 3 Medium, 3 Low |
| Shipped-code change | 8 files, **+188 / -115** |
| Surface inventory | **21 of 21 rows swept**, 1 row disclosed unreachable on this host |
| Ledger at convergence | **empty** - every finding worked, none carried |
| Evaluator | **1 invocation, PASS** |

## What the loop found

The High is silent data loss on the CLI's adversarial surface. **`SKIP-1`**:
a skippable frame whose header over-declares its length was stepped over
with a seek that succeeds past end of file, so `lz4 -dc` on that file
followed by a valid frame emitted nothing and exited 0, and `lz4 -t` called
the same file sound. It was the third finding sharing one root cause - a
container-declared length trusted and seeked over - so it was closed as one
structural boundary (`fseek_u32` now proves the declared region is present),
and the enumeration built by provoking each declared-length site found a
live legacy-frame site the filing had missed, one the source itself carried
a comment conceding.

The Mediums are the same class seen from `--list`: **`LIST-1`**, where a
truncated `.lz4` that `lz4 -t` rejects listed with exit 0 through three
distinct loss points, and **`LIST-2`**, where the first unreadable file in a
multi-file listing killed the whole process through four distinct exit
paths, dropping every file after it. **`DOC-1`**: `make manuals` regenerated
the frame-API manual into broken output because one comment opener keyed the
generator's chapter rule instead of its declaration rule - and the filed
acceptance check passed vacuously, because a git checkout leaves the manual
newer than its sources and the make target no-ops.

The Lows, all closed rather than carried: **`MT-1`**, the cmake build
shipped without multithreading so `-T` did nothing there (2.3x once fixed),
**`RING-1`**, the ring-buffer macro and its function disagree below block
size 16 with neither comment saying so, and **`DOC-2`**, raw doxygen markup
rendered verbatim to readers of the published frame manual.

## Declared limits

- The Verify command is the project's own quick gate (`make check` plus the
  two differential engines); nothing here claims upstream's fuller 66-leg
  matrix was run locally. The sanitizer oracle the command lacks was
  supplied separately: both engines rebuilt under ASan, UBSan and
  LeakSanitizer, zero reports.
- One inventory row is disclosed unreachable rather than swept: meson is
  not installed here, `build/VS2022` targets MSVC and `contrib/djgpp`
  targets DOS.
- The gate recorded four observations it did not raise as REJECT reasons
  (unpublished doxygen tags in two headers among them); they carry to the
  next run rather than being fixed after the PASS, because a fix after a
  PASS invalidates it.
- Graded under WSL2 Linux x86_64, run headless by `claude -p` on
  **claude-opus-5 (1M context) at xhigh effort**.

## Nothing was sent upstream

Every finding rests on probes this loop wrote - eight kept batteries, over
700 checks, each mutation-tested - and no existing test was deleted,
disabled or weakened. Run 1 ended out of budget with the map complete and
declined to converge on a stale audit; run 2 closed the three carried Lows,
ran the fresh audit the rules require, and the gate's PASS re-executed the
acceptance checks, rebuilt both battery mutants itself, and covered the one
thing the run had not: a seven-configuration cmake matrix.
