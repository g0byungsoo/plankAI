import XCTest
@testable import plankAI

// MARK: - MethodSpineTests (app v25 pass 54)
//
// THE JENI METHOD becomes the intelligence layer, and the spine gets
// the machine checks the brief demanded:
//
//   · the late-cycle gate reads the RHYTHM'S OWN band, not a
//     hardcoded week (pass 53 gave the product interval rhythms; the
//     Method kept assuming seven days)
//   · a frightening morning has THREE specific explanations before
//     the generic one — salt, then cycle, then the jump note — and
//     each refuses to fire without its facts
//   · a deliberately ended medication plan earns the one transition
//     note the catalog has named as unwritable since E8.1
//   · her own repeated pattern outranks the population sentence
//     (the N-of-1 layer: "the third time your record has shown this
//     pair"), and only when the record actually supports it
//   · the priority list is complete and PINNED — a trigger absent
//     from it silently never fires, and a reorder is a behavior
//     change, so both are now a failing test instead of a review note
//   · every external claim carries a tier and an attribution, even
//     when the claim lives in the mechanism line rather than the
//     evidence line — the pass-53 sweep graded the citation, not the
//     claim
//
// RED before GREEN against the honest-BEFORE state.

final class MethodSpineTests: XCTestCase {

    /// A medicated payer with a floor on file and nothing else
    /// remarkable — the quiet base every trigger probe perturbs.
    private func quietDay() -> MethodEngine.Input {
        var i = MethodEngine.Input()
        i.plateCountEver = 40
        i.proteinEatenTodayG = 70
        i.proteinFloorG = 90
        i.recentLoggedDayProteins = [95, 92, 98, 91, 94]
        i.metProteinFloorBeforeToday = true
        i.loggedDayOffsets = Set(0..<7)
        i.weekendDayOffsets = [2, 3]
        i.programDay = 30
        i.hourOfDay = 10
        i.trendIsEstablished = true
        i.weighInCount = 9
        i.emaDelta7dKg = -0.2
        i.daysOfWeightHistory = 40
        i.latestWeightKg = 74.0
        i.previousWeightKg = 74.1
        i.strengthSessionsLast7 = 2
        i.steps7dMean = 7_000
        i.steps28dMean = 7_200
        return i
    }

    // MARK: - the late-cycle gate reads the rhythm's own band

    /// A q10d user on day 5 or 6 is MID-cycle — the medicine is not
    /// low, the end is days away, and "day 6 of your dose week" is
    /// wrong twice in one sentence.
    func testAnIntervalRhythmIsNotToldTheHungryEndMidCycle() {
        var i = quietDay()
        i.doseCycleLength = 10
        for day in [4, 5, 6, 7] {
            i.doseCycleDay = day
            XCTAssertNotEqual(
                MethodEngine.note(i)?.note.trigger, .lateInDoseWeek,
                "day \(day) of 10 is mid-cycle; the engine's own band says steady"
            )
        }
    }

    /// Days 8-10 of a 10-day rhythm ARE the waning end (the engine's
    /// band law: edge = ceil(2·length/7) = 3), and until this pass the
    /// note stayed silent exactly when it was finally true.
    func testAnIntervalRhythmHearsTheWaningEndWhenItArrives() {
        var i = quietDay()
        i.doseCycleLength = 10
        for day in [8, 9, 10] {
            i.doseCycleDay = day
            let note = MethodEngine.note(i)
            XCTAssertEqual(
                note?.note.trigger, .lateInDoseWeek,
                "day \(day) of 10 is the waning end and the note owes her the shape of it"
            )
            XCTAssertFalse(
                note?.line.contains("dose week") ?? false,
                "a 10-day rhythm is not a week: \(note?.line ?? "")"
            )
        }
    }

    /// Control: the shipped weekly behavior is unchanged — days 6-7
    /// of 7 fire (band edge 2 → waning is day > 5), day 3 does not.
    func testAWeeklyRhythmKeepsItsLateWindow() {
        var i = quietDay()
        i.doseCycleLength = 7
        i.doseCycleDay = 6
        XCTAssertEqual(MethodEngine.note(i)?.note.trigger, .lateInDoseWeek)
        i.doseCycleDay = 3
        XCTAssertNotEqual(MethodEngine.note(i)?.note.trigger, .lateInDoseWeek)
    }

