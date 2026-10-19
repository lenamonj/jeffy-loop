#!/usr/bin/env bash
# measure-surface.sh - how much tracked source a run would have to audit, and
# whether that is more than the operator agreed to.
#
#   bash measure-surface.sh <project-root> [--ceiling <lines>]
#
# Prints one line, `lines=<n> files=<m>`, then the five largest files as
# `<lines> <path>`. With --ceiling, exits 3 when lines exceed it and prints
# the refusal the launcher and the campaign driver both show, so there is one
# message and one measurement rather than two that drift.
#
# Why the engine measures before it starts. Every iteration audits the whole
# surface, so wall clock and usage scale with the tree, and a budget approved
# as "5 rounds of 10" is approved blind when nobody has said how big the tree
# is. On 2026-10-18 a 234,821-line Rust runtime was launched on exactly that
# approval; the operator killed it twenty minutes in, saying he would never
# have started had he known the size. The size was knowable before iteration
# 1 for the cost of one git listing, so it is measured here, at launch, and a
# tree past the ceiling never starts: the operator either raises the ceiling
# on the command line, which is the informed approval the budget alone is not,
# or picks a smaller target.
#
# The measurement is a proxy. It counts lines in tracked files whose extension
# names a programming language, and skips directories that conventionally hold
# vendored or generated trees. It does not know that a file is generated, that
# a crate is out of the run's scope, or that half the lines are tests. It is a
# floor on what the audit reads, which is enough to refuse a tree that is an
# order of magnitude past anything that has converged.
#
# Exit codes: 0 measured (and under any ceiling); 2 the root is not a git
# work tree, so nothing was measured; 3 over the ceiling; 64 bad usage.
# Dependency-free: bash, git, wc, sort.
set -u

root="${1:-}"
ceiling=0
shift $(( $# > 0 ? 1 : 0 ))
while [ $# -gt 0 ]; do
  case "$1" in
    --ceiling)
      case "${2:-}" in
        ''|*[!0-9]*) echo "measure-surface: --ceiling takes a whole number of lines" >&2; exit 64 ;;
      esac
      ceiling="$2"; shift 2 ;;
    *) echo "measure-surface: unknown argument $1" >&2; exit 64 ;;
  esac
done
[ -n "$root" ] || { echo "usage: measure-surface.sh <project-root> [--ceiling <lines>]" >&2; exit 64; }
git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "measure-surface: $root is not a git work tree; nothing measured" >&2; exit 2; }

# Source extensions, one alternation. A tree in a language missing here measures
# low, never high, which is the safe direction for a ceiling.
ext='\.(c|cc|cpp|cxx|h|hh|hpp|cs|dart|ex|exs|go|java|js|jsx|kt|kts|lua|m|mm|php|py|rb|rs|scala|swift|ts|tsx|zig)$'
# Directories that conventionally hold code the project did not write or will
# regenerate; anchored at a path segment so `vendored_api.go` still counts.
skip='(^|/)(vendor|vendored|node_modules|third_party|thirdparty|external|_vendor)/'

# wc on the file list from git, read as NUL-separated so a path with a space
# or a quote is one path. Paths relative to the root, so wc runs there.
counts="$(cd "$root" && git ls-files -z \
  | tr '\0' '\n' | grep -E "$ext" | grep -vE "$skip" \
  | tr '\n' '\0' | xargs -0 -r wc -l 2>/dev/null \
  | grep -v ' total$' | sort -rn)"

lines=0; files=0
if [ -n "$counts" ]; then
  files="$(printf '%s\n' "$counts" | wc -l | tr -d ' ')"
  lines="$(printf '%s\n' "$counts" | { while read -r n _; do t=$(( ${t:-0} + n )); done; echo "${t:-0}"; })"
fi
echo "lines=$lines files=$files"
[ -n "$counts" ] && printf '%s\n' "$counts" | head -n 5 | sed 's/^[[:space:]]*//'

if [ "$ceiling" -gt 0 ] && [ "$lines" -gt "$ceiling" ]; then
  cat <<EOF
SURFACE OVER CEILING: $lines tracked source lines in $files files; the ceiling for this launch is $ceiling.
Every iteration audits the whole surface, so wall clock and usage grow with it. A tree this size was not part of the budget's approval.
Relaunch with --max-surface $lines (or any ceiling above the measurement) to run it knowingly, or --max-surface 0 to turn the check off for this run.
EOF
  exit 3
fi
exit 0
