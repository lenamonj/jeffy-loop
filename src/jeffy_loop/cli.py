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
import re
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
                print(f"[OK] removed {dest / rel} (not in this version)")
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
    # The command runs under a shell, so a $ in the home path is escaped.
    path = path.replace("$", "\\$")
    return f'bash "{path}"'


def is_jeffy_hook(hook):
    return isinstance(hook, dict) and HOOK_FRAGMENT in str(hook.get("command", ""))


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
        found.extend(hook for hook in inner if is_jeffy_hook(hook))
    return found


def registered_path(command):
    # The command is a shell string; the path is the token ending in the
    # fragment, quoted or bare, with ~ and $HOME expanded the way the shell
    # would. A quoted path may hold a space, so the quoted forms are tried first.
    frag = re.escape(HOOK_FRAGMENT)
    match = re.search("\"([^\"]*" + frag + ")\"|'([^']*" + frag + ")'|([^\"' ]*" + frag + ")", command)
    path = next(group for group in match.groups() if group)
    if os.name == "nt":
        # install.sh run from Git Bash writes the hook as /c/...; Windows reads C:/...
        path = re.sub(r"^/([A-Za-z])/", r"\1:/", path)
    # A "\$" in the command is a literal dollar in the path: expand variables in
    # the pieces around it, never in the joined result, or a home such as a$USER
    # reads back as another path and the registration as dead.
    pieces = os.path.expanduser(path).split("\\$")
    return Path("$".join(os.path.expandvars(piece) for piece in pieces))


def prune_dead_hooks(settings):
    """Remove every Jeffy registration whose hook path is no file.

    A settings.json carried in from another home names that home's hook, and
    "already registered" would then hold while the loop never fires.
    """
    removed = [
        h for h in matching_hooks(settings)
        if not registered_path(str(h.get("command", ""))).is_file()
    ]
    if not removed:
        return []
    settings["hooks"]["Stop"] = drop_hooks(settings["hooks"]["Stop"], removed)
    return [str(h.get("command", "")) for h in removed]


def drop_hooks(stop, removed):
    """Return the Stop entries with the given hook objects taken out.

    An entry whose hook list this empties is dropped; an entry that was not a
    hook group to begin with is kept as it was. Hooks are matched by identity,
    so an unrelated hook with the same command is never removed by accident.
    """
    kept_entries = []
    for entry in stop:
        if isinstance(entry, dict) and isinstance(entry.get("hooks"), list) and entry["hooks"]:
            entry["hooks"] = [h for h in entry["hooks"] if not any(h is r for r in removed)]
            if not entry["hooks"]:
                continue
        kept_entries.append(entry)
    return kept_entries


def write_settings(path, settings):
    """Replace settings.json atomically.

    install.sh writes this file as mktemp, then a validity gate, then mv, so a
    write that fails partway cannot truncate the user's whole Claude Code
    configuration. A direct write_text truncates in place, which is both a
    narrower guarantee than the sibling installer's and the reason an
    unwritable settings.json raised PermissionError where every other failure
    here prints [FAILED]. os.replace is atomic on POSIX and on Windows, and
    renaming into place needs write permission on the directory rather than on
    the file on POSIX, which is what lets a read-only settings.json be replaced
    as mv replaces it; Windows refuses the rename over a read-only file and the
    boundary in main reports that as [FAILED].
    """
    # A symlinked settings.json (stow, home-manager) is replaced at its target,
    # not turned into a regular file beside a dangling link; the existing mode
    # is carried over, because a rename takes the umask's mode and would open a
    # 0600 file holding API keys to 0644.
    if path.is_symlink():
        path = path.resolve()
    tmp = path.with_name(f"{path.name}.jeffy-{os.getpid()}.tmp")
    try:
        tmp.write_text(json.dumps(settings, indent=2) + "\n", encoding="utf-8")
        if path.exists():
            shutil.copymode(path, tmp)
        os.replace(tmp, path)
    except OSError as exc:
        with contextlib.suppress(OSError):
            tmp.unlink()
        if exc.filename and str(exc.filename) == str(tmp) and not getattr(exc, "filename2", None):
            # The temp file is an implementation detail; name the file the user knows.
            raise OSError(exc.errno, exc.strerror, str(path)) from exc
        raise


def has_settings(settings_path):
    return settings_path.is_file() and settings_path.stat().st_size > 0


def read_settings(settings_path, then):
    """Return settings.json as a dict, or None after printing why it cannot be used.

    `then` finishes the [FAILED] line: what the user re-runs once the file is fixed.
    """
    try:
        settings = json.loads(settings_path.read_text(encoding="utf-8"))
    except (ValueError, UnicodeDecodeError):
        settings = None
    if not isinstance(settings, dict):
        print(f"[FAILED] {settings_path} is not valid JSON; fix it, then {then}")
        return None
    return settings


