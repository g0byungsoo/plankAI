#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/PlankApp/Resources/VoiceClips"
source "$PROJECT_DIR/.env"

KIRA_VOICE="03vEurziQfq3V8WZhQvn"
# voicePreference="encouraging" maps to this voice. User-facing
# display name is "Jeni" (mindful, cheerful, kind). Asset prefix
# `jeni_` is internal-only and predates the persona rename.
JENI_VOICE="hA4zGnmTwX2NQiTRMt7o"
# voicePreference="balanced" maps to this voice. Asset prefix `matson_`
# (kept for back-compat; user-facing display name is "Sam").
MATSON_VOICE="ZRwrL4id6j1HPGFkeCzO"

mkdir -p "$OUTPUT_DIR"

# Workout coach prompt settings — tuned for the short, command-style
# phrases ElevenLabs gets in this app. Medium stability avoids the
# robotic flatness very-high stability produces on one-shot phrases;
# high similarity preserves coach identity on tiny clips; style at 0
# stops short prompts from going inconsistent or overly dramatic;
# speaker_boost trades a touch of latency for clarity, which we want
# for pre-generated clips. Defaults per ElevenLabs docs are 0.75 /
# 0.0; we override stability and similarity for short-phrase fidelity.
VOICE_SETTINGS='{"stability":0.55,"similarity_boost":0.85,"style":0.0,"use_speaker_boost":true}'

# Pass-through. Earlier we expanded short prompts ("Go." → "Three,
# two, one, go!") but the rewritten output read worse than the
# original on real workouts. Existing clip texts already have
# enough flow ("And done.", "Okay, rest.") for the model.
expand_for_tts() {
    echo "$1"
}

generate() {
    local voice_id="$1"
    local id="$2"
    local text="$3"
    local output="$OUTPUT_DIR/${id}.m4a"
    [ -f "$output" ] && { echo "SKIP $id"; return; }
    echo "GEN  $id"
    local payload_text
    payload_text="$(expand_for_tts "$text")"
    local url="https://api.elevenlabs.io/v1/text-to-speech/$voice_id"
    local tmp=$(mktemp /tmp/voice_XXXXXX.mp3)
    curl -s -X POST "$url" \
        -H "xi-api-key: $ELEVENLABS_API_KEY" \
        -H "Content-Type: application/json" \
        -H "Accept: audio/mpeg" \
        -d "{\"text\":\"${payload_text}\",\"model_id\":\"eleven_turbo_v2_5\",\"voice_settings\":${VOICE_SETTINGS}}" \
        -o "$tmp"
    afconvert "$tmp" "$output" -d aac -f m4af -b 128000 2>/dev/null
    rm -f "$tmp"; sleep 0.5
}

K="$KIRA_VOICE"
J="$JENI_VOICE"
M="$MATSON_VOICE"

echo "=== KIRA (existing plank session clips) ==="

