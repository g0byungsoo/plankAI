import XCTest
import SwiftData
import PlankSync
import PlankFood
@testable import plankAI

// MARK: - OneRecordTests
//
// docs/app_v25/37_THE_ONE_RECORD.md, turned into law.
//
// THE INVARIANT THIS FILE EXISTS FOR:
//
//   If the customer told Jeni something once, every legitimate surface
//   either knows the same fact or explicitly says why it cannot.
//   If the fact belongs to her account, changing devices must not
//   silently change it. If the fact changes, every dependent number
//   changes with it.
//
// `29`–`36` proved the ARITHMETIC has one authority. This file proves
// the RECORD does: one weight ladder including the coach, one pace
// word, one day grammar across the three record lists, and one
// deletion contract.
//
// Every test here is a customer promise, not an implementation detail.

@MainActor
final class OneRecordTests: XCTestCase {

    private let d = UserDefaults.standard

    private static let ownedKeys = [
        "onboardingCurrentWeightKg", "onboardingGoalWeightKg",
        "onboardingHeightCm", "onboardingGender", "onboardingPickedTier",
        "onboarding_goal_direction", "program_mode", "safety_pace_cap",
        "safety_numeric_suppression", "onboarding_glp1_status",
        "onboardingHormonalStage", "onboardingSleepHours",
        "onboarding_weight_trend", "onboarding_glp1_phase",
        "onb_v4_movement_baseline", "activityLevel", "onboardingActivityLevel",
        "onb_v5_age_years", "ageRange", "onboardingAgeRange", "weightUnit",
        "onb_v5_gender", "onb_v5_height_cm",
    ]

    override func setUpWithError() throws {
        Self.ownedKeys.forEach { d.removeObject(forKey: $0) }
    }

    override func tearDownWithError() throws {
        Self.ownedKeys.forEach { d.removeObject(forKey: $0) }
    }

    /// The canonical ordinary persona this whole line of work is
    /// measured against: 5'3" · 124 lb · goal 110 lb · female · 34 ·
    /// "walks here and there" · steady · no GLP-1. Its target is pinned
    /// at 1,282 by `CalorieGoldenMatrixTests`.
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

    private var context: ModelContext { TestModelContainer.shared.mainContext }

