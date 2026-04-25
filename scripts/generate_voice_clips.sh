#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/PlankApp/Resources/VoiceClips"
source "$PROJECT_DIR/.env"
# Voice IDs per trainer
KIRA_VOICE="03vEurziQfq3V8WZhQvn"
SARAH_VOICE="nf4MCGNSdM0hxM95ZBQR"
MATSON_VOICE="ZRwrL4id6j1HPGFkeCzO"
# Default voice for existing clips
VOICE_ID="$KIRA_VOICE"
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

# =============================================
# ROUTINE MODE — Exercise intros (Kira voice)
# Keep clips SHORT. 2-5 seconds max. Punchy.
# =============================================

# Session bookends
generate "routine_start_1" "Let's work."
generate "routine_start_2" "We're going."
generate "routine_start_3" "Time to go."
generate "routine_done_1" "Done! You ate that."
generate "routine_done_2" "That's a wrap."
generate "routine_done_3" "Finished. Go drink water."

# Exercise intros — SHORT. Name + one cue. Under 3 seconds.
# Front core
generate "intro_bicycle_crunch" "Bicycle crunches. Elbow to knee."
generate "intro_reverse_crunch" "Reverse crunches. Knees to chest."
generate "intro_leg_raises" "Leg raises. Slow and controlled."
generate "intro_flutter_kicks" "Flutter kicks. Keep 'em low."
generate "intro_toe_touches" "Toe touches. Reach up, crunch up."
generate "intro_v_ups" "V-ups. Hands and feet meet in the middle."
generate "intro_dead_bug" "Dead bug. Opposite arm, opposite leg."
generate "intro_hollow_body_hold" "Hollow body. Press your back down. Hold."

# Obliques
generate "intro_russian_twists" "Russian twists. Side to side."
generate "intro_side_plank_left" "Side plank. Left side. Hips up."
generate "intro_side_plank_right" "Side plank. Right side. Hips up."
generate "intro_oblique_crunch_left" "Oblique crunch. Left side."
generate "intro_oblique_crunch_right" "Oblique crunch. Right side."
generate "intro_woodchoppers" "Woodchoppers. Twist and drive."

# Lower back
generate "intro_superman_hold" "Superman hold. Arms and legs up. Fly."
generate "intro_superman_pulses" "Superman pulses. Up and down."
generate "intro_bird_dog" "Bird dog. Opposite arm, opposite leg."
generate "intro_glute_bridge_hold" "Glute bridge. Hips up. Squeeze."
generate "intro_glute_bridge_marches" "Glute bridge marches. Keep hips level."

# Full core
generate "intro_mountain_climbers" "Mountain climbers. Drive those knees."
generate "intro_plank_shoulder_taps" "Shoulder taps. Don't rock. Stable."
generate "intro_bear_crawl_hold" "Bear crawl hold. Knees off the floor."
generate "intro_inchworms" "Inchworms. Walk out, walk back."
generate "intro_high_knees" "High knees. Drive 'em up."

# Tempo pacing — 2-3 words max
generate "tempo_1" "Keep going."
generate "tempo_2" "Don't stop."
generate "tempo_3" "Same pace."
generate "tempo_4" "Faster."
generate "tempo_twist_1" "Twist, twist."
generate "tempo_twist_2" "Side to side."
generate "tempo_drive_1" "Drive, drive."
generate "tempo_drive_2" "Higher."

# Static hold — short
generate "hold_1" "Hold. Breathe."
generate "hold_2" "Stay."
generate "hold_3" "Don't move."
generate "hold_4" "Don't drop."
generate "hold_5" "Shake is good."
generate "hold_6" "Almost."

# Rest — short
generate "rest_1" "Rest."
generate "rest_2" "Breathe."
generate "rest_3" "Shake it out."
generate "rest_4" "Quick break."

# Exercise cues — one or two words max
generate "exercise_countdown" "Go."
generate "exercise_almost" "Five seconds."
generate "exercise_done" "Time."

# Skip
generate "skip_1" "Next."
generate "skip_2" "Moving on."

echo ""
echo "=== Done! $(ls "$OUTPUT_DIR"/*.m4a 2>/dev/null | wc -l | tr -d ' ') clips ==="
