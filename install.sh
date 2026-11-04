#!/usr/bin/env bash
# Jeffy installer: verifies prerequisites, installs the /jeffy skill (which
# ships the Stop hook loop engine), and registers the hook in ~/.claude/settings.json.
set -euo pipefail

echo "Jeffy installer"
echo ""

ok=1
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Claude Code CLI (the one prerequisite this installer cannot install for you)
if command -v claude >/dev/null 2>&1; then
  echo "[OK] Claude Code CLI found"
else
  echo "[MISSING] Claude Code CLI. Install it first: https://claude.com/claude-code"
  ok=0
fi

# 2. jq (required by Jeffy's Stop hook, and by this installer to edit settings.json)
if command -v jq >/dev/null 2>&1; then
  echo "[OK] jq found"
elif command -v brew >/dev/null 2>&1; then
  read -r -p "[MISSING] jq is required by Jeffy's Stop hook. Install with brew now? (y/n) " answer || { answer=""; echo "[MISSING] jq, and the install prompt could not be answered (non-interactive run)."; }
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    if brew install jq; then
      echo "[OK] jq installed"
    else
      echo "[FAILED] brew install failed. Install manually: brew install jq"
      ok=0
    fi
  else
    echo "Skipped. Install later with: brew install jq"
    ok=0
  fi
elif command -v apt-get >/dev/null 2>&1; then
  read -r -p "[MISSING] jq is required by Jeffy's Stop hook. Install with apt now? (y/n) " answer || { answer=""; echo "[MISSING] jq, and the install prompt could not be answered (non-interactive run)."; }
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    if sudo apt-get install -y jq; then
      echo "[OK] jq installed"
    else
      echo "[FAILED] apt-get install failed. Install manually: sudo apt-get install jq"
      ok=0
    fi
  else
    echo "Skipped. Install later with: sudo apt-get install jq"
    ok=0
  fi
else
  echo "[MISSING] jq. Install it with your package manager (brew install jq / sudo apt install jq)"
  ok=0
fi

# 3. Install the skills (/jeffy and /cancel-jeffy). The jeffy skill folder
#    carries the Stop hook at hooks/stop-hook.sh, so the engine lands here too.
for name in jeffy cancel-jeffy; do
  src="$script_dir/skills/$name/SKILL.md"
  if [[ ! -f "$src" ]]; then
    echo "ERROR: skills/$name/SKILL.md not found next to this script. Run install.sh from the cloned repo." >&2
    exit 1
  fi
  dest="$HOME/.claude/skills/$name"
  mkdir -p "$dest"
  cp -R "$script_dir/skills/$name/." "$dest/"
  # A copy over the top never removes: references/enhance-plan-default.md
  # outlived its removal in 1.11.0 on every installed host. Files the shipped
  # tree no longer carries are removed, and nothing else - a template the user
  # edited is still overwritten by the copy above, as it always was.
  while IFS= read -r stale; do
    [ -n "$stale" ] || continue
    [ -e "$script_dir/skills/$name/$stale" ] || { rm -f "$dest/$stale"; echo "[OK] removed $dest/$stale (not in this version)"; }
  done < <(cd "$dest" && find . -type f | sed 's|^\./||')
  echo "[OK] /$name skill installed to $dest"
done
# cp over an existing file keeps that file's mode, so an upgrade from a release
# that shipped a hook script at 644 would keep it there; every one is set here.
find "$HOME/.claude/skills/jeffy/hooks" -type f -name '*.sh' -exec chmod +x {} + 2>/dev/null || true

