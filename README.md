# Christian Posta — Blog

Source for [blog.christianposta.com](https://blog.christianposta.com).

Built with [Jekyll](https://jekyllrb.com/) using the
[Chirpy](https://github.com/cotes2020/jekyll-theme-chirpy) theme. Deployed via
GitHub Pages from the `master` branch.

---

## Run locally

The theme requires **Ruby 3.0+**. macOS system Ruby (2.6) is too old, so the
default flow uses Docker:

```bash
./run_local.sh
```

That starts a containerized Jekyll on **http://localhost:4001** with
LiveReload. First run takes a few minutes (gem install); subsequent runs are
fast because the bundle is cached in `.bundle/`.

If you'd rather use a native Ruby 3 toolchain (rbenv / rvm / asdf):

```bash
bundle install
bundle exec jekyll serve --livereload
```

---

## Write a new post

```bash
./new_post.sh "Your Post Title Here"
```

That creates `_posts/YYYY-MM-DD-your-post-title-here.md` with Chirpy front
matter (title, date, categories, tags, description, optional mermaid + image
blocks). If `$EDITOR` is set, it opens the file too.

### Front matter cheat sheet

```yaml
---
title: "My Post"
date: 2026-05-19T10:00:00Z
categories: [AI Agents, Identity]   # 1–2 categories, broad
tags: [mcp, oauth, agents]          # 3–6 lower-case tags
description: One-line summary used in SEO + post list excerpt.
mermaid: true                       # only if you embed ```mermaid blocks
image:
  path: /images/foo/bar.png
  alt: Short description
pin: true                           # pin to top of homepage
---
```

Images live in `/images/` (root). Reference with absolute paths like
`/images/foo/bar.png`.

---

## Project layout

| Path | Purpose |
|---|---|
| `_config.yml` | Site config: title, URL, GA ID, giscus, social, theme settings |
| `_posts/` | Blog posts (`.md`, dated-prefix filename) |
| `_tabs/` | Sidebar nav pages: Agent Identity, Categories, Tags, Archives, About |
| `_includes/sidebar.html` | Override of theme sidebar (LinkedIn CTA + Agent Identity star) |
| `_includes/update-list.html` | Override: right-rail "Most popular" panel |
| `_layouts/home.html` | Override: adds the "Agent Identity Series" featured panel |
| `_data/popular.yml` | Curated list driving the "Most popular" sidebar panel |
| `_data/contact.yml` | Social icons in the sidebar footer |
| `assets/css/jekyll-theme-chirpy.scss` | Custom SCSS overrides |
| `images/` | All post images |
| `run_local.sh` | Docker-based local dev server |
| `new_post.sh` | Scaffold a new post |

---

## Customizations on top of Chirpy

- URL permalink set to `/:title/` (preserves the previous Minimal Mistakes
  URL structure — important for SEO and inbound links).
- LinkedIn "Connect" CTA pinned under the avatar in the sidebar.
- "Agent Identity Series" featured panel on the homepage, linking to the
  external AAuth and Entra Agent ID series sites.
- Sidebar nav highlights the **Agent Identity** tab.
- Right-rail panel renamed from Chirpy's auto "Recently Updated" to a
  hand-curated "Most popular" list driven by `_data/popular.yml`.

---

## Comments (giscus)

Comments are configured for [giscus](https://giscus.app/) against the
`christian-posta/christian-posta.github.io` repo. To activate them in
production, complete these one-time steps on the GitHub repo:

1. Settings → Features → enable **Discussions**.
2. Install the [giscus GitHub App](https://github.com/apps/giscus) and grant
   it access to this repo.
3. Go to https://giscus.app, paste the repo path, pick a Discussions category
   (e.g. "Announcements"), and copy the generated `data-repo-id` and
   `data-category-id` values.
4. Paste them into `_config.yml` under `comments.giscus.repo_id` and
   `comments.giscus.category_id`.

Until those IDs are filled in, every post will show *"giscus is not installed
on this repository"* — that's expected.

The previous Disqus comment history does **not** migrate to giscus.

---

## Analytics

Google Analytics 4 (property `G-P7J87BW4XK`) is wired in via
`_config.yml → analytics.google.id`. The tag only emits in production builds
(`JEKYLL_ENV=production`).
