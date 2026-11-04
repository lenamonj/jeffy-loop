#!/usr/bin/env python3
"""Replace a literal byte string in a binary file and fail loudly if absent.

mutate.py reads its target as UTF-8, which a PDF is not, so the mutations that
have to reach the published binaries use this instead. Exits non-zero when the
target was not there or the occurrence count disagrees, so a mutation that
silently failed to land cannot be read as the battery passing.
"""
import sys

path, old, new = sys.argv[1], sys.argv[2].encode("latin-1"), sys.argv[3].encode("latin-1")
want = int(sys.argv[4]) if len(sys.argv) > 4 else 0
with open(path, "rb") as fh:
    data = fh.read()
n = data.count(old)
if n == 0:
    sys.exit("bmutate.py: %r is not in %s; the mutation would not have landed" % (old, path))
if want and n != want:
    sys.exit("bmutate.py: expected %d occurrences of %r in %s, found %d" % (want, old, path, n))
if len(new) != len(old):
    # A PDF's xref table holds byte offsets, so a length change moves every
    # object after the edit and the reader would be faulting on the offsets
    # rather than on the value under test.
    sys.exit("bmutate.py: replacement must be the same length as the target (%d vs %d)" % (len(new), len(old)))
with open(path, "wb") as fh:
    fh.write(data.replace(old, new))
print("bmutate.py: replaced %d occurrence(s)" % n)
