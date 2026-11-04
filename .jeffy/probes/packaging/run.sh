#!/usr/bin/env bash
# Known-answer battery for the Python packaging surface: pyproject.toml and the
# hatch build backend hook. The wheel is what a user installs from PyPI, and
# the hook rewrites the README that becomes that release's long description -
# the text a user reads on the project page before deciding to install.
#
# hatch_build.py needs hatchling, which this host does not carry. Only the
# external base class is stubbed; ReadmeHook.update is the real shipped code,
# and the stub supplies nothing but the two attributes the base class would
# (self.root and self.config), so the regexes and the file read under test are
# the ones that run in a real build.
#
# Two roots, as the jeffy-loop-cli battery has. The files under test resolve
# from JEFFY_PROBE_ROOT, so a staged mutation needs only hatch_build.py and
# pyproject.toml beside it; the real README and the tracked-path listing come
# from the project root either way, because the invariant worth asserting is
# about the README this repository actually publishes.
set -u
pk_root="${JEFFY_PROBE_ROOT:-$PWD}"
pk_real="$PWD"
pk_hook="$pk_root/hatch_build.py"
pk_proj="$pk_root/pyproject.toml"
[ -f "$pk_hook" ] || { echo "packaging battery: no $pk_hook"; exit 2; }
[ -f "$pk_proj" ] || { echo "packaging battery: no $pk_proj"; exit 2; }

pk_py=""
for pk_c in python3 python; do
  pk_py="$(command -v "$pk_c" 2>/dev/null)" && [ -n "$pk_py" ] && break
  pk_py=""
done
[ -n "$pk_py" ] || { echo "packaging battery: NOT RUNNABLE: no python3 or python on PATH; install python3"; exit 2; }

pk_ok=0; pk_bad=0
ck() { # $1 label, $2 expected, $3 actual
  if [ "$2" = "$3" ]; then pk_ok=$((pk_ok + 1)); else
    pk_bad=$((pk_bad + 1)); echo "FAIL $1: expected [$2] got [$3]"
  fi
}
pk_tmp="$(mktemp -d)" || exit 2
trap 'rm -rf "$pk_tmp"' EXIT

# --- the declared paths exist ------------------------------------------------
# A manifest naming a path the tree does not carry builds an artifact missing
# the thing it promised, and hatchling does not fail the build over it.
#
# pk_count is set as a global rather than printed, and the call is never made
# in a command substitution. The first draft of this function printed its count
# and was called as $(...), so every ck() inside it ran in a subshell: six
# checks vanished from the tally and a FAIL line would have been captured into
# the variable instead of reaching the reader. The battery reported 13/13 while
# having asserted nineteen things, and only the expected count gave it away -
# which is the reason the count is asserted at all.
pk_count=0
pk_declared() { # $1 label, $2 extractor
  pk_count=0; pk_miss=0
  while IFS= read -r pk_p; do
    [ -n "$pk_p" ] || continue
    pk_count=$((pk_count + 1))
    [ -e "$pk_real/$pk_p" ] || { pk_miss=$((pk_miss + 1)); echo "  missing $1: $pk_p"; }
  done <<EOF
$(eval "$2")
EOF
  # The count is asserted beside the misses: an extractor that read nothing
  # reports zero missing, which is the shape of a passing check that looked at
  # nothing at all.
  ck "$1 extracted a non-empty list" 1 "$([ "$pk_count" -gt 0 ] && echo 1 || echo 0)"
  ck "$1 all present" 0 "$pk_miss"
}
pk_declared "wheel force-include source" "sed -n '/^\[tool.hatch.build.targets.wheel.force-include\]/,/^\[/p' '$pk_proj' | sed -n 's/^\"\{0,1\}\([^\"=]*\)\"\{0,1\}[[:space:]]*=.*/\1/p'"
ck "wheel force-include pair count" 2 "$pk_count"
pk_declared "sdist only-include path" "sed -n '/^only-include = \[/,/^\]/p' '$pk_proj' | sed -n 's/^  \"\([^\"]*\)\",*\$/\1/p'"
ck "sdist only-include path count" 6 "$pk_count"
pk_declared "wheel packages path" "sed -n 's/^packages = \[\"\([^\"]*\)\"\]\$/\1/p' '$pk_proj'"
ck "wheel packages path count" 1 "$pk_count"

