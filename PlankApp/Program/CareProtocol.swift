import Foundation

// MARK: - CareProtocol
//
// App v8 (docs/app_v8/03_ARCHITECTURE.md §3a) — the platform seam.
// Every clinical constant the engines previously carried as
// scattered `static let`s, gathered into ONE injectable, Codable,
// reviewable config. `.default` reproduces shipped behavior exactly
// (the equivalence is unit-tested), so this struct is the single
// artifact a medical director reviews and signs — and a clinic
// later becomes a protocol instance, not a fork.
//
// Laws:
//   - Engines take `careProtocol:` defaulting to `.default`; call
//     sites don't churn. No global mutable state — injection is by
//     parameter (S2 introduces the served resolver).
//   - Values here are THRESHOLDS AND POLICY, never prose. Voice
//     lives in BrandVoice (rules/voice split — 00_THESIS §4).
//   - Consumer-visible behavior under `.default` changes ONLY where
//     04_DECISIONS records a deliberate clinical fix (the GLP-1
//     small-body protein floor).
//
// Deliberately still static in S1 (config candidates, not yet
// injected): IntensityProfile tier tables, CalorieTargetCalculator
// population math (Mifflin-St Jeor + ACSM), archetype rotations.
// They are product/population definitions, not per-clinic clinical
// judgment; they join in S2 if a real configuration need appears.

struct CareProtocol: Codable, Equatable, Sendable {

    /// Stable identity for provenance ("which protocol composed
    /// this day") and the S2 served-row key.
    var id: String
    var version: Int

    // MARK: - Protein (TargetsService)

    struct ProteinPolicy: Codable, Equatable, Sendable {
        /// g/kg for the GLP-1-current cohort (4-society advisory
        /// band 1.2-2.0; we anchor 1.6 for lean-mass preservation).
        var perKgGLP1Current: Double
        /// g/kg default (general WL).
        var perKgDefault: Double
        /// Absolute floors (g). The GLP-1 floor may never push a
        /// small body above the advisory band — the formula caps it
        /// at perKg × kg (04_DECISIONS: the small-body honesty fix).
        var floorGLP1G: Double
        var floorDefaultG: Double
        /// Absolute caps (g).
        var capGLP1G: Double
        var capDefaultG: Double
        /// Rounding grain — the number reads as guidance, not
        /// false precision.
        var roundToG: Double
    }
    var protein: ProteinPolicy

    // MARK: - Pace (TargetsService.planImpliedRate)

    /// The sane-band clamp on any plan-implied loss rate. Never
    /// render a target built on a faster rate, even off corrupt
    /// plan data (ACSM ceiling).
    var maxPlanRatePctPerWeek: Double

    // MARK: - Day composition (CarePlanEngine)

    struct CompositionPolicy: Codable, Equatable, Sendable {
        /// Ringed moves under the lead (≤). Adherence law: the
        /// whole day stays ≤ 3 actionable asks (01_RESEARCH §B5).
        var maxSupportingMoves: Int
        /// Quiet invitations (≤). Never counted, never debt.
        var maxOfferedMoves: Int
        /// Gentle-tone triggers.
        var shortNightHours: Double
        var gentleReturnDays: Int
        /// Lead promotions (clinical priority ladder).
        var rapidLossRatePctPerWeek: Double
        var proteinDeficitPromoteG: Int
    }
    var composition: CompositionPolicy

    // MARK: - Cadences (PrescriptionEngineV2)

    struct CadencePolicy: Codable, Equatable, Sendable {
        /// Weigh-in rotation slots (0 = program-week Monday).
        var weighSlotsDefault: [Int]
        var weighSlotsGLP1Current: [Int]
        var weighSlotsRestrictiveRisk: [Int]
        var weighSlotsSoftened: [Int]
        var weighSlotsMaintenance: [Int]
        /// A weigh-in re-offers after this many silent days.
        var weighStaleFallbackDays: Int
    }
    var cadence: CadencePolicy

