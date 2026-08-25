import XCTest

// A scriptable walker-arm for product walks: reads a command script from
// the host filesystem (simulator processes share the host FS), executes
// taps/swipes/typing against the app, and writes device screenshots and
// accessibility dumps straight back to the host directory. Pure session
// QA tooling — nothing here ships, and no product behavior depends on it.
//
// Script grammar, one command per line (# comments allowed):
//   launch --uitest-inapp-qa --uitest-pro-access ...
//   tap <label or identifier>          first hittable match, 8s wait
//   tapxy <x> <y>                      absolute device points
//   press <label> <seconds>            long-press
//   swipe up|down|left|right           on the app
//   swipeon <label> up|down|left|right on a matching element
//   type <text>                        types into the focused field
//   sleep <seconds>
//   shot <name>                        PNG to $JENI_DRIVE_OUT/<name>.png
//   dump <name>                        accessibility tree to <name>.txt
//   alert <button label>               taps a springboard alert button
//   home                               press the device home affordance
//   terminate
final class DriveUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    func testDrive() throws {
        let env = ProcessInfo.processInfo.environment
        guard let scriptPath = env["JENI_DRIVE_SCRIPT"],
              let script = try? String(contentsOfFile: scriptPath, encoding: .utf8) else {
            XCTFail("JENI_DRIVE_SCRIPT missing or unreadable"); return
        }
        let outDir = env["JENI_DRIVE_OUT"] ?? "/tmp/jeni_drive"
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        var log: [String] = []
        defer { try? log.joined(separator: "\n").write(toFile: outDir + "/drive.log", atomically: true, encoding: .utf8) }

        let app = XCUIApplication()

        for rawLine in script.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
            let cmd = parts[0]
            let arg = parts.count > 1 ? parts[1] : ""
            log.append("> \(line)")

            switch cmd {
            case "launch":
                app.launchArguments = arg.split(separator: " ").map(String.init)
                app.launch()
            case "tap":
                if let el = find(app, arg) {
                    if el.isHittable { el.tap() }
                    else {
                        log.append("NOTE tap \(arg): not hittable, coordinate tap")
                        el.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                    }
                } else { log.append("MISS tap \(arg)") }
            case "tapxy":
                let xy = arg.split(separator: " ").compactMap { Double($0) }
                guard xy.count == 2 else { log.append("BAD tapxy \(arg)"); continue }
                app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: xy[0], dy: xy[1])).tap()
            case "press":
                let bits = arg.split(separator: " ")
                let secs = Double(bits.last ?? "1") ?? 1
                let label = bits.dropLast().joined(separator: " ")
                if let el = find(app, label) { el.press(forDuration: secs) } else { log.append("MISS press \(label)") }
            case "swipe":
                switch arg {
                case "up": app.swipeUp()
                case "down": app.swipeDown()
                case "left": app.swipeLeft()
                case "right": app.swipeRight()
                default: log.append("BAD swipe \(arg)")
                }
            case "swipeon":
                let bits = arg.split(separator: " ").map(String.init)
                guard bits.count >= 2 else { log.append("BAD swipeon \(arg)"); continue }
                let dir = bits.last!
                let label = bits.dropLast().joined(separator: " ")
                if let el = find(app, label) {
                    switch dir {
                    case "up": el.swipeUp()
                    case "down": el.swipeDown()
                    case "left": el.swipeLeft()
                    case "right": el.swipeRight()
                    default: break
                    }
                } else { log.append("MISS swipeon \(label)") }
            case "tapfield":
                // Taps the first text input on screen (field else editor).
                // Falls back to a coordinate tap when the element exists but
                // XCUITest deems it non-hittable (custom-overlay z-order).
                let f = app.textFields.firstMatch
                let v = app.textViews.firstMatch
                if f.waitForExistence(timeout: 4) {
                    if f.isHittable { f.tap() }
                    else {
                        log.append("NOTE tapfield: field not hittable, coordinate tap")
                        f.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                    }
                } else if v.waitForExistence(timeout: 2) {
                    if v.isHittable { v.tap() }
                    else { v.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
                } else { log.append("MISS tapfield") }
            case "type":
                if app.keyboards.firstMatch.waitForExistence(timeout: 4) {
                    app.typeText(arg)
                } else {
                    log.append("MISS type (no keyboard): \(arg)")
                }
            case "return":
                if app.keyboards.firstMatch.exists { app.typeText("\n") }
                else { log.append("MISS return (no keyboard)") }
            case "sleep":
                Thread.sleep(forTimeInterval: Double(arg) ?? 1)
            case "shot":
                let png = XCUIScreen.main.screenshot().pngRepresentation
                try? png.write(to: URL(fileURLWithPath: outDir + "/\(arg).png"))
            case "dump":
                try? app.debugDescription.write(toFile: outDir + "/\(arg).txt", atomically: true, encoding: .utf8)
            case "alert":
                let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
                let deadline = Date().addingTimeInterval(6)
                var hit = false
                while Date() < deadline, !hit {
                    let b = springboard.alerts.buttons[arg].firstMatch
                    if b.exists, b.isHittable { b.tap(); hit = true } else { usleep(300_000) }
                }
                if !hit { log.append("MISS alert \(arg)") }
            case "home":
                XCUIDevice.shared.press(.home)
            case "terminate":
                app.terminate()
            default:
                log.append("UNKNOWN \(cmd)")
            }
        }
    }

    /// Finds the first existing element whose identifier or label matches,
    /// searching the common element types, then a contains-fallback.
    private func find(_ app: XCUIApplication, _ key: String, timeout: TimeInterval = 8) -> XCUIElement? {
        let direct: [XCUIElement] = [
            app.buttons[key], app.staticTexts[key], app.textFields[key],
            app.secureTextFields[key], app.otherElements[key], app.images[key],
            app.cells[key], app.switches[key], app.tabBars.buttons[key],
        ]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for el in direct where el.exists { return el }
            let contains = app.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@", key, key)
            ).firstMatch
            if contains.exists { return contains }
            usleep(300_000)
        }
        return nil
    }
}