# Kira plank session clips (no prefix, backwards compatible)
generate $K "guide_setup_1" "Okay prop your phone up so I can see your whole body, then get into plank. Forearms on the floor, elbows under your shoulders."
generate $K "guide_setup_2" "Set your phone down about six feet away, lean it against something, then drop into plank position. I need to see you head to toe."
generate $K "guide_setup_3" "Alright, get your phone set up where it can see you, then get down. Forearms flat, toes tucked, body straight like a board."
generate $K "guide_good_1" "Good. Hold."
generate $K "guide_good_2" "That's it."
generate $K "guide_good_3" "Yes. Breathe."
generate $K "hip_sag_1" "Hips! Up! You're giving hammock right now."
generate $K "hip_sag_2" "Hips up. Squeeze your glutes. My mama planks better than this."
generate $K "hip_sag_3" "Hips! Belly button to spine. Don't spill grandma's soup."
generate $K "hip_sag_4" "Hips are sagging. Tuck your tailbone. Tighten everything."
generate $K "hip_sag_5" "Hips! If they drop any lower they'll need their own zip code."
generate $K "hip_sag_6" "Hips up! Engage that core like rent is due tomorrow."
generate $K "hip_pike_1" "Hips down! This is a plank not yoga class."
generate $K "hip_pike_2" "Drop your hips! You look like a tent. Flatten out."
generate $K "hip_pike_3" "Hips down! Cheating doesn't count in this house."
generate $K "hip_pike_4" "Flatten! Your butt is way too high. Straight line."
generate $K "shoulder_1" "Shoulders! Down! You're not a turtle, drop them."
generate $K "shoulder_2" "Shoulders down. Push the floor away. You're planking not panicking."
generate $K "shoulder_3" "Shoulders! Relax. Shoulder blades in your back pockets."
generate $K "shoulder_4" "Drop the shoulders! Your traps didn't sign up for this."
generate $K "recovery_1" "There it is. Hold that."
generate $K "recovery_2" "Good fix. Stay."
generate $K "recovery_3" "See? When you try, you're actually good at this."
generate $K "recovery_4" "That's the one. Don't move."
generate $K "stopped_1" "Back down! I didn't say stop."
generate $K "stopped_2" "Get back in plank! Timer's still going."
generate $K "stopped_3" "Nope! Back down. We're not done."
generate $K "stopped_4" "You stopped? In this economy? Back down."
generate $K "milestone_10" "Ten seconds. Stay tight."
generate $K "milestone_30" "Thirty! Halfway. Check form. Keep going."
generate $K "milestone_60" "One minute! Okay I see you!"
generate $K "milestone_90" "Ninety seconds! Most people quit by now. Not you."
generate $K "milestone_120" "Two minutes! That's elite. Your core is transforming."
generate $K "countdown_10" "Ten seconds! Lock in. Finish strong."
generate $K "countdown_5" "Five!"
generate $K "countdown_3" "Three!"
generate $K "countdown_2" "Two!"
generate $K "countdown_1" "One!"
generate $K "start_1" "I see you. Go."
generate $K "start_2" "You showed up. Let's get it."
generate $K "end_good" "Done! You ate that. See you tomorrow."
generate $K "end_bad" "It's done. We don't talk about it. Tomorrow."
generate $K "camera_bad_1" "Can't see you. Move your phone back."
generate $K "camera_bad_2" "Back up your phone. I need the full picture."

# Coach previews
generate $K "kira_preview" "Hey, I'm Kira. I don't do gentle. But I'll get you right."
generate $J "jeni_preview" "Hi, I'm Jeni. We'll take this one breath at a time."
generate $M "matson_preview" "What's up, I'm Matson. We're gonna have a good time."

# =============================================
# JENI plank session clips
# =============================================
echo ""
echo "=== JENI plank session clips ==="
generate $J "jeni_guide_setup_1" "Set your phone where it can see you, then ease into plank. Forearms down, elbows under shoulders."
generate $J "jeni_guide_setup_2" "Place your phone about six feet away, then come into plank position. I want to see your whole body."
generate $J "jeni_guide_good_1" "Beautiful. Hold that."
generate $J "jeni_guide_good_2" "That's lovely."
generate $J "jeni_guide_good_3" "Yes. Keep breathing."
generate $J "jeni_hip_sag_1" "Gently lift your hips. Think of lengthening your spine."
generate $J "jeni_hip_sag_2" "Hips up a little. Draw your belly in."
generate $J "jeni_hip_sag_3" "Your hips are dropping. Engage your core, lift gently."
generate $J "jeni_hip_pike_1" "Lower your hips just a touch. Find that straight line."
generate $J "jeni_hip_pike_2" "Hips are a bit high. Ease them down."
generate $J "jeni_shoulder_1" "Relax your shoulders away from your ears."
generate $J "jeni_shoulder_2" "Let your shoulders melt down. You're safe here."
generate $J "jeni_recovery_1" "There it is. Beautiful."
generate $J "jeni_recovery_2" "That's the alignment. Hold it."
generate $J "jeni_stopped_1" "Come back when you're ready. We're still going."
generate $J "jeni_stopped_2" "Take a breath, then come back down."
generate $J "jeni_milestone_10" "Ten seconds. You're doing great."
generate $J "jeni_milestone_30" "Thirty seconds. Wonderful."
generate $J "jeni_milestone_60" "One minute. I'm so proud of you."
generate $J "jeni_milestone_90" "Ninety seconds. That's incredible."
generate $J "jeni_milestone_120" "Two minutes. You are amazing."
generate $J "jeni_countdown_10" "Ten seconds left. You've got this."
generate $J "jeni_countdown_5" "Five."
generate $J "jeni_countdown_3" "Three."
generate $J "jeni_countdown_2" "Two."
generate $J "jeni_countdown_1" "One."
generate $J "jeni_start_1" "Whenever you're ready. Go."
generate $J "jeni_start_2" "Let's begin together."
generate $J "jeni_end_good" "You did it. Be proud of yourself."
generate $J "jeni_end_bad" "It's okay. You showed up. That's what matters."
generate $J "jeni_camera_bad_1" "I can't quite see you. Move your phone back a little."
generate $J "jeni_camera_bad_2" "Adjust your phone so I can see your full body."

