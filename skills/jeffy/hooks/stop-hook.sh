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
JEFFY_VERSION="1.6.0"

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

# Run identity: the session prefix alone does not name a run. Relaunching
# /jeffy in the same Claude Code session reuses the session id, so several
# runs stamp identical headings and the journal cannot say where one ended -
# observed across six runs and 64 iterations on one project. The started_at
# time from the loop state, which is rewritten at every launch, separates
# them. A state file without it predates this and falls back to the prefix.
# Derived here rather than at the re-feed because the declaration's evaluator
# check reads the journal under the same run id the hygiene checks use, and
# two derivations of one identity drift.
runid8="${fm_session:0:8}"
run_tok="$(printf '%s' "$(fm started_at)" | sed -n 's/.*T\([0-9][0-9]\):\([0-9][0-9]\):\([0-9][0-9]\).*/\1\2\3/p')"
if [ -n "$run_tok" ]; then
  runid8="$runid8-$run_tok"
fi

# Extension honesty, first half: the +2 window buys the convergence sequence
# and never an audit. A full audit run inside the window manufactures the
# clean-audit precondition the declaration cites, and every other gate here
# is blind to it - the ledger stays empty, the rows stay swept, the verdict
# reads PASS. Observed twice before this check existed: python-dotenv run 3,
# then the TOML-M receipt, whose iteration-13 audit its declaration cited.
# The window is the last two iterations of the extended budget, so an AUDIT
# primary entry for this run numbered max-1 or higher ends the run out of
# budget on the spot - before any promise below can be read - and
# convergence falls to the next run's fresh audit, which is what the
# prompt's "never run an audit inside it" always meant. The second half of
# the honesty pair, the ledger-refill check, lives below the promise path.
if [ "$(fm extension_granted)" = "1" ] && [ -f "$root/JOURNAL.md" ]; then
  ext_max="$(fm max_iterations)"
  case "$ext_max" in ''|*[!0-9]*) ext_max="" ;; esac
  if [ -n "$ext_max" ]; then
    ext_audit="$(awk -v tok="| $runid8 |" -v lo=$((ext_max - 1)) '
      { sub(/\r$/, "") }
      /^## iter / && index($0, tok) {
        split($0, f, "|"); t = f[4]; gsub(/^[ \t]+|[ \t]+$/, "", t)
        n = f[1]; sub(/^## iter[ \t]*/, "", n); sub(/\/.*/, "", n)
        if (t == "AUDIT" && n + 0 >= lo) { print n + 0; exit }
      }
    ' "$root/JOURNAL.md")"
    if [ -n "$ext_audit" ]; then
      echo "jeffy stop hook: an AUDIT entry sits at iteration $ext_audit, inside the closing extension window; the extension buys the convergence sequence and never an audit, so a clean audit produced there is not a precondition a declaration may cite. Ending the run out of budget; convergence falls to the next run's fresh audit." >&2
      rm -f "$state"
      exit 0
    fi
  fi
