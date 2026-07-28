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
#    discipline against a silent regression in a future edit. Dependency-free
#    (grep).
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
  "independent evaluator gate" \
  "the only sub-agent review this Method authorizes" \
  "strong enough to fail" \
  "stops auditing for the rest of the run" \
  "a reduction is new code" \
  "## Surface inventory" \
  "silence, not cleanliness" \
  "lists no unswept row" \
  "a correctness check, not a liveness check" \
  "a comparable amount of surface" \
  "including underscore-private modules"
check_markers skills/jeffy/references/backlog-default.md \
  "## Proposed" \
  "## Settled classes" \
  "## Converged"
# Rotation must append. "Move all but the last 10 entries to JOURNAL-archive.md"
# reads as "write the archive" to a model that has never seen one, and the
# second rotation of a long run then destroys everything the first preserved -
# observed on bukosabino/ta, where 18 entries went and nothing noticed, because
# the live journal looks healthy afterwards.
check_markers skills/jeffy/references/journal-default.md \
  "Append-only." \
  "never overwriting it" \
  "so two runs in one session are told apart"
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
  "newly exposed rather than introduced"
if [ "$gm_missing" -eq 0 ]; then
  pass "jeffy skill files carry all governance markers"
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
    hb_write_plan() { # $1 verify command line for PLAN.md
      printf '# Plan\n\n## Verify command\n%s\n' "$1" > "$hb_proj/PLAN.md"
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
      printf '# Journal\n\n## iter %s/%s | sess-1-000000 | 2026-01-01 | T1 | done\n\nTask: t.\n' "$1" "$2" > "$hb_proj/JOURNAL.md"
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
    printf '# Plan\n\n## Surface inventory\n\n- [x] core: swept at abc1234 - all entry points probed\n- [ ] plots: unswept\n\n## Verify command\nnone\n' > "$hb_proj/PLAN.md"
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
    printf '# Plan\n\n## Surface inventory\n\n- [x] core: swept at abc1234 - all entry points probed\n- [x] plots: swept at abc1234 - all 20 functions probed\n\n## Verify command\nnone\n' > "$hb_proj/PLAN.md"
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
