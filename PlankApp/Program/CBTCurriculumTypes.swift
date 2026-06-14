import Foundation

// MARK: - Pillar
//
// The six CBT pillars the JeniMethod 84-day curriculum is built around.
// Each lesson tags 1-3 of these; the scheduler keeps coverage above the
// floor at every program length (60/75/84/102 + arbitrary N 30...150).
//
// Pillar identities are stable across manifest versions; pillar copy
// lives in manifest_v1.json so content writers can update names/thesis
// without an app submission.

public enum PillarId: String, Codable, CaseIterable, Sendable {
    case P1, P2, P3, P4, P5, P6

    public static var all: [PillarId] { allCases }

    /// Short human label used in analytics + DEBUG inspectors. UI
    /// reads the manifest's pillar.name (writers tune the wording).
    public var debugName: String {
        switch self {
        case .P1: return "cognitive restructuring + food noise"
        case .P2: return "hunger, satiety, urge surfing"
        case .P3: return "all-or-nothing + self-compassion"
        case .P4: return "body image + identity"
        case .P5: return "sleep, stress, emotional regulation"
        case .P6: return "maintenance + values"
        }
    }
}

// MARK: - CohortFlags
//
// Encoded clinical signals collected at onboarding v4.5. The scheduler
// reads these to (a) inject the day-zero primer for prior-attempts-high
// users, (b) swap cohort-variant content per slot, and (c) prioritize
// which lessons survive a compression to 60/75 days.
//
// EVERY field has a safe default — `default` constructor yields a
// "universal" cohort that gets the canonical 84-day arc with no
// variants. Sourced from existing AppStorage keys + UserRecord fields;
// see `fromAppStorage(_:)` for the bridge.

public struct CohortFlags: Codable, Equatable, Sendable {

    public enum GLP1Status: String, Codable, Sendable {
        case current, considering, none, triedOff
    }

    public enum FoodNoiseLoudness: String, Codable, Sendable {
        case quiet, moderate, loud
    }

    public enum StressLevel: String, Codable, Sendable {
        case low, moderate, high
    }

    public enum VoicePreference: String, Codable, Sendable {
        case encouraging, balanced, roast
    }

    public var glp1Status: GLP1Status
    public var perimenopausal: Bool
    public var pcos: Bool
    public var postpartumRecent: Bool
    public var lowBackPainRecent: Bool
    public var priorAttemptsCount: Int
    public var restrictiveFoodRelationship: Bool
    public var foodNoiseLoudness: FoodNoiseLoudness
    public var sleepUnder6h: Bool
    public var stressLevel: StressLevel
    public var voicePreference: VoicePreference

    /// 4+ prior attempts is the load-bearing threshold the curriculum
    /// research lane settled on for routing the day-zero primer.
    public var priorAttemptsHigh: Bool { priorAttemptsCount >= 4 }

    /// Diet-content voice override (locked: roast→balanced for any
    /// lesson surface — the brand voice does not roast users about
    /// food). Matches `JeniMethodContent.voiceForDietContent`.
    public var effectiveVoice: VoicePreference {
        voicePreference == .roast ? .balanced : voicePreference
    }

    public init(
        glp1Status: GLP1Status = .none,
        perimenopausal: Bool = false,
        pcos: Bool = false,
        postpartumRecent: Bool = false,
        lowBackPainRecent: Bool = false,
        priorAttemptsCount: Int = 0,
        restrictiveFoodRelationship: Bool = false,
        foodNoiseLoudness: FoodNoiseLoudness = .moderate,
        sleepUnder6h: Bool = false,
        stressLevel: StressLevel = .moderate,
        voicePreference: VoicePreference = .encouraging
    ) {
        self.glp1Status = glp1Status
        self.perimenopausal = perimenopausal
        self.pcos = pcos
        self.postpartumRecent = postpartumRecent
        self.lowBackPainRecent = lowBackPainRecent
        self.priorAttemptsCount = priorAttemptsCount
        self.restrictiveFoodRelationship = restrictiveFoodRelationship
        self.foodNoiseLoudness = foodNoiseLoudness
        self.sleepUnder6h = sleepUnder6h
        self.stressLevel = stressLevel
        self.voicePreference = voicePreference
    }

