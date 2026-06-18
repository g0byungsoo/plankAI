import SwiftUI
#if canImport(UIKit)
import UIKit

// MARK: - HandwrittenLessonQuoteCard
//
// v1.0.10 (2026-06-17) — Pinterest it-girl variant of the lesson
// quote share card. Typography-only (no photos), but reuses the same
// handwritten typography family + butter-cream gradient + paper grain
// as HandwrittenDailyShareCard / HandwrittenWeeklyShareCard so the
// three handwritten surfaces feel like one IG-Story brand.
//
// Layout (1080×1920 top-down):
//   - 0    →  240pt: editorial eyebrow (handwritten) + day mark capsule
//   - 240  →  280pt: hand-drawn hairline divider
//   - 280  → 1380pt: hero quote — italic Bradley-Hand-Bold on punch words,
//                     Noteworthy-Light on the rest; body line below in
//                     smaller Noteworthy with a hand-drawn underline accent
//   - 1380 → 1640pt: pillar attribution in Snell Roundhand italic
//   - 1640 → 1920pt: jenifit wordmark + bottom inset
//
// All glyphs are bundled-on-iOS handwriting fonts or SF Symbols —
// no asset cost, no extra fonts to download.

struct HandwrittenLessonQuoteCard: View {

    let headline: String
    let italicWords: [String]
    let bodyLine: String?
    let dayLabel: String
    let pillarTitle: String

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer().frame(height: 130)
                eyebrowRow.padding(.horizontal, 80)
                Spacer().frame(height: 12)
                hairlineDivider.padding(.horizontal, 80)
                Spacer().frame(height: 80)

                heroQuote.padding(.horizontal, 70)

                if let bodyLine, !bodyLine.isEmpty {
                    Spacer().frame(height: 42)
                    bodyLineView(bodyLine).padding(.horizontal, 90)
                }

                Spacer()

