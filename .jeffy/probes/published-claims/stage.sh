#!/usr/bin/env bash
# Stage both published pages and the receipts they quantify over, under
# .jeffy/scratch/, and print the staged root. The whole of evals/ rides along
# rather than a subset: the arms walk every receipt and resolve every details
# link, so a partial stage would report misses no mutation caused - the defect
# the docs battery recorded on its first mutation run.
set -eu
s=".jeffy/scratch/$1"
rm -rf "$s"
mkdir -p "$s"
cp README.md "$s/"
cp -r evals "$s/"
# The reference arm resolves paths that leave evals/, so the directories the
# front page points into are present as themselves.
for d in docs media scripts skills .github; do [ -e "$d" ] && cp -r "$d" "$s/"; done
for f in CONTRIBUTING.md SECURITY.md LICENSE The-Jeffy-Loop.pdf Jeffy-Loop-STE100.pdf; do [ -e "$f" ] && cp "$f" "$s/"; done
printf '%s\n' "$s"
