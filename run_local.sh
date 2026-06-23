#!/usr/bin/env bash
# Run the blog locally on http://localhost:4001
#
# Chirpy requires Ruby 3.0+. macOS system Ruby (2.6) doesn't cut it, so this
# script uses the official ruby:3.3-slim Docker image. On first run it does a
# full `bundle install` inside the container (a few minutes); subsequent runs
# reuse the cache in .bundle/ and start in seconds.
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
      --livereload-port 35729
  '
