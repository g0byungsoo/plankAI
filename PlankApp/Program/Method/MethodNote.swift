import Foundation

// MARK: - THE METHOD, rebuilt (v25 E8.1)
//
// ─── WHAT ITS JOB USED TO BE ────────────────────────────────────────
//
// An 84-lesson CBT curriculum about diet culture and body image, keyed
// to `canonicalDay`, delivered one lesson per program day for twelve
// weeks. Six pillars, four acts, Beck (2007) as the evidence anchor,
// `manifest_v1.json` at 400 KB.
//
// It was built for a different product: a women-focused CBT app whose
// user was expected to read daily for three months. Two things then
// happened. The product became a GLP-1-era weight-management system
// behind a hard paywall, and the record showed who actually arrives.
//
// ─── WHY A CURRICULUM CANNOT WORK HERE ──────────────────────────────
//
// Measured, not assumed:
//
//   · 82% of everyone who finishes onboarding has exactly ONE active
//     day. 28 of 2,237 have ever reached a second week (E3).
//   · The payer median is 2.0 active days (E5).
//   · 90 days of production: 464 people opened a lesson, and only
//     23.5% of them ever paid — it is auto-presented after purchase,
//     not chosen. 1.66 distinct days per user. 39 people have ever
//     completed one.
//
// A curriculum indexed by program day can therefore only ever deliver
// lessons one and two. Lessons 3 through 84 are not under-read; they
// are UNREACHABLE by construction, and no amount of content quality
// changes that. The whole 84-slot authoring debt — including the 22
// lessons that address the reader as female (E8 §6) — was work on a
// shelf nobody walks past.
//
// ─── WHAT ITS JOB IS NOW ────────────────────────────────────────────
//
//     Jeni notices something in her record, teaches the one thing that
//     makes the next decision better, offers one action she can take
//     today, and remembers what happened.
//
// This is a just-in-time adaptive intervention, and the choice is
// evidence-led rather than a hunch. Koh et al's 2025 scoping review of
// 35 JITAI weight-management studies (J Med Internet Res 27:e76625)
// found the support types used were prompts (33 studies) and feedback
// (24), with coping strategies in 7 — and EDUCATIONAL INFORMATION in
// 5. Education is the least-used component in the literature of the
// exact thing we are trying to do. The review also found greater
// engagement associated with better weight outcomes, and that 68.6% of
// these interventions were rule-based rather than machine-learned: the
// binding constraint is which moment you choose, not model capacity.
//
// The six design elements below are Nahum-Shani's, as summarised by
// that review, and this file implements them literally:
//
//   tailoring variables → MethodFacts, read from the SAME engines the
//                         surfaces render from
//   decision points    → the moments the app already composes
//   decision rules     → MethodEngine, pure and tested
//   intervention options → MethodNote
//   proximal outcome   → FollowUp, checked against her own record
//   distal outcome     → active days, weight trend
//
// The review's own framing of a good threshold is the taxonomy for
// `MethodNote.Kind`: a state of VULNERABILITY (a high-risk moment), a
// state of OPPORTUNITY (a moment worth using), or receptivity. To
// which this product adds the fourth option the literature keeps
// implicit and this cohort needs most: SILENCE.
//
// ─── WHAT DID NOT CHANGE ────────────────────────────────────────────
//
// `RepEngine` already held ten genuinely good interventions — "the
// scale is up two pounds overnight", "small appetite today, one plate
// maybe", "four days away, the app is open again". Every one of them
// is a state, described. They were keyed to `canonicalDay`, so the
// scale note fired on program day 19 whether or not the scale had
// moved. The Method already contained the interventions; it was firing
// them on a calendar instead of on her life. That is the defect, and
// the fix is a trigger layer, not new prose.

// MARK: - Authority

/// WHO IS TALKING. Reuses E1's authority ladder rather than inventing a
/// second one: `careTeam` outranks `jeni` exactly as `prescribed`
/// outranks `preferred` in `ProgramFactStore`.
///
/// A clinician's actual instruction must never be silently contradicted
/// by generic Jeni content — and a clinic connection must never produce
/// an EMPTY Method either. Both follow from one rule: clinic content
/// REPLACES the Jeni default for a trigger it covers, and Jeni's
/// default stands everywhere else.
enum MethodAuthority: Equatable, Sendable, Codable {
    /// Jeni's evidence-informed default content.
    case jeni
    /// Authored by the connected clinic. `attribution` is rendered
    /// verbatim and is never optional: content whose source a patient
    /// cannot name is content she cannot weigh.
    case careTeam(attribution: String)

