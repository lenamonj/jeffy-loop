#!/usr/bin/env bash
# Known-answer battery for the shipped console script, src/jeffy_loop.
#
# The package is staged the way the wheel builds it - src/jeffy_loop/*.py plus
# the force-include map read out of pyproject.toml rather than typed here - and
# then driven as a user drives it: every documented command, every documented
# parameter at two or more values that must change the answer, and every
# failure shape the module's own docstrings claim to turn into a [FAILED] line.
#
# Two roots on purpose. The module under test is resolved from
# JEFFY_PROBE_ROOT, so a staged mutation of cli.py can be pointed at with no
# copy of the skills payload beside it; the payload and pyproject are read from
# the project root either way.
#
# shellcheck disable=SC2016
#   Every single-quoted $ below is a literal the shell must not expand: the
#   registered hook command carries an escaped dollar by design, and the
#   fixture home paths are the inputs that produce it. Expanding any of them
#   would test a different string than the one a user's settings.json holds.
#   The disable sits above `set -u` because a directive placed after the first
#   command silences nothing (PLAN.md Lessons).
set -u
jl_proj="$PWD"
jl_root="${JEFFY_PROBE_ROOT:-$PWD}"
jl_mod="$jl_root/src/jeffy_loop"
[ -d "$jl_mod" ] || { echo "jeffy-loop-cli battery: no $jl_mod"; exit 2; }
[ -f "$jl_proj/pyproject.toml" ] || { echo "jeffy-loop-cli battery: no $jl_proj/pyproject.toml"; exit 2; }

jl_py=""
for jl_c in python3 python; do
  # Resolved to an absolute path, because the missing-prerequisite arm below
  # runs with a PATH holding neither claude nor jq - and a bare interpreter
  # name is not findable there either, which made that arm exit 127 and read
  # as the installer failing rather than as the battery hiding its own python.
  jl_py="$(command -v "$jl_c" 2>/dev/null)" && [ -n "$jl_py" ] && break
  jl_py=""
done
[ -n "$jl_py" ] || { echo "jeffy-loop-cli battery: NOT RUNNABLE: no python3 or python on PATH; install python3"; exit 2; }

jl_ok=0; jl_bad=0
ck() { # $1 label, $2 expected, $3 actual
  if [ "$2" = "$3" ]; then jl_ok=$((jl_ok + 1)); else
    jl_bad=$((jl_bad + 1)); echo "FAIL $1: expected [$2] got [$3]"
  fi
}

jl_tmp="$(mktemp -d)" || exit 2
# The read-only fixtures below would defeat rm -rf, so the mode is restored
# first; a battery that leaves a 0500 directory in TMPDIR is its own defect.
trap 'chmod -R u+rwX "$jl_tmp" 2>/dev/null; rm -rf "$jl_tmp"' EXIT

