import Foundation
import SwiftData

// MARK: - JeniMemory (v25 E3 ONE JENI)
//
// docs/app_v25/12_E3_ONE_JENI.md §4. THE COMPOUNDING LOOP.
//
// The founder's test for this era: *something the user does today
// should make Jeni meaningfully better tomorrow or next week.* Every
// other store in the app records what HAPPENED (plates, doses,
// weights, steps). Nothing recorded what the user TOLD her. So the
// same sentence — "i don't eat before 11", "i can't do floor work",
// "stop telling me to weigh in" — had to be said again every session,
// and a coach who forgets is not a coach.
//
// This is that store. It is deliberately small.
//
// THE LAWS:
//
//  1. NOTHING IS WRITTEN SILENTLY. A note only lands through the
//     `remember` tool, which always renders a confirmation card
//     showing the exact words. This is the adaptation-consent law
//     (00_THE_SYSTEM §13) applied to knowledge: silent profiling is a
//     bug class, not a feature. `MemoryGuard` refuses categories that
//     should never be inferred by a model at all.
//  2. IT IS HERS. Every note is visible and deletable in settings,
//     in the words that were stored. Nothing is paraphrased on the
//     way out.
//  3. IT NEVER BECOMES A MEDICAL RECORD. Diagnoses, medications,
//     symptoms, body descriptions and weights are refused at the
//     door — those live in their own provenance-stamped stores where
//     they carry a basis, or they do not live at all.
//  4. IT IS BOUNDED. `maxNotes` per topic, supersede-in-place on a
//     near-duplicate, so the set stays something a person could read
//     in one sitting and a context envelope can carry whole.
//  5. IT IS NOT A TRANSCRIPT. Notes are facts about the person, not
//     things that happened. "prefers evenings" is a note; "had a bad
//     day tuesday" is not.

@Model
final class JeniMemoryRecord {
    @Attribute(.unique) var id: String
    var userId: String
    /// One of `JeniMemoryTopic`.
    var topic: String
    /// The note, verbatim as confirmed. Short by contract.
    var note: String
    /// "told" — they said it. "confirmed" — they accepted jeni's
    /// reading of it. No third basis exists on purpose: nothing here
    /// is inferred behind their back.
    var basis: String
    var createdAt: Date
    /// Set when a later note replaced this one; kept so the settings
    /// list can stay honest about what changed without resurrecting
    /// it into the envelope.
    var supersededAt: Date?

    init(
        id: String = UUID().uuidString,
        userId: String,
        topic: String,
        note: String,
        basis: String = "told",
        createdAt: Date = .now,
        supersededAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.topic = topic
        self.note = note
        self.basis = basis
        self.createdAt = createdAt
        self.supersededAt = supersededAt
    }
}

enum JeniMemoryTopic: String, CaseIterable {
    case food
    case movement
    case schedule
    /// How they want to be coached — the one topic that changes jeni
    /// herself.
    case coaching
    case life

    var heading: String {
        switch self {
        case .food: return "how you eat"
        case .movement: return "how you move"
        case .schedule: return "your days"
        case .coaching: return "how you want to be coached"
        case .life: return "the rest"
        }
    }
}

// MARK: - MemoryGuard
//
// The door. Pure, so its refusals are pinnable.

enum MemoryGuard {

    enum Verdict: Equatable {
        case accept(note: String, topic: JeniMemoryTopic)
        case refuse(reason: String)
    }

    static let maxLength = 140
    static let minLength = 4

    /// Categories a model must never write into a durable note about
    /// a person. Some are refused because a wrong one is harmful
    /// (medical), some because the app already stores them properly
    /// with a basis (weights, doses), and some because a coach
    /// recording them is simply not okay (body judgements).
    static let bannedMarkers: [String] = [
        // medical + diagnostic
        "diagnos", "prescrib", "dose", "mg ", "milligram", "ozempic",
        "wegovy", "mounjaro", "zepbound", "saxenda", "trulicity",
        "rybelsus", "semaglutide", "tirzepatide", "liraglutide",
        "insulin", "thyroid", "pcos", "diabet", "cancer", "pregnan",
        "depress", "anxiety disorder", "adhd", "bipolar", "disorder",
        // symptoms belong to the observation store, with severity
        "nausea", "nauseous", "constipat", "vomit", "diarrh",
        // the body, which is never jeni's to describe (L4)
        "weighs", "weight is", "bmi", "body fat", "overweight",
        "obese", "fat ", "skinny", "looks ", "ugly", "attractive",
        // things with their own provenance-stamped homes
        "calorie target", "step goal", "protein floor",
        // self-harm and ED language routes to care, never to a note
        "suicid", "self harm", "self-harm", "purge", "anorex", "bulim",
    ]

