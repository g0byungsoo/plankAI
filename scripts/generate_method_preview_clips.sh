#!/bin/bash
# Generate the 3 method-preview voice clips for case 250 (onboarding
# "what you get with me" screen). The Audio sample button on that
# screen plays the coach the user picked in onboarding; this script
# generates one ~8s line per coach (jeni / kira / sam).
#
# Voice settings tuned for ritual cadence (softer + steadier than the
# workout-coach defaults in generate_voice_clips.sh): higher stability,
# tiny bit of style expression for warmth. Same model (eleven_turbo_v2_5)
# as the rest of the app so the timbre matches.
#
# Outputs to PlankApp/Resources/VoiceClips/ (folder reference in Xcode —
# new files ship in the bundle on the next build, no project edit needed).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/PlankApp/Resources/VoiceClips"
# Targeted extract — sibling generate_voice_clips.sh uses plain `source`
# but that breaks if any .env value contains spaces (POSTHOG_PROJECT_REGION
# = "US Cloud" is the current offender). Grep just the key we need.
ELEVENLABS_API_KEY="$(grep '^ELEVENLABS_API_KEY=' "$PROJECT_DIR/.env" | cut -d= -f2- | tr -d '"')"
if [ -z "$ELEVENLABS_API_KEY" ]; then
    echo "ELEVENLABS_API_KEY missing in $PROJECT_DIR/.env" >&2
    exit 1
fi

# Voice IDs match Scripts/generate_voice_clips.sh (workout cascade) so
# the user hears the same Jeni / Kira / Sam in onboarding + workouts.
KIRA_VOICE="03vEurziQfq3V8WZhQvn"
JENI_VOICE="hA4zGnmTwX2NQiTRMt7o"
MATSON_VOICE="ZRwrL4id6j1HPGFkeCzO"

# Ritual-cadence settings — softer + steadier than workout cues.
# stability 0.70 (was 0.55 on workouts) reduces the over-emphatic
# delivery on long-form ritual lines; style 0.15 adds a touch of warmth
# without going dramatic.
VOICE_SETTINGS='{"stability":0.70,"similarity_boost":0.85,"style":0.15,"use_speaker_boost":true}'

mkdir -p "$OUTPUT_DIR"

generate() {
    local voice_id="$1"
    local id="$2"
    local text="$3"
    local output="$OUTPUT_DIR/${id}.m4a"
    if [ -f "$output" ]; then
        echo "SKIP $id (already exists — delete to regen)"
        return
    fi
    echo "GEN  $id : \"$text\""
    local url="https://api.elevenlabs.io/v1/text-to-speech/$voice_id"
    local tmp=$(mktemp /tmp/voice_XXXXXX.mp3)
    local http_status
    http_status=$(curl -s -o "$tmp" -w "%{http_code}" -X POST "$url" \
        -H "xi-api-key: $ELEVENLABS_API_KEY" \
        -H "Content-Type: application/json" \
        -H "Accept: audio/mpeg" \
        -d "{\"text\":\"${text}\",\"model_id\":\"eleven_turbo_v2_5\",\"voice_settings\":${VOICE_SETTINGS}}")
    if [ "$http_status" != "200" ]; then
        echo "  FAIL (HTTP $http_status):"
        head -c 400 "$tmp"
        echo ""
        rm -f "$tmp"
        return 1
    fi
    afconvert "$tmp" "$output" -d aac -f m4af -b 128000 2>/dev/null
    rm -f "$tmp"
    local size=$(stat -f %z "$output")
    echo "  → $output ($size bytes)"
    sleep 0.3
}

echo "=== Method preview voice clips (case 250 audio sample) ==="
# v2 lines — research-grounded refresh (2026-05-26). Conversion mechanic
# is "acknowledge resistance + tiny action with you" (Calm/Headspace
# converting previews always feature technique-in-action, not meta intro;
# Intellect 2024 parasocial trust research). Lines avoid repeating
# "5 minutes / show up / every day" since those are already on-screen
# above the audio button — audio is *demonstration*, not recap.
generate "$JENI_VOICE"   "method_preview_jeni"    "hey. you don't have to feel ready. you just have to be here. and we're already doing it."
generate "$KIRA_VOICE"   "method_preview_kira"    "look. ready isn't a feeling. it's something you fake until your body catches up. i'll fake it with you."
generate "$MATSON_VOICE" "method_preview_matson"  "soft jaw. let's breathe... in. and out. one down — you're already further than you were."

echo ""
echo "Done. Rebuild the app — the 3 clips will ship in the bundle and"
echo "the case 250 audio button will activate (was disabled while files"
echo "were missing)."
