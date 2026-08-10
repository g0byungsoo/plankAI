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

// MARK: - MedicationLabelFacts (v25 E2 — B3)
//
// Per-product LABEL FACTS for the late face (08_E2_BRIEF: "a late
// dose meets facts, not silence"). The discipline:
// - every line is the label's own rule, ATTRIBUTED ("the wegovy
//   label: …") and snapshot-tested verbatim against the FDA
//   prescribing information (source + revision year pinned in
//   MedicationLabelFactsTests — a drifted line is a failing test);
// - the surface always renders `routingLine` beneath — the app
//   never decides, never computes a catch-up, never says "take it
//   now";
// - machine fields (window hours, day-change gap) exist for tests
//   and honest line-selection from HER record (e.g. interruption
//   line only when ≥2 consecutive slots actually missed) — never
//   for dosing arithmetic;
// - compounded products carry NO facts by construction (no FDA
//   label exists) → `compoundedLine`;
// - a product without verified facts renders `unlabeledLine`.
struct MedicationLabelFacts: Equatable, Sendable {

    /// How the label frames a missed dose (the frames differ by
    /// product and must not be homogenized — decision doc pins this).
    enum MissedDoseFrame: Equatable, Sendable {
        /// "within N hours after the missed dose" (ozempic 120 h,
        /// mounjaro/zepbound 96 h).
        case windowAfterSlot(hours: Int)
        /// framed by distance to the NEXT scheduled dose (wegovy:
        /// more than `minHoursToNext` away → the label's take-asap
        /// branch; less → its skip branch).
        case nextDoseDistance(minHoursToNext: Int)
        /// daily products: skip the missed day, resume next dose.
        case dailySkip
    }

    let frame: MissedDoseFrame
    /// The label's whole missed-dose rule, one authored line, both
    /// branches where the label has two. Attributed.
    let missedDoseLine: String
    /// The label's extended-interruption rule (wegovy 2+ consecutive,
    /// saxenda >3 days). nil = the label has none (ozempic,
    /// mounjaro, zepbound — a verified negative fact).
    let interruptionLine: String?
    /// Minimum gap between two doses when moving the dose day, in
    /// hours (weekly products). nil = daily / no label rule.
    let dayChangeMinGapHours: Int?
    /// Attribution + label revision year.
    let sourceLine: String