    // MARK: - Keeping bands (BandModel)

    struct BandPolicy: Codable, Equatable, Sendable {
        /// Zone thresholds over settle weight (kg) — STOP Regain
        /// lines (~3 lb watch / ~5 lb reset).
        var driftingAtKg: Double
        var resetAtKg: Double
        /// A kept maintenance week's floors.
        var keptMinWeighDays: Int
        var keptMinPresenceDays: Int
    }
    var band: BandPolicy

    // MARK: - Regimen (v8 — medication + supports composition)

    struct RegimenPolicy: Codable, Equatable, Sendable {
        /// The early-titration support window (weeks). GI events
        /// cluster at escalation and drive the first-4-week quits
        /// (01_RESEARCH §B1) — hydration + side-effect care ride
        /// this window.
        var titrationSupportWeeks: Int
        /// Offer the hydration row during the titration window.
        var hydrationDuringTitration: Bool
        /// The offered hydration mark's daily aim (ASMBS 2025 sets
        /// ≥1,800 cc/d during escalation).
        var hydrationMlDuringTitration: Int
        /// Dose day: the medication mark is the required top line
        /// (med + one keystone are the non-negotiables — §B8.1).
        var doseDayLeads: Bool
    }
    var regimen: RegimenPolicy

    // MARK: - Supports (founder refinement 2026-07-29, FR8)

    /// A clinician-authored adjunct (fiber note, "proactively
    /// consider vitamin D", magnesium titrated for regularity…).
    /// AUTHORED data, never app-originated claims (FTC: the same
    /// substantiation standard applies regardless of framing —
    /// attribution to the configuring care team is the shield AND
    /// the thesis). The patient render is at most ONE attributed
    /// observational line (S3) — never a pill-check row
    /// (MedISAFE-BP: reminder-marking moved self-report 0.4 pts,
    /// outcomes zero). Protein is deliberately NOT here: it is the
    /// one tracked support, and it lives in ProteinPolicy riding
    /// data the app already holds.
    struct SupportItem: Codable, Equatable, Sendable {
        var kind: String
        var note: String?
    }
    /// Empty for the consumer default — nothing renders until a
    /// care team authors it.
    var supports: [SupportItem]

    // MARK: - Tolerant decoding (S2 contract)
    //
    // Served payloads must survive ADDITIVE fields in either
    // direction: an older row missing a newer optional-by-meaning
    // field decodes with its default rather than failing whole.
    // `supports` is the first such field; future additions follow
    // the same decodeIfPresent pattern here.
    enum CodingKeys: String, CodingKey {
        case id, version, protein, maxPlanRatePctPerWeek,
             composition, cadence, band, regimen, supports
    }

    init(
        id: String, version: Int, protein: ProteinPolicy,
        maxPlanRatePctPerWeek: Double, composition: CompositionPolicy,
        cadence: CadencePolicy, band: BandPolicy,
        regimen: RegimenPolicy, supports: [SupportItem]
    ) {
        self.id = id
        self.version = version
        self.protein = protein
        self.maxPlanRatePctPerWeek = maxPlanRatePctPerWeek
        self.composition = composition
        self.cadence = cadence
        self.band = band
        self.regimen = regimen
        self.supports = supports
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        version = try c.decode(Int.self, forKey: .version)
        protein = try c.decode(ProteinPolicy.self, forKey: .protein)
        maxPlanRatePctPerWeek = try c.decode(Double.self, forKey: .maxPlanRatePctPerWeek)
        composition = try c.decode(CompositionPolicy.self, forKey: .composition)
        cadence = try c.decode(CadencePolicy.self, forKey: .cadence)
        band = try c.decode(BandPolicy.self, forKey: .band)
        regimen = try c.decode(RegimenPolicy.self, forKey: .regimen)
        supports = try c.decodeIfPresent([SupportItem].self, forKey: .supports) ?? []
    }

    // MARK: - The sanity gate (S2 — served payloads)

