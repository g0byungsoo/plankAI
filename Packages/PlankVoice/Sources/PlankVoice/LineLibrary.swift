import Foundation

/// Manages the library of coaching lines. Handles selection, tagging, and no-repeat logic.
public struct LineLibrary: Sendable {
    private let lines: [VoiceLine]

    public init(lines: [VoiceLine]) {
        self.lines = lines
    }

    /// Select a random line matching category and trigger state, excluding already-played IDs.
    public func randomLine(
        for category: VoiceCategory,
        triggerState: String?,
        excluding played: Set<String>
    ) -> VoiceLine? {
        let candidates = lines.filter { line in
            line.category == category
            && (triggerState == nil || line.triggerState == triggerState)
            && !played.contains(line.id)
        }

        return candidates.randomElement()
    }

    /// Default dev library with placeholder lines for testing.
    public static var devLibrary: LineLibrary {
        LineLibrary(lines: [
            // Form roasts (hip sag)
            VoiceLine(id: "hip_sag_1", text: "Your hips are sagging. My dead houseplant has better core engagement.", category: .form, triggerState: "hipSag"),
            VoiceLine(id: "hip_sag_2", text: "Hips. Up. Now.", category: .form, triggerState: "hipSag"),
            VoiceLine(id: "hip_sag_3", text: "I can see your hips dropping from here. And I'm a phone.", category: .form, triggerState: "hipSag"),

            // Form roasts (shoulder creep)
            VoiceLine(id: "shoulder_1", text: "Your shoulders are creeping forward. Are you planking or praying?", category: .form, triggerState: "shoulderCreep"),
            VoiceLine(id: "shoulder_2", text: "Shoulders back. You're not a turtle.", category: .form, triggerState: "shoulderCreep"),

            // Recovery (encouragement)
            VoiceLine(id: "recovery_1", text: "There you go. That's the form I was waiting for.", category: .form, triggerState: "recovery"),
            VoiceLine(id: "recovery_2", text: "Better. Much better. Keep that.", category: .form, triggerState: "recovery"),

            // Milestones
            VoiceLine(id: "milestone_10", text: "Ten seconds. Barely started.", category: .milestone, triggerState: "10s"),
            VoiceLine(id: "milestone_30", text: "Thirty seconds. Halfway there. Don't you dare quit.", category: .milestone, triggerState: "30s"),
            VoiceLine(id: "milestone_60", text: "Sixty seconds. That's a full minute. Respect.", category: .milestone, triggerState: "60s"),

            // Countdown
            VoiceLine(id: "countdown_10", text: "Ten seconds left.", category: .countdown, triggerState: "10"),
            VoiceLine(id: "countdown_5", text: "Five.", category: .countdown, triggerState: "5"),
            VoiceLine(id: "countdown_3", text: "Three.", category: .countdown, triggerState: "3"),
            VoiceLine(id: "countdown_2", text: "Two.", category: .countdown, triggerState: "2"),
            VoiceLine(id: "countdown_1", text: "One.", category: .countdown, triggerState: "1"),

            // Session
            VoiceLine(id: "start_1", text: "Let's go. Phone sees you. Timer starts now.", category: .sessionStart),
            VoiceLine(id: "end_good", text: "Done. Not bad. See you tomorrow.", category: .sessionEnd, triggerState: "good"),
            VoiceLine(id: "end_bad", text: "We'll pretend that didn't happen. See you tomorrow.", category: .sessionEnd, triggerState: "bad"),

            // Camera
            VoiceLine(id: "camera_bad_1", text: "I can't see you. Move your phone back a bit.", category: .cameraBad),
        ])
    }
}