    var isCareTeam: Bool {
        if case .careTeam = self { return true }
        return false
    }

    /// The label the surface renders. Authority is never communicated
    /// by colour alone — it is a word, always present.
    var label: String {
        switch self {
        case .jeni: return "from jeni"
        case .careTeam(let who): return "from \(who)"
        }
    }

    /// Higher wins for the same trigger.
    var rank: Int { isCareTeam ? 1 : 0 }
}

// MARK: - Trigger

/// WHY a note appears. A closed set, named after the OBSERVATION rather
/// than the topic — because the observation is what makes the teaching
/// land, and a topic is what makes a library.
///
/// Every case here must be derivable from data the product already
/// holds. A trigger that cannot fire is a promise, not a feature, so
/// none are declared speculatively.
enum MethodTrigger: String, Equatable, Sendable, Codable, CaseIterable {

    // ── states of vulnerability ──────────────────────────────────────

    /// Protein has been under her floor on most of her recent logged
    /// days. The single highest-value teaching in the product for this
    /// cohort, and invisible to her by construction: appetite falls
    /// sharply on these drugs, so there is no internal signal that she
    /// is short.
    case proteinUnderFloorRepeatedly

    /// The scale jumped since her last weigh-in while the trend did
    /// not. The most common reason people quit weighing.
    case weightJumpedAgainstTrend

    /// She is still logging, and the trend has been flat for weeks.
    case trendFlatWhileLogging

    /// She was away for days and has just come back.
    case returnedAfterGap

    /// Late in the dose week on a weekly injectable, where appetite
    /// returns before the next dose does.
    case lateInDoseWeek

    /// She logs on weekdays and stops at weekends.
    case weekendRecordDisappears

    /// Her own daily movement has dropped well below her own baseline.
    case movementBelowOwnBaseline

    /// v25 E9 — she has logged nausea or a loose stomach in the last
    /// couple of days. The two symptoms every GLP-1 label names as the
    /// route to volume depletion, and the moment fluids stop being
    /// generic wellness advice and become the label's own instruction.
    ///
    /// This is the note that replaced a NUMBER. Until E9 the consumer
    /// protocol offered "about 1,800 ml across the day" during titration
    /// — a post-bariatric-surgery figure applied to a cohort it was not
    /// written for, on a screen that could not know whether the reader
    /// restricts fluids for heart failure or kidney disease. The
    /// instruction survives; the volume does not.
    case fluidsOnAQueasyDay

    /// v25 E9 — constipation logged, and her own recent fiber is low.
    /// Two of her own signals, and the one GI complaint where the first
    /// line of management is a thing she can put on a plate.
    case constipationWithLowFiber

    /// p53 — the gap lives at breakfast: several recent logged days
    /// missed the floor AND carried almost no morning protein.
    case morningProteinGap

    /// p53 — a scale bump the morning after a high-sodium day, named
    /// for what it is (water), before it reads as failure.
    case saltyDinnerScaleBump

    /// p54 — a scale bump in the first days of flow, while the trend
    /// is not rising. The third specific explanation for a frightening
    /// morning (salt, then cycle, then the generic jump note), and the
    /// market's clearest unclaimed women-specific gap: every tracker
    /// reads cycle water as fat. Fires only from HER OWN recorded
    /// period starts, through `CycleSignal`'s irregularity stand-downs
    /// — an unreliable cycle signal produces silence, never a guess.
    case mensesOnsetScaleBump

    /// p54 — her self-managed medication plan was deliberately ended
    /// (endReason "ended", never "paused", never a care-team plan) and
    /// no successor exists. The highest-value teaching in the domain,
    /// unwritable until the regimen model exposed a deliberate end:
    /// the months after stopping are when appetite returns and the
    /// trial extensions saw weight begin to come back — and the floors
    /// and the record are the part she keeps.
    case medicationRecentlyEnded

    // ── states of opportunity ────────────────────────────────────────

    /// Her first plate is on file. The one moment the record can
    /// explain itself using something she just did.
    case firstPlateOnFile

    /// Enough weigh-ins that the line can finally be read.
    case trendJustReadable

    /// She hit her protein floor. Say why it mattered, once.
    case proteinFloorMetFirstTime

