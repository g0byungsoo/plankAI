import XCTest
import SwiftData
import PlankSync
@testable import plankAI

// MARK: - PastRecordRepairTests
//
// docs/app_v25/36_THE_APP_I_WOULD_TRUST_FOR_30_DAYS.md, turned into law.
//
// THE FINDING THIS FILE EXISTS FOR, and it is `34`'s finding one domain
// further on. `34` closed the write-only-in-the-past defect for FOOD and
// WEIGHT — the two records every user has — and named the other two:
//
//   · the shot log (`33`'s `the doses`) was LISTED and READ-ONLY;
//   · side effects were today-only, in `load()`, `record` and `remove`.
//
// Those are the two records a GLP-1 payer is most likely to get wrong in
// a busy week: a shot marked on the wrong site, a dose marked by
// accident, nausea remembered the next morning. And side effects had it
// worst — there was no LIST at all, so the only surfaces that could show
// her what she had recorded were a Becoming chart and **the PDF she
// hands a clinician.** The product would tell her doctor what she
// recorded three weeks ago and would not tell her.
//
// Every test here is an invariant, not a pixel:
//
//   1. The symptom record lists days, newest first, and reports — it has
//      no vocabulary for judgement, no count of bad days, no rate.
//   2. A day word identifies exactly one day, in the calendar's OWN time
//      zone (the bug `34` found in `WeightLedger` and fixed in the
//      product rather than in the test).
//   3. A symptom can be recorded, corrected and cleared on any of the
//      last fourteen days, and doing so touches that day and no other.
//   4. Correcting a PAST dose slot changes that slot and never today's
//      checklist — the invariant that makes the new tap target safe.
//   5. The paid product has ONE pace vocabulary.

@MainActor
final class PastRecordRepairTests: XCTestCase {

