#!/usr/bin/env bash
# Re-sync one vendored YouTube library at a pinned upstream revision.
# Usage: scripts/update-vendored-youtube.sh streams|api <git-revision>
set -euo pipefail

usage="usage: $0 streams|api <git-revision>"
case "${1:-}" in
  streams) repo=https://github.com/alexeichhorn/YouTubeKit.git; target=YouTubeStreams ;;
  api) repo=https://github.com/b5i/YouTubeKit.git; target=YouTubeAPI ;;
  *) echo "$usage" >&2; exit 64 ;;
esac
revision=${2:?$usage}

root=$(cd "$(dirname "$0")/.." && pwd)
dest="$root/Packages/WhyTeaYouTube/Sources/$target"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

git clone --quiet "$repo" "$work/upstream"
git -C "$work/upstream" checkout --quiet "$revision"

cp "$dest/UPSTREAM.md" "$work/UPSTREAM.md"
rm -rf "$dest"
mkdir -p "$dest"
cp -R "$work/upstream/Sources/YouTubeKit/." "$dest/"
cp "$work/upstream/LICENSE" "$dest/LICENSE"
cp "$work/UPSTREAM.md" "$dest/UPSTREAM.md"

# Both upstream modules are named YouTubeKit; b5i qualifies a few of its own
# types with the module name.
if [[ $target == YouTubeAPI ]]; then
  find "$dest" -name '*.swift' -exec sed -i '' -E 's/YouTubeKit\.([A-Z])/YouTubeAPI.\1/g' {} +
fi

echo "Synced $target to $(git -C "$work/upstream" rev-parse HEAD)."
echo "Next: update the revision in $target/UPSTREAM.md, then run the package tests and the live bake-off."
