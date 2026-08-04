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
pass() { echo "[OK] $1"; }
fault() { echo "[FAIL] $1"; fail=1; }

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
  echo "[SKIP] exec-bit checks (not a git checkout)"
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
  skills/jeffy/references/enhance-plan-default.md \
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
  echo "[SKIP] install.ps1 parse check (no pwsh or powershell on PATH)"
fi

# 5. shellcheck lint of the shell scripts, when shellcheck is available. Optional:
#    hosts without shellcheck skip cleanly. bash -n (check 1) is parse-only and
#    misses the bugs shellcheck catches (unquoted expansions, unreachable code).
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck install.sh scripts/validate.sh skills/jeffy/hooks/stop-hook.sh; then
    pass "shell scripts lint clean (shellcheck)"
  else
    fault "shellcheck reported issues (see output above)"
  fi
else
  echo "[SKIP] shellcheck lint (shellcheck not on PATH)"
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
  "in-envelope" \
  "Convergence ratchet:" \
  "Three-strike rule:" \
  "one structural task" \
  "## Verify command" \
  "Command: " \
  "## Lessons" \
  "leaves no open task behind" \
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
  "(<Severity>, <class>, <dimension>)" \
  "one glob per line" \
  "run at least one test module in isolation" \
  "provoking a failure at every step" \
  "re-executes the claims it invalidates" \
  "write a line number into a state file"
check_markers skills/jeffy/references/backlog-default.md \
  "## Proposed" \
  "## Settled classes" \
  "## Converged" \
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
  "or AUDIT or EVALUATOR or RATCHET"
check_markers skills/jeffy/references/iteration-prompt.txt \
  "Salvage first:" \
  "Ratchet next:" \
  "Verify gate:" \
  "Severity discipline:" \
  "Backlog discipline:" \
  "Stall check:" \
  "Checkpoint:" \
  "Lessons:" \
  "Run report:" \
  "no Low is silently left behind" \
  "wrapped in promise XML tags" \
  "Evaluator gate:" \
  "Evaluator: PASS" \
  "at most 2 evaluator invocations per run" \
  "never overwriting it" \
  "so two runs in one session are told apart" \
  "Closeout:" \
  "Surface inventory" \
  "Change discipline:" \
  "rows swept of rows total" \
  "never only run-without-crash probes" \
  "newly exposed rather than introduced" \
  "whose value changes nothing" \
  "Run the gate while its verdict can still be answered:" \
  "One transaction closes the run:" \
  "copy the fixed files aside" \
  "or a test run through head or tail" \
  "or AUDIT or EVALUATOR or RATCHET" \
  ".jeffy/probes/" \
  "never run an audit inside it" \
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
  "RUN STATE" \
  "CLOSING EXTENSION" \
  "JEFFY_VERSION" \
  "refilled inside the closing extension"
# The launch-time lint is the whole malformed-Verify-command class caught at
# zero iteration cost: the hook's parser runs only on the convergence branch,
# so without this check a line written at launch waits a whole run to fire.
# Its placeholder exemption is pinned too: the bootstrapped PLAN.md ships
# `Command: <first audit fills this in>`, which no sanitation makes parse, so
# a lint that reads the template's own line as a defect hard-stops every
# relaunch whose first iteration was interrupted before the audit filled it.
check_markers skills/jeffy/SKILL.md \
  "Verify command lint:" \
  "nor an unfilled \`<...>\` placeholder" \
  "a pager or truncator" \
  "core.autocrlf false" \
  "show-toplevel" \
  "Nested Jeffy project:" \
  "mode \`120000\`" \
  "enhance <topic>" \
  "Mode guard:" \
  "whose mode is Enhance"
check_markers skills/jeffy/references/enhance-plan-default.md \
  "## Mode" \
  "Enhance." \
  "## Topic" \
  "<filled at bootstrap with the sanitized topic>" \
  "never files defect findings at severity" \
  "## Impact ranking" \
  "cost: exceeds one iteration" \
  "## Surface inventory" \
  "lists no unswept row" \
  "## Verify command" \
  "Command: " \
  "an acceptance check that can fail" \
  "adversarial evaluator gate" \
  "Evaluator: unavailable" \
  "recorded in the run report for a standard run" \
  "## Lessons"
if [ "$gm_missing" -eq 0 ]; then
  pass "jeffy skill files carry all governance markers"
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
hook_ver="$(sed -n 's/^JEFFY_VERSION="\([0-9][0-9.]*\)"$/\1/p' skills/jeffy/hooks/stop-hook.sh | head -n 1)"
if [ -z "$hook_ver" ]; then
  fault "stop-hook.sh carries no JEFFY_VERSION=\"x.y.z\" line"
