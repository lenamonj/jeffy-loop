# Jeffy eval: rs/xid

A globally unique id generator for Go - a 12-byte, k-sortable,
base32-encoded identifier with a time prefix, a machine id, a process
id and a counter, plus the `xidb` binary-column helper for SQL. Run
2026-09-01 as wave 10 of the campaign (COHORT-WAVE9.md, which covers
waves 9 and 10). **1 run, 10 iterations, converged** in round 1 at
`83f724c36c0d1b65973f1e98b635084cab310782`, within a
**pre-registered budget of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `30792e834f6f` |
| Findings closed | **6** - 5 Medium, 1 Low |
| Shipped-code change | 4 files, **+166 / -15** |
| Surface inventory | **11 of 11 reachable rows swept** |
| Ledger at convergence | 4 Lows carried |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | green through the verify gate, 4 batteries each observed red under a discriminating mutation |

## What the loop found

- **`XID-1` (Medium)** - `UnmarshalJSON` stripped the first and last
  byte of the token without checking they were quotes, so **a bare
  JSON number of 22 bytes decoded as a valid id**:
  `{"id":1234567890123456789000}` returned a nil error and the id
  23456789012345678900. The fix rejects any token that is not `null`
  or a quoted string. The acceptance check was run against the
  restored pre-fix `id.go` and failed there on two of its seven
  documents, the positive and the negative 22-byte number.
- **`XID-2` (Medium)** - the pid was xor-ed with a checksum of
  `/proc/self/cpuset` whenever that file held more than one byte, and
  the root cpuset `"/\n"` that every ordinary Linux host reads is two
  bytes, so **`ID.Pid()` bore no relation to `os.Getpid()` on an
  uncontained host**: 1185502 against 54610. The guard now tests the
  trimmed content. Container differentiation is preserved bit for bit,
  because a cpuset naming a real cgroup path still mixes the pid with
  the checksum of exactly the bytes the file yields.
- **`XID-3` (Medium)** - a panic inside the lazy machine-id resolution
  spent `machineIDOnce` and left the cache empty, so **a caller that
  recovered the first panic got "index out of range [0] with length 0"
  from every later `New()`** instead of the descriptive message.
  `getMachineID` now re-resolves when the cache is not a full machine
  id, so the real failure repeats. Reproduced by re-executing the test
  binary as a child with an unusable `XID_MACHINE_ID`.
- **`XID-4` (Medium)** - the package doc's feature list said the
  base32 form costs 16 bytes of storage as a printable string, four
  under the truth, while the same doc block and the README both say
  20, so **the godoc a reader sizes a column from was wrong**. A grep
  across Go and Markdown sources found four "16 bytes" sites, three of
  them correct statements about UUID and shortuuid, leaving exactly
  the one line this iteration changed.
- **`XID-5` (Medium)** - the Go module zip carries every file under
  the module root, so **`PLAN.md`, `BACKLOG.md`, `JOURNAL.md` and
  twenty-one paths under `.jeffy/` would reach every consumer of a
  published version**, in their module cache and in any committed
  `vendor/` tree. Fixed with a `.gitattributes` marking those paths
  `export-ignore`. Verified differentially against the real zip
  builder, `golang.org/x/mod/zip.CreateFromVCS`: the zip built from
  this repository listed the state files, the zip built from a clone
  carrying the fix listed twenty-one paths, all library or CI files.
- **`XID-8` (Low)** - `TestMachineFromEnv` set `XID_MACHINE_ID` with
  `os.Setenv` and never restored it, so **the last subtest's value
  leaked into every test that ran after it in the same binary** and an
  invalid one panicked the first id minted afterwards. `t.Setenv`
  restores it. The reproduction is statistical because the leaking
  value depends on Go map iteration order: twenty fresh processes
  running the pair in source order failed sixteen times against the
  unfixed file and zero times against the fix, and fifty shuffled
  orders against the fix failed zero times.

## Evaluator

One invocation, PASS. It re-ran the verify wrapper green, re-ran
check-claims to 4 checked and 0 mismatched, and for each of XID-1
through XID-5 reproduced the defect failing at the base tree in a
separate worktree, passing at HEAD, re-executed the filed acceptance
and read the diff for regressions. It also ran the four batteries
against the base tree and found codec and identity go red there
exactly on the defects this run fixed. The gate recorded eight
observations, all Low and none a REJECT reason, and none was fixed in
that iteration, because a fix after a PASS invalidates the PASS.

## Upstream

Nothing was filed. The run closed no High, and the bar for an upstream
PR is a genuine High with an external oracle. Four Lows are carried on
the ledger: XID-6, the receiver keeping its previous value on two of
the three `UnmarshalText` rejection paths; XID-7, `ID.Scan` reading
any twelve-byte value as raw binary without saying so in its doc
comment; XID-9, five hostid files that `gofmt` would rewrite for their
legacy build tags; and XID-10, README badges pointing at travis-ci.org
and gocover.io beside two dead CI configs.
