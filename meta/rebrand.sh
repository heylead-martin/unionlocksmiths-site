#!/usr/bin/env bash
#
# Union Locksmiths -> Wah Luen Locksmiths static site rebrand
#
# Usage:
#   ./rebrand.sh /path/to/site           # dry run, reports only, changes nothing
#   ./rebrand.sh /path/to/site --apply   # writes changes
#
# Always run the dry run first and read the manual review section.
# Work on a COPY. Never point this at the live document root.

set -euo pipefail

SITE="${1:?Usage: ./rebrand.sh /path/to/site [--apply]}"
APPLY="${2:-}"

if [[ ! -d "$SITE" ]]; then
  echo "Not a directory: $SITE" >&2
  exit 1
fi

if [[ "$APPLY" == "--apply" ]]; then
  MODE="APPLY"
  WORKDIR="$SITE"
else
  MODE="DRY RUN"
  # Work on a throwaway copy so the "remaining Union" report below is
  # accurate, i.e. it shows what is left AFTER the automated pass,
  # not everything that currently exists.
  WORKDIR="$(mktemp -d)"
  cp -a "$SITE/." "$WORKDIR/"
  trap 'rm -rf "$WORKDIR"' EXIT
fi

echo "=============================================="
echo "  Rebrand: Union -> Wah Luen"
echo "  Target : $SITE"
echo "  Mode   : $MODE"
echo "=============================================="
echo

FILES=$(find "$WORKDIR" -type f \( -name '*.html' -o -name '*.htm' -o -name '*.css' -o -name '*.js' -o -name '*.xml' -o -name '*.json' -o -name '*.txt' -o -name '*.webmanifest' \))

if [[ -z "$FILES" ]]; then
  echo "No matching files found. Check the path." >&2
  exit 1
fi

echo "Files in scope: $(echo "$FILES" | wc -l)"
echo

# ---------------------------------------------------------------
# Ordered replacements. Longest and most specific first, so that
# "Union Locksmiths" is consumed before any bare "Union" rule.
# ---------------------------------------------------------------

declare -a PAIRS=(
  "unionlocksmiths.sg|wahluenlocksmiths.sg"
  "Union Locksmiths'|Wah Luen Locksmiths'"
  "Union Locksmiths|Wah Luen Locksmiths"
  "union-logo.png|wahluen-logo.png"
  "A Union locksmith at work|A Wah Luen locksmith at work"
  "handled by Union Locksmiths|handled by Wah Luen Locksmiths"
  "Union's professional locksmiths|Wah Luen's professional locksmiths"
)

for pair in "${PAIRS[@]}"; do
  FROM="${pair%%|*}"
  TO="${pair##*|}"
  COUNT=$(grep -hooF "$FROM" $FILES 2>/dev/null | wc -l || true)
  printf '  %-45s -> %-40s  %s occurrence(s)\n' "$FROM" "$TO" "$COUNT"
  if [[ "$COUNT" -gt 0 ]]; then
    # shellcheck disable=SC2086
    perl -pi -e "s/\Q$FROM\E/$TO/g" $FILES
  fi
done

echo
echo "----------------------------------------------"
echo "  MANUAL REVIEW: remaining 'Union' occurrences"
echo "----------------------------------------------"
echo "These are NOT auto-replaced. Every one is a judgement call."
echo

# shellcheck disable=SC2086
# Blank out the new brand first, THEN look for Union. A line can
# legitimately contain both after the automated pass, and a naive
# line-level filter would hide it.
FOUND=$(perl -ne '
  my $orig = $_;
  my $t = $_;
  $t =~ s/wah[\s-]*luen[a-z]*//gi;
  if ($t =~ /union/i) { printf("%s:%d:%s", $ARGV, $., $orig); }
  close ARGV if eof;
' $FILES 2>/dev/null | sed "s|^$WORKDIR/||")

if [[ -n "$FOUND" ]]; then
  echo "$FOUND"
else
  echo "  (none)"
fi

echo
echo "----------------------------------------------"
echo "  ASSET RENAMES"
echo "----------------------------------------------"
if [[ -f "$WORKDIR/assets/union-logo.png" ]]; then
  echo "  assets/union-logo.png -> assets/wahluen-logo.png"
  if [[ "$MODE" == "APPLY" ]]; then
    git -C "$WORKDIR" mv assets/union-logo.png assets/wahluen-logo.png 2>/dev/null \
      || mv "$WORKDIR/assets/union-logo.png" "$WORKDIR/assets/wahluen-logo.png"
    echo "  renamed. NOTE: replace the file itself with the new Wah Luen mark."
  fi
else
  echo "  assets/union-logo.png not found at expected path"
fi

echo
echo "----------------------------------------------"
echo "  STILL TO DO BY HAND"
echo "----------------------------------------------"
cat <<'EOF'
  1. Header logo markup: the wordmark is split across two elements,
     UNION in <strong> and LOCKSMITHS in <em>. "WAH LUEN" is two words
     and will wrap differently. Needs a look, not a replace.

  2. /our-history/ : full rewrite. See our-history-rewrite.md.
     Do not run this script's output on that page and call it done.
     The word "Union" carries the meaning on that page.

  3. Meta descriptions: every page currently shares one identical
     description. Fix while you are in here, it is free.

  4. Email: admin@unionlocksmiths.sg appears on Home and Contact.
     The new mailbox must exist and receive before this goes live.

  5. Phone: site shows +65 8334 7296. The WhatsApp number on file is
     +65 8818 3193. Confirm with Kenneth which is canonical before ads.

  6. Schema / OG tags: check for JSON-LD or og: meta not caught above.

  7. Trailing slash: canonical tags use /our-history/ but the server
     also answers /our-history. Pick one and be consistent.
EOF

echo
echo "Done ($MODE)."
if [[ "$MODE" != "APPLY" ]]; then
  echo "Nothing was written. Re-run with --apply when the above looks right."
fi
