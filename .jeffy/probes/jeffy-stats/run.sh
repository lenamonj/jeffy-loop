#!/usr/bin/env bash
# Known-answer battery for scripts/jeffy-stats.sh - the maintainer telemetry
# reader that aggregates the Stop hook's per-turn JSON records.
#
# This is a surface that computes values, and PLAN.md's own rule for such a row
# is that a probe is a correctness check and not a liveness check: wrong numbers
# returned without complaint survive every liveness probe. The row's previous
# evidence was exactly a liveness probe - it exited 0 on an empty tree and said
# so in one line - so every figure the script derives was unverified. Each is
# known by construction here: the record files are written by this battery, so
# the iteration counts, the strike sums, the minute conversions and the
# gate-reached total are all arithmetic whose answer is fixed before the script
# runs.
#
# Expected: 31 executed checks. `grep -c '^ *ck "' run.sh` returns 34, and the
# difference is not a dropped check: the jq-absent branch writes its three
# checks once per arm, so three of the 34 sites can never run in the same
# pass. The executed figure is worked out from the arms before the run rather
# than read off a green one, and a disagreement with it is explained before it
# is edited. It read 24 against 27 until run 27 iteration 2, which added the
# seven token-column arms below: 1.28.0 gave this reader two new columns and
# two new parameters and left four of this battery's arms pinning the older
# header, so the instrument was red for a release while the columns it was
# meant to grade had no arm at all. The seven are counted here before the run,
# not read off it.
set -u
js_root="${JEFFY_PROBE_ROOT:-$PWD}"
js_sh="$js_root/scripts/jeffy-stats.sh"
[ -f "$js_sh" ] || { echo "jeffy-stats battery: no $js_sh"; exit 2; }
command -v jq >/dev/null 2>&1 ||
  { echo "jeffy-stats battery: NOT RUNNABLE: no jq on PATH, which is the script's own prerequisite; install jq"; exit 2; }

js_ok=0; js_bad=0
ck() { # $1 label, $2 expected, $3 actual
  if [ "$2" = "$3" ]; then js_ok=$((js_ok + 1)); else
    js_bad=$((js_bad + 1)); echo "FAIL $1: expected [$2] got [$3]"
  fi
}

js_tmp="$(mktemp -d)"
trap 'rm -rf "$js_tmp"' EXIT

# Squeeze the fixed-width table into a field sequence. The script prints with
# printf column widths, so comparing raw lines would pin the widths rather than
# the figures; the values are what this battery is about.
js_fields() { tr -s ' ' | sed 's/^ //; s/ $//'; }

# --- 1. the three documented early exits ------------------------------------
# Each is a branch a maintainer meets on a tree that has not run the loop, and
# each must exit 0 rather than fail: this is a reader, not a gate.
js_a="$js_tmp/no-dir"; mkdir -p "$js_a"
js_out="$(bash "$js_sh" "$js_a" 2>&1)"; js_rc=$?
ck "a tree with no telemetry directory exits 0" 0 "$js_rc"
ck "a tree with no telemetry directory says so" 1 \
  "$(printf '%s\n' "$js_out" | grep -c 'no telemetry at')"

js_b="$js_tmp/empty-dir"; mkdir -p "$js_b/.jeffy/metrics"
js_out="$(bash "$js_sh" "$js_b" 2>&1)"; js_rc=$?
ck "a telemetry directory with no records exits 0" 0 "$js_rc"
ck "a telemetry directory with no records says so" 1 \
  "$(printf '%s\n' "$js_out" | grep -c 'holds no records yet')"

# jq absent is a documented skip, not a failure. The needed binaries are
# symlinked in by name with jq deliberately left out, because a PATH holding
# only one directory also hides coreutils and the script would die at 127
# before reaching the branch under test - the defect the install-sh battery
# recorded. The guard is derived from the condition (is jq reachable, are the
# tools reachable) rather than from an exit code.
js_bin="$js_tmp/bin"; mkdir -p "$js_bin"
js_have=1
for js_t in find sort basename wc tr tail bash; do
  js_p="$(command -v "$js_t" 2>/dev/null)" || { js_have=0; break; }
  ln -sf "$js_p" "$js_bin/$js_t" || { js_have=0; break; }
