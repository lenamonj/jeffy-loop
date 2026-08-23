#!/usr/bin/env bash
# Jeffy repo validation: shell syntax (bash -n) for the installer and the Stop
# hook, skill frontmatter, referenced paths, governance markers in the jeffy
# skill, a de-echo guard that keeps literal promise tags out of the skill,
# sandboxed runtime runs of both installers that assert the skills land and
# the hook gets registered, and a behavioral pass over the Stop hook itself
# (re-feed, budget exhaustion, promise, foreign session). Optional passes that
# skip cleanly when their tool is absent: install.ps1 syntax and runtime
# (PowerShell), the jq-dependent hook behavior pass, and a shellcheck lint of
# the shell scripts. Core is dependency-free (bash and coreutils). Run from
# anywhere.
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root" || exit 1

fail=0
ok_n=0
skip_n=0
skipped=""
pass() { echo "[OK] $1"; ok_n=$((ok_n + 1)); }
fault() { echo "[FAIL] $1"; fail=1; }
# A skipped check is not a passed one, and the closing line has to say so.
# Skips are printed where they happen and reprinted in the summary, because a
# run that ends "All checks passed." after scrolling a skip past the reader is
# telling the truth about what it ran and the wrong thing about what it covered.
skip() { echo "[SKIP] $1"; skip_n=$((skip_n + 1)); skipped="$skipped$1
"; }

# Interrupt safety: the runtime checks (8 and 9) build mktemp sandboxes; an
# aborted run must not leak them.
rt_tmp=""; pr_tmp=""; hb_tmp=""
trap 'rm -rf ${rt_tmp:+"$rt_tmp"} ${pr_tmp:+"$pr_tmp"} ${hb_tmp:+"$hb_tmp"}' EXIT

# 1. The shell entry points parse cleanly. Parser stderr is shown on failure
#    so the [FAIL] names the offending line.
for sh_src in install.sh skills/jeffy/hooks/stop-hook.sh; do
  if bash_err="$(bash -n "$sh_src" 2>&1)"; then
    pass "$sh_src parses (bash -n)"
  else
    echo "$bash_err"
    fault "$sh_src has a syntax error (bash -n)"
  fi
done

# 1b. The executable entry points ship with their exec bit committed. Windows
#     working trees hide mode bits (core.fileMode=false), so this reads the git
#     index, not the filesystem: 100644 here means every Linux and Mac clone
#     fails the README's ./install.sh with Permission denied. Skips cleanly
#     outside a git checkout (release tarballs).
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  for exec_src in install.sh scripts/validate.sh skills/jeffy/hooks/stop-hook.sh; do
    mode="$(git ls-files -s "$exec_src" 2>/dev/null | awk '{print $1}')"
    if [ "$mode" = "100755" ]; then
      pass "$exec_src carries the exec bit in the git index (100755)"
    elif [ -z "$mode" ]; then
      fault "$exec_src is not in the git index"
    else
      fault "$exec_src committed without exec bit ($mode): ./install.sh breaks on Linux and Mac"
    fi
  done
else
  skip "exec-bit checks (not a git checkout)"
fi

# 2. Every skill carries name: and description: frontmatter.
for skill in skills/*/SKILL.md; do
  if [ ! -f "$skill" ]; then
    fault "expected skill file missing: $skill"
    continue
  fi
  if grep -qE '^name:[[:space:]]*[^[:space:]]' "$skill" \
     && grep -qE '^description:[[:space:]]*[^[:space:]]' "$skill"; then
    pass "$skill has name and description frontmatter"
  else
    fault "$skill is missing name: or description: frontmatter"
  fi
done

# 3. Skill paths the README, installers, and SKILL.md reference must exist.
for required in skills/jeffy/SKILL.md skills/cancel-jeffy/SKILL.md \
  skills/jeffy/references/plan-default.md \
  skills/jeffy/references/backlog-default.md \
  skills/jeffy/references/journal-default.md \
  skills/jeffy/references/iteration-prompt.txt \
  skills/jeffy/hooks/stop-hook.sh; do
  if [ -f "$required" ]; then
    pass "referenced path exists: $required"
  else
    fault "referenced path missing: $required"
  fi
done

# 4. install.ps1 parses, when a PowerShell interpreter is available. Optional:
#    hosts without pwsh/powershell (most Linux CI) skip this cleanly, so the
#    check stays dependency-free.
ps=""
# JEFFY_PS pins the interpreter (CI uses it to force Windows PowerShell 5.1
# coverage on the windows runner, where pwsh would otherwise win detection).
# The pin fails closed: a JEFFY_PS naming a missing interpreter is a fault,
# not a silent fallback, so the CI job cannot go green without its coverage.
if [ -n "${JEFFY_PS:-}" ]; then
  if command -v "$JEFFY_PS" >/dev/null 2>&1; then
    ps="$JEFFY_PS"
  else
    fault "JEFFY_PS=$JEFFY_PS requested but not found on PATH (pin fails closed)"
  fi
elif command -v pwsh >/dev/null 2>&1; then
  ps=pwsh
elif command -v powershell >/dev/null 2>&1; then
  ps=powershell
fi
if [ -n "$ps" ]; then
  ps1_path="$repo_root/install.ps1"
  command -v cygpath >/dev/null 2>&1 && ps1_path="$(cygpath -w "$repo_root/install.ps1")"
  export JEFFY_PS1_PATH="$ps1_path"
  # Single quotes are intentional: this is PowerShell source, not shell, and must not expand.
  # shellcheck disable=SC2016
  ps_parse='$e=$null; $null=[System.Management.Automation.Language.Parser]::ParseFile($env:JEFFY_PS1_PATH,[ref]$null,[ref]$e); if ($e -and $e.Count -gt 0) { $e | ForEach-Object { [Console]::Error.WriteLine($_.Message) }; exit 1 }; exit 0'
  if ps_err="$("$ps" -NoProfile -NonInteractive -Command "$ps_parse" 2>&1)"; then
    pass "install.ps1 parses ($ps)"
  else
    [ -n "$ps_err" ] && echo "$ps_err"
    fault "install.ps1 has a syntax error ($ps)"
  fi
  unset JEFFY_PS1_PATH
else
  skip "install.ps1 parse check (no pwsh or powershell on PATH)"
fi

# 5. shellcheck lint of the shell scripts, when shellcheck is available. Optional
#    for a contributor: a clone without shellcheck skips cleanly, and bash -n
#    (check 1) is parse-only, so it misses what shellcheck catches (unquoted
#    expansions, unreachable code). Not optional in the maintainer tree, which
#    is where releases are cut: this lint rides the Linux CI leg, so a skip here
#    means the first machine to run it is a machine the push has already reached.
#    That has shipped a shellcheck-only breakage twice. CHANGELOG.md marks the
#    maintainer tree, the same predicate the pairing and count checks use.
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -x install.sh scripts/validate.sh skills/jeffy/hooks/stop-hook.sh skills/jeffy/hooks/lib/quiet-verify.sh; then
    pass "shell scripts lint clean (shellcheck)"
  else
    fault "shellcheck reported issues (see output above)"
  fi
elif [ -f CHANGELOG.md ]; then
  fault "shellcheck is not on PATH, and this is the maintainer tree releases are cut from - a skip here is a lint that first runs in CI, after the push"
else
  skip "shellcheck lint (shellcheck not on PATH)"
fi

# 6. The jeffy skill's convergence-governance blocks survive edits: every
#    marker below must appear in the skill file that now carries that block
#    (the templates and iteration prompt live under skills/jeffy/references).
#    Guards the operating envelope, settled-classes ledger, ratchet,
#    checkpoint, verify gate, promise discipline, and the rest of the prompt
#    discipline against a silent regression in a future edit. The hook and
#    SKILL.md carry lists of their own, for the strings the reference text
#    teaches the model to read and the launcher check nothing else asserts.
#    Dependency-free (grep).
gm_missing=0
check_markers() {
  local file="$1"
  shift
  for marker in "$@"; do
    if ! grep -qF -- "$marker" "$file"; then
      fault "governance marker missing from $file: $marker"
      gm_missing=1
    fi
  done
}
check_markers skills/jeffy/references/plan-default.md \
  "## Operating envelope" \
  "then unswept or stale Surface inventory rows, then open Medium" \
  "never the mapping of unswept surface" \
  "in-envelope" \
  "Convergence ratchet:" \
  "(repoints <old hash>, tree unchanged)" \
  "must be reachable from HEAD" \
  "Three-strike rule:" \
  "one structural task" \
  "## Verify command" \
  "Command: " \
  "Oracle class: " \
  "Environment fingerprint: " \
  "bare assertion that nothing is excluded" \
  "## Lessons" \
  "leaves no High and no Medium behind" \
  "run report" \
  "adversarial evaluator gate" \
  "the only sub-agent review this Method authorizes" \
  "strong enough to fail" \
  "stops auditing for the rest of the run" \
  "a reduction is new code" \
  "## Surface inventory" \
  "silence, not cleanliness" \
  "lists no unswept row" \
  "a correctness check, not a liveness check" \
  "a comparable amount of surface" \
  "including underscore-private modules" \
  "every documented parameter" \
  "- [~] <surface>: unreachable on this host" \
  "cost: exceeds one iteration" \
  ".jeffy/probes/" \
  "scope line names the enumeration command" \
  "recording its second occurrence is marked" \
  "re-invoked at the declaration" \
  "files its findings and the run continues" \
  "gate findings closed, declaration deferred" \
  "it enters gate salvage" \
  ".jeffy/evaluator/<run-id>-<n>.md" \
  "reads the highest ordinal on record" \
  "committed and unmodified" \
  "and ends blocked" \
  "one convergence shape is legal and only one" \
  "a fix after a PASS invalidates the PASS" \
  "(<Severity>, <class>, <dimension>)" \
  "one glob per line" \
  "run at least one test module in isolation" \
  "provoking a failure at every step" \
  "re-executes the claims it invalidates" \
  "write a line number into a state file"
check_markers skills/jeffy/references/backlog-default.md \
  "## Proposed" \
  "unswept Surface inventory rows above every open Low" \
  "## Settled classes" \
  "## Converged" \
  "(repoints <old hash>, tree unchanged)" \
  "reachable from HEAD" \
  "(<Severity>, <class>, <dimension>)"
# Rotation must append. "Move all but the last 10 entries to JOURNAL-archive.md"
# reads as "write the archive" to a model that has never seen one, and the
# second rotation of a long run then destroys everything the first preserved -
# observed on bukosabino/ta, where 18 entries went and nothing noticed, because
# the live journal looks healthy afterwards.
check_markers skills/jeffy/references/journal-default.md \
  "Append-only." \
  "never overwriting it" \
  "so two runs in one session are told apart" \
  "or AUDIT or SWEEP or EVALUATOR or RATCHET"
check_markers skills/jeffy/references/iteration-prompt.txt \
  "Salvage first:" \
  "ignoring any path under .jeffy/metrics/, which the Stop hook writes after every checkpoint" \
  "To declare convergence, and only then, output the run report" \
  "the promise is the declaration and never the way a turn or a run ends" \
  "then unswept or stale Surface inventory rows, then open Medium" \
  "never the mapping of unswept surface" \
  "Ratchet next:" \
  "(repoints <old hash>, tree unchanged)" \
  "A Converged line is never edited" \
  "Verify gate:" \
  "Severity discipline:" \
  "Backlog discipline:" \
  "Stall check:" \
  "the harness-written .claude/jeffy-loop.local.md and .claude/settings.local.json, and no BACKLOG.md item changed state" \
  "no Surface inventory row changed state" \
  "QUIET-VERIFY-ONLY" \
  "added, removed, edited, or moved between sections" \
  "for at most three consecutive iterations" \
  "Checkpoint:" \
  "Lessons:" \
  "Run report:" \
  "lists each carried Low by ID" \
  "wrapped in promise XML tags" \
  "Evaluator gate:" \
  "Evaluator: PASS" \
  "at most 2 evaluator invocations per run" \
  "files its findings and the run continues" \
  "blocked - N gate findings closed, declaration deferred" \
  "it enters gate salvage" \
  "never overwriting it" \
  "so two runs in one session are told apart" \
  "Closeout:" \
  "Surface inventory" \
  "Change discipline:" \
  "rows swept of rows total" \
  "never only run-without-crash probes" \
  "newly exposed rather than introduced" \
  "whose value changes nothing" \
  "Oracle class names what the command actually grades" \
  "bare assertion that nothing is excluded" \
  "Run the gate while its verdict can still be answered:" \
  "One transaction closes the run:" \
  "copy the fixed files aside" \
  "or a test run through head or tail" \
  "or AUDIT or SWEEP or EVALUATOR or RATCHET" \
  ".jeffy/probes/" \
  "never run an audit inside it" \
  "One convergence shape is legal inside the window and only one" \
  "write the artifact .jeffy/evaluator/<run-id>-<n>.md" \
  "where n is the invocation ordinal you were told" \
  "reads the highest invocation ordinal on record" \
  "opening with one line naming that run-id, that ordinal, and the iteration i of N that invoked you" \
  "never fixed inside the convergence sequence" \
  "the combination is for when the budget forces it" \
  "end the run under the hard blocker rule and never declare" \
  "Battery ownership:" \
  "provoking a failure at every step" \
  "re-executes the claims it invalidates" \
  "write a line number into a state file"
# The hook's two named notes. The model is taught to read both by name - the
# run-state arithmetic on every re-feed, the one-time closing extension at the
# budget boundary - so the names are an interface, not internal wording, and
# Phase 2 shipped them pinned by nothing but the behavior fixtures that write
# them.
check_markers skills/jeffy/hooks/stop-hook.sh \
  "added, removed, edited, or moved between sections" \
  "RUN STATE" \
  "CLOSING EXTENSION" \
  "CORRECTIVE" \
  "JEFFY_VERSION" \
  "refilled inside the closing extension"
# The launch-time lint is the whole malformed-Verify-command class caught at
# zero iteration cost: the hook's parser runs only on the convergence branch,
# so without this check a line written at launch waits a whole run to fire.
# Its placeholder exemption is pinned too: the bootstrapped PLAN.md ships
# `Command: <first audit fills this in>`, which no sanitation makes parse, so
# a lint that reads the template's own line as a defect hard-stops every
# relaunch whose first iteration was interrupted before the audit filled it.
# Single quotes on the base_head marker are intentional: it pins a literal
# command-substitution line in the launch heredoc and must not expand here.
# shellcheck disable=SC2016
check_markers skills/jeffy/SKILL.md \
  "Verify command lint:" \
  "nor an unfilled \`<...>\` placeholder" \
  "a pager or truncator" \
  "core.autocrlf false" \
  "show-toplevel" \
  "Nested Jeffy project:" \
  "mode \`120000\`" \
  "Mode guard:" \
  "Enhance mode was removed in v1.11.0" \
  'base_head: $(git -C ' \
  "the Stop hook uses it to tell a genuine convergence ratchet"
if [ "$gm_missing" -eq 0 ]; then
  pass "jeffy skill files carry all governance markers"
fi

# H2. quiet-verify: the loop's verify gate is bounded, and the bound is shared.
#     A green suite prints its whole passing output into the window every
#     iteration - the engine's own validator is 226 lines of OK - in a session
#     where context already accumulates. The wrapper makes success silent and
#     failure bounded. Two things this checks beyond the contract itself: that
#     silence did not delete the verify count journals and receipts quote (the
#     summary passthrough), and that the hook and the wrapper resolve the
#     timeout through ONE function, because a second copy of that ladder would
#     drift from the bound the converged stop enforces. (P1-50)
qv_sh=skills/jeffy/hooks/lib/quiet-verify.sh
if [ ! -f "$qv_sh" ]; then
  fault "the verify wrapper $qv_sh is missing; the iteration prompt sends every verify through it"
elif ! bash -n "$qv_sh" 2>/dev/null; then
  fault "the verify wrapper does not parse"
else
  qv_tmp="$(mktemp -d)"
  qv_plan="$qv_tmp/PLAN.md"
  qv_bad=0
  # The wrapper reads its labelled lines from the ## Verify command section
  # only, as the hook does (P1-59), so every case writes the heading first.
  qv_case() { { printf '## Verify command\n'; printf '%s\n' "$@"; } > "$qv_plan"; }

  qv_case 'Command: true' 'Oracle class: deterministic'
  qv_out="$(bash "$qv_sh" "$qv_plan" "$qv_tmp" 2>"$qv_tmp/err")"
  qv_rc=$?
  if [ -n "$qv_out" ] || [ "$qv_rc" -ne 0 ] || ! grep -q '^verify: green (' "$qv_tmp/err"; then
    qv_bad=1; echo "  green: stdout=[$qv_out] rc=$qv_rc err=[$(cat "$qv_tmp/err")]"
  fi

  qv_case 'Command: bash -c "seq 1 5000; exit 1"' 'Oracle class: deterministic'
  bash "$qv_sh" "$qv_plan" "$qv_tmp" >"$qv_tmp/out" 2>"$qv_tmp/err"
  qv_rc=$?
  qv_lines="$(wc -l < "$qv_tmp/err" | tr -d ' ')"
  if [ "$qv_rc" -eq 0 ] || [ -s "$qv_tmp/out" ] || [ "$qv_lines" -gt 85 ]; then
    qv_bad=1; echo "  red: rc=$qv_rc stdout_bytes=$(wc -c < "$qv_tmp/out") err_lines=$qv_lines"
  fi

  qv_case 'Command: bash -c "seq 1 5000; exit 1"' 'Oracle class: deterministic' 'Verify output budget: 10'
  bash "$qv_sh" "$qv_plan" "$qv_tmp" 2>"$qv_tmp/err" >/dev/null
  qv_lines="$(wc -l < "$qv_tmp/err" | tr -d ' ')"
  if [ "$qv_lines" -gt 15 ]; then
    qv_bad=1; echo "  budget ignored: err_lines=$qv_lines against a budget of 10"
  fi

  # The passthrough is not a nicety: without it the journal grammar loses a
  # field the published corpus already uses.
  qv_case 'Command: bash -c "echo 226 OK, 0 FAIL"' 'Oracle class: deterministic' 'Verify summary pattern: [0-9]+ OK'
  bash "$qv_sh" "$qv_plan" "$qv_tmp" 2>"$qv_tmp/err" >/dev/null
  if ! grep -q '226 OK' "$qv_tmp/err"; then
    qv_bad=1; echo "  summary not surfaced on green: [$(cat "$qv_tmp/err")]"
  fi

  qv_case 'Command: true' 'Environment fingerprint: linux'
  if bash "$qv_sh" "$qv_plan" "$qv_tmp" >/dev/null 2>"$qv_tmp/err"; then
    qv_bad=1; echo "  half-migrated PLAN.md accepted with no Oracle class"
  elif ! grep -q 'oracle class not declared' "$qv_tmp/err"; then
    qv_bad=1; echo "  oracle refusal did not name itself: [$(cat "$qv_tmp/err")]"
  fi

  # Never stricter than the converged stop: a PLAN.md carrying neither line
  # predates the rule and still runs, with a note.
  qv_case 'Command: true'
  if ! bash "$qv_sh" "$qv_plan" "$qv_tmp" >/dev/null 2>"$qv_tmp/err"; then
    qv_bad=1; echo "  pre-1.8.0 PLAN.md refused, which is stricter than the converged stop"
  fi

  # A fresh project still carrying the template placeholder: executing it
  # yields a shell syntax error, which this wrapper would otherwise report as
  # a failed suite - reading exactly like the project being broken, the one
  # thing it must never say when it is not true.
  qv_case 'Command: <first audit fills this in>' 'Oracle class: deterministic'
  if bash "$qv_sh" "$qv_plan" "$qv_tmp" >/dev/null 2>"$qv_tmp/err"; then
    qv_bad=1; echo "  template placeholder was executed as a command"
  elif ! grep -q 'template placeholder' "$qv_tmp/err"; then
    qv_bad=1; echo "  placeholder refusal did not name itself: [$(cat "$qv_tmp/err")]"
  fi

  qv_case 'Command: none' 'Oracle class: deterministic'
  if ! bash "$qv_sh" "$qv_plan" "$qv_tmp" >/dev/null 2>"$qv_tmp/err" ||
    ! grep -q 'not configured' "$qv_tmp/err"; then
    qv_bad=1; echo "  Command: none no longer fails open"
  fi

  rm -rf "$qv_tmp"
  if [ "$qv_bad" -eq 0 ]; then
    pass "quiet-verify is silent on green, bounded on red, honours its budget, surfaces the summary, and refuses an undeclared oracle"
  else
    fault "quiet-verify does not meet its contract (see the lines above)"
  fi
fi

# One ladder, two callers. The hook must resolve its converged-stop bound
# through the lib rather than carrying a second copy: two bounds that can
# drift is the defect this extraction exists to prevent, and it is the same
# lesson P1-19 taught about two definitions of one signal.
if grep -q 'jeffy_verify_bound' skills/jeffy/hooks/stop-hook.sh &&
  grep -q 'jeffy_verify_run' skills/jeffy/hooks/stop-hook.sh &&
  grep -q 'jeffy_verify_bound()' skills/jeffy/hooks/lib/quiet-verify.sh &&
  grep -q 'jeffy_verify_run()' skills/jeffy/hooks/lib/quiet-verify.sh &&
  ! grep -q 'elif command -v gtimeout' skills/jeffy/hooks/stop-hook.sh; then
  pass "the verify bound and runner are defined once in the lib and called by the hook (no forked timeout ladder)"
else
  fault "stop-hook.sh does not share the verify bound with the wrapper; two timeout ladders will drift"
fi

# K3. Blast-radius honesty. The loop runs unattended with permissions
#     relaxed, so the sandbox is the only boundary left and the operator
#     deserves one sentence about it - stated, never enforced. The detector
#     must answer with exactly one of three words and must never error: a
#     probe that dies at launch would take the run with it. (P2-22)
k3_sh=skills/jeffy/hooks/lib/detect-sandbox.sh
if [ ! -f "$k3_sh" ]; then
  fault "the sandbox detector $k3_sh is missing; the launch banner cannot state the blast radius"
else
  k3_plain="$(bash "$k3_sh" 2>/dev/null)"
  k3_declared="$(JEFFY_SANDBOXED=1 bash "$k3_sh" 2>/dev/null)"
  k3_bad=""
  case "$k3_plain" in yes|no|unknown) ;; *) k3_bad="plain run answered [$k3_plain]" ;; esac
  [ "$k3_declared" = "yes" ] || k3_bad="$k3_bad; JEFFY_SANDBOXED=1 answered [$k3_declared]"
  grep -q "^## Blast radius" SECURITY.md || k3_bad="$k3_bad; SECURITY.md carries no blast-radius section"
  if [ -z "$k3_bad" ]; then
    pass "the sandbox detector answers one of three words, honours an explicit declaration, and SECURITY.md states the blast radius"
  else
    fault "blast-radius honesty is broken:$k3_bad"
  fi
fi

# I. The product states its version, and it cannot drift from the release
#    record: the hook's JEFFY_VERSION must equal the newest release heading
#    in CHANGELOG.md. Both are bumped in the same release commit.
#
#    CHANGELOG.md is a maintainer file and is not published (see .gitignore),
#    so a clone of this repository does not carry one. The pairing is enforced
#    where the release is actually cut - the maintainer's tree - and skipped
#    elsewhere; faulting on its absence would make every CI leg red on a file
#    the repository is designed never to ship.
#    Every JEFFY_VERSION line, not the first: a second one stating a different
#    version is the drift this pairing exists to catch, and reading one with
#    head -n 1 would compare the CHANGELOG against whichever came first. The
#    CHANGELOG read below is head -n 1 on purpose and stays that way - the
#    newest release is the topmost heading, so first is the claim. (M1)
hook_ver="$(sed -n 's/^JEFFY_VERSION="\([0-9][0-9.]*\)"$/\1/p' skills/jeffy/hooks/stop-hook.sh \
  | sort -u | tr '\n' ' ' | sed 's/ $//')"
if [ -z "$hook_ver" ]; then
  fault "stop-hook.sh carries no JEFFY_VERSION=\"x.y.z\" line"
elif [ "${hook_ver#* }" != "$hook_ver" ]; then
  fault "stop-hook.sh states more than one JEFFY_VERSION [$hook_ver]; no single version is shipped"
elif [ ! -f CHANGELOG.md ]; then
  skip "JEFFY_VERSION/CHANGELOG pairing (no CHANGELOG.md; maintainer-only file)"
else
  cl_ver="$(sed -n 's/^## \[\([0-9][0-9.]*\)\].*/\1/p' CHANGELOG.md | head -n 1)"
  if [ "$hook_ver" = "$cl_ver" ]; then
    pass "JEFFY_VERSION $hook_ver matches the newest CHANGELOG release heading"
  else
    fault "JEFFY_VERSION $hook_ver does not match the newest CHANGELOG release [$cl_ver]; bump them together"
  fi
fi

# J. Counts the README states are derived, never transcribed - the class
#    that produced three drift incidents in one day across two codebases.
#    Source of truth is the eval table: one row per evals/*/REPORT.md, a
#    numeric Iters cell marks the row converged, the Language column feeds
#    the distinct count. A row whose Iters cell is neither a number nor an
#    italic status is unclassifiable and faults rather than being dropped
#    from the tally in silence - that silence is what the old **converged**
#    grep allowed, where a typo'd marker just stopped counting.
#    On failure, remember the surfaces grep cannot see: the GitHub About
#    text, release bodies, and any live article state the same numbers.
receipts=0
for receipt in evals/*/REPORT.md; do
  # An unmatched glob arrives as the literal pattern, so the -f test is what
  # makes an empty evals/ count zero rather than one.
  if [ -f "$receipt" ]; then receipts=$((receipts + 1)); fi
done
tbl_rows="$(grep -c '^| \[.*(evals/.*/REPORT\.md)' README.md)"
tbl_conv="$(awk -F'|' '/^\| \[.*\(evals\/.*\/REPORT\.md\)/ { i=$5; gsub(/[ \t]/, "", i); if (i ~ /^[0-9]+$/) c++ } END { print c+0 }' README.md)"
tbl_langs="$(awk -F'|' '/^\| \[.*\(evals\/.*\/REPORT\.md\)/ { i=$5; gsub(/[ \t]/, "", i); if (i ~ /^[0-9]+$/) { gsub(/^[ \t]+|[ \t]+$/, "", $4); print $4 } }' README.md | sort -u | wc -l | tr -d ' ')"
tbl_odd="$(awk -F'|' '/^\| \[.*\(evals\/.*\/REPORT\.md\)/ { i=$5; gsub(/^[ \t]+|[ \t]+$/, "", i); if (i !~ /^[0-9]+$/ && i !~ /^\*[a-z]+\*$/) print $2 }' README.md | wc -l | tr -d ' ')"
# Every marker of each kind, not the first: a second one is free to state a
# different number, and the count:converged pair in this file is exactly that
# shape. Reading them all means the message names the defect rather than
# blaming the eval table for a number the README disagrees with itself
# about. (M1)
# Extracted with grep -o rather than a sed carrying a leading .*, because that
# .* is greedy and runs to the last match on a line, so the sed yielded one
# value per line where the claim is one per site. README.md already ships two
# count:converged markers on a single line, and rewriting the first of that
# pair was reproduced leaving this check green. Every extractor of a repeatable
# site in this file reads with grep -o for that reason. (G1)
claim_conv="$(grep -o '<!-- count:converged -->[0-9][0-9]*<!-- /count -->' README.md \
  | tr -dc '0-9\n' | grep -v '^$' | sort -u | tr '\n' ' ' | sed 's/ $//')"
claim_langs="$(grep -o '<!-- count:languages -->[0-9][0-9]*<!-- /count -->' README.md \
  | tr -dc '0-9\n' | grep -v '^$' | sort -u | tr '\n' ' ' | sed 's/ $//')"
if [ "$tbl_rows" != "$receipts" ]; then
  fault "README eval table has $tbl_rows rows but evals/ holds $receipts REPORT.md receipts; a new eval landed without its row (and the About text and live articles need the same edit)"
elif [ "$tbl_odd" != "0" ]; then
  fault "README eval table has $tbl_odd row(s) whose Iters cell is neither an iteration count nor an italic status; such a row is silently absent from every derived count"
elif [ -z "$claim_conv" ] || [ -z "$claim_langs" ]; then
  fault "README prose counts are not marker-anchored (<!-- count:converged --> / <!-- count:languages -->); an unanchored count is an untracked claim"
elif [ "${claim_conv#* }" != "$claim_conv" ] || [ "${claim_langs#* }" != "$claim_langs" ]; then
  fault "README's own count markers disagree (converged [$claim_conv], languages [$claim_langs]); no single number is published for a check to derive"
elif [ "$claim_conv" != "$tbl_conv" ]; then
  fault "README claims $claim_conv converged but the eval table shows $tbl_conv (and the About text and live articles need the same edit)"
elif [ "$claim_langs" != "$tbl_langs" ]; then
  fault "README claims $claim_langs languages but the converged rows span $tbl_langs"
else
  pass "README counts are derived from the eval table ($tbl_conv converged of $receipts, $tbl_langs languages)"
fi

# L/M. Enumerations the product text asserts about the engine's own behaviour,
#      derived from the engine rather than transcribed beside it. Check J
#      covers the two totals README.md publishes; these two cover the other
#      half of that class - a sentence that lists what the hook does,
#      which drifts the moment the hook grows a case and the prose does not.
#      Both are stated in more than one document, so both compare every
#      document that states them: SECURITY.md understated the truncator set
#      for a release while skills/jeffy/SKILL.md had it right, and a check
#      reading one file would have called that green.
#      PLAN.md's "Derived and settled claims" section carries the enumeration
#      of every such site and says of each one which check derives it or why
#      none does; add to that list rather than assuming this pair is all of
#      them.
# The timeout ladder moved into the shared lib in 1.13.0 (P1-50) so the
# hook and the loop-facing wrapper cannot drift. This check follows it:
# it derives the chain from wherever the assignments really are.
lm_hook="skills/jeffy/hooks/stop-hook.sh"
# The timeout ladder moved into the shared lib in 1.13.0 (P1-50) so the hook
# and the loop-facing wrapper cannot drift apart, while the truncator arm
# above still lives in the hook. Two derivations, two sources: pointing one
# variable at both is what blinded this pair during that extraction.
lm_to_src="skills/jeffy/hooks/lib/quiet-verify.sh"

# L. The refused pager/truncator set, from the case arm that sets vc_lint.
#    The extractor accounts for every alternative in that arm rather than
#    keeping the ones it recognises. A whitelist that drops what it does not
#    match is silently agreed with by product text that also omits it: add a
#    sixth truncator in a shape this pattern misses and the derived set, the
#    documents and this check all stay consistent with each other while the
#    engine refuses something none of them mention. The arm legitimately
#    carries two shapes, a bare token and that token's argument form, so the
#    rule is a partition: every alternative is one or the other, every
#    argument form has its bare token beside it, and anything left over is
#    reported with a leading ! and faults. (L1)
lm_trunc_raw="$(awk '
  /^[ \t]*[a-z|\\ *]+\)$/ && !seen {
    line = $0
    if (line ~ /head/ && line ~ /tail/) {
      gsub(/[ \t]/, "", line); sub(/\)$/, "", line)
      n = split(line, a, "|")
      for (i = 1; i <= n; i++) {
        if (a[i] ~ /^[a-z]+$/) { print a[i]; tok[a[i]] = 1 }
        else if (a[i] ~ /^[a-z]+\\\*$/) { b = a[i]; sub(/\\\*$/, "", b); argf[b] = 1 }
        else print "!" a[i]
      }
      seen = 1
    }
  }
  END { for (b in argf) if (!(b in tok)) print "!" b " (argument form with no bare token)" }
' "$lm_hook")"
lm_trunc_left="$(printf '%s\n' "$lm_trunc_raw" | grep '^!' | sed 's/^!//' | tr '\n' ' ')"
lm_trunc="$(printf '%s\n' "$lm_trunc_raw" | grep -v '^!' | grep -v '^$' | sort -u | tr '\n' ' ')"
#    Every site in each document is compared, never the first. Reading one with
#    head -n 1 left a second and contradicting sentence in the same file
#    unexamined: appending "refuses a final pager or truncator stage - `head` or
#    `tail` - and nothing else" to SECURITY.md was reproduced passing this check
#    green. The comparison here is deliberately a set - the hook's case arm
#    lists alternatives, and no order among them is claimed - which is the one
#    difference from check M below, where the claim is a sequence. (M1)
lm_trunc_bad=""
for lm_f in SECURITY.md skills/jeffy/SKILL.md; do
  lm_seen=0
  lm_sites="$(grep -o 'pager or truncator[^.]*' "$lm_f")"
  while IFS= read -r lm_site; do
    [ -n "$lm_site" ] || continue
    lm_seen=$((lm_seen + 1))
    # shellcheck disable=SC2016
    lm_got="$(printf '%s\n' "$lm_site" | grep -o '`[a-z]*`' | tr -d '`' | sort -u | tr '\n' ' ')"
    [ "$lm_got" = "$lm_trunc" ] || lm_trunc_bad="$lm_trunc_bad ${lm_f}#${lm_seen}[${lm_got}]"
  done < <(printf '%s\n' "$lm_sites")
  if [ "$lm_seen" -eq 0 ]; then
    lm_trunc_bad="$lm_trunc_bad $lm_f(states no 'pager or truncator' enumeration)"
  fi
done
if [ -z "$lm_trunc" ]; then
  fault "the hook's refused-truncator case arm could not be enumerated; the arm moved and this check went blind"
elif [ -n "$lm_trunc_left" ]; then
  fault "the hook's refused-truncator case arm carries an alternative this check cannot classify [$lm_trunc_left]; it would be dropped from the derived set and no document would be asked to state it"
elif [ -n "$lm_trunc_bad" ]; then
  fault "the hook refuses [$lm_trunc] but the product text disagrees:$lm_trunc_bad"
else
  pass "the refused pager/truncator set is derived from the hook in every document that states it ($lm_trunc)"
fi

