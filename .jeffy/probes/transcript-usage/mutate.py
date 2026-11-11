#!/usr/bin/env python3
"""Replace a literal substring in a file and fail loudly if it was not there.

Used instead of sed or awk for the two mutations whose target carries shell
quoting a recorded command loses in transit - the hook's own `sed -n "s/^$1:
//p"` reader being the sharp one. Exits non-zero when nothing matched, so a
mutation that silently failed to land cannot be read as the battery passing.
"""
import sys

path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
want = int(sys.argv[4]) if len(sys.argv) > 4 else 0
with open(path, encoding="utf-8") as fh:
    text = fh.read()
n = text.count(old)
if n == 0:
    sys.exit("mutate.py: %r is not in %s; the mutation would not have landed" % (old, path))
if want and n != want:
    sys.exit("mutate.py: expected %d occurrences of %r in %s, found %d" % (want, old, path, n))
with open(path, "w", encoding="utf-8", newline="\n") as fh:
    fh.write(text.replace(old, new))
print("mutate.py: replaced %d occurrence(s)" % n)
