#!/usr/bin/env bash
# Known-answer battery for install.sh, the shell installer. It is one of the
# two shipped paths that put the engine on a machine, and PLAN.md's row for the
# Python console script states the premise both rows share: the same contract
# is implemented twice, in two languages, and the two can drift without either
# one breaking.
#
# install.sh resolves its payload from its own directory, so the file under
# test and the skills it copies always come from one tree; JEFFY_PROBE_ROOT
# selects that tree, which is what lets a mutation be staged beside a copy of
# skills/ and driven as the real thing.
#
# shellcheck disable=SC2016
#   The single-quoted $ below are literals: the registered hook command carries
#   an escaped dollar by design, and the four unescaping forms a registration
#   can take - ~, $HOME, ${HOME} and \$ - are the inputs that exercise the
#   prune's own read-back. Expanding any of them would test a different string
#   than the one a user's settings.json holds. Above set -u, because a
#   directive after the first command silences nothing.
set -u
is_root="${JEFFY_PROBE_ROOT:-$PWD}"
is_sh="$is_root/install.sh"
[ -f "$is_sh" ] || { echo "install-sh battery: no $is_sh"; exit 2; }
[ -f "$is_root/skills/jeffy/SKILL.md" ] || { echo "install-sh battery: no skills payload beside $is_sh"; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "install-sh battery: NOT RUNNABLE: no jq on PATH; install jq"; exit 2; }

is_ok=0; is_bad=0
ck() { # $1 label, $2 expected, $3 actual
  if [ "$2" = "$3" ]; then is_ok=$((is_ok + 1)); else
    is_bad=$((is_bad + 1)); echo "FAIL $1: expected [$2] got [$3]"
  fi
}
is_tmp="$(mktemp -d)" || exit 2
trap 'chmod -R u+rwX "$is_tmp" 2>/dev/null; rm -rf "$is_tmp"' EXIT

is_bin="$is_tmp/bin"; mkdir -p "$is_bin"
printf '#!/bin/sh\nexit 0\n' > "$is_bin/claude"; chmod +x "$is_bin/claude"
is_frag="skills/jeffy/hooks/stop-hook.sh"

# Run the installer against a sandbox home. Output and status are captured so
# an arm can read either alone; the installer runs under set -e, so a non-zero
# status is part of its contract rather than a harness failure.
is_run() { # $1 home, rest: extra env assignments
  is_home="$1"; shift
  env HOME="$is_home" PATH="$is_bin:$PATH" "$@" bash "$is_sh" \
    </dev/null >"$is_tmp/out" 2>"$is_tmp/err"
}
is_both() { cat "$is_tmp/out" "$is_tmp/err"; }
# Read the registration state out of settings.json rather than off the printed
# line: the message is what the installer claims, the file is what Claude Code
# will read.
is_reg() { jq -r --arg f "$is_frag" \
  '[.hooks.Stop[]?.hooks[]? | select((.command // "") | contains($f))] as $m
   | "\($m | length) \($m | map(.timeout // "none") | join(","))"' < "$1" 2>/dev/null \
  || echo UNREADABLE; }
is_home_new() { h="$is_tmp/$1"; mkdir -p "$h/.claude"; printf '%s' "$h"; }

# --- A. a fresh install -------------------------------------------------------
isA="$(is_home_new hA)"
is_run "$isA"; ck "fresh install exit" 0 "$?"
ck "jeffy skill landed" 1 "$([ -f "$isA/.claude/skills/jeffy/SKILL.md" ] && echo 1 || echo 0)"
ck "cancel-jeffy skill landed" 1 "$([ -f "$isA/.claude/skills/cancel-jeffy/SKILL.md" ] && echo 1 || echo 0)"
ck "the stop hook landed" 1 "$([ -f "$isA/.claude/skills/jeffy/hooks/stop-hook.sh" ] && echo 1 || echo 0)"
ck "one registration at 1800s" "1 1800" "$(is_reg "$isA/.claude/settings.json")"
ck "every installed hook script is executable" 0 \
  "$(find "$isA/.claude/skills/jeffy/hooks" -name '*.sh' ! -perm -u+x | grep -c .)"
ck "the final line reports success" 1 "$(grep -c '^Done\. Start a new Claude Code session' "$is_tmp/out")"
# The registered command has to resolve back to the file just installed, which
# is the property the prune below depends on.
is_cmd="$(jq -r --arg f "$is_frag" '[.hooks.Stop[]?.hooks[]?.command // empty | select(contains($f))][0]' < "$isA/.claude/settings.json")"
is_path="$(printf '%s' "$is_cmd" | grep -oE "\"[^\"]*$is_frag\"|'[^']*$is_frag'|[^\"' ]*$is_frag" | head -n 1)"
is_path="${is_path#[\"\']}"; is_path="${is_path%[\"\']}"
ck "the registered command names the installed hook" 1 "$([ -f "$is_path" ] && echo 1 || echo 0)"

