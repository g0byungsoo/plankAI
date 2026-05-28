#!/usr/bin/env bash
# Generate JeniFit educational-screen illustrations via the xAI Grok
# Imagine API. Each prompt produces one PNG, saved as an Xcassets
# imageset under PlankApp/Assets.xcassets/<name>.imageset/.
#
# Endpoint: https://api.x.ai/v1/images/generations
# Model:    grok-imagine-image-quality (the 2026-current replacement
#           for grok-imagine-image-pro, deprecated 2026-05-15)
# Auth:     Authorization: Bearer $GROK_IMAGINE_API_KEY  (read from .env)
#
# Re-running is safe — existing imagesets are skipped unless
# FORCE_REGEN=1 is set in the environment. The Xcode project uses
# folder-synchronized xcassets, so dropped .imageset folders are
# auto-discovered without touching the pbxproj.
#
# Usage:
#   ./Scripts/generate_edu_illustrations.sh           # generate missing
#   FORCE_REGEN=1 ./Scripts/generate_edu_illustrations.sh   # overwrite
#
# All prompts share the same stylistic anchor — soft watercolor,
# blush/cream palette, gentle painterly aesthetic with no people,
# no text, no body comparisons, no shame imagery. Pure abstract +
# symbolic so they hold up at any size and stay on-brand with the
# existing sticker scatter / scrapbook chrome.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
ASSETS_DIR="$REPO_ROOT/PlankApp/Assets.xcassets"
MODEL="grok-imagine-image-quality"
ASPECT="1:1"      # Square — matches the .frame(maxHeight: 220) hero slot
RESOLUTION="1k"   # 1024×1024 is enough for the 220pt hero size; 2k doubles cost

# Load GROK_IMAGINE_API_KEY from .env. Falls back to an already-set
# env var so CI can inject the key without committing a .env.
if [[ -f "$ENV_FILE" ]]; then
    GROK_IMAGINE_API_KEY="$(grep -E '^GROK_IMAGINE_API_KEY=' "$ENV_FILE" | head -n1 | cut -d= -f2- || true)"
fi

if [[ -z "${GROK_IMAGINE_API_KEY:-}" ]]; then
    echo "✗ GROK_IMAGINE_API_KEY not set in .env or environment"
    exit 1
fi

# Two style prefixes — one per family of illustrations. The 5 edu
# screens stay in the y2k-coquette 3D glossy sticker family (matches
# the existing gummy-bear / iridescent-bow stickers per
# docs/THEME.md). The 3 barrier yes/no screens get a different
# treatment: flat modern editorial illustrations of a woman in a
# relatable scene, in the Storyset / Spotbot psychology-test /
# corporate-training visual idiom — more relatable, sympathetic,
# matches the introspective tone of the questions.
#
# Both prefixes ask explicitly for a pure-white background which the
# post-processing step then chroma-keys to alpha-transparent. White
# is easier to key cleanly than the cream we asked for previously.

STYLE_STICKER="y2k coquette 3D glossy sticker, saturated candy pink with pearl and soft yellow iridescent highlights, jelly resin material with subtle reflections, single hero object centered with generous breathing room, isolated on pure flat white background with no shadows or surface textures, die-cut sticker look, sticker pack aesthetic matching glossy gummy-bear and iridescent satin-bow style, no text, no people, no human figures, no faces, no body comparisons,"

STYLE_FLAT="flat modern editorial illustration in the style of Storyset / Spotbot / corporate-training illustrations, single young woman with simple soft features and warm friendly expression, gentle sympathetic pose, dusty rose pink and warm cream and soft cocoa palette, minimal clean vector lines, isolated on pure flat white background, no harsh outlines, no text, no logos, no body shaming, supportive and gentle mood, modern minimal humanist style,"

