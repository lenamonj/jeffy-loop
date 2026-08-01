"""F1: set_key(quote_mode="never") silently writes values the parser reads back
as something else, and reports success while doing it.

This measures the class rather than demonstrating one instance of it. The same
seeded corpus of 4,000 values is written through set_key in each of the three
quote modes and read back with dotenv_values; a value that does not survive the
round trip is a silent corruption, because set_key returned (True, key, value).

Run it against a clean checkout of upstream at the base commit, and again against
a tree carrying the fix:

    git clone https://github.com/theskumar/python-dotenv
    git -C python-dotenv checkout 751f8c14
    python3 repro.py python-dotenv

Measured on CPython 3.14 at base 751f8c14:

    quote_mode     round-trip failures   reported success anyway
    never                          927                       927
    always                           1                         1
    auto                             1                         1

and on the converged tree, where an unrepresentable value raises ValueError
instead of being written, all three modes report 0.

Use an interpreter with no python-dotenv installed. An editable install shadows
the path insert below and silently measures the wrong tree, which returns a clean
and completely meaningless zero; the assertion after the import refuses that.
"""

import random
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SEED = 20260801
N_VALUES = 4000

# Weighted toward the characters a .env line cannot carry unquoted: the comment
# introducer, quotes, whitespace at the edges, and the newline that makes this an
# injection primitive rather than only a corruption.
ALPHABET = (
    "abcdefghijklmnopqrstuvwxyz"
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "0123456789"
    "_-./:@+"
    "   "
    "##"
    "''"
    '""'
    "\n\n"
    "\t"
    "=$\\{}"
    "é中"
)


def make_corpus(n, seed):
    rng = random.Random(seed)
    return ["".join(rng.choice(ALPHABET) for _ in range(rng.randint(0, 12)))
            for _ in range(n)]


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)

    checkout = Path(sys.argv[1]).resolve()
    sys.path.insert(0, str(checkout / "src"))
    import dotenv
    from dotenv import dotenv_values, set_key

    loaded = Path(dotenv.__file__).resolve()
    if checkout not in loaded.parents:
        sys.exit(f"ABORT: imported dotenv from {loaded}, not from {checkout}.\n"
                 f"Use an interpreter with no python-dotenv installed.")

    rev = subprocess.run(["git", "-C", str(checkout), "rev-parse", "--short", "HEAD"],
                         capture_output=True, text=True).stdout.strip()
    print(f"dotenv package from : {loaded}")
    print(f"commit under test   : {rev or '(unknown)'}")
    print(f"corpus              : {N_VALUES} values, seed {SEED}")
    print()

    corpus = make_corpus(N_VALUES, SEED)
    modes = ["never", "always", "auto"]
    results, examples = {}, {m: [] for m in modes}

    tmpdir = Path(tempfile.mkdtemp(prefix="dotenv-f1-"))
    try:
        for mode in modes:
            failures = silent = 0
            for i, value in enumerate(corpus):
                path = tmpdir / f"{mode}_{i}.env"
                path.write_text("", encoding="utf-8")
                try:
                    ok, _, _ = set_key(str(path), "K", value, quote_mode=mode)
                except ValueError:
                    # The fix refuses instead of writing. A refusal is loud, so
                    # it is not a corruption and is not counted as one.
                    path.unlink()
                    continue
                if dotenv_values(str(path)).get("K") != value:
                    failures += 1
                    silent += bool(ok)
                    if len(examples[mode]) < 3:
                        examples[mode].append((value, dotenv_values(str(path)).get("K")))
                path.unlink()
            results[mode] = (failures, silent)
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)

    print(f"{'quote_mode':<12}{'round-trip failures':>22}{'reported success anyway':>26}")
    print("-" * 60)
    for mode in modes:
        failures, silent = results[mode]
        print(f"{mode:<12}{failures:>22}{silent:>26}")
    print()
    print(f"never = {results['never'][0]}   "
          f"always + auto = {results['always'][0] + results['auto'][0]}")
    print()
    for mode in modes:
        if examples[mode]:
            print(f"{mode} examples (written -> read back):")
            for sent, got in examples[mode]:
                print(f"   {sent!r} -> {got!r}")


if __name__ == "__main__":
    main()