                attribution.padding(.horizontal, 80)
                Spacer().frame(height: 28)
                wordmark
                Spacer().frame(height: 76)
            }

            decorativeOverlay
        }
        .frame(width: 1080, height: 1920)
    }

    // MARK: - Background

    @ViewBuilder private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.985, green: 0.945, blue: 0.880),
                    Color(red: 0.972, green: 0.917, blue: 0.864),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Canvas { ctx, size in
                var rng = HandwrittenLessonSplitMix64(seed: 7_032_104)
                for _ in 0..<320 {
                    let x = CGFloat(rng.nextDouble()) * size.width
                    let y = CGFloat(rng.nextDouble()) * size.height
                    let r = 0.6 + CGFloat(rng.nextDouble()) * 1.2
                    let opacity = 0.04 + CGFloat(rng.nextDouble()) * 0.06
                    var path = Path()
                    path.addEllipse(in: CGRect(x: x, y: y, width: r, height: r))
                    ctx.fill(path, with: .color(.black.opacity(opacity)))
                }
            }
            .blendMode(.multiply)
        }
    }

    // MARK: - Eyebrow + day capsule

    @ViewBuilder private var eyebrowRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("the jenifit method")
                .font(.custom("BradleyHandITCTT-Bold", size: 28))
                .foregroundStyle(Color(red: 0.45, green: 0.30, blue: 0.30))
            Spacer()
            Text(dayLabel.lowercased())
                .font(.custom("BradleyHandITCTT-Bold", size: 24))
                .foregroundStyle(Color(red: 0.45, green: 0.30, blue: 0.30))
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.72))
                        .overlay(
                            Capsule().stroke(
                                Color(red: 0.85, green: 0.55, blue: 0.62).opacity(0.55),
                                style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])
                            )
                        )
                )
        }
    }

    // MARK: - Hand-drawn hairline

    /// Wavy underline using a single cubic bezier — gives the feel
    /// of a hand-pulled marker line instead of a flat 1pt rectangle.
    @ViewBuilder private var hairlineDivider: some View {
        WavyLine()
            .stroke(
                Color(red: 0.50, green: 0.30, blue: 0.30).opacity(0.30),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
            .frame(height: 14)
    }

    // MARK: - Hero quote with italic punch words

    @ViewBuilder private var heroQuote: some View {
        composedQuoteText()
            .foregroundStyle(Color(red: 0.45, green: 0.22, blue: 0.30))
            .multilineTextAlignment(.leading)
            .lineSpacing(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Token-walks the headline and renders italic-punch words in
    /// Bradley-Hand-Bold (the "heavier hand" cuts a punch out of the
    /// surrounding Noteworthy-Light flow). Same italicWords matching
    /// logic as the editorial LessonQuoteCard so writers don't need
    /// to learn two systems.
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
                out = out + Text(token)
                    .font(.custom("BradleyHandITCTT-Bold", size: 68))
                    .foregroundColor(Color(red: 0.78, green: 0.32, blue: 0.40))
            } else {
                out = out + Text(token)
                    .font(.custom("Noteworthy-Light", size: 60))
            }
            if i < tokens.count - 1 {
                out = out + Text(" ").font(.custom("Noteworthy-Light", size: 60))
            }
        }
        return out
    }

    @ViewBuilder
    private func bodyLineView(_ line: String) -> some View {
        Text(line)
            .font(.custom("Noteworthy-Light", size: 30))
            .lineSpacing(6)
            .foregroundStyle(Color(red: 0.45, green: 0.30, blue: 0.30).opacity(0.85))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Attribution + wordmark

    @ViewBuilder private var attribution: some View {
        HStack(spacing: 14) {
            // Heart accent + pillar in Snell italic so the bottom mark
            // reads as a hand-signed credit, not a corporate tag.
            Image(systemName: "heart.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color(red: 0.93, green: 0.55, blue: 0.65).opacity(0.70))
            Text(pillarTitle)
                .font(.custom("SnellRoundhand-Bold", size: 36))
                .foregroundStyle(Color(red: 0.50, green: 0.28, blue: 0.32))
            Spacer()
        }
    }

    @ViewBuilder private var wordmark: some View {
        HStack(spacing: 8) {
            Spacer()
            Image(systemName: "heart.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color(red: 0.93, green: 0.55, blue: 0.65).opacity(0.55))
            Text("jenifit")
                .font(.custom("SnellRoundhand-Bold", size: 38))
                .foregroundStyle(Color(red: 0.70, green: 0.30, blue: 0.42).opacity(0.62))
            Spacer()
        }
    }

    // MARK: - Decorative overlay (3-scatter rule)

    @ViewBuilder private var decorativeOverlay: some View {
        ZStack {
            Image(systemName: "sparkle")
                .font(.system(size: 30))
                .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.50).opacity(0.78))
                .rotationEffect(.degrees(-12))
                .position(x: 130, y: 250)

            Image(systemName: "cloud.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.white.opacity(0.78))
                .position(x: 960, y: 350)

            Image(systemName: "heart.fill")
                .font(.system(size: 26))
                .foregroundStyle(Color(red: 0.95, green: 0.62, blue: 0.70).opacity(0.78))
                .rotationEffect(.degrees(16))
                .position(x: 980, y: 1620)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - WavyLine

/// Simple cubic bezier that mimics a hand-drawn underline. Two humps
/// across the rect width, rendered with rounded line cap.
struct WavyLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mid = rect.midY
        path.move(to: CGPoint(x: rect.minX, y: mid))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: mid),
            control1: CGPoint(x: rect.minX + rect.width * 0.25, y: mid - 6),
            control2: CGPoint(x: rect.minX + rect.width * 0.25, y: mid + 6)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: mid),
            control1: CGPoint(x: rect.midX + rect.width * 0.25, y: mid - 6),
            control2: CGPoint(x: rect.midX + rect.width * 0.25, y: mid + 6)
        )
        return path
    }
}

// MARK: - HandwrittenLessonQuoteRenderer

@MainActor
enum HandwrittenLessonQuoteRenderer {

    static func render(
        headline: String,
        italicWords: [String],
        bodyLine: String?,
        dayLabel: String,
        pillarTitle: String
    ) -> UIImage? {
        let card = HandwrittenLessonQuoteCard(
            headline: headline,
            italicWords: italicWords,
            bodyLine: bodyLine,
            dayLabel: dayLabel,
            pillarTitle: pillarTitle
        )
        .frame(width: 1080, height: 1920)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 1.0
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1920)
        return renderer.uiImage
    }
}

// MARK: - SplitMix64 (renamed to avoid clashing across files)

private struct HandwrittenLessonSplitMix64 {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func nextDouble() -> Double {
        Double(next() >> 11) * (1.0 / Double(1 << 53))
    }
}

#endif  // canImport(UIKit)