# =============================================
# MATSON plank session clips
# =============================================
echo ""
echo "=== MATSON plank session clips ==="
generate $M "matson_guide_setup_1" "Prop your phone up so I can see you, then get into plank. Forearms down, let's go."
generate $M "matson_guide_setup_2" "Set your phone down, lean it against something, then drop into plank. I need the full view."
generate $M "matson_guide_good_1" "That's it, hold that."
generate $M "matson_guide_good_2" "Lookin' good."
generate $M "matson_guide_good_3" "Nice. Breathe."
generate $M "matson_hip_sag_1" "Hips up. You're dipping a little."
generate $M "matson_hip_sag_2" "Bring those hips up. Squeeze everything."
generate $M "matson_hip_sag_3" "Hips are sagging on me. Tighten up."
generate $M "matson_hip_pike_1" "Drop your hips down a bit. Straight line."
generate $M "matson_hip_pike_2" "Hips are too high. Flatten it out."
generate $M "matson_shoulder_1" "Shoulders down. Relax 'em."
generate $M "matson_shoulder_2" "Drop those shoulders, you're all tensed up."
generate $M "matson_recovery_1" "There you go. Hold that."
generate $M "matson_recovery_2" "That's the one. Stay right there."
generate $M "matson_stopped_1" "Hey, get back down. We're not done."
generate $M "matson_stopped_2" "Back in plank. Timer's still going."
generate $M "matson_milestone_10" "Ten seconds. Solid."
generate $M "matson_milestone_30" "Thirty seconds. Halfway there."
generate $M "matson_milestone_60" "One minute. That's what's up."
generate $M "matson_milestone_90" "Ninety seconds. You're killing it."
generate $M "matson_milestone_120" "Two minutes. Beast mode."
generate $M "matson_countdown_10" "Ten seconds left. Finish strong."
generate $M "matson_countdown_5" "Five."
generate $M "matson_countdown_3" "Three."
generate $M "matson_countdown_2" "Two."
generate $M "matson_countdown_1" "One."
generate $M "matson_start_1" "Alright, let's go."
generate $M "matson_start_2" "Here we go. You got this."
generate $M "matson_end_good" "That was sick. See you next time."
generate $M "matson_end_bad" "It happens. We'll get it next time."
generate $M "matson_camera_bad_1" "Can't see you. Back your phone up."
generate $M "matson_camera_bad_2" "Move your phone back, I need the full picture."

# =============================================
# ROUTINE MODE — All three trainers
# =============================================

