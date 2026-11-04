#!/usr/bin/env bash
# Known-answer battery for the repository metadata group - SECURITY.md,
# CONTRIBUTING.md, LICENSE, .github, .gitattributes and .gitignore.
#
# .github is one of the zeroes the Oracle class line names: `git ls-files |
# sed 's|/.*||' | sort -u` against `grep -cF` over scripts/validate.sh returns 0
# for it, so no check in the harness reads either workflow or any issue
# template. That is the sharpest zero in the group, because .github holds the
# only two things here that execute: validate.yml, whose three jobs are the
# oracle behind the published claim that the engine passes its checks on Linux,
# Windows and macOS, and publish.yml, which builds and uploads the wheel a user
# installs from PyPI and carries a shell guard of its own.
#
# What is deliberately not re-asserted: the truncator set and the sandbox
# answer set SECURITY.md states, which checks L and Q already derive, and the
# three transient paths .gitignore must carry, which the harness asserts near
# its exploratory-output check. A battery that restated them would add a second
# source for one claim rather than coverage.
#
# Expected: 38 checks. Worked out from the arms before the run and written here
# rather than read off a green one, because a helper that loses checks to a
# subshell reports a smaller total with no failure at all.
set -u
rm_root="${JEFFY_PROBE_ROOT:-$PWD}"
rm_real="$PWD"
[ -d "$rm_root/.github" ] || { echo "repo-meta battery: no $rm_root/.github"; exit 2; }

rm_py=""
for rm_c in python3 python; do
  rm_py="$(command -v "$rm_c" 2>/dev/null)" && [ -n "$rm_py" ] && break
  rm_py=""
done
[ -n "$rm_py" ] || { echo "repo-meta battery: NOT RUNNABLE: no python3 or python on PATH; install python3"; exit 2; }
"$rm_py" -c 'import yaml' 2>/dev/null ||
  { echo "repo-meta battery: NOT RUNNABLE: python has no yaml module, so no workflow can be parsed; pip install PyYAML"; exit 2; }

rm_ok=0; rm_bad=0
ck() { # $1 label, $2 expected, $3 actual
  if [ "$2" = "$3" ]; then rm_ok=$((rm_ok + 1)); else
    rm_bad=$((rm_bad + 1)); echo "FAIL $1: expected [$2] got [$3]"
  fi
}

rm_tmp="$(mktemp -d)"
trap 'rm -rf "$rm_tmp"' EXIT

# --- 1. the .github file set ------------------------------------------------
# Read off the directory and asserted whole, so a workflow or template added or
# removed reaches this battery instead of passing unnoticed.
rm_set="$(find "$rm_root/.github" -type f | sed "s|^$rm_root/||" | sort | tr '\n' ' ')"
ck "the .github file set" \
  ".github/ISSUE_TEMPLATE/bug-report.yml .github/ISSUE_TEMPLATE/config.yml .github/ISSUE_TEMPLATE/proposal.yml .github/pull_request_template.md .github/workflows/publish.yml .github/workflows/validate.yml " \
  "$rm_set"

# --- 2. every YAML under .github parses -------------------------------------
# A malformed workflow does not fail loudly: GitHub declines to run it, and a
# malformed issue template is silently dropped from the chooser.
find "$rm_root/.github" -type f -name '*.yml' | sort > "$rm_tmp/ymls"
ck "the YAML file population" 5 "$(grep -c . "$rm_tmp/ymls")"
while IFS= read -r rm_y; do
  ck "$(basename "$rm_y") parses as YAML" 0 \
    "$("$rm_py" -c 'import yaml,sys; yaml.safe_load(open(sys.argv[1]))' "$rm_y" >/dev/null 2>&1; echo $?)"
done < "$rm_tmp/ymls"

# --- 3. the CI matrix is the one the published pages claim -------------------
# README.md, docs/how-it-works.md and CONTRIBUTING.md each say the engine's
# checks pass on Linux, Windows and macOS. The oracle for that sentence is
# validate.yml's job matrix, and nothing read it until now: drop the macOS job
# and three published sentences become false with nothing going red.
rm_os="$(grep -ohE '^ +runs-on: [a-z-]+' "$rm_root/.github/workflows/validate.yml" \
  | sed 's/.*runs-on: //' | sort -u | tr '\n' ' ')"
ck "validate.yml's runner set" "macos-latest ubuntu-latest windows-latest " "$rm_os"
# The documents are enumerated rather than typed: any tracked markdown outside
# evals/ naming the trio. The three known ones are a floor, so a page that
# drops the sentence cannot shrink the set into agreement.
rm_docs="$(grep -rlE 'Linux, Windows,? and macOS' \
  "$rm_root/README.md" "$rm_root/CONTRIBUTING.md" "$rm_root/docs" 2>/dev/null | sort -u | wc -l)"