# --- stage the package exactly as the wheel declares it -----------------------
jl_stage="$jl_tmp/pkg"; jl_bin="$jl_tmp/bin"
mkdir -p "$jl_stage/jeffy_loop" "$jl_bin"
cp "$jl_mod"/*.py "$jl_stage/jeffy_loop/" 2>/dev/null
jl_pairs="$(sed -n '/^\[tool.hatch.build.targets.wheel.force-include\]/,/^\[/p' "$jl_proj/pyproject.toml" \
  | sed -n 's/^"\{0,1\}\([^"=]*\)"\{0,1\}[[:space:]]*=[[:space:]]*"\([^"]*\)"[[:space:]]*$/\1|\2/p')"
jl_staged=0
while IFS='|' read -r jl_src jl_dst; do
  [ -n "$jl_src" ] || continue
  mkdir -p "$jl_stage/${jl_dst%/*}"
  cp -R "$jl_proj/$jl_src" "$jl_stage/$jl_dst" && jl_staged=$((jl_staged + 1))
done <<EOF
$jl_pairs
EOF
# A staging that read an empty map would install no skills and every arm below
# would pass over a packaging change, which is the failure this guard names.
ck "force-include pairs staged from pyproject" 2 "$jl_staged"
jl_mods=0
for jl_m in "$jl_stage/jeffy_loop"/*.py; do [ -f "$jl_m" ] && jl_mods=$((jl_mods + 1)); done
ck "modules staged" 2 "$jl_mods"

printf '#!/bin/sh\nexit 0\n' > "$jl_bin/claude"; chmod +x "$jl_bin/claude"
printf '#!/bin/sh\nexit 0\n' > "$jl_bin/jq"; chmod +x "$jl_bin/jq"

jl_frag="skills/jeffy/hooks/stop-hook.sh"
export PYTHONPYCACHEPREFIX="$jl_tmp/pyc"

# Run the console script against a sandbox home. $1 is the home, the rest is
# the argv; stdout and stderr land in files so an arm can read either alone.
jl_run() {
  jl_home="$1"; shift
  HOME="$jl_home" USERPROFILE="$jl_home" PATH="$jl_bin:$PATH" PYTHONPATH="$jl_stage" \
    "$jl_py" -m jeffy_loop.cli "$@" </dev/null >"$jl_tmp/out" 2>"$jl_tmp/err"
}
# As above but with an empty PATH prefix, so a prerequisite is genuinely absent.
jl_run_bare() {
  jl_home="$1"; shift
  mkdir -p "$jl_tmp/nobin"
  HOME="$jl_home" USERPROFILE="$jl_home" PATH="$jl_tmp/nobin" PYTHONPATH="$jl_stage" \
    "$jl_py" -m jeffy_loop.cli "$@" </dev/null >"$jl_tmp/out" 2>"$jl_tmp/err"
}
jl_both() { cat "$jl_tmp/out" "$jl_tmp/err"; }
# Count the live Jeffy registrations and read the one timeout, from the file
# rather than from the printed line: the message is what the installer claims
# and settings.json is what Claude Code will actually read.
jl_reg() {
  "$jl_py" - "$1" "$jl_frag" <<'PY'
import json, sys
try:
    s = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception as exc:
    print("UNREADABLE", exc); raise SystemExit(0)
frag = sys.argv[2]
found = []
for entry in s.get("hooks", {}).get("Stop", []) or []:
    for h in (entry or {}).get("hooks", []) or []:
        if isinstance(h, dict) and frag in str(h.get("command", "")):
            found.append(h)
print(len(found), *(h.get("timeout") for h in found))
PY
}

jl_home_new() { jl_h="$jl_tmp/$1"; mkdir -p "$jl_h/.claude"; printf '%s' "$jl_h"; }

# --- A. help, usage and path --------------------------------------------------
jl_hA="$(jl_home_new hA)"
jl_run "$jl_hA" help; ck "help exit" 0 "$?"
cp "$jl_tmp/out" "$jl_tmp/help.txt"
ck "help lists four commands" 4 "$(grep -c '^jeffy ' "$jl_tmp/help.txt")"
for jl_alias in --help -h; do
  jl_run "$jl_hA" "$jl_alias"
  ck "$jl_alias matches help" "" "$(diff "$jl_tmp/help.txt" "$jl_tmp/out")"
done
jl_run "$jl_hA"; ck "no argv exit" 0 "$?"
ck "no argv matches help" "" "$(diff "$jl_tmp/help.txt" "$jl_tmp/out")"
jl_run "$jl_hA" bogus; ck "unknown command exit" 2 "$?"
ck "unknown command named on stderr" 1 "$(grep -c '^jeffy: unknown command: bogus$' "$jl_tmp/err")"
ck "unknown command still prints usage" 4 "$(grep -c '^jeffy ' "$jl_tmp/out")"
jl_run "$jl_hA" path; ck "path exit" 0 "$?"
ck "path prints the packaged skills dir" "$jl_stage/jeffy_loop/skills" "$(cat "$jl_tmp/out")"

# --- B. a fresh install -------------------------------------------------------
jl_hB="$(jl_home_new hB)"
jl_run "$jl_hB" install; ck "fresh install exit" 0 "$?"
ck "jeffy skill landed" 1 "$([ -f "$jl_hB/.claude/skills/jeffy/SKILL.md" ] && echo 1 || echo 0)"
ck "cancel-jeffy skill landed" 1 "$([ -f "$jl_hB/.claude/skills/cancel-jeffy/SKILL.md" ] && echo 1 || echo 0)"
ck "stop hook landed" 1 "$([ -f "$jl_hB/.claude/skills/jeffy/hooks/$(basename "$jl_frag")" ] && echo 1 || echo 0)"
ck "one registration at 1800s" "1 1800" "$(jl_reg "$jl_hB/.claude/settings.json")"
# The registered command is a shell string; what matters is that reading it
# back the way the installer's own prune reads it finds the file it installed.
ck "registered command resolves to the installed hook" live "$(
  HOME="$jl_hB" PYTHONPATH="$jl_stage" "$jl_py" - "$jl_hB/.claude/settings.json" <<'PY'
import json, sys
from jeffy_loop.cli import matching_hooks, registered_path
s = json.load(open(sys.argv[1], encoding="utf-8"))
h = matching_hooks(s)[0]
print("live" if registered_path(str(h["command"])).is_file() else "dead")
PY
)"

# --- C. idempotence and the two timeout upgrades ------------------------------
jl_run "$jl_hB" install; ck "second install exit" 0 "$?"
ck "second install reports already registered" 1 "$(grep -c 'already registered' "$jl_tmp/out")"
ck "second install adds no registration" "1 1800" "$(jl_reg "$jl_hB/.claude/settings.json")"
# The timeout field is a documented parameter with three values that must lead
# to three different outcomes: absent and 600 are upgraded, 1800 is left alone.
jl_upgrade() { # $1 label, $2 the hook object
  jl_hU="$(jl_home_new "hU$1")"
  printf '{"hooks":{"Stop":[{"hooks":[%s]}]}}\n' "$2" > "$jl_hU/.claude/settings.json"
  mkdir -p "$jl_hU/.claude/skills/jeffy/hooks"
  jl_run "$jl_hU" install
  ck "$1 upgrade exit" 0 "$?"
  ck "$1 upgraded to one 1800s registration" "1 1800" "$(jl_reg "$jl_hU/.claude/settings.json")"
  ck "$1 upgrade says so" 1 "$(grep -c 'upgraded to an 1800s timeout' "$jl_tmp/out")"
  jl_run "$jl_hU" install
  ck "$1 upgrade is once only" 1 "$(grep -c 'already registered' "$jl_tmp/out")"
}
jl_cmd600="bash \\\"$jl_tmp/hU600/.claude/$jl_frag\\\""
jl_upgrade 600 "{\"type\":\"command\",\"command\":\"$jl_cmd600\",\"timeout\":600}"
jl_cmdnone="bash \\\"$jl_tmp/hUnone/.claude/$jl_frag\\\""
jl_upgrade none "{\"type\":\"command\",\"command\":\"$jl_cmdnone\"}"

# --- D. preservation and the dead-registration prune --------------------------
jl_hD="$(jl_home_new hD)"
cat > "$jl_hD/.claude/settings.json" <<'JSON'
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
jl_run "$jl_hD" install; ck "install over a dead foreign registration exit" 0 "$?"
ck "the dead registration is reported removed" 1 "$(grep -c 'removed a Stop hook registration naming a hook that does not exist' "$jl_tmp/out")"
ck "exactly one live registration remains" "1 1800" "$(jl_reg "$jl_hD/.claude/settings.json")"
jl_keep() {
  "$jl_py" - "$jl_hD/.claude/settings.json" <<'PY'
import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
stop = s["hooks"]["Stop"]
other = sum(1 for e in stop for h in e.get("hooks", []) if h.get("command") == "echo unrelated")
print(other, "PreToolUse" in s["hooks"], s.get("env", {}).get("KEEP"))
PY
}
ck "unrelated Stop hook, other events and other keys all kept" "1 True 1" "$(jl_keep)"

# --- E. the stale-file sync ---------------------------------------------------
echo stale > "$jl_hB/.claude/skills/jeffy/references/gone.md"
jl_run "$jl_hB" install; ck "install over a stale file exit" 0 "$?"
ck "the stale file is named as removed" 1 "$(grep -c 'references/gone.md (not in this version)' "$jl_tmp/out")"
ck "the stale file is gone" 0 "$([ -f "$jl_hB/.claude/skills/jeffy/references/gone.md" ] && echo 1 || echo 0)"
ck "a shipped file beside it is kept" 1 "$([ -f "$jl_hB/.claude/skills/jeffy/references/iteration-prompt.txt" ] && echo 1 || echo 0)"

# --- F. the exec bit over an existing install ---------------------------------
jl_hF="$(jl_home_new hF)"
jl_run "$jl_hF" install >/dev/null 2>&1
find "$jl_hF/.claude/skills/jeffy/hooks" -name '*.sh' -exec chmod 644 {} +
if [ -x "$jl_hF/.claude/skills/jeffy/hooks/stop-hook.sh" ]; then
  echo "SKIP exec-bit arm: this filesystem does not clear the mode"
else
  jl_run "$jl_hF" install; ck "install over a 644 install exit" 0 "$?"
  ck "every installed hook script is executable again" 0 \
    "$(find "$jl_hF/.claude/skills/jeffy/hooks" -name '*.sh' ! -perm -u+x | grep -c .)"
fi

# --- G. a dollar in the home path ---------------------------------------------
# The installer escapes it so the shell reads the real path, and its own prune
# has to read that escape back or the second run calls its work dead.
jl_hG="$jl_tmp/h\$USER"; mkdir -p "$jl_hG/.claude"
jl_run "$jl_hG" install; ck "dollar-home install exit" 0 "$?"
ck "the registered command escapes the dollar" 1 \
  "$(grep -c 'h\\\\\$USER' "$jl_hG/.claude/settings.json")"
jl_run "$jl_hG" install; ck "dollar-home second install exit" 0 "$?"
ck "dollar-home registration read back as live, not re-added" "1 1800" "$(jl_reg "$jl_hG/.claude/settings.json")"
ck "dollar-home second install reports already registered" 1 "$(grep -c 'already registered' "$jl_tmp/out")"

# --- H. version, every branch -------------------------------------------------
jl_vstage="$jl_tmp/vpkg"; cp -R "$jl_stage" "$jl_vstage"
jl_vhook="$jl_vstage/jeffy_loop/$jl_frag"
jl_pkgver="$(sed -n 's/^__version__ = "\(.*\)"$/\1/p' "$jl_stage/jeffy_loop/__init__.py")"
ck "package version read from the staged module" 1 "$(printf '%s' "$jl_pkgver" | grep -c '^[0-9][0-9.]*$')"
jl_version() { # $1 home
  HOME="$1" USERPROFILE="$1" PYTHONPATH="$jl_vstage" \
    "$jl_py" -m jeffy_loop.cli version </dev/null >"$jl_tmp/out" 2>"$jl_tmp/err"
}
jl_hH="$(jl_home_new hH)"
jl_version "$jl_hH"; ck "version exit with nothing installed" 0 "$?"
ck "version prints the package and engine pair" 1 \
  "$(grep -c "^jeffy-loop $jl_pkgver (engine JEFFY_VERSION $jl_pkgver from the packaged stop-hook.sh)$" "$jl_tmp/out")"
HOME="$jl_hH" USERPROFILE="$jl_hH" PYTHONPATH="$jl_vstage" \
  "$jl_py" -m jeffy_loop.cli --version </dev/null >"$jl_tmp/out2" 2>/dev/null
ck "--version matches version" "" "$(diff "$jl_tmp/out" "$jl_tmp/out2")"
# The packaged engine disagreeing with the package is the build-without-a-bump
# shape, and it must not pass quietly.
sed -i.bak "s/^JEFFY_VERSION=.*/JEFFY_VERSION=\"9.9.9\"/" "$jl_vhook"
jl_version "$jl_hH"; ck "version exit when the packaged engine differs" 2 "$?"
ck "the packaged-engine mismatch names both versions" 1 \
  "$(grep -c "The package says $jl_pkgver and the packaged stop-hook.sh says 9.9.9" "$jl_tmp/err")"