# Portrait style — polished flat-vector illustrated portraits with
# soft naturalistic features. Matches the aesthetic of the original
# coach portraits the user wanted preserved, while harmonizing
# character look with the rest of the new illustration system
# (warm pink + cream + cocoa + sage palette, gentle expressions).
# NOT cartoon-character exaggerated. NOT full photorealism. Sits
# in the polished-editorial-illustration middle.
STYLE_PORTRAIT="polished editorial flat-vector portrait illustration in a refined illustrated style, soft naturalistic facial features rendered with simple flat color shading and subtle geometric color blocks, warm dusty rose pink and cream and warm cocoa and sage green palette, skin tones in warm peach and cocoa shades with NO pure white highlights anywhere on the face neck or body, all shading uses warm cream or peach instead of white, gentle confident expression, head-and-shoulders close-up portrait composition centered with generous breathing room, modern magazine-quality illustrated portrait, isolated on pure flat white background that is clearly separated from the subject, no text, no logos, no harsh outlines, no cartoon-character exaggeration, no full photorealism, similar quality to high-end editorial wellness brand portraits,"

# Prompts. KEY|STYLE|BODY triples. STYLE is "sticker" or "flat";
# the script picks the appropriate prefix.
declare -a PROMPTS=(
    # ── 5 educational screens — switched from glossy 3D sticker to
    # flat editorial illustrations to match the 3 barrier ones the
    # user loves. Each = a single female figure in a relatable scene
    # tied directly to the screen's content.
    "edu-coach-intro|flat|a young woman in cozy loungewear sitting cross-legged on the floor in a fully visible head-to-toe pose, holding a steaming mug with both hands, warm friendly smile looking directly at the viewer with kind eyes, both feet and legs clearly visible in the frame with generous bottom margin so nothing is cropped, signifying a supportive coach welcoming you in"
    "edu-body-primer|flat|a young woman in cozy loungewear sitting and writing in a small personal journal with a pencil, looking down at the page with a calm focused expression, a small pink heart drawn on the journal cover, signifying a private personal data moment"
    "edu-five-minutes|flat|a young woman in cozy workout wear glancing at her wristwatch with a soft confident smile, holding her wrist up gently, signifying a brief quick time commitment"
    "edu-cycle|flat|a young woman sitting peacefully holding an open small calendar with floral page decorations, looking thoughtfully at the dates with a gentle smile, signifying tracking the rhythm of her monthly cycle"
    "edu-plateau|flat|a young woman sitting cross-legged calmly looking at a small phone screen showing a simple wavy line chart, with a thoughtful peaceful expression and a soft smile, signifying calm understanding that progress is not always linear"

    # ── 3 barrier yes/no screens — unchanged, user loves these ──
    "edu-barrier-body|flat|a young woman sitting cross-legged on the floor in cozy loungewear, gently looking at a phone screen with a soft thoughtful expression, one hand resting near her heart, signifying a moment of disconnect between herself and a generic workout app"
    "edu-barrier-guidance|flat|a young woman standing with one hand on her chin in a thoughtful pose, looking up at three floating circles each containing a simple workout icon — a yoga mat, a dumbbell, and a pair of running shoes — with a curious slightly overwhelmed expression, signifying not knowing which workout to pick"
    "edu-barrier-stick|flat|a young woman sitting on a rolled-out yoga mat, leaning back on her hands with her phone beside her, looking off to the side with a soft distracted expression, gym gear loosely scattered nearby, signifying losing motivation when a workout starts to feel boring or hard"

    # ── 3 coach portraits — moved to PORTRAIT style for realism ──
    # Cartoon flat style felt disconnected from the "i've been there"
    # peer voice of the rebrand — coaches need to read as real people
    # the user can trust. Editorial digital portrait painting strikes
    # a balance: realistic enough to feel like a person, painterly
    # enough to stay coherent with the brand illustration system.
    "coach-kira|portrait|a young Black woman in her late twenties with warm brown skin and natural curly hair pulled into a soft top bun, light freckles on the cheeks, wearing a soft cream athletic tank top, confident knowing smile with a slight playful smirk, looking directly into the camera with bright thoughtful eyes, natural warm lighting"
    "coach-jeni|portrait|a young woman in her late twenties with warm wavy shoulder-length honey-brown hair and natural light olive skin with subtle blush, wearing a soft dusty pink athletic top, gentle warm supportive smile, kind hazel eyes looking directly into the camera with calm grounded presence, soft natural lighting"
    "coach-matson|portrait|a young man in his late twenties with short tousled medium-brown hair and warm light skin, soft friendly stubble, brown eyes, wearing a solid deep forest green sweatshirt with a tall high crewneck collar that comes up close to under his chin and fully covers the neck and chest area with no gaps, the green color is rich and saturated never light or cream, relaxed easygoing smile with a slight playful glint, looking directly into the camera, natural warm lighting"
)

