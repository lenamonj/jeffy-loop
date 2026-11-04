#!/usr/bin/env bash
# Structural battery over the instruments themselves: every battery under
# .jeffy/probes/, and the Surface inventory rows that name them.
#
# Why it exists. A battery declares a paths file the engine reads to derive a
# row's staleness and a claims file the gate executes, so a battery that stops
# being reachable silently removes a gate - and the two halves fail in opposite
# directions. A battery no row names is never run by a sweep; a row whose
# battery does not exist cannot be derived by the closing gate at all.
#
# One arm here is not about batteries. PLAN.md carries two commands that
# classify inventory rows, one for staleness and one for coverage, and between
# them they read the row against its commit and the tree against the rows.
# Neither reads the row against the tree, so a row claiming a path that no
# longer exists is invisible to both - and one did: the renderer row carried
# scripts/render-banner.py, retired at 38ffc0f, and both commands stayed quiet
# for every run since. That arm is the third classifier, and PLAN.md's own
# Surface inventory section carries it as a command too, because a reader of
# that section should not have to find it here.
#
# Expected: 16 executed checks. `grep -c '^ *ck "' run.sh` returns 16 and no
# ck() sits inside a loop or a command substitution, so the static count and
# the executed count agree. A disagreement is explained before it is edited.
set -u
pm_root="${JEFFY_PROBE_ROOT:-$PWD}"
pm_dir="$pm_root/.jeffy/probes"
pm_plan="$pm_root/PLAN.md"
[ -d "$pm_dir" ] || { echo "probes-meta battery: no $pm_dir"; exit 2; }
[ -f "$pm_plan" ] || { echo "probes-meta battery: no $pm_plan"; exit 2; }

pm_ok=0; pm_bad=0
ck() { # $1 label, $2 expected, $3 actual
  if [ "$2" = "$3" ]; then pm_ok=$((pm_ok + 1)); else
    pm_bad=$((pm_bad + 1)); echo "FAIL $1: expected [$2] got [$3]"
  fi
}

pm_tmp="$(mktemp -d)"
trap 'rm -rf "$pm_tmp"' EXIT

find "$pm_dir" -mindepth 1 -maxdepth 1 -type d | sed "s|^$pm_dir/||" | sort > "$pm_tmp/batteries"
pm_n="$(grep -c . "$pm_tmp/batteries")"
ck "the battery population is plausible (>=15 directories)" yes \
  "$([ "$pm_n" -ge 15 ] && echo yes || echo "no ($pm_n)")"

# A directory name outside this class breaks the enumerating command the probes
# row is derived by, which reads names with exactly this character set.
ck "every battery directory name is one the enumerating command can read" "" \
  "$(grep -vE '^[A-Za-z0-9_-]+$' "$pm_tmp/batteries" | tr '\n' ' ' | sed 's/ *$//')"

# --- what every battery must carry ------------------------------------------
pm_nopaths=""; pm_emptypaths=""; pm_norun=""; pm_badrun=""
while IFS= read -r pm_b; do
  [ -f "$pm_dir/$pm_b/paths" ] || { pm_nopaths="$pm_nopaths$pm_b "; continue; }
  [ -s "$pm_dir/$pm_b/paths" ] || pm_emptypaths="$pm_emptypaths$pm_b "
  if [ -f "$pm_dir/$pm_b/run.sh" ]; then
    bash -n "$pm_dir/$pm_b/run.sh" 2>/dev/null || pm_badrun="$pm_badrun$pm_b "
  else
    pm_norun="$pm_norun$pm_b "
  fi
done < "$pm_tmp/batteries"
ck "every battery declares a paths file" "" "$(printf '%s' "$pm_nopaths" | sed 's/ *$//')"
ck "no declared paths file is empty" "" "$(printf '%s' "$pm_emptypaths" | sed 's/ *$//')"
ck "every battery carries a run.sh" "" "$(printf '%s' "$pm_norun" | sed 's/ *$//')"
ck "every run.sh parses" "" "$(printf '%s' "$pm_badrun" | sed 's/ *$//')"