ck "the pages stating the OS trio" 3 "$rm_docs"
# Each of them must name all three, so a page narrowed to two is a disagreement
# rather than a smaller set.
rm_short=""
while IFS= read -r rm_d; do
  for rm_w in Linux Windows macOS; do
    grep -qF -- "$rm_w" "$rm_d" || rm_short="$rm_short $(basename "$rm_d"):$rm_w"
  done
done < <(grep -rlE 'Linux, Windows,? and macOS' \
  "$rm_root/README.md" "$rm_root/CONTRIBUTING.md" "$rm_root/docs" 2>/dev/null | sort -u)
ck "no page names fewer than the three runners" "" "$rm_short"

# --- 4. every action is pinned to a commit, not a tag -----------------------
# A floating tag is a third party's mutable pointer running in a workflow that
# holds id-token: write. Each pin carries its version as a trailing comment,
# which is this repository's own convention and the only thing that makes the
# SHAs readable.
grep -ohE '^ +- uses: .*' "$rm_root"/.github/workflows/*.yml > "$rm_tmp/uses"
ck "the action-reference population" 7 "$(grep -c . "$rm_tmp/uses")"
ck "no action is referenced by anything but a 40-hex commit" 0 \
  "$(grep -cvE 'uses: [^ @]+@[0-9a-f]{40}( |$)' "$rm_tmp/uses")"
ck "every pin carries its version as a comment" 0 \
  "$(grep -cvE '# *v[0-9]+\.[0-9]+' "$rm_tmp/uses")"

# --- 5. a release cannot publish without the validator ----------------------
# The whole point of the publish workflow's shape: the upload job depends on a
# job that runs the suite, so a red suite cannot reach PyPI.
"$rm_py" - "$rm_root/.github/workflows/publish.yml" > "$rm_tmp/pub" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
# `on:` is YAML 1.1 truthy, so safe_load keys it as True rather than "on".
trig = d.get(True, d.get("on"))
jobs = d.get("jobs", {})
print("needs=%s" % jobs.get("pypi", {}).get("needs"))
print("trigger=%s" % sorted((trig or {}).keys()))
print("released=%s" % ((trig or {}).get("release", {}) or {}).get("types"))
print("toplevel_perms=%s" % d.get("permissions"))
print("pypi_perms=%s" % jobs.get("pypi", {}).get("permissions"))
steps = jobs.get("validate", {}).get("steps", [])
print("validates=%s" % any("scripts/validate.sh" in (s.get("run") or "") for s in steps))
PY
rm_f() { sed -n "s/^$1=//p" "$rm_tmp/pub"; }
ck "the upload job depends on the validating job" "validate" "$(rm_f needs)"
ck "the validating job runs the suite" "True" "$(rm_f validates)"
ck "publishing is triggered by a published release alone" "['release'] ['published']" \
  "$(rm_f trigger) $(rm_f released)"

# --- 6. the tag-versus-version guard runs as published ----------------------
# publish.yml carries a shell guard that refuses a release whose tag does not
# name the version in pyproject.toml. It is published code, so it is executed
# rather than read, in exactly the form the workflow carries, and driven on
# both sides of its own comparison.
"$rm_py" - "$rm_root/.github/workflows/publish.yml" > "$rm_tmp/guard.sh" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
for s in d["jobs"]["validate"]["steps"]:
    r = s.get("run") or ""
    if "GITHUB_REF_NAME" in r:
        sys.stdout.write(r)
        break
PY
ck "the tag guard was extracted" 1 "$([ -s "$rm_tmp/guard.sh" ] && echo 1 || echo 0)"
ck "the tag guard parses" 0 "$(bash -n "$rm_tmp/guard.sh" 2>/dev/null; echo $?)"
# The guard reads pyproject.toml from the working directory, so it runs there.
# GitHub executes a run: block under `bash -e`, which is what it is given here.
rm_ver="$(sed -n 's/^version = "\(.*\)"$/\1/p' "$rm_root/pyproject.toml" | head -n 1)"
ck "pyproject states a version the guard can read" 1 \
  "$([ -n "$rm_ver" ] && echo 1 || echo 0)"
rm_g() { ( cd "$rm_root" && env GITHUB_REF_NAME="$1" bash -e "$rm_tmp/guard.sh" 2>&1; echo "rc=$?" ); }
ck "a tag naming the version is accepted" "rc=0" "$(rm_g "v$rm_ver" | tail -n 1)"
ck "a tag naming another version is refused" "rc=1" "$(rm_g "v0.0.0-probe" | tail -n 1)"

# --- 7. least privilege on both workflows -----------------------------------
# The upload job needs id-token: write for trusted publishing; nothing else
# does, and the default for the rest is read.
ck "publish.yml grants read at the top level" "{'contents': 'read'}" "$(rm_f toplevel_perms)"
ck "the upload job holds the trusted-publishing token" \
  "{'id-token': 'write', 'contents': 'read'}" "$(rm_f pypi_perms)"
ck "validate.yml grants read at the top level" "{'contents': 'read'}" \
  "$("$rm_py" -c 'import yaml,sys; print(yaml.safe_load(open(sys.argv[1])).get("permissions"))' \
    "$rm_root/.github/workflows/validate.yml")"

# --- 8. .gitattributes covers what the tree actually holds ------------------
# The binary pins are not decoration: a tracked .png that git treats as text is
# eol-converted on a Windows checkout and the file is corrupt. The pinned set is
# compared against the extensions the tree really tracks, so a new binary kind
# committed without a pin is a finding rather than a silent risk.
rm_pinned="$(grep -oE '^\*\.[a-z0-9]+ binary' "$rm_root/.gitattributes" \
  | sed 's/^\*\.//; s/ binary//' | sort -u | tr '\n' ' ')"
ck "the binary-pinned set was extracted" 1 "$([ -n "$rm_pinned" ] && echo 1 || echo 0)"
if git -C "$rm_real" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  rm_unpinned=""
  rm_binclass=" png gif jpg jpeg webp mp4 pdf ico woff woff2 "
  for rm_e in $(git -C "$rm_real" ls-files | sed -n 's/.*\.\([A-Za-z0-9]\+\)$/\1/p' \
    | tr '[:upper:]' '[:lower:]' | sort -u); do
    case "$rm_binclass" in
      *" $rm_e "*) case " $rm_pinned" in *" $rm_e "*) ;; *) rm_unpinned="$rm_unpinned $rm_e" ;; esac ;;
    esac
  done
  ck "every tracked binary extension is pinned binary" "" "$rm_unpinned"
else
  echo "  note: not a git work tree, so the tracked-extension comparison is skipped"
  ck "every tracked binary extension is pinned binary" "" ""
fi
# The three LF pins the file explains in its own comments, each load-bearing for
# a mechanism named there: byte-exact templates, check 10's anchored patterns,
# and git apply over the published receipt patches.
for rm_pat in 'skills/jeffy/references/\*\*' 'skills/\*/SKILL.md' '\*.patch'; do
  ck "a LF pin covers $rm_pat" 1 \
    "$(grep -cE "^$rm_pat text eol=lf\$" "$rm_root/.gitattributes")"
