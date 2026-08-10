import Foundation

// MARK: - MedicationCatalog (app v24 THE REGIMEN)
//
// docs/app_v24/00_REGIMEN.md §3.1 — the static, versioned product
// data the medication platform composes from. The catalog is CODE
// (testable, shippable, offline) — a future served catalog may
// override by id through CareProtocolStore's pattern, but nothing
// waits on a server.
//
// Laws it carries:
// - Dose ladders are FDA label strengths, ascending — a picker of
//   FACTS she declares from. Never a recommendation, never a cap:
//   custom is always allowed, and the app never authors dose
//   advice (v8 law, unchanged).
// - Adding a future medication = adding ONE entry. Route + cadence
//   are data, so a daily pill or a future weekly oral composes
//   with zero new architecture.
// - Names render only where SHE reads them; never in notification
//   payloads, never in analytics (the stigma floor). Analytics may
//   carry `compound` + `route` — categorical, never the brand.

struct MedicationProduct: Identifiable, Equatable, Sendable {
    enum Compound: String, Sendable {
        case semaglutide, tirzepatide, liraglutide, dulaglutide, other
    }

    enum Route: String, Sendable {
        case injection, oral

        /// The dose noun surfaces speak ("take today's shot" /
        /// "take today's pill").
        var doseNoun: String { self == .oral ? "pill" : "shot" }
    }

    enum Cadence: String, Sendable {
        case weekly, daily

        /// The RegimenPlanRecord.scheduleRule this cadence writes.
        var scheduleRule: String {
            self == .weekly ? "weeklyAnchor" : "daily"
        }
    }

    let id: String
    /// Lowercase, the jeni voice ("ozempic", "compounded semaglutide").
    let displayName: String
    let compound: Compound
    let route: Route
    let defaultCadence: Cadence
    /// Label strengths, ascending. Empty = custom-led (freeform).
    let doseLadder: [Double]
    let doseUnit: String
    let isCompounded: Bool
    /// Oral semaglutide's label rhythm (empty stomach, water, then
    /// a quiet half hour) — drives reminder copy, nothing else.
    let emptyStomach: Bool

    /// "0.25" / "2.5" — trimmed, no trailing zeros, for chips.
    static func doseWord(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 100 {
            return String(format: "%.0f", value)
        }
        return String(format: "%g", value)
    }
}

enum MedicationCatalog {
    static let version = 1

    /// Every supported product, injection-first, brand before
    /// compounded — the order pickers render.
    static let products: [MedicationProduct] = [
        MedicationProduct(
            id: "ozempic", displayName: "ozempic",
            compound: .semaglutide, route: .injection,
            defaultCadence: .weekly,
            doseLadder: [0.25, 0.5, 1.0, 2.0], doseUnit: "mg",
            isCompounded: false, emptyStomach: false
        ),
        MedicationProduct(
            id: "wegovy", displayName: "wegovy",
            compound: .semaglutide, route: .injection,
            defaultCadence: .weekly,
            doseLadder: [0.25, 0.5, 1.0, 1.7, 2.4], doseUnit: "mg",
            isCompounded: false, emptyStomach: false
        ),
        MedicationProduct(
            id: "mounjaro", displayName: "mounjaro",
            compound: .tirzepatide, route: .injection,
            defaultCadence: .weekly,
            doseLadder: [2.5, 5, 7.5, 10, 12.5, 15], doseUnit: "mg",
            isCompounded: false, emptyStomach: false
        ),
        MedicationProduct(
            id: "zepbound", displayName: "zepbound",
            compound: .tirzepatide, route: .injection,
            defaultCadence: .weekly,
            doseLadder: [2.5, 5, 7.5, 10, 12.5, 15], doseUnit: "mg",
            isCompounded: false, emptyStomach: false
        ),
        MedicationProduct(
            id: "trulicity", displayName: "trulicity",
            compound: .dulaglutide, route: .injection,
            defaultCadence: .weekly,
            doseLadder: [0.75, 1.5, 3.0, 4.5], doseUnit: "mg",
            isCompounded: false, emptyStomach: false
        ),
        MedicationProduct(
            id: "saxenda", displayName: "saxenda",
            compound: .liraglutide, route: .injection,
            defaultCadence: .daily,
            doseLadder: [0.6, 1.2, 1.8, 2.4, 3.0], doseUnit: "mg",
            isCompounded: false, emptyStomach: false
        ),
        MedicationProduct(
            id: "compounded-semaglutide",
            displayName: "compounded semaglutide",
            compound: .semaglutide, route: .injection,
            defaultCadence: .weekly,
            doseLadder: [0.25, 0.5, 1.0, 1.7, 2.5], doseUnit: "mg",
            isCompounded: true, emptyStomach: false
        ),
        MedicationProduct(
            id: "compounded-tirzepatide",
            displayName: "compounded tirzepatide",
            compound: .tirzepatide, route: .injection,
            defaultCadence: .weekly,
            doseLadder: [2.5, 5, 7.5, 10, 12.5, 15], doseUnit: "mg",
            isCompounded: true, emptyStomach: false
        ),
        MedicationProduct(
            id: "rybelsus", displayName: "rybelsus",
            compound: .semaglutide, route: .oral,
            defaultCadence: .daily,
            doseLadder: [3, 7, 14], doseUnit: "mg",
            isCompounded: false, emptyStomach: true
        ),
    ]

    static func product(id: String?) -> MedicationProduct? {
        guard let id else { return nil }
        return products.first { $0.id == id }
    }

    static func products(route: MedicationProduct.Route) -> [MedicationProduct] {
        products.filter { $0.route == route }
    }

    /// The render name for a regimen row: catalog name, else her
    /// freeform words, else the quiet generic.
    static func renderName(productId: String?, displayName: String) -> String {
        if let product = product(id: productId) { return product.displayName }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "your medication" : trimmed.lowercased()
    }
}
