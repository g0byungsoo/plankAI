import Foundation

/// Instructional content for the in-session "info" sheet (Justfit-style).
/// Lives in a separate file from `ExerciseBankData.swift` because that
/// file is auto-generated from the spreadsheet via
/// `Scripts/build_workout_data.py` and gets wiped on regeneration —
/// rich coaching copy needs a stable home that survives data refreshes.
///
/// Lookup is by `Exercise.id`. Missing entries don't crash anything —
/// the info sheet falls back to a quiet quick-facts panel built from
/// `targetAreas` + `position`. All 128 exercises in the bank are
/// covered as of this revision; new bank entries should land here too.
///
/// Tone: lowercase, JeniFit-casual. Declarative when describing the
/// position; imperative when describing the motion. No exclamation
/// points. Each entry: 5–7 action steps, 2–3 breathing notes,
/// 2–4 action-feeling cues, 3–5 common mistakes.
struct ExerciseInstructions {
    let actionSteps: [String]
    let breathing: [String]
    let actionFeeling: [String]
    let commonMistakes: [String]
}

enum ExerciseInstructionRegistry {
    static func instructions(for id: String) -> ExerciseInstructions? {
        all[id]
    }

    private static let all: [String: ExerciseInstructions] = [

        // MARK: - Plank variations

        "plank_saw": ExerciseInstructions(
            actionSteps: [
                "start in a forearm plank — your elbows are directly under your shoulders, forearms parallel.",
                "your feet are hip-width apart, toes pressing firmly into the floor.",
                "engage your core so your shoulders, hips, and heels form one long line.",
                "using your toes, slide your entire body forward about an inch — your nose moves past your hands.",
                "pause, then slide back the same inch — your shoulders return behind your elbows.",
                "the motion comes from your feet — your arms stay anchored, your hips stay level.",
            ],
            breathing: [
                "exhale as you slide forward.",
                "inhale as you slide back.",
                "never hold your breath — the deep core fires best with steady airflow.",
            ],
            actionFeeling: [
                "deep burn through the lower abdominals as your body shifts forward.",
                "your shoulders and chest work to keep the plank stable.",
                "the back of your neck stays long — eyes between your hands.",
            ],
            commonMistakes: [
                "letting your hips sag toward the floor as you slide forward.",
                "piking your hips up to make the slide easier.",
                "moving too quickly — small, controlled inches build the strength.",
                "shrugging your shoulders up to your ears.",
            ]
        ),

        "mountain_climbers": ExerciseInstructions(
            actionSteps: [
                "start in a high plank — hands directly under your shoulders, fingers spread wide.",
                "your body forms one straight line from head to heels.",
                "engage your core so your hips stay level the entire time.",
                "drive your right knee in toward your chest, keeping your hips low.",
                "as you return the right leg, drive your left knee in.",
                "switch quickly — like running in place with your hands on the floor.",
            ],
            breathing: [
                "short rhythmic breaths — in through the nose, out through the mouth.",
                "match the breath to the pace — never hold.",
            ],
            actionFeeling: [
                "core firing to keep your hips from rising or rotating.",
                "shoulders and chest supporting the plank.",
                "you should feel out of breath quickly — that's the cardio.",
            ],
            commonMistakes: [
                "hips rising up into a piking shape — keep them low and level.",
                "slamming the feet — stay light on the ball of the foot.",
                "shoulders drifting in front of the hands.",
                "running so fast that form breaks down.",
            ]
        ),

        "kneeling_shoulder_tap": ExerciseInstructions(
            actionSteps: [
                "start on your hands and knees with your knees under your hips and wrists under your shoulders.",
                "lift your knees an inch off the floor so you're balancing on toes + hands.",
                "engage your core to keep your hips perfectly square to the floor.",
                "lift your right hand and tap your left shoulder.",
                "place the right hand back down with control, then tap the right shoulder with your left hand.",
                "your hips should not rock side to side — that's the entire challenge.",
            ],
            breathing: [
                "exhale on each tap.",
                "inhale between taps.",
            ],
            actionFeeling: [
                "deep core working hard to resist the rotation each time you lift a hand.",
                "your supporting shoulder stabilizes the body weight.",
            ],
            commonMistakes: [
                "rocking the hips side to side — the goal is anti-rotation.",
                "rushing — slow taps make the core work harder.",
                "letting the hips sag or pike.",
            ]
        ),

        "high_plank_leg_raise": ExerciseInstructions(
            actionSteps: [
                "start in a high plank — wrists under shoulders, body in one straight line.",
                "engage your core and squeeze your glutes.",
                "lift your right leg straight up about 6 inches — keep the leg straight and the foot flexed.",
                "lower with control — don't let the leg drop.",
                "alternate sides.",
            ],
            breathing: [
                "exhale as you lift the leg.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "the glute of the lifted leg activating.",
                "core firing to keep the hips square.",
            ],
            commonMistakes: [
                "letting the hips tilt or rotate as the leg lifts.",
                "lifting the leg too high — height isn't the point, control is.",
                "shoulders shrugging — keep them pressed away from the ears.",
            ]
        ),

        "low_plank_leg_raise": ExerciseInstructions(
            actionSteps: [
                "start in a forearm plank — elbows under shoulders, body in one line.",
                "engage your core and glutes.",
                "lift your right leg straight up a few inches, keeping it long.",
                "lower with control — don't drop.",
                "alternate sides.",
            ],
            breathing: [
                "exhale as you lift.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "lifted leg's glute squeezing.",
                "core resisting any sway of the hips.",
            ],
            commonMistakes: [
                "hips tilting toward the lifted leg.",
                "lifting the leg so high it arches the lower back.",
                "letting the hips drop on the supporting side.",
            ]
        ),

        "plank_jacks": ExerciseInstructions(
            actionSteps: [
                "start in a forearm plank with your feet together.",
                "engage your core and keep your hips level.",
                "jump your feet wide — slightly past hip-width — landing softly on the balls of your feet.",
                "jump them back together with the same control.",
                "your shoulders, hips, and head should not bounce up and down.",
            ],
            breathing: [
                "exhale as you jump out.",
                "inhale as you jump back.",
            ],
            actionFeeling: [
                "core working overtime to keep the plank stable.",
                "inner thighs and outer hips engaging on each jump.",
            ],
            commonMistakes: [
                "hips piking up on each jump.",
                "landing hard — stay light on the balls of the feet.",
                "losing the plank shape as fatigue sets in.",
            ]
        ),

        "plank_frog_jump": ExerciseInstructions(
            actionSteps: [
                "start in a high plank with your hands under your shoulders.",
                "engage your core.",
                "jump both feet forward toward the outside of your hands — like a frog squat at the top of the plank.",
                "land softly with your feet wider than your hands.",
                "jump back to the starting plank position.",
            ],
            breathing: [
                "exhale as you jump forward.",
                "inhale as you jump back.",
            ],
            actionFeeling: [
                "explosive engagement through the core and hips.",
                "quads and glutes loading as you land.",
            ],
            commonMistakes: [
                "landing with feet too narrow — they should frame the hands.",
                "shoulders collapsing forward of the wrists on landing.",
                "rushing — controlled landings keep the wrists safe.",
            ]
        ),

        "plank_run": ExerciseInstructions(
            actionSteps: [
                "start in a forearm plank.",
                "engage your core to keep your hips level and your back flat.",
                "alternate driving each knee in toward your chest, like running while planking.",
                "your hips stay low and your shoulders don't bounce.",
                "keep the pace steady — quality of plank shape over speed.",
            ],
            breathing: [
                "short, rhythmic breaths matched to the pace.",
            ],
            actionFeeling: [
                "deep core and shoulders working to hold the plank.",
                "hip flexors driving each knee.",
            ],
            commonMistakes: [
                "hips popping up with each knee drive.",
                "stomping the feet — stay light.",
                "shoulders drifting forward of the elbows.",
            ]
        ),

        "diagonal_plank": ExerciseInstructions(
            actionSteps: [
                "start in a forearm plank with feet hip-width.",
                "engage your core and squeeze your glutes.",
                "rotate your right hip toward the floor — hovering just above it — then return through center.",
                "rotate your left hip toward the floor next.",
                "your shoulders stay square; only the hips rotate.",
            ],
            breathing: [
                "exhale as you rotate down.",
                "inhale as you return to center.",
            ],
            actionFeeling: [
                "deep burn through the obliques on each rotation.",
                "shoulders stable, core wrapping around the spine.",
            ],
            commonMistakes: [
                "rotating the shoulders along with the hips.",
                "letting the hip touch the floor — keep it hovering.",
                "rushing the rotation — slow is what wakes up the obliques.",
            ]
        ),

        "floor_dip": ExerciseInstructions(
            actionSteps: [
                "sit on the floor with your knees bent, feet flat.",
                "place your hands behind you, fingertips pointing toward your hips, palms flat.",
                "lift your hips so your torso forms a reverse tabletop.",
                "bend your elbows to lower your hips toward the floor — just a few inches.",
                "press through your palms to extend your elbows and return to the top.",
                "keep your hips lifted throughout — don't sit back down between reps.",
            ],
            breathing: [
                "inhale as you lower.",
                "exhale as you press up.",
            ],
            actionFeeling: [
                "the back of your arms — triceps — doing the work.",
                "your shoulders stay open, not shrugged up to your ears.",
            ],
            commonMistakes: [
                "flaring the elbows out to the sides — keep them tracking back.",
                "letting the hips drop on the way down.",
                "pointing the fingers away from the body — point them toward the hips.",
            ]
        ),

        // MARK: - Lower back / posterior chain (prone)

        "alternating_superman": ExerciseInstructions(
            actionSteps: [
                "lie face-down. arms reach overhead, fingertips long; legs straight, toes pointed.",
                "your forehead rests lightly on the floor — neck stays neutral.",
                "engage your glutes and low back.",
                "lift your right arm and left leg an inch or two off the floor at the same time.",
                "pause for a beat, then lower with control.",
                "lift your left arm and right leg next.",
            ],
            breathing: [
                "exhale as you lift.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "muscles along your low back activating.",
                "glute of the lifted leg squeezing.",
            ],
            commonMistakes: [
                "yanking the limbs up — the lift is small and controlled.",
                "lifting the head and crunching the neck.",
                "holding the breath through the lift.",
            ]
        ),

        "back_extension_lying": ExerciseInstructions(
            actionSteps: [
                "lie face-down with your hands behind your head or by your temples.",
                "your feet are hip-width apart, resting on the floor.",
                "engage your low back muscles to lift your chest a few inches off the floor.",
                "pause at the top — your gaze stays toward the floor, not up at the ceiling.",
                "lower with control.",
            ],
            breathing: [
                "exhale as you lift.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "the muscles of the lower back doing the work.",
                "the upper body lifts as one piece — no chin-lead.",
            ],
            commonMistakes: [
                "lifting too high and crunching the lower back.",
                "yanking the head up to lead with the chin.",
                "letting the feet kick up off the floor for momentum.",
            ]
        ),

        "superman_pull_up": ExerciseInstructions(
            actionSteps: [
                "lie face-down with your arms reaching overhead.",
                "lift your chest, arms, and legs a few inches off the floor — superman position.",
                "from the top, pull your elbows down and back, squeezing your shoulder blades together.",
                "your arms form a W shape next to your ribs at the bottom of the pull.",
                "reach back overhead and repeat.",
            ],
            breathing: [
                "exhale as you pull.",
                "inhale as you reach.",
            ],
            actionFeeling: [
                "upper back muscles — between the shoulder blades — squeezing on each pull.",
                "low back active to keep the chest lifted.",
            ],
            commonMistakes: [
                "letting the chest drop between reps.",
                "shrugging the shoulders up toward the ears.",
                "rushing — the squeeze at the bottom is the rep.",
            ]
        ),

        "superman_hold": ExerciseInstructions(
            actionSteps: [
                "lie face-down with arms extended overhead and legs straight.",
                "lift your chest, arms, and legs off the floor at the same time.",
                "reach long through your fingertips and your toes.",
                "your gaze stays at the floor — neck long and neutral.",
                "hold the position — breathe — until the timer ends.",
            ],
            breathing: [
                "steady inhale and exhale through the hold.",
                "never let the breath stop.",
            ],
            actionFeeling: [
                "low back and glutes engaged the entire time.",
                "shoulders open and active to keep the arms lifted.",
            ],
            commonMistakes: [
                "yanking the head up to look forward.",
                "letting the body sag back to the floor in the middle of the hold.",
                "tensing the neck to compensate.",
            ]
        ),

        "w_raise": ExerciseInstructions(
            actionSteps: [
                "lie face-down with your arms bent in a W shape — elbows out wide, hands by your shoulders.",
                "your forehead rests lightly on the floor.",
                "squeeze your shoulder blades together and lift your hands and elbows off the floor.",
                "your arms stay in the W shape throughout — don't let them straighten.",
                "lower with control.",
            ],
            breathing: [
                "exhale as you lift.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "upper back muscles between the shoulder blades activating.",
                "rear shoulders engaging to lift the elbows.",
            ],
            commonMistakes: [
                "leading with the hands instead of the elbows.",
                "shrugging the shoulders up to the ears.",
                "lifting the head off the floor.",
            ]
        ),

        "y_raise": ExerciseInstructions(
            actionSteps: [
                "lie face-down with your arms reaching overhead in a Y shape — wider than shoulder-width.",
                "thumbs point up toward the ceiling.",
                "lift your arms a few inches off the floor, keeping them long.",
                "pause at the top, then lower with control.",
            ],
            breathing: [
                "exhale as you lift.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "lower trapezius (between and below the shoulder blades) doing the lift.",
                "shoulders engaging without shrugging.",
            ],
            commonMistakes: [
                "shrugging the shoulders up to the ears.",
                "rotating the thumbs down — keep them pointing up.",
                "lifting too high and using the lower back.",
            ]
        ),

        "baby_cobra": ExerciseInstructions(
            actionSteps: [
                "lie face-down with your palms flat on the floor under your shoulders.",
                "your elbows hug close to your ribs.",
                "press the tops of your feet and your pelvis gently into the floor.",
                "use your back muscles — not your hands — to lift your chest a few inches.",
                "your gaze stays forward and slightly down, neck long.",
                "hold or lower with control.",
            ],
            breathing: [
                "inhale as you lift.",
                "exhale as you lower.",
            ],
            actionFeeling: [
                "gentle activation through the lower back.",
                "shoulders stay relaxed and away from the ears.",
            ],
            commonMistakes: [
                "pushing up with the hands instead of lifting with the back.",
                "throwing the head back and crunching the neck.",
                "letting the elbows flare out wide.",
            ]
        ),

        "cobra": ExerciseInstructions(
            actionSteps: [
                "lie face-down with palms flat under your shoulders, elbows close to your sides.",
                "press into the floor with your hands to lift your chest and upper torso.",
                "your pelvis stays connected to the floor.",
                "open your chest and roll your shoulders down and back.",
                "your gaze is forward — neck long, not thrown back.",
                "hold the position, breathing steadily.",
            ],
            breathing: [
                "inhale as you lift up.",
                "breathe steadily through the hold.",
            ],
            actionFeeling: [
                "stretch across the front of the chest and abdomen.",
                "low back engaged but not crunching.",
            ],
            commonMistakes: [
                "shoulders hunching up by the ears.",
                "lifting the pelvis off the floor.",
                "locking the elbows aggressively — keep a soft micro-bend.",
            ]
        ),

        "upward_dog": ExerciseInstructions(
            actionSteps: [
                "lie face-down with hands under your shoulders.",
                "press into your palms and the tops of your feet to lift your entire body off the floor — thighs hover above the ground.",
                "your arms straighten, your chest opens, your shoulders roll down.",
                "your hips lift but your back doesn't collapse — keep the line long.",
                "gaze is forward, neck long.",
            ],
            breathing: [
                "inhale as you press up.",
                "steady breath in the hold.",
            ],
            actionFeeling: [
                "deep opening across the chest, shoulders, and front of the hips.",
                "back of the body lengthens, front of the body stretches.",
            ],
            commonMistakes: [
                "letting the shoulders hunch up.",
                "letting the thighs drop and resting on the floor.",
                "throwing the head back — keep the neck long.",
            ]
        ),

        "sphinx": ExerciseInstructions(
            actionSteps: [
                "lie face-down. place your forearms on the floor in front of you, elbows directly under your shoulders.",
                "your forearms are parallel, palms pressing into the floor.",
                "press into your forearms to lift your chest.",
                "your pelvis stays heavy and connected to the floor.",
                "shoulders roll down and back.",
                "hold and breathe.",
            ],
            breathing: [
                "steady inhale and exhale through the hold.",
            ],
            actionFeeling: [
                "gentle stretch through the front of the body.",
                "low back active but not strained.",
                "shoulders open, neck long.",
            ],
            commonMistakes: [
                "shrugging the shoulders.",
                "letting the chin drop.",
                "elbows drifting forward of the shoulders.",
            ]
        ),

        "bow_pose": ExerciseInstructions(
            actionSteps: [
                "lie face-down. bend your knees and reach back to grab your ankles (or shins).",
                "your knees stay hip-width apart — don't let them splay wide.",
                "kick your feet back into your hands to lift your chest and thighs.",
                "your weight rests on your belly.",
                "open your chest and breathe into the front of your body.",
            ],
            breathing: [
                "inhale as you lift.",
                "breathe steadily in the hold — the lift sustains on the kick, not on holding the breath.",
            ],
            actionFeeling: [
                "deep stretch across the front of the body — quads, hip flexors, chest.",
                "the lift comes from the legs kicking back into the hands.",
            ],
            commonMistakes: [
                "trying to pull the feet up with the arms — the arms hold, the legs kick.",
                "letting the knees splay wide apart.",
                "holding the breath.",
            ]
        ),

        "backbend": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet hip-width apart.",
                "place your hands on your lower back, fingertips pointing down.",
                "press your hips slightly forward and lift your chest up toward the ceiling.",
                "let your head follow gently — don't force the neck back.",
                "hold the gentle backbend, breathing steady.",
                "come up slowly, leading with the chest.",
            ],
            breathing: [
                "inhale as you lift the chest.",
                "steady breath in the bend.",
            ],
            actionFeeling: [
                "opening through the front of the chest and hips.",
                "low back active but supported by the hands.",
            ],
            commonMistakes: [
                "throwing the head back hard.",
                "collapsing into the lower back instead of lifting the chest.",
                "holding the breath.",
            ]
        ),

        // MARK: - Core / abs (supine)

        "crunch": ExerciseInstructions(
            actionSteps: [
                "lie on your back with your knees bent and feet flat on the floor, hip-width apart.",
                "your hands rest lightly behind your head, elbows wide.",
                "press your lower back into the floor.",
                "lift your shoulder blades off the floor — chin stays a fist away from your chest.",
                "exhale fully and squeeze the abs at the top.",
                "lower with control.",
            ],
            breathing: [
                "exhale as you lift.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "front of the core working hard — especially the upper abs.",
                "neck stays relaxed — the lift comes from the abs, not the head.",
            ],
            commonMistakes: [
                "pulling on the neck with the hands.",
                "trying to sit all the way up — only the shoulder blades leave the floor.",
                "rushing — slow lifts make the abs do the work.",
            ]
        ),

        "sit_up": ExerciseInstructions(
            actionSteps: [
                "lie on your back with your knees bent and feet flat on the floor.",
                "cross your arms over your chest or place your hands behind your head.",
                "engage your core and lift your entire torso up toward your knees.",
                "your back rolls up off the floor one vertebra at a time.",
                "lower with control, rolling back down vertebra by vertebra.",
            ],
            breathing: [
                "exhale as you sit up.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "deep abs and hip flexors working together to lift the torso.",
                "your back rolls — it doesn't pop up as one piece.",
            ],
            commonMistakes: [
                "yanking on the head with the hands.",
                "popping the body up using momentum.",
                "rounding the back so hard the chin drops to the chest.",
            ]
        ),

        "v_up": ExerciseInstructions(
            actionSteps: [
                "lie flat on your back with your arms extended overhead and legs straight.",
                "engage your core to simultaneously lift your torso and your legs.",
                "reach your hands toward your toes — your body forms a V shape.",
                "lower both halves with control back to the starting position.",
            ],
            breathing: [
                "exhale as you fold up.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "deep core firing through the entire front of the body.",
                "hip flexors and abs sharing the work.",
            ],
            commonMistakes: [
                "bending the knees to make it easier — keep the legs straight.",
                "swinging the arms for momentum.",
                "letting the lower back arch off the floor in the starting position.",
            ]
        ),

        "vertical_leg_crunch": ExerciseInstructions(
            actionSteps: [
                "lie on your back with your legs extended straight up toward the ceiling.",
                "hands rest lightly behind your head, elbows wide.",
                "press your lower back into the floor.",
                "lift your shoulder blades off the floor, reaching toward your toes.",
                "lower with control.",
            ],
            breathing: [
                "exhale as you lift.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "upper abs working hard to lift the shoulders.",
                "core engaged to keep the legs vertical.",
            ],
            commonMistakes: [
                "letting the legs drift forward instead of staying vertical.",
                "pulling on the neck.",
                "lifting too high — only the shoulder blades leave the floor.",
            ]
        ),

        "crunch_knee_raise": ExerciseInstructions(
            actionSteps: [
                "lie on your back with knees bent, feet flat on the floor.",
                "place your hands lightly behind your head.",
                "as you crunch your upper body up, draw your knees in toward your chest.",
                "your shoulders and knees move toward each other simultaneously.",
                "lower both halves with control.",
            ],
            breathing: [
                "exhale as you crunch in.",
                "inhale as you extend.",
            ],
            actionFeeling: [
                "upper and lower abs both firing.",
                "tight, controlled middle — the body folds and unfolds.",
            ],
            commonMistakes: [
                "swinging the legs up using momentum.",
                "yanking on the head.",
                "extending the lower back off the floor on the return.",
            ]
        ),

        "alt_knee_raise_crunch": ExerciseInstructions(
            actionSteps: [
                "lie on your back with hands behind your head, knees bent.",
                "crunch your upper body up off the floor.",
                "as you crunch, draw your right knee in toward your chest.",
                "extend the right leg back out as you lower slightly.",
                "crunch up again and draw the left knee in.",
            ],
            breathing: [
                "exhale on each crunch.",
                "inhale on the lower.",
            ],
            actionFeeling: [
                "upper abs holding the crunch.",
                "alternating side feeling stronger as the knee draws in.",
            ],
            commonMistakes: [
                "fully lowering the shoulders between reps — keep them slightly lifted.",
                "rushing the knee drive.",
                "rotating the torso when the knee comes in.",
            ]
        ),

        "bicycle_crunch": ExerciseInstructions(
            actionSteps: [
                "lie on your back with hands behind your head, legs lifted to a tabletop position (knees bent at 90°).",
                "lift your shoulder blades off the floor.",
                "extend your right leg long while bringing your left knee in toward your chest.",
                "rotate your torso to bring your right elbow toward your left knee.",
                "switch — extend the left leg, draw the right knee in, rotate the left elbow toward the right knee.",
            ],
            breathing: [
                "exhale on each rotation.",
                "steady breath between sides.",
            ],
            actionFeeling: [
                "obliques firing on each rotation.",
                "deep abs holding the shoulder lift.",
            ],
            commonMistakes: [
                "pulling on the head with the hands.",
                "moving too fast — slow rotations work the obliques harder.",
                "letting the extended leg touch the floor — keep it hovering.",
            ]
        ),

        "cocoon_crunch": ExerciseInstructions(
            actionSteps: [
                "lie on your back with arms extended overhead and legs straight.",
                "engage your core to curl your body inward.",
                "draw your knees toward your chest while bringing your arms in around your knees — like wrapping into a cocoon.",
                "pause and squeeze.",
                "extend back out long and repeat.",
            ],
            breathing: [
                "exhale as you curl in.",
                "inhale as you extend.",
            ],
            actionFeeling: [
                "full-core engagement — front, deep, and a hint of obliques.",
                "the body folds completely inward.",
            ],
            commonMistakes: [
                "fully extending and resting between reps.",
                "swinging the arms to gain momentum.",
                "lifting the head with the chin instead of the chest.",
            ]
        ),

        "bent_knee_hip_raise": ExerciseInstructions(
            actionSteps: [
                "lie on your back with your knees bent and lifted, shins parallel to the floor.",
                "arms rest by your sides, palms down for support.",
                "use your lower abs to lift your hips off the floor — your knees move toward your chest.",
                "the lift is small — about an inch or two.",
                "lower your hips with control.",
            ],
            breathing: [
                "exhale as you lift the hips.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "lower abs doing the lifting — not the legs swinging.",
                "no help from the arms pressing down.",
            ],
            commonMistakes: [
                "kicking the legs up for momentum.",
                "pressing through the hands to muscle the hips up.",
                "lifting too high and rolling backward.",
            ]
        ),

        "reverse_crunch": ExerciseInstructions(
            actionSteps: [
                "lie on your back with your knees bent at 90° and lifted toward the ceiling.",
                "arms rest by your sides, palms down.",
                "use your lower abs to curl your hips up off the floor.",
                "your knees draw toward your chest as your hips lift.",
                "lower with control.",
            ],
            breathing: [
                "exhale as you curl.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "lower abs working specifically.",
                "no swing — the curl is generated from the core.",
            ],
            commonMistakes: [
                "using the hands to muscle the hips up.",
                "letting the lower back arch on the lower phase.",
                "swinging the legs for momentum.",
            ]
        ),

        "leg_raise": ExerciseInstructions(
            actionSteps: [
                "lie on your back with your legs straight and arms by your sides.",
                "press your lower back into the floor.",
                "engage your lower abs to lift both legs up to vertical.",
                "lower both legs back down with control — slower than the lift.",
                "your lower back stays connected to the floor throughout.",
            ],
            breathing: [
                "exhale as you lift.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "lower abs working hard, especially as the legs lower.",
                "back stays pressed to the floor — that's the rep.",
            ],
            commonMistakes: [
                "letting the lower back arch as the legs lower.",
                "dropping the legs fast at the end — control the lower.",
                "lifting only halfway up.",
            ]
        ),

        "leg_raise_hold": ExerciseInstructions(
            actionSteps: [
                "lie on your back with legs straight up toward the ceiling.",
                "press your lower back into the floor and engage your lower abs.",
                "hold the position — legs vertical, back flat.",
                "your hands can rest by your sides or under your hips for support.",
                "breathe steadily until the timer ends.",
            ],
            breathing: [
                "steady inhale and exhale through the hold.",
            ],
            actionFeeling: [
                "lower abs working hard to keep the legs from drifting.",
                "back pinned to the floor.",
            ],
            commonMistakes: [
                "letting the back arch off the floor.",
                "letting the legs lean forward over the body.",
                "holding the breath.",
            ]
        ),

        "leg_raise_hip_lift": ExerciseInstructions(
            actionSteps: [
                "lie on your back with your legs straight up toward the ceiling.",
                "engage your lower abs to lift your hips slightly off the floor.",
                "your feet press toward the ceiling — a small hip lift up.",
                "lower the hips back to the floor with control, keeping legs vertical.",
            ],
            breathing: [
                "exhale as you lift the hips.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "lower abs doing the work — not the arms pressing.",
                "small, controlled lift through the hips.",
            ],
            commonMistakes: [
                "swinging the legs for momentum.",
                "pressing through the hands to muscle the lift.",
                "rolling so far back you go onto your shoulders.",
            ]
        ),

        "alt_leg_raise": ExerciseInstructions(
            actionSteps: [
                "lie on your back with legs straight, hands by your sides or under your hips.",
                "press your lower back into the floor.",
                "lift your right leg up to vertical.",
                "lower the right leg as you lift the left leg up to vertical.",
                "your back stays flat throughout.",
            ],
            breathing: [
                "exhale as you lift each leg.",
                "inhale on the cross.",
            ],
            actionFeeling: [
                "lower abs controlling each lift.",
                "back stays pressed down — the work is in the abs, not the back.",
            ],
            commonMistakes: [
                "letting the back arch off the floor.",
                "dropping the lowering leg fast.",
                "rushing the alternation.",
            ]
        ),

        "flutter_kicks": ExerciseInstructions(
            actionSteps: [
                "lie on your back with your legs extended straight, hovering a few inches off the floor.",
                "your hands rest by your sides or under your hips.",
                "engage your lower abs and press your back into the floor.",
                "alternate kicking your legs up and down in small, quick motions.",
                "your feet never touch the floor.",
            ],
            breathing: [
                "short rhythmic breaths matched to the kicks.",
            ],
            actionFeeling: [
                "lower abs burning to keep the legs hovering.",
                "back stays glued to the floor.",
            ],
            commonMistakes: [
                "letting the legs drop too low and the back arch.",
                "huge kick range — keep the kicks small.",
                "holding the breath.",
            ]
        ),

        "dead_bug": ExerciseInstructions(
            actionSteps: [
                "lie on your back. bend your knees to 90° so your shins are parallel to the floor.",
                "reach both arms straight up toward the ceiling, palms facing each other.",
                "press your lower back gently into the floor — no gap.",
                "slowly extend your right arm overhead and your left leg out long, hovering just above the floor.",
                "return to the starting position with the same control.",
                "alternate — left arm and right leg next.",
            ],
            breathing: [
                "exhale as you extend.",
                "inhale as you return.",
            ],
            actionFeeling: [
                "deep core working hard to keep your back flat.",
                "no neck strain — head and shoulders relaxed.",
            ],
            commonMistakes: [
                "letting the lower back arch off the floor.",
                "rushing — the slow tempo is the training.",
                "extending the leg too low if your back lifts.",
            ]
        ),

        "dead_bug_leg_lower": ExerciseInstructions(
            actionSteps: [
                "lie on your back with both legs lifted, knees bent at 90°.",
                "reach your arms toward the ceiling.",
                "press your lower back into the floor.",
                "slowly lower your right leg, extending it long, hovering just above the floor.",
                "return to the starting position, then lower the left leg.",
            ],
            breathing: [
                "exhale as you extend down.",
                "inhale as you return.",
            ],
            actionFeeling: [
                "deep lower-ab engagement controlling the leg.",
                "back stays pressed down — only go as low as you can maintain that.",
            ],
            commonMistakes: [
                "letting the back arch as the leg lowers.",
                "dropping the leg fast.",
                "compensating by tensing the neck.",
            ]
        ),

        "glute_bridge_march": ExerciseInstructions(
            actionSteps: [
                "lie on your back with knees bent, feet flat on the floor.",
                "press through your heels and lift your hips into a glute bridge — knees, hips, shoulders in line.",
                "while keeping your hips lifted and level, lift your right knee toward your chest.",
                "lower the right foot back down, then lift the left knee.",
                "keep alternating — your hips stay lifted the entire time.",
            ],
            breathing: [
                "exhale as you lift each knee.",
                "inhale on the lower.",
            ],
            actionFeeling: [
                "supporting glute working hard to keep the hips lifted.",
                "deep core controlling the rotation.",
            ],
            commonMistakes: [
                "letting the hips drop as one leg lifts.",
                "hips rotating toward the supporting side.",
                "rushing the march.",
            ]
        ),

        "windshield_wipers": ExerciseInstructions(
            actionSteps: [
                "lie on your back with your arms out wide for stability.",
                "lift both legs up to vertical, then bend them slightly.",
                "with control, lower your legs to the right side toward the floor.",
                "your left shoulder stays on the floor.",
                "use your obliques to lift back up through center, then lower to the left.",
            ],
            breathing: [
                "exhale as you rotate down.",
                "inhale as you return.",
            ],
            actionFeeling: [
                "deep oblique engagement on each side.",
                "shoulders stay anchored — only the lower body rotates.",
            ],
            commonMistakes: [
                "letting the legs slam to the floor.",
                "letting the shoulder lift off the floor on rotation.",
                "going too low if your back rounds.",
            ]
        ),

        "boat_flutters": ExerciseInstructions(
            actionSteps: [
                "sit on the floor with your knees bent.",
                "lean back to about 45° and lift your feet so your shins are parallel to the floor.",
                "extend your legs straight out, holding the boat position.",
                "from this hold, flutter your feet up and down in small alternating motions.",
                "keep your chest tall and your back long.",
            ],
            breathing: [
                "short rhythmic breaths matched to the flutters.",
            ],
            actionFeeling: [
                "deep core working hard to hold the boat.",
                "hip flexors firing through the flutter.",
            ],
            commonMistakes: [
                "rounding the back as you fatigue.",
                "letting the chest cave inward.",
                "huge flutter range — small is fine.",
            ]
        ),

        "boat_bicycle": ExerciseInstructions(
            actionSteps: [
                "sit on the floor with your knees bent and lean back to about 45°.",
                "lift your feet off the floor so your shins are parallel to the floor.",
                "from this boat hold, draw your right knee in and extend your left leg long.",
                "switch — extend the right leg long, draw the left knee in.",
                "your chest stays tall throughout.",
            ],
            breathing: [
                "exhale on each leg switch.",
            ],
            actionFeeling: [
                "deep core holding the boat position.",
                "obliques fire on the alternating motion.",
            ],
            commonMistakes: [
                "rounding the back.",
                "letting the feet drop to the floor.",
                "rushing — control matters more than speed.",
            ]
        ),

        "seated_knee_tuck": ExerciseInstructions(
            actionSteps: [
                "sit on the floor with your hands on the floor slightly behind your hips, fingers pointing forward.",
                "lean back slightly and lift your feet off the floor.",
                "extend your legs long out in front, hovering off the floor.",
                "draw your knees in toward your chest.",
                "extend back out long.",
            ],
            breathing: [
                "exhale as you tuck in.",
                "inhale as you extend.",
            ],
            actionFeeling: [
                "deep core and hip flexors working together.",
                "chest stays open — the back doesn't round.",
            ],
            commonMistakes: [
                "letting the feet touch the floor between reps.",
                "rounding the back.",
                "swinging the legs for momentum.",
            ]
        ),

        "crab_toe_touches": ExerciseInstructions(
            actionSteps: [
                "sit on the floor with hands behind you and feet flat — set up like a tabletop.",
                "lift your hips off the floor.",
                "lift your right hand and your left leg, reaching the hand toward the foot.",
                "lower with control, then switch sides.",
                "keep your hips lifted the entire time.",
            ],
            breathing: [
                "exhale on each reach.",
                "inhale on the lower.",
            ],
            actionFeeling: [
                "core engaged across the front and obliques.",
                "shoulders and glutes hold the table position.",
            ],
            commonMistakes: [
                "letting the hips drop between reps.",
                "shrugging the supporting shoulder.",
                "twisting only the upper body — the reach goes hand-to-opposite-foot.",
            ]
        ),

        "bird_dog": ExerciseInstructions(
            actionSteps: [
                "start on your hands and knees. wrists directly under shoulders, knees under hips.",
                "your spine is long and neutral — back flat, head in line with the spine.",
                "engage your core, gently pulling your belly button up toward your spine.",
                "extend your right arm forward at shoulder height and your left leg back at hip height.",
                "your fingertips reach long in one direction while your heel pushes long in the other.",
                "pause for one breath, return to center with control, switch sides.",
            ],
            breathing: [
                "exhale as you extend.",
                "inhale as you return to center.",
            ],
            actionFeeling: [
                "deep obliques keeping your hips from twisting.",
                "glute of the lifted leg activates.",
                "shoulder of the lifted arm stabilizes.",
            ],
            commonMistakes: [
                "twisting the hips — keep them square.",
                "lifting the leg higher than the hip — length, not height.",
                "rushing — slow makes the core work harder.",
            ]
        ),

        "side_plank": ExerciseInstructions(
            actionSteps: [
                "lie on your side. your bottom forearm rests on the floor, elbow directly under your shoulder.",
                "stack your legs — top foot rests on top of bottom foot.",
                "your top arm rests along your side or extends toward the ceiling.",
                "press through the forearm and the side of the bottom foot to lift your hips.",
                "your body forms one long line from head to feet.",
                "hold — keep breathing — switch sides when the timer ends.",
            ],
            breathing: [
                "steady inhale, steady exhale throughout the hold.",
            ],
            actionFeeling: [
                "deep burn along the side waist (obliques) of the bottom side.",
                "supporting shoulder is active and stable.",
            ],
            commonMistakes: [
                "hips sagging toward the floor.",
                "rolling forward or backward — stack the body in one plane.",
                "elbow drifting away from the shoulder.",
            ]
        ),

        "side_crunch": ExerciseInstructions(
            actionSteps: [
                "lie on your side with your legs stacked and your bottom forearm on the floor.",
                "place your top hand behind your head.",
                "engage your obliques and lift your shoulder and your top leg up toward each other.",
                "your elbow and knee come close — a side crunch.",
                "lower with control.",
            ],
            breathing: [
                "exhale as you crunch.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "obliques on the top side firing hard.",
                "the lift is small and controlled.",
            ],
            commonMistakes: [
                "rolling forward or backward — stay stacked.",
                "yanking on the head.",
                "kicking the leg up for momentum.",
            ]
        ),

        "side_crunch_hip_raise": ExerciseInstructions(
            actionSteps: [
                "lie on your side with your bottom forearm on the floor, elbow under shoulder.",
                "your legs are stacked and slightly bent.",
                "lift your hips into a side plank.",
                "from the side plank, dip your top hip down toward the floor and lift it back up.",
                "small dips — your bottom hip never touches the floor.",
            ],
            breathing: [
                "exhale as you lift the hip.",
                "inhale as you dip.",
            ],
            actionFeeling: [
                "deep oblique burn through the bottom side.",
                "shoulder and arm stable as the hip moves.",
            ],
            commonMistakes: [
                "letting the hip drop all the way to the floor.",
                "rolling forward as you fatigue.",
                "shrugging the supporting shoulder.",
            ]
        ),

        "tabletop_bridge": ExerciseInstructions(
            actionSteps: [
                "sit on the floor with your knees bent and feet flat.",
                "place your hands flat on the floor behind you, fingers pointing toward your hips.",
                "press through your palms and feet to lift your hips up — your torso forms a flat tabletop.",
                "your knees, hips, and shoulders are roughly in one line.",
                "hold — keep breathing — and lower with control.",
            ],
            breathing: [
                "exhale as you lift.",
                "steady breath through the hold.",
            ],
            actionFeeling: [
                "glutes squeezing to hold the table.",
                "shoulders and arms supporting the lift.",
                "core working to keep the line.",
            ],
            commonMistakes: [
                "letting the hips drop in the middle of the hold.",
                "fingers pointing away from the body — keep them toward your hips.",
                "shrugging the shoulders.",
            ]
        ),

        "tabletop_bridge_knee_lift": ExerciseInstructions(
            actionSteps: [
                "set up in tabletop bridge — hips lifted, body in a flat line, hands and feet on the floor.",
                "lift your right knee up toward your chest.",
                "lower the right foot back down, then lift the left knee.",
                "your hips stay level and lifted throughout.",
            ],
            breathing: [
                "exhale on each knee lift.",
                "inhale on the lower.",
            ],
            actionFeeling: [
                "supporting glute working hard.",
                "core controlling the rotation.",
            ],
            commonMistakes: [
                "letting the hips drop as a leg lifts.",
                "rotating the hips toward the supporting side.",
                "rushing the lifts.",
            ]
        ),

        "tabletop_hold_knee_lift": ExerciseInstructions(
            actionSteps: [
                "start on hands and knees — wrists under shoulders, knees under hips.",
                "lift your knees an inch off the floor so you're balancing on toes + hands.",
                "from this hover, lift your right knee a few inches higher.",
                "lower with control, then lift the left.",
                "your hips stay square the entire time.",
            ],
            breathing: [
                "exhale on each knee lift.",
                "inhale between lifts.",
            ],
            actionFeeling: [
                "deep core resisting the rotation.",
                "supporting shoulder and hip working hard.",
            ],
            commonMistakes: [
                "rocking the hips side to side.",
                "letting the back round or arch.",
                "feet popping up too high — the lift is small.",
            ]
        ),

        "standing_side_bend": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet hip-width apart.",
                "place your right hand on your hip and reach your left arm up overhead.",
                "with control, bend to the right — the left side stretches as the right side contracts.",
                "return through center and switch sides.",
                "your hips stay forward — only the upper body bends.",
            ],
            breathing: [
                "exhale as you bend.",
                "inhale as you return.",
            ],
            actionFeeling: [
                "stretch along the lengthening side.",
                "obliques on the contracting side activating.",
            ],
            commonMistakes: [
                "letting the hips push the opposite direction.",
                "leaning forward instead of straight to the side.",
                "yanking down with the arm — let the side bend.",
            ]
        ),

        // MARK: - Glutes / legs / lower body (standing)

        "glute_bridge": ExerciseInstructions(
            actionSteps: [
                "lie on your back. bend your knees and place your feet flat on the floor, hip-width apart.",
                "your heels are close enough that your fingertips can graze them.",
                "your arms rest by your sides, palms down.",
                "press through your heels and squeeze your glutes to lift your hips off the floor.",
                "at the top, your knees, hips, and shoulders form one straight line.",
                "pause and squeeze the glutes hard.",
                "lower with control.",
            ],
            breathing: [
                "exhale as you lift.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "glutes doing the work — not the lower back.",
                "hamstrings activate as you press through the heels.",
            ],
            commonMistakes: [
                "arching the lower back instead of squeezing the glutes.",
                "knees falling in or splaying out.",
                "feet too far from the body.",
            ]
        ),

        "single_leg_glute_bridge": ExerciseInstructions(
            actionSteps: [
                "lie on your back with one knee bent, foot flat on the floor.",
                "extend the other leg straight out in front, hovering.",
                "press through the planted heel and lift your hips.",
                "at the top, your knees, hips, and shoulders are in one line.",
                "lower with control.",
            ],
            breathing: [
                "exhale as you lift.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "working-side glute squeezing.",
                "core stabilizes the lift.",
            ],
            commonMistakes: [
                "letting the lifted leg's hip drop.",
                "pushing through the toes instead of the heel.",
                "arching the lower back.",
            ]
        ),

        "squat": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet shoulder-width apart, toes slightly turned out.",
                "engage your core and keep your chest tall.",
                "send your hips back and down as if sitting into a chair.",
                "your knees track over your toes — they don't cave inward.",
                "go as low as you can while keeping a flat back — at least until thighs are parallel to the floor.",
                "press through your whole foot to stand back up.",
            ],
            breathing: [
                "inhale on the way down.",
                "exhale on the way up.",
            ],
            actionFeeling: [
                "quads and glutes both working.",
                "weight stays in your heels and mid-foot, not the toes.",
            ],
            commonMistakes: [
                "knees caving inward as you lower.",
                "heels lifting off the floor.",
                "rounding the back at the bottom.",
                "stopping the squat too high.",
            ]
        ),

        "air_squat": ExerciseInstructions(
            actionSteps: [
                "stand with your feet shoulder-width apart, toes slightly out.",
                "extend your arms straight in front for balance.",
                "send your hips back and bend your knees to lower down.",
                "your chest stays tall, back stays flat.",
                "lower until your thighs are parallel to the floor.",
                "drive through your heels to stand back up.",
            ],
            breathing: [
                "inhale on the way down.",
                "exhale on the way up.",
            ],
            actionFeeling: [
                "quads, glutes, and core all firing.",
                "weight even across the whole foot.",
            ],
            commonMistakes: [
                "rising up onto the toes.",
                "knees collapsing inward.",
                "leaning the chest forward at the bottom.",
            ]
        ),

        "narrow_squat": ExerciseInstructions(
            actionSteps: [
                "stand with your feet together or just a few inches apart.",
                "your toes point forward.",
                "send your hips back and bend your knees to lower down.",
                "your chest stays tall — the narrow stance forces a more upright torso.",
                "press through your whole foot to stand back up.",
            ],
            breathing: [
                "inhale down.",
                "exhale up.",
            ],
            actionFeeling: [
                "quads working harder than glutes — that's the narrow-stance shift.",
                "core working to balance.",
            ],
            commonMistakes: [
                "knees falling forward of the toes.",
                "rounding the back to go deeper.",
                "losing balance — go shallower if needed.",
            ]
        ),

        "sumo_squat": ExerciseInstructions(
            actionSteps: [
                "stand with your feet wider than your shoulders, toes turned out to about 45°.",
                "your hands can rest at your chest or your hips.",
                "send your hips straight down — the wide stance allows a vertical drop.",
                "your knees track over your toes, staying turned out.",
                "lower until your thighs are parallel to the floor or lower.",
                "drive through your heels to stand up, squeezing your glutes at the top.",
            ],
            breathing: [
                "inhale on the way down.",
                "exhale on the way up.",
            ],
            actionFeeling: [
                "inner thighs and glutes working together.",
                "more glute engagement than a regular squat.",
            ],
            commonMistakes: [
                "letting the knees collapse inward.",
                "tipping the chest forward.",
                "feet too narrow — keep them wide.",
            ]
        ),

        "pulse_squat": ExerciseInstructions(
            actionSteps: [
                "stand with your feet shoulder-width apart.",
                "lower into a squat, thighs parallel to the floor.",
                "from the bottom of the squat, pulse up an inch or two and back down.",
                "small, fast pulses — you never come fully out of the squat.",
                "hold the squat position throughout.",
            ],
            breathing: [
                "short rhythmic breaths matched to the pulses.",
            ],
            actionFeeling: [
                "deep burn through the quads and glutes — they don't get a break.",
                "core working to hold the squat shape.",
            ],
            commonMistakes: [
                "standing all the way up between pulses.",
                "letting the back round under fatigue.",
                "heels lifting off the floor.",
            ]
        ),

        "wall_sit": ExerciseInstructions(
            actionSteps: [
                "stand with your back against a wall, feet about two feet in front.",
                "slide down the wall until your thighs are parallel to the floor.",
                "your knees are bent at 90° and stacked over your ankles.",
                "your back stays pressed flat against the wall.",
                "arms can rest by your sides or out in front.",
                "hold — breathe — until the timer ends.",
            ],
            breathing: [
                "steady inhale, steady exhale throughout.",
            ],
            actionFeeling: [
                "quads burning hard.",
                "glutes and core active to hold the position.",
            ],
            commonMistakes: [
                "knees drifting forward of the ankles.",
                "back peeling off the wall.",
                "holding your breath.",
            ]
        ),

        "squat_calf_raise": ExerciseInstructions(
            actionSteps: [
                "perform a squat — hips back, knees bent, thighs parallel to the floor.",
                "as you stand up, drive through the balls of your feet to lift onto your toes.",
                "pause at the top with your heels lifted.",
                "lower your heels with control as you go into the next squat.",
            ],
            breathing: [
                "inhale on the way down.",
                "exhale as you press up onto your toes.",
            ],
            actionFeeling: [
                "quads and glutes through the squat.",
                "calves activating at the top of the raise.",
            ],
            commonMistakes: [
                "rushing the calf raise — control the lift.",
                "knees caving in the squat.",
                "leaning forward for balance instead of stacking the body.",
            ]
        ),

        "calf_raise": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet hip-width apart.",
                "press through the balls of your feet to lift your heels up.",
                "pause at the top with your weight on the balls of your feet.",
                "lower your heels with control.",
            ],
            breathing: [
                "exhale as you lift.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "calves contracting at the top.",
                "ankles stable as you balance.",
            ],
            commonMistakes: [
                "bouncing up and down fast.",
                "rolling the ankles outward — press evenly through the big and pinky toes.",
                "not coming all the way back to flat — full range matters.",
            ]
        ),

        "single_leg_calf_raise": ExerciseInstructions(
            actionSteps: [
                "stand on one foot — the other foot can hover or hook behind the supporting ankle.",
                "hold something nearby for light balance if needed.",
                "press through the ball of the supporting foot to lift the heel.",
                "pause at the top.",
                "lower with control.",
            ],
            breathing: [
                "exhale as you lift.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "calf and ankle working harder than a two-leg version.",
                "small stabilizer muscles in the foot engaging.",
            ],
            commonMistakes: [
                "rolling outward onto the pinky-toe side.",
                "rushing the reps.",
                "leaning hard on a balance support — keep it light.",
            ]
        ),

        "kneeling_squat": ExerciseInstructions(
            actionSteps: [
                "kneel on the floor with your knees hip-width apart.",
                "tuck your toes under for support, or rest the tops of the feet flat.",
                "engage your core and squeeze your glutes.",
                "send your hips back, lowering your sit bones toward your heels.",
                "press your hips forward to return upright, squeezing the glutes at the top.",
            ],
            breathing: [
                "inhale on the way back.",
                "exhale as you drive the hips forward.",
            ],
            actionFeeling: [
                "glutes working hard at the top.",
                "quads stretching as the hips lower.",
            ],
            commonMistakes: [
                "arching the lower back at the top — squeeze the glutes instead.",
                "lowering too far back if your knees can't tolerate it.",
                "knees splaying wide.",
            ]
        ),

        "good_morning": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet hip-width apart.",
                "place your hands behind your head, elbows wide.",
                "with a slight bend in your knees, hinge at your hips and lower your torso forward.",
                "your back stays flat — the hinge comes from the hips, not the spine.",
                "stop when your torso is parallel to the floor (or as far as you can with a flat back).",
                "press your hips forward to return upright.",
            ],
            breathing: [
                "inhale as you hinge.",
                "exhale as you return.",
            ],
            actionFeeling: [
                "hamstrings stretching as you hinge.",
                "lower back active to hold the flat back.",
                "glutes drive the return.",
            ],
            commonMistakes: [
                "rounding the back instead of hinging the hips.",
                "bending the knees too much — keep them softly bent.",
                "going further than your flexibility allows.",
            ]
        ),

        "forward_lunge": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet hip-width apart.",
                "step your right foot forward into a long stride.",
                "lower your back knee toward the floor, hovering just above it.",
                "both knees end up at about 90°.",
                "press through your front heel to stand and step back to start.",
                "alternate sides or repeat on one side.",
            ],
            breathing: [
                "inhale as you lower.",
                "exhale as you press up.",
            ],
            actionFeeling: [
                "front-leg quad and glute doing the work.",
                "back leg stretching at the hip.",
            ],
            commonMistakes: [
                "front knee drifting past the toes.",
                "leaning the torso too far forward.",
                "stepping too short and slamming the back knee down.",
            ]
        ),

        "reverse_lunge": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet hip-width apart.",
                "step your right foot back into a long stride.",
                "lower your back knee toward the floor.",
                "both knees end up at about 90°.",
                "press through your front heel to stand and bring the back foot home.",
                "repeat on the other side or stay on one side.",
            ],
            breathing: [
                "inhale as you step back and lower.",
                "exhale as you stand.",
            ],
            actionFeeling: [
                "front-leg glute working harder than in a forward lunge.",
                "quads supporting the descent.",
            ],
            commonMistakes: [
                "stepping too short — give the back leg room.",
                "front knee caving inward.",
                "rushing — control the lower.",
            ]
        ),

        "alt_forward_lunge": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet hip-width apart.",
                "step your right foot forward into a lunge — back knee hovers above the floor.",
                "press through the front heel to return to standing.",
                "step the left foot forward next.",
                "keep alternating.",
            ],
            breathing: [
                "inhale as you lower into the lunge.",
                "exhale as you stand up.",
            ],
            actionFeeling: [
                "front-leg glute and quad on each lunge.",
                "core balancing as you switch sides.",
            ],
            commonMistakes: [
                "letting the front knee cave in.",
                "leaning the torso forward.",
                "rushing — each lunge gets controlled descent.",
            ]
        ),

        "reverse_to_forward_lunge": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet hip-width apart.",
                "step your right foot back into a reverse lunge — back knee toward the floor.",
                "press up to standing, then immediately step the same right foot forward into a forward lunge.",
                "press back to standing and switch legs.",
            ],
            breathing: [
                "inhale as you lower.",
                "exhale as you press up.",
            ],
            actionFeeling: [
                "front leg's quad and glute working through both lunges.",
                "core balancing through the direction change.",
            ],
            commonMistakes: [
                "rushing the transition between back and front.",
                "front knee drifting over the toes in the forward lunge.",
                "back knee slamming the floor.",
            ]
        ),

        "side_lunge": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet wider than shoulder-width.",
                "send your hips back and bend your right knee — your weight shifts to the right side.",
                "your left leg stays straight, foot flat.",
                "lower until your right thigh is roughly parallel to the floor.",
                "press through the right foot to return to center.",
                "switch sides.",
            ],
            breathing: [
                "inhale as you lower.",
                "exhale as you stand.",
            ],
            actionFeeling: [
                "inner thigh of the straight leg stretching.",
                "glute and quad of the bent leg working.",
            ],
            commonMistakes: [
                "letting the bent knee cave inward.",
                "lifting the heel of the bent leg.",
                "bending forward at the waist instead of hinging at the hips.",
            ]
        ),

        "split_squat": ExerciseInstructions(
            actionSteps: [
                "stand in a split stance — right foot forward, left foot back, feet about two feet apart.",
                "your back heel stays lifted throughout.",
                "lower straight down, bending both knees to about 90°.",
                "your back knee hovers above the floor.",
                "press through your front heel to return to the top.",
                "stay on one side for the full set, then switch.",
            ],
            breathing: [
                "inhale as you lower.",
                "exhale as you press up.",
            ],
            actionFeeling: [
                "front-leg glute and quad working.",
                "back leg's hip flexor stretches at the bottom.",
            ],
            commonMistakes: [
                "front foot too close to the back — give yourself a long stride.",
                "knees drifting forward of the toes.",
                "leaning the torso forward — stay upright.",
            ]
        ),

        "side_split_squat": ExerciseInstructions(
            actionSteps: [
                "stand with your feet wider than shoulder-width, toes pointed forward.",
                "shift your weight to your right side, bending your right knee.",
                "your left leg stays straight.",
                "lower until your right thigh is parallel to the floor — your left leg pulls long.",
                "stay on this side, then press up and switch.",
            ],
            breathing: [
                "inhale on the way down.",
                "exhale on the way up.",
            ],
            actionFeeling: [
                "inner-thigh stretch on the straight leg.",
                "glute and quad of the bent leg loaded.",
            ],
            commonMistakes: [
                "lifting the heel of the bent leg.",
                "rotating the toes outward — keep them forward.",
                "rushing — control the side load.",
            ]
        ),

        "jumping_lunges": ExerciseInstructions(
            actionSteps: [
                "start in a lunge position — right foot forward, left foot back, both knees bent.",
                "explode upward, jumping off the floor.",
                "in the air, switch your legs — left foot forward, right foot back.",
                "land softly into a lunge on the other side.",
                "keep alternating with each jump.",
            ],
            breathing: [
                "short rhythmic breaths matched to the jumps.",
            ],
            actionFeeling: [
                "explosive power through the quads and glutes.",
                "core stabilizing the landing.",
            ],
            commonMistakes: [
                "landing hard with locked legs — bend on impact.",
                "front knee caving inward on the landing.",
                "leaning forward through the jump.",
            ]
        ),

        "overhead_forward_lunge": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet hip-width apart.",
                "reach both arms straight up overhead, biceps by your ears.",
                "keeping your arms overhead, step your right foot forward into a lunge.",
                "lower the back knee toward the floor.",
                "press up and step back to standing.",
                "alternate sides.",
            ],
            breathing: [
                "inhale as you lower.",
                "exhale as you stand.",
            ],
            actionFeeling: [
                "shoulders and upper back working to hold the arms overhead.",
                "lunge muscles working as in a regular forward lunge.",
                "core firing harder because of the overhead load.",
            ],
            commonMistakes: [
                "letting the arms drift forward — keep them by your ears.",
                "arching the lower back to hold the arms up.",
                "knee caving in on the lunge.",
            ]
        ),

        "overhead_reverse_lunge": ExerciseInstructions(
            actionSteps: [
                "stand tall, feet hip-width apart.",
                "reach both arms straight overhead.",
                "step your right foot back into a reverse lunge while keeping the arms up.",
                "press up and bring the right foot home.",
                "switch sides.",
            ],
            breathing: [
                "inhale as you step back.",
                "exhale as you stand.",
            ],
            actionFeeling: [
                "shoulders and upper back stabilizing the overhead reach.",
                "glutes and quads driving the lunge.",
            ],
            commonMistakes: [
                "arms drifting forward of the head.",
                "arching the back to keep the arms up.",
                "rushing — the overhead load needs control.",
            ]
        ),

        "single_leg_rdl": ExerciseInstructions(
            actionSteps: [
                "stand tall on one leg, the other leg hovering just behind you.",
                "with a slight bend in the supporting knee, hinge at your hips and lean forward.",
                "your back stays flat as your free leg lifts behind you — your body forms one long line.",
                "lower your torso to about parallel with the floor.",
                "drive through your supporting heel to return upright.",
                "complete reps on one side before switching.",
            ],
            breathing: [
                "inhale as you hinge.",
                "exhale as you return.",
            ],
            actionFeeling: [
                "hamstring of the supporting leg stretching and loading.",
                "glute of the supporting side firing on the way up.",
                "core working hard for balance.",
            ],
            commonMistakes: [
                "rounding the back instead of hinging.",
                "letting the hip of the lifted leg rotate up — keep it square.",
                "going too far if the back rounds.",
            ]
        ),

        "stiff_leg_deadlift": ExerciseInstructions(
            actionSteps: [
                "stand with your feet hip-width apart, a slight bend in your knees.",
                "engage your core, keep your back flat.",
                "hinge at your hips and lower your torso forward — your knees stay slightly bent throughout.",
                "your hands slide down your legs toward your shins.",
                "stop when you feel a strong stretch in your hamstrings.",
                "drive your hips forward to return upright, squeezing your glutes.",
            ],
            breathing: [
                "inhale on the way down.",
                "exhale on the way up.",
            ],
            actionFeeling: [
                "hamstrings stretching and loading.",
                "glutes firing on the return.",
                "back stays flat — never rounded.",
            ],
            commonMistakes: [
                "rounding the back.",
                "bending the knees too much.",
                "going so deep the back rounds — stop at hamstring stretch.",
            ]
        ),

        "donkey_kick": ExerciseInstructions(
            actionSteps: [
                "start on your hands and knees — wrists under shoulders, knees under hips.",
                "keep your right knee bent at 90° and lift the leg up and back.",
                "your heel drives toward the ceiling.",
                "keep your hips square — don't open them.",
                "lower with control.",
                "repeat on one side before switching.",
            ],
            breathing: [
                "exhale as you lift.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "glute squeezing at the top of the lift.",
                "core resisting any rotation of the hips.",
            ],
            commonMistakes: [
                "letting the hips rotate as the leg lifts.",
                "kicking the leg too high and arching the lower back.",
                "letting the foot's toes drive the lift — drive with the heel.",
            ]
        ),

        "donkey_kick_pulse": ExerciseInstructions(
            actionSteps: [
                "set up like a donkey kick — leg lifted, knee at 90°, heel toward the ceiling.",
                "from the top of the lift, pulse the heel up an inch or two.",
                "small, fast pulses — the leg never comes back down to start.",
                "hips stay square throughout.",
                "complete the set on one side before switching.",
            ],
            breathing: [
                "short rhythmic breaths matched to the pulses.",
            ],
            actionFeeling: [
                "deep, focused burn in the glute.",
                "core holding the hips steady.",
            ],
            commonMistakes: [
                "letting the leg drop fully between pulses.",
                "rotating the hips up.",
                "shrugging the supporting shoulder.",
            ]
        ),

        "donkey_kickback": ExerciseInstructions(
            actionSteps: [
                "start on your hands and knees.",
                "extend your right leg straight back so it's parallel to the floor.",
                "from this position, lift the straight leg up a few more inches.",
                "lower with control.",
                "complete the set on one side, then switch.",
            ],
            breathing: [
                "exhale as you lift.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "glute and hamstring of the lifting leg working together.",
                "core fires to keep the hips square.",
            ],
            commonMistakes: [
                "lifting so high the back arches.",
                "letting the hip rotate up.",
                "rounding the shoulders.",
            ]
        ),

        "fire_hydrant": ExerciseInstructions(
            actionSteps: [
                "start on your hands and knees.",
                "keeping your right knee bent at 90°, lift it out to the side.",
                "your knee rises toward the ceiling at about hip height.",
                "lower with control.",
                "your hips stay square — try not to shift weight side to side.",
                "complete the set on one side, then switch.",
            ],
            breathing: [
                "exhale as you lift.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "outer glute of the lifting leg firing.",
                "core stabilizing the position.",
            ],
            commonMistakes: [
                "shifting weight to the supporting side.",
                "letting the foot dangle outward — keep the knee at 90°.",
                "lifting the leg too high and rotating the hip.",
            ]
        ),

        "standing_hip_abduction": ExerciseInstructions(
            actionSteps: [
                "stand tall — hold onto a wall or chair for balance if needed.",
                "shift your weight to your left leg.",
                "with control, lift your right leg out to the side, keeping the leg straight.",
                "your foot lifts to about a foot off the floor — height isn't the goal.",
                "lower with control.",
                "complete reps on one side before switching.",
            ],
            breathing: [
                "exhale as you lift.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "outer hip of the lifting leg activating.",
                "core stabilizing the standing posture.",
            ],
            commonMistakes: [
                "leaning the upper body away from the lifting leg.",
                "rotating the hip and turning the toes up — keep them forward.",
                "rushing — slow makes the glute work harder.",
            ]
        ),

        "side_lying_hip_abduction": ExerciseInstructions(
            actionSteps: [
                "lie on your side with your bottom leg slightly bent for support.",
                "rest your head on your bottom arm.",
                "keep your top leg straight, foot flexed.",
                "lift your top leg up toward the ceiling, leading with the heel.",
                "lower with control.",
                "your hips stay stacked — don't roll backward.",
            ],
            breathing: [
                "exhale as you lift.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "outer hip and glute working in isolation.",
                "core stabilizing the stacked position.",
            ],
            commonMistakes: [
                "rolling backward to lift the leg higher.",
                "letting the foot lead the lift — lead with the heel.",
                "kicking the leg up — keep it slow.",
            ]
        ),

        "side_plank_hip_abduction": ExerciseInstructions(
            actionSteps: [
                "set up in a side plank on your forearm — elbow under shoulder, hips lifted.",
                "from the side plank, lift your top leg up toward the ceiling.",
                "lower the top leg with control.",
                "hips stay lifted — don't sag.",
                "complete reps on one side before switching.",
            ],
            breathing: [
                "exhale as you lift.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "deep burn through the side plank.",
                "outer hip of the lifting leg activating.",
            ],
            commonMistakes: [
                "letting the hips drop as the leg lifts.",
                "rolling forward.",
                "shrugging the supporting shoulder.",
            ]
        ),

        // MARK: - Cardio / explosive

        "jumping_jacks": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet together, arms at your sides.",
                "in one motion, jump your feet wide and raise your arms overhead.",
                "jump your feet back together while lowering your arms.",
                "land softly each time, knees slightly bent.",
                "find a steady rhythm.",
            ],
            breathing: [
                "rhythmic breath matched to the pace.",
            ],
            actionFeeling: [
                "full-body warm-up — heart rate climbs quickly.",
                "calves and shoulders working through every rep.",
            ],
            commonMistakes: [
                "landing hard on locked legs.",
                "letting the arms swing wildly instead of moving with intention.",
                "letting the rhythm fall apart as you fatigue.",
            ]
        ),

        "modified_jacks": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet together, arms at your sides.",
                "step your right foot wide as your arms raise overhead.",
                "bring the right foot back as the arms lower.",
                "step the left foot wide next.",
                "alternate sides — no jumping, just stepping.",
            ],
            breathing: [
                "rhythmic breath matched to the steps.",
            ],
            actionFeeling: [
                "lower-impact full-body warm-up.",
                "shoulders and calves still active.",
            ],
            commonMistakes: [
                "rushing — find a controlled rhythm.",
                "letting the arms hang limp — drive them up.",
                "rounding the back.",
            ]
        ),

        "simple_jacks": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet hip-width and arms at your sides.",
                "jump your feet slightly wider as your arms come out to the sides at shoulder height.",
                "jump back to start.",
                "a smaller, simpler version of full jumping jacks.",
            ],
            breathing: [
                "rhythmic breath matched to the pace.",
            ],
            actionFeeling: [
                "easy full-body warm-up.",
                "shoulders and legs both engaged.",
            ],
            commonMistakes: [
                "letting the arms drop instead of lifting them.",
                "landing hard on flat feet.",
            ]
        ),

        "side_jacks": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet hip-width and arms at your sides.",
                "jump your right foot out to the side as your arms raise overhead.",
                "return to center, then jump the left foot out next.",
                "the arms rise and lower with each step.",
            ],
            breathing: [
                "rhythmic breath matched to the pace.",
            ],
            actionFeeling: [
                "side-to-side mobility through the hips.",
                "shoulders engaging on each lift.",
            ],
            commonMistakes: [
                "landing stiff-legged.",
                "letting the arms hang low.",
                "rushing the rhythm.",
            ]
        ),

        "side_leg_jack": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet hip-width apart.",
                "lift your right leg out to the side, keeping it straight.",
                "return to center and lift the left leg next.",
                "your arms can rest on your hips or move with the rhythm.",
            ],
            breathing: [
                "exhale as you lift each leg.",
                "inhale as you return.",
            ],
            actionFeeling: [
                "outer hip of the lifting leg activating.",
                "supporting leg's glute stabilizing.",
            ],
            commonMistakes: [
                "leaning away from the lifting leg.",
                "kicking the leg out instead of lifting with the hip.",
                "shrugging the shoulders.",
            ]
        ),

        "high_knees": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet hip-width apart.",
                "lift your right knee toward your chest as you push off the left foot.",
                "switch quickly — drive the left knee up as the right foot lands.",
                "your knees come up to hip height (or higher).",
                "your arms swing naturally — counter to the legs.",
            ],
            breathing: [
                "rhythmic breath matched to the pace.",
            ],
            actionFeeling: [
                "hip flexors and quads working hard.",
                "heart rate climbs fast.",
            ],
            commonMistakes: [
                "rounding the back as you fatigue.",
                "knees not coming up to hip height — keep the drive.",
                "landing hard — stay light on the balls of the feet.",
            ]
        ),

        "butt_kicks": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet hip-width apart.",
                "kick your right heel up toward your glutes.",
                "switch quickly — left heel kicks up as the right foot lands.",
                "your arms swing naturally.",
                "your knees stay pointing down toward the floor.",
            ],
            breathing: [
                "rhythmic breath matched to the pace.",
            ],
            actionFeeling: [
                "hamstrings and glutes activating.",
                "heart rate rising.",
            ],
            commonMistakes: [
                "leaning the torso forward to make it easier.",
                "knees swinging forward instead of straight down.",
                "letting the rhythm fall apart.",
            ]
        ),

        "front_kicks": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet hip-width apart.",
                "engage your core.",
                "kick your right leg straight out in front, foot flexed.",
                "bring it back to standing.",
                "kick with the left leg next.",
                "your standing leg has a slight bend for balance.",
            ],
            breathing: [
                "exhale on each kick.",
                "inhale on the return.",
            ],
            actionFeeling: [
                "quads firing on each kick.",
                "core balancing the standing posture.",
            ],
            commonMistakes: [
                "swinging the leg too high — kick with control.",
                "rounding the upper back to balance.",
                "rushing — quality kicks over speed.",
            ]
        ),

        "squat_front_kick": ExerciseInstructions(
            actionSteps: [
                "stand with your feet shoulder-width apart.",
                "lower into a squat — hips back, thighs parallel to floor.",
                "as you press up, kick your right leg straight out in front.",
                "return to standing, then squat again.",
                "kick with the left leg on the next rep.",
            ],
            breathing: [
                "inhale on the way down.",
                "exhale on the press-up + kick.",
            ],
            actionFeeling: [
                "quads and glutes through the squat.",
                "core stabilizing the kick.",
                "kicking leg's quad firing.",
            ],
            commonMistakes: [
                "rushing the kick — control it.",
                "letting the back round in the squat.",
                "kicking too high and losing balance.",
            ]
        ),

        "jump_squat": ExerciseInstructions(
            actionSteps: [
                "stand with your feet shoulder-width apart.",
                "lower into a squat — hips back, thighs parallel.",
                "explode upward, jumping off the floor.",
                "land softly into the next squat — knees bend on impact.",
                "use the bend in the knees to absorb the landing.",
            ],
            breathing: [
                "inhale on the way down.",
                "exhale on the jump.",
            ],
            actionFeeling: [
                "explosive power through the legs and glutes.",
                "core controls the body in the air.",
            ],
            commonMistakes: [
                "landing on locked legs — always bend on impact.",
                "knees caving inward on the landing.",
                "leaning forward through the jump.",
            ]
        ),

        "sumo_jump_squat": ExerciseInstructions(
            actionSteps: [
                "stand with your feet wider than shoulder-width, toes turned out.",
                "lower into a sumo squat — thighs parallel to the floor.",
                "explode upward, jumping off the floor.",
                "land softly back into the sumo squat — feet stay wide, toes out.",
            ],
            breathing: [
                "inhale on the way down.",
                "exhale on the jump.",
            ],
            actionFeeling: [
                "inner thighs and glutes loaded.",
                "explosive power through the wide stance.",
            ],
            commonMistakes: [
                "knees caving inward.",
                "landing flat and hard — bend through the landing.",
                "narrowing the stance on the landing.",
            ]
        ),

        "burpee": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet shoulder-width apart.",
                "squat down and place your hands on the floor.",
                "jump your feet back into a high plank.",
                "lower your chest to the floor (optional).",
                "push back up to the plank, then jump your feet to your hands.",
                "explode up, jumping at the top with your arms overhead.",
            ],
            breathing: [
                "exhale on the jump down and on the jump up.",
                "inhale during the transition.",
            ],
            actionFeeling: [
                "full-body engagement — legs, core, arms, lungs.",
                "heart rate spikes fast.",
            ],
            commonMistakes: [
                "sagging hips in the plank.",
                "feet landing too narrow on the jump-in.",
                "landing hard on the explosive jump — bend on impact.",
            ]
        ),

        "burpee_no_jump": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet shoulder-width apart.",
                "squat down and place your hands on the floor.",
                "step (don't jump) your feet back into a high plank.",
                "lower your chest to the floor (optional).",
                "push back up, then step your feet back to your hands.",
                "stand up — no jump at the top.",
            ],
            breathing: [
                "exhale on the steps back.",
                "inhale as you stand.",
            ],
            actionFeeling: [
                "full-body engagement at a lower impact.",
                "still works the core and legs hard.",
            ],
            commonMistakes: [
                "letting the hips sag in the plank.",
                "rushing the transition — steady is the goal.",
                "rounding the back as you stand.",
            ]
        ),

        "burpee_pushup": ExerciseInstructions(
            actionSteps: [
                "stand tall with feet shoulder-width apart.",
                "squat down, hands to the floor.",
                "jump your feet back to a high plank.",
                "perform one push-up — chest toward the floor, then back up.",
                "jump the feet back to the hands and explode up into a jump.",
            ],
            breathing: [
                "exhale on each transition.",
                "inhale on the push-up's lower.",
            ],
            actionFeeling: [
                "chest, shoulders, and triceps on the push-up.",
                "full-body cardio across the whole movement.",
            ],
            commonMistakes: [
                "letting the hips sag during the push-up.",
                "skipping the push-up depth.",
                "landing hard on the explosive jump.",
            ]
        ),

        "modified_burpee": ExerciseInstructions(
            actionSteps: [
                "stand tall with feet shoulder-width apart.",
                "squat down and place your hands on the floor.",
                "step your right foot back, then your left foot back into a plank.",
                "step the right foot forward, then the left foot back to the hands.",
                "stand up — optional small jump at the top.",
            ],
            breathing: [
                "exhale on each step.",
                "inhale on the stand.",
            ],
            actionFeeling: [
                "full-body movement at a lower impact.",
                "core and legs both working.",
            ],
            commonMistakes: [
                "sagging hips in the plank.",
                "rounding the back on the squat.",
                "rushing — quality of movement matters.",
            ]
        ),

        "skipping": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet hip-width apart.",
                "lift your right knee up while pushing off the left foot — a small hop.",
                "land back on the left foot, then switch — lift the left knee, push off the right.",
                "your arms swing naturally — counter to the legs.",
                "find a steady rhythm — like skipping as a kid.",
            ],
            breathing: [
                "rhythmic breath matched to the pace.",
            ],
            actionFeeling: [
                "calves and quads firing.",
                "heart rate climbing fast.",
            ],
            commonMistakes: [
                "landing hard and flat.",
                "letting the arms hang.",
                "shoulders shrugging.",
            ]
        ),

        "bodyweight_swing": ExerciseInstructions(
            actionSteps: [
                "stand with your feet shoulder-width apart, a slight bend in your knees.",
                "swing your arms back between your legs as you hinge at the hips.",
                "drive your hips forward and use the momentum to swing your arms up to shoulder height.",
                "your body straightens up as the arms swing forward.",
                "swing back between the legs and repeat.",
            ],
            breathing: [
                "exhale on the forward swing.",
                "inhale on the back swing.",
            ],
            actionFeeling: [
                "glutes and hamstrings firing on the hip drive.",
                "core stabilizes the body.",
            ],
            commonMistakes: [
                "lifting with the arms — the swing comes from the hips.",
                "rounding the back on the hinge.",
                "swinging the arms too high — shoulder height is plenty.",
            ]
        ),

        "boxing_punches": ExerciseInstructions(
            actionSteps: [
                "stand with your feet staggered — left foot forward, right foot back, knees soft.",
                "bring your hands up by your jaw, fists ready.",
                "punch out with your left fist — extend the arm without locking the elbow.",
                "pull it back and punch out with your right.",
                "rotate slightly through the hips on each punch for power.",
                "keep alternating quick punches.",
            ],
            breathing: [
                "short exhales matched to each punch.",
            ],
            actionFeeling: [
                "shoulders, arms, and obliques working on each punch.",
                "core stabilizes the rotation.",
            ],
            commonMistakes: [
                "locking the elbows fully at extension.",
                "rotating only with the arms instead of the hips.",
                "shoulders shrugging up.",
            ]
        ),

        "run_punch": ExerciseInstructions(
            actionSteps: [
                "stand tall with a small jog in place — light feet, knees lifting.",
                "as you jog, punch out alternating fists in front of your chest.",
                "your feet keep moving while your arms punch.",
                "maintain a steady rhythm.",
            ],
            breathing: [
                "rhythmic breath matched to the pace.",
            ],
            actionFeeling: [
                "full-body cardio — arms, legs, and lungs working.",
                "shoulders and core engaging.",
            ],
            commonMistakes: [
                "letting the feet get heavy.",
                "punches dropping low — keep them at chest height.",
                "rounding the back.",
            ]
        ),

        "run_in_place": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet hip-width apart.",
                "begin jogging in place — knees lift, feet stay light.",
                "your arms swing naturally — counter to the legs.",
                "find a comfortable rhythm and maintain it.",
            ],
            breathing: [
                "rhythmic breath matched to the pace.",
            ],
            actionFeeling: [
                "calves and quads firing.",
                "heart rate climbing.",
            ],
            commonMistakes: [
                "landing flat-footed.",
                "rounding the back.",
                "letting the arms hang stiff.",
            ]
        ),

        // MARK: - Stretches / yoga / cool-down

        "cat_cow": ExerciseInstructions(
            actionSteps: [
                "start on hands and knees — wrists under shoulders, knees under hips.",
                "inhale: drop your belly toward the floor, lift your chest and gaze (cow).",
                "exhale: round your spine up toward the ceiling, tuck your chin (cat).",
                "move through the two shapes slowly with the breath.",
            ],
            breathing: [
                "inhale into cow (back arches, gaze up).",
                "exhale into cat (back rounds, chin tucks).",
            ],
            actionFeeling: [
                "gentle mobility through the entire spine.",
                "tension releasing through the back and neck.",
            ],
            commonMistakes: [
                "rushing — the slow rhythm is the medicine.",
                "shoulders shrugging up by the ears.",
                "letting the elbows lock — keep them softly bent.",
            ]
        ),

        "cat_stretch": ExerciseInstructions(
            actionSteps: [
                "start on hands and knees — wrists under shoulders, knees under hips.",
                "round your spine up toward the ceiling.",
                "draw your belly button toward your spine.",
                "tuck your chin gently toward your chest.",
                "hold and breathe.",
            ],
            breathing: [
                "exhale into the round.",
                "breathe steadily in the hold.",
            ],
            actionFeeling: [
                "stretch through the entire back of the body.",
                "shoulders and upper back releasing.",
            ],
            commonMistakes: [
                "shrugging the shoulders.",
                "letting the head drop heavy.",
                "rushing through the hold.",
            ]
        ),

        "cow_stretch": ExerciseInstructions(
            actionSteps: [
                "start on hands and knees.",
                "drop your belly toward the floor.",
                "lift your chest and your gaze.",
                "keep your shoulders relaxed and away from your ears.",
                "hold and breathe.",
            ],
            breathing: [
                "inhale into the lift.",
                "steady breath in the hold.",
            ],
            actionFeeling: [
                "opening through the chest and front of the body.",
                "gentle stretch through the abdomen.",
            ],
            commonMistakes: [
                "throwing the head back hard.",
                "letting the elbows hyperextend.",
                "shrugging the shoulders up.",
            ]
        ),

        "childs_pose": ExerciseInstructions(
            actionSteps: [
                "kneel on the floor with your big toes touching and knees wide apart.",
                "sit your hips back toward your heels.",
                "fold your torso forward between your thighs.",
                "extend your arms forward on the floor or rest them by your sides.",
                "let your forehead rest on the floor.",
                "breathe slowly into the back of the body.",
            ],
            breathing: [
                "slow, deep belly breaths.",
                "let each exhale soften you deeper.",
            ],
            actionFeeling: [
                "stretch through the lower back and hips.",
                "release through the shoulders and neck.",
            ],
            commonMistakes: [
                "forcing the hips down to the heels — let it open over time.",
                "tensing the shoulders.",
                "holding the breath.",
            ]
        ),

        "downward_dog": ExerciseInstructions(
            actionSteps: [
                "start on hands and knees.",
                "tuck your toes and lift your hips up and back.",
                "press the floor away with your hands.",
                "straighten your legs as much as feels good — heels reach toward the floor.",
                "your body forms an upside-down V.",
                "head hangs heavy between the arms.",
            ],
            breathing: [
                "deep, even breaths.",
                "each exhale soften deeper into the pose.",
            ],
            actionFeeling: [
                "stretch through the entire back of the body — calves, hamstrings, back.",
                "shoulders and chest opening.",
            ],
            commonMistakes: [
                "shoulders shrugging up by the ears.",
                "rounding the back to force the heels down.",
                "letting the hands collapse — press the floor away.",
            ]
        ),

        "puppy_pose": ExerciseInstructions(
            actionSteps: [
                "start on hands and knees.",
                "walk your hands forward while keeping your hips stacked over your knees.",
                "lower your forehead or chest toward the floor.",
                "your hips stay above your knees — don't sit back.",
                "breathe into the shoulders and chest.",
            ],
            breathing: [
                "slow, deep breaths.",
            ],
            actionFeeling: [
                "deep stretch through the shoulders and chest.",
                "back lengthens.",
            ],
            commonMistakes: [
                "sitting back into the heels — keep the hips lifted.",
                "letting the elbows splay wide.",
                "tensing the neck.",
            ]
        ),

        "shoulder_stretch": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet hip-width apart.",
                "bring your right arm across your chest at shoulder height.",
                "use your left hand to gently pull the right arm closer to your body.",
                "your right shoulder stays down — don't shrug.",
                "hold the stretch, then switch sides.",
            ],
            breathing: [
                "slow, steady breaths in the hold.",
            ],
            actionFeeling: [
                "stretch through the back of the shoulder and upper arm.",
                "shoulders stay relaxed.",
            ],
            commonMistakes: [
                "shrugging the stretched shoulder up.",
                "pulling too hard — let the stretch open gradually.",
                "twisting the torso.",
            ]
        ),

        "neck_stretch": ExerciseInstructions(
            actionSteps: [
                "stand or sit tall with your shoulders relaxed.",
                "gently tilt your head to your right shoulder.",
                "let the weight of your head lengthen the left side of your neck.",
                "your left shoulder stays down and back.",
                "hold, then switch sides.",
            ],
            breathing: [
                "slow, steady breaths.",
            ],
            actionFeeling: [
                "gentle release through the side of the neck.",
                "no forcing — let gravity do the work.",
            ],
            commonMistakes: [
                "pulling on the head with the hand.",
                "shrugging the opposite shoulder.",
                "tilting the head forward instead of straight to the side.",
            ]
        ),

        "side_tilt": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet hip-width apart.",
                "raise your right arm overhead.",
                "with control, tilt your torso to the left — your right side stretches long.",
                "keep your hips facing forward.",
                "return through center and switch sides.",
            ],
            breathing: [
                "inhale as you reach up.",
                "exhale as you tilt.",
            ],
            actionFeeling: [
                "stretch through the side of the body — ribs to hip.",
            ],
            commonMistakes: [
                "tipping forward instead of straight sideways.",
                "letting the hip push the opposite direction.",
                "shrugging the lifted shoulder.",
            ]
        ),

        "forward_fold_bind": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet hip-width apart.",
                "with a slight bend in your knees, hinge at your hips and fold forward.",
                "let your torso hang heavy toward your legs.",
                "grab opposite elbows and let your head dangle.",
                "breathe into the back of your body.",
            ],
            breathing: [
                "slow, steady breaths.",
                "each exhale soften further.",
            ],
            actionFeeling: [
                "stretch through the hamstrings and lower back.",
                "release through the neck and shoulders.",
            ],
            commonMistakes: [
                "forcing the legs straight if your back rounds — keep the knees bent.",
                "bouncing in the fold.",
                "shrugging the shoulders.",
            ]
        ),

        "seated_forward_fold": ExerciseInstructions(
            actionSteps: [
                "sit on the floor with your legs extended straight in front.",
                "flex your feet, toes pointing toward the ceiling.",
                "lift your chest as you hinge forward from the hips.",
                "reach toward your toes — grab your shins, ankles, or feet, wherever you can reach.",
                "let the spine lengthen, not round.",
                "hold and breathe.",
            ],
            breathing: [
                "inhale as you lengthen.",
                "exhale as you fold deeper.",
            ],
            actionFeeling: [
                "stretch through the hamstrings and lower back.",
            ],
            commonMistakes: [
                "rounding the back hard to reach the toes — lengthen first.",
                "forcing the knees straight — slight bend is fine.",
                "holding the breath.",
            ]
        ),

        "hamstring_stretch_standing": ExerciseInstructions(
            actionSteps: [
                "stand tall, feet together.",
                "step your right foot slightly forward and flex it — heel down, toes up.",
                "with hands on hips or extending forward, hinge at the hips.",
                "feel a stretch through the back of the right leg.",
                "hold, then switch.",
            ],
            breathing: [
                "slow, steady breaths.",
            ],
            actionFeeling: [
                "stretch through the back of the leg, especially the hamstring.",
            ],
            commonMistakes: [
                "rounding the back — hinge from the hips.",
                "letting the chest twist sideways.",
                "forcing the front leg straight.",
            ]
        ),

        "lying_hamstring_stretch": ExerciseInstructions(
            actionSteps: [
                "lie on your back with both knees bent.",
                "extend your right leg up toward the ceiling.",
                "grab behind your right thigh or knee with both hands.",
                "gently pull the leg toward your chest, keeping it as straight as comfortable.",
                "hold, then switch sides.",
            ],
            breathing: [
                "slow, steady breaths.",
                "exhale to soften deeper.",
            ],
            actionFeeling: [
                "stretch through the hamstring of the lifted leg.",
                "low back stays neutral.",
            ],
            commonMistakes: [
                "yanking the leg too hard.",
                "lifting the head off the floor.",
                "forcing the leg fully straight if your back lifts.",
            ]
        ),

        "lying_glute_stretch": ExerciseInstructions(
            actionSteps: [
                "lie on your back with both knees bent.",
                "cross your right ankle over your left thigh, just above the knee.",
                "reach through and grab the back of your left thigh with both hands.",
                "pull the left thigh toward your chest.",
                "you should feel a stretch in your right glute.",
                "hold, then switch sides.",
            ],
            breathing: [
                "slow, steady breaths.",
            ],
            actionFeeling: [
                "deep stretch through the outer glute of the crossed leg.",
            ],
            commonMistakes: [
                "tensing the head and shoulders — keep them on the floor.",
                "letting the crossed knee fall toward the body.",
                "pulling too hard too fast.",
            ]
        ),

        "single_knee_to_chest": ExerciseInstructions(
            actionSteps: [
                "lie on your back with both legs extended.",
                "draw your right knee in toward your chest.",
                "wrap both hands around the shin or the back of the thigh.",
                "gently pull the knee closer.",
                "your left leg stays long on the floor.",
                "hold, then switch sides.",
            ],
            breathing: [
                "slow, steady breaths.",
                "exhale to soften the hip deeper.",
            ],
            actionFeeling: [
                "stretch through the right glute and lower back.",
                "stretch through the front of the left hip.",
            ],
            commonMistakes: [
                "letting the extended leg bend up.",
                "lifting the head off the floor.",
                "pulling too aggressively.",
            ]
        ),

        "knees_to_chest": ExerciseInstructions(
            actionSteps: [
                "lie on your back.",
                "draw both knees in toward your chest.",
                "wrap your hands around your shins or the back of your thighs.",
                "gently pull both knees closer.",
                "let your lower back press into the floor.",
                "hold and breathe.",
            ],
            breathing: [
                "slow, steady breaths.",
                "exhale to soften deeper.",
            ],
            actionFeeling: [
                "stretch through the lower back and glutes.",
            ],
            commonMistakes: [
                "lifting the head off the floor.",
                "tensing the shoulders.",
                "rocking side to side.",
            ]
        ),

        "standing_knee_hug": ExerciseInstructions(
            actionSteps: [
                "stand tall with your feet hip-width apart.",
                "draw your right knee up toward your chest.",
                "wrap both hands around the shin and pull the knee closer.",
                "your standing leg stays straight and active.",
                "lower with control, then switch sides.",
            ],
            breathing: [
                "exhale as you pull the knee in.",
                "inhale as you lower.",
            ],
            actionFeeling: [
                "stretch through the glute and lower back of the lifted leg.",
                "balance and core working on the standing leg.",
            ],
            commonMistakes: [
                "leaning backward to make balance easier.",
                "yanking the knee too hard.",
                "shrugging the shoulders.",
            ]
        ),

        "standing_quad_stretch": ExerciseInstructions(
            actionSteps: [
                "stand tall — hold a wall or chair for balance if needed.",
                "bend your right knee and grab your right foot behind you.",
                "gently pull the heel toward your glute.",
                "your knees stay close together — don't let the lifted knee splay out.",
                "stand tall and tuck your tailbone slightly.",
                "hold, then switch sides.",
            ],
            breathing: [
                "slow, steady breaths.",
            ],
            actionFeeling: [
                "stretch through the front of the thigh.",
                "front of the hip opens slightly.",
            ],
            commonMistakes: [
                "letting the bent knee splay out wide.",
                "arching the lower back to reach further.",
                "leaning forward.",
            ]
        ),

        "kneeling_quad_stretch": ExerciseInstructions(
            actionSteps: [
                "kneel on your right knee with your left foot planted in front in a runner's lunge.",
                "use a soft mat under the back knee if needed.",
                "reach back and grab the top of your right foot with your right hand.",
                "gently pull the heel toward your right glute.",
                "tuck your tailbone slightly to deepen the stretch.",
                "hold, then switch sides.",
            ],
            breathing: [
                "slow, steady breaths.",
            ],
            actionFeeling: [
                "deep stretch through the quad and hip flexor of the back leg.",
            ],
            commonMistakes: [
                "arching the lower back.",
                "letting the front knee drift forward of the ankle.",
                "yanking the foot hard.",
            ]
        ),

        "hip_flexor_stretch": ExerciseInstructions(
            actionSteps: [
                "kneel on your right knee with your left foot planted in front in a low lunge.",
                "your front knee is stacked over your front ankle at 90°.",
                "tuck your tailbone slightly and press your hips forward.",
                "you should feel a stretch through the front of the right hip and thigh.",
                "hold, then switch.",
            ],
            breathing: [
                "slow, steady breaths.",
                "exhale to deepen.",
            ],
            actionFeeling: [
                "stretch through the front of the hip and the top of the thigh.",
            ],
            commonMistakes: [
                "letting the front knee drift past the toes.",
                "arching the lower back instead of tucking the tailbone.",
                "leaning forward.",
            ]
        ),

        "deep_hip_flexor": ExerciseInstructions(
            actionSteps: [
                "start in a low kneeling lunge — right foot forward, left knee on the floor behind.",
                "front knee at 90°, stacked over the ankle.",
                "tuck your tailbone and press the left hip forward.",
                "for more depth, raise your left arm overhead and reach toward your right side.",
                "hold, then switch.",
            ],
            breathing: [
                "slow, steady breaths.",
                "exhale to deepen the hip release.",
            ],
            actionFeeling: [
                "deep stretch through the front of the back-leg hip.",
                "side of the body lengthens with the overhead reach.",
            ],
            commonMistakes: [
                "arching the back instead of tucking the tailbone.",
                "front knee drifting past the toes.",
                "shrugging the lifted shoulder.",
            ]
        ),

        "lizard_pose": ExerciseInstructions(
            actionSteps: [
                "start in a low lunge with your right foot forward, hands on the floor inside the right foot.",
                "lower your left knee to the floor for support.",
                "walk the right foot slightly outside your right hand.",
                "lower onto your forearms if your body allows.",
                "let your hips melt toward the floor.",
                "hold, then switch sides.",
            ],
            breathing: [
                "slow, deep belly breaths.",
            ],
            actionFeeling: [
                "deep stretch through the front of the back leg's hip.",
                "opening through the right hip and groin.",
            ],
            commonMistakes: [
                "shrugging the shoulders up.",
                "letting the front knee cave inward.",
                "forcing the depth — let the hips open over time.",
            ]
        ),

        "reverse_tabletop": ExerciseInstructions(
            actionSteps: [
                "sit on the floor with your knees bent and feet flat.",
                "place your hands flat on the floor behind you, fingers pointing toward your hips.",
                "press into your hands and feet to lift your hips toward the ceiling.",
                "your torso forms a flat tabletop.",
                "shoulders are over the wrists, knees over the ankles.",
                "hold and breathe.",
            ],
            breathing: [
                "exhale as you lift.",
                "steady breath through the hold.",
            ],
            actionFeeling: [
                "stretch across the front of the shoulders and chest.",
                "glutes squeezing to hold the line.",
            ],
            commonMistakes: [
                "letting the hips drop.",
                "fingers pointing the wrong way.",
                "shrugging the shoulders.",
            ]
        ),

    ]
}