    // MARK: - the cycle explanation (salt, then cycle, then the jump)

    func testTheMensesBumpIsNamedAsWater() {
        var i = quietDay()
        i.cycleSeasonIsMenstrual = true
        i.latestWeightKg = 78.6
        i.previousWeightKg = 78.0
        i.lastWeighInDaysAgo = 0
        i.emaDelta7dKg = -0.1
        let note = MethodEngine.note(i)
        XCTAssertEqual(note?.note.trigger, .mensesOnsetScaleBump)
        XCTAssertTrue(
            note?.line.lowercased().contains("water") ?? false,
            "the whole job is naming the mechanism before the number reads as failure"
        )
    }

    /// An unreliable cycle signal produces silence, never a guess —
    /// CycleSignal's irregularity stand-downs arrive here as a false
    /// flag, and a false flag must mean NO cycle claim at all.
    func testTheMensesBumpNeedsHerOwnPlausibleCycle() {
        var i = quietDay()
        i.cycleSeasonIsMenstrual = false
        i.latestWeightKg = 78.6
        i.previousWeightKg = 78.0
        i.lastWeighInDaysAgo = 0
        i.emaDelta7dKg = -0.1
        XCTAssertNotEqual(
            MethodEngine.note(i)?.note.trigger, .mensesOnsetScaleBump
        )
    }

    /// Reassurance must never hide a real change: against a clearly
    /// rising trend the water explanation stands down.
    func testTheMensesBumpRefusesARisingTrend() {
        var i = quietDay()
        i.cycleSeasonIsMenstrual = true
        i.latestWeightKg = 78.6
        i.previousWeightKg = 78.0
        i.lastWeighInDaysAgo = 0
        i.emaDelta7dKg = 0.4
        XCTAssertNotEqual(
            MethodEngine.note(i)?.note.trigger, .mensesOnsetScaleBump
        )
    }

    /// When yesterday's salt AND the cycle both explain the morning,
    /// the salty note wins: yesterday's dinner is the more specific
    /// fact, and the priority list is where that ruling lives.
    func testSaltOutranksCycleWhenBothExplainTheMorning() {
        var i = quietDay()
        i.cycleSeasonIsMenstrual = true
        i.yesterdaySodiumMg = 3_400
        i.latestWeightKg = 78.6
        i.previousWeightKg = 78.0
        i.lastWeighInDaysAgo = 0
        i.emaDelta7dKg = -0.1
        XCTAssertEqual(
            MethodEngine.note(i)?.note.trigger, .saltyDinnerScaleBump
        )
    }

    // MARK: - the ended plan

    func testAnEndedPlanEarnsTheTransitionNote() {
        var i = quietDay()
        i.selfMedicationEndedDaysAgo = 3
        let note = MethodEngine.note(i)
        XCTAssertEqual(note?.note.trigger, .medicationRecentlyEnded)
        XCTAssertTrue(
            note?.note.because.contains("prescriber") ?? false,
            "the what-next belongs to her prescriber, in the note's own words"
        )
    }

    /// The engine only ever sees a value for a DELIBERATE end — the
    /// builder returns nil for pauses, era changes, care-team plans
    /// and any active successor. Absence means silence.
    func testNoEndingMeansNoTransitionNote() {
        var i = quietDay()
        i.selfMedicationEndedDaysAgo = nil
        XCTAssertNotEqual(
            MethodEngine.note(i)?.note.trigger, .medicationRecentlyEnded
        )
    }

    /// Weeks later the moment has passed; the note does not haunt.
    func testAnOldEndingStopsSpeaking() {
        var i = quietDay()
        i.selfMedicationEndedDaysAgo = 40
        XCTAssertNotEqual(
            MethodEngine.note(i)?.note.trigger, .medicationRecentlyEnded
        )
    }

    // MARK: - the N-of-1 layer

