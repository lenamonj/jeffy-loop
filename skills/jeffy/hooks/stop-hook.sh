#!/usr/bin/env bash
# Jeffy Stop hook: the loop engine. Registered machine-wide in
# ~/.claude/settings.json by the installer and fired at every
# turn end of every session, so the no-state fast path comes first and stays
# silent. While .claude/jeffy-loop.local.md at the project root names this
# session and budget remains, the hook re-feeds the iteration prompt by
# blocking the stop; it deletes the state file and lets the session end when
# the budget is spent or the completion promise appears in the last assistant
# message. Anchored to CLAUDE_PROJECT_DIR, which hooks receive fixed at the
# directory Claude Code was started in, so Bash-tool cwd drift mid-iteration
# cannot kill the loop.
set -u

root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$root" ] || [ ! -d "$root" ]; then
  root="$(pwd)"
fi
state="$root/.claude/jeffy-loop.local.md"
[ -f "$state" ] || exit 0

# jq is a declared prerequisite; without it the hook cannot parse its stdin,
# so fail open (allow the stop) and say why, rather than trap the session.
if ! command -v jq >/dev/null 2>&1; then
  echo "jeffy stop hook: jq not found on PATH; not re-feeding. Install jq and re-run /jeffy." >&2
  exit 0
fi

input="$(cat)"
session_id="$(printf '%s' "$input" | jq -r '.session_id // empty')"

# Frontmatter fields are fixed single-line keys written by the /jeffy launch;
# the state file body never starts a line with any of them.
fm() { sed -n "s/^$1: //p" "$state" | head -n 1; }
fm_session="$(fm session_id)"
iter="$(fm iteration)"
max="$(fm max_iterations)"
prompt_path="$(fm prompt_path)"
focus="$(fm focus)"
promise="$(fm completion_promise)"

# Foreign or orphaned state file: another session owns it. Leave it alone;
# /jeffy pre-flight is the place that adjudicates orphans with the user.
if [ -z "$fm_session" ] || [ "$fm_session" != "$session_id" ]; then
  exit 0
fi

case "$iter$max" in
  '' | *[!0-9]*)
    echo "jeffy stop hook: malformed state file $state (iteration=$iter, max_iterations=$max); not re-feeding. Run /cancel-jeffy or delete the file." >&2
    exit 0
    ;;
esac

# Completion promise: prefer the last_assistant_message field newer CLIs put
# on stdin; fall back to the last assistant entry of the JSONL transcript.
violation=""
if [ -n "$promise" ]; then
  last="$(printf '%s' "$input" | jq -r '.last_assistant_message // empty')"
  if [ -z "$last" ]; then
    transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty')"
    if [ -n "$transcript" ] && [ -f "$transcript" ]; then
      last="$(jq -rRs 'split("\n") | map(fromjson? // empty) | map(select(.type == "assistant")) | (last // empty) | [.message.content[]? | select(.type == "text") | .text] | join("\n")' "$transcript" 2>/dev/null || true)"
    fi
  fi
  case "$last" in
    *"<promise>"*"$promise"*"</promise>"*)
      # Machine-checked converged stop: the promise alone does not end the
      # run; the closing claims must verify. A missing ledger is an
      # infrastructure defect and fails open; a discipline violation falls
      # through to the re-feed below with the evidence appended.
      if [ ! -f "$root/BACKLOG.md" ]; then
        echo "jeffy stop hook: BACKLOG.md missing at $root; accepting the promise unchecked." >&2
        rm -f "$state"
        exit 0
      fi
      open_tasks="$(awk '{ sub(/\r$/, "") } /^## (Now|Next|Later)$/ { take = 1; next } /^## / { take = 0 } take && /^- \[ \]/ { print }' "$root/BACKLOG.md")"
      if [ -n "$open_tasks" ]; then
        violation="BACKLOG.md still lists open tasks in Now, Next, or Later, first: $(printf '%s' "$open_tasks" | head -n 1)"
      elif command -v git >/dev/null 2>&1 && git -C "$root" rev-parse --verify HEAD >/dev/null 2>&1; then
        # Converged-hash check: the latest Converged line must name a commit
        # in this repository, and nothing but loop state may have changed
        # between it and HEAD - the ratchet's definition of an unchanged
        # tree. HEAD-exact equality would be unsatisfiable wherever the state
        # files are tracked, because the closing checkpoint commits the
        # Converged line itself. Skipped in non-git projects.
        conv_hash="$(awk '{ sub(/\r$/, "") } /^## Converged$/ { take = 1; next } /^## / { take = 0 } take && /^Converged: / { h = $2 } END { if (h) print h }' "$root/BACKLOG.md")"
        if [ -z "$conv_hash" ] || ! git -C "$root" rev-parse --verify --quiet "$conv_hash^{commit}" >/dev/null 2>&1; then
          violation="the ## Converged section of BACKLOG.md does not name a commit in this repository; append the Converged line for the certified checkpoint"
        else
          nonstate="$(git -C "$root" diff --name-only "$conv_hash" HEAD 2>/dev/null | grep -vE '^(PLAN\.md|BACKLOG\.md|JOURNAL\.md|JOURNAL-archive\.md)$' | head -n 1)"
          if [ -n "$nonstate" ]; then
            violation="product path $nonstate changed after the Converged hash $conv_hash; certify the current tree before declaring"
          fi
        fi
      fi
      if [ -z "$violation" ]; then
        rm -f "$state"
        exit 0
      fi
      ;;
  esac
fi

# Budget spent: end the run and let the session stop. A convergence claim
# whose checks failed gets a stderr note instead of a silent swallow.
if [ "$iter" -ge "$max" ]; then
  if [ -n "$violation" ]; then
    echo "jeffy stop hook: convergence rejected ($violation) but the budget is spent; ending the run." >&2
  fi
  rm -f "$state"
  exit 0
fi

# Re-feed: advance the iteration counter in place, then block the stop with
# the iteration prompt as the reason. The prompt file was resolved at launch;
# a moved or removed jeffy skills folder leaves it stale, in which
# case ending the loop with a pointer beats re-feeding garbage.
if [ ! -f "$prompt_path" ]; then
  echo "jeffy stop hook: iteration prompt missing at $prompt_path (was the jeffy skill moved or removed?); ending the loop. Re-run /jeffy to relaunch." >&2
  rm -f "$state"
  exit 0
fi
next=$((iter + 1))
tmp="$state.tmp"
if awk -v n="$next" '!done && /^iteration: / { print "iteration: " n; done = 1; next } { print }' "$state" > "$tmp"; then
  mv "$tmp" "$state"
else
  rm -f "$tmp"
  echo "jeffy stop hook: could not update $state; not re-feeding." >&2
  exit 0
fi
reason="$(cat "$prompt_path")"
if [ -n "$focus" ]; then
  reason="$reason Focus this run on: $focus."
fi
reason="$reason This is jeffy iteration $next of $max for this run."
if [ -n "$violation" ]; then
  reason="$reason CONVERGENCE REJECTED by the stop hook: $violation. Fix this, then re-declare convergence with the promise phrase."
fi
jq -n --arg reason "$reason" '{decision: "block", reason: $reason}'
exit 0
