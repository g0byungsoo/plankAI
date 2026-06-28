import Foundation

enum RapidLossTripwire {
    struct Result { let isTooFast: Bool; let careMessage: String? }

    /// `trendKgPerWeek` > 0 means losing weight. Fires when the loss rate exceeds
    /// the safe ceiling (default 1%/wk of body weight). Care-framed, never shame.
    static func evaluate(trendKgPerWeek: Double,
                         currentWeightKg: Double,
                         safeCeilingPctPerWeek: Double = 0.01) -> Result {
        guard currentWeightKg > 0, trendKgPerWeek > 0 else {
            return Result(isTooFast: false, careMessage: nil)
        }
        let pct = trendKgPerWeek / currentWeightKg
        guard pct > safeCeilingPctPerWeek else {
            return Result(isTooFast: false, careMessage: nil)
        }
        return Result(isTooFast: true,
                      careMessage: "you're losing faster than we plan for. let's make sure you're eating enough \u{2665}")
    }
}