# --- B. idempotence and the two timeout upgrades ------------------------------
is_run "$isA"; ck "second install exit" 0 "$?"
ck "second install reports already registered" 1 "$(grep -c 'already registered' "$is_tmp/out")"
ck "second install adds no registration" "1 1800" "$(is_reg "$isA/.claude/settings.json")"

# The timeout field is a documented parameter with three values leading to
# three outcomes: absent and 600 upgrade once, 1800 is left alone.
is_upgrade() { # $1 label, $2 hook object
  h="$(is_home_new "hU$1")"
  mkdir -p "$h/.claude/skills/jeffy/hooks"
  printf '{"hooks":{"Stop":[{"hooks":[%s]}]}}\n' "$2" > "$h/.claude/settings.json"
  is_run "$h"; ck "$1 upgrade exit" 0 "$?"
  ck "$1 upgraded to one 1800s registration" "1 1800" "$(is_reg "$h/.claude/settings.json")"
  ck "$1 upgrade says so" 1 "$(grep -c 'upgraded to an 1800s timeout' "$is_tmp/out")"
  is_run "$h"
  ck "$1 upgrade happens once only" 1 "$(grep -c 'already registered' "$is_tmp/out")"
}
is_upgrade 600 "{\"type\":\"command\",\"command\":\"bash \\\"$is_tmp/hU600/.claude/$is_frag\\\"\",\"timeout\":600}"
is_upgrade none "{\"type\":\"command\",\"command\":\"bash \\\"$is_tmp/hUnone/.claude/$is_frag\\\"\"}"

# --- C. the dead-registration prune and what it must preserve ---------------
isC="$(is_home_new hC)"
cat > "$isC/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "Stop": [
      {"hooks": [{"type": "command", "command": "bash \"/nonexistent/other-home/.claude/skills/jeffy/hooks/stop-hook.sh\"", "timeout": 600}]},
      {"hooks": [{"type": "command", "command": "echo unrelated", "timeout": 5}]}
    ],
    "PreToolUse": [{"hooks": [{"type": "command", "command": "echo pre"}]}]
  },
  "env": {"KEEP": "1"}
}
JSON
is_run "$isC"; ck "install over a dead foreign registration exit" 0 "$?"
ck "the dead registration is reported removed" 1 \
  "$(grep -c 'removed a Stop hook registration naming a hook that does not exist' "$is_tmp/out")"
ck "exactly one live registration remains" "1 1800" "$(is_reg "$isC/.claude/settings.json")"
ck "unrelated hook, other event and other key all kept" "1 true 1" \
  "$(jq -r '[([.hooks.Stop[]?.hooks[]? | select(.command == "echo unrelated")] | length),
             (.hooks | has("PreToolUse")), .env.KEEP] | join(" ")' < "$isC/.claude/settings.json")"

