import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - LessonQuoteCard
//
// v1.0.10 (2026-06-17) — IG-Story / TikTok-bait share card for a
// single CBT lesson page. Built to live in the same typography
// family as DailyShareCard + WeeklyShareCard + NutritionCardView:
// JeniHeroSerif on the punch words, Fraunces72pt on the eyebrow,
// cream background, three coquette stickers scattered at the
// corners.
//
// Founder direction: "jenifit education module also needs ...
// visual improvement constantly with her75 pinterest it-girl
// style and it needs to be more engageable. we can research what
// other winning products do for their contents and copy some of
// the winning strategies." — the universal winning strategy for
// CBT / journal apps (Finch, Stoic, How We Feel, Calm) is the
// shareable insight: the user posts the line that moved her, the
// app gets free organic acquisition.
//
// Layout (1080×1920 canvas, top-down):
//   - 0    →  220pt: editorial eyebrow + program-day mark
//                    ("THE JENIFIT METHOD ·  ·  day 14")
//   - 220  →  240pt: hairline divider
//   - 240  → 1400pt: hero quote — page.headline rendered with
//                    italic punch words at 72pt, body sentence at
//                    34pt below as supporting evidence
//   - 1400 → 1620pt: pillar attribution (italic Fraunces; the
//                    chapter / pillar name the lesson belongs to)
//   - 1620 → 1920pt: jenifit wordmark + bottom inset
//
// Designed for ImageRenderer offscreen rendering. NEVER mounted in
// the user's actual view hierarchy — only by LessonQuoteRenderer.

struct LessonQuoteCard: View {

    /// The lesson page headline (e.g. "the voice in your head was
    /// taught"). Becomes the visual hero on the share card.
    let headline: String

    /// Lowercased italic-punch tokens (e.g. ["taught"]). Each
    /// matching token in `headline` renders in JeniHeroSerif-Italic;
    /// the rest stays JeniHeroSerif-Regular. Empty array → headline
    /// renders fully Regular.
    let italicWords: [String]

    /// Optional supporting body line (one sentence, ideally the
    /// reframe). nil collapses to a quote-only layout.
    let bodyLine: String?

    /// Day-N label (e.g. "day 14"). Drives the editorial eyebrow.
    let dayLabel: String

    /// Pillar / chapter the lesson belongs to (e.g. "the voice").
    /// Anchors the bottom attribution as a sub-register signature.
    let pillarTitle: String

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer().frame(height: 130)
                eyebrowRow.padding(.horizontal, 80)
                Spacer().frame(height: 18)
                hairline.padding(.horizontal, 80)
                Spacer().frame(height: 84)

                heroQuote.padding(.horizontal, 70)

                if let bodyLine, !bodyLine.isEmpty {
                    Spacer().frame(height: 42)
                    bodySupport(line: bodyLine).padding(.horizontal, 90)
                }

                Spacer()

                attribution.padding(.horizontal, 80)
                Spacer().frame(height: 28)
                wordmark
                Spacer().frame(height: 76)
            }
        }
        .frame(width: 1080, height: 1920)
    }

    // MARK: - Background + sticker scatter
    //
    // Three accents max per the milestone-scatter rule. Earned
    // moment register (the user is sharing something she found
    // worth keeping) so the stickers belong.

    @ViewBuilder private var background: some View {
        ZStack {
            Color(hex: "#F7F1E8")

            Image("sticker_cherries", bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: 138, height: 138)
                .rotationEffect(.degrees(-14))
                .opacity(0.78)
                .offset(x: -380, y: -800)

            Image("sticker_bow_satin", bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: 108, height: 108)
                .rotationEffect(.degrees(13))
                .opacity(0.74)
                .offset(x: 400, y: -760)

            Image("sticker_flower_3d", bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: 94, height: 94)
                .rotationEffect(.degrees(-9))
                .opacity(0.70)
                .offset(x: 380, y: 760)
        }
    }

    // MARK: - Eyebrow + hero

    @ViewBuilder private var eyebrowRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("THE JENIFIT METHOD")
                .font(.custom("Fraunces72pt-SemiBold", size: 22))
                .foregroundStyle(Color(hex: "#7B5959"))
                .kerning(3.6)
            Spacer()
            Text(dayLabel.lowercased())
                .font(.custom("Fraunces72pt-Regular", size: 24))
                .foregroundStyle(Color(hex: "#7B5959"))
        }
    }

    @ViewBuilder private var hairline: some View {
        Rectangle()
            .fill(Color(hex: "#3D2B2B").opacity(0.18))
            .frame(height: 1)
    }

    @ViewBuilder private var heroQuote: some View {
        composedQuoteText()
            .foregroundStyle(Color(hex: "#3D2B2B"))
            .multilineTextAlignment(.leading)
            .lineSpacing(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Builds a single Text by token-walking the headline and swapping
    /// font face on each italic-punch word match. Case-folded match;
    /// punctuation is stripped from the token before comparison so
    /// "taught." still matches the italic set ["taught"].
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
                out = out + Text(token).font(.custom("JeniHeroSerif-Italic", size: 72))
            } else {
                out = out + Text(token).font(.custom("JeniHeroSerif-Regular", size: 72))
            }
            if i < tokens.count - 1 {
                out = out + Text(" ").font(.custom("JeniHeroSerif-Regular", size: 72))
            }
        }
        return out
    }

    @ViewBuilder private func bodySupport(line: String) -> some View {
        Text(line)
            .font(.custom("JeniHeroSerif-Regular", size: 32))
            .lineSpacing(6)
            .foregroundStyle(Color(hex: "#3D2B2B").opacity(0.78))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Attribution + wordmark

    @ViewBuilder private var attribution: some View {
        HStack(spacing: 0) {
            Text(pillarTitle)
                .font(.custom("JeniHeroSerif-Italic", size: 26))
                .foregroundStyle(Color(hex: "#7B5959"))
            Spacer()
        }
    }

    @ViewBuilder private var wordmark: some View {
        HStack {
            Spacer()
            Text("jenifit")
                .font(.custom("Fraunces72pt-SemiBold", size: 28))
                .foregroundStyle(Color(hex: "#C4677A").opacity(0.42))
            Spacer()
        }
    }
}