    private func wipe(_ uid: String) {
        let owner = uid
        try? context.delete(model: WeightLogRecord.self,
                            where: #Predicate { $0.userId == owner })
        try? context.delete(model: ProgramPlanRecord.self,
                            where: #Predicate { $0.userId == owner })
        try? context.delete(model: JeniMemoryRecord.self,
                            where: #Predicate { $0.userId == owner })
        try? context.delete(model: ProgramFactRecord.self,
                            where: #Predicate { $0.userId == owner })
        try? context.delete(model: WeeklyReadRecord.self,
                            where: #Predicate { $0.userId == owner })
        try? context.delete(model: ObservationRecord.self,
                            where: #Predicate { $0.userId == owner })
        try? context.delete(model: DoseEventRecord.self,
                            where: #Predicate { $0.userId == owner })
        try? context.delete(model: RegimenPlanRecord.self,
                            where: #Predicate { $0.userId == owner })
        try? context.delete(model: ChatMessageRecord.self,
                            where: #Predicate { $0.userId == owner })
        try? context.delete(model: UserRecord.self,
                            where: #Predicate { $0.id == owner })
        try? context.save()
        FoodLogPersister.deleteAllEntries(userId: owner)
    }

    @discardableResult
    private func log(
        _ kg: Double, daysAgo: Int, source: String = "manual", userId: String
    ) -> WeightLogRecord {
        let at = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        let row = WeightLogRecord(
            userId: userId, weightKg: kg, loggedAt: at, source: source
        )
        context.insert(row)
        try? context.save()
        return row
    }

    @discardableResult
    private func seedPlan(userId: String, tier: String = "medium") -> ProgramPlanRecord {
        let startDate = Calendar.current.date(byAdding: .day, value: -20, to: .now)!
        let plan = ProgramPlanRecord(
            userId: userId, startDate: startDate,
            goalDate: startDate.addingTimeInterval(119 * 86_400),
            totalDays: 119,
            currentWeightKg: 124 / 2.20462, goalWeightKg: 110 / 2.20462,
            intensityTier: tier
        )
        plan.pendingUpsert = false
        context.insert(plan)
        try? context.save()
        return plan
    }

    // MARK: - 1 · ONE WEIGHT LADDER, AND THE COACH IS ON IT
    //
    // `35` fixed the coach's ladder for `missingEnergyInput` and left
    // the PUBLISHED weight on the raw weigh-in row. Every existing
    // envelope test seeds a weigh-in first, which is exactly why the
    // hole survived: the state that breaks is the ordinary one — a
    // woman who told the consult what she weighs and has not opened the
    // scale yet.

    func testTheCoachStatesTheWeightTheScreensState() {
        let uid = "one-record-weight-ladder"
        wipe(uid); defer { wipe(uid) }
        seedPersona()
        seedPlan(userId: uid)
        // NO weigh-in row on purpose. Her weight came from the consult.

        let resolved = TargetsService.resolvedWeightKg(
            userId: uid, plan: ProgramService.shared.activePlan(userId: uid, in: context),
            in: context
        )
        XCTAssertNotNil(resolved, "the screens hold her consult weight")

        let envelope = CoachContextAssembler.assemble(userId: uid, in: context)
        let weight = envelope["weight"] as? [String: Any]
        XCTAssertNotNil(weight, "the coach must have a weight block")
        XCTAssertEqual(
            weight?["current_kg"] as? Double,
            ((resolved ?? 0) * 10).rounded() / 10,
            "jeni must state the same current weight `your numbers` states"
        )
    }

    /// The sharper half of the same defect: the envelope published
    /// `to_go_kg` — a distance measured FROM her current weight —
    /// while refusing to state the weight it measured from. A payload
    /// cannot answer "how far am I" and "what do I weigh" differently.
    func testTheCoachNeverPublishesADistanceWithoutTheWeightItMeasuredFrom() {
        let uid = "one-record-distance"
        wipe(uid); defer { wipe(uid) }
        seedPersona()
        seedPlan(userId: uid)

        let envelope = CoachContextAssembler.assemble(userId: uid, in: context)
        let weight = envelope["weight"] as? [String: Any]
        if weight?["to_go_kg"] != nil {
            XCTAssertNotNil(
                weight?["current_kg"],
                "a distance is current − goal; publishing one without the other is two answers to one question"
            )
        }
    }

    /// The control. A logged weigh-in outranks the stored answer, and
    /// this passed before the fix — it is here so a future change that
    /// breaks the ordinary path fails loudly.
    func testAWeighInStillOutranksTheStoredAnswerForTheCoach() {
        let uid = "one-record-weighin-wins"
        wipe(uid); defer { wipe(uid) }
        seedPersona()
        seedPlan(userId: uid)
        log(54.0, daysAgo: 0, userId: uid)

        let envelope = CoachContextAssembler.assemble(userId: uid, in: context)
        let weight = envelope["weight"] as? [String: Any]
        XCTAssertEqual(weight?["current_kg"] as? Double, 54.0,
                       "the freshest weigh-in is the current weight, everywhere")
    }

    // MARK: - 2 · ONE PACE WORD, WITH ONE AUTHORITY
    //
    // The same three stored values (`soft`/`medium`/`hard`) were mapped
    // to words in THREE separate view files, and the coach was handed
    // the RAW value. So every screen said `steady` and jeni said
    // `medium` — one fact, two vocabularies, and the customer is the
    // one who has to reconcile them.

    func testThereIsOnePaceWordPerTier() {
        XCTAssertEqual(IntensityTier.soft.paceWord, "gentle")
        XCTAssertEqual(IntensityTier.medium.paceWord, "steady")
        XCTAssertEqual(IntensityTier.hard.paceWord, "strong")
    }

    /// The stored vocabulary is never a customer-facing word. If a
    /// future tier is added, this fails until it is given a word.
    func testNoStoredTierValueIsEverACustomerFacingWord() {
        for tier in IntensityTier.allCases {
            XCTAssertNotEqual(
                tier.paceWord, tier.rawValue,
                "`\(tier.rawValue)` is storage; the customer reads a word"
            )
        }
    }

    func testTheCoachIsToldThePaceWordTheScreensShow() {
        let uid = "one-record-pace-word"
        wipe(uid); defer { wipe(uid) }
        seedPersona()
        seedPlan(userId: uid, tier: "medium")
        log(56.245, daysAgo: 0, userId: uid)

        let envelope = CoachContextAssembler.assemble(userId: uid, in: context)
        let inputs = (envelope["targets"] as? [String: Any])?["inputs"] as? [String: Any]
        let pace = inputs?["pace"] as? String
        XCTAssertEqual(pace, "steady",
                       "jeni must name the pace in the words Home and `your numbers` use")
        XCTAssertNil(inputs?["pace_tier"],
                     "the raw storage value must not travel to the model as a word")
    }

    // MARK: - 3 · ONE DAY GRAMMAR ACROSS THE THREE RECORD LISTS
    //
    // `your weigh-ins`, `the doses` and `the symptoms` are three lists
    // of the same shape, and two of them sit in ONE frame (the regimen
    // home). A record that calls the same date `today` in one list and
    // `aug 14` in the list below it is asking the customer to learn the
    // codebase's history.

    private var zonedCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }

    private func dayKey(_ date: Date, _ calendar: Calendar) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = calendar.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    func testTheThreeRecordListsSpeakOneDayGrammar() {
        let cal = zonedCalendar
        let now = cal.date(from: DateComponents(year: 2026, month: 8, day: 14, hour: 10))!
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        let older = cal.date(byAdding: .day, value: -8, to: now)!

        for (date, expected) in [(now, "today"), (yesterday, "yesterday"), (older, "aug 6")] {
            let key = dayKey(date, cal)
            XCTAssertEqual(
                WeightLedger.dayWord(date, now: now, calendar: cal), expected,
                "your weigh-ins"
            )
            XCTAssertEqual(
                SymptomLedger.dayWord(key, now: now, calendar: cal), expected,
                "the symptoms"
            )
            XCTAssertEqual(
                DoseLedger.dayWord(key, now: now, calendar: cal), expected,
                "the doses — the same frame as the symptoms, so the same words"
            )
        }
    }

    /// `34` found this in `WeightLedger` and fixed it; `36` wrote it
    /// into `SymptomLedger` on the way in. `DoseLedger` was written
    /// first and never corrected: its PARSER sets the zone, its PRINTER
    /// does not, so a row the calendar placed on `aug 11` can print
    /// `aug 10` — the ledger disagreeing with itself about which day it
    /// is listing.
    func testTheDoseDayWordInheritsTheCalendarTimeZone() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Pacific/Kiritimati")!   // UTC+14
        let now = cal.date(from: DateComponents(year: 2026, month: 8, day: 14, hour: 9))!

        XCTAssertEqual(DoseLedger.dayWord("2026-08-11", now: now, calendar: cal), "aug 11")
        XCTAssertEqual(DoseLedger.dayWord("2026-08-13", now: now, calendar: cal), "yesterday")
        XCTAssertEqual(DoseLedger.dayWord("2026-08-14", now: now, calendar: cal), "today")
        // And the year rule survives the zone.
        XCTAssertEqual(
            DoseLedger.dayWord("2025-08-11", now: now, calendar: cal), "aug 11, 2025"
        )
    }

    /// A dose row's spoken form must carry the same day word the row
    /// draws, or VoiceOver reads a different record from the screen.
    func testADoseRowSpeaksTheDayItDraws() {
        let cal = zonedCalendar
        let now = cal.date(from: DateComponents(year: 2026, month: 8, day: 14, hour: 10))!
        let row = DoseLedger.row(
            .init(dayKey: "2026-08-14", status: "taken", takenAt: nil,
                  site: "left_thigh", doseWord: "0.5 mg", skipReason: nil),
            now: now, calendar: cal
        )
        XCTAssertEqual(row.day, "today")
        XCTAssertEqual(row.voiceOver, "today, 0.5 mg · left thigh")
    }

    // MARK: - 3b · THE SITE IS ON HER RECORD AND THE COACH COULD NOT SEE IT
    //
    // `33` and `34` both list *"where did I inject last time?"* as
    // answered by `read_dose_history`. It was not: the tool returns the
    // compound, the route, the eras and a STATUS TALLY, and the site
    // never appears in any payload the model receives — while the dose
    // sheet has stated it since v24 (`SiteRotationAdvisor`). A fact on
    // her record that the coach cannot read is the same write-only
    // defect one layer out.

    func testTheCoachCanSayWhereSheInjectedLast() {
        let uid = "one-record-site"
        wipe(uid); defer { wipe(uid) }

        let plan = RegimenPlanRecord(
            userId: uid, kind: "medication", displayName: "",
            scheduleRule: "weeklyAnchor", anchorWeekday: 5
        )
        context.insert(plan)
        let cal = Calendar.current
        for (daysAgo, site) in [(14, "right_abdomen"), (7, "left_thigh")] {
            let at = cal.date(byAdding: .day, value: -daysAgo, to: .now)!
            context.insert(DoseEventRecord(
                id: "\(uid)-\(daysAgo)", userId: uid, regimenPlanId: plan.id,
                dayKey: dayKey(at, cal), scheduledAt: at, status: "taken",
                takenAt: at, site: site
            ))
        }
        try? context.save()

        let out = JeniReadTools.execute(
            ChatToolCall(id: "t", name: "read_dose_history", arguments: [:]),
            userId: uid, in: context
        )
        XCTAssertEqual(out["have"] as? Bool, true)
        XCTAssertEqual(
            out["last_site"] as? String, "left thigh",
            "the freshest recorded site, in her words — not the raw key"
        )
        XCTAssertNotNil(out["last_site_day"],
                        "a site without its day cannot answer 'last time'")
    }

    /// A skipped day has no site, and an oral regimen never has one.
    /// The absent field must simply not appear — the provenance rule.
    func testAnAbsentSiteIsSilentAndNeverInvented() {
        let uid = "one-record-no-site"
        wipe(uid); defer { wipe(uid) }

        let plan = RegimenPlanRecord(
            userId: uid, kind: "medication", displayName: "",
            scheduleRule: "weeklyAnchor", anchorWeekday: 5
        )
        context.insert(plan)
        let at = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        context.insert(DoseEventRecord(
            id: "\(uid)-skip", userId: uid, regimenPlanId: plan.id,
            dayKey: dayKey(at, Calendar.current), scheduledAt: at,
            status: "skipped", skipReason: "traveling"
        ))
        try? context.save()

        let out = JeniReadTools.execute(
            ChatToolCall(id: "t", name: "read_dose_history", arguments: [:]),
            userId: uid, in: context
        )
        XCTAssertNil(out["last_site"], "a skipped day has no site to state")
        XCTAssertNil(out["last_site_day"])
    }

    // MARK: - 4 · THE DELETION CONTRACT
    //
    // "One record" also means ONE deletion. The 2026-08-08 release
    // audit found five families surviving delete-account on device and
    // closed them with a sentence that is the whole rule: **deletion
    // means deletion.** Three families added since then were never
    // added to the sweep — including `what jeni remembers`, which is
    // free text the customer typed and which Settings presents as hers
    // with a per-row forget.

    func testDeletingTheAccountLeavesNoRecordOfHerOnThisDevice() {
        let uid = "one-record-delete-a"
        wipe(uid); defer { wipe(uid) }

        let user = UserRecord(id: uid, name: "a")
        context.insert(user)
        log(56.0, daysAgo: 0, userId: uid)
        seedPlan(userId: uid)
        JeniMemoryStore.remember(
            note: "doesn't eat before 11am", topic: "food", userId: uid, in: context
        )
        context.insert(ProgramFactRecord(
            userId: uid, kind: ProgramFactKind.stepGoal.rawValue,
            value: "i:6000", authority: "preferred",
            basis: "she asked", source: "chat"
        ))
        context.insert(WeeklyReadRecord(
            userId: uid, windowStartDay: "2026-08-10", anchor: "preference",
            offerKey: "steps_up", decision: "accepted"
        ))
        try? context.save()

        XCTAssertFalse(JeniMemoryStore.active(userId: uid, in: context).isEmpty)

        AppSync.clearLocalUserRecords(userId: uid, in: context)

        XCTAssertTrue(
            JeniMemoryStore.active(userId: uid, in: context).isEmpty,
            "what jeni remembers is free text she typed. delete means delete."
        )
        XCTAssertEqual(facts(uid), 0, "her program's facts are hers")
        XCTAssertEqual(reads(uid), 0, "her weekly reads are hers")
        // The families the 2026-08-08 audit already closed, re-pinned so
        // a future sweep cannot quietly drop one.
        XCTAssertEqual(weighIns(uid), 0)
        XCTAssertEqual(plans(uid), 0)
        XCTAssertEqual(users(uid), 0)
    }

    /// The control, and the reason the sweep must stay userId-scoped:
    /// two accounts have shared this device before.
    func testDeletingOneAccountLeavesTheOtherAccountUntouched() {
        let a = "one-record-delete-x", b = "one-record-delete-y"
        wipe(a); wipe(b); defer { wipe(a); wipe(b) }

        for uid in [a, b] {
            context.insert(UserRecord(id: uid, name: uid))
            log(56.0, daysAgo: 0, userId: uid)
            JeniMemoryStore.remember(
                note: "works nights on weekends", topic: "schedule",
                userId: uid, in: context
            )
        }
        try? context.save()

        AppSync.clearLocalUserRecords(userId: a, in: context)

        XCTAssertTrue(JeniMemoryStore.active(userId: a, in: context).isEmpty)
        XCTAssertFalse(
            JeniMemoryStore.active(userId: b, in: context).isEmpty,
            "one account's deletion must never reach another account's record"
        )
        XCTAssertEqual(weighIns(b), 1)
    }

    private func weighIns(_ uid: String) -> Int {
        ((try? context.fetch(FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == uid }))) ?? []).count
    }

    private func plans(_ uid: String) -> Int {
        ((try? context.fetch(FetchDescriptor<ProgramPlanRecord>(
            predicate: #Predicate { $0.userId == uid }))) ?? []).count
    }

    private func facts(_ uid: String) -> Int {
        ((try? context.fetch(FetchDescriptor<ProgramFactRecord>(
            predicate: #Predicate { $0.userId == uid }))) ?? []).count
    }

    private func reads(_ uid: String) -> Int {
        ((try? context.fetch(FetchDescriptor<WeeklyReadRecord>(
            predicate: #Predicate { $0.userId == uid }))) ?? []).count
    }

    private func users(_ uid: String) -> Int {
        ((try? context.fetch(FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == uid }))) ?? []).count
    }

    // MARK: - 5 · PROPAGATION — one fact changes, every surface changes
    //
    // Not "the resolver is shared" (that is an implementation claim) —
    // that the NUMBER on Home, the number on the plan screen and the
    // number in jeni's envelope all move together, in one launch, from
    // one edit.

    private struct Reading: Equatable {
        var home: Int?
        var plan: Int?
        var jeni: Int?
        var protein: Int?
    }

    private func read(_ uid: String) -> Reading {
        let plan = ProgramService.shared.activePlan(userId: uid, in: context)
        let targets = TargetsService.current(userId: uid, in: context)
        let weight = TargetsService.resolvedWeightKg(userId: uid, plan: plan, in: context)
        let summary = PlanSummary.build(
            plan: plan, latestWeightKg: weight,
            proteinG: targets.proteinG, stepsGoal: targets.steps,
            numericsSuppressed: targets.numericsSuppressed, defaults: d
        )
        let envelope = CoachContextAssembler.assemble(userId: uid, in: context)
        let jeni = (envelope["targets"] as? [String: Any])?["kcal"] as? Int
        return Reading(home: targets.kcal, plan: summary.energyKcal,
                       jeni: jeni, protein: targets.proteinG)
    }

    private func assertAgrees(_ r: Reading, _ label: String) {
        XCTAssertNotNil(r.home, "[\(label)] a coherent state must produce a target")
        XCTAssertEqual(r.home, r.plan, "[\(label)] Home vs the plan screen")
        XCTAssertEqual(r.home, r.jeni, "[\(label)] Home vs jeni's envelope")
    }

    func testEditingHeightMovesEveryDependentSurfaceTogether() {
        let uid = "one-record-height"
        wipe(uid); defer { wipe(uid) }
        seedPersona()
        seedPlan(userId: uid)
        log(56.245, daysAgo: 0, userId: uid)
        context.insert(UserRecord(id: uid, name: "h"))
        try? context.save()

        let before = read(uid)
        assertAgrees(before, "before")

        BodyFactsStore.setHeightCm(170.0, userId: uid, in: context, defaults: d)

        let after = read(uid)
        assertAgrees(after, "after the height edit")
        XCTAssertNotEqual(before.home, after.home,
                          "6.25 kcal per centimetre — a height edit must move the number")
        XCTAssertEqual(d.double(forKey: "onboardingHeightCm"), 170.0)
    }

    func testEditingTheSexTermMovesEveryDependentSurfaceTogether() {
        let uid = "one-record-sex"
        wipe(uid); defer { wipe(uid) }
        seedPersona()
        seedPlan(userId: uid)
        log(56.245, daysAgo: 0, userId: uid)
        context.insert(UserRecord(id: uid, name: "s"))
        try? context.save()

        let before = read(uid)
        assertAgrees(before, "before")

        BodyFactsStore.setSex("male", userId: uid, in: context, defaults: d)

        let after = read(uid)
        assertAgrees(after, "after the sex edit")
        // Mifflin-St Jeor carries exactly two constants and the deficit
        // is unchanged, so the BMR term is the only thing that moved.
        // 229, not 166 × 1.375 = 228: `dailyTarget` rounds TDEE to a
        // whole calorie BEFORE the deficit comes off (1693 → 1922), and
        // `CalorieGoldenMatrixTests` pins both ends of this persona at
        // 1,282 and 1,511. Deriving it by hand first is what caught
        // that; the test was wrong, not the arithmetic.
        XCTAssertEqual((after.home ?? 0) - (before.home ?? 0), 229,
                       "the BMR constant is the only thing that moved")
        let envelope = CoachContextAssembler.assemble(userId: uid, in: context)
        let inputs = (envelope["targets"] as? [String: Any])?["inputs"] as? [String: Any]
        XCTAssertEqual(inputs?["sex_term"] as? String, "male",
                       "and jeni is told the term she just changed")
    }

    func testEditingTheGoalMovesTheDistanceOnEverySurface() {
        let uid = "one-record-goal"
        wipe(uid); defer { wipe(uid) }
        seedPersona()
        let plan = seedPlan(userId: uid)
        log(56.245, daysAgo: 0, userId: uid)
        context.insert(UserRecord(id: uid, name: "g"))
        try? context.save()

        let planId = plan.id
        let startDate = plan.startDate

        GoalWeightStore.setGoalWeightKg(
            115 / 2.20462, userId: uid, in: context, defaults: d
        )

        let after = read(uid)
        assertAgrees(after, "after the goal edit")

        let envelope = CoachContextAssembler.assemble(userId: uid, in: context)
        let weight = envelope["weight"] as? [String: Any]
        XCTAssertEqual(weight?["goal_kg"] as? Double,
                       ((115 / 2.20462) * 10).rounded() / 10,
                       "jeni must quote the goal the screens now show")

        let live = ProgramService.shared.activePlan(userId: uid, in: context)
        XCTAssertEqual(live?.id, planId, "a goal edit is not a new program")
        XCTAssertEqual(live?.startDate, startDate, "and it never moves the day she is on")
    }

    // MARK: - 6 · ONE PLATE, SEVEN NUTRIENTS
    //
    // The seven numbers a plate carries must be the same seven
    // everywhere they are read, and must survive every repair the
    // product offers. The customer edits nothing here; nothing may
    // change.

    private struct Seven: Equatable {
        var kcal: Int?, protein: Int?, carbs: Int?, fat: Int?
        var fiber: Int?, sugar: Int?, sodium: Int?
    }

    private func sevenFromJeni(_ uid: String, daysAgo: Int) -> Seven? {
        let call = ChatToolCall(
            id: "t", name: "read_food_day", arguments: ["days_ago": daysAgo]
        )
        let out = JeniReadTools.execute(call, userId: uid, in: context)
        guard (out["have"] as? Bool) == true,
              let plate = (out["plates"] as? [[String: Any]])?.first
        else { return nil }
        return Seven(
            kcal: plate["kcal"] as? Int, protein: plate["protein_g"] as? Int,
            carbs: plate["carbs_g"] as? Int, fat: plate["fat_g"] as? Int,
            fiber: plate["fiber_g"] as? Int, sugar: plate["sugar_g"] as? Int,
            sodium: plate["sodium_mg"] as? Int
        )
    }

    func testOnePlateCarriesTheSameSevenNumbersThroughEveryRepair() {
        let uid = "one-record-plate-\(UUID().uuidString.prefix(6))"
        defer { FoodLogPersister.deleteAllEntries(userId: uid) }
        seedPersona()

        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: .now)!
        let entryId = UUID().uuidString
        FoodLogPersister.mergeRemote([
            .init(id: entryId, userId: uid, loggedAt: yesterday,
                  kcal: 640, protein: 42, carbs: 55, fat: 22, fiber: 9,
                  sugar: 12, sodiumMg: 880, satFatG: 6,
                  title: "chicken bowl", source: "photo"),
        ])

        let expected = Seven(kcal: 640, protein: 42, carbs: 55, fat: 22,
                             fiber: 9, sugar: 12, sodium: 880)
        XCTAssertEqual(sevenFromJeni(uid, daysAgo: 1), expected,
                       "the coach reads the plate the record holds")

        // THE DAY MOVES; THE NUMBERS DO NOT.
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: .now)!
        XCTAssertTrue(
            FoodLogPersister.setLoggedDay(id: entryId, to: twoDaysAgo),
            "a plate can be put on the day it fed"
        )
        XCTAssertEqual(sevenFromJeni(uid, daysAgo: 2), expected,
                       "re-dating a plate must not re-estimate it")
        XCTAssertNil(sevenFromJeni(uid, daysAgo: 1),
                     "and the day it left is empty, not duplicated")

        // A REPEAT IS THE SAME PLATE, TODAY.
        guard let moved = FoodLogPersister.allEntries(userId: uid)
            .first(where: { $0.id == entryId }) else {
            return XCTFail("the moved plate must still be on file")
        }
        FoodLogPersister.relog(moved, userId: uid)
        let today = FoodLogPersister.allEntries(userId: uid)
            .filter { cal.isDateInToday($0.loggedAt) }
        XCTAssertEqual(today.count, 1)
        XCTAssertEqual(
            Seven(kcal: Int(today[0].kcal), protein: Int(today[0].protein),
                  carbs: Int(today[0].carbs), fat: Int(today[0].fat),
                  fiber: Int(today[0].fiber), sugar: Int(today[0].sugar),
                  sodium: Int(today[0].sodiumMg)),
            expected,
            "a repeat carries the numbers she already corrected, not a new guess"
        )
    }
}
