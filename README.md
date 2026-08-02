# wahluenlocksmiths.sg

Live static site for Wah Luen Locksmiths (Singapore), served via GitHub Pages.
Originally recovered from the Wayback Machine and rebuilt per client feedback
(Kenneth, Jul 2026), then rebranded from Union Locksmiths in Aug 2026.

## This repo is now the source of truth

It used to be build output. It is not any more.

The old workflow was: edit `~/Downloads/unionlocksmiths-recovery/`, run
`meta/build_site.py` then `meta/make_production.py`, copy `dist-production/`
here, push. **Do not do that.** That generator has no knowledge of the Wah Luen
rebrand, so running it would regenerate Union-branded pages and silently
overwrite this work — including the `/our-history/` rewrite, which was written
by hand and does not exist anywhere in the generator's inputs.

If the generator is ever brought back into use, its source templates must be
rebranded first and the history page ported into them by hand.

Edit the HTML and CSS in this repo directly.

## Domain

`CNAME` points at `wahluenlocksmiths.sg`. The old `unionlocksmiths.sg` domain
is handled by a Cloudflare 301 redirect rule on that zone — see `cutover.md`.
Renewing `unionlocksmiths.sg` keeps those redirects alive; if it lapses, every
301 dies with it.

## Cache-busting

`assets/css/style.css` is referenced with a `?v=` query string on every page.
It is the first 8 characters of the file's md5. If you edit the CSS, update it
on all seven pages, or returning visitors keep the old stylesheet. (`404.html`
links the stylesheet without a `?v=` and so needs no update.)

    NEW=$(md5sum assets/css/style.css | cut -c1-8)
    perl -pi -e "s/style\.css\?v=[0-9a-f]+/style.css?v=$NEW/g" \
      index.html */index.html