    /// Two prior pairings on file + today's makes three: the record
    /// itself owns the claim now, and the note says so in her words.
    func testTheThirdSaltyMorningSpeaksHerOwnPattern() {
        var i = quietDay()
        i.yesterdaySodiumMg = 3_400
        i.latestWeightKg = 78.6
        i.previousWeightKg = 78.0
        i.lastWeighInDaysAgo = 0
        i.emaDelta7dKg = -0.1
        i.saltyBumpPriorInstances = 2
        let note = MethodEngine.note(i)
        XCTAssertEqual(note?.note.trigger, .saltyDinnerScaleBump)
        XCTAssertTrue(
            note?.line.contains("third") ?? false,
            "at the third pairing the pattern is HERS to hear: \(note?.line ?? "")"
        )
    }

    /// Below the floor the pattern claim would be two coincidences
    /// wearing a trend costume — the population mechanism speaks
    /// instead.
    func testTheFirstSaltyMorningSpeaksThePopulationMechanism() {
        var i = quietDay()
        i.yesterdaySodiumMg = 3_400
        i.latestWeightKg = 78.6
        i.previousWeightKg = 78.0
        i.lastWeighInDaysAgo = 0
        i.emaDelta7dKg = -0.1
        i.saltyBumpPriorInstances = 1
        let note = MethodEngine.note(i)
        XCTAssertEqual(note?.note.trigger, .saltyDinnerScaleBump)
        XCTAssertFalse(note?.line.contains("time your record") ?? true)
    }

