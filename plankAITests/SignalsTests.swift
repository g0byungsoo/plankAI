import XCTest
@testable import plankAI

// MARK: - SignalsTests
//
// docs/app_v6/00_RESEARCH.md — the passive layer's laws: the window
// is observed never prescribed (tone saturates at 14h, care at 16h);
// phases only speak inside the 8–20h sanity band; meal moves credit
// complete hours once; sweetness needs 3 sugar-days before it may
// speak and both weeks before it may claim a direction; absence
// never fabricates.

final class SignalsTests: XCTestCase {

    // Fixed GMT calendar so day boundaries are deterministic.
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "GMT")!
        return c
    }()

    /// Day 0 = 2026-07-15. `date(-1, 20, 41)` = July 14, 20:41 GMT.
    private func date(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 7; c.day = 15 + dayOffset
        c.hour = hour; c.minute = minute
        c.timeZone = TimeZone(identifier: "GMT")
        return cal.date(from: c)!
    }

    // MARK: - KitchenSignal.phase

    func testOvernightPhaseCountsLive() {
        let phase = KitchenSignal.phase(
            plateTimes: [date(-1, 13, 0), date(-1, 20, 41)],
            now: date(0, 8, 0), calendar: cal
        )
        guard case let .overnight(hours, closedAt) = phase else {
            return XCTFail("expected .overnight, got \(String(describing: phase))")
        }
        XCTAssertEqual(hours, 11.32, accuracy: 0.01)
        XCTAssertEqual(closedAt, date(-1, 20, 41))
    }

    func testOvernightStaysSilentUnderEightHours() {
        // 23:00 plate, 4am wake — a 5h gap is night noise, not a story.
        XCTAssertNil(KitchenSignal.phase(
            plateTimes: [date(-1, 23, 0)],
            now: date(0, 4, 0), calendar: cal
        ))
    }

    func testOvernightStaysSilentPastTwentyHours() {
        // Last plate two days back — travel or missed logs, never narrated.
        XCTAssertNil(KitchenSignal.phase(
            plateTimes: [date(-2, 20, 0)],
            now: date(0, 18, 0), calendar: cal
        ))
    }

    func testSettledPhaseAfterFirstPlate() {
        let phase = KitchenSignal.phase(
            plateTimes: [date(-1, 20, 41), date(0, 9, 15), date(0, 12, 30)],
            now: date(0, 14, 0), calendar: cal
        )
        guard case let .settled(hours, closedAt, openedAt) = phase else {
            return XCTFail("expected .settled, got \(String(describing: phase))")
        }
        XCTAssertEqual(hours, 12.57, accuracy: 0.01)
        XCTAssertEqual(closedAt, date(-1, 20, 41))
        XCTAssertEqual(openedAt, date(0, 9, 15))
    }

    func testSettledStaysSilentOutsideBand() {
        // 22:00 → 04:00 is 6h: today HAS a plate, but the window
        // can't be narrated → the module stays quiet all day.
        XCTAssertNil(KitchenSignal.phase(
            plateTimes: [date(-1, 22, 0), date(0, 4, 0)],
            now: date(0, 12, 0), calendar: cal
        ))
    }

    func testEveningPhaseAfterQuietNinetyMinutes() {
        let phase = KitchenSignal.phase(
            plateTimes: [date(0, 8, 0), date(0, 19, 30)],
            now: date(0, 21, 30), calendar: cal
        )
        guard case let .evening(hours, closedAt) = phase else {
            return XCTFail("expected .evening, got \(String(describing: phase))")
        }
        XCTAssertEqual(hours, 2.0, accuracy: 0.01)
        XCTAssertEqual(closedAt, date(0, 19, 30))
    }

    func testEveningNeedsBothLateHourAndQuietGap() {
        // 20:30 with only a 1h gap → still the settled fact.
        let early = KitchenSignal.phase(
            plateTimes: [date(-1, 21, 0), date(0, 8, 0), date(0, 19, 30)],
            now: date(0, 20, 30), calendar: cal
        )
        guard case .settled = early else {
            return XCTFail("expected .settled before the quiet gap, got \(String(describing: early))")
        }
        // 19:59 with a 3h gap → hour bound not met yet.
        let beforeEight = KitchenSignal.phase(
            plateTimes: [date(-1, 21, 0), date(0, 8, 0), date(0, 16, 45)],
            now: date(0, 19, 59), calendar: cal
        )
        guard case .settled = beforeEight else {
            return XCTFail("expected .settled before 20:00, got \(String(describing: beforeEight))")
        }
    }

    func testFirstPlateToday() {
        XCTAssertEqual(
            KitchenSignal.firstPlateToday(
                plateTimes: [date(-1, 20, 0), date(0, 9, 15), date(0, 12, 0)],
                now: date(0, 14, 0), calendar: cal
            ),
            date(0, 9, 15)
        )
        XCTAssertNil(KitchenSignal.firstPlateToday(
            plateTimes: [date(-1, 20, 0)],
            now: date(0, 14, 0), calendar: cal
        ))
    }

    // MARK: - KitchenSignal.tone (the safety clamp)

    func testToneSaturatesAtFourteenAndCaresAtSixteen() {
        XCTAssertEqual(KitchenSignal.tone(forHours: 11.9), .plain)
        XCTAssertEqual(KitchenSignal.tone(forHours: 12.0), .warm)
        XCTAssertEqual(KitchenSignal.tone(forHours: 13.9), .warm)
        XCTAssertEqual(KitchenSignal.tone(forHours: 14.0), .plain)
        XCTAssertEqual(KitchenSignal.tone(forHours: 15.9), .plain)
        XCTAssertEqual(KitchenSignal.tone(forHours: 16.0), .care)
        XCTAssertEqual(KitchenSignal.tone(forHours: 19.5), .care)
    }

    // MARK: - KitchenSignal.weekStory

    /// Eight steady days: dinner 20:30 + breakfast 08:30 → every
    /// night narratable at 12h, close spread zero.
    func testWeekStorySteadyRhythm() {
        var plates: [Date] = []
        for d in -7...0 {
            plates.append(date(d, 8, 30))
            plates.append(date(d, 20, 30))
        }
        let story = KitchenSignal.weekStory(
            plateTimes: plates, now: date(0, 12, 0), calendar: cal
        )
        XCTAssertNotNil(story)
        XCTAssertEqual(story?.narratedCount, 7)
        XCTAssertEqual(story?.averageHours ?? 0, 12.0, accuracy: 0.01)
        XCTAssertEqual(story?.medianCloseMinutes, 20 * 60 + 30)
        XCTAssertEqual(story?.closeSpreadMinutes, 0)
        XCTAssertEqual(story?.nights.count, 7)
        XCTAssertEqual(story?.nights.first?.daysAgo, 6)
        XCTAssertEqual(story?.nights.last?.daysAgo, 0)
    }

    /// A skipped logging day silences BOTH adjacent nights (no
    /// plates → no morning edge; the 30h+ gap that follows is out of
    /// band) — absence never fabricates.
    func testWeekStoryMissingDaySilencesHonestly() {
        var plates: [Date] = []
        for d in -7...0 where d != -3 {
            plates.append(date(d, 8, 30))
            plates.append(date(d, 20, 30))
        }
        let story = KitchenSignal.weekStory(
            plateTimes: plates, now: date(0, 12, 0), calendar: cal
        )
        XCTAssertEqual(story?.narratedCount, 5)
        let silent = story?.nights.filter { $0.hours == nil }.map(\.daysAgo)
        XCTAssertEqual(Set(silent ?? []), [3, 2])
    }

    func testWeekStoryNeedsTwoNights() {
        let plates = [date(-1, 20, 30), date(0, 8, 30)]
        XCTAssertNil(KitchenSignal.weekStory(
            plateTimes: plates, now: date(0, 12, 0), calendar: cal
        ))
    }

    /// A small-hours close (night-shift pattern: last plate 04:30,
    /// next plate just past the following midnight) folds past 24h in
    /// the median/spread math so it reads as "very late", not "very
    /// early". Without the fold the median here would land at 20:00.
    func testWeekStoryFoldsSmallHoursCloses() {
        let plates: [Date] = [
            date(-6, 12, 0), date(-6, 21, 0),   // night(-5): 21:00 → 09:00 = 12h
            date(-5, 9, 0), date(-5, 22, 0),    // night(-4): 22:00 → 10:00 = 12h
            date(-4, 10, 0),                    // night(-3): 10:00 → 04:30 = 18.5h
            date(-3, 4, 30),                    // night(-2): 04:30 → 00:25 = 19.9h (fold!)
            date(-2, 0, 25), date(-2, 14, 0),   // night(-1): 14:00 → 09:30 = 19.5h
            date(-1, 9, 30), date(-1, 20, 0),   // night(0):  20:00 → 08:30 = 12.5h
            date(0, 8, 30),
        ]
        let story = KitchenSignal.weekStory(
            plateTimes: plates, now: date(0, 12, 0), calendar: cal
        )
        XCTAssertEqual(story?.narratedCount, 6)
        // Sorted closes (minutes): [600, 840, 1200, 1260, 1320, 1710]
        // — the 00:25... 04:30 close folds to 1710. Median = 1260
        // (21:00). Unfolded, the median would have been 1200.
        XCTAssertEqual(story?.medianCloseMinutes, 21 * 60)
        XCTAssertEqual(story?.closeSpreadMinutes, 1710 - 600)
    }

    // MARK: - SleepSignal

    func testSleepBands() {
        XCTAssertEqual(SleepSignal.band(asleepHours: 5.9), .short)
        XCTAssertEqual(SleepSignal.band(asleepHours: 6.0), .light)
        XCTAssertEqual(SleepSignal.band(asleepHours: 6.9), .light)
        XCTAssertEqual(SleepSignal.band(asleepHours: 7.0), .full)
        XCTAssertEqual(SleepSignal.band(asleepHours: 9.2), .full)
    }

    func testSleepDurationWord() {
        XCTAssertEqual(SleepSignal.durationWord(6 * 3600 + 12 * 60), "6h 12m")
        XCTAssertEqual(SleepSignal.durationWord(7 * 3600), "7h")
        XCTAssertEqual(SleepSignal.durationWord(45 * 60), "45m")
        // 6h 59m 40s rounds to the clean hour.
        XCTAssertEqual(SleepSignal.durationWord(6 * 3600 + 59 * 60 + 40), "7h")
    }

    // MARK: - MealMoves

    private func hourly(_ pairs: [Int: Int]) -> [Int] {
        var buckets = [Int](repeating: 0, count: 24)
        for (h, s) in pairs { buckets[h] = s }
        return buckets
    }

    func testMealMoveDetectedInFollowingHour() {
        let moves = MealMoves.detect(
            plateTimes: [date(0, 12, 40)],
            hourlySteps: hourly([13: 600]),
            now: date(0, 15, 0), calendar: cal
        )
        XCTAssertEqual(moves.count, 1)
        XCTAssertEqual(moves.first?.slot, "lunch")
        XCTAssertEqual(moves.first?.steps, 600)
    }

    func testMealMoveWaitsForCompleteHour() {
        // Bucket 13 is still filling at 13:30 — no claim yet.
        XCTAssertTrue(MealMoves.detect(
            plateTimes: [date(0, 12, 40)],
            hourlySteps: hourly([13: 600]),
            now: date(0, 13, 30), calendar: cal
        ).isEmpty)
        // At 14:05 the hour is complete — the claim lands.
        XCTAssertEqual(MealMoves.detect(
            plateTimes: [date(0, 12, 40)],
            hourlySteps: hourly([13: 600]),
            now: date(0, 14, 5), calendar: cal
        ).count, 1)
    }

    func testMealMoveRespectsFloor() {
        XCTAssertTrue(MealMoves.detect(
            plateTimes: [date(0, 12, 40)],
            hourlySteps: hourly([13: 180]),
            now: date(0, 15, 0), calendar: cal
        ).isEmpty)
    }

    func testMealMoveBucketCreditsOnce() {
        // Two plates in the same hour share one following-hour walk.
        let moves = MealMoves.detect(
            plateTimes: [date(0, 12, 10), date(0, 12, 50)],
            hourlySteps: hourly([13: 900]),
            now: date(0, 15, 0), calendar: cal
        )
        XCTAssertEqual(moves.count, 1)
        XCTAssertEqual(moves.first?.plateAt, date(0, 12, 10))
    }

    func testMealMoveLateNightBucketNeverOverflows() {
        XCTAssertTrue(MealMoves.detect(
            plateTimes: [date(0, 23, 30)],
            hourlySteps: hourly([:]),
            now: date(0, 23, 55), calendar: cal
        ).isEmpty)
    }

    func testMealMoveSlots() {
        XCTAssertEqual(MealMoves.slot(forHour: 8), "breakfast")
        XCTAssertEqual(MealMoves.slot(forHour: 12), "lunch")
        XCTAssertEqual(MealMoves.slot(forHour: 16), "your afternoon plate")
        XCTAssertEqual(MealMoves.slot(forHour: 19), "dinner")
    }

    func testMealMoveRejectsMalformedBuckets() {
        XCTAssertTrue(MealMoves.detect(
            plateTimes: [date(0, 12, 40)],
            hourlySteps: [Int](repeating: 500, count: 12),
            now: date(0, 15, 0), calendar: cal
        ).isEmpty)
    }

    // MARK: - WeekRhythm

    func testWeekRhythmWeighCadence() {
        let weighs = [date(-13, 8, 0), date(-9, 8, 0), date(-6, 8, 0),
                      date(-2, 8, 0), date(0, 8, 0),
                      date(0, 20, 0)]  // second same-day log = one day
        let story = WeekRhythm.story(
            weighDates: weighs, plateTimes: [],
            now: date(0, 12, 0), calendar: cal
        )
        XCTAssertEqual(story.weighDayCount, 5)
        XCTAssertEqual(story.weighDayFlags.count, 14)
        XCTAssertEqual(story.weighDayFlags[0], true)    // 13 days ago
        XCTAssertEqual(story.weighDayFlags[13], true)   // today
        XCTAssertEqual(story.weighDayFlags[12], false)  // yesterday
    }

    func testWeekRhythmFirstPlateMedian() {
        var plates: [Date] = []
        let minutes = [(0, 8, 30), (-1, 9, 0), (-2, 9, 15), (-3, 8, 45), (-4, 9, 30)]
        for (d, h, m) in minutes {
            plates.append(date(d, h, m))
            plates.append(date(d, 13, 0))  // later plates never shift the median
        }
        let story = WeekRhythm.story(
            weighDates: [], plateTimes: plates,
            now: date(0, 12, 0), calendar: cal
        )
        XCTAssertEqual(story.plateDayCount, 5)
        XCTAssertEqual(story.firstPlateMedianMinutes, 9 * 60)
    }

    func testWeekRhythmMedianNeedsFourDays() {
        let plates = [date(0, 8, 30), date(-1, 9, 0), date(-2, 9, 15)]
        let story = WeekRhythm.story(
            weighDates: [], plateTimes: plates,
            now: date(0, 12, 0), calendar: cal
        )
        XCTAssertNil(story.firstPlateMedianMinutes)
    }

    func testCadenceWords() {
        XCTAssertNil(WeekRhythm.cadenceWord(weighDayCount: 0))
        XCTAssertNil(WeekRhythm.cadenceWord(weighDayCount: 1))
        XCTAssertEqual(WeekRhythm.cadenceWord(weighDayCount: 2), "finding shape")
        XCTAssertEqual(WeekRhythm.cadenceWord(weighDayCount: 5), "steady")
        XCTAssertEqual(WeekRhythm.cadenceWord(weighDayCount: 9), "daily-ish")
    }

    // MARK: - Sweetness

    private func sugarEntries(_ rows: [(Int, Int, Double)]) -> [(at: Date, sugarG: Double)] {
        rows.map { (at: date($0.0, $0.1, 0), sugarG: $0.2) }
    }

    func testSweetnessNeedsThreeSugarDays() {
        XCTAssertNil(Sweetness.story(
            entries: sugarEntries([(0, 20, 25), (-1, 20, 30)]),
            now: date(0, 21, 0), calendar: cal
        ))
    }

    func testSweetnessStoryEveningPattern() {
        let story = Sweetness.story(
            entries: sugarEntries([
                (0, 20, 24), (-1, 21, 30), (-2, 19, 18),
                (-3, 8, 6),                        // one small morning
            ]),
            now: date(0, 22, 0), calendar: cal
        )
        XCTAssertNotNil(story)
        XCTAssertEqual(story?.sugarDayCount, 4)
        XCTAssertEqual(story?.averageG, 20)        // (24+30+18+6)/4 = 19.5 → 20
        XCTAssertEqual(story?.dominantMoment, "evenings")
        XCTAssertNil(story?.direction)             // prior week is empty
    }

    func testSweetnessDirectionNeedsBothWeeks() {
        // This week eases vs a heavier prior week.
        var rows: [(Int, Int, Double)] = []
        for d in [-1, -2, -3] { rows.append((d, 20, 20)) }
        for d in [-8, -9, -10] { rows.append((d, 20, 40)) }
        let story = Sweetness.story(
            entries: sugarEntries(rows), now: date(0, 21, 0), calendar: cal
        )
        XCTAssertEqual(story?.direction, .easing)

        // Near-identical weeks read steady.
        var steadyRows: [(Int, Int, Double)] = []
        for d in [-1, -2, -3] { steadyRows.append((d, 20, 21)) }
        for d in [-8, -9, -10] { steadyRows.append((d, 20, 20)) }
        let steady = Sweetness.story(
            entries: sugarEntries(steadyRows), now: date(0, 21, 0), calendar: cal
        )
        XCTAssertEqual(steady?.direction, .steady)
    }

    func testSweetnessDayGramsKeepPlatelessDaysNil() {
        let story = Sweetness.story(
            entries: sugarEntries([(0, 20, 24), (-2, 20, 30), (-4, 20, 18)]),
            now: date(0, 22, 0), calendar: cal
        )
        XCTAssertEqual(story?.dayGrams.count, 7)
        XCTAssertNil(story?.dayGrams[5] ?? nil)    // yesterday: no plates
        XCTAssertEqual(story?.dayGrams[6] ?? nil, 24)
    }

    // MARK: - CycleSignal

    func testPeriodStartsDerivedByGap() {
        // Flow on days 1-3 and again 28 days later → two starts;
        // adjacent flow days merge into one episode.
        let flow = [date(-30, 9, 0), date(-29, 9, 0), date(-28, 21, 0),
                    date(-2, 8, 0), date(-1, 8, 0)]
        let starts = CycleSignal.periodStarts(flowDays: flow, calendar: cal)
        XCTAssertEqual(starts.count, 2)
        XCTAssertEqual(starts.first, cal.startOfDay(for: date(-30, 9, 0)))
        XCTAssertEqual(starts.last, cal.startOfDay(for: date(-2, 8, 0)))
    }

    func testCycleReadPhases() {
        // Single start, default 28-day length.
        let start = [date(-2, 8, 0)]                 // day 3
        XCTAssertEqual(
            CycleSignal.read(periodStarts: start, now: date(0, 12, 0), calendar: cal)?.phase,
            .menstrual
        )
        let day10 = [date(-9, 8, 0)]
        XCTAssertEqual(
            CycleSignal.read(periodStarts: day10, now: date(0, 12, 0), calendar: cal)?.phase,
            .follicular
        )
        // p53 RE-PIN: a luteal claim off a SINGLE start is a
        // prediction against a 28-day DEFAULT — no history under it,
        // so the phase stays follicular (silent at the surfaces).
        // With one real start-to-start gap on file the claim stands.
        let day18 = [date(-17, 8, 0)]
        XCTAssertEqual(
            CycleSignal.read(periodStarts: day18, now: date(0, 12, 0), calendar: cal)?.phase,
            .follicular
        )
        let day18WithHistory = [date(-45, 8, 0), date(-17, 8, 0)]
        XCTAssertEqual(
            CycleSignal.read(periodStarts: day18WithHistory, now: date(0, 12, 0), calendar: cal)?.phase,
            .luteal
        )
    }

    func testCycleReadUsesMedianLengthFromHistory() {
        // Starts 62 and 31 days ago and today-ish: diffs 31, 31 →
        // median 31; day 22 of a 31-day cycle (21 gap) is luteal
        // (31-10=21) — with a 28 default it would already be luteal
        // at day 18, so also assert day 17 stays follicular at 31.
        let starts = [date(-48, 8, 0), date(-17, 8, 0)]
        let read = CycleSignal.read(periodStarts: starts, now: date(0, 12, 0), calendar: cal)
        XCTAssertEqual(read?.cycleLengthDays, 31)
        XCTAssertEqual(read?.dayOfCycle, 18)
        XCTAssertEqual(read?.phase, .follicular)   // 18 < 21 at length 31
    }

    func testCycleReadGoesSilentWhenStale() {
        // 50 days since the last start → any phase claim is a guess.
        XCTAssertNil(CycleSignal.read(
            periodStarts: [date(-50, 8, 0)], now: date(0, 12, 0), calendar: cal
        ))
        XCTAssertNil(CycleSignal.read(
            periodStarts: [], now: date(0, 12, 0), calendar: cal
        ))
    }

    // MARK: - ProteinPacing

    private func proteinEntries(_ rows: [(Int, Int, Double)]) -> [(at: Date, proteinG: Double)] {
        rows.map { (at: date($0.0, $0.1, 0), proteinG: $0.2) }
    }

    func testProteinPacingNeedsFourDays() {
        XCTAssertNil(ProteinPacing.story(
            entries: proteinEntries([(0, 8, 30), (-1, 8, 28), (-2, 8, 25)]),
            now: date(0, 20, 0), calendar: cal
        ))
    }

    func testProteinPacingSharesAndFlags() {
        // Evening-heavy week: small mornings, big dinners.
        var rows: [(Int, Int, Double)] = []
        for d in [0, -1, -2, -3, -4] {
            rows.append((d, 8, 8))     // light breakfast protein
            rows.append((d, 19, 40))   // dinner carries it
        }
        let story = ProteinPacing.story(
            entries: proteinEntries(rows), now: date(0, 21, 0), calendar: cal
        )
        XCTAssertEqual(story?.proteinDayCount, 5)
        XCTAssertEqual(story?.eveningShare ?? 0, 40.0 / 48.0, accuracy: 0.001)
        XCTAssertEqual(story?.morningLeads, false)
        XCTAssertEqual(story?.eveningHeavy, true)

        // Morning-forward week flips both flags.
        var front: [(Int, Int, Double)] = []
        for d in [0, -1, -2, -3] {
            front.append((d, 8, 30))
            front.append((d, 19, 25))
        }
        let frontStory = ProteinPacing.story(
            entries: proteinEntries(front), now: date(0, 21, 0), calendar: cal
        )
        XCTAssertEqual(frontStory?.morningLeads, true)
        XCTAssertEqual(frontStory?.eveningHeavy, false)
    }

    // MARK: - BodyLine (the cohesion layer's laws)

    func testEasedDeltaRequiresEstablishedAndVisible() {
        XCTAssertNotNil(BodyLine.easedDelta(established: true, emaDelta7dKg: -0.2))
        XCTAssertNil(BodyLine.easedDelta(established: false, emaDelta7dKg: -0.2))
        XCTAssertNil(BodyLine.easedDelta(established: true, emaDelta7dKg: -0.05))
        // A rising trend NEVER pairs with habits.
        XCTAssertNil(BodyLine.easedDelta(established: true, emaDelta7dKg: 0.3))
    }

    func testWindowBodyLineShapes() {
        XCTAssertEqual(
            BodyLine.window(avgHours: 12.5, narratedCount: 5, easedDisplay: "0.4 lb"),
            "5 steady nights · your trend is down 0.4 lb this week"
        )
        // No eased trend → the mechanism line, numeral-free.
        XCTAssertEqual(
            BodyLine.window(avgHours: 12.5, narratedCount: 5, easedDisplay: nil),
            "a consistent overnight fast keeps next-day hunger lower"
        )
        // The care band owns 16h+ pages — no pairing, no praise.
        XCTAssertNil(BodyLine.window(avgHours: 16.2, narratedCount: 5, easedDisplay: "0.4 lb"))
        XCTAssertNil(BodyLine.window(avgHours: 12.5, narratedCount: 3, easedDisplay: nil))
    }

    func testSleepAndRhythmBodyLines() {
        XCTAssertEqual(
            BodyLine.sleep(avgHours: 6.1, shortNights: 3, easedDisplay: nil),
            "short sleep raises hunger hormones. plan for hungrier days"
        )
        XCTAssertEqual(
            BodyLine.sleep(avgHours: 7.4, shortNights: 0, easedDisplay: "0.3 lb"),
            "full nights this week · your trend is down 0.3 lb alongside"
        )
        XCTAssertNil(BodyLine.sleep(avgHours: 7.4, shortNights: 0, easedDisplay: nil))
        XCTAssertEqual(
            BodyLine.rhythm(weighDayCount: 5, easedDisplay: nil),
            "the trend line gets sharper with every weigh-in"
        )
        XCTAssertNil(BodyLine.rhythm(weighDayCount: 2, easedDisplay: "0.4 lb"))
    }

    func testSweetnessPacingSeasonBodyLines() {
        XCTAssertNotNil(BodyLine.sweetness(direction: .easing, easedDisplay: "0.4 lb"))
        XCTAssertNil(BodyLine.sweetness(direction: .rising, easedDisplay: "0.4 lb"))
        XCTAssertNil(BodyLine.sweetness(direction: .easing, easedDisplay: nil))

        let late = ProteinPacing.Story(
            morningShare: 0.1, afternoonShare: 0.3, eveningShare: 0.6, proteinDayCount: 5
        )
        XCTAssertEqual(
            BodyLine.pacing(story: late),
            "moving some protein to the morning usually cuts evening snacking"
        )

        XCTAssertNotNil(BodyLine.season(phase: .luteal))
        XCTAssertNotNil(BodyLine.season(phase: .menstrual))
        XCTAssertNil(BodyLine.season(phase: .follicular))
    }

    // MARK: - CoachSummary (one move, fixed clinical priority)

    private func summaryInput(
        fast: Double? = 12.5, fastNights: Int = 6,
        sleep: Double? = 7.2, short: Int = 0,
        eveningHeavyPacing: Bool = false,
        sweet: Sweetness.Direction? = .steady,
        weighDays: Int? = 5,
        luteal: Bool = false
    ) -> CoachSummary.Input {
        CoachSummary.Input(
            fastAvgHours: fast, fastNights: fastNights,
            sleepAvgHours: sleep, shortNights: short,
            pacing: eveningHeavyPacing
                ? ProteinPacing.Story(morningShare: 0.1, afternoonShare: 0.3,
                                      eveningShare: 0.6, proteinDayCount: 5)
                : nil,
            sweetDirection: sweet,
            weighDays14: weighDays,
            lutealNow: luteal
        )
    }

    func testCoachSummaryNeedsTwoStories() {
        XCTAssertNil(CoachSummary.compose(.init(
            fastAvgHours: 12, fastNights: 5
        )))
    }

    func testCoachSummaryPriorityLadder() {
        // Sleep debt outranks everything, even an evening-heavy week.
        let sleepPick = CoachSummary.compose(summaryInput(
            short: 3, eveningHeavyPacing: true, sweet: .rising, weighDays: 0
        ))
        XCTAssertEqual(sleepPick?.headline, "this week: guard your sleep.")

        // With sleep fine, protein timing wins over sweetness + cadence.
        let pacingPick = CoachSummary.compose(summaryInput(
            eveningHeavyPacing: true, sweet: .rising, weighDays: 0
        ))
        XCTAssertEqual(pacingPick?.headline, "this week: protein earlier in the day.")

        // A short fast beats sugar drift.
        let fastPick = CoachSummary.compose(summaryInput(
            fast: 10.2, sweet: .rising
        ))
        XCTAssertEqual(fastPick?.headline, "this week: stop eating a little earlier.")

        // Sugar drift beats a thin weigh cadence.
        let sweetPick = CoachSummary.compose(summaryInput(
            sweet: .rising, weighDays: 0
        ))
        XCTAssertEqual(sweetPick?.headline, "this week: cut back on sugar.")

        // Thin cadence alone.
        let cadencePick = CoachSummary.compose(summaryInput(weighDays: 1))
        XCTAssertEqual(cadencePick?.headline, "this week: weigh in at least once.")

        // A steady week earns protection, and luteal rides as a note.
        let steady = CoachSummary.compose(summaryInput(luteal: true))
        XCTAssertEqual(steady?.headline, "this week: change nothing.")
        XCTAssertNotNil(steady?.seasonNote)
        XCTAssertNil(CoachSummary.compose(summaryInput())?.seasonNote)
    }
}
