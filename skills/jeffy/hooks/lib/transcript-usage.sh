#!/usr/bin/env bash
# transcript-usage.sh - what a session has consumed so far, in tokens and
# live context, read from its Claude Code transcript.
#
#   bash transcript-usage.sh <transcript_path> [since]
#   . transcript-usage.sh; jeffy_transcript_usage <transcript_path> [since]
#
# Prints one JSON object, keys in this order:
#   api_messages, tokens_input, tokens_cache_write_5m, tokens_cache_write_1h,
#   tokens_cache_read, tokens_output, context_tokens_last,
#   context_tokens_peak, model
# `since` is an ISO 8601 timestamp; messages stamped before it are left out,
# so conversation before a run's launch is not billed to the run. Empty or
# absent means no bound.
#
# Why it reads what it reads. A transcript holds one entry per content block
# and every entry repeats its message's usage, so a message is counted once,
# by .message.id. Sub-agents write their own files beside the session
# (<transcript minus .jsonl>/subagents/*.jsonl) and share no message id with
# it; the evaluator gate alone added 11 percent on a measured self-run, so
# they are read too. The one-hour and five-minute cache-write tiers are
# priced apart (2x and 1.25x the base input price), so they are kept apart.
# Context is the main session's alone: a sub-agent's window is not the
# loop's.
#
# What it cannot see. The transcript is written asynchronously and may not
# hold the final message at Stop time; the read is cumulative, so a late
# message is counted at the next Stop. An API failure leaves a "<synthetic>"
# assistant entry with zero usage; it is no message and no context, so it is
# dropped rather than allowed to zero context_tokens_last.
#
# The path is used only as a quoted shell word, so a Windows path with
# backslashes opens as given.
#
# Exit codes: 0 printed; 1 the path is not a readable file or jq is absent
# (nothing printed). Dependencies: bash, jq.
set -u

jeffy_transcript_usage() { # $1 transcript path, $2 optional since timestamp
  local since="${2:-}" f
  [ -f "${1:-}" ] && [ -r "$1" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  # First pass, per line and before any slurp, so a large transcript is
  # projected to four fields instead of held whole.
  # shellcheck disable=SC2016  # a jq program, not a shell expansion
  local pick='fromjson? // empty
    | select(type == "object" and .type == "assistant"
        and (.message | type) == "object"
        and (.message.usage | type) == "object"
        and .message.model != "<synthetic>")
    | select($since == "" or ((.timestamp // "")[:19]) >= ($since[:19]))
    | {id: .message.id, m: .message.model, u: .message.usage, src: $src}'
  {
    jq -cR --arg since "$since" --arg src main "$pick" < "$1"
    for f in "${1%.jsonl}"/subagents/*.jsonl; do
      [ -f "$f" ] || continue
      jq -cR --arg since "$since" --arg src sub "$pick" < "$f"
    done
  } | jq -cs '
    def ctx: (.u.input_tokens // 0) + (.u.cache_read_input_tokens // 0)
      + (.u.cache_creation_input_tokens // 0);
    unique_by(.id) as $msgs
    | map(select(.src == "main") | ctx) as $ctx
    | ($msgs | map(.u.cache_creation.ephemeral_1h_input_tokens // 0) | add // 0) as $w1h
    | {
        api_messages: ($msgs | length),
        tokens_input: ($msgs | map(.u.input_tokens // 0) | add // 0),
        tokens_cache_write_5m: (($msgs | map(.u.cache_creation_input_tokens // 0) | add // 0) - $w1h),
        tokens_cache_write_1h: $w1h,
        tokens_cache_read: ($msgs | map(.u.cache_read_input_tokens // 0) | add // 0),
        tokens_output: ($msgs | map(.u.output_tokens // 0) | add // 0),
        context_tokens_last: ($ctx | last // 0),
        context_tokens_peak: ($ctx | max // 0),
        model: (reduce .[].m as $m ([]; if any(.[]; . == $m) then . else . + [$m] end)
          | map(. // "") | join(","))
      }'
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  jeffy_transcript_usage "$@"
fi
