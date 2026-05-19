#!/usr/bin/env bash
# Scaffold a new blog post in Chirpy format.
#
# Usage:   ./new_post.sh "Your Post Title Here"
# Result:  _posts/YYYY-MM-DD-your-post-title-here.md  (opened in $EDITOR if set)
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 \"Post Title\"" >&2
  exit 1
fi

TITLE="$*"
DATE="$(date +%Y-%m-%d)"
DATETIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Slugify: lowercase, non-alnum -> '-', collapse and trim '-'
SLUG="$(printf '%s' "$TITLE" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')"

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
FILE="$PROJECT_DIR/_posts/${DATE}-${SLUG}.md"

if [[ -e "$FILE" ]]; then
  echo "File already exists: $FILE" >&2
  exit 1
fi

cat > "$FILE" <<EOF
---
title: "${TITLE}"
date: ${DATETIME}
categories: []
tags: []
description:
# Uncomment if this post includes Mermaid diagrams:
# mermaid: true
# Uncomment to add a feature image:
# image:
#   path: /images/path/to/image.png
#   alt: Description of the image
---

Write your post here.
EOF

echo "Created: $FILE"

if [[ -n "${EDITOR:-}" ]]; then
  "$EDITOR" "$FILE"
fi