# --- D. the prune's read-back, over every form a registration can take ------
# These four substitutions are the whole of what stands between the prune and
# deleting a live registration. Each is driven with a command that really does
# name the installed hook, so a read-back that failed would make the installer
# call its own work dead and re-add it - giving two registrations, not one.
isD_forms() {
  h="$(is_home_new "hD$1")"
  mkdir -p "$h/.claude/skills/jeffy/hooks"
  printf '#!/bin/sh\n' > "$h/.claude/skills/jeffy/hooks/stop-hook.sh"
  printf '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":%s,"timeout":1800}]}]}}\n' "$2" \
    > "$h/.claude/settings.json"
  env HOME="$h" PATH="$is_bin:$PATH" bash "$is_sh" </dev/null >"$is_tmp/out" 2>"$is_tmp/err"
  ck "a registration written as $1 is read back as live" "1 1800" "$(is_reg "$h/.claude/settings.json")"
  ck "a registration written as $1 is not reported dead" 0 \
    "$(grep -c 'naming a hook that does not exist' "$is_tmp/out")"
}
isD_forms tilde '"bash \"~/.claude/skills/jeffy/hooks/stop-hook.sh\""'
isD_forms dollar-HOME '"bash \"$HOME/.claude/skills/jeffy/hooks/stop-hook.sh\""'
isD_forms braced-HOME '"bash \"${HOME}/.claude/skills/jeffy/hooks/stop-hook.sh\""'
# The bare form has to name a real absolute path: a non-existent one is
# correctly pruned, so the first draft of this arm was asserting the opposite of
# what it meant. The home is substituted in rather than written as a literal.
isD_forms bare "\"bash $is_tmp/hDbare/.claude/skills/jeffy/hooks/stop-hook.sh\""

# --- E. the stale-file sync -------------------------------------------------
echo stale > "$isA/.claude/skills/jeffy/references/gone.md"
is_run "$isA"; ck "install over a stale file exit" 0 "$?"
ck "the stale file is named as removed" 1 "$(grep -c 'references/gone.md (not in this version)' "$is_tmp/out")"
ck "the stale file is gone" 0 "$([ -f "$isA/.claude/skills/jeffy/references/gone.md" ] && echo 1 || echo 0)"
ck "a shipped file beside it is kept" 1 \
  "$([ -f "$isA/.claude/skills/jeffy/references/iteration-prompt.txt" ] && echo 1 || echo 0)"

# --- F. the exec bit over an existing install -------------------------------
find "$isA/.claude/skills/jeffy/hooks" -name '*.sh' -exec chmod 644 {} +
if [ -x "$isA/.claude/skills/jeffy/hooks/stop-hook.sh" ]; then
  echo "SKIP exec-bit arm: this filesystem does not clear the mode"
else
  is_run "$isA"; ck "install over a 644 install exit" 0 "$?"
  ck "the exec bit is restored on every hook script" 0 \
    "$(find "$isA/.claude/skills/jeffy/hooks" -name '*.sh' ! -perm -u+x | grep -c .)"
fi

# --- G. a dollar in the home path -------------------------------------------
isG="$is_tmp/h\$USER"; mkdir -p "$isG/.claude"
is_run "$isG"; ck "dollar-home install exit" 0 "$?"
ck "the registered command escapes the dollar" 1 "$(grep -c 'h\\\\\$USER' "$isG/.claude/settings.json")"
is_run "$isG"; ck "dollar-home second install exit" 0 "$?"
ck "dollar-home registration read back as live, not re-added" "1 1800" "$(is_reg "$isG/.claude/settings.json")"
ck "dollar-home second install reports already registered" 1 "$(grep -c 'already registered' "$is_tmp/out")"

