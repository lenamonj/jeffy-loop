#!/usr/bin/env bash
# Stage a faithful copy of every path docs/ can reach, under .jeffy/scratch/,
# and print it. Faithful matters: the first mutation run here used a stage
# holding only docs/ and SKILL.md, so every ../ target was legitimately absent
# and the reference arm reported five misses that had nothing to do with the
# mutation - which reads exactly like the battery being broken.
set -eu
s=".jeffy/scratch/$1"
rm -rf "$s"
mkdir -p "$s/docs" "$s/skills/jeffy" "$s/evals" "$s/media"
cp docs/*.md "$s/docs/"
cp skills/jeffy/SKILL.md "$s/skills/jeffy/"
cp README.md CONTRIBUTING.md SECURITY.md "$s/"
cp evals/README.md "$s/evals/"
cp media/jeffy-vs-raw-loop.gif "$s/media/"
printf '%s\n' "$s"
