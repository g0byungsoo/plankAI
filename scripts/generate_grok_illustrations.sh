#!/bin/bash
# Generate 5 JeniFit illustrations via Grok Imagine API.
# Prompts from docs/her75_design_extraction_2026_06_10.md §7.

set -euo pipefail

cd "$(dirname "$0")/.."

KEY=$(grep '^GROK_IMAGINE_API_KEY=' .env | cut -d= -f2-)
[ -z "$KEY" ] && { echo "GROK_IMAGINE_API_KEY missing from .env" >&2; exit 1; }

OUT_DIR="generated_illustrations"
mkdir -p "$OUT_DIR"

STYLE_SUFFIX=". Photorealistic 3D glossy sticker render, gummy iridescent satin finish, sub-surface scattering, soft warm-rose key light at 30 degrees, no shadow on the asset itself, isolated subject floating on a flat pink-cream #FDF6F4 background, square 1:1 framing, sticker bleeds 6% off the bottom-right at a +5 degree tilt, tiny film-grain overlay 2%, dusty rose #C4677A accent highlights only, no other colors saturated, no text, no logo, no people, no faces, no hands. Coquette y2k editorial mood. Tactile, candy-like, premium. 2048x2048."

PROMPT_goal="A single glossy 3D heart-shaped padlock charm rendered in dusty rose satin, with a tiny gold key suspended mid-air just above it on an invisible thread, both elements floating dead-center. The padlock has a subtle bow ribbon detail tied around its top loop. Reads as committing to yourself, sealing in the intention - the visual shorthand for setting a goal that's been made deliberate, not casual"

PROMPT_social_proof="A loose huddle of three glossy 3D iridescent bows (pearl, blush, dusty rose) overlapping slightly at their knot-centers like friends standing shoulder-to-shoulder, each bow at a slightly different tilt and scale (largest bow center, smaller bows flanking). No people, but the composition reads unmistakably as three friends together. Each bow has a tiny pearl detail in its knot"

PROMPT_future_self="A single glossy 3D mirror compact (round, satin-rose case, partially open at a 30 degree angle), with the open mirror surface catching a soft iridescent reflection - not a face, just a swirl of dusty-pink and pearl light suggesting future self. The closed half of the compact has a tiny embossed bow detail on its lid. Reads as the version of you that's already on its way"

PROMPT_ritual="A single glossy 3D perfume bottle in dusty-rose satin glass with a pearlescent rounded stopper, sitting upright dead-center. A thin iridescent ribbon is loosely tied around the bottle's neck, trailing down to one side. The bottle has no label. Reads as the small daily ritual - something you reach for at the same time every day"

PROMPT_celebration="A cluster of glossy 3D iridescent objects floating in a loose arrangement: one center disco ball (palm-sized, pearl-finish), two small 3D sparkle stars in dusty rose flanking it, one heart-shaped charm in satin blush, and one tiny iridescent bow at the bottom-right. Objects orbit the disco ball at varying depths with mild parallax, all floating, no ground. Reads as the moment you actually arrive"

generate_one() {
  local name="$1"
  local prompt_var="PROMPT_${name}"
  local prompt="${!prompt_var}"
  local out_path="$OUT_DIR/$name.jpg"
  local json_path="$OUT_DIR/${name}_response.json"

  local full_prompt="${prompt}${STYLE_SUFFIX}"

  local body
  body=$(jq -n --arg p "$full_prompt" '{model:"grok-imagine-image-quality",prompt:$p,n:1,response_format:"b64_json"}')

  curl -s -X POST https://api.x.ai/v1/images/generations \
    -H "Authorization: Bearer $KEY" \
    -H "Content-Type: application/json" \
    -d "$body" \
    > "$json_path"

  if jq -e '.data[0].b64_json' "$json_path" > /dev/null 2>&1; then
    jq -r '.data[0].b64_json' "$json_path" | base64 -d > "$out_path"
    local size
    size=$(stat -f%z "$out_path" 2>/dev/null || stat -c%s "$out_path")
    echo "[ok] $name ($((size/1024))KB) -> $out_path"
    rm -f "$json_path"
  else
    echo "[fail] $name -- response:" >&2
    head -c 500 "$json_path" >&2
    echo "" >&2
    return 1
  fi
}

# Fan out 5 backgrounded calls, wait for all
for name in goal social_proof future_self ritual celebration; do
  generate_one "$name" &
done

wait

echo ""
echo "Done. Files in $OUT_DIR/"
ls -lh "$OUT_DIR/" | grep -v _response
