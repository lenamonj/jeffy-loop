#!/usr/bin/env bash
# Stage the whole tracked tree plus PLAN.md and the probes directory, under
# .jeffy/scratch/, and print the staged root. The whole tree is needed and not
# a subset: two arms resolve declared paths and row paths against the tree, so
# every tracked file is part of the surface they walk and a partial stage would
# report dead paths no mutation caused. PLAN.md is gitignored here, so it is
# copied rather than taken from the index.
set -eu
s=".jeffy/scratch/$1"
rm -rf "$s"
mkdir -p "$s"
git ls-files -z | xargs -0 cp --parents -t "$s"
cp PLAN.md "$s/"
# This battery's own files are not yet committed while it is being written.
mkdir -p "$s/.jeffy/probes/probes-meta"
cp .jeffy/probes/probes-meta/paths .jeffy/probes/probes-meta/run.sh "$s/.jeffy/probes/probes-meta/"
[ -f .jeffy/probes/probes-meta/claims ] && cp .jeffy/probes/probes-meta/claims "$s/.jeffy/probes/probes-meta/"
[ -f .jeffy/probes/probes-meta/README.md ] && cp .jeffy/probes/probes-meta/README.md "$s/.jeffy/probes/probes-meta/"
printf '%s\n' "$s"
