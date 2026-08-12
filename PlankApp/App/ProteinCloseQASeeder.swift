#if DEBUG
import Foundation
import SwiftData
import PlankFood

// MARK: - ProteinCloseQASeeder (v25 E8.1)
//
// E8 shipped THE PROTEIN CLOSE — the one line on the evening screen that
// can still change today — and could film exactly one of its four
// branches. Its own record says why: "no QA seed produces an under-floor
// day."
//
// That was true, and the reason is structural rather than lazy. Every
// existing seeder writes a fixed protein number, while the floor is
// DERIVED from the latest weight on file (`TargetsService.proteinTargetG`
// = weight × g/kg, adjusted). So the gap a seed produces is whatever
// arithmetic falls out of two independently-chosen numbers, and the three
// gap branches are cut at 25 g and 40 g. Hitting a chosen branch by
// tuning a seed constant means re-tuning it every time the floor formula,
// the seeded weight, or the protein adjustment moves — which is to say it
// would break silently and nobody would notice, because the failure looks
// like "a different line rendered".
//
// So this seeder works BACKWARDS from the floor. Name the gap you want to
// see; it reads the same floor the surface reads and writes one plate at
// `floor - gap`. The branch is then correct by construction, for any
// weight, any formula and any adjustment.
//
//   --uitest-protein-gap 18    → "18 g would close it" (the ≤25 branch)
//   --uitest-protein-gap 32    → "a shake or a cup of cottage cheese"
//   --uitest-protein-gap 60    → "anything with protein in it helps"
//   --uitest-protein-gap 0     → "protein landed."
//
// Pair with `--uitest-force-hour 20` (which now also makes Home's
// `isEvening` true — see AppClock) to land on the evening close.
//
// HONESTY. This clears TODAY's plates for the user first, because a gap
// is only exact if nothing else is on the day. It writes ONE plate whose
// door is `.words`, which is what it actually is: a sentence, typed by a
// machine instead of a person. It never touches another day, never
// touches the cloud (`pendingUpsert` is not involved — debugSeed is
// device-local and the sync hook does not fire), and it is compiled out
// of Release entirely.
enum ProteinCloseQASeeder {

    static let flag = "--uitest-protein-gap"

    /// The requested gap in grams, or nil when the flag is absent.
    static var requestedGap: Int? {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: flag), idx + 1 < args.count,
              let g = Int(args[idx + 1]), g >= 0 else { return nil }
        return g
    }

    /// Returns a one-line trace for `QASeedTrace`, or nil when it did
    /// nothing. Must run AFTER the weight seed, or there is no floor.
    @MainActor
    @discardableResult
    static func seed(userId: String, in context: ModelContext) -> String? {
        guard let gap = requestedGap else { return nil }
        guard let weightKg = TargetsService.latestWeightKg(userId: userId, in: context)
        else {
            // No weight on file means no floor, which means the protein
            // close renders NOTHING by law (E7). Say so rather than
            // seeding a plate that cannot produce the state asked for.
            return "protein-gap \(gap)g: SKIPPED, no weight on file so there is no floor"
        }
        let floor = TargetsService.proteinTargetG(weightKg: weightKg)
        guard floor > 0 else { return "protein-gap \(gap)g: SKIPPED, floor computed 0" }

        // Today must be empty or the gap is not the gap.
        let cleared = clearToday(userId: userId)

        let protein = max(0, floor - gap)
        if protein == 0 {
            return "protein-gap \(gap)g: floor \(floor)g, cleared \(cleared) plate(s), "
                + "seeded NOTHING (gap ≥ floor is the empty-record state)"
        }

        // kcal at ~4.2 kcal per gram of a mixed protein-forward plate, so
        // the resting nutrition strip and the kcal line read plausibly
        // instead of showing a protein number with no meal around it.
        let kcal = (Double(protein) * 4.2).rounded()
        FoodLogPersister.debugSeed(
            id: "qa-protein-gap-\(TodayStateService.dayKey())-\(gap)",
            userId: userId,
            loggedAt: Date().addingTimeInterval(-3 * 3600),
            kcal: kcal,
            protein: Double(protein),
            carbs: (kcal * 0.30 / 4).rounded(),
            fat: (kcal * 0.25 / 9).rounded(),
            fiber: 6,
            sugar: 5,
            sodiumMg: 420,
            title: "chicken and greens",
            source: EntryMethod.words.rawValue
        )
        return "protein-gap \(gap)g: floor \(floor)g from \(weightKg)kg, "
            + "cleared \(cleared) plate(s), seeded \(protein)g"
    }

    /// Remove every entry logged today for this user. Deliberately
    /// per-entry (not the device-wide wipe) so a walk can seed a gap
    /// WITHOUT losing the week of history the trend surfaces need.
    @MainActor
    private static func clearToday(userId: String) -> Int {
        let start = Calendar.current.startOfDay(for: .now)
        let todays = FoodLogPersister.allEntries(userId: userId)
            .filter { $0.loggedAt >= start }
        for entry in todays { FoodLogPersister.deleteEntry(id: entry.id) }
        return todays.count
    }
}
#endif