done
if [ "$js_have" = 1 ] && ! PATH="$js_bin" command -v jq >/dev/null 2>&1; then
  js_out="$(PATH="$js_bin" bash "$js_sh" "$js_b" 2>"$js_tmp/err")"; js_rc=$?
  ck "jq absent is a skip at exit 0" 0 "$js_rc"
  ck "jq absent names jq on stderr" 1 "$(grep -c 'jq not found on PATH' "$js_tmp/err")"
  ck "jq absent prints nothing on stdout" "" "$js_out"
else
  echo "  note: could not build a jq-free PATH carrying the script's other tools; the jq-absent branch is not driven here"
  ck "jq absent is a skip at exit 0" skipped skipped
  ck "jq absent names jq on stderr" skipped skipped
  ck "jq absent prints nothing on stdout" skipped skipped
fi

# --- 2. the computed figures, known by construction -------------------------
# Two runs written here. Run A: three records, strikes spread across all three
# so a sum that reads only the last record is caught, the gate reached in two
# of the three records while only one run carries it at all, and 3720 seconds
# of wall time. Run B: two records, nothing set.
# Every figure below is arithmetic over those, fixed before the script runs.
js_c="$js_tmp/corpus"; mkdir -p "$js_c/.jeffy/metrics"
{
  echo '{"rows_unswept":9,"open_above_low":3,"stall_strike":1,"evaluator_invocations":1}'
  echo '{"rows_unswept":7,"open_above_low":3,"oscillation_strike":1}'
  echo '{"rows_unswept":5,"open_above_low":2,"evaluator_invocations":1,"overrun_strike":2,"wall_elapsed_s":3720}'
} > "$js_c/.jeffy/metrics/aaa-run.jsonl"
{
  echo '{"rows_unswept":1,"open_above_low":0}'
  echo '{"rows_unswept":0,"open_above_low":0,"evaluator_invocations":0,"wall_elapsed_s":59}'
} > "$js_c/.jeffy/metrics/bbb-run.jsonl"
js_out="$(bash "$js_sh" "$js_c" 2>&1)"; js_rc=$?
printf '%s\n' "$js_out" > "$js_tmp/corpus.out"
ck "a corpus run exits 0" 0 "$js_rc"
ck "the table header" "RUN ITERS UNSWEPT ABOVELOW GATE STRIKES WALL IN_M OUT_K" \
  "$(grep -m1 '^RUN' "$js_tmp/corpus.out" | js_fields)"
# Run A: 3 records; last record's unswept 5, above-low 2, gate 1; strikes
# 1 + 1 + 2 summed across records, never just the last; 3720s floors to 62m.
ck "the three-record run's figures" "aaa-run 3 5 2 1 4 62m - -" \
  "$(grep '^aaa-run' "$js_tmp/corpus.out" | js_fields)"
# Run B: 2 records; zeros are values and must print as 0 rather than "-";
# 59s floors to 0m, which is the boundary the minute conversion turns on.
ck "the two-record run's figures" "bbb-run 2 0 0 0 0 0m - -" \
  "$(grep '^bbb-run' "$js_tmp/corpus.out" | js_fields)"
ck "the run and iteration totals" "runs: 2 iterations: 5" \
  "$(grep '^runs:' "$js_tmp/corpus.out" | js_fields)"
# Counted per record, not per run, and the corpus is built so the two answers
# differ: two of the five records carry a non-zero invocation count while only
# one run does, so a per-run implementation reports 1 here and falls.
ck "the gate-reached total" "turn-ends with the evaluator gate already invoked: 2" \
  "$(grep '^turn-ends' "$js_tmp/corpus.out" | js_fields)"
# The file list is sorted, so the rows come out in name order.
ck "the runs are listed in sorted order" "aaa-run bbb-run" \
  "$(grep -E '^[ab]{3}-run' "$js_tmp/corpus.out" | awk '{print $1}' | tr '\n' ' ' | sed 's/ $//')"

