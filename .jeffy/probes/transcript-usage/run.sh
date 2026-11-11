#!/usr/bin/env bash
# Known-answer battery for skills/jeffy/hooks/lib/transcript-usage.sh - the
# token and live-context reader the Stop hook sources for its turn record.
#
# This is a surface that computes values, so PLAN.md's rule for such a row is
# a correctness check per function family and never a liveness probe: wrong
# numbers returned without complaint survive every liveness probe, and every
# figure this reader prints reaches a user through `jeffy-stats`.
#
# The harness already carries four scenarios over this file (the aggregate
# figures on one fixture, one `since` value, an unreadable path and a
# backslashed path). What those cannot establish is what this battery is for,
# and the sharpest gap is one line of arithmetic: their fixture's
# context_tokens_last and context_tokens_peak are both 30005, so an
# implementation that returns `last` for both passes the harness. The fixture
# here is built so the two differ, so that the sub-agent's much larger window
# would move the peak if context were not the main session's alone, and so
# the `since` boundary is driven on both sides of its own comparison.
#
# Expected: 27 executed checks, or 28 on a host where chmod blocks the owner's
# own read, which the unreadable-file arm derives before it runs rather than
# inferring from an exit code. `grep -c '^ *ck "' run.sh` returns 28: the 26
# unconditional arms, that conditional one, and the arm that compares the
# executed total against the figure this paragraph states. The figure is
# worked out from the arms before the run and a disagreement with it is
# explained before it is edited.
set -u
tu_root="${JEFFY_PROBE_ROOT:-$PWD}"
tu_sh="$tu_root/skills/jeffy/hooks/lib/transcript-usage.sh"
[ -f "$tu_sh" ] || { echo "transcript-usage battery: no $tu_sh"; exit 2; }
command -v jq >/dev/null 2>&1 ||
  { echo "transcript-usage battery: NOT RUNNABLE: no jq on PATH, which is the reader's own prerequisite; install jq"; exit 2; }

tu_ok=0; tu_bad=0
ck() { # $1 label, $2 expected, $3 actual
  if [ "$2" = "$3" ]; then tu_ok=$((tu_ok + 1)); else
    tu_bad=$((tu_bad + 1)); echo "FAIL $1: expected [$2] got [$3]"
  fi
}
tu_tmp="$(mktemp -d)"
trap 'rm -rf "$tu_tmp"' EXIT

# --- the fixture, and the arithmetic fixed before the reader runs -----------
# Main session. Every figure below is a sum over these by hand:
#   A  ts :02  M1  in 100  create 1000 (1h 400)  read   5000  out  10   ctx  6100
#   B  ts :04  M1  in 200  create 2000 (1h   0)  read  50000  out  20   ctx 52200  <- peak
#   B  ts :05  repeated verbatim, as a transcript repeats a message per block
#   E  no ts   M1  in   1  create    0           read      2  out   3   ctx     3
#   C  ts :06  M2  in 300  create    0 (no object) read 7000  out  30   ctx  7300  <- last
#   D  ts :06  M1  no usage at all                                      (dropped)
#   S  ts :07  <synthetic>  all zero                                    (dropped)
# Sub-agent beside it:
#   G  ts :08  M3  in 1000 create  500 (1h 500)  read 900000 out 100   ctx 901500
# E sits before C on purpose, so the last main entry in file order is the one
# with the smaller window: an implementation reading the file's last line
# rather than the last picked one answers 3 here.
tu_s="$tu_tmp/s.jsonl"
mkdir -p "$tu_tmp/s/subagents"
cat > "$tu_s" <<'TU1'
{"type":"user","timestamp":"2026-01-01T00:00:01.000Z","message":{"role":"user","content":"hi"}}
{"type":"assistant","timestamp":"2026-01-01T00:00:02.000Z","message":{"id":"A","model":"M1","usage":{"input_tokens":100,"cache_creation_input_tokens":1000,"cache_read_input_tokens":5000,"output_tokens":10,"cache_creation":{"ephemeral_1h_input_tokens":400,"ephemeral_5m_input_tokens":600}}}}
{"type":"assistant","timestamp":"2026-01-01T00:00:04.000Z","message":{"id":"B","model":"M1","usage":{"input_tokens":200,"cache_creation_input_tokens":2000,"cache_read_input_tokens":50000,"output_tokens":20,"cache_creation":{"ephemeral_1h_input_tokens":0,"ephemeral_5m_input_tokens":2000}}}}
{"type":"assistant","timestamp":"2026-01-01T00:00:05.000Z","message":{"id":"B","model":"M1","usage":{"input_tokens":200,"cache_creation_input_tokens":2000,"cache_read_input_tokens":50000,"output_tokens":20,"cache_creation":{"ephemeral_1h_input_tokens":0,"ephemeral_5m_input_tokens":2000}}}}
{"type":"assistant","message":{"id":"E","model":"M1","usage":{"input_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":2,"output_tokens":3}}}
{"type":"assistant","timestamp":"2026-01-01T00:00:06.000Z","message":{"id":"C","model":"M2","usage":{"input_tokens":300,"cache_creation_input_tokens":0,"cache_read_input_tokens":7000,"output_tokens":30}}}
{"type":"assistant","timestamp":"2026-01-01T00:00:06.500Z","message":{"id":"D","model":"M1","content":[{"type":"text","text":"no usage on this entry"}]}}
{"type":"assistant","timestamp":"2026-01-01T00:00:07.000Z","message":{"id":"S","model":"<synthetic>","usage":{"input_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":0}}}
TU1
cat > "$tu_tmp/s/subagents/x.jsonl" <<'TU2'
{"type":"assistant","timestamp":"2026-01-01T00:00:08.000Z","message":{"id":"G","model":"M3","usage":{"input_tokens":1000,"cache_creation_input_tokens":500,"cache_read_input_tokens":900000,"output_tokens":100,"cache_creation":{"ephemeral_1h_input_tokens":500,"ephemeral_5m_input_tokens":0}}}}
TU2