    /// Universal "no overrides" cohort. Returns canonical 84 with zero
    /// cohort variant swaps applied.
    public static let universal = CohortFlags()

    /// Build from the live `@AppStorage` mirrors. Bridge layer keeps the
    /// scheduler decoupled from SwiftUI / SwiftData. Missing keys fall
    /// to the universal defaults.
    public static func fromAppStorage(_ d: UserDefaults = .standard) -> CohortFlags {
        let glp1Raw = (d.string(forKey: "onb_glp1_status")
                      ?? d.string(forKey: "glp1Status")
                      ?? "none").lowercased()
        let glp1: GLP1Status = {
            switch glp1Raw {
            case "current", "yes": return .current
            case "considering": return .considering
            case "triedoff", "tried_off", "tried-off": return .triedOff
            default: return .none
            }
        }()

        let noiseRaw = (d.string(forKey: "onb_food_noise") ?? "moderate").lowercased()
        let noise: FoodNoiseLoudness = {
            switch noiseRaw {
            case "quiet", "low": return .quiet
            case "loud", "high": return .loud
            default: return .moderate
            }
        }()

        let stressRaw = (d.string(forKey: "onb_stress_level") ?? "moderate").lowercased()
        let stress: StressLevel = {
            switch stressRaw {
            case "low": return .low
            case "high": return .high
            default: return .moderate
            }
        }()

        let voiceRaw = (d.string(forKey: "voicePreference") ?? "encouraging").lowercased()
        let voice: VoicePreference = {
            switch voiceRaw {
            case "balanced": return .balanced
            case "roast": return .roast
            default: return .encouraging
            }
        }()

        let attempts = d.integer(forKey: "onb_prior_attempts_count")
        let perimeno = d.bool(forKey: "onb_perimenopausal")
        let pcos = d.bool(forKey: "onb_pcos")
        let pp = d.bool(forKey: "onb_postpartum_recent")
        let lbp = d.bool(forKey: "onb_lbp_recent")
        let restrictive = d.bool(forKey: "onb_restrictive_food")
        let lowSleep = d.bool(forKey: "onb_sleep_under_6h")

        return CohortFlags(
            glp1Status: glp1,
            perimenopausal: perimeno,
            pcos: pcos,
            postpartumRecent: pp,
            lowBackPainRecent: lbp,
            priorAttemptsCount: attempts,
            restrictiveFoodRelationship: restrictive,
            foodNoiseLoudness: noise,
            sleepUnder6h: lowSleep,
            stressLevel: stress,
            voicePreference: voice
        )
    }
}

// MARK: - LessonSlot
//
// One entry in the canonical 84-day manifest (plus the 18-day extension
// pool + the day-zero primer). The full 4-page body lives on `pages`;
// cohort variants live on `cohortVariants` and the scheduler picks one
// at most per slot per user. All metadata fields are load-bearing for
// the dynamic schedule algorithm (see CBTCurriculumScheduler).

