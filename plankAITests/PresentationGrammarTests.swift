import XCTest

// Pass 57 — THE PRESENTATION GRAMMAR IS A CHOKEPOINT, MECHANICALLY HELD.
//
// The interaction defects this pass closed (a 0.42 sheet whose record
// button sat below a fold it could not scroll past; `.large` sheets
// with no visible exit; hand-drawn grabbers over a hidden system one;
// sibling records in three different vessels) all came from one soil:
// every call site hand-rolled its presentation modifiers, so a wrong
// combination was always one keystroke away and no reviewer could see
// a rule being broken.
//
// `jeniSheet` / `jeniCover` (JeniKit.swift) are now the only legal
// presenters in the shipping app target. This suite is the same
// mechanism p54 used for the notification chokepoint: walk the source
// tree, strip `#if DEBUG` regions, and fail any bare `.sheet(` or
// `.fullScreenCover(` outside the kit and the named exemptions.
//
// Exemptions carry reasons, and the list is the documentation.
final class PresentationGrammarTests: XCTestCase {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// Bare presenters allowed outside the kit, each with its reason.
    /// A system view controller manages its own presentation chrome —
    /// wrapping it in the grammar's detents/corner/background would
    /// fight the system surface rather than style ours.
    private let exemptions: [String: String] = [
        "PlankApp/DesignSystem/Kit/JeniKit.swift":
            "the grammar itself — its implementation calls the system presenters",
    ]

    /// Every shipping `.swift` under PlankApp with `#if DEBUG` regions
    /// removed (a QA harness presenter is not a shipping presenter —
    /// but a shipping presenter in a file that also has DEBUG blocks
    /// must still be caught, so exclusion is by region, not by file).
    private func shippingSources() throws -> [(path: String, text: String)] {
        let root = repoRoot.appendingPathComponent("PlankApp")
        guard let walker = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: nil
        ) else { return [] }
        var out: [(String, String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            let rel = url.path.replacingOccurrences(of: repoRoot.path + "/", with: "")
            out.append((rel, strippingDebugRegions(text)))
        }
        XCTAssertGreaterThan(out.count, 100, "the source walk found almost nothing — wrong root?")
        return out
    }