fi

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
        # Converged line itself. Skipped in non-git projects. The line is
        # markdown a model writes, so a leading list marker and backticks
        # around the hash are tolerated; the section anchoring is not.
        conv_hash="$(awk '{ sub(/\r$/, "") } /^## Converged$/ { take = 1; next } /^## / { take = 0 } take && /^[-*] +Converged: / { sub(/^[-*] +/, "") } take && /^Converged: / { h = $2; gsub(/^`|`$/, "", h) } END { if (h) print h }' "$root/BACKLOG.md")"
        if [ -z "$conv_hash" ] || ! git -C "$root" rev-parse --verify --quiet "$conv_hash^{commit}" >/dev/null 2>&1; then
          violation="the ## Converged section of BACKLOG.md does not name a commit in this repository; append the Converged line for the certified checkpoint"
        else
          # .jeffy/ is loop memory too, so it joins the state files in the
          # exclusion: a row's known-answer battery lives under
          # .jeffy/probes/ and the checkpoints commit it, which makes a
          # battery written or refreshed on the way to the declaration
          # loop-state churn rather than a product change. Without this the
          # run that kept its instruments fails the nothing-but-state test
          # that the run which threw them away and rebuilt them passes, and
          # the persistence the probes exist for costs a declaration.
          nonstate="$(git -C "$root" diff --name-only "$conv_hash" HEAD 2>/dev/null | grep -vE '^(PLAN\.md|BACKLOG\.md|JOURNAL\.md|JOURNAL-archive\.md|\.jeffy/.*)$' | head -n 1)"
          if [ -n "$nonstate" ]; then
            violation="product path $nonstate changed after the Converged hash $conv_hash; certify the current tree before declaring"
          fi
        fi
      fi
      # Surface-inventory check: a convergence claim covers the whole mapped
      # surface. Dimension scores claim only what an audit examined, so an
      # unswept row is unexamined code behind a clean-looking score - a
      # None on a dimension whose surface was never opened is silence, not
      # cleanliness. A PLAN.md without the section predates this check and
      # fails open with a stderr note.
      if [ -z "$violation" ] && [ -f "$root/PLAN.md" ]; then
        if grep -q '^## Surface inventory' "$root/PLAN.md"; then
          unswept="$(awk '{ sub(/\r$/, "") } /^## Surface inventory$/ { take = 1; next } /^## / { take = 0 } take && /^- \[ \]/ { print; exit }' "$root/PLAN.md")"
          if [ -n "$unswept" ]; then
            violation="the Surface inventory in PLAN.md still lists an unswept row, first: $unswept; sweep it and record the commit, or record why it is out of scope, then re-declare convergence"
          fi
        else
          echo "jeffy stop hook: PLAN.md has no Surface inventory section; skipping the inventory check." >&2
        fi
      fi
      if [ -z "$violation" ]; then
        # Verify-command check: the project's own gate must be green at the
        # converged stop. A missing PLAN.md or an absent timeout binary is
        # an infrastructure defect: skip with a stderr note, never trap.
        if [ ! -f "$root/PLAN.md" ]; then
          echo "jeffy stop hook: PLAN.md missing at $root; skipping the verify check." >&2
        else
          # The template writes prose under the heading and the command on a
          # "Command: <cmd>" line, and only that labeled line is ever run.
          # Section prose fed to bash -c is not a gate, it is an accidental
          # command whose exit status means nothing, so a section without
          # the label skips the check with a note instead.
          verify_cmd="$(awk '{ sub(/\r$/, "") } /^## Verify command$/ { take = 1; next } /^## / { take = 0 } take && /^Command: / { sub(/^Command: /, ""); print; exit }' "$root/PLAN.md")"
          # A markdown hard break is two trailing spaces, so the payload
          # arrives padded often enough to matter: the padding defeats the
          # backtick pattern below, which anchors on both ends, and pads the
          # command quoted back in a violation. Trim before anything reads it.
          verify_cmd="${verify_cmd#"${verify_cmd%%[![:space:]]*}"}"
          verify_cmd="${verify_cmd%"${verify_cmd##*[![:space:]]}"}"
          # Both empty payloads skip the check, and the note has to say which
          # one it is: a section with no Command line at all is a different
          # edit to PLAN.md than a Command line holding nothing.
          vc_skip=""
          if [ -z "$verify_cmd" ]; then
            vc_skip="carries no Command line"
          fi
          # Markdown reflex wraps the command in backticks, and bash -c reads
          # the pair as command substitution: it runs the output of the
          # command instead of the command itself and exits 127. Strip one
          # wrapping pair, only when both ends carry it and nothing between
          # them does - a payload whose first and last backticks belong to two
          # different substitutions is re-paired by a blind strip and then
          # executes a command nobody wrote, and it parses, so bash -n below
          # cannot catch it.
          case "$verify_cmd" in
            '`'*'`')
              vc_inner="${verify_cmd#'`'}"; vc_inner="${vc_inner%'`'}"
              case "$vc_inner" in
                *'`'*) ;;
                *) verify_cmd="$vc_inner" ;;
              esac
              ;;
          esac
          if [ -z "$verify_cmd" ] && [ -z "$vc_skip" ]; then
            vc_skip="carries an empty Command line"
          fi
          if [ -n "$vc_skip" ]; then
            echo "jeffy stop hook: the Verify command section of PLAN.md $vc_skip; skipping the verify check." >&2
          elif [ "$verify_cmd" != "none" ]; then
            # An annotated line (cargo test (419 tests)) is not runnable
            # shell, and running it reports the parse failure as a mystery
            # exit status. Parse it first and name the defect; never guess
            # which trailing text was the annotation, and never execute a
            # line that did not parse.
            if ! verify_syntax="$(printf '%s\n' "$verify_cmd" | bash -n 2>&1)"; then
              violation="the Verify command line ($verify_cmd) is not runnable shell (bash -n: $(printf '%s' "$verify_syntax" | head -n 1)); make the Command line a pure runnable command with no annotation, then re-declare convergence"
            else
              # A pipeline's exit status is its last stage's. A gate ending in
              # a pager or truncator therefore reports head/tail/cat, not the
              # suite - observed twice in one day (python-dotenv, libuv), 13
              # failing tests behind an exit 0. Lint only when a pipe exists:
              # a pipe-free 'cat file' is the user's own command.
              vc_lint=""
              case "$verify_cmd" in
                *'|'*)
                  vc_last="${verify_cmd##*|}"
                  vc_last="${vc_last#"${vc_last%%[![:space:]]*}"}"
                  case "$vc_last" in
                    head|head\ *|tail|tail\ *|less|less\ *|more|more\ *|cat|cat\ *)
                      vc_lint="${vc_last%% *}"
                      ;;
                  esac
                  ;;
              esac
              if [ -n "$vc_lint" ]; then
                violation="the Verify command ($verify_cmd) ends in $vc_lint, so its exit status is the truncator's, not the suite's; drop the trailing stage, then re-declare convergence"
              else
                vt="$(fm verify_timeout_seconds)"
                case "$vt" in '' | *[!0-9]*) vt=240 ;; esac
                # The gate has to run everywhere it is claimed to run. A stock
                # macOS ships no GNU timeout, and skipping the run there left
                # the loudest promise in the README - the hook re-runs your
                # verify command - quietly false on a whole platform. Resolve
                # timeout, then gtimeout (Homebrew coreutils), then fall back
                # to a shell watchdog so the run always happens under a bound.
                vto=""
                if command -v timeout >/dev/null 2>&1; then
                  vto=timeout
                elif command -v gtimeout >/dev/null 2>&1; then
                  vto=gtimeout
                fi
                if [ -n "$vto" ]; then
                  ( cd "$root" && "$vto" "$vt" bash -c "$verify_cmd" ) >/dev/null 2>&1
                  vrc=$?
                else
                  # Watchdog: run the gate in the background and arm a killer
                  # that leaves a sentinel behind before it fires. The sentinel
                  # is what tells a timeout apart from a suite that took a
                  # SIGTERM of its own, which a bare exit status cannot.
                  vsent="${TMPDIR:-/tmp}/jeffy-verify-timeout-$$"
                  rm -f "$vsent"
                  ( cd "$root" && bash -c "$verify_cmd" ) >/dev/null 2>&1 &
                  vpid=$!
                  # Both background jobs must hold no inherited descriptor.
                  # The caller reads this hook through a pipe, and a pipe is
                  # closed by its last writer, not by the hook exiting: a
                  # watchdog still sleeping out its budget would keep that
                  # pipe open and hang the reader long after the gate had
                  # finished. Detach stdout and stderr on both.
                  # Poll in one-second steps rather than sleeping the whole
                  # budget: the watchdog then exits as soon as the gate does,
                  # instead of outliving the hook as an orphan holding a
                  # four-minute sleep.
                  ( vwaited=0
                    while [ "$vwaited" -lt "$vt" ]; do
                      sleep 1
                      kill -0 "$vpid" 2>/dev/null || exit 0
                      vwaited=$((vwaited + 1))
                    done
                    : > "$vsent"
                    kill -TERM "$vpid" 2>/dev/null
                    sleep 5
                    kill -KILL "$vpid" 2>/dev/null ) >/dev/null 2>&1 &
                  vwpid=$!
                  wait "$vpid" 2>/dev/null
                  vrc=$?
                  kill "$vwpid" 2>/dev/null
                  wait "$vwpid" 2>/dev/null
                  if [ -f "$vsent" ]; then
                    vrc=124
                  fi
                  rm -f "$vsent"
                fi
                if [ "$vrc" -eq 124 ]; then
                  violation="the Verify command ($verify_cmd) exceeded the ${vt}s timeout; get it green, then re-declare convergence"
                elif [ "$vrc" -ne 0 ]; then
                  violation="the Verify command ($verify_cmd) exited $vrc; get it green, then re-declare convergence"
                fi
              fi
            fi
          fi
        fi
      fi
      # Evaluator check: the adversarial gate is where the audits' misses were
      # found, and six of thirteen corpus convergences recorded no verdict at
      # all. The closing entry of this run is what must carry it - an earlier
      # entry's PASS answered an earlier tree - so the search starts at the
      # last primary heading stamped with this run id and reads to end of
      # file. A
      # RATCHET re-declares an unchanged tree and never invokes the gate by
      # design, so its type field exempts it. A missing journal, or one
      # holding no entry for this run (rotated away, or a run id predating the
      # started_at token), is an infrastructure defect and fails open.
      # ROTATION and SALVAGE are additional entries rather than closing ones:
      # a closing iteration that pushes JOURNAL.md past 500 lines appends its
      # ROTATION entry after the declaration, and a scan anchored at the last
      # heading would then read a window holding no verdict and reject a
      # declaration that carries one. The anchor is the last primary entry,
      # and a run whose only entries are those types has no anchor at all.
      # The verdict is matched as a substring anywhere after the anchor: it
      # normally lives in the entry's Verification field per journal-default,
      # a prose false-accept is bounded by the run report a human reads, and
      # a field-anchored match would reject every legacy journal instead.
      if [ -z "$violation" ]; then
        if [ ! -f "$root/JOURNAL.md" ]; then
          echo "jeffy stop hook: JOURNAL.md missing at $root; skipping the evaluator check." >&2
        else
          ev_verdict="$(awk -v tok="| $runid8 |" '
            { sub(/\r$/, "") }
            /^## iter / && index($0, tok) {
              split($0, f, "|"); t = f[4]; gsub(/^[ \t]+|[ \t]+$/, "", t)
              if (t == "ROTATION" || t == "SALVAGE") next
              found = 1; ev = 0; type = t; next
            }
            found && (index($0, "Evaluator: PASS") || index($0, "Evaluator: unavailable")) { ev = 1 }
            END { if (!found) print "none"; else if (type == "RATCHET" || ev) print "ok"; else print "missing" }
          ' "$root/JOURNAL.md")"
          if [ "$ev_verdict" = "none" ]; then
            echo "jeffy stop hook: JOURNAL.md holds no entry headed with the run id $runid8; skipping the evaluator check." >&2
          elif [ "$ev_verdict" = "missing" ]; then
            violation="the closing entry records no Evaluator verdict; run the adversarial evaluator gate (or record Evaluator: unavailable with the reason), then re-declare"
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

