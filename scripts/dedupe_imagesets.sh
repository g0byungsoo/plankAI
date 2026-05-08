#!/usr/bin/env bash
# Deduplicate imagesets that ship identical 1x/2x/3x PNGs.
# Keeps only the @3x file + updates Contents.json to reference it as @3x.
# No visual change — modern iPhones use @3x anyway, and the dropped files
# were byte-identical to the kept one.
#
# Usage: bash Scripts/dedupe_imagesets.sh
# Idempotent — only deduplicates imagesets where all PNGs hash identical.

set -euo pipefail

ASSETS_DIR="$(cd "$(dirname "$0")/../PlankApp/Assets.xcassets" && pwd)"
total_saved=0

for d in "$ASSETS_DIR"/*.imageset; do
    name=$(basename "$d" .imageset)
    pngs=("$d"/*.png)
    [[ ! -f "${pngs[0]}" ]] && continue
    [[ ${#pngs[@]} -lt 2 ]] && continue

    # Confirm all PNGs in the set are identical
    distinct=$(md5 -q "${pngs[@]}" | sort -u | wc -l | tr -d ' ')
    if [[ "$distinct" -ne 1 ]]; then
        continue
    fi

    # Pick one to keep — prefer the file referenced as @3x in Contents.json.
    keep=$(python3 -c "
import json, os, sys
with open('$d/Contents.json') as f:
    data = json.load(f)
for img in data.get('images', []):
    if img.get('scale') == '3x':
        print(img['filename'])
        sys.exit(0)
print(data['images'][0]['filename'])
")

    before=$(du -sk "$d" | cut -f1)

    # Rename the kept file to a clean name (drop temp_image_<uuid>... clutter)
    clean_name="${name}.png"
    if [[ "$keep" != "$clean_name" ]]; then
        mv "$d/$keep" "$d/$clean_name"
    fi

    # Delete every other PNG
    for png in "$d"/*.png; do
        if [[ "$(basename "$png")" != "$clean_name" ]]; then
            rm "$png"
        fi
    done

    # Rewrite Contents.json to a single @3x entry
    cat > "$d/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "$clean_name",
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

    after=$(du -sk "$d" | cut -f1)
    saved=$((before - after))
    total_saved=$((total_saved + saved))
    echo "[dedupe] $name: ${before}K → ${after}K (saved ${saved}K)"
done

echo "[dedupe] total saved: ${total_saved}K (~$((total_saved / 1024))MB)"
