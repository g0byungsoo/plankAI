import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - LessonQuoteCard
//
// v1.0.12 (2026-06-17) — REBUILT after founder review of the v1.0.11
// magazine layout: "needs to be much simpler with much bigger title
// and more context so users can share what they learned briefly with
// friends or family via social media."
//
// Direction:
//   - DOMINANT title — the lesson's core insight has to read at a
//     glance in a scrolling feed.
//   - MORE body — enough context for a friend or family member to
//     understand what was learned without opening the app.
//   - Minimal chrome — no top eyebrow row, no bottom folio, no
//     hairlines other than one quiet divider between hero and body.
//
// Layout (1080×1920, top-down):
//
//   - 0    →  280pt: generous top inset (breathing room)
//   - 280  → 1340pt: hero quote in JeniHeroSerif Regular + Italic at
//                    ~130pt, italic punch words still match the
//                    italicWords array via case-folded token walk
//   - 1340 → 1380pt: short hairline rule (160pt wide) — the only
//                    chrome on the page, marks the title-to-body
//                    transition
//   - 1380 → 1740pt: body text in DM Sans Regular 36pt at 0.80
//                    opacity, up to ~4 lines (caller supplies multi-
//                    sentence context, not the single firstSentence)
//   - 1740 → 1920pt: wordmark "JENIFIT" Fraunces SemiBold tracked
//                    44pt + day mark below
//
// Background is warm off-white (#F8F2E8) — print page feel, softer
// than pure white. Background and typography do all the work; no
// container, no border, no sticker scatter.

struct LessonQuoteCard: View {

    /// Page headline ("the voice in your head was taught").
    let headline: String

    /// Lowercased italic-punch tokens (e.g. ["taught"]).
    let italicWords: [String]

    /// Multi-sentence supporting body line. Caller should pass enough
    /// context for the share to stand alone — usually 2-3 sentences,
    /// not just the single firstSentence of page.body.
    let bodyLine: String?

    /// Day-N label (e.g. "day fourteen").
    let dayLabel: String

    /// Pillar / chapter name (kept for telemetry parity even though
    /// the v1.0.12 layout no longer surfaces it visually).
    let pillarTitle: String

    var body: some View {
        ZStack {
            Color(hex: "#F8F2E8")

            VStack(spacing: 0) {
                Spacer().frame(height: 280)
                heroQuote.padding(.horizontal, 100)
                Spacer().frame(height: 32)
                shortHairline
                Spacer().frame(height: 36)
                if let bodyLine, !bodyLine.isEmpty {
                    bodyBlock(bodyLine).padding(.horizontal, 100)
                }
                Spacer()
                wordmarkBlock.padding(.horizontal, 100)
                Spacer().frame(height: 110)
            }
        }
        .frame(width: 1080, height: 1920)
    }

    // MARK: - Hero quote (dominant)

    @ViewBuilder private var heroQuote: some View {
        composedQuoteText()
            .foregroundStyle(Color(hex: "#3D2B2B"))
            .multilineTextAlignment(.leading)
            .lineSpacing(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Token-walks the headline rendering italic-punch words in
    /// `JeniHeroSerif-Italic` and the rest in `JeniHeroSerif-Regular`.
    /// 130pt magazine pull-quote register — dominant by design.
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
                out = out + Text(token).font(.custom("JeniHeroSerif-Italic", size: 130))
            } else {
                out = out + Text(token).font(.custom("JeniHeroSerif-Regular", size: 130))
            }
            if i < tokens.count - 1 {
                out = out + Text(" ").font(.custom("JeniHeroSerif-Regular", size: 130))
            }
        }
        return out
    }

    @ViewBuilder private var shortHairline: some View {
        HStack {
            Rectangle()
                .fill(Color(hex: "#3D2B2B").opacity(0.45))
                .frame(width: 160, height: 1)
                .padding(.leading, 100)
            Spacer()
        }
    }

    // MARK: - Body block (the context users actually share)

    @ViewBuilder
    private func bodyBlock(_ line: String) -> some View {
        Text(line)
            .font(.custom("DMSans-Regular", size: 36))
            .lineSpacing(10)
            .foregroundStyle(Color(hex: "#3D2B2B").opacity(0.80))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Wordmark + day mark

    @ViewBuilder private var wordmarkBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("JENIFIT")
                .font(.custom("Fraunces72pt-SemiBold", size: 44))
                .foregroundStyle(Color(hex: "#3D2B2B"))
                .kerning(4.6)
            Text(dayLabel.uppercased())
                .font(.custom("Fraunces72pt-Regular", size: 20))
                .foregroundStyle(Color(hex: "#3D2B2B").opacity(0.55))
                .kerning(2.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