# --- 2b. the token columns and the two parameters that shape them -----------
# 1.28.0 added IN_M and OUT_K to every row and --weights and --input-price
# behind them, and nothing here graded any of it. Records are cumulative per
# session, so a run's figure is the sum of each session's *last* record - not
# of every record, and not of the file's last record alone. The fixture is
# built so those three answers differ, which is what makes the arm mean
# anything: per-session-last gives an input side of 1,500,000 and 30,000 out,
# every record would give 2,065,000, and the file's last record alone 550,000.
js_t="$js_tmp/tokens"; mkdir -p "$js_t/.jeffy/metrics"
{
  echo '{"session8":"s1","tokens_input":100000,"tokens_cache_write_5m":10000,"tokens_cache_write_1h":10000,"tokens_cache_read":200000,"tokens_output":5000}'
  echo '{"session8":"s1","tokens_input":300000,"tokens_cache_write_5m":30000,"tokens_cache_write_1h":20000,"tokens_cache_read":600000,"tokens_output":20000}'
  echo '{"session8":"s2","tokens_input":100000,"tokens_cache_write_5m":5000,"tokens_cache_write_1h":0,"tokens_cache_read":140000,"tokens_output":4000}'
  echo '{"session8":"s2","tokens_input":200000,"tokens_cache_write_5m":10000,"tokens_cache_write_1h":0,"tokens_cache_read":340000,"tokens_output":10000}'
} > "$js_t/.jeffy/metrics/ttt-run.jsonl"
# IN_M is the four input-side components over a million to one decimal,
# 1500000/1e6; OUT_K truncates, 30000/1000.
ck "the token columns of a two-session run" "ttt-run 4 - - 0 0 - 1.5 30" \
  "$(bash "$js_sh" "$js_t" 2>&1 | grep '^ttt-run' | js_fields)"
# --weights adds two columns to the header and to every row; --input-price
# adds a third, and only with --weights (the script refuses it alone).
ck "the header with --weights" "RUN ITERS UNSWEPT ABOVELOW GATE STRIKES WALL IN_M OUT_K W_M READ_PCT" \
  "$(bash "$js_sh" "$js_t" --weights 1,1,1,1,1 2>&1 | grep -m1 '^RUN' | js_fields)"
ck "the header with --weights and --input-price" \
  "RUN ITERS UNSWEPT ABOVELOW GATE STRIKES WALL IN_M OUT_K W_M READ_PCT COST" \
  "$(bash "$js_sh" "$js_t" --weights 1,1,1,1,1 --input-price 4 2>&1 | grep -m1 '^RUN' | js_fields)"
# The one parameter is driven at two values that must move both columns it
# governs: flat weights total 1,530,000 with the cache read 61 percent of it,
# and 1,2,3,4,6 total 4,580,000 with the read 82 percent. A weight vector that
# changed neither figure would be a parameter whose value changes nothing.
ck "flat weights" "ttt-run 4 - - 0 0 - 1.5 30 1.5 61" \
  "$(bash "$js_sh" "$js_t" --weights 1,1,1,1,1 2>&1 | grep '^ttt-run' | js_fields)"
ck "weights that price the tiers apart" "ttt-run 4 - - 0 0 - 1.5 30 4.6 82" \
  "$(bash "$js_sh" "$js_t" --weights 1,2,3,4,6 2>&1 | grep '^ttt-run' | js_fields)"
# COST is the weighted total at the stated price per million, two decimals.
ck "the cost column at two prices" "6.12 18.32" \
  "$(bash "$js_sh" "$js_t" --weights 1,1,1,1,1 --input-price 4 2>&1 | grep '^ttt-run' | js_fields | awk '{print $12}') $(bash "$js_sh" "$js_t" --weights 1,2,3,4,6 --input-price 4 2>&1 | grep '^ttt-run' | js_fields | awk '{print $12}')"
# The boundary the share turns on: a record whose every token field is zero is
# a record with tokens, so IN_M and OUT_K are values and not dashes, while the
# read share has no denominator and falls back. A fallback firing on a
# legitimate zero, or a zero printed where the fallback belongs, shows here.
js_z="$js_tmp/zerotok"; mkdir -p "$js_z/.jeffy/metrics"
echo '{"session8":"s1","tokens_input":0,"tokens_cache_write_5m":0,"tokens_cache_write_1h":0,"tokens_cache_read":0,"tokens_output":0}' > "$js_z/.jeffy/metrics/zzz-run.jsonl"
ck "an all-zero token record is values with no share" "zzz-run 1 - - 0 0 - 0.0 0 0.0 -" \
  "$(bash "$js_sh" "$js_z" --weights 1,1,1,1,1 2>&1 | grep '^zzz-run' | js_fields)"

