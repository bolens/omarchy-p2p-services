#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
output_dir="$repo_root/_site"
version=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$repo_root/manifest.json")

rm -rf -- "$output_dir"
cp -R -- "$repo_root/docs" "$output_dir"
cp -- "$repo_root/manifest.json" "$output_dir/manifest.json"
sed -i "s/__PLUGIN_VERSION__/$version/g" "$output_dir/index.html"
