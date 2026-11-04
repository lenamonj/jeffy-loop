# jeffy-loop-cli

Known-answer battery for `src/jeffy_loop`, the pip-installable face of the
engine. The module's own docstring calls itself "the Python-native equivalent
of install.sh and install.ps1", which is the reason this battery exists: the
same contract is implemented twice in two languages, and the two can drift
without either one breaking.

The package is staged the way the wheel builds it rather than the way a reader
would guess. `src/jeffy_loop/*.py` is copied, and the skills payload is placed
using the `[tool.hatch.build.targets.wheel.force-include]` map read out of
`pyproject.toml`; the number of pairs that staging produced is itself asserted,
because a staging that read an empty map would install no skills and every arm
below would then pass over a packaging change.

Two roots, on purpose. The module under test resolves from `JEFFY_PROBE_ROOT`,
so a mutated `cli.py` can be staged alone with no copy of the skills payload
beside it; the payload and `pyproject.toml` are read from the project root
either way.

## What it drives

Every documented command, at values required to change the answer rather than
once each: `help`, `--help`, `-h` and an empty argv all produce the same four
usage lines; an unknown command names itself on stderr, still prints the usage,
and exits 2; `path` prints the staged skills directory; `install`, `uninstall`
and `version` are driven below.

The parameters that decide a branch are each driven on both sides:

- The registered hook's `timeout` field, at absent, 600 and 1800. The first two
  are upgraded to 1800 and say so; the third is left alone and reports
  "already registered". Each upgrade is then re-run to confirm it happens once.
- The home path, at a plain path, a path holding `$`, and a path holding a
  space. The installer escapes the dollar so a shell reads the real path, and
  its own prune has to read that escape back - a second install on such a home
  either reports its own work live or deletes it as dead.
- The installed engine version against the package version, equal and unequal,
  and the packaged engine version against `__version__`, equal and unequal.
  Both inequalities exit 2 with a message naming the two versions.
- Prerequisite presence on PATH. With neither `claude` nor `jq` reachable the
  installer still installs and still registers, and exits 1 - which is what
  `install.sh` does with `ok=0`, and the half most likely to drift.
- The state of `settings.json`: absent, valid, invalid JSON, read-only,
  and a symlink. The read-only file is replaced as `mv` replaces it and keeps
  its mode, because a bare rename would take the umask's and open a 0600 file
  holding API keys to 0644; the symlink is written through rather than replaced
  by a regular file beside a dangling link.

Three properties are asserted from `settings.json` itself rather than from the
installer's printed line, since the message is what the installer claims and
the file is what Claude Code will read: the live registration count, the
timeout value, and that an unrelated Stop hook, an unrelated hook event and an
unrelated top-level key all survive an install, a prune and an uninstall.

The computed half is checked by known answer rather than by running the
installer. `hook_command` writes a path a shell will read and `registered_path`
reads it back; the pair decides whether the installer calls its own work dead,
so each shape it can meet is asserted against the answer - quoted,
single-quoted, bare, holding a space, leading `~`, carrying an escaped dollar,
and followed by a trailing argument - and the round trip is driven over a home
holding a dollar, a space, a backslash and a trailing dollar.

## What it was observed failing on

Recorded at creation, because an instrument never seen to fail reads exactly
like one that passed. Each mutation is one of the v1.26.12..349934b additions
this run was pointed at, each was confirmed to compile with `py_compile` and to
differ from the shipped file before its result counted, and each is replayed by
a line in `claims`.

- Dropping `path.replace("$", "\\$")` from `hook_command` leaves the dollar
  unescaped: the registration no longer carries the escape, the second install
  on such a home fails to recognise its own work, and the round trip returns
  the path with `$USER` expanded by the shell.
- Restoring the pre-1.27.0 one-line read-back in `registered_path` expands the
  variable in the joined result instead of in the pieces around the escape, so
  an escaped dollar comes back as a different path and the installer reads its
  own live registration as dead.
- Deleting the installed-engine comparison from `cmd_version` makes a stale
  installed engine exit 0, so `jeffy version` reports health on the exact
  configuration the message exists to warn about.
- Replacing the stale-file `unlink` with `pass` leaves a file the shipped tree
  no longer carries installed, which is the 1.11.0 `enhance-plan-default.md`
  failure this sync was added for.
- Deleting the `except shutil.Error` arm of the boundary degrades the message
  on a copy failure. See below - this one does not fail the arm a reader would
  expect.

## What it cannot discriminate, and why

Deleting the `shutil.Error` handler does **not** produce a traceback, and the
no-traceback arms stay green under it. `shutil.Error` subclasses `OSError`, so
the generic arm beneath it still catches the failure and the exit status is
still 1. What is lost is the message: `copytree` gathers its failures into a
list of `(src, dst, why)` tuples and sets no `filename`, so the generic arm
falls through to its own placeholder and prints `[FAILED] a file it needed:
Error`, naming nothing the user can act on. The arm that falls is therefore the
one asserting the failure line names the source it could not copy, and that is
the right arm rather than a weaker substitute.

The differential against `install.sh` is deliberately not an arm here, and
that is a scoping decision rather than an oversight. Running both installers
over one tree into two sandbox homes is the sharpest test of this row's premise
that the two implementations can drift, and it was run by hand in the sweep
that created this battery - identical file trees with identical modes,
identical `settings.json`, identical stale-file message. Making it an arm would
put `install.sh` into this battery's `paths`, so every edit to the shell
installer would mark the console script's row stale; `install.sh` has its own
row, and the differential belongs to whichever sweep touches both.

Three further limits are stated rather than papered over. The `os.name == "nt"`
branches of `hook_command` and `registered_path` - the backslash-to-forward-slash
rewrite and the `/c/` to `C:/` rewrite - are not reached on this host, and no
arm claims them; `install.ps1` is the Windows installer and it has its own row.
And the `metadata.version` branch of `package_version` is not exercised, since
the staged package is run from `PYTHONPATH` and is never pip-installed, so the
`PackageNotFoundError` fallback to `__version__` is the path every arm takes.