# M. The verify-timeout fallback chain, from the vto assignments the hook
#    tries before it falls back to its own shell watchdog. The watchdog is not
#    a binary and carries no backticks, so it is not part of the derived set;
#    the anchor "a shell watchdog" is what locates the sentence in each file.
#    Same account-for-everything rule as check L, for the same reason: a
#    fourth candidate written in a shape this sed misses - quoted, or carrying
#    an argument - would leave the derived set silently, and the documents
#    that omit it would go on agreeing with a check that never saw it. So the
#    assignments are counted as well as extracted. The empty initialiser is
#    not a candidate and is excluded by name, never by falling through the
#    pattern, because falling through is the defect. (L1)
#    Order is the claim here, so order is what is compared. Both sides were
#    sorted, which made the sequence unobservable: reversing the chain in
#    README.md and SECURITY.md, so each named gtimeout before timeout where the
#    hook resolves timeout first, was reproduced passing this check green while
#    its own pass message printed the set alphabetically and called it a chain.
#    The dedupe is order-preserving for that reason, and every site in each
#    document is compared rather than the first. (M1)
lm_to="$(sed -n 's/^[ \t]*vto=\([a-z][a-z]*\)$/\1/p' "$lm_to_src" | awk '!seen[$0]++' | tr '\n' ' ')"
lm_to_cand="$(grep -c '^[ \t]*vto=' "$lm_to_src")"
lm_to_init="$(grep -c '^[ \t]*vto=""$' "$lm_to_src")"
lm_to_kept="$(sed -n 's/^[ \t]*vto=\([a-z][a-z]*\)$/\1/p' "$lm_to_src" | wc -l | tr -d '[:space:]')"
lm_to_want=$((lm_to_cand - lm_to_init))
lm_to_bad=""
for lm_f in README.md SECURITY.md; do
  lm_seen=0
  # The site list is hoisted so the SC2016 directive attaches to an assignment
  # rather than to a loop terminator, and it is replayed with printf rather
  # than a heredoc: these sites carry backticks, which an expanding heredoc
  # would run as command substitution. (M1)
  # shellcheck disable=SC2016
  lm_sites="$(grep -oE '(`[a-z]+`[,;]?( +[a-z]+)? +){1,4}a shell watchdog' "$lm_f")"
  while IFS= read -r lm_site; do
    [ -n "$lm_site" ] || continue
    lm_seen=$((lm_seen + 1))
    # shellcheck disable=SC2016
    lm_got="$(printf '%s\n' "$lm_site" | grep -o '`[a-z]*`' | tr -d '`' | awk '!seen[$0]++' | tr '\n' ' ')"
    [ "$lm_got" = "$lm_to" ] || lm_to_bad="$lm_to_bad ${lm_f}#${lm_seen}[${lm_got}]"
  done < <(printf '%s\n' "$lm_sites")
  if [ "$lm_seen" -eq 0 ]; then
    lm_to_bad="$lm_to_bad $lm_f(states no fallback chain before its shell watchdog)"
  fi
done
if [ -z "$lm_to" ]; then
  fault "the hook's timeout fallback chain could not be enumerated; the vto assignments moved and this check went blind"
elif [ "$lm_to_kept" -ne "$lm_to_want" ]; then
  fault "the hook carries $lm_to_want vto assignments beyond the empty initialiser but this check extracted $lm_to_kept; one is written in a shape the pattern misses and would leave the derived set unnoticed"
elif [ -n "$lm_to_bad" ]; then
  fault "the hook resolves [$lm_to] before its shell watchdog but the product text disagrees:$lm_to_bad"
else
  pass "the verify-timeout fallback chain is derived from the hook in every document that states it ($lm_to then a shell watchdog)"
fi

# O. The evaluator artifact is required committed and unmodified, so its
#    hygiene cannot be repaired after the fact - a redaction would break the
#    very property the Stop hook checks. The rule therefore lands at write
#    time, in plan-default.md, and this check enforces what actually ships.
#    The artifact's audience is a clone. A path only the authoring machine can
#    resolve - a drive letter, a home directory, a Windows profile directory -
#    is not evidence to anyone else, and it republishes the operator's local
#    layout into a public tree. The drive-letter arm is anchored on a
#    non-letter because an unanchored [A-Za-z]:[/\] matches every https://
#    URL, which is the first thing an artifact full of command output contains.
#    Only tracked artifacts are in scope: an untracked one has not been
#    published, and a project that has never converged has none to check.
o_files="$(git ls-files '.jeffy/evaluator/*.md' 2>/dev/null)"
if [ -z "$o_files" ]; then
  pass "no tracked evaluator artifact to check for machine-absolute paths"
else
  o_bad=""
  o_n=0
  # NUL-delimited, never a split of the space-separated list above: an artifact
  # whose filename carries whitespace split into fragments, grep read paths
  # that do not exist, the artifact escaped the hygiene check entirely, and the
  # pass message counted the fragments as artifacts. Same defect L1 closed in
  # check P; this site survived it because L1's enumeration matched `in $(` and
  # this one splits a variable. The enumeration that covers both is
  # `grep -nE 'for [A-Za-z_][A-Za-z0-9_]* in \$' scripts/validate.sh`, which
  # now returns nothing here, in the hook or in the installers. (G2)
  while IFS= read -r -d '' o_f; do
    o_n=$((o_n + 1))
    o_hit="$(grep -nE '(^|[^A-Za-z])[A-Za-z]:[/\]|/home/|/Users/|AppData' "$o_f" | head -n 3)"
    if [ -n "$o_hit" ]; then
      o_bad="$o_bad$o_f
$o_hit
"
    fi
  done < <(git ls-files -z '.jeffy/evaluator/*.md' 2>/dev/null)
  if [ -n "$o_bad" ]; then
    printf '%s' "$o_bad"
    fault "an evaluator artifact names a machine-absolute path; name locations outside the repository with a placeholder defined once (\$SCRATCH) so the record reads on any clone"
  else
    pass "no tracked evaluator artifact names a machine-absolute path ($o_n artifacts)"
  fi
fi

# P. The converged-stop verify bound's derivation chain, regenerated from the
#    hook and compared byte for byte in every document that states it.
#    Check M already derives the chain of timeout *binaries* the same sentence
#    in README.md names - timeout, gtimeout, a shell watchdog - and that
#    proximity is exactly why this one was needed: 1.8.2 gave the *bound* a
#    second source (P1-31) while README went on calling 240 the default and
#    verify_timeout_seconds the only override, and check M did not fault
#    because the mechanism it derives never moved. Two mechanisms sharing one
#    sentence need two checks.
#    Nothing here classifies prose. The five fields come out of the hook, the
#    clause is rebuilt from them, and each document must carry that exact
#    string, which is the reason the wording is fixed rather than idiomatic
#    per file.
#    Every field is asserted, never merely extracted: a field that goes empty
#    faults instead of silently shortening the clause, and the default and the
#    floor must agree, because if they ever diverge "else 240s" stops naming
#    one number and this check has gone blind.
#    Every field is asserted to have matched exactly once, not merely to be
#    non-empty. A second matching line concatenates into the field, the clause
#    rebuilt from it carries an embedded newline, and grep -F reads that as two
#    alternative patterns - the first of which still matches every document. A
#    hook given a second `*) vt=$((vd * 5)) ;;` arm was reproduced passing this
#    check green while its own message printed the clause broken across a
#    newline. (M1)
# The bound is derived across two files since 1.13.0: the hook reads the
# state key, the shared lib resolves the rest. Enumerating from one of
# them alone is how this check went blind during that extraction, so it
# reads the pair as one source.
p_hook="$(mktemp)"
cat skills/jeffy/hooks/stop-hook.sh skills/jeffy/hooks/lib/quiet-verify.sh > "$p_hook"
# Newline-delimited rather than space-delimited, and enumerated NUL-safe below,
# because a space-delimited list fails open on exactly the input this check
# exists to catch: a tracked path carrying whitespace split into fragments, the
# membership grep failed on names that do not exist, and that document escaped
# the comparison in silence while the check reported green. (L1)
p_files="README.md
skills/jeffy/SKILL.md
skills/jeffy/references/plan-default.md"
if [ ! -f "$p_hook" ]; then
  skip "verify-bound derivation chain (no $p_hook)"
