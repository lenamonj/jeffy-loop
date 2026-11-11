#!/usr/bin/env bash
# Stage a copy of the reader under .jeffy/scratch/ and print the staged root.
# The file resolves no helper beside itself and the battery writes every
# transcript it reads, so lib/ alone is the whole surface a mutation needs.
set -eu
s=".jeffy/scratch/$1"
rm -rf "$s"
mkdir -p "$s/skills/jeffy/hooks/lib"
cp skills/jeffy/hooks/lib/transcript-usage.sh "$s/skills/jeffy/hooks/lib/"
printf '%s\n' "$s"
