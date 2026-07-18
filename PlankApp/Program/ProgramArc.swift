import Foundation

// MARK: - ProgramArc (app v4 spine)
//
// docs/app_v4/01_PROGRAM.md. The program's shape as an object: named
// phases over the plan's weeks, per chapter. Before v4 the "program"
// was day math (a 7-slot rotation stamped totalDays times) — nothing
// existed to render as "the plan," which is why the app couldn't
// answer "how does today connect to the bigger picture."
//
// Pure + deterministic: same (week, totalWeeks, chapter) → same
// phase. No I/O. Table-tested in ProgramArcTests across plan lengths.
//
// Evidence anchors (docs/app_v4/research/PROGRAM_STRUCTURE.md):
// stability-first weeks 1-2 (Kiernan 2013); the week 3-4 early-
// response gate (Unick — "early rescue," never a verdict); the
// plateau as adherence decay → a schedulable support phase (Hall);
// a 2-week stability hold before graduation (Kiernan again);
// keeping's settle = the first six weeks (regain half-life ~23wk);
// on-medication runs open-ended (medication timelines are hers).

// MARK: - ArcPhase

struct ArcPhase: Equatable {
    enum Key: String {
        // losing
        case findingSteady = "finding_steady"
        case earlyRead = "early_read"
        case build
        case bend
        case lastStretch = "last_stretch"
        case hold
        // on-medication
        case arriving
        case practice
        // keeping
        case settle
        case kept
    }

    let key: Key
    /// 1-indexed week range within the plan. Open-ended phases run
    /// to Int.max (on-medication practice, keeping kept).
    let weeks: ClosedRange<Int>

    var isOpenEnded: Bool { weeks.upperBound == Int.max }

    /// The phase name — lowercase by voice contract; the serif word
    /// on the arc ribbon and the journey masthead.
    var name: String {
        switch key {
        case .findingSteady: return "finding steady"
        case .earlyRead:     return "the early read"
        case .build:         return "the build"
        case .bend:          return "the bend"
        case .lastStretch:   return "the last stretch"
        case .hold:          return "the hold"
        case .arriving:      return "arriving"
        case .practice:      return "the practice"
        case .settle:        return "the settle"
        case .kept:          return "kept"
        }
    }

    /// One sentence of intent — what this phase is FOR. Renders on
    /// the journey and seeds the reading's arc awareness.
    var line: String {
        switch key {
        case .findingSteady:
            return "settle into the rhythm first."
        case .earlyRead:
            return "your first data teaches the plan."
        case .build:
            return "one focus per week. they stack."
        case .bend:
            return "the plateau phase. planned for."
        case .lastStretch:
            return "we count down now."
        case .hold:
            return "practice holding at goal before it's done."
        case .arriving:
            return "the medication does its part. we cover the rest."
        case .practice:
            return "strength and rhythm blocks, rolling."
        case .settle:
            return "six weeks to learn your new normal and draw the band around it."
        case .kept:
            return "inside the band."
        }
    }
}

// MARK: - ProgramArc

enum ProgramArc {

    /// Weeks in a plan, 1-indexed, partial final week counts.
    static func totalWeeks(totalDays: Int) -> Int {
        max(1, Int(ceil(Double(max(totalDays, 1)) / 7.0)))
    }

    /// The full phase table for a plan. Every week 1...totalWeeks is
    /// covered by exactly one phase (open-ended chapters extend the
    /// final phase to Int.max). Table-tested for coverage + order.
    static func phases(totalWeeks: Int, chapter: Chapter) -> [ArcPhase] {
        switch chapter {
        case .onMedication:
            if totalWeeks <= 2 {
                return [ArcPhase(key: .arriving, weeks: 1...Int.max)]
            }
            return [
                ArcPhase(key: .arriving, weeks: 1...2),
                ArcPhase(key: .practice, weeks: 3...Int.max),
            ]
        case .keeping:
            if totalWeeks <= 6 {
                return [ArcPhase(key: .settle, weeks: 1...Int.max)]
            }
            return [
                ArcPhase(key: .settle, weeks: 1...6),
                ArcPhase(key: .kept, weeks: 7...Int.max),
            ]
        case .losing:
            return losingPhases(totalWeeks: totalWeeks)
        }
    }

