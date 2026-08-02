# Cutover: exact steps

Confirmed from the live site on 02 Aug 2026. Seven pages, static build, assets under `/assets/`, clean URLs.

**Page inventory:** `/` `/about/` `/our-history/` `/services/` `/digital-locks/` `/rates/` `/contact/`

This is a same-structure domain swap, which is the cleanest migration case there is. Every path maps 1:1.

---

## 1. Cloudflare redirect rule (the 301)

On the **unionlocksmiths.sg** zone, not the new one.

Rules > Redirect Rules > Create rule.

**Name:** `Union to Wah Luen 301`

**When incoming requests match, use the Expression Editor:**

```
(http.host eq "unionlocksmiths.sg") or (http.host eq "www.unionlocksmiths.sg")
```

**Then:**

| Setting | Value |
|---|---|
| Type | Dynamic |
| Expression | `concat("https://wahluenlocksmiths.sg", http.request.uri.path)` |
| Status code | **301** Permanent Redirect |
| Preserve query string | **On** |

That single rule covers all seven pages, both hosts, both schemes, and every asset. No per-page rows needed because the paths are identical.

**One asset exception.** If you rename `union-logo.png` to `wahluen-logo.png`, add a Bulk Redirect list entry above the catch-all:

```
/assets/union-logo.png  ->  https://wahluenlocksmiths.sg/assets/wahluen-logo.png  (301)
```

Or simpler: keep a copy of the file at the old filename on the new server for twelve months and skip the exception entirely. Fewer moving parts.

### Why Cloudflare and not .htaccess

Rollback is a single toggle. If the new site misbehaves at cutover, you disable the rule and the old site is instantly back. An .htaccess redirect requires a file edit, a cache purge, and hope.

---

## 2. Order of operations on the day

Do not reorder. Each step depends on the one before it.

1. New site live and verified on `wahluenlocksmiths.sg`, apex and www, http and https, valid certificate, no mixed content
2. New mailbox `admin@wahluenlocksmiths.sg` receiving mail (test it, send and receive)
3. **Then** enable the Cloudflare redirect rule
4. Run `./verify-redirects.sh`, require zero FAIL
5. Search Console: verify the new property, then Change of Address on the old one
6. Submit sitemap, request indexing on all seven pages
7. Google Business Profile name and URL change
8. Tell Kenneth

Step 3 before step 1 takes the site down. Step 5 before step 4 tells Google about a migration you have not confirmed works.

---

## 3. Pre-flight blockers

Neither of these is optional and both sit with Kenneth.

- **unionlocksmiths.sg auto-renew is OFF, due 26 Sep 2026.** The redirect rule lives on that zone. If the domain lapses, the rule dies with it and every one of those 301s stops resolving. Renew for two years before cutover, not after.
- **`admin@unionlocksmiths.sg` is published on two pages.** Set the new mailbox up first and forward the old address for twelve months. Enquiries will keep arriving at the old one.

---

## 4. Two content items to confirm with Kenneth

- **Phone number.** The site publishes `+65 8334 7296`. The WhatsApp number on file for the business is `+65 8818 3193`. Both may be correct for different purposes, but they need to be deliberate before ads point at either. A mismatched number across the site, Google Business Profile and the ads account is a ranking and quality-score problem, and a lead-loss problem.
- **The Our History page.** See `our-history-rewrite.md`. It needs writing, not replacing, and there is a factual claim on it worth checking before it gets republished under a new name.

---

## 5. What I have not touched

The runbook assumed WordPress based on the earlier project notes. The live site looks like a **static build**: no `/wp-content/` paths, clean trailing-slash URLs, flat `/assets/` directory. If that is right, the WP-CLI section of the main runbook does not apply and `rebrand.sh` replaces it, which makes this job considerably faster.

Confirm the stack before you start, since it changes the deploy step and nothing else.

---

## Addendum, 02 Aug 2026 (added during the rebrand build)

### wahluen.sg is a third domain and is not covered above

Kenneth: *"Anyone who visits unionlocksmiths.sg and wahluen.sg will be directed
to wahluenlocksmiths.sg."*

The redirect rule in §1 matches only the `unionlocksmiths.sg` zone. `wahluen.sg`
needs its **own** redirect rule, on its own Cloudflare zone, with the same
dynamic target. It is not in `redirect-map.csv` either.

Add to §3 pre-flight: confirm who holds `wahluen.sg`, that it is on Cloudflare,
and what its auto-renew status is. The same lapse risk that applies to
`unionlocksmiths.sg` applies here.

`verify-redirects.sh` has been updated to test all four hosts.

### The Our History question is answered

Kenneth confirmed the 1934 firm did trade in English as Union Construction
Company, and asked for that name to be kept on the page: *"Nothing to do with
Union Locks and just a part of history."* The rewritten page states the English
name and the 華聯 / Wah Luen reading together. The caveat in
`our-history-rewrite.md` §"One caveat" is resolved.

### Still open with Kenneth

- **Phone number.** Unchanged from §4. Site still shows `+65 8334 7296`
  throughout; WhatsApp on file is `+65 8818 3193`. Not touched by the rebrand.
- **Logo artwork.** `assets/wahluen-logo.png` is the *old Union PNG under a new
  filename*. The header currently renders the old mark. The SVG text fallback
  has been updated to WAH LUEN and is correct, but it only shows if the PNG
  fails to load. This must be replaced before launch.
- **`admin@wahluenlocksmiths.sg` now appears on all seven pages**, not the two
  §4 predicted. The mailbox must exist and receive before deploy (§2 step 2).