mv "$jl_vhook.bak" "$jl_vhook"
jl_version "$jl_hH"; ck "version exit once the packaged engine agrees again" 0 "$?"
# An installed engine behind the package is the stale-session shape.
mkdir -p "$jl_hH/.claude/skills/jeffy/hooks"
printf 'JEFFY_VERSION="0.0.1"\n' > "$jl_hH/.claude/skills/jeffy/hooks/stop-hook.sh"
jl_version "$jl_hH"; ck "version exit when the installed engine differs" 2 "$?"
ck "the installed-engine mismatch tells the user to re-install" 1 \
  "$(grep -c "the installed engine is 0.0.1, not $jl_pkgver; run jeffy install" "$jl_tmp/err")"
printf 'JEFFY_VERSION="%s"\n' "$jl_pkgver" > "$jl_hH/.claude/skills/jeffy/hooks/stop-hook.sh"
jl_version "$jl_hH"; ck "version exit when the installed engine agrees" 0 "$?"

# --- I. a missing prerequisite ------------------------------------------------
# install.sh sets ok=0 and installs anyway, exiting 1; the Python installer is
# the same contract, and the two drifting is what this row exists to catch.
jl_hI="$(jl_home_new hI)"
jl_run_bare "$jl_hI" install; ck "install exit with no prerequisites on PATH" 1 "$?"
ck "the missing prerequisites are both reported" 2 "$(grep -c '^\[MISSING\]' "$jl_tmp/out")"
ck "install still says what to do next" 1 "$(grep -c 'Skills installed, but fix the items above' "$jl_tmp/out")"
ck "the skills landed anyway" 1 "$([ -f "$jl_hI/.claude/skills/jeffy/SKILL.md" ] && echo 1 || echo 0)"
ck "the hook was registered anyway" "1 1800" "$(jl_reg "$jl_hI/.claude/settings.json")"