mkdir -p "$ASSETS_DIR"

generate_one() {
    local name="$1"
    local style="$2"      # "sticker" or "flat"
    local prompt_body="$3"
    local imageset_dir="$ASSETS_DIR/${name}.imageset"
    local png_path="$imageset_dir/${name}.png"

    if [[ -f "$png_path" && -z "${FORCE_REGEN:-}" ]]; then
        echo "↷ skip ${name}.imageset (exists; set FORCE_REGEN=1 to overwrite)"
        return 0
    fi

    mkdir -p "$imageset_dir"
    local style_prefix
    case "$style" in
        sticker)  style_prefix="$STYLE_STICKER" ;;
        flat)     style_prefix="$STYLE_FLAT" ;;
        portrait) style_prefix="$STYLE_PORTRAIT" ;;
        *) echo "✗ unknown style '$style' for $name"; return 1 ;;
    esac
    local full_prompt="${style_prefix} ${prompt_body}"

    echo "→ generating ${name} (${style})…"
    local body
    body=$(jq -n \
        --arg model "$MODEL" \
        --arg prompt "$full_prompt" \
        --arg aspect "$ASPECT" \
        --arg resolution "$RESOLUTION" \
        '{model:$model, prompt:$prompt, aspect_ratio:$aspect, resolution:$resolution, response_format:"b64_json"}')

    local response
    response=$(curl -sS -X POST "https://api.x.ai/v1/images/generations" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${GROK_IMAGINE_API_KEY}" \
        -d "$body")

    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        echo "✗ ${name} failed:"
        echo "$response" | jq '.error'
        return 1
    fi

    local b64
    b64=$(echo "$response" | jq -r '.data[0].b64_json // empty')
    if [[ -z "$b64" ]]; then
        echo "✗ ${name} returned no image data"
        echo "$response" | jq .
        return 1
    fi

    echo "$b64" | base64 --decode > "$png_path"

    # Post-process: convert the background to alpha-transparent so
    # the illustration sits cleanly on the app's #FDF6F4 cream
    # instead of showing a visible rectangle edge. Strategy:
    #   1. Sample the corner pixel (top-left) — that's the background
    #      color the model produced (asked for pure white, but Grok
    #      sometimes lands on near-white / off-white).
    #   2. Chroma-key everything within 18% fuzz tolerance.
    #   3. Use connected-component flood-fill from the 4 corners so
    #      pure-white pixels INSIDE the subject (e.g. highlights on
    #      the heart locket) are preserved.
    if command -v magick >/dev/null 2>&1; then
        local corner
        corner=$(magick "$png_path" -format '%[pixel:p{0,0}]' info: 2>/dev/null || echo "white")
        # Step 1: corner flood-fill keys the outside background to alpha.
        # Step 2: alpha-channel morphological CLOSE seals any small
        # internal holes that got punched through (e.g. a near-white
        # collar gap on Sam's shirt). The 8x8 disk closes holes up to
        # ~16px wide without expanding the subject's silhouette.
        magick "$png_path" \
            -alpha set \
            -bordercolor "$corner" -border 1 \
            -fuzz 10% -fill none -draw "alpha 0,0 floodfill" \
            -shave 1x1 \
            -channel A -morphology Close Disk:8 +channel \
            "${png_path}.tmp.png" 2>/dev/null
        if [[ -f "${png_path}.tmp.png" ]]; then
            mv "${png_path}.tmp.png" "$png_path"
        fi
    fi

    cat > "$imageset_dir/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "${name}.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
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
    echo "✓ wrote ${name}.imageset"
}

for entry in "${PROMPTS[@]}"; do
    name="${entry%%|*}"
    rest="${entry#*|}"
    style="${rest%%|*}"
    prompt_body="${rest#*|}"
    generate_one "$name" "$style" "$prompt_body"
done

echo ""
echo "Done. Open Xcode and verify the imagesets show up in Assets.xcassets."
