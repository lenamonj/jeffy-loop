"""Console entry point for the Jeffy Loop.

The engine is a Claude Code skill plus a Stop hook, both shipped inside this
package under jeffy_loop/skills. This module is the Python-native equivalent of
install.sh and install.ps1: it checks the prerequisites, copies the two skill
folders into the user's Claude Code skills directory, and registers the Stop
hook in settings.json with the same idempotence and timeout rules.
"""

import contextlib
import json
import os
import shutil
import stat
import sys
from importlib import metadata, resources
from pathlib import Path

DISTRIBUTION = "jeffy-loop"
SKILL_NAMES = ("jeffy", "cancel-jeffy")
HOOK_FRAGMENT = "skills/jeffy/hooks/stop-hook.sh"
HOOK_TIMEOUT = 1800


def package_version():
    try:
        return metadata.version(DISTRIBUTION)
    except metadata.PackageNotFoundError:
        from jeffy_loop import __version__

        return __version__


def engine_version(skills_root):
    hook = skills_root / "jeffy" / "hooks" / "stop-hook.sh"
    if not hook.is_file():
        raise SystemExit(f"jeffy: packaged Stop hook not found at {hook}")
    for line in hook.read_text(encoding="utf-8").splitlines():
        if line.startswith("JEFFY_VERSION="):
            return line.split("=", 1)[1].strip().strip('"')
    raise SystemExit(f"jeffy: no JEFFY_VERSION line in {hook}")


def claude_home():
    return Path.home() / ".claude"


def which(name):
    return shutil.which(name) is not None


def check_prerequisites():
    ok = True
    if which("claude"):
        print("[OK] Claude Code CLI found")
    else:
        print("[MISSING] Claude Code CLI. Install it first: https://claude.com/claude-code")
        ok = False
    if which("jq"):
        print("[OK] jq found")
    elif os.name == "nt":
        print(
            "[MISSING] jq. Install it manually: winget install jqlang.jq "
            "(or see https://jqlang.github.io/jq/download/)"
        )
        ok = False
    else:
        print(
            "[MISSING] jq. Install it with your package manager "
            "(brew install jq / sudo apt install jq)"
        )
        ok = False
    return ok


def relative_files(root):
    return sorted(
        p.relative_to(root) for p in root.rglob("*") if p.is_file()
    )


def install_skills(skills_root):
    for name in SKILL_NAMES:
        src = skills_root / name
        if not (src / "SKILL.md").is_file():
            raise SystemExit(f"jeffy: packaged skills/{name}/SKILL.md not found at {src}")
        dest = claude_home() / "skills" / name
        dest.mkdir(parents=True, exist_ok=True)
        shutil.copytree(src, dest, dirs_exist_ok=True)
        # A copy over the top never removes. Files the shipped tree no longer
        # carries are removed, and nothing else.
        for rel in relative_files(dest):
            if not (src / rel).exists():
                (dest / rel).unlink()
                print(f"[OK] removed {dest / rel} (no longer shipped)")
        print(f"[OK] /{name} skill installed to {dest}")


