#!/usr/bin/env bash
# build.sh — Convert all content/*.md and content/posts/*.md to docs/
# Requires: pandoc, bash 4+

set -euo pipefail

CONTENT="content"
OUT="docs"
TEMPLATE="template.html"
POSTS_DIR="$CONTENT/posts"
POSTS_OUT="$OUT/posts"

# ── sanity checks ─────────────────────────────────────────────────────────────

command -v pandoc >/dev/null 2>&1 || { echo "Error: pandoc not found" >&2; exit 1; }
[[ -f "$TEMPLATE" ]] || { echo "Error: $TEMPLATE not found" >&2; exit 1; }

mkdir -p "$OUT" "$POSTS_OUT"

# Copy static assets
cp style.css "$OUT/style.css"
[[ -f _colors.css ]] && cp _colors.css "$OUT/_colors.css" \
  || echo "Warning: _colors.css not found — run ./theme.sh first" >&2

# ── pandoc helper ─────────────────────────────────────────────────────────────

build_page() {
  local src="$1"       # e.g. content/index.md
  local dest="$2"      # e.g. docs/index.html
  local active="$3"    # active nav item for highlighting

  pandoc "$src" \
    --template="$TEMPLATE" \
    --from=markdown+yaml_metadata_block \
    --to=html5 \
    --standalone \
    --highlight-style=kate \
    --variable="active_${active}:true" \
    --output="$dest"

  echo "  built: $dest"
}

# ── static pages ──────────────────────────────────────────────────────────────

echo "Building pages..."
build_page "$CONTENT/index.md"    "$OUT/index.html"    "home"
# build_page "$CONTENT/projects.md" "$OUT/projects.html" "projects"
# build_page "$CONTENT/resume.md"   "$OUT/resume.html"   "resume"

# ── blog posts ────────────────────────────────────────────────────────────────

echo "Building posts..."

declare -a post_entries  # will hold "date|title|tags|url" per post

for src in "$POSTS_DIR"/*.md; do
  [[ -f "$src" ]] || continue

  filename=$(basename "$src" .md)
  dest="$POSTS_OUT/$filename.html"

  build_page "$src" "$dest" "blog"

  # Extract frontmatter fields for the index
  date=$(grep -m1 "^date:" "$src" | sed 's/date:[[:space:]]*//')
  title=$(grep -m1 "^title:" "$src" | sed 's/title:[[:space:]]*//')
  tags=$(grep -m1 "^tags:" "$src" | sed 's/tags:[[:space:]]*//')

  post_entries+=("${date}|${title}|${tags}|posts/${filename}.html")
done

# ── blog index ────────────────────────────────────────────────────────────────

echo "Building blog index..."

# Sort posts newest-first
IFS=$'\n' sorted=($(printf '%s\n' "${post_entries[@]}" | sort -r))
unset IFS

# Build the markdown for the index body
{
  echo "---"
  echo "title: Blog"
  echo "---"
  echo ""
  for entry in "${sorted[@]}"; do
    IFS='|' read -r date title tags url <<< "$entry"
    echo "### [$title]($url)"
    echo ""
    echo "<span class=\"post-meta\">\`$date\`  ·  $tags</span>"
    echo ""
  done
} | pandoc \
    --template="$TEMPLATE" \
    --from=markdown+yaml_metadata_block \
    --to=html5 \
    --standalone \
    --variable="active_blog:true" \
    --output="$OUT/blog.html"

echo "  built: $OUT/blog.html"
echo ""
echo "Done. Output in ./$OUT/"
