import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - LessonQuoteCard
//
// v1.0.11 (2026-06-17) — REBUILT after founder feedback on v1.0.10:
// "all shared cards look like some cute elementary school design.
// can we make them more like luxury girl magazine style without
// card design in shared screen?"
//
// Direction:
//   - Handwritten typography (Bradley Hand / Snell / Marker Felt) is
//     RESERVED for food-photo overlays. Non-food shares use the
//     JeniFit type system (JeniHeroSerif Italic / Fraunces / DM Sans).
//   - No "card" chrome — no cream containers, no scrapbook borders,
//     no sticker scatter. Negative space + hairline rules + magazine
//     typography do the work.
//   - The page IS the share. Background is off-white cream, edges
//     are clean to the canvas.
//
// Layout (1080×1920, top-down):
//
//   - 0    →  220pt: editorial eyebrow row — "THE JENIFIT METHOD"
//                    tracked Fraunces SemiBold + day mark right-aligned
//   - 220  →  240pt: hairline rule (0.5pt cocoa, full bleed)
//   - 240  → 1500pt: hero italic-punch quote rendered in JeniHeroSerif
//                    Regular + Italic at ~84pt centered vertically;
//                    body line (DM Sans Regular 22pt) below at 0.75
//                    opacity
//   - 1500 → 1520pt: hairline rule
//   - 1520 → 1920pt: bottom folio — tracked Fraunces caps with pillar
//                    name, "JENIFIT" Fraunces SemiBold wordmark right
//
// Designed for ImageRenderer offscreen rendering. Never mounted in
// the user's live view hierarchy — only by LessonQuoteRenderer.

struct LessonQuoteCard: View {

    /// Page headline ("the voice in your head was taught").
    let headline: String

    /// Lowercased italic-punch tokens (e.g. ["taught"]).
    let italicWords: [String]

    /// Optional supporting body line.
    let bodyLine: String?

    /// Day-N label (e.g. "day fourteen").
    let dayLabel: String

    /// Pillar / chapter name.
    let pillarTitle: String

    var body: some View {
        ZStack {
            Color(hex: "#F8F2E8")  // warm off-white — magazine page,
                                    // softer than the #FDF6F4 cream
                                    // the app uses on screen so the
                                    // share reads as a printed page.

            VStack(spacing: 0) {
                Spacer().frame(height: 130)
                eyebrowRow.padding(.horizontal, 110)
                Spacer().frame(height: 18)
                hairline.padding(.horizontal, 110)

                Spacer()

                heroQuote.padding(.horizontal, 110)

                if let bodyLine, !bodyLine.isEmpty {
                    Spacer().frame(height: 48)
                    bodySupport(line: bodyLine).padding(.horizontal, 150)
                }

                Spacer()

                hairline.padding(.horizontal, 110)
                Spacer().frame(height: 28)
                bottomFolio.padding(.horizontal, 110)
                Spacer().frame(height: 88)
            }
        }
        .frame(width: 1080, height: 1920)
    }

    // MARK: - Eyebrow

    @ViewBuilder private var eyebrowRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("THE JENIFIT METHOD")
                .font(.custom("Fraunces72pt-SemiBold", size: 22))
                .foregroundStyle(Color(hex: "#5B3C3C"))
                .kerning(3.8)
            Spacer()
            Text(dayLabel.uppercased())
                .font(.custom("Fraunces72pt-Regular", size: 22))
                .foregroundStyle(Color(hex: "#5B3C3C"))
                .kerning(2.2)
        }
    }

    // MARK: - Hairlines

    @ViewBuilder private var hairline: some View {
        Rectangle()
            .fill(Color(hex: "#3D2B2B").opacity(0.22))
            .frame(height: 0.6)
    }

    // MARK: - Hero quote

    @ViewBuilder private var heroQuote: some View {
        composedQuoteText()
            .foregroundStyle(Color(hex: "#3D2B2B"))
            .multilineTextAlignment(.leading)
            .lineSpacing(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Token-walk the headline and render italic-punch words in
    /// `JeniHeroSerif-Italic`; the rest in `JeniHeroSerif-Regular`.
    /// Magazine-pull-quote register — case-folded match, punctuation-
    /// safe so "taught." in the headline matches ["taught"] in the
    /// italic set.
    private func composedQuoteText() -> Text {
        let italicSet = Set(italicWords.map { $0.lowercased() })
        let tokens = headline.split(separator: " ", omittingEmptySubsequences: false)
        var out = Text("")
        for (i, raw) in tokens.enumerated() {
            let token = String(raw)
            let stripped = token
                .lowercased()
                .trimmingCharacters(in: .punctuationCharacters)
            if italicSet.contains(stripped) {
                out = out + Text(token).font(.custom("JeniHeroSerif-Italic", size: 92))
            } else {
                out = out + Text(token).font(.custom("JeniHeroSerif-Regular", size: 92))
            }
            if i < tokens.count - 1 {
                out = out + Text(" ").font(.custom("JeniHeroSerif-Regular", size: 92))
            }
        }
        return out
    }

    @ViewBuilder private func bodySupport(line: String) -> some View {
        Text(line)
            .font(.custom("DMSans-Regular", size: 26))
            .lineSpacing(8)
            .foregroundStyle(Color(hex: "#3D2B2B").opacity(0.65))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Bottom folio (pillar attribution + wordmark)

    @ViewBuilder private var bottomFolio: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(pillarTitle.uppercased())
                .font(.custom("Fraunces72pt-Regular", size: 18))
                .foregroundStyle(Color(hex: "#5B3C3C"))
                .kerning(2.6)
            Spacer()
            Text("JENIFIT")
                .font(.custom("Fraunces72pt-SemiBold", size: 22))
                .foregroundStyle(Color(hex: "#5B3C3C"))
                .kerning(3.4)
        }
    }
}