public struct LessonSlot: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: String                 // e.g., "D14_self_compassion"
    public var canonicalDay: Int          // 1...84 (or 0 for primer / 85...102 for ext)
    public var act: Int                   // 1...4
    public var workingTitle: String       // includes [italic] markers
    public var pillarIds: [PillarId]
    public var primaryPillar: PillarId
    public var cbtTechniques: [String]
    public var evidenceAnchor: String
    public var priorityWithinAct: Int     // 1=anchor (never cut), 5=most-cuttable
    public var keepIn60: Bool
    public var keepIn75: Bool
    public var extendFor102: Bool
    public var isActClosing: Bool
    public var isMilestone: Bool
    public var isDataAware: Bool
    public var isVoiceNoteEligible: Bool
    public var isBreathRitual: Bool
    public var isJournalPrompt: Bool
    public var cohortOverrides: [String: String]   // cohort key → 1-sentence override note
    public var pages: [CBTLessonPage]
    public var cohortVariants: [CohortVariant]
    /// Round-2 redesign: primary visual treatment for this lesson.
    /// Defaults to `.typographyOnly` when absent from manifest (back-compat).
    public var primaryTreatment: VisualTreatment?
    /// Round-2 redesign: per-page treatment override map (page-int as
    /// string key for JSON compat). Wins over `primaryTreatment` when set.
    /// e.g. {"1": "collage_scatter", "4": "milestone_seal_close"}
    public var pageTreatmentOverrides: [String: VisualTreatment]?
    /// Round-2 redesign: asset slug for any image-bearing treatment.
    /// Resolves to a bundled imageset; nil for typographyOnly /
    /// gradientOrbSelection / pullQuoteSpread treatments.
    public var illustrationAsset: String?
    /// Round-4 native anchor field. Manifest writers populate this
    /// directly; the legacy `primaryTreatment` is retained for
    /// backward-compatible decode but the renderer prefers `anchor`
    /// when present via `resolvedAnchor`.
    public var anchor: AnchorEncoding?
    /// Round-4: per-page anchor overrides. Same encoding as `anchor`,
    /// keyed by page-int-as-string ("1", "2", "3", "4"). Wins over
    /// `anchor` when present.
    public var pageAnchorOverrides: [String: AnchorEncoding]?

    /// The variant that applies to this cohort, if any. Returns the first
    /// matching cohort by priority order: glp1 > postpartum > restrictive
    /// > perimenopause > prior_attempts_high > low_back_pain. Only one
    /// variant ever applies; never compose two.
    public func variant(for cohort: CohortFlags) -> CohortVariant? {
        let order: [(String, Bool)] = [
            ("glp1", cohort.glp1Status == .current || cohort.glp1Status == .triedOff),
            ("postpartum", cohort.postpartumRecent),
            ("restrictive", cohort.restrictiveFoodRelationship),
            ("perimenopause", cohort.perimenopausal),
            ("prior_attempts_high", cohort.priorAttemptsHigh),
            ("low_back_pain", cohort.lowBackPainRecent),
        ]
        for (key, active) in order where active {
            if let match = cohortVariants.first(where: { $0.cohort == key }) {
                return match
            }
        }
        return nil
    }
}

// MARK: - CBTLessonPage
//
// A single page of a CBT lesson. Pages 1-4 follow the structural arc:
// hook → story → concept+evidence → skill+optional prompt → close.
// All UI-facing copy lives in `headline` / `body`; italic punch words
// flow through `italicWords` for the InkRevealHeadline renderer.
//
// Named `CBTLessonPage` (not `LessonPage`) to avoid colliding with the
// legacy `LessonPage` struct in `JeniMethodRitual.swift` that drives
// the v1 14-day arc. Both coexist during the v2 transition; once the
// legacy arc retires the prefix can drop.

public struct CBTLessonPage: Codable, Equatable, Hashable, Sendable {
    public var page: Int
    public var kind: String                // "hook" | "story" | "concept" | "evidence" | "skill" | "prompt" | "close"
    public var eyebrow: String?
    public var headline: String
    public var italicWords: [String]
    public var body: String
    public var citation: String?
    public var breathLine: String?
    public var dataTie: String?
    public var prompt: String?
    public var ctaLabel: String
    /// Round-2 redesign: editor-marked pull-quote — when present, the
    /// reader promotes this substring to a 22pt italic-Fraunces pull
    /// inside the body. The text must already appear verbatim in
    /// `body` (renderer matches case-insensitively, whole-phrase).
    public var pullQuote: String?
    /// Round-2 redesign: gradient-orb selection prompt. Only used on
    /// pages where `kind == "skill"` AND the lesson's primary or
    /// override treatment is `.gradientOrbSelection`. The reader
    /// renders the orbs + the chosen orb-key persists to AppStorage
    /// scoped by (lessonSlotId, page).
    public var orbPrompt: OrbPrompt?

