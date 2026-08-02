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
| `wahluenlocksmiths.sg` | `103.11.189.189` | Registered at **Vodien**, on Vodien shared hosting |
| `wahluen.sg` | *no answer* | No DNS records; may not be registered |

`wahluenlocksmiths.sg` is **not** on Cloudflare. Its nameservers are
`ns1/ns2.vodien.com`. Those nameservers happen to answer from Cloudflare IP
space (`162.159.x`, `2400:cb00:`) because Vodien runs its DNS on Cloudflare's
platform - that is Vodien's arrangement, not an account you control, and it
gives you **no** access to Redirect Rules on this zone. Do not mistake it for
the domain already being "on Cloudflare".

Re-check these before starting; they may have moved.

## Two constraints that drive the whole order

**Cloudflare Redirect Rules only fire on proxied traffic.** They run at
Cloudflare's edge. A DNS-only (grey cloud) record means Cloudflare answers the
lookup and traffic goes straight to origin, so no rule ever executes.
**Confirmed 02 Aug 2026:** `unionlocksmiths.sg` is on Cloudflare with Full DNS
setup, but every record is grey cloud - which is why it returns GitHub's real
IPs. The §1 rule would not have fired. Fix is a per-record toggle, not a
migration. See step 5.

**A GitHub Pages site answers for exactly one custom domain** - whatever is in
`CNAME`. Once that file says `wahluenlocksmiths.sg`, Pages no longer recognises
`unionlocksmiths.sg`. If that domain is still pointed at GitHub's IPs at that
moment, every old URL returns a **GitHub 404, not a 301**. That is the worst
outcome available: link equity lost and no path to the new site.

So `unionlocksmiths.sg` must stop pointing at GitHub in the same change that
starts pointing it at something that redirects. Do not merge to `main` before
step 5 is staged and ready to enable.

## The unavoidable window, and how small it can be

A Pages site cannot serve both domains at once, so there is no arrangement where
the old domain keeps working right up until the new one is fully live. There are
two gaps. Plan for them rather than being surprised:

**Gap 1: old URLs dark.** Between the merge (step 2) and enabling the redirect
(step 5), `unionlocksmiths.sg` returns a GitHub 404. If the rule is pre-created
and disabled, and the proxy toggle is ready, this is **under two minutes**.
Staging step 5 in advance is what makes it two minutes instead of twenty.

**Gap 2: new domain without HTTPS.** GitHub issues the certificate for
`wahluenlocksmiths.sg` only once `CNAME` names it - which is the merge itself.
Issuance takes minutes to about an hour. During that time the redirect is
sending people to an `https://` URL that has no valid certificate yet, so they
get a browser warning. This is the worse of the two gaps.

Two ways to close gap 2, pick one:

- **Wait it out.** Merge at a genuinely quiet hour, watch Pages settings until
  the certificate issues and *Enforce HTTPS* unlocks, and only then enable the
  redirect. Old URLs 404 for that whole period, so gap 1 grows to match. Simple,
  no extra moving parts, and for a seven-page site with low direct traffic this
  is usually the right trade.
- **Proxy the new domain too.** Put `wahluenlocksmiths.sg` on Cloudflare orange
  cloud with SSL mode **Full**. Cloudflare's Universal SSL terminates TLS at the
  edge immediately, so HTTPS works from the first request regardless of GitHub's
  certificate. Closes gap 2 to nothing. Cost: Cloudflare is now permanently in
  the path, and you cannot use Full (strict) until GitHub's origin certificate
  exists.

Do not merge on a Friday.

## Steps

Do not reorder. A day or two ahead, drop TTLs on all three zones to 300s so a
mistake is minutes to undo rather than hours.

### 1. Point wahluenlocksmiths.sg at GitHub Pages

**Resolved 02 Aug 2026:** `103.11.189.189` is a **Vodien shared hosting** box.
The zone is managed in Vodien's own DNS panel (Domain > DNS Settings), and
carries Vodien's default hosting template:

