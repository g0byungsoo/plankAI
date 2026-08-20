import XCTest
@testable import plankAI

// MARK: - DailyUtilityTests
//
// The two boring capabilities `33_THE_WEIGHT_LOSS_APP_I_WOULD_ACTUALLY_KEEP`
// added, pinned as honesty tables rather than as layout.
//
//   1. WHAT IS LEFT TODAY — Home's day tier states the remainder, not
//      just the position. The refusals matter more than the arithmetic:
//      a maintenance figure gets NO remainder, and no target gets no
//      sentence at all (the repair door owns that state).
//
//   2. THE DOSE LOG — the shot-by-shot ledger the GLP-1 surfaces never
//      had. It reports and never interprets: no adherence rate, no
//      streak, no grading of a missed dose, no invented reason.
//
// Both engines are pure, so this file needs no container, no view and
// no simulator state.

final class DailyUtilityTests: XCTestCase {

    // MARK: - 1 · WHAT IS LEFT TODAY

    private func line(_ target: Int?, _ eaten: Int, maintenance: Bool = false) -> String? {
        HomeNutritionSummary.energyReferenceLine(
            targetKcal: target, eatenKcal: eaten, isMaintenance: maintenance
        )
    }

    func testUnderTheTargetStatesWhatIsLeft() {
        XCTAssertEqual(line(1460, 1240), "of 1,460 kcal · 220 left")
    }

    func testOverTheTargetStatesHowFarOver() {
        XCTAssertEqual(line(1460, 1660), "of 1,460 kcal · 200 over")
    }

    /// "0 left" reads like a broken number. The word for landing on it
    /// is a word.
    func testExactlyOnTheTargetSaysSo() {
        XCTAssertEqual(line(1460, 1460), "of 1,460 kcal · right on it")
    }

    func testNothingEatenYetLeavesTheWholeTarget() {
        XCTAssertEqual(line(1282, 0), "of 1,282 kcal · 1,282 left")
    }

    /// THE REFUSAL THAT MATTERS. A maintenance figure is an ESTIMATE OF
    /// HER EXPENDITURE, not a budget she was handed. "220 left" against
    /// an estimate is an instruction to eat that nothing in the record
    /// supports, so `· holding` stands alone — exactly as `31` §8 shipped
    /// it, and this test is what stops a later pass from "completing"
    /// the sentence.
    func testMaintenanceGetsHoldingAndNeverARemainder() {
        XCTAssertEqual(line(1693, 900, maintenance: true), "of 1,693 kcal · holding")
        XCTAssertEqual(line(1693, 2200, maintenance: true), "of 1,693 kcal · holding")
        XCTAssertNil(HomeNutritionSummary.energyRemainderWord(
            targetKcal: 1693, eatenKcal: 900, isMaintenance: true
        ))
    }

    /// p53 — THE COUNT-UP COHORT. For someone whose medication is
    /// already doing the deficit, "over" is the market's named harm
    /// (the countdown trauma MeAgain's reviews quote; the what-the-
    /// hell effect the restriction literature measures): under stays
    /// spoken (it invites eating, which is this cohort's actual job),
    /// over falls silent — the pair itself states the fact plainly.
    func testTheCountUpCohortNeverHearsOver() {
        XCTAssertEqual(
            HomeNutritionSummary.energyReferenceLine(
                targetKcal: 1460, eatenKcal: 1660,
                isMaintenance: false, countUpOnly: true
            ),
            "of 1,460 kcal"
        )
        XCTAssertEqual(
            HomeNutritionSummary.energyReferenceLine(
                targetKcal: 1460, eatenKcal: 1240,
                isMaintenance: false, countUpOnly: true
            ),
            "of 1,460 kcal · 220 left"
        )
        XCTAssertEqual(
            HomeNutritionSummary.energyReferenceLine(
                targetKcal: 1460, eatenKcal: 1460,
                isMaintenance: false, countUpOnly: true
            ),
            "of 1,460 kcal · right on it"
        )
    }

    /// No target ⇒ NO SENTENCE. The band's repair door owns that state
    /// (`30` §8); a dangling "of  kcal · " would be the fabrication this
    /// whole line of work exists to stop.
    func testNoTargetProducesNoReferenceSentenceAtAll() {
        XCTAssertNil(line(nil, 1200))
        XCTAssertNil(line(0, 1200))
    }

    /// The separator can never be left hanging: every non-nil line ends
    /// in a word, never in " · ".
    func testTheSentenceNeverEndsInADanglingSeparator() {
        for target in [nil, 0, 1, 1200, 1460, 3500] as [Int?] {
            for eaten in [0, 1, 900, 1460, 4000] {
                for maintenance in [false, true] {
                    guard let s = line(target, eaten, maintenance: maintenance) else { continue }
                    XCTAssertFalse(s.hasSuffix("·"), s)
                    XCTAssertFalse(s.hasSuffix(" "), s)
                    XCTAssertFalse(s.contains("·  "), s)
                }
            }
        }
    }