# Run-state facts, read once and used twice: the closing extension below turns
# on them and every re-feed states them. The model reads the last few journal
# entries and owns no arithmetic, so a budget it cannot see is a budget it
# feels rather than plans - "the arithmetic should have been done at iteration
# 7, not felt at iteration 9". Counting is the same section-scoped awk the
# promise path uses, per section here. A file that does not exist yields no
# count and the note simply omits that field: this is an accounting aid, never
# a gate, and an infrastructure gap must not block a re-feed.
open_now=""
open_next=""
open_later=""
if [ -f "$root/BACKLOG.md" ]; then
  read -r open_now open_next open_later <<< "$(awk '
    { sub(/\r$/, "") }
    /^## Now$/ { sec = 1; next }
    /^## Next$/ { sec = 2; next }
    /^## Later$/ { sec = 3; next }
    /^## / { sec = 0 }
    sec && /^- \[ \]/ { n[sec]++ }
    END { printf "%d %d %d", n[1], n[2], n[3] }
  ' "$root/BACKLOG.md")"
fi
unswept_rows=""
if [ -f "$root/PLAN.md" ] && grep -q '^## Surface inventory' "$root/PLAN.md"; then
  unswept_rows="$(awk '{ sub(/\r$/, "") } /^## Surface inventory$/ { take = 1; next } /^## / { take = 0 } take && /^- \[ \]/ { n++ } END { printf "%d", n }' "$root/PLAN.md")"
