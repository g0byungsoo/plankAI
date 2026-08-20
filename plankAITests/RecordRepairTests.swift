import XCTest
import SwiftData
import PlankSync
@testable import plankAI

// MARK: - RecordRepairTests
//
// docs/app_v25/34_THE_BORING_WEIGHT_LOSS_APP.md, turned into law.
//
// THE FINDING THIS FILE EXISTS FOR: Jeni was a write-only record in the
// past tense. Every write path in the product stamped today and refused
// to look back — food (`Date()` at persist), weight (today's row or a
// new one), side effects (today's dayKey), a dose correction (the open
// slot only). Deleting a plate was the single exception.
//
// The weigh-in was the sharpest case, because it is the one number the
// whole product is priced on. `WeightLogRecord` has stored a day and a
// number since v1; five engines read it and the freshest row outranks
// every stored weight — so it is the numerator of BOTH the calorie
// target and the protein floor. And **no screen had ever listed the
// rows.** Becoming drew a line. A line is a trend, not a record: you
// cannot read a date off it, and you cannot touch it.
//
// The consequence was not cosmetic. One mistyped weigh-in silently
// moved the two numbers the product charges for, and the only repair
// on offer was to weigh again on the same calendar day. Miss that
// window and it was permanent.
//
// Every test here is an invariant, not a pixel:
//
//   1. A weigh-in can be corrected in place, on any day, and the
//      correction is the SAME weigh-in — same id, same day.
//   2. Correcting the freshest one moves the daily targets, through the
//      existing single resolver — no second copy of the arithmetic.
//   3. Removing one falls back down the existing ladder and never to
//      zero and never to a fabricated number.
//   4. Nothing in the repair touches the plan: not the start weight,
//      not the start date, not the plan id.
//   5. The ledger reports and never grades.

@MainActor
final class RecordRepairTests: XCTestCase {

    private let d = UserDefaults.standard

    private static let ownedKeys = [
        "onboardingCurrentWeightKg", "onboardingGoalWeightKg",
        "onboardingHeightCm", "onboardingGender", "onboardingPickedTier",
        "onboarding_goal_direction", "program_mode", "safety_pace_cap",
        "safety_numeric_suppression", "onboarding_glp1_status",
        "onb_v4_movement_baseline", "activityLevel",
        "onb_v5_age_years", "ageRange", "onboardingAgeRange", "weightUnit",
    ]

    override func setUpWithError() throws {
        Self.ownedKeys.forEach { d.removeObject(forKey: $0) }
    }

    override func tearDownWithError() throws {
        Self.ownedKeys.forEach { d.removeObject(forKey: $0) }
    }

    /// The same regression persona the rest of this line of work uses:
    /// 5'3" · 124 lb · goal 110 lb · female · "walks here and there" ·
    /// 34 · steady. Its target is pinned at 1,282 by
    /// `CalorieGoldenMatrixTests`.
    private func seedPersona() {
        d.set(124 / 2.20462, forKey: "onboardingCurrentWeightKg")
        d.set(110 / 2.20462, forKey: "onboardingGoalWeightKg")
        d.set(160.02, forKey: "onboardingHeightCm")
        d.set("female", forKey: "onboardingGender")
        d.set(34, forKey: "onb_v5_age_years")
        d.set("walks", forKey: "onb_v4_movement_baseline")
        d.set("medium", forKey: "onboardingPickedTier")
        d.set("lose", forKey: "onboarding_goal_direction")
        d.set("lb", forKey: "weightUnit")
        d.set(-1.0, forKey: "safety_pace_cap")
    }

    private func freshContext(_ uid: String) -> ModelContext {
        let ctx = TestModelContainer.shared.mainContext
        wipe(uid, in: ctx)
        return ctx
    }

