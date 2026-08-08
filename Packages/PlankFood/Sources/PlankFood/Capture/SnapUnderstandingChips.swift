#if canImport(UIKit)
import SwiftUI

// MARK: - SnapUnderstandingChips (v22 ONE HAND)
//
// THE UNDERSTANDING — the result's own items land ON the photograph
// as named chips: the food becomes the interface. Honest theater
// (law E2): every chip is a real recognized item carrying its real
// calories; nothing is simulated. Up to three chips take fixed
// slots (left · right · left) over the photo's top region and land
// one at a time on a soft stagger.
//
// Shared by the live result stage (PhotoCaptureView) and the
// carousel harness so films and captures exercise the same view.

public struct SnapUnderstandingChips: View {
    let items: [CapturedItem]

    @State private var landed = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(items: [CapturedItem]) {
        self.items = Array(items.prefix(3))
    }

    public var body: some View {
        GeometryReader { geo in
            // v22.3 — MAGNETIC: the chips cluster around the meal
            // (the photograph's subject region above the panel), each
            // with a berry anchor stem pointing into the plate. We
            // hold no per-ingredient coordinates, so the chips attach
            // to the MEAL — honest anchoring (E2), never invented
            // ingredient positions.
            let cx = geo.size.width * 0.5
            let cy = geo.size.height * 0.26
            let radius = geo.size.width * 0.33
            let angles: [Double] = [-118, -10, 158]   // degrees
            ZStack(alignment: .topLeading) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    let a = angles[i % angles.count] * .pi / 180
                    // Clamped so a wide chip never clips the glass
                    // (frame-caught at the right edge).
                    let x = min(max(cx + radius * cos(a), 104),
                                geo.size.width - 104)
                    let y = cy + radius * sin(a) * 0.5

                    // v22 — DISCOVERED, not shown: a single soft ring
                    // blooms out of each landing point as its chip
                    // settles (one ring, one breath — restraint is
                    // the intelligence).
                    if !reduceMotion {
                        Circle()
                            .stroke(FoodTheme.roseBerry.opacity(
                                landed > i ? 0 : 0.35
                            ), lineWidth: 1.5)
                            .frame(width: 54, height: 54)
                            .scaleEffect(landed > i ? 1.6 : 0.55)
                            .position(x: x, y: y)
                            .animation(
                                .easeOut(duration: 0.6)
                                    .delay(Double(i) * 0.14),
                                value: landed
                            )
                    }

                    // The anchor stem — a small berry dot between
                    // chip and meal, the magnet made visible.
                    let ux = (cx - x), uy = (cy - y)
                    let len = max(1, (ux * ux + uy * uy).squareRoot())
                    Circle()
                        .fill(FoodTheme.roseBerry.opacity(0.85))
                        .frame(width: 5, height: 5)
                        .position(x: x + ux / len * 30, y: y + uy / len * 30)
                        .opacity(landed > i ? 1 : 0)
                        .animation(
                            .easeOut(duration: 0.4).delay(Double(i) * 0.14 + 0.1),
                            value: landed
                        )

                    chip(item)
                        .position(x: x, y: y)
                        .opacity(landed > i ? 1 : 0)
                        .scaleEffect(landed > i ? 1 : 0.6)
                        .animation(
                            reduceMotion
                                ? .easeOut(duration: 0.2)
                                : .spring(response: 0.5, dampingFraction: 0.72)
                                    .delay(Double(i) * 0.14),
                            value: landed
                        )
                }
            }
        }
        .onAppear {
            landed = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                landed = items.count
            }
        }
        .accessibilityHidden(true)   // the panel reads the same items
    }

    @ViewBuilder
    private func chip(_ item: CapturedItem) -> some View {
        HStack(spacing: 6) {
            Text(item.name.lowercased())
                .font(.custom("DMSans-Medium", size: 13))
                .foregroundStyle(FoodTheme.textPrimary)
                .lineLimit(1)
            if let kcal = item.kcal, kcal >= 1 {
                Text("\(Int(kcal.rounded()))")
                    .font(.custom("DMSans-SemiBold", size: 12))
                    .monospacedDigit()
                    .foregroundStyle(FoodTheme.roseBerry)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(Color.white.opacity(0.94))
                .shadow(color: Color.black.opacity(0.10), radius: 8, y: 2)
        )
        .frame(maxWidth: 190)
    }
}

#endif  // canImport(UIKit)
