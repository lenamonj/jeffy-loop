#!/usr/bin/env bash
# Known-answer battery for docs/ - the four published pages README.md links.
#
# Two of these pages are not prose about the engine. docs/headless.md publishes
# two driver scripts a user copies into a shell and runs unattended, and
# docs/usage.md publishes the flag set the launcher accepts. This project's own
# Publication rule says code leaving the project is run in exactly the form it
# is published, and nothing in the tree ran these: scripts/validate.sh check 10
# extracts and parses every fenced bash block in skills/jeffy/SKILL.md and has
# no sibling for docs/, which `grep -nF -- docs/ scripts/validate.sh` shows
# reads these pages only for count markers, one flag name and the timeout
# chain. So the driver is executed here against a sandbox HOME and a stub
# claude, through each of the three outcomes it documents, and its PowerShell
# twin - which no host here can parse - is held to the same three messages.
#
# Expected: 45 checks. The total is worked out from the arms before the run and
# written here rather than read off a green one, because a helper that loses
# checks to a subshell reports a smaller total with no failure.
set -u
dc_root="${JEFFY_PROBE_ROOT:-$PWD}"
dc_d="$dc_root/docs"
dc_skill="$dc_root/skills/jeffy/SKILL.md"
[ -d "$dc_d" ] || { echo "docs battery: no $dc_d"; exit 2; }
[ -f "$dc_skill" ] || { echo "docs battery: no $dc_skill"; exit 2; }

for dc_c in git bash; do
  command -v "$dc_c" >/dev/null 2>&1 ||
    { echo "docs battery: NOT RUNNABLE: no $dc_c on PATH; install $dc_c"; exit 2; }
done

dc_ok=0; dc_bad=0
ck() { # $1 label, $2 expected, $3 actual
  if [ "$2" = "$3" ]; then dc_ok=$((dc_ok + 1)); else
    dc_bad=$((dc_bad + 1)); echo "FAIL $1: expected [$2] got [$3]"
  fi
}

dc_tmp="$(mktemp -d)"
trap 'rm -rf "$dc_tmp"' EXIT