    // MARK: - Harness

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }

    private func now(_ iso: String = "2026-08-14") -> Date {
        let f = DateFormatter()
        f.calendar = cal
        f.timeZone = cal.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: "\(iso) 12:00")!
    }

    private func entry(
        _ dayKey: String, _ word: String, _ severity: String = "a touch"
    ) -> SymptomLedger.Entry {
        .init(dayKey: dayKey, word: word, severityWord: severity)
    }

    private func freshContext(_ uid: String) -> ModelContext {
        let ctx = TestModelContainer.shared.mainContext
        wipe(uid, in: ctx)
        return ctx
    }

    /// Everything `MedicationQASeeder`'s `history` variant writes, and
    /// that is FOUR model types, not three.
    ///
    /// Found by this file breaking `ReattributionTests`, which does an
    /// UNSCOPED `fetch(FetchDescriptor<WeightLogRecord>())` against the
    /// one shared `TestModelContainer` and expects exactly 2 rows. It
    /// saw 42: the seeder also writes ten weekly weigh-ins (the dose-era
    /// read draws from them), four of my tests seed it, and my wipe list
    /// did not include them. **The defect was in this file, not in the
    /// product, and not in the test it broke** — a suite that leaves rows
    /// behind in a shared container is a suite that will fail somebody
    /// else's assertion for a reason that has nothing to do with them.
    private func wipe(_ uid: String, in ctx: ModelContext) {
        let owner = uid
        try? ctx.delete(model: ObservationRecord.self,
                        where: #Predicate { $0.userId == owner })
        try? ctx.delete(model: DoseEventRecord.self,
                        where: #Predicate { $0.userId == owner })
        try? ctx.delete(model: RegimenPlanRecord.self,
                        where: #Predicate { $0.userId == owner })
        try? ctx.delete(model: WeightLogRecord.self,
                        where: #Predicate { $0.userId == owner })
        try? ctx.save()
    }

    /// The day key N days before "today", in the device's calendar —
    /// the same conversion `TodayStateService` performs.
    private func dayKey(daysAgo: Int) -> String {
        let day = Calendar.current.date(
            byAdding: .day, value: -daysAgo, to: .now
        ) ?? .now
        return TodayStateService.dayKey(for: day)
    }

    // MARK: - 1 · The symptom record is a record

    func testTheSymptomRecordListsEveryDayNewestFirst() {
        let rows = SymptomLedger.rows(
            [
                entry("2026-08-10", "queasy"),
                entry("2026-08-13", "worn down"),
                entry("2026-08-01", "headache"),
            ],
            now: now(), calendar: cal
        )
        XCTAssertEqual(rows.map(\.dayKey),
                       ["2026-08-13", "2026-08-10", "2026-08-01"],
                       "the record reads newest first, like its two siblings")
    }

    /// A day is one row. Three symptoms on Tuesday is Tuesday saying
    /// three things, never three rows competing for the same date — the
    /// law `34` wrote for the weigh-in ledger, applied the other way up.
    func testADayThatCarriedTwoSymptomsIsOneRowStatingBoth() {
        let rows = SymptomLedger.rows(
            [
                entry("2026-08-13", "worn down", "rough"),
                entry("2026-08-13", "hair shedding", "a touch"),
            ],
            now: now(), calendar: cal
        )
        XCTAssertEqual(rows.count, 1)
        // `.first?` and not `[0]`: an index into an empty array aborts
        // the whole runner and prints a green count for the tests that
        // never ran (`30` §11's trap). A failing assertion is the point.
        XCTAssertEqual(rows.first?.detail,
                       "hair shedding · a touch, worn down · rough",
                       "alphabetical within a day — stable, and it ranks nothing")
    }

    /// The ledger reports and never grades. Swept over every symptom ×
    /// every severity, exactly as `33` swept `DoseLedger`.
    func testTheSymptomRecordHasNoVocabularyForJudgement() {
        let banned = [
            "bad", "worse", "worst", "better", "improved", "good", "poor",
            "streak", "missed", "failed", "fail", "should", "again",
            "still", "unfortunately", "concerning", "alarming", "risk",
            "warning", "abnormal", "severe", "%", "average", "trend",
            "caused", "because", "due to", "since your dose",
        ]
        for symptom in SideEffectSymptom.allCases {
            for severity in SideEffectSeverity.allCases {
                let row = SymptomLedger.row(
                    dayKey: "2026-08-13",
                    [entry("2026-08-13", symptom.word, severity.word)],
                    now: now(), calendar: cal
                )
                let text = (row.day + " " + row.detail + " " + row.voiceOver)
                    .lowercased()
                for word in banned {
                    XCTAssertFalse(
                        text.contains(word),
                        "\(symptom.rawValue)/\(severity.rawValue) said '\(word)'"
                    )
                }
            }
        }
    }

    /// `34` found this in the product, not in a test: a `DateFormatter`
    /// that does not inherit the calendar's zone prints the day BEFORE
    /// the one the calendar chose, so the ledger disagrees with itself
    /// about which day it is listing.
    func testTheSymptomDayWordInheritsTheCalendarTimeZone() {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let f = DateFormatter()
        f.calendar = tokyo
        f.timeZone = tokyo.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        let tokyoNow = f.date(from: "2026-08-14 09:00")!

        XCTAssertEqual(
            SymptomLedger.dayWord("2026-08-11", now: tokyoNow, calendar: tokyo),
            "aug 11",
            "the formatter must render in the zone the calendar decided in"
        )
        XCTAssertEqual(
            SymptomLedger.dayWord("2026-08-14", now: tokyoNow, calendar: tokyo),
            "today"
        )
        XCTAssertEqual(
            SymptomLedger.dayWord("2026-08-13", now: tokyoNow, calendar: tokyo),
            "yesterday"
        )
        XCTAssertEqual(
            SymptomLedger.dayWord("2025-12-30", now: tokyoNow, calendar: tokyo),
            "dec 30, 2025",
            "a year boundary states the year"
        )
    }

    /// Fourteen days, never forward. A symptom cannot have happened
    /// tomorrow, and an unbounded picker on the record that reaches a
    /// clinician is an invitation to invent history.
    func testTheSymptomRecordOffersFourteenDaysAndNeverTomorrow() {
        let options = SymptomLedger.dayOptions(now: now(), calendar: cal)
        XCTAssertEqual(options.count, 14)
        XCTAssertEqual(options.first, cal.startOfDay(for: now()))
        for day in options {
            XCTAssertLessThanOrEqual(
                day, now(), "no option may be in the future"
            )
        }
        XCTAssertEqual(
            cal.dateComponents([.day], from: options.last!, to: options.first!).day,
            13
        )
    }

    // MARK: - 2 · A symptom lands on the day it happened

    func testASymptomCanBeRecordedOnADayThatIsNotToday() {
        let uid = "past-symptom-record"
        let ctx = freshContext(uid)
        defer { wipe(uid, in: ctx) }

        let threeAgo = dayKey(daysAgo: 3)
        _ = SideEffectLog.record(
            .nausea, severity: .rough, dayKey: threeAgo, userId: uid, in: ctx
        )

        let onThatDay = SideEffectLog.recorded(on: threeAgo, userId: uid, in: ctx)
        XCTAssertEqual(onThatDay[.nausea], .rough,
                       "it lands on the day she says it happened")
        XCTAssertTrue(
            SideEffectLog.recorded(
                on: TodayStateService.dayKey(), userId: uid, in: ctx
            ).isEmpty,
            "and nowhere near today"
        )
    }

    /// The correction is the SAME record — one row per day per symptom,
    /// through the deterministic id — not a second row on the same day.
    func testCorrectingAPastSymptomChangesThatDayAndNothingElse() {
        let uid = "past-symptom-correct"
        let ctx = freshContext(uid)
        defer { wipe(uid, in: ctx) }

        let yesterday = dayKey(daysAgo: 1)
        let fiveAgo = dayKey(daysAgo: 5)
        _ = SideEffectLog.record(.nausea, severity: .aTouch,
                                 dayKey: yesterday, userId: uid, in: ctx)
        _ = SideEffectLog.record(.nausea, severity: .aTouch,
                                 dayKey: fiveAgo, userId: uid, in: ctx)

        _ = SideEffectLog.record(.nausea, severity: .rough,
                                 dayKey: yesterday, userId: uid, in: ctx)

        XCTAssertEqual(
            SideEffectLog.recorded(on: yesterday, userId: uid, in: ctx)[.nausea],
            .rough, "the day she corrected moved"
        )
        XCTAssertEqual(
            SideEffectLog.recorded(on: fiveAgo, userId: uid, in: ctx)[.nausea],
            .aTouch, "the day she did not touch did not move"
        )
        XCTAssertEqual(
            SideEffectLog.entries(userId: uid, in: ctx).count, 2,
            "a correction is the same row, never a second one on that day"
        )
    }

    func testClearingAPastSymptomLeavesEveryOtherDayOnFile() {
        let uid = "past-symptom-clear"
        let ctx = freshContext(uid)
        defer { wipe(uid, in: ctx) }

        let yesterday = dayKey(daysAgo: 1)
        let sixAgo = dayKey(daysAgo: 6)
        _ = SideEffectLog.record(.fatigue, severity: .noticeable,
                                 dayKey: yesterday, userId: uid, in: ctx)
        _ = SideEffectLog.record(.fatigue, severity: .noticeable,
                                 dayKey: sixAgo, userId: uid, in: ctx)
        _ = SideEffectLog.record(.headache, severity: .aTouch,
                                 dayKey: yesterday, userId: uid, in: ctx)

        SideEffectLog.remove(.fatigue, dayKey: yesterday, userId: uid, in: ctx)

        let left = SideEffectLog.recorded(on: yesterday, userId: uid, in: ctx)
        XCTAssertNil(left[.fatigue], "the one she cleared is gone")
        XCTAssertEqual(left[.headache], .aTouch,
                       "the other symptom on that day stands")
        XCTAssertEqual(
            SideEffectLog.recorded(on: sixAgo, userId: uid, in: ctx)[.fatigue],
            .noticeable, "the same symptom on another day stands"
        )
    }

    /// The one a view-level bug would break: reading a past day must not
    /// leak today's rows into it, and writing a past day must not write
    /// today's.
    func testRecordingOnAPastDayNeverTouchesToday() {
        let uid = "past-symptom-isolation"
        let ctx = freshContext(uid)
        defer { wipe(uid, in: ctx) }

        let today = TodayStateService.dayKey()
        _ = SideEffectLog.record(.foodNoise, severity: .aTouch,
                                 dayKey: today, userId: uid, in: ctx)
        _ = SideEffectLog.record(.nausea, severity: .rough,
                                 dayKey: dayKey(daysAgo: 4), userId: uid, in: ctx)

        let todayMap = SideEffectLog.recorded(on: today, userId: uid, in: ctx)
        XCTAssertEqual(todayMap.count, 1)
        XCTAssertEqual(todayMap[.foodNoise], .aTouch)
        XCTAssertNil(todayMap[.nausea],
                     "a past day's symptom must never appear under today")

        let pastMap = SideEffectLog.recorded(
            on: dayKey(daysAgo: 4), userId: uid, in: ctx
        )
        XCTAssertEqual(pastMap.count, 1)
        XCTAssertEqual(pastMap[.nausea], .rough)
    }

    // MARK: - 3 · A past dose slot is correctable, and bounded

    /// `the doses` rows are built from `DoseEventStore.events`, so a row
    /// exists only for a slot ALREADY on file. Tapping one can correct a
    /// record; it can never invent a day.
    func testTheDoseRecordOnlyListsSlotsAlreadyOnFile() {
        let uid = "past-dose-listing"
        let ctx = freshContext(uid)
        defer { wipe(uid, in: ctx) }

        XCTAssertTrue(DoseEventStore.events(userId: uid, in: ctx).isEmpty)
        MedicationQASeeder.seed(variant: "history", userId: uid, in: ctx)
        let events = DoseEventStore.events(userId: uid, in: ctx)
        XCTAssertFalse(events.isEmpty)

        let rows = DoseLedger.rows(events.map {
            DoseLedger.Entry(dayKey: $0.dayKey, status: $0.status,
                             takenAt: $0.takenAt, site: $0.site,
                             doseWord: nil, skipReason: $0.skipReason)
        })
        XCTAssertEqual(
            Set(rows.map(\.dayKey)), Set(events.map(\.dayKey)),
            "every row is a slot on file, and every slot on file is a row"
        )
    }

    /// The invariant that makes the new tap target safe: a PAST slot is
    /// its own record. Correcting it moves that slot and leaves today's
    /// checklist — and every other slot — exactly where it was.
    func testCorrectingAPastDoseChangesThatSlotAndNothingElse() {
        let uid = "past-dose-correct"
        let ctx = freshContext(uid)
        defer { wipe(uid, in: ctx) }
        MedicationQASeeder.seed(variant: "history", userId: uid, in: ctx)

        let taken = DoseEventStore.events(userId: uid, in: ctx)
            .filter { $0.status == "taken" }
            .sorted { $0.dayKey > $1.dayKey }
        guard taken.count >= 2 else {
            return XCTFail("the history fixture must seed ≥2 taken slots")
        }
        let target = taken[1]                      // NOT the newest
        let untouched = taken[0]
        let targetSlot = target.dayKey
        let untouchedSite = untouched.site
        let before = DoseEventStore.events(userId: uid, in: ctx).count

        MedicationLog.resolve(
            .taken(site: .rightArm, note: nil, at: target.takenAt ?? .now),
            slotDayKey: targetSlot, source: .sheet, userId: uid, in: ctx
        )

        let after = DoseEventStore.events(userId: uid, in: ctx)
        XCTAssertEqual(after.count, before,
                       "a correction upserts the slot; it never adds a row")
        XCTAssertEqual(
            after.first { $0.dayKey == targetSlot }?.site,
            InjectionSite.rightArm.rawValue,
            "the slot she corrected carries the new site"
        )
        XCTAssertEqual(
            after.first { $0.dayKey == untouched.dayKey }?.site, untouchedSite,
            "no other slot moved"
        )
    }

    /// A past unmark must not reach today. `MedicationLog.resolve` only
    /// writes the checklist and retires reminders when the slot IS
    /// today — this pins that, because the new tap target is the first
    /// surface that can send it a past slot for an already-resolved day.
    func testUnmarkingAPastDoseNeverTouchesTodaysChecklist() {
        let uid = "past-dose-unmark"
        let ctx = freshContext(uid)
        defer { wipe(uid, in: ctx) }
        MedicationQASeeder.seed(variant: "history", userId: uid, in: ctx)

        let today = TodayStateService.dayKey()
        let past = DoseEventStore.events(userId: uid, in: ctx)
            .filter { $0.status == "taken" && $0.dayKey != today }
            .sorted { $0.dayKey > $1.dayKey }
        guard let slot = past.first else {
            return XCTFail("the history fixture must seed a past taken slot")
        }
        let slotKey = slot.dayKey
        UserDefaults.standard.removeObject(forKey: "day.dose.\(today)")

        MedicationLog.resolve(
            .unmark, slotDayKey: slotKey, source: .sheet, userId: uid, in: ctx
        )

        XCTAssertNil(
            DoseEventStore.events(userId: uid, in: ctx)
                .first { $0.dayKey == slotKey },
            "the slot she took back is gone from the record"
        )
        XCTAssertNil(
            UserDefaults.standard.string(forKey: "day.dose.\(today)"),
            "today's dose key was never written by a past unmark"
        )
        XCTAssertNil(
            UserDefaults.standard.string(forKey: "day.dose.\(slotKey)"),
            "and the slot's own key went with it"
        )
    }

    func testSkippingAPastSlotRecordsTheReasonOnThatSlotOnly() {
        let uid = "past-dose-skip"
        let ctx = freshContext(uid)
        defer { wipe(uid, in: ctx) }
        MedicationQASeeder.seed(variant: "history", userId: uid, in: ctx)

        let today = TodayStateService.dayKey()
        guard let slot = DoseEventStore.events(userId: uid, in: ctx)
            .filter({ $0.status == "taken" && $0.dayKey != today })
            .sorted(by: { $0.dayKey > $1.dayKey }).first
        else { return XCTFail("the history fixture must seed a past slot") }
        let slotKey = slot.dayKey

        MedicationLog.resolve(
            .skipped(reason: "traveling"), slotDayKey: slotKey,
            source: .sheet, userId: uid, in: ctx
        )

        let row = DoseEventStore.events(userId: uid, in: ctx)
            .first { $0.dayKey == slotKey }
        XCTAssertEqual(row?.status, "skipped")
        XCTAssertEqual(row?.skipReason, "traveling")
        // And the ledger states it in her words, without grading it.
        let rendered = DoseLedger.row(
            .init(dayKey: slotKey, status: "skipped", takenAt: nil,
                  site: nil, doseWord: nil, skipReason: "traveling")
        )
        XCTAssertEqual(rendered.detail, "skipped · traveling")
    }

    // MARK: - 4 · One pace vocabulary in the paid product

    /// The same three stored values had four names. `32` §16 found it,
    /// removed the fifth, and left the rest P2. The screen that BUILDS
    /// her plan said `soft/medium/hard` while Home, `your numbers`, the
    /// pace editor and the coach all said `gentle/steady/strong`.
    func testThePaidProductHasOnePaceVocabulary() {
        XCTAssertEqual(IntensityTier.soft.label, "gentle")
        XCTAssertEqual(IntensityTier.medium.label, "steady")
        XCTAssertEqual(IntensityTier.hard.label, "strong")

        // The RAW values are what is persisted, and they are untouched —
        // nothing about an installed account moves.
        XCTAssertEqual(IntensityTier.soft.rawValue, "soft")
        XCTAssertEqual(IntensityTier.medium.rawValue, "medium")
        XCTAssertEqual(IntensityTier.hard.rawValue, "hard")
    }
}