# --- J. the error boundary: every shape is a [FAILED] line, never a traceback -
jl_hJ1="$(jl_home_new hJ1)"
printf 'not json at all\n' > "$jl_hJ1/.claude/settings.json"
jl_run "$jl_hJ1" install; ck "invalid-JSON settings exit" 1 "$?"
ck "invalid-JSON settings reports FAILED" 1 "$(grep -c "^\[FAILED\] .*settings.json is not valid JSON" "$jl_tmp/out")"
ck "invalid-JSON settings is left untouched" "not json at all" "$(cat "$jl_hJ1/.claude/settings.json")"
ck "invalid-JSON settings raises no traceback" 0 "$(jl_both | grep -c Traceback)"

jl_hJ2="$(jl_home_new hJ2)"
chmod 500 "$jl_hJ2/.claude"
jl_run "$jl_hJ2" install; jl_rcJ2=$?
chmod 700 "$jl_hJ2/.claude"
if [ -d "$jl_hJ2/.claude/skills" ]; then
  echo "SKIP read-only-home arm: this filesystem ignored the directory mode"
else
  ck "read-only .claude exit" 1 "$jl_rcJ2"
  ck "read-only .claude reports FAILED naming a path" 1 "$(grep -c "^\[FAILED\] $jl_hJ2/.claude/skills" "$jl_tmp/out")"
  ck "read-only .claude raises no traceback" 0 "$(jl_both | grep -c Traceback)"
