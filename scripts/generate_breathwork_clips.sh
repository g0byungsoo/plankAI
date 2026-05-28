#!/bin/bash
# Generate the 6 breathwork voice clips for BreathworkSessionView
# (post-purchase breath session). Two clips per coach voice:
#   breath_intro_<voice>.m4a  — Jeni opens the session, counts the user
#                               into the breath (~12-15s)
#   breath_close_<voice>.m4a  — Jeni closes after the cycles, names the
#                               nervous-system shift (~10-12s)
#
# The breath cycles themselves are guided VISUALLY (BreathCircle's bloom
# + inhale/exhale labels + countdown + haptics), so there are no
# per-cycle audio clips — the voice bookends the session.
#
# Voice settings match generate_coach_intro_clips.sh — warm, steady,
# long-form (stability 0.78, style 0.30) so the breath guidance feels
# calm and intentional rather than excited. Same model + voice IDs as
# the rest of the app for timbre consistency.
#
# Usage: bash Scripts/generate_breathwork_clips.sh [--force]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/PlankApp/Resources/VoiceClips"

ELEVENLABS_API_KEY="$(grep '^ELEVENLABS_API_KEY=' "$PROJECT_DIR/.env" | cut -d= -f2- | tr -d '"')"
if [ -z "$ELEVENLABS_API_KEY" ]; then
    echo "ELEVENLABS_API_KEY missing in $PROJECT_DIR/.env" >&2
    exit 1
fi

KIRA_VOICE="03vEurziQfq3V8WZhQvn"
JENI_VOICE="hA4zGnmTwX2NQiTRMt7o"
MATSON_VOICE="ZRwrL4id6j1HPGFkeCzO"

# Warm long-form settings (same as coach intro).
VOICE_SETTINGS='{"stability":0.78,"similarity_boost":0.85,"style":0.30,"use_speaker_boost":true}'

FORCE=0
if [[ "${1:-}" == "--force" ]]; then FORCE=1; fi

mkdir -p "$OUTPUT_DIR"

generate() {
    local voice_id="$1"
    local id="$2"
    local text="$3"
    local output="$OUTPUT_DIR/${id}.m4a"
    if [ -f "$output" ] && [ $FORCE -eq 0 ]; then
        echo "SKIP $id (exists — pass --force to regen)"
        return
    fi
    echo "GEN  $id"
    echo "     \"$text\""
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
        head -c 400 "$tmp"; echo ""
        rm -f "$tmp"
        return 1
    fi
    afconvert "$tmp" "$output" -d aac -f m4af -b 128000 2>/dev/null
    rm -f "$tmp"
    echo "  → $output ($(stat -f %z "$output") bytes)"
    sleep 0.4
}

echo "=== Breathwork voice clips (BreathworkSessionView) ==="
echo ""

# Intro clips — open the session, settle the user, hand off to the
# visual breath guide. ~12-15s. The exhale-dominant pattern (4 in,
# 6 out) is what the BreathCircle will render, so the intro primes
# "longer out than in" without over-instructing.
generate "$JENI_VOICE" "breath_intro_jeni" \
"okay. let's take two minutes before anything else. breathe into your belly, not your chest. soften your jaw. drop your shoulders. we'll breathe in for four, and let it go for six. longer out than in. that's the part that lowers cortisol. follow the circle with me."

generate "$KIRA_VOICE" "breath_intro_kira" \
"alright. two minutes, just breathing. no performance here. breathe into your belly, not your chest. soften your jaw, drop your shoulders. in for four, let it go for six. the long exhale is the part that actually lowers your cortisol. follow the circle."

generate "$MATSON_VOICE" "breath_intro_matson" \
"let's settle first. breathe into your belly, not your chest. soften your jaw. let your shoulders drop. we'll breathe in for four, and let it go for six, longer on the way out. that's the part your nervous system listens to. follow the circle with me."

# Close clips — name the shift, hand off to the choice. ~10-12s.
generate "$JENI_VOICE" "breath_close_jeni" \
"good. feel that? that's your nervous system settling. that's less stress, and fewer of the cravings that aren't really hunger. you just did the first thing. i'm proud of you."

generate "$KIRA_VOICE" "breath_close_kira" \
"there it is. that's your system coming off stress. that's the part most people skip, and it's the part that makes the rest easier. you showed up. that counts."

generate "$MATSON_VOICE" "breath_close_matson" \
"good. notice how that feels. that's your body settling, off the stress that drives the cravings. you just did the first thing today. that's enough to build on."

echo ""
echo "Done. Rebuild the app — the 6 clips ship in the bundle and"
echo "BreathworkSessionView will use them automatically (it falls back"
echo "to text-only + the BreathCircle visual if they're missing)."
