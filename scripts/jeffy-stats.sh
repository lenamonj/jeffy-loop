#!/usr/bin/env bash
# jeffy-stats.sh [project-root] [--weights in,w5m,w1h,read,out] [--input-price <usd per million>]
# - read a project's committed run telemetry.
#
# JOURNAL.md is prose: greppable, which is enough for one run and useless
# across fifty. The Stop hook writes one JSON record per turn end under
# .jeffy/metrics/, and this reads them back as the questions anyone actually
# asks of a corpus - how many iterations a run took, whether the map was
# clearing, how often the evaluator was reached, where the strikes fired.
#
# Tokens (from 1.28.0). A record's token fields are cumulative over its
# session, so a run's figure is each session's last record summed, and an
# iteration's own consumption is its record minus the previous record of the
# same session. Tokens are not cost: a cache read is billed at a fraction of
# the base input price that differs by model, so weights and a price come
# only from the operator (--weights, --input-price) and nothing here carries
# a default. docs/usage.md gives the multipliers from the pricing page.
#
# Plain shell and jq, matching the engine's own dependency floor, and a clean
# skip where jq is absent rather than a hard failure.
set -u

usage="usage: jeffy-stats.sh [project-root] [--weights in,w5m,w1h,read,out] [--input-price <usd per million>]"
root="."
weights=""
price=""
while [ $# -gt 0 ]; do
  case "$1" in
    --weights)
      if ! printf '%s' "${2:-}" | grep -Eq '^[0-9]+(\.[0-9]+)?(,[0-9]+(\.[0-9]+)?){4}$'; then
        echo "jeffy-stats: --weights takes five comma-separated non-negative decimals (input, five-minute write, one-hour write, cache read, output), got '${2:-}'." >&2
        echo "$usage" >&2
        exit 2
      fi
      weights="$2"; shift 2 ;;
    --input-price)
      if ! printf '%s' "${2:-}" | grep -Eq '^[0-9]+(\.[0-9]+)?$'; then
        echo "jeffy-stats: --input-price takes one non-negative decimal (USD per million base input tokens), got '${2:-}'." >&2
        echo "$usage" >&2
        exit 2
      fi
      price="$2"; shift 2 ;;
    -*)
      echo "jeffy-stats: unknown argument '$1'." >&2
      echo "$usage" >&2
      exit 2 ;;
    *) root="$1"; shift ;;
  esac
done
if [ -n "$price" ] && [ -z "$weights" ]; then
  echo "jeffy-stats: --input-price prices weighted units, so it needs --weights." >&2
  echo "$usage" >&2
  exit 2
fi
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

# The token columns of one row, padded to the header's widths. Reads
# "<in> <w5m> <w1h> <read> <out>" (or "-") on stdin; the weights and price
# reach awk through the environment, never -v. $1 is "run" or "type": a type
# row has no share and no cost.
tok_cols() {
  JS_W="$weights" JS_P="$price" JS_MODE="$1" awk '
    {
      mode = ENVIRON["JS_MODE"]; w = ENVIRON["JS_W"]; p = ENVIRON["JS_P"]
      if ($1 == "-") { inm = "-"; outk = "-"; wm = "-"; pct = "-"; cost = "-" }
      else {
        inm = sprintf("%.1f", ($1 + $2 + $3 + $4) / 1000000)
        outk = int($5 / 1000)
        if (w != "") {
          split(w, k, ",")
          tot = $1 * k[1] + $2 * k[2] + $3 * k[3] + $4 * k[4] + $5 * k[5]
          wm = sprintf("%.1f", tot / 1000000)
          pct = tot > 0 ? sprintf("%.0f", 100 * $4 * k[4] / tot) : "-"
          if (p != "") cost = sprintf("%.2f", tot * p / 1000000)
        }
      }
      s = sprintf(" %6s %6s", inm, outk)
      if (w != "") s = s sprintf(" %6s", wm)
      if (w != "" && mode == "run") s = s sprintf(" %8s", pct)
      if (p != "" && mode == "run") s = s sprintf(" %8s", cost)
      print s
    }'
}