    private func wipe(_ uid: String, in ctx: ModelContext) {
        let owner = uid
        try? ctx.delete(model: WeightLogRecord.self,
                        where: #Predicate { $0.userId == owner })
        try? ctx.delete(model: ProgramPlanRecord.self,
                        where: #Predicate { $0.userId == owner })
    }

    @discardableResult
    private func log(
        _ kg: Double, daysAgo: Int, source: String = "manual",
        userId: String, in ctx: ModelContext
    ) -> WeightLogRecord {
        let at = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        let row = WeightLogRecord(
            userId: userId, weightKg: kg, loggedAt: at, source: source
        )
        ctx.insert(row)
        try? ctx.save()
        return row
    }

    // MARK: - 1 · THE ENGINE — the list, and what it refuses

    func testTheLedgerListsEveryWeighInNewestFirst() {
        let now = Date()
        let cal = Calendar.current
        let entries = [
            WeightLedger.Entry(id: "a", at: cal.date(byAdding: .day, value: -4, to: now)!,
                               kg: 56.7, source: "manual"),
            WeightLedger.Entry(id: "b", at: now, kg: 56.0, source: "manual"),
            WeightLedger.Entry(id: "c", at: cal.date(byAdding: .day, value: -2, to: now)!,
                               kg: 56.3, source: "manual"),
        ]
        let rows = WeightLedger.rows(entries, unit: .kg, now: now)
        XCTAssertEqual(rows.map(\.id), ["b", "c", "a"])
        XCTAssertEqual(rows[0].day, "today")
    }

    /// THE NUMBER ON SCREEN MUST BE THE DIFFERENCE OF THE TWO NUMBERS ON
    /// SCREEN. The change is computed from the DISPLAYED values, so a
    /// row can never argue with the rows above and below it.
    func testTheChangeIsTheDifferenceOfTheTwoNumbersOnScreen() {
        let now = Date()
        let cal = Calendar.current
        // 165.3 lb over 164.9 lb — the ledger must read 0.4 lb down, and
        // it must get there without touching kilograms.
        let entries = [
            WeightLedger.Entry(id: "new", at: now, kg: 164.9 / 2.20462, source: "manual"),
            WeightLedger.Entry(id: "old", at: cal.date(byAdding: .day, value: -1, to: now)!,
                               kg: 165.3 / 2.20462, source: "manual"),
        ]
        let rows = WeightLedger.rows(entries, unit: .lb, now: now)
        XCTAssertEqual(rows[0].value, "164.9 lb")
        XCTAssertEqual(rows[1].value, "165.3 lb")
        XCTAssertEqual(rows[0].change, "0.4 lb down")
        XCTAssertNil(rows[1].change, "the oldest row has nothing behind it")
    }

    /// A GAIN IS STATED AS FLATLY AS A LOSS. Same words, same shape, no
    /// adjective, no verdict — `WeightJourney`'s standing law, kept here
    /// by construction rather than by taste.
    func testAGainIsStatedInTheSameShapeAsALoss() {
        let down = WeightLedger.changeWord(from: 56.5, to: 56.0, unit: .kg)
        let up   = WeightLedger.changeWord(from: 56.0, to: 56.5, unit: .kg)
        XCTAssertEqual(down, "0.5 kg down")
        XCTAssertEqual(up, "0.5 kg up")
        XCTAssertEqual(down.count - 4, up.count - 2,
                       "the two readings differ by exactly the direction word")
    }

    func testAnUnchangedWeightSaysSameAndNeverZero() {
        XCTAssertEqual(WeightLedger.changeWord(from: 56.0, to: 56.0, unit: .kg), "same")
        // Below the display resolution is the same number on screen.
        XCTAssertEqual(WeightLedger.changeWord(from: 56.02, to: 56.0, unit: .kg), "same")
    }

    /// The ordinary case says nothing. A record does not need to
    /// announce that it is ordinary — only that it is NOT hers.
    func testProvenanceIsSilentWhenTheNumberIsHers() {
        XCTAssertNil(WeightLedger.provenanceWord(.hers))
        XCTAssertEqual(WeightLedger.provenanceWord(.health), "from health")
        XCTAssertEqual(WeightLedger.provenanceWord(.signUp), "at sign-up")
        XCTAssertEqual(WeightLedger.provenance(for: "manual"), .hers)
        XCTAssertEqual(WeightLedger.provenance(for: "healthkit"), .health)
        XCTAssertEqual(WeightLedger.provenance(for: "onboarding"), .signUp)
        XCTAssertEqual(WeightLedger.provenance(for: "something-new"), .hers,
                       "an unknown source is not narrated at all")
    }

    /// Two rows on one day are BOTH listed. Merging them would hide a
    /// row, and a row you cannot see is a row you cannot remove — which
    /// is the entire defect this surface was built to end.
    func testTwoRowsOnOneDayAreBothListed() {
        // A fixed midday `now`, so "eight hours earlier" is the same day
        // whatever hour the suite happens to run at.
        let cal = Calendar.current
        let now = cal.date(bySettingHour: 18, minute: 0, second: 0,
                           of: cal.startOfDay(for: Date()))!
        let entries = [
            WeightLedger.Entry(id: "morning", at: now.addingTimeInterval(-3600 * 8),
                               kg: 56.0, source: "manual"),
            WeightLedger.Entry(id: "health", at: now, kg: 57.4, source: "healthkit"),
        ]
        let rows = WeightLedger.rows(entries, unit: .kg, now: now)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].provenanceWord, "from health")
        XCTAssertNil(rows[1].provenanceWord)
        // A DAY WORD MUST IDENTIFY EXACTLY ONE ROW. Two rows both
        // reading "today" is a screen asking her to guess which one she
        // is about to correct, so a shared day states its time.
        XCTAssertEqual(rows[0].day, "today \u{00B7} 6:00pm")
        XCTAssertEqual(rows[1].day, "today \u{00B7} 10:00am")
        XCTAssertTrue(rows[0].voiceOver.hasPrefix("today \u{00B7} 6:00pm, 57.4 kg"),
                      "voiceOver must carry the disambiguating time too")
    }

