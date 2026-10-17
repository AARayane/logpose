#!/usr/bin/env bash
# Bump helium.nix to imputnet's latest release (CI runs this daily). Needs curl, jq, nix.
set -euo pipefail

ROOT="${1:-.}"
f="$ROOT/helium.nix"
[ -f "$f" ] || { echo "update-helium: $f not found" >&2; exit 1; }

api="https://api.github.com/repos/imputnet/helium-linux/releases/latest"
latest=$(curl -fsSL "$api" | jq -r .tag_name)
[ -n "$latest" ] && [ "$latest" != "null" ] || { echo "update-helium: couldn't resolve latest release" >&2; exit 1; }
cur=$(sed -nE 's/^[[:space:]]*version = "([^"]+)";.*/\1/p' "$f" | head -1)

if [ "$latest" = "$cur" ]; then
  echo "helium: already latest ($cur)"
  exit 0
fi
echo "helium: $cur -> $latest"

declare -A arches=( [x86_64-linux]=x86_64 )
for sys in x86_64-linux; do
  a="${arches[$sys]}"
  url="https://github.com/imputnet/helium-linux/releases/download/$latest/helium-$latest-$a.AppImage"
  printf '  prefetch %s ... ' "$sys"
  h=$(nix store prefetch-file --json "$url" | jq -r .hash)
  echo "$h"
  sed -i.bak -E "s|(\"$sys\" = \")sha256-[^\"]*(\";)|\1$h\2|" "$f"
done
sed -i.bak -E "s|(version = \")[^\"]*(\";)|\1$latest\2|" "$f"
rm -f "$f.bak"
echo "helium: bumped to $latest — review & commit $f"