# The metadata hook is declared and points at the file this battery drives.
ck "metadata hook path declared" 1 "$(grep -c '^path = "hatch_build.py"$' "$pk_proj")"
ck "metadata hook repo declared" 1 "$(grep -c '^repo = "[^"]*"$' "$pk_proj")"
# The console script a user types is the one the module defines.
pk_ep="$(sed -n 's/^jeffy = "\(.*\)"$/\1/p' "$pk_proj")"
ck "console script entry point" "jeffy_loop.cli:main" "$pk_ep"
ck "the entry point resolves to a callable" callable "$(
  cd "$pk_real/src" && PYTHONPATH="$pk_real/src" "$pk_py" - "$pk_ep" <<'PY'
import importlib, sys
mod, _, fn = sys.argv[1].partition(":")
print("callable" if callable(getattr(importlib.import_module(mod), fn, None)) else "not callable")
PY
)"
# The sdist has to carry whatever the build itself reads, or the release cannot
# be rebuilt from it: the metadata hook opens README.md at build time.
ck "sdist carries the file the metadata hook reads" 1 "$(sed -n '/^only-include = \[/,/^\]/p' "$pk_proj" | grep -c '"README.md"')"
ck "sdist carries the metadata hook itself" 1 "$(sed -n '/^only-include = \[/,/^\]/p' "$pk_proj" | grep -c '"hatch_build.py"')"
# The declared floor is a claim about what the shipped module may use.
ck "requires-python declared" 1 "$(grep -c '^requires-python = ">=3\.[0-9]*"$' "$pk_proj")"
ck "no runtime dependencies" 1 "$(grep -c '^dependencies = \[\]$' "$pk_proj")"
ck "readme is dynamic, so the hook is what produces it" 1 "$(grep -c '^dynamic = \["readme"\]$' "$pk_proj")"

# --- the README rewrite, by known answer --------------------------------------
cat > "$pk_tmp/drive.py" <<'PY'
import importlib.util, pathlib, re, subprocess, sys, tempfile, types

hook_path, root = sys.argv[1], sys.argv[2]

# Stub the external base class only. It contributes self.root and self.config
# and nothing else that update() touches.
iface = types.ModuleType("hatchling.metadata.plugin.interface")
class MetadataHookInterface:
    def __init__(self, root, config):
        self.root, self.config = root, config
iface.MetadataHookInterface = MetadataHookInterface
for name in ("hatchling", "hatchling.metadata", "hatchling.metadata.plugin"):
    sys.modules.setdefault(name, types.ModuleType(name))
sys.modules["hatchling.metadata.plugin.interface"] = iface

spec = importlib.util.spec_from_file_location("hb", hook_path)
hb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hb)

bad = 0
ran = 0
def ck(label, want, got):
    """Counts every arm as well as every failure. The whole python side reaches
    the shell tally as one check, so an arm that stops running - a loop whose
    body never executes, a call that raised before it - leaves the failure
    count at 0 and reads exactly like an arm that passed. The arm total is
    published beside it and asserted by the caller against a figure worked out
    by reading these call sites, never read off a green run: that is the rule
    this project already learned from a battery reporting 13/13 while having
    asserted nineteen things, and this battery had no such guard until the
    iteration that added the refusal arms needed one to prove they ran."""
    global bad, ran
    ran += 1
    if want != got:
        bad += 1
        print("FAIL %s: expected [%s] got [%s]" % (label, want, got))

def rewrite(text, repo="R"):
    d = tempfile.mkdtemp()
    pathlib.Path(d, "README.md").write_text(text, encoding="utf-8")
    meta = {}
    hb.ReadmeHook(d, {"repo": repo}).update(meta)
    return meta

def faults(text, repo="R"):
    """The refusal message, or "" when the hook published the text. The fix
    J10 landed makes the hook fail the build rather than ship a reference that
    resolves nowhere, so a carrier it cannot handle is observed here as a
    raised ValueError and never as a silently wrong output."""
    try:
        rewrite(text, repo)
    except ValueError as e:
        return str(e)
    return ""

RAW = "https://raw.githubusercontent.com/R/main/"
BLOB = "https://github.com/R/blob/main/"

# What the hook handles. Each shape is one reference carrier, and the answer is
# written out rather than computed, so a regex that drifts is caught by value.
for label, src, want in [
    ("relative src",           '<img src="media/a.png">',        '<img src="%smedia/a.png">' % RAW),
    ("relative srcset",        '<source srcset="media/a.png">',  '<source srcset="%smedia/a.png">' % RAW),
    ("relative md link",       '[u](docs/usage.md)',             '[u](%sdocs/usage.md)' % BLOB),
    ("relative md image",      '![a](media/a.png)',              '![a](%smedia/a.png)' % BLOB),
    ("http src untouched",     '<img src="http://x/y.png">',     '<img src="http://x/y.png">'),
    ("https src untouched",    '<img src="https://x/y.png">',    '<img src="https://x/y.png">'),
    ("https link untouched",   '[u](https://x/y)',               '[u](https://x/y)'),
    ("anchor untouched",       '[a](#sec)',                      '[a](#sec)'),
    ("mailto untouched",       '[m](mailto:a@b.c)',              '[m](mailto:a@b.c)'),
]:
    ck("rewrite " + label, want, rewrite(src)["readme"]["text"])

