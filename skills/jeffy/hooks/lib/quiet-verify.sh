#!/usr/bin/env bash
# quiet-verify.sh - run a project's Verify command under the loop's own
# bound and report it in bounded form.
#
# Two roles, one file, on purpose:
#
#   sourced  - stop-hook.sh sources this and calls jeffy_verify_bound and
#              jeffy_verify_run, so the timeout ladder exists once. A second
#              copy of that ladder in the wrapper would drift from the one
#              the converged stop enforces, and a bound that means two
#              different things is worse than no wrapper at all.
#   executed - the loop runs it per iteration instead of the raw command.
#
# Why the wrapper exists: a green suite prints its whole passing output into
# the window every iteration, in a session where context already
# accumulates. The engine's own validator is hundreds of lines of "OK" on a green
# run. Success is therefore silent here, and only failure produces text.
#
# What silence must not cost: journal entries and published receipts quote
# verify counts ("119 OK, 0 FAIL"). If green printed nothing at all, the
# loop could no longer see that figure and the existing journal grammar
# would quietly lose a field the corpus already uses. So green prints one
# structured stderr line carrying the oracle class and, when PLAN.md
# declares a `Verify summary pattern:` regex, the single line of real output
# that matched it. One line in, hundreds out.
#
# Contract when executed:  quiet-verify.sh <plan-path> [project-root]
#   exit 0   : stdout silent; stderr `verify: green (Ns, oracle=<class>[, <summary>])`
#   exit rc  : stderr `verify: FAILED (exit rc, Ns) - last N lines:` + last N
#   timeout  : stderr `verify: TIMEOUT after Ns - last 20 lines:` + tail, exit 124
#   none     : stderr `verify: not configured`, exit 0 (preserves fail-open)
#   empty    : stderr `verify: the Command line is empty`, exit 2
#   no oracle: stderr `verify: oracle class not declared`, exit 2
set -u

# The one heading test, shared with the hook's jeffy_section (the hook sources
# this file, and the wrapper runs it alone, so it lives here): CR and trailing
# whitespace are dropped, and the heading is the section when it reads
# "## <Name>" alone or goes on with a space, a tab, "(" or ":" - a suffixed
# heading is read as the section. "## Nowhere" is not Now, and neither is
# "## Next-gen ideas" Next: a hyphen straight after the name is another word,
# and a dash after a space ("## Next - queued") is already the space rule.
# shellcheck disable=SC2016  # an awk program, not a shell expansion
jeffy_awk_heading='function jeffy_heading(h, names,    n, want, i, p, c) {
  sub(/\r$/, "", h); sub(/[ \t]+$/, "", h)
  n = split(names, want, "|")
  for (i = 1; i <= n; i++) {
    p = "## " want[i]
    if (index(h, p) != 1) continue
    c = substr(h, length(p) + 1, 1)
    if (c == "" || c == " " || c == "\t" || c == "(" || c == ":") return want[i]
  }
  return ""
}'

# The heading a writer meant when jeffy_heading found no section: the first
# heading line of any depth whose text begins with the section's words in any
# case ("## Verify commands", "## Surface Inventory", "### Verify command").
# The declaration refuses an absent section, and quoting the near miss is what
# makes that refusal a one-line repair.
jeffy_near_heading() { # $1 file, $2 section name
  awk -v name="$2" "$jeffy_awk_heading"'
    { sub(/\r$/, "") }
    /^#+/ {
      h = $0; sub(/^#+[ \t]*/, "", h)
      if (index(tolower(h), tolower(name)) == 1 && jeffy_heading($0, name) == "") { print; exit }
    }
  ' "$1" 2>/dev/null
}