    /// A served protocol steers CLINICAL behavior, so it passes
    /// this gate whole or is rejected whole — never partially
    /// applied, never trusted blindly. Bounds are deliberately
    /// wide (a clinic tunes within them; corrupt or hostile data
    /// cannot leave them). The bundled `.default` is always sane.
    var isClinicallySane: Bool {
        let proteinSane =
            (0.8...2.5).contains(protein.perKgGLP1Current)
            && (0.8...2.5).contains(protein.perKgDefault)
            && (40...150).contains(protein.floorGLP1G)
            && (40...150).contains(protein.floorDefaultG)
            && (80...250).contains(protein.capGLP1G)
            && (80...250).contains(protein.capDefaultG)
            && protein.floorGLP1G <= protein.capGLP1G
            && protein.floorDefaultG <= protein.capDefaultG
            && (1...10).contains(protein.roundToG)
        let paceSane = (0.002...0.0125).contains(maxPlanRatePctPerWeek)
        let compositionSane =
            (0...4).contains(composition.maxSupportingMoves)
            && (0...4).contains(composition.maxOfferedMoves)
            && (4...8).contains(composition.shortNightHours)
            && (2...14).contains(composition.gentleReturnDays)
            && (0.005...0.02).contains(composition.rapidLossRatePctPerWeek)
            && (10...60).contains(composition.proteinDeficitPromoteG)
        let slotsSane = [
            cadence.weighSlotsDefault, cadence.weighSlotsGLP1Current,
            cadence.weighSlotsRestrictiveRisk, cadence.weighSlotsSoftened,
            cadence.weighSlotsMaintenance,
        ].allSatisfy { !$0.isEmpty && $0.allSatisfy((0...6).contains) }
            && (3...30).contains(cadence.weighStaleFallbackDays)
        let bandSane =
            (0.5...3.0).contains(band.driftingAtKg)
            && band.resetAtKg > band.driftingAtKg
            && band.resetAtKg <= 6.0
            && (0...7).contains(band.keptMinWeighDays)
            && (0...7).contains(band.keptMinPresenceDays)
        let regimenSane =
            (0...16).contains(regimen.titrationSupportWeeks)
            && (800...4_000).contains(regimen.hydrationMlDuringTitration)
        let supportsSane = supports.count <= 12
            && supports.allSatisfy { !$0.kind.isEmpty }
        return proteinSane && paceSane && compositionSane
            && slotsSane && bandSane && regimenSane && supportsSane
    }

    // MARK: - The shipped default (jeni, consumer, org-null tenant)

    static let `default` = CareProtocol(
        id: "jenifit.default",
        version: 1,
        protein: ProteinPolicy(
            perKgGLP1Current: 1.6,
            perKgDefault: 1.2,
            floorGLP1G: 90,
            floorDefaultG: 70,
            capGLP1G: 140,
            capDefaultG: 130,
            roundToG: 5
        ),
        maxPlanRatePctPerWeek: 0.01,
        composition: CompositionPolicy(
            maxSupportingMoves: 2,
            maxOfferedMoves: 2,
            shortNightHours: 6,
            gentleReturnDays: 4,
            rapidLossRatePctPerWeek: 0.01,
            proteinDeficitPromoteG: 25
        ),
        cadence: CadencePolicy(
            weighSlotsDefault: [0, 3],
            weighSlotsGLP1Current: [0],
            weighSlotsRestrictiveRisk: [0],
            weighSlotsSoftened: [0],
            weighSlotsMaintenance: [6],
            weighStaleFallbackDays: 7
        ),
        band: BandPolicy(
            driftingAtKg: 1.4,
            resetAtKg: 2.3,
            keptMinWeighDays: 1,
            keptMinPresenceDays: 3
        ),
        regimen: RegimenPolicy(
            titrationSupportWeeks: 8,
            hydrationDuringTitration: true,
            hydrationMlDuringTitration: 1_800,
            doseDayLeads: true
        ),
        supports: []
    )
}
