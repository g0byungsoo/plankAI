import Foundation
import PlankSync

// MARK: - RegimenEras (app v25 pass 58)
//
// THE ONE ERA ARITHMETIC. Three surfaces derived "dose eras" from the
// regimen version chain independently (the becoming ledger, the
// pattern engine's doseChangeDays, the chat envelope) and all three
// carried the same two defects:
//
//   1. `previousPlanId != nil && strengthValue != nil` counted a
//      SCHEDULE-only change as a dose change — so the pattern engine
//      could say "picked up after the dose changed" about a week in
//      which the dose did not change, and the envelope handed the
//      model two "eras" at one strength sharing one start date
//      (schedule versions INHERIT startedAt — RegimenService's own
//      rule).
//   2. Iterating versions `where strengthValue != nil` minted a
//      duplicate era row per schedule change, splitting one dose's
//      span into two artificially.
//
// An ERA is one continuous span at one strength. Consecutive versions
// at the same strength are ONE era; only a real strength move opens a
// new one. A version with no stated strength breaks the run and
// counts as no change in either direction — unknown is never a fact.
//
// Pure over lifted facts (the DoseLedger house pattern) so it is
// testable without SwiftData. Timing, never causality: an era says
// WHEN the dose changed, never what the change did.

enum RegimenEras {

    /// One version's facts, lifted off the record row.
    struct Version: Equatable {
        let startedAt: Date
        let endedAt: Date?
        let strengthValue: Double?
        let strengthUnit: String?
        let createdAt: Date

        init(
            startedAt: Date,
            endedAt: Date?,
            strengthValue: Double?,
            strengthUnit: String?,
            createdAt: Date? = nil
        ) {
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.strengthValue = strengthValue
            self.strengthUnit = strengthUnit
            self.createdAt = createdAt ?? startedAt
        }
    }

    /// One continuous span at one strength. `endedAt == nil` means
    /// the era is current.
    struct Era: Equatable {
        let startedAt: Date
        let endedAt: Date?
        let strengthValue: Double?
        let strengthUnit: String
    }

    /// The lift — record rows to value facts, so every consumer
    /// derives from ONE arithmetic.
    static func versions(of records: [RegimenPlanRecord]) -> [Version] {
        records.map {
            Version(
                startedAt: $0.startedAt,
                endedAt: $0.endedAt,
                strengthValue: $0.strengthValue,
                strengthUnit: $0.strengthUnit,
                createdAt: $0.createdAt
            )
        }
    }

    /// Versions (any order) → eras, oldest first. Chain order is
    /// (startedAt, createdAt) — schedule inheritors share startedAt
    /// with their predecessor and settle by creation.
    static func eras(_ versions: [Version]) -> [Era] {
        let ordered = versions.sorted {
            ($0.startedAt, $0.createdAt) < ($1.startedAt, $1.createdAt)
        }
        var out: [Era] = []
        for v in ordered {
            if let last = out.last,
               last.strengthValue == v.strengthValue,
               last.strengthValue != nil {
                // Same strength continuing (a schedule change, a
                // product rename): ONE era, its end tracking the
                // latest version's own end.
                out[out.count - 1] = Era(
                    startedAt: last.startedAt,
                    endedAt: v.endedAt,
                    strengthValue: last.strengthValue,
                    strengthUnit: last.strengthUnit
                )
            } else {
                out.append(Era(
                    startedAt: v.startedAt,
                    endedAt: v.endedAt,
                    strengthValue: v.strengthValue,
                    strengthUnit: v.strengthUnit ?? "mg"
                ))
            }
        }
        return out
    }

    /// The civil days on which the DOSE actually moved: era
    /// boundaries where both sides state a strength and the strength
    /// differs. The first era is a start, not a change; a nil
    /// strength on either side is unknown, and unknown never claims
    /// a change happened.
    static func doseChangeDays(
        _ versions: [Version], calendar: Calendar = .current
    ) -> [String] {
        let spans = eras(versions)
        guard spans.count >= 2 else { return [] }
        var days: [String] = []
        for i in 1..<spans.count {
            guard let before = spans[i - 1].strengthValue,
                  let after = spans[i].strengthValue,
                  before != after else { continue }
            days.append(MedicationScheduleEngine.dayKey(
                for: spans[i].startedAt, calendar: calendar
            ))
        }
        return days
    }
}
