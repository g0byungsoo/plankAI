import Foundation
import SwiftData
import PlankFood
import PlankSync

// MARK: - MethodInputBuilder
//
// The one place the pure engine meets the live app. Everything here is
// a READ, from the same services the surfaces render from — the food
// journal, `BodyStateService`, `StepsService`, `TodaySnapshot` — so a
// note can never quote a number the screen behind it disagrees with.
//
// Nothing is derived twice: where a value already exists on the snapshot
// (the dose cycle, the program day, suppression) it is passed through
// rather than recomputed, because two derivations of one fact is how the
// `source`/`entryMethod` defect happened.

@MainActor
enum MethodInputBuilder {

    /// How many recent logged days the protein pattern looks at.
    private static let proteinWindowDays = 14
    /// The band inside which a smoothed week counts as flat, in kg.
    private static let flatBandKg = 0.25

    static func input(
        userId: String,
        snapshot: TodaySnapshot,
        clinic: MethodClinicSource.Resolved = .empty,
        in context: ModelContext
    ) -> MethodEngine.Input {
        var out = MethodEngine.Input()
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        // ── the food record ──
        let entries = FoodLogPersister.allEntries(userId: userId)
        out.plateCountEver = entries.count
        out.plateCountToday = entries.filter { $0.loggedAt >= today }.count
        out.proteinEatenTodayG = snapshot.proteinEatenG
        out.proteinFloorG = snapshot.targets.proteinG

        // Protein per DAY, for days that carry a plate. An unlogged day
        // is absent rather than zero: a blank day is not a low-protein
        // day, and folding the two together would make the pattern
        // trigger fire on someone who simply did not open the app.
        var proteinByOffset: [Int: Double] = [:]
        var offsets: Set<Int> = []
        for entry in entries {
            let day = cal.startOfDay(for: entry.loggedAt)
            guard let ago = cal.dateComponents([.day], from: day, to: today).day,
                  ago >= 0, ago < proteinWindowDays else { continue }
            proteinByOffset[ago, default: 0] += entry.protein
            offsets.insert(ago)
        }
        out.loggedDayOffsets = offsets
        out.recentLoggedDayProteins = proteinByOffset
            .sorted { $0.key < $1.key }
            .map { Int($0.value.rounded()) }
        if let floor = out.proteinFloorG, floor > 0 {
            // BEFORE today, so the first-time note can fire on the day it
            // happens. Today's own total is excluded on purpose.
            out.metProteinFloorBeforeToday = proteinByOffset
                .filter { $0.key > 0 }
                .values.contains { Int($0.rounded()) >= floor }
        }

        // v25 E9 — fiber across her recent LOGGED days. Same rule as
        // protein above: days with no plate are absent rather than zero,
        // because a day she did not open the app is not a no-fiber day.
        var fiberByOffset: [Int: Double] = [:]
        for entry in entries {
            let day = cal.startOfDay(for: entry.loggedAt)
            guard let ago = cal.dateComponents([.day], from: day, to: today).day,
                  ago >= 0, ago < proteinWindowDays else { continue }
            fiberByOffset[ago, default: 0] += entry.fiber
        }
        // Three logged days before a mean means anything. One salad does
        // not make a fiber habit and one bad day does not make a gap.
        if fiberByOffset.count >= 3 {
            let mean = fiberByOffset.values.reduce(0, +) / Double(fiberByOffset.count)
            out.recentFiberGPerDay = Int(mean.rounded())
        }

        // v25 E9 — the GI symptoms whose consequence the drug labels
        // name. Read from the SAME store the side-effect logger writes
        // and the chart renders, so a note can never describe a symptom
        // the timeline disagrees with.
        let symptoms = SideEffectLog.entries(userId: userId, limit: 60, in: context)
        func loggedWithin(_ days: Int, _ set: Set<SideEffectSymptom>) -> SideEffectSymptom? {
            let keys = Set((0...days).compactMap { ago -> String? in
                cal.date(byAdding: .day, value: -ago, to: today)
                    .map { TodayStateService.dayKey(for: $0) }
            })
            return symptoms.first { keys.contains($0.dayKey) && set.contains($0.symptom) }?
                .symptom
        }
        out.recentQueasySymptomWord = loggedWithin(
            MethodEngine.queasyRecencyDays, [.nausea, .looseStomach]
        )?.word
        out.loggedConstipationRecently = loggedWithin(
            MethodEngine.constipationRecencyDays, [.constipation]
        ) != nil

        // Which of the last 9 days were weekend days at all. Computed
        // from the calendar rather than assumed, so the trigger holds in
        // every locale's week.
        var weekendOffsets: Set<Int> = []
        for ago in 0..<9 {
            guard let date = cal.date(byAdding: .day, value: -ago, to: today) else { continue }
            if cal.isDateInWeekend(date) { weekendOffsets.insert(ago) }
        }
        out.weekendDayOffsets = weekendOffsets

        // ── weight ──
        let body = BodyStateService.current(userId: userId, in: context)
        if let weight = body.weight {
            out.latestWeightKg = weight.latestKg
            out.emaDelta7dKg = weight.emaDelta7dKg
            out.trendIsEstablished = weight.trendEstablished
            out.weighInCount = weight.emaSeries.count
            out.emaKg = weight.emaSeries.last?.emaKg
            if let first = weight.emaSeries.first?.date,
               let days = cal.dateComponents([.day], from: first, to: .now).day {
                out.daysOfWeightHistory = max(0, days)
            }
            out.flatWeeks = flatWeeks(weight.emaSeries)
        }
        out.previousWeightKg = previousWeighInKg(userId: userId, in: context)

        // ── movement ──
        let steps = StepsService.shared
        let counts28 = steps.dailyCounts28
        if counts28.contains(where: { $0 > 0 }) {
            let recent = Array(counts28.suffix(7))
            out.steps7dMean = recent.isEmpty ? nil : recent.reduce(0, +) / recent.count
            out.steps28dMean = counts28.reduce(0, +) / counts28.count
        }
        out.strengthSessionsLast7 = body.movement?.strengthSessionsLast7 ?? 0

        // ── medication (straight off the snapshot; E2 owns the cycle) ──
        out.doseCadenceIsWeekly = snapshot.hasMedicationRegimen
            && !snapshot.doseCadenceIsDaily
        out.dayInDoseWeek = snapshot.dayInDoseWeek

        // ── lifecycle + context ──
        out.daysSinceLastOpen = snapshot.daysSinceLastOpen
        out.programDay = snapshot.programDay
        out.isMaintenancePhase = snapshot.chapter == .keeping
        out.hourOfDay = AppClock.hourOfDay
        out.numericsSuppressed = snapshot.targets.numericsSuppressed
        out.adequacyNetShowing = snapshot.showsAdequacyNet

        // ── memory + authority ──
        out.shownDaysAgoById = MethodLedger.shownDaysAgoById()
        out.clinicNotes = clinic.notes
        out.clinicSuppressedIds = clinic.suppressedIds
        out.now = .now
        return out
    }

