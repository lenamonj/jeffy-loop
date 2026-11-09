#!/usr/bin/env bash
# Invariant battery for the published binaries: the white paper, the STE100
# description, and the media set.
#
# These are three of the six paths the Oracle class line's own coverage command
# reports at zero - `git ls-files | sed 's|/.*||' | sort -u` against
# `grep -cF` over scripts/validate.sh returns 0 for both PDFs, and 1 for media
# which is a comment rather than a check. So nothing in the tree reads any of
# them, and the two documents are the first thing a reader downloads.
#
# The structural arms are three independent derivations of one number: the page
# tree root's /Count, the /Type /Page objects, and the /Contents references. A
# truncated upload, a half-written regeneration or a corrupt stream breaks the
# agreement, and no single one of them would notice on its own. That is an
# invariant rather than a liveness probe, which is this file's own rule for a
# row whose surface carries values.
#
# Text is reached with the standard library alone, because the Environment
# fingerprint records that this host carries neither pypdf nor pdftotext. The
# two documents need different filters - the white paper is FlateDecode, the
# STE100 description is ASCII85 then Flate, which is ReportLab's default - and
# pdf.py tries both so the row does not rest on one generator's habits.
#
# Expected: 21 executed checks. `grep -c '^ *ck "' run.sh` returns 21 and no
# ck() sits inside a loop or a command substitution, so the static count and
# the executed count agree. A disagreement is explained before it is edited.
set -u
pd_root="${JEFFY_PROBE_ROOT:-$PWD}"
pd_py="$pd_root/.jeffy/probes/published-docs/pdf.py"
pd_wp="$pd_root/docs/The-Jeffy-Loop.pdf"
pd_ste="$pd_root/docs/Jeffy-Loop-STE100.pdf"
for pd_f in "$pd_py" "$pd_wp" "$pd_ste"; do
  [ -f "$pd_f" ] || { echo "published-docs battery: no $pd_f"; exit 2; }
done
command -v python3 >/dev/null 2>&1 ||
  { echo "published-docs battery: NOT RUNNABLE: no python3 on PATH, and the reader is a Python script; install python3"; exit 2; }

pd_ok=0; pd_bad=0
ck() { # $1 label, $2 expected, $3 actual
  if [ "$2" = "$3" ]; then pd_ok=$((pd_ok + 1)); else
    pd_bad=$((pd_bad + 1)); echo "FAIL $1: expected [$2] got [$3]"
  fi
}

pd_tmp="$(mktemp -d)"
trap 'rm -rf "$pd_tmp"' EXIT

pd_field() { sed -n "s/^$2=//p" "$1"; }

# --- both documents: structure ----------------------------------------------
python3 "$pd_py" "$pd_wp" > "$pd_tmp/wp" 2>&1 || true
python3 "$pd_py" "$pd_ste" > "$pd_tmp/ste" 2>&1 || true

ck "the white paper reads as a PDF, header and trailer" "1 1" \
  "$(pd_field "$pd_tmp/wp" header) $(pd_field "$pd_tmp/wp" eof)"
ck "the STE100 description reads as a PDF, header and trailer" "1 1" \
  "$(pd_field "$pd_tmp/ste" header) $(pd_field "$pd_tmp/ste" eof)"

# One page tree root per document, so a second /Count would mean the file is
# not the single-document shape every arm below assumes.
ck "the white paper carries one page tree root" 1 \
  "$(pd_field "$pd_tmp/wp" counts | awk -F, '{print NF}')"
ck "the STE100 description carries one page tree root" 1 \
  "$(pd_field "$pd_tmp/ste" counts | awk -F, '{print NF}')"

# The three-way agreement, each document reported so the page count is visible
# rather than only compared.
ck "the white paper's page count agrees three ways" \
  "$(pd_field "$pd_tmp/wp" counts) $(pd_field "$pd_tmp/wp" counts) $(pd_field "$pd_tmp/wp" counts)" \
  "$(pd_field "$pd_tmp/wp" counts) $(pd_field "$pd_tmp/wp" typepage) $(pd_field "$pd_tmp/wp" contents)"
ck "the STE100 description's page count agrees three ways" \
  "$(pd_field "$pd_tmp/ste" counts) $(pd_field "$pd_tmp/ste" counts) $(pd_field "$pd_tmp/ste" counts)" \
  "$(pd_field "$pd_tmp/ste" counts) $(pd_field "$pd_tmp/ste" typepage) $(pd_field "$pd_tmp/ste" contents)"

# A content stream per page at least, and text behind it. Floors rather than
# equalities: an appearance stream is a content stream too, and a document is
# free to split a page across several.
ck "the white paper decodes at least one content stream per page" yes \
  "$([ "$(pd_field "$pd_tmp/wp" decoded)" -ge "$(pd_field "$pd_tmp/wp" counts)" ] && echo yes || echo "no (decoded=$(pd_field "$pd_tmp/wp" decoded) pages=$(pd_field "$pd_tmp/wp" counts))")"
ck "the STE100 description decodes at least one content stream per page" yes \
  "$([ "$(pd_field "$pd_tmp/ste" decoded)" -ge "$(pd_field "$pd_tmp/ste" counts)" ] && echo yes || echo "no (decoded=$(pd_field "$pd_tmp/ste" decoded) pages=$(pd_field "$pd_tmp/ste" counts))")"
ck "the white paper's text is reachable without a PDF extractor" yes \
  "$([ "$(pd_field "$pd_tmp/wp" textlen)" -ge 50000 ] && echo yes || echo "no (textlen=$(pd_field "$pd_tmp/wp" textlen))")"
ck "the STE100 description's text is reachable without a PDF extractor" yes \
  "$([ "$(pd_field "$pd_tmp/ste" textlen)" -ge 1000 ] && echo yes || echo "no (textlen=$(pd_field "$pd_tmp/ste" textlen))")"

