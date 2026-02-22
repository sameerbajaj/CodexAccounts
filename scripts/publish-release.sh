#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <tag> [--attach-now]"
  echo "Example: $0 v1.0.1"
  echo "Example: $0 v1.0.1 --attach-now"
  exit 1
fi

TAG="$1"
ATTACH_NOW="false"

if [[ "${2:-}" == "--attach-now" ]]; then
  ATTACH_NOW="true"
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is not installed."
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "You are not logged into gh. Run: gh auth login"
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Working tree has uncommitted changes. Commit or stash before releasing."
  exit 1
fi

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "Tag $TAG already exists locally."
else
  git tag "$TAG"
  echo "Created tag: $TAG"
fi

git push origin "$TAG"

gh release create "$TAG" --title "$TAG" --generate-notes

echo "Published release: $TAG"
echo "GitHub Actions will now build and attach the DMG automatically."

if [[ "$ATTACH_NOW" == "true" ]]; then
  ./scripts/build-dmg.sh "$TAG"
  gh release upload "$TAG" "dist/CodexAccounts-$TAG.dmg" --clobber
  echo "Attached local DMG immediately: dist/CodexAccounts-$TAG.dmg"
fi
