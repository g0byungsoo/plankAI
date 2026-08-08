#if canImport(UIKit)
import SwiftUI

// MARK: - SnapUnderstandingChips (v23 THE STILL LIFE §4)
//
// THE UNDERSTANDING — the result's own items land ON the photograph
// as named chips: the food becomes the interface. Honest theater
// (law E2): every chip is a real recognized item carrying its real
// calories; nothing is simulated. Up to three chips take fixed
// slots over the photograph's subject region and land one at a
// time on a soft stagger, each discovered with a single fading
// ring (restraint is the intelligence).
//
// v23 pass 2 — the chips are TOUCHABLE: a tap hands the item id to
// the host, which expands the reading and flashes the item's row.
// The v22 anchor stems retired (S5): a stem claimed per-ingredient
// pointing the EF doesn't provide.
//
// Shared by the live result stage (PhotoCaptureView) and the
// harnesses so films and captures exercise the same view.

public struct SnapUnderstandingChips: View {
    let items: [CapturedItem]
    /// When present, chips are buttons; a tap hands up the item id.
    var onTap: ((String) -> Void)?

    @State private var landed = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(items: [CapturedItem], onTap: ((String) -> Void)? = nil) {
        self.items = Array(items.prefix(3))
        self.onTap = onTap
    }

    public var body: some View {
        GeometryReader { geo in
            // The chips cluster around the meal (the photograph's
            // subject region above the panel). We hold no
            // per-ingredient coordinates, so the chips attach to the
            // MEAL — honest anchoring (E2), never invented positions.
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

                    // DISCOVERED, not shown: one soft ring blooms out
                    // of each landing point as its chip settles.
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
        // Non-interactive hosts (share slide, harness stills) keep
        // the chips decorative; interactive hosts expose each chip.
        .accessibilityHidden(onTap == nil)
    }

    @ViewBuilder
    private func chip(_ item: CapturedItem) -> some View {
        let body = HStack(spacing: 6) {
            Text(item.name.foodNameCleaned.lowercased())
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

        if let onTap {
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                onTap(item.id)
            } label: {
                body
                    // The capsule stays visually light; the target
                    // meets the 44pt floor.
                    .frame(minHeight: 44)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                "\(item.name), \(Int((item.kcal ?? 0).rounded())) calories. shows its row"
            )
        } else {
            body
        }
    }
}

#endif  // canImport(UIKit)