fi

# Extension honesty: the +2 window buys the convergence sequence - the gate,
# fixes for tasks that gate filed, the declaration - never new work. A ledger
# that refills inside the window from any other source ends the run at once,
# honestly out of budget, with the filed tasks kept for the next run. The
# exception is read from the journal: when the last primary entry for this
# run is the EVALUATOR gate, its filings ride the one-transaction endgame.
if [ "$(fm extension_granted)" = "1" ] && [ "$iter" -ge $((max - 1)) ] \
  && [ -n "$open_now" ] \
  && { [ "$open_now" != "0" ] || [ "$open_next" != "0" ] || [ "$open_later" != "0" ]; }; then
  last_type=""
  if [ -f "$root/JOURNAL.md" ]; then
    last_type="$(awk -v tok="| $runid8 |" '
      { sub(/\r$/, "") }
      /^## iter / && index($0, tok) {
        split($0, f, "|"); t = f[4]; gsub(/^[ \t]+|[ \t]+$/, "", t)
        if (t != "ROTATION" && t != "SALVAGE") type = t
      }
      END { print type }
    ' "$root/JOURNAL.md")"
  fi
  if [ "$last_type" != "EVALUATOR" ]; then
    echo "jeffy stop hook: the ledger refilled inside the closing extension (open tasks Now $open_now Next $open_next Later $open_later; last entry $last_type); the extension buys the convergence sequence, not new work. Ending the run out of budget; the filed tasks stay on the ledger for the next run." >&2
    rm -f "$state"
    exit 0
  fi
