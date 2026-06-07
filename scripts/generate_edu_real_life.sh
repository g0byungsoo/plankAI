#!/usr/bin/env bash
# One-shot generator for the edu-real-life illustration (case 230
# "built for real life" anchor, 2026-06-07 rewrite). Same xAI Grok
# Imagine pipeline + chroma-key flow as generate_edu_illustrations.sh,
# isolated to this single asset so we don't risk regenerating the
# others.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
ASSETS_DIR="$REPO_ROOT/PlankApp/Assets.xcassets"
OUT_DIR="$REPO_ROOT/Scripts/generated"
NAME="edu-real-life"
CANDIDATES="${CANDIDATES:-3}"

MODEL="grok-imagine-image-quality"
ASPECT="1:1"
RESOLUTION="1k"

if [[ -f "$ENV_FILE" ]]; then
    GROK_IMAGINE_API_KEY="$(grep -E '^GROK_IMAGINE_API_KEY=' "$ENV_FILE" | head -n1 | cut -d= -f2- || true)"
fi
if [[ -z "${GROK_IMAGINE_API_KEY:-}" ]]; then
    echo "✗ GROK_IMAGINE_API_KEY not set"; exit 1
fi

STYLE_FLAT="flat modern editorial illustration in the style of Storyset / Spotbot / corporate-training illustrations, single young woman with simple soft features and warm friendly expression, gentle sympathetic pose, dusty rose pink and warm cream and soft cocoa palette, minimal clean vector lines, isolated on pure flat white background, no harsh outlines, no text, no logos, no body shaming, supportive and gentle mood, modern minimal humanist style,"

# Subject prompt — domestic real-life scene that conveys "this fits
# into your actual life." NOT at a gym, NOT in workout clothes. A
# moment of integration: cozy clothes, casual posture, a small
# everyday gesture (sipping tea, glancing at phone) that signals
# "five minutes here, then back to my day." Centered composition
# with both hands and full body visible so it crops cleanly to the
# square hero slot.
SUBJECT_PROMPT="a young woman in cozy loungewear at home in a soft sunlit living room, comfortably seated on a low cushion with both legs visible, holding a small steaming mug in one hand and a phone showing a simple calm wellness interface in the other, looking down at the phone with a soft confident smile, one plant or soft houseplant just visible in the background corner, signifying a 5-minute calm wellness moment integrated naturally into real domestic life, NOT at a gym, NOT in workout clothes, focus on the calm everyday-integration moment with both legs and feet clearly visible in the frame and generous bottom margin so nothing is cropped"

FULL_PROMPT="${STYLE_FLAT} ${SUBJECT_PROMPT}"

mkdir -p "$OUT_DIR"

echo "→ generating ${CANDIDATES} candidate(s) for ${NAME}"

for i in $(seq 1 "$CANDIDATES"); do
    out_path="$OUT_DIR/${NAME}_v${i}.png"
    echo "  • candidate ${i}/${CANDIDATES}"

    body=$(jq -n \
        --arg model "$MODEL" \
        --arg prompt "$FULL_PROMPT" \
        --arg aspect "$ASPECT" \
        --arg resolution "$RESOLUTION" \
        '{model:$model, prompt:$prompt, aspect_ratio:$aspect, resolution:$resolution, response_format:"b64_json"}')

    response=$(curl -sS -X POST "https://api.x.ai/v1/images/generations" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${GROK_IMAGINE_API_KEY}" \
        -d "$body")

    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        echo "✗ candidate ${i} failed:"
        echo "$response" | jq '.error'
        continue
    fi

    b64=$(echo "$response" | jq -r '.data[0].b64_json // empty')
    if [[ -z "$b64" ]]; then
        echo "✗ candidate ${i} returned no image data"
        continue
    fi

    echo "$b64" | base64 --decode > "$out_path"

    # Chroma-key the white background to alpha — same recipe as the
    # main edu generator. 10% fuzz, then a Close Disk:8 morphology
    # to seal small internal holes.
    if command -v magick >/dev/null 2>&1; then
        corner=$(magick "$out_path" -format '%[pixel:p{0,0}]' info: 2>/dev/null || echo "white")
        magick "$out_path" \
            -alpha set \
            -bordercolor "$corner" -border 1 \
            -fuzz 10% -fill none -draw "alpha 0,0 floodfill" \
            -shave 1x1 \
            -channel A -morphology Close Disk:8 +channel \
            "${out_path}.tmp.png" 2>/dev/null
        if [[ -f "${out_path}.tmp.png" ]]; then
            mv "${out_path}.tmp.png" "$out_path"
        fi
    fi

    size_kb=$(($(stat -f %z "$out_path") / 1024))
    echo "    ✓ $out_path (${size_kb} KB)"
done

echo "done. review candidates in ${OUT_DIR}/"