    /// Weight is coming off steadily and nothing in the record says she
    /// is doing anything against gravity.
    case losingWithoutResistanceWork

    // ── expectations ─────────────────────────────────────────────────

    /// The end of her first week, the point at which the difference
    /// between a diet and a method becomes answerable.
    case firstWeekClosing

    /// The loss has stopped being the job.
    case enteringMaintenance

    var kind: MethodNote.Kind {
        switch self {
        case .proteinUnderFloorRepeatedly, .weightJumpedAgainstTrend,
             .trendFlatWhileLogging, .returnedAfterGap, .lateInDoseWeek,
             .weekendRecordDisappears, .movementBelowOwnBaseline,
             .fluidsOnAQueasyDay, .constipationWithLowFiber,
             .morningProteinGap, .saltyDinnerScaleBump,
             .mensesOnsetScaleBump, .medicationRecentlyEnded:
            return .vulnerability
        case .firstPlateOnFile, .trendJustReadable,
             .proteinFloorMetFirstTime, .losingWithoutResistanceWork:
            return .opportunity
        case .firstWeekClosing, .enteringMaintenance:
            return .expectation
        }
    }
}

// MARK: - The note

/// ONE intervention. Data, not prose scattered through views: the type
/// is `Codable` so an externally-authored note — a clinician's — is the
/// same object arriving from somewhere else, and the surface, the
/// engine, the ledger and the chat tool need no second code path.
///
/// `noticed` is a TEMPLATE. Its `{tokens}` are filled from
/// `MethodFacts`, which comes from her record, so every number a note
/// says traces to a collected field. A note whose tokens cannot all be
/// filled is DROPPED rather than rendered with a hole — the provenance
/// rule, enforced by construction.
struct MethodNote: Equatable, Sendable, Codable {

    enum Kind: String, Equatable, Sendable, Codable {
        case vulnerability
        case opportunity
        case expectation
    }

    /// One achievable thing, behind a real door. Feedback that points at
    /// the next action beats feedback that points at the self (Kluger &
    /// DeNisi 1996 — a large minority of feedback interventions make
    /// performance worse, and the self-directed kind is that variety).
    struct Action: Equatable, Sendable, Codable {
        let label: String
        /// A route into something that already exists. Encoded as a
        /// token so the note stays Codable and a clinician can never
        /// hand the app an arbitrary destination.
        let door: Door
        /// For `.askJeni` only: what the conversation should open on, in
        /// the third person, as every other chat seam in the product
        /// phrases it. Jeni still answers from her own read tools.
        var chatSeed: String? = nil

        init(label: String, door: Door, chatSeed: String? = nil) {
            self.label = label
            self.door = door
            self.chatSeed = chatSeed
        }

        enum Door: String, Equatable, Sendable, Codable, CaseIterable {
            case describePlate      // the words door (E7)
            case againSheet         // her own record, one tap (E4)
            case weightTrend
            case breath
            case move
            case doseSheet
            case askJeni
            /// No door: the note's action is a thing she does away from
            /// the phone. Still an action, still measurable through its
            /// follow-up.
            case none
        }
    }

    /// The PROXIMAL OUTCOME — what would have to appear in her record
    /// for this note to have worked. Pre-registered per note so the
    /// hypothesis is falsifiable before it ships, not narrated after.
    enum FollowUp: String, Equatable, Sendable, Codable {
        case plateLoggedToday
        case proteinFloorMetToday
        case weighedInWithinThreeDays
        case movementRecordedWithinTwoDays
        case openedAgainWithinThreeDays
        /// Deliberately none: some things are worth saying even though
        /// nothing observable follows. Saying so is more honest than
        /// attaching a metric that would be measured and believed.
        case none
    }

    /// p53 — THE EVIDENCE SPINE. Every external claim carries its
    /// tier; the sweep in tests enforces the pairing (a note whose
    /// `evidence` line cites a finding must be `.strong` or
    /// `.reasonablePractice`; an `.arithmetic` note may make NO
    /// external claim). "Weak" is deliberately NOT a case — an
    /// unshippable tier that cannot be typed cannot ship.
    enum EvidenceTier: String, Codable, Equatable {
        /// Systematic review / RCT / guideline-grade support.
        case strong = "s"
        /// Reasonable practice: label guidance, professional
        /// consensus — attributed, hedged, never outcome-promising.
        case reasonablePractice = "rp"
        /// Arithmetic on her own record; no external claim exists.
        case arithmetic = "a"
    }

