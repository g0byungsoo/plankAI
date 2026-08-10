import Foundation

// MARK: - MedicationPatternEngine (app v24 THE REGIMEN)
//
// docs/app_v24 §4 — where medication becomes VALUABLE: day-offset
// joins between her dose marks and everything else she records.
// Pure, floor-gated (≥3 co-occurrences, never a lone coincidence),
// and every sentence speaks TIMING, never causality, never advice
// (the S3 law): "queasiness has followed your last three dose
// days" — an observation about her own record, nothing more.
// Anti-shame by construction: patterns describe days, never her.

enum MedicationPatternEngine {

    struct Inputs: Equatable {
        /// Day keys of TAKEN doses, any order.
        var takenDoseDays: [String] = []
        /// Day keys where a NEW dose (different strength) began.
        var doseChangeDays: [String] = []
        /// (dayKey, symptom raw value) — side-effect entries.
        var symptoms: [SymptomDay] = []
        /// Logged protein by dayKey (logged days only, honest gaps).
        var proteinByDay: [String: Int] = [:]
        /// "today" as a dayKey; the window anchors to it.
        var today: String
        var windowDays: Int = 42

        struct SymptomDay: Equatable {
            let dayKey: String
            let symptom: String
            init(_ dayKey: String, _ symptom: String) {
                self.dayKey = dayKey
                self.symptom = symptom
            }
        }
    }

    struct Observation: Equatable, Identifiable {
        let id: String
        let sentence: String
        let italics: [String]
    }

    // MARK: The read

    /// ≤3 floor-gated observations, strongest first.
    static func observations(_ inputs: Inputs) -> [Observation] {
        var out: [Observation] = []
        if let change = afterDoseChange(inputs) { out.append(change) }
        if let dose = afterDoseDay(inputs) { out.append(dose) }
        if let protein = proteinDayAfter(inputs) { out.append(protein) }
        return Array(out.prefix(3))
    }

    /// "9 of your last 10 doses, marked." — the tile face's quiet
    /// fact. nil below 3 resolved slots (no verdicts on thin data).
    static func adherenceLine(taken: Int, resolved: Int) -> String? {
        guard resolved >= 3, taken >= 0, taken <= resolved else { return nil }
        return "\(taken) of your last \(resolved) doses, marked."
    }

    // MARK: Patterns

    /// The founder's proof case: symptoms clustering AFTER a dose
    /// change. Window: 10 days after the latest change vs the 14
    /// days before it. Fires on ≥2 after AND after > before.
    private static func afterDoseChange(_ inputs: Inputs) -> Observation? {
        guard let change = inputs.doseChangeDays
            .compactMap(day(from:)).max() else { return nil }
        // Only a RECENT change reads (a seam from months ago is
        // settled history).
        guard let today = day(from: inputs.today),
              let daysSince = days(from: change, to: today),
              daysSince >= 2, daysSince <= 21 else { return nil }

        var after: [String: Int] = [:]
        var before = 0
        for entry in inputs.symptoms {
            guard let entryDay = day(from: entry.dayKey),
                  let offset = days(from: change, to: entryDay) else { continue }
            if offset >= 0 && offset <= 10 {
                after[entry.symptom, default: 0] += 1
            } else if offset < 0 && offset >= -14 {
                before += 1
            }
        }
        guard let (symptomKey, count) = after.max(by: { $0.value < $1.value }),
              count >= 2,
              after.values.reduce(0, +) > before,
              let symptom = SideEffectSymptom(rawValue: symptomKey)
        else { return nil }
        return Observation(
            id: "after-change-\(symptomKey)",
            sentence: "\(symptom.nounWord) picked up after the dose changed. worth a mention at your next visit.",
            italics: ["after"]
        )
    }

    /// Symptoms landing on dose day or the day after, when that is
    /// where they cluster (≥3 entries, ≥⅔ inside the window).
    private static func afterDoseDay(_ inputs: Inputs) -> Observation? {
        let doseDays = Set(inputs.takenDoseDays.compactMap(day(from:)))
        guard doseDays.count >= 3 else { return nil }

        var counts: [String: (inWindow: Int, total: Int)] = [:]
        for entry in inputs.symptoms {
            guard let entryDay = day(from: entry.dayKey) else { continue }
            let inWindow = doseDays.contains { dose in
                guard let offset = days(from: dose, to: entryDay) else { return false }
                return offset == 0 || offset == 1
            }
            var slot = counts[entry.symptom] ?? (0, 0)
            slot.total += 1
            if inWindow { slot.inWindow += 1 }
            counts[entry.symptom] = slot
        }
        guard let (symptomKey, slot) = counts
            .filter({ $0.value.total >= 3 })
            .max(by: { $0.value.inWindow < $1.value.inWindow }),
            slot.inWindow >= 3,
            Double(slot.inWindow) / Double(slot.total) >= 0.66,
            let symptom = SideEffectSymptom(rawValue: symptomKey)
        else { return nil }
        return Observation(
            id: "after-dose-\(symptomKey)",
            sentence: "\(symptom.nounWord) has followed your last few dose days. the day after tends to run quieter.",
            italics: ["followed"]
        )
    }

    /// Protein dipping the day after a dose (≥3 logged day-afters,
    /// ≥3 logged baseline days, ≥15% dip).
    private static func proteinDayAfter(_ inputs: Inputs) -> Observation? {
        let doseDays = Set(inputs.takenDoseDays.compactMap(day(from:)))
        guard !doseDays.isEmpty else { return nil }

        var dayAfter: [Double] = []
        var baseline: [Double] = []
        for (key, grams) in inputs.proteinByDay {
            guard let logged = day(from: key) else { continue }
            let isDayAfter = doseDays.contains { dose in
                days(from: dose, to: logged) == 1
            }
            if isDayAfter { dayAfter.append(Double(grams)) }
            else { baseline.append(Double(grams)) }
        }
        guard dayAfter.count >= 3, baseline.count >= 3 else { return nil }
        let afterMean = dayAfter.reduce(0, +) / Double(dayAfter.count)
        let baseMean = baseline.reduce(0, +) / Double(baseline.count)
        guard baseMean > 0, (baseMean - afterMean) / baseMean >= 0.15 else { return nil }
        return Observation(
            id: "protein-day-after",
            sentence: "protein tends to run lower the day after your shot. small plates count double that day.",
            italics: ["day after"]
        )
    }

    // MARK: Date helpers (pure, POSIX)

    private static func day(from key: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: key)
    }

    private static func days(from: Date, to: Date) -> Int? {
        Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: from),
            to: Calendar.current.startOfDay(for: to)
        ).day
    }
}
