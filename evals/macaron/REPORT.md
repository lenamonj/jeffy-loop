# Jeffy eval: oracle/macaron

Oracle's Macaron, a supply-chain security analyzer that checks a package's
build provenance, its repository, its build tool and its dependencies
against SLSA levels. 210 stars, a Python code base with Go helpers, and an
active maintainer team that merged 22 PRs in the 120 days before the run.
Run 2026-09-06 as the Oracle target of the Meta and Oracle wave
(COHORT-META-2026-09-06.md). **4 runs, 36 iterations, converged** at
`07c4f86f7adc862f344aa825430c2b74170080d8`, within a **pre-registered budget
of 5 rounds of 10** that was later topped up to 50 iterations (see below).

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `16c6a1ecbda8b6f24563fa44de317bd0e59b7b70` (main, 2026-09-04) |
| Findings closed | **19** - 3 High, 9 Medium, 7 Low |
| Shipped-code change | 17 source files, **+156 / -106**; 16 test files, +935 / -5; plus `pyproject.toml` and `.gitignore` (6 lines of loop housekeeping, see `PKG-001`) |
| Surface inventory | **29 of 29 rows swept** |
| Ledger at convergence | 2 Lows carried (`TEST-002`, `VSA-002`) |
| Evaluator | **2 invocations: REJECT, then PASS** |
| Suite at convergence | `python -m pytest` + `go test ./golang/...`: **1285 passed** (1167 at base) |
| Upstream | [#1465](https://github.com/oracle/macaron/pull/1465) (`RVER-001`) open, [#1466](https://github.com/oracle/macaron/pull/1466) (`BSG-001`) open; `PROV-001` reported privately per the project's SECURITY.md |

## What the loop found

- **`RVER-001` (High, correctness)** - the Maven repository verifier
  indexed the third segment of a group id unconditionally, so a two-segment
  id such as `com.github`, with the repository reported on `github.com`,
  raised `IndexError` and aborted the whole analysis. It now returns the
  same namespace-mismatch result a wrong account gets, which is what the
  sibling check in the Maven Central registry already did for the same
  shape. Four new parametrized cases fail on main and pass with the fix.
  Filed as oracle/macaron #1465 after issue #1463.
- **`BSG-001` (High, correctness)** - `MavenBuildSpec.resolve_fields`
  selected the JDK version with `jdk_from_jar or existing if existing else
  "8"`, which Python parses as `(jdk_from_jar or existing) if existing else
  "8"`: whenever the database had no recorded language version, the JDK
  version just read from the Maven Central JAR was discarded and the build
  spec said Java 8. One line, now `jdk_from_jar or existing or "8"`, the
  order the comment above it describes. Filed as #1466 after issue #1464.
- **`PROV-001` (High, security)** - a finding in the provenance
  verifier's archive extraction. Oracle's SECURITY.md asks that
  vulnerabilities go to its security alert address and never to a public
  issue or pull request, so the report and its fix went there on
  2026-09-06 and the details are withheld here until the project answers.
- **Nine Mediums**, all runtime correctness or error handling: a JDK
  version table that stopped at 24 and made JDK 25 fatal (`BSG-002`); a
  build-tool heuristic reporting under an evidence name its own map did
  not hold (`BT-001`); a CycloneDX guard comparing against `None` where the
  library normalizes to an empty set (`CDX-001`); a GitHub Actions
  injection detector that recognised four attacker-controlled context
  references where the documented set is larger (`GHA-002`); a highest-tag
  search that raised on a tag set whose only valid version normalizes to
  zero (`GIT-001`); `detect_parent_pom` appending `pom.xml` to a
  `<relativePath>` that already named the file, Maven's own documented
  form (`POM-001`); `_clean_spdx` using `lstrip("git+")`, which strips a
  character set rather than a prefix (`PROV-002`); a VSA generator writing
  the literal string `null` after a swallowed database error (`VSA-001`);
  and the flit sdist carrying the loop's own state files (`PKG-001`, the
  housekeeping change above).
- **Seven Lows** closed, two carried: a test that leaves a module cache
  dirty for its neighbours (`TEST-002`) and a docstring that documents a
  return value the function does not produce (`VSA-002`).

## How the run went

Round 1 ended at iteration 7 of 10 and the map at 13 of 28 rows: engine
1.22.0's coverage projection judged the map unclearable inside the round
and ended the run early, a behaviour this wave exposed and 1.22.1 removed
the same evening (P1-72). Round 2 cleared the map. Round 3 died at
iteration 9 at 1:40 PM ET when the account's usage window closed with the
run inside its closing audit; the orphan state was cleared and the
campaign resumed at 3:31 PM with rounds added until the journal reached
50 iterations, so the shortfall the early stop caused was never charged to
the target. The final run spent seven iterations closing ledger items, ran
the closing audit, and met the gate twice: the first invocation filed
`VSA-003`, a test fixture that left a database engine undisposed and made
the suite exit 1 on two runs out of two while printing all passes; the
loop fixed it with the pattern the project's own database tests use, and
the second invocation ran the gate eight times green at 1285 and passed.

The three Highs were all found and fixed by round 2. Everything after was
the map, the Mediums and the closing sequence, which is the pattern the
hunt mode was built around.
