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
            ZStack(alignment: .topLeading) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    chip(item)
                        .position(
                            x: i == 1
                                ? geo.size.width * 0.72
                                : geo.size.width * (0.26 + Double(i) * 0.04),
                            y: geo.size.height * (0.16 + Double(i) * 0.085)
                        )
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
