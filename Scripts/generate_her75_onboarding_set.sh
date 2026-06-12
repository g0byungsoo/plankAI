#!/bin/bash
# Onboarding v4.5 — her75-register editorial cutout set via Grok Imagine.
# Spec: docs/onboarding_v4_5_conversion_spec_2026_06_11.md
# Cream #FDF6F4 flat background = reads as transparent cutout on the
# app's bgPrimary (her75's white-on-white technique). Faces always
# obscured (Direction A amendment 2026-06-11).

set -uo pipefail

cd "$(dirname "$0")/.."

KEY=$(grep '^GROK_IMAGINE_API_KEY=' .env | cut -d= -f2-)
[ -z "$KEY" ] && { echo "GROK_IMAGINE_API_KEY missing from .env" >&2; exit 1; }

OUT_DIR="generated_illustrations/her75_set"
mkdir -p "$OUT_DIR"

STYLE=". Editorial luxury women's lifestyle magazine photography, Pinterest that-girl quiet-luxury aesthetic, warm natural golden-hour light, subtle 35mm film grain, soft muted warm tones, the subject perfectly isolated and centered on a completely flat seamless solid cream #FDF6F4 studio background that fills the entire frame edge to edge with zero props or environment behind the subject, no text, no logo, no watermark, face never visible (cropped above the eyes, or shoulders-down, or photographed from behind, or obscured by an arm or sunglasses), photorealistic, premium, calm, 1:1 square, 2048x2048."

# bash 3.2 (macOS default) has no associative arrays — PROMPT_<name>
# variables + indirect expansion, same pattern as generate_grok_illustrations.sh
PROMPT_welcome_stretch="A young woman in a matching cream ribbed knit athleisure set photographed FROM BEHIND mid-stretch with arms raised overhead, hair in a loose claw clip, elegant relaxed posture, back view only"
PROMPT_welcome_matcha="A woman's hand whisking bright green matcha in a ceramic bowl with a bamboo whisk, gold bracelet on the wrist, steam barely visible"
PROMPT_welcome_journal="An open linen-bound journal showing a neat handwritten weekly habit tracker grid with small checkmarks, a fountain pen resting across the page"
PROMPT_movement_sneakers="A woman's legs from the hips down in beige bike shorts and fresh cream sneakers, holding a wooden-handled cotton jump rope loosely at her side"
PROMPT_identity_powerful="A woman photographed from behind in a black workout set with perfect upright posture, hair in a slick low bun, hands on hips, quiet strength"
PROMPT_identity_calm="A woman lying back in a white waffle robe with a silk scrunchie on her wrist, holding two chilled silver facial globes near her face which is mostly out of frame above the eyes"
PROMPT_identity_light="A woman walking through warm sunlight in a flowy white linen set photographed from behind, hair catching the light with slight motion"
PROMPT_identity_strong="A woman doing a pilates glute bridge on a mat with a small exercise ball under one foot, wearing chocolate-brown shorts and beige ankle weights, cropped chin-down"
PROMPT_identity_radiant="A woman in a black tank top with over-ear silver headphones holding an iced latte, photographed in profile cropped above the eyes, gold hoops, glowy skin"
PROMPT_cohort_1="A woman at the beach in a sage green bikini top and oversized dark sunglasses holding a slice of melon, photographed chin-down close, sun-warmed skin"
PROMPT_cohort_2="A woman in a matching butter-yellow knit shorts set carrying a black tote bag mid-stride on a sunny street, cropped from the shoulders down"
PROMPT_cohort_3="A woman drinking a green juice from a glass, photographed chin-down close, dainty gold necklace, soft morning light"
PROMPT_reveal_balcony="A woman in a white two-piece workout set leaning on an ornate black wrought-iron balcony railing photographed from behind, looking out toward a soft hazy sea horizon implied only by light, hair in a loose bun"
PROMPT_paywall_breakfast="A wooden breakfast table by a bright window with a plate of fresh papaya and berries, a small ceramic coffee cup, and an open paperback book"
PROMPT_paywall_books="A neat stack of five pastel-spined paperback books with a pair of thin gold reading glasses resting on top, on soft white linen"
PROMPT_paywall_produce="An abundant fresh market spread of colorful vegetables and berries arranged on a linen towel, carrots cherry tomatoes blueberries leafy greens, overhead angle"
PROMPT_paywall_walk="Two women in matching athletic wear walking away down a quiet desert road at golden hour photographed from behind, relaxed gait, long shadows"

generate_one() {
  local name="$1"
  local prompt_var="PROMPT_${name}"
  local prompt="${!prompt_var}"
  local out_path="$OUT_DIR/$name.jpg"
  local json_path="$OUT_DIR/${name}_response.json"

  [ -s "$out_path" ] && { echo "[skip] $name exists"; return 0; }

  local body
  body=$(jq -n --arg p "${prompt}${STYLE}" '{model:"grok-imagine-image-quality",prompt:$p,n:1,response_format:"b64_json"}')

  curl -s --max-time 180 -X POST https://api.x.ai/v1/images/generations \
    -H "Authorization: Bearer $KEY" \
    -H "Content-Type: application/json" \
    -d "$body" \
    > "$json_path"

  if jq -e '.data[0].b64_json' "$json_path" > /dev/null 2>&1; then
    jq -r '.data[0].b64_json' "$json_path" | base64 -d > "$out_path"
    local size
    size=$(stat -f%z "$out_path" 2>/dev/null || stat -c%s "$out_path")
    echo "[ok] $name ($((size/1024))KB)"
    rm -f "$json_path"
  else
    echo "[fail] $name -- $(head -c 300 "$json_path")" >&2
    return 1
  fi
}

NAMES=(welcome_stretch welcome_matcha welcome_journal movement_sneakers \
       identity_powerful identity_calm identity_light identity_strong identity_radiant \
       cohort_1 cohort_2 cohort_3 reveal_balcony \
       paywall_breakfast paywall_books paywall_produce paywall_walk)

# Batches of 4 to stay friendly with rate limits
for ((i=0; i<${#NAMES[@]}; i+=4)); do
  for name in "${NAMES[@]:i:4}"; do
    generate_one "$name" &
  done
  wait
done

echo ""
echo "Done. $(ls "$OUT_DIR"/*.jpg 2>/dev/null | wc -l | tr -d ' ')/17 images in $OUT_DIR/"
