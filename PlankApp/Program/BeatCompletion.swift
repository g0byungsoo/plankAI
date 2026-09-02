import Foundation

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
            return JKBeatState(
                isDone: fraction >= 1,
                isAuto: true,
                progress: min(1, fraction)
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
}