    /// Rendered under every label fact, always.
    static let routingLine = "your prescriber decides what's right for you."
    /// Compounded products (no FDA label exists — verified).
    static let compoundedLine = "compounded medications don't carry standard fda labeling. your prescriber's instructions rule here."
    /// Catalog products whose label facts aren't verified yet, and
    /// freeform medications.
    static let unlabeledLine = "your medication's own label carries the missed-dose rule."
}

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
    /// v25 E2 — verified label facts for the late face. nil for
    /// compounded (no label exists) and for products not yet
    /// verified against their PI.
    var labelFacts: MedicationLabelFacts? = nil

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
            isCompounded: false, emptyStomach: false,
            labelFacts: MedicationLabelFacts(
                frame: .windowAfterSlot(hours: 120),
                missedDoseLine: "the ozempic label: a missed dose can be taken within 5 days. past that, skip it — next dose on your usual day.",
                interruptionLine: nil,
                dayChangeMinGapHours: 48,
                sourceLine: "from the ozempic prescribing information, 2025"
            )
        ),
        MedicationProduct(
            id: "wegovy", displayName: "wegovy",
            compound: .semaglutide, route: .injection,
            defaultCadence: .weekly,
            doseLadder: [0.25, 0.5, 1.0, 1.7, 2.4], doseUnit: "mg",
            isCompounded: false, emptyStomach: false,
            labelFacts: MedicationLabelFacts(
                frame: .nextDoseDistance(minHoursToNext: 48),
                missedDoseLine: "the wegovy label: next dose more than 2 days away — take the missed one when you can. less than 2 days away — skip it, keep your day.",
                interruptionLine: "two or more missed in a row: the label points you to your prescriber about restarting.",
                dayChangeMinGapHours: 48,
                sourceLine: "from the wegovy prescribing information, 2026"
            )
        ),
        MedicationProduct(
            id: "mounjaro", displayName: "mounjaro",
            compound: .tirzepatide, route: .injection,
            defaultCadence: .weekly,
            doseLadder: [2.5, 5, 7.5, 10, 12.5, 15], doseUnit: "mg",
            isCompounded: false, emptyStomach: false,
            labelFacts: MedicationLabelFacts(
                frame: .windowAfterSlot(hours: 96),
                missedDoseLine: "the mounjaro label: a missed dose can be taken within 4 days. past that, skip it — next dose on your usual day.",
                interruptionLine: nil,
                dayChangeMinGapHours: 72,
                sourceLine: "from the mounjaro prescribing information, 2026"
            )
        ),
        MedicationProduct(
            id: "zepbound", displayName: "zepbound",
            compound: .tirzepatide, route: .injection,
            defaultCadence: .weekly,
            doseLadder: [2.5, 5, 7.5, 10, 12.5, 15], doseUnit: "mg",
            isCompounded: false, emptyStomach: false,
            labelFacts: MedicationLabelFacts(
                frame: .windowAfterSlot(hours: 96),
                missedDoseLine: "the zepbound label: a missed dose can be taken within 4 days. past that, skip it — next dose on your usual day.",
                interruptionLine: nil,
                dayChangeMinGapHours: 72,
                sourceLine: "from the zepbound prescribing information, 2026"
            )
        ),
        MedicationProduct(
            id: "trulicity", displayName: "trulicity",
            compound: .dulaglutide, route: .injection,
            defaultCadence: .weekly,
            doseLadder: [0.75, 1.5, 3.0, 4.5], doseUnit: "mg",
            isCompounded: false, emptyStomach: false,
            labelFacts: MedicationLabelFacts(
                frame: .nextDoseDistance(minHoursToNext: 72),
                missedDoseLine: "the trulicity label: next dose at least 3 days away — take the missed one when you can. closer than that — skip it, keep your day.",
                interruptionLine: nil,
                dayChangeMinGapHours: 72,
                sourceLine: "from the trulicity prescribing information, 2026"
            )
        ),
        MedicationProduct(
            id: "saxenda", displayName: "saxenda",
            compound: .liraglutide, route: .injection,
            defaultCadence: .daily,
            doseLadder: [0.6, 1.2, 1.8, 2.4, 3.0], doseUnit: "mg",
            isCompounded: false, emptyStomach: false,
            labelFacts: MedicationLabelFacts(
                frame: .dailySkip,
                missedDoseLine: "the saxenda label: resume with the next scheduled dose — never an extra or larger dose to make up for one.",
                interruptionLine: "more than 3 days off: the label points you to your prescriber about restarting.",
                dayChangeMinGapHours: nil,
                sourceLine: "from the saxenda prescribing information, 2025"
            )
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
            isCompounded: false, emptyStomach: true,
            labelFacts: MedicationLabelFacts(
                frame: .dailySkip,
                missedDoseLine: "the rybelsus label: skip the missed day. take the next dose tomorrow.",
                interruptionLine: nil,
                dayChangeMinGapHours: nil,
                sourceLine: "from the rybelsus prescribing information, 2025"
            )
        ),
    ]

    /// The late face's fact lines for a product id (nil id = freeform
    /// medication). Compounded → the no-label truth; missing facts →
    /// the honest generic. `consecutiveMissed` selects the
    /// interruption line from HER record (≥2 unresolved slots in a
    /// row) — fact selection, never advice.
    static func lateFactLines(
        productId: String?, consecutiveMissed: Int = 0
    ) -> [String] {
        guard let product = product(id: productId) else {
            return [MedicationLabelFacts.unlabeledLine,
                    MedicationLabelFacts.routingLine]
        }
        if product.isCompounded {
            return [MedicationLabelFacts.compoundedLine,
                    MedicationLabelFacts.routingLine]
        }
        guard let facts = product.labelFacts else {
            return [MedicationLabelFacts.unlabeledLine,
                    MedicationLabelFacts.routingLine]
        }
        var lines = [facts.missedDoseLine]
        if consecutiveMissed >= 2, let interruption = facts.interruptionLine {
            lines.append(interruption)
        }
        lines.append(facts.sourceLine)
        lines.append(MedicationLabelFacts.routingLine)
        return lines
    }

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
