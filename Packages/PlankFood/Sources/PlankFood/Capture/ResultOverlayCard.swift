#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - ResultOverlayCard
//
// v1.0.20 (2026-06-18) — IN-APP slide 2 of the post-scan carousel.
// Transparent backdrop so the frozen camera photo behind shows
// through (no second embedded photo). Carries the dish name + macro
// caption + "share what you see" affordance, in the her75 editorial
// register so the slide feels like a magazine title page laid over
// the user's plate, not a chrome strip.
//
// The SHARE-READY 1080×1920 PNG (with embedded photo) is still
// rendered by HandwrittenSnapResultShareCard when the user taps
// share — this view is the IN-APP companion.
//
// Layout (rendered at 1080×1920 for scale parity with slides 1+3,
// then scaled into the carousel slot):
//
//   - top inset: ~620pt of transparency (camera photo bleeds through)
//   - dish title in JeniHeroSerif-Italic + cocoa drop shadow
//   - macro caption strip in DMSans-Medium with cocoa drop shadow
//   - bottom inset: ~340pt transparency (toolbar + page dots live here)

struct ResultOverlayCard: View {

    let dishName: String
    let mealLabel: String
    let totalKcal: Int
    let totalProtein: Int
    let totalFiber: Int
    let loggedAt: Date
    let itemCount: Int

    var body: some View {
        ZStack {
            Color.clear  // transparent — camera shows through

            VStack(alignment: .leading, spacing: 28) {
                Spacer()
                eyebrow
                title
                macroCaption
                shareableHint
                Spacer().frame(height: 280)
            }
            .padding(.horizontal, 80)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 1080, height: 1920)
    }

    // MARK: - Eyebrow strip

    @ViewBuilder private var eyebrow: some View {
        (
            Text("today's ")
                .font(.custom("DMSans-Medium", size: 30))
            + Text(mealLabel.isEmpty ? "plate" : mealLabel.lowercased())
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 32))
        )
        .foregroundStyle(.white)
        .kerning(0.4)
        .shadow(color: .black.opacity(0.50), radius: 8, x: 0, y: 2)
    }

    // MARK: - Dish title (the magazine cover line)

    @ViewBuilder private var title: some View {
        Text(dishLineDisplay)
            .font(.custom("JeniHeroSerif-Italic", size: 96))
            .foregroundStyle(.white)
            .kerning(-1.6)
            .lineSpacing(-4)
            .multilineTextAlignment(.leading)
            .shadow(color: .black.opacity(0.55), radius: 10, x: 0, y: 3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var dishLineDisplay: String {
        let stripped = dishName
            .replacingOccurrences(
                of: #"\s*\+\s*\d+\s+more$"#,
                with: "",
                options: .regularExpression
            )
            .lowercased()
        return stripped.isEmpty ? "your plate" : stripped
    }

    // MARK: - Macro caption (the editorial subhead)

    @ViewBuilder private var macroCaption: some View {
        Text(macroString)
            .font(.custom("DMSans-Medium", size: 32))
            .foregroundStyle(.white.opacity(0.95))
            .shadow(color: .black.opacity(0.55), radius: 8, x: 0, y: 2)
    }

    private var macroString: String {
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mma"
        let time = timeFmt.string(from: loggedAt).lowercased()
        var parts = [time]
        if totalKcal > 0 { parts.append("\(totalKcal) calories") }
        if totalProtein > 0 { parts.append("\(totalProtein)g protein") }
        if totalFiber > 0 { parts.append("\(totalFiber)g fiber") }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private var shareableHint: some View {
        (
            Text(itemCount > 0 ? "\(itemCount) " : "")
                .font(.custom("DMSans-Medium", size: 26))
            + Text(itemCount == 1 ? "ingredient" : "ingredients")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 26))
            + Text(" noted. ready to share. ♡")
                .font(.custom("DMSans-Medium", size: 26))
        )
        .foregroundStyle(.white.opacity(0.92))
        .shadow(color: .black.opacity(0.55), radius: 8, x: 0, y: 2)
    }
}

#endif  // canImport(UIKit)