    enum CodingKeys: String, CodingKey {
        case page, kind, eyebrow, headline
        case italicWords = "italic_words"
        case body, citation
        case breathLine = "breath_line"
        case dataTie = "data_tie"
        case prompt
        case ctaLabel = "cta_label"
        case pullQuote = "pull_quote"
        case orbPrompt = "orb_prompt"
    }
}

// MARK: - AnchorEncoding (JSON-friendly LessonAnchor)
//
// Round-4: a Codable struct shape that the JSON manifest can store +
// the renderer maps to `LessonAnchor` at resolve time. Cleaner than
// a custom Codable on the enum + safer to decode (no error on
// unknown asset slug — falls back to typographyOnly).

public struct AnchorEncoding: Codable, Equatable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case typographyOnly = "typography_only"
        case singleHeroPhoto = "single_hero_photo"
        case singleArtifactPinned = "single_artifact_pinned"
        case twinAccentCorners = "twin_accent_corners"
        case scrapbookSpread = "scrapbook_spread"
        case layoutArchetype = "layout_archetype"
    }
    public var kind: Kind
    public var heroSlug: HeroPhotoSlug?
    public var artifactSlug: ArtifactSlug?
    public var leadingAccent: AccentSlug?
    public var trailingAccent: AccentSlug?
    public var bleed: BleedDirection?
    public var pin: CornerPin?
    public var diagonal: Diagonal?
    public var dingbat: Dingbat?
    /// Round-5: scrapbook recipe + asset fills.
    public var recipe: ScrapbookRecipe?
    public var heroFill: String?
    public var accent1Fill: String?
    public var accent2Fill: String?
    /// Per-slot overrides (rare — usually recipe defaults work).
    public var slotOverrides: [ScrapbookSlot]?
    /// Round-6: layout archetype + slots.
    public var archetype: LayoutArchetype?
    public var archetypeSlots: [LayoutSlot]?

    public init(kind: Kind,
                heroSlug: HeroPhotoSlug? = nil,
                artifactSlug: ArtifactSlug? = nil,
                leadingAccent: AccentSlug? = nil,
                trailingAccent: AccentSlug? = nil,
                bleed: BleedDirection? = nil,
                pin: CornerPin? = nil,
                diagonal: Diagonal? = nil,
                dingbat: Dingbat? = nil,
                recipe: ScrapbookRecipe? = nil,
                heroFill: String? = nil,
                accent1Fill: String? = nil,
                accent2Fill: String? = nil,
                slotOverrides: [ScrapbookSlot]? = nil) {
        self.kind = kind
        self.heroSlug = heroSlug
        self.artifactSlug = artifactSlug
        self.leadingAccent = leadingAccent
        self.trailingAccent = trailingAccent
        self.bleed = bleed
        self.pin = pin
        self.diagonal = diagonal
        self.dingbat = dingbat
        self.recipe = recipe
        self.heroFill = heroFill
        self.accent1Fill = accent1Fill
        self.accent2Fill = accent2Fill
        self.slotOverrides = slotOverrides
    }

    public var asAnchor: LessonAnchor {
        switch kind {
        case .typographyOnly:
            return .typographyOnly(dingbat: dingbat)
        case .singleHeroPhoto:
            return .singleHeroPhoto(
                slug: heroSlug ?? .onbItgirlPromise,
                bleed: bleed ?? .topBleedCentered
            )
        case .singleArtifactPinned:
            return .singleArtifactPinned(
                slug: artifactSlug ?? .onbFillerMatcha,
                pin: pin ?? .topRightPin
            )
        case .twinAccentCorners:
            return .twinAccentCorners(
                leading: leadingAccent ?? .accentSunglasses,
                trailing: trailingAccent ?? .accentPlateRibbon,
                diagonal: diagonal ?? .topLeftToBottomRight
            )
        case .scrapbookSpread:
            let r = recipe ?? .editorialBleed
            let slots = slotOverrides ?? r.defaultSlots(
                fillingHero: heroFill,
                fillingAccent1: accent1Fill,
                fillingAccent2: accent2Fill
            )
            return .scrapbookSpread(recipe: r, slots: slots)
        case .layoutArchetype:
            return .layoutArchetype(archetype ?? .pureTypography,
                                    slots: archetypeSlots ?? [])
        }
    }
}