generate_routine_clips() {
    local V="$1"
    local P="$2"  # prefix: "" for Kira, "jeni_" for Jeni, "matson_" for Matson

    # --- Session bookends ---
    # routine_start_* clips are the welcome on PreRoutineView. Length
    # target ~5-7s — enough for a proper instructor-style intro, short
    # enough to not delay the user from tapping Start. Texts are
    # persona-specific (mindful/warm for Jeni, sassy for Kira, chill
    # for Sam). The specific workout details (focus area, duration,
    # exercise list) live on the screen visually; voice carries
    # personality + framing.
    case "$P" in
        jeni_)
            generate $V "${P}routine_start_1" "Welcome. Take a breath and settle in. Today is about moving with intention. I'll be with you the whole way."
            generate $V "${P}routine_start_2" "I'm glad you're here. We'll check in with your body, work through this together, and finish feeling stronger. Whenever you're ready."
            generate $V "${P}routine_start_3" "Take a moment to land in your body. Today we're going to move steady and present. Tap start when you're ready."
            generate $V "${P}routine_done_1" "Beautiful work. You should feel proud of yourself."
            generate $V "${P}routine_done_2" "You did it. Take a moment to appreciate that."
            generate $V "${P}routine_done_3" "All done. Your body is grateful for that."
            generate $V "${P}routine_done_4" "Wonderful. You showed up for yourself today."
            generate $V "${P}routine_done_5" "Session complete. Carry this feeling with you."
            ;;
        matson_)
            generate $V "${P}routine_start_1" "Alright, glad you showed up. We're gonna take this nice and steady — solid work, no rushing. Tap start when you're ready."
            generate $V "${P}routine_start_2" "Here we go. Quick check-in with the body, then we'll get to it together. You've got this."
            generate $V "${P}routine_start_3" "Let's do this thing. I'll keep the pace honest, you stay with the form, and we'll be done before you know it."
            generate $V "${P}routine_done_1" "Dude, you crushed that. Seriously."
            generate $V "${P}routine_done_2" "That's what I'm talking about. Good stuff."
            generate $V "${P}routine_done_3" "Nice work, that was solid."
            generate $V "${P}routine_done_4" "And done! You're a beast, you know that?"
            generate $V "${P}routine_done_5" "That's a wrap. You killed it today."
            ;;
        *)
            generate $V "routine_start_1" "Alright, time to work. Show up, do the reps, no excuses. Tap start when you're ready and let's go."
            generate $V "routine_start_2" "I see you out here. We're going hard but smart — form first, ego last. Hit start, let's get it."
            generate $V "routine_start_3" "Let's get into it. I'll keep you honest, you keep showing up. That's the deal. Tap start."
            generate $V "routine_done_1" "Yes! You just put in real work. I'm proud of you."
            generate $V "routine_done_2" "Done! That was all you. Remember this feeling."
            generate $V "routine_done_3" "You showed up and you finished. That's everything."
            generate $V "routine_done_4" "Workout complete! Your body is thanking you right now."
            generate $V "routine_done_5" "That's a wrap! You're getting stronger every single time."
            ;;
    esac

    # --- Exercise intros ---
    case "$P" in
        jeni_)
            generate $V "${P}intro_bicycle_crunch" "Bicycle crunches. Nice and controlled."
            generate $V "${P}intro_reverse_crunch" "Reverse crunches. Bring those knees in gently."
            generate $V "${P}intro_leg_raises" "Leg raises. Slow, mindful movements."
            generate $V "${P}intro_flutter_kicks" "Flutter kicks. Keep them light."
            generate $V "${P}intro_toe_touches" "Toe touches. Reach up, connect."
            generate $V "${P}intro_v_ups" "V-ups. Meet in the middle."
            generate $V "${P}intro_dead_bug" "Dead bug. Opposite arm, opposite leg."
            generate $V "${P}intro_hollow_body_hold" "Hollow body. Press down and hold."
            generate $V "${P}intro_russian_twists" "Russian twists. Easy rotation."
            generate $V "${P}intro_side_plank_left" "Side plank, left side. Find your balance."
            generate $V "${P}intro_side_plank_right" "Side plank, right side. Stay centered."
            generate $V "${P}intro_oblique_crunch_left" "Oblique crunch, left side."
            generate $V "${P}intro_oblique_crunch_right" "Oblique crunch, right side."
            generate $V "${P}intro_woodchoppers" "Woodchoppers. Twist through your core."
            generate $V "${P}intro_superman_hold" "Superman hold. Lift and breathe."
            generate $V "${P}intro_superman_pulses" "Superman pulses. Gentle up and down."
            generate $V "${P}intro_bird_dog" "Bird dog. Extend and balance."
            generate $V "${P}intro_glute_bridge_hold" "Glute bridge. Lift and squeeze."
            generate $V "${P}intro_glute_bridge_marches" "Glute bridge marches. One at a time."
            generate $V "${P}intro_mountain_climbers" "Mountain climbers. Find your rhythm."
            generate $V "${P}intro_plank_shoulder_taps" "Shoulder taps. Stay steady."
            generate $V "${P}intro_bear_crawl_hold" "Bear crawl hold. Knees just off the ground."
            generate $V "${P}intro_inchworms" "Inchworms. Walk out and back."
            generate $V "${P}intro_high_knees" "High knees. Light on your feet."
            ;;
        matson_)
            generate $V "${P}intro_bicycle_crunch" "Bicycle crunches. Elbow to knee, let's go."
            generate $V "${P}intro_reverse_crunch" "Reverse crunches. Pull those knees up."
            generate $V "${P}intro_leg_raises" "Leg raises. Keep 'em smooth."
            generate $V "${P}intro_flutter_kicks" "Flutter kicks. Low and steady."
            generate $V "${P}intro_toe_touches" "Toe touches. Reach for it."
            generate $V "${P}intro_v_ups" "V-ups. This one's fun, trust me."
            generate $V "${P}intro_dead_bug" "Dead bug. Opposite arm, opposite leg."
            generate $V "${P}intro_hollow_body_hold" "Hollow body hold. Lock it in."
            generate $V "${P}intro_russian_twists" "Russian twists. Side to side, nice and easy."
            generate $V "${P}intro_side_plank_left" "Side plank, left side. Stack it up."
            generate $V "${P}intro_side_plank_right" "Side plank, right side. Same vibe."
            generate $V "${P}intro_oblique_crunch_left" "Oblique crunch, left side."
            generate $V "${P}intro_oblique_crunch_right" "Oblique crunch, right side."
            generate $V "${P}intro_woodchoppers" "Woodchoppers. Twist and rip."
            generate $V "${P}intro_superman_hold" "Superman. Arms up, legs up, fly."
            generate $V "${P}intro_superman_pulses" "Superman pulses. Up and down."
            generate $V "${P}intro_bird_dog" "Bird dog. Balance it out."
            generate $V "${P}intro_glute_bridge_hold" "Glute bridge. Hips up, hold it."
            generate $V "${P}intro_glute_bridge_marches" "Bridge marches. Keep those hips level."
            generate $V "${P}intro_mountain_climbers" "Mountain climbers. Let's pick it up."
            generate $V "${P}intro_plank_shoulder_taps" "Shoulder taps. Don't wobble on me."
            generate $V "${P}intro_bear_crawl_hold" "Bear crawl hold. Knees hovering."
            generate $V "${P}intro_inchworms" "Inchworms. Walk it out."
            generate $V "${P}intro_high_knees" "High knees. Get 'em up."
            ;;
        *)
            generate $V "intro_bicycle_crunch" "Bicycle crunches. Elbow to knee."
            generate $V "intro_reverse_crunch" "Reverse crunches. Knees to chest."
            generate $V "intro_leg_raises" "Leg raises. Slow and controlled."
            generate $V "intro_flutter_kicks" "Flutter kicks. Keep 'em low."
            generate $V "intro_toe_touches" "Toe touches. Reach up, crunch up."
            generate $V "intro_v_ups" "V-ups. Hands and feet meet in the middle."
            generate $V "intro_dead_bug" "Dead bug. Opposite arm, opposite leg."
            generate $V "intro_hollow_body_hold" "Hollow body. Press your back down. Hold."
            generate $V "intro_russian_twists" "Russian twists. Side to side."
            generate $V "intro_side_plank_left" "Side plank. Left side. Hips up."
            generate $V "intro_side_plank_right" "Side plank. Right side. Hips up."
            generate $V "intro_oblique_crunch_left" "Oblique crunch. Left side."
            generate $V "intro_oblique_crunch_right" "Oblique crunch. Right side."
            generate $V "intro_woodchoppers" "Woodchoppers. Twist and drive."
            generate $V "intro_superman_hold" "Superman hold. Arms and legs up. Fly."
            generate $V "intro_superman_pulses" "Superman pulses. Up and down."
            generate $V "intro_bird_dog" "Bird dog. Opposite arm, opposite leg."
            generate $V "intro_glute_bridge_hold" "Glute bridge. Hips up. Squeeze."
            generate $V "intro_glute_bridge_marches" "Glute bridge marches. Keep hips level."
            generate $V "intro_mountain_climbers" "Mountain climbers. Drive those knees."
            generate $V "intro_plank_shoulder_taps" "Shoulder taps. Don't rock. Stable."
            generate $V "intro_bear_crawl_hold" "Bear crawl hold. Knees off the floor."
            generate $V "intro_inchworms" "Inchworms. Walk out, walk back."
            generate $V "intro_high_knees" "High knees. Drive 'em up."
            ;;
    esac

    # --- Tempo / Hold / Rest / Cues ---
    case "$P" in
        jeni_)
            generate $V "${P}tempo_1" "Keep flowing, keep flowing."
            generate $V "${P}tempo_2" "Stay with the movement."
            generate $V "${P}tempo_3" "Beautiful pace."
            generate $V "${P}tempo_4" "A little quicker now."
            generate $V "${P}tempo_twist_1" "Twist gently, twist gently."
            generate $V "${P}tempo_twist_2" "Side to side, breathe through it."
            generate $V "${P}tempo_drive_1" "Keep moving, keep moving."
            generate $V "${P}tempo_drive_2" "Lift a little higher."
            generate $V "${P}hold_1" "Hold right here. Breathe."
            generate $V "${P}hold_2" "Stay present."
            generate $V "${P}hold_3" "You're doing beautifully."
            generate $V "${P}hold_4" "Just a little longer."
            generate $V "${P}hold_5" "That trembling is strength building."
            generate $V "${P}hold_6" "Almost there, stay with me."
            generate $V "${P}rest_1" "Rest now."
            generate $V "${P}rest_2" "Take a breath in."
            generate $V "${P}rest_3" "Let your muscles relax."
            generate $V "${P}rest_4" "Nice and easy."
            generate $V "${P}exercise_countdown" "Go."
            generate $V "${P}exercise_almost" "Five more seconds."
            generate $V "${P}exercise_done" "And rest."
            generate $V "${P}encourage_1" "You're doing so well."
            generate $V "${P}encourage_2" "I believe in you."
            generate $V "${P}encourage_3" "That's beautiful form."
            generate $V "${P}encourage_4" "You're stronger than you know."
            generate $V "${P}encourage_5" "Listen to your body, it's grateful."
            generate $V "${P}skip_1" "That's okay, next one."
            generate $V "${P}skip_2" "Moving forward."
            ;;
        matson_)
            generate $V "${P}tempo_1" "Keep it rolling, keep it rolling."
            generate $V "${P}tempo_2" "Don't slow down on me now."
            generate $V "${P}tempo_3" "That's the pace right there."
            generate $V "${P}tempo_4" "Little faster, you got it."
            generate $V "${P}tempo_twist_1" "Twist it, twist it."
            generate $V "${P}tempo_twist_2" "Side to side, lookin' good."
            generate $V "${P}tempo_drive_1" "Drive, drive, drive."
            generate $V "${P}tempo_drive_2" "Get those knees up higher."
            generate $V "${P}hold_1" "Hold that right there."
            generate $V "${P}hold_2" "Stay locked in."
            generate $V "${P}hold_3" "You're chillin', you got this."
            generate $V "${P}hold_4" "Don't drop, almost there."
            generate $V "${P}hold_5" "That shake means it's working."
            generate $V "${P}hold_6" "So close, hang tight."
            generate $V "${P}rest_1" "Take a breather."
            generate $V "${P}rest_2" "Catch your breath."
            generate $V "${P}rest_3" "Shake it loose."
            generate $V "${P}rest_4" "Quick break, stay loose."
            generate $V "${P}exercise_countdown" "Let's go."
            generate $V "${P}exercise_almost" "Five seconds left."
            generate $V "${P}exercise_done" "Nice, done."
            generate $V "${P}encourage_1" "You got this, easy."
            generate $V "${P}encourage_2" "There it is."
            generate $V "${P}encourage_3" "Lookin' strong."
            generate $V "${P}encourage_4" "That's what I like to see."
            generate $V "${P}encourage_5" "You're built for this."
            generate $V "${P}roast_1" "Come on, my little sister goes harder."
            generate $V "${P}roast_2" "That's all you got? I've seen more effort at brunch."
            generate $V "${P}roast_3" "You're lucky you're cute."
            generate $V "${P}roast_4" "I'm not mad, just disappointed. Kidding."
            generate $V "${P}skip_1" "No worries, next."
            generate $V "${P}skip_2" "Onto the next one."
            ;;
        *)
            generate $V "tempo_1" "Keep going, keep going."
            generate $V "tempo_2" "Don't stop on me."
            generate $V "tempo_3" "Same pace, same pace."
            generate $V "tempo_4" "Pick it up, pick it up."
            generate $V "tempo_twist_1" "Twist, twist."
            generate $V "tempo_twist_2" "Side to side."
            generate $V "tempo_drive_1" "Drive, drive."
            generate $V "tempo_drive_2" "Get those knees higher."
            generate $V "hold_1" "Hold it right there."
            generate $V "hold_2" "Stay with me."
            generate $V "hold_3" "Don't you move."
            generate $V "hold_4" "Don't you drop."
            generate $V "hold_5" "That shake is good."
            generate $V "hold_6" "Almost there."
            generate $V "rest_1" "Okay, rest."
            generate $V "rest_2" "Catch your breath."
            generate $V "rest_3" "Shake it out, shake it out."
            generate $V "rest_4" "Quick break, stay ready."
            generate $V "exercise_countdown" "Go."
            generate $V "exercise_almost" "Five seconds left."
            generate $V "exercise_done" "And done."
            generate $V "encourage_1" "You got this."
            generate $V "encourage_2" "There you go."
            generate $V "encourage_3" "That's it, that's it."
            generate $V "encourage_4" "I see you working."
            generate $V "encourage_5" "You're stronger than you think."
            generate $V "roast_1" "My grandma moves faster than that."
            generate $V "roast_2" "That's the best you got? Really?"
            generate $V "roast_3" "I've seen better form on a pool noodle."
            generate $V "roast_4" "You're lucky I can't reach through the phone."
            generate $V "skip_1" "Next."
            generate $V "skip_2" "Moving on."
            ;;
    esac
}

