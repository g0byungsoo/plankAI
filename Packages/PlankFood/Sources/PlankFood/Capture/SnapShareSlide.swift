#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - SnapShareSlide  (carousel slide 3 — the shareable card + picker)
//
// Wraps SnapShareCard (embedsPhoto: false, so the frozen camera shows
// through) and adds an Instagram-style font rail + an alignment toggle.
// The chosen font + alignment persist in @AppStorage so (a) her aesthetic
// carries across snaps and (b) the PNG export reads the same choice —
// what she sees here is exactly what she posts.
//
// The rail offers only fonts actually registered in the bundle, so the
// "statement" (Bodoni Moda) option appears once the face ships and is a
// no-op until then — never a broken system-fallback pill.

struct SnapShareSlide: View {

    let photo: UIImage?
    let mealLabel: String
    let dishName: String
    let itemNames: [String]
    let totals: (carbs: Int, protein: Int, fat: Int, fiber: Int, kcal: Int)
    var loggedAt: Date = Date()

    @AppStorage("snapShareFont") private var fontRaw: String = SnapShareFont.editorial.rawValue
    @AppStorage("snapShareTrailing") private var trailing: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selected: SnapShareFont { SnapShareFont(rawValue: fontRaw) ?? .editorial }

    private var availableFonts: [SnapShareFont] {
        SnapShareFont.allCases.filter { UIFont(name: $0.postScript, size: 12) != nil }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            SnapShareCard(
                photo: photo ?? Self.placeholder,
                dishName: dishName,
                itemNames: itemNames,
                totals: totals,
                loggedAt: loggedAt,
                font: selected,
                trailing: trailing,
                embedsPhoto: false,
                bottomInset: 78          // clear the font-picker rail
            )
            .id(selected)                              // re-create → crossfade on switch
            .transition(.opacity)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: selected)

            fontRail
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Font rail

    private var fontRail: some View {
        HStack(spacing: 8) {
            ForEach(availableFonts, id: \.self) { f in
                pill(f)
            }
            alignmentToggle
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
    }

    private func pill(_ f: SnapShareFont) -> some View {
        let isOn = selected == f
        return Button {
            guard f != selected else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            fontRaw = f.rawValue
        } label: {
            Text(f.label)
                .font(.custom(f.postScript, size: 16 * f.sizeMultiplier))
                .foregroundStyle(isOn ? FoodTheme.bgPrimary : FoodTheme.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(isOn ? FoodTheme.textPrimary : FoodTheme.bgElevated.opacity(0.9))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(f.label) font\(isOn ? ", selected" : "")")
    }

    private var alignmentToggle: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            trailing.toggle()
        } label: {
            Image(systemName: trailing ? "text.alignright" : "text.alignleft")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(FoodTheme.textPrimary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(FoodTheme.bgElevated.opacity(0.9)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("toggle text alignment")
    }

    private static let placeholder: UIImage = {
        UIGraphicsImageRenderer(size: CGSize(width: 1080, height: 1920)).image { ctx in
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [UIColor(red: 0.42, green: 0.32, blue: 0.30, alpha: 1).cgColor,
                         UIColor(red: 0.20, green: 0.15, blue: 0.14, alpha: 1).cgColor] as CFArray,
                locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(g, start: .zero,
                end: CGPoint(x: 1080, y: 1920), options: [])
        }
    }()
}
#endif
