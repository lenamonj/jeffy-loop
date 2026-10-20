#!/usr/bin/env bash
# install-ps1 battery - drive the shipped Windows installer's documented
# contract against throwaway profiles and assert the observable outcome of
# each case, never merely that it ran.
#
# Why it exists: scripts/validate.sh finds a PowerShell interpreter only on
# PATH (checks 4 and 9), so on a WSL host where Windows PowerShell is
# reachable through interop but absent from PATH, install.ps1 is graded by
# nothing local. That left its Surface inventory row recorded unreachable for
# four runs on a host that could in fact run it.
#
# Safety: the sandbox profile redirect is asserted from inside the process
# that will run the installer, before it runs. $HOME is read-only in Windows
# PowerShell 5.1, so an assignment to it fails non-terminating and the
# installer proceeds against the operator's real profile - which happened
# once here. This battery refuses to run the installer until the child
# process reports the sandbox as its own $HOME.
#
# Exit 0 and a one-line notice where no PowerShell host is reachable: a probe
# that cannot run on this host is not a failing probe.
set -u

root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root" || { echo "install-ps1 battery: cannot reach the repository root" >&2; exit 2; }

# --- interpreter discovery: PATH first, then the WSL interop location ---
ps=""
if [ -n "${JEFFY_PS:-}" ] && command -v "$JEFFY_PS" >/dev/null 2>&1; then
  ps="$JEFFY_PS"
elif command -v pwsh >/dev/null 2>&1; then
  ps="$(command -v pwsh)"
elif command -v powershell >/dev/null 2>&1; then
  ps="$(command -v powershell)"
else
  for cand in /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe \
              /mnt/c/Program\ Files/PowerShell/7/pwsh.exe; do
    [ -x "$cand" ] && { ps="$cand"; break; }
  done
fi
[ -n "$ps" ] || { echo "install-ps1 battery: unavailable - no PowerShell host reachable on this host"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "install-ps1 battery: unavailable - jq is not on PATH"; exit 0; }

