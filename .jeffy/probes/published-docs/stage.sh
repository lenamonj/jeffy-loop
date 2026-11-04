#!/usr/bin/env bash
# Stage the whole tracked tree, under .jeffy/scratch/, and print the staged
# root. Nothing smaller works: the orphan arm asks which media files no tracked
# file references, so every tracked file is part of the surface it walks, and a
# stage holding only the pages this battery is about reported eleven orphans
# the mutation never caused on its first run - the partial-stage defect the
# docs battery already recorded. The stage is a git repository of its own
# because three arms read the index.
set -eu
s=".jeffy/scratch/$1"
rm -rf "$s"
mkdir -p "$s"
git ls-files -z | xargs -0 cp --parents -t "$s"
# This battery's own files are not yet committed when it is being written, so
# the working-tree copy is overlaid rather than taken from the index.
mkdir -p "$s/.jeffy/probes/published-docs"
cp .jeffy/probes/published-docs/pdf.py "$s/.jeffy/probes/published-docs/"
git -C "$s" init -q
git -C "$s" add -A
git -C "$s" -c user.email=p@p -c user.name=p commit -qm stage
printf '%s\n' "$s"
