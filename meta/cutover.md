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

---

# DNS and redirect runbook

**This section supersedes §1 and §2 above.** Those were written assuming
Cloudflare already sat in front of `unionlocksmiths.sg`. DNS lookups on
02 Aug 2026 show it does not. Follow the steps here instead.

Goal, in Kenneth's words: everything moves to `wahluenlocksmiths.sg`, and
`unionlocksmiths.sg` (plus `wahluen.sg`) 301 to it.

## Observed DNS state, 02 Aug 2026

| Domain | Resolves to | Reading |
|---|---|---|
| `unionlocksmiths.sg` | `185.199.108-111.153` | GitHub Pages apex IPs, **direct, not proxied** |
| `wahluenlocksmiths.sg` | `103.11.189.189` | Registered, but not GitHub Pages |
| `wahluen.sg` | *no answer* | No DNS records; may not be registered |

Re-check these before starting; they may have moved.

## Two constraints that drive the whole order

**Cloudflare Redirect Rules only fire on proxied traffic.** They run at
Cloudflare's edge. A DNS-only (grey cloud) record means Cloudflare answers the
lookup and traffic goes straight to origin, so no rule ever executes.
`unionlocksmiths.sg` currently returns GitHub's real IPs, so it is either not on
Cloudflare or is grey-clouded. Either way the §1 rule would not fire today, and
the "rollback is a single toggle" advantage does not exist until it is proxied.

**A GitHub Pages site answers for exactly one custom domain** - whatever is in
`CNAME`. Once that file says `wahluenlocksmiths.sg`, Pages no longer recognises
`unionlocksmiths.sg`. If that domain is still pointed at GitHub's IPs at that
moment, every old URL returns a **GitHub 404, not a 301**. That is the worst
outcome available: link equity lost and no path to the new site.

So `unionlocksmiths.sg` must stop pointing at GitHub in the same change that
starts pointing it at something that redirects. Do not merge to `main` before
step 5 is staged and ready to enable.

## Steps

Do not reorder. A day or two ahead, drop TTLs on all three zones to 300s so a
mistake is minutes to undo rather than hours.

### 1. Point wahluenlocksmiths.sg at GitHub Pages

First find out what `103.11.189.189` is - registrar parking, or a live host
with content on it. Do not repoint until you know what you are switching off.

- apex `@` -> four A records: `185.199.108.153`, `185.199.109.153`,
  `185.199.110.153`, `185.199.111.153`
- `www` -> CNAME to `heylead-martin.github.io`
- optional AAAA: `2606:50c0:8000::153`, `8001::153`, `8002::153`, `8003::153`

If this zone is on Cloudflare, set these **DNS-only / grey cloud** for now.
See step 3.

### 2. Merge the rebrand branch to main

Pages serves from a branch here - there is no Actions workflow and the default
branch is `main`. The rebrand is not live until it is on `main`, and the
`CNAME` file is what tells Pages which host to answer for.

Branch: `claude/union-wah-luen-rebrand-xinrkv`

### 3. Wait for the TLS certificate before proxying anything

The step people trip on. While a record is proxied, GitHub's ACME HTTP-01
challenge cannot complete, so the certificate is never issued and **Enforce
HTTPS stays greyed out** in Pages settings.

1. Keep `wahluenlocksmiths.sg` grey-cloud / DNS-only
2. Repo Settings > Pages, confirm the custom domain shows and the DNS check passes
3. Wait for the certificate (minutes to about an hour)
4. Tick **Enforce HTTPS**
5. Only then, if you want Cloudflare in front, switch to orange cloud with SSL
   mode **Full (strict)**

Verify apex and www, http and https, and no mixed content.

### 4. Mailbox live before any traffic arrives

`admin@wahluenlocksmiths.sg` is on all seven pages. Send **and** receive a real
test message. Set `admin@unionlocksmiths.sg` to forward for twelve months -
enquiries will keep arriving there long after cutover.

### 5. Redirect unionlocksmiths.sg

Only now. The new site must already be verified and serving.

1. Add `unionlocksmiths.sg` to Cloudflare if it is not there, and move the
   nameservers at the registrar
2. Set apex and `www` records to **proxied (orange cloud)**. The origin behind
   them is irrelevant once proxied - the redirect fires at the edge before
   origin is consulted - but records must exist for the rule to attach to
3. Remove the GitHub Pages A records, or the domain keeps trying to reach a
   Pages site that no longer answers for it
4. Rules > Redirect Rules > Create rule, exactly as §1 above:
   - expression `(http.host eq "unionlocksmiths.sg") or (http.host eq "www.unionlocksmiths.sg")`
   - dynamic target `concat("https://wahluenlocksmiths.sg", http.request.uri.path)`
   - **301**, preserve query string **on**

One rule covers all seven pages and every asset, because the paths are
identical on both domains.

### 6. Redirect wahluen.sg

Separate zone, so a **separate rule** - the step 5 expression does not match it.
Same dynamic target, same 301, same preserve-query-string.

If the domain turns out not to be registered, register it before publicising
the name anywhere. See the open question below.

### 7. Verify before telling Google

    ./meta/verify-redirects.sh

Requires **zero FAIL**. It now tests all four old hosts across both schemes.
A green run here is the gate for step 8 - not the other way round.

### 8. Search Console and the rest

1. Verify the new property for `wahluenlocksmiths.sg`
2. Change of Address on the old property, pointing at the new one
3. Submit `https://wahluenlocksmiths.sg/sitemap.xml`, request indexing on all
   seven pages
4. Google Business Profile: business name and website URL
5. Update the ads account destination URLs before any spend resumes
6. Tell Kenneth

## Blockers that sit with Kenneth, not with the build

- **`wahluen.sg` has no DNS at all**, which may mean it is not registered.
  He is describing it publicly as a domain that will redirect. Given this
  rebrand is trademark-driven, an unregistered domain being associated with the
  brand is worth settling with the registrar this week, not at cutover.
- **`unionlocksmiths.sg` auto-renew is OFF, due 26 Sep 2026.** After step 5 the
  redirects live on that zone. If it lapses, every 301 dies and the domain goes
  to whoever wants it. Renew for two years **before** cutover.
- **The logo PNG is still the old Union artwork** under a new filename. See
  "Still open with Kenneth" above.
- **Phone number** still unresolved. See §4.

## Rollback

After step 5, rollback is disabling the redirect rule and repointing
`unionlocksmiths.sg` at the GitHub Pages IPs - but that only restores the old
site if `main` still has Union content, which after step 2 it does not. Real
rollback is `git revert` of the rebrand merge plus reverting `CNAME`, then
waiting on a fresh certificate. Treat step 2 as the point of no easy return and
make sure steps 1, 3 and 4 are genuinely green before taking it.