    // MARK: - 2 · THE DOSE LOG

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }

    private func now() -> Date {
        cal.date(from: DateComponents(year: 2026, month: 8, day: 13))!
    }

    private func entry(
        _ dayKey: String, _ status: String,
        site: String? = nil, dose: String? = nil,
        takenAt: Date? = nil, skipReason: String? = nil
    ) -> DoseLedger.Entry {
        .init(dayKey: dayKey, status: status, takenAt: takenAt,
              site: site, doseWord: dose, skipReason: skipReason)
    }

    func testATakenDoseStatesTheDayTheDoseAndTheSite() {
        let row = DoseLedger.row(
            entry("2026-08-06", "taken", site: "left_thigh", dose: "0.5 mg"),
            now: now(), calendar: cal
        )
        XCTAssertEqual(row.day, "aug 6")
        XCTAssertEqual(row.detail, "0.5 mg · left thigh")
        XCTAssertFalse(row.isMuted)
        XCTAssertEqual(row.voiceOver, "aug 6, 0.5 mg · left thigh")
    }

    /// An oral dose has no site and a legacy row may have no recorded
    /// dose. The row still states the fact that it happened rather than
    /// rendering an empty cell.
    func testATakenDoseWithNeitherSiteNorDoseStillSaysTaken() {
        let row = DoseLedger.row(entry("2026-08-06", "taken"), now: now(), calendar: cal)
        XCTAssertEqual(row.detail, "taken")
        XCTAssertFalse(row.isMuted)
    }

    func testASkippedDayStatesHerReasonWhenSheGaveOne() {
        XCTAssertEqual(
            DoseLedger.row(entry("2026-07-09", "skipped", skipReason: "traveling"),
                           now: now(), calendar: cal).detail,
            "skipped · traveling"
        )
        XCTAssertEqual(
            DoseLedger.row(entry("2026-07-09", "skipped", skipReason: "out_of_medication"),
                           now: now(), calendar: cal).detail,
            "skipped · none on hand"
        )
    }

    /// "just_didnt" is an option the sheet offers so she can close the
    /// loop without explaining herself. Rendering it back as a reason
    /// would turn a shrug into a confession.
    func testJustDidntIsNotRenderedAsAReason() {
        XCTAssertNil(DoseLedger.skipWord("just_didnt"))
        XCTAssertEqual(
            DoseLedger.row(entry("2026-07-09", "skipped", skipReason: "just_didnt"),
                           now: now(), calendar: cal).detail,
            "skipped"
        )
        // An unrecognised reason is never invented either.
        XCTAssertNil(DoseLedger.skipWord("something_new"))
    }

    /// A slot whose window closed with nothing recorded is a FACT, not a
    /// failure: "not recorded", quieter, never "you missed one".
    func testAMissedSlotIsStatedFlatlyAndNeverGraded() {
        let row = DoseLedger.row(entry("2026-07-02", "missed"), now: now(), calendar: cal)
        XCTAssertEqual(row.detail, "not recorded")
        XCTAssertTrue(row.isMuted)
        XCTAssertFalse(row.detail.contains("missed"))
    }

    func testALateTakeIsStatedAsProvenanceNotAReprimand() {
        let slot = cal.date(from: DateComponents(year: 2026, month: 8, day: 6))!
        let taken = cal.date(byAdding: .day, value: 2, to: slot)!
        let row = DoseLedger.row(
            entry("2026-08-06", "taken", site: "right_arm", dose: "0.25 mg", takenAt: taken),
            now: now(), calendar: cal
        )
        XCTAssertEqual(row.detail, "0.25 mg · right arm · 2 days late")
        XCTAssertFalse(row.isMuted, "a late dose is a dose")
    }

    func testATakeOnTheSlotDayCarriesNoLateWord() {
        let slot = cal.date(from: DateComponents(year: 2026, month: 8, day: 6))!
        let row = DoseLedger.row(
            entry("2026-08-06", "taken", site: "right_arm", dose: "0.25 mg",
                  takenAt: cal.date(byAdding: .hour, value: 20, to: slot)!),
            now: now(), calendar: cal
        )
        XCTAssertEqual(row.detail, "0.25 mg · right arm")
    }

    func testRowsAreNewestFirstAndCapped() {
        let entries = (1...30).map { entry(String(format: "2026-06-%02d", $0), "taken", dose: "1 mg") }
        let rows = DoseLedger.rows(entries, now: now(), limit: 24, calendar: cal)
        XCTAssertEqual(rows.count, 24)
        XCTAssertEqual(rows.first?.dayKey, "2026-06-30")
        XCTAssertEqual(rows.last?.dayKey, "2026-06-07")
    }

    /// A dose from a previous year must not read "jun 30" beside this
    /// year's "jun 30".
    func testACrossYearDayCarriesItsYear() {
        XCTAssertEqual(
            DoseLedger.dayWord("2025-06-30", now: now(), calendar: cal),
            "jun 30, 2025"
        )
        XCTAssertEqual(
            DoseLedger.dayWord("2026-06-30", now: now(), calendar: cal),
            "jun 30"
        )
    }

    /// THE LEDGER REPORTS. It has no vocabulary for grading, and this is
    /// the test that keeps it that way: no row this engine can produce
    /// may contain a judgement word or a percentage.
    func testTheLedgerHasNoVocabularyForJudgement() {
        let banned = ["missed one", "streak", "%", "good", "great", "bad",
                      "should", "consistent", "adherence", "on track", "behind"]
        let statuses = ["taken", "skipped", "missed", "pending", "anything_else"]
        let reasons: [String?] = [nil, "traveling", "out_of_medication",
                                  "clinician_paused", "just_didnt"]
        for status in statuses {
            for reason in reasons {
                let row = DoseLedger.row(
                    entry("2026-08-06", status, site: "left_abdomen",
                          dose: "0.5 mg", skipReason: reason),
                    now: now(), calendar: cal
                )
                for word in banned {
                    XCTAssertFalse(
                        row.detail.lowercased().contains(word),
                        "\(status)/\(reason ?? "nil") produced a judgement: \(row.detail)"
                    )
                }
            }
        }
    }

    /// An unknown status can only ever fall to the pending face — never
    /// to a taken face that would claim a dose she did not record.
    func testAnUnknownStatusNeverClaimsADose() {
        let row = DoseLedger.row(entry("2026-08-13", "brand_new_status"),
                                 now: now(), calendar: cal)
        XCTAssertEqual(row.detail, "due")
        XCTAssertTrue(row.isMuted)
    }
}
