#!/usr/bin/env bash
# Known-answer battery for the two published-evidence pages: README.md and the
# receipts page evals/README.md.
#
# Why these two needed an instrument and what it is deliberately not. Check J
# already derives every `count:` marker on every published page from the
# receipts table, so none of those totals is restated here - that would give
# one claim two sources rather than add coverage. What check J cannot see is
# prose: `grep -cF` over scripts/validate.sh returns 0 for `blocked at the
# close`, `all but five`, `Convergence standard` and `countersigned`, so the
# two sentences that quantify over the receipts themselves had no oracle at
# all, and one of them is a number the 1.27.0 release introduced. PLAN.md's own
# rule is that such a number joins the Derived list in the commit that
# introduces it; this battery is what it joins.
#
# Nor does anything resolve the links: `grep -cF 'details](./' scripts/validate.sh`
# returns 0, so the harness matches the row shape and never opens the target.
#
# Both sentences are rendered from the derived figures and required verbatim,
# never located and parsed. That is this project's Lesson about comparing a
# canonical form instead of classifying prose, and it is the stronger direction:
# a locator would accept a document that states the claim in words the extractor
# happens to read, where rendering requires the document to carry exactly what
# the receipts say.
#
# Expected: 23 executed checks. `grep -c '^ *ck "' run.sh` returns 23 and no
# ck() sits inside a loop or a command substitution, so the static count and
# the executed count agree. A disagreement is explained before it is edited.
set -u
pc_root="${JEFFY_PROBE_ROOT:-$PWD}"
pc_front="$pc_root/README.md"
pc_sc="$pc_root/evals/README.md"
if [ ! -f "$pc_front" ] || [ ! -f "$pc_sc" ]; then
  echo "published-claims battery: no README.md or evals/README.md under $pc_root"
  exit 2
fi

pc_ok=0; pc_bad=0
ck() { # $1 label, $2 expected, $3 actual
  if [ "$2" = "$3" ]; then pc_ok=$((pc_ok + 1)); else
    pc_bad=$((pc_bad + 1)); echo "FAIL $1: expected [$2] got [$3]"
  fi
}

pc_tmp="$(mktemp -d)"
trap 'rm -rf "$pc_tmp"' EXIT

# A cardinal the published sentences spell in words. Rendering needs the word,
# and a figure with no word in this table faults rather than rendering digits
# the document could never carry - the shape in which a derived value silently
# stops being comparable.
pc_word() {
  case "$1" in
    0) echo none ;; 1) echo one ;; 2) echo two ;; 3) echo three ;; 4) echo four ;;
    5) echo five ;; 6) echo six ;; 7) echo seven ;; 8) echo eight ;; 9) echo nine ;;
    10) echo ten ;; 11) echo eleven ;; 12) echo twelve ;; 13) echo thirteen ;;
    14) echo fourteen ;; 15) echo fifteen ;; 16) echo sixteen ;; 17) echo seventeen ;;
    18) echo eighteen ;; 19) echo nineteen ;; 20) echo twenty ;;
    *) echo "NO-WORD-FOR-$1" ;;
  esac
}

# The receipts table's own row shape, the same one check J reads: a row whose
# third cell opens with a details link.
pc_rows() { grep -E '^\| [^|]+ \| [^|]+ \| \[details\]\(' "$pc_sc"; }

# --- the receipt population --------------------------------------------------
pc_receipts="$(find "$pc_root/evals" -mindepth 2 -maxdepth 2 -name REPORT.md | grep -c .)"
pc_rown="$(pc_rows | grep -c .)"
ck "the receipt population is plausible (>=100 receipts)" yes \
  "$([ "$pc_receipts" -ge 100 ] && echo yes || echo "no ($pc_receipts)")"
ck "the receipts table population is plausible (>=100 rows)" yes \
  "$([ "$pc_rown" -ge 100 ] && echo yes || echo "no ($pc_rown)")"

