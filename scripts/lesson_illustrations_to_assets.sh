#!/usr/bin/env bash
# Convert lesson_illustrations/*.jpg into Asset Catalog imagesets so
# SwiftUI's `Image("lesson_d1_hero")` can load them. Idempotent — each
# imageset is regenerated from the source jpg on every run, so re-running
# after a regeneration pass picks up the new image.
#
# Source:      PlankApp/Resources/lesson_illustrations/*.jpg
# Destination: PlankApp/Assets.xcassets/<name>.imageset/{Contents.json, <name>.jpg}

set -euo pipefail

SRC_DIR="PlankApp/Resources/lesson_illustrations"
DST_DIR="PlankApp/Assets.xcassets"

cd "$(dirname "$0")/.."

if [[ ! -d "$SRC_DIR" ]]; then
    echo "missing $SRC_DIR" >&2; exit 1
fi

added=0
# Phase 9.13: PNG takes precedence over JPG for the same stem name —
# the chroma-keyed character illustrations ship as transparent PNG,
# everything else stays JPG. We process PNG first; the JPG pass skips
# any stem that already has a transparent PNG counterpart present in
# Resources. macOS ships bash 3.2 (no associative arrays), so we use
# stem-presence as the dedupe signal instead of an array.
for ext in png jpg; do
    for src in "$SRC_DIR"/*."$ext"; do
        [[ -e "$src" ]] || continue
        name="$(basename "$src" ".$ext")"
        # Skip JPG if a PNG counterpart exists for this stem.
        if [[ "$ext" == "jpg" && -f "$SRC_DIR/${name}.png" ]]; then
            continue
        fi
        imageset="$DST_DIR/${name}.imageset"
        mkdir -p "$imageset"
        # Wipe any stale opposite-extension copy from a previous run.
        rm -f "$imageset/${name}.jpg" "$imageset/${name}.png"
        cp -f "$src" "$imageset/${name}.${ext}"
        cat > "$imageset/Contents.json" <<EOF
{
  "images" : [
    { "idiom" : "universal", "filename" : "${name}.${ext}", "scale" : "1x" },
    { "idiom" : "universal", "scale" : "2x" },
    { "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF
        added=$((added + 1))
    done
done

echo "wrote $added imagesets to $DST_DIR"