# The repo slug is a documented parameter and it is driven at two values that
# must change the output; a hook that ignored its config would pass one value.
one = rewrite('<img src="media/a.png">', "owner-one")["readme"]["text"]
two = rewrite('<img src="media/a.png">', "owner-two")["readme"]["text"]
ck("repo slug reaches the src rewrite", True, "owner-one" in one and "owner-two" in two)
ck("two repo slugs give two answers", True, one != two)
one = rewrite('[u](docs/usage.md)', "owner-one")["readme"]["text"]
two = rewrite('[u](docs/usage.md)', "owner-two")["readme"]["text"]
ck("repo slug reaches the link rewrite", True, "owner-one" in one and "owner-two" in two)
ck("two repo slugs give two link answers", True, one != two)

# The metadata contract, not just the text.
meta = rewrite('<img src="media/a.png">')
ck("content type", "text/markdown", meta["readme"]["content-type"])
ck("readme key set", True, set(meta) == {"readme"})

# --- the four carriers the rewrites cannot read ------------------------------
# These four were the enumerated class J10 filed, and each arm pinned the wrong
# output here until the fix landed - the coupling those arms promised, honoured
# in the iteration that closed it. The hook now verifies its own output through
# extractors wider than its rewrites and fails the build, so each shape is
# asserted as a refusal naming the reference that would have shipped, never as
# a corrected rewrite: the fix is one assertion rather than a regex per carrier,
# and what it buys is that a carrier nobody anticipated fails loudly too.
for label, src, needle in [
    ("srcset second candidate left relative",
     '<source srcset="media/a.png 1x, media/b.png 2x">', "srcset=media/b.png"),
    ("html anchor href untouched",
     '<a href="docs/usage.md">u</a>', "href=docs/usage.md"),
    ("titled md link untouched",
     '[u](docs/usage.md "Usage")', "link=docs/usage.md"),
    ("protocol-relative src gets the prefix glued on",
     '<img src="//cdn.x/y.png">', "src=%s//cdn.x/y.png" % RAW),
]:
    ck("refuses: " + label, True, needle in faults(src))

# --- the invariant over the real README --------------------------------------
# This is the property the hook exists to establish, and the one nothing in the
# tree asserts: no relative reference survives into the published description.
real = hb.ReadmeHook(root, {"repo": "lenamonj/jeffy-loop"})
meta = {}
real.update(meta)
out = meta["readme"]["text"]
source = pathlib.Path(root, "README.md").read_text(encoding="utf-8")
ck("the rewrite changed something", True, out != source)
# The other side of the refusal: the assertion the four arms above establish
# must not fire on the README this repository actually publishes, or the fix
# would have traded four broken references for a build that cannot run.
ck("the real README publishes no unresolved reference", "", faults(source))
ck("the rewrite is not empty", True, len(out) > 1000)

survivors = [u for u in re.findall(r'(?:src|srcset)="([^"]+)"', out)
             if not u.startswith(("http://", "https://"))]
ck("no relative src/srcset survives", [], survivors)
link_survivors = [u for u in re.findall(r'\]\(([^)\s]+)\)', out)
                  if not u.startswith(("http://", "https://", "#", "mailto:"))]
ck("no relative md link survives", [], link_survivors)

# Every rewritten target has to name a path a clone really carries, or the
# published page links into nothing. Tracked, not merely present on disk.
tracked = set(subprocess.run(["git", "-C", root, "ls-files"],
                             capture_output=True, text=True).stdout.split())
ck("git ls-files returned a tree", True, len(tracked) > 10)
RAW_R = "https://raw.githubusercontent.com/lenamonj/jeffy-loop/main/"
BLOB_R = "https://github.com/lenamonj/jeffy-loop/blob/main/"
missing = []
n_src = n_link = 0
for u in re.findall(r'(?:src|srcset)="([^"]+)"', out):
    if u.startswith(RAW_R):
        n_src += 1
        if u[len(RAW_R):] not in tracked:
            missing.append(("src", u[len(RAW_R):]))
for u in re.findall(r'\]\(([^)\s]+)\)', out):
    if u.startswith(BLOB_R):
        n_link += 1
        p = u[len(BLOB_R):].split("#")[0]
        if p and p not in tracked:
            missing.append(("link", p))
# Counted as well as checked: zero rewritten references would make the
# missing list empty for the wrong reason.
ck("rewritten src references found", True, n_src > 0)
ck("rewritten link references found", True, n_link > 0)
ck("every rewritten reference is a tracked path", [], missing)

print("packaging known-answer arms: %d" % ran)
print("packaging known-answer failures: %d" % bad)
PY
pk_out="$("$pk_py" "$pk_tmp/drive.py" "$pk_hook" "$pk_real" 2>&1)"
ck "README rewrite known answers" "packaging known-answer failures: 0" "$(printf '%s\n' "$pk_out" | tail -n 1)"
ck "README rewrite arm count" "packaging known-answer arms: 28" "$(printf '%s\n' "$pk_out" | grep '^packaging known-answer arms: ')"
printf '%s\n' "$pk_out" | grep '^FAIL ' || true

if [ "$pk_bad" -eq 0 ]; then
  echo "packaging battery: $pk_ok/$pk_ok checks passed"
  exit 0
fi
echo "packaging battery: $pk_bad of $((pk_ok + pk_bad)) checks failed"
exit 1