elif [ ! -f CHANGELOG.md ]; then
  echo "[SKIP] JEFFY_VERSION/CHANGELOG pairing (no CHANGELOG.md; maintainer-only file)"
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
#    Source of truth is the eval table: one row per evals/*/REPORT.md, the
#    Run column says **converged**, the Language column feeds the distinct
#    count. On failure, remember the surfaces grep cannot see: the GitHub
#    About text, release bodies, and any live article state the same numbers.
receipts="$(ls evals/*/REPORT.md 2>/dev/null | wc -l | tr -d ' ')"
tbl_rows="$(grep -c '^| \[.*(evals/.*/REPORT\.md)' README.md)"
tbl_conv="$(grep -c '^| \[.*(evals/.*/REPORT\.md).*\*\*converged\*\*' README.md)"
tbl_langs="$(awk -F'|' '/^\| \[/ && /\*\*converged\*\*/ { gsub(/^[ \t]+|[ \t]+$/, "", $4); print $4 }' README.md | sort -u | wc -l | tr -d ' ')"
claim_conv="$(sed -n 's/.*<!-- count:converged -->\([0-9][0-9]*\)<!-- \/count -->.*/\1/p' README.md | head -n 1)"
claim_langs="$(sed -n 's/.*<!-- count:languages -->\([0-9][0-9]*\)<!-- \/count -->.*/\1/p' README.md | head -n 1)"
if [ "$tbl_rows" != "$receipts" ]; then
  fault "README eval table has $tbl_rows rows but evals/ holds $receipts REPORT.md receipts; a new eval landed without its row (and the About text and live articles need the same edit)"
elif [ -z "$claim_conv" ] || [ -z "$claim_langs" ]; then
  fault "README prose counts are not marker-anchored (<!-- count:converged --> / <!-- count:languages -->); an unanchored count is an untracked claim"
elif [ "$claim_conv" != "$tbl_conv" ]; then
  fault "README claims $claim_conv converged but the eval table shows $tbl_conv (and the About text and live articles need the same edit)"
elif [ "$claim_langs" != "$tbl_langs" ]; then
  fault "README claims $claim_langs languages but the converged rows span $tbl_langs"