    let id: String
    let trigger: MethodTrigger
    /// What Jeni saw, in her own numbers. Template — see `MethodFacts`.
    let noticed: String
    let noticedItalic: [String]
    /// The mechanism. ONE sentence. Why this is true, not that it is.
    let because: String
    /// Provenance a person can read. nil where the claim is arithmetic
    /// on her own record rather than a finding.
    let evidence: String?
    let action: Action?
    let followUp: FollowUp
    /// Bumped when the words change. The ledger keeps the version it
    /// showed, so a rewrite never rewrites history.
    let version: Int
    /// Never twice inside this many days.
    let cooldownDays: Int
    /// Words-only rendering under `numericsSuppressed` (the restrictive
    /// -risk cohort). A note with no numeral-free form is SUPPRESSED
    /// entirely rather than shown with its numbers stripped into
    /// nonsense.
    let suppressedForm: String?
    let authority: MethodAuthority
    /// Clinic content can be dated. An expired clinic note falls back
    /// to Jeni's default for the same trigger rather than leaving a
    /// hole. nil = does not expire.
    let expiresAt: Date?
    /// p53 — the claim's evidence grade (see `EvidenceTier`).
    let evidenceTier: EvidenceTier

    init(
        id: String,
        trigger: MethodTrigger,
        noticed: String,
        noticedItalic: [String] = [],
        because: String,
        evidence: String? = nil,
        action: Action? = nil,
        followUp: FollowUp = .none,
        version: Int = 1,
        cooldownDays: Int = 14,
        suppressedForm: String? = nil,
        authority: MethodAuthority = .jeni,
        expiresAt: Date? = nil,
        evidenceTier: EvidenceTier = .arithmetic
    ) {
        self.id = id
        self.trigger = trigger
        self.noticed = noticed
        self.noticedItalic = noticedItalic
        self.because = because
        self.evidence = evidence
        self.action = action
        self.followUp = followUp
        self.version = version
        self.cooldownDays = cooldownDays
        self.suppressedForm = suppressedForm
        self.authority = authority
        self.expiresAt = expiresAt
        self.evidenceTier = evidenceTier
    }

    var kind: Kind { trigger.kind }
}

// MARK: - Facts

/// The tailoring variables, resolved. Deliberately `[String: String]`
/// of already-formatted values rather than a wide typed struct: the
/// notes are content, the facts are what the content is allowed to say,
/// and a closed dictionary keeps the rendering pure and the failure
/// mode loud (a missing token drops the note).
typealias MethodFacts = [String: String]

extension MethodNote {

    /// Fill `{tokens}` from facts. Returns nil when ANY token is
    /// missing, so a note can never render "{n} g" at a person.
    static func render(_ template: String, facts: MethodFacts) -> String? {
        var out = ""
        var rest = Substring(template)
        while let open = rest.firstIndex(of: "{") {
            guard let close = rest[open...].firstIndex(of: "}") else { return nil }
            let key = String(rest[rest.index(after: open)..<close])
            guard let value = facts[key], !value.isEmpty else { return nil }
            out += rest[rest.startIndex..<open]
            out += value
            rest = rest[rest.index(after: close)...]
        }
        out += rest
        return out
    }

    /// Every token this template needs — used by the catalog test that
    /// proves each note's tokens are ones its trigger actually supplies.
    static func tokens(in template: String) -> [String] {
        var found: [String] = []
        var rest = Substring(template)
        while let open = rest.firstIndex(of: "{"),
              let close = rest[open...].firstIndex(of: "}") {
            found.append(String(rest[rest.index(after: open)..<close]))
            rest = rest[rest.index(after: close)...]
        }
        return found
    }
}

// MARK: - Resolved

/// A note with its numbers in it, ready to render. The only thing the
/// view ever sees.
struct ResolvedMethodNote: Equatable {
    let note: MethodNote
    /// `noticed`, rendered.
    let line: String
    let italic: [String]
    /// p54 — the evidence line, SUPPRESSION-AWARE. Under
    /// `numericsSuppressed` the engine renders the words-only form of
    /// the note, but the view used to read `note.evidence` directly —
    /// so "1.2 to 1.6 g/kg" and "25% to 39%" reached exactly the
    /// cohort the suppression law protects. The view renders THIS,
    /// which the engine leaves nil under suppression.
    var evidenceLine: String? = nil

    var id: String { note.id }
    var authorityLabel: String { note.authority.label }
}