fi

# Budget spent: end the run and let the session stop. A convergence claim
# whose checks failed gets a stderr note instead of a silent swallow.
# One exception, taken once: a run whose ledger is empty and whose inventory
# is swept has nothing left but its convergence sequence, and that sequence
# costs two to three iterations nobody budgeted - six of fourteen runs across
# two projects died there with the work done. The grant is +2, recorded on the
# state file, and it applies just as much when a check rejected the promise at
# the last iteration: that rejection is repairable, and today it goes to
# stderr where nobody reads it. Conditions the hook cannot evaluate (no
# ledger, no inventory section) are not conditions it can grant on.
# Two shapes are not the boundary this grant was written for and take the
# plain exhaustion path instead. An iteration already past max is a
# hand-lowered budget, and extending it re-feeds arithmetic that runs
# negative ("-5 remain after it"), so only an iteration exactly at max
# grants. And the flag that makes the grant once-only is written by the
# rewriter at the frontmatter close, so a state file whose frontmatter never
# closes can never record it: the +2 would land every second turn forever
# with nothing accumulating to stop it. The guard tests the same ^---$ the
# rewriter counts, because a grant the rewriter cannot stamp is not a grant.
extension=""
if [ "$iter" -ge "$max" ]; then
  fm_close="$(grep -c '^---$' "$state" 2>/dev/null || true)"
  case "$fm_close" in '' | *[!0-9]*) fm_close=0 ;; esac
  if [ "$iter" -eq "$max" ] && [ "$fm_close" -ge 2 ] \
    && [ "$(fm extension_granted)" != "1" ] \
    && [ "$open_now" = "0" ] && [ "$open_next" = "0" ] && [ "$open_later" = "0" ] \
    && [ "$unswept_rows" = "0" ]; then
    extension=1
  else
    if [ -n "$violation" ]; then
      echo "jeffy stop hook: convergence rejected ($violation) but the budget is spent; ending the run." >&2
    fi
    rm -f "$state"
    exit 0
  fi
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
# Iteration hygiene at the re-feed boundary: the finished iteration must
# have journaled itself under the heading grammar. A missing JOURNAL.md is
# an infrastructure defect and fails open with a stderr note; a violation
# rides the re-feed as evidence, and the budget bounds retries.
hygiene=""
next=$((iter + 1))
if [ -f "$root/JOURNAL.md" ]; then
  if ! grep -qF -- "## iter $iter/$max | $runid8" "$root/JOURNAL.md"; then
    hygiene="iteration $iter wrote no JOURNAL.md entry with the heading ## iter $iter/$max | $runid8; record it before proceeding"
  fi
  # Duplicate-index hygiene: a user interrupt can leave the journal ahead of
  # the loop counter, and the re-fed iteration then writes a second primary
  # entry under an index that already holds one - two entries headed 10/10
  # on one run, after which per-iteration accounting is silently wrong.
  # Warn only: the entry is what gets corrected, never the state.
  # Without the started_at token runid8 is the bare session prefix, which
  # every run of the session shares, so an earlier run's entry at the next
  # index reads as a desync that never happened. No token, no check.
  if [ -n "$run_tok" ] && grep -qF -- "## iter $next/$max | $runid8" "$root/JOURNAL.md"; then
    hygiene="$hygiene${hygiene:+; also }JOURNAL.md already holds a primary entry headed ## iter $next/$max | $runid8; the loop counter may have desynced (a user interrupt), so continue at the next free index and say so in the entry"
  fi