pass=0; fail=0
ck() { # ck <label> <condition-exit-status>
  if [ "$2" = 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "  FAIL: $1"; fi
}

# The Windows-visible form of a directory, derived by asking the interpreter
# rather than by string arithmetic: cygpath exists on MINGW and not on WSL,
# and the UNC root a WSL distro is reachable at is not a constant.
winpath() { ( cd "$1" && "$ps" -NoProfile -NonInteractive -Command '(Get-Location).ProviderPath' 2>/dev/null | tr -d '\r' ); }

tmp="$(mktemp -d)" || { echo "install-ps1 battery: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"; bin="$tmp/bin"
mkdir -p "$repo" "$bin"
cp install.ps1 "$repo/" && cp -R skills "$repo/skills"
# Stub the two prerequisites so no prompt fires and no winget branch runs.
printf '@echo off\r\nexit /b 0\r\n' > "$bin/claude.bat"
printf '@echo off\r\nexit /b 0\r\n' > "$bin/jq.bat"
w_repo="$(winpath "$repo")"
w_bin="$(winpath "$bin")"
if [ -z "$w_repo" ] || [ -z "$w_bin" ]; then
  echo "install-ps1 battery: could not resolve the sandbox as the interpreter sees it" >&2
  exit 2
fi

# Run the installer against $1 as its profile. The redirect is set in this
# process and the installer runs in a child, because $HOME is read-only in
# 5.1; the child prints its own $HOME first and the run is abandoned unless
# that line is the sandbox.
run_install() {
  local phome w_home
  phome="$1"; w_home="$(winpath "$phome")"
  [ -n "$w_home" ] || return 90
  "$ps" -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "
    \$env:USERPROFILE = '$w_home'
    \$env:PATH = '$w_bin' + ';' + \$env:PATH
    Remove-Item Env:HOMEDRIVE -ErrorAction SilentlyContinue
    Remove-Item Env:HOMEPATH  -ErrorAction SilentlyContinue
    \$exe = (Get-Process -Id \$PID).Path
    \$seen = & \$exe -NoProfile -NonInteractive -Command '\$HOME'
    if (\"\$seen\".Trim() -ne '$w_home') {
      [Console]::Error.WriteLine('REDIRECT NOT IN EFFECT: child HOME is ' + \$seen)
      exit 91
    }
    & \$exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File '$w_repo\\install.ps1'
    exit \$LASTEXITCODE
  " 2>&1 | tr -d '\r'
  return "${PIPESTATUS[0]}"
}

# The number of Stop registrations naming the engine, and the timeouts they carry.
regs() { jq -r '[.hooks.Stop[]?.hooks[]? | select(.command | test("skills/jeffy/hooks/stop-hook\\.sh"))] | length' "$1" 2>/dev/null; }
reg_timeouts() { jq -r '[.hooks.Stop[]?.hooks[]? | select(.command | test("skills/jeffy/hooks/stop-hook\\.sh")) | .timeout] | sort | join(",")' "$1" 2>/dev/null; }
other_hooks() { jq -r '[.hooks.Stop[]?.hooks[]? | select(.command | test("skills/jeffy/hooks/stop-hook\\.sh") | not) | .command] | sort | join(",")' "$1" 2>/dev/null; }

# --- P: the file parses, with the errors collected rather than discarded.
#        ParseFile reports a path it cannot read *into* the error collection,
#        so the [ref]$null form returns quietly and prints a pass over a file
#        carrying a real syntax error - which is how this battery's first
#        parse evidence was obtained before it was corrected. The provider
#        path is taken with .ProviderPath, because .Path yields the
#        provider-qualified form that ParseFile cannot open.
ps_parse() {
  "$ps" -NoProfile -NonInteractive -Command "
    \$e = \$null
    \$null = [System.Management.Automation.Language.Parser]::ParseFile(
      (Resolve-Path '$1').ProviderPath, [ref]\$null, [ref]\$e)
    if (\$e -and \$e.Count -gt 0) { exit 1 }
    exit 0" >/dev/null 2>&1
}
( cd "$repo" && ps_parse install.ps1 ); ck "P: install.ps1 parses with no errors" "$?"
# The single quotes hold PowerShell source, which must not expand here.
# shellcheck disable=SC2016
printf 'if ($true) {\n' > "$tmp/truncated.ps1"
( cd "$tmp" && ps_parse truncated.ps1 ) && pf=1 || pf=0
ck "P: the parse check faults on a truncated script, so its silence is evidence" "$pf"
rm -f "$tmp/truncated.ps1"

# --- A: a fresh profile gains both skills, the engine and one registration ---
A="$tmp/A"; mkdir -p "$A"
out="$(run_install "$A")"; rc=$?
ck "A: fresh install exits 0 (got $rc)" "$([ "$rc" = 0 ] && echo 0 || echo 1)"
for f in .claude/skills/jeffy/SKILL.md \
         .claude/skills/jeffy/hooks/stop-hook.sh \
         .claude/skills/jeffy/references/iteration-prompt.txt \
         .claude/skills/cancel-jeffy/SKILL.md \
         .claude/settings.json; do
  ck "A: $f installed" "$([ -f "$A/$f" ] && echo 0 || echo 1)"
done
ck "A: exactly one engine registration (got $(regs "$A/.claude/settings.json"))" "$([ "$(regs "$A/.claude/settings.json")" = 1 ] && echo 0 || echo 1)"
ck "A: that registration carries an 1800s timeout (got $(reg_timeouts "$A/.claude/settings.json"))" "$([ "$(reg_timeouts "$A/.claude/settings.json")" = 1800 ] && echo 0 || echo 1)"
ck "A: settings.json has no UTF-8 BOM" "$(head -c 3 "$A/.claude/settings.json" | od -An -tx1 | grep -q 'ef bb bf' && echo 1 || echo 0)"
ck "A: the run says it registered the hook" "$(printf '%s' "$out" | grep -q 'Stop hook registered' && echo 0 || echo 1)"

# --- B: a second run changes nothing and says so ---
out="$(run_install "$A")"; rc=$?
ck "B: second run exits 0 (got $rc)" "$([ "$rc" = 0 ] && echo 0 || echo 1)"
ck "B: still exactly one registration (got $(regs "$A/.claude/settings.json"))" "$([ "$(regs "$A/.claude/settings.json")" = 1 ] && echo 0 || echo 1)"
ck "B: the run says it was already registered" "$(printf '%s' "$out" | grep -q 'already registered' && echo 0 || echo 1)"

# --- C: a foreign settings.json - unrelated keys and hook kept, a dead-path
#        engine registration at 600s pruned, one live registration at 1800 ---
C="$tmp/C"; mkdir -p "$C/.claude"
cat > "$C/.claude/settings.json" <<'JSON'
{
  "model": "opus",
  "env": { "FOO": "bar" },
  "permissions": { "allow": ["Bash(ls:*)"] },
  "hooks": {
    "Stop": [
      { "hooks": [ { "type": "command", "command": "bash \"/nonexistent/elsewhere/.claude/skills/jeffy/hooks/stop-hook.sh\"", "timeout": 600 } ] },
      { "hooks": [ { "type": "command", "command": "echo unrelated-stop-hook", "timeout": 5 } ] }
    ]
  }
}
JSON
out="$(run_install "$C")"; rc=$?
ck "C: foreign-profile install exits 0 (got $rc)" "$([ "$rc" = 0 ] && echo 0 || echo 1)"
ck "C: the dead-path registration was pruned and reported" "$(printf '%s' "$out" | grep -q 'removed a Stop hook registration naming a hook that does not exist' && echo 0 || echo 1)"
ck "C: exactly one engine registration remains (got $(regs "$C/.claude/settings.json"))" "$([ "$(regs "$C/.claude/settings.json")" = 1 ] && echo 0 || echo 1)"
ck "C: it carries 1800 and not 600 (got $(reg_timeouts "$C/.claude/settings.json"))" "$([ "$(reg_timeouts "$C/.claude/settings.json")" = 1800 ] && echo 0 || echo 1)"
ck "C: the unrelated Stop hook survives (got $(other_hooks "$C/.claude/settings.json"))" "$([ "$(other_hooks "$C/.claude/settings.json")" = 'echo unrelated-stop-hook' ] && echo 0 || echo 1)"
ck "C: unrelated top-level keys survive" "$([ "$(jq -r '[.model, .env.FOO, .permissions.allow[0]] | join("|")' "$C/.claude/settings.json" 2>/dev/null)" = 'opus|bar|Bash(ls:*)' ] && echo 0 || echo 1)"
ck "C: no dead path is left anywhere in the file" "$(grep -q '/nonexistent/elsewhere' "$C/.claude/settings.json" && echo 1 || echo 0)"

# --- D: a file the shipped tree no longer carries is removed ---
D="$tmp/D"; mkdir -p "$D/.claude/skills/jeffy/references"
printf 'stale\n' > "$D/.claude/skills/jeffy/references/enhance-plan-default.md"
out="$(run_install "$D")"; rc=$?
ck "D: install over a stale profile exits 0 (got $rc)" "$([ "$rc" = 0 ] && echo 0 || echo 1)"
ck "D: the unshipped file is gone" "$([ -e "$D/.claude/skills/jeffy/references/enhance-plan-default.md" ] && echo 1 || echo 0)"
ck "D: the removal was reported" "$(printf '%s' "$out" | grep -q 'no longer shipped' && echo 0 || echo 1)"
ck "D: a shipped sibling is still installed" "$([ -f "$D/.claude/skills/jeffy/references/plan-default.md" ] && echo 0 || echo 1)"

# --- E: unparseable settings.json is reported and never overwritten ---
E="$tmp/E"; mkdir -p "$E/.claude"
printf '{ this is not json\n' > "$E/.claude/settings.json"
before="$(cat "$E/.claude/settings.json")"
out="$(run_install "$E")"; rc=$?
ck "E: a broken settings.json makes the installer exit non-zero (got $rc)" "$([ "$rc" != 0 ] && echo 0 || echo 1)"
ck "E: it names the file as invalid JSON" "$(printf '%s' "$out" | grep -q 'is not valid JSON' && echo 0 || echo 1)"
ck "E: the file was left byte-identical" "$([ "$(cat "$E/.claude/settings.json")" = "$before" ] && echo 0 || echo 1)"
ck "E: the skills still installed despite the failure" "$([ -f "$E/.claude/skills/jeffy/SKILL.md" ] && echo 0 || echo 1)"

# --- G, H, I: the atomic-write contract (T7). G and H were the reproduction
#     before the fix - G printed [FAILED] and exited 1 where install.sh on
#     identical input exits 0, and H threw a raw PowerShell error record from
#     the prune write, which sat outside every handler. I is the arm that must
#     still fail, and fail the product's own way: a settings.json that cannot
#     be replaced at all reports [FAILED], exits non-zero, prints no raw error
#     record and leaves no temporary file behind.
leftovers() { find "$1/.claude" -maxdepth 1 -name 'settings.json.jeffy-*' 2>/dev/null | wc -l; }
raw_record() { printf '%s' "$1" | grep -qE 'CategoryInfo|FullyQualifiedErrorId|At line:[0-9]+ char:' && echo 1 || echo 0; }

G="$tmp/G"; mkdir -p "$G/.claude"
printf '{"model":"opus"}\n' > "$G/.claude/settings.json"
chmod 444 "$G/.claude/settings.json"
out="$(run_install "$G")"; rc=$?
chmod 644 "$G/.claude/settings.json" 2>/dev/null || true
ck "G: a read-only settings.json is replaced rather than refused, exit 0 (got $rc)" "$([ "$rc" = 0 ] && echo 0 || echo 1)"
ck "G: exactly one engine registration landed (got $(regs "$G/.claude/settings.json"))" "$([ "$(regs "$G/.claude/settings.json")" = 1 ] && echo 0 || echo 1)"
ck "G: it carries 1800 (got $(reg_timeouts "$G/.claude/settings.json"))" "$([ "$(reg_timeouts "$G/.claude/settings.json")" = 1800 ] && echo 0 || echo 1)"
ck "G: the pre-existing key survived the replacement" "$([ "$(jq -r '.model' "$G/.claude/settings.json" 2>/dev/null)" = opus ] && echo 0 || echo 1)"
ck "G: no [FAILED] line was printed" "$(printf '%s' "$out" | grep -q '\[FAILED\]' && echo 1 || echo 0)"
ck "G: no temporary file was left behind (got $(leftovers "$G"))" "$([ "$(leftovers "$G")" = 0 ] && echo 0 || echo 1)"

H="$tmp/H"; mkdir -p "$H/.claude"
cat > "$H/.claude/settings.json" <<'JSON'
{"model":"opus","hooks":{"Stop":[{"hooks":[{"type":"command","command":"bash \"/nonexistent/elsewhere/.claude/skills/jeffy/hooks/stop-hook.sh\"","timeout":600}]}]}}
JSON
chmod 444 "$H/.claude/settings.json"
out="$(run_install "$H")"; rc=$?
chmod 644 "$H/.claude/settings.json" 2>/dev/null || true
ck "H: a read-only settings.json needing a prune exits 0 (got $rc)" "$([ "$rc" = 0 ] && echo 0 || echo 1)"
ck "H: the prune write no longer throws a raw error record" "$(raw_record "$out")"
ck "H: the dead-path registration was pruned and reported" "$(printf '%s' "$out" | grep -q 'removed a Stop hook registration naming a hook that does not exist' && echo 0 || echo 1)"
ck "H: exactly one engine registration remains (got $(regs "$H/.claude/settings.json"))" "$([ "$(regs "$H/.claude/settings.json")" = 1 ] && echo 0 || echo 1)"
ck "H: it carries 1800 and not 600 (got $(reg_timeouts "$H/.claude/settings.json"))" "$([ "$(reg_timeouts "$H/.claude/settings.json")" = 1800 ] && echo 0 || echo 1)"
ck "H: no dead path survives in the file" "$(grep -q '/nonexistent/elsewhere' "$H/.claude/settings.json" && echo 1 || echo 0)"
ck "H: no temporary file was left behind (got $(leftovers "$H"))" "$([ "$(leftovers "$H")" = 0 ] && echo 0 || echo 1)"

I="$tmp/I"; mkdir -p "$I/.claude/settings.json"
out="$(run_install "$I")"; rc=$?
ck "I: a settings.json that cannot be replaced exits non-zero (got $rc)" "$([ "$rc" != 0 ] && echo 0 || echo 1)"
ck "I: it prints the product's [FAILED] line naming the path" "$(printf '%s' "$out" | grep -q '\[FAILED\].*settings\.json' && echo 0 || echo 1)"
ck "I: it prints no raw PowerShell error record" "$(raw_record "$out")"
ck "I: no temporary file was left behind (got $(leftovers "$I"))" "$([ "$(leftovers "$I")" = 0 ] && echo 0 || echo 1)"
ck "I: the skills still installed despite the failure" "$([ -f "$I/.claude/skills/jeffy/SKILL.md" ] && echo 0 || echo 1)"

total=$((pass + fail))
if [ "$fail" = 0 ]; then
  echo "install-ps1 battery ok: $pass/$total checks passed ($ps)"
  exit 0
fi
echo "install-ps1 battery FAILED: $fail of $total checks failed ($ps)"
exit 1