# --- the white paper's reference list ----------------------------------------
python3 "$pd_py" "$pd_wp" --refs > "$pd_tmp/refs" 2>&1 || true
ck "the reference list is found as a section and not only as a contents entry" 2 \
  "$(pd_field "$pd_tmp/refs" sections)"
ck "the reference list is non-empty" yes \
  "$([ "$(pd_field "$pd_tmp/refs" n)" -ge 1 ] && echo yes || echo "no (n=$(pd_field "$pd_tmp/refs" n))")"
ck "the reference entries run contiguously from one with no gap or repeat" 1 \
  "$(pd_field "$pd_tmp/refs" contiguous)"
ck "every reference entry carries a link" "" "$(pd_field "$pd_tmp/refs" nolink)"

# --- the STE100 description states the standard it is named for --------------
python3 "$pd_py" "$pd_ste" --text > "$pd_tmp/ste.txt" 2>&1 || true
ck "the STE100 description names its own standard" yes \
  "$(grep -qF 'ASD-STE100' "$pd_tmp/ste.txt" && echo yes || echo no)"

# --- the published download links --------------------------------------------
# README links both documents by absolute URL, so the sibling battery over
# relative references cannot see them: a renamed document would break every
# published download link with nothing going red.
( cd "$pd_root" && git grep -h -oE 'raw/main/[A-Za-z0-9._/-]+' -- '*.md' 2>/dev/null ) | sed 's|^raw/main/||' | sort -u > "$pd_tmp/raw"
ck "the published raw-link population is non-empty" yes \
  "$([ "$(grep -c . "$pd_tmp/raw")" -ge 1 ] && echo yes || echo no)"
ck "every published raw link names a tracked file" "" \
  "$(while IFS= read -r t; do ( cd "$pd_root" && git ls-files --error-unmatch "$t" >/dev/null 2>&1 ) || printf '%s ' "$t"; done < "$pd_tmp/raw" | sed 's/ *$//')"

# --- the figures these documents no longer publish ---------------------------
# PLAN.md's Derived and settled numbers section settles the page count and the
# source count on the ground that no document states them any more. That is an
# absence, and an absence decays the moment someone writes the sentence back.
# The scope is the claims section's own - tracked markdown outside evals/ and
# outside .jeffy/ - and it is that rather than every tracked page for a reason
# about what those paths are: an evaluator artifact is a frozen record the Stop
# hook requires committed and unmodified, so one quoting the old sentence is
# evidence of what was true when its verdict was written and can never be
# brought into agreement with a page that has moved on. Narrowing here was
# driven by that exact hit on the first run.
ck "no tracked page documents a page count or a source count for either paper" "" \
  "$( cd "$pd_root" && git grep -nE '[0-9]+-page|cites [0-9]+ sources' -- '*.md' ':!evals' ':!.jeffy' 2>/dev/null | cut -d: -f1,2 | tr '\n' ' ' | sed 's/ *$//')"

# --- the media set ------------------------------------------------------------
( cd "$pd_root" && git ls-files media ) > "$pd_tmp/media"
ck "the media population is plausible (>=20 tracked files)" yes \
  "$([ "$(grep -c . "$pd_tmp/media")" -ge 20 ] && echo yes || echo "no ($(grep -c . "$pd_tmp/media"))")"
# A themed asset ships in both themes. Two conventions are in use and both are
# accepted, because the set uses both: an explicit -dark sibling, or an
# unsuffixed default standing in for it.
pd_unpaired=""
while IFS= read -r pd_m; do
  pd_e="${pd_m##*.}"
  case "$pd_m" in
    *-light."$pd_e") pd_b="${pd_m%-light."$pd_e"}"
      [ -e "$pd_root/$pd_b-dark.$pd_e" ] || [ -e "$pd_root/$pd_b.$pd_e" ] || pd_unpaired="$pd_unpaired$pd_m " ;;
    *-dark."$pd_e") pd_b="${pd_m%-dark."$pd_e"}"
      [ -e "$pd_root/$pd_b-light.$pd_e" ] || pd_unpaired="$pd_unpaired$pd_m " ;;
  esac
done < "$pd_tmp/media"
ck "every themed media asset ships in both themes" "" "$(printf '%s' "$pd_unpaired" | sed 's/ *$//')"
# The orphans are named rather than tolerated as slack: these three are
# referenced by nothing in the tree because their consumers are outside it -
# the logo pair is repository chrome and the mp4 is the source the gif beside
# it was rendered from. A fourth orphan is a finding.
ck "the media files no tracked file references are exactly the known three" \
  "media/jeffy-vs-raw-loop.mp4 media/logo-dark.png media/logo-light.png" \
  "$(while IFS= read -r pd_m; do ( cd "$pd_root" && git grep -q -F -- "$(basename "$pd_m")" -- ':!.jeffy' 2>/dev/null ) || printf '%s ' "$pd_m"; done < "$pd_tmp/media" | sed 's/ *$//')"

echo "  published-docs: white-paper pages=$(pd_field "$pd_tmp/wp" counts) refs=$(pd_field "$pd_tmp/refs" n) text=$(pd_field "$pd_tmp/wp" textlen); ste100 pages=$(pd_field "$pd_tmp/ste" counts) text=$(pd_field "$pd_tmp/ste" textlen); media=$(grep -c . "$pd_tmp/media")"
if [ "$pd_bad" -eq 0 ]; then
  echo "published-docs battery: $pd_ok/$((pd_ok + pd_bad)) checks passed"
  exit 0
fi
echo "published-docs battery: $pd_ok/$((pd_ok + pd_bad)) checks passed, $pd_bad FAILED"
exit 1