    static func screen(note rawNote: String, topic rawTopic: String) -> Verdict {
        let note = rawNote
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        guard note.count >= minLength else {
            return .refuse(reason: "too short to be a fact")
        }
        guard note.count <= maxLength else {
            return .refuse(reason: "too long for a note")
        }
        guard let topic = JeniMemoryTopic(rawValue: rawTopic) else {
            return .refuse(reason: "unknown topic")
        }
        let lowered = " " + note.lowercased() + " "
        if let hit = bannedMarkers.first(where: { lowered.contains($0) }) {
            return .refuse(reason: "not jeni's to remember (\(hit.trimmingCharacters(in: .whitespaces)))")
        }
        return .accept(note: note.lowercased(), topic: topic)
    }

    /// Two notes are "the same fact" when they share most of their
    /// meaningful words. Cheap on purpose: the point is to stop the
    /// set drifting into six phrasings of one thing, not to be clever.
    static func isNearDuplicate(_ a: String, _ b: String) -> Bool {
        let stop: Set<String> = ["the", "a", "an", "i", "im", "i'm", "to",
                                 "of", "and", "my", "me", "is", "are", "on",
                                 "in", "for", "it", "that", "with", "you"]
        func tokens(_ s: String) -> Set<String> {
            Set(
                s.lowercased()
                    .components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { $0.count > 1 && !stop.contains($0) }
            )
        }
        let ta = tokens(a), tb = tokens(b)
        guard !ta.isEmpty, !tb.isEmpty else { return false }
        let overlap = Double(ta.intersection(tb).count)
        return overlap / Double(min(ta.count, tb.count)) >= 0.6
    }
}

// MARK: - JeniMemoryStore

@MainActor
enum JeniMemoryStore {

    /// Per topic. The whole set has to fit in a context envelope and
    /// in a person's patience.
    static let maxNotesPerTopic = 6

    static func active(
        userId: String, in context: ModelContext
    ) -> [JeniMemoryRecord] {
        guard !userId.isEmpty else { return [] }
        let d = FetchDescriptor<JeniMemoryRecord>(
            predicate: #Predicate {
                $0.userId == userId && $0.supersededAt == nil
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(d)) ?? []
    }

    /// Write a screened note. Returns the stored record, or nil when
    /// the guard refused. Near-duplicates SUPERSEDE rather than
    /// accumulate, so "i don't eat before 11" becoming "i don't eat
    /// before noon" replaces the fact instead of contradicting it.
    @discardableResult
    static func remember(
        note rawNote: String,
        topic rawTopic: String,
        userId: String,
        basis: String = "told",
        now: Date = .now,
        in context: ModelContext
    ) -> JeniMemoryRecord? {
        guard case let .accept(note, topic) = MemoryGuard.screen(
            note: rawNote, topic: rawTopic
        ), !userId.isEmpty else { return nil }

        let existing = active(userId: userId, in: context)
        for record in existing where MemoryGuard.isNearDuplicate(record.note, note) {
            if record.note == note { return record }   // already known
            record.supersededAt = now
        }
        // Bound the topic: the oldest goes when a seventh arrives.
        let inTopic = existing
            .filter { $0.topic == topic.rawValue && $0.supersededAt == nil }
            .sorted { $0.createdAt < $1.createdAt }
        if inTopic.count >= maxNotesPerTopic, let oldest = inTopic.first {
            oldest.supersededAt = now
        }

        let record = JeniMemoryRecord(
            userId: userId, topic: topic.rawValue, note: note,
            basis: basis, createdAt: now
        )
        context.insert(record)
        try? context.save()
        return record
    }

    static func forget(id: String, userId: String, in context: ModelContext) {
        let d = FetchDescriptor<JeniMemoryRecord>(
            predicate: #Predicate { $0.id == id && $0.userId == userId }
        )
        guard let record = (try? context.fetch(d))?.first else { return }
        context.delete(record)
        try? context.save()
    }

    static func forgetAll(userId: String, in context: ModelContext) {
        for record in active(userId: userId, in: context) {
            context.delete(record)
        }
        try? context.save()
    }

    /// The envelope form — grouped by topic, newest first, verbatim.
    static func envelope(
        userId: String, in context: ModelContext
    ) -> [String: [String]] {
        var out: [String: [String]] = [:]
        for record in active(userId: userId, in: context) {
            out[record.topic, default: []].append(record.note)
        }
        return out
    }
}