    /// The time appears ONLY when it disambiguates. A single row on a
    /// day says "yesterday", not "yesterday · 8:02am" — extra ink that
    /// answers nothing is the thing this product removes.
    func testTheTimeAppearsOnlyWhenADayCarriesMoreThanOneRow() {
        let cal = Calendar.current
        let now = cal.date(bySettingHour: 18, minute: 0, second: 0,
                           of: cal.startOfDay(for: Date()))!
        let entries = [
            WeightLedger.Entry(id: "a", at: now, kg: 56.0, source: "manual"),
            WeightLedger.Entry(id: "b", at: cal.date(byAdding: .day, value: -1, to: now)!,
                               kg: 56.4, source: "manual"),
        ]
        let rows = WeightLedger.rows(entries, unit: .kg, now: now)
        XCTAssertEqual(rows.map(\.day), ["today", "yesterday"])
    }

    func testUnitsArePresentationOnly() {
        let now = Date()
        let entries = [
            WeightLedger.Entry(id: "a", at: now, kg: 56.245, source: "manual")
        ]
        XCTAssertEqual(WeightLedger.rows(entries, unit: .lb, now: now)[0].value, "124 lb")
        XCTAssertEqual(WeightLedger.rows(entries, unit: .kg, now: now)[0].value, "56.2 kg")
    }