echo ""
echo "=== KIRA routine clips ==="
generate_routine_clips "$KIRA_VOICE" ""

echo ""
echo "=== JENI routine clips ==="
generate_routine_clips "$JENI_VOICE" "jeni_"

echo ""
echo "=== MATSON routine clips ==="
generate_routine_clips "$MATSON_VOICE" "matson_"

# =============================================
# prep_short_<id> — exercise-name-only cues for the 6-11s prep window.
# Per docs/workout_session_rules.md §7. Source list lives in
# Scripts/prep_short_clips.tsv (128 entries, regenerated from
# ExerciseBankData when the bank changes).
#
# Each clip says "Next up is <name>." in the trainer's voice. Style
# variation comes from the voice itself (the text stays identical so
# we don't have to hand-author 384 lines). Skip-on-existing keeps the
# rerun cost at zero once a clip is generated.
# =============================================

generate_prep_shorts() {
    local V="$1"
    local P="$2"  # prefix: "" / "jeni_" / "matson_"
    while IFS=$'\t' read -r id name; do
        # Skip header line + any blank rows.
        [[ "$id" =~ ^# ]] && continue
        [ -z "$id" ] && continue
        generate "$V" "${P}prep_short_${id}" "Next up is ${name}."
    done < "$SCRIPT_DIR/prep_short_clips.tsv"
}

echo ""
echo "=== prep_short × 3 trainers (128 exercises each) ==="
echo "--- Kira ---"
generate_prep_shorts "$KIRA_VOICE" ""
echo "--- Jeni ---"
generate_prep_shorts "$JENI_VOICE" "jeni_"
echo "--- Matson ---"
generate_prep_shorts "$MATSON_VOICE" "matson_"

# =============================================
# prep_full_<id> — long prep window cue (≥12s). Combines exercise
# name + position-specific setup instruction. The position lookup
# below is shared across all three trainers; voice character comes
# from the synth, not the text. Per docs/workout_session_rules.md §7.
# =============================================

# Position → setup-cue text. Keep these calm + concrete; the user
# is preparing for the move during this window.
position_cue() {
    case "$1" in
        standing)   echo "Stand tall, feet shoulder-width." ;;
        quadruped)  echo "Hands and knees, wrists under shoulders." ;;
        plank)      echo "Forearms down, body in a straight line." ;;
        prone)      echo "Lie face down on the mat." ;;
        sideLying)  echo "Lie on your side, hips stacked." ;;
        supine)     echo "Lie on your back, knees bent." ;;
        seated)     echo "Sit up tall, legs out long." ;;
        *)          echo "Get into position." ;;
    esac
}