# PLAN.md labelled-line reader, the only one: the wrapper and every hook check
# that reads a `## Verify command` field come through here, because two
# readers of one line disagreed in both directions - the hook wanted
# "Command: " with its space and read `Command:false` as no Command at all,
# so the converged stop ran no gate the wrapper had been running all along,
# and the hook trimmed the payload the wrapper ran raw. Prints the payload
# with the whitespace around it dropped (a markdown hard break is two trailing
# spaces); prints nothing when the label is absent. An absent label and a
# label with an empty payload are different states and the callers treat them
# differently, so presence is the exit status: 0 when the label exists, 1
# when the section exists without it, 2 when the file has no such section.
jeffy_plan_line() { # $1 plan path, $2 label
  # Scoped to the `## Verify command` section (P1-59): through 1.14.0 this
  # took the first matching label anywhere in the file, so a `Command:` line
  # quoted under Lessons made the per-iteration wrapper run one command and
  # the converged stop another.
  [ -f "$1" ] || return 2
  awk -v lbl="$2" "$jeffy_awk_heading"'
    { sub(/\r$/, "") }
    NR == FNR { if ($0 ~ /^[ \t]*(```|~~~)/) fences++; next }
    /^[ \t]*(```|~~~)/ { if (fences % 2 == 0) fenced = !fenced; next }
    fenced { next }
    /^## / { take = (jeffy_heading($0, "Verify command") != ""); if (take) sec = 1; next }
    take && index($0, lbl "\x3a") == 1 {
      v = substr($0, length(lbl) + 2)
      sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
      print v
      found = 1
      exit
    }
    END { exit(found ? 0 : (sec ? 1 : 2)) }
  ' "$1" "$1"
}

# The Command payload as both consumers run it. Markdown reflex wraps the
# command in backticks, and bash -c reads the pair as command substitution: it
# runs the output of the command instead of the command itself and exits 127.
# Strip one wrapping pair, only when both ends carry it and nothing between
# them does - a payload whose first and last backticks belong to two
# different substitutions is re-paired by a blind strip and then executes a
# command nobody wrote, and it parses, so bash -n cannot catch it. Exit status
# as jeffy_plan_line.
jeffy_plan_command() { # $1 plan path
  jpc_plan="$1"
  jpc_cmd="$(jeffy_plan_line "$jpc_plan" 'Command')"
  jpc_rc=$?
  case "$jpc_cmd" in
    '`'*'`')
      jpc_inner="${jpc_cmd#'`'}"; jpc_inner="${jpc_inner%'`'}"
      case "$jpc_inner" in
        *'`'*) ;;
        *) jpc_cmd="$jpc_inner" ;;
      esac
      ;;
  esac
  printf '%s' "$jpc_cmd"
  return "$jpc_rc"
}

# The verify bound, resolved exactly once for the whole engine: an explicit
# verify_timeout_seconds wins; else the measured `Verify duration: <N>s` in
# PLAN.md with 3x headroom for a loaded host, floored at 240 so a stale or
# tiny measurement can never make the gate twitchier than its default; else
# 240. (P1-31, and the engine's own repository met that refusal first: a
# 404s suite under a 240s default.)
# Capped at 1740s: the installer registers the hook with an 1800s timeout,
# and a bound the registration cannot honour is a declaration that is never
# adjudicated - Claude Code kills the hook mid-suite and leaves the state
# file as an orphan (P1-58). The clamp is said on stderr where it happens.
JEFFY_VERIFY_BOUND_CAP=1740
jeffy_verify_bound() { # $1 plan path, $2 verify_timeout_seconds from state (may be empty)
  # Leading zeros are dropped at both reads: an explicit 0 is unset rather
  # than GNU timeout's "no limit", and 08s is 8 rather than an octal error.
  vt="$(printf '%s' "${2:-}" | sed 's/^0*//')"
  case "$vt" in '' | *[!0-9]*)
    vd="$(jeffy_plan_line "$1" 'Verify duration' 2>/dev/null | sed -n 's/^0*\([0-9][0-9]*\)s.*/\1/p' | head -n 1)"
    case "$vd" in
      '' | *[!0-9]*) vt=240 ;;
      *) vt=$((vd * 3)); [ "$vt" -lt 240 ] && vt=240 ;;
    esac
  ;; esac
  if [ "$vt" -gt "$JEFFY_VERIFY_BOUND_CAP" ]; then
    echo "jeffy verify: the resolved bound of ${vt}s exceeds the ${JEFFY_VERIFY_BOUND_CAP}s cap the hook's registered 1800s timeout can honour; clamping to the cap" >&2
    vt="$JEFFY_VERIFY_BOUND_CAP"
  fi
  printf '%s' "$vt"
}