    // MARK: - Derived

    /// Consecutive most-recent whole weeks whose smoothed change stayed
    /// inside the flat band. Reads the EMA rather than raw weigh-ins,
    /// because a plateau is a property of the line.
    private static func flatWeeks(_ series: [WeightTrendChart.EMAPoint]) -> Int {
        guard series.count >= 2 else { return 0 }
        let cal = Calendar.current
        let now = Date.now
        var weeks = 0
        for week in 0..<8 {
            guard let end = cal.date(byAdding: .day, value: -7 * week, to: now),
                  let start = cal.date(byAdding: .day, value: -7 * (week + 1), to: now)
            else { break }
            let inWindow = series.filter { $0.date >= start && $0.date <= end }
            guard let first = inWindow.first, let last = inWindow.last,
                  inWindow.count >= 2 else { break }
            guard abs(last.emaKg - first.emaKg) <= flatBandKg else { break }
            weeks += 1
        }
        return weeks
    }

    /// The weigh-in BEFORE the latest one. The scale-jump note compares
    /// two real readings, not a reading against a smoothed line: what
    /// frightens someone is the difference between two mornings.
    private static func previousWeighInKg(
        userId: String, in context: ModelContext
    ) -> Double? {
        var descriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 2
        let rows = (try? context.fetch(descriptor)) ?? []
        guard rows.count == 2 else { return nil }
        return rows[1].weightKg
    }
}