else
  echo "jeffy stop hook: JOURNAL.md missing at $root; skipping the journal-entry check." >&2
fi
# Tracked-tree check: modified or deleted tracked paths mean the iteration
# ended without its checkpoint. Untracked files never fire it - salvage and
# the checkpoint's git add -A own those, and they may be user droppings the
# hook has no right to demand committed. Skipped without git or a born HEAD.
if command -v git >/dev/null 2>&1 && git -C "$root" rev-parse --verify HEAD >/dev/null 2>&1; then
  dirty="$(git -C "$root" status --porcelain --untracked-files=no 2>/dev/null | head -n 1)"
  if [ -n "$dirty" ]; then
    hygiene="$hygiene${hygiene:+; also }iteration $iter ended with uncommitted tracked changes ($dirty); checkpoint them"
  fi
fi
# Archive integrity: JOURNAL-archive.md is append-only across every rotation
# and every run, so its entry count can never fall. A rotation that writes the
# archive instead of appending to it destroys the run's own record, and nothing
# else notices, because the live journal looks healthy afterwards. Only the
# instruction guarded this before, and the instruction was not enough: a
# 64-iteration run on a third-party project lost 18 entries this way. A run
# with no recorded baseline - never rotated, or launched before this shipped -
# never fires.
cur_archive="none"
naive_archive="none"
if [ -f "$root/JOURNAL-archive.md" ]; then
  # An entry heading names an iteration number; the journal template's
  # heading-grammar example begins "## iter <i>/<N>" and is not an entry,
  # so the count anchors on a digit. The strict count is always stored.
  cur_archive="$(grep -c '^## iter [0-9]' "$root/JOURNAL-archive.md" 2>/dev/null || true)"
  case "$cur_archive" in '' | *[!0-9]*) cur_archive=0 ;; esac
  naive_archive="$(grep -c '^## iter ' "$root/JOURNAL-archive.md" 2>/dev/null || true)"
  case "$naive_archive" in '' | *[!0-9]*) naive_archive=0 ;; esac
fi
last_archive="$(fm last_archive)"
# A baseline written before the strict anchor counted the template line, so a
# strict count one below it is the correction and not a loss. That escape is
# one-shot: it holds only until the state file carries archive_migrated, which
# the rewrite below stamps on with the strict baseline. A permanent escape
# would mask every later one-entry loss in an archive that keeps the template
# line, which is exactly the archive this migration exists for.
archive_migrated="$(fm archive_migrated)"
case "$last_archive" in
  '' | none | *[!0-9]*) ;;
  *)
    if [ "$cur_archive" = "none" ]; then
      hygiene="$hygiene${hygiene:+; also }JOURNAL-archive.md held $last_archive entries at the previous turn end and is now missing; the archive is append-only, so restore it"
    elif [ "$cur_archive" -lt "$last_archive" ]; then
      if [ "$archive_migrated" != "1" ] && [ "$naive_archive" -ge "$last_archive" ]; then
        echo "jeffy stop hook: migrated a legacy JOURNAL-archive.md baseline of $last_archive to the strict count $cur_archive; template lines are excluded from the count from here on." >&2
      else
        hygiene="$hygiene${hygiene:+; also }JOURNAL-archive.md fell from $last_archive entries to $cur_archive; rotation must append to the archive and never overwrite it, so restore the lost entries"
      fi
    fi
    ;;
esac

