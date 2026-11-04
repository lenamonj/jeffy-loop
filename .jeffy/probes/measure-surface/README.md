# measure-surface

Known-answer battery for `skills/jeffy/hooks/lib/measure-surface.sh`, the
surface measure the launcher's pre-flight runs and refuses above.

It builds one throwaway git tree whose counted total is known by construction
rather than read off a run: five files with a source extension hold 10, 5, 7, 4
and 6 lines, so the answer is `lines=32 files=5`, and four more paths are there
to be excluded - a markdown file by extension, a file under `vendor/` by
directory, a symlink, and a gitlink recorded at mode 160000 with no submodule
behind it. `vendored_api.go` is counted on purpose, because the skip pattern is
anchored at a path segment and a file merely named like a vendored tree is the
project's own. Two of the paths are shaped to break naive plumbing: one carries
a space, and one begins with a hyphen.

Every documented parameter is driven at more than one value, each value
required to change the answer: `--ceiling` below the measurement exits 3 and
the refusal names the line total it measured and the headroom ceiling it
suggests, at
the measurement exactly exits 0 because the comparison is strictly greater,
and at 0 exits 0 with the check off. Each documented exit code is driven from
the shape that produces it - 0 measured, 2 outside a git work tree, 3 over the
ceiling, 64 for a non-numeric ceiling, an absurd one, a ceiling with no value,
an unknown argument and a missing root.

## What it was observed failing on

Recorded at creation, because an instrument never seen to fail reads exactly
like one that passed.

- The v1.26.12 copy of the file, staged aside and pointed at with
  `JEFFY_PROBE_ROOT`, fails on the measurement and on both ceiling arms. The
  cause is the hyphen-led path: that release handed the list to `wc -l` with no
  `--`, so `wc` read `-dash.py` as flags, refused the whole invocation, and the
  measurement collapsed to `lines=0 files=0`. A surface measure that answers
  zero passes every ceiling, which is the direction that cannot be allowed to
  fail quietly.
- Removing the `--` from the shipped copy reproduces exactly that collapse.
- Removing both the `^(120000|160000)` mode filter and the `-L` test together
  counts the symlink, and the measurement moves to `lines=42 files=6`.

## What it cannot discriminate, and why

Removing either the mode filter or the `-L` test alone leaves the battery
green, and that is a fact about this platform rather than a gap to be patched.
Git on Linux records a symlink at mode 120000, so each guard excludes it
without help from the other; the `-L` test exists for Git for Windows, which
records an MSYS link as a plain file the mode filter cannot see. Driving the
two apart needs a Windows host.

The 160000 half is not discriminable through the output at all. A gitlink
reaches `wc` as a path that is absent or a directory, `wc` complains on stderr
where the script discards it, and the counts of every other path still print,
so including it changes no published figure. It is there to keep the error out
of the stream, and this battery asserts the figure rather than the stream.