// MARK: - MethodClinicSource
//
// THE B2B CONTRACT, and only the contract.
//
// A clinician's Method content is `MethodNote` — the same `Codable`
// struct the defaults are, with `authority = .careTeam(attribution:)`.
// That is the whole interface. It means the engine, the ledger, the view,
// the analytics and the chat tool need no second code path for clinic
// content, and a clinic that authors nothing changes nothing.
//
// WHAT THIS RELEASE IMPLEMENTS: the resolution rules (override, add,
// suppress, expire, and what happens when the connection ends), a
// decode path, and a DEBUG injection door so the rules are walkable.
//
// WHAT IT DOES NOT: the authoring side. That lives in the clinician web
// project (`/Users/bko/jeni-health-web`), which already has the
// org/patient/consent model this would hang off — `program_facts` and
// `care_weekly_summaries` are the precedent for how clinic-authored rows
// reach a patient. Building the CMS here would be building the smaller
// half of a system whose larger half is not designed yet. The contract
// is fixed so that when it is, iOS needs a fetch and nothing else.
//
// ─── AUTHORITY RULES ────────────────────────────────────────────────
//
//   DEFAULT    Jeni's note for a trigger, always present.
//   OVERRIDE   a clinic note for the SAME trigger replaces it. Same
//              moment, their words. Never both: two voices on one
//              observation is how a patient ends up weighing generic
//              content against her own clinician's instruction.
//   ADD        a clinic note for a trigger Jeni has none for simply
//              fires. Nothing else changes.
//   SUPPRESS   a clinic can silence a Jeni note by id. It cannot
//              suppress its own — authoring a hole is not a feature.
//              Suppression leaves NO substitute: the moment passes in
//              silence, which is a legitimate clinical decision.
//   EXPIRE     `expiresAt` retires a clinic note. Jeni's default for
//              that trigger returns rather than the moment going quiet,
//              because an expired instruction is not an instruction to
//              stay silent.
//   END        when a clinic connection ends, clinic notes stop being
//              eligible immediately and defaults return. What she was
//              already TOLD stays in the ledger, attributed, forever: a
//              record of instruction belongs to the patient, and
//              deleting it because a relationship ended would be
//              rewriting her history.
//   ATTRIBUTION always rendered, never optional, never colour alone.
//
// ─── WHAT A CLINICIAN CANNOT DO ─────────────────────────────────────
//
// Not a policy, a type: `MethodNote` has no route field, only a `Door`
// token from a closed enum, so clinic content cannot send a patient to
// an arbitrary destination. It has no numbers of its own either — its
// `{tokens}` are filled from HER record by the same renderer, so a
// clinic note cannot state a fact about a patient that the patient's own
// data does not support.

enum MethodClinicSource {

    struct Resolved: Equatable {
        var notes: [MethodNote]
        var suppressedIds: Set<String>
        /// Rendered on any clinic note. Never blank when notes exist.
        var attribution: String

        static let empty = Resolved(notes: [], suppressedIds: [], attribution: "")
    }

    /// The wire shape a clinic would supply. One object, versioned, so a
    /// future fetch is a decode and not a design.
    struct Bundle: Codable, Equatable {
        let version: Int
        let attribution: String
        let notes: [MethodNote]
        let suppressedNoteIds: [String]
        let expiresAt: Date?
    }

    /// Resolve a bundle for right now. A bundle past its own expiry
    /// resolves to nothing at all, which restores every Jeni default.
    static func resolve(_ bundle: Bundle?, now: Date = .now) -> Resolved {
        guard let bundle else { return .empty }
        if let expiry = bundle.expiresAt, expiry <= now { return .empty }
        guard !bundle.attribution.trimmingCharacters(in: .whitespaces).isEmpty else {
            // Unattributed clinic content is refused at the door. A
            // patient must always be able to name who is talking.
            return .empty
        }
        let live = bundle.notes.filter { $0.expiresAt.map { $0 > now } ?? true }
        return Resolved(
            notes: live,
            suppressedIds: Set(bundle.suppressedNoteIds),
            attribution: bundle.attribution
        )
    }

    #if DEBUG
    /// `--uitest-clinic-method` — a walkable clinic bundle. Overrides the
    /// protein note, adds nothing, and suppresses the scale note, so all
    /// three authority rules are visible in one launch.
    static var debugBundle: Bundle? {
        guard ProcessInfo.processInfo.arguments.contains("--uitest-clinic-method")
        else { return nil }
        return Bundle(
            version: 1,
            attribution: "dr. okafor · lakeside metabolic",
            notes: [
                MethodNote(
                    id: "clinic_protein_v1",
                    trigger: .proteinUnderFloorRepeatedly,
                    noticed: "{days} of your last {window} days were under {floor} g.",
                    noticedItalic: ["under {floor} g."],
                    because: "we set that number together at your last visit. hitting it at breakfast is the part that usually needs a plan.",
                    evidence: nil,
                    action: .init(label: "add something with protein", door: .describePlate),
                    followUp: .proteinFloorMetToday,
                    cooldownDays: 7,
                    suppressedForm: "your protein has been landing light most days.",
                    authority: .careTeam(attribution: "dr. okafor · lakeside metabolic")
                )
            ],
            suppressedNoteIds: ["scale_vs_trend_v1"],
            expiresAt: nil
        )
    }
    #endif
}
