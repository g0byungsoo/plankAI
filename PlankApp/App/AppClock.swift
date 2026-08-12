import Foundation

// MARK: - AppClock (v25 E8.1)
//
// ONE hour. E8 recorded this as open debt and it is the reason a whole
// branch of the evening close could not be filmed:
//
//   · `HomeView.isEvening` read `Calendar.current.component(.hour)`
//     directly and honoured `--uitest-force-evening` / `--uitest-force-day`.
//   · `TodayStateService.hourOfDay` read the same clock but honoured
//     `--uitest-force-hour N`.
//
// So `--uitest-force-hour 20` made the day composer believe it was
// evening while Home believed it was whatever time the machine said, and
// `--uitest-force-evening` made Home believe it was evening while the
// composer disagreed. Two flags, neither of which moved both. A walker
// could not put the app in a single coherent evening, which is why E8's
// protein-close film covered one branch out of four.
//
// Precedence is deliberate: an explicit hour outranks the coarse flags,
// because a QA engineer who names 20 means 20 — including for
// `isEvening`. That is the specific coupling that was missing.
enum AppClock {

    /// The hour every surface reasons about, 0..23.
    static var hourOfDay: Int {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "--uitest-force-hour"),
           idx + 1 < args.count,
           let h = Int(args[idx + 1]), (0...23).contains(h) {
            return h
        }
        if args.contains("--uitest-force-evening") { return 20 }
        if args.contains("--uitest-force-day") { return 10 }
        #endif
        return Calendar.current.component(.hour, from: .now)
    }

    /// The evening threshold, in one place. 18:00 is the value Home has
    /// used since v11; nothing about it changes here.
    static let eveningHour = 18

    static var isEvening: Bool { hourOfDay >= eveningHour }
}