def prune_and_report(settings_path, settings):
    removed = prune_dead_hooks(settings)
    if removed:
        write_settings(settings_path, settings)
        for command in removed:
            print(f"[OK] removed a Stop hook registration naming a hook that does not exist: {command}")


def upgrade_timeouts(settings_path, settings, found):
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


def add_registration(settings_path, settings):
    entry = {
        "hooks": [
            {"type": "command", "command": hook_command(), "timeout": HOOK_TIMEOUT}
        ]
    }
    hooks = settings.setdefault("hooks", {})
    stop = hooks.setdefault("Stop", []) if isinstance(hooks, dict) else None
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


def register_hook():
    settings_path = claude_home() / "settings.json"
    settings_path.parent.mkdir(parents=True, exist_ok=True)
    settings = {}
    if has_settings(settings_path):
        settings = read_settings(settings_path, "re-run this installer to register the hook.")
        if settings is None:
            return False

    prune_and_report(settings_path, settings)
    found = matching_hooks(settings)
    if found:
        return upgrade_timeouts(settings_path, settings, found)
    return add_registration(settings_path, settings)


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


def remove_skills():
    for name in SKILL_NAMES:
        dest = claude_home() / "skills" / name
        if dest.is_dir():
            shutil.rmtree(dest)
            print(f"[OK] removed {dest}")
        else:
            print(f"[OK] {dest} was not installed")


def strip_jeffy_hooks(stop):
    """Return (kept entries, number of Jeffy hooks removed) for a Stop list.

    An entry that held only Jeffy hooks is dropped; one that was already
    empty, or is not a hook group at all, is kept as it was.
    """
    removed = 0
    kept_entries = []
    for entry in stop:
        if not isinstance(entry, dict) or not isinstance(entry.get("hooks"), list):
            kept_entries.append(entry)
            continue
        kept_hooks = [hook for hook in entry["hooks"] if not is_jeffy_hook(hook)]
        removed += len(entry["hooks"]) - len(kept_hooks)
        if kept_hooks:
            entry["hooks"] = kept_hooks
            kept_entries.append(entry)
        elif not entry["hooks"]:
            kept_entries.append(entry)
    return kept_entries, removed


def cmd_uninstall():
    remove_skills()

    settings_path = claude_home() / "settings.json"
    if not has_settings(settings_path):
        print(f"[OK] no {settings_path} to clean")
        return 0
    settings = read_settings(settings_path, "re-run to remove the hook.")
    if settings is None:
        return 1

    hooks = settings.get("hooks")
    stop = hooks.get("Stop") if isinstance(hooks, dict) else None
    if not isinstance(stop, list):
        print(f"[OK] no Jeffy Stop hook in {settings_path}")
        return 0

    kept_entries, removed = strip_jeffy_hooks(stop)
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
    installed = claude_home() / "skills"
    if (installed / "jeffy" / "hooks" / "stop-hook.sh").is_file():
        running = engine_version(installed)
        if running != pkg:
            print(
                f"jeffy: the installed engine is {running}, not {pkg}; run jeffy install "
                "and start a new Claude Code session.",
                file=sys.stderr,
            )
            return 2
    return 0


def cmd_help():
    print("jeffy install    install both skills and register the Stop hook in settings.json")
    print("jeffy uninstall  remove both skills and the Jeffy Stop hook entry")
    print("jeffy version    print the package and engine versions; exit 2 when the installed engine differs")
    print("jeffy path       print the packaged skills directory")
    return 0


def main():
    """Run the command, turning a filesystem failure into the product's own message.

    One boundary rather than a guard at every site: the operating envelope asks
    for a single place where this class is handled, and an unhandled OSError
    anywhere below here used to reach the user as a traceback - on an
    unwritable settings.json, and on a read-only ~/.claude where the skill copy
    fails first.
    """
    try:
        return _run()
    except shutil.Error as exc:
        # copytree gathers its failures into a list of (src, dst, why) with no filename.
        source, _, why = exc.args[0][0]
        print(f"[FAILED] {source}: {why}; fix that, then re-run this installer.")
        return 1
    except OSError as exc:
        # os.replace reports the source in filename and the destination in
        # filename2, and the destination is the path the user recognises - the
        # first draft of this handler named the internal temp file instead.
        target = getattr(exc, "filename2", None) or getattr(exc, "filename", None) or "a file it needed"
        detail = exc.strerror or exc.__class__.__name__
        # stdout, beside every other [OK] and [FAILED] line this installer prints.
        print(f"[FAILED] {target}: {detail}; fix that, then re-run this installer.")
        return 1


def _run():
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