# 4. Register the Stop hook (the loop engine) in ~/.claude/settings.json.
#    Idempotent: a settings file that already names the hook is left alone, and
#    an unparseable settings file is never overwritten.
settings="$HOME/.claude/settings.json"
hook_frag="skills/jeffy/hooks/stop-hook.sh"
# The command runs under a shell, so a $ in the home path is escaped.
hook_cmd="bash \"${HOME//\$/\\\$}/.claude/skills/jeffy/hooks/stop-hook.sh\""
if command -v jq >/dev/null 2>&1; then
  mkdir -p "$HOME/.claude"
  # The replacement lands beside the real file, so the rename is a rename: a link
  # stays a link, the mode stays, and a full disk fails the write and leaves the
  # file alone. macOS before 12.3 has no readlink -f and replaces the link.
  # Resolved ahead of the seed below, because that seed now falls back to this
  # same temp-and-rename path and so needs $real. (J17)
  real="$settings"
  if [ -L "$settings" ]; then
    real="$(readlink -f "$settings" 2>/dev/null || true)"
    [ -n "$real" ] || real="$settings"
  fi
  # A registration names the hook by path, and a settings.json carried in
  # from another home names that home's hook: "already registered" would
  # hold while the loop never fires. A Jeffy registration whose path is no
  # file is removed here, so the steps below see this home's truth.
  # A temp file beside the real settings file, so the write lands by rename on
  # the same filesystem and a link stays a link. A file in a directory that
  # cannot be written, a store a dotfile manager generates, has nowhere for one,
  # and under set -e a failed assignment would end the run with no [FAILED]
  # line; each caller says what it left as it was.
  settings_tmp() {
    tmp="$(mktemp "$real.XXXXXX" 2>/dev/null)" || return 1
    # J17: the mode rides over so the rename preserves it, and the copy is then
    # made writable. cp -p stamps the source's mode on the temp, so a read-only
    # settings.json - the store a dotfile manager generates, named just above -
    # handed the temp its own 444 and every write below failed, while a rename
    # over that same file needs the directory rather than the file and works.
    # The sibling installer in src/jeffy_loop/cli.py writes its temp first and
    # copies the mode after, which is this fix in the other order, and its own
    # docstring states the property: a rename needs write permission on the
    # directory rather than on the file. settings_mv puts the mode back.
    cp -p "$real" "$tmp" 2>/dev/null || true
    chmod u+w "$tmp" 2>/dev/null || true
  }
  # The destination's own mode goes back on before the rename, so replacing a
  # read-only settings.json leaves it read-only. One bound, stated rather than
  # implied: root tests writable on every file, so a 444 settings.json replaced
  # by a root install comes back 644 - the file's accessibility to its readers
  # is unchanged, and no arm below claims otherwise.
  settings_mv() {
    if [ -e "$real" ] && [ ! -w "$real" ]; then
      chmod a-w "$tmp" 2>/dev/null || true
    fi
    mv -f "$tmp" "$real"
  }
  # A file of only whitespace is valid to jq empty and yields nothing to edit.
  # J17: the direct write stays the first attempt, so a fresh install still
  # creates the file at the umask's mode exactly as it always has and as the
  # sibling installer does. It fails only where the file exists and cannot be
  # written, and under set -euo pipefail that ended the installer at this line
  # with a bare Permission denied, no [FAILED] line and no closing summary -
  # the skills installed and the hook not. The 2>/dev/null precedes the
  # redirection it silences, because bash applies them left to right and the
  # message is the shell's own rather than printf's. The tr reads its input the
  # same way for the same reason: with the 2>/dev/null written after the input
  # redirection, as it was, a fresh install where settings.json does not exist
  # yet leaked a bare "No such file or directory" on every single run.
  if [ -z "$(tr -d '[:space:]' 2>/dev/null < "$settings")" ] \
    && ! printf '{}\n' 2>/dev/null > "$settings"; then
    if settings_tmp && printf '{}\n' > "$tmp" && settings_mv; then
      :
    else
      rm -f "$tmp" 2>/dev/null || true
      echo "[FAILED] $settings holds no JSON object and could not be seeded with one: neither it nor $(dirname "$real") can be written; put {} in that file by hand, or make that directory writable, then re-run."
      ok=0
    fi
  fi
  # jq reads every file on stdin: under Git Bash a native jq is handed a POSIX
  # path unconverted when it holds an apostrophe, and cannot open it.
  prune_failed=0
  if jq empty < "$settings" >/dev/null 2>&1; then
    dead_cmds=""
    while IFS= read -r reg_cmd; do
      # jq on Windows ends every -r line in CRLF.
      reg_cmd="${reg_cmd%$'\r'}"
      # A quoted path may hold a space, so the quoted token is read first.
      reg_path="$(printf '%s' "$reg_cmd" | grep -oE "\"[^\"]*$hook_frag\"|'[^']*$hook_frag'|[^\"' ]*$hook_frag" | head -n 1)"
      # Only the surrounding quotes go: a home path can hold an apostrophe.
      reg_path="${reg_path#[\"\']}"; reg_path="${reg_path%[\"\']}"
      reg_path="${reg_path/#\~/$HOME}"
      reg_path="${reg_path//\$\{HOME\}/$HOME}"
      reg_path="${reg_path//\$HOME/$HOME}"
      reg_path="${reg_path//\\\$/\$}"
      [ -f "$reg_path" ] || dead_cmds="$dead_cmds$reg_cmd"$'\n'
    done < <(jq -r --arg frag "$hook_frag" '.hooks.Stop[]?.hooks[]?.command // empty | select(contains($frag))' < "$settings")
    if [ -n "$dead_cmds" ]; then
      if ! settings_tmp; then
        echo "[FAILED] no temporary file can be made beside $real, most often because $(dirname "$real") is not writable, so the Stop hook registration naming a hook that does not exist ($(printf '%s' "$dead_cmds" | head -n 1)) was left in place; make that directory writable, or remove that entry and add the registration where that file is generated, then re-run."
        ok=0; prune_failed=1
      elif jq --arg dead "$dead_cmds" '($dead | split("\n") | map(select(. != ""))) as $d | .hooks.Stop |= [.[] | if (.hooks | type) == "array" then (.hooks |= [.[] | select(((.command // "") as $c | any($d[]; . == $c)) | not)]) else . end | select((.hooks | type) != "array" or (.hooks | length) > 0)]' < "$settings" > "$tmp" \
        && jq empty < "$tmp" >/dev/null 2>&1; then
        settings_mv
        echo "[OK] removed a Stop hook registration naming a hook that does not exist: $(printf '%s' "$dead_cmds" | head -n 1)"
      else
        rm -f "$tmp"
        echo "[FAILED] $settings registers a Stop hook that does not exist ($(printf '%s' "$dead_cmds" | head -n 1)) and it could not be removed; delete that entry by hand and re-run."
        ok=0; prune_failed=1
      fi
    fi
  fi
  if ! jq empty < "$settings" >/dev/null 2>&1; then
    echo "[FAILED] $settings is not valid JSON; fix it, then re-run this installer to register the hook."
    ok=0
  elif [ "$prune_failed" = 1 ]; then
    # The only registration names a hook that does not exist and could not be
    # removed; the line above said so, and "already registered" would be false.
    :
  elif jq -e --arg frag "$hook_frag" '[.hooks.Stop[]?.hooks[]?.command // empty] | any(contains($frag))' < "$settings" >/dev/null 2>&1; then
    # Already registered. A pre-1.2 registration lacks the timeout field and a
    # 1.2-1.14 registration carries 600s; the hook runs the project's verify
    # command at the converged stop under a bound that can exceed 600s (P1-58),
    # so upgrade either shape to 1800s exactly once.
    if jq -e --arg frag "$hook_frag" '[.hooks.Stop[]?.hooks[]? | select((.command // "") | contains($frag)) | (has("timeout") and .timeout != 600)] | all' < "$settings" >/dev/null 2>&1; then
      echo "[OK] Jeffy Stop hook already registered in $settings"
    else
      if ! settings_tmp; then
        echo "[FAILED] no temporary file can be made beside $real, most often because $(dirname "$real") is not writable, so the Stop hook timeout could not be upgraded; make that directory writable or add \"timeout\": 1800 to the hook entry where that file is generated, then re-run."
        ok=0
      elif jq --arg frag "$hook_frag" '.hooks.Stop |= [.[] | if (.hooks | type) == "array" then (.hooks |= [.[] | if ((.command // "") | contains($frag)) and ((has("timeout") | not) or .timeout == 600) then . + {"timeout": 1800} else . end]) else . end]' < "$settings" > "$tmp" \
        && jq empty < "$tmp" >/dev/null 2>&1; then
        settings_mv
        echo "[OK] Jeffy Stop hook registration upgraded to an 1800s timeout in $settings"
      else
        rm -f "$tmp"
        echo "[FAILED] could not upgrade the Stop hook timeout in $settings; add \"timeout\": 1800 to the hook entry by hand and re-run to verify."
        ok=0
      fi
    fi
  else
    if ! settings_tmp; then
      echo "[FAILED] no temporary file can be made beside $real, most often because $(dirname "$real") is not writable, so the Stop hook could not be registered; make that directory writable or add the registration where that file is generated, then re-run."
      ok=0
    elif jq --arg cmd "$hook_cmd" '.hooks //= {} | .hooks.Stop //= [] | .hooks.Stop += [{"hooks": [{"type": "command", "command": $cmd, "timeout": 1800}]}]' < "$settings" > "$tmp" \
      && jq empty < "$tmp" >/dev/null 2>&1; then
      settings_mv
      echo "[OK] Jeffy Stop hook registered in $settings (1800s timeout)"
    else
      rm -f "$tmp"
      echo "[FAILED] could not update $settings; add the Stop hook entry by hand (see README) and re-run to verify."
      ok=0
    fi
  fi
else
  echo "[SKIPPED] hook registration needs jq; install jq, then re-run this installer."
  ok=0
fi

echo ""
if [[ $ok -eq 1 ]]; then
  echo "Done. Start a new Claude Code session in any project and run: /jeffy"
else
  echo "Skills installed, but fix the items above, then re-run this installer to verify."
  exit 1
fi