| Sub domain | Type | Content | Keep? |
|---|---|---|---|
| `wahluenlocksmiths.sg` | A | `103.11.189.189` | **CHANGE** -> GitHub Pages |
| `www` | CNAME | `wahluenlocksmiths.sg` | Keep |
| `mail` | A | `103.11.189.189` | **KEEP - this is the mailbox** |
| `wahluenlocksmiths.sg` | MX (prio 0) | `mail.wahluenlocksmiths.sg` | **KEEP** |
| `*` (wildcard) | A | `103.11.189.189` | Remove, see below |
| `ftp` | CNAME | `wahluenlocksmiths.sg` | Remove if unused |
| `localhost` | A | `127.0.0.1` | Harmless, ignore |

**The apex A record is the only web record that must change.** Replace
`103.11.189.189` with the four GitHub Pages addresses:

    185.199.108.153
    185.199.109.153
    185.199.110.153
    185.199.111.153

Optional AAAA: `2606:50c0:8000::153`, `8001::153`, `8002::153`, `8003::153`.

If Vodien's panel will not accept four A records on one name, that is a blocker
worth a Live Chat ticket - GitHub publishes all four for redundancy and a single
address is a single point of failure.

`www` is a CNAME to the apex, which resolves to the Pages IPs and sends
`Host: www.wahluenlocksmiths.sg`. Pages handles that correctly, so it can stay
as is. Pointing it at `heylead-martin.github.io` instead is equally fine.

**Do not touch `mail` or the MX record.** They point at the Vodien box and are
what will carry `admin@wahluenlocksmiths.sg`. Repointing the apex does not
affect them, because MX resolves via the separate `mail.` A record rather than
the apex. This is exactly the case §5a warns about in reverse - here the mail
host is a distinct name, so the web move is safe.

**Remove the wildcard `*` A record** before cutover. It sends every
unrecognised subdomain to the Vodien box, so any typo or stale hostname lands
on hosting rather than failing cleanly - and it will quietly mask a
misconfigured subdomain later.

**Lower the TTLs first.** Every record is at `14400` (four hours). Drop the apex
to `300` at least a day ahead, or a mistake at cutover takes four hours to
undo rather than five minutes.

This zone is not on Cloudflare and **does not need to be** - the redirect work
all happens on the `unionlocksmiths.sg` zone. Leaving DNS at Vodien is the lower
risk option because the mail records stay where they are. The one thing
Cloudflare would buy you here is closing HTTPS gap 2 (see above); decide that
on its own merits, not by default.

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

**This is unblocked now and can run in parallel with everything else.** The MX
record already exists and already points at the Vodien hosting box, so the
mailbox can be created today in the Vodien control panel - it does not depend on
the web move, the merge, or the redirect. It is on the critical path for step 2,
so start it first.

### 5. Redirect unionlocksmiths.sg

**Confirmed 02 Aug 2026:** the zone is already on Cloudflare, DNS Setup **Full**
(nameservers delegated), free plan, 10 records. So there is **no nameserver
migration to do** - the only thing standing between this and a working redirect
is that every record is set to **DNS only**. That is why the §1 rule would not
have fired.

Current web records, all grey cloud:

| Name | Type | Content |
|---|---|---|
| `unionlocksmiths.sg` | A x4 | `185.199.108-111.153` (GitHub Pages) |
| `www` | CNAME | `heylead-martin.github.io` |

1. **Create the Redirect Rule first, disabled.** Rules > Redirect Rules, exactly
   as §1 above:
   - expression `(http.host eq "unionlocksmiths.sg") or (http.host eq "www.unionlocksmiths.sg")`
   - dynamic target `concat("https://wahluenlocksmiths.sg", http.request.uri.path)`
   - **301**, preserve query string **on**

   Staging it in advance means the switch in step 2 is two clicks, not two
   minutes of typing while the old URLs are dark.

