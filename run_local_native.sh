#!/usr/bin/env bash
# Run the blog locally on http://localhost:4000 using a native Ruby 3.3.
#
# Uses Homebrew's keg-only ruby@3.3 (installed via `brew install ruby@3.3`),
# which is NOT linked into PATH globally and does not affect your default
# `ruby`/RVM setup. This script only prepends it to PATH for its own
# subshell, so it's fully scoped to this repo.
#
# Why native instead of run_local.sh (Docker)? Profiling showed Jekyll's
# build was spending ~90% of its time in the READ phase, not RENDER/WRITE:
# Docker Desktop's bind-mount forwards every file stat/read across the
# host<->VM boundary, and with ~6,400 files in this repo that overhead alone
# was costing 60+ seconds per rebuild. Running natively eliminates that
# entirely.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUBY_PREFIX="$(brew --prefix ruby@3.3)"

export PATH="$RUBY_PREFIX/bin:$PATH"
export GEM_HOME="$PROJECT_DIR/.gem-native"
export PATH="$GEM_HOME/bin:$PATH"

cd "$PROJECT_DIR"

echo "Using: $(ruby -v)"
gem install bundler --no-document --conservative >/dev/null
bundle config set --local path "$PROJECT_DIR/.bundle-native"
bundle install

echo "Starting Jekyll/Chirpy on http://localhost:4000 (livereload: 35729)"
bundle exec jekyll serve \
  --livereload \
  --livereload-port 35729 \
  --incremental