# Stall gate: progress since the previous turn end means a path outside the
# loop's own state moved, or BACKLOG.md changed - an audit that files tasks is
# progress even without a commit. HEAD moving is NOT the signal, though it was
# until 1.7.0: the iteration prompt mandates a checkpoint commit and a
# bookkeeping commit every iteration, so HEAD moves at every turn end of every
# git project - which is every project in the corpus - and both strikes were
# unreachable in all of them, the note as much as the stop. So when the heads
# differ the hook asks what moved, filtering the diff against the same loop
# memory the converged-tree test excludes: PLAN.md, BACKLOG.md, JOURNAL.md,
# JOURNAL-archive.md, and .jeffy/, which holds the probe batteries. The
# iteration prompt's own stall rule carries that list too, aligned here.
# A recorded head this repository cannot resolve - a state file carried from
# another checkout, a rewritten history - is an infrastructure gap rather than
# evidence of a stall, and fails open as progress.
# The first re-feed initializes the baseline and never fires. A flat iteration
# rides a STALL note; the stall flag arms the second-strike stop. With no
# git HEAD and no ledger there is no signal at all: skip with a stderr note.
stall_note=""
new_stall=0
cur_head="none"
if command -v git >/dev/null 2>&1 && git -C "$root" rev-parse --verify HEAD >/dev/null 2>&1; then
  cur_head="$(git -C "$root" rev-parse HEAD 2>/dev/null || echo none)"
fi
cur_backlog="none"
if [ -f "$root/BACKLOG.md" ]; then
  cur_backlog="$(cksum < "$root/BACKLOG.md" | tr ' \t' '--')"
fi
last_head="$(fm last_head)"
last_backlog="$(fm last_backlog)"
stall_flag="$(fm stall)"
case "$stall_flag" in 1) stall_flag=1 ;; *) stall_flag=0 ;; esac
if [ "$cur_head" = "none" ] && [ "$cur_backlog" = "none" ]; then
  echo "jeffy stop hook: no git HEAD and no BACKLOG.md; skipping the stall check." >&2
elif [ -n "$last_head" ] || [ -n "$last_backlog" ]; then
  progress=0
  if [ "$cur_backlog" != "$last_backlog" ]; then
    progress=1
  elif [ "$cur_head" != "none" ] && [ "$cur_head" != "$last_head" ]; then
    if [ -n "$last_head" ] && [ "$last_head" != "none" ] \
      && git -C "$root" rev-parse --verify --quiet "$last_head^{commit}" >/dev/null 2>&1; then
      moved="$(git -C "$root" diff --name-only "$last_head" "$cur_head" 2>/dev/null | grep -vE '^(PLAN\.md|BACKLOG\.md|JOURNAL\.md|JOURNAL-archive\.md|\.jeffy/.*)$' | head -n 1)"
      [ -n "$moved" ] && progress=1
    else
      progress=1
    fi
  fi
  if [ "$progress" = "1" ]; then
    new_stall=0
  else
    # Two iteration types are exempt from the strike. A closeout audit that
    # files nothing legitimately changes state files only, and so does the
    # evaluator gate; two of them in a row are the correct shape of the
    # convergence sequence, not a stall, and a gate that ended the run there
    # would kill converging runs at the finish line. An exempt iteration is
    # transparent: no note, no strike, and the flag carried through
    # unchanged, so a flat task iteration on either side of the ceremony
    # still counts. The prompt's own stall rule keeps covering these types.
    stall_exempt=""
    if [ -f "$root/JOURNAL.md" ]; then
      stall_type="$(awk -v tok="| $runid8 |" -v it="$iter" '
        { sub(/\r$/, "") }
        /^## iter / && index($0, tok) {
          split($0, f, "|"); t = f[4]; gsub(/^[ \t]+|[ \t]+$/, "", t)
          if (t == "ROTATION" || t == "SALVAGE") next
          n = f[1]; sub(/^## iter[ \t]*/, "", n); sub(/\/.*/, "", n)
          if (n + 0 == it + 0) { print t; exit }
        }
      ' "$root/JOURNAL.md")"
      case "$stall_type" in
        AUDIT | EVALUATOR) stall_exempt="$stall_type" ;;
      esac
    fi
    if [ -n "$stall_exempt" ]; then
      new_stall="$stall_flag"
    elif [ "$stall_flag" = "1" ]; then
      # Second strike: the prompted hard-blocker close-out did not happen,
      # so the hook ends the stalled run itself, the way budget exhaustion
      # does - state deleted, stop allowed, evidence on stderr.
      echo "jeffy stop hook: two consecutive flat iterations (latest: iteration $iter) with nothing changed outside the loop state files; ending the run as stalled." >&2
      rm -f "$state"
      exit 0
    else
      new_stall=1
      stall_note="iteration $iter made no progress (nothing changed since the previous turn end outside PLAN.md, BACKLOG.md, JOURNAL.md, JOURNAL-archive.md, and .jeffy/, and BACKLOG.md is byte-identical); a second consecutive flat iteration ends the run"
    fi
  fi
