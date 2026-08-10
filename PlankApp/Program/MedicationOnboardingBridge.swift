import Foundation

// MARK: - MedicationOnboardingBridge (app v24 THE REGIMEN)
//
// The consult's medication answers → ONE regimen spec, pure and
// testable. The rule that matters: a regimen exists only when at
// least one CONCRETE fact landed (product, dose, shot day, or an
// explicit reminder choice). All-skips build nothing — the v8
// evening shot-day ask keeps its job for her, and no hollow row
// ever suppresses it.

enum MedicationOnboardingBridge {

    struct Answers: Equatable {
        var route: String = ""        // "shots" | "pills" | "not_sure" | ""
        var product: String = ""      // catalog id | "other" | "not_sure" | ""
        var dose: String = ""         // "0.5" | "not_sure" | ""
        var shotDayWord: String = ""  // "mon"…"sun" | ""
        var hour: String = ""         // "morning" | "midday" | "evening" | "none" | ""

        static func read(_ d: UserDefaults = .standard) -> Answers {
            Answers(
                route: d.string(forKey: "onb_med_route") ?? "",
                product: d.string(forKey: "onb_med_product") ?? "",
                dose: d.string(forKey: "onb_med_dose") ?? "",
                shotDayWord: d.string(forKey: "onb_v5_shot_day") ?? "",
                hour: d.string(forKey: "onb_med_hour") ?? ""
            )
        }
    }

    static func spec(from answers: Answers) -> RegimenService.SelfRegimenSpec? {
        let product = MedicationCatalog.product(id: answers.product)
        let doseValue = Double(answers.dose)
        let anchor = RegimenService.isoWeekday(fromWord: answers.shotDayWord)
        let hourChosen = ["morning", "midday", "evening"].contains(answers.hour)

        // At least one concrete fact, or nothing is built.
        let concrete = product != nil || doseValue != nil || anchor != nil
            || hourChosen || answers.hour == "none"
        guard concrete else { return nil }

        var spec = RegimenService.SelfRegimenSpec()
        spec.productId = product?.id
        spec.displayName = product?.displayName ?? ""

        let route: MedicationProduct.Route =
            product?.route ?? (answers.route == "pills" ? .oral : .injection)
        spec.route = route.rawValue

        let cadence: MedicationProduct.Cadence =
            product?.defaultCadence ?? (answers.route == "pills" ? .daily : .weekly)
        spec.scheduleRule = cadence.scheduleRule
        spec.anchorWeekday = cadence == .weekly ? anchor : nil

        switch answers.hour {
        case "morning": spec.timeOfDayMinutes = 8 * 60
        case "midday": spec.timeOfDayMinutes = 12 * 60
        case "evening": spec.timeOfDayMinutes = 18 * 60
        default: spec.timeOfDayMinutes = nil
        }
        spec.reminderEnabled = hourChosen

        spec.doseValue = doseValue
        spec.doseUnit = doseValue == nil ? nil : (product?.doseUnit ?? "mg")
        return spec
    }
}