hdr="$(printf '%-26s %5s %7s %8s %6s %7s %8s %6s %6s' RUN ITERS UNSWEPT ABOVELOW GATE STRIKES WALL IN_M OUT_K)"
[ -n "$weights" ] && hdr="$hdr$(printf ' %6s %8s' W_M READ_PCT)"
[ -n "$price" ] && hdr="$hdr$(printf ' %8s' COST)"
printf '%s\n' "$hdr"
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
  # Records are cumulative per session, so the run is the sum of each
  # session's last measured record; group_by is stable, so last is file order.
  toks="$(jq -s -r '[.[] | select(.tokens_input != null)]
    | if length == 0 then "-" else
        group_by(.session8) | map(last)
        | [ (map(.tokens_input // 0) | add), (map(.tokens_cache_write_5m // 0) | add),
            (map(.tokens_cache_write_1h // 0) | add), (map(.tokens_cache_read // 0) | add),
            (map(.tokens_output // 0) | add) ]
        | map(tostring) | join(" ")
      end' "$f" 2>/dev/null)"
  printf '%-26s %5s %7s %8s %6s %7s %8s%s\n' "$run" "$iters" "$unswept" "$above" "$gate" "$strikes" "$wall" \
    "$(printf '%s\n' "${toks:--}" | tok_cols run)"
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

# Per iteration type: each measured record minus the previous record of the
# same session in the same file, a session's first record counted whole. The
# engine's ceremony types stand on their own; task ids pool as "task" and a
# record whose journal named no type as "other".
deltas=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  d="$(jq -s -r '[.[] | select(.tokens_input != null)]
    | reduce .[] as $r ({prev: {}, rows: []};
        ($r.session8 // "") as $k
        | ([$r.tokens_input, $r.tokens_cache_write_5m, $r.tokens_cache_write_1h,
            $r.tokens_cache_read, $r.tokens_output] | map(. // 0)) as $v
        | .prev[$k] as $p
        | .rows += [{t: $r.iter_type,
            d: (if $p == null then $v else [range(0; 5) as $i | $v[$i] - $p[$i]] end)}]
        | .prev[$k] = $v)
    | .rows[]
    | (.t as $t
       | if $t == null then "other"
         elif (["AUDIT", "EVALUATOR", "SWEEP", "RATCHET", "WRAPUP", "SALVAGE", "ROTATION"]
               | map(. == $t) | any) then $t
         else "task" end) + " " + (.d | map(tostring) | join(" "))' "$f" 2>/dev/null)"
  [ -n "$d" ] && deltas="$deltas$d
"
done <<EOF
$files
EOF
if [ -n "$deltas" ]; then
  echo
  echo "BY TYPE"
  bt_hdr="$(printf '%-10s %7s %6s %6s' TYPE RECORDS IN_M OUT_K)"
  [ -n "$weights" ] && bt_hdr="$bt_hdr$(printf ' %6s' W_M)"
  printf '%s\n' "$bt_hdr"
  for t in AUDIT EVALUATOR SWEEP RATCHET WRAPUP SALVAGE ROTATION task other; do
    sums="$(printf '%s' "$deltas" | JS_T="$t" awk '$1 == ENVIRON["JS_T"] { n++; a += $2; b += $3; c += $4; d += $5; e += $6 }
      END { if (n) printf "%d %.0f %.0f %.0f %.0f %.0f\n", n, a, b, c, d, e }')"
    [ -n "$sums" ] || continue
    read -r n a b c d e <<EOS
$sums
EOS
    printf '%-10s %7s%s\n' "$t" "$n" "$(printf '%s %s %s %s %s\n' "$a" "$b" "$c" "$d" "$e" | tok_cols type)"
  done
fi
