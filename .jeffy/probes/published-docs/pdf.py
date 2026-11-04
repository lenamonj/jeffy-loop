#!/usr/bin/env python3
"""Read a published PDF with the standard library alone and print what a
structural claim about it can rest on.

No pypdf, no pdftotext: PLAN.md's Environment fingerprint records that this
host carries neither, and S4 established that the content streams are reachable
without them. The two documents here need different routes - the white paper's
streams are FlateDecode, the STE100 description's are ASCII85 then Flate, which
is ReportLab's default - so both filters are tried in order and a stream that
answers to neither is skipped rather than failing the read, because font and
image streams legitimately answer to neither.

Usage: pdf.py <file>          key=value summary, one per line
       pdf.py <file> --text   the extracted text, one line
"""
import base64
import re
import sys
import zlib


def streams(data):
    for m in re.finditer(rb"stream\r?\n", data):
        s = m.end()
        e = data.find(b"endstream", s)
        if e < 0:
            continue
        yield data[s:e]


def decode(raw):
    for attempt in (lambda b: zlib.decompress(b),
                    lambda b: zlib.decompress(base64.a85decode(b.strip(), adobe=True)),
                    lambda b: base64.a85decode(b.strip(), adobe=True)):
        try:
            return attempt(raw)
        except Exception:
            continue
    return None


def text_of(data):
    # A font or image stream decodes as happily as a content stream and its
    # bytes are full of parenthesised runs, so the decoded set is narrowed to
    # streams carrying a text-showing operator. Without that narrowing the
    # extraction grows by a third in garbage and a word straddling two real
    # chunks stops being findable.
    out = []
    total = decoded = 0
    for raw in streams(data):
        total += 1
        d = decode(raw)
        if d is None or (b"Tj" not in d and b"TJ" not in d):
            continue
        decoded += 1
        out.append(d.decode("latin-1"))
    blob = "\n".join(out)
    chunks = re.findall(r"\((?:\\.|[^\\()])*\)", blob)
    # Joined with nothing: the generator splits a word across show operators,
    # so any separator inserted here invents a boundary the page does not have.
    plain = "".join(c[1:-1] for c in chunks).replace("\\(", "(").replace("\\)", ")")
    return plain, total, decoded


def main():
    path = sys.argv[1]
    data = open(path, "rb").read()
    plain, total, decoded = text_of(data)
    if len(sys.argv) > 2 and sys.argv[2] == "--text":
        sys.stdout.write(plain.replace("\n", " "))
        return
    if len(sys.argv) > 2 and sys.argv[2] == "--refs":
        # The reference list, read from the last occurrence of its own heading
        # rather than the first - the first is the table of contents entry. The
        # entry marker carries the generator's language tag, which is what
        # makes it a marker at all: a bare "N." also matches a sentence ending
        # in a numeral.
        hits = [m.start() for m in re.finditer(r"References", plain)]
        if len(hits) < 2:
            print("sections=%d" % len(hits))
            print("n=0")
            print("contiguous=0")
            print("nolink=")
            return
        tail = plain[hits[-1]:]
        ents = re.findall(r"en-US(\d{1,3})\.en-US", tail)
        blocks = re.split(r"en-US\d{1,3}\.en-US", tail)[1:]
        print("sections=%d" % len(hits))
        print("n=%d" % len(ents))
        print("contiguous=%d" % (1 if ents == [str(i) for i in range(1, len(ents) + 1)] else 0))
        print("nolink=%s" % ",".join(str(i + 1) for i, blk in enumerate(blocks) if "http" not in blk))
        return
    counts = [int(c) for c in re.findall(rb"/Count\s+(\d+)", data)]
    print("header=%d" % (1 if data.startswith(b"%PDF-") else 0))
    print("eof=%d" % (1 if data.rstrip().endswith(b"%%EOF") else 0))
    print("counts=%s" % ",".join(str(c) for c in counts))
    print("typepage=%d" % len(re.findall(rb"/Type\s*/Page[^s]", data)))
    print("contents=%d" % len(re.findall(rb"/Contents", data)))
    print("streams=%d" % total)
    print("decoded=%d" % decoded)
    print("textlen=%d" % len(plain))


main()
