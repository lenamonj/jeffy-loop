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
  echo "[OK] /$name skill installed to $dest"
done
chmod +x "$HOME/.claude/skills/jeffy/hooks/stop-hook.sh" 2>/dev/null || true

# 4. Register the Stop hook (the loop engine) in ~/.claude/settings.json.
#    Idempotent: a settings file that already names the hook is left alone, and
#    an unparseable settings file is never overwritten.
settings="$HOME/.claude/settings.json"
hook_frag="skills/jeffy/hooks/stop-hook.sh"
hook_cmd="bash \"$HOME/.claude/skills/jeffy/hooks/stop-hook.sh\""
if command -v jq >/dev/null 2>&1; then
  mkdir -p "$HOME/.claude"
  [[ -s "$settings" ]] || printf '{}\n' > "$settings"
  if ! jq empty "$settings" >/dev/null 2>&1; then
    echo "[FAILED] $settings is not valid JSON; fix it, then re-run this installer to register the hook."
    ok=0
  elif jq -e --arg frag "$hook_frag" '[.hooks.Stop[]?.hooks[]?.command // empty] | any(contains($frag))' "$settings" >/dev/null 2>&1; then
    # Already registered. A pre-1.2 registration lacks the timeout field; the
    # hook now runs the project's verify command at the converged stop, which
    # the default hook timeout cannot contain, so upgrade it exactly once.
    if jq -e --arg frag "$hook_frag" '[.hooks.Stop[]?.hooks[]? | select((.command // "") | contains($frag)) | has("timeout")] | all' "$settings" >/dev/null 2>&1; then
      echo "[OK] Jeffy Stop hook already registered in $settings"
    else
      tmp="$(mktemp)"
      if jq --arg frag "$hook_frag" '.hooks.Stop |= [.[] | if (.hooks | type) == "array" then (.hooks |= [.[] | if ((.command // "") | contains($frag)) and (has("timeout") | not) then . + {"timeout": 600} else . end]) else . end]' "$settings" > "$tmp" \
        && jq empty "$tmp" >/dev/null 2>&1; then
        mv "$tmp" "$settings"
        echo "[OK] Jeffy Stop hook registration upgraded with a 600s timeout in $settings"
      else
        rm -f "$tmp"
        echo "[FAILED] could not upgrade the Stop hook timeout in $settings; add \"timeout\": 600 to the hook entry by hand and re-run to verify."
        ok=0
      fi
    fi
  else
    tmp="$(mktemp)"
    if jq --arg cmd "$hook_cmd" '.hooks //= {} | .hooks.Stop //= [] | .hooks.Stop += [{"hooks": [{"type": "command", "command": $cmd, "timeout": 600}]}]' "$settings" > "$tmp" \
      && jq empty "$tmp" >/dev/null 2>&1; then
      mv "$tmp" "$settings"
      echo "[OK] Jeffy Stop hook registered in $settings (600s timeout)"
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
