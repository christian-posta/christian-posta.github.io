#!/usr/bin/env bash
# Run the blog locally on http://localhost:4001
#
# Chirpy requires Ruby 3.0+. macOS system Ruby (2.6) doesn't cut it, so this
# script uses the official ruby:3.3-slim Docker image. On first run it does a
# full `bundle install` inside the container (a few minutes); subsequent runs
# reuse the cache in the blog-bundle volume and start in seconds.
#
# .bundle/, _site/, and .jekyll-cache/ are mounted as named Docker volumes
# instead of host bind-mounts: Docker Desktop's bind-mount I/O (osxfs/gRPC-FUSE)
# is slow enough on macOS that full rebuilds were taking 70-85s, which looked
# like edits weren't being picked up. Only source files (_posts, _includes,
# etc.) are bind-mounted from the host; --force_polling is still needed for
# Jekyll to notice those via mtime polling since inotify doesn't cross the
# bind-mount boundary. --incremental limits rebuilds to changed files.
#
# If you'd rather run on a native Ruby 3 toolchain (rbenv/rvm/asdf):
#     bundle install
#     bundle exec jekyll serve --livereload
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTAINER_NAME="blog-serve"

# Stop any previous instance
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

echo "Starting Jekyll/Chirpy on http://localhost:4001 (livereload: 35729)"
echo "First run installs gems; this can take a few minutes."

docker run --rm -it \
  --name "$CONTAINER_NAME" \
  -v "$PROJECT_DIR:/srv/jekyll" \
  -v blog-bundle:/srv/jekyll/.bundle \
  -v blog-site:/srv/jekyll/_site \
  -v blog-jekyll-cache:/srv/jekyll/.jekyll-cache \
  -p 4001:4000 \
  -p 35729:35729 \
  -e JEKYLL_ENV=development \
  ruby:3.3-slim \
  bash -c '
    set -e
    if ! command -v git >/dev/null; then
      apt-get update -qq && apt-get install -y -qq build-essential git nodejs >/dev/null
    fi
    cd /srv/jekyll
    bundle config set --local path /srv/jekyll/.bundle
    bundle install
    bundle exec jekyll serve \
      --host 0.0.0.0 \
      --port 4000 \
      --livereload \
      --livereload-port 35729 \
      --force_polling \
      --incremental
  '
