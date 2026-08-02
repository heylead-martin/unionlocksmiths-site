#!/usr/bin/env bash
#
# Verify the Union -> Wah Luen 301s.
# Run immediately after enabling the Cloudflare redirect rule,
# BEFORE running Change of Address in Search Console.
#
# Checks per URL:
#   - status is 301, not 302 (302 passes no equity)
#   - exactly ONE hop, no chains
#   - lands on the matching path, not the homepage
#   - no loop

set -uo pipefail

# wahluen.sg added 02 Aug 2026: Kenneth confirmed it as a third domain that must
# also land on wahluenlocksmiths.sg. It needs its own Cloudflare redirect rule --
# the rule in cutover.md matches only the unionlocksmiths.sg zone.
OLD_HOSTS=("unionlocksmiths.sg" "www.unionlocksmiths.sg" "wahluen.sg" "www.wahluen.sg")
SCHEMES=("http" "https")
PATHS=(
  "/"
  "/about/"
  "/our-history/"
  "/services/"
  "/digital-locks/"
  "/rates/"
  "/contact/"
  "/assets/loc-working.jpg"
  "/nonexistent-page-check/"
)
NEW_HOST="wahluenlocksmiths.sg"

PASS=0; FAIL=0; WARN=0

check() {
  local url="$1"
  local expected_path="$2"

  local out status location hops
  out=$(curl -sS -o /dev/null -m 15 \
        -w '%{http_code} %{redirect_url} %{num_redirects}' \
        "$url" 2>/dev/null) || { echo "  FAIL  $url  (curl error)"; ((FAIL++)); return; }

  status=$(awk '{print $1}' <<<"$out")
  location=$(awk '{print $2}' <<<"$out")
  hops=$(awk '{print $3}' <<<"$out")

  local expected="https://${NEW_HOST}${expected_path}"

  if [[ "$status" != "301" ]]; then
    echo "  FAIL  $url"
    echo "        expected 301, got $status"
    ((FAIL++)); return
  fi

  if [[ "$location" == *"unionlocksmiths.sg"* ]]; then
    echo "  FAIL  $url"
    echo "        LOOP: redirects back to the old domain -> $location"
    ((FAIL++)); return
  fi

  if [[ "$location" != "$expected" ]]; then
    echo "  WARN  $url"
    echo "        expected $expected"
    echo "        got      $location"
    ((WARN++)); return
  fi

  # Follow the full chain and count hops
  local chain
  chain=$(curl -sSIL -m 20 -o /dev/null -w '%{num_redirects}' "$url" 2>/dev/null)
  if [[ "$chain" -gt 1 ]]; then
    echo "  WARN  $url"
    echo "        redirect CHAIN of $chain hops, should be 1"
    ((WARN++)); return
  fi

  echo "  PASS  $url  ->  $location"
  ((PASS++))
}

echo "=============================================="
echo "  Redirect verification: Union -> Wah Luen"
echo "  $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "=============================================="
echo

for scheme in "${SCHEMES[@]}"; do
  for host in "${OLD_HOSTS[@]}"; do
    echo "--- ${scheme}://${host} ---"
    for p in "${PATHS[@]}"; do
      check "${scheme}://${host}${p}" "$p"
    done
    echo
  done
done

echo "----------------------------------------------"
echo "  Also confirm the NEW domain answers directly"
echo "----------------------------------------------"
for p in "${PATHS[@]}"; do
  code=$(curl -sS -o /dev/null -m 15 -w '%{http_code}' "https://${NEW_HOST}${p}" 2>/dev/null)
  if [[ "$p" == "/nonexistent-page-check/" ]]; then
    [[ "$code" == "404" ]] && echo "  PASS  $p returns 404 as it should" \
                           || echo "  WARN  $p returns $code, expected 404 (soft 404?)"
  else
    [[ "$code" == "200" ]] && echo "  PASS  $p  200" \
                           || echo "  FAIL  $p  $code"
  fi
done

echo
echo "=============================================="
printf "  PASS: %d   WARN: %d   FAIL: %d\n" "$PASS" "$WARN" "$FAIL"
echo "=============================================="
echo
if [[ "$FAIL" -gt 0 ]]; then
  echo "Do NOT run Change of Address until FAIL is zero."
  exit 1
fi
echo "Clean. Safe to proceed to Search Console Change of Address."
