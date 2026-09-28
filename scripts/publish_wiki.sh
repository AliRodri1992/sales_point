#!/bin/bash

set -euo pipefail

# ==========================================
# Delta POS - Publish docs/ to GitHub Wiki
# ==========================================

REPO_ROOT="$(git rev-parse --show-toplevel)"
DOCS_DIR="$REPO_ROOT/docs"
WIKI_DIR="${TMPDIR:-/tmp}/sales_point.wiki"

WIKI_REPO="https://github.com/AliRodri1992/sales_point.wiki.git"

echo "=========================================="
echo " Delta POS - GitHub Wiki Publisher"
echo "=========================================="

# ------------------------------------------
# Validate docs/
# ------------------------------------------

if [ ! -d "$DOCS_DIR" ]; then
  echo "ERROR: No existe la carpeta:"
  echo "$DOCS_DIR"
  exit 1
fi

# ------------------------------------------
# Clone or update Wiki
# ------------------------------------------

if [ -d "$WIKI_DIR/.git" ]; then
  echo ""
  echo "Actualizando repositorio de la Wiki..."

  git -C "$WIKI_DIR" fetch origin
  git -C "$WIKI_DIR" pull --rebase origin master 2>/dev/null \
    || git -C "$WIKI_DIR" pull --rebase origin main
else
  echo ""
  echo "Clonando GitHub Wiki..."

  rm -rf "$WIKI_DIR"

  git clone "$WIKI_REPO" "$WIKI_DIR"
fi

# ------------------------------------------
# Synchronize Markdown files
# ------------------------------------------

echo ""
echo "Sincronizando docs/ -> GitHub Wiki..."

find "$DOCS_DIR" -type f -name "*.md" -print0 |
while IFS= read -r -d '' file; do
  relative_path="${file#$DOCS_DIR/}"
  destination="$WIKI_DIR/$relative_path"

  mkdir -p "$(dirname "$destination")"

  cp "$file" "$destination"

  echo "  ✓ $relative_path"
done

# ------------------------------------------
# Show changes
# ------------------------------------------

echo ""
echo "Cambios detectados:"
echo "------------------------------------------"

git -C "$WIKI_DIR" status --short

# ------------------------------------------
# Check whether there are changes
# ------------------------------------------

if git -C "$WIKI_DIR" diff --quiet && \
   [ -z "$(git -C "$WIKI_DIR" status --porcelain)" ]; then

  echo ""
  echo "La Wiki ya está actualizada."
  exit 0
fi

# ------------------------------------------
# Commit
# ------------------------------------------

echo ""
echo "Creando commit..."

git -C "$WIKI_DIR" add "*.md" 2>/dev/null || true
git -C "$WIKI_DIR" add -A

git -C "$WIKI_DIR" commit \
  -m "docs: synchronize Wiki with project documentation"

# ------------------------------------------
# Push
# ------------------------------------------

echo ""
echo "Publicando en GitHub..."

CURRENT_BRANCH="$(git -C "$WIKI_DIR" branch --show-current)"

if [ -z "$CURRENT_BRANCH" ]; then
  CURRENT_BRANCH="master"
fi

git -C "$WIKI_DIR" push origin "$CURRENT_BRANCH"

echo ""
echo "=========================================="
echo " Wiki publicada correctamente"
echo "=========================================="
echo ""
echo "Repositorio:"
echo "$WIKI_REPO"
echo ""
