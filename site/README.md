# Quarters — marketing site

Static site for [GitHub Pages](https://pages.github.com). No build step, no dependencies
(fonts load from Google Fonts).

```
index.html    the page
styles.css    all styles + design tokens (Warm Mint, light + dark)
```

## Deploy

**Option A — dedicated repo**
1. Create a repo (e.g. `quarters-site`), put `index.html` and `styles.css` at the root.
2. Repo → Settings → Pages → Source: *Deploy from a branch* → `main` / `/ (root)`.
3. Site appears at `https://<user>.github.io/quarters-site/`.

**Option B — inside your app repo**
1. Put both files in a `docs/` folder on `main`.
2. Settings → Pages → Source: `main` / `/docs`.

Custom domain: add a `CNAME` file containing the domain, then configure DNS per GitHub's docs.

The "Download for Mac" buttons currently link to `#` — point them at your release
(`https://github.com/<user>/<repo>/releases/latest`) when ready.
