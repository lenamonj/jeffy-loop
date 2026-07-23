# Jeffy eval: sivel/speedtest-cli

**Target**: [sivel/speedtest-cli](https://github.com/sivel/speedtest-cli) (~13k stars) at HEAD `22210ca` (2021), Python 3.11 — run in a local clone; nothing was pushed upstream.

A deliberately contrasting case to [records](../records/REPORT.md): a dormant but fundamentally sound codebase, where the honest outcome is *small findings and restraint* — the loop must not invent problems to look busy.

**Found and fixed** (5 iterations of a budget of 6, converged):

- **M1 (Medium, testing/CI)** — the project's own lint gate was red on unchanged code: modern flake8 reports 8x F821 from runtime-guarded Python 2 branches, with no config declaring the py2-only builtins. One structural config change (`[flake8] builtins`) settled all 8 sites; zero `noqa` comments; gate green again.
- **M2 (Medium, documentation)** — README led with a Travis badge pointing at defunct travis-ci.org, advertising a CI gate that had not run in years. Removed; the packaging path that reads the README verified unaffected.

**Routed to the owner under Proposed, not seized**: the Python floor (the `#!/usr/bin/env python` shebang fails on modern distros that ship no `python`, but fixing it means dropping the declared 2.4-3.10 span), the CI replacement for dead Travis, and the hostile-server posture for parsing speedtest.net responses.

**Disclosed limitation**: the live-network legs of the project's tox gate were unreachable in the eval sandbox (proxy 403) — recorded in the journal as an environment limitation, never counted as a finding.

Full iteration-by-iteration record: [journal.md](journal.md).