# --- the standards split -----------------------------------------------------
# Every converged receipt states one Convergence standard. The three classes
# are enumerated rather than whitelisted: a value outside them faults, because
# a member the extractor drops is a claim nobody compared, and the split is
# what README.md's sentence restates.
grep -h -oE '^\*\*Convergence standard\*\*: [^.,;]+' "$pc_root"/evals/*/REPORT.md \
  | sed 's/^\*\*Convergence standard\*\*: //; s/[[:space:]]*$//' | sort > "$pc_tmp/std"
pc_std_n="$(grep -c . "$pc_tmp/std")"
pc_counter="$(grep -cxF 'evaluator countersigned' "$pc_tmp/std")"
pc_pregate="$(grep -cxF 'pre-evaluator' "$pc_tmp/std")"
pc_without="$(grep -cxF 'evaluator unavailable' "$pc_tmp/std")"
ck "every converged receipt states a Convergence standard this battery classifies" "" \
  "$(grep -vxF -e 'evaluator countersigned' -e 'pre-evaluator' -e 'evaluator unavailable' "$pc_tmp/std" | sort -u | tr '\n' ' ' | sed 's/ *$//')"
ck "the three standard classes account for every receipt that states one" "$pc_std_n" \
  "$((pc_counter + pc_pregate + pc_without))"
ck "the standards population is plausible (>=100 receipts state one)" yes \
  "$([ "$pc_std_n" -ge 100 ] && echo yes || echo "no ($pc_std_n)")"

# The front page's converged total is the set these standards partition, so the
# two have to agree before the split sentence means anything.
pc_converged="$(grep -oE '<!-- count:converged -->[0-9]+' "$pc_front" | head -n 1 | tr -dc '0-9')"
ck "the converged marker is readable" yes \
  "$([ -n "$pc_converged" ] && echo yes || echo no)"
ck "the standards split accounts for every converged run the front page claims" "${pc_converged:-unread}" "$pc_std_n"

pc_notcounter=$((pc_std_n - pc_counter))
pc_split="all but $(pc_word "$pc_notcounter") were countersigned, $(pc_word "$pc_pregate") predate the gate and $(pc_word "$pc_without") ran without it"
ck "every figure in the standards split has a word to render" "" \
  "$(printf '%s\n' "$pc_split" | grep -oE 'NO-WORD-FOR-[0-9]+' | tr '\n' ' ' | sed 's/ *$//')"
ck "the front page states the standards split the receipts derive, once" 1 \
  "$(grep -c -F -- "$pc_split" "$pc_front")"

# --- the blocked-at-the-close claim ------------------------------------------
# New in 1.27.0 and stated in both documents. Derived from the rows that carry
# the annotation, not from either sentence.
pc_rows | grep -F 'blocked at the close' > "$pc_tmp/blocked"
pc_blocked="$(grep -c . "$pc_tmp/blocked")"
ck "the blocked-at-the-close population is non-empty" yes \
  "$([ "$pc_blocked" -ge 1 ] && echo yes || echo "no ($pc_blocked)")"
ck "the blocked figure has a word to render" "" \
  "$(pc_word "$pc_blocked" | grep -oE 'NO-WORD-FOR-[0-9]+')"
ck "the front page states the blocked count the rows derive, once" 1 \
  "$(grep -c -F -- "$(pc_word "$pc_blocked") carry a finding blocked at the close, named on its row" "$pc_front")"
ck "the receipts page states the same count, once" 1 \
  "$(grep -c -F -- "$(pc_word "$pc_blocked") of those rows carry a finding blocked at the close, named on the row" "$pc_sc")"
# The claim is about converged work, so an annotated row that is not Fixed would
# make both sentences count a row their own subject excludes.
ck "every row annotated blocked at the close is a Fixed row" "" \
  "$(awk -F'|' '{ gsub(/^[ \t]+|[ \t]+$/, "", $2); r = $5; gsub(/[ \t]/, "", r); if (r != "Fixed") print $2 }' "$pc_tmp/blocked" | tr '\n' ' ' | sed 's/ *$//')"
ck "every row annotated blocked at the close has a receipt on disk" "" \
  "$(grep -oE '\[details\]\(\./[^)]+\)' "$pc_tmp/blocked" | sed 's/\[details\](\.\///; s/)$//' | while IFS= read -r t; do [ -e "$pc_root/evals/$t" ] || printf '%s ' "$t"; done | sed 's/ *$//')"

# --- the links the harness matches and never opens ---------------------------
grep -oE '\[details\]\(\./[^)]+\)' "$pc_sc" | sed 's/\[details\](\.\///; s/)$//' | sort -u > "$pc_tmp/links"
pc_linkn="$(grep -c . "$pc_tmp/links")"
ck "the details-link population is plausible (>=100 targets)" yes \
  "$([ "$pc_linkn" -ge 100 ] && echo yes || echo "no ($pc_linkn)")"
ck "every details link resolves" "" \
  "$(while IFS= read -r t; do [ -e "$pc_root/evals/$t" ] || printf '%s ' "$t"; done < "$pc_tmp/links" | sed 's/ *$//')"
ck "every receipt on disk is linked by a row" "" \
  "$(find "$pc_root/evals" -mindepth 2 -maxdepth 2 -name REPORT.md | sed "s|^$pc_root/evals/||" | while IFS= read -r r; do grep -qxF "$r" "$pc_tmp/links" || printf '%s ' "$r"; done | sed 's/ *$//')"

# --- every other relative reference on both pages ----------------------------
# Scheme-bearing and anchor-only targets are excluded by shape; what is left is
# a path this repository has to carry. Each target is checked against the page
# it was found on, because a relative path resolves from its own directory.
pc_refs() { # $1 page
  grep -oE '\]\([^)]+\)|src="[^"]+"' "$1" \
    | sed 's/^\](//; s/)$//; s/^src="//; s/"$//' \
    | sed 's/ .*$//' \
    | grep -vE '^(https?|mailto|data):' | grep -v '^#' | sed 's/#.*$//' | grep . | sort -u
}
for pc_p in "$pc_front" "$pc_sc"; do
  pc_dir="$(dirname "$pc_p")"
  pc_refs "$pc_p" > "$pc_tmp/refs.$(basename "$pc_dir")"
done
pc_refn=$(($(grep -c . "$pc_tmp/refs.$(basename "$(dirname "$pc_front")")") + $(grep -c . "$pc_tmp/refs.$(basename "$(dirname "$pc_sc")")")))
ck "the relative-reference population is plausible (>=40 across both pages)" yes \
  "$([ "$pc_refn" -ge 40 ] && echo yes || echo "no ($pc_refn)")"
pc_missing=""
for pc_p in "$pc_front" "$pc_sc"; do
  pc_dir="$(dirname "$pc_p")"
  while IFS= read -r pc_t; do
    [ -e "$pc_dir/$pc_t" ] || pc_missing="$pc_missing$(basename "$pc_p"):$pc_t "
  done < "$pc_tmp/refs.$(basename "$pc_dir")"
done
ck "every relative reference on both pages resolves" "" "$(printf '%s' "$pc_missing" | sed 's/ *$//')"

# --- the front page's own anchors --------------------------------------------
# Proved on a known positive and a known negative before its silence counts: a
# slug rule that matched everything would report a clean page for the worst
# possible reason.
grep -oE '^#+ .*' "$pc_front" | sed 's/^#\+ *//' | tr '[:upper:]' '[:lower:]' \
  | sed 's/[^a-z0-9 _-]//g; s/ /-/g' | sort -u > "$pc_tmp/slugs"