tu_run() { bash "$tu_sh" "$@" 2>/dev/null; }
tu_f() { printf '%s' "$1" | jq -r "$2" 2>/dev/null; }

tu_all="$(tu_run "$tu_s")"
# --- 1. the five token sums and the message count --------------------------
# 5 messages: A, B (once, not twice), E, C from main and G from the sub-agent;
# D carries no usage and S is synthetic, so neither is a message.
ck "messages are counted once each, across main and sub-agent" 5 "$(tu_f "$tu_all" .api_messages)"
ck "tokens_input sums every counted message" 1601 "$(tu_f "$tu_all" .tokens_input)"
# creation 3500 total, of which 900 is the one-hour tier, so 2600 is five-minute.
ck "the five-minute tier is creation minus the one-hour tier" 2600 "$(tu_f "$tu_all" .tokens_cache_write_5m)"
ck "the one-hour tier is summed on its own" 900 "$(tu_f "$tu_all" .tokens_cache_write_1h)"
ck "tokens_cache_read sums every counted message" 962002 "$(tu_f "$tu_all" .tokens_cache_read)"
ck "tokens_output sums every counted message" 163 "$(tu_f "$tu_all" .tokens_output)"
# --- 2. context, which is the main session's alone and a peak, not a copy ---
# The two figures differ here, which is what the harness fixture cannot show:
# its own last and peak are the same number, so returning last for both passes
# it. B's window is the peak, C's is the last.
ck "context_tokens_last is the last picked main entry's window" 7300 "$(tu_f "$tu_all" .context_tokens_last)"
ck "context_tokens_peak is the largest main window, not the last" 52200 "$(tu_f "$tu_all" .context_tokens_peak)"
# The sub-agent's own window is 901500, an order of magnitude past the peak, so
# a reader that let sub-agents into the context answers that instead.
ck "the sub-agent's larger window never reaches the context" "52200 901500" \
  "$(tu_f "$tu_all" .context_tokens_peak) $(jq -r '(.message.usage.input_tokens + .message.usage.cache_read_input_tokens + .message.usage.cache_creation_input_tokens)' "$tu_tmp/s/subagents/x.jsonl")"
# --- 3. the model list: first-seen order, deduplicated ---------------------
ck "models are listed once each in first-seen order" "M1,M2,M3" "$(tu_f "$tu_all" .model)"
# --- 4. the documented key order ------------------------------------------
ck "the keys are printed in the documented order" \
  "api_messages tokens_input tokens_cache_write_5m tokens_cache_write_1h tokens_cache_read tokens_output context_tokens_last context_tokens_peak model" \
  "$(printf '%s' "$tu_all" | jq -r 'keys_unsorted | join(" ")' 2>/dev/null)"
# --- 5. the one documented parameter, at four values that change the output -
# The comparison is >=, so a bound equal to a message's own stamp keeps it.
tu_at="$(tu_run "$tu_s" 2026-01-01T00:00:06Z)"
ck "a since equal to a message's stamp keeps that message" 2 "$(tu_f "$tu_at" .api_messages)"
ck "a since equal to a message's stamp keeps its tokens" 1300 "$(tu_f "$tu_at" .tokens_input)"
# One second later and the same message is gone: the exclusive side of the
# same boundary, which also leaves the main file with no picked entry at all.
tu_after="$(tu_run "$tu_s" 2026-01-01T00:00:07Z)"
ck "a since one second past it drops that message" 1 "$(tu_f "$tu_after" .api_messages)"
ck "a since that excludes every main entry leaves context at zero" "0 0" \
  "$(tu_f "$tu_after" .context_tokens_last) $(tu_f "$tu_after" .context_tokens_peak)"
