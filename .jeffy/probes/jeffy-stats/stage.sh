#!/usr/bin/env bash
# Stage a copy of the script under test, under .jeffy/scratch/, and print the
# staged root. Only scripts/ is needed here: the battery writes every record
# file it reads, so there is no wider surface for a partial stage to break.
set -eu
s=".jeffy/scratch/$1"
rm -rf "$s"
mkdir -p "$s/scripts"
cp scripts/jeffy-stats.sh "$s/scripts/"
printf '%s\n' "$s"