def make_hook_executable():
    if os.name == "nt":
        return
    hook = claude_home() / "skills" / "jeffy" / "hooks" / "stop-hook.sh"
    if hook.is_file():
        mode = hook.stat().st_mode
        hook.chmod(mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def hook_command():
    hook = claude_home() / "skills" / "jeffy" / "hooks" / "stop-hook.sh"
    path = str(hook)
    if os.name == "nt":
        # The command runs under bash (Git Bash on Windows), as install.ps1 writes it.
        path = path.replace("\\", "/")
    return f'bash "{path}"'


def matching_hooks(settings):
    hooks = settings.get("hooks")
    if not isinstance(hooks, dict):
        return []
    stop = hooks.get("Stop")
    if not isinstance(stop, list):
        return []
    found = []
    for entry in stop:
        if not isinstance(entry, dict):
            continue
        inner = entry.get("hooks")
        if not isinstance(inner, list):
            continue
        for hook in inner:
            if isinstance(hook, dict) and HOOK_FRAGMENT in str(hook.get("command", "")):
                found.append(hook)
    return found


def write_settings(path, settings):
    path.write_text(json.dumps(settings, indent=2) + "\n", encoding="utf-8")


def register_hook():
    settings_path = claude_home() / "settings.json"
    settings_path.parent.mkdir(parents=True, exist_ok=True)
    if settings_path.is_file() and settings_path.stat().st_size > 0:
        try:
            settings = json.loads(settings_path.read_text(encoding="utf-8"))
        except (ValueError, UnicodeDecodeError):
            print(
                f"[FAILED] {settings_path} is not valid JSON; fix it, then "
                "re-run this installer to register the hook."
            )
            return False
        if not isinstance(settings, dict):
            print(
                f"[FAILED] {settings_path} is not valid JSON; fix it, then "
                "re-run this installer to register the hook."
            )
            return False
    else:
        settings = {}

    found = matching_hooks(settings)
    if found:
        # A pre-1.2 registration lacks the timeout field and a 1.2-1.14
        # registration carries 600s, which the verify bound can exceed (P1-58).
        # Either shape moves to 1800s exactly once.
        stale = [h for h in found if "timeout" not in h or h["timeout"] == 600]
        if not stale:
            print(f"[OK] Jeffy Stop hook already registered in {settings_path}")
            return True
        for hook in stale:
            hook["timeout"] = HOOK_TIMEOUT
        write_settings(settings_path, settings)
        print(
            f"[OK] Jeffy Stop hook registration upgraded to an 1800s timeout in {settings_path}"
        )
        return True

    entry = {
        "hooks": [
            {"type": "command", "command": hook_command(), "timeout": HOOK_TIMEOUT}
        ]
    }
    hooks = settings.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        print(
            f"[FAILED] could not update {settings_path}; add the Stop hook entry "
            "by hand (see README) and re-run to verify."
        )
        return False
    stop = hooks.setdefault("Stop", [])
    if not isinstance(stop, list):
        print(
            f"[FAILED] could not update {settings_path}; add the Stop hook entry "
            "by hand (see README) and re-run to verify."
        )
        return False
    stop.append(entry)
    write_settings(settings_path, settings)
    print(f"[OK] Jeffy Stop hook registered in {settings_path} (1800s timeout)")
    return True


def cmd_install(skills_root):
    print("Jeffy installer")
    print("")
    ok = check_prerequisites()
    install_skills(skills_root)
    make_hook_executable()
    if not register_hook():
        ok = False
    print("")
    if ok:
        print("Done. Start a new Claude Code session in any project and run: /jeffy")
        return 0
    print("Skills installed, but fix the items above, then re-run this installer to verify.")
    return 1


def cmd_uninstall():
    for name in SKILL_NAMES:
        dest = claude_home() / "skills" / name
        if dest.is_dir():
            shutil.rmtree(dest)
            print(f"[OK] removed {dest}")
        else:
            print(f"[OK] {dest} was not installed")

    settings_path = claude_home() / "settings.json"
    if not (settings_path.is_file() and settings_path.stat().st_size > 0):
        print(f"[OK] no {settings_path} to clean")
        return 0
    try:
        settings = json.loads(settings_path.read_text(encoding="utf-8"))
    except (ValueError, UnicodeDecodeError):
        print(
            f"[FAILED] {settings_path} is not valid JSON; fix it, then re-run "
            "to remove the hook."
        )
        return 1
    if not isinstance(settings, dict):
        print(
            f"[FAILED] {settings_path} is not valid JSON; fix it, then re-run "
            "to remove the hook."
        )
        return 1

    hooks = settings.get("hooks")
    stop = hooks.get("Stop") if isinstance(hooks, dict) else None
    if not isinstance(stop, list):
        print(f"[OK] no Jeffy Stop hook in {settings_path}")
        return 0

    removed = 0
    kept_entries = []
    for entry in stop:
        if not isinstance(entry, dict) or not isinstance(entry.get("hooks"), list):
            kept_entries.append(entry)
            continue
        kept_hooks = []
        for hook in entry["hooks"]:
            if isinstance(hook, dict) and HOOK_FRAGMENT in str(hook.get("command", "")):
                removed += 1
            else:
                kept_hooks.append(hook)
        if kept_hooks:
            entry["hooks"] = kept_hooks
            kept_entries.append(entry)
        elif not entry["hooks"]:
            kept_entries.append(entry)
    if removed == 0:
        print(f"[OK] no Jeffy Stop hook in {settings_path}")
        return 0
    if kept_entries:
        hooks["Stop"] = kept_entries
    else:
        del hooks["Stop"]
    write_settings(settings_path, settings)
    print(f"[OK] removed the Jeffy Stop hook from {settings_path}")
    return 0


def cmd_version(skills_root):
    pkg = package_version()
    engine = engine_version(skills_root)
    print(f"jeffy-loop {pkg} (engine JEFFY_VERSION {engine} from the packaged stop-hook.sh)")
    if pkg != engine:
        print(
            f"jeffy: version mismatch. The package says {pkg} and the packaged "
            f"stop-hook.sh says {engine}. The package was built without the "
            "release bump; bump JEFFY_VERSION in skills/jeffy/hooks/stop-hook.sh "
            "or the version in pyproject.toml so they agree, then rebuild.",
            file=sys.stderr,
        )
        return 2
    return 0


def cmd_help():
    print("jeffy install    install both skills and register the Stop hook in settings.json")
    print("jeffy uninstall  remove both skills and the Jeffy Stop hook entry")
    print("jeffy version    print the package version and the packaged engine version")
    print("jeffy path       print the packaged skills directory")
    return 0


def main():
    args = sys.argv[1:]
    cmd = args[0] if args else "help"

    if cmd in ("help", "--help", "-h"):
        return cmd_help()
    if cmd == "uninstall":
        return cmd_uninstall()
    if cmd not in ("install", "version", "--version", "path"):
        print(f"jeffy: unknown command: {cmd}", file=sys.stderr)
        cmd_help()
        return 2

    with contextlib.ExitStack() as stack:
        root = stack.enter_context(resources.as_file(resources.files("jeffy_loop")))
        skills_root = Path(root) / "skills"
        if not skills_root.is_dir():
            raise SystemExit(f"jeffy: packaged skills directory not found at {skills_root}")
        if cmd == "path":
            print(skills_root)
            return 0
        if cmd in ("version", "--version"):
            return cmd_version(skills_root)
        return cmd_install(skills_root)


if __name__ == "__main__":
    sys.exit(main())
