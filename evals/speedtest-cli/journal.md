# Journal

Append-only. One entry per iteration. Never rewrite past entries.

Heading grammar, exactly:
## iter <i>/<N> | <run-id> | <YYYY-MM-DD> | <task-id or AUDIT or RATCHET or WRAPUP or SALVAGE> | <done|blocked|audit|converged|rotation>

run-id is the first 8 characters of the session id. Body fields, in order: Task, Changed, Checkpoint (the jeffy checkpoint commit hash, or none with the reason), Verification, Learnings, Next.

Closed tasks are recorded here as one line each (ID, title, closing evidence), because BACKLOG.md deletes them. Rotation: when this file exceeds 500 lines, move all but the last 10 entries to JOURNAL-archive.md and record the rotation as a new entry.

## iter 1/6 | f8fdc2e2 | 2026-07-18 | AUDIT | audit

Task: Full audit of sivel/speedtest-cli at 22210ca (Improvement mode), Jeffy mini-eval in a local scratch clone; nothing is ever pushed.
Changed: PLAN.md (envelope, verify command), BACKLOG.md (M1 filed).
Checkpoint: recorded after commit.
Verification: python3 -m compileall -q speedtest.py green; flake8 7.3.0 red with 8x F821 (reproduced); python3 speedtest.py --version runs clean on 3.11.15; setup.py parses and reports 2.1.4b1 via setuptools; error path prints a clean message, no traceback. Live-network legs of the tox gate are unreachable here (proxy 403) - environment limitation, not a finding.
Learnings: Scores - Testing/CI: Medium (M1: red flake8 gate; .travis.yml targets defunct Travis - CI migration filed under Proposed). Install/DX: Medium finding, but the remedy is a compat decision (env python shebang fails on modern distros that ship no `python`; fixing it means choosing python3 over the declared 2.4-3.10 span) - filed under Proposed per severity discipline, not worked. Code quality: Low (py2 guard baggage; structural removal is the same compat decision - folded into the same Proposed item). Security: None found (no cert-disabling, no bare except at top level). Error handling: None. Docs: None material.
Next: Execute M1.

## iter 2/6 | f8fdc2e2 | 2026-07-18 | M1 | done

Task: M1 - restore the flake8 gate: declare the py2-only builtins (basestring, unicode, file) in setup.cfg [flake8] so guarded branches stop tripping F821 under modern flake8.
Changed: setup.cfg, PLAN.md (flake8 folded into the verify command).
Checkpoint: recorded after commit.
Verification: flake8 7.3.0 exits 0 on speedtest.py; zero noqa comments in the file; compileall green. Structural fix - one config line settles all 8 sites; no per-site patches.
Learnings: The gate rotted from tool drift, not code drift - the code is unchanged since 2021 and still passes its own rules once the rules are stated for modern linters.
Next: Replenishment sweep - fewer than 3 open tasks remain (zero).

## iter 3/6 | f8fdc2e2 | 2026-07-18 | AUDIT | audit

Task: Replenishment partial audit - documentation and offline CLI paths (least recently scored).
Changed: BACKLOG.md (M2 filed).
Checkpoint: recorded after commit.
Verification: --help and --csv-header run clean offline on 3.11; README.rst lines 10-12 reproduce the dead Travis shield; setup.py reads its version from source, not README, so removing the badge cannot break packaging.
Learnings: Documentation: Medium (M2). Offline CLI surface: None - argparse paths behave. The badge is fixable independently of the CI-replacement decision parked under Proposed: removing a claim is honest today; choosing new CI is the owner's call.
Next: Execute M2.

## iter 4/6 | f8fdc2e2 | 2026-07-18 | M2 | done

Task: M2 - remove the dead Travis badge block from README.rst.
Changed: README.rst (three-line badge block deleted; PyPI version and license badges kept).
Checkpoint: recorded after commit.
Verification: grep -ci travis README.rst returns 0; python3 setup.py --version runs clean - and a correction to the iter-3 entry: setup.py does read README.rst as long_description (version comes from source), so this check carries real weight; full verify gate green (compileall + flake8).
Learnings: Removing an unearned claim is the honest half of the CI story; restoring a live gate stays under Proposed as the owner's decision.
Next: Full fresh-evidence audit - backlog is empty.

## iter 5/6 | f8fdc2e2 | 2026-07-18 | AUDIT | converged

Task: Full fresh-evidence audit, convergence check.
Changed: BACKLOG.md (Converged line), JOURNAL.md.
Checkpoint: recorded after commit.
Verification: verify gate green this iteration (compileall + flake8); all offline CLI probes clean (--version, --help, --csv-header); setup.py packaging path clean; zero travis references; Now/Next/Later empty.
Learnings: Zero High, zero Medium in-envelope across every applicable dimension. Three items sit under Proposed - the Python floor, the CI replacement, and the hostile-server posture - all genuinely the owner's decisions, none blocking convergence by rule. In-envelope, this codebase is now clean: its gates run green again and its README claims nothing it does not have.
Next: none - run converged. Converged: 5f595c738da8705b3b567365b28d441bcdf2ca54.