# --- H. the settings-file shapes --------------------------------------------
isH1="$(is_home_new hH1)"
printf 'not json at all\n' > "$isH1/.claude/settings.json"
is_run "$isH1"; ck "invalid-JSON settings exit" 1 "$?"
ck "invalid-JSON settings reports FAILED" 1 "$(grep -c 'is not valid JSON; fix it' "$is_tmp/out")"
ck "invalid-JSON settings is left untouched" "not json at all" "$(cat "$isH1/.claude/settings.json")"
ck "invalid-JSON run still installed the skills" 1 \
  "$([ -f "$isH1/.claude/skills/jeffy/SKILL.md" ] && echo 1 || echo 0)"
ck "invalid-JSON settings left no temp behind" 0 "$(find "$isH1/.claude" -name 'settings.json.*' | grep -c .)"

isH2="$(is_home_new hH2)"
printf '   \n\t\n' > "$isH2/.claude/settings.json"
is_run "$isH2"; ck "whitespace-only settings exit" 0 "$?"
ck "whitespace-only settings is registered into" "1 1800" "$(is_reg "$isH2/.claude/settings.json")"

isH3="$(is_home_new hH3)"
printf '{"env":{"KEEP":"1"}}\n' > "$is_tmp/real-settings.json"
if ln -s "$is_tmp/real-settings.json" "$isH3/.claude/settings.json" 2>/dev/null; then
  is_run "$isH3"; ck "symlinked settings exit" 0 "$?"
  ck "symlinked settings is still a link" 1 "$([ -L "$isH3/.claude/settings.json" ] && echo 1 || echo 0)"
  ck "the link target carries the registration" "1 1800" "$(is_reg "$is_tmp/real-settings.json")"
  ck "the link target kept the user key" 1 "$(grep -c '"KEEP"' "$is_tmp/real-settings.json")"
else
  echo "SKIP symlinked-settings arm: this filesystem made no symlink"
fi

# --- I. an unwritable settings directory ------------------------------------
# The installer cannot make its temp beside the real file and has to say which
# directory and what it left alone, rather than dying under set -e.
# The order matters and the first draft got it wrong: locking ~/.claude before
# the first install makes the skills copy fail, and set -e ends the run before
# the settings block is ever reached - so the arm was asserting a message the
# installer had no chance to print. The skills are installed first, the
# directory is locked after, and the settings file is left at a timeout the
# installer must rewrite, so a temp file is genuinely needed.
isI="$(is_home_new hI)"
is_run "$isI" >/dev/null 2>&1
printf '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"bash \\"%s/.claude/%s\\"","timeout":600}]}]}}\n' \
  "$isI" "$is_frag" > "$isI/.claude/settings.json"
chmod 500 "$isI/.claude"
# Whether the lock took is tested directly, not inferred from the installer's
# exit code. Inferring it conflated "this filesystem ignored the mode" with
# "the installer had no reason to write", and a mutation to the upgrade
# predicate then silently removed these three arms from the tally rather than
# failing them - the battery reported a smaller total with no failure, which is
# the same shape as the subshell defect the packaging battery had.
is_lockedI=1
( : > "$isI/.claude/.probe-write-test" ) 2>/dev/null && is_lockedI=0
rm -f "$isI/.claude/.probe-write-test" 2>/dev/null
is_run "$isI"; is_rcI=$?
chmod 700 "$isI/.claude"
if [ "$is_lockedI" = 0 ]; then
  echo "SKIP unwritable-settings-dir arm: this filesystem ignored the directory mode"
else
  ck "unwritable settings dir exit" 1 "$is_rcI"
  ck "unwritable settings dir names the directory and what it left" 1 \
    "$(grep -c 'no temporary file can be made beside' "$is_tmp/out")"
  ck "unwritable settings dir raises no shell error" 0 "$(is_both | grep -c 'line [0-9]*:')"
fi

