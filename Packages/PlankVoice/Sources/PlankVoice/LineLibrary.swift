import Foundation

/// Manages the library of coaching lines.
public struct LineLibrary: Sendable {
    private let lines: [VoiceLine]

    public init(lines: [VoiceLine]) {
        self.lines = lines
    }

    public func randomLine(
        for category: VoiceCategory,
        triggerState: String?,
        excluding played: Set<String>
    ) -> VoiceLine? {
        lines.filter { line in
            line.category == category
            && (triggerState == nil || line.triggerState == triggerState)
            && !played.contains(line.id)
        }.randomElement()
    }

    // MARK: - Default Library
    //
    // Voice pattern: SHORT COMMAND first → then roast/color.
    // Like a real gym trainer: the correction is instant and clear,
    // the personality comes after. "Hips! Up! ...you're giving hammock."
    //
    // Persona: Trendy Black woman fitness creator. Warm, funny, not mean.

    public static var devLibrary: LineLibrary {
        LineLibrary(lines: [

            // ── GUIDE: Setup (natural, like talking to a friend) ──
            VoiceLine(id: "guide_setup_1", text: "Okay prop your phone up so I can see your whole body, then get into plank. Forearms on the floor, elbows under your shoulders.", category: .guide, triggerState: "notInPosition"),
            VoiceLine(id: "guide_setup_2", text: "Set your phone down about six feet away, lean it against something, then drop into plank position. I need to see you head to toe.", category: .guide, triggerState: "notInPosition"),
            VoiceLine(id: "guide_setup_3", text: "Alright, get your phone set up where it can see you, then get down. Forearms flat, toes tucked, body straight like a board.", category: .guide, triggerState: "notInPosition"),

            // ── GUIDE: Good form (2-3 words) ──
            VoiceLine(id: "guide_good_1", text: "Good. Hold.", category: .guide, triggerState: "goodForm"),
            VoiceLine(id: "guide_good_2", text: "That's it.", category: .guide, triggerState: "goodForm"),
            VoiceLine(id: "guide_good_3", text: "Yes. Breathe.", category: .guide, triggerState: "goodForm"),

            // ── HIP SAG — command then roast ──
            VoiceLine(id: "hip_sag_1", text: "Hips! Up! You're giving hammock right now.", category: .form, triggerState: "hipSag"),
            VoiceLine(id: "hip_sag_2", text: "Hips up. Squeeze your glutes. My mama planks better than this.", category: .form, triggerState: "hipSag"),
            VoiceLine(id: "hip_sag_3", text: "Hips! Belly button to spine. Don't spill grandma's soup.", category: .form, triggerState: "hipSag"),
            VoiceLine(id: "hip_sag_4", text: "Hips are sagging. Tuck your tailbone. Tighten everything.", category: .form, triggerState: "hipSag"),
            VoiceLine(id: "hip_sag_5", text: "Hips! If they drop any lower they'll need their own zip code.", category: .form, triggerState: "hipSag"),
            VoiceLine(id: "hip_sag_6", text: "Hips up! Engage that core like rent is due tomorrow.", category: .form, triggerState: "hipSag"),

            // ── HIP PIKE — command then roast ──
            VoiceLine(id: "hip_pike_1", text: "Hips down! This is a plank not yoga class.", category: .form, triggerState: "hipPike"),
            VoiceLine(id: "hip_pike_2", text: "Drop your hips! You look like a tent. Flatten out.", category: .form, triggerState: "hipPike"),
            VoiceLine(id: "hip_pike_3", text: "Hips down! Cheating doesn't count in this house.", category: .form, triggerState: "hipPike"),
            VoiceLine(id: "hip_pike_4", text: "Flatten! Your butt is way too high. Straight line.", category: .form, triggerState: "hipPike"),

            // ── SHOULDER CREEP — command then roast ──
            VoiceLine(id: "shoulder_1", text: "Shoulders! Down! You're not a turtle, drop them.", category: .form, triggerState: "shoulderCreep"),
            VoiceLine(id: "shoulder_2", text: "Shoulders down. Push the floor away. You're planking not panicking.", category: .form, triggerState: "shoulderCreep"),
            VoiceLine(id: "shoulder_3", text: "Shoulders! Relax. Shoulder blades in your back pockets.", category: .form, triggerState: "shoulderCreep"),
            VoiceLine(id: "shoulder_4", text: "Drop the shoulders! Your traps didn't sign up for this.", category: .form, triggerState: "shoulderCreep"),

            // ── RECOVERY ──
            VoiceLine(id: "recovery_1", text: "There it is. Hold that.", category: .form, triggerState: "recovery"),
            VoiceLine(id: "recovery_2", text: "Good fix. Stay.", category: .form, triggerState: "recovery"),
            VoiceLine(id: "recovery_3", text: "See? When you try, you're actually good at this.", category: .form, triggerState: "recovery"),
            VoiceLine(id: "recovery_4", text: "That's the one. Don't move.", category: .form, triggerState: "recovery"),

            // ── STOPPED ──
            VoiceLine(id: "stopped_1", text: "Back down! I didn't say stop.", category: .form, triggerState: "stopped"),
            VoiceLine(id: "stopped_2", text: "Get back in plank! Timer's still going.", category: .form, triggerState: "stopped"),
            VoiceLine(id: "stopped_3", text: "Nope! Back down. We're not done.", category: .form, triggerState: "stopped"),
            VoiceLine(id: "stopped_4", text: "You stopped? In this economy? Back down.", category: .form, triggerState: "stopped"),

            // ── MILESTONES ──
            VoiceLine(id: "milestone_10", text: "Ten seconds. Stay tight.", category: .milestone, triggerState: "10s"),
            VoiceLine(id: "milestone_30", text: "Thirty! Halfway. Check form. Keep going.", category: .milestone, triggerState: "30s"),
            VoiceLine(id: "milestone_60", text: "One minute! Okay I see you!", category: .milestone, triggerState: "60s"),
            VoiceLine(id: "milestone_90", text: "Ninety seconds! Most people quit by now. Not you.", category: .milestone, triggerState: "90s"),
            VoiceLine(id: "milestone_120", text: "Two minutes! That's elite. Your core is transforming.", category: .milestone, triggerState: "120s"),

            // ── COUNTDOWN ──
            VoiceLine(id: "countdown_10", text: "Ten seconds! Lock in. Finish strong.", category: .countdown, triggerState: "10"),
            VoiceLine(id: "countdown_5", text: "Five!", category: .countdown, triggerState: "5"),
            VoiceLine(id: "countdown_3", text: "Three!", category: .countdown, triggerState: "3"),
            VoiceLine(id: "countdown_2", text: "Two!", category: .countdown, triggerState: "2"),
            VoiceLine(id: "countdown_1", text: "One!", category: .countdown, triggerState: "1"),

            // ── SESSION ──
            VoiceLine(id: "start_1", text: "I see you. Go.", category: .sessionStart),
            VoiceLine(id: "start_2", text: "You showed up. Let's get it.", category: .sessionStart),
            VoiceLine(id: "end_good", text: "Done! You ate that. See you tomorrow.", category: .sessionEnd, triggerState: "good"),
            VoiceLine(id: "end_bad", text: "It's done. We don't talk about it. Tomorrow.", category: .sessionEnd, triggerState: "bad"),

            // ── CAMERA ──
            VoiceLine(id: "camera_bad_1", text: "Can't see you. Move your phone back.", category: .cameraBad),
            VoiceLine(id: "camera_bad_2", text: "Back up your phone. I need the full picture.", category: .cameraBad),
        ])
    }
}
