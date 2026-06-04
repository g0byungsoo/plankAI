#if canImport(UIKit)
import SwiftUI

// MARK: - RestaurantRangeBar
//
// Per v5 §Calorie scan + D14 "i'm out tonight" mode: visualizes a
// kcal range estimate (e.g., "around 700–900") as a soft cocoa bar
// with the range bracket marked. The range itself IS the feature —
// honesty about uncertainty for restaurant logging where photo
// recognition is impossible (per audience research, restaurants are
// where every other tracker dies).
//
// Layout:
//
//     ┌─────────────────────────────────────────────┐
//     │       ████████████████                       │
//     └─────────────────────────────────────────────┘
//      ~400              ~700-900            ~1200
//
// The bar's "filled" portion spans low→high. The track shows the
// plausible full range for the cuisine type (defaults 200-1500
// kcal — covers from a snack to a heavy entrée).

public struct RestaurantRangeBar: View {

    public let kcalLow: Double
    public let kcalHigh: Double
    public var trackLow: Double
    public var trackHigh: Double

    public init(
        kcalLow: Double,
        kcalHigh: Double,
        trackLow: Double = 200,
        trackHigh: Double = 1500
    ) {
        self.kcalLow = kcalLow
        self.kcalHigh = kcalHigh
        self.trackLow = trackLow
        self.trackHigh = trackHigh
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("around \(Int(kcalLow))–\(Int(kcalHigh))")
                .font(.custom("Fraunces72pt-SemiBold", size: 24))
                .foregroundStyle(FoodTheme.textPrimary)

            GeometryReader { geo in
                let trackSpan = max(trackHigh - trackLow, 1)
                let lowFrac = max(0, min(1, (kcalLow - trackLow) / trackSpan))
                let highFrac = max(lowFrac, min(1, (kcalHigh - trackLow) / trackSpan))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(FoodTheme.accentSubtle.opacity(0.5))
                        .frame(height: 8)

                    Capsule()
                        .fill(FoodTheme.textPrimary)
                        .frame(
                            width: geo.size.width * (highFrac - lowFrac),
                            height: 8
                        )
                        .offset(x: geo.size.width * lowFrac)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(Int(trackLow))")
                    .font(.system(size: 11))
                    .foregroundStyle(FoodTheme.textSecondary)
                Spacer()
                Text("\(Int(trackHigh))")
                    .font(.system(size: 11))
                    .foregroundStyle(FoodTheme.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("range from \(Int(kcalLow)) to \(Int(kcalHigh)) calories")
    }
}

// MARK: - Preview

#Preview("RestaurantRangeBar") {
    VStack(alignment: .leading, spacing: 24) {
        RestaurantRangeBar(kcalLow: 700, kcalHigh: 900)
        RestaurantRangeBar(kcalLow: 400, kcalHigh: 1100)  // wider
        RestaurantRangeBar(kcalLow: 600, kcalHigh: 720)   // tighter
    }
    .padding()
    .background(FoodTheme.bgPrimary)
}

#endif  // canImport(UIKit)
