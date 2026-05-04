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
    // IDs must exist for ALL trainers (Kira, Jeni, Matson).
    // Only use IDs 1-2 (or 1-3 max) per category to ensure
    // every trainer has a matching clip.

    public static var devLibrary: LineLibrary {
        LineLibrary(lines: [

            // ── GUIDE: Setup ──
            VoiceLine(id: "guide_setup_1", text: "", category: .guide, triggerState: "notInPosition"),
            VoiceLine(id: "guide_setup_2", text: "", category: .guide, triggerState: "notInPosition"),

            // ── GUIDE: Good form ──
            VoiceLine(id: "guide_good_1", text: "", category: .guide, triggerState: "goodForm"),
            VoiceLine(id: "guide_good_2", text: "", category: .guide, triggerState: "goodForm"),
            VoiceLine(id: "guide_good_3", text: "", category: .guide, triggerState: "goodForm"),

            // ── HIP SAG ──
            VoiceLine(id: "hip_sag_1", text: "", category: .form, triggerState: "hipSag"),
            VoiceLine(id: "hip_sag_2", text: "", category: .form, triggerState: "hipSag"),
            VoiceLine(id: "hip_sag_3", text: "", category: .form, triggerState: "hipSag"),

            // ── HIP PIKE ──
            VoiceLine(id: "hip_pike_1", text: "", category: .form, triggerState: "hipPike"),
            VoiceLine(id: "hip_pike_2", text: "", category: .form, triggerState: "hipPike"),

            // ── SHOULDER CREEP ──
            VoiceLine(id: "shoulder_1", text: "", category: .form, triggerState: "shoulderCreep"),
            VoiceLine(id: "shoulder_2", text: "", category: .form, triggerState: "shoulderCreep"),

            // ── RECOVERY ──
            VoiceLine(id: "recovery_1", text: "", category: .form, triggerState: "recovery"),
            VoiceLine(id: "recovery_2", text: "", category: .form, triggerState: "recovery"),

            // ── STOPPED ──
            VoiceLine(id: "stopped_1", text: "", category: .form, triggerState: "stopped"),
            VoiceLine(id: "stopped_2", text: "", category: .form, triggerState: "stopped"),

            // ── MILESTONES ──
            VoiceLine(id: "milestone_10", text: "", category: .milestone, triggerState: "10s"),
            VoiceLine(id: "milestone_30", text: "", category: .milestone, triggerState: "30s"),
            VoiceLine(id: "milestone_60", text: "", category: .milestone, triggerState: "60s"),
            VoiceLine(id: "milestone_90", text: "", category: .milestone, triggerState: "90s"),
            VoiceLine(id: "milestone_120", text: "", category: .milestone, triggerState: "120s"),

            // ── COUNTDOWN ──
            VoiceLine(id: "countdown_10", text: "", category: .countdown, triggerState: "10"),
            VoiceLine(id: "countdown_5", text: "", category: .countdown, triggerState: "5"),
            VoiceLine(id: "countdown_3", text: "", category: .countdown, triggerState: "3"),
            VoiceLine(id: "countdown_2", text: "", category: .countdown, triggerState: "2"),
            VoiceLine(id: "countdown_1", text: "", category: .countdown, triggerState: "1"),

            // ── SESSION ──
            VoiceLine(id: "start_1", text: "", category: .sessionStart),
            VoiceLine(id: "start_2", text: "", category: .sessionStart),
            VoiceLine(id: "end_good", text: "", category: .sessionEnd, triggerState: "good"),
            VoiceLine(id: "end_bad", text: "", category: .sessionEnd, triggerState: "bad"),

            // ── CAMERA ──
            VoiceLine(id: "camera_bad_1", text: "", category: .cameraBad),
            VoiceLine(id: "camera_bad_2", text: "", category: .cameraBad),
        ])
    }
}