# --- J. jq absent -----------------------------------------------------------
# jq is both the hook's dependency and this installer's editor, so its absence
# is a documented degradation rather than a crash: the skills still land.
# A PATH holding only claude also hides coreutils, and the installer then dies
# at 127 before reaching the branch under test - which reads as the degradation
# being broken when it is the fixture that is. The needed binaries are
# symlinked in by name and jq alone is left out; if any is unresolvable the arm
# skips rather than reporting a failure it cannot attribute.
isJ="$(is_home_new hJ)"
mkdir -p "$is_tmp/nojq"
cp "$is_bin/claude" "$is_tmp/nojq/claude"
is_missing=""
for is_b in bash mkdir tr cp find sed rm mv chmod dirname readlink mktemp grep head cat; do
  is_p="$(command -v "$is_b" 2>/dev/null)"
  if [ -n "$is_p" ]; then ln -sf "$is_p" "$is_tmp/nojq/$is_b"; else is_missing="$is_missing $is_b"; fi
done
if [ -n "$is_missing" ]; then
  echo "SKIP no-jq arm: these binaries could not be resolved for the fixture PATH:$is_missing"
elif PATH="$is_tmp/nojq" command -v jq >/dev/null 2>&1; then
  echo "SKIP no-jq arm: jq is still reachable on the fixture PATH"
else
env HOME="$isJ" PATH="$is_tmp/nojq" bash "$is_sh" </dev/null >"$is_tmp/out" 2>"$is_tmp/err"; is_rcJ=$?
ck "no-jq exit" 1 "$is_rcJ"
ck "no-jq reports the skip and what to do" 1 "$(grep -c '^\[SKIPPED\] hook registration needs jq' "$is_tmp/out")"
ck "no-jq reports jq missing" 1 "$(grep -c '^\[MISSING\] jq' "$is_tmp/out")"
ck "no-jq still installed the skills" 1 "$([ -f "$isJ/.claude/skills/jeffy/SKILL.md" ] && echo 1 || echo 0)"
ck "no-jq wrote no settings.json" 0 "$([ -f "$isJ/.claude/settings.json" ] && echo 1 || echo 0)"
ck "no-jq ends with the fix-and-re-run line" 1 \
  "$(grep -c '^Skills installed, but fix the items above' "$is_tmp/out")"
fi

# --- K. a missing payload ---------------------------------------------------
# install.sh resolves its payload from its own directory and refuses rather
# than installing half of it.
isK="$(is_home_new hK)"
mkdir -p "$is_tmp/bare"
cp "$is_sh" "$is_tmp/bare/install.sh"
env HOME="$isK" PATH="$is_bin:$PATH" bash "$is_tmp/bare/install.sh" </dev/null >"$is_tmp/out" 2>"$is_tmp/err"
ck "a copy with no payload beside it exits 1" 1 "$?"
ck "it names the missing file and where to run from" 1 \
  "$(grep -c 'SKILL.md not found next to this script' "$is_tmp/err")"

# --- L. a read-only settings.json (J17) --------------------------------------
# The cross of two states the arms above drive only one at a time. Section H
# drives a whitespace-only settings file and section I an unwritable settings
# directory; neither drives a settings file the user cannot write, and that is
# where both of this installer's write paths failed. A read-only settings.json
# is the state a dotfile manager leaves behind - the comment beside
# settings_tmp names that store, and the Python sibling's names stow and
# home-manager - and replacing one is a rename, which needs the directory
# rather than the file, so it is a state this installer must handle rather than
# refuse. Whether this filesystem honours a read-only file mode is tested
# directly, on a probe file of the battery's own, never inferred from the
# installer's exit code: section I records what inferring it cost. Root tests
# writable on everything, so a root run skips here rather than reporting a
# failure it cannot attribute.
: > "$is_tmp/ro-probe"; chmod 444 "$is_tmp/ro-probe"
is_ro=1
( printf 'x' >> "$is_tmp/ro-probe" ) 2>/dev/null && is_ro=0
rm -f "$is_tmp/ro-probe"
if [ "$is_ro" = 0 ]; then
  echo "SKIP read-only-settings arms: this filesystem (or this user) ignores a read-only file mode"
