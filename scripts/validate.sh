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
  "## Lessons" \
  "leaves no open task behind" \
  "run report" \
  "independent evaluator gate" \
  "the only sub-agent review this Method authorizes"
check_markers skills/jeffy/references/backlog-default.md \
  "## Proposed" \
  "## Settled classes" \
  "## Converged"
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
  "at most 2 evaluator invocations per run"
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
#     run with a stderr note; a foreign session's state file is left
#     untouched; and a project with no state file is a silent no-op. Needs jq
#     (the hook's own runtime dependency); skips cleanly without it.
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
    hb_out="$(hb_run sess-1 'still working' '')"
    if [ "$(printf '%s' "$hb_out" | jq -r '.decision' 2>/dev/null)" = "block" ] \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'Do the jeffy iteration now.' \
      && printf '%s' "$hb_out" | jq -r '.reason' | grep -qF 'Focus this run on: speed' \
      && grep -q '^iteration: 2$' "$hb_state"; then
      pass "stop hook re-feeds mid-budget (block, iteration advanced, prompt and focus in reason)"
    else
      printf '%s\n' "$hb_out"
      fault "stop hook mid-budget re-feed is broken"
    fi

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
    else
      echo "[SKIP] verify-command scenarios (coreutils timeout not on PATH)"
    fi

    hb_write_state sess-1 1 3
    rm -f "$hb_proj/BACKLOG.md"
    hb_out="$(hb_run sess-1 'done <promise>JEFFY CONVERGED</promise>' '' 2>"$hb_tmp/hb_err.txt")"
    if [ -z "$hb_out" ] && [ ! -f "$hb_state" ] && grep -q 'BACKLOG.md missing' "$hb_tmp/hb_err.txt"; then
      pass "stop hook fails open on a missing BACKLOG.md at promise time (stderr note)"
    else
      fault "stop hook mishandled a missing BACKLOG.md at promise time"
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
