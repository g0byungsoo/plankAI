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
# =============================================

# Session bookends
generate "routine_start_1" "Alright, let's get into it. Your workout's ready, no excuses."
generate "routine_start_2" "Time to work. I picked this one just for you, so don't waste it."
generate "routine_start_3" "We're going. Five minutes, no phone breaks, no quitting."
generate "routine_done_1" "Done! You showed up and you showed out. That's the whole game."
generate "routine_done_2" "And that's a wrap. Your abs don't know what hit 'em."
generate "routine_done_3" "Finished! Now go drink some water and stop scrolling."

# Exercise intros — front core
generate "intro_bicycle_crunch" "Bicycle crunches. Opposite elbow to opposite knee. Don't just flop around, make it count."
generate "intro_reverse_crunch" "Reverse crunches. Knees to chest, lift those hips. Your lower abs are about to have a conversation."
generate "intro_leg_raises" "Leg raises. Slow and controlled, don't just let gravity do the work. That's cheating."
generate "intro_flutter_kicks" "Flutter kicks. Keep those legs straight, keep 'em low. This one burns and I love that for you."
generate "intro_toe_touches" "Toe touches. Reach up, crunch up. If you can't touch, just reach. We'll get there."
generate "intro_v_ups" "V-ups. This one's spicy. Hands and feet meet in the middle. Don't look at me like that."
generate "intro_dead_bug" "Dead bug. Arms up, legs up, opposite arm and leg go down. Look like a dead bug, work like a machine."
generate "intro_hollow_body_hold" "Hollow body hold. Arms by your ears, legs straight out, press your lower back into the floor. And hold."

# Exercise intros — obliques
generate "intro_russian_twists" "Russian twists. Lean back, twist side to side. Your waist isn't gonna sculpt itself."
generate "intro_side_plank_left" "Side plank, left side. Stack those feet, hips up. Don't let that hip drop or I'll know."
generate "intro_side_plank_right" "Side plank, right side. Same energy. Hips up, core tight. Balance."
generate "intro_oblique_crunch_left" "Oblique crunches, left side. Elbow to hip. Squeeze at the top."
generate "intro_oblique_crunch_right" "Oblique crunches, right side. Match what you did on the left. Symmetry matters."
generate "intro_woodchoppers" "Woodchoppers. Twist and drive. Pretend you're chopping wood, except the wood is your excuses."

# Exercise intros — lower back
generate "intro_superman_hold" "Superman hold. Face down, arms and legs up. Fly. You look ridiculous and it's working."
generate "intro_superman_pulses" "Superman pulses. Same position but pulse up and down. Your lower back's gonna thank me tomorrow."
generate "intro_bird_dog" "Bird dog. Opposite arm, opposite leg. Extend, hold, switch. Balance and control."
generate "intro_glute_bridge_hold" "Glute bridge hold. Feet flat, hips up, squeeze. Don't let those hips sag."
generate "intro_glute_bridge_marches" "Glute bridge marches. Hips up, now march one leg at a time. Keep those hips level."

# Exercise intros — full core
generate "intro_mountain_climbers" "Mountain climbers. Hands down, drive those knees. Fast. Like your rent depends on it."
generate "intro_plank_shoulder_taps" "Plank shoulder taps. Tap each shoulder, don't rock side to side. Stable. Like your credit score should be."
generate "intro_bear_crawl_hold" "Bear crawl hold. Hands and toes, knees one inch off the floor. Just hold. This one's sneaky."
generate "intro_inchworms" "Inchworms. Walk your hands out to plank, walk 'em back. Full body, full drama."
generate "intro_high_knees" "High knees. Drive 'em up, pump those arms. Cardio core. Let's go."

# Tempo pacing — dynamic exercises
generate "tempo_1" "Up, down. Up, down. Keep that rhythm."
generate "tempo_2" "And switch. And switch. Don't slow down on me."
generate "tempo_3" "Keep going. Same pace. You got this."
generate "tempo_4" "Faster. I know you have more than that."
generate "tempo_twist_1" "Twist, twist. Get that rotation."
generate "tempo_twist_2" "Side to side. Feel your obliques working."
generate "tempo_drive_1" "Drive, drive, drive. Don't stop."
generate "tempo_drive_2" "Keep those knees coming. Higher."

# Static hold encouragement
generate "hold_1" "Hold. Breathe. Don't you dare move."
generate "hold_2" "Stay right there. Time's ticking and you're winning."
generate "hold_3" "Almost. Keep holding. Your muscles are lying to you, you're fine."
generate "hold_4" "Don't drop. Ten more seconds and you own this."
generate "hold_5" "Hold it. Shake is good. Shake means it's working."
generate "hold_6" "Breathe through it. You've done harder things than this."

# Rest transitions
generate "rest_1" "Rest. Shake it out. You earned that."
generate "rest_2" "Take a breath. Next one's coming."
generate "rest_3" "Quick break. Don't sit down, stay ready."
generate "rest_4" "Rest up. We're not done yet."
generate "rest_next_1" "Okay, next up."
generate "rest_next_2" "Here we go. Next exercise."
generate "rest_next_3" "Get ready. Next one in three, two, one."

# Countdown for exercises
generate "exercise_countdown" "Three, two, one, go."
generate "exercise_almost" "Five more seconds. Finish it."
generate "exercise_done" "Time! Nice."
generate "exercise_halfway" "Halfway. Don't quit now."

# Skip reaction (no judgment per design doc, but still Kira)
generate "skip_1" "Skipped. Moving on."
generate "skip_2" "Next one. We keep going."

echo ""
echo "=== Done! $(ls "$OUTPUT_DIR"/*.m4a 2>/dev/null | wc -l | tr -d ' ') clips ==="
