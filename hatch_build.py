"""Rewrite the README for PyPI at build time.

PyPI renders the project description from README.md but cannot resolve
relative paths, so images under assets/ and links to files in the repository
render broken there. This hook turns every relative src, srcset and markdown
link into an absolute GitHub URL in the built metadata only; the README in the
repository stays relative, which is what GitHub wants.
"""
import os
import re

from hatchling.metadata.plugin.interface import MetadataHookInterface


class ReadmeHook(MetadataHookInterface):
    def update(self, metadata):
        repo = self.config["repo"]
        raw = f"https://raw.githubusercontent.com/{repo}/main/"
        blob = f"https://github.com/{repo}/blob/main/"
        with open(os.path.join(self.root, "README.md"), encoding="utf-8") as f:
            text = f.read()
        text = re.sub(r'((?:src|srcset)=")(?!https?://)([^"]+)"', lambda m: f'{m.group(1)}{raw}{m.group(2)}"', text)
        text = re.sub(r'\]\((?!https?://|#|mailto:)([^)\s]+)\)', lambda m: f"]({blob}{m.group(1)})", text)
        metadata["readme"] = {"content-type": "text/markdown", "text": text}