else
  # The single quotes are deliberate: these are sed scripts matching the
  # hook's literal $ characters, not shell expansions. Without the directives
  # below, SC2016 is reported at info level on each, and check 5 above lints
  # with no severity flag, so info alone is enough to take its fault branch
  # and turn the Linux CI leg red while this host - where the linter is
  # absent, the one exclusion the Environment fingerprint declares - stays
  # green. That is how it shipped and how the gate caught it. A comment line
  # here must never open with the linter's own name, or it is parsed as a
  # malformed directive; the first fix for this finding did exactly that. (G2)
  # shellcheck disable=SC2016
  p_key="$(sed -n 's/^[ \t]*vt="\$(fm \([a-z_][a-z_]*\))"$/\1/p' "$p_hook")"
  # The label is read off the lib's scoped jeffy_plan_line call (P1-59), the
  # one place the measured-duration line is named in code.
  p_lbl="$(grep -o "jeffy_plan_line \"\$1\" '[A-Za-z][A-Za-z ]*'" "$p_hook" | sed "s/.*'\(.*\)'/\1/")"
  # shellcheck disable=SC2016
  p_mul="$(sed -n 's/^[ \t]*\*) vt=\$((vd \* \([0-9][0-9]*\))).*/\1/p' "$p_hook")"
  p_dfl="$(sed -n "s/^[ \t]*'' | \*\[!0-9\]\*) vt=\([0-9][0-9]*\) ;;.*/\1/p" "$p_hook")"
  # shellcheck disable=SC2016
  p_flr="$(grep -o '\[ "\$vt" -lt [0-9][0-9]* \]' "$p_hook" | tr -dc '0-9\n' | grep -v '^$')"
  p_missing=""
  p_multi=""
  p_field() {
    if [ -z "$2" ]; then
      p_missing="$p_missing $1"
    else
      p_n="$(printf '%s\n' "$2" | wc -l | tr -d '[:space:]')"
      [ "$p_n" -gt 1 ] && p_multi="$p_multi $1(x$p_n)"
    fi
    return 0
  }
  p_field "state key" "$p_key"
  p_field "PLAN label" "$p_lbl"
  p_field "multiplier" "$p_mul"
  p_field "default" "$p_dfl"
  p_field "floor" "$p_flr"
  # The document set is the hook's own state key rather than a list typed here:
  # a fourth document that discusses the bound joins the comparison in the
  # commit that introduces it instead of drifting outside a hardcoded three.
  # The seed list stays as the floor, so a document that drops the key entirely
  # is still required to carry the clause, and nothing is skipped where git is
  # absent. (M1)
  if [ -n "$p_key" ] && command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    while IFS= read -r -d '' p_extra; do
      case "$p_extra" in evals/* | .jeffy/*) continue ;; esac
      grep -q -- "$p_key" "$p_extra" || continue
      printf '%s\n' "$p_files" | grep -Fxq -- "$p_extra" || p_files="$p_files
$p_extra"
    done < <(git ls-files -z '*.md')
  fi
  if [ -n "$p_missing" ]; then
    fault "the hook's verify-bound derivation could not be enumerated (no$p_missing); the assignments moved and this check went blind"
  elif [ -n "$p_multi" ]; then
    fault "the hook's verify-bound derivation matched more than once ($p_multi); the rebuilt clause would carry an embedded newline, which grep -F reads as alternative patterns and this check would satisfy on the first line alone"
  elif [ "$p_dfl" != "$p_flr" ]; then
    fault "the hook's verify-bound default ($p_dfl) and floor ($p_flr) disagree, so no single number names the last link of the chain"
  else
    # shellcheck disable=SC2016
    p_want='`'"$p_key"'`, else `'"$p_lbl"'` x'"$p_mul"' floored at '"$p_flr"'s, else '"$p_dfl"'s'
    p_bad=""
    # Every statement of the chain in each document, not merely one. Requiring
    # the canonical string to be present is a presence read, and it left every
    # other statement of the same fact in that document unchecked: a second,
    # differing clause passed green beside the canonical one. The locator below
    # matches the clause by shape rather than by its values, so any restatement
    # carrying different numbers is found and compared. What it cannot see is a
    # restatement in free prose, and the answer to that is the one this project
    # already settled - documents state such a fact in one canonical form and it
    # is compared exactly, never classified from wording - which is why the
    # launcher skill's own paragraph was rewritten to state it once. (G3)
    # shellcheck disable=SC2016
    p_shape='`[a-z_][a-z_]*`, else `[A-Za-z][A-Za-z ]*` x[0-9][0-9]* floored at [0-9][0-9]*s, else [0-9][0-9]*s'
    while IFS= read -r p_f; do
      [ -n "$p_f" ] || continue
      if [ ! -f "$p_f" ]; then
        p_bad="$p_bad $p_f(absent)"
        continue
      fi
      p_sites="$(grep -o "$p_shape" "$p_f")"
      if [ -z "$p_sites" ]; then
        p_bad="$p_bad $p_f(states no bound-derivation chain)"
        continue
      fi
      p_i=0
      while IFS= read -r p_site; do
        [ -n "$p_site" ] || continue
        p_i=$((p_i + 1))
        [ "$p_site" = "$p_want" ] || p_bad="$p_bad ${p_f}#${p_i}[${p_site}]"
      done < <(printf '%s\n' "$p_sites")
    done < <(printf '%s\n' "$p_files")
    if [ -n "$p_bad" ]; then
      fault "the hook resolves the verify bound as [$p_want] but the product text disagrees:$p_bad"
    else
      pass "the verify-bound derivation chain is regenerated from the hook and stated identically in every document that carries it ($p_want)"
    fi
  fi
fi

# 6b. The iteration prompt's shape invariants: one single line, no double
#     quotes, no CR bytes. The Stop hook cats the file into its block reason
#     and jq handles the JSON encoding, so nothing breaks mechanically - these
#     invariants exist so the re-fed reason stays one homogeneous instruction
#     string (no stray line breaks splitting the discipline mid-sentence) and
#     so the file stays greppable as a single unit by the governance checks.
prompt_file=skills/jeffy/references/iteration-prompt.txt
if [ -f "$prompt_file" ]; then
  cr_count="$(tr -dc '\r' < "$prompt_file" | wc -c)"
  nl_count="$(tr -dc '\n' < "$prompt_file" | wc -c)"
  # One trailing LF is conventional and harmless; CR bytes and embedded
  # newlines are what the invariant forbids.
  ends_nl=0
  [ -s "$prompt_file" ] && [ "$(tail -c 1 "$prompt_file")" = "" ] && ends_nl=1
  if LC_ALL=C grep -q '"' "$prompt_file"; then
    fault "$prompt_file contains a double quote (breaks shell injection)"
  elif [ "$cr_count" -ne 0 ]; then
    fault "$prompt_file contains a CR byte (breaks shell injection)"
  elif [ "$nl_count" -gt "$ends_nl" ]; then
    fault "$prompt_file has an embedded newline: must be one line (a single trailing LF is fine)"
  else
    pass "$prompt_file is a single line, no double quotes, no CR"
  fi
fi

# 6b2. P0-2 (1.9.0): the prompt's closing rule is the severity floor, and the
#      three clauses that make it safe each appear exactly once - the floor
#      itself, the carried-findings publication duty, and the evaluator
#      re-score. Exactly-once, not presence: a restatement is how the launcher
#      paragraph produced four consecutive gate findings, so the count is the
#      check. Each clause is one canonical substring; the documents state the
#      rule once and nothing else paraphrases it.
if [ -f "$prompt_file" ]; then
  p02_ok=1
  for p02_clause in 'zero open High and zero open Medium' 'lists each carried Low by ID' 're-score the severity of every open and carried finding'; do
    p02_n="$(grep -oF -- "$p02_clause" "$prompt_file" | wc -l | tr -d '[:space:]')"
    if [ "$p02_n" != "1" ]; then
      p02_ok=0
      fault "prompt clause '$p02_clause' appears $p02_n times, expected exactly 1 (the severity floor is stated once or it drifts)"
    fi
  done
  [ "$p02_ok" = "1" ] && pass "the severity-floor closing rule, carried-findings duty, and evaluator re-score each appear exactly once in the prompt"
fi

# 6c. The evaluator-gate marker is unique in the prompt. Check 6 only proves
#     presence, so a stray duplicate of the marker text elsewhere in the file
#     would keep check 6 green even with the gate section itself removed;
#     exactly one occurrence closes that hole. Dependency-free (grep, wc).
if [ -f "$prompt_file" ]; then
  ev_count="$(grep -oF -- "Evaluator gate:" "$prompt_file" | wc -l | tr -d '[:space:]')"
  if [ "$ev_count" = "1" ]; then
    pass "evaluator gate marker appears exactly once (removing the gate fails check 6)"
  else
    fault "evaluator gate marker count is $ev_count, expected exactly 1 (check 6 loses its teeth)"
  fi
fi

# 6d. The one-transaction exemption is the single crack in one task per
#     iteration and it exists on the convergence path alone. Check 6 proves the
#     clause is present; a second copy of it anywhere else in the prompt reads
#     as a general licence to batch, which is the discipline the exemption was
#     carved out of, and check 6 would stay green through it. Exactly one.
if [ -f "$prompt_file" ]; then
  ot_count="$(grep -oF -- "One transaction closes the run:" "$prompt_file" | wc -l | tr -d '[:space:]')"
  if [ "$ot_count" = "1" ]; then
    pass "one-transaction exemption appears exactly once (the convergence path is its only home)"
  else
    fault "one-transaction exemption count is $ot_count, expected exactly 1 (a second copy licenses batching)"
  fi
fi

# 6e. The evaluator bypass is gone from every reference file. Through 1.6.0 a
#     run that could not spawn the sub-agent recorded `Evaluator: unavailable`
#     and converged anyway - the graded party certifying its own gate away in
#     eleven characters, and ta used it in production. The rule lived in three
#     files and a copy left behind in any one of them teaches the bypass back
#     into existence, so the clause is asserted absent by name rather than
#     trusted to have been edited everywhere. Dependency-free (grep).
bypass_left=""
for ref_src in skills/jeffy/references/*.md skills/jeffy/references/*.txt skills/jeffy/SKILL.md; do
  [ -f "$ref_src" ] || continue
  if grep -qF -- "converge under the remaining conditions" "$ref_src"; then
    bypass_left="$bypass_left $ref_src"
  fi
done
if [ -z "$bypass_left" ]; then
  pass "no reference file still lets an unavailable evaluator converge the run"
else
  fault "the evaluator bypass clause survives in:$bypass_left (an unavailable gate must end the run blocked)"
fi

# 7. De-echo guard: the Stop hook pattern-matches promise tags in assistant
#    output, and a prompt that spells the tagged form gets echoed by the model
#    and ends runs early. The skill and the iteration prompt must describe the
#    promise without writing the tag, so the literal string must never appear.
for de_echo in skills/jeffy/SKILL.md skills/jeffy/references/iteration-prompt.txt; do
  if grep -qF -- "<promise>" "$de_echo"; then
    fault "$de_echo contains a literal promise tag (de-echo guard)"
  else
    pass "$de_echo is free of literal promise tags"
  fi
done

# 8. install.sh runtime: run the real installer non-interactively against a
#    sandboxed HOME (stubbed claude on a narrowed PATH; the real jq linked in
#    when the host has one, a stub otherwise) and assert the skills and the
#    Stop hook actually land. With a real jq, also assert the hook got
#    registered in the sandbox settings.json and that a second run does not
#    duplicate the registration. Checks 1-5 are parse/lint-only; this is the
#    behavioral gate that catches a broken copy loop or path regression.
rt_tmp="$(mktemp -d)" || rt_tmp=""
if [ -z "$rt_tmp" ]; then
  fault "install.sh runtime check could not create its sandbox (mktemp failed)"
else
  rt_repo="$rt_tmp/repo"; rt_home="$rt_tmp/home"; rt_bin="$rt_tmp/bin"
  mkdir -p "$rt_repo" "$rt_home" "$rt_bin"
  cp install.sh "$rt_repo/" && cp -R skills "$rt_repo/skills"
  printf '#!/bin/sh\nexit 0\n' > "$rt_bin/claude"
  chmod +x "$rt_bin/claude"
  rt_real_jq=0
  if command -v jq >/dev/null 2>&1; then
    # Wrapper, not a symlink or copy: on the Windows runner jq is a Chocolatey
    # shim that resolves its target relative to its own location, so a copied
    # or MSYS-"symlinked" jq breaks. Exec-ing the original in place works
    # everywhere.
    printf '#!/bin/sh\nexec "%s" "$@"\n' "$(command -v jq)" > "$rt_bin/jq"
    chmod +x "$rt_bin/jq"
    rt_real_jq=1
  else
    printf '#!/bin/sh\nexit 0\n' > "$rt_bin/jq"
    chmod +x "$rt_bin/jq"
  fi
  # P2-32: a file the shipped tree no longer carries is removed on install,
  # planted here so the first run has one to remove.
  mkdir -p "$rt_home/.claude/skills/jeffy/references"
  printf 'stale\n' > "$rt_home/.claude/skills/jeffy/references/enhance-plan-default.md"
  if HOME="$rt_home" PATH="$rt_bin:/usr/bin:/bin" bash "$rt_repo/install.sh" </dev/null >"$rt_tmp/run.log" 2>&1 \
    && [ -f "$rt_home/.claude/skills/jeffy/SKILL.md" ] \
    && [ ! -f "$rt_home/.claude/skills/jeffy/references/enhance-plan-default.md" ] \
    && [ -f "$rt_home/.claude/skills/jeffy/references/iteration-prompt.txt" ] \
    && [ -f "$rt_home/.claude/skills/jeffy/hooks/stop-hook.sh" ] \
    && [ -f "$rt_home/.claude/skills/cancel-jeffy/SKILL.md" ]; then
    pass "install.sh runtime installs both skills and the Stop hook into a sandboxed HOME"
  else
    echo "---- install.sh sandbox run output ----"
    cat "$rt_tmp/run.log"
    echo "---------------------------------------"
    fault "install.sh runtime check failed (nonzero exit or missing installed files)"
  fi
  if [ "$rt_real_jq" -eq 1 ]; then
    rt_count() {
      jq '[.hooks.Stop[]?.hooks[]?.command // empty | select(contains("skills/jeffy/hooks/stop-hook.sh"))] | length' \
        "$rt_home/.claude/settings.json" 2>/dev/null || echo 0
    }
    if [ "$(rt_count)" = "1" ]; then
      pass "install.sh registers the Stop hook in the sandbox settings.json"
    else
      fault "install.sh did not register the Stop hook in the sandbox settings.json"
    fi
    HOME="$rt_home" PATH="$rt_bin:/usr/bin:/bin" bash "$rt_repo/install.sh" </dev/null >"$rt_tmp/rerun.log" 2>&1 || true
    if [ "$(rt_count)" = "1" ]; then
      pass "install.sh hook registration is idempotent (second run adds nothing)"
    else
      echo "---- install.sh sandbox rerun output ----"
      cat "$rt_tmp/rerun.log"
      echo "-----------------------------------------"
      fault "install.sh duplicated or lost the hook registration on a second run"
    fi
    rt_timeouts() {
      jq -r '[.hooks.Stop[]?.hooks[]? | select((.command // "") | contains("skills/jeffy/hooks/stop-hook.sh")) | .timeout // "none" | tostring] | join(",")' \
        "$rt_home/.claude/settings.json" 2>/dev/null || echo ""
    }
    if [ "$(rt_timeouts)" = "1800" ]; then
      pass "install.sh registers the Stop hook with an 1800s timeout"
    else
      fault "install.sh fresh registration lacks the 1800s timeout (got: $(rt_timeouts))"
    fi
    # Legacy upgrade: a pre-1.2 registration without the timeout field gets
    # it added exactly once, and a further run leaves the file byte-identical.
    jq -n --arg cmd "bash \"$rt_home/.claude/skills/jeffy/hooks/stop-hook.sh\"" \
      '{hooks: {Stop: [{hooks: [{type: "command", command: $cmd}]}]}}' > "$rt_home/.claude/settings.json"
    HOME="$rt_home" PATH="$rt_bin:/usr/bin:/bin" bash "$rt_repo/install.sh" </dev/null >"$rt_tmp/upgrade.log" 2>&1 || true
    if [ "$(rt_count)" = "1" ] && [ "$(rt_timeouts)" = "1800" ]; then
      cp "$rt_home/.claude/settings.json" "$rt_tmp/settings.after-upgrade"
      HOME="$rt_home" PATH="$rt_bin:/usr/bin:/bin" bash "$rt_repo/install.sh" </dev/null >"$rt_tmp/upgrade2.log" 2>&1 || true
      if cmp -s "$rt_home/.claude/settings.json" "$rt_tmp/settings.after-upgrade"; then
        pass "install.sh upgrades a legacy registration to the 1800s timeout exactly once"
      else
        fault "install.sh kept rewriting the upgraded registration on later runs"
      fi
    else
      echo "---- install.sh upgrade run output ----"
      cat "$rt_tmp/upgrade.log"
      echo "---------------------------------------"
      fault "install.sh did not upgrade a legacy hook registration with the timeout"
    fi
    # P1-58: a 1.2-1.14 registration carries 600s, which the verify bound can
    # exceed; it moves to 1800s exactly once, and a later run leaves it alone.
    jq -n --arg cmd "bash \"$rt_home/.claude/skills/jeffy/hooks/stop-hook.sh\"" \
      '{hooks: {Stop: [{hooks: [{type: "command", command: $cmd, timeout: 600}]}]}}' > "$rt_home/.claude/settings.json"
    HOME="$rt_home" PATH="$rt_bin:/usr/bin:/bin" bash "$rt_repo/install.sh" </dev/null >"$rt_tmp/upgrade600.log" 2>&1 || true
    if [ "$(rt_count)" = "1" ] && [ "$(rt_timeouts)" = "1800" ]; then
      cp "$rt_home/.claude/settings.json" "$rt_tmp/settings.after-600"
      HOME="$rt_home" PATH="$rt_bin:/usr/bin:/bin" bash "$rt_repo/install.sh" </dev/null >"$rt_tmp/upgrade600b.log" 2>&1 || true
      if cmp -s "$rt_home/.claude/settings.json" "$rt_tmp/settings.after-600"; then
        pass "install.sh moves a 600s registration to 1800s exactly once (P1-58)"
      else
        fault "install.sh kept rewriting the 1800s registration on later runs"
      fi
    else
      cat "$rt_tmp/upgrade600.log"
      fault "install.sh left a 600s registration in place, below the bound the verify ladder can resolve (got: $(rt_timeouts))"
    fi
  else
    skip "install.sh hook-registration assertions (jq not on PATH)"
  fi
  rm -rf "$rt_tmp"
fi

# 9. install.ps1 runtime, when a PowerShell interpreter is available (reuses
#     check 4's $ps). Mirror of check 8 for the Windows install path: stub
#     claude and jq first on PATH so no prompt fires, redirect the profile
#     (HOME for pwsh, USERPROFILE/HOMEDRIVE/HOMEPATH for Windows PowerShell),
#     and assert the skills and the Stop hook land, the hook gets registered
#     in the sandbox settings.json (PowerShell writes it natively, no jq
#     needed), and a second run does not duplicate the registration. Skips
#     cleanly without an interpreter.
if [ -n "$ps" ]; then
  pr_tmp="$(mktemp -d)" || pr_tmp=""
  if [ -z "$pr_tmp" ]; then
    fault "install.ps1 runtime check could not create its sandbox (mktemp failed)"
  else
    pr_repo="$pr_tmp/repo"; pr_home="$pr_tmp/home"; pr_bin="$pr_tmp/bin"
    mkdir -p "$pr_repo" "$pr_home" "$pr_bin"
    cp install.ps1 "$pr_repo/" && cp -R skills "$pr_repo/skills"
    printf '@echo off\r\nexit /b 0\r\n' > "$pr_bin/claude.bat"
    printf '@echo off\r\nexit /b 0\r\n' > "$pr_bin/jq.bat"
    printf '#!/bin/sh\nexit 0\n' > "$pr_bin/claude"
    printf '#!/bin/sh\nexit 0\n' > "$pr_bin/jq"
    chmod +x "$pr_bin/claude" "$pr_bin/jq"
    pr_home_n="$pr_home"; pr_file_n="$pr_repo/install.ps1"
    if command -v cygpath >/dev/null 2>&1; then
      pr_home_n="$(cygpath -w "$pr_home")"
      pr_file_n="$(cygpath -w "$pr_repo/install.ps1")"
    fi
    pr_drive="${pr_home_n%%\\*}"
    pr_rest="${pr_home_n#"$pr_drive"}"
    pr_run() {
      HOME="$pr_home" USERPROFILE="$pr_home_n" HOMEDRIVE="$pr_drive" HOMEPATH="$pr_rest" \
        PATH="$pr_bin:$PATH" "$ps" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$pr_file_n"
    }
    # -ExecutionPolicy Bypass: a stock Windows box defaults to Restricted, which
    # blocks -File and would spuriously fail the check; the flag scopes to this
    # process only.
    # P2-32: a file the shipped tree no longer carries is removed on install.
    mkdir -p "$pr_home/.claude/skills/jeffy/references"
    printf 'stale\n' > "$pr_home/.claude/skills/jeffy/references/enhance-plan-default.md"
    if pr_run >"$pr_tmp/run.log" 2>&1 \
      && [ -f "$pr_home/.claude/skills/jeffy/SKILL.md" ] \
      && [ ! -f "$pr_home/.claude/skills/jeffy/references/enhance-plan-default.md" ] \
      && [ -f "$pr_home/.claude/skills/jeffy/references/iteration-prompt.txt" ] \
      && [ -f "$pr_home/.claude/skills/jeffy/hooks/stop-hook.sh" ] \
      && [ -f "$pr_home/.claude/skills/cancel-jeffy/SKILL.md" ]; then
      pass "install.ps1 runtime installs both skills and the Stop hook into a sandboxed profile ($ps)"
    else
      echo "---- install.ps1 sandbox run output ----"
      cat "$pr_tmp/run.log"
      echo "----------------------------------------"
      fault "install.ps1 runtime check failed (nonzero exit or missing installed files)"
    fi
    pr_count() {
      grep -o 'skills/jeffy/hooks/stop-hook.sh' "$pr_home/.claude/settings.json" 2>/dev/null | wc -l | tr -d '[:space:]'
    }
    if [ "$(pr_count)" = "1" ]; then
      pass "install.ps1 registers the Stop hook in the sandbox settings.json ($ps)"
    else
      fault "install.ps1 did not register the Stop hook in the sandbox settings.json"
    fi
    pr_run >"$pr_tmp/rerun.log" 2>&1 || true
    if [ "$(pr_count)" = "1" ]; then
      pass "install.ps1 hook registration is idempotent (second run adds nothing) ($ps)"
    else
      echo "---- install.ps1 sandbox rerun output ----"
      cat "$pr_tmp/rerun.log"
      echo "------------------------------------------"
      fault "install.ps1 duplicated or lost the hook registration on a second run"
    fi
    # 1.15.0's stale-file sync computed each installed file's relative path by
    # string arithmetic against $HOME, and a $HOME spelled as an 8.3 short path
    # (RUNNER~1 on the CI runner) does not match the long path Get-ChildItem
    # reports: every installed file was removed as "no longer shipped". The
    # sync now lists relative names, and this runs the installer under the
    # short-path spelling to keep it that way.
    if command -v cygpath >/dev/null 2>&1 && pr_home_s="$(cygpath -d "$pr_home" 2>/dev/null)" && [ -n "$pr_home_s" ]; then
      pr_drive_s="${pr_home_s%%\\*}"; pr_rest_s="${pr_home_s#"$pr_drive_s"}"
      HOME="$pr_home" USERPROFILE="$pr_home_s" HOMEDRIVE="$pr_drive_s" HOMEPATH="$pr_rest_s" \
        PATH="$pr_bin:$PATH" "$ps" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$pr_file_n" >"$pr_tmp/short.log" 2>&1 || true
      if [ -f "$pr_home/.claude/skills/jeffy/SKILL.md" ] \
        && [ -f "$pr_home/.claude/skills/jeffy/hooks/stop-hook.sh" ] \
        && [ -f "$pr_home/.claude/skills/jeffy/hooks/lib/quiet-verify.sh" ] \
        && [ -f "$pr_home/.claude/skills/jeffy/references/iteration-prompt.txt" ] \
        && [ -f "$pr_home/.claude/skills/cancel-jeffy/SKILL.md" ] \
        && ! grep -q 'SKILL.md (no longer shipped)' "$pr_tmp/short.log"; then
        pass "install.ps1 keeps every installed file under an 8.3 short-path HOME ($ps)"
      else
        echo "---- install.ps1 short-path run output ----"
        cat "$pr_tmp/short.log"
        fault "install.ps1 removed installed files under an 8.3 short-path HOME (the 1.15.0 sync defect)"
      fi
    fi
    pr_timeout_count() {
      grep -c '"timeout": *1800' "$pr_home/.claude/settings.json" 2>/dev/null | tr -d '[:space:]'
    }
    if [ "$(pr_timeout_count)" = "1" ]; then
      pass "install.ps1 registers the Stop hook with an 1800s timeout ($ps)"
    else
      fault "install.ps1 fresh registration lacks the 1800s timeout"
    fi
    # Legacy upgrade: a pre-1.2 registration without the timeout field gets
    # it added exactly once, and a further run leaves the file byte-identical.
    printf '{\n  "hooks": {\n    "Stop": [\n      {\n        "hooks": [\n          { "type": "command", "command": "bash \\"%s\\"" }\n        ]\n      }\n    ]\n  }\n}\n' \
      "$pr_home/.claude/skills/jeffy/hooks/stop-hook.sh" > "$pr_home/.claude/settings.json"
    pr_run >"$pr_tmp/upgrade.log" 2>&1 || true
    if [ "$(pr_count)" = "1" ] && [ "$(pr_timeout_count)" = "1" ]; then
      cp "$pr_home/.claude/settings.json" "$pr_tmp/settings.after-upgrade"
      pr_run >"$pr_tmp/upgrade2.log" 2>&1 || true
      if cmp -s "$pr_home/.claude/settings.json" "$pr_tmp/settings.after-upgrade"; then
        pass "install.ps1 upgrades a legacy registration to the 1800s timeout exactly once ($ps)"
      else
        fault "install.ps1 kept rewriting the upgraded registration on later runs"
      fi
    else
      echo "---- install.ps1 upgrade run output ----"
      cat "$pr_tmp/upgrade.log"
      echo "----------------------------------------"
      fault "install.ps1 did not upgrade a legacy hook registration with the timeout"
    fi
    rm -rf "$pr_tmp"
  fi
else
  skip "install.ps1 runtime check (no pwsh or powershell on PATH)"
fi

# 10. The fenced bash blocks in skills/jeffy/SKILL.md are executed verbatim at
#     launch (bootstrap, state-file write); parse each one so a syntax break
#     cannot ship. Placeholders like <PROJECT_ROOT> live inside quoted strings
#     or parse as redirections, so bash -n accepts them. Dependency-free
#     (awk, bash).
if [ -f skills/jeffy/SKILL.md ]; then
  fb_count="$(grep -c '^```bash$' skills/jeffy/SKILL.md)"
  fb_bad=0
  fb_i=1
  while [ "$fb_i" -le "$fb_count" ]; do
    fb_block="$(awk -v n="$fb_i" '/^```bash$/{c++; if(c==n){f=1; next}} /^```$/{if(f)exit} f' skills/jeffy/SKILL.md)"
    fb_err="$(printf '%s\n' "$fb_block" | bash -n 2>&1)"
    fb_rc=$?
    if [ "$fb_rc" -ne 0 ]; then
      [ -n "$fb_err" ] && echo "fenced block $fb_i: $fb_err"
      fault "a fenced bash block in skills/jeffy/SKILL.md has a syntax error (block $fb_i)"
      fb_bad=1
    elif printf '%s' "$fb_err" | grep -q 'here-document'; then
      # bash -n accepts an unterminated heredoc with only a warning; that is
      # exactly what a fence line inside a heredoc body produces after the awk
      # extraction truncates the block, so treat the warning as a failure.
      echo "fenced block $fb_i: $fb_err"
      fault "fenced block $fb_i has an unterminated here-document (a fence line inside a heredoc breaks extraction)"
      fb_bad=1
    fi
    fb_i=$((fb_i + 1))
  done
  if [ "$fb_bad" -eq 0 ] && [ "$fb_count" -gt 0 ]; then
    pass "all $fb_count fenced bash blocks in skills/jeffy/SKILL.md parse (bash -n)"
  elif [ "$fb_count" -eq 0 ]; then
    fault "expected fenced bash blocks in skills/jeffy/SKILL.md, found none (extraction broken?)"
  fi
fi

# 11. Stop hook behavior: run the real hook against a sandboxed project and
#     assert the loop-engine lifecycle end to end: a mid-budget stop is
#     blocked with the prompt and focus in the reason and the iteration
#     counter advanced; budget exhaustion deletes the state file and allows
#     the stop; the completion promise ends the run (via the stdin field and
#     via the transcript fallback) but only when its closing claims verify -
#     open tasks in Now, Next, or Later reject the promise with a corrective
#     re-feed, and a pending violation at budget exhaustion still ends the
#     run with a stderr note; the mid-budget re-feed carries iteration
#     hygiene notes when the finished iteration skipped its journal entry or
#     left tracked changes uncommitted (untracked files never fire it); the
#     stall gate stays silent on progress (a commit or a ledger change),
#     rides a STALL note on the first flat iteration, ends the run on the
#     second consecutive one, resets the strike on progress, degrades to
#     the ledger signal without git, and skips with a stderr note when no
#     signal exists, while budget exhaustion and the promise path stay
#     unaffected; a foreign session's state file is left untouched; and a
#     project with no state file is a silent no-op. Needs jq (the hook's own
#     runtime dependency); skips cleanly without it.
if command -v jq >/dev/null 2>&1; then
  hb_tmp="$(mktemp -d)" || hb_tmp=""
  if [ -z "$hb_tmp" ]; then
    fault "stop hook behavior check could not create its sandbox (mktemp failed)"
  else
    hb_hook="skills/jeffy/hooks/stop-hook.sh"
    hb_proj="$hb_tmp/proj"
    hb_state="$hb_proj/.claude/jeffy-loop.local.md"
    mkdir -p "$hb_proj/.claude"
    printf 'Do the jeffy iteration now.' > "$hb_tmp/prompt.txt"
    hb_write_state() { # $1 session_id, $2 iteration, $3 max_iterations, $4 optional verify_timeout_seconds
      {
        printf -- '---\n'
        printf 'session_id: %s\n' "$1"
        printf 'iteration: %s\n' "$2"
        printf 'max_iterations: %s\n' "$3"
        printf 'prompt_path: %s\n' "$hb_tmp/prompt.txt"
        printf 'focus: speed\n'
        printf 'completion_promise: JEFFY CONVERGED\n'
        if [ -n "${4:-}" ]; then printf 'verify_timeout_seconds: %s\n' "$4"; fi
        printf 'started_at: 2026-01-01T00:00:00Z\n'
        printf -- '---\n'
        printf 'Jeffy loop state.\n'
      } > "$hb_state"
    }
    hb_state_addkey() { # $1 "key: value", inserted before the closing ---
      awk -v kv="$1" 'BEGIN { c = 0 } /^---$/ { c++; if (c == 2) print kv } { print }' "$hb_state" > "$hb_state.k" && mv "$hb_state.k" "$hb_state"
    }
    hb_write_plan() { # $1 command for PLAN.md's Command: line
      # The labeled line is the only shape the hook executes (the bare
      # first-line fallback was removed in 1.5.0), so every fixture that
      # wants its command run writes it here.
      printf '# Plan\n\n## Verify command\nCommand: %s\n' "$1" > "$hb_proj/PLAN.md"
    }
    hb_write_plan_full() { # $1 Command: payload, $2... Surface inventory rows, one per line
      hb_cmd="$1"; shift
      {
        printf '# Plan\n\n## Verify command\nCommand: %s\n\n## Surface inventory\n' "$hb_cmd"
        for hb_row in "$@"; do printf '%s\n' "$hb_row"; done
      } > "$hb_proj/PLAN.md"
    }
    hb_write_plan_oracle() { # $1 Command payload, $2 Oracle class payload or ABSENT, $3 Environment fingerprint payload or ABSENT, $4... Surface inventory rows
      # ABSENT omits the line entirely, which is the pre-1.8.0 PLAN.md shape;
      # an empty payload writes the label with nothing after it, which is what
      # a template copied and never filled looks like once the placeholder is
      # deleted rather than answered.
      hb_cmd="$1"; hb_oc="$2"; hb_ef="$3"; shift 3
      {
        printf '# Plan\n\n## Verify command\nCommand: %s\n' "$hb_cmd"
        [ "$hb_oc" = ABSENT ] || printf 'Oracle class: %s\n' "$hb_oc"
        [ "$hb_ef" = ABSENT ] || printf 'Environment fingerprint: %s\n' "$hb_ef"
        printf '\n## Surface inventory\n'
        for hb_row in "$@"; do printf '%s\n' "$hb_row"; done
      } > "$hb_proj/PLAN.md"
    }
    hb_write_state_extra() { # $1 session_id, $2 iteration, $3 max_iterations, $4... raw frontmatter lines placed before started_at
      hb_sid="$1"; hb_it="$2"; hb_max="$3"; shift 3
      {
        printf -- '---\n'
        printf 'session_id: %s\n' "$hb_sid"
        printf 'iteration: %s\n' "$hb_it"
        printf 'max_iterations: %s\n' "$hb_max"
        printf 'prompt_path: %s\n' "$hb_tmp/prompt.txt"
        printf 'focus: speed\n'
        printf 'completion_promise: JEFFY CONVERGED\n'
        for hb_extra in "$@"; do printf '%s\n' "$hb_extra"; done
        printf 'started_at: 2026-01-01T00:00:00Z\n'
        printf -- '---\n'
        printf 'Jeffy loop state.\n'
      } > "$hb_state"
    }
    hb_write_journal_entries() { # $1... full entry heading lines, each optionally <heading>:::<body line>
      # The preamble carries journal-default's unfenced grammar example so the
      # counting and rotation anchors are exercised against the same decoy the
      # real journals hold.
      {
        printf '# Journal\n\nAppend-only. Heading grammar, exactly:\n'
        printf '## iter <i>/<N> | <run-id> | <YYYY-MM-DD> | <task-id or AUDIT or RATCHET or WRAPUP or SALVAGE or ROTATION> | <done|blocked|audit|converged|salvage|rotation>\n'
        for hb_entry in "$@"; do
          hb_head="${hb_entry%%:::*}"
          hb_body='Task: t.'
          case "$hb_entry" in *:::*) hb_body="${hb_entry#*:::}" ;; esac
          printf '\n%s\n\n%s\n' "$hb_head" "$hb_body"
        done
      } > "$hb_proj/JOURNAL.md"
    }
    hb_write_state_stall() { # $1 session_id, $2 iteration, $3 max, $4 last_head, $5 last_backlog, $6 stall flag
      {
        printf -- '---\n'
        printf 'session_id: %s\n' "$1"
        printf 'iteration: %s\n' "$2"
        printf 'max_iterations: %s\n' "$3"
        printf 'prompt_path: %s\n' "$hb_tmp/prompt.txt"
        printf 'focus: speed\n'
        printf 'completion_promise: JEFFY CONVERGED\n'
        printf 'last_head: %s\n' "$4"
        printf 'last_backlog: %s\n' "$5"
        printf 'stall: %s\n' "$6"
        printf 'started_at: 2026-01-01T00:00:00Z\n'
        printf -- '---\n'
        printf 'Jeffy loop state.\n'
      } > "$hb_state"
    }
    hb_write_journal() { # $1 iteration, $2 max - heading for harness session sess-1
      # Run token 000000 comes from the harness started_at of 2026-01-01T00:00:00Z.
      # The entry records a passing evaluator verdict because most fixtures
      # below declare convergence on it, and from 1.5.0 a closing entry that
      # states no verdict is itself the violation. The cases that exercise
      # that check write their own journals with hb_write_journal_entries.
      printf '# Journal\n\n## iter %s/%s | sess-1-000000 | 2026-01-01 | T1 | done\n\nTask: t.\nVerification: Evaluator: PASS - clean sweep.\n' "$1" "$2" > "$hb_proj/JOURNAL.md"
    }
    # Mirrors the hook's ledger signal exactly. From 1.8.0 that signal is a
    # digest of the task lines under Now, Next and Later rather than a cksum
    # of the whole file, so a fixture still checksumming the file would be
    # comparing a different quantity and every stall scenario turning on the
    # ledger would be testing nothing. Reads the current $hb_proj, so it is
    # correct in whichever sandbox the caller has switched to.
    hb_backlog_sig() {
      awk '
        { sub(/\r$/, "") }
        /^## Now$/ { sec = "Now"; next }
        /^## Next$/ { sec = "Next"; next }
        /^## Later$/ { sec = "Later"; next }
        /^## / { sec = "" }
        sec != "" && /^- \[[ b]\]/ { print sec "|" $0 }
      ' "$hb_proj/BACKLOG.md" | cksum | tr ' \t' '--'
    }
    hb_write_backlog() { # $1 optional open task line, $2 optional Converged line
      {
        printf '# Backlog\n\n## Now\n\n'
        if [ -n "${1:-}" ]; then printf '%s\n' "$1"; fi
        printf '\n## Next\n\n## Later\n\n## Converged\n\n'
        if [ -n "${2:-}" ]; then printf '%s\n' "$2"; fi
      } > "$hb_proj/BACKLOG.md"
    }
    # From 1.7.0 a declaration carrying Evaluator: PASS must point at the
    # artifact the gate wrote, so every sandbox that declares needs one, and
    # in a git sandbox it must be committed the way the checkpoint commits it.
    # Run token 000000 comes from the harness started_at, as everywhere else.
    hb_art_n=0
    hb_write_evaluator_artifact() { # $1 optional run id (default sess-1-000000), $2 optional invocation ordinal (default 1)
      # From 1.8.0 the path carries the invocation ordinal, so each verdict
      # is a distinct path no history operation can fold away. hb_art_n is
      # kept for content churn alone: a re-commit at the same ordinal has to
      # differ in bytes for the committed-and-unmodified test to mean
      # anything.
      hb_art_id="${1:-sess-1-000000}"
      hb_art_ord="${2:-1}"
      hb_art_n=$((hb_art_n + 1))
      mkdir -p "$hb_proj/.jeffy/evaluator"
      {
        printf '# Evaluator gate - run %s, invocation %s, iteration 2 of 3 (write %s)\n\n' "$hb_art_id" "$hb_art_ord" "$hb_art_n"
        printf 'Command: bash -c true\nExit: 0\n\n'
        printf 'Verdict: PASS\n'
      } > "$hb_proj/.jeffy/evaluator/$hb_art_id-$hb_art_ord.md"
    }
    # Takes the run id positionally like its sibling; shellcheck flags an
    # optional parameter no caller passes (SC2120), so the one caller passes
    # the default explicitly rather than the helper growing a second shape.
    hb_write_legacy_artifact() { # $1 run id - the pre-1.8.0 single path, for the fallback
      hb_art_id="$1"
      hb_art_n=$((hb_art_n + 1))
      mkdir -p "$hb_proj/.jeffy/evaluator"
      {
        printf '# Evaluator gate - run %s (pre-1.8.0 single-path artifact, write %s)\n\n' "$hb_art_id" "$hb_art_n"
        printf 'Command: bash -c true\nExit: 0\n\n'
        printf 'Verdict: PASS\n'
      } > "$hb_proj/.jeffy/evaluator/$hb_art_id.md"
    }
    # A PASS is dated against the Converged hash, because the contract
    # re-invokes the gate in the iteration that declares. A fixture whose
    # Converged line names a commit made after the sandbox was built has to
    # re-invoke too, and the nonce above is what makes each refresh a real
    # commit rather than a no-op.
    # shellcheck disable=SC2329
    hb_recommit_artifact() {
      hb_write_evaluator_artifact
      hb_git add -A -- .jeffy >/dev/null 2>&1
      hb_git commit -q -m 'jeffy: evaluator artifact' >/dev/null 2>&1
    }
    hb_run() { # $1 session_id, $2 last_assistant_message, $3 transcript_path
      # Feed the hook from a file, not a pipe: the no-state fast path exits
      # before reading stdin, and a pipe writer would take a noisy EPIPE for
      # that (on Windows, "writing output failed: Invalid argument").
      jq -n --arg sid "$1" --arg lam "$2" --arg tr "$3" \
        '{session_id: $sid, last_assistant_message: $lam, transcript_path: $tr, hook_event_name: "Stop"}' \
        > "$hb_tmp/stdin.json"
      CLAUDE_PROJECT_DIR="$hb_proj" bash "$hb_hook" < "$hb_tmp/stdin.json"
    }

    hb_write_evaluator_artifact
    hb_write_state sess-1 1 3
    hb_write_journal 1 3
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'Do the jeffy iteration now.' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'Focus this run on: speed' \
      && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'ITERATION HYGIENE' \
      && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'STALL:' \
      && grep -q '^iteration: 2$' "$hb_state"; then
      pass "stop hook re-feeds mid-budget (block, iteration advanced, prompt and focus in reason)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook mid-budget re-feed is broken"
    fi

    # Iteration hygiene: a journaled iteration re-feeds silently (asserted
    # above); a missing entry rides the re-feed as evidence with the counter
    # still advanced; a missing JOURNAL.md is infrastructure and fails open.
    hb_write_state sess-1 1 3
    hb_write_journal 2 3
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'ITERATION HYGIENE' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF '## iter 1/3 | sess-1' \
      && grep -q '^iteration: 2$' "$hb_state"; then
      pass "stop hook flags a missing journal entry on the re-feed (counter still advances)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook let an unjournaled iteration re-feed silently"
    fi

    hb_write_state sess-1 1 3
    rm -f "$hb_proj/JOURNAL.md"
    hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'ITERATION HYGIENE' \
      && grep -q 'JOURNAL.md missing' "$hb_tmp/hb_err.txt"; then
      pass "stop hook fails open on a missing JOURNAL.md at the re-feed (stderr note)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook mishandled a missing JOURNAL.md at the re-feed"
    fi

    # Run identity: the heading's run-id must name the RUN, not the session.
    # Six /jeffy runs inside one Claude Code session all stamped the identical
    # eight characters on bukosabino/ta, so the journal could not say where one
    # run ended and the next began; reconstructing 64 iterations took the commit
    # timeline instead, and three attempts to count them from the journal were
    # wrong. The started_at time from the loop state disambiguates them.
    hb_write_state sess-1 1 3
    printf '# Journal\n\n## iter 1/3 | sess-1 | 2026-01-01 | T1 | done\n\nTask: t.\n' > "$hb_proj/JOURNAL.md"
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'ITERATION HYGIENE' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'sess-1-000000'; then
      pass "stop hook rejects a journal heading naming the session but not the run"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook accepted a session-only run-id (runs in one session are indistinguishable)"
    fi

    # A state file with no started_at (a run launched before the run token
    # shipped) falls back to the session prefix rather than trapping the run.
    hb_write_state sess-1 1 3
    grep -v '^started_at: ' "$hb_state" > "$hb_state.tmp" && mv "$hb_state.tmp" "$hb_state"
    printf '# Journal\n\n## iter 1/3 | sess-1 | 2026-01-01 | T1 | done\n\nTask: t.\n' > "$hb_proj/JOURNAL.md"
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'ITERATION HYGIENE'; then
      pass "stop hook falls back to the session prefix when the state has no started_at"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook trapped a legacy state file that carries no started_at"
    fi

    hb_write_journal 1 3

    hb_write_state sess-1 3 3
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
      pass "stop hook ends the run at budget exhaustion (state deleted, stop allowed)"
    else
      fault "stop hook did not end the run at budget exhaustion"
    fi

    hb_write_state sess-1 1 3
    hb_write_backlog ''
    hb_write_plan none
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
      pass "stop hook honors the completion promise from last_assistant_message"
    else
      fault "stop hook missed the completion promise in last_assistant_message"
    fi

    hb_write_state sess-1 1 3
    hb_tr="$hb_tmp/transcript.jsonl"
    {
      jq -cn '{type: "user"}'
      jq -cn '{type: "assistant", message: {content: [{type: "text", text: "done <promise>JEFFY CONVERGED</promise>"}]}}'
    } > "$hb_tr"
    hb_out="$(hb_run sess-1 '' "$hb_tr")"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
      pass "stop hook honors the completion promise via the transcript fallback"
    else
      fault "stop hook missed the completion promise in the transcript fallback"
    fi

    # Machine-checked converged stop: an open task in Now, Next, or Later
    # rejects the promise with a corrective re-feed (block, counter advanced,
    # evidence in the reason); an empty ledger accepts it; a pending
    # violation at budget exhaustion still ends the run, with a stderr note.
    hb_write_state sess-1 1 3
    hb_write_backlog '- [ ] T1: unfinished task'
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'CONVERGENCE REJECTED' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'T1: unfinished task' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'Do the jeffy iteration now.' \
      && grep -q '^iteration: 2$' "$hb_state"; then
      pass "stop hook rejects the promise while open tasks remain (corrective re-feed)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook accepted a convergence promise with open backlog tasks"
    fi

    hb_write_state sess-1 1 3
    hb_write_backlog ''
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
      pass "stop hook accepts the promise once Now, Next, and Later are empty"
    else
      fault "stop hook rejected a legitimate convergence promise"
    fi

    # P0-2 (1.9.0): the closing test is a severity floor. An open Low is
    # carried, not blocking - the accept-path stderr note names it so the run
    # report cannot omit it. High, Medium, and any line whose severity the
    # parser cannot read still block, the last because a floor that guesses
    # is a floor gamed by omission. Five scenarios, one severity token
    # mutated between them, so each fails under exactly one mutation.
    # The classifier's severity pattern ends [,)], so a Low is carried whether
    # its parenthetical names a class or not, and both alternatives are driven
    # here. R3: for one release only the comma side was, and a scenario set
    # that exercises one branch of the pattern it tests reads exactly like one
    # that exercises both. The bare form is not hypothetical: the template's
    # own Method says a legacy task line carrying no class is read as runtime,
    # so a ledger written before the class taxonomy existed reaches exactly
    # this branch at its declaration.
    hb_write_state sess-1 1 3
    hb_write_backlog '- [ ] X9 (Low): a bare severity, no class field. Acceptance: fixed.'
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
      && grep -q 'carried Low' "$hb_tmp/hb_err.txt" \
      && grep -qF 'X9 (Low)' "$hb_tmp/hb_err.txt"; then
      pass "stop hook carries a Low whose parenthetical names no class (the severity pattern's other branch)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook did not carry a bare (Low) task line; the severity floor reads only the comma form"
    fi

    hb_write_state sess-1 1 3
    hb_write_backlog '- [ ] X9 (Low, docs, documentation): imprecise sentence. Acceptance: rewritten.'
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
      && grep -q 'carried Low' "$hb_tmp/hb_err.txt" \
      && grep -qF 'X9 (Low' "$hb_tmp/hb_err.txt"; then
      pass "stop hook accepts a declaration whose only open task is a Low, naming it as carried (P0-2)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook refused a declaration blocked only by a Low, or accepted it without naming the carried finding"
    fi

    hb_write_state sess-1 1 3
    hb_write_backlog '- [ ] X9 (Medium, runtime, correctness): wrong value returned. Acceptance: fixed.'
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'still lists open High or Medium tasks' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'X9 (Medium'; then
      pass "stop hook still refuses a declaration with an open Medium under the severity floor"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook let an open Medium through the severity floor"
    fi

    hb_write_state sess-1 1 3
    hb_write_backlog '- [ ] X9 (High, runtime, correctness): crash on empty input. Acceptance: fixed.'
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'still lists open High or Medium tasks'; then
      pass "stop hook still refuses a declaration with an open High under the severity floor"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook let an open High through the severity floor"
    fi

    hb_write_state sess-1 1 3
    hb_write_backlog '- [ ] X9: a task line carrying no severity parenthetical at all'
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'no parseable severity'; then
      pass "stop hook fails closed on an open task with no parseable severity (P0-2 cannot be gamed by omission)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook guessed a severity for an unparseable task line instead of failing closed"
    fi
    # Restore the empty ledger the scenarios below assume; this block's
    # sandbox state is its own to clean up.
    hb_write_backlog ''

    # Surface-inventory check: a convergence claim covers the whole mapped
    # surface. Dimension scores claim only what an audit examined, so an
    # unswept row is unexamined code behind a clean-looking score -
    # quantstats scored correctness None while its montecarlo module had
    # never been opened. A PLAN.md without the section predates the check
    # and fails open.
    hb_write_state sess-1 1 3
    printf '# Plan\n\n## Surface inventory\n\n- [x] core: swept at abc1234 - all entry points probed\n- [ ] plots: unswept\n\n## Verify command\nCommand: none\n' > "$hb_proj/PLAN.md"
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'Surface inventory' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'plots: unswept' \
      && grep -q '^iteration: 2$' "$hb_state"; then
      pass "stop hook rejects the promise while the Surface inventory lists an unswept row"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook accepted convergence over unswept surface rows (None can mean unexamined)"
    fi

    hb_write_state sess-1 1 3
    printf '# Plan\n\n## Surface inventory\n\n- [x] core: swept at abc1234 - all entry points probed\n- [x] plots: swept at abc1234 - all 20 functions probed\n\n## Verify command\nCommand: none\n' > "$hb_proj/PLAN.md"
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
      pass "stop hook accepts the promise once every Surface inventory row is swept"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook rejected convergence with a fully swept Surface inventory"
    fi

    hb_write_state sess-1 1 3
    hb_write_plan none
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] && grep -q 'no Surface inventory' "$hb_tmp/hb_err.txt"; then
      pass "stop hook fails open on a PLAN.md without a Surface inventory section (stderr note)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook mishandled a pre-inventory PLAN.md at the converged stop"
    fi

    # P1-46: a Declined entry's premise is a claim the declaration rests on,
    # and it was the one state-file claim the closing sequence never
    # re-verified - zstd's terminal REJECT was a Declined premise the gate
    # disproved in minutes. An entry with no recorded Derivation blocks the
    # declaration with the entry named; a recorded derivation passes, and so
    # does the priced policy reason, which has nothing to re-run.
    hb_write_state sess-1 1 3
    printf '# Plan\n\n## Surface inventory\n\n- [x] core: swept at abc1234 - all entry points probed\n\n## Verify command\nCommand: none\n' > "$hb_proj/PLAN.md"
    {
      printf '# Backlog\n\n## Now\n\n## Next\n\n## Later\n\n## Declined\n\n'
      printf -- '- D1: testing that path is impractical on this host.\n'
      printf '\n## Converged\n'
    } > "$hb_proj/BACKLOG.md"
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'Declined entry carries no recorded derivation' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'D1: testing that path is impractical' \
      && grep -q '^iteration: 2$' "$hb_state"; then
      pass "stop hook refuses a declaration over a Declined entry with no recorded derivation (the zstd shape)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook let a declaration rest on a Declined premise nothing ever re-ran"
    fi

    hb_write_state sess-1 1 3
    {
      printf '# Backlog\n\n## Now\n\n## Next\n\n## Later\n\n## Declined\n\n'
      printf -- '- D1: that path needs a live origin remote this host does not have. Derivation: git remote -v | grep -c origin\n'
      printf -- '- D2: fix plus regression test does not fit an iteration. cost: exceeds one iteration\n'
      printf '\n## Converged\n'
    } > "$hb_proj/BACKLOG.md"
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
      pass "stop hook accepts a declaration whose Declined entries carry a Derivation or the priced policy reason"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook refused Declined entries that carry exactly what the rule asks for"
    fi
    hb_write_backlog ''

    # --- P1-10: the Verify command declares what it grades ----------------
    # An exit status is the only thing this hook can read from a project's
    # own gate, and go-yaml showed how little that can mean. That run's
    # command exited 0 for 29 iterations across three runs while the
    # repository's 402-case conformance corpus never executed once - the file
    # holding it is build-tagged for another platform and the command's own
    # package selection never reached it - and the journal asserted twice
    # that the corpus was green. Scored independently, the external oracle
    # moved by nothing across 8,174 inserted lines. The hook cannot judge
    # whether a command is wide enough; that is a judgement about the
    # project, and guessing at it is exactly what this engine refuses to do.
    # What it can refuse is a declaration that never wrote down what the
    # command grades and what the platform excludes.
    hb_p10_row='- [x] core: swept at abc1234 - all entry points probed'

    hb_write_state sess-1 1 3
    hb_write_plan_oracle none '<first audit fills this in>' 'linux, go 1.22, excludes nothing' "$hb_p10_row"
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'Oracle class' \
      && grep -q '^iteration: 2$' "$hb_state"; then
      pass "stop hook rejects a declaration whose Oracle class still carries the template placeholder"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook accepted a convergence that never said what its Verify command grades"
    fi

    # An empty payload is the same defect wearing a different face: the
    # placeholder deleted rather than answered.
    hb_write_state sess-1 1 3
    hb_write_plan_oracle none 'unit tests only' '' "$hb_p10_row"
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'Environment fingerprint' \
      && grep -q '^iteration: 2$' "$hb_state"; then
      pass "stop hook rejects a declaration whose Environment fingerprint is left empty"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook accepted a convergence that never named the targets its platform excludes"
    fi

    # Half-migrated PLAN.md: one line answered, its sibling never added. The
    # file is 1.8-shaped the moment either line appears, so the missing one
    # is a defect to name rather than a legacy shape to wave through.
    hb_write_state sess-1 1 3
    hb_write_plan_oracle none 'conformance corpus, 402 cases' ABSENT "$hb_p10_row"
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'Environment fingerprint' \
      && grep -q '^iteration: 2$' "$hb_state"; then
      pass "stop hook rejects a PLAN.md carrying one oracle declaration and not its sibling"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook let a half-migrated oracle declaration through"
    fi

    hb_write_state sess-1 1 3
    hb_write_plan_oracle none 'conformance corpus, 402 cases, run by go test ./...' \
      'linux, go 1.22.5; excludes yaml_test_suite_test.go (build-tagged !windows), per go list -f' "$hb_p10_row"
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
      pass "stop hook accepts a declaration whose Verify command declares its oracle class and exclusions"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook rejected a fully declared oracle"
    fi

    # Every project bootstrapped before 1.8.0 carries neither line, and the
    # loop is designed to be relaunched over state files it wrote under an
    # older engine. Same fail-open shape the Surface inventory shipped with.
    hb_write_state sess-1 1 3
    hb_write_plan_full none "$hb_p10_row"
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] && grep -q 'no Oracle class' "$hb_tmp/hb_err.txt"; then
      pass "stop hook fails open on a pre-1.8.0 PLAN.md with no oracle declarations (stderr note)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook stranded a project bootstrapped before the oracle declaration shipped"
    fi
    hb_write_plan none

    # P1-17: a convergence refused at budget exhaustion used to go to stderr
    # and nowhere else, and nobody reads stderr. The model's declaration and
    # its run report stood in the transcript uncontradicted, so the run read
    # as converged to the only audience that matters while the hook had
    # already refused it. The hook's one channel is blocking the stop, so it
    # spends it once: a corrective re-feed that asks for an honest close, not
    # another attempt - telling a run with no budget left to fix and
    # re-declare would be an instruction it cannot carry out.
    hb_write_state sess-1 3 3
    hb_write_backlog '- [ ] T1: unfinished task'
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'CORRECTIVE' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'still lists open High or Medium tasks' \
      && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'CONVERGENCE REJECTED' \
      && [ -f "$hb_state" ] && grep -q '^corrective_granted: 1$' "$hb_state"; then
      pass "stop hook spends one corrective re-feed on a convergence refused at budget exhaustion"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook let a refused convergence stand uncontradicted in the transcript"
    fi

    # The grant is once, ever. The turn after, the same refusal repeated ends
    # the run rather than buying another corrective, so this cannot become a
    # budget the run extends by declaring badly.
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
      && grep -q 'convergence rejected' "$hb_tmp/hb_err.txt"; then
      pass "stop hook ends the run on the turn after its corrective re-feed (the grant is once)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook granted a second corrective re-feed"
    fi

    # The stall gate must not swallow the corrective. Both want to end the
    # same turn: the budget block grants the corrective, then the stall
    # gate's second strike - which runs later - deletes the state and allows
    # the stop, and the refusal lands on stderr where nobody reads it, which
    # is the exact silence the corrective exists to break. Found in review by
    # driving a rejected declaration through a run whose stall flag was
    # already armed and whose closing entry was not ceremony-exempt. The
    # corrective wins because it is the run's last turn ever - the grant flag
    # ends everything at the next stop regardless - so yielding costs at most
    # one turn and buys the honest close.
    hb_write_plan none
    hb_write_backlog '- [ ] T1: open task'
    hb_write_journal 3 3
    hb_write_state_stall sess-1 3 3 none "$(hb_backlog_sig)" 1
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'CORRECTIVE' \
      && [ -f "$hb_state" ] && grep -q '^corrective_granted: 1$' "$hb_state"; then
      pass "stop hook lets the corrective re-feed outrank the stall gate's second strike"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook let the stall gate swallow the corrective re-feed (the refusal died on stderr)"
    fi

    # Converged-hash check: outside a git repository even a stale Converged
    # line is skipped; inside one, the named commit must resolve and only
    # loop-state paths may differ between it and HEAD.
    hb_write_state sess-1 1 3
    hb_write_backlog '' 'Converged: 1111111111111111111111111111111111111111 - 2026-01-01'
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
      pass "stop hook skips the converged-hash check outside a git repository"
    else
      fault "stop hook applied the converged-hash check to a non-git project"
    fi

    if command -v git >/dev/null 2>&1; then
      hb_saved_proj="$hb_proj"; hb_saved_state="$hb_state"
      hb_proj="$hb_tmp/gitproj"; hb_state="$hb_proj/.claude/jeffy-loop.local.md"
      mkdir -p "$hb_proj/.claude"
      hb_git() { git -C "$hb_proj" -c user.email=jeffy@test -c user.name=jeffy -c core.autocrlf=false "$@"; }
      hb_git init -q -b main
      hb_write_plan none
      hb_write_journal 1 3
      printf 'v1\n' > "$hb_proj/product.txt"
      hb_write_evaluator_artifact
      hb_git add product.txt .jeffy >/dev/null
      hb_git commit -q -m c1
      hb_c1="$(hb_git rev-parse HEAD)"

      hb_write_state sess-1 1 3
      hb_write_backlog '' "Converged: $hb_c1 - 2026-01-01"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook accepts the promise when the Converged line certifies HEAD"
      else
        fault "stop hook rejected a Converged line naming HEAD"
      fi

      printf 'v2\n' > "$hb_proj/product.txt"
      hb_git commit -aqm c2
      hb_write_state sess-1 1 3
      hb_write_backlog '' "Converged: $hb_c1 - 2026-01-01"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'product.txt changed after the Converged hash' \
        && grep -q '^iteration: 2$' "$hb_state"; then
        pass "stop hook rejects the promise when product paths changed after the Converged hash"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook accepted a convergence promise on an uncertified tree"
      fi

      hb_c2="$(hb_git rev-parse HEAD)"
      # A state-only commit after the certified hash, and the gate re-invoked
      # in the declaring iteration the way the contract requires - both are
      # loop memory, and neither may read as a product change.
      hb_write_journal_entries '## iter 1/3 | sess-1-000000 | 2026-01-01 | T1 | done:::Verification: Evaluator: PASS - clean sweep.'
      hb_git add JOURNAL.md >/dev/null
      hb_git commit -q -m state-only
      hb_recommit_artifact
      hb_write_state sess-1 1 3
      hb_write_backlog '' "Converged: $hb_c2 - 2026-01-01"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook accepts state-file-only commits after the Converged hash"
      else
        fault "stop hook rejected a tree where only loop state changed since the Converged hash"
      fi

      hb_write_state sess-1 1 3
      hb_write_backlog ''
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'does not name a commit' \
        && grep -q '^iteration: 2$' "$hb_state"; then
        pass "stop hook rejects the promise when no Converged line names a commit"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook accepted a convergence promise with no certifying Converged line"
      fi

      # P0-6: a swept row is a claim about code at a commit, and the code
      # moves. arrow and spdlog were both refused by the evaluator over rows
      # recorded at commits their sources had moved past - the rule that a
      # stale row flips back to unswept has always been in the prompt with
      # nothing behind it. Staleness needs the row's paths, which is why the
      # row now names the battery that swept it and the battery's paths file
      # supplies the scope. Both directions here, plus the migration case: a
      # row written before the form existed cannot be derived and must fail
      # open, exactly as the Surface inventory and Oracle class checks did.
      mkdir -p "$hb_proj/.jeffy/probes/core"
      printf 'product.txt\n' > "$hb_proj/.jeffy/probes/core/paths"
      hb_git add .jeffy >/dev/null
      hb_git commit -q -m probes
      hb_recommit_artifact

      hb_write_state sess-1 1 3
      hb_write_backlog '' "Converged: $hb_c2 - 2026-01-01"
      hb_write_plan_full none "- [x] core: swept at $hb_c1 via .jeffy/probes/core - probed every entry point"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'is stale' \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'product.txt has changed since' \
        && grep -q '^iteration: 2$' "$hb_state"; then
        pass "stop hook rejects the promise when a swept row's battery paths changed after its recorded commit"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook accepted convergence over a stale Surface inventory row"
      fi

      hb_write_state sess-1 1 3
      hb_write_backlog '' "Converged: $hb_c2 - 2026-01-01"
      hb_write_plan_full none "- [x] core: swept at $hb_c2 via .jeffy/probes/core - re-swept after the change"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook accepts a swept row re-recorded at a commit its battery paths have not moved past"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook rejected a freshly re-recorded Surface inventory row"
      fi

      # P0-8: the template says one glob per line, and through 1.14.0 the
      # comparison was fixed-string, so a glob never matched and the gate was
      # inert for 164 of the corpus's 756 paths files. A glob that covers the
      # moved file refuses; a glob that does not covers nothing and accepts;
      # a battery with no paths file is reported rather than passed over.
      printf '*.txt\n' > "$hb_proj/.jeffy/probes/core/paths"
      hb_write_state sess-1 1 3
      hb_write_backlog '' "Converged: $hb_c2 - 2026-01-01"
      hb_write_plan_full none "- [x] core: swept at $hb_c1 via .jeffy/probes/core - probed every entry point"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'is stale' \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'product.txt has changed since'; then
        pass "stop hook derives staleness through a glob paths line (P0-8)"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook treated a glob paths line as a literal and accepted convergence over a stale row"
      fi
      printf 'docs/*.md\n' > "$hb_proj/.jeffy/probes/core/paths"
      hb_write_state sess-1 1 3
      hb_write_backlog '' "Converged: $hb_c2 - 2026-01-01"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook accepts a row whose glob paths cover nothing that moved (P0-8 control)"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook refused a row over a glob that matches no changed path"
      fi
      rm -f "$hb_proj/.jeffy/probes/core/paths"
      hb_write_state sess-1 1 3
      hb_write_backlog '' "Converged: $hb_c2 - 2026-01-01"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
        && grep -q 'name a battery that has no paths file' "$hb_tmp/hb_err.txt"; then
        pass "stop hook reports a swept row whose battery has no paths file instead of passing it silently (P0-8)"
      else
        printf '%s\n' "$hb_out"; cat "$hb_tmp/hb_err.txt"
        fault "stop hook said nothing about a battery with no paths file"
      fi
      printf 'product.txt\n' > "$hb_proj/.jeffy/probes/core/paths"

      hb_write_state sess-1 1 3
      hb_write_backlog '' "Converged: $hb_c2 - 2026-01-01"
      hb_write_plan_full none "- [x] core: swept at $hb_c1 - probed every entry point"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
        && grep -q 'no swept row names the battery' "$hb_tmp/hb_err.txt"; then
        pass "stop hook fails open on swept rows predating the battery reference (stderr note)"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt"
        fault "stop hook mishandled a pre-1.14.0 swept row carrying no battery reference"
      fi

      hb_proj="$hb_saved_proj"; hb_state="$hb_saved_state"
    else
      skip "converged-hash git scenarios (git not on PATH)"
    fi

    # Verify-command check: the project's own gate runs at the converged
    # stop under a timeout; none skips it, a red or overrunning gate blocks
    # the promise, and a missing ledger fails open with a stderr note.
    hb_write_state sess-1 1 3
    hb_write_backlog ''
    hb_write_plan 'exit 0'
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
      pass "stop hook accepts the promise when the Verify command is green"
    else
      fault "stop hook rejected a convergence promise with a green Verify command"
    fi
    # P2-30: an entry carrying both verdicts reads as the REJECT. A PASS
    # that quotes an earlier rejection verbatim is the model's to reword;
    # a REJECT that also contains the eleven characters of a PASS must not
    # declare on them.
    hb_write_state sess-1 1 3
    hb_write_journal_entries '## iter 1/3 | sess-1-000000 | 2026-01-01 | EVALUATOR | converged:::Verification: Evaluator: PASS - after invocation 1 returned Evaluator: REJECT - one.'
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'records Evaluator: REJECT'; then
      pass "stop hook reads an entry carrying both verdicts as the REJECT (P2-30)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook let a PASS substring outrank a REJECT in the same closing entry"
    fi
    hb_write_journal 1 3

    hb_write_state sess-1 1 3
    hb_write_backlog ''
    hb_write_plan 'exit 3'
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'exited 3' \
      && grep -q '^iteration: 2$' "$hb_state"; then
      pass "stop hook rejects the promise when the Verify command fails"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook accepted a convergence promise with a failing Verify command"
    fi

    hb_write_state sess-1 1 3 1
    hb_write_backlog ''
    hb_write_plan 'sleep 5'
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'exceeded the 1s timeout' \
      && grep -q '^iteration: 2$' "$hb_state"; then
      pass "stop hook rejects the promise when the Verify command exceeds verify_timeout_seconds"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook mishandled a Verify command overrunning its timeout"
    fi

    # P1-31: the bound is measured, not guessed. With no state key the hook
    # derives its timeout from PLAN.md's "Verify duration: <N>s" line at 3x
    # headroom, floored at the old 240s default; a state key still wins.
    # A verify command exiting 124 of its own accord reads as a timeout (a
    # recorded Declined quirk), which makes the ${vt} in the refusal message
    # observable in milliseconds - no fixture has to actually sleep out a
    # bound. The refusal must also name the remedy, because the operator who
    # meets it is standing at a declaration with a slow suite, not reading
    # this script.
    hb_write_plan_duration() { # $1 command, $2 Verify duration payload
      printf '# Plan\n\n## Verify command\nCommand: %s\nVerify duration: %s\n' "$1" "$2" > "$hb_proj/PLAN.md"
    }
    hb_write_state sess-1 1 3
    hb_write_backlog ''
    hb_write_plan_duration 'exit 124' '100s measured 2026-01-01'
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'exceeded the 300s timeout' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'Verify duration:'; then
      pass "stop hook derives its verify bound from PLAN.md's Verify duration line (100s -> 300s), and the refusal names the remedy"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook did not derive its verify bound from the recorded Verify duration"
    fi

    hb_write_state sess-1 1 3
    hb_write_backlog ''
    hb_write_plan_duration 'exit 124' '10s measured 2026-01-01'
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'exceeded the 240s timeout'; then
      pass "stop hook floors a derived verify bound at the 240s default (10s -> 240s, never twitchier than before)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook let a tiny recorded duration lower the verify bound below the default"
    fi

    hb_write_state sess-1 1 3 7
    hb_write_backlog ''
    hb_write_plan_duration 'exit 124' '100s measured 2026-01-01'
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'exceeded the 7s timeout'; then
      pass "stop hook lets an explicit verify_timeout_seconds outrank the PLAN-derived bound (7s wins over 300s)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook mishandled precedence between the state key and the PLAN-derived bound"
    fi

    hb_write_state sess-1 1 3
    hb_write_backlog ''
    hb_write_plan none
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
      pass "stop hook skips the verify check when the Verify command is none"
    else
      fault "stop hook ran a Verify command declared none"
    fi

    # Template-shape contract: plan-default.md writes prose under the
    # heading and the command on a "Command:" line. The hook must run
    # that line, never the prose - live-reproduced when the prose parsed
    # as the command and exited 127, rejecting a legitimate convergence.
    hb_write_plan_templated() { # $1 command for the Command: line
      printf '# Plan\n\n## Verify command\nOne runnable command that must exit 0 for this project to count as unbroken.\n\nCommand: %s\n' "$1" > "$hb_proj/PLAN.md"
    }
    hb_write_state sess-1 1 3
    hb_write_backlog ''
    hb_write_plan_templated 'exit 0'
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
      pass "stop hook parses the template-shaped Verify section (Command: line, not prose)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook mishandled a template-shaped Verify section with a green command"
    fi

    hb_write_state sess-1 1 3
    hb_write_backlog ''
    hb_write_plan_templated 'exit 3'
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'exited 3' \
      && grep -q '^iteration: 2$' "$hb_state"; then
      pass "stop hook runs the Command: line of a template-shaped Verify section"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook did not run the Command: line of a template-shaped Verify section"
    fi

    hb_write_state sess-1 1 3
    hb_write_backlog ''
    hb_write_plan_templated none
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
      pass "stop hook skips a template-shaped Verify command declared none"
    else
      fault "stop hook ran a template-shaped Verify command declared none"
    fi
    hb_write_plan none

    # Fail-open contract: a missing PLAN.md is an infrastructure defect,
    # not a red gate - the hook skips the verify check with a stderr note
    # and the promise still ends the run. Sits before the timeout check in
    # the hook, so this scenario runs even where coreutils timeout is absent.
    hb_write_state sess-1 1 3
    hb_write_backlog ''
    rm -f "$hb_proj/PLAN.md"
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] && grep -q 'PLAN.md missing' "$hb_tmp/hb_err.txt"; then
      pass "stop hook fails open on a missing PLAN.md at promise time (stderr note, verify skipped)"
    else
      fault "stop hook mishandled a missing PLAN.md at promise time"
    fi
    hb_write_plan none

    # A missing BACKLOG.md is NOT the same fail-open shape as a missing
    # PLAN.md above, and 1.8.0 separates them. PLAN.md's absence costs one
    # check, the verify gate, and the hook says so. BACKLOG.md's absence cost
    # every check: the open-task test, the Converged hash, the surface
    # inventory's sibling, and both gates 1.7.0 added all read it, and the
    # hook accepted the promise before any of them ran. It was the broadest
    # fail-open left in the engine and the only shape where "the stop is
    # machine-checked" was untrue. It re-feeds rather than ending the run, so
    # a ledger lost to a bad rotation is repairable inside the budget.
    hb_write_state sess-1 1 3
    rm -f "$hb_proj/BACKLOG.md"
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'CONVERGENCE REJECTED' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'BACKLOG.md is missing' \
      && [ -f "$hb_state" ] && grep -q '^iteration: 2$' "$hb_state"; then
      pass "stop hook refuses a promise with no BACKLOG.md in the tree (the broadest 1.7.0 fail-open)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook accepted a convergence promise with no ledger in the tree"
    fi
    hb_write_backlog ''

    # Iteration hygiene, tracked-tree check: a modified tracked file rides
    # the re-feed as evidence; untracked files never fire it - salvage and
    # the checkpoint's git add -A own those.
    if [ -d "$hb_tmp/gitproj/.git" ]; then
      hb_saved_proj="$hb_proj"; hb_saved_state="$hb_state"
      hb_proj="$hb_tmp/gitproj"; hb_state="$hb_proj/.claude/jeffy-loop.local.md"
      hb_write_journal 1 3
      hb_git add JOURNAL.md >/dev/null
      hb_git commit -q -m reseed-journal

      hb_write_state sess-1 1 3
      printf 'dirty\n' > "$hb_proj/product.txt"
      hb_out="$(hb_run sess-1 'still working' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'ITERATION HYGIENE' \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'product.txt' \
        && grep -q '^iteration: 2$' "$hb_state"; then
        pass "stop hook flags uncommitted tracked changes on the re-feed"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook let a dirty tracked tree re-feed silently"
      fi
      hb_git checkout -q -- product.txt

      hb_write_state sess-1 1 3
      printf 'junk\n' > "$hb_proj/junk.txt"
      hb_out="$(hb_run sess-1 'still working' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'ITERATION HYGIENE' \
        && grep -q '^iteration: 2$' "$hb_state"; then
        pass "stop hook ignores untracked files in the tracked-tree check"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook flagged untracked files as hygiene violations"
      fi
      # P1-48: oscillation and the attempt limit. The stall gate asks whether
      # anything moved; these ask whether what moved went anywhere. A run that
      # edits a source file and reverts it two iterations later moves a
      # non-memory path every single iteration, so it passes the stall gate
      # forever while achieving nothing. These run in the git fixture because
      # the content hash is a real ls-tree over a real repository - a synthetic
      # state file would prove the arithmetic and not the behaviour.
      hb_write_backlog ''
      printf 'v-osc-A\n' > "$hb_proj/product.txt"
      hb_git add -A >/dev/null 2>&1
      hb_git commit -q -m osc-a >/dev/null 2>&1 || true
      hb_osc_head_a="$(hb_git rev-parse HEAD)"
      hb_osc_hash_a="$(hb_git ls-tree -r HEAD | awk -F'\t' 'NF == 2 && $2 !~ /^(PLAN\.md|BACKLOG\.md|JOURNAL\.md|JOURNAL-archive\.md|\.jeffy\/.*|\.claude\/jeffy-loop\.local\.md|\.claude\/settings\.local\.json)$/ { print $1 "\t" $2 }' | cksum | tr ' \t' '--')"

      printf 'v-osc-B\n' > "$hb_proj/product.txt"
      hb_git add -A >/dev/null 2>&1
      hb_git commit -q -m osc-b >/dev/null 2>&1 || true

      # Back to A: the tree now holds content it already held, which is the
      # signature the plain tree hash cannot see because the journal moved too.
      printf 'v-osc-A\n' > "$hb_proj/product.txt"
      hb_git add -A >/dev/null 2>&1
      hb_git commit -q -m osc-back >/dev/null 2>&1 || true
      hb_osc_head_c="$(hb_git rev-parse HEAD)"
      hb_write_journal 3 10

      hb_write_state_stall sess-1 3 10 "$hb_osc_head_a" stale-0 0
      hb_state_addkey "fingerprints: 1|T1|$hb_osc_hash_a|1;2|T2|other-hash|1"
      hb_out="$(hb_run sess-1 'worked the task' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'OSCILLATION' \
        && grep -q '^oscillation: 1$' "$hb_state"; then
        pass "stop hook sees a tree returned to a state it already held and calls it oscillation, not progress"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook read a revert-to-a-previous-tree as ordinary progress, which is a whole budget spent looking productive"
      fi

      # Armed, and it happens again: the run ends.
      hb_write_state_stall sess-1 3 10 "$hb_osc_head_a" stale-0 0
      hb_state_addkey "fingerprints: 1|T1|$hb_osc_hash_a|1;2|T2|other-hash|1"
      hb_state_addkey 'oscillation: 1'
      hb_err="$(hb_run sess-1 'worked the task' '' 2>&1 1>/dev/null)"
      if [ ! -f "$hb_state" ] && printf '%s' "$hb_err" | grep -qF 'oscillating rather than progressing'; then
        pass "a second oscillation ends the run"
      else
        printf '%s\n' "$hb_err"
        fault "the second oscillation did not end the run"
      fi

      # A tree that genuinely moved forward is not oscillation, and the strike
      # resets - the control that keeps this from firing on every run.
      printf 'v-osc-D\n' > "$hb_proj/product.txt"
      hb_git add -A >/dev/null 2>&1
      hb_git commit -q -m osc-d >/dev/null 2>&1 || true
      hb_write_journal 3 10
      hb_write_state_stall sess-1 3 10 "$hb_osc_head_c" stale-0 0
      hb_state_addkey "fingerprints: 1|T1|$hb_osc_hash_a|1;2|T2|other-hash|1"
      hb_state_addkey 'oscillation: 1'
      hb_out="$(hb_run sess-1 'worked the task' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && [ -f "$hb_state" ] \
        && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'OSCILLATION' \
        && grep -q '^oscillation: 0$' "$hb_state"; then
        pass "a tree that moved somewhere new clears the oscillation strike"
      else
        printf '%s\n' "$hb_out"
        fault "the oscillation strike did not reset on real progress, so a healthy run would die of it"
      fi

      # P1-57 was half-applied through 1.15.1. The current iteration was
      # exempted when it was ceremony, but the trail it compared against was
      # still indexed positionally, so the first task iteration after a run of
      # sweeps was measured against a ceremony iteration's content hash -
      # unchanged by design - and took a strike for work nobody had undone.
      # Under coverage-first ordering that is the normal shape rather than a
      # corner, since a run sweeps its map for several iterations and then
      # starts on the ledger; this engine's own repository hit it at iteration
      # 5 of a 10-iteration run, four sweeps followed by one task. A second
      # occurrence ends the run, so the cost is a healthy run dying with
      # budget left. The trail here is all ceremony and the tree is back at
      # hash A, which is exactly the shape that used to fault.
      printf 'v-osc-A\n' > "$hb_proj/product.txt"
      hb_git add -A >/dev/null 2>&1
      hb_git commit -q -m osc-a-again >/dev/null 2>&1 || true
      hb_write_journal 5 10
      hb_write_state_stall sess-1 5 10 "$hb_osc_head_a" stale-0 0
      hb_state_addkey "fingerprints: 1|ceremony|$hb_osc_hash_a|0;2|ceremony|$hb_osc_hash_a|0;3|ceremony|$hb_osc_hash_a|0"
      hb_out="$(hb_run sess-1 'worked the task' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'OSCILLATION' \
        && grep -q '^oscillation: 0$' "$hb_state"; then
        pass "a task iteration is not oscillating against a ceremony iteration's unchanged hash"
      else
        printf '%s\n' "$hb_out"
        fault "the first task iteration after a run of ceremony iterations took a false oscillation strike; a second one ends a healthy run with budget left"
      fi

      # Attempt limit: the same task attempted three iterations running and
      # still open. This makes the prompt's oldest unenforced rule mechanical.
      hb_write_backlog '- [ ] T7 (Medium, runtime, correctness): resists fixing. Acceptance: test.'
      hb_write_journal_task() { # $1 iteration, $2 max, $3 task id
        printf '## iter %s/%s | sess-1-000000 | 2026-01-01 | %s | done\n\nTask: %s\n' \
          "$1" "$2" "$3" "$3" >> "$hb_proj/JOURNAL.md"
      }
      : > "$hb_proj/JOURNAL.md"
      hb_write_journal_task 3 10 T7
      printf 'v-attempt\n' > "$hb_proj/product.txt"
      hb_git add -A >/dev/null 2>&1
      hb_git commit -q -m attempt >/dev/null 2>&1 || true
      hb_write_state_stall sess-1 3 10 "$(hb_git rev-parse HEAD)" stale-0 0
      hb_state_addkey 'fingerprints: 1|T7|h1|2;2|T7|h2|1'
      hb_out="$(hb_run sess-1 'worked the task' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'ATTEMPT LIMIT' \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'T7'; then
        pass "stop hook enforces the three-attempt rule the prompt has always stated and nothing checked"
      else
        printf '%s\n' "$hb_out"
        fault "a task attempted three iterations running and still open drew no attempt-limit note"
      fi

      # And it does not fire on a task that closed: the ledger is the oracle.
      hb_write_backlog ''
      hb_write_state_stall sess-1 3 10 "$(hb_git rev-parse HEAD)" stale-0 0
      hb_state_addkey 'fingerprints: 1|T7|h1|2;2|T7|h2|1'
      hb_out="$(hb_run sess-1 'worked the task' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'ATTEMPT LIMIT'; then
        pass "the attempt limit stays silent once the task it counted has closed"
      else
        printf '%s\n' "$hb_out"
        fault "the attempt limit fired on a task that is no longer open"
      fi

      # One exclusion list, two callers, asserted rather than assumed: if the
      # oscillation hash and the stall gate ever disagree about what loop
      # memory is, both gates look right and the pair is wrong.
      if [ "$(grep -c 'JEFFY_LOOP_MEMORY_RE' "$hb_hook")" -ge 4 ] \
        && [ "$(grep -c "grep -vE '\^(PLAN" "$hb_hook")" -eq 0 ]; then
        pass "loop memory is enumerated once in the hook and shared by every gate that asks what moved"
      else
        fault "the hook carries more than one definition of loop memory; the stall gate and the oscillation hash will drift apart"
      fi

      rm -f "$hb_proj/junk.txt" "$hb_state"
      hb_proj="$hb_saved_proj"; hb_state="$hb_saved_state"
    fi

    # Stall gate: progress on either recorded signal (a product path moved,
    # ledger cksum changed) stays silent and refreshes the baseline; a flat
    # iteration rides a STALL note and arms the flag. Baseline initialization
    # is asserted in the first mid-budget check above (state with no stall
    # fields, no note).
    if [ -d "$hb_tmp/gitproj/.git" ]; then
      hb_saved_proj="$hb_proj"; hb_saved_state="$hb_state"
      hb_proj="$hb_tmp/gitproj"; hb_state="$hb_proj/.claude/jeffy-loop.local.md"
      hb_write_backlog ''
      hb_write_journal 1 3
      hb_git add -A >/dev/null 2>&1
      hb_git commit -q -m stall-baseline >/dev/null 2>&1 || true
      hb_prev_head="$(hb_git rev-parse HEAD)"
      # The recorded baseline has to be a commit this repository holds, and
      # the commit after it has to carry a product path: from 1.7.0 a HEAD
      # that moved for loop bookkeeping alone is not progress, so a fixture
      # that only moves HEAD proves nothing about the progress branch.
      printf 'v-stall\n' > "$hb_proj/product.txt"
      hb_git add -A >/dev/null 2>&1
      hb_git commit -q -m stall-product >/dev/null 2>&1 || true
      hb_head="$(hb_git rev-parse HEAD)"
      hb_ck="$(hb_backlog_sig)"

      hb_write_state_stall sess-1 1 3 "$hb_prev_head" "$hb_ck" 0
      hb_out="$(hb_run sess-1 'still working' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'STALL:' \
        && grep -q "^last_head: $hb_head\$" "$hb_state" \
        && grep -q '^stall: 0$' "$hb_state" \
        && grep -q '^iteration: 2$' "$hb_state"; then
        pass "stop hook stays silent when a product path moved since the last re-feed (baseline refreshed)"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook mishandled a committing iteration in the stall gate"
      fi

      hb_write_state_stall sess-1 1 3 "$hb_head" stale-0 0
      hb_out="$(hb_run sess-1 'still working' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'STALL:' \
        && grep -q "^last_backlog: $hb_ck\$" "$hb_state" \
        && grep -q '^stall: 0$' "$hb_state"; then
        pass "stop hook counts a backlog-only change as progress (no commit needed)"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook flagged a backlog-only iteration as flat"
      fi

      # P1-19: the two definitions of ledger progress agreed on task lines
      # and disagreed on everything else in the file. The hook checksummed
      # the whole of BACKLOG.md, so a reworded Declined note or a new Settled
      # classes line read as progress here while the prompt's own stall rule
      # - no BACKLOG.md item changed state - called the same iteration a
      # stall. The laxer definition was the one deciding whether a run kept
      # going. Now both are the task lines under Now, Next and Later.
      hb_write_backlog ''
      hb_ck_prose="$(hb_backlog_sig)"
      printf '\n## Declined\n\nD1: reworded on the way past, no task line touched.\n' >> "$hb_proj/BACKLOG.md"
      if [ "$(hb_backlog_sig)" = "$hb_ck_prose" ] \
        && [ "$(cksum < "$hb_proj/BACKLOG.md" | tr ' \t' '--')" != "$(printf '' | cksum | tr ' \t' '--')" ]; then
        hb_write_state_stall sess-1 1 3 "$hb_head" "$hb_ck_prose" 0
        hb_out="$(hb_run sess-1 'still working' '')"
        if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
          && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'STALL:' \
          && grep -q '^stall: 1$' "$hb_state"; then
          pass "stop hook reads a BACKLOG.md prose edit that moved no task line as a stall, not progress"
        else
          printf '%s\n' "$hb_out"
          fault "stop hook counted a ledger prose edit as progress while the prompt called it a stall"
        fi
      else
        fault "the ledger-signal fixture did not build a prose-only BACKLOG.md change"
      fi

      # And the other side of the same definition: a task line that moved
      # between sections is a state change even though the file's task lines
      # are otherwise identical.
      hb_write_backlog '- [ ] T9 (Low, docs, documentation): a filed task. Acceptance: the check runs.'
      hb_ck_moved="$(hb_backlog_sig)"
      hb_write_backlog ''
      printf '\n## Declined\n\n- [ ] T9 (Low, docs, documentation): a filed task. Acceptance: the check runs.\n' >> "$hb_proj/BACKLOG.md"
      hb_write_state_stall sess-1 1 3 "$hb_head" "$hb_ck_moved" 0
      hb_out="$(hb_run sess-1 'still working' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'STALL:' \
        && grep -q '^stall: 0$' "$hb_state"; then
        pass "stop hook counts a task line moved out of Now to Declined as a ledger state change"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook missed a task line leaving the open sections"
      fi
      hb_write_backlog ''
      hb_git add -A >/dev/null 2>&1
      hb_git commit -q -m stall-ledger-reset >/dev/null 2>&1 || true
      hb_head="$(hb_git rev-parse HEAD)"
      hb_ck="$(hb_backlog_sig)"

      hb_write_state_stall sess-1 1 3 "$hb_head" "$hb_ck" 0
      hb_out="$(hb_run sess-1 'still working' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'STALL:' \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'no progress' \
        && grep -q '^stall: 1$' "$hb_state" \
        && grep -q '^iteration: 2$' "$hb_state"; then
        pass "stop hook flags the first flat iteration with a STALL note and arms the flag"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook missed a flat iteration"
      fi

      # Second strike: a flat iteration with the flag already armed ends
      # the run the way budget exhaustion does.
      hb_write_state_stall sess-1 2 6 "$hb_head" "$hb_ck" 1
      hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] && grep -q 'ending the run as stalled' "$hb_tmp/hb_err.txt"; then
        pass "stop hook ends the run on the second consecutive flat iteration (state deleted, stderr note)"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook did not end a stalled run on the second flat iteration"
      fi

      # Progress with the flag armed clears it; a later flat iteration is
      # strike 1 again, not strike 2 - proven on the hook's own state
      # rewrites across two consecutive invocations.
      hb_write_state_stall sess-1 1 3 "$hb_prev_head" "$hb_ck" 1
      hb_out="$(hb_run sess-1 'still working' '')"
      hb_out2=""
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'STALL:' \
        && grep -q '^stall: 0$' "$hb_state"; then
        hb_out2="$(hb_run sess-1 'still working' '')"
      fi
      if [ -n "$hb_out2" ] \
        && [ "$(printf '%s' "$hb_out2" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out2" | jq -r '.reason' | grep -qF 'STALL:' \
        && [ -f "$hb_state" ] \
        && grep -q '^stall: 1$' "$hb_state"; then
        pass "stop hook clears the stall flag on progress (later flat iteration is strike 1, not strike 2)"
      else
        printf '%s\n%s\n' "$hb_out" "$hb_out2"
        fault "stop hook mishandled the stall flag across progress and a later flat iteration"
      fi

      # Archive integrity: JOURNAL-archive.md is append-only across every
      # rotation and every run, so its entry count can never fall. A rotation
      # that writes the archive instead of appending to it destroys the run's
      # own record, and nothing else notices, because the live journal looks
      # healthy afterwards. Observed on bukosabino/ta: the second rotation of
      # a 64-iteration run destroyed all 18 entries the first had preserved.
      hb_write_state_archive() { # $1 session_id, $2 iteration, $3 max, $4 last_archive
        {
          printf -- '---\n'
          printf 'session_id: %s\n' "$1"
          printf 'iteration: %s\n' "$2"
          printf 'max_iterations: %s\n' "$3"
          printf 'prompt_path: %s\n' "$hb_tmp/prompt.txt"
          printf 'focus: speed\n'
          printf 'completion_promise: JEFFY CONVERGED\n'
          printf 'last_archive: %s\n' "$4"
          printf 'started_at: 2026-01-01T00:00:00Z\n'
          printf -- '---\n'
          printf 'Jeffy loop state.\n'
        } > "$hb_state"
      }
      hb_write_archive() { # $1 entry count
        printf '# Journal archive\n\n' > "$hb_proj/JOURNAL-archive.md"
        hb_i=1
        while [ "$hb_i" -le "$1" ]; do
          printf '## iter %s/9 | sess-1 | 2026-01-01 | T%s | done\n\nTask: t.\n\n' \
            "$hb_i" "$hb_i" >> "$hb_proj/JOURNAL-archive.md"
          hb_i=$((hb_i + 1))
        done
      }

      hb_write_journal 1 3
      hb_write_archive 3
      hb_write_state_archive sess-1 1 3 12
      hb_git add -A >/dev/null 2>&1
      hb_git commit -q -m archive-shrank >/dev/null 2>&1 || true
      hb_out="$(hb_run sess-1 'still working' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'JOURNAL-archive.md fell from 12 entries to 3' \
        && grep -q '^last_archive: 3$' "$hb_state"; then
        pass "stop hook catches a rotation that overwrote JOURNAL-archive.md instead of appending"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook missed a shrinking JOURNAL-archive.md (silent journal loss)"
      fi

      hb_write_journal 1 3
      hb_write_archive 7
      hb_write_state_archive sess-1 1 3 3
      hb_git add -A >/dev/null 2>&1
      hb_git commit -q -m archive-grew >/dev/null 2>&1 || true
      hb_out="$(hb_run sess-1 'still working' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'JOURNAL-archive.md' \
        && grep -q '^last_archive: 7$' "$hb_state"; then
        pass "stop hook stays silent when a rotation appends to the archive (baseline advances)"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook flagged a legitimate appending rotation"
      fi

      rm -f "$hb_proj/JOURNAL-archive.md"
      hb_write_journal 1 3
      hb_write_state_archive sess-1 1 3 4
      hb_git add -A >/dev/null 2>&1
      hb_git commit -q -m archive-deleted >/dev/null 2>&1 || true
      hb_out="$(hb_run sess-1 'still working' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'JOURNAL-archive.md held 4 entries at the previous turn end and is now missing'; then
        pass "stop hook catches a deleted JOURNAL-archive.md"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook missed a deleted JOURNAL-archive.md"
      fi

      # A project that has never rotated must not trip the check, and the
      # first re-feed of an upgraded run has no recorded baseline at all.
      hb_write_journal 1 3
      hb_write_state sess-1 1 3
      hb_git add -A >/dev/null 2>&1
      hb_git commit -q -m archive-absent >/dev/null 2>&1 || true
      hb_out="$(hb_run sess-1 'still working' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'JOURNAL-archive.md' \
        && grep -q '^last_archive: none$' "$hb_state"; then
        pass "stop hook ignores a project that has never rotated (no archive, no baseline)"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook mishandled a project with no JOURNAL-archive.md"
      fi

      rm -f "$hb_state"
      hb_proj="$hb_saved_proj"; hb_state="$hb_saved_state"
    fi

    # Stall gate degrades: a non-git project stalls out on the ledger
    # signal alone; a project with neither signal skips the gate with a
    # stderr note; the budget path ends the run normally even with the
    # flag armed and both signals flat (the budget is the hard stop).
    hb_write_backlog ''
    hb_ck0="$(hb_backlog_sig)"
    hb_write_state_stall sess-1 2 6 none "$hb_ck0" 1
    hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] && grep -q 'ending the run as stalled' "$hb_tmp/hb_err.txt"; then
      pass "stop hook stalls out a non-git project on the backlog signal alone"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook mishandled the stall gate in a non-git project"
    fi

    rm -f "$hb_proj/BACKLOG.md"
    hb_write_state_stall sess-1 2 6 none none 1
    hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'STALL:' \
      && grep -q 'skipping the stall check' "$hb_tmp/hb_err.txt"; then
      pass "stop hook skips the stall gate with a stderr note when neither signal exists"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook mishandled a project with no stall signals"
    fi
    hb_write_backlog ''

    hb_write_state_stall sess-1 6 6 none "$hb_ck0" 1
    hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] && ! grep -q 'stalled' "$hb_tmp/hb_err.txt"; then
      pass "stop hook budget exhaustion wins over the stall gate (normal run end, no stall note)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook let the stall gate interfere with budget exhaustion"
    fi

    hb_write_state_stall sess-1 2 6 none "$hb_ck0" 1
    hb_write_plan none
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] && ! grep -q 'stalled' "$hb_tmp/hb_err.txt"; then
      pass "stop hook accepts a valid promise with the stall flag armed (promise path never evaluates the gate)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook let the stall gate interfere with the promise-accept path"
    fi

    # --- P1-1: the stall gate against the engine's own commit behaviour ----
    # Every scenario above drove the gate with synthetic state. The engine
    # does not behave that way: the iteration prompt mandates a checkpoint
    # commit and a bookkeeping commit every iteration, so HEAD moves at every
    # turn end of every git project - which is every project in the corpus -
    # and both strikes were unreachable in all of them. These cases drive
    # real iterations with real commits, and the progress signal they hold
    # the hook to is a path outside the loop's own state files.
    if command -v git >/dev/null 2>&1; then
      hb_saved_proj="$hb_proj"; hb_saved_state="$hb_state"
      hb_proj="$hb_tmp/p11proj"; hb_state="$hb_proj/.claude/jeffy-loop.local.md"
      mkdir -p "$hb_proj/.claude" "$hb_proj/.jeffy/probes/core"
      hb_git init -q -b main
      hb_write_plan none
      hb_write_backlog ''
      printf 'v1\n' > "$hb_proj/product.txt"
      printf '#!/bin/sh\nexit 0\n' > "$hb_proj/.jeffy/probes/core/run.sh"
      # Bootstrap gitignores the loop state file, because the checkpoint's
      # git add -A would otherwise commit transient session state every
      # iteration - and a state file inside the tree is a path outside the
      # exclusion list, so it would read as product progress at every single
      # turn and hand the gate back exactly the tautology it just lost.
      printf '.claude/jeffy-loop.local.md\n' > "$hb_proj/.gitignore"
      hb_write_journal_entries
      hb_git add -A >/dev/null 2>&1
      hb_git commit -q -m p11-base >/dev/null 2>&1
      hb_p11_ck="$(hb_backlog_sig)"
      # One real iteration: write the journal entry this iteration is
      # supposed to have written, commit it the way the checkpoint does, and
      # hand the hook the head it recorded at the previous turn end.
      hb_p11_iter() { # $1 iteration, $2 heading suffix (type | status), $3 what else the iteration touched
        hb_p11_prev="$(hb_git rev-parse HEAD)"
        case "${3:-}" in
          product) printf 'v-%s\n' "$1" > "$hb_proj/product.txt" ;;
          battery) printf '#!/bin/sh\n# refreshed at %s\nexit 0\n' "$1" > "$hb_proj/.jeffy/probes/core/run.sh" ;;
        esac
        hb_write_journal_entries "## iter $1/9 | sess-1-000000 | 2026-01-01 | $2"
        hb_git add -A >/dev/null 2>&1
        hb_git commit -q -m "jeffy: iter $1/9" >/dev/null 2>&1
      }

      # (1) Two journal-only task iterations. Each one commits, so the old
      # gate read both as progress and neither strike could ever land.
      hb_p11_iter 1 'T1 | done'
      hb_write_state_stall sess-1 1 9 "$hb_p11_prev" "$hb_p11_ck" 0
      hb_out="$(hb_run sess-1 'still working' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'STALL:' \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'no progress' \
        && grep -q '^stall: 1$' "$hb_state"; then
        pass "stop hook flags a journal-only iteration that committed (the engine's own commits are not progress)"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook read the mandated checkpoint commit as progress - the first strike is dead in git projects"
      fi

      hb_p11_iter 2 'T2 | done'
      hb_write_state_stall sess-1 2 9 "$hb_p11_prev" "$hb_p11_ck" 1
      hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
        && grep -q 'ending the run as stalled' "$hb_tmp/hb_err.txt"; then
        pass "stop hook ends the run on a second committing journal-only iteration (the second strike lands in a git project)"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt" 2>/dev/null
        fault "stop hook could not end a stalled run in a git repository"
      fi

      # (2) The shape the naive fix would kill: a closeout audit that files
      # nothing, then the evaluator gate. Both legitimately change state
      # files only, and two in a row are the correct convergence sequence.
      # The flag is armed going in, so without the exemption the audit ends
      # the run on the spot; it must survive, and the flag must survive with
      # it - an exempt iteration is transparent to the gate, neither strike
      # nor absolution.
      hb_p11_iter 3 'AUDIT | audit'
      hb_write_state_stall sess-1 3 9 "$hb_p11_prev" "$hb_p11_ck" 1
      hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'STALL:' \
        && ! grep -q 'stalled' "$hb_tmp/hb_err.txt" \
        && grep -q '^stall: 1$' "$hb_state"; then
        pass "stop hook exempts a closeout AUDIT iteration from the strike and preserves the flag"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt" 2>/dev/null
        fault "stop hook struck a closeout audit that changed only state files"
      fi

      hb_p11_iter 4 'EVALUATOR | audit'
      hb_write_state_stall sess-1 4 9 "$hb_p11_prev" "$hb_p11_ck" 1
      hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'STALL:' \
        && ! grep -q 'stalled' "$hb_tmp/hb_err.txt" \
        && grep -q '^stall: 1$' "$hb_state"; then
        pass "stop hook exempts an EVALUATOR iteration from the strike (the convergence sequence is not a stall)"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt" 2>/dev/null
        fault "stop hook ended a converging run on its own evaluator gate"
      fi

      # (3) A one-line source change alongside the state files is progress,
      # and it clears the armed flag.
      hb_p11_iter 5 'T5 | done' product
      hb_write_state_stall sess-1 5 9 "$hb_p11_prev" "$hb_p11_ck" 1
      hb_out="$(hb_run sess-1 'still working' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'STALL:' \
        && grep -q '^stall: 0$' "$hb_state"; then
        pass "stop hook counts a source change committed with the state files as progress"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook missed a real product change in the stall gate"
      fi

      # (4) A battery-only iteration draws the note: .jeffy/ is loop memory
      # in the converged-tree test, so it is loop memory here too, and the
      # iteration prompt's own stall rule carries the same list.
      hb_p11_iter 6 'T6 | done' battery
      hb_write_state_stall sess-1 6 9 "$hb_p11_prev" "$hb_p11_ck" 0
      hb_out="$(hb_run sess-1 'still working' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'STALL:' \
        && grep -q '^stall: 1$' "$hb_state"; then
        pass "stop hook flags a battery-only iteration (.jeffy/ is loop memory on both lists)"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook read a .jeffy/ write as product progress"
      fi

      # The bound on the diff: a recorded head this repository cannot resolve
      # - a state file carried from another checkout, a rewritten history -
      # is an infrastructure gap, not evidence of a stall, and fails open.
      hb_write_state_stall sess-1 6 9 deadbeefdeadbeefdeadbeefdeadbeefdeadbeef "$hb_p11_ck" 1
      hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'STALL:' \
        && ! grep -q 'stalled' "$hb_tmp/hb_err.txt" \
        && grep -q '^stall: 0$' "$hb_state"; then
        pass "stop hook fails open when the recorded head is not a commit in this repository"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt" 2>/dev/null
        fault "stop hook struck a run over a baseline it could not resolve"
      fi

      # All four ceremony types, each exempt with the count fresh, and each
      # leaving the armed flag exactly as it found it. AUDIT and EVALUATOR
      # are proven above; RATCHET re-declares an unchanged tree and WRAPUP
      # tidies the ledger and writes a handoff, and both are journal-only by
      # design, so a rejected declaration that reaches this gate must not
      # strike either.
      hb_write_state_ceremony() { # $1 iteration, $2 last_head, $3 stall, $4 ceremony count
        {
          printf -- '---\n'
          printf 'session_id: sess-1\niteration: %s\nmax_iterations: 12\n' "$1"
          printf 'prompt_path: %s\n' "$hb_tmp/prompt.txt"
          printf 'focus: speed\ncompletion_promise: JEFFY CONVERGED\n'
          printf 'last_head: %s\nlast_backlog: %s\nstall: %s\nstall_ceremony: %s\n' "$2" "$hb_p11_ck" "$3" "$4"
          printf 'started_at: 2026-01-01T00:00:00Z\n'
          printf -- '---\nJeffy loop state.\n'
        } > "$hb_state"
      }
      hb_p11_types_ok=1
      for hb_p11_t in AUDIT EVALUATOR RATCHET WRAPUP; do
        hb_p11_iter 7 "$hb_p11_t | audit"
        hb_write_state_ceremony 7 "$hb_p11_prev" 1 0
        hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
        if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
          && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'STALL:' \
          && grep -q '^stall: 1$' "$hb_state" \
          && grep -q '^stall_ceremony: 1$' "$hb_state"; then
          :
        else
          printf 'type %s: %s\n' "$hb_p11_t" "$hb_out"
          hb_p11_types_ok=0
        fi
      done
      if [ "$hb_p11_types_ok" = "1" ]; then
        pass "stop hook exempts every ceremony type (AUDIT, EVALUATOR, RATCHET, WRAPUP) and counts each one"
      else
        fault "stop hook struck a ceremony iteration that legitimately touches state files only"
      fi

      # And the exemption is bounded, because the type is eleven characters
      # the graded party types into its own journal. Three consecutive
      # ceremony iterations are the whole convergence sequence the prompt
      # describes; at the cap the ordinary strike logic resumes.
      hb_p11_iter 7 'AUDIT | audit'
      hb_write_state_ceremony 7 "$hb_p11_prev" 0 3
      hb_out="$(hb_run sess-1 'still working' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'STALL:' \
        && grep -q '^stall: 1$' "$hb_state"; then
        pass "stop hook draws the note on a fourth consecutive ceremony iteration (the exemption is capped)"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook let a run type AUDIT indefinitely to hold the stall gate off"
      fi

      hb_p11_iter 7 'AUDIT | audit'
      hb_write_state_ceremony 7 "$hb_p11_prev" 1 3
      hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
        && grep -q 'ending the run as stalled' "$hb_tmp/hb_err.txt"; then
        pass "stop hook ends a run that kept typing a ceremony type past the cap"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt" 2>/dev/null
        fault "stop hook could not end a run hiding behind the ceremony exemption"
      fi

      # P1-29: an iteration whose entry honestly records blocked did real
      # work and refused an unearned checkpoint - the canonical case is a
      # verify still in flight at turn end, which is how a run died three
      # minutes before its own verify returned green. The status word joins
      # the ceremony exemption under the same cap, so the strike logic is
      # unchanged for every run that never writes it and bounded for one
      # that always does.
      hb_p11_iter 7 'T7 | blocked'
      hb_write_state_ceremony 7 "$hb_p11_prev" 1 0
      hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'STALL:' \
        && grep -q '^stall: 1$' "$hb_state" \
        && grep -q '^stall_ceremony: 1$' "$hb_state"; then
        pass "stop hook exempts an iteration honestly recorded blocked from the stall strike (counted against the ceremony cap)"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook struck an iteration that recorded blocked instead of claiming an unearned checkpoint"
      fi

      hb_p11_iter 7 'T7 | blocked'
      hb_write_state_ceremony 7 "$hb_p11_prev" 1 3
      hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
        && grep -q 'ending the run as stalled' "$hb_tmp/hb_err.txt"; then
        pass "stop hook ends a run that types blocked past the ceremony cap (the exemption cannot become immortality)"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt" 2>/dev/null
        fault "stop hook let a run hide behind the blocked status indefinitely"
      fi

      # A user interrupt can leave two primary entries at one index, which
      # the hygiene check above already warns about. The journal is
      # append-only, so the current entry is the later one: a stale AUDIT
      # heading in front of the real task entry must not exempt it.
      hb_p11_prev="$(hb_git rev-parse HEAD)"
      hb_write_journal_entries \
        '## iter 6/9 | sess-1-000000 | 2026-01-01 | AUDIT | audit' \
        '## iter 6/9 | sess-1-000000 | 2026-01-01 | T6 | done'
      hb_git add -A >/dev/null 2>&1
      hb_git commit -q -m 'jeffy: iter 6/9' >/dev/null 2>&1
      hb_write_state_stall sess-1 6 9 "$hb_p11_prev" "$hb_p11_ck" 1
      hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
        && grep -q 'ending the run as stalled' "$hb_tmp/hb_err.txt"; then
        pass "stop hook reads the last primary entry at a desynced index, not a stale AUDIT heading in front of it"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook let a superseded AUDIT heading exempt the entry that replaced it"
      fi

      # Without started_at the run id is the bare session prefix every run of
      # the session shares, so an earlier run's audit at this index would
      # exempt this run's flat task iteration. The duplicate-index check is
      # disabled on exactly that state file; so is this.
      hb_p11_prev="$(hb_git rev-parse HEAD)"
      hb_write_journal_entries '## iter 7/9 | sess-1 | 2026-01-01 | AUDIT | audit'
      hb_git add -A >/dev/null 2>&1
      hb_git commit -q -m 'jeffy: iter 7/9' >/dev/null 2>&1
      {
        printf -- '---\n'
        printf 'session_id: sess-1\niteration: 7\nmax_iterations: 9\n'
        printf 'prompt_path: %s\n' "$hb_tmp/prompt.txt"
        printf 'focus: speed\ncompletion_promise: JEFFY CONVERGED\n'
        printf 'last_head: %s\nlast_backlog: %s\nstall: 1\n' "$hb_p11_prev" "$hb_p11_ck"
        printf -- '---\nJeffy loop state.\n'
      } > "$hb_state"
      hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
        && grep -q 'ending the run as stalled' "$hb_tmp/hb_err.txt"; then
        pass "stop hook withholds the ceremony exemption from a state file carrying no run token"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook let an earlier run's audit exempt this run through a shared session prefix"
      fi

      # The harness writes .claude/settings.local.json whenever the run's own
      # work draws a permission grant, and the checkpoint's git add -A commits
      # it wherever the project does not ignore it. That is the loop's own
      # tooling moving, not the project, and reading it as progress hands the
      # gate back the tautology it just lost.
      hb_p11_prev="$(hb_git rev-parse HEAD)"
      mkdir -p "$hb_proj/.claude"
      printf '{ "permissions": { "allow": ["Bash(ls:*)"] } }\n' > "$hb_proj/.claude/settings.local.json"
      hb_write_journal_entries '## iter 8/9 | sess-1-000000 | 2026-01-01 | T8 | done'
      # Forced: a maintainer whose global git ignore file carries
      # **/.claude/settings.local.json never commits the file, and the
      # scenario then passes against a hook with no exclusion at all. That is
      # a check the defect also satisfies, so the fixture stages it by hand
      # and the case means the same thing on every machine.
      hb_git add -f .claude/settings.local.json >/dev/null 2>&1
      hb_git add -A >/dev/null 2>&1
      hb_git commit -q -m 'jeffy: iter 8/9' >/dev/null 2>&1
      hb_write_state_stall sess-1 8 9 "$hb_p11_prev" "$hb_p11_ck" 0
      hb_out="$(hb_run sess-1 'still working' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'STALL:' \
        && grep -q '^stall: 1$' "$hb_state"; then
        pass "stop hook reads a committed .claude/settings.local.json as harness churn, not product progress"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook let the harness's own permission file count as an iteration's progress"
      fi

      # And the loop state file itself, wherever the bootstrap gitignore step
      # did not run: the hook rewrites it at every turn end, so a tracked copy
      # differs at every checkpoint and the gate would never fire again.
      hb_p11_prev="$(hb_git rev-parse HEAD)"
      hb_write_journal_entries '## iter 9/12 | sess-1-000000 | 2026-01-01 | T9 | done'
      hb_write_state_stall sess-1 9 12 "$hb_p11_prev" "$hb_p11_ck" 0
      hb_git add -A -f .claude >/dev/null 2>&1
      hb_git add -A >/dev/null 2>&1
      hb_git commit -q -m 'jeffy: iter 9/12' >/dev/null 2>&1
      hb_write_state_stall sess-1 9 12 "$hb_p11_prev" "$hb_p11_ck" 0
      hb_out="$(hb_run sess-1 'still working' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'STALL:' \
        && grep -q '^stall: 1$' "$hb_state"; then
        pass "stop hook reads a tracked .claude/jeffy-loop.local.md as loop state, not product progress"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook let its own state file, committed where bootstrap did not ignore it, defeat the gate"
      fi

      # A run whose git HEAD disappears mid-run - a repository re-inited
      # underneath it - has no head signal at all and falls back to the
      # ledger, exactly as a project that never had git does. Deliberate:
      # the alternative reads a repository that vanished as an iteration's
      # work. Pinned because it was an unannounced change otherwise.
      hb_p11_prev="$(hb_git rev-parse HEAD)"
      mv "$hb_proj/.git" "$hb_tmp/p11-git-aside"
      hb_write_state_stall sess-1 9 12 "$hb_p11_prev" "$hb_p11_ck" 1
      hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
        && grep -q 'ending the run as stalled' "$hb_tmp/hb_err.txt"; then
        pass "stop hook falls back to the ledger signal when the git HEAD it recorded is gone"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt" 2>/dev/null
        fault "stop hook mishandled a repository that disappeared mid-run"
      fi
      mv "$hb_tmp/p11-git-aside" "$hb_proj/.git"

      # A closing extension decided this turn is written by the state rewrite
      # the stall stop never reaches, so the grant evaporates. Ending the run
      # there is right - two flat task iterations are a stall whatever the
      # budget says - but the operator has to be told the +2 went with it.
      hb_p11_prev="$(hb_git rev-parse HEAD)"
      hb_write_journal_entries '## iter 9/9 | sess-1-000000 | 2026-01-01 | T9 | done'
      hb_write_plan_full none '- [x] core: swept at abc1234 - probed'
      hb_git add -A >/dev/null 2>&1
      hb_git commit -q -m 'jeffy: iter 9/9' >/dev/null 2>&1
      hb_p11_ck2="$(hb_backlog_sig)"
      hb_write_state_stall sess-1 9 9 "$hb_p11_prev" "$hb_p11_ck2" 1
      hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
        && grep -q 'ending the run as stalled' "$hb_tmp/hb_err.txt" \
        && grep -q 'closing extension decided this turn is forfeited' "$hb_tmp/hb_err.txt"; then
        pass "stop hook names the closing extension it forfeits when the second strike ends the run"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt" 2>/dev/null
        fault "stop hook discarded a granted closing extension silently"
      fi

      hb_proj="$hb_saved_proj"; hb_state="$hb_saved_state"
    else
      skip "stall-gate commit scenarios (git not on PATH)"
    fi

    # --- P1-1b: both tree gates in a project below the repository root ----
    # git reports paths from the repository root, and every filename in the
    # two exclusion lists is anchored at the project root. In a project that
    # is a subdirectory of a larger repository - a shape the launch pre-flight
    # states plainly and permits - nothing matched: the stall gate read every
    # iteration as progress, exactly the defect it had just been fixed for,
    # and the converged-tree test rejected every declaration by naming a state
    # file as a product path. --relative on both diffs is the whole fix.
    if command -v git >/dev/null 2>&1; then
      hb_saved_proj="$hb_proj"; hb_saved_state="$hb_state"
      hb_sub_root="$hb_tmp/subrepo"
      hb_proj="$hb_sub_root/pkg"; hb_state="$hb_proj/.claude/jeffy-loop.local.md"
      mkdir -p "$hb_proj/.claude"
      git -C "$hb_sub_root" init -q -b main
      hb_subgit() { git -C "$hb_sub_root" -c user.email=jeffy@test -c user.name=jeffy -c core.autocrlf=false "$@"; }
      printf 'outer\n' > "$hb_sub_root/outer.txt"
      printf 'v1\n' > "$hb_proj/product.txt"
      printf '.claude/jeffy-loop.local.md\n' > "$hb_sub_root/.gitignore"
      hb_write_plan_full none '- [x] core: swept at abc1234 - probed'
      hb_write_backlog ''
      hb_write_evaluator_artifact
      hb_write_journal_entries
      hb_subgit add -A >/dev/null 2>&1
      hb_subgit commit -q -m sub-base >/dev/null 2>&1
      hb_sub_ck="$(hb_backlog_sig)"

      hb_sub_prev="$(hb_subgit rev-parse HEAD)"
      hb_write_journal_entries '## iter 1/9 | sess-1-000000 | 2026-01-01 | T1 | done'
      hb_subgit add -A >/dev/null 2>&1
      hb_subgit commit -q -m 'jeffy: iter 1/9' >/dev/null 2>&1
      hb_write_state_stall sess-1 1 9 "$hb_sub_prev" "$hb_sub_ck" 0
      hb_out="$(hb_run sess-1 'still working' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'STALL:' \
        && grep -q '^stall: 1$' "$hb_state"; then
        pass "stop hook flags a journal-only iteration in a project below the repository root"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook read repository-root-relative paths against project-root filenames (the gate is dead in a subdirectory project)"
      fi

      # The same fix on the converged-tree test: state files committed after
      # the Converged hash must not read as product paths here either.
      hb_sub_conv="$(hb_subgit rev-parse HEAD)"
      hb_write_journal_entries '## iter 2/9 | sess-1-000000 | 2026-01-01 | EVALUATOR | converged:::Verification: Evaluator: PASS - ok'
      hb_write_backlog '' "Converged: $hb_sub_conv - 2026-01-01"
      hb_write_evaluator_artifact
      hb_subgit add -A >/dev/null 2>&1
      hb_subgit commit -q -m 'jeffy: iter 2/9' >/dev/null 2>&1
      hb_write_state sess-1 2 9
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook accepts a declaration in a project below the repository root (state files are still state files)"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook named a loop state file as a changed product path in a subdirectory project"
      fi

      hb_proj="$hb_saved_proj"; hb_state="$hb_saved_state"
    else
      skip "subdirectory-project scenarios (git not on PATH)"
    fi

    hb_write_state sess-other 1 3
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ -z "$hb_out" ] && grep -q '^iteration: 1$' "$hb_state"; then
      pass "stop hook leaves a foreign session's state file untouched"
    else
      fault "stop hook touched a foreign session's state file"
    fi

    rm -f "$hb_state"
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ -z "$hb_out" ]; then
      pass "stop hook is a silent no-op without a state file"
    else
      fault "stop hook produced output with no state file present"
    fi

    # Defensive exits fail open, never trap the session. A malformed counter
    # must allow the stop and leave the state file untouched for /jeffy
    # pre-flight to adjudicate; a missing prompt file must end the loop
    # (delete the state) rather than re-feed garbage.
    hb_write_state sess-1 banana 3
    hb_out="$(hb_run sess-1 'still working' '' 2>/dev/null)"
    if [ -z "$hb_out" ] && grep -q '^iteration: banana$' "$hb_state"; then
      pass "stop hook fails open on a malformed counter (stop allowed, state intact)"
    else
      fault "stop hook mishandled a malformed iteration counter"
    fi
    # P2-30: a state file missing its iteration line used to pass the guard,
    # because the guard validated the concatenation of the two fields and
    # "" + "3" read as a well-formed 3; the rewriter then never found a line
    # to advance and the run re-fed forever. Missing is malformed.
    {
      printf -- '---\nsession_id: sess-1\nmax_iterations: 3\nprompt_path: %s\nfocus: speed\ncompletion_promise: JEFFY CONVERGED\nstarted_at: 2026-01-01T00:00:00Z\n---\nJeffy loop state.\n' "$hb_tmp/prompt.txt"
    } > "$hb_state"
    hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
    if [ -z "$hb_out" ] && [ -f "$hb_state" ] && grep -q 'malformed state file' "$hb_tmp/hb_err.txt"; then
      pass "stop hook refuses a state file with no iteration line as malformed instead of re-feeding it forever (P2-30)"
    else
      printf '%s\n' "$hb_out"; cat "$hb_tmp/hb_err.txt"
      fault "stop hook re-fed a state file that carries no iteration line"
    fi

    hb_write_state sess-1 1 3
    rm -f "$hb_tmp/prompt.txt"
    hb_out="$(hb_run sess-1 'still working' '' 2>/dev/null)"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
      pass "stop hook ends the loop when the prompt file is missing (state deleted, stop allowed)"
    else
      fault "stop hook mishandled a missing prompt file"
    fi

    # --- v1.5.0 Phase 1 expectations (E1, E6, E7, E8) --------------------
    # These cases state the planned parser, counting, and hygiene behavior
    # and are written before the hook changes that satisfy them, so several
    # are red against the v1.4.1 hook by design. Each names the corpus loss
    # it exists to prevent. The missing-prompt case above deleted the prompt
    # file; every re-feed below needs it back.
    printf 'Do the jeffy iteration now.' > "$hb_tmp/prompt.txt"

    if command -v git >/dev/null 2>&1; then
      # The promise path only means anything inside a repository - the
      # converged-hash check has to certify a real commit - and a dedicated
      # sandbox keeps these fixtures clear of the stall and archive
      # scenarios above.
      hb_saved_proj="$hb_proj"; hb_saved_state="$hb_state"
      hb_proj="$hb_tmp/p1proj"; hb_state="$hb_proj/.claude/jeffy-loop.local.md"
      mkdir -p "$hb_proj/.claude"
      hb_git init -q -b main
      printf 'v1\n' > "$hb_proj/product.txt"
      hb_write_evaluator_artifact
      hb_git add product.txt .jeffy >/dev/null
      hb_git commit -q -m c1
      hb_p1_c1="$(hb_git rev-parse HEAD)"
      hb_p1_row='- [x] core: swept at abc1234 - all entry points probed'
      hb_write_journal 1 3

      # E1: the Converged line is prose a model writes, so the parser must
      # tolerate the markdown shapes it actually produces - a list marker,
      # and a hash in backticks. The column-zero anchor cost bat two
      # declarations and the run its last two iterations.
      hb_write_state sess-1 1 3
      hb_write_plan_full none "$hb_p1_row"
      hb_write_backlog '' "- Converged: $hb_p1_c1 - 2026-01-01"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook accepts a Converged line written as a markdown list item"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook rejected a list-form Converged line that names HEAD"
      fi

      hb_write_state sess-1 1 3
      hb_write_backlog '' '- Converged: `'"$hb_p1_c1"'` - 2026-01-01'
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook accepts a Converged line whose hash is wrapped in backticks"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook rejected a backticked Converged hash that names HEAD"
      fi

      # The other list marker markdown produces, alone and combined with the
      # backticked hash: the parser tolerates the shapes models write, so
      # every one of them is pinned rather than assumed.
      hb_write_state sess-1 1 3
      hb_write_backlog '' "* Converged: $hb_p1_c1 - 2026-01-01"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook accepts a Converged line written with a star list marker"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook rejected a star-marker Converged line that names HEAD"
      fi

      hb_write_state sess-1 1 3
      hb_write_backlog '' '* Converged: `'"$hb_p1_c1"'` - 2026-01-01'
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook accepts a Converged line carrying both a list marker and a backticked hash"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook rejected a Converged line combining a list marker with a backticked hash"
      fi

      # E1: a backticked Command payload reaches bash -c as command
      # substitution, which runs the command's own output as a command -
      # exit 127, and the shape that killed declarations on bat, dayjs,
      # fasthttp, and pyportfolioopt. The wrapping pair is stripped.
      hb_write_state sess-1 1 3
      # The backticks are the fixture, not an expansion: the payload has to
      # reach the hook wrapped in literal backticks, exactly as written.
      # shellcheck disable=SC2016
      hb_write_plan_full '`echo ok`' "$hb_p1_row"
      hb_write_backlog '' "Converged: $hb_p1_c1 - 2026-01-01"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook strips wrapping backticks from the Command line and runs the command"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook fed a backticked Command line to bash -c as command substitution"
      fi

      # E1: a Command line carrying an annotation is not runnable shell.
      # The hook must say so instead of executing it and reporting the
      # syntax error as a mystery exit 2 (ta, yfinance, bat), and must
      # never guess which trailing text was annotation - so nothing runs.
      rm -f "$hb_proj/p1-side.txt"
      hb_write_state sess-1 1 3
      hb_write_plan_full 'printf p1 > p1-side.txt (419 tests)' "$hb_p1_row"
      hb_write_backlog '' "Converged: $hb_p1_c1 - 2026-01-01"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'not runnable shell' \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'bash -n' \
        && [ ! -f "$hb_proj/p1-side.txt" ] \
        && grep -q '^iteration: 2$' "$hb_state"; then
        pass "stop hook reports a non-runnable Command line as a bash -n violation without executing it"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook executed a Command line that is not runnable shell"
      fi

      # E1: with the bare-first-line fallback deleted, a Verify section
      # that names no Command line skips the check with a stderr note the
      # way every other infrastructure defect does. Prose is never shell.
      hb_write_state sess-1 1 3
      printf '# Plan\n\n## Verify command\nRun the full suite before declaring; see CONTRIBUTING.md.\n\n## Surface inventory\n%s\n' "$hb_p1_row" > "$hb_proj/PLAN.md"
      hb_write_backlog '' "Converged: $hb_p1_c1 - 2026-01-01"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
        && grep -q 'carries no Command line' "$hb_tmp/hb_err.txt" \
        && grep -q 'skipping the verify check' "$hb_tmp/hb_err.txt"; then
        pass "stop hook skips the verify check when the Verify section has no Command line (stderr note)"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt"
        fault "stop hook ran the prose of a Verify section that names no Command line"
      fi

      # The other empty payload: a Command line holding a bare pair of
      # backticks is empty only after the strip, and it is a different edit
      # to PLAN.md than a section with no Command line at all, so the note
      # has to name the line rather than deny it exists.
      hb_write_state sess-1 1 3
      # shellcheck disable=SC2016
      hb_write_plan_full '``' "$hb_p1_row"
      hb_write_backlog '' "Converged: $hb_p1_c1 - 2026-01-01"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
        && grep -q 'carries an empty Command line' "$hb_tmp/hb_err.txt" \
        && grep -q 'skipping the verify check' "$hb_tmp/hb_err.txt"; then
        pass "stop hook reports a Command line emptied by the backtick strip as an empty Command line"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt"
        fault "stop hook misdiagnosed a Command line emptied by the backtick strip"
      fi

      # The fallback's own target shape - a bare command as the section's
      # first non-empty line - proves the deletion: the marker must not
      # exist afterwards, so nothing was executed.
      rm -f "$hb_proj/p1-prose-ran.txt"
      hb_write_state sess-1 1 3
      printf '# Plan\n\n## Verify command\ntouch p1-prose-ran.txt\n\n## Surface inventory\n%s\n' "$hb_p1_row" > "$hb_proj/PLAN.md"
      hb_write_backlog '' "Converged: $hb_p1_c1 - 2026-01-01"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] && [ ! -f "$hb_proj/p1-prose-ran.txt" ]; then
        pass "stop hook no longer executes a bare first line as the Verify command (fallback deleted)"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook executed an unlabeled first line as the Verify command"
      fi
      rm -f "$hb_proj/p1-prose-ran.txt"

      # Regression guard for the bash -n check: parentheses inside quotes
      # are legitimate shell and must still run. The check rejects
      # unparsable lines, not lines that merely look annotated.
      hb_write_state sess-1 1 3
      hb_write_plan_full "test -n 'ok (419 tests)'" "$hb_p1_row"
      hb_write_backlog '' "Converged: $hb_p1_c1 - 2026-01-01"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook still runs a Command line whose parentheses are quoted"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook rejected a runnable Command line carrying quoted parentheses"
      fi

      # Trailing spaces are a markdown hard break, a shape real PLAN.md
      # files carry, and they sit outside the closing backtick where they
      # defeat a strip anchored on both ends. The payload is trimmed first.
      hb_write_state sess-1 1 3
      # shellcheck disable=SC2016
      hb_write_plan_full '`echo ok` ' "$hb_p1_row"
      hb_write_backlog '' "Converged: $hb_p1_c1 - 2026-01-01"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook trims whitespace around the Command payload before stripping backticks"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook let trailing whitespace defeat the Command-line backtick strip"
      fi

      # The strip pairs the two ends, so a payload whose first and last
      # backticks belong to two different substitutions must be left alone:
      # stripping re-pairs them into a command nobody wrote, and it parses,
      # so bash -n cannot catch it. Written as-is the payload creates
      # p1-tick.txt; re-paired it creates a differently named file instead
      # and still exits 0, so only the marker tells the two apart.
      rm -f "$hb_proj"/p1-tick.txt*
      hb_write_state sess-1 1 3
      # shellcheck disable=SC2016
      hb_write_plan_full '`touch p1-tick.txt` true `true`' "$hb_p1_row"
      hb_write_backlog '' "Converged: $hb_p1_c1 - 2026-01-01"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] && [ -f "$hb_proj/p1-tick.txt" ]; then
        pass "stop hook leaves a Command payload with interior backticks exactly as written"
      else
        printf '%s\n' "$hb_out"
        ls "$hb_proj"
        fault "stop hook re-paired backticks belonging to two different substitutions"
      fi
      rm -f "$hb_proj"/p1-tick.txt*

      hb_proj="$hb_saved_proj"; hb_state="$hb_saved_state"
    else
      skip "Converged-line and Command-line scenarios (git not on PATH)"
    fi

    # E6: the archive counter must anchor on real entries. journal-default's
    # unfenced grammar example begins "## iter <i>/<N>", so a naive count of
    # "^## iter " counts a line that is not an entry: the baseline inflates
    # by one every turn and a real loss of one entry reads as no change.
    hb_write_archive_tpl() { # $1 entry count, $2 'template' to prepend journal-default's unfenced grammar example
      {
        printf '# Journal archive\n\n'
        if [ "${2:-}" = template ]; then
          printf '## iter <i>/<N> | <run-id> | <YYYY-MM-DD> | <task-id or AUDIT or RATCHET or WRAPUP or SALVAGE or ROTATION> | <done|blocked|audit|converged|salvage|rotation>\n\n'
        fi
        hb_i=1
        while [ "$hb_i" -le "$1" ]; do
          printf '## iter %s/9 | sess-1-000000 | 2026-01-01 | T%s | done\n\nTask: t.\n\n' "$hb_i" "$hb_i"
          hb_i=$((hb_i + 1))
        done
      } > "$hb_proj/JOURNAL-archive.md"
    }
    hb_write_backlog ''
    hb_write_journal 1 3

    hb_write_archive_tpl 3 template
    hb_write_state_extra sess-1 1 3 'last_archive: 3'
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'JOURNAL-archive.md' \
      && grep -q '^last_archive: 3$' "$hb_state"; then
      pass "stop hook counts archive entries strictly, excluding the grammar-example line"
    else
      printf '%s\n' "$hb_out"
      grep '^last_archive: ' "$hb_state"
      fault "stop hook counted journal-default's grammar example as an archived entry"
    fi

    # Migration: a baseline recorded by the naive counter includes the
    # template line, so the strict counter must not read the correction as
    # loss. The escape is one-shot and says so on stderr: the same re-feed
    # stores the strict baseline and stamps archive_migrated on the state.
    hb_write_archive_tpl 2 template
    hb_write_state_extra sess-1 1 3 'last_archive: 3'
    hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'JOURNAL-archive.md' \
      && grep -q 'migrated a legacy JOURNAL-archive.md baseline' "$hb_tmp/hb_err.txt" \
      && grep -q '^last_archive: 2$' "$hb_state" \
      && grep -q '^archive_migrated: 1$' "$hb_state"; then
      pass "stop hook migrates a template-inflated archive baseline once and records the migration"
    else
      printf '%s\n' "$hb_out"
      cat "$hb_tmp/hb_err.txt"
      grep '^last_archive: \|^archive_migrated: ' "$hb_state"
      fault "stop hook mishandled a legacy archive baseline that counted the grammar example"
    fi

    # The blind spot the flag closes: the archive still carries the template
    # line after migration, so a permanent naive escape would swallow every
    # later loss of exactly one entry. With the flag set, the strict count
    # alone decides and the loss is named.
    hb_write_archive_tpl 2 template
    hb_write_state_extra sess-1 1 3 'last_archive: 3' 'archive_migrated: 1'
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'JOURNAL-archive.md fell from 3 entries to 2' \
      && grep -q '^last_archive: 2$' "$hb_state" \
      && grep -q '^archive_migrated: 1$' "$hb_state"; then
      pass "stop hook catches a one-entry archive loss after migration (the template line stops excusing it)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook let a migrated template-carrying archive hide a one-entry loss"
    fi

    # Loss detection keeps its teeth: no template, two entries, a baseline
    # of three is a destroyed rotation and must still be named.
    hb_write_archive_tpl 2
    hb_write_state_extra sess-1 1 3 'last_archive: 3'
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'JOURNAL-archive.md fell from 3 entries to 2' \
      && grep -q '^last_archive: 2$' "$hb_state"; then
      pass "stop hook still catches a genuine archive loss under the strict count"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook lost its archive-loss detection to the strict count"
    fi
    rm -f "$hb_proj/JOURNAL-archive.md"

    # E7: a user interrupt desyncs the iteration counter from the journal,
    # and the run then writes two primary entries under one index - observed
    # on fasthttp at 10/10, where per-iteration accounting went silently
    # wrong. Warn only: the note rides the re-feed, no state surgery.
    hb_write_journal_entries \
      '## iter 1/3 | sess-1-000000 | 2026-01-01 | T1 | done' \
      '## iter 2/3 | sess-1-000000 | 2026-01-01 | T2 | done'
    hb_write_state sess-1 1 3
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'ITERATION HYGIENE' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'iter 2/3' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'desynced' \
      && grep -q '^iteration: 2$' "$hb_state"; then
      pass "stop hook flags a re-feed into an index that already holds a primary entry"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook re-fed an already-occupied iteration index without a hygiene note"
    fi

    # The bound on that check: a state file older than started_at has no run
    # token, so the run id is the bare session prefix every run of the session
    # shares. An earlier run's entry at the next index is then not a desync,
    # and the note would ride every re-feed of an upgraded run.
    hb_write_journal_entries \
      '## iter 1/3 | sess-1 | 2026-01-01 | T1 | done' \
      '## iter 2/3 | sess-1 | 2026-01-01 | T2 | done'
    {
      printf -- '---\n'
      printf 'session_id: sess-1\n'
      printf 'iteration: 1\n'
      printf 'max_iterations: 3\n'
      printf 'prompt_path: %s\n' "$hb_tmp/prompt.txt"
      printf 'focus: speed\n'
      printf 'completion_promise: JEFFY CONVERGED\n'
      printf -- '---\n'
      printf 'Jeffy loop state.\n'
    } > "$hb_state"
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'desynced' \
      && grep -q '^iteration: 2$' "$hb_state"; then
      pass "stop hook skips the duplicate-index check when the state file carries no run token"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook read an earlier run's entry as a desync on a state file with no run token"
    fi

    # E8: the state schema grows additively. The awk rewriter must carry
    # extension_granted and any key it has never heard of through untouched,
    # so an old state file stays valid and a new one survives every re-feed.
    hb_write_journal 1 3
    hb_write_state_extra sess-1 1 3 'extension_granted: 1' 'unknown_future_key: x'
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && grep -q '^extension_granted: 1$' "$hb_state" \
      && grep -q '^unknown_future_key: x$' "$hb_state" \
      && grep -q '^iteration: 2$' "$hb_state"; then
      pass "stop hook state rewrite preserves extension_granted and unknown keys verbatim"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook dropped an additive state key on the re-feed"
    fi

    # --- v1.5.0 Phase 2 expectations (E3, E4, E5) ------------------------
    # Run-state telemetry on every re-feed, the one-time closing extension,
    # and a machine-checked evaluator verdict at the declaration. Written
    # before the hook changes that satisfy them, so most are red against the
    # Phase 1 hook by design. Each names the corpus loss it exists to
    # prevent.

    # The telemetry counts open rows per section, so the ledger fixture has
    # to differ per section and hb_write_backlog only fills Now. The closed
    # row in each section is the discriminator: a count that reads every
    # list line rather than the open ones gets a different answer.
    hb_write_backlog_counts() { # $1 open in Now, $2 open in Next, $3 open in Later
      {
        printf '# Backlog\n\n'
        hb_sec=1
        for hb_n in "$1" "$2" "$3"; do
          case "$hb_sec" in
            1) printf '## Now\n\n' ;;
            2) printf '## Next\n\n' ;;
            3) printf '## Later\n\n' ;;
          esac
          hb_i=1
          while [ "$hb_i" -le "$hb_n" ]; do
            printf -- '- [ ] S%s%s: open task\n' "$hb_sec" "$hb_i"
            hb_i=$((hb_i + 1))
          done
          printf -- '- [x] S%sD: closed task\n\n' "$hb_sec"
          hb_sec=$((hb_sec + 1))
        done
        printf '## Converged\n\n'
      } > "$hb_proj/BACKLOG.md"
    }

    # E3: the model reads the last three journal entries and owns no
    # arithmetic, so the budget is felt rather than computed - "the budget
    # arithmetic should have been done at iteration 7, not felt at iteration
    # 9" (pyportfolioopt), and dayjs run 7 spent three iterations on four
    # tasks it was already arithmetically short of. The hook holds every
    # number involved and states them on every re-feed.
    hb_write_journal 1 3
    hb_write_backlog_counts 2 1 0
    hb_write_plan_full none \
      '- [ ] alpha: unswept' \
      '- [ ] beta: unswept' \
      '- [ ] gamma: unswept' \
      '- [x] delta: swept at abc1234 - all entry points probed' \
      '- [~] epsilon: unreachable on this host - no arm64 runner'
    hb_write_state sess-1 1 3
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'RUN STATE: iteration 2 of 3; 1 remain after it' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'open tasks Now 2 Next 1 Later 0' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'unswept rows 3' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'jeffy v' \
      && grep -q '^iteration: 2$' "$hb_state"; then
      pass "stop hook states the run arithmetic on a mid-budget re-feed (iterations, open tasks per section, unswept rows)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook re-fed without the RUN STATE telemetry (the model owns the budget arithmetic again)"
    fi

    # The endgame is the case the telemetry exists for: an empty ledger and
    # a swept inventory still need two to three iterations of ceremony, and
    # a run that does not know that spends them and dies mid-declaration.
    hb_write_backlog_counts 0 0 0
    hb_write_plan_full none \
      '- [x] delta: swept at abc1234 - all entry points probed' \
      '- [~] epsilon: unreachable on this host - no arm64 runner'
    hb_write_state sess-1 1 3
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'unswept rows 0' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'Only the convergence sequence remains' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'plan the remaining 1 accordingly'; then
      pass "stop hook names the convergence sequence when the ledger is empty and every row is swept"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook left the endgame cost unstated on an empty ledger"
    fi

    # Telemetry is an accounting aid, never a gate: a project missing the
    # files it counts from re-feeds exactly as before, with the fields it
    # could not compute simply absent.
    rm -f "$hb_proj/BACKLOG.md" "$hb_proj/PLAN.md"
    hb_write_state sess-1 1 3
    hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'RUN STATE: iteration 2 of 3; 1 remain after it' \
      && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'open tasks' \
      && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'unswept rows' \
      && grep -q '^iteration: 2$' "$hb_state"; then
      pass "stop hook omits the telemetry fields it cannot compute without BACKLOG.md or PLAN.md (re-feed unchanged)"
    else
      printf '%s\n' "$hb_out"
      cat "$hb_tmp/hb_err.txt"
      fault "stop hook let missing telemetry sources change the re-feed"
    fi

    # E4: six of fourteen dayjs and pyportfolioopt runs died at the tail
    # with the work done and only the declaration outstanding. When the
    # ledger is empty and the inventory swept, the run is inside the
    # convergence sequence, and the hook grants it two more iterations -
    # once, mechanically, on conditions it already computes.
    hb_write_journal 3 3
    hb_write_backlog_counts 0 0 0
    hb_write_plan_full none \
      '- [x] core: swept at abc1234 - all entry points probed' \
      '- [~] plots: unreachable on this host - no display'
    hb_write_state sess-1 3 3
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'CLOSING EXTENSION' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'This is jeffy iteration 4 of 5' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'RUN STATE: iteration 4 of 5; 1 remain after it' \
      && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'ITERATION HYGIENE' \
      && grep -q '^iteration: 4$' "$hb_state" \
      && grep -q '^max_iterations: 5$' "$hb_state" \
      && grep -q '^extension_granted: 1$' "$hb_state"; then
      pass "stop hook grants the one-time closing extension at budget exhaustion with an empty ledger and a swept inventory"
    else
      printf '%s\n' "$hb_out"
      grep '^iteration: \|^max_iterations: \|^extension_granted: ' "$hb_state" 2>/dev/null
      fault "stop hook ended a run that had only its convergence sequence left"
    fi

    # Same shape, but the run has spent every invocation any cap could grant.
    # There is no convergence sequence left for the window to buy - it cannot
    # re-invoke, so it cannot produce the verdict a declaration needs - and
    # two more iterations would only move the same blocked ending two turns
    # later. Bounded at the absolute cap for the same reason the declaration
    # check is: below it a legal endgame still exists, and the extension is
    # exactly what pays for it.
    hb_write_journal_entries \
      '## iter 1/3 | sess-1-000000 | 2026-01-01 | EVALUATOR | audit:::Verification: Evaluator: REJECT - one.' \
      '## iter 2/3 | sess-1-000000 | 2026-01-01 | EVALUATOR | audit:::Verification: Evaluator: REJECT - two.' \
      '## iter 3/3 | sess-1-000000 | 2026-01-01 | EVALUATOR | audit:::Verification: Evaluator: REJECT - three.'
    hb_write_state sess-1 3 3
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
      pass "stop hook withholds the closing extension from a run past every invocation cap"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook extended a run that could no longer produce a verdict to declare on"
    fi
    hb_write_journal 3 3

    # The bound: the flag is the whole of it. A run that already took its
    # extension ends at the new budget exactly the way it ended at the old
    # one, so the escape cannot be taken twice.
    hb_write_state_extra sess-1 3 3 'extension_granted: 1'
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
      pass "stop hook ends the run at budget exhaustion when the closing extension was already granted"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook granted a second closing extension"
    fi

    # The conditions: blocking open work or an unswept row means the run is
    # not in its convergence sequence, and the budget is the budget. The
    # counts helper writes task lines with no severity at all, so this case
    # is also the fail-closed proof: a line the parse cannot read blocks the
    # grant exactly as the declaration's floor blocks on it (P0-4).
    hb_write_backlog_counts 1 0 0
    hb_write_state sess-1 3 3
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
      pass "stop hook ends the run at budget exhaustion while a task with no parseable severity is open (fails closed, no extension)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook extended a run past a task line whose severity it could not parse"
    fi

    # P0-4: the grant's ledger test is the severity floor, not an empty
    # ledger. The canonical endgame under P0-2 - swept map, zero open High
    # or Medium, carried Lows named on the record - is exactly the shape the
    # window exists for, and the raw-count test could never grant to it.
    # Live instance: claude-code-action attempt 2 run 3 reached its last
    # iteration carrying two accurately scored Lows with all 28 rows swept.
    hb_write_journal 3 3
    hb_write_plan_full none '- [x] core: swept at abc1234 - all entry points probed'
    {
      printf '# Backlog\n\n## Now\n\n'
      printf -- '- [ ] L1 (Low, docs, clarity): carried low one. Acceptance: x.\n'
      printf -- '- [ ] L2 (Low, tests, hygiene): carried low two. Acceptance: x.\n'
      printf '\n## Next\n\n## Later\n\n## Converged\n\n'
    } > "$hb_proj/BACKLOG.md"
    hb_write_state sess-1 3 3
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'CLOSING EXTENSION' \
      && grep -q '^max_iterations: 5$' "$hb_state" \
      && grep -q '^extension_granted: 1$' "$hb_state" \
      && grep -q '^extension_lows: 2$' "$hb_state"; then
      pass "stop hook grants the closing extension over carried Lows (zero High/Medium, swept inventory) and records their count"
    else
      printf '%s\n' "$hb_out"
      grep '^iteration: \|^max_iterations: \|^extension_granted: ' "$hb_state" 2>/dev/null
      fault "stop hook refused the extension to the severity floor's own canonical endgame shape"
    fi

    # The floor's other face: one open Medium still refuses the grant.
    hb_write_journal 3 3
    hb_write_backlog '- [ ] M1 (Medium, runtime, correctness): open medium. Acceptance: x.' ''
    hb_write_plan_full none '- [x] core: swept at abc1234 - all entry points probed'
    hb_write_state sess-1 3 3
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
      pass "stop hook still withholds the closing extension past an open Medium"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook granted a closing extension over an open Medium"
    fi

    # And the window granted with carried Lows must survive them: before
    # P0-4 the refill guard read the same raw counts, so the Lows the grant
    # accepted killed the window one turn later as a false refill. This
    # fixture carries no extension_lows key - the pre-1.11.0 granted shape -
    # so it also proves the Low-delta arm fails open where it cannot
    # evaluate, leaving the High/Medium arm as the only guard.
    hb_write_journal_entries '## iter 4/5 | sess-1-000000 | 2026-01-01 | T7 | done:::Task: closed T7.'
    {
      printf '# Backlog\n\n## Now\n\n'
      printf -- '- [ ] L1 (Low, docs, clarity): carried low one. Acceptance: x.\n'
      printf -- '- [ ] L2 (Low, tests, hygiene): carried low two. Acceptance: x.\n'
      printf '\n## Next\n\n## Later\n\n## Converged\n\n'
    } > "$hb_proj/BACKLOG.md"
    hb_write_plan_full none '- [x] core: swept at abc1234 - all entry points probed'
    hb_write_state_extra sess-1 4 5 'extension_granted: 1'
    hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && grep -q '^iteration: 5$' "$hb_state" \
      && ! grep -q 'refilled inside the closing extension' "$hb_tmp/hb_err.txt"; then
      pass "stop hook carries a granted window over its own carried Lows (no false refill)"
    else
      printf '%s\n' "$hb_out"
      cat "$hb_tmp/hb_err.txt"
      fault "stop hook read the Lows a window was granted with as a refill and killed it"
    fi

    # The other face of the snapshot: a Low FILED inside the window - the
    # count rising above what the grant recorded - is discovered work the
    # prompt routes to the run report, and a ledger line for it is a genuine
    # refill. The window ends honestly, named as a new-Low refill.
    hb_write_journal_entries '## iter 4/5 | sess-1-000000 | 2026-01-01 | T8 | done:::Task: closed T8, filed discovered L2.'
    {
      printf '# Backlog\n\n## Now\n\n'
      printf -- '- [ ] L1 (Low, docs, clarity): carried low one. Acceptance: x.\n'
      printf -- '- [ ] L2 (Low, tests, hygiene): filed inside the window. Acceptance: x.\n'
      printf '\n## Next\n\n## Later\n\n## Converged\n\n'
    } > "$hb_proj/BACKLOG.md"
    hb_write_plan_full none '- [x] core: swept at abc1234 - all entry points probed'
    hb_write_state_extra sess-1 4 5 'extension_granted: 1' 'extension_lows: 1'
    hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
      && grep -q 'refilled inside the closing extension with new Low tasks' "$hb_tmp/hb_err.txt"; then
      pass "stop hook ends the window when a Low is filed inside it (count above the grant's snapshot)"
    else
      printf '%s\n' "$hb_out"
      cat "$hb_tmp/hb_err.txt"
      fault "stop hook let a Low filed inside the window ride as carried"
    fi

    # And with the key present and no delta, the window continues: the
    # snapshot discriminates, it does not merely re-arm the old raw test.
    hb_write_journal_entries '## iter 4/5 | sess-1-000000 | 2026-01-01 | T8 | done:::Task: closed T8.'
    {
      printf '# Backlog\n\n## Now\n\n'
      printf -- '- [ ] L1 (Low, docs, clarity): carried low one. Acceptance: x.\n'
      printf -- '- [ ] L2 (Low, tests, hygiene): carried low two. Acceptance: x.\n'
      printf '\n## Next\n\n## Later\n\n## Converged\n\n'
    } > "$hb_proj/BACKLOG.md"
    hb_write_plan_full none '- [x] core: swept at abc1234 - all entry points probed'
    hb_write_state_extra sess-1 4 5 'extension_granted: 1' 'extension_lows: 2'
    hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && grep -q '^iteration: 5$' "$hb_state" \
      && ! grep -q 'refilled inside the closing extension' "$hb_tmp/hb_err.txt"; then
      pass "stop hook continues the window over exactly the Lows the grant recorded (snapshot discriminates)"
    else
      printf '%s\n' "$hb_out"
      cat "$hb_tmp/hb_err.txt"
      fault "stop hook's Low snapshot fired without a delta"
    fi

    # The endgame-cost note reads the same severity count as the grant: a
    # run at zero High/Medium with a swept map is told the convergence
    # sequence's cost even when its carried Lows keep the raw counts
    # nonzero - the exact runs a note keyed to an empty ledger never
    # reached.
    hb_write_journal 1 3
    {
      printf '# Backlog\n\n## Now\n\n'
      printf -- '- [ ] L1 (Low, docs, clarity): carried low one. Acceptance: x.\n'
      printf '\n## Next\n\n## Later\n\n## Converged\n\n'
    } > "$hb_proj/BACKLOG.md"
    hb_write_plan_full none '- [x] core: swept at abc1234 - all entry points probed'
    hb_write_state sess-1 1 3
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'Only the convergence sequence remains' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'Open Lows are carried to the declaration'; then
      pass "stop hook states the endgame cost over carried Lows (severity count, not raw totals)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook kept the endgame-cost note from the canonical severity-floor endgame"
    fi
    rm -f "$hb_state"

    hb_write_backlog_counts 0 0 0
    hb_write_plan_full none \
      '- [x] core: swept at abc1234 - all entry points probed' \
      '- [ ] plots: unswept'
    hb_write_state sess-1 3 3
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
      pass "stop hook ends the run at budget exhaustion while the Surface inventory lists an unswept row (no extension)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook extended a run with unswept surface"
    fi

    # The once-only flag is written by the rewriter at the frontmatter close,
    # so a state file that never closes its frontmatter cannot record it: the
    # conditions stay true, the budget climbs by two every second turn, and
    # nothing ever accumulates to stop it. Every other condition here is the
    # accepting one, so the case turns on the missing second --- alone.
    hb_write_backlog_counts 0 0 0
    hb_write_plan_full none '- [x] core: swept at abc1234 - all entry points probed'
    {
      printf -- '---\n'
      printf 'session_id: sess-1\n'
      printf 'iteration: 3\n'
      printf 'max_iterations: 3\n'
      printf 'prompt_path: %s\n' "$hb_tmp/prompt.txt"
      printf 'focus: speed\n'
      printf 'completion_promise: JEFFY CONVERGED\n'
      printf 'started_at: 2026-01-01T00:00:00Z\n'
      printf 'Jeffy loop state.\n'
    } > "$hb_state"
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
      pass "stop hook ends the run at budget exhaustion on a state file whose frontmatter never closes (no extension)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook granted a closing extension it could never record as granted"
    fi

    # The grant belongs to the budget boundary, not to everything past it. A
    # hand-lowered budget leaves the iteration already beyond max, and an
    # extension there re-feeds arithmetic that runs negative ("-5 remain
    # after it") straight to the model. Ending the run says nothing at all,
    # which is what the stderr and stdout assertions below check.
    hb_write_state sess-1 10 5
    hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
      && ! grep -q -- '-[0-9]' "$hb_tmp/hb_err.txt"; then
      pass "stop hook ends the run when the iteration is already past max (no extension, no negative arithmetic)"
    else
      printf '%s\n' "$hb_out"
      cat "$hb_tmp/hb_err.txt"
      fault "stop hook extended a run whose iteration had already passed its budget"
    fi

    # The near-death shape bat actually died of: the promise fires at the
    # last iteration and a check rejects it, so today the run ends with the
    # rejection on stderr and nobody to read it. The violation and the
    # extension ride the same re-feed.
    hb_write_journal 3 3
    hb_write_backlog_counts 0 0 0
    hb_write_plan_full 'exit 3' '- [x] core: swept at abc1234 - all entry points probed'
    hb_write_state sess-1 3 3
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'CONVERGENCE REJECTED' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'exited 3' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'CLOSING EXTENSION' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'RUN STATE: iteration 4 of 5' \
      && ! grep -q 'budget is spent' "$hb_tmp/hb_err.txt" \
      && grep -q '^iteration: 4$' "$hb_state" \
      && grep -q '^max_iterations: 5$' "$hb_state" \
      && grep -q '^extension_granted: 1$' "$hb_state"; then
      pass "stop hook grants the closing extension when a promise is rejected at the last iteration (violation rides the re-feed)"
    else
      printf '%s\n' "$hb_out"
      cat "$hb_tmp/hb_err.txt"
      fault "stop hook discarded a repairable convergence rejection at the budget"
    fi

    # E8 round trip: the extension writes two keys the rewriter now owns,
    # and every ordinary re-feed after it must leave both exactly as it
    # found them. A max_iterations the rewriter rewrites unconditionally
    # would extend the run again on every turn.
    hb_write_journal 3 3
    hb_write_backlog_counts 0 0 0
    hb_write_plan_full none '- [x] core: swept at abc1234 - all entry points probed'
    hb_write_state sess-1 3 3
    hb_out="$(hb_run sess-1 'still working' '')"
    hb_out2=""
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && grep -q '^max_iterations: 5$' "$hb_state"; then
      hb_write_journal 4 5
      hb_out2="$(hb_run sess-1 'still working' '')"
    fi
    if [ -n "$hb_out2" ] \
      && [ "$(printf '%s' "$hb_out2" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && ! printf '%s' "$hb_out2" | jq -r '.reason' | grep -qF 'CLOSING EXTENSION' \
      && printf '%s' "$hb_out2" | jq -r '.reason' | grep -qF 'RUN STATE: iteration 5 of 5; 0 remain after it' \
      && grep -q '^iteration: 5$' "$hb_state" \
      && grep -q '^max_iterations: 5$' "$hb_state" \
      && grep -q '^extension_granted: 1$' "$hb_state"; then
      pass "stop hook carries the granted extension through later re-feeds untouched (only the iteration advances)"
    else
      printf '%s\n%s\n' "$hb_out" "$hb_out2"
      grep '^iteration: \|^max_iterations: \|^extension_granted: ' "$hb_state" 2>/dev/null
      fault "stop hook did not round-trip max_iterations and extension_granted after granting the extension"
    fi
    rm -f "$hb_state"

    # B: a Verify command ending in a truncator reports the truncator's exit
    # status, not the suite's - libuv's first suite run reported exit 0 over
    # 13 failing tests. The hook must refuse the declaration and name it.
    hb_proj="$hb_tmp/proj"; hb_state="$hb_proj/.claude/jeffy-loop.local.md"
    hb_write_journal 2 3
    hb_write_backlog "" ""
    hb_write_plan 'false | tail -n 1'
    hb_write_state sess-1 2 3
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'ends in tail' \
      && [ -f "$hb_state" ]; then
      pass "stop hook rejects a Verify command whose last pipeline stage is a truncator"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook accepted a truncator-terminated Verify command (exit status is tail's, not the suite's)"
    fi
    # The lint fires only when a pipe exists: a bare 'cat file' gate is the
    # user's own legitimate command and its exit status is its own.
    hb_write_journal 2 3
    hb_write_plan 'true'
    hb_write_state sess-1 2 3
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ ! -f "$hb_state" ]; then
      pass "stop hook still accepts a pipe-free Verify command at the converged stop"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook rejected a clean pipe-free Verify command"
    fi

    # F: the +2 exists for the convergence sequence, not new work. In the
    # python-dotenv run that first fired it live, an audit inside the window
    # filed a Medium, the fix consumed the window, the gate was never
    # reached, and the run ended unconverged anyway. If the ledger refills
    # inside the window from anything but the evaluator gate's own filings,
    # the hook ends the run honestly: out of budget, tasks kept for next run.
    # The refill source here is a task entry: an AUDIT inside the window now
    # ends the run one check earlier with its own message (the P1-14
    # scenarios below own that shape), so this fixture keeps the refill path
    # independently covered.
    hb_proj="$hb_tmp/proj"; hb_state="$hb_proj/.claude/jeffy-loop.local.md"
    hb_write_journal_entries '## iter 4/5 | sess-1-000000 | 2026-01-01 | T7 | done:::Task: closed T7, filed discovered subtask F1.'
    hb_write_backlog '- [ ] F1 (Medium, runtime, correctness): filed inside the extension window. Acceptance: x.' ''
    hb_write_plan_full none '- [x] core: swept at abc1234 - probed'
    hb_write_state_extra sess-1 4 5 'extension_granted: 1'
    hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/f_err.txt")"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
      && grep -qF 'refilled inside the closing extension' "$hb_tmp/f_err.txt"; then
      pass "stop hook ends the run when non-evaluator work refills the ledger inside the closing extension"
    else
      printf '%s\n' "$hb_out"; cat "$hb_tmp/f_err.txt"
      fault "stop hook let the closing extension be consumed by new work (the budget signal went dishonest)"
    fi
    # The exception: tasks the evaluator gate itself filed are what the
    # one-transaction endgame exists for, and the window must let them run.
    hb_write_journal_entries '## iter 4/5 | sess-1-000000 | 2026-01-01 | EVALUATOR | audit:::Task: gate REJECT filed E1.'
    hb_write_backlog '- [ ] E1 (Medium, runtime, correctness): filed by the evaluator gate. Acceptance: x.' ''
    hb_write_plan_full none '- [x] core: swept at abc1234 - probed'
    hb_write_state_extra sess-1 4 5 'extension_granted: 1'
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && grep -q '^iteration: 5$' "$hb_state"; then
      pass "stop hook lets evaluator-filed tasks proceed inside the extension window (one-transaction endgame)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook killed the extension window on the evaluator gate's own filings"
    fi

    # E5: the hook contains no notion of the evaluator gate, and six of
    # thirteen corpus convergences carried no evaluator verdict at all. The
    # gate is where the audits' misses were found, so the declaration is
    # where its verdict is read. Needs a repository: the promise path only
    # means something where the Converged hash can name a commit.
    if command -v git >/dev/null 2>&1; then
      hb_saved_proj="$hb_proj"; hb_saved_state="$hb_state"
      hb_proj="$hb_tmp/p2proj"; hb_state="$hb_proj/.claude/jeffy-loop.local.md"
      mkdir -p "$hb_proj/.claude"
      hb_git init -q -b main
      printf 'v1\n' > "$hb_proj/product.txt"
      hb_write_evaluator_artifact
      hb_git add product.txt .jeffy >/dev/null
      hb_git commit -q -m c1
      hb_p2_c1="$(hb_git rev-parse HEAD)"
      hb_p2_row='- [x] core: swept at abc1234 - all entry points probed'
      # Everything except the journal is held at the accepting shape, so
      # each case below turns on the closing entry alone.
      hb_p2_fixture() {
        hb_write_state sess-1 2 3
        hb_write_plan_full 'exit 0' "$hb_p2_row"
        hb_write_backlog '' "Converged: $hb_p2_c1 - 2026-01-01"
      }

      # The earlier entry carries a PASS and the closing entry does not, so
      # a check that greps the file rather than the closing entry accepts a
      # declaration the gate never saw.
      hb_write_journal_entries \
        '## iter 1/3 | sess-1-000000 | 2026-01-01 | AUDIT | audit:::Verification: Evaluator: PASS - clean sweep.' \
        '## iter 2/3 | sess-1-000000 | 2026-01-01 | T2 | done:::Verification: the suite is green.'
      hb_p2_fixture
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'CONVERGENCE REJECTED' \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'records no Evaluator verdict' \
        && grep -q '^iteration: 3$' "$hb_state"; then
        pass "stop hook rejects a declaration whose closing entry records no Evaluator verdict"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook accepted a convergence no evaluator gate ever answered"
      fi

      hb_write_journal_entries \
        '## iter 1/3 | sess-1-000000 | 2026-01-01 | AUDIT | audit:::Verification: audit only.' \
        '## iter 2/3 | sess-1-000000 | 2026-01-01 | T2 | converged:::Verification: Evaluator: PASS - ok'
      hb_p2_fixture
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook accepts a declaration whose closing entry records Evaluator: PASS"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook rejected a declaration carrying a passing evaluator verdict"
      fi

      # ta recorded the gate unavailable twice under a session constraint
      # that forbade sub-agents, and converged on it. Through 1.6.0 that
      # satisfied the stop, which let the graded party certify its own gate
      # away in eleven characters. From 1.7.0 a disclosed unavailability is
      # still a verdict the run must record - and it ends the run blocked
      # rather than converging it.
      hb_write_journal_entries \
        '## iter 1/3 | sess-1-000000 | 2026-01-01 | AUDIT | audit:::Verification: audit only.' \
        '## iter 2/3 | sess-1-000000 | 2026-01-01 | T2 | converged:::Verification: Evaluator: unavailable (no sub-agents in this session)'
      hb_p2_fixture
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'CONVERGENCE REJECTED' \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'the adversarial gate is not optional' \
        && grep -q '^iteration: 3$' "$hb_state"; then
        pass "stop hook refuses to converge on Evaluator: unavailable (the self-certified bypass is closed)"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook let a run certify its own evaluator gate away as unavailable"
      fi

      # The ratchet never invokes the gate by design - it re-declares an
      # already-converged tree - and yfinance's accepted ratchet
      # re-declaration is the precedent the exemption is written from.
      hb_write_journal_entries \
        '## iter 1/3 | sess-1-000000 | 2026-01-01 | SALVAGE | salvage:::Task: recovered the state files.' \
        '## iter 2/3 | sess-1-000000 | 2026-01-01 | RATCHET | converged:::Task: re-declared an unchanged tree.'
      hb_p2_fixture
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook exempts a RATCHET closing entry from the evaluator requirement"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook demanded an evaluator verdict from a ratchet re-declaration"
      fi

      # Rotation is an additional entry, not a closing one: a closing
      # iteration that pushes JOURNAL.md past 500 lines appends its ROTATION
      # entry after the declaration, and a scan anchored at the last heading
      # reads a window with no verdict in it and rejects a declaration that
      # carries one. The anchor is the last primary entry.
      hb_write_journal_entries \
        '## iter 1/3 | sess-1-000000 | 2026-01-01 | AUDIT | audit:::Verification: audit only.' \
        '## iter 2/3 | sess-1-000000 | 2026-01-01 | T2 | converged:::Verification: Evaluator: PASS - ok' \
        '## iter 2/3 | sess-1-000000 | 2026-01-01 | ROTATION | rotation:::Task: moved 40 entries to JOURNAL-archive.md.'
      hb_p2_fixture
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook accepts a declaration whose ROTATION entry lands after the closing entry's verdict"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook rejected a declaration because a rotation entry followed it"
      fi

      # The three shapes that used to fail open here, and no longer do. Each
      # one let the run decide whether the gate applied to it by choosing what
      # it wrote in its own journal - stamp the wrong id, omit the heading,
      # delete the file - and the converged-tree test cannot see any of it,
      # because JOURNAL.md is loop state there. The rotation rule keeps the
      # last ten entries, so a closing entry written this turn is never among
      # the rotated, which is what the fail-open was for. All three now
      # re-feed with the evidence rather than ending anything, so a genuine
      # heading defect is repairable inside the budget.
      hb_write_journal_entries \
        '## iter 2/3 | sess-1-000000 | 2026-01-01 | ROTATION | rotation:::Task: moved 40 entries to JOURNAL-archive.md.'
      hb_p2_fixture
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'holds no primary entry headed with the run id' \
        && grep -q '^iteration: 3$' "$hb_state"; then
        pass "stop hook refuses a declaration whose run wrote only ROTATION entries (no primary entry, no verdict)"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt"
        fault "stop hook let a run with no primary journal entry skip the evaluator check"
      fi

      rm -f "$hb_proj/JOURNAL.md"
      hb_p2_fixture
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'JOURNAL.md is missing' \
        && grep -q '^iteration: 3$' "$hb_state"; then
        pass "stop hook refuses a declaration with JOURNAL.md deleted (the journal is not an optional file at the stop)"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt"
        fault "stop hook accepted a convergence over a deleted journal"
      fi

      hb_write_journal_entries \
        '## iter 9/9 | sess-9-999999 | 2026-01-01 | T9 | done:::Verification: Evaluator: PASS - a different run entirely.'
      hb_p2_fixture
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'holds no primary entry headed with the run id' \
        && grep -q '^iteration: 3$' "$hb_state"; then
        pass "stop hook refuses a declaration whose journal carries no entry under this run's id"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt"
        fault "stop hook let a heading stamped with another run's id skip the evaluator check"
      fi

      # --- P1-14: the +2 window never buys an audit ----------------------
      # TOML-M iteration 13 ran a full fresh-evidence audit inside the
      # closing extension and iteration 14's declaration cited it as the
      # clean-audit precondition; dotenv run 3 had already proven the shape.
      # Every other gate is blind to it - the ledger stays empty, the rows
      # stay swept, the verdict reads PASS - so the hook must end the run
      # the moment an AUDIT primary entry for this run sits at an iteration
      # inside the window, whether or not a promise follows.
      hb_write_journal_entries \
        '## iter 2/4 | sess-1-000000 | 2026-01-01 | T2 | done:::Verification: green.' \
        '## iter 3/4 | sess-1-000000 | 2026-01-01 | AUDIT | audit:::Verification: clean audit, filed nothing.'
      hb_p2_fixture
      hb_write_state_extra sess-1 3 4 'extension_granted: 1'
      hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
        && grep -q 'never an audit' "$hb_tmp/hb_err.txt"; then
        pass "stop hook ends the run when an AUDIT entry lands inside the closing extension window"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt" 2>/dev/null
        fault "stop hook let a full audit run inside the closing extension window"
      fi

      # The declaration variant: the same journal one turn later, promise
      # attached. The convergence must be refused for the same reason, not
      # accepted because the ledger is empty and the verdict reads PASS.
      hb_write_journal_entries \
        '## iter 2/4 | sess-1-000000 | 2026-01-01 | T2 | done:::Verification: green.' \
        '## iter 3/4 | sess-1-000000 | 2026-01-01 | AUDIT | audit:::Verification: clean audit, filed nothing.' \
        '## iter 4/4 | sess-1-000000 | 2026-01-01 | EVALUATOR | converged:::Verification: Evaluator: PASS - ok'
      hb_p2_fixture
      hb_write_state_extra sess-1 4 4 'extension_granted: 1'
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
        && grep -q 'never an audit' "$hb_tmp/hb_err.txt"; then
        pass "stop hook refuses a declaration whose clean audit was manufactured inside the extension window"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt" 2>/dev/null
        fault "stop hook accepted a convergence resting on an extension-window audit"
      fi

      # The legal window shape stays legal: clean audit BEFORE the window,
      # gate and declaration inside it. That is the sequence the extension
      # exists to buy, and the new bound must not tax it.
      hb_write_journal_entries \
        '## iter 2/4 | sess-1-000000 | 2026-01-01 | AUDIT | audit:::Verification: clean audit before the window.' \
        '## iter 4/4 | sess-1-000000 | 2026-01-01 | EVALUATOR | converged:::Verification: Evaluator: PASS - ok'
      hb_p2_fixture
      hb_write_state_extra sess-1 4 4 'extension_granted: 1'
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
        && ! grep -q 'never an audit' "$hb_tmp/hb_err.txt"; then
        pass "stop hook accepts the gate-only extension window with the clean audit before it"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt" 2>/dev/null
        fault "stop hook rejected the legal extension shape - clean audit pre-window, gate inside"
      fi

      # The key-off bound: without an extension there is no window, and an
      # audit at max-1 is an ordinary audit. The rule must read the flag,
      # never the arithmetic alone.
      hb_write_journal_entries \
        '## iter 2/3 | sess-1-000000 | 2026-01-01 | AUDIT | audit:::Verification: clean audit at the budget edge.'
      hb_p2_fixture
      hb_write_state sess-1 2 3
      hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && ! grep -q 'never an audit' "$hb_tmp/hb_err.txt"; then
        pass "stop hook leaves an audit at the budget edge alone when no extension was granted"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook applied the extension-window audit rule to a run with no extension"
      fi

      # The run-token bound, the same one the ceremony exemption and the
      # duplicate-index check already carry: on a state file with no
      # started_at the run id is the bare session prefix every run of the
      # session shares, so a PRIOR run's audit at a high iteration would end
      # THIS run out of budget. No token, no scan.
      hb_write_journal_entries \
        '## iter 3/4 | sess-1 | 2026-01-01 | AUDIT | audit:::Verification: an earlier run of this session.'
      hb_p2_fixture
      {
        printf -- '---\n'
        printf 'session_id: sess-1\niteration: 3\nmax_iterations: 4\n'
        printf 'prompt_path: %s\n' "$hb_tmp/prompt.txt"
        printf 'focus: speed\ncompletion_promise: JEFFY CONVERGED\n'
        printf 'extension_granted: 1\n'
        printf -- '---\nJeffy loop state.\n'
      } > "$hb_state"
      hb_out="$(hb_run sess-1 'still working' '' 2>"$hb_tmp/hb_err.txt")"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && ! grep -q 'never an audit' "$hb_tmp/hb_err.txt"; then
        pass "stop hook withholds the extension-window audit scan from a state file carrying no run token"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt" 2>/dev/null
        fault "stop hook let a prior run's audit end this run through a shared session prefix"
      fi

      # --- P1-2: a PASS has to point at something ------------------------
      # Through 1.6.0 the verdict was a substring in a file the graded party
      # writes, and nothing distinguished a real invocation from eleven typed
      # characters. The gate now leaves .jeffy/evaluator/<run-id>-<n>.md naming
      # the commands it ran and their real exit statuses. Authorship is
      # unenforceable at the shell layer and this does not pretend otherwise;
      # what it buys is that faking a PASS costs a fabricated forensic record
      # the checkpoint commits and the repository keeps.
      hb_p2_pass_journal() {
        hb_write_journal_entries \
          '## iter 1/3 | sess-1-000000 | 2026-01-01 | AUDIT | audit:::Verification: clean audit.' \
          '## iter 2/3 | sess-1-000000 | 2026-01-01 | EVALUATOR | converged:::Verification: Evaluator: PASS - ok'
      }

      hb_p2_pass_journal
      hb_p2_fixture
      mv "$hb_proj/.jeffy/evaluator/sess-1-000000-1.md" "$hb_tmp/p2-artifact.md"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'is not a file with content' \
        && grep -q '^iteration: 3$' "$hb_state"; then
        pass "stop hook rejects Evaluator: PASS with no evaluator artifact for this run"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook accepted a PASS that pointed at nothing"
      fi

      # An artifact belonging to some other run is not this run's evidence.
      # The gate's verdict answers the tree this run produced, so the file
      # the hook demands is keyed to the run id its journal headings carry.
      hb_write_evaluator_artifact sess-9-999999
      hb_git add .jeffy >/dev/null 2>&1
      hb_git commit -q -m foreign-artifact >/dev/null 2>&1
      hb_p2_pass_journal
      hb_p2_fixture
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'is not a file with content' \
        && grep -q '^iteration: 3$' "$hb_state"; then
        pass "stop hook rejects an evaluator artifact filed under another run's id"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook accepted another run's evaluator artifact as this run's evidence"
      fi
      rm -f "$hb_proj/.jeffy/evaluator/sess-9-999999-1.md"
      hb_git add -A .jeffy >/dev/null 2>&1
      hb_git commit -q -m drop-foreign-artifact >/dev/null 2>&1

      # Uncommitted is not evidence. .jeffy/ is excluded from the
      # converged-tree test above - deliberately, so a refreshed probe
      # battery is not read as a product change - which means an artifact
      # left loose in the working tree can be rewritten with nothing in the
      # record to show for it. The checkpoint is what makes it durable.
      cp "$hb_tmp/p2-artifact.md" "$hb_proj/.jeffy/evaluator/sess-1-000000-1.md"
      hb_p2_pass_journal
      hb_p2_fixture
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'is not committed in HEAD' \
        && grep -q '^iteration: 3$' "$hb_state"; then
        pass "stop hook rejects an evaluator artifact left uncommitted in the working tree"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook accepted a PASS whose artifact was never checkpointed"
      fi

      # Committed and clean is the accepting shape, and it is the one every
      # other declaration in this file now rides on.
      hb_git add .jeffy >/dev/null 2>&1
      hb_git commit -q -m evaluator-artifact >/dev/null 2>&1
      hb_p2_pass_journal
      hb_p2_fixture
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook accepts a PASS backed by this run's committed evaluator artifact"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook rejected a declaration whose evaluator artifact was committed"
      fi

      # The escape hatch that is not one. An earlier draft skipped the
      # committed check wherever git said the artifact was ignored, on the
      # reasoning that a project which ignores .jeffy/ cannot commit it - but
      # .git/info/exclude is writable by the run itself, is tracked by
      # nothing, and shows up in no diff, so the graded party could open that
      # hatch mid-run and walk through it. The requirement is unconditional:
      # the artifact is in HEAD or the declaration is refused, and a project
      # that ignores .jeffy/ un-ignores this one directory. The rule goes in
      # .git/info/exclude here rather than a tracked .gitignore precisely
      # because that is the shape a run could arrange for itself.
      printf '.jeffy/\n' >> "$hb_proj/.git/info/exclude"
      hb_git rm -q -r --cached .jeffy >/dev/null 2>&1
      hb_git commit -q -m untrack-jeffy >/dev/null 2>&1
      hb_p2_pass_journal
      hb_p2_fixture
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'is not committed in HEAD' \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'un-ignore .jeffy/evaluator/' \
        && grep -q '^iteration: 3$' "$hb_state"; then
        pass "stop hook refuses an artifact the run put beyond git's reach through .git/info/exclude"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt" 2>/dev/null
        fault "stop hook let a run open its own escape hatch by ignoring the artifact it had to commit"
      fi
      # Put the artifact back in the index for the cases below.
      hb_git rm -q -r --cached . >/dev/null 2>&1
      : > "$hb_proj/.git/info/exclude"
      hb_recommit_artifact
      hb_git add -f product.txt >/dev/null 2>&1
      hb_git commit -q -m retrack >/dev/null 2>&1

      # --- P1-2b: what "an artifact" and "a verdict" have to mean ----------
      # An adversarial pass over the first cut found four ways to satisfy the
      # gate without one, and each of these is one of them.

      # A directory. test -s is true of a directory wherever directories
      # carry a nonzero size, which is every Linux and macOS filesystem the
      # corpus runs on, and git status says nothing about an untracked
      # directory with no files in it - so mkdir passed both halves. The
      # regular-file test is what makes the case read the same everywhere.
      hb_p2_art_dir="$hb_proj/.jeffy/evaluator/sess-1-000000-1.md"
      rm -f "$hb_p2_art_dir"; mkdir -p "$hb_p2_art_dir"
      hb_p2_pass_journal
      hb_p2_fixture
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'is not a file with content'; then
        pass "stop hook refuses a directory standing in for the evaluator artifact"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook accepted mkdir as an evaluator artifact"
      fi
      rmdir "$hb_p2_art_dir"
      hb_recommit_artifact

      # Committed, then rewritten. The test is byte-identity against the copy
      # in HEAD rather than the absence of a git status line, because git is
      # silent about a path it has been told to ignore, a path inside a nested
      # repository, and a path marked assume-unchanged - three ways to rewrite
      # the evidence with the negative test none the wiser.
      printf 'rewritten after the gate ran\n' > "$hb_proj/.jeffy/evaluator/sess-1-000000-1.md"
      hb_git update-index --assume-unchanged .jeffy/evaluator/sess-1-000000-1.md >/dev/null 2>&1
      hb_p2_pass_journal
      hb_p2_fixture
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'differs from the copy committed in HEAD'; then
        pass "stop hook refuses an evaluator artifact rewritten after it was committed, even under assume-unchanged"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook read a tampered artifact as committed because git stayed quiet about it"
      fi
      hb_git update-index --no-assume-unchanged .jeffy/evaluator/sess-1-000000-1.md >/dev/null 2>&1
      hb_git checkout -q -- .jeffy/evaluator/sess-1-000000-1.md 2>/dev/null

      # An artifact older than the tree it certifies. The contract re-invokes
      # the gate in the iteration that declares - a PASS that does not declare
      # in its own iteration does not carry forward - so a gate run three
      # iterations and two product commits ago answers a tree that is gone.
      hb_p2_stale_art="$(hb_git rev-parse HEAD)"
      printf 'v2\n' > "$hb_proj/product.txt"
      hb_git add product.txt >/dev/null 2>&1
      hb_git commit -q -m 'jeffy: later product work' >/dev/null 2>&1
      hb_p2_late="$(hb_git rev-parse HEAD)"
      hb_p2_pass_journal
      hb_write_state sess-1 2 3
      hb_write_plan_full 'exit 0' "$hb_p2_row"
      hb_write_backlog '' "Converged: $hb_p2_late - 2026-01-01"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'predates the Converged hash' \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'a re-invocation writes the next ordinal'; then
        pass "stop hook refuses a PASS whose artifact predates the commit the Converged line certifies, naming the ordinal remedy"
      else
        printf '%s\n' "$hb_out"
        printf 'artifact commit %s, converged %s\n' "$hb_p2_stale_art" "$hb_p2_late"
        fault "stop hook let a stale evaluator artifact certify work committed after it"
      fi
      hb_recommit_artifact
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook accepts the same declaration once the gate is re-invoked in the declaring iteration"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook rejected a declaration whose artifact postdates the Converged hash"
      fi

      # --- P1-16: one path per invocation, so the record survives a squash --
      # Keyed by run id alone, every re-invocation overwrote its predecessor
      # and the gate's forensic record was one version deep. A run that spent
      # three invocations published one verdict, the third; the earlier two
      # lived only as blobs in checkpoint commits, and a squash, rebase,
      # filtered export or shallow clone reduced the record to whatever came
      # last. On the tree that made this concrete, git log on that path
      # returned exactly one commit - the squash - and the earlier verdicts
      # survived only on a local branch no clone carries.
      hb_p2_ord_fixture() {
        hb_p2_pass_journal
        hb_write_state sess-1 2 3
        hb_write_plan_full 'exit 0' "$hb_p2_row"
        hb_write_backlog '' "Converged: $(hb_git rev-parse HEAD) - 2026-01-01"
      }

      # The highest ordinal is the verdict that answers this tree, so it is
      # the one that has to stand up - a committed ordinal 1 does not excuse
      # an ordinal 2 the checkpoint never captured.
      hb_write_evaluator_artifact sess-1-000000 2
      hb_p2_ord_fixture
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'sess-1-000000-2.md' \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'is not committed in HEAD'; then
        pass "stop hook binds the PASS to the highest evaluator invocation ordinal, not the newest committed one"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook read an older committed artifact while a later invocation sat uncommitted"
      fi

      hb_git add .jeffy >/dev/null 2>&1
      hb_git commit -q -m 'jeffy: evaluator artifact, invocation 2' >/dev/null 2>&1
      hb_p2_ord_fixture
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
        && [ -f "$hb_proj/.jeffy/evaluator/sess-1-000000-1.md" ] \
        && [ -f "$hb_proj/.jeffy/evaluator/sess-1-000000-2.md" ]; then
        pass "stop hook accepts a re-invocation as a second path, leaving the verdict it superseded in the tree"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook mishandled a run whose gate wrote two ordinal-keyed verdicts"
      fi

      # A run launched under a pre-1.8.0 engine wrote the single path, and
      # the loop is built to be relaunched over state files an older engine
      # left behind. Falling back is what keeps that run from being stranded
      # mid-arc by an upgrade.
      hb_git rm -q .jeffy/evaluator/sess-1-000000-1.md .jeffy/evaluator/sess-1-000000-2.md >/dev/null 2>&1
      hb_write_legacy_artifact sess-1-000000
      hb_git add .jeffy >/dev/null 2>&1
      hb_git commit -q -m 'jeffy: pre-1.8.0 single-path artifact' >/dev/null 2>&1
      hb_p2_ord_fixture
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
        && grep -q 'pre-1.8.0 single-path artifact' "$hb_tmp/hb_err.txt"; then
        pass "stop hook falls back to the pre-1.8.0 single-path evaluator artifact (stderr note)"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt"
        fault "stop hook stranded a run whose gate wrote the pre-1.8.0 artifact path"
      fi
      rm -f "$hb_proj/.jeffy/evaluator/sess-1-000000.md"
      hb_git rm -q --cached .jeffy/evaluator/sess-1-000000.md >/dev/null 2>&1
      hb_write_evaluator_artifact
      hb_git add -A .jeffy >/dev/null 2>&1
      hb_git commit -q -m 'jeffy: back to ordinal artifacts' >/dev/null 2>&1

      # --- P1-3 and P1-4: what terminal means, and what follows it ---------
      # The cap stays absolute, but the hook enforces only the bound it can
      # actually derive. The midpoint rule turns on when the first
      # invocation landed, which this hook does not compute, so two REJECTs
      # are left to the prompt: where the cap is 3 a second REJECT legally
      # precedes a third invocation, and that is the path opened for the run
      # whose first verdict was REJECT. Three REJECTs are past every cap the
      # contract can grant, whatever the closing entry claims.
      hb_p5_journal() { # $1... extra entries appended before the closing PASS entry
        hb_write_journal_entries "$@" \
          '## iter 2/3 | sess-1-000000 | 2026-01-01 | EVALUATOR | converged:::Verification: Evaluator: PASS - ok'
      }

      hb_p5_journal \
        '## iter 1/3 | sess-1-000000 | 2026-01-01 | AUDIT | audit:::Verification: clean audit.' \
        '## iter 1/3 | sess-1-000000 | 2026-01-01 | EVALUATOR | audit:::Verification: Evaluator: REJECT - one.' \
        '## iter 1/3 | sess-1-000000 | 2026-01-01 | EVALUATOR | audit:::Verification: Evaluator: REJECT - two.'
      hb_p2_ord_fixture_keep_journal() {
        hb_write_state sess-1 2 3
        hb_write_plan_full 'exit 0' "$hb_p2_row"
        hb_write_backlog '' "Converged: $(hb_git rev-parse HEAD) - 2026-01-01"
      }
      hb_p2_ord_fixture_keep_journal
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook still accepts a declaration after two REJECTs and a PASS (the cap-3 path stays open)"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook closed the third invocation the cap-3 run had earned"
      fi

      hb_p5_journal \
        '## iter 1/3 | sess-1-000000 | 2026-01-01 | EVALUATOR | audit:::Verification: Evaluator: REJECT - one.' \
        '## iter 1/3 | sess-1-000000 | 2026-01-01 | EVALUATOR | audit:::Verification: Evaluator: REJECT - two.' \
        '## iter 1/3 | sess-1-000000 | 2026-01-01 | EVALUATOR | audit:::Verification: Evaluator: REJECT - three.'
      hb_p2_ord_fixture_keep_journal
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'no invocation remains' \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'declaration deferred'; then
        pass "stop hook refuses a declaration past every invocation cap the contract can grant"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook accepted a PASS from a run that had spent every invocation it could have had"
      fi

      # The same bound read off the artifact set rather than the journal: a
      # fourth ordinal is a fourth invocation however the entries are typed.
      hb_write_evaluator_artifact sess-1-000000 4
      hb_git add .jeffy >/dev/null 2>&1
      hb_git commit -q -m 'jeffy: evaluator artifact, invocation 4' >/dev/null 2>&1
      hb_p5_journal '## iter 1/3 | sess-1-000000 | 2026-01-01 | AUDIT | audit:::Verification: clean audit.'
      hb_p2_ord_fixture_keep_journal
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'no invocation remains'; then
        pass "stop hook reads a fourth evaluator artifact ordinal as past the cap, whatever the journal says"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook let a fourth gate invocation declare because the journal did not admit to it"
      fi
      hb_git rm -q .jeffy/evaluator/sess-1-000000-4.md >/dev/null 2>&1
      hb_git commit -q -m 'jeffy: drop the fourth ordinal' >/dev/null 2>&1

      # The bound counts gate verdicts, not the word. An ordinary task entry
      # names the rejection that filed its task - "G1, filed by the gate at
      # iteration 5 under Evaluator: REJECT" is exactly how the prompt asks a
      # run to record provenance - and a substring scan over every primary
      # entry read those references as verdicts. A run one rejection into a
      # cap-3 budget then counted three and was refused as past every cap,
      # which is a FALSE REFUSAL of a legal convergence on the precise path
      # P1-3 opened: worse than the fail-open it replaced, because it breaks
      # runs that did everything right. Only EVALUATOR-typed entries carry a
      # verdict, so only they are counted.
      # The preceding scenario's git rm moved HEAD past the artifact commit,
      # so re-commit it first: otherwise this case is refused by the recency
      # check and proves nothing about the counter it exists to test.
      hb_recommit_artifact
      hb_write_journal_entries \
        '## iter 1/3 | sess-1-000000 | 2026-01-01 | AUDIT | audit:::Verification: clean audit.' \
        '## iter 1/3 | sess-1-000000 | 2026-01-01 | EVALUATOR | audit:::Verification: Evaluator: REJECT - two findings filed as G1 and G2.' \
        '## iter 1/3 | sess-1-000000 | 2026-01-01 | G1 | done:::Task: G1, filed by the gate at iteration 1 under Evaluator: REJECT.' \
        '## iter 1/3 | sess-1-000000 | 2026-01-01 | G2 | done:::Task: G2, filed by the gate at iteration 1 under Evaluator: REJECT.' \
        '## iter 2/3 | sess-1-000000 | 2026-01-01 | EVALUATOR | converged:::Verification: Evaluator: PASS - ok'
      hb_p2_ord_fixture_keep_journal
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook counts gate verdicts, not task entries that cite the rejection that filed them"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook read provenance references as verdicts and refused a legal convergence"
      fi

      # Gate salvage is a prompt state, not a hook state: mid-budget the hook
      # keeps re-feeding after a terminal REJECT, which is what gives the run
      # the iterations it was previously forbidden to use.
      hb_write_journal_entries \
        '## iter 1/3 | sess-1-000000 | 2026-01-01 | EVALUATOR | audit:::Verification: Evaluator: REJECT - one.' \
        '## iter 2/3 | sess-1-000000 | 2026-01-01 | EVALUATOR | audit:::Verification: Evaluator: REJECT - two.'
      hb_write_state sess-1 2 3
      hb_write_plan_full 'exit 0' "$hb_p2_row"
      hb_write_backlog '- [ ] G1 (High, runtime, correctness): a finding the gate filed. Acceptance: the reproduction exits 0.'
      hb_out="$(hb_run sess-1 'still working the gate findings' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && grep -q '^iteration: 3$' "$hb_state"; then
        pass "stop hook keeps re-feeding a run working gate findings after a terminal REJECT (budget salvage)"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook ended a run that still had budget and gate findings to close"
      fi

      # The evaluator check runs before the Verify command, because the
      # Verify command is a model-authored shell line the hook executes: a
      # PLAN.md planted at iteration 1 could write and commit the very
      # artifact the next check was about to read. The marker proves the
      # ordering - it must not exist, because verify must never have run.
      rm -f "$hb_proj/p2-verify-ran.txt"
      hb_write_journal_entries \
        '## iter 1/3 | sess-1-000000 | 2026-01-01 | AUDIT | audit:::Verification: clean audit.' \
        '## iter 2/3 | sess-1-000000 | 2026-01-01 | EVALUATOR | converged:::Verification: the suite is green.'
      hb_write_state sess-1 2 3
      hb_write_plan_full 'touch p2-verify-ran.txt' "$hb_p2_row"
      hb_write_backlog '' "Converged: $(hb_git rev-parse HEAD) - 2026-01-01"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'records no Evaluator verdict' \
        && [ ! -f "$hb_proj/p2-verify-ran.txt" ]; then
        pass "stop hook reads the evaluator verdict before it executes the model's Verify command"
      else
        printf '%s\n' "$hb_out"
        ls "$hb_proj"
        fault "stop hook ran a model-authored command before the check that command could satisfy"
      fi
      rm -f "$hb_proj/p2-verify-ran.txt"

      # A ROTATION entry appended after a verdict-less closing entry must not
      # supply the verdict. The scan skips those headings, and skipping them
      # has to mean stopping, not reading on through their bodies as if they
      # belonged to the entry above.
      hb_write_journal_entries \
        '## iter 1/3 | sess-1-000000 | 2026-01-01 | AUDIT | audit:::Verification: clean audit.' \
        '## iter 2/3 | sess-1-000000 | 2026-01-01 | T2 | converged:::Verification: the suite is green. No gate was run.' \
        '## iter 2/3 | sess-1-000000 | 2026-01-01 | ROTATION | rotation:::Task: rotated. Evaluator: PASS was recorded back at iteration 1.'
      hb_p2_fixture
      hb_write_backlog '' "Converged: $(hb_git rev-parse HEAD) - 2026-01-01"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'records no Evaluator verdict'; then
        pass "stop hook does not let a ROTATION entry's prose supply the closing entry's verdict"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook read a skipped rotation entry as part of the entry it followed"
      fi

      # An honest REJECT is a verdict, and it is not one a run declares on.
      # Diagnosing it as "no verdict recorded" told the run to re-invoke a
      # gate whose cap it may already have spent.
      hb_write_journal_entries \
        '## iter 1/3 | sess-1-000000 | 2026-01-01 | AUDIT | audit:::Verification: clean audit.' \
        '## iter 2/3 | sess-1-000000 | 2026-01-01 | EVALUATOR | converged:::Verification: Evaluator: REJECT - two findings stand.'
      hb_p2_fixture
      hb_write_backlog '' "Converged: $(hb_git rev-parse HEAD) - 2026-01-01"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'not a verdict a run declares on'; then
        pass "stop hook names an Evaluator: REJECT for what it is instead of calling it a missing verdict"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook told a rejected run to re-run the gate and re-declare"
      fi

      # --- P1-2c: the ratchet's own precondition ---------------------------
      # RATCHET exempts the closing entry from the gate, because a ratchet
      # re-declares a tree an earlier run already certified. Nothing checked
      # that: seven characters in a heading turned the whole evaluator block
      # off, cheaper than the eleven this release just closed. base_head is
      # written by the launch and names the commit the run started on, which
      # is the one thing about its own history a run cannot restate.
      hb_write_state_base() { # $1 iteration, $2 max, $3 base_head
        {
          printf -- '---\n'
          printf 'session_id: sess-1\niteration: %s\nmax_iterations: %s\n' "$1" "$2"
          printf 'prompt_path: %s\n' "$hb_tmp/prompt.txt"
          printf 'focus: speed\ncompletion_promise: JEFFY CONVERGED\n'
          printf 'started_at: 2026-01-01T00:00:00Z\nbase_head: %s\n' "$3"
          printf -- '---\nJeffy loop state.\n'
        } > "$hb_state"
      }
      hb_p2_ratchet_journal() {
        hb_write_journal_entries \
          '## iter 1/3 | sess-1-000000 | 2026-01-01 | RATCHET | converged:::Task: re-declared an unchanged tree.'
      }

      hb_p2_base="$(hb_git rev-parse HEAD)"
      hb_p2_ratchet_journal
      hb_write_plan_full none "$hb_p2_row"
      hb_write_backlog '' "Converged: $hb_p2_base - 2026-01-01"
      hb_write_state_base 1 3 "$hb_p2_base"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook accepts a genuine ratchet whose Converged hash predates the run"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt" 2>/dev/null
        fault "stop hook rejected a ratchet re-declaring the tree its run started on"
      fi

      printf 'v3\n' > "$hb_proj/product.txt"
      hb_git add product.txt >/dev/null 2>&1
      hb_git commit -q -m 'jeffy: work this run did itself' >/dev/null 2>&1
      hb_p2_own="$(hb_git rev-parse HEAD)"
      hb_p2_ratchet_journal
      hb_write_plan_full none "$hb_p2_row"
      hb_write_backlog '' "Converged: $hb_p2_own - 2026-01-01"
      hb_write_state_base 1 3 "$hb_p2_base"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'is not an ancestor of the commit this run started on'; then
        pass "stop hook refuses a RATCHET over work the run committed itself (the cheapest bypass in the hook)"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook let seven characters in a heading turn the evaluator gate off"
      fi

      # The bound: a state file written before base_head existed cannot be
      # dated, and the hook says so rather than refusing every legacy ratchet.
      hb_p2_ratchet_journal
      hb_write_plan_full none "$hb_p2_row"
      hb_write_backlog '' "Converged: $hb_p2_own - 2026-01-01"
      hb_write_state sess-1 1 3
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
        && grep -q 'no resolvable base_head' "$hb_tmp/hb_err.txt"; then
        pass "stop hook fails open on a ratchet whose state file predates base_head (stderr note)"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt" 2>/dev/null
        fault "stop hook mishandled a legacy state file at the ratchet check"
      fi

      hb_proj="$hb_saved_proj"; hb_state="$hb_saved_state"
    else
      skip "evaluator-verdict scenarios (git not on PATH)"
    fi

    # --- v1.5.0 Phase 3 expectations (P8) --------------------------------
    # A row's known-answer battery lives under .jeffy/probes/ and the
    # checkpoints commit it, so the converged-tree check has to read it as
    # loop memory the way it reads the ledger files. Otherwise the run that
    # kept its instruments fails the nothing-but-state test that the run
    # which threw them away and rebuilt them passes - pyportfolioopt and
    # quantstats each rebuilt a battery a prior session already had.
    if command -v git >/dev/null 2>&1; then
      hb_saved_proj="$hb_proj"; hb_saved_state="$hb_state"
      hb_proj="$hb_tmp/p3proj"; hb_state="$hb_proj/.claude/jeffy-loop.local.md"
      mkdir -p "$hb_proj/.claude" "$hb_proj/.jeffy/probes"
      hb_git init -q -b main
      printf 'v1\n' > "$hb_proj/product.txt"
      hb_write_evaluator_artifact
      hb_git add product.txt .jeffy >/dev/null
      hb_git commit -q -m c1
      hb_p3_c1="$(hb_git rev-parse HEAD)"
      hb_p3_row='- [x] core: swept at abc1234 - all entry points probed'

      # The closing checkpoint: a probe battery and the state files, nothing
      # else, committed after the hash the Converged line certifies.
      hb_write_journal 1 3
      hb_write_plan_full none "$hb_p3_row"
      hb_write_backlog '' "Converged: $hb_p3_c1 - 2026-01-01"
      printf '#!/bin/sh\nexit 0\n' > "$hb_proj/.jeffy/probes/x.sh"
      hb_git add PLAN.md BACKLOG.md JOURNAL.md .jeffy >/dev/null
      hb_git commit -q -m probes-and-state
      hb_write_state sess-1 1 3
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook accepts a commit after the Converged hash touching only .jeffy probes and state files"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook read a committed probe battery as a product change"
      fi

      # The harness's own two files under .claude/ ride the same exclusion at
      # the converged stop, for the same reason they ride it in the stall
      # gate: settings.local.json is written when the run's work draws a
      # permission grant, and the loop state file is tracked wherever the
      # bootstrap gitignore step did not run. Naming either one as a changed
      # product path rejects a declaration over the harness, not the project.
      # Staged by hand because a maintainer's global git ignore file may carry
      # the settings path, which would make this fixture prove nothing.
      mkdir -p "$hb_proj/.claude"
      printf '{ "permissions": { "allow": ["Bash(ls:*)"] } }\n' > "$hb_proj/.claude/settings.local.json"
      hb_git add -f .claude/settings.local.json >/dev/null 2>&1
      hb_git commit -q -m harness-files >/dev/null 2>&1
      hb_write_state sess-1 1 3
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook accepts a commit after the Converged hash touching the harness's own files under .claude/"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook named a harness file under .claude/ as a changed product path"
      fi

      # The companion bound: excluding .jeffy/ excuses the probes, never the
      # tree around them. A commit carrying a refreshed battery and a source
      # edit is still an uncertified tree, and the violation names the source.
      printf 'v2\n' > "$hb_proj/product.txt"
      printf '#!/bin/sh\nexit 0\n# refreshed\n' > "$hb_proj/.jeffy/probes/x.sh"
      hb_git add product.txt .jeffy >/dev/null
      hb_git commit -q -m probe-and-product
      hb_write_state sess-1 1 3
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'product.txt changed after the Converged hash' \
        && grep -q '^iteration: 2$' "$hb_state"; then
        pass "stop hook still rejects a product path changed alongside a committed probe battery"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook let the .jeffy exclusion excuse a product change"
      fi

      hb_proj="$hb_saved_proj"; hb_state="$hb_saved_state"
    else
      skip "probe-battery converged-tree scenarios (git not on PATH)"
    fi

    # --- P1-15: the Converged hash has to be reachable, and a repoint is
    # --- appended rather than written over the line it supersedes ----------
    # Through 1.7.0 the hash only had to rev-parse to a commit object, and
    # every commit object satisfies that: an orphan left by a rebase, an
    # abandoned branch tip, a commit fetched from somewhere else. A published
    # receipt whose Converged hash does not resolve on a clone cannot be
    # checked by anyone, which is the one claim this corpus is least able to
    # defend. The first production tree to meet this squashed 63 checkpoints
    # before publication, orphaned the certified commit, and had to edit a
    # line the template calls un-editable to keep the tree legal - because
    # the engine offered no other path. These scenarios build the same shape
    # on purpose: commit, capture the hash, reset past it, rebuild an
    # identical tree.
    if command -v git >/dev/null 2>&1; then
      hb_saved_proj="$hb_proj"; hb_saved_state="$hb_state"
      hb_proj="$hb_tmp/p15proj"; hb_state="$hb_proj/.claude/jeffy-loop.local.md"
      mkdir -p "$hb_proj/.claude"
      hb_git init -q -b main
      hb_p15_row='- [x] core: swept at abc1234 - all entry points probed'
      printf 'v1\n' > "$hb_proj/product.txt"
      hb_write_evaluator_artifact
      hb_git add product.txt .jeffy >/dev/null
      hb_git commit -q -m p15-c0
      hb_p15_c0="$(hb_git rev-parse HEAD)"

      # The commit that gets orphaned, and the tree it certified.
      printf 'v2\n' > "$hb_proj/product.txt"
      hb_git add product.txt >/dev/null
      hb_git commit -q -m p15-converged
      hb_p15_orphan="$(hb_git rev-parse HEAD)"

      # Rebuild the identical tree on a fresh commit, the way a squash does.
      hb_git reset -q --hard "$hb_p15_c0"
      printf 'v2\n' > "$hb_proj/product.txt"
      hb_git add product.txt >/dev/null
      hb_git commit -q -m p15-squashed
      hb_p15_new="$(hb_git rev-parse HEAD)"

      # And a commit whose tree genuinely differs, for the laundering case.
      printf 'v3\n' > "$hb_proj/product.txt"
      hb_git add product.txt >/dev/null
      hb_git commit -q -m p15-different
      hb_p15_diff="$(hb_git rev-parse HEAD)"
      hb_git reset -q --hard "$hb_p15_new"

      if [ "$(hb_git rev-parse "$hb_p15_orphan^{tree}")" = "$(hb_git rev-parse "$hb_p15_new^{tree}")" ] \
        && [ "$(hb_git rev-parse "$hb_p15_orphan^{tree}")" != "$(hb_git rev-parse "$hb_p15_diff^{tree}")" ] \
        && ! hb_git merge-base --is-ancestor "$hb_p15_orphan" HEAD 2>/dev/null; then
        pass "converged-hash sandbox built a genuine orphan (resolvable, unreachable, tree-identical to its replacement)"
      else
        fault "converged-hash sandbox did not build the orphan shape these scenarios need"
      fi

      # $1 reset target, then the Converged lines in order. The artifact is
      # rewritten and committed after the reset so it postdates whatever the
      # Converged line names, which is what the 1.7.0 recency check wants.
      hb_p15_fixture() {
        hb_p15_target="$1"; shift
        hb_git reset -q --hard "$hb_p15_target"
        {
          printf '# Backlog\n\n## Now\n\n## Next\n\n## Later\n\n## Converged\n\n'
          for hb_p15_line in "$@"; do printf '%s\n' "$hb_p15_line"; done
        } > "$hb_proj/BACKLOG.md"
        hb_write_plan_full 'exit 0' "$hb_p15_row"
        hb_write_journal_entries \
          '## iter 1/3 | sess-1-000000 | 2026-01-01 | AUDIT | audit:::Verification: clean audit.' \
          '## iter 2/3 | sess-1-000000 | 2026-01-01 | EVALUATOR | converged:::Verification: Evaluator: PASS - ok'
        hb_write_evaluator_artifact
        hb_git add .jeffy >/dev/null 2>&1
        hb_git commit -q -m p15-bookkeeping >/dev/null 2>&1
        hb_write_state sess-1 2 3
      }

      hb_p15_fixture "$hb_p15_new" "Converged: $hb_p15_orphan - 2026-01-01"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'not reachable from HEAD' \
        && grep -q '^iteration: 3$' "$hb_state"; then
        pass "stop hook refuses a Converged hash that resolves but is unreachable from HEAD"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook certified a convergence on a commit no clone of the repository can reach"
      fi

      hb_p15_fixture "$hb_p15_new" \
        "Converged: $hb_p15_orphan - 2026-01-01" \
        "Converged: $hb_p15_new - 2026-01-02 (repoints $hb_p15_orphan, tree unchanged)"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook accepts an appended repoint whose trees match and whose predecessor still stands"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook refused the one legal answer to a history rewrite"
      fi

      # The laundering shape: a repoint marker over two different trees is a
      # new convergence claim wearing an old certificate.
      hb_p15_fixture "$hb_p15_diff" \
        "Converged: $hb_p15_orphan - 2026-01-01" \
        "Converged: $hb_p15_diff - 2026-01-02 (repoints $hb_p15_orphan, tree unchanged)"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'do not carry the same tree' \
        && grep -q '^iteration: 3$' "$hb_state"; then
        pass "stop hook refuses a repoint whose two commits carry different trees"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook let a repoint marker launder a different tree past the gate"
      fi

      # Appended, not written over: the superseded line is the only evidence
      # in the tree that the rewrite happened at all.
      hb_p15_fixture "$hb_p15_new" \
        "Converged: $hb_p15_new - 2026-01-02 (repoints $hb_p15_orphan, tree unchanged)"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'no earlier Converged line' \
        && grep -q '^iteration: 3$' "$hb_state"; then
        pass "stop hook refuses a repoint written over the line it supersedes instead of beneath it"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook accepted a repoint with no surviving record of what it replaced"
      fi

      # A repoint whose old hash has been collected cannot be checked at all,
      # and failing open there would reopen the hole this closes.
      hb_p15_gone=0123456789012345678901234567890123456789
      hb_p15_fixture "$hb_p15_new" \
        "Converged: $hb_p15_gone - 2026-01-01" \
        "Converged: $hb_p15_new - 2026-01-02 (repoints $hb_p15_gone, tree unchanged)"
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'no longer resolves to a commit' \
        && grep -q '^iteration: 3$' "$hb_state"; then
        pass "stop hook refuses a repoint whose superseded commit can no longer be read"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook accepted a repoint it had no way to verify"
      fi

      hb_proj="$hb_saved_proj"; hb_state="$hb_saved_state"
    else
      skip "converged-hash reachability scenarios (git not on PATH)"
    fi

    # P0-5: the sweep-arithmetic note under coverage-first ordering. Only an
    # open High (or an unparseable severity, same fail-closed parse) keeps
    # the note silent, because only a High outranks the map now: a Medium
    # queues behind coverage. The silent case carries a control that the
    # hook still counted the rows, so silence cannot be a crash wearing a
    # pass. A state-key injector rides beside the fixtures: projection and
    # history scenarios need rows_history and stall ones last_inventory, and
    # the frontmatter is where the hook reads both.
    hb_write_state sess-1 3 10
    {
      printf '# Backlog\n\n## Now\n'
      printf -- '- [ ] T1 (Low, docs, documentation): doc gap. Acceptance: grep.\n'
      printf '\n## Next\n\n## Later\n\n## Converged\n'
    } > "$hb_proj/BACKLOG.md"
    {
      printf '# Plan\n\n## Verify command\nCommand: true\n\n## Surface inventory\n'
      printf -- '- [ ] rowA: scope\n- [ ] rowB: scope\n- [x] rowC: swept at abc123 - probed\n'
    } > "$hb_proj/PLAN.md"
    hb_out="$(hb_run sess-1 'worked the task' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'Sweep arithmetic: 2 rows are unswept' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'the map outranks everything but an open High' \
      && grep -q '^rows_history: 2$' "$hb_state"; then
      pass "stop hook says the sweep arithmetic on a Low-only ledger and seeds the sweep history"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook stayed silent about unswept rows on a Low-only ledger, which is how six targets ended runs with the gate never due"
    fi

    # A Medium no longer silences the note - it queues behind the map.
    hb_write_state sess-1 3 10
    {
      printf '# Backlog\n\n## Now\n'
      printf -- '- [ ] T2 (Medium, runtime, correctness): real bug. Acceptance: test.\n'
      printf '\n## Next\n\n## Later\n\n## Converged\n'
    } > "$hb_proj/BACKLOG.md"
    {
      printf '# Plan\n\n## Verify command\nCommand: true\n\n## Surface inventory\n'
      printf -- '- [ ] rowA: scope\n'
    } > "$hb_proj/PLAN.md"
    hb_out="$(hb_run sess-1 'worked the task' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'Sweep arithmetic: 1 rows are unswept'; then
      pass "stop hook says the sweep arithmetic past an open Medium, which queues behind the map"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook let an open Medium silence the sweep note, which is the pre-P0-5 ordering"
    fi

    # An open High is the one thing that still outranks the map.
    hb_write_state sess-1 3 10
    {
      printf '# Backlog\n\n## Now\n'
      printf -- '- [ ] T3 (High, runtime, correctness): crash. Acceptance: test.\n'
      printf '\n## Next\n\n## Later\n\n## Converged\n'
    } > "$hb_proj/BACKLOG.md"
    hb_out="$(hb_run sess-1 'worked the task' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'Sweep arithmetic:' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'unswept rows 1'; then
      pass "stop hook keeps the sweep note silent while an open High outranks the map"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook either nudged sweeping past an open High or lost the unswept count entirely"
    fi

    # P0-5: the projection. With a history on the state file the note names
    # the observed rate and the projected clearing iteration, derived from
    # the run's own samples rather than hoped.
    hb_write_state sess-1 3 10
    hb_state_addkey 'rows_history: 6,4'
    {
      printf '# Backlog\n\n## Now\n'
      printf -- '- [ ] T1 (Low, docs, documentation): doc gap. Acceptance: grep.\n'
      printf '\n## Next\n\n## Later\n\n## Converged\n'
    } > "$hb_proj/BACKLOG.md"
    {
      printf '# Plan\n\n## Verify command\nCommand: true\n\n## Surface inventory\n'
      printf -- '- [ ] rowA: scope\n- [ ] rowB: scope\n'
      printf -- '- [x] rowC: swept at abc123 - probed\n- [x] rowD: swept at abc123 - probed\n'
    } > "$hb_proj/PLAN.md"
    hb_out="$(hb_run sess-1 'worked the task' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'Observed rate: 4 rows swept over the last 2 iterations' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'projecting the map clearing around iteration 4 of 10' \
      && grep -q '^rows_history: 6,4,2$' "$hb_state"; then
      pass "stop hook projects the map-clear iteration from the run's own sweep history"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook did not derive or say the sweep projection (rate and clearing iteration)"
    fi

    # P0-5 fail-fast, the rate shape: 9 rows at 1 row per iteration against
    # 3 sweep iterations left after the closing reserve - the run is ended
    # now, with the arithmetic, instead of at exhaustion. The state file is
    # deleted, which is how the hook ends a run.
    hb_write_state sess-1 4 10
    hb_state_addkey 'rows_history: 12,11,10'
    {
      printf '# Backlog\n\n## Now\n'
      printf -- '- [ ] T1 (Low, docs, documentation): doc gap. Acceptance: grep.\n'
      printf '\n## Next\n\n## Later\n\n## Converged\n'
    } > "$hb_proj/BACKLOG.md"
    {
      printf '# Plan\n\n## Verify command\nCommand: true\n\n## Surface inventory\n'
      for hb_i in 1 2 3 4 5 6 7 8 9; do printf -- '- [ ] row%s: scope\n' "$hb_i"; done
    } > "$hb_proj/PLAN.md"
    hb_err="$(hb_run sess-1 'worked the task' '' 2>&1 1>/dev/null)"
    if [ ! -f "$hb_state" ] \
      && printf '%s' "$hb_err" | grep -qF 'the map cannot clear inside this budget' \
      && printf '%s' "$hb_err" | grep -qF 'needs about 9 more sweep iterations against 3 available'; then
      pass "stop hook ends a run early when the observed rate says the map cannot clear (fail-fast, with arithmetic)"
    else
      printf '%s\n' "$hb_err"
      fault "stop hook let a provably unclearable map spend its whole budget, which is the 100-iteration case P0-5 exists to end"
    fi

    # P0-5 fail-fast, the zero-rate shape: rows unswept, nothing above Low
    # open, and no row swept across the whole window.
    hb_write_state sess-1 4 10
    hb_state_addkey 'rows_history: 9,9,9'
    {
      printf '# Plan\n\n## Verify command\nCommand: true\n\n## Surface inventory\n'
      for hb_i in 1 2 3 4 5 6 7 8 9; do printf -- '- [ ] row%s: scope\n' "$hb_i"; done
    } > "$hb_proj/PLAN.md"
    hb_err="$(hb_run sess-1 'worked the task' '' 2>&1 1>/dev/null)"
    if [ ! -f "$hb_state" ] \
      && printf '%s' "$hb_err" | grep -qF 'the map is not clearing' \
      && printf '%s' "$hb_err" | grep -qF '0 rows were swept over the last 3 iterations'; then
      pass "stop hook ends a run early when no row has been swept across the whole observed window"
    else
      printf '%s\n' "$hb_err"
      fault "stop hook kept re-feeding a run that swept nothing for the whole window with nothing above Low open"
    fi

    # The suppressions, each a control against overreach: an open High keeps
    # the fail-fast away (its iterations are not sweep failures), and so does
    # an unparseable severity line, by the same fail-closed parse.
    hb_write_state sess-1 4 10
    hb_state_addkey 'rows_history: 12,11,10'
    {
      printf '# Backlog\n\n## Now\n'
      printf -- '- [ ] T3 (High, runtime, correctness): crash. Acceptance: test.\n'
      printf '\n## Next\n\n## Later\n\n## Converged\n'
    } > "$hb_proj/BACKLOG.md"
    {
      printf '# Plan\n\n## Verify command\nCommand: true\n\n## Surface inventory\n'
      for hb_i in 1 2 3 4 5 6 7 8 9; do printf -- '- [ ] row%s: scope\n' "$hb_i"; done
    } > "$hb_proj/PLAN.md"
    hb_out="$(hb_run sess-1 'worked the task' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && [ -f "$hb_state" ] \
      && grep -q '^iteration: 5$' "$hb_state"; then
      pass "stop hook keeps the fail-fast away while an open High legitimately outranks the map"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook ended a run early over a High it should have kept alive to fix"
    fi

    hb_write_state sess-1 4 10
    hb_state_addkey 'rows_history: 12,11,10'
    {
      printf '# Backlog\n\n## Now\n'
      printf -- '- [ ] T4: severity missing entirely. Acceptance: test.\n'
      printf '\n## Next\n\n## Later\n\n## Converged\n'
    } > "$hb_proj/BACKLOG.md"
    hb_out="$(hb_run sess-1 'worked the task' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && [ -f "$hb_state" ]; then
      pass "stop hook fails closed on an unparseable severity: no early stop over a ledger it cannot read"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook ended a run early over an unparseable ledger line, which the severity floor treats as blocking"
    fi

    # P0-7: the sample filter. Through 1.14.0 every turn end was sampled into
    # rows_history, so the opening audit and every High-fix turn sat in the
    # window as "sweep iterations that swept nothing" and the first sweep
    # turn after the Highs closed projected from them - six of eight rounds
    # in the 2026-08-21 wave ended at iteration 4-5 of 10 on the turn their
    # last High closed. A turn with an open High is not sampled.
    hb_write_state sess-1 2 10
    hb_state_addkey 'rows_history: 26'
    {
      printf '# Backlog\n\n## Now\n'
      printf -- '- [ ] T3 (High, runtime, correctness): crash. Acceptance: test.\n'
      printf '\n## Next\n\n## Later\n\n## Converged\n'
    } > "$hb_proj/BACKLOG.md"
    {
      printf '# Plan\n\n## Verify command\nCommand: true\n\n## Surface inventory\n'
      for hb_i in $(seq 1 25); do printf -- '- [ ] row%s: scope\n' "$hb_i"; done
    } > "$hb_proj/PLAN.md"
    hb_write_journal_entries '## iter 2/10 | sess-1-000000 | 2026-01-01 | M8 | done'
    hb_out="$(hb_run sess-1 'worked the task' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && grep -q '^rows_history: 26$' "$hb_state"; then
      pass "stop hook does not sample the sweep history on a turn where an open High held the queue (P0-7)"
    else
      printf '%s\n' "$hb_out"; grep '^rows_history' "$hb_state"
      fault "stop hook sampled a High turn into the sweep history, which is how Carbon's four rounds died at iteration 4"
    fi

    # Nor is an AUDIT turn: it fills the map, it does not sweep it.
    hb_write_state sess-1 1 10
    {
      printf '# Backlog\n\n## Now\n'
      printf -- '- [ ] T1 (Low, docs, documentation): doc gap. Acceptance: grep.\n'
      printf '\n## Next\n\n## Later\n\n## Converged\n'
    } > "$hb_proj/BACKLOG.md"
    hb_write_journal_entries '## iter 1/10 | sess-1-000000 | 2026-01-01 | AUDIT | audit'
    hb_out="$(hb_run sess-1 'worked the task' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && ! grep -q '^rows_history:' "$hb_state"; then
      pass "stop hook does not sample the sweep history on an AUDIT turn (P0-7)"
    else
      printf '%s\n' "$hb_out"; grep '^rows_history' "$hb_state"
      fault "stop hook sampled the opening audit into the sweep history"
    fi

    # A sweep-eligible turn is sampled, the control for both filters.
    hb_write_state sess-1 3 10
    hb_state_addkey 'rows_history: 26'
    {
      printf '# Plan\n\n## Verify command\nCommand: true\n\n## Surface inventory\n'
      for hb_i in $(seq 1 20); do printf -- '- [ ] row%s: scope\n' "$hb_i"; done
    } > "$hb_proj/PLAN.md"
    hb_write_journal_entries '## iter 3/10 | sess-1-000000 | 2026-01-01 | SWEEP | done'
    hb_out="$(hb_run sess-1 'worked the task' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && grep -q '^rows_history: 26,20$' "$hb_state"; then
      pass "stop hook samples the sweep history on a turn where the map was the top of the queue (P0-7 control)"
    else
      printf '%s\n' "$hb_out"; grep '^rows_history' "$hb_state"
      fault "stop hook stopped sampling sweep-eligible turns, which would disarm the fail-fast entirely"
    fi

    # P0-7: the reserve is the convergence sequence, which is only next when
    # nothing above Low is open. Same history and map, a Medium open: the
    # projection (5) fits the unreserved room (6) and the run continues;
    # Low-only, the reserve applies (room 3) and the run ends.
    hb_write_state sess-1 4 10
    hb_state_addkey 'rows_history: 15,13,11'
    {
      printf '# Backlog\n\n## Now\n'
      printf -- '- [ ] T2 (Medium, runtime, correctness): real bug. Acceptance: test.\n'
      printf '\n## Next\n\n## Later\n\n## Converged\n'
    } > "$hb_proj/BACKLOG.md"
    {
      printf '# Plan\n\n## Verify command\nCommand: true\n\n## Surface inventory\n'
      for hb_i in 1 2 3 4 5 6 7 8 9; do printf -- '- [ ] row%s: scope\n' "$hb_i"; done
    } > "$hb_proj/PLAN.md"
    hb_write_journal_entries '## iter 4/10 | sess-1-000000 | 2026-01-01 | SWEEP | done'
    hb_out="$(hb_run sess-1 'worked the task' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && [ -f "$hb_state" ] && grep -q '^iteration: 5$' "$hb_state"; then
      pass "stop hook does not reserve the convergence sequence from the sweep room while a Medium is open (P0-7)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook ended a run whose map fits the budget once the reserve it cannot use yet is left out"
    fi
    hb_write_state sess-1 4 10
    hb_state_addkey 'rows_history: 15,13,11'
    {
      printf '# Backlog\n\n## Now\n'
      printf -- '- [ ] T1 (Low, docs, documentation): doc gap. Acceptance: grep.\n'
      printf '\n## Next\n\n## Later\n\n## Converged\n'
    } > "$hb_proj/BACKLOG.md"
    hb_err="$(hb_run sess-1 'worked the task' '' 2>&1 1>/dev/null)"
    if [ ! -f "$hb_state" ] \
      && printf '%s' "$hb_err" | grep -qF 'needs about 5 more sweep iterations against 3 available'; then
      pass "stop hook still reserves the convergence sequence when only Lows are open (P0-7 control)"
    else
      printf '%s\n' "$hb_err"
      fault "stop hook stopped reserving the convergence sequence on a Low-only ledger"
    fi

    # P0-7 replay: Carbon run 74e5d096 turn by turn, the hook keeping its own
    # history. Audit at 26 unswept with a High filed; a High fix at 25 with
    # the High still open; a sweep to 20 with the High still open; the High
    # closed at 19. Under 1.14.0 the fourth turn ended the run (history
    # 26,25,20,19 - 7 rows over 3 turns, 19 left, room 3); now only the
    # fourth turn is a sample and the run continues.
    hb_write_state sess-1 1 10
    hb_carbon_turn() { # $1 iteration, $2 type, $3 severity-or-NONE, $4 unswept
      {
        printf '# Backlog\n\n## Now\n'
        [ "$3" = NONE ] || printf -- '- [ ] T9 (%s, runtime, correctness): x. Acceptance: y.\n' "$3"
        printf '\n## Next\n\n## Later\n\n## Converged\n'
      } > "$hb_proj/BACKLOG.md"
      {
        printf '# Plan\n\n## Verify command\nCommand: true\n\n## Surface inventory\n'
        for hb_i in $(seq 1 "$4"); do printf -- '- [ ] row%s: scope\n' "$hb_i"; done
      } > "$hb_proj/PLAN.md"
      hb_write_journal_entries "## iter $1/10 | sess-1-000000 | 2026-01-01 | $2 | done"
      hb_run sess-1 'worked the task' '' >/dev/null 2>"$hb_tmp/carbon-err.txt"
    }
    hb_carbon_turn 1 AUDIT High 26
    hb_carbon_turn 2 M8 High 25
    hb_carbon_turn 3 SWEEP High 20
    hb_carbon_turn 4 M12 NONE 19
    if [ -f "$hb_state" ] && grep -q '^iteration: 5$' "$hb_state" \
      && grep -q '^rows_history: 19$' "$hb_state"; then
      pass "stop hook keeps the Carbon 74e5d096 round alive at iteration 4 (P0-7 replay: High turns are not sweep samples)"
    else
      cat "$hb_tmp/carbon-err.txt"; grep '^rows_history\|^iteration' "$hb_state" 2>/dev/null
      fault "stop hook ended the Carbon replay at iteration 4 of 10 with 19 rows unswept, the 2026-08-21 failure"
    fi

    # P2-21: run telemetry. JOURNAL.md is prose - enough for one run, useless
    # across fifty - so the numbers this hook already computes are also
    # written as JSON, one record per turn end. It is COMMITTED under
    # .jeffy/metrics/ rather than gitignored, following this tree's own model
    # (.jeffy is loop memory, the checkpoints commit all of it, only the
    # transient state file is ignored), and it lands inside a path the
    # loop-memory exclusion list already covers - telemetry that registered as
    # progress would manufacture the very signal it exists to measure.
    rm -rf "$hb_proj/.jeffy/metrics"
    hb_write_state sess-1 3 10
    hb_out="$(hb_run sess-1 'worked the task' '')"
    hb_metrics="$(find "$hb_proj/.jeffy/metrics" -name '*.jsonl' -type f 2>/dev/null | head -n 1)"
    if [ -n "$hb_metrics" ] && [ "$(wc -l < "$hb_metrics" | tr -d '[:space:]')" = "1" ] \
      && jq -e '.iteration == 3 and has("evaluator_invocations") and has("content_tree_hash")' "$hb_metrics" >/dev/null 2>&1; then
      pass "stop hook writes one valid telemetry record per turn end"
    else
      printf 'metrics=[%s]\n' "$hb_metrics"
      fault "stop hook wrote no usable telemetry record at turn end"
    fi

    # Appends rather than overwrites: a run's record is its whole arc.
    hb_write_state sess-1 4 10
    hb_out="$(hb_run sess-1 'worked the task' '')"
    if [ "$(wc -l < "$hb_metrics" | tr -d '[:space:]')" = "2" ] \
      && [ "$(jq -s '[.[].iteration] | join(",")' "$hb_metrics" | tr -d '"')" = "3,4" ]; then
      pass "telemetry appends one record per turn rather than overwriting the run's arc"
    else
      fault "the telemetry file did not accumulate across turns"
    fi

    # Never a cost figure: nothing here can measure spend, so nothing claims to.
    if jq -e '.cost_estimate_usd == null' "$hb_metrics" >/dev/null 2>&1; then
      pass "telemetry records a null cost rather than a number nothing measured"
    else
      fault "telemetry carries a fabricated cost estimate"
    fi

    # And the record itself must never read as progress to either tree gate.
    if printf '%s' '.jeffy/metrics/x.jsonl' | grep -qE "$(sed -n 's/^JEFFY_LOOP_MEMORY_RE=.\(.*\).$/\1/p' "$hb_hook")"; then
      pass "a telemetry write lands inside loop memory, so it cannot register as progress"
    else
      fault "the metrics path is outside the loop-memory exclusion list; writing telemetry would look like work"
    fi

    # P2-29: the record that matters most is the one the run ends on, and it
    # was the only one never written - the write sat at the foot of the file,
    # after every branch that ends a run had already exited, so three targets
    # came up four records short across four runs each and every gap was a
    # closing turn. A run ended by budget exhaustion has to leave one behind
    # exactly as a re-feed does; it is an EXIT trap now rather than a
    # trailing block, so the record does not depend on which branch ends the
    # turn.
    rm -rf "$hb_proj/.jeffy/metrics"
    hb_write_state sess-1 3 3
    hb_out="$(hb_run sess-1 'still working' '')"
    hb_endm="$(find "$hb_proj/.jeffy/metrics" -name '*.jsonl' -type f 2>/dev/null | head -n 1)"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] && [ -n "$hb_endm" ] \
      && [ "$(wc -l < "$hb_endm" | tr -d '[:space:]')" = "1" ] \
      && jq -e '.iteration == 3 and .budget == 3' "$hb_endm" >/dev/null 2>&1; then
      pass "a run ended by budget exhaustion still writes its closing telemetry record"
    else
      printf 'endm=[%s] out=[%s]\n' "$hb_endm" "$hb_out"
      fault "the turn that ended the run left no telemetry record (the closing turn is the one that matters)"
    fi
    hb_write_state sess-1 3 10

    # The reader runs clean on populated, empty, and absent directories: a
    # stats tool that dies on an untouched project is a stats tool nobody runs.
    if bash scripts/jeffy-stats.sh "$hb_proj" >/dev/null 2>&1 \
      && bash scripts/jeffy-stats.sh "$hb_tmp" >/dev/null 2>&1; then
      pass "jeffy-stats reads a populated project and an untouched one without failing"
    else
      fault "jeffy-stats failed on a populated or an empty project"
    fi
    rm -rf "$hb_proj/.jeffy/metrics"

    # P2-26: context pressure, measured from the transcript rather than
    # counted in iterations. The engine re-feeds one session, so context
    # accumulates within a run; an iteration ordinal is a proxy for that,
    # while the transcript is the thing itself. Advisory only, and the
    # threshold is off unless the state file sets one - the same refusal to
    # publish an unmeasured constant that leaves the time ceilings off.
    hb_ctx="$hb_tmp/transcript.jsonl"
    : > "$hb_ctx"
    for hb_i in $(seq 1 200); do printf '{"n":%s,"pad":"aaaaaaaaaaaaaaaaaaaa"}\n' "$hb_i" >> "$hb_ctx"; done
    hb_ctx_now="$(wc -c < "$hb_ctx" | tr -d '[:space:]')"

    hb_write_state sess-1 3 10
    hb_state_addkey "context_base_bytes: $((hb_ctx_now / 4))"
    hb_state_addkey 'max_context_growth: 3'
    hb_out="$(hb_run sess-1 'worked the task' "$hb_ctx")"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'CONTEXT PRESSURE' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'the closing rule still governs'; then
      pass "stop hook advises on measured context growth past a declared threshold, without ending the run"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook said nothing about a transcript that quadrupled inside one run"
    fi

    # Advisory means advisory: the run continues and the counter advances.
    hb_write_state sess-1 3 10
    hb_state_addkey "context_base_bytes: $((hb_ctx_now / 4))"
    hb_state_addkey 'max_context_growth: 3'
    hb_out="$(hb_run sess-1 'worked the task' "$hb_ctx")"
    if [ -f "$hb_state" ] && grep -q '^iteration: 4$' "$hb_state"; then
      pass "the context-pressure note never ends a run or forfeits a declared budget"
    else
      printf '%s\n' "$hb_out"
      fault "the context-pressure note stopped a run it is only allowed to advise"
    fi

    # No threshold means no note, and the growth is still reported so the
    # operator sees the number without one being imposed.
    hb_write_state sess-1 3 10
    hb_state_addkey "context_base_bytes: $((hb_ctx_now / 4))"
    hb_out="$(hb_run sess-1 'worked the task' "$hb_ctx")"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'CONTEXT PRESSURE' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qE 'context [0-9]+\.[0-9]x'; then
      pass "with no threshold set, context growth is reported and never nagged about"
    else
      printf '%s\n' "$hb_out"
      fault "context growth was either enforced without a threshold or dropped from the run state"
    fi

    # An unreachable transcript is an infrastructure gap, not evidence.
    hb_write_state sess-1 3 10
    hb_state_addkey "context_base_bytes: $((hb_ctx_now / 4))"
    hb_state_addkey 'max_context_growth: 3'
    hb_out="$(hb_run sess-1 'worked the task' "$hb_tmp/no-such-transcript.jsonl")"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && [ -f "$hb_state" ] \
      && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'CONTEXT PRESSURE'; then
      pass "an unreadable transcript path leaves the context signal silent rather than guessing"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook invented a context figure from a transcript it could not read"
    fi

    # P1-49: the time ceilings. A turn budget counts turns and a turn is
    # unbounded in time, so these bound the run in hours. Both default to off,
    # which is itself checked: a run with no keys must behave exactly as it
    # did before this shipped. What matters most here is the precedence - a
    # ceiling that preempted the closing extension would kill runs three
    # iterations from a certified declaration, which is worse than the
    # unbounded turn it was protecting against.
    hb_now="$(date +%s)"

    hb_write_state sess-1 3 10
    hb_state_addkey "run_started_at: $((hb_now - 7200))"
    hb_state_addkey 'max_wall_clock_seconds: 3600'
    hb_err="$(hb_run sess-1 'worked the task' '' 2>&1 1>/dev/null)"
    if [ ! -f "$hb_state" ] && printf '%s' "$hb_err" | grep -qF 'wall-clock ceiling'; then
      pass "stop hook ends a run that passed its wall-clock ceiling, out of time rather than out of turns"
    else
      printf '%s\n' "$hb_err"
      fault "stop hook ran past its declared wall-clock ceiling"
    fi

    hb_write_state sess-1 3 10
    hb_state_addkey "run_started_at: $((hb_now - 999999))"
    hb_state_addkey 'max_wall_clock_seconds: 0'
    hb_out="$(hb_run sess-1 'worked the task' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && [ -f "$hb_state" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'no ceiling set'; then
      pass "a wall-clock ceiling of 0 disables enforcement and still reports elapsed time"
    else
      printf '%s\n' "$hb_out"
      fault "max_wall_clock_seconds: 0 did not disable the ceiling, or the run state dropped the wall figure"
    fi

    # Malformed epochs are an infrastructure gap, not evidence: fail open with
    # a note, the way every other unparseable state value here does.
    hb_write_state sess-1 3 10
    hb_state_addkey 'run_started_at: not-an-epoch'
    hb_state_addkey 'max_wall_clock_seconds: 60'
    hb_out="$(hb_run sess-1 'worked the task' '' 2>"$hb_tmp/hb_err.txt")"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && [ -f "$hb_state" ] \
      && grep -q 'not an epoch integer' "$hb_tmp/hb_err.txt"; then
      pass "a malformed run_started_at fails open with a diagnostic rather than trapping the session"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook mishandled a malformed epoch in the wall-clock ceiling"
    fi

    # A run with none of the keys is the pre-1.13.0 shape and must be untouched.
    hb_write_state sess-1 3 10
    hb_out="$(hb_run sess-1 'worked the task' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && [ -f "$hb_state" ] \
      && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'wall '; then
      pass "a state file with no time keys behaves exactly as it did before the ceilings shipped"
    else
      printf '%s\n' "$hb_out"
      fault "the time ceilings changed the behaviour of a state file that declares none"
    fi

    # Per-iteration overrun: the note first, the stop only on the second.
    hb_write_state sess-1 3 10
    hb_state_addkey "iteration_started_at: $((hb_now - 600))"
    hb_state_addkey 'max_iteration_seconds: 60'
    hb_out="$(hb_run sess-1 'worked the task' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'ITERATION OVERRUN' \
      && grep -q '^overrun: 1$' "$hb_state"; then
      pass "a long iteration draws an ITERATION OVERRUN note and arms the second strike"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook said nothing about an iteration that blew its per-iteration ceiling"
    fi

    hb_write_state sess-1 3 10
    hb_state_addkey "iteration_started_at: $((hb_now - 600))"
    hb_state_addkey 'max_iteration_seconds: 60'
    hb_state_addkey 'overrun: 1'
    hb_err="$(hb_run sess-1 'worked the task' '' 2>&1 1>/dev/null)"
    if [ ! -f "$hb_state" ] && printf '%s' "$hb_err" | grep -qF 'two consecutive iterations exceeded'; then
      pass "two consecutive per-iteration overruns end the run"
    else
      printf '%s\n' "$hb_err"
      fault "the second consecutive overrun did not end the run"
    fi

    # Precedence, and this is the one that matters: a ceiling never robs a run
    # of the closing extension it just earned.
    hb_write_state sess-1 10 10
    hb_state_addkey "run_started_at: $((hb_now - 999999))"
    hb_state_addkey 'max_wall_clock_seconds: 60'
    hb_write_backlog ''
    {
      printf '# Plan\n\n## Verify command\nCommand: true\n\n## Surface inventory\n'
      printf -- '- [x] rowA: swept at abc123 - probed\n'
    } > "$hb_proj/PLAN.md"
    hb_out="$(hb_run sess-1 'worked the task' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && [ -f "$hb_state" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'CLOSING EXTENSION'; then
      pass "a blown wall-clock ceiling yields to a closing extension granted the same turn"
    else
      printf '%s\n' "$hb_out"
      fault "a time ceiling preempted the closing extension, killing a run at its finish line"
    fi

    # And never a converged promise: that branch returns before the ceilings.
    hb_write_state sess-1 3 10
    hb_state_addkey "run_started_at: $((hb_now - 999999))"
    hb_state_addkey 'max_wall_clock_seconds: 60'
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
      pass "a valid converged promise is unaffected by a blown wall-clock ceiling"
    else
      printf '%s\n' "$hb_out"
      fault "a time ceiling disturbed a valid convergence"
    fi

    # P0-5 (P1-47): a Surface inventory row flip is progress to the stall
    # gate. The armed run whose inventory moved keeps going with the strike
    # cleared; the control with an identical inventory takes the second
    # strike and ends, proving the new signal did not fail open.
    {
      printf '# Backlog\n\n## Now\n'
      printf -- '- [ ] T1 (Low, docs, documentation): doc gap. Acceptance: grep.\n'
      printf '\n## Next\n\n## Later\n\n## Converged\n'
    } > "$hb_proj/BACKLOG.md"
    hb_p05_bl="$(awk '
      { sub(/\r$/, "") }
      /^## Now$/ { sec = "Now"; next }
      /^## Next$/ { sec = "Next"; next }
      /^## Later$/ { sec = "Later"; next }
      /^## / { sec = "" }
      sec != "" && /^- \[[ b]\]/ { print sec "|" $0 }
    ' "$hb_proj/BACKLOG.md" | cksum | tr ' \t' '--')"
    {
      printf '# Plan\n\n## Verify command\nCommand: true\n\n## Surface inventory\n'
      printf -- '- [x] rowA: swept at abc123 - probed\n- [ ] rowB: scope\n'
    } > "$hb_proj/PLAN.md"
    hb_p05_inv="$(awk '
      { sub(/\r$/, "") }
      /^## Surface inventory$/ { take = 1; next }
      /^## / { take = 0 }
      take && /^- \[[ xb]\]/ { print }
    ' "$hb_proj/PLAN.md" | cksum | tr ' \t' '--')"
    hb_write_state sess-1 3 10
    hb_state_addkey 'stall: 1'
    hb_state_addkey "last_backlog: $hb_p05_bl"
    hb_state_addkey 'last_inventory: stale-inventory-sig'
    hb_out="$(hb_run sess-1 'worked the task' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'STALL:' \
      && grep -q '^stall: 0$' "$hb_state" \
      && grep -q "^last_inventory: $hb_p05_inv\$" "$hb_state"; then
      pass "stop hook reads a Surface inventory row flip as progress, so a sweep-only iteration is not a stall"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook still reads a sweep-only iteration as flat, which forced runs to pair sweeps with unrelated Lows"
    fi

    hb_write_state sess-1 3 10
    hb_state_addkey 'stall: 1'
    hb_state_addkey "last_backlog: $hb_p05_bl"
    hb_state_addkey "last_inventory: $hb_p05_inv"
    hb_err="$(hb_run sess-1 'worked the task' '' 2>&1 1>/dev/null)"
    if [ ! -f "$hb_state" ] \
      && printf '%s' "$hb_err" | grep -qF 'ending the run as stalled'; then
      pass "stop hook still takes the second strike when neither the ledger nor the inventory moved"
    else
      printf '%s\n' "$hb_err"
      fault "stop hook's inventory signal failed open and disarmed the stall gate entirely"
    fi

    rm -rf "$hb_tmp"
  fi