# The negative side: a bound past everything is no messages and no sums, which
# is the shape in which a fallback firing on a legitimate zero would show.
tu_none="$(tu_run "$tu_s" 2030-01-01T00:00:00Z)"
ck "a since past every message counts none and sums zero" "0 0 0 0 0 0 0 0" \
  "$(tu_f "$tu_none" '[.api_messages, .tokens_input, .tokens_cache_write_5m, .tokens_cache_write_1h, .tokens_cache_read, .tokens_output, .context_tokens_last, .context_tokens_peak] | join(" ")')"
ck "a since past every message leaves the model list empty" "" "$(tu_f "$tu_none" .model)"
# An entry with no timestamp cannot satisfy any bound, because the reader
# compares "" against it - so it is in without a bound and out with one.
tu_e="$tu_tmp/e.jsonl"
grep '"id":"E"' "$tu_s" > "$tu_e"
ck "an entry with no timestamp is counted without a bound and not with one" "1 0" \
  "$(tu_f "$(tu_run "$tu_e")" .api_messages) $(tu_f "$(tu_run "$tu_e" 2026-01-01T00:00:00Z)" .api_messages)"
# --- 6. a message with no model at all ------------------------------------
tu_m="$tu_tmp/m.jsonl"
printf '%s\n' '{"type":"assistant","timestamp":"2026-01-01T00:00:02.000Z","message":{"id":"N","usage":{"input_tokens":7,"cache_read_input_tokens":0,"cache_creation_input_tokens":0,"output_tokens":1}}}' > "$tu_m"
ck "a message naming no model is counted and contributes an empty name" "1 7 " \
  "$(tu_f "$(tu_run "$tu_m")" '[.api_messages, .tokens_input, .model] | join(" ")')"
# --- 7. the paths that print nothing, and the ones that print zeroes -------
tu_rc() { bash "$tu_sh" "$@" >"$tu_tmp/out" 2>"$tu_tmp/err"; printf '%s' $?; }
ck "a path that is not there returns 1" 1 "$(tu_rc "$tu_tmp/no-such.jsonl")"
ck "and prints nothing on stdout" 0 "$(wc -c < "$tu_tmp/out" | tr -d '[:space:]')"
ck "a directory returns 1" 1 "$(tu_rc "$tu_tmp/s")"
ck "no argument at all returns 1" 1 "$(tu_rc)"
: > "$tu_tmp/empty.jsonl"
ck "an empty transcript is read as an all-zero session at exit 0" "0 0 0 0" \
  "$(tu_rc "$tu_tmp/empty.jsonl") $(tu_f "$(tu_run "$tu_tmp/empty.jsonl")" '[.api_messages, .tokens_input, .context_tokens_peak] | join(" ")')"
printf 'not json at all\n{half an object\n' > "$tu_tmp/junk.jsonl"
ck "lines that are not JSON are dropped rather than failing the read" "0 0 0 0" \
  "$(tu_rc "$tu_tmp/junk.jsonl") $(tu_f "$(tu_run "$tu_tmp/junk.jsonl")" '[.api_messages, .tokens_input, .context_tokens_peak] | join(" ")')"
# chmod has to be shown to block this user's own read before the arm means
# anything: under root, and on a filesystem that drops modes, it does not.
cp "$tu_s" "$tu_tmp/noread.jsonl"; chmod 000 "$tu_tmp/noread.jsonl" 2>/dev/null
tu_expected=27
if [ -r "$tu_tmp/noread.jsonl" ]; then
  echo "  transcript-usage: SKIPPED the unreadable-file arm - chmod 000 left the file readable to this user (root, or a filesystem that drops modes)"
else
  tu_expected=28
  ck "a file this user cannot read returns 1" 1 "$(tu_rc "$tu_tmp/noread.jsonl")"
fi
chmod 644 "$tu_tmp/noread.jsonl" 2>/dev/null
# --- 8. the two roles one file has ----------------------------------------
# The hook sources this file and calls the function; the loop's own banner
# runs it. Both have to produce the same object, or the record and the
# command-line reading disagree about one session.
# shellcheck source=/dev/null
tu_sourced="$( . "$tu_sh"; jeffy_transcript_usage "$tu_s" )"
ck "sourced and executed produce the same object" "$tu_all" "$tu_sourced"

ck "the executed check count is the one worked out before the run" "$tu_expected" "$((tu_ok + tu_bad + 1))"
echo "  transcript-usage: $((tu_ok + tu_bad)) checks, $tu_ok passed, $tu_bad failed (expected $tu_expected)"
if [ "$tu_bad" -eq 0 ]; then
  echo "transcript-usage battery: $tu_ok/$((tu_ok + tu_bad)) checks passed"
  exit 0
fi
echo "transcript-usage battery: $tu_ok/$((tu_ok + tu_bad)) checks passed, $tu_bad FAILED"
exit 1
