#!/usr/bin/env bash
# Stage the file under test, under .jeffy/scratch/, and print the staged root.
# PLAN.md rides along because one arm compares the harness's green line against
# the Verify summary pattern that file states, and a stage without it would
# turn that arm into a FAIL the mutation never caused.
set -eu
s=".jeffy/scratch/$1"
rm -rf "$s"
mkdir -p "$s/scripts"
cp scripts/validate.sh "$s/scripts/"
cp PLAN.md "$s/"
printf '%s\n' "$s"
