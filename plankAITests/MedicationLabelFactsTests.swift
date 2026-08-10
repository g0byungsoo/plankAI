import XCTest
@testable import plankAI

// MARK: - MedicationLabelFactsTests (v25 E2 — B3)
//
// The era's one genuine safety surface (08_E2_BRIEF risk §1): every
// label fact is pinned VERBATIM against the FDA prescribing
// information it came from. A drifted number or line is a failing
// test, not a silent copy change. Sources verified 2026-08-10:
//   ozempic  — accessdata 209637s035/s037 (2025) §2.1
//   wegovy   — accessdata 218316s002 (2026) §2.4 + Medication Guide
//   mounjaro — accessdata 215866s041 (2026) §2.1
//   zepbound — accessdata 217806s037 (2026) §2.3
//   saxenda  — accessdata 206321s020 (2025) §2.1
//   rybelsus — accessdata 213051s024 (2025) §2.2
//   trulicity — accessdata 125469s065 (2026) §2.3
//   compounded — no FDA label exists (fda.gov compounding Q&A)

final class MedicationLabelFactsTests: XCTestCase {

    private func facts(_ id: String) -> MedicationLabelFacts? {
        MedicationCatalog.product(id: id)?.labelFacts
    }

    // MARK: verified numbers

    func testOzempicWindowAndGap() {
        let f = facts("ozempic")
        XCTAssertEqual(f?.frame, .windowAfterSlot(hours: 120))   // 5 days
        XCTAssertEqual(f?.dayChangeMinGapHours, 48)              // >48 h
        XCTAssertNil(f?.interruptionLine)  // verified negative: no rule in label
    }

    func testWegovyNextDoseFrameAndInterruption() {
        let f = facts("wegovy")
        XCTAssertEqual(f?.frame, .nextDoseDistance(minHoursToNext: 48))
        XCTAssertEqual(f?.dayChangeMinGapHours, 48)  // Medication Guide: ≥2 days
        XCTAssertNotNil(f?.interruptionLine)         // 2+ consecutive missed
    }

    func testTirzepatidePairWindowAndGap() {
        for id in ["mounjaro", "zepbound"] {
            let f = facts(id)
            XCTAssertEqual(f?.frame, .windowAfterSlot(hours: 96), id)  // 4 days
            XCTAssertEqual(f?.dayChangeMinGapHours, 72, id)            // 72 h
            XCTAssertNil(f?.interruptionLine, id)  // verified negative
        }
    }

    func testTrulicityNextDoseFrameNoInterruptionRule() {
        let f = facts("trulicity")
        XCTAssertEqual(f?.frame, .nextDoseDistance(minHoursToNext: 72))
        XCTAssertEqual(f?.dayChangeMinGapHours, 72)  // ≥3 days from last dose
        XCTAssertNil(f?.interruptionLine)  // verified negative: label has none
        XCTAssertEqual(
            f?.missedDoseLine,
            "the trulicity label: next dose at least 3 days away — take the missed one when you can. closer than that — skip it, keep your day."
        )
    }

    func testDailyProductsSkipFrame() {
        XCTAssertEqual(facts("saxenda")?.frame, .dailySkip)
        XCTAssertNotNil(facts("saxenda")?.interruptionLine)  // >3 days → provider
        XCTAssertEqual(facts("rybelsus")?.frame, .dailySkip)
        XCTAssertNil(facts("rybelsus")?.dayChangeMinGapHours)
    }

    // MARK: verbatim line snapshots

    func testMissedDoseLinesVerbatim() {
        XCTAssertEqual(
            facts("ozempic")?.missedDoseLine,
            "the ozempic label: a missed dose can be taken within 5 days. past that, skip it — next dose on your usual day."
        )
        XCTAssertEqual(
            facts("wegovy")?.missedDoseLine,
            "the wegovy label: next dose more than 2 days away — take the missed one when you can. less than 2 days away — skip it, keep your day."
        )
        XCTAssertEqual(
            facts("mounjaro")?.missedDoseLine,
            "the mounjaro label: a missed dose can be taken within 4 days. past that, skip it — next dose on your usual day."
        )
        XCTAssertEqual(
            facts("zepbound")?.missedDoseLine,
            "the zepbound label: a missed dose can be taken within 4 days. past that, skip it — next dose on your usual day."
        )
        XCTAssertEqual(
            facts("saxenda")?.missedDoseLine,
            "the saxenda label: resume with the next scheduled dose — never an extra or larger dose to make up for one."
        )
        XCTAssertEqual(
            facts("rybelsus")?.missedDoseLine,
            "the rybelsus label: skip the missed day. take the next dose tomorrow."
        )
    }