    /// The losing chapter's skeleton, scaled to plan length with two
    /// fixed clocks (steady = weeks 1-2, the read = weeks 3-4) and
    /// end-anchored hold/stretch. The bend exists only when the plan
    /// is long enough to reach it (~week 9+); shorter plans meet
    /// plateau support through the data-triggered overlay instead.
    private static func losingPhases(totalWeeks W: Int) -> [ArcPhase] {
        // Tiny plans: keep the grammar, drop the middle.
        switch W {
        case ...1:
            return [ArcPhase(key: .findingSteady, weeks: 1...1)]
        case 2:
            return [
                ArcPhase(key: .findingSteady, weeks: 1...1),
                ArcPhase(key: .hold, weeks: 2...2),
            ]
        case 3:
            return [
                ArcPhase(key: .findingSteady, weeks: 1...1),
                ArcPhase(key: .build, weeks: 2...2),
                ArcPhase(key: .hold, weeks: 3...3),
            ]
        case 4:
            return [
                ArcPhase(key: .findingSteady, weeks: 1...1),
                ArcPhase(key: .earlyRead, weeks: 2...2),
                ArcPhase(key: .build, weeks: 3...3),
                ArcPhase(key: .hold, weeks: 4...4),
            ]
        default:
            break
        }

        let holdLen = W >= 10 ? 2 : 1
        let stretchLen = max(1, Int((Double(W) * 0.15).rounded()))
        let readEnd = W >= 8 ? 4 : 3

        let holdStart = W - holdLen + 1
        var stretchStart = holdStart - stretchLen
        let buildStart = readEnd + 1

        // The bend: entered by clock around week 9-13 (~month 3),
        // only when at least two build weeks precede it and two bend
        // weeks fit before the stretch.
        let bendStart = max(9, min(13, Int((Double(W) * 0.55).rounded())))
        var phases: [ArcPhase] = [
            ArcPhase(key: .findingSteady, weeks: 1...2),
            ArcPhase(key: .earlyRead, weeks: 3...readEnd),
        ]

        if bendStart >= buildStart + 2, stretchStart - bendStart >= 2 {
            phases.append(ArcPhase(key: .build, weeks: buildStart...(bendStart - 1)))
            phases.append(ArcPhase(key: .bend, weeks: bendStart...(stretchStart - 1)))
        } else {
            // No room for a clock-bend — build runs to the stretch.
            // On the tightest plans the stretch itself collides with
            // the hold; the build absorbs it (coverage law > phase
            // count — the range must never invert).
            stretchStart = max(buildStart + 1, stretchStart)
            phases.append(ArcPhase(
                key: .build,
                weeks: buildStart...(min(stretchStart, holdStart) - 1)
            ))
        }

        if stretchStart < holdStart {
            phases.append(ArcPhase(key: .lastStretch, weeks: stretchStart...(holdStart - 1)))
        }
        phases.append(ArcPhase(key: .hold, weeks: holdStart...W))
        return phases
    }

    /// The phase a given week sits in. `emaFlatWeeks` overlays the
    /// data-triggered bend: an EMA flat ≥3 weeks during the build
    /// names the bend early (the plateau is adherence decay, not
    /// metabolism — support, not silence). Clamped to the table
    /// otherwise.
    static func phase(
        week: Int,
        totalWeeks: Int,
        chapter: Chapter,
        emaFlatWeeks: Int = 0
    ) -> ArcPhase {
        let table = phases(totalWeeks: totalWeeks, chapter: chapter)
        let clamped = max(1, week)
        let found = table.first { $0.weeks.contains(clamped) } ?? table[table.count - 1]
        if chapter == .losing, found.key == .build, emaFlatWeeks >= 3 {
            return ArcPhase(key: .bend, weeks: found.weeks)
        }
        return found
    }

    // MARK: - Position language

    // v5: leadLine ("6 kept" / "44 to go") retired — the becoming
    // eyebrow renders position + phase directly, with the midpoint
    // countdown (Koo & Fishbach) computed at the render site.

    /// The quiet ordinal ("week 2 of 15" / open-ended "week 7").
    static func ordinalLine(week: Int, totalWeeks: Int, chapter: Chapter) -> String {
        switch chapter {
        case .losing: return "week \(week) of \(totalWeeks)"
        case .onMedication, .keeping: return "week \(week)"
        }
    }
}
