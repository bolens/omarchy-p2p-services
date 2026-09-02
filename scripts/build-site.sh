#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
output_dir="$repo_root/_site"
python3 "$repo_root/scripts/render-changelog.py" --name "Omarchy P2P Services" --base-url https://bolens.github.io/omarchy-p2p-services/ --accent "#a6e3a1" --source "$repo_root/CHANGELOG.md" --output "$repo_root/docs/changelog/index.html"
version=${SITE_RELEASE_VERSION:-$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$repo_root/manifest.json")}
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]] || { echo "invalid site release version: $version" >&2; exit 1; }

rm -rf -- "$output_dir"
cp -R -- "$repo_root/docs" "$output_dir"
cp -- "$repo_root/manifest.json" "$output_dir/manifest.json"
sed -i "s/__PLUGIN_VERSION__/$version/g" "$output_dir/index.html"
