import Foundation

// p66 — JKBeatState moved home. It was declared in JKBeatRow.swift
// beside a dead view (deleted this pass, zero call sites); the STATE
// is BeatCompletion's own return vocabulary and lives with the
// authority that mints it.
struct JKBeatState: Equatable {
    var isDone: Bool
    var isAuto: Bool          // autoCompleted → sparkle instead of check
    /// Live progress rows (steps) render a fraction instead of a circle.
    var progress: Double?     // nil = binary row

    static let empty = JKBeatState(isDone: false, isAuto: false, progress: nil)
}


// MARK: - BeatCompletion (p64 — THE DELIGHT LAYER)
//
// ONE authority for "does this beat render as done" — extracted from
// HomeView's view body (the §36 lesson: a rule inside a view body
// cannot be tested, which is why nobody noticed the offered rows
// never consulted it). The p64 founder walk found exactly that
// defect: marking water done wrote a record nothing rendered, and a
// crossed step goal never completed its own row.
//
// Pure. The caller hands it the day's check states and the live
// step count; it answers with the row state every row — owed OR
// offered — must render.

enum BeatCompletion {
    static func state(
        for beat: ProgramDayPrescription,
        checkStates: [String: String],
        stepsToday: Int
    ) -> JKBeatState {
        if case .steps(let goal) = beat {
            let fraction = goal > 0 ? Double(stepsToday) / Double(goal) : 0
            // The measured crossing is the strongest fact — render-only,
            // un-unmarkable (a sensor reading cannot be taken back).
            if fraction >= 1 {
                return JKBeatState(isDone: true, isAuto: true, progress: 1)
            }
            // p65 — HER WORD completes the ACTION (the founder's second
            // walk: the quick-mark and the mark sheet both wrote
            // `complete` and this branch never read it — burst, haptic
            // and sync all fired over a row that stayed an open ask).
            // The sensor keeps owning the NUMBER: a manual mark renders
            // done without inventing a count, and a stale
            // `autoCompleted` row never fakes a crossing the live
            // measurement does not show.
            if checkStates[beat.itemKey] == "complete" {
                return JKBeatState(
                    isDone: true, isAuto: false, progress: min(1, fraction)
                )
            }
            return JKBeatState(
                isDone: false, isAuto: true, progress: min(1, fraction)
            )
        }
        let raw = checkStates[beat.itemKey] ?? "empty"
        // v24 — a SKIPPED dose is resolved, not open: the row
        // compresses like a done one (its note says "not today")
        // instead of asking all day. Honesty lives in the record;
        // gentleness lives here.
        if case .medication = beat, raw == "skipped" {
            return JKBeatState(isDone: true, isAuto: false, progress: nil)
        }
        return JKBeatState(
            isDone: raw == "complete" || raw == "autoCompleted",
            isAuto: raw == "autoCompleted",
            progress: nil
        )
    }

    /// p65 — the check-state fold that CANNOT crash on duplicates.
    /// Two rows for one (plan, day, itemKey) are a real state — one
    /// minted locally, one arriving from the insert-only hydrate
    /// under its own id (any slot two devices both marked) — and the
    /// old `Dictionary(uniqueKeysWithValues:)` asserted on exactly
    /// that, crashing every snapshot from launch. Merge law: a
    /// RESOLVED state (anything but "empty") outranks empty — her
    /// completion is never re-opened by a stale duplicate — and
    /// among resolved states the newest write wins.
    static func checkStates(
        from rows: [(key: String, state: String, updatedAt: Date)]
    ) -> [String: String] {
        var best: [String: (state: String, updatedAt: Date)] = [:]
        for row in rows {
            guard let current = best[row.key] else {
                best[row.key] = (row.state, row.updatedAt)
                continue
            }
            let currentResolved = current.state != "empty"
            let rowResolved = row.state != "empty"
            if rowResolved != currentResolved {
                if rowResolved { best[row.key] = (row.state, row.updatedAt) }
            } else if row.updatedAt > current.updatedAt {
                best[row.key] = (row.state, row.updatedAt)
            }
        }
        return best.mapValues(\.state)
    }

    /// The steps row's title under the same authority as its state:
    /// a measured crossing states the count ("9,214 steps"), her
    /// word states the act ("walked" — never a numeral the sensor
    /// did not measure), an open row keeps the ask.
    static func stepsRowTitle(
        state: JKBeatState, todayCount: Int, goalTitle: String
    ) -> String {
        guard state.isDone else { return goalTitle }
        return state.isAuto ? "\(todayCount.formatted()) steps" : "walked"
    }

    /// p75 — a DONE row is a receipt, not an echo of the ask. The
    /// checklist used to keep the imperative after completion ("add a
    /// small meal, protein first" beside a drawn check — did I do it,
    /// or is it still asking?). The done title states what happened,
    /// and for meals it speaks the RECORD: the day's actual plate
    /// count, the one glance-fact Home held nowhere above the tools.
    /// `plateCount` 0 with a done state = marked by hand, no plate on
    /// file — the receipt claims only the mark, never invents a meal.
    /// Steps rows keep `stepsRowTitle` (measured facts have their own
    /// authority); everything unlisted keeps its ask title untouched.
    static func doneTitle(
        for beat: ProgramDayPrescription,
        askTitle: String,
        plateCount: Int = 0,
        doseIsOral: Bool = false,
        doseCadenceIsDaily: Bool = false
    ) -> String {
        switch beat {
        case .snapMeal:
            if plateCount == 1 { return "1 meal logged" }
            if plateCount > 1 { return "\(plateCount) meals logged" }
            return "meal logged"
        case .workout:
            return "session logged"
        case .weighIn:
            return "weighed in"
        case .breath:
            return "took a minute to breathe"
        case .lesson:
            return "lesson read"
        case .bodyScan:
            return "scan done"
        case .medication:
            if doseIsOral { return "pill taken" }
            return doseCadenceIsDaily ? "dose taken" : "shot taken"
        case .steps, .plank, .water, .measurements:
            return askTitle
        }
    }
}