# --- 3. the missing-field fallbacks -----------------------------------------
# The script documents a fallback per field. Each is driven from a last record
# carrying none of them, so a fallback that silently became 0 or empty shows.
js_d="$js_tmp/sparse"; mkdir -p "$js_d/.jeffy/metrics"
echo '{"note":"a record carrying none of the read fields"}' > "$js_d/.jeffy/metrics/ccc-run.jsonl"
js_sparse="$(bash "$js_sh" "$js_d" 2>&1 | grep '^ccc-run' | js_fields)"
ck "a record with no read fields at all" "ccc-run 1 - - 0 0 - - -" "$js_sparse"
# And each field alone, so the fallbacks are not established only in a group.
js_one() { # $1 json, $2 field index (1-based within the squeezed row)
  local d="$js_tmp/one$2"; mkdir -p "$d/.jeffy/metrics"
  printf '%s\n' "$1" > "$d/.jeffy/metrics/ddd-run.jsonl"
  bash "$js_sh" "$d" 2>&1 | grep '^ddd-run' | js_fields | awk -v i="$2" '{print $i}'
}
ck "rows_unswept absent alone falls back" "-" \
  "$(js_one '{"open_above_low":4,"evaluator_invocations":2,"wall_elapsed_s":600}' 3)"
ck "open_above_low absent alone falls back" "-" \
  "$(js_one '{"rows_unswept":4,"evaluator_invocations":2,"wall_elapsed_s":600}' 4)"
ck "wall_elapsed_s absent alone falls back" "-" \
  "$(js_one '{"rows_unswept":4,"open_above_low":1,"evaluator_invocations":2}' 7)"

# --- 4. the one documented parameter, driven at values that must disagree ---
# The positional project root defaults to the working directory. Driven at two
# corpora whose outputs differ, and at the default from inside a tree with no
# telemetry, so a script ignoring its argument could not pass all three.
js_p1="$(bash "$js_sh" "$js_c" 2>&1 | grep -c '^aaa-run')"
js_p2="$(bash "$js_sh" "$js_d" 2>&1 | grep -c '^aaa-run')"
ck "the root argument selects the corpus it names" "1 0" "$js_p1 $js_p2"
ck "the two roots produce different output" 1 \
  "$([ "$(bash "$js_sh" "$js_c" 2>&1)" != "$(bash "$js_sh" "$js_d" 2>&1)" ] && echo 1 || echo 0)"
ck "no argument reads the working directory" 1 \
  "$(cd "$js_a" && bash "$js_sh" 2>&1 | grep -c 'no telemetry at')"

# --- 5. boundaries the arithmetic turns on ----------------------------------
# The minute conversion floors rather than rounds, which 119 seconds is the
# discriminating input for: a rounding implementation prints 2m.
js_w() { # $1 seconds
  local d="$js_tmp/w$1"; mkdir -p "$d/.jeffy/metrics"
  printf '{"wall_elapsed_s":%s}\n' "$1" > "$d/.jeffy/metrics/eee-run.jsonl"
  bash "$js_sh" "$d" 2>&1 | grep '^eee-run' | js_fields | awk '{print $7}'
}
ck "119 seconds floors to one minute" "1m" "$(js_w 119)"
ck "121 seconds floors to two minutes" "2m" "$(js_w 121)"
# find is recursive with no depth limit, so a record in a subdirectory of
# .jeffy/metrics is part of the corpus. Asserted because it is behaviour a
# reader would otherwise have to infer from the absence of -maxdepth.
js_n="$js_tmp/nested"; mkdir -p "$js_n/.jeffy/metrics/archive"
echo '{"rows_unswept":2,"open_above_low":0}' > "$js_n/.jeffy/metrics/archive/fff-run.jsonl"
ck "a record nested below the metrics directory is counted" "runs: 1 iterations: 1" \
  "$(bash "$js_sh" "$js_n" 2>&1 | grep '^runs:' | js_fields)"

echo "  jeffy-stats: $((js_ok + js_bad)) checks, $js_ok passed, $js_bad failed"
if [ "$js_bad" -eq 0 ]; then
  echo "jeffy-stats battery: $js_ok/$((js_ok + js_bad)) checks passed"
  exit 0
fi
echo "jeffy-stats battery: $js_ok/$((js_ok + js_bad)) checks passed, $js_bad FAILED"
exit 1