# Extract the n'th fenced block of a given language from a page. Same shape as
# check 10's extractor, which is the one this battery is the missing sibling of.
dc_block() { # $1 page, $2 lang, $3 n
  awk -v n="$3" -v open="\`\`\`$2" '
    $0 == open { c++; if (c == n) { f = 1; next } }
    /^```$/ { if (f) exit }
    f' "$1"
}

# --- 1. the published set is exactly the pages README.md links ---------------
# Derived from the directory and the count asserted, so a page added or removed
# reaches this battery rather than passing unnoticed. find rather than ls,
# which shellcheck refuses at info level and this project's lint takes as red.
dc_pages="$(find "$dc_d" -maxdepth 1 -type f -name '*.md' -printf '%f\n' | sort | tr '\n' ' ')"
ck "the docs page set" "README.md headless.md how-it-works.md usage.md " "$dc_pages"

# --- 2. the fenced-block inventory ------------------------------------------
# Counted rather than assumed, because every arm below indexes into these
# blocks: a page that gains a third bash block would otherwise leave the new
# one unparsed while every existing arm still passed.
ck "headless.md fenced bash blocks" 2 "$(grep -c '^```bash$' "$dc_d/headless.md")"
ck "headless.md fenced powershell blocks" 1 "$(grep -c '^```powershell$' "$dc_d/headless.md")"
ck "usage.md fenced bash blocks" 2 "$(grep -c '^```bash$' "$dc_d/usage.md")"
# An odd fence count means a block is unterminated, which silently swallows the
# rest of the page into the previous extraction.
for dc_p in README.md headless.md how-it-works.md usage.md; do
  ck "$dc_p fences are balanced" 0 "$(( $(grep -c '^```' "$dc_d/$dc_p") % 2 ))"
done

# --- 3. every published fenced bash block parses -----------------------------
# Three properties per block, not one. The extraction is asserted non-empty
# first, because an extractor that returns nothing hands bash -n an empty
# script that parses clean - the silent pass this project's Lessons name
# twice. bash -n accepts an unterminated heredoc with only a warning on
# stderr, so the warning is read as well as the status, exactly as check 10
# does for the skill.
for dc_pair in "headless.md 1" "headless.md 2" "usage.md 1" "usage.md 2"; do
  dc_p="${dc_pair%% *}"; dc_i="${dc_pair##* }"
  dc_body="$(dc_block "$dc_d/$dc_p" bash "$dc_i")"
  ck "$dc_p bash block $dc_i extracted something" 1 \
    "$([ -n "$dc_body" ] && echo 1 || echo 0)"
  dc_err="$(printf '%s\n' "$dc_body" | bash -n 2>&1)"
  ck "$dc_p bash block $dc_i parses" 0 "$?"
  ck "$dc_p bash block $dc_i has no heredoc warning" "" "$dc_err"
done

# --- 4. the published driver runs as published -------------------------------
# docs/headless.md's second bash block is the driver. It is run verbatim -
# copied, never retyped - with only the environment changed: HOME points at a
# sandbox so the block's own `TARGET=~/targets/itoa` resolves there, PATH
# carries a stub claude, and env -i keeps the real session out of it.
#
# Each of the three outcomes the page documents is driven by the stub that
# produces it, and the stub's invocation count is asserted beside the message,
# because a loop that exits on its first pass prints the same budget-spent
# line as one that ran every round.
dc_drv="$dc_tmp/driver.sh"
dc_block "$dc_d/headless.md" bash 2 > "$dc_drv"
# Guard the index: block 2 is the loop, block 1 is the two git clone lines.
ck "the driver block is the one carrying the round loop" 1 \
  "$(grep -c '^ROUNDS=3$' "$dc_drv")"

dc_case() { # $1 sandbox name, $2 stub body; echoes "<exit> <rounds> <lastline>"
  local dc_sb="$dc_tmp/$1" dc_out dc_rc dc_n
  mkdir -p "$dc_sb/home/targets/itoa" "$dc_sb/bin"
  (
    cd "$dc_sb/home/targets/itoa" || exit 1
    git init -q .
    git config user.email probe@example.invalid
    git config user.name probe
    echo seed > f
    git add -A
    git commit -qm seed
  ) >/dev/null 2>&1
  {
    printf '#!/usr/bin/env bash\n'
    printf 'echo invoked >> "%s/rounds"\n' "$dc_sb"
    printf '%s\n' "$2"
  } > "$dc_sb/bin/claude"
  chmod +x "$dc_sb/bin/claude"
  : > "$dc_sb/rounds"
  dc_out="$(env -i HOME="$dc_sb/home" PATH="$dc_sb/bin:/usr/bin:/bin" \
    TMPDIR="$dc_sb" bash "$dc_drv" 2>&1)"
  dc_rc="$?"
  dc_n="$(grep -c invoked "$dc_sb/rounds")"
  printf '%s %s %s\n' "$dc_rc" "$dc_n" "$(printf '%s\n' "$dc_out" | tail -n 1)"
}

# Budget spent: every round commits, none writes an accepted record. The page
# promises all ROUNDS rounds run and the closing line names the budget.
dc_r="$(dc_case spent 'echo x >> f; git add -A; git commit -qm round')"
ck "budget-spent exit status" 0 "${dc_r%% *}"
ck "budget-spent rounds run" 3 "$(printf '%s\n' "$dc_r" | cut -d' ' -f2)"
ck "budget-spent message" "budget spent: 3 rounds of 10, not converged" \
  "$(printf '%s\n' "$dc_r" | cut -d' ' -f3-)"

# No progress: the round makes no commit. The page promises the loop stops
# rather than burning the remaining rounds, and exits non-zero.
dc_r="$(dc_case noprog 'echo nothing')"
ck "no-progress exit status" 1 "${dc_r%% *}"
ck "no-progress stops after one round" 1 "$(printf '%s\n' "$dc_r" | cut -d' ' -f2)"
ck "no-progress message" "round 1: no progress, stopping" \
  "$(printf '%s\n' "$dc_r" | cut -d' ' -f3-)"

# Converged: an accepted metrics record appears. Only a new accepted record
# counts, which is what the block's own comment says it is reading.
dc_r="$(dc_case conv 'mkdir -p .jeffy/metrics; echo {\"verdict\":\"accepted\"} >> .jeffy/metrics/r.jsonl; echo x >> f; git add -A; git commit -qm round')"
ck "converged exit status" 0 "${dc_r%% *}"
ck "converged stops in the round that converged" 1 "$(printf '%s\n' "$dc_r" | cut -d' ' -f2)"
ck "converged message" "converged in round 1" \
  "$(printf '%s\n' "$dc_r" | cut -d' ' -f3-)"

# --- 5. every relative reference and anchor resolves -------------------------
# These pages sit one directory below the root and link both ways - ../README.md
# upward, usage.md sideways, #anchor within. A moved heading breaks an anchor
# silently; nothing in the harness reads them.
#
# Each reference is carried with the page it was found on, because a bare
# #anchor resolves against its own page and a list that has lost the page
# cannot tell which one that is.
dc_refs="$dc_tmp/refs"
for dc_p in README.md headless.md how-it-works.md usage.md; do
  grep -ohE '\]\([^)]+\)' "$dc_d/$dc_p" | sed 's/^](//; s/)$//' \
    | grep -v '^https\?://' | grep -v '^mailto:' \
    | while IFS= read -r dc_r; do printf '%s\t%s\n' "$dc_p" "$dc_r"; done
done | sort -u > "$dc_refs"
ck "the reference extraction found something" 1 \
  "$([ -s "$dc_refs" ] && echo 1 || echo 0)"

# GitHub's heading slug: lowercase, drop formatting and punctuation, spaces to
# hyphens. Proved on a known positive and a known negative rather than
# trusted, because a slug rule that matches nothing reports every anchor
# missing and one that matches everything reports every anchor fine.
dc_slugs() { # $1 page
  grep -hE '^#{1,6} ' "$1" | sed 's/^#\{1,6\} //' \
    | tr -d '`*' | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9 -]//g; s/ /-/g'
}
ck "the slug rule resolves a heading it must" 1 \
  "$(dc_slugs "$dc_d/usage.md" | grep -cFx 'high-hunt')"