else
  # L1: a valid settings.json the user cannot write. Before J17 settings_tmp
  # ran cp -p before the jq write, so the temp inherited 444 and the write
  # failed: this exited 1 with [FAILED] and no registration at all.
  isL1="$(is_home_new hL1)"
  printf '{"other":1}\n' > "$isL1/.claude/settings.json"
  chmod 444 "$isL1/.claude/settings.json"
  is_run "$isL1"; ck "read-only settings exit" 0 "$?"
  ck "read-only settings gets one 1800s registration" "1 1800" "$(is_reg "$isL1/.claude/settings.json")"
  ck "read-only settings keeps the user key" "1" \
    "$(jq -r '.other // "ABSENT"' < "$isL1/.claude/settings.json" 2>/dev/null || echo UNREADABLE)"
  # The mode is read with -w rather than with stat, which differs between GNU
  # and BSD userlands; what the claim is about is whether it stayed unwritable.
  ck "read-only settings is left read-only" "readonly" \
    "$(if [ -w "$isL1/.claude/settings.json" ]; then echo writable; else echo readonly; fi)"
  ck "read-only settings raises no shell error" 0 "$(is_both | grep -c 'line [0-9]*:')"
  ck "read-only settings leaves no temp behind" 0 \
    "$(find "$isL1/.claude" -name 'settings.json.*' | grep -c .)"

  # L2: empty and unwritable. This is the seed's own path: the direct
  # redirection at the head of the settings block failed here, and under
  # set -euo pipefail the installer died at that line with a bare Permission
  # denied, no [FAILED] line and no closing summary at all.
  isL2="$(is_home_new hL2)"
  : > "$isL2/.claude/settings.json"
  chmod 444 "$isL2/.claude/settings.json"
  is_run "$isL2"; ck "empty read-only settings exit" 0 "$?"
  ck "empty read-only settings gets one 1800s registration" "1 1800" \
    "$(is_reg "$isL2/.claude/settings.json")"
  ck "empty read-only settings raises no shell error" 0 "$(is_both | grep -c 'line [0-9]*:')"
  ck "empty read-only settings reaches the closing summary" 1 \
    "$(grep -cE '^Done\.|^Skills installed, but fix' "$is_tmp/out")"

  # L3: whitespace only and unwritable. The same site, and the state the
  # whitespace test was added to catch - it widened what reaches that write.
  isL3="$(is_home_new hL3)"
  printf '   \n\t\n' > "$isL3/.claude/settings.json"
  chmod 444 "$isL3/.claude/settings.json"
  is_run "$isL3"; ck "whitespace-only read-only settings exit" 0 "$?"
  ck "whitespace-only read-only settings gets one 1800s registration" "1 1800" \
    "$(is_reg "$isL3/.claude/settings.json")"
  ck "whitespace-only read-only settings raises no shell error" 0 \
    "$(is_both | grep -c 'line [0-9]*:')"
fi

# --- M. a fresh install says nothing on stderr (J17) -------------------------
# The whitespace test reads the settings file through a redirection, and with
# its 2>/dev/null written after that redirection rather than before it the
# shell's own "No such file or directory" reached stderr on every install into
# a home with no settings.json yet. Bash applies redirections left to right,
# so the order is the whole content of the fix, and nothing here had ever read
# this installer's stderr on the ordinary path.
isM="$(is_home_new hM)"
rm -f "$isM/.claude/settings.json"
is_run "$isM"; ck "fresh install into a home with no settings.json exits 0" 0 "$?"
ck "a fresh install raises no shell diagnostic on stderr" 0 "$(grep -c 'line [0-9]*:' "$is_tmp/err")"

if [ "$is_bad" -eq 0 ]; then
  echo "install-sh battery: $is_ok/$is_ok checks passed"
  exit 0
fi
echo "install-sh battery: $is_bad of $((is_ok + is_bad)) checks failed"
exit 1
