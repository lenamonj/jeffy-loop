#!/usr/bin/env bash
# Stage a faithful copy of every path this battery reads, under .jeffy/scratch/,
# and print it. Faithful matters for the same reason it does in the docs
# battery: an arm that walks a surface the stage only partly carries fails for
# a reason the mutation never caused.
set -eu
s=".jeffy/scratch/$1"
rm -rf "$s"
mkdir -p "$s/docs"
cp -R .github "$s/.github"
cp README.md CONTRIBUTING.md SECURITY.md LICENSE .gitattributes .gitignore pyproject.toml "$s/"
cp docs/*.md "$s/docs/"
printf '%s\n' "$s"
