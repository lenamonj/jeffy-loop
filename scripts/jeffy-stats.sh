#!/usr/bin/env bash
# jeffy-stats.sh [project-root] - read a project's committed run telemetry.
#
# JOURNAL.md is prose: greppable, which is enough for one run and useless
# across fifty. The Stop hook writes one JSON record per turn end under
# .jeffy/metrics/, and this reads them back as the questions anyone actually
# asks of a corpus - how many iterations a run took, whether the map was
# clearing, how often the evaluator was reached, where the strikes fired.
#
# Plain shell and jq, matching the engine's own dependency floor, and a clean
# skip where jq is absent rather than a hard failure.
set -u

root="${1:-.}"
dir="$root/.jeffy/metrics"

if ! command -v jq >/dev/null 2>&1; then
  echo "jeffy-stats: jq not found on PATH; skipping (jq is the engine's own prerequisite)." >&2
  exit 0
fi
if [ ! -d "$dir" ]; then
  echo "jeffy-stats: no telemetry at $dir (no run has recorded one here yet)."
  exit 0
fi

files="$(find "$dir" -name '*.jsonl' -type f 2>/dev/null | sort)"
if [ -z "$files" ]; then
  echo "jeffy-stats: $dir holds no records yet."
  exit 0
fi

printf '%-26s %5s %7s %8s %6s %7s %8s\n' RUN ITERS UNSWEPT ABOVELOW GATE STRIKES WALL
total_iters=0
total_runs=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  run="$(basename "$f" .jsonl)"
  # Last record of a run carries its final position; the count of records is
  # the iterations it actually reached.
  iters="$(wc -l < "$f" | tr -d '[:space:]')"
  last="$(tail -n 1 "$f")"
  unswept="$(printf '%s' "$last" | jq -r '.rows_unswept // "-"')"
  above="$(printf '%s' "$last" | jq -r '.open_above_low // "-"')"
  gate="$(printf '%s' "$last" | jq -r '.evaluator_invocations // 0')"
  wall="$(printf '%s' "$last" | jq -r 'if .wall_elapsed_s then ((.wall_elapsed_s / 60) | floor | tostring) + "m" else "-" end')"
  strikes="$(jq -s '[.[] | (.stall_strike // 0) + (.oscillation_strike // 0) + (.overrun_strike // 0)] | add // 0' "$f")"
  printf '%-26s %5s %7s %8s %6s %7s %8s\n' "$run" "$iters" "$unswept" "$above" "$gate" "$strikes" "$wall"
  total_iters=$((total_iters + iters))
  total_runs=$((total_runs + 1))
done <<EOF
$files
EOF

echo
echo "runs: $total_runs   iterations: $total_iters"
# The figure a corpus is actually judged on, and the one no prose record can
# answer without being read end to end. The file list is newline-separated,
# so it is fed through a loop rather than word-split into jq's argv.
reached=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  n="$(jq -s '[.[] | select((.evaluator_invocations // 0) > 0)] | length' "$f" 2>/dev/null || echo 0)"
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  reached=$((reached + n))
done <<EOF
$files
EOF
echo "turn-ends with the evaluator gate already invoked: $reached"