else
  skip "stop hook behavior checks (jq not on PATH)"
fi

# K. The check count the README publishes is derived from this run, never
#    transcribed. Two README claims carry a derivation: the converged and
#    language totals against the eval table (check J), and this count. Those
#    two are the numbers this project publishes outside the repository, which
#    is why they are the two that are machine-checked; every other figure in
#    the README is ordinary prose and should be read as such. PLAN.md's
#    Derived and settled numbers section holds the full enumeration.
#    Published means what a clone runs, so the derivation subtracts what only
#    a maintainer tree adds: the CHANGELOG pairing above, this check itself,
#    and a shellcheck lint where the linter is installed. It asserts only in
#    that maintainer tree, which is where releases are cut and where the
#    marker is authored; a clone or a CI leg has nothing to author and skips.
#    Every marker, never the first: reading one with head -n 1 leaves a second
#    marker free to state a different number. One marker carries this claim
#    today, so this is the guard rather than a current disagreement. (M1)
claim_checks="$(grep -o '<!-- count:checks -->\*\*[0-9][0-9]* behavioural checks\*\*<!-- /count -->' README.md \
  | tr -dc '0-9\n' | grep -v '^$' | sort -u | tr '\n' ' ' | sed 's/ $//')"
if [ -z "$claim_checks" ]; then
  fault "README carries no <!-- count:checks -->N behavioural checks<!-- /count --> marker; the engine's own check count is then an untracked claim"