# Whether the Command runs under pipefail. A pipeline's exit status is its
# last stage's, so a failing suite behind `| tee verify.log` was green in the
# wrapper and at the converged stop; under pipefail a failure of any stage is
# the run's. The exception is a stage that closes its pipe before draining it
# (grep -q or -m, head, an awk that exits): the stage feeding it dies of
# SIGPIPE, status 141, so pipefail turns a healthy `suite | grep -q "0
# failures"` red, and turns a gate that reads a pipeline as its failure test
# (`... | grep -q FAIL && rc=1`, smithy-go's) green over a red suite. A
# Command holding such a stage runs as written. `set +o pipefail` at the head
# of a Command is the author's own way out.
jeffy_verify_pipefail() { # $1 command; prints -o or +o
  if printf '%s\n' "$1" | grep -Eq '(^|[^|])[|][[:space:]]*([ef]?grep[[:space:]]([^|;&]*[[:space:]])?(-[A-Za-z]*[qm]|--quiet|--silent|--max-count)|head([[:space:]]|$)|awk[[:space:]][^|]*exit)'; then
    printf '%s' '+o'
  else
    printf '%s' '-o'
  fi
}

# Run a command under the bound, output captured to a file, and return its
# real exit status (124 for a timeout). The gate has to run everywhere it is
# claimed to run: stock macOS ships no GNU timeout, and skipping the run
# there once left the README's loudest promise quietly false on a whole
# platform. Resolve timeout, then gtimeout, then a shell watchdog.
jeffy_verify_run() { # $1 project root, $2 command, $3 bound seconds, $4 output file
  vr_root="$1"; vr_cmd="$2"; vr_bound="$3"; vr_out="$4"
  vr_pf="$(jeffy_verify_pipefail "$vr_cmd")"
  vto=""
  if command -v timeout >/dev/null 2>&1; then
    vto=timeout
  elif command -v gtimeout >/dev/null 2>&1; then
    vto=gtimeout
  fi
  if [ -n "$vto" ]; then
    # -k: a suite that ignores SIGTERM is killed 5s past the bound, as the
    # watchdog below does. timeout then exits 137, not 124, and a kill at or
    # past the bound is the bound's. The outer 2>/dev/null drops the shell's
    # own "Killed" notice, which would otherwise land on the caller's stderr.
    vr_start="$(date +%s)"
    { ( cd "$vr_root" && PYTHONDONTWRITEBYTECODE=1 "$vto" -k 5 "$vr_bound" bash "$vr_pf" pipefail -c "$vr_cmd" ) >"$vr_out" 2>&1; } 2>/dev/null
    vr_rc=$?
    if [ "$vr_rc" -eq 137 ] && [ $(( $(date +%s) - vr_start )) -ge "$vr_bound" ]; then
      vr_rc=124
    fi
    return "$vr_rc"
  fi
  # Watchdog: run in the background and arm a killer that leaves a sentinel
  # behind before it fires. The sentinel is what tells a timeout apart from a
  # suite that took a SIGTERM of its own, which a bare exit status cannot.
  # Both background jobs detach their descriptors: the caller may read this
  # through a pipe, and a pipe is closed by its last writer, so a watchdog
  # still sleeping out its budget would hang that reader. Poll in one-second
  # steps so the watchdog exits as soon as the gate does.
  vr_sent="${TMPDIR:-/tmp}/jeffy-verify-timeout-$$"
  rm -f "$vr_sent"
  ( cd "$vr_root" && PYTHONDONTWRITEBYTECODE=1 bash "$vr_pf" pipefail -c "$vr_cmd" ) >"$vr_out" 2>&1 &
  vr_pid=$!
  ( vr_waited=0
    while [ "$vr_waited" -lt "$vr_bound" ]; do
      sleep 1
      kill -0 "$vr_pid" 2>/dev/null || exit 0
      vr_waited=$((vr_waited + 1))
    done
    : > "$vr_sent"
    kill -TERM "$vr_pid" 2>/dev/null
    sleep 5
    kill -KILL "$vr_pid" 2>/dev/null ) >/dev/null 2>&1 &
  vr_wpid=$!
  wait "$vr_pid" 2>/dev/null
  vr_rc=$?
  kill "$vr_wpid" 2>/dev/null
  wait "$vr_wpid" 2>/dev/null
  if [ -f "$vr_sent" ]; then
    vr_rc=124
  fi
  rm -f "$vr_sent"
  return "$vr_rc"
}

