import Foundation
import SwiftData
import PlankSync

// MARK: - PenSupply (p70)
//
// THE PEN, COUNTED. A weekly injector's most common real-world failure
// is not a missed dose — it is a pen that runs out before the refill
// is in hand. The record already knows every dose she marks; what it
// never knew is what the pen HOLDS.
//
// The whole feature is one stated fact and one subtraction:
//
//   · SHE states how many doses are left in the pen she's using
//     ("4"), once, on the regimen page. That statement is hers,
//     stamped with its moment.
//   · Everything else DERIVES: remaining = her count minus the doses
//     she marked taken after the statement. There is no counter to
//     decrement, no state to drift — restating replaces the fact,
//     marking a dose moves the answer, un-marking moves it back.
//   · When the rhythm has a fixed interval, the last on-hand dose has
//     a civil day, and jeni can say it. twiceWeekly and as-needed
//     rhythms get the count only — a run-out DATE on a rhythm without
//     a fixed interval would be an invented denominator.
//
// The boundary holds: jeni records her count, does her arithmetic and
// names the logistics ("a refill keeps the rhythm"). It never advises
// a dose, never sources medication, never urges.
//
// Storage is the `move.manual.v1` shape exactly: device-scoped
// UserDefaults, customer-authored, registered in
// LocalHandoffInventory and the sign-out sweep — a stranger's phone
// must not know her pen, and hers forgets it at sign-out (the §35/§38
// trade, accepted again).

@MainActor
enum PenSupply {

    static let storageKey = "regimen.supply.v1"

    struct Statement: Codable, Equatable {
        /// Doses left in the pen she is using, as SHE counted them.
        var dosesOnHand: Int
        /// The instant she said so — doses marked taken after this
        /// moment draw the count down; earlier ones were already in it.
        var statedAt: Date
    }

    struct Read: Equatable {
        /// Her count minus the doses recorded since — never below 0.
        var remaining: Int
        /// The civil day the LAST on-hand dose lands at the current
        /// rhythm. nil when the rhythm has no fixed interval, when the
        /// next slot is unknown, or when the pen is already done.
        var lastDoseDay: Date?
    }

    // MARK: the stated fact

    static func statement(defaults: UserDefaults = .standard) -> Statement? {
        guard let data = defaults.data(forKey: storageKey),
              let s = try? JSONDecoder().decode(Statement.self, from: data),
              s.dosesOnHand > 0
        else { return nil }
        return s
    }

    static func state(
        _ dosesOnHand: Int, at: Date = .now,
        defaults: UserDefaults = .standard
    ) {
        guard dosesOnHand > 0, dosesOnHand <= 50 else { return }
        let s = Statement(dosesOnHand: dosesOnHand, statedAt: at)
        if let data = try? JSONEncoder().encode(s) {
            defaults.set(data, forKey: storageKey)
        }
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }

    // MARK: the derivation (pure)

    /// The count and the runway. `takenAfterStatement` is the number
    /// of dose events marked TAKEN whose moment is after `statedAt`;
    /// `intervalDays` is the rhythm's fixed interval (nil = no date
    /// claim); `nextDoseDay` is the next scheduled slot's civil day.
    static func read(
        statement: Statement,
        takenAfterStatement: Int,
        nextDoseDay: Date?,
        intervalDays: Int?,
        calendar: Calendar = .current
    ) -> Read {
        let remaining = max(0, statement.dosesOnHand - max(0, takenAfterStatement))
        guard remaining >= 1,
              let nextDoseDay,
              let intervalDays, intervalDays >= 1,
              let last = calendar.date(
                byAdding: .day, value: (remaining - 1) * intervalDays,
                to: calendar.startOfDay(for: nextDoseDay)
              )
        else { return Read(remaining: remaining, lastDoseDay: nil) }
        return Read(remaining: remaining, lastDoseDay: last)
    }

    /// The rhythm's fixed interval in days, or nil when the cadence
    /// cannot honestly carry a run-out date.
    static func intervalDays(for cadence: MedicationScheduleEngine.Cadence) -> Int? {
        switch cadence {
        case .weekly: return 7
        case .daily: return 1
        case .everyNDays(let n): return n >= 1 ? n : nil
        case .twiceWeekly, .asNeeded, .unknown:
            // Two anchors have no single interval; a date claim here
            // would be an invented denominator.
            return nil
        }
    }

    // MARK: the words

    /// The regimen row's value. nil statement → the row's own invite
    /// is the caller's ("add it, if you like").
    static func rowWord(remaining: Int) -> String {
        // p78 — the row's label became "doses left", so the value is
        // the count alone ("doses left · 4 doses left" said it twice).
        switch remaining {
        case 0: return "none, by your count"
        default: return "\(remaining)"
        }
    }

    /// The quiet line under "next dose", spoken only when it matters.
    /// nil when the pen still has runway (≥2) or nothing was stated.
    static func whisper(remaining: Int) -> String? {
        switch remaining {
        case 0: return "this pen is done, by your count."
        case 1: return "the next dose is this pen's last, by your count. a refill keeps the rhythm."
        default: return nil
        }
    }

    // MARK: the record-side count

    /// Doses marked taken after the statement's moment. `takenAt` is
    /// the truth when she recorded one (the late face records WHEN);
    /// the slot's scheduled time stands in when she didn't.
    static func takenCount(
        since statedAt: Date, userId: String, in context: ModelContext
    ) -> Int {
        let uid = userId
        let d = FetchDescriptor<DoseEventRecord>(
            predicate: #Predicate {
                $0.userId == uid && $0.status == "taken"
            }
        )
        let events = (try? context.fetch(d)) ?? []
        return events.filter { ($0.takenAt ?? $0.scheduledAt) > statedAt }.count
    }
}
