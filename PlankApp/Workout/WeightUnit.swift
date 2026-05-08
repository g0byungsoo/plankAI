import Foundation

/// User-facing weight unit. Storage is always kg (canonical) — `WeightUnit`
/// only governs input + display. Conversion factor is the standard
/// 1 kg = 2.20462 lb.
///
/// The `weightUnit` AppStorage key holds the raw value ("lb" / "kg").
/// Default is "lb" — most users self-identify lb in onboarding even
/// though the slider records kg, so showing kg in Analytics felt
/// foreign. Switching to lb-default avoids the cognitive translation.
enum WeightUnit: String {
    case kg
    case lb

    /// Read the persisted preference, defaulting to lb.
    static var current: WeightUnit {
        WeightUnit(rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "lb") ?? .lb
    }

    var label: String {
        switch self {
        case .kg: return "kg"
        case .lb: return "lb"
        }
    }

    /// Convert from kg → display unit, rounded to 1 decimal place. Used
    /// at every render site so we never store the lossy display value.
    func display(fromKg kg: Double) -> Double {
        switch self {
        case .kg: return (kg * 10).rounded() / 10
        case .lb: return (kg * 2.20462 * 10).rounded() / 10
        }
    }

    /// Convert a user-entered display value back to kg for storage.
    /// Lossless within float precision; round-tripping a value through
    /// display() → toKg() produces a value that displays identically.
    func toKg(displayed: Double) -> Double {
        switch self {
        case .kg: return displayed
        case .lb: return displayed / 2.20462
        }
    }

    /// Plausible weight bounds in display units (matches the kg 20–250
    /// range used by the stepper clamps). Pre-computed so the keypad +
    /// stepper math doesn't repeatedly convert sentinel values.
    var displayRange: ClosedRange<Double> {
        switch self {
        case .kg: return 20...250
        case .lb: return 44...551
        }
    }

    /// Stepper deltas in display units. Lb users expect 0.2 / 2.0 lb
    /// rounding (close to the kg 0.1 / 1.0 grain) — neither feels like
    /// a translation artifact.
    var smallStep: Double {
        switch self {
        case .kg: return 0.1
        case .lb: return 0.2
        }
    }

    var largeStep: Double {
        switch self {
        case .kg: return 1.0
        case .lb: return 2.0
        }
    }

    /// Format for typical inline display (`"154.3 lb"`). Used by the
    /// trend headline + log lists so we don't repeat the format string.
    func formatted(fromKg kg: Double) -> String {
        String(format: "%.1f %@", display(fromKg: kg), label)
    }
}
