"""Rewrite the README for PyPI at build time.

PyPI renders the project description from README.md but cannot resolve
relative paths, so images under assets/ and links to files in the repository
render broken there. This hook turns every relative src, srcset and markdown
link into an absolute GitHub URL in the built metadata only; the README in the
repository stays relative, which is what GitHub wants.

The two rewrites below each read one carrier shape, and a carrier they do not
read used to ship relative: an srcset's second candidate, an html href, a
markdown link carrying a title, and a protocol-relative URL that already was
absolute and got a prefix glued onto it. Nothing failed on the way out -
hatchling does not validate this hook's output - so the first sign was a
broken image or a dead link on the project page a user reads before deciding
to install. The remedy is one assertion rather than a regex per carrier: the
hook verifies its own output through extractors deliberately wider than its
rewrites and fails the build on anything that would resolve nowhere. (J10)
"""
import os
import re

from hatchling.metadata.plugin.interface import MetadataHookInterface

# Wider than the rewrites on purpose, which is the whole point: a carrier a
# rewrite cannot handle is exactly what has to be visible here. srcset is read
# candidate by candidate, because the rewrite prefixes the attribute value
# whole; a markdown target is read to the closing paren rather than to the
# first space, so a link carrying a title is seen too.
_ATTR = re.compile(r'(?:src|href)="([^"]*)"')
_SRCSET = re.compile(r'srcset="([^"]*)"')
_MDLINK = re.compile(r'\]\(([^)]+)\)')
_ABSOLUTE = ("http://", "https://")
_INERT = ("#", "mailto:")


def _references(text):
    """Every reference the published description has to resolve, as
    (carrier, target) pairs."""
    for m in _ATTR.finditer(text):
        yield m.group(0).split("=", 1)[0], m.group(1).strip()
    for m in _SRCSET.finditer(text):
        for candidate in m.group(1).split(","):
            token = candidate.split()
            if token:
                yield "srcset", token[0]
    for m in _MDLINK.finditer(text):
        token = m.group(1).split()
        if token:
            yield "link", token[0]


def _unresolved(text, prefixes):
    """References that would ship unresolved: still relative, or absolute only
    because a prefix was glued onto a target that was already absolute - a
    protocol-relative //host/path leaves a doubled slash behind."""
    bad = []
    for carrier, target in _references(text):
        if target.startswith(_INERT):
            continue
        if not target.startswith(_ABSOLUTE):
            bad.append(f"{carrier}={target}")
        elif any(target.startswith(p) and target[len(p):].startswith("/") for p in prefixes):
            bad.append(f"{carrier}={target}")
    return bad


class ReadmeHook(MetadataHookInterface):
    def update(self, metadata):
        repo = self.config["repo"]
        raw = f"https://raw.githubusercontent.com/{repo}/main/"
        blob = f"https://github.com/{repo}/blob/main/"
        with open(os.path.join(self.root, "README.md"), encoding="utf-8") as f:
            text = f.read()
        text = re.sub(r'((?:src|srcset)=")(?!https?://)([^"]+)"', lambda m: f'{m.group(1)}{raw}{m.group(2)}"', text)
        text = re.sub(r'\]\((?!https?://|#|mailto:)([^)\s]+)\)', lambda m: f"]({blob}{m.group(1)})", text)
        unresolved = _unresolved(text, (raw, blob))
        if unresolved:
            raise ValueError(
                f"hatch_build: {len(unresolved)} reference(s) would ship unresolved in the "
                "PyPI description, so the project page would carry a broken image or a dead "
                "link: " + ", ".join(unresolved) + ". Make each target absolute in README.md, "
                "or extend the rewrite above to its carrier."
            )
        metadata["readme"] = {"content-type": "text/markdown", "text": text}