fi

# A read-only destination *inside* the skill tree is the copytree failure the
# shutil.Error arm of the boundary exists for: it carries a list of tuples and
# no filename, so the OSError arm cannot name anything useful.
jl_hJ3="$(jl_home_new hJ3)"
mkdir -p "$jl_hJ3/.claude/skills/jeffy"; printf 'x\n' > "$jl_hJ3/.claude/skills/jeffy/SKILL.md"
chmod 500 "$jl_hJ3/.claude/skills/jeffy"
jl_run "$jl_hJ3" install; jl_rcJ3=$?
chmod 700 "$jl_hJ3/.claude/skills/jeffy"
if [ -d "$jl_hJ3/.claude/skills/jeffy/references" ]; then
  echo "SKIP read-only-skill arm: this filesystem ignored the directory mode"
else
  ck "read-only skill dir exit" 1 "$jl_rcJ3"
  ck "read-only skill dir reports FAILED naming the source it could not copy" 1 \
    "$(grep -c "^\[FAILED\] $jl_stage/jeffy_loop/skills/jeffy/" "$jl_tmp/out")"
  ck "read-only skill dir raises no traceback" 0 "$(jl_both | grep -c Traceback)"
fi

# A read-only settings.json in a writable directory is replaced, as mv replaces
# it, and keeps its mode: a rename would otherwise take the umask's and open a
# 0600 file holding API keys to 0644.
jl_hJ4="$(jl_home_new hJ4)"
printf '{"env":{"KEEP":"1"}}\n' > "$jl_hJ4/.claude/settings.json"
chmod 444 "$jl_hJ4/.claude/settings.json"
jl_run "$jl_hJ4" install; jl_rcJ4=$?
if [ -w "$jl_hJ4/.claude/settings.json" ]; then
  echo "SKIP read-only-settings arm: this filesystem ignored the file mode"
else
  ck "read-only settings.json install exit" 0 "$jl_rcJ4"
  ck "read-only settings.json was replaced" "1 1800" "$(jl_reg "$jl_hJ4/.claude/settings.json")"
  ck "read-only settings.json kept its mode" 444 "$(
    "$jl_py" -c 'import os,sys;print(oct(os.stat(sys.argv[1]).st_mode & 0o777)[2:])' "$jl_hJ4/.claude/settings.json")"
  ck "read-only settings.json kept the user key" 1 "$(grep -c '"KEEP"' "$jl_hJ4/.claude/settings.json")"
  ck "read-only settings.json left no temp behind" 0 "$(find "$jl_hJ4/.claude" -name '*.jeffy-*.tmp' | grep -c .)"
fi

