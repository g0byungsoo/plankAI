#!/bin/bash
# Generate the 3 coach-intro voice clips for the post-purchase
# CoachIntroView (Phase A.0). One ~30s line per coach voice
# (jeni / kira / sam) — designed for the welcome moment, where the
# personalization happens visually on-screen and the audio carries the
# parasocial weight.
#
# Voice settings tuned for long-form parasocial warmth — slightly higher
# stability than the ritual-cadence clips (0.78 vs 0.70) because users
# need to FEEL the voice as a calm, intentional coach, not an excited
# narrator. Style bumped to 0.30 (vs 0.15 for ritual previews, 0.0 for
# workout cascade) for the extra warmth the post-purchase moment
# demands. Same model (eleven_turbo_v2_5) so timbre matches the rest of
# the app and users don't perceive a "different voice" between
# CoachIntroView and the workout cues.
#
# Outputs to PlankApp/Resources/VoiceClips/. CoachIntroView prefers
# coach_intro_<voice>.m4a; falls back to method_preview_<voice>.m4a
# if these are missing — so app keeps working while you run this.
#
# Usage: bash Scripts/generate_coach_intro_clips.sh
# Re-run after editing content below to regenerate (delete the files
# first or change the GENERATE_FORCE flag).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/PlankApp/Resources/VoiceClips"

# Targeted extract — same pattern as generate_method_preview_clips.sh
# (sibling `source` breaks on .env values with spaces).
ELEVENLABS_API_KEY="$(grep '^ELEVENLABS_API_KEY=' "$PROJECT_DIR/.env" | cut -d= -f2- | tr -d '"')"
if [ -z "$ELEVENLABS_API_KEY" ]; then
    echo "ELEVENLABS_API_KEY missing in $PROJECT_DIR/.env" >&2
    exit 1
fi

# Voice IDs match Scripts/generate_voice_clips.sh and generate_method_preview_clips.sh
# so the user hears the same Jeni / Kira / Sam in onboarding, post-purchase,
# and during workouts. Never change these without re-recording the entire
# voice library — timbre consistency is the parasocial moat.
KIRA_VOICE="03vEurziQfq3V8WZhQvn"
JENI_VOICE="hA4zGnmTwX2NQiTRMt7o"
MATSON_VOICE="ZRwrL4id6j1HPGFkeCzO"

# Coach-intro settings — softer + warmer than ritual previews.
# stability 0.78 keeps long-form delivery steady (avoids the "different
# emotion on every other word" effect very-low-stability gives on 30s+
# clips). similarity_boost 0.85 preserves voice identity. style 0.30 is
# the warmth lever — 0.0 reads as flat, 0.5+ reads as theatrical;
# 0.30 lands in "warm coach". use_speaker_boost on for clarity.
VOICE_SETTINGS='{"stability":0.78,"similarity_boost":0.85,"style":0.30,"use_speaker_boost":true}'

# Allow forcing regeneration by passing --force.
FORCE=0
if [[ "${1:-}" == "--force" ]]; then FORCE=1; fi

mkdir -p "$OUTPUT_DIR"

generate() {
    local voice_id="$1"
    local id="$2"
    local text="$3"
    local output="$OUTPUT_DIR/${id}.m4a"
    if [ -f "$output" ] && [ $FORCE -eq 0 ]; then
        echo "SKIP $id (already exists — pass --force to regen)"
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
        head -c 400 "$tmp"
        echo ""
        rm -f "$tmp"
        return 1
    fi
    afconvert "$tmp" "$output" -d aac -f m4af -b 128000 2>/dev/null
    rm -f "$tmp"
    local size=$(stat -f %z "$output")
    echo "  → $output ($size bytes)"
    sleep 0.4
}

echo "=== Coach intro voice clips (CoachIntroView post-purchase) ==="
echo ""

# v1 content — designed for the post-purchase welcome moment.
# Architecture per docs/product_direction_2026.md §8.1: audio carries
# the parasocial weight (warm, voice-specific tone), text on-screen
# carries the personalization (name, weight delta, identity feeling,
# barrier). So audio content is generic — it works for EVERY user.
#
# Tone per voicePreference:
#   - JENI (encouraging):   warm, reassuring, "i'm here for you" energy
#   - KIRA (keepItReal):    direct, no-bullshit, validation through honesty
#   - SAM  (balanced):      steady, grounded, calming
#
# Length target: 25-35 seconds. Spoken at a normal pace, leaves room
# for the user to read the personalized stats on-screen during playback.
# Ellipses (...) in source render as natural pauses in ElevenLabs.

generate "$JENI_VOICE" "coach_intro_jeni" \
"hi there. i'm so glad you're here. i know you just made a real decision, and that takes something — most people never get this far. take a breath right now. and remember... you don't have to be ready. you just have to begin. let's start with today. five minutes. that's all i'm asking, ever. one day at a time."

generate "$KIRA_VOICE" "coach_intro_kira" \
"hey. you're in. and i'm not gonna do the fake hype thing with you. you just signed up for something hard, and i respect that. so here's what's true. small things, every day, and one day you'll look back and not recognize yourself. that's how it actually works. so. today. five minutes. open it. that's the whole thing. let's just start."

generate "$MATSON_VOICE" "coach_intro_matson" \
"hey there. take a breath with me. one in... and one out. okay. you just made a real choice. and that means something. now we go small. five minutes today. then we figure out tomorrow together. open today's workout when you're ready. i'm right here."

echo ""
echo "Done. Rebuild the app — the 3 clips will ship in the bundle."
echo "CoachIntroView will automatically prefer these over the"
echo "method_preview fallback once they're in the bundle."