    func testTheDayWordSaysTodayYesterdayThenTheDate() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = cal.date(from: DateComponents(year: 2026, month: 8, day: 14))!
        XCTAssertEqual(WeightLedger.dayWord(now, now: now, calendar: cal), "today")
        XCTAssertEqual(
            WeightLedger.dayWord(cal.date(byAdding: .day, value: -1, to: now)!,
                                 now: now, calendar: cal),
            "yesterday"
        )
        XCTAssertEqual(
            WeightLedger.dayWord(cal.date(byAdding: .day, value: -3, to: now)!,
                                 now: now, calendar: cal),
            "aug 11"
        )
        // Across a year the row states which year, or "aug 11" is a lie
        // about a weigh-in from last summer.
        XCTAssertEqual(
            WeightLedger.dayWord(cal.date(from: DateComponents(year: 2025, month: 8, day: 11))!,
                                 now: now, calendar: cal),
            "aug 11, 2025"
        )
    }

    /// The ledger has no vocabulary for judgement. `DoseLedger` is
    /// pinned the same way and for the same reason: the surface most
    /// likely to acquire a grade is the one that lists what she did.
    func testTheLedgerHasNoVocabularyForJudgement() {
        let banned = [
            "missed", "failed", "should", "streak", "goal met", "great",
            "good", "bad", "gain", "backslide", "slipped", "off track",
            "on track", "well done", "oops", "sorry", "again", "only",
            "just", "unfortunately", "keep it up",
        ]
        let now = Date()
        let cal = Calendar.current
        var entries: [WeightLedger.Entry] = []
        for (index, source) in ["manual", "healthkit", "onboarding", "unknown"].enumerated() {
            entries.append(WeightLedger.Entry(
                id: "e\(index)",
                at: cal.date(byAdding: .day, value: -index * 3, to: now)!,
                kg: 56.0 + Double(index) * 0.6, source: source
            ))
        }
        var text: [String] = []
        for unit in [WeightUnit.lb, .kg] {
            for row in WeightLedger.rows(entries, unit: unit, now: now) {
                text.append(contentsOf: [
                    row.day, row.value, row.change ?? "",
                    row.provenanceWord ?? "", row.voiceOver,
                    WeightLedger.removalNote(row.provenance, day: row.day),
                ])
            }
            text.append(WeightLedger.countLine(entries, now: now) ?? "")
        }
        let all = text.joined(separator: " ").lowercased()
        for word in banned {
            XCTAssertFalse(all.contains(word),
                           "the ledger must not contain the word \"\(word)\": \(all)")
        }
    }

    /// The one place the surface must NOT be silent: a Health row can
    /// come back, because `BodyMassImportService` re-walks thirty days
    /// on launch. Saying so is cheaper than a tombstone column and it is
    /// the truth.
    func testTheRemovalNoteTellsTheTruthAboutAHealthRow() {
        let note = WeightLedger.removalNote(.health, day: "aug 11")
        XCTAssertTrue(note.contains("apple health"))
        // Pass 51 — the note used to warn "a later sync can bring it
        // back", which stopped being true when §44's day tombstone
        // shipped and is doubly false under the instant tombstone.
        // Copy that under-promises the record's own guarantees is a
        // lie in the cautious direction, but still a lie.
        XCTAssertFalse(note.contains("bring it back"),
                       "the resurrection warning outlived the resurrection")
        XCTAssertTrue(note.contains("won't pull it back"),
                      "the note states the guarantee the tombstones actually make")
        // And it must NOT claim any of that about a number she typed.
        XCTAssertFalse(WeightLedger.removalNote(.hers, day: "aug 11").contains("apple health"))
    }

    /// A correction to a Health row becomes HERS. Not a relabel: the
    /// importer overwrites any row still marked `healthkit` within its
    /// window, so a typed correction that kept the source would be
    /// silently reverted by the next sync. Its own rule — "manual rows
    /// always win their day" — is the fix.
    func testCorrectingAHealthRowMakesItHers() {
        XCTAssertEqual(WeightLedger.sourceAfterCorrection("healthkit"), "manual")
        XCTAssertEqual(WeightLedger.sourceAfterCorrection("onboarding"), "manual")
    }

    func testTheCountLineStatesTheRecordsSizeAndNothingElse() {
        let now = Date()
        XCTAssertNil(WeightLedger.countLine([], now: now))
        let one = [WeightLedger.Entry(id: "a", at: now, kg: 56, source: "manual")]
        XCTAssertEqual(WeightLedger.countLine(one, now: now), "1 weigh-in this month")
    }

    // MARK: - 2 · THE WRITER — the repair itself

    func testCorrectingAPastWeighInMovesThatRowAndNothingElse() {
        let uid = "record-repair-past"
        let ctx = freshContext(uid)
        defer { wipe(uid, in: ctx) }
        seedPersona()

        let old = log(57.0, daysAgo: 6, userId: uid, in: ctx)
        let recent = log(56.245, daysAgo: 0, userId: uid, in: ctx)
        let oldId = old.id
        let oldDay = old.loggedAt

        XCTAssertTrue(
            WeightLogWriter.update(id: oldId, toKg: 56.9, userId: uid, in: ctx)
        )

        XCTAssertEqual(old.weightKg, 56.9, accuracy: 0.0001)
        XCTAssertEqual(old.id, oldId, "a correction must not mint a new weigh-in")
        XCTAssertEqual(old.loggedAt, oldDay, "a correction must not move the day")
        XCTAssertEqual(old.source, "manual")
        XCTAssertTrue(old.pendingUpsert, "the correction must be queued for the server")
        XCTAssertEqual(recent.weightKg, 56.245, accuracy: 0.0001,
                       "correcting one weigh-in touched another")
        XCTAssertEqual(WeightLogWriter.entries(userId: uid, in: ctx).count, 2,
                       "a correction must not add a row")
    }

    /// THE WHOLE POINT. The freshest weigh-in is the numerator of the
    /// calorie target and the protein floor, so a wrong one is a wrong
    /// plan — and until this build the only repair was to weigh again on
    /// the same calendar day.
    func testCorrectingTheFreshestWeighInMovesTheDailyTargets() {
        let uid = "record-repair-targets"
        let ctx = freshContext(uid)
        defer { wipe(uid, in: ctx) }
        seedPersona()

        // The fat finger: 156 lb typed as 165 lb, yesterday.
        let wrong = log(165 / 2.20462, daysAgo: 1, userId: uid, in: ctx)
        let before = TargetsService.current(userId: uid, in: ctx)
        XCTAssertNotNil(before.kcal)
        XCTAssertNotNil(before.proteinG)

        XCTAssertTrue(
            WeightLogWriter.update(id: wrong.id, toKg: 156 / 2.20462,
                                   userId: uid, in: ctx)
        )

        let after = TargetsService.current(userId: uid, in: ctx)
        XCTAssertNotNil(after.kcal)
        XCTAssertLessThan(after.kcal!, before.kcal!,
                          "a lighter body has a lower target; the correction did not reach the math")
        XCTAssertLessThan(after.proteinG!, before.proteinG!,
                          "the protein floor derives from the same weight and must move with it")
        // And it moved through the ONE resolver, not a second copy.
        XCTAssertEqual(
            TargetsService.resolvedWeightKg(userId: uid, plan: nil, in: ctx) ?? 0,
            156 / 2.20462, accuracy: 0.001
        )
    }

    func testRemovingTheFreshestWeighInFallsBackToThePreviousOne() {
        let uid = "record-repair-remove"
        let ctx = freshContext(uid)
        defer { wipe(uid, in: ctx) }
        seedPersona()

        log(57.0, daysAgo: 5, userId: uid, in: ctx)
        let bogus = log(80.0, daysAgo: 0, userId: uid, in: ctx)
        XCTAssertEqual(TargetsService.resolvedWeightKg(userId: uid, plan: nil, in: ctx) ?? 0,
                       80.0, accuracy: 0.001)

        XCTAssertTrue(WeightLogWriter.remove(id: bogus.id, userId: uid, in: ctx))

        XCTAssertEqual(WeightLogWriter.entries(userId: uid, in: ctx).count, 1)
        XCTAssertEqual(TargetsService.resolvedWeightKg(userId: uid, plan: nil, in: ctx) ?? 0,
                       57.0, accuracy: 0.001,
                       "removing the freshest row must fall to the one behind it")
    }

    /// Removing everything falls down the EXISTING ladder to her own
    /// onboarding number. Never zero, never a fabricated value — the
    /// `30` §3 law, exercised from a direction it had never been.
    func testRemovingEveryWeighInFallsBackToHerOwnOnboardingNumber() {
        let uid = "record-repair-empty"
        let ctx = freshContext(uid)
        defer { wipe(uid, in: ctx) }
        seedPersona()

        let only = log(80.0, daysAgo: 0, userId: uid, in: ctx)
        XCTAssertTrue(WeightLogWriter.remove(id: only.id, userId: uid, in: ctx))

        XCTAssertTrue(WeightLogWriter.entries(userId: uid, in: ctx).isEmpty)
        XCTAssertEqual(TargetsService.resolvedWeightKg(userId: uid, plan: nil, in: ctx) ?? 0,
                       124 / 2.20462, accuracy: 0.001)
        XCTAssertNotNil(TargetsService.current(userId: uid, in: ctx).kcal,
                        "she still has a number; the ladder did not collapse")
    }

    /// With no weigh-in AND no stored weight, the answer is silence and
    /// a named missing input — never zero and never a guess.
    func testWithNothingOnFileTheTargetIsSilentAndNamesTheMissingFact() {
        let uid = "record-repair-nothing"
        let ctx = freshContext(uid)
        defer { wipe(uid, in: ctx) }
        seedPersona()
        d.removeObject(forKey: "onboardingCurrentWeightKg")

        XCTAssertNil(TargetsService.resolvedWeightKg(userId: uid, plan: nil, in: ctx))
        XCTAssertNil(TargetsService.current(userId: uid, in: ctx).kcal)
        XCTAssertEqual(
            TargetsService.missingEnergyInput(
                plan: nil,
                latestWeightKg: nil,
                careProtocol: CareProtocolStore.current
            ),
            .weight
        )
    }

    /// The repair is a repair, not a re-enrolment. `31` §2's identity
    /// class, held from the new writer's direction.
    func testTheRepairNeverTouchesThePlan() {
        let uid = "record-repair-plan"
        let ctx = freshContext(uid)
        defer { wipe(uid, in: ctx) }
        seedPersona()

        let started = Calendar.current.date(byAdding: .day, value: -26, to: .now)!
        let plan = ProgramPlanRecord(
            userId: uid, startDate: started,
            goalDate: started.addingTimeInterval(119 * 86_400),
            totalDays: 119, currentWeightKg: 124 / 2.20462,
            goalWeightKg: 110 / 2.20462, intensityTier: "medium"
        )
        ctx.insert(plan)
        try? ctx.save()
        let planId = plan.id
        let planStart = plan.startDate
        let startWeight = plan.currentWeightKg

        let row = log(60.0, daysAgo: 2, userId: uid, in: ctx)
        WeightLogWriter.update(id: row.id, toKg: 56.0, userId: uid, in: ctx)
        WeightLogWriter.remove(id: row.id, userId: uid, in: ctx)

        XCTAssertEqual(plan.id, planId)
        XCTAssertEqual(plan.startDate, planStart)
        XCTAssertEqual(plan.currentWeightKg ?? 0, startWeight ?? 0, accuracy: 0.0001,
                       "the start weight is what every \"since you started\" line is measured from")
        XCTAssertEqual(plan.goalWeightKg ?? 0, 110 / 2.20462, accuracy: 0.0001)
        XCTAssertEqual(plan.totalDays, 119)
        XCTAssertEqual(
            (try? ctx.fetchCount(FetchDescriptor<ProgramPlanRecord>(
                predicate: #Predicate { $0.userId == uid }))) ?? 0,
            1, "the repair minted a plan"
        )
    }

    /// A weigh-in belongs to one account. The repair is scoped the same
    /// way every read in this codebase is — cross-account isolation is
    /// not a feature to be re-earned per writer.
    func testAWeighInCannotBeRepairedByAnotherAccount() {
        let uid = "record-repair-owner"
        let other = "record-repair-intruder"
        let ctx = freshContext(uid)
        wipe(other, in: ctx)
        defer { wipe(uid, in: ctx); wipe(other, in: ctx) }

        let row = log(56.0, daysAgo: 1, userId: uid, in: ctx)
        XCTAssertFalse(WeightLogWriter.update(id: row.id, toKg: 90, userId: other, in: ctx))
        XCTAssertFalse(WeightLogWriter.remove(id: row.id, userId: other, in: ctx))
        XCTAssertEqual(row.weightKg, 56.0, accuracy: 0.0001)
        XCTAssertEqual(WeightLogWriter.entries(userId: uid, in: ctx).count, 1)
    }

    /// An implausible number is refused at the door rather than stored
    /// and then defended by every reader downstream — the same posture
    /// `BodyFactsStore.setSex` takes with an unrecognised key.
    func testAnImplausibleCorrectionIsRefused() {
        let uid = "record-repair-bounds"
        let ctx = freshContext(uid)
        defer { wipe(uid, in: ctx) }

        let row = log(56.0, daysAgo: 0, userId: uid, in: ctx)
        XCTAssertFalse(WeightLogWriter.update(id: row.id, toKg: 0, userId: uid, in: ctx))
        XCTAssertFalse(WeightLogWriter.update(id: row.id, toKg: 900, userId: uid, in: ctx))
        XCTAssertEqual(row.weightKg, 56.0, accuracy: 0.0001)
    }

    func testRepairingSomethingThatIsNotOnFileChangesNothing() {
        let uid = "record-repair-absent"
        let ctx = freshContext(uid)
        defer { wipe(uid, in: ctx) }
        log(56.0, daysAgo: 0, userId: uid, in: ctx)
        XCTAssertFalse(WeightLogWriter.update(id: "no-such-row", toKg: 57, userId: uid, in: ctx))
        XCTAssertFalse(WeightLogWriter.remove(id: "no-such-row", userId: uid, in: ctx))
        XCTAssertEqual(WeightLogWriter.entries(userId: uid, in: ctx).count, 1)
    }

    /// The feed the surface renders from is the record itself, newest
    /// first, with the stored provenance intact — so the sheet cannot
    /// quietly show a different set of rows from the one the math reads.
    func testTheLedgerFeedIsTheRecord() {
        let uid = "record-repair-feed"
        let ctx = freshContext(uid)
        defer { wipe(uid, in: ctx) }

        log(57.2, daysAgo: 4, source: "onboarding", userId: uid, in: ctx)
        log(56.8, daysAgo: 2, source: "healthkit", userId: uid, in: ctx)
        log(56.4, daysAgo: 0, userId: uid, in: ctx)

        let entries = WeightLogWriter.entries(userId: uid, in: ctx)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries.map(\.source), ["manual", "healthkit", "onboarding"])
        let rows = WeightLedger.rows(entries, unit: .kg)
        XCTAssertEqual(rows[0].day, "today")
        XCTAssertEqual(rows[1].provenanceWord, "from health")
        XCTAssertEqual(rows[2].provenanceWord, "at sign-up")
    }

    // MARK: - 3 · THE COACH SEES THE SAME REPAIR DOOR
    //
    // `31` §7 built the screen that answers "why is my target this" and
    // "where do I change it". The coach could not see it or name it, so
    // the product had two front desks: the screen offered the repair and
    // the coach explained the number away.

    func testTheEnvelopeCarriesTheTargetsInputsAndWhereToChangeThem() {
        let uid = "record-repair-envelope"
        let ctx = freshContext(uid)
        defer { wipe(uid, in: ctx) }
        seedPersona()
        log(56.245, daysAgo: 0, userId: uid, in: ctx)

        let envelope = CoachContextAssembler.assemble(userId: uid, in: ctx)
        let targets = envelope["targets"] as? [String: Any]
        XCTAssertNotNil(targets?["kcal"])
        let inputs = targets?["inputs"] as? [String: Any]
        XCTAssertEqual(inputs?["height_cm"] as? Int, 160)
        XCTAssertEqual(inputs?["age"] as? Int, 34)
        XCTAssertNil(inputs?["age_is_approximate"],
                     "an exact age must not be marked approximate")
        XCTAssertNotNil(inputs?["sex_term"])
        XCTAssertNotNil(inputs?["activity"])
        XCTAssertNotNil(targets?["repair_note"])

        let doors = envelope["doors"] as? [String: Any]
        XCTAssertNotNil(doors?["your_numbers"])
        XCTAssertNotNil(doors?["goal_weight"])
        XCTAssertNotNil(doors?["food_record"])
        XCTAssertNotNil(doors?["weigh_ins"],
                        "the coach must know the weigh-in record exists on day one")
    }

    /// A restored account's age comes back as a BAND. The envelope has
    /// to say so, or the coach states "34" from a value that means
    /// "somewhere in 25-34" — the same fabrication class the screens
    /// were taught to refuse.
    func testTheEnvelopeMarksARestoredAgeApproximate() {
        let uid = "record-repair-band"
        let ctx = freshContext(uid)
        defer { wipe(uid, in: ctx) }
        seedPersona()
        d.removeObject(forKey: "onb_v5_age_years")
        d.set("25to34", forKey: "onboardingAgeRange")
        log(56.245, daysAgo: 0, userId: uid, in: ctx)

        let envelope = CoachContextAssembler.assemble(userId: uid, in: ctx)
        let inputs = (envelope["targets"] as? [String: Any])?["inputs"] as? [String: Any]
        XCTAssertEqual(inputs?["age_is_approximate"] as? Bool, true)
    }
}