ck "the slug rule rejects a heading it must not" 0 \
  "$(dc_slugs "$dc_d/usage.md" | grep -cFx 'no-such-heading-here')"

dc_files=0; dc_anch=0; dc_miss=""
while IFS="$(printf '\t')" read -r dc_on dc_ref; do
  dc_path="${dc_ref%%\#*}"
  dc_frag=""
  case "$dc_ref" in *\#*) dc_frag="${dc_ref#*\#}" ;; esac
  if [ -z "$dc_path" ]; then
    dc_target="$dc_d/$dc_on"
  else
    dc_target="$dc_d/$dc_path"
    dc_files=$((dc_files + 1))
    [ -e "$dc_target" ] || dc_miss="$dc_miss missing-file:$dc_on>$dc_ref"
  fi
  if [ -n "$dc_frag" ]; then
    dc_anch=$((dc_anch + 1))
    if [ -f "$dc_target" ]; then
      [ "$(dc_slugs "$dc_target" | grep -cFx -- "$dc_frag")" -ge 1 ] ||
        dc_miss="$dc_miss missing-anchor:$dc_on>$dc_ref"
    else
      dc_miss="$dc_miss anchor-into-missing-file:$dc_on>$dc_ref"
    fi
  fi
done < "$dc_refs"
# The populations are asserted as well as the misses: nought references checked
# would empty the miss list for the wrong reason.
ck "relative file references resolved" 11 "$dc_files"
ck "anchors resolved" 4 "$dc_anch"
ck "no unresolved reference" "" "$dc_miss"

# --- 6. the flag set usage.md publishes is the one the launcher accepts -------
# The launcher refuses an unrecognised -- token, so the accepted set is closed:
# a flag it gains and usage.md does not document is a flag no user can find,
# and one usage.md documents and it refuses is a documented refusal.
awk '/^## Arguments$/ { f = 1; next } f && /^## / { exit } f' "$dc_skill" > "$dc_tmp/args"
dc_pub="$(sed -n '/^\/jeffy \[N\]/p' "$dc_d/usage.md" \
  | grep -ohE '\-\-[a-z][a-z-]+' | sort -u | tr '\n' ' ')"
# Literal markdown backticks delimit the flag in the skill's own prose, so the
# pattern carries them; they are not a command substitution.
# shellcheck disable=SC2016
dc_acc="$(grep -ohE '`--[a-z][a-z-]+`' "$dc_tmp/args" | tr -d '`' | sort -u | tr '\n' ' ')"
ck "usage.md publishes a flag set" 1 "$([ -n "$dc_pub" ] && echo 1 || echo 0)"
ck "the launcher defines a flag set" 1 "$([ -n "$dc_acc" ] && echo 1 || echo 0)"
ck "the published flag set is the accepted one" "$dc_acc" "$dc_pub"

# The two surface ceilings are the only numeric defaults both files state.
# Compared digits-only, since usage.md writes them with thousands separators.
dc_num() { grep -ohE '150,?000|600,?000' "$1" | tr -d ',' | sort -u | tr '\n' ' '; }
ck "the launcher states both surface ceilings" "150000 600000 " "$(dc_num "$dc_tmp/args")"
ck "usage.md states the same two ceilings" "$(dc_num "$dc_tmp/args")" "$(dc_num "$dc_d/usage.md")"

# --- 7. the PowerShell driver is held to the same contract -------------------
# No host here can parse PowerShell - the Environment fingerprint records pwsh
# and powershell both absent - so this is not a sweep of that block. What it
# is: the two published drivers promise one behaviour, and the three outcome
# messages are the observable form of it. The bash half above was executed;
# this half asserts the PowerShell twin still states the same three, so the
# pair cannot drift while only one of them is runnable here.
dc_ps="$(dc_block "$dc_d/headless.md" powershell 1)"
ck "the powershell driver extracted something" 1 \
  "$([ -n "$dc_ps" ] && echo 1 || echo 0)"
for dc_msg in 'no progress, stopping' 'converged in round' 'budget spent:'; do
  ck "the powershell driver states [$dc_msg]" 1 \
    "$(printf '%s\n' "$dc_ps" | grep -cF -- "$dc_msg")"
done
if command -v pwsh >/dev/null 2>&1 || command -v powershell >/dev/null 2>&1; then
  echo "  note: a PowerShell host is present; this battery still does not parse the block"
else
  echo "  NOT RUNNABLE: no pwsh or powershell on PATH, so the published PowerShell driver is not parsed here; install PowerShell to cover it"
fi

echo "  docs: $((dc_ok + dc_bad)) checks, $dc_ok passed, $dc_bad failed"
if [ "$dc_bad" -eq 0 ]; then
  echo "docs battery: $dc_ok/$((dc_ok + dc_bad)) checks passed"
  exit 0
fi
echo "docs battery: $dc_ok/$((dc_ok + dc_bad)) checks passed, $dc_bad FAILED"
exit 1