// MARK: - LessonSlot.resolvedAnchor (round-4 dispatch)

public extension LessonSlot {
    /// Returns the per-page anchor: override > slot default > legacy
    /// `primaryTreatment` migration > typographyOnly fallback. Always
    /// safe to call; never throws.
    func resolvedAnchor(forPage page: Int) -> LessonAnchor {
        if let override = pageAnchorOverrides?[String(page)] {
            return override.asAnchor
        }
        // Slot-default applies only to page 1 by convention; subsequent
        // pages fall through to typographyOnly (with optional dingbat
        // on close pages of milestone days).
        if page == 1, let slotAnchor = anchor {
            return slotAnchor.asAnchor
        }
        // Close-page dingbat on milestone days.
        if page == 4 && isMilestone {
            return .typographyOnly(dingbat: DingbatLookup.dingbat(forCanonicalDay: canonicalDay))
        }
        // Legacy migration — only used while manifest still references
        // the round-2 `primaryTreatment` field.
        if page == 1, let legacy = primaryTreatment {
            switch legacy {
            case .heroPhotoBleed:
                return .singleHeroPhoto(slug: .onbItgirlPromise, bleed: .topBleedCentered)
            case .singleArtifact, .photoEdgeBleed:
                return .singleArtifactPinned(slug: .onbFillerMatcha, pin: .topRightPin)
            case .collageScatter, .milestoneSealClose:
                return .singleHeroPhoto(slug: .onbItgirlPromise, bleed: .topBleedCentered)
            case .gradientOrbSelection, .pullQuoteSpread, .typographyOnly:
                return .typographyOnly(dingbat: nil)
            }
        }
        return .typographyOnly(dingbat: nil)
    }
}

// MARK: - VisualTreatment
//
// Round-2 redesign register for a JeniMethod lesson page. Mapped on
// `LessonSlot.primaryTreatment` (per-lesson default) with optional
// `pageTreatmentOverrides` (per-page override). See expert synthesis
// (jenifit-cbt-redesign-round2 workflow 2026-06-13) for the
// distribution + rationale per case.

public enum VisualTreatment: String, Codable, CaseIterable, Sendable {
    /// Default. PaperCanvas + headline + body + folio. No illustration.
    /// ~55% of pages. The base register that ages well across 84 mornings.
    case typographyOnly = "typography_only"

    /// Full-bleed cropped real-photo cutout 55-70% of canvas. Face obscured
    /// (sunglasses / from-behind / cropped). Headline overlays negative space.
    /// Earned on milestone + emotional-peak hook pages only. ~12%.
    case heroPhotoBleed = "hero_photo_bleed"

    /// One photographed-real-object cutout (matcha, anthurium, journal, mirror,
    /// lemon, candle, stone) floating beside body text. Sepia-warmed monochrome.
    /// Skill pages where the object metaphorically anchors the practice. ~12%.
    case singleArtifact = "single_artifact"

    /// 6-9 cutout objects scrapbook-scattered around centered type. EARNED.
    /// Only days 21/42/63/84 P1 + day 1 P1 welcome moment. Honors scatter rule. ~8%.
    case collageScatter = "collage_scatter"

    /// 2-4 radial-gradient orbs as tappable inline reflection options.
    /// Selected orb blooms, one body sentence adapts to the pick. Persists local. ~6%.
    case gradientOrbSelection = "gradient_orb_selection"

    /// Photograph bleeds off one edge 25-35% of canvas. Atmosphere, not subject.
    /// Mood-anchoring lessons (sleep, stress, evening rituals). ~5%.
    case photoEdgeBleed = "photo_edge_bleed"

    /// Pull-quote spread: one body sentence promoted to italic-Fraunces 22pt
    /// bracketed by hairline cocoa rules. Editor-marked only, never automatic. ~6%.
    case pullQuoteSpread = "pull_quote_spread"