# --- the paths a battery declares have to exist ------------------------------
# The engine reads these to decide whether a row went stale, so a path that is
# not there makes the derivation quietly narrower than the row claims.
pm_deadpath=""; pm_pathn=0
while IFS= read -r pm_b; do
  while IFS= read -r pm_p; do
    [ -n "$pm_p" ] || continue
    pm_pathn=$((pm_pathn + 1))
    [ -e "$pm_root/$pm_p" ] || pm_deadpath="$pm_deadpath$pm_b:$pm_p "
    # The Stop hook writes a telemetry record at every turn end and the next
    # checkpoint commits it, so a scope covering that directory is stale
    # immediately after every checkpoint and no re-sweep can ever clear it.
    case "$pm_p" in .jeffy/metrics|.jeffy/metrics/*) pm_deadpath="$pm_deadpath$pm_b:$pm_p(engine-owned) " ;; esac
  done < "$pm_dir/$pm_b/paths"
done < "$pm_tmp/batteries"
ck "the declared-path population is plausible (>=20 entries)" yes \
  "$([ "$pm_pathn" -ge 20 ] && echo yes || echo "no ($pm_pathn)")"
ck "every path a battery declares exists and is not engine-owned output" "" \
  "$(printf '%s' "$pm_deadpath" | sed 's/ *$//')"

# --- the claims file, which is what makes a battery re-executable ------------
# A battery with no claims file is an instrument whose discriminating power
# check-claims cannot grade: it reads this file and nothing else. The two that
# carry none are named rather than tolerated as slack, under a `known gap:`
# label, because a battery omitting them from the arm would read as coverage.
pm_noclaims=""; pm_badclaims=""; pm_noreadme=""
while IFS= read -r pm_b; do
  if [ -f "$pm_dir/$pm_b/claims" ]; then
    grep -qvE '^(expect .+ :: .+|none)$' "$pm_dir/$pm_b/claims" && pm_badclaims="$pm_badclaims$pm_b "
  else
    pm_noclaims="$pm_noclaims$pm_b "
  fi
  [ -f "$pm_dir/$pm_b/README.md" ] || pm_noreadme="$pm_noreadme$pm_b "
done < "$pm_tmp/batteries"
ck "every claims file holds only expect lines or the single word none" "" \
  "$(printf '%s' "$pm_badclaims" | sed 's/ *$//')"
ck "known gap: the batteries carrying no claims file (J14)" "install-ps1 language-pie" \
  "$(printf '%s' "$pm_noclaims" | sed 's/ *$//')"
ck "known gap: the batteries carrying no README (J14)" "install-ps1 language-pie" \
  "$(printf '%s' "$pm_noreadme" | sed 's/ *$//')"

# --- the two directions between a battery and a row --------------------------
# A battery no row names is never run by a sweep. The three that no row names
# are the probes row's own subject and are asserted as that set.
# A row names its battery in two positions and nowhere else: the `via` clause
# of its sweep record - written both as `swept via X` and as `swept at <hash>
# via X` in this file, so the clause rather than either phrasing is what is
# matched - and the machine-read Paths field. Reading any mention on the line is
# what this extraction did first, and it was wrong in the direction that
# flatters the map - two rows written in the same iteration explained in prose
# why a renderer battery sweeps nothing on this host, and both batteries
# promptly read as named. That is the whole-file-grep defect this row's own
# command already records, arriving one level in, so the fix is the same:
# positions, not mentions.
{ tr -d '\r' < "$pm_plan" | grep '^- \[' | grep -oE 'via `?\.jeffy/probes/[A-Za-z0-9_-]+' | sed 's|.*/||'
  tr -d '\r' < "$pm_plan" | sed -n 's/^- \[[ x~]\].* Paths: \(.*\)\.$/\1/p' | tr ' ' '\n' \
    | grep '^\.jeffy/probes/' | sed 's|\.jeffy/probes/||'
} | grep . | sort -u > "$pm_tmp/named"
ck "the named-battery population is non-empty" yes \
  "$([ "$(grep -c . "$pm_tmp/named")" -ge 1 ] && echo yes || echo no)"
ck "the batteries no inventory row names" "flowchart install-ps1 media-render" \
  "$(comm -23 "$pm_tmp/batteries" "$pm_tmp/named" | tr '\n' ' ' | sed 's/ *$//')"
# And the other direction: the closing gate derives a battery-bearing row's
# staleness from that battery's paths file, so a row naming a battery that does
# not exist is a row the gate cannot derive at all.
ck "every battery an inventory row names exists" "" \
  "$(comm -13 "$pm_tmp/batteries" "$pm_tmp/named" | tr '\n' ' ' | sed 's/ *$//')"

# --- the third row classifier ------------------------------------------------
# PLAN.md's staleness command reads a row against its commit and its coverage
# command reads the tree against the rows; neither reads a row against the
# tree. This is that reading, and it found a live instance when it was written.
tr -d '\r' < "$pm_plan" | sed -n 's/^- \[[ x~]\].* Paths: \(.*\)\.$/\1/p' \
  | tr ' ' '\n' | sed '/^$/d' | sort -u > "$pm_tmp/rowpaths"
ck "the row-path population is plausible (>=20 entries)" yes \
  "$([ "$(grep -c . "$pm_tmp/rowpaths")" -ge 20 ] && echo yes || echo "no ($(grep -c . "$pm_tmp/rowpaths"))")"
ck "every path an inventory row claims exists in the tree" "" \
  "$(while IFS= read -r pm_p; do [ -e "$pm_root/$pm_p" ] || printf '%s ' "$pm_p"; done < "$pm_tmp/rowpaths" | sed 's/ *$//')"

echo "  probes-meta: batteries=$pm_n declared-paths=$pm_pathn row-paths=$(grep -c . "$pm_tmp/rowpaths") named=$(grep -c . "$pm_tmp/named")"
if [ "$pm_bad" -eq 0 ]; then
  echo "probes-meta battery: $pm_ok/$((pm_ok + pm_bad)) checks passed"
  exit 0
fi
echo "probes-meta battery: $pm_ok/$((pm_ok + pm_bad)) checks passed, $pm_bad FAILED"
exit 1