# A symlinked settings.json (stow, home-manager) is written through, not
# replaced by a regular file beside a dangling link.
jl_hJ5="$(jl_home_new hJ5)"
printf '{"env":{"KEEP":"1"}}\n' > "$jl_tmp/real-settings.json"
if ln -s "$jl_tmp/real-settings.json" "$jl_hJ5/.claude/settings.json" 2>/dev/null; then
  jl_run "$jl_hJ5" install; ck "symlinked settings.json install exit" 0 "$?"
  ck "symlinked settings.json is still a link" 1 "$([ -L "$jl_hJ5/.claude/settings.json" ] && echo 1 || echo 0)"
  ck "the link target carries the registration" "1 1800" "$(jl_reg "$jl_tmp/real-settings.json")"
else
  echo "SKIP symlinked-settings arm: this filesystem made no symlink"
fi

# --- K. uninstall -------------------------------------------------------------
jl_run "$jl_hD" uninstall; ck "uninstall exit" 0 "$?"
ck "uninstall removed both skill dirs" 0 \
  "$(( $([ -d "$jl_hD/.claude/skills/jeffy" ] && echo 1 || echo 0) + $([ -d "$jl_hD/.claude/skills/cancel-jeffy" ] && echo 1 || echo 0) ))"
ck "uninstall removed the Jeffy registration" 0 "$(jl_reg "$jl_hD/.claude/settings.json")"
ck "uninstall kept the unrelated hook, other events and other keys" "1 True 1" "$(jl_keep)"
jl_run "$jl_hD" uninstall; ck "second uninstall exit" 0 "$?"
ck "second uninstall says there is no hook left" 1 "$(grep -c 'no Jeffy Stop hook in' "$jl_tmp/out")"
ck "second uninstall says the skills were not installed" 2 "$(grep -c 'was not installed' "$jl_tmp/out")"
jl_hK="$(jl_home_new hK)"
jl_run "$jl_hK" uninstall; ck "uninstall with no settings.json exit" 0 "$?"
ck "uninstall with no settings.json says so" 1 "$(grep -c 'no .*settings.json to clean' "$jl_tmp/out")"

# --- L. the computed values, by known answer ----------------------------------
# hook_command writes the path a shell will read; registered_path reads it
# back. The pair is what decides whether the installer calls its own work dead,
# so each shape is asserted against the answer rather than against a run.
cat > "$jl_tmp/known.py" <<'PY'
import os, sys
from jeffy_loop.cli import registered_path, hook_command, HOOK_FRAGMENT as F

bad = 0
def ck(label, want, got):
    global bad
    if want != got:
        bad += 1
        print("FAIL %s: expected [%s] got [%s]" % (label, want, got))

os.environ["HOME"] = "/home/zz"
cases = [
    ("quoted",        'bash "/home/u/.claude/%s"' % F,        "/home/u/.claude/" + F),
    ("single quoted", "bash '/home/u/.claude/%s'" % F,        "/home/u/.claude/" + F),
    ("bare",          "bash /home/u/.claude/%s" % F,          "/home/u/.claude/" + F),
    ("path w space",  'bash "/home/a b/.claude/%s"' % F,      "/home/a b/.claude/" + F),
    ("tilde",         'bash "~/.claude/%s"' % F,              "/home/zz/.claude/" + F),
    ("escaped $",     'bash "/home/a\\$USER/.claude/%s"' % F, "/home/a$USER/.claude/" + F),
    ("trailing arg",  'bash "/home/u/.claude/%s" --x' % F,    "/home/u/.claude/" + F),
]
for label, cmd, want in cases:
    ck("registered_path " + label, want, str(registered_path(cmd)))

# The round trip is the property the prune depends on: whatever hook_command
# writes for a home, registered_path has to return that same home's hook.
for home in ["/home/plain", "/home/a$USER", "/home/a b", "/home/back\\slash", "/home/d$"]:
    os.environ["HOME"] = home
    ck("round trip %r" % home, home + "/.claude/" + F, str(registered_path(hook_command())))
print("known-answer failures: %d" % bad)
sys.exit(0)
PY
jl_known="$(PYTHONPATH="$jl_stage" "$jl_py" "$jl_tmp/known.py" 2>&1)"
ck "computed-value known answers" "known-answer failures: 0" "$(printf '%s\n' "$jl_known" | tail -n 1)"
printf '%s\n' "$jl_known" | grep '^FAIL ' || true

if [ "$jl_bad" -eq 0 ]; then
  echo "jeffy-loop-cli battery: $jl_ok/$jl_ok checks passed"
  exit 0
fi
echo "jeffy-loop-cli battery: $jl_bad of $((jl_ok + jl_bad)) checks failed"
exit 1
