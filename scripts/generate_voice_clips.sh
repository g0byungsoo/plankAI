#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/PlankApp/Resources/VoiceClips"
source "$PROJECT_DIR/.env"
VOICE_ID="03vEurziQfq3V8WZhQvn"
API_URL="https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID"
mkdir -p "$OUTPUT_DIR"

generate() {
    local id="$1"
    local text="$2"
    local output="$OUTPUT_DIR/${id}.m4a"
    [ -f "$output" ] && { echo "SKIP $id"; return; }
    echo "GEN  $id"
    local tmp=$(mktemp /tmp/voice_XXXXXX.mp3)
    curl -s -X POST "$API_URL" \
        -H "xi-api-key: $ELEVENLABS_API_KEY" \
        -H "Content-Type: application/json" \
        -H "Accept: audio/mpeg" \
        -d "{\"text\":\"$text\",\"model_id\":\"eleven_turbo_v2_5\",\"voice_settings\":{\"stability\":0.4,\"similarity_boost\":0.75,\"style\":0.6}}" \
        -o "$tmp"
    afconvert "$tmp" "$output" -d aac -f m4af -b 128000 2>/dev/null
    rm -f "$tmp"; sleep 0.5
}

echo "=== Generating voice clips ==="

# Guide setup
generate "guide_setup_1" "Okay prop your phone up so I can see your whole body, then get into plank. Forearms on the floor, elbows under your shoulders."
generate "guide_setup_2" "Set your phone down about six feet away, lean it against something, then drop into plank position. I need to see you head to toe."
generate "guide_setup_3" "Alright, get your phone set up where it can see you, then get down. Forearms flat, toes tucked, body straight like a board."
generate "guide_good_1" "Good. Hold."
generate "guide_good_2" "That's it."
generate "guide_good_3" "Yes. Breathe."

# Hip sag
generate "hip_sag_1" "Hips! Up! You're giving hammock right now."
generate "hip_sag_2" "Hips up. Squeeze your glutes. My mama planks better than this."
generate "hip_sag_3" "Hips! Belly button to spine. Don't spill grandma's soup."
generate "hip_sag_4" "Hips are sagging. Tuck your tailbone. Tighten everything."
generate "hip_sag_5" "Hips! If they drop any lower they'll need their own zip code."
generate "hip_sag_6" "Hips up! Engage that core like rent is due tomorrow."

# Hip pike
generate "hip_pike_1" "Hips down! This is a plank not yoga class."
generate "hip_pike_2" "Drop your hips! You look like a tent. Flatten out."
generate "hip_pike_3" "Hips down! Cheating doesn't count in this house."
generate "hip_pike_4" "Flatten! Your butt is way too high. Straight line."

# Shoulder
generate "shoulder_1" "Shoulders! Down! You're not a turtle, drop them."
generate "shoulder_2" "Shoulders down. Push the floor away. You're planking not panicking."
generate "shoulder_3" "Shoulders! Relax. Shoulder blades in your back pockets."
generate "shoulder_4" "Drop the shoulders! Your traps didn't sign up for this."

# Recovery
generate "recovery_1" "There it is. Hold that."
generate "recovery_2" "Good fix. Stay."
generate "recovery_3" "See? When you try, you're actually good at this."
generate "recovery_4" "That's the one. Don't move."

# Stopped
generate "stopped_1" "Back down! I didn't say stop."
generate "stopped_2" "Get back in plank! Timer's still going."
generate "stopped_3" "Nope! Back down. We're not done."
generate "stopped_4" "You stopped? In this economy? Back down."

# Milestones
generate "milestone_10" "Ten seconds. Stay tight."
generate "milestone_30" "Thirty! Halfway. Check form. Keep going."
generate "milestone_60" "One minute! Okay I see you!"
generate "milestone_90" "Ninety seconds! Most people quit by now. Not you."
generate "milestone_120" "Two minutes! That's elite. Your core is transforming."

# Countdown
generate "countdown_10" "Ten seconds! Lock in. Finish strong."
generate "countdown_5" "Five!"
generate "countdown_3" "Three!"
generate "countdown_2" "Two!"
generate "countdown_1" "One!"

# Session
generate "start_1" "I see you. Go."
generate "start_2" "You showed up. Let's get it."
generate "end_good" "Done! You ate that. See you tomorrow."
generate "end_bad" "It's done. We don't talk about it. Tomorrow."

# Camera
generate "camera_bad_1" "Can't see you. Move your phone back."
generate "camera_bad_2" "Back up your phone. I need the full picture."

echo ""
echo "=== Done! $(ls "$OUTPUT_DIR"/*.m4a 2>/dev/null | wc -l | tr -d ' ') clips ==="
