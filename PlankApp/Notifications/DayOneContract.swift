import Foundation

// MARK: - DayOneContract (pass 52 — THE FIRST DAY)
//
// The day-one contract: after her FIRST record files, one card states
// what pays out tomorrow — "the morning read is built from what you
// give me today" — and THAT is the notification moment. The system ask
// rides a product promise she just watched come true, never a launch
// dialog (50 §5.5's design; R1's close).
//
// Laws, pinned by DayOneContractTests:
//   · The card renders ONLY while the OS ask is still open
//     (.notDetermined). A denied OS state is respected silently —
//     no punishment, no fake error, no Settings chase.
//   · It renders only when a record exists today: the promise must be
//     ABOUT something she just did, or it is a nag with a bow on it.
//   · It is answered at most once, ever. Yes or no, the card is gone.
//   · The GLP-1 sentence about the shot-day nudge appears only for a
//     medicated user who asked for reminders in the consult.
//
// The pure decision is separated from storage so the whole contract is
// table-testable; HomeView feeds it live state.
enum DayOneContract {

    static let answeredKey = "dayOne.contract.answeredAt"

    struct Inputs: Equatable {
        /// She already answered the card (either way), ever.
        var answered: Bool
        /// The OS authorization is still undetermined — the one state
        /// where a system ask can still be made.
        var osAskAvailable: Bool
        /// Records she put on file today (plates + weigh-ins + doses).
        var recordsToday: Int
        /// GLP-1 current + a consult reminder word other than "none".
        var wantsDoseReminder: Bool
    }

    enum Decision: Equatable {
        case hidden
        case show(line: String, ask: String)
    }

    static func decide(_ i: Inputs) -> Decision {
        guard !i.answered, i.osAskAvailable, i.recordsToday > 0 else {
            return .hidden
        }
        let line = "that's on file. tomorrow's morning read is built from what you give me today."
        let ask = i.wantsDoseReminder
            ? "want it as a quiet note? your shot-day nudge rides the same switch."
            : "want it as a quiet note?"
        return .show(line: line, ask: ask)
    }

    // MARK: - Storage (device-scoped, deliberately NOT identity-swept)
    //
    // The contract is about THIS phone's notification permission — an
    // OS fact, not an account fact — so it survives sign-out the same
    // way the permission itself does.

    static var answered: Bool {
        UserDefaults.standard.object(forKey: answeredKey) != nil
    }

    static func markAnswered(now: Date = .now) {
        guard UserDefaults.standard.object(forKey: answeredKey) == nil else { return }
        UserDefaults.standard.set(now, forKey: answeredKey)
    }
}
