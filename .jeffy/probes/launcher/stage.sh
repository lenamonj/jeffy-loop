#!/usr/bin/env bash
# Stage a faithful copy of every path this battery reads, under .jeffy/scratch/,
# and print it. The whole skills/jeffy tree is copied because the battery reads
# the skill, the hook and the references directory together, and a partial copy
# makes an arm fail for a reason no mutation caused.
set -eu
s=".jeffy/scratch/$1"
rm -rf "$s"
mkdir -p "$s/skills"
cp -R skills/jeffy "$s/skills/jeffy"
# /cancel-jeffy joined this battery when the state-file contract it shares
# with the launcher and the hook acquired arms; without it in the stage those
# arms fault on a missing file rather than on the mutation.
cp -R skills/cancel-jeffy "$s/skills/cancel-jeffy"
printf '%s\n' "$s"