elif [ "${claim_checks#* }" != "$claim_checks" ]; then
  fault "README states the behavioural check count as [$claim_checks]; its own count:checks markers disagree, so no single number is published"
elif [ ! -f CHANGELOG.md ] || [ -z "$ps" ] \
  || ! command -v jq >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1; then
  skip "README check-count derivation (asserts in a maintainer tree with jq, git and PowerShell, where the marker is written)"
else
  cc_extra=2
  if command -v shellcheck >/dev/null 2>&1; then cc_extra=$((cc_extra + 1)); fi
  cc_derived=$((ok_n + 1 - cc_extra))
  if [ "$cc_derived" -eq "$claim_checks" ]; then
    pass "README check count is derived, not transcribed ($claim_checks on a clone, $((ok_n + 1)) in this tree)"
  else
    fault "README claims $claim_checks behavioural checks but this run derives $cc_derived; the marker ships in the same commit as the scenarios that moved it"
  fi
fi

echo ""
if [ "$skip_n" -gt 0 ]; then
  echo "$skip_n check(s) did not run on this host, and a check that did not run covers nothing:"
  printf '%s' "$skipped" | sed 's/^/  - /'
  echo ""
fi
if [ "$fail" -eq 0 ]; then
  echo "All checks passed ($ok_n ran, $skip_n skipped)."
  exit 0
fi
echo "Validation failed ($ok_n ran, $skip_n skipped)."
exit 1
