import Foundation

// MARK: - LessonManifest
//
// In-memory representation of the bundled `manifest_v1.json` resource —
// the full 84-day canonical CBT spine + 18-day extension + per-slot
// cohort variants + pillar/act metadata.
//
// Loading model: bundled at app launch (synchronous, cheap — JSON is
// ~430KB, decodes in <50ms on A14). A future v1.0.8+ pass can swap in
// `loadFromSupabaseStorage` so content updates ship without app review;
// the on-device bundled copy stays as the offline fallback.
//
// Versioning: `version` increments when a manifest ships incompatible
// schema changes; `ScheduledLesson.manifestVersion` snapshots the
// version a user was scheduled against so re-personalization can detect
// drift. Lesson IDs are stable across versions (additive-only edits).

public struct LessonManifest: Codable, Sendable {
    public var version: Int
    public var generatedAt: String
    public var pillars: [PillarSpec]
    public var acts: [ActSpec]
    public var canonical84: [LessonSlot]
    public var extension18: [LessonSlot]
    /// Voice playbook payload — north star + forbidden/preferred vocab
    /// + sentence rhythms. Carried as opaque dictionary because the
    /// shape is content-team-owned; lint tests parse it as JSON without
    /// requiring Swift struct edits when writers iterate.
    public var voicePlaybook: [String: AnyCodable]?

    // MARK: - Lookups

    public func slot(byCanonicalDay day: Int) -> LessonSlot? {
        canonical84.first { $0.canonicalDay == day }
    }

    public func slot(byId id: String) -> LessonSlot? {
        canonical84.first { $0.id == id }
            ?? extension18.first { $0.id == id }
    }

    public func pillar(_ pid: PillarId) -> PillarSpec? {
        pillars.first { $0.id == pid }
    }

    public func act(_ number: Int) -> ActSpec? {
        acts.first { $0.number == number }
    }

    // MARK: - Loading

    /// Bundled manifest. Throws if the resource is missing (release-
    /// blocking) or unparseable (release-blocking).
    public static func loadBundled(bundle: Bundle = .main) throws -> LessonManifest {
        guard let url = bundle.url(forResource: "manifest_v1", withExtension: "json")
                    ?? bundle.url(forResource: "manifest_v1", withExtension: "json", subdirectory: "Resources") else {
            throw ManifestError.bundleMissing
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(LessonManifest.self, from: data)
        } catch {
            throw ManifestError.decodeFailed(error)
        }
    }

    /// Test/preview helper: a minimal in-memory manifest with two
    /// canonical slots covering pillars P1 + P3. Use in SwiftUI
    /// previews and unit tests that don't need full content.
    public static let stubForPreview: LessonManifest = LessonManifest(
        version: 0,
        generatedAt: "preview",
        pillars: PillarId.all.map { pid in
            PillarSpec(id: pid, name: pid.debugName, thesis: "", techniques: [], evidenceAnchors: [], forbiddenRegister: [])
        },
        acts: (1...4).map { n in
            ActSpec(number: n, name: ["deconstruct","build","rewire","maintain"][n-1],
                    weeks: "preview", thesis: "", openingDay: (n-1)*21+1, closingDay: n*21,
                    expectedCognitiveShift: "")
        },
        canonical84: [
            LessonSlot(
                id: "D01_preview",
                canonicalDay: 1,
                act: 1,
                workingTitle: "the diet brain is [learned], not you",
                pillarIds: [.P1],
                primaryPillar: .P1,
                cbtTechniques: ["psychoeducation"],
                evidenceAnchor: "beck, cognitive behavior therapy for weight loss (2007)",
                priorityWithinAct: 1,
                keepIn60: true,
                keepIn75: true,
                extendFor102: false,
                isActClosing: false,
                isMilestone: true,
                isDataAware: false,
                isVoiceNoteEligible: true,
                isBreathRitual: false,
                isJournalPrompt: false,
                cohortOverrides: [:],
                pages: [
                    CBTLessonPage(page: 1, kind: "hook", eyebrow: "day one",
                               headline: "the voice in your head was [taught].",
                               italicWords: ["taught"],
                               body: "preview body. " + String(repeating: "lorem ipsum dolor sit amet. ", count: 4),
                               citation: nil, breathLine: nil, dataTie: nil, prompt: nil,
                               ctaLabel: "continue"),
                ],
                cohortVariants: []
            )
        ],
        extension18: [],
        voicePlaybook: nil
    )

    public enum ManifestError: Error, CustomStringConvertible {
        case bundleMissing
        case decodeFailed(Error)

        public var description: String {
            switch self {
            case .bundleMissing: return "manifest_v1.json missing from app bundle"
            case .decodeFailed(let e): return "manifest_v1.json decode failed: \(e)"
            }
        }
    }
}

// MARK: - AnyCodable
//
// Opaque codable wrapper so voicePlaybook can carry the writer-team's
// freely-shaped JSON without requiring schema edits each time they
// iterate. Decoding is best-effort: unknown subtrees decode to .null
// rather than throwing.

public struct AnyCodable: Codable, Sendable {
    public let value: Sendable?

    public init(_ value: Sendable?) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self.value = nil
        } else if let v = try? c.decode(Bool.self) {
            self.value = v
        } else if let v = try? c.decode(Int.self) {
            self.value = v
        } else if let v = try? c.decode(Double.self) {
            self.value = v
        } else if let v = try? c.decode(String.self) {
            self.value = v
        } else if let v = try? c.decode([AnyCodable].self) {
            self.value = v
        } else if let v = try? c.decode([String: AnyCodable].self) {
            self.value = v
        } else {
            self.value = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case nil:                       try c.encodeNil()
        case let v as Bool:             try c.encode(v)
        case let v as Int:              try c.encode(v)
        case let v as Double:           try c.encode(v)
        case let v as String:           try c.encode(v)
        case let v as [AnyCodable]:     try c.encode(v)
        case let v as [String: AnyCodable]: try c.encode(v)
        default:                        try c.encodeNil()
        }
    }
}
