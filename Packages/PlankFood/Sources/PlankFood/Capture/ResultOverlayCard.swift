#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - ResultOverlayCard
//
// v1.0.22 (2026-06-18) — terminal slide of the post-scan carousel,
// the natural "I want to post this" swipe-out gesture per founder
// direction. Transparent backdrop so the frozen camera photo behind
// shows through (no second embedded photo). The IN-APP companion to
// HandwrittenSnapResultShareCard, which still renders the embedded-
// photo PNG when the user taps share.
//
// v1.0.22 polish: richer overlay composition in the TikTok / IG-
// girl-post register the founder asked for. Two-line italic title
// in JeniHeroSerif-Italic with cocoa drop shadow, a dish-mark
// hairline + "dish *fits*" + ♡ caption, full macro caption line,
// kcal hero in italic Fraunces, ingredient count with heart cluster.
// Every element wears the cocoa drop shadow that makes the white-on-
// photo register read crisp on any background.

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

            VStack(alignment: .leading, spacing: 24) {
                Spacer()

                topMeta
                title
                hairlineRule
                dishMark
                kcalHero
                macroCaption
                shareableHint

                Spacer().frame(height: 260)
            }
            .padding(.horizontal, 72)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 1080, height: 1920)
    }

    // MARK: - Top meta (eyebrow)

    @ViewBuilder private var topMeta: some View {
        (
            Text("today's ")
                .font(.custom("DMSans-Medium", size: 36))
            + Text(mealLabel.isEmpty ? "plate" : mealLabel.lowercased())
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 38))
        )
        .foregroundStyle(.white)
        .kerning(0.4)
        .shadow(color: .black.opacity(0.50), radius: 8, x: 0, y: 2)
    }

    // MARK: - Dish title (the magazine cover line)

    @ViewBuilder private var title: some View {
        Text(dishLineDisplay)
            .font(.custom("JeniHeroSerif-Italic", size: 132))
            .foregroundStyle(.white)
            .kerning(-2.0)
            .lineSpacing(-12)
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

    // MARK: - Hairline rule + dish-mark

    @ViewBuilder private var hairlineRule: some View {
        Rectangle()
            .fill(Color.white.opacity(0.75))
            .frame(height: 0.75)
            .frame(width: 200)
            .shadow(color: .black.opacity(0.40), radius: 4, x: 0, y: 1)
    }

    @ViewBuilder private var dishMark: some View {
        (
            Text("this one ")
                .font(.custom("DMSans-Light", size: 34))
            + Text("fits")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 38))
            + Text(" ♡")
                .font(.custom("DMSans-Medium", size: 32))
        )
        .foregroundStyle(.white.opacity(0.92))
        .shadow(color: .black.opacity(0.55), radius: 8, x: 0, y: 2)
    }

    // MARK: - Kcal hero

    @ViewBuilder private var kcalHero: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(totalKcal)")
                .font(.custom("JeniHeroSerif-Regular", size: 108))
                .foregroundStyle(.white)
                .kerning(-1.4)
                .monospacedDigit()
            Text("calories")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 38))
                .foregroundStyle(.white.opacity(0.92))
                .baselineOffset(16)
        }
        .shadow(color: .black.opacity(0.55), radius: 10, x: 0, y: 3)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Macro caption

    @ViewBuilder private var macroCaption: some View {
        Text(macroString)
            .font(.custom("DMSans-Medium", size: 34))
            .foregroundStyle(.white.opacity(0.92))
            .shadow(color: .black.opacity(0.55), radius: 8, x: 0, y: 2)
    }

    private var macroString: String {
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mma"
        let time = timeFmt.string(from: loggedAt).lowercased()
        var parts = [time]
        if totalProtein > 0 { parts.append("\(totalProtein)g protein") }
        if totalFiber > 0 { parts.append("\(totalFiber)g fiber") }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private var shareableHint: some View {
        HStack(spacing: 10) {
            (
                Text("\(itemCount) ")
                    .font(.custom("DMSans-Medium", size: 32))
                + Text(itemCount == 1 ? "ingredient" : "ingredients")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 32))
                + Text(" noted")
                    .font(.custom("DMSans-Medium", size: 32))
            )
            .foregroundStyle(.white.opacity(0.92))

            Text("♡ ♡ ♡")
                .font(.custom("DMSans-Medium", size: 28))
                .foregroundStyle(.white.opacity(0.85))
                .kerning(2)
        }
        .shadow(color: .black.opacity(0.55), radius: 8, x: 0, y: 2)
    }
}

#endif  // canImport(UIKit)
