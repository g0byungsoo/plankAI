import Foundation

// MARK: - ClinicalBaseline
//
// Pure helpers for the clinical baseline record. Keep math here so it is
// testable and the persisted numbers always trace to a collected field
// (provenance rule: docs/STATE.md).

enum ClinicalBaseline {

    /// Returns BMI (kg/m²) from weight in kilograms and height in centimetres.
    /// Returns nil when either value is zero or negative; guards against
    /// unset onboarding defaults landing as a persisted zero.
    static func bmi(weightKg: Double, heightCm: Double) -> Double? {
        guard heightCm > 0, weightKg > 0 else { return nil }
        let m = heightCm / 100.0
        return weightKg / (m * m)
    }
}