# The loop-facing wrapper. It lives in a function so a sourced copy defines
# it and runs nothing: the hook wants the two resolvers above and nothing
# else, while the loop invokes this file directly and gets the whole thing.
qv_main() {
  qv_plan="${1:-PLAN.md}"
  qv_root="${2:-$(dirname "$qv_plan")}"
  [ -f "$qv_plan" ] || { echo "verify: no PLAN.md at $qv_plan" >&2; exit 2; }

  qv_cmd="$(jeffy_plan_command "$qv_plan")" || {
    echo "verify: PLAN.md carries no Command: line" >&2; exit 2; }
  case "$qv_cmd" in
    '')
      # The converged stop refuses this line, so the run hears it here first.
      echo "verify: the Command line is empty; write the project's real gate, or none and a one-line reason" >&2
      exit 2
      ;;
    none | None | NONE)
      echo "verify: not configured" >&2
      exit 0
      ;;
    '<'*'>')
      # A fresh project still carrying the template's own placeholder. Running
      # it produces a bash syntax error reported as a failed suite, which
      # reads exactly like the project being broken - the one thing this
      # wrapper must never say when it is not true. The launch lint refuses a
      # placeholder at launch; this refuses it at the gate, and names it.
      #
      # Anchored, matching the hook's own oracle_unfilled rather than merely
      # resembling it: the payload has to BE a placeholder, not contain one.
      # Unanchored, this arm read any command carrying a redirect pair as
      # unfilled - `make test < /dev/null > out.log` was refused at exit 2
      # with a message naming the wrong cause, every iteration, while the
      # converged stop ran the same line without complaint because it calls
      # jeffy_verify_run directly and never reaches this guard. (A2)
      echo "verify: Command is still the template placeholder ($qv_cmd); the first audit fills it with the project's real gate, or with none and a one-line reason" >&2
      exit 2
      ;;
  esac

  # Oracle class, enforced here exactly as the converged stop enforces it and
  # never more strictly. A PLAN.md carrying neither the Oracle class nor the
  # Environment fingerprint line predates that rule and fails open with a note,
  # the way the hook treats it; a file carrying one of the two, or carrying the
  # label with nothing after it, is half-migrated or an unfilled template and
  # is refused. Refusing at iteration 2 rather than at the promise is the whole
  # point: the run finds out while it still has budget to answer.
  qv_oracle="$(jeffy_plan_line "$qv_plan" 'Oracle class')"; qv_oracle_present=$?
  jeffy_plan_line "$qv_plan" 'Environment fingerprint' >/dev/null; qv_fp_present=$?
  if [ "$qv_oracle_present" -ne 0 ] && [ "$qv_fp_present" -ne 0 ]; then
    echo "verify: no Oracle class line in PLAN.md (pre-1.8.0 shape); proceeding" >&2
    qv_oracle="undeclared"
  elif [ "$qv_oracle_present" -ne 0 ] || [ -z "$qv_oracle" ]; then
    echo "verify: oracle class not declared - fill the Oracle class line in PLAN.md with what the command actually grades, then re-run" >&2
    exit 2
  fi

  qv_budget="$(jeffy_plan_line "$qv_plan" 'Verify output budget')"
  case "$qv_budget" in '' | *[!0-9]*) qv_budget=80 ;; esac
  qv_pattern="$(jeffy_plan_line "$qv_plan" 'Verify summary pattern')"

  qv_bound="$(jeffy_verify_bound "$qv_plan" "${JEFFY_VERIFY_TIMEOUT_SECONDS:-}")"
  qv_out="$(mktemp "${TMPDIR:-/tmp}/jeffy-verify-XXXXXX")"
  qv_start="$(date +%s)"
  jeffy_verify_run "$qv_root" "$qv_cmd" "$qv_bound" "$qv_out"
  qv_rc=$?
  qv_secs=$(( $(date +%s) - qv_start ))

  if [ "$qv_rc" -eq 124 ]; then
    echo "verify: TIMEOUT after ${qv_secs}s (bound ${qv_bound}s) - last 20 lines:" >&2
    tail -n 20 "$qv_out" >&2
    rm -f "$qv_out"
    exit 124
  fi
  if [ "$qv_rc" -ne 0 ]; then
    echo "verify: FAILED (exit $qv_rc, ${qv_secs}s) - last $qv_budget lines:" >&2
    tail -n "$qv_budget" "$qv_out" >&2
    if [ "$qv_rc" -eq 141 ]; then
      echo "verify: exit 141 is SIGPIPE - a stage closed its pipe early and the Command runs under pipefail; let that stage drain its input, or open the Command with set +o pipefail" >&2
    fi
    rm -f "$qv_out"
    exit "$qv_rc"
  fi

  # Green. Nothing on stdout, ever - that silence is the feature. The stderr
  # line carries the summary so the journal can still quote a real figure.
  qv_summary=""
  if [ -n "$qv_pattern" ]; then
    qv_summary="$(grep -E "$qv_pattern" "$qv_out" 2>/dev/null | tail -n 1)"
  fi
  rm -f "$qv_out"
  # P1-66: the total on the summary line is a measurement this wrapper took,
  # so it is recorded where the hook reads it. The first integer on the
  # matched line is the count (`# pass 1064`, `422 passed in 0.46s`,
  # `verify totals: 39 passed`); a project whose summary carries no integer
  # records none and the cell check stays silent. Under .jeffy/metrics/ so
  # every guard that already excuses telemetry excuses this.
  if [ -n "$qv_summary" ] && command -v jq >/dev/null 2>&1; then
    qv_count="$(printf '%s' "$qv_summary" | grep -oE '[0-9]+' | head -n 1)"
    if [ -n "$qv_count" ] && mkdir -p "$qv_root/.jeffy/metrics" 2>/dev/null; then
      jq -n --arg c "$qv_count" --arg s "$qv_summary" --arg h "$(git -C "$qv_root" rev-parse HEAD 2>/dev/null)" --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{count: ($c | tonumber), summary: $s, head: $h, ts: $t}' > "$qv_root/.jeffy/metrics/verify-last.json" 2>/dev/null || true
    fi
  fi
  if [ -n "$qv_summary" ]; then
    echo "verify: green (${qv_secs}s, oracle=$qv_oracle, $qv_summary)" >&2
  else
    echo "verify: green (${qv_secs}s, oracle=$qv_oracle)" >&2
  fi
  exit 0
}

if [ "${0##*/}" = "quiet-verify.sh" ]; then
  qv_main "$@"
fi