generate_prep_fulls() {
    local V="$1"
    local P="$2"  # prefix: "" / "jeni_" / "matson_"
    while IFS=$'\t' read -r id name position; do
        [[ "$id" =~ ^# ]] && continue
        [ -z "$id" ] && continue
        local cue
        cue="$(position_cue "$position")"
        generate "$V" "${P}prep_full_${id}" "Next up is ${name}. ${cue}"
    done < "$SCRIPT_DIR/prep_full_clips.tsv"
}

echo ""
echo "=== prep_full × 3 trainers (128 exercises each) ==="
echo "--- Kira ---"
generate_prep_fulls "$KIRA_VOICE" ""
echo "--- Jeni ---"
generate_prep_fulls "$JENI_VOICE" "jeni_"
echo "--- Matson ---"
generate_prep_fulls "$MATSON_VOICE" "matson_"

# =============================================
# Switch-sides hops — minimal cues for unilateral L→R transitions.
# Per docs/workout_session_rules.md §7: when same exerciseId fires
# back-to-back with different .side, play one of these instead of
# re-introducing the exercise. Same exercise, just other side.
# =============================================

echo ""
echo "=== Switch-sides cues (3 trainers × 2 variants) ==="

# Kira (un-prefixed — voice manager falls back to base names)
generate $K "switch_sides_1" "Other side."
generate $K "switch_sides_2" "Switch sides."

# Jeni
generate $J "jeni_switch_sides_1" "Now the other side."
generate $J "jeni_switch_sides_2" "Switch sides, gently."

# Matson (will be renamed to Sam in the next ElevenLabs pass per
# docs/workout_session_rules.md §7).
generate $M "matson_switch_sides_1" "Other side, let's go."
generate $M "matson_switch_sides_2" "Switch sides."

echo ""
echo "=== Done! $(ls "$OUTPUT_DIR"/*.m4a 2>/dev/null | wc -l | tr -d ' ') clips ==="
