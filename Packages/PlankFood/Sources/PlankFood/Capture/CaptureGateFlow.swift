import Foundation

// MARK: - CaptureGateFlow (pass 52 — THE FIRST DAY)
//
// The pure decision layer for what stands between an entrance and the
// record. Pass 50 filmed the defect this exists to prevent: a typed
// first meal hit the consent gate and the gate exited to the CAMERA —
// the sentence survived only as a hidden prefill behind "or write it",
// and the OS camera-permission dialog fired over a meal that never
// needed a lens (`films/words.mp4`, 50 §5).
//
// THE LAW: an entrance may never mutate into another entrance because
// a gate was attached at the wrong architectural level. WORDS stays
// WORDS; PHOTO stays PHOTO. A gate is a pause on the way to the door
// she chose, never a detour to a different one.
//
// The second law (50 §5.3): the "before your first plate" questions are
// an accuracy OFFER, not a toll. They may never stand between her and
// record #1 — they are offered once, AFTER her first reading has filed.
public enum CaptureGateFlow {

    /// Where the flow lands once every gate is passed — decided by the
    /// door she used, nothing else.
    public enum Landing: Equatable {
        /// The describe path: her words, straight to the estimate.
        case words
        /// The lens. Only when the camera was the door she chose.
        case camera
    }

    /// The door's landing. Words intent comes from the entry itself or
    /// from a handed-in sentence (jeni's prefill is the user's words by
    /// contract — jeni never authors a plate).
    public static func landing(entry: CaptureFlowView.Entry, prefill: String?) -> Landing {
        if entry == .words { return .words }
        if let p = prefill, !p.trimmingCharacters(in: .whitespaces).isEmpty {
            return .words
        }
        return .camera
    }

    /// The first phase of the flow. Consent (Apple 5.1.2(i)) is the one
    /// gate allowed to precede a record — and it exits to the LANDING,
    /// never to a hardcoded door. The first-plate questions are gone
    /// from this chain by law (they offer themselves after the first
    /// reading files — `offersQuestionsAfterLog`).
    public enum FirstPhase: Equatable {
        case consent
        case landing
    }

    public static func firstPhase(consented: Bool) -> FirstPhase {
        consented ? .landing : .consent
    }

    /// Whether the flow, having just FILED a record, should offer the
    /// three soft questions — once ever, after the first kept plate,
    /// never before it.
    public static func offersQuestionsAfterLog(questionsDone: Bool) -> Bool {
        !questionsDone
    }
}

// MARK: - Door-aware consent copy
//
// One consent, two doors. Both variants disclose BOTH channels (the
// sentence and the photo make the same trip), so a single acceptance
// covers the feature — but the door she is standing at leads, and the
// photo teachings render only where there is a photograph to teach.
public enum FoodAIConsentCopy {

    public enum Door: Equatable { case photo, words }

    /// The serif header. The photo door keeps its shipped line.
    public static func header(for door: Door) -> (text: String, italic: String) {
        switch door {
        case .photo: return ("how jeni reads a plate", "reads")
        case .words: return ("how jeni counts a meal", "counts")
        }
    }

    /// The line under the header.
    public static func subline(for door: Door) -> String {
        switch door {
        case .photo:
            return "one photo. these three make her answer tighter."
        case .words:
            return "you say it, jeni prices it. one thing to agree to first."
        }
    }

    /// The uppercase label over the facts.
    public static func factsLabel(for door: Door) -> String {
        switch door {
        case .photo: return "what happens to the photo"
        case .words: return "what happens to your words"
        }
    }

    /// The disclosure facts, exactly true, door-led. Every fact the
    /// shipped photo sheet carried is still carried; the words door
    /// leads with the sentence and names the photo's future trip so
    /// one acceptance honestly covers both channels.
    public static func facts(for door: Door) -> [String] {
        switch door {
        case .photo:
            return [
                "it goes to OpenAI's vision model",
                "they don't train on it",
                "it's deleted after analysis, unless you opt to keep it",
            ]
        case .words:
            return [
                "your sentence goes to OpenAI's model to be counted",
                "they don't train on it",
                "a photo, when you use the camera later, makes the same trip",
            ]
        }
    }

    /// The three framing teachings are drawn from photographic failure
    /// modes; they render only on the door that takes photographs.
    public static func showsTeachings(for door: Door) -> Bool {
        door == .photo
    }
}
