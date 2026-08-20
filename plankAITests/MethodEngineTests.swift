import XCTest
@testable import plankAI

// MARK: - MethodEngineTests (v25 E8.1)
//
// The Method's honesty laws, and the ones that replace an 84-lesson
// curriculum's completion metrics:
//
//   · silence is the default and there is NO fallback note
//   · every number a note says comes from her record, or the note drops
//   · a note never fires on a state that is not true
//   · a note never fires twice inside its cooldown
//   · care-team content outranks Jeni's, and a clinic that authors
//     nothing changes nothing
//   · suppression yields words or nothing, never stripped numbers

final class MethodEngineTests: XCTestCase {

    // MARK: - Helpers

    /// A payer with a floor on file and nothing remarkable happening.
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
        i.daysSinceLastOpen = 0
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
        i.flatWeeks = 0
        return i
    }

    // MARK: - THE LAW THAT MATTERS MOST

    /// The single decision that separates this from the thing it
    /// replaces. The old Method ALWAYS had a lesson for today, so it
    /// always spoke, so it became wallpaper. If a generic fallback ever
    /// reappears, this test is the thing that notices.
    func testAQuietDayProducesNothing() {
        XCTAssertNil(MethodEngine.note(quietDay()))
    }

    func testAnEmptyRecordProducesNothing() {
        // A brand-new user with nothing on file has nothing observable
        // about her, so there is nothing honest to notice.
        XCTAssertNil(MethodEngine.note(MethodEngine.Input()))
    }

    func testThereIsNoFallbackNoteInTheCatalog() {
        // Every note is bound to a trigger, and every trigger is a state.
        // A note with no trigger would be a lesson.
        for note in MethodCatalog.notes {
            XCTAssertTrue(
                MethodTrigger.allCases.contains(note.trigger),
                "\(note.id) is not bound to a real state"
            )
        }
    }

    // MARK: - Triggers fire only when true

    func testProteinNoteNeedsAPatternNotADay() {
        var i = quietDay()
        i.recentLoggedDayProteins = [40, 95, 98, 91, 94]   // one low day
        XCTAssertNil(MethodEngine.note(i))
        i.recentLoggedDayProteins = [40, 45, 50, 91, 94]   // three of five
        XCTAssertEqual(MethodEngine.note(i)?.note.trigger, .proteinUnderFloorRepeatedly)
    }

    func testProteinNoteNeverFiresWithoutAFloor() {
        var i = quietDay()
        i.proteinFloorG = nil
        i.recentLoggedDayProteins = [10, 12, 14, 11, 13]
        XCTAssertNil(MethodEngine.note(i))
    }

    /// The evening close already speaks to today's gap. Two prompts
    /// about the same thing, one of them counting grams, is the pile-on
    /// this cohort must not get.
    func testProteinNoteStaysOutOfTheEvening() {
        var i = quietDay()
        i.recentLoggedDayProteins = [40, 45, 50, 91, 94]
        i.hourOfDay = 20
        XCTAssertNil(MethodEngine.note(i))
    }

    func testProteinNoteYieldsToTheMedicationAdequacyNet() {
        var i = quietDay()
        i.recentLoggedDayProteins = [40, 45, 50, 91, 94]
        i.adequacyNetShowing = true
        XCTAssertNil(MethodEngine.note(i))
    }

    /// The scale note's whole claim is that the LINE disagrees with the
    /// dot. If the line is rising, the note would be false.
    func testScaleNoteRefusesToLieWhenTheTrendIsActuallyUp() {
        var i = quietDay()
        i.previousWeightKg = 73.0
        i.latestWeightKg = 74.2
        i.emaDelta7dKg = 0.4          // genuinely gaining
        XCTAssertNotEqual(MethodEngine.note(i)?.note.trigger, .weightJumpedAgainstTrend)
    }

    func testScaleNoteFiresOnAJumpAgainstAFallingLine() {
        var i = quietDay()
        i.previousWeightKg = 73.0
        i.latestWeightKg = 74.2
        i.emaDelta7dKg = -0.3
        let note = MethodEngine.note(i)
        XCTAssertEqual(note?.note.trigger, .weightJumpedAgainstTrend)
        XCTAssertTrue(note?.line.contains("1.2 kg") ?? false, note?.line ?? "nil")
        XCTAssertTrue(note?.line.contains("coming down") ?? false, note?.line ?? "nil")
    }

    func testScaleNoteNeedsAnEstablishedTrendToNameADirection() {
        var i = quietDay()
        i.trendIsEstablished = false
        i.previousWeightKg = 73.0
        i.latestWeightKg = 74.2
        i.emaDelta7dKg = -0.3
        XCTAssertNotEqual(MethodEngine.note(i)?.note.trigger, .weightJumpedAgainstTrend)
    }

    /// A flat line over an empty record is an unlogged fortnight, not a
    /// plateau. Calling it a plateau would teach her something false
    /// about her own body.
    func testPlateauNoteRefusesAnUnloggedFortnight() {
        var i = quietDay()
        i.flatWeeks = 4
        i.emaDelta7dKg = 0.0
        i.loggedDayOffsets = [0]        // one logged day in two weeks
        XCTAssertNotEqual(MethodEngine.note(i)?.note.trigger, .trendFlatWhileLogging)
        i.loggedDayOffsets = Set(0..<7) // still doing the work
        XCTAssertEqual(MethodEngine.note(i)?.note.trigger, .trendFlatWhileLogging)
    }

    /// The return note must never count the days out loud: feedback that
    /// points at the person is the variety that makes performance worse.
    func testReturnNoteNamesNoNumberOfDays() {
        var i = quietDay()
        i.daysSinceLastOpen = 9
        let note = MethodEngine.note(i)
        XCTAssertEqual(note?.note.trigger, .returnedAfterGap)
        XCTAssertFalse(note?.line.contains("9") ?? true, note?.line ?? "nil")
        for digit in "0123456789" {
            XCTAssertFalse(
                note?.line.contains(digit) ?? true,
                "the return note must carry no numeral: \(note?.line ?? "")"
            )
        }
    }

    func testLateDoseWeekNeverFiresForADailyRegimen() {
        // p54 re-pin: daily/as-needed/split rhythms arrive with NO
        // cycle pair by the engine's own law (`cyclePosition` returns
        // nil for them), so the invalid "day 6 of nothing" cannot be
        // constructed. A day without a length must never fire either.
        var i = quietDay()
        i.doseCycleDay = nil
        i.doseCycleLength = nil
        XCTAssertNotEqual(MethodEngine.note(i)?.note.trigger, .lateInDoseWeek)
        i.doseCycleDay = 6
        i.doseCycleLength = nil
        XCTAssertNotEqual(MethodEngine.note(i)?.note.trigger, .lateInDoseWeek)
        i.doseCycleLength = 7
        XCTAssertEqual(MethodEngine.note(i)?.note.trigger, .lateInDoseWeek)
    }

    func testWeekendNoteNeedsAWeekdayHabitToContrastWith() {
        var i = quietDay()
        i.weekendDayOffsets = [2, 3]
        i.loggedDayOffsets = [2, 3]        // only weekend days logged
        XCTAssertNotEqual(MethodEngine.note(i)?.note.trigger, .weekendRecordDisappears)
        i.loggedDayOffsets = [0, 1, 4, 5]  // weekdays only, weekend blank
        XCTAssertEqual(MethodEngine.note(i)?.note.trigger, .weekendRecordDisappears)
    }

    func testMovementNoteNeedsHerOwnBaselineNotAPopulationOne() {
        var i = quietDay()
        i.steps7dMean = 2_000
        i.steps28dMean = nil               // no baseline at all
        XCTAssertNotEqual(MethodEngine.note(i)?.note.trigger, .movementBelowOwnBaseline)
        i.steps28dMean = 8_000
        let note = MethodEngine.note(i)
        XCTAssertEqual(note?.note.trigger, .movementBelowOwnBaseline)
        XCTAssertTrue(note?.line.contains("25%") ?? false, note?.line ?? "nil")
    }

    func testResistanceNoteOnlyFiresWhileSheIsActuallyLosing() {
        var i = quietDay()
        i.strengthSessionsLast7 = 0
        i.emaDelta7dKg = -0.05             // barely moving
        XCTAssertNotEqual(MethodEngine.note(i)?.note.trigger, .losingWithoutResistanceWork)
        i.emaDelta7dKg = -0.6
        XCTAssertEqual(MethodEngine.note(i)?.note.trigger, .losingWithoutResistanceWork)
    }

    // MARK: - Once-ever moments

    func testFirstPlateFiresExactlyOnce() {
        var i = MethodEngine.Input()
        i.plateCountEver = 1
        XCTAssertEqual(MethodEngine.note(i)?.note.trigger, .firstPlateOnFile)
        i.plateCountEver = 2
        XCTAssertNil(MethodEngine.note(i))
    }

    func testCooldownSilencesARepeat() {
        var i = quietDay()
        i.recentLoggedDayProteins = [40, 45, 50, 91, 94]
        let first = MethodEngine.note(i)
        XCTAssertNotNil(first)
        i.shownDaysAgoById = [first!.note.id: 1]
        XCTAssertNil(MethodEngine.note(i), "a note inside its cooldown must stay quiet")
        i.shownDaysAgoById = [first!.note.id: 60]
        XCTAssertNotNil(MethodEngine.note(i))
    }

    // MARK: - Priority

    /// When several states are true, the one that is only true TODAY
    /// wins. The others will still be true tomorrow.
    func testTheMostTimeCriticalStateWins() {
        var i = quietDay()
        i.recentLoggedDayProteins = [40, 45, 50, 91, 94]  // pattern
        i.daysSinceLastOpen = 5                            // she just came back
        XCTAssertEqual(MethodEngine.note(i)?.note.trigger, .returnedAfterGap)
    }

    func testActiveTriggersReportsEverythingTrueForTheChatTool() {
        var i = quietDay()
        i.recentLoggedDayProteins = [40, 45, 50, 91, 94]
        i.daysSinceLastOpen = 5
        let active = MethodEngine.activeTriggers(i)
        XCTAssertTrue(active.contains(.returnedAfterGap))
        XCTAssertTrue(active.contains(.proteinUnderFloorRepeatedly))
        XCTAssertEqual(active.first, .returnedAfterGap, "priority order must hold")
    }

    // MARK: - Suppression

    func testSuppressionYieldsWordsOnlyNeverStrippedNumbers() {
        var i = quietDay()
        i.recentLoggedDayProteins = [40, 45, 50, 91, 94]
        i.numericsSuppressed = true
        let note = MethodEngine.note(i)
        XCTAssertNotNil(note)
        for digit in "0123456789" {
            XCTAssertFalse(
                note?.line.contains(digit) ?? true,
                "suppressed note leaked a numeral: \(note?.line ?? "")"
            )
        }
        XCTAssertTrue(note?.italic.isEmpty ?? false)
    }

    func testEveryNoteHasASuppressedForm() {
        // A note with no numeral-free form would be shown with its
        // numbers ripped out, which reads as broken. The engine drops
        // such a note; this makes sure none exist to drop.
        for note in MethodCatalog.notes {
            XCTAssertNotNil(note.suppressedForm, "\(note.id) has no suppressed form")
            for digit in "0123456789" {
                XCTAssertFalse(
                    note.suppressedForm?.contains(digit) ?? false,
                    "\(note.id) suppressed form carries a numeral"
                )
            }
        }
    }

    // MARK: - Rendering / provenance

    func testANoteWithAMissingFactIsDroppedNotRenderedWithAHole() {
        XCTAssertNil(MethodNote.render("{days} of {window}", facts: ["days": "3"]))
        XCTAssertEqual(
            MethodNote.render("{days} of {window}", facts: ["days": "3", "window": "5"]),
            "3 of 5"
        )
    }

    func testNoRenderedNoteEverContainsABrace() {
        var probes: [MethodEngine.Input] = []
        var i = quietDay(); i.recentLoggedDayProteins = [40, 45, 50]; probes.append(i)
        i = quietDay(); i.daysSinceLastOpen = 4; probes.append(i)
        i = quietDay(); i.previousWeightKg = 73.0; i.latestWeightKg = 74.4; probes.append(i)
        i = quietDay(); i.flatWeeks = 4; probes.append(i)
        i = quietDay(); i.doseCycleDay = 7; i.doseCycleLength = 7; probes.append(i)
        i = quietDay(); i.doseCycleDay = 9; i.doseCycleLength = 10; probes.append(i)
        i = quietDay(); i.steps7dMean = 1_500; i.steps28dMean = 8_000; probes.append(i)
        i = MethodEngine.Input(); i.plateCountEver = 1; probes.append(i)
        i = quietDay(); i.programDay = 7; probes.append(i)
        i = quietDay(); i.isMaintenancePhase = true; probes.append(i)
        i = quietDay(); i.strengthSessionsLast7 = 0; i.emaDelta7dKg = -0.7; probes.append(i)
        for probe in probes {
            guard let note = MethodEngine.note(probe) else { continue }
            XCTAssertFalse(note.line.contains("{"), note.line)
            XCTAssertFalse(note.line.contains("}"), note.line)
        }
    }

    /// Every token a note quotes must be one its OWN trigger supplies.
    /// Without this a content edit can silently make a note unrenderable
    /// forever, and the failure looks like "that note never fires".
    func testEveryNoteRendersUnderItsOwnTrigger() {
        var seen: Set<MethodTrigger> = []
        for note in MethodCatalog.notes {
            guard let input = probe(for: note.trigger) else {
                XCTFail("no probe for \(note.trigger.rawValue)"); continue
            }
            seen.insert(note.trigger)
            let resolved = MethodEngine.note(input)
            XCTAssertNotNil(
                resolved,
                "\(note.trigger.rawValue) has a note but no input can produce it"
            )
        }
        XCTAssertEqual(
            seen.count, MethodTrigger.allCases.count,
            "a trigger exists with no note, so a state would be detected and then ignored"
        )
    }

    /// One input per trigger that makes exactly that trigger the winner.
    private func probe(for trigger: MethodTrigger) -> MethodEngine.Input? {
        var i = quietDay()
        switch trigger {
        case .proteinUnderFloorRepeatedly:
            i.recentLoggedDayProteins = [40, 45, 50, 91, 94]
        case .weightJumpedAgainstTrend:
            i.previousWeightKg = 73.0; i.latestWeightKg = 74.4
        case .morningProteinGap:
            i.proteinFloorG = 85
            i.morningLowProteinDays = 4
            i.typicalDayGapG = 20
            i.hourOfDay = 9
        case .saltyDinnerScaleBump:
            i.yesterdaySodiumMg = 3400
            i.previousWeightKg = 78.0; i.latestWeightKg = 78.6
            i.lastWeighInDaysAgo = 0
        case .trendFlatWhileLogging:
            i.flatWeeks = 4
        case .returnedAfterGap:
            i.daysSinceLastOpen = 4
        case .lateInDoseWeek:
            i.doseCycleDay = 6; i.doseCycleLength = 7
        case .mensesOnsetScaleBump:
            i.cycleSeasonIsMenstrual = true
            i.previousWeightKg = 78.0; i.latestWeightKg = 78.6
            i.lastWeighInDaysAgo = 0
        case .medicationRecentlyEnded:
            i.selfMedicationEndedDaysAgo = 3
        case .weekendRecordDisappears:
            i.weekendDayOffsets = [2, 3]; i.loggedDayOffsets = [0, 1, 4, 5]
        case .movementBelowOwnBaseline:
            i.steps7dMean = 1_500; i.steps28dMean = 8_000
        case .firstPlateOnFile:
            i = MethodEngine.Input(); i.plateCountEver = 1
        case .trendJustReadable:
            i = MethodEngine.Input(); i.trendIsEstablished = true; i.weighInCount = 3
        case .proteinFloorMetFirstTime:
            i = MethodEngine.Input()
            i.plateCountEver = 5
            i.proteinFloorG = 90
            i.proteinEatenTodayG = 96
        case .losingWithoutResistanceWork:
            i.strengthSessionsLast7 = 0; i.emaDelta7dKg = -0.7
        case .firstWeekClosing:
            i.programDay = 7
        case .enteringMaintenance:
            i.isMaintenancePhase = true
        case .fluidsOnAQueasyDay:
            i.recentQueasySymptomWord = "queasy"
        case .dizzyOnAFluidLossDay:
            i.recentDizzyLogged = true
            i.recentQueasySymptomWord = "queasy"
        case .constipationWithLowFiber:
            i.loggedConstipationRecently = true
            i.recentFiberGPerDay = 11
        }
        return i
    }

    // MARK: - Authority (the B2B contract)

    private func clinicNote(
        trigger: MethodTrigger = .proteinUnderFloorRepeatedly,
        expiresAt: Date? = nil
    ) -> MethodNote {
        MethodNote(
            id: "clinic_x",
            trigger: trigger,
            noticed: "{days} of {window} days under {floor} g, per our plan.",
            because: "we set that together.",
            action: .init(label: "add protein", door: .describePlate),
            followUp: .proteinFloorMetToday,
            suppressedForm: "your protein has been light, per our plan.",
            authority: .careTeam(attribution: "dr. okafor"),
            expiresAt: expiresAt
        )
    }

    func testClinicContentOverridesJeniForTheSameTrigger() {
        var i = quietDay()
        i.recentLoggedDayProteins = [40, 45, 50, 91, 94]
        i.clinicNotes = [clinicNote()]
        let note = MethodEngine.note(i)
        XCTAssertEqual(note?.note.id, "clinic_x")
        XCTAssertTrue(note?.note.authority.isCareTeam ?? false)
        XCTAssertEqual(note?.authorityLabel, "from dr. okafor")
    }

    func testAClinicThatAuthorsNothingChangesNothing() {
        var i = quietDay()
        i.recentLoggedDayProteins = [40, 45, 50, 91, 94]
        i.clinicNotes = []
        XCTAssertEqual(MethodEngine.note(i)?.note.id, "protein_per_meal_v1")
    }

    func testClinicSuppressionLeavesSilenceNotASubstitute() {
        var i = quietDay()
        i.previousWeightKg = 73.0
        i.latestWeightKg = 74.4
        i.clinicSuppressedIds = ["scale_vs_trend_v1"]
        XCTAssertNotEqual(MethodEngine.note(i)?.note.trigger, .weightJumpedAgainstTrend)
    }

    /// An expired clinic note must fall back to Jeni's default, not
    /// leave a hole: an expired instruction is not an instruction to
    /// stay silent.
    func testAnExpiredClinicNoteFallsBackToTheJeniDefault() {
        var i = quietDay()
        i.recentLoggedDayProteins = [40, 45, 50, 91, 94]
        i.clinicNotes = [clinicNote(expiresAt: Date(timeIntervalSinceNow: -60))]
        XCTAssertEqual(MethodEngine.note(i)?.note.id, "protein_per_meal_v1")
    }

    func testUnattributedClinicContentIsRefusedAtTheDoor() {
        let bundle = MethodClinicSource.Bundle(
            version: 1, attribution: "  ",
            notes: [clinicNote()], suppressedNoteIds: [], expiresAt: nil
        )
        XCTAssertEqual(MethodClinicSource.resolve(bundle), .empty)
    }

    func testAnEndedConnectionRestoresEveryDefault() {
        // An expired bundle is the shape of a connection that ended.
        let bundle = MethodClinicSource.Bundle(
            version: 1, attribution: "dr. okafor",
            notes: [clinicNote()], suppressedNoteIds: ["scale_vs_trend_v1"],
            expiresAt: Date(timeIntervalSinceNow: -60)
        )
        let resolved = MethodClinicSource.resolve(bundle)
        XCTAssertEqual(resolved, .empty)
        var i = quietDay()
        i.recentLoggedDayProteins = [40, 45, 50, 91, 94]
        i.clinicNotes = resolved.notes
        i.clinicSuppressedIds = resolved.suppressedIds
        XCTAssertEqual(MethodEngine.note(i)?.note.id, "protein_per_meal_v1")
    }

    // MARK: - Content integrity

    func testNoteIdsAreUnique() {
        let ids = MethodCatalog.notes.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    /// The product's register, and the never-do list, as a test rather
    /// than a review note.
    func testEveryNoteObeysTheVoiceContract() {
        let banned = [
            "\u{2014}",        // em-dash between words
            "AI", "burn", "cheat", "bad food", "good food", "guilt",
            "should have", "failed", "ruined", "earn ",
        ]
        for note in MethodCatalog.notes {
            let all = [note.noticed, note.because, note.evidence ?? "",
                       note.action?.label ?? "", note.suppressedForm ?? ""]
            for text in all {
                XCTAssertEqual(text, text.lowercased(), "\(note.id): \(text)")
                for word in banned {
                    XCTAssertFalse(
                        text.contains(word),
                        "\(note.id) contains a banned token '\(word)': \(text)"
                    )
                }
            }
            XCTAssertFalse(note.because.isEmpty, "\(note.id) has no mechanism")
        }
    }

    /// The hygiene registry must know every trigger, or a new state
    /// ships analytics-dark — the exact defect E8 spent an era working
    /// around on the words door.
    func testHygieneVocabularyMatchesTheTriggerEnum() {
        XCTAssertEqual(
            AnalyticsHygiene.methodTriggerWords,
            Set(MethodTrigger.allCases.map(\.rawValue))
        )
    }

    func testHygieneDoorVocabularyMatchesTheDoorEnum() {
        XCTAssertEqual(
            AnalyticsHygiene.methodDoorWords,
            Set(MethodNote.Action.Door.allCases.map(\.rawValue))
        )
    }

    // MARK: - v25 E9 — the GI notes, and the number that left

    /// The trigger exists because the FDA labels for every drug in this
    /// cohort name nausea/vomiting/diarrhea as the route to volume
    /// depletion. It fires on HER logged symptom and nothing else.
    func testQueasyDayFiresOnHerOwnLoggedSymptom() {
        var i = quietDay()
        i.recentQueasySymptomWord = "queasy"
        let note = MethodEngine.note(i)
        XCTAssertEqual(note?.note.trigger, .fluidsOnAQueasyDay)
        XCTAssertTrue(note?.line.contains("queasy") == true,
                      "the note quotes the word she tapped")
    }

    func testNoSymptomNoFluidNote() {
        XCTAssertNil(MethodEngine.note(quietDay()))
    }

    /// THE POINT OF THE WHOLE CHANGE. Jeni may say "drink" and may not
    /// say "how much": no credible body prescribes a personal fluid
    /// volume, and fluid restriction is standard care in heart failure,
    /// advanced CKD and hyponatremia. If a millilitre or an ounce ever
    /// appears in this note's rendered text, this test fails.
    func testTheFluidNoteNeverPrescribesAVolume() {
        var i = quietDay()
        i.recentQueasySymptomWord = "queasy"
        guard let note = MethodEngine.note(i) else {
            return XCTFail("expected the fluid note")
        }
        let text = [note.line, note.note.because, note.note.evidence ?? "",
                    note.note.action?.label ?? "", note.note.suppressedForm ?? ""]
            .joined(separator: " ")
            .lowercased()
        for banned in ["ml", "millilit", " oz", "ounce", "litre", "liter",
                       "glasses", "cups", "1,800", "1800", "2,000", "2000"] {
            XCTAssertFalse(text.contains(banned),
                           "the fluid note must not carry a volume: found \(banned)")
        }
    }

    /// A body losing fluid outranks a teaching about last week's pattern.
    func testFluidsOutrankThePatternNotes() {
        var i = quietDay()
        i.recentLoggedDayProteins = [40, 45, 42, 50, 44]   // under-floor pattern
        i.recentQueasySymptomWord = "queasy"
        XCTAssertEqual(MethodEngine.note(i)?.note.trigger, .fluidsOnAQueasyDay)
    }

    /// Telling someone already eating 35 g of fiber to eat more fiber is
    /// how a note stops being believed. Her OWN number is half the rule.
    func testConstipationNoteNeedsHerOwnFiberToBeLow() {
        var i = quietDay()
        i.loggedConstipationRecently = true
        i.recentFiberGPerDay = 34
        XCTAssertNil(MethodEngine.note(i), "high fiber, nothing to add")

        i.recentFiberGPerDay = 11
        let note = MethodEngine.note(i)
        XCTAssertEqual(note?.note.trigger, .constipationWithLowFiber)
        XCTAssertTrue(note?.line.contains("11") == true, "it quotes her own figure")
    }

    /// Absent rather than zero: without enough logged days there is no
    /// mean, and a note that cannot fill its tokens must not render.
    func testConstipationNoteStaysSilentWithoutAFiberNumber() {
        var i = quietDay()
        i.loggedConstipationRecently = true
        i.recentFiberGPerDay = nil
        XCTAssertNil(MethodEngine.note(i))
    }

    func testTheConstipationNoteNeverPrescribesAVolumeEither() {
        var i = quietDay()
        i.loggedConstipationRecently = true
        i.recentFiberGPerDay = 11
        guard let note = MethodEngine.note(i) else {
            return XCTFail("expected the constipation note")
        }
        let text = [note.line, note.note.because, note.note.action?.label ?? ""]
            .joined(separator: " ").lowercased()
        for banned in ["ml", "millilit", " oz", "ounce", "glasses", "cups"] {
            XCTAssertFalse(text.contains(banned))
        }
    }
}