ck "the heading-slug population is plausible (>=10 headings)" yes \
  "$([ "$(grep -c . "$pc_tmp/slugs")" -ge 10 ] && echo yes || echo "no ($(grep -c . "$pc_tmp/slugs"))")"
ck "the slug rule finds a heading that exists and not one that does not" "yes no" \
  "$(grep -qxF 'the-record' "$pc_tmp/slugs" && printf yes || printf no; printf ' '; grep -qxF 'no-such-heading-here' "$pc_tmp/slugs" && printf yes || printf no)"
ck "every anchor on the front page names a heading on it" "" \
  "$(grep -oE '\]\(#[^)]+\)' "$pc_front" | sed 's/^\](#//; s/)$//' | sort -u | while IFS= read -r a; do grep -qxF "$a" "$pc_tmp/slugs" || printf '%s ' "$a"; done | sed 's/ *$//')"

echo "  published-claims: receipts=$pc_receipts rows=$pc_rown standards=$pc_counter/$pc_pregate/$pc_without blocked=$pc_blocked links=$pc_linkn refs=$pc_refn"
if [ "$pc_bad" -eq 0 ]; then
  echo "published-claims battery: $pc_ok/$((pc_ok + pc_bad)) checks passed"
  exit 0
fi
echo "published-claims battery: $pc_ok/$((pc_ok + pc_bad)) checks passed, $pc_bad FAILED"
exit 1
