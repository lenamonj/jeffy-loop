#!/usr/bin/env bash
#
# Reproduces the external conformance measurement reported in REPORT.md:
# the vendored YAML test suite scores identically before and after the run's
# changes.
#
# It clones pristine upstream twice, measures the corpus on the base commit,
# applies this receipt's fixes.patch to the second copy, and measures again.
# The converged tree itself is a local tree and is not published, so the
# patched clone is what stands in for it - fixes.patch is the run's product
# diff with the loop's own state files excluded, so the two are identical
# everywhere the corpus can see.
#
# Requires: git, go, bash. Network access to clone the target.
# Runtime: about a minute, most of it cloning.

set -euo pipefail

BASE=edee2f91616c6d73112a13e7c0dbde72ce938877
UPSTREAM=https://github.com/goccy/go-yaml.git
PATCH="$(cd "$(dirname "$0")" && pwd)/fixes.patch"

for tool in git go; do
  command -v "$tool" >/dev/null 2>&1 || { echo "missing required tool: $tool" >&2; exit 1; }
done
[ -f "$PATCH" ] || { echo "cannot find fixes.patch beside this script" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Two changes are needed before the corpus can run at all, and both are
# defects in the target's own harness rather than adjustments to suit us:
#
#   1. yaml_test_suite_test.go is build-tagged `!windows`, so the runner is
#      not compiled on Windows. On other platforms this is already a no-op.
#   2. the loader builds case names with strings.TrimPrefix(path, dir+"/"),
#      a hardcoded separator, so on Windows every name becomes an absolute
#      path and the suite's own known-failure list stops matching. ToSlash is
#      the identity function elsewhere, so this is also a no-op off Windows.
#
# Both are filed upstream as goccy/go-yaml#915. Neither touches library code,
# and neither is applied to the tree being measured - only to the harness that
# does the measuring, identically on both sides.
enable_corpus() {
  local dir="$1"
  sed -i.bak '1{/^\/\/go:build !windows$/d}' "$dir/yaml_test_suite_test.go"
  sed -i.bak 's|name := strings.TrimPrefix(path, dir+"/")|name := strings.TrimPrefix(filepath.ToSlash(path), filepath.ToSlash(dir)+"/")|' \
    "$dir/testdata/yaml-test-suite/yaml.go"
  rm -f "$dir/yaml_test_suite_test.go.bak" "$dir/testdata/yaml-test-suite/yaml.go.bak"
}

# core.autocrlf=false is not a preference here. The corpus compares raw bytes
# and YAML is whitespace sensitive, so a checkout that converts line endings
# fails 33 cases for that reason alone and the numbers become meaningless.
prepare() {
  local dir="$1"
  git clone -q -c core.autocrlf=false -c core.eol=lf "$UPSTREAM" "$dir"
  git -C "$dir" checkout -q "$BASE"
}

RESULTS="$WORK/results.txt"

measure() {
  local dir="$1"
  local label="$2"
  local log="$WORK/$label.log"
  local status=0
  ( cd "$dir" && go test -run TestYAMLTestSuite -count=1 -v . ) > "$log" 2>&1 || status=$?
  local ran passed failed
  ran="$(grep -c '^=== RUN   TestYAMLTestSuite/' "$log" || true)"
  passed="$(grep -c '^    --- PASS: TestYAMLTestSuite/' "$log" || true)"
  failed="$(grep -c '^    --- FAIL: TestYAMLTestSuite/' "$log" || true)"
  printf '%-14s %8s %8s %8s %8s\n' "$label" "$ran" "$passed" "$failed" "$status"
  printf '%s %s %s %s %s\n' "$label" "$ran" "$passed" "$failed" "$status" >> "$RESULTS"
}

echo "Cloning pristine upstream at ${BASE:0:8} (twice)..."
prepare "$WORK/base"
prepare "$WORK/patched"

echo "Applying this receipt's fixes.patch to the second copy..."
git -C "$WORK/patched" apply "$PATCH"

enable_corpus "$WORK/base"
enable_corpus "$WORK/patched"

echo
printf '%-14s %8s %8s %8s %8s\n' tree ran passed failed exit
printf '%-14s %8s %8s %8s %8s\n' -------------- -------- -------- -------- --------
measure "$WORK/base" base
measure "$WORK/patched" "base+fixes"
echo
echo "47 further cases are excluded by the suite's own failureTestNames list,"
echo "identically on both sides; 402 cases exist in total."
echo

# The exit status is itself a measurement. A reproduction script that prints
# numbers but succeeds regardless of what they are would carry the same
# defect this receipt reports in the target's own harness, where the printed
# pass rate is arithmetic over a constant. Both rows must match the figures
# REPORT.md publishes, or this script fails.
bad=0
while read -r label ran passed failed status; do
  if [ "$ran" != 355 ] || [ "$passed" != 355 ] || [ "$failed" != 0 ] || [ "$status" != 0 ]; then
    echo "MISMATCH: $label measured $ran ran / $passed passed / $failed failed (go test exit $status); REPORT.md publishes 355 / 355 / 0" >&2
    bad=1
  fi
done < "$RESULTS"
if [ "$bad" -ne 0 ]; then
  exit 1
fi
echo "Verified: both trees measure 355 ran / 355 passed / 0 failed, the figures"
echo "REPORT.md publishes. The run's changes moved the external oracle in"
echo "neither direction."