    /// Removes `#if DEBUG … #endif` regions, tracking nesting. `#else`
    /// inside a DEBUG conditional re-enables emission (the non-DEBUG
    /// branch ships). Conservative by construction: only conditions
    /// that literally contain "DEBUG" are stripped.
    func strippingDebugRegions(_ text: String) -> String {
        var kept: [Substring] = []
        // Stack entry: are we currently emitting inside this level?
        var stack: [Bool] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#if") {
                let isDebug = trimmed.contains("DEBUG")
                let parentEmitting = stack.last ?? true
                stack.append(parentEmitting && !isDebug)
                continue
            }
            if trimmed.hasPrefix("#elseif") {
                // Treat like a fresh condition at the same level.
                if !stack.isEmpty {
                    let isDebug = trimmed.contains("DEBUG")
                    let parentEmitting = stack.dropLast().last ?? true
                    stack[stack.count - 1] = parentEmitting && !isDebug
                }
                continue
            }
            if trimmed.hasPrefix("#else") {
                if !stack.isEmpty {
                    let parentEmitting = stack.dropLast().last ?? true
                    // The #else branch emits iff the #if branch did not
                    // (and the parent is emitting).
                    stack[stack.count - 1] = parentEmitting && !stack[stack.count - 1]
                }
                continue
            }
            if trimmed.hasPrefix("#endif") {
                if !stack.isEmpty { stack.removeLast() }
                continue
            }
            if stack.last ?? true { kept.append(line) }
        }
        return kept.joined(separator: "\n")
    }

    /// A bare presenter is allowed when its content is a SYSTEM view
    /// controller that manages its own presentation chrome — wrapping
    /// SFSafariViewController or UIActivityViewController in our
    /// detents/corner/grabber would fight the system surface rather
    /// than style ours. Matched within 3 lines of the presenter.
    private let systemControllerMarkers = ["SafariView", "ActivityShareSheet", "PhotoLibraryPicker"]

    private func violations(matching needle: String) throws -> [String] {
        var found: [String] = []
        for (path, text) in try shippingSources() {
            if exemptions[path] != nil { continue }
            let rows = text.split(separator: "\n", omittingEmptySubsequences: false)
            for (idx, row) in rows.enumerated() {
                guard row.contains(needle) else { continue }
                // Prose about presenters is not a presenter.
                if row.trimmingCharacters(in: .whitespaces).hasPrefix("//") { continue }
                let window = rows[idx..<min(idx + 4, rows.count)].joined(separator: "\n")
                if systemControllerMarkers.contains(where: window.contains) { continue }
                found.append("\(path):\(idx + 1)  \(row.trimmingCharacters(in: .whitespaces).prefix(80))")
            }
        }
        return found
    }

    func testEveryShippingSheetGoesThroughTheGrammar() throws {
        let bare = try violations(matching: ".sheet(")
        XCTAssertEqual(bare.count, 0, """
        \(bare.count) bare `.sheet(` presenter(s) outside the grammar. \
        Present through `jeniSheet` (JeniKit.swift) or add a reasoned \
        exemption:
        \(bare.joined(separator: "\n"))
        """)
    }

    func testEveryShippingCoverGoesThroughTheGrammar() throws {
        let bare = try violations(matching: ".fullScreenCover(")
        XCTAssertEqual(bare.count, 0, """
        \(bare.count) bare `.fullScreenCover(` presenter(s) outside the \
        grammar. Present through `jeniCover` (JeniKit.swift) or add a \
        reasoned exemption:
        \(bare.joined(separator: "\n"))
        """)
    }

    /// The grammar's own guarantees, pinned as source facts: the sheet
    /// fold sets detents, a 28pt corner, the paper background, and an
    /// ALWAYS-VISIBLE drag indicator — the affordance language this
    /// pass unified. If someone edits the kit to hide the grabber
    /// again, this is the test that asks them to say why out loud.
    func testTheGrammarKeepsTheGrabberVisible() throws {
        let kit = try String(contentsOf: repoRoot.appendingPathComponent(
            "PlankApp/DesignSystem/Kit/JeniKit.swift"), encoding: .utf8)
        XCTAssertFalse(kit.contains("presentationDragIndicator(.hidden)"),
                       "the grammar hides the grabber — two exit-less sheets came from exactly this")
        XCTAssertEqual(kit.components(separatedBy: "presentationDragIndicator(.visible)").count - 1, 3,
                       "all three jeniSheet folds (isPresented / item / item+heights) assert the visible grabber")
    }

    /// No shipping surface hides the system drag indicator anywhere.
    /// (JKSheetChrome did, globally, which is how `.large` sheets with
    /// no close control and no grabber shipped.)
    func testNoShippingSurfaceHidesTheGrabber() throws {
        var found: [String] = []
        for (path, text) in try shippingSources() {
            if text.contains("presentationDragIndicator(.hidden)") {
                found.append(path)
            }
        }
        XCTAssertEqual(found, [], "surfaces hiding the drag indicator: \(found)")
    }

    /// The stripper itself, pinned — a sweep that silently strips too
    /// much is indistinguishable from a passing one.
    func testDebugStripperKeepsShippingCodeAndDropsDebug() {
        let sample = """
        a
        #if DEBUG
        debugOnly()
        #if os(iOS)
        nestedDebug()
        #endif
        #else
        shippingElse()
        #endif
        b
        #if os(iOS)
        shippingConditional()
        #endif
        """
        let out = strippingDebugRegions(sample)
        XCTAssertTrue(out.contains("a") && out.contains("b"))
        XCTAssertTrue(out.contains("shippingElse()"), "the non-DEBUG branch ships")
        XCTAssertTrue(out.contains("shippingConditional()"))
        XCTAssertFalse(out.contains("debugOnly()"))
        XCTAssertFalse(out.contains("nestedDebug()"))
    }
}