else
  pass "README counts are derived from the eval table ($tbl_conv converged of $receipts, $tbl_langs languages)"
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
  if HOME="$rt_home" PATH="$rt_bin:/usr/bin:/bin" bash "$rt_repo/install.sh" </dev/null >"$rt_tmp/run.log" 2>&1 \
    && [ -f "$rt_home/.claude/skills/jeffy/SKILL.md" ] \
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
    if [ "$(rt_timeouts)" = "600" ]; then
      pass "install.sh registers the Stop hook with a 600s timeout"
    else
      fault "install.sh fresh registration lacks the 600s timeout (got: $(rt_timeouts))"
    fi
    # Legacy upgrade: a pre-1.2 registration without the timeout field gets
    # it added exactly once, and a further run leaves the file byte-identical.
    jq -n --arg cmd "bash \"$rt_home/.claude/skills/jeffy/hooks/stop-hook.sh\"" \
      '{hooks: {Stop: [{hooks: [{type: "command", command: $cmd}]}]}}' > "$rt_home/.claude/settings.json"
    HOME="$rt_home" PATH="$rt_bin:/usr/bin:/bin" bash "$rt_repo/install.sh" </dev/null >"$rt_tmp/upgrade.log" 2>&1 || true
    if [ "$(rt_count)" = "1" ] && [ "$(rt_timeouts)" = "600" ]; then
      cp "$rt_home/.claude/settings.json" "$rt_tmp/settings.after-upgrade"
      HOME="$rt_home" PATH="$rt_bin:/usr/bin:/bin" bash "$rt_repo/install.sh" </dev/null >"$rt_tmp/upgrade2.log" 2>&1 || true
      if cmp -s "$rt_home/.claude/settings.json" "$rt_tmp/settings.after-upgrade"; then
        pass "install.sh upgrades a legacy registration with the 600s timeout exactly once"
      else
        fault "install.sh kept rewriting the upgraded registration on later runs"
      fi
    else
      echo "---- install.sh upgrade run output ----"
      cat "$rt_tmp/upgrade.log"
      echo "---------------------------------------"
      fault "install.sh did not upgrade a legacy hook registration with the timeout"
    fi
  else
    echo "[SKIP] install.sh hook-registration assertions (jq not on PATH)"
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
    if pr_run >"$pr_tmp/run.log" 2>&1 \
      && [ -f "$pr_home/.claude/skills/jeffy/SKILL.md" ] \
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
    pr_timeout_count() {
      grep -c '"timeout": *600' "$pr_home/.claude/settings.json" 2>/dev/null | tr -d '[:space:]'
    }
    if [ "$(pr_timeout_count)" = "1" ]; then
      pass "install.ps1 registers the Stop hook with a 600s timeout ($ps)"
    else
      fault "install.ps1 fresh registration lacks the 600s timeout"
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
        pass "install.ps1 upgrades a legacy registration with the 600s timeout exactly once ($ps)"
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
  echo "[SKIP] install.ps1 runtime check (no pwsh or powershell on PATH)"
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
    hb_write_plan() { # $1 command for PLAN.md's Command: line
      # The labeled line is the only shape the hook executes (the bare
      # first-line fallback was removed in 1.5.0), so every fixture that
      # wants its command run writes it here.
      printf '# Plan\n\n## Verify command\nCommand: %s\n' "$1" > "$hb_proj/PLAN.md"
    }
    # The three hb_*_full / _extra / _entries variants below are staged for the
    # 1.5.0 cases (Command-line sanitation, inventory rows, state schema
    # growth, multi-entry journals) and are deliberately not called yet.
    # shellcheck disable=SC2329
    hb_write_plan_full() { # $1 Command: payload, $2... Surface inventory rows, one per line
      hb_cmd="$1"; shift
      {
        printf '# Plan\n\n## Verify command\nCommand: %s\n\n## Surface inventory\n' "$hb_cmd"
        for hb_row in "$@"; do printf '%s\n' "$hb_row"; done
      } > "$hb_proj/PLAN.md"
    }
    # shellcheck disable=SC2329
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
    # shellcheck disable=SC2329
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
    hb_write_backlog() { # $1 optional open task line, $2 optional Converged line
      {
        printf '# Backlog\n\n## Now\n\n'
        if [ -n "${1:-}" ]; then printf '%s\n' "$1"; fi
        printf '\n## Next\n\n## Later\n\n## Converged\n\n'
        if [ -n "${2:-}" ]; then printf '%s\n' "$2"; fi
      } > "$hb_proj/BACKLOG.md"
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

    hb_write_state sess-1 3 3
    hb_write_backlog '- [ ] T1: unfinished task'
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] && grep -q 'convergence rejected' "$hb_tmp/hb_err.txt"; then
      pass "stop hook ends the run at budget exhaustion even with a pending violation (stderr note)"
    else
      fault "stop hook mishandled a violation at budget exhaustion"
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
      hb_git add product.txt >/dev/null
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
      printf 'entry\n' > "$hb_proj/JOURNAL.md"
      hb_git add JOURNAL.md >/dev/null
      hb_git commit -q -m state-only
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

      hb_proj="$hb_saved_proj"; hb_state="$hb_saved_state"
    else
      echo "[SKIP] converged-hash git scenarios (git not on PATH)"
    fi

    # Verify-command check: the project's own gate runs at the converged
    # stop under a timeout; none skips it, a red or overrunning gate blocks
    # the promise, and a missing ledger fails open with a stderr note.
    if command -v timeout >/dev/null 2>&1; then
      hb_write_state sess-1 1 3
      hb_write_backlog ''
      hb_write_plan 'exit 0'
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook accepts the promise when the Verify command is green"
      else
        fault "stop hook rejected a convergence promise with a green Verify command"
      fi

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
    else
      echo "[SKIP] verify-command scenarios (coreutils timeout not on PATH)"
    fi

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

    hb_write_state sess-1 1 3
    rm -f "$hb_proj/BACKLOG.md"
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] && grep -q 'BACKLOG.md missing' "$hb_tmp/hb_err.txt"; then
      pass "stop hook fails open on a missing BACKLOG.md at promise time (stderr note)"
    else
      fault "stop hook mishandled a missing BACKLOG.md at promise time"
    fi

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
      rm -f "$hb_proj/junk.txt" "$hb_state"
      hb_proj="$hb_saved_proj"; hb_state="$hb_saved_state"
    fi

    # Stall gate: progress on either recorded signal (HEAD, ledger cksum)
    # stays silent and refreshes the baseline; a flat iteration rides a
    # STALL note and arms the flag. Baseline initialization is asserted in
    # the first mid-budget check above (state with no stall fields, no note).
    if [ -d "$hb_tmp/gitproj/.git" ]; then
      hb_saved_proj="$hb_proj"; hb_saved_state="$hb_state"
      hb_proj="$hb_tmp/gitproj"; hb_state="$hb_proj/.claude/jeffy-loop.local.md"
      hb_write_backlog ''
      hb_write_journal 1 3
      hb_git add -A >/dev/null 2>&1
      hb_git commit -q -m stall-baseline >/dev/null 2>&1 || true
      hb_head="$(hb_git rev-parse HEAD)"
      hb_ck="$(cksum < "$hb_proj/BACKLOG.md" | tr ' \t' '--')"

      hb_write_state_stall sess-1 1 3 stale-head "$hb_ck" 0
      hb_out="$(hb_run sess-1 'still working' '')"
      if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
        && ! printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'STALL:' \
        && grep -q "^last_head: $hb_head\$" "$hb_state" \
        && grep -q '^stall: 0$' "$hb_state" \
        && grep -q '^iteration: 2$' "$hb_state"; then
        pass "stop hook stays silent when HEAD moved since the last re-feed (baseline refreshed)"
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
      hb_write_state_stall sess-1 1 3 stale-head "$hb_ck" 1
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
    hb_ck0="$(cksum < "$hb_proj/BACKLOG.md" | tr ' \t' '--')"
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
      hb_git add product.txt >/dev/null
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

      if command -v timeout >/dev/null 2>&1; then
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
      else
        echo "[SKIP] Command-line sanitation scenarios (coreutils timeout not on PATH)"
      fi

      hb_proj="$hb_saved_proj"; hb_state="$hb_saved_state"
    else
      echo "[SKIP] Converged-line and Command-line scenarios (git not on PATH)"
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

    # The conditions: an open task or an unswept row means the run is not
    # in its convergence sequence, and the budget is the budget.
    hb_write_backlog_counts 1 0 0
    hb_write_state sess-1 3 3
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
      pass "stop hook ends the run at budget exhaustion while a task is still open (no extension)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook extended a run that still had open tasks"
    fi

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
    if command -v timeout >/dev/null 2>&1; then
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
    else
      echo "[SKIP] closing extension on the rejected-promise path (coreutils timeout not on PATH)"
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
    hb_proj="$hb_tmp/proj"; hb_state="$hb_proj/.claude/jeffy-loop.local.md"
    hb_write_journal_entries '## iter 4/5 | sess-1-000000 | 2026-01-01 | AUDIT | audit:::Task: audit filed F1.'
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
      hb_git add product.txt >/dev/null
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
      # that forbade sub-agents. A disclosed unavailability is a verdict;
      # silence is not.
      hb_write_journal_entries \
        '## iter 1/3 | sess-1-000000 | 2026-01-01 | AUDIT | audit:::Verification: audit only.' \
        '## iter 2/3 | sess-1-000000 | 2026-01-01 | T2 | converged:::Verification: Evaluator: unavailable (no sub-agents in this session)'
      hb_p2_fixture
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '')"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ]; then
        pass "stop hook accepts a declaration recording Evaluator: unavailable with a reason"
      else
        printf '%s\n' "$hb_out"
        fault "stop hook rejected a disclosed evaluator unavailability"
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

      # The companion bound: skipping those headings must not invent an
      # anchor where there is none. A run holding only rotation entries has
      # no primary entry to read a verdict from, which is the rotated-away
      # shape, and that fails open with the note rather than rejecting.
      hb_write_journal_entries \
        '## iter 2/3 | sess-1-000000 | 2026-01-01 | ROTATION | rotation:::Task: moved 40 entries to JOURNAL-archive.md.'
      hb_p2_fixture
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
        && grep -q 'skipping the evaluator check' "$hb_tmp/hb_err.txt"; then
        pass "stop hook fails open when this run's only journal entries are ROTATION entries"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt"
        fault "stop hook rejected a declaration over a journal holding only rotation entries for this run"
      fi

      # Fail-open contract: an infrastructure defect skips the check with a
      # stderr note, a discipline defect rejects. A missing journal and a
      # journal holding no entry for this run (rotated, or a legacy run id)
      # are both the former.
      rm -f "$hb_proj/JOURNAL.md"
      hb_p2_fixture
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
        && grep -q 'skipping the evaluator check' "$hb_tmp/hb_err.txt"; then
        pass "stop hook fails open on a missing JOURNAL.md at the evaluator check (stderr note)"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt"
        fault "stop hook mishandled a missing JOURNAL.md at the evaluator check"
      fi

      hb_write_journal_entries \
        '## iter 9/9 | sess-9-999999 | 2026-01-01 | T9 | done:::Verification: an earlier run, rotated away.'
      hb_p2_fixture
      hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
      if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] \
        && grep -q 'skipping the evaluator check' "$hb_tmp/hb_err.txt"; then
        pass "stop hook fails open when JOURNAL.md holds no entry for this run (rotated or legacy)"
      else
        printf '%s\n' "$hb_out"
        cat "$hb_tmp/hb_err.txt"
        fault "stop hook rejected a declaration over a journal carrying no entry for this run"
      fi

      hb_proj="$hb_saved_proj"; hb_state="$hb_saved_state"
    else
      echo "[SKIP] evaluator-verdict scenarios (git not on PATH)"
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
      hb_git add product.txt >/dev/null
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
      echo "[SKIP] probe-battery converged-tree scenarios (git not on PATH)"
    fi

    rm -rf "$hb_tmp"
  fi
else
  echo "[SKIP] stop hook behavior checks (jq not on PATH)"
fi

echo ""
if [ "$fail" -eq 0 ]; then
  echo "All checks passed."
  exit 0
fi
echo "Validation failed."
exit 1