    /// Quiet wax-seal monogram + corner ornament on milestone close pages.
    /// P4 of days 21/42/63/84 only. Long-press fires share card. ~2%.
    case milestoneSealClose = "milestone_seal_close"
}

// MARK: - OrbPrompt
//
// One 2-4 way inline reflection choice, rendered as radial-gradient
// orbs (peach/cream/sage/cocoa palette). User picks one; choice
// persists locally; one body sentence on the page adapts to the pick.

public struct OrbPrompt: Codable, Equatable, Hashable, Sendable {
    public var question: String            // "today, the voice sounded most like..."
    public var choices: [OrbChoice]        // 2-4 items
}

public struct OrbChoice: Codable, Equatable, Hashable, Sendable {
    public var key: String                 // stable id stored in AppStorage
    public var label: String               // 1-3 lowercase words ("critic", "coach")
    public var hueHex: String              // gradient inner hex
    public var adaptedBodyLine: String?    // optional body-line swap on pick
}

// MARK: - CohortVariant
//
// A complete alternate 4-page script that REPLACES the canonical pages
// when the user's cohort matches. We never blend or partial-replace —
// the writer pods deliver the variant as a whole so the voice stays
// consistent. The citation + technique never change vs the canonical;
// only the hook, story, and one body line.

public struct CohortVariant: Codable, Equatable, Hashable, Sendable {
    public var cohort: String              // matches the keys in LessonSlot.cohortOverrides
    public var pages: [CBTLessonPage]
}

// MARK: - ScheduledLesson
//
// The scheduler's output: one entry per program day. Drives the Today
// card, the lesson reader, analytics, and the once-per-day gate. Stable
// across cold starts as long as `(totalDays, cohort, manifestVersion)`
// is unchanged.

public struct ScheduledLesson: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var programDay: Int             // 1...totalDays
    public var lessonSlotId: String
    public var variantCohort: String?      // matches CohortVariant.cohort if applied
    public var primaryPillar: PillarId
    public var pillarIds: [PillarId]
    public var act: Int
    public var isMilestone: Bool
    public var isActClosing: Bool
    public var isDataAware: Bool
    public var isVoiceNoteEligible: Bool
    public var isBreathRitual: Bool
    public var isJournalPrompt: Bool
    public var manifestVersion: Int

    public init(
        id: UUID = UUID(),
        programDay: Int,
        lessonSlotId: String,
        variantCohort: String? = nil,
        primaryPillar: PillarId,
        pillarIds: [PillarId],
        act: Int,
        isMilestone: Bool,
        isActClosing: Bool,
        isDataAware: Bool,
        isVoiceNoteEligible: Bool,
        isBreathRitual: Bool,
        isJournalPrompt: Bool,
        manifestVersion: Int
    ) {
        self.id = id
        self.programDay = programDay
        self.lessonSlotId = lessonSlotId
        self.variantCohort = variantCohort
        self.primaryPillar = primaryPillar
        self.pillarIds = pillarIds
        self.act = act
        self.isMilestone = isMilestone
        self.isActClosing = isActClosing
        self.isDataAware = isDataAware
        self.isVoiceNoteEligible = isVoiceNoteEligible
        self.isBreathRitual = isBreathRitual
        self.isJournalPrompt = isJournalPrompt
        self.manifestVersion = manifestVersion
    }
}

// MARK: - Pillar (manifest-driven content)

public struct PillarSpec: Codable, Equatable, Sendable {
    public var id: PillarId
    public var name: String
    public var thesis: String
    public var techniques: [String]
    public var evidenceAnchors: [String]
    public var forbiddenRegister: [String]
}

// MARK: - Act (manifest-driven content)

public struct ActSpec: Codable, Equatable, Sendable {
    public var number: Int
    public var name: String
    public var weeks: String
    public var thesis: String
    public var openingDay: Int
    public var closingDay: Int
    public var expectedCognitiveShift: String
}