    /// The instance counter itself: pairings need a salty day, a
    /// next-morning sample, the engine's own bump threshold, and the
    /// bump morning strictly before today.
    func testSaltyBumpInstancesCountOnlyCompletedPriorPairings() {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: .now)
        func day(_ ago: Int) -> Date {
            cal.date(byAdding: .day, value: -ago, to: today)!
        }
        let sodium = [
            day(10): 3_000,   // pairing 1: bump next day
            day(6): 3_100,    // pairing 2: bump next day
            day(4): 3_200,    // salty but NO next-day sample
            day(2): 900,      // not salty
            day(1): 3_400,    // today's own pairing — NOT prior
        ]
        let weigh = [
            day(10): 78.0, day(9): 78.5,
            day(6): 77.8, day(5): 78.3,
            day(4): 77.9,
            day(1): 77.5, day(0): 78.1,
        ]
        XCTAssertEqual(
            MethodInputBuilder.saltyBumpPriorInstances(
                sodiumMgByDay: sodium, weighKgByDay: weigh,
                today: today, calendar: cal
            ),
            2,
            "two completed PRIOR pairings; the no-sample day and today's own bump must not count"
        )
    }

    /// The FILM caught this one, not a test: "up 0.6 kg" rendered at
    /// a lb user — the v5 law (the story speaks HER unit) never
    /// reached the Method's bump notes, and nothing had ever looked
    /// at the unit.
    func testTheBumpSpeaksHerUnit() {
        var i = quietDay()
        i.yesterdaySodiumMg = 3_400
        i.latestWeightKg = 78.6
        i.previousWeightKg = 78.0
        i.lastWeighInDaysAgo = 0
        i.emaDelta7dKg = -0.1
        i.weightUnitIsLb = true
        let lb = MethodEngine.note(i)
        XCTAssertTrue(lb?.line.contains("1.3 lb") ?? false, lb?.line ?? "nil")
        XCTAssertFalse(lb?.line.contains("kg") ?? true)

        i.weightUnitIsLb = false
        let kg = MethodEngine.note(i)
        XCTAssertTrue(kg?.line.contains("0.6 kg") ?? false, kg?.line ?? "nil")
    }

    // MARK: - the pattern window excludes today

    /// A half-logged morning is not an under-floor day. The pattern
    /// note fires on FINISHED days; today is still being written.
    func testTheProteinPatternWindowExcludesToday() {
        let series = MethodInputBuilder.proteinPatternDays(
            byOffset: [0: 20, 1: 40, 2: 45, 3: 50]
        )
        XCTAssertEqual(
            series, [40, 45, 50],
            "offset 0 is today mid-writing; counting it makes breakfast read as a failed day"
        )
    }

    // MARK: - the priority list is complete and pinned

    func testEveryTriggerSitsInThePriorityListExactlyOnce() {
        for trigger in MethodTrigger.allCases {
            XCTAssertEqual(
                MethodEngine.priority.filter { $0 == trigger }.count, 1,
                "\(trigger.rawValue) — a trigger absent from the priority list silently never fires"
            )
        }
        XCTAssertEqual(MethodEngine.priority.count, MethodTrigger.allCases.count)
    }

    func testThePriorityOrderIsPinned() {
        XCTAssertEqual(
            MethodEngine.priority, [
                .returnedAfterGap,
                // p55 — the routing note outranks the teaching.
                .dizzyOnAFluidLossDay,
                .fluidsOnAQueasyDay,
                .saltyDinnerScaleBump,
                .mensesOnsetScaleBump,
                .weightJumpedAgainstTrend,
                .medicationRecentlyEnded,
                .firstPlateOnFile,
                .proteinFloorMetFirstTime,
                .trendJustReadable,
                .firstWeekClosing,
                .constipationWithLowFiber,
                .lateInDoseWeek,
                .morningProteinGap,
                .proteinUnderFloorRepeatedly,
                .weekendRecordDisappears,
                .losingWithoutResistanceWork,
                .movementBelowOwnBaseline,
                .trendFlatWhileLogging,
                .enteringMaintenance,
            ],
            "reordering the priority list is a behavior change, not a refactor — re-pin it deliberately"
        )
    }

    // MARK: - the evidence spine grades the claim, not the citation line

    /// Pass 53's sweep checked that an evidence LINE carries a tier.
    /// These markers catch the external claims that live in the
    /// mechanism line with no attribution at all — the 7,700-calorie
    /// constant, the pharmacokinetic trough, the side-effect
    /// epidemiology. A note whose `because` reaches outside her own
    /// record must say who stands behind the claim.
    func testExternalClaimsInBecauseCarryEvidence() {
        let externalClaimMarkers = [
            "7,700", "most common", "the medicine runs", "the medicine is",
            "medication guides", "g/kg", "trials", "in the trial",
            "adaptation",
        ]
        for note in MethodCatalog.notes {
            let because = note.because.lowercased()
            guard externalClaimMarkers.contains(where: because.contains) else { continue }
            XCTAssertNotEqual(
                note.evidenceTier, .arithmetic,
                "\(note.id)'s mechanism makes an external claim with an arithmetic tier: \(because)"
            )
            XCTAssertNotNil(
                note.evidence,
                "\(note.id)'s mechanism makes an external claim with no attribution line"
            )
        }
    }

    // MARK: - suppression covers the evidence line too

    /// Evidence lines carry population numerals ("1.2 to 1.6 g/kg",
    /// "7,700 calories"). Under numeric suppression the note renders
    /// its words-only form — and the provenance row must go with it,
    /// or the suppressed cohort reads the numbers through the back
    /// door. Pinned, not RED: found while implementing the spine.
    func testSuppressionDropsTheEvidenceLine() {
        var i = MethodEngine.Input()
        i.recentQueasySymptomWord = "queasy"
        i.numericsSuppressed = true
        let suppressed = MethodEngine.note(i)
        XCTAssertNotNil(suppressed)
        XCTAssertNil(
            suppressed?.evidenceLine,
            "population numerals must not reach the suppressed cohort via the provenance row"
        )
        i.numericsSuppressed = false
        XCTAssertNotNil(
            MethodEngine.note(i)?.evidenceLine,
            "control: the attribution renders for everyone else"
        )
    }

    // MARK: - a rewrite cannot ship without touching the version

    /// FNV-1a over the note's user-facing words, stable across runs.
    private func contentFingerprint(_ note: MethodNote) -> String {
        let joined = [
            note.noticed, note.because, note.evidence ?? "-",
            note.suppressedForm ?? "-", note.action?.label ?? "-",
        ].joined(separator: "|")
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in joined.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 16)
    }

    /// The ledger stores the version a note was SHOWN at, so a later
    /// rewrite never re-dates what someone was actually told — a
    /// promise that was vacuous until now, because nothing forced the
    /// version to move when the words did (E9 and p53 both rewrote
    /// content on version 1). Now the words are fingerprinted: change
    /// them and this fails until `version` (and the catalog version)
    /// are bumped deliberately and the pin is refreshed.
    func testACopyRewriteMustBumpTheNoteVersion() {
        let pinned: [String: (version: Int, fingerprint: String)] = [
            "protein_per_meal_v1": (2, "aef598ad4f7b720a"),
            "scale_vs_trend_v1": (3, "aa06f20fd2e9d29b"),
            "flat_stretch_v1": (3, "bdba7a3d81d2bca5"),
            "no_catch_up_v1": (1, "71962bd5563b94a6"),
            "late_dose_week_v1": (2, "ca07ba93f85593d7"),
            "weekend_record_v1": (2, "c70a88cf9da8b663"),
            "movement_dropped_v1": (1, "1390e773b4ae6f28"),
            "first_plate_v1": (2, "1b6fd58960e2463e"),
            "trend_readable_v1": (1, "90cadd48cbb19b11"),
            "floor_met_v1": (2, "4e598c0f6718127"),
            "resistance_pairing_v1": (2, "2e11f6060f2a5107"),
            "first_week_v1": (2, "a28eb2c7df715b0b"),
            "maintenance_band_v1": (2, "33e070deb182778b"),
            "fluids_queasy_day_v1": (1, "ad1f3d138d5d9541"),
            // p55 — the routing note (label-tier volume-depletion pairing).
            "dizzy_fluid_loss_v1": (1, "fc9f760efc231039"),
            "constipation_fiber_v1": (2, "186e15984749bf1d"),
            "morning_protein_gap_v1": (1, "d0893b65ea690eeb"),
            "salty_dinner_pattern_v1": (1, "61df3f78900cf13c"),
            "salty_dinner_scale_v1": (2, "8feb0042edd9d13a"),
            "menses_scale_bump_v1": (1, "350e21877c25b212"),
            "medication_ended_v1": (2, "1ef639333ee4dd81"),
        ]
        for note in MethodCatalog.notes {
            guard let pin = pinned[note.id] else {
                XCTFail("""
                \(note.id) has no version pin. add:
                "\(note.id)": (\(note.version), "\(contentFingerprint(note))"),
                """)
                continue
            }
            XCTAssertEqual(
                note.version, pin.version,
                "\(note.id): version moved — refresh the pin deliberately"
            )
            XCTAssertEqual(
                contentFingerprint(note), pin.fingerprint,
                """
                \(note.id)'s words changed without a version bump. \
                bump `version` on the note AND `MethodCatalog.version`, \
                then re-pin: (\(note.version), "\(contentFingerprint(note))")
                """
            )
        }
    }

    /// Every note's tier, pinned by hand. A new note fails until its
    /// tier is chosen deliberately; a tier change is a review event.
    func testEveryNoteTierIsPinned() {
        let pinned: [String: MethodNote.EvidenceTier] = [
            "protein_per_meal_v1": .reasonablePractice,
            "scale_vs_trend_v1": .strong,
            "flat_stretch_v1": .strong,
            "no_catch_up_v1": .arithmetic,
            "late_dose_week_v1": .reasonablePractice,
            "weekend_record_v1": .strong,
            "movement_dropped_v1": .arithmetic,
            "first_plate_v1": .arithmetic,
            "trend_readable_v1": .arithmetic,
            "floor_met_v1": .strong,
            "resistance_pairing_v1": .reasonablePractice,
            "first_week_v1": .arithmetic,
            "maintenance_band_v1": .arithmetic,
            "fluids_queasy_day_v1": .reasonablePractice,
            // p55 — the claim is the label's own post-marketing warning.
            "dizzy_fluid_loss_v1": .strong,
            "constipation_fiber_v1": .strong,
            "morning_protein_gap_v1": .reasonablePractice,
            "salty_dinner_pattern_v1": .reasonablePractice,
            "salty_dinner_scale_v1": .reasonablePractice,
            "menses_scale_bump_v1": .strong,
            "medication_ended_v1": .strong,
        ]
        for note in MethodCatalog.notes {
            XCTAssertEqual(
                note.evidenceTier, pinned[note.id],
                "\(note.id): tier changed or was never pinned — grade it deliberately"
            )
        }
        for id in pinned.keys {
            XCTAssertTrue(
                MethodCatalog.notes.contains { $0.id == id },
                "\(id) is pinned but absent from the catalog"
            )
        }
    }
}