    // MARK: copy laws

    func testEveryFactLineIsAttributedToItsLabel() {
        for product in MedicationCatalog.products {
            guard let f = product.labelFacts else { continue }
            XCTAssertTrue(
                f.missedDoseLine.hasPrefix("the \(product.displayName) label:"),
                "\(product.id) missed-dose line must carry its attribution"
            )
            XCTAssertTrue(
                f.sourceLine.contains(product.displayName),
                "\(product.id) source line must name its label"
            )
        }
    }

    func testNoFactLineCommandsAnImmediateDose() {
        for product in MedicationCatalog.products {
            guard let f = product.labelFacts else { continue }
            let all = [f.missedDoseLine, f.interruptionLine ?? "", f.sourceLine]
                .joined(separator: " ")
            XCTAssertFalse(all.contains("take it now"), product.id)
            XCTAssertFalse(all.contains("right now"), product.id)
        }
    }

    func testNoFactLineCarriesADoseAmount() {
        for product in MedicationCatalog.products {
            guard let f = product.labelFacts else { continue }
            let all = [f.missedDoseLine, f.interruptionLine ?? "", f.sourceLine]
                .joined(separator: " ")
            XCTAssertFalse(all.contains("mg"), product.id)
        }
    }

    func testCompoundedProductsCarryNoLabelFactsByConstruction() {
        for product in MedicationCatalog.products where product.isCompounded {
            XCTAssertNil(product.labelFacts, product.id)
        }
    }

    // MARK: the late face's composed lines

    func testLateFactLinesForLabeledProduct() {
        let lines = MedicationCatalog.lateFactLines(productId: "ozempic")
        XCTAssertEqual(lines.first, facts("ozempic")?.missedDoseLine)
        XCTAssertEqual(lines.last, MedicationLabelFacts.routingLine)
        XCTAssertTrue(lines.contains(facts("ozempic")!.sourceLine))
    }

    func testInterruptionLineNeedsTwoConsecutiveMissedFromHerRecord() {
        let quiet = MedicationCatalog.lateFactLines(
            productId: "wegovy", consecutiveMissed: 1
        )
        XCTAssertFalse(quiet.contains(facts("wegovy")!.interruptionLine!))
        let interrupted = MedicationCatalog.lateFactLines(
            productId: "wegovy", consecutiveMissed: 2
        )
        XCTAssertTrue(interrupted.contains(facts("wegovy")!.interruptionLine!))
    }

    func testCompoundedRendersTheNoLabelTruth() {
        let lines = MedicationCatalog.lateFactLines(
            productId: "compounded-semaglutide"
        )
        XCTAssertEqual(lines, [
            MedicationLabelFacts.compoundedLine,
            MedicationLabelFacts.routingLine,
        ])
    }

    func testFreeformRendersTheHonestGeneric() {
        let freeform = MedicationCatalog.lateFactLines(productId: nil)
        XCTAssertEqual(freeform, [
            MedicationLabelFacts.unlabeledLine,
            MedicationLabelFacts.routingLine,
        ])
    }

    func testEveryNonCompoundedCatalogProductCarriesVerifiedFacts() {
        for product in MedicationCatalog.products where !product.isCompounded {
            XCTAssertNotNil(product.labelFacts, product.id)
        }
    }

    func testRoutingLineAlwaysCloses() {
        for id in [nil, "ozempic", "wegovy", "compounded-tirzepatide",
                   "trulicity", "rybelsus"] {
            XCTAssertEqual(
                MedicationCatalog.lateFactLines(productId: id).last,
                MedicationLabelFacts.routingLine, id ?? "freeform"
            )
        }
    }
}