fi

# The extension is granted by the same rewrite that advances the counter, so
# the new budget is on the state file before anything reads it: the iteration
# suffix, the run-state note, and the next turn's budget test all see max+2.
if [ -n "$extension" ]; then
  max=$((max + 2))
fi

tmp="$state.tmp"
# The rewriter owns the keys it names and prints every other line verbatim,
# so the schema is additive: a state file carrying keys this version never
# heard of survives the re-feed untouched. max_iterations and
# extension_granted are owned only on the re-feed that grants the extension;
# on every ordinary re-feed they fall through to the verbatim print, because a
# max_iterations rewritten unconditionally would re-extend the run every turn.
# archive_migrated rides along with the strict archive baseline it certifies:
# the baseline this rewrite stores is strict, so the naive escape above has
# done its one job and must never be taken again.
if awk -v n="$next" -v lh="$cur_head" -v lb="$cur_backlog" -v sf="$new_stall" -v la="$cur_archive" -v mx="$max" -v ex="$extension" '
  /^---$/ { fmc++; if (fmc == 2) { if (!slh) print "last_head: " lh; if (!slb) print "last_backlog: " lb; if (!ssf) print "stall: " sf; if (!sla) print "last_archive: " la; if (!sam) print "archive_migrated: 1"; if (ex && !sex) print "extension_granted: 1" } print; next }
  fmc == 1 && /^iteration: / { print "iteration: " n; next }
  fmc == 1 && ex && /^max_iterations: / { print "max_iterations: " mx; next }
  fmc == 1 && ex && /^extension_granted: / { print "extension_granted: 1"; sex = 1; next }
  fmc == 1 && /^last_head: / { print "last_head: " lh; slh = 1; next }
  fmc == 1 && /^last_backlog: / { print "last_backlog: " lb; slb = 1; next }
  fmc == 1 && /^stall: / { print "stall: " sf; ssf = 1; next }
  fmc == 1 && /^last_archive: / { print "last_archive: " la; sla = 1; next }
  fmc == 1 && /^archive_migrated: / { print "archive_migrated: 1"; sam = 1; next }
  { print }
' "$state" > "$tmp"; then
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
if [ -n "$hygiene" ]; then
  reason="$reason ITERATION HYGIENE: $hygiene."
fi
if [ -n "$stall_note" ]; then
  reason="$reason STALL: $stall_note."
fi
if [ -n "$extension" ]; then
  reason="$reason CLOSING EXTENSION: one-time +2 iterations granted because only the convergence sequence remains. No further extension will be granted."
fi
# The run-state note closes the reason, after the evidence the other notes
# carry: it is the arithmetic, not a finding. Fields the hook could not count
# are absent rather than guessed.
run_state="RUN STATE: iteration $next of $max; $((max - next)) remain after it"
if [ -n "$open_now" ]; then
  run_state="$run_state; open tasks Now $open_now Next $open_next Later $open_later"
fi
if [ -n "$unswept_rows" ]; then
  run_state="$run_state; unswept rows $unswept_rows"
fi
run_state="$run_state; jeffy v$JEFFY_VERSION"
reason="$reason $run_state."
# An empty ledger over a swept surface is not a finished run: the closing
# audit, the evaluator gate and the declaration are still to come, and runs
# that did not know that spent their last iterations discovering it.
if [ "$open_now" = "0" ] && [ "$open_next" = "0" ] && [ "$open_later" = "0" ] && [ "$unswept_rows" = "0" ]; then
  reason="$reason Only the convergence sequence remains; it typically needs 2 to 3 iterations (closing audit, evaluator gate, declaration); plan the remaining $((max - next)) accordingly."
fi
jq -n --arg reason "$reason" '{decision: "block", reason: $reason}'
exit 0