done

# --- 9. CONTRIBUTING.md's published commands parse --------------------------
# A contributor copies these. Three properties per block, the non-empty guard
# first, because an extractor returning nothing hands bash -n an empty script
# that parses clean.
ck "CONTRIBUTING.md fenced bash blocks" 3 "$(grep -c '^```bash$' "$rm_root/CONTRIBUTING.md")"
for rm_i in 1 2 3; do
  rm_body="$(awk -v n="$rm_i" '/^```bash$/{c++; if(c==n){f=1; next}} /^```$/{if(f)exit} f' \
    "$rm_root/CONTRIBUTING.md")"
  ck "CONTRIBUTING.md block $rm_i extracted something" 1 \
    "$([ -n "$rm_body" ] && echo 1 || echo 0)"
  ck "CONTRIBUTING.md block $rm_i parses" 0 \
    "$(printf '%s\n' "$rm_body" | bash -n 2>/dev/null; echo $?)"
done

# --- 10. the licence the package declares is the one the file grants --------
ck "LICENSE is non-empty" 1 "$([ -s "$rm_root/LICENSE" ] && echo 1 || echo 0)"
ck "pyproject's licence is the one LICENSE grants" "MIT MIT" \
  "$(sed -n 's/^license = "\(.*\)"$/\1/p' "$rm_root/pyproject.toml" | head -n 1) $(awk 'NR==1 { print $1 }' "$rm_root/LICENSE")"

echo "  repo-meta: $((rm_ok + rm_bad)) checks, $rm_ok passed, $rm_bad failed"
if [ "$rm_bad" -eq 0 ]; then
  echo "repo-meta battery: $rm_ok/$((rm_ok + rm_bad)) checks passed"
  exit 0
fi
echo "repo-meta battery: $rm_ok/$((rm_ok + rm_bad)) checks passed, $rm_bad FAILED"
exit 1