2. **Then flip apex and `www` to Proxied (orange cloud)** and enable the rule.
   Once proxied, the rule fires at Cloudflare's edge before origin is consulted,
   so the GitHub Pages IPs behind the records become irrelevant.

**Leave the A records in place.** Do not delete them. They are harmless behind a
proxied record with a redirect rule in front, and keeping them means rollback is
"grey-cloud the records, disable the rule" rather than retyping four A records
from memory under pressure.

One rule covers all seven pages and every asset, because the paths are identical
on both domains.

### 5a. Do not touch the email records on this zone

The zone carries `_dmarc` (`v=DMARC1; p=reject`) and a `*._domainkey` DKIM
record, plus three more records below the fold in the console - almost certainly
MX and SPF. These are what make `admin@unionlocksmiths.sg` work, and §3 requires
that address to keep receiving for twelve months after cutover.

Proxying is an HTTP-layer feature and applies only to A, AAAA and CNAME records.
**MX and TXT records are unaffected by the orange cloud**, so step 5 does not put
mail at risk. But:

- Confirm the three hidden records before changing anything. If any MX points at
  the **apex hostname** rather than a mail provider's hostname, proxying the apex
  *would* break delivery. Uncommon, worth thirty seconds to rule out.
- **Do not delete this zone** after cutover. It holds both the redirects and the
  mail routing.

### 5b. Replicate the email security records on the new domain

Not previously listed anywhere, and **confirmed as a real gap** on 02 Aug 2026.

`unionlocksmiths.sg` has DMARC at `p=reject` plus a DKIM record.
`wahluenlocksmiths.sg` has **no SPF, no DKIM and no DMARC at all** - its Vodien
zone contains only the default A/CNAME/MX template.

That means the new domain is trivially spoofable, and outbound mail from it is
likely to land in spam from day one. A brand-new domain has no sending
reputation, so it is treated with suspicion by default; missing auth records
turn that suspicion into outright filtering. The business is about to publish
this address on all seven pages of a site whose entire purpose is inbound
enquiries.

Add to the Vodien zone as part of step 4:

- **SPF** - a TXT record authorising the Vodien mail host to send. Vodien
  support will give the correct value for the hosting plan; do not guess it.
- **DKIM** - enable signing in the Vodien mail panel, then publish the key it
  generates.
- **DMARC** - a `_dmarc` TXT record. Start at `p=none` with a reporting address
  so you can see what is actually sending, then tighten to `p=reject` to match
  the old domain once the reports are clean. Going straight to `p=reject` on an
  unproven config risks silently dropping legitimate mail.

Do this before the address goes live, not after the first lost enquiry.

### 6. Redirect wahluen.sg - DEFERRED

**Descoped 02 Aug 2026 by Martin.** Not part of this cutover. Nothing below
blocks on it and it can be picked up later without redoing any other step.

When it is picked up: separate zone means a **separate rule** - the step 5
expression does not match `wahluen.sg`. Same dynamic target, same 301, same
preserve-query-string. Check first whether the domain is registered at all; it
returned no DNS on 02 Aug 2026.

Kenneth has told at least one person that `wahluen.sg` will redirect to the new
site. Until this step is done, it will not. Worth telling him it is deferred
rather than leaving him to assume it works.

`verify-redirects.sh` still tests all four hosts, so it will report FAIL on the
two `wahluen.sg` rows until this is done. Expected - do not treat those two as
a launch blocker, but do not let them mask a real failure on the other rows
either.

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
- ~~**`unionlocksmiths.sg` auto-renew is OFF, due 26 Sep 2026.**~~ Auto-renew
  **enabled 02 Aug 2026** by Martin. Residual risk: auto-renew is a standing
  instruction, not a completed renewal - it still fails silently if the card on
  file expires or the registrar cannot charge it. Since the redirects live on
  this zone after step 5, and a lapse kills every 301 and releases the domain,
  an explicit multi-year renewal now is stronger than relying on the toggle
  firing correctly on 26 Sep. Confirm the payment method is current either way.
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
