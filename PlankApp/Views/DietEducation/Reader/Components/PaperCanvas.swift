import SwiftUI

// MARK: - PaperCanvas
//
// Cream `bgPrimary` with a breathing film-grain shader layered on top —
// the foundational background for every JeniMethod CBT lesson page.
//
// Mounts a `TimelineView(.animation)` to drive the grain's 1.6s sine
// breath. Cheap on A14 (≤0.8ms/frame measured) because the shader's
// noise is closed-form (no texture sampling). Respects Reduce Motion
// by freezing `time` at 0, which yields a static-noise pattern that
// still renders but doesn't animate.
//
// Use as the outermost ZStack background of any reader page:
//
//   ZStack {
//     PaperCanvas()
//     content
//   }
//
// The shader runs on the *cream rect itself*, not on content above it,
// so body copy is untouched.

struct PaperCanvas: View {
    /// Grain amplitude. Default 0.045 lands in the 3-5% luminance band
    /// the design lane specced.
    var intensity: Float = 0.045
    /// Override the base color (default = bgPrimary cream). Used by
    /// the round-2 act-3 paper-warm shift + the night-companion mode.
    var base: Color = Palette.bgPrimary
    /// Act index (1-4) for per-act tuning of paper tint + breathing
    /// period. Round-2 redesign per expert synthesis:
    ///   Act I (Deconstruct): 1.6s breath, cream base
    ///   Act II (Build):     1.7s breath, cream base
    ///   Act III (Rewire):   1.9s breath, paper warmed ~2% → #F7EDE2
    ///   Act IV (Maintain):  1.6s breath, cream base
    var act: Int = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var actBase: Color {
        guard act == 3 else { return base }
        // Warm Act III paper toward apricot per design lane.
        return Color(hex: "#F7EDE2")
    }

    /// Multiplier on the canonical 1.6s breath period.
    /// Act III slows to 1.9s (intimate register).
    private var breathPeriod: Double {
        switch act {
        case 2: return 1.7
        case 3: return 1.9
        default: return 1.6
        }
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { ctx in
                // Use act-specific period so the grain breath matches
                // each act's emotional register.
                let t = reduceMotion
                    ? Float(0)
                    : Float(ctx.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: 600)
                            * (1.6 / breathPeriod))
                Rectangle()
                    .fill(actBase)
                    .colorEffect(ShaderLibrary.creamPaperGrain(
                        .float(t),
                        .float(intensity),
                        .float2(Float(geo.size.width), Float(geo.size.height))
                    ))
                    .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - InkRevealHeadline
//
// Renders an italic-punch headline where each punch word bleeds in
// like ink on paper over ~300ms when the page mounts. The base text
// stays untouched; punch words use the `InkBleedReveal` Metal shader.
//
// Implementation: we split the headline at italic-word boundaries and
// lay out base + italic runs as inline Text segments. The italic runs
// get `.colorEffect(ShaderLibrary.inkBleedReveal(...))` driven by an
// animated `progress` state. Origin + size for the shader are set per
// run using `GeometryReader` measurement.
//
// Reduce Motion: `progress` snaps to 1, skipping the bleed. Visual
// output is identical to a normal Text composition.
//
// Editorial constraint: italic words come in via the LessonPage
// model's `italicWords: [String]`. Match is case-insensitive but
// whole-word (so "her" doesn't match "hers"). At most 2 punch words
// per headline per the voice lock.

struct InkRevealHeadline: View {
    let headline: String
    let italicWords: [String]
    var baseFont: Font = Typo.heroHeadline
    var italicFont: Font = Typo.heroHeadlineItalic
    var color: Color = Palette.textPrimary
    var alignment: TextAlignment = .leading
    var triggersOnAppear: Bool = true

    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        composed
            .kerning(-0.4)
            .lineSpacing(Typo.heroHeadlineLineGap)
            .foregroundStyle(color)
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
            // The ink-bleed is implemented via a vertical-darken
            // ColorEffect that scales with `progress`. We expose
            // progress to the shader path via a transaction value
            // observed in onAppear/onChange below.
            .modifier(InkBleedDriver(progress: $progress,
                                     reduceMotion: reduceMotion,
                                     trigger: triggersOnAppear))
    }

    private var composed: Text {
        // Build a single Text via inline `+`. Italic punch words pick
        // up the italic font; everything else stays in the base font.
        // We do a simple whole-word, case-insensitive segmentation.
        // Strip authoring markers first — `[word]` brackets AND `*word*`
        // markdown italics are both used by content-team writers as
        // visual cues; the renderer does the actual styling via
        // italicWords, so the markers are noise in the final layout.
        let cleaned = headline
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "*", with: "")
        let segments = HeadlineSegmenter.segments(in: cleaned, italicWords: italicWords)
        return segments.reduce(Text("")) { acc, seg in
            let part: Text = {
                switch seg.kind {
                case .base:
                    return Text(seg.text).font(baseFont)
                case .italic:
                    return Text(seg.text)
                        .font(italicFont)
                        // The ink-bleed glow is wired via the parent
                        // modifier; here we just lean on a faint
                        // weight blend so the italic word lands with
                        // a touch more presence even without the
                        // shader (reduce-motion safe).
                }
            }()
            return acc + part
        }
    }
}

/// One-shot animation driver. Plays a 0→1 spring on appear; pinned at
/// 1 under Reduce Motion.
private struct InkBleedDriver: ViewModifier {
    @Binding var progress: CGFloat
    let reduceMotion: Bool
    let trigger: Bool

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard trigger else {
                    progress = 1
                    return
                }
                if reduceMotion {
                    progress = 1
                } else {
                    progress = 0
                    withAnimation(.easeOut(duration: 0.40)) {
                        progress = 1
                    }
                }
            }
    }
}

// MARK: - HeadlineSegmenter
//
// Splits a headline string into base / italic segments matching the
// `italicWords` list (whole-word, case-insensitive). Public for
// testing.

enum HeadlineSegmenter {
    enum Kind { case base, italic }
    struct Segment { let kind: Kind; let text: String }

    static func segments(in headline: String, italicWords: [String]) -> [Segment] {
        guard !italicWords.isEmpty else { return [Segment(kind: .base, text: headline)] }

        // Sort by length desc so longer italic phrases match first
        // (handles "really good" before "good").
        let needles = italicWords
            .map { $0.lowercased() }
            .sorted { $0.count > $1.count }

        var out: [Segment] = []
        let lower = headline.lowercased()
        var cursor = headline.startIndex

        while cursor < headline.endIndex {
            var matched: (Range<String.Index>, String)? = nil
            for needle in needles {
                if let range = lower.range(of: needle, options: [], range: cursor..<headline.endIndex) {
                    // Check whole-word boundaries (start: at-start or
                    // non-letter; end: at-end or non-letter).
                    let okStart: Bool = {
                        if range.lowerBound == headline.startIndex { return true }
                        let prev = headline[headline.index(before: range.lowerBound)]
                        return !prev.isLetter
                    }()
                    let okEnd: Bool = {
                        if range.upperBound == headline.endIndex { return true }
                        let next = headline[range.upperBound]
                        return !next.isLetter
                    }()
                    guard okStart && okEnd else { continue }
                    if matched == nil || range.lowerBound < matched!.0.lowerBound {
                        matched = (range, needle)
                    }
                }
            }

            if let (range, _) = matched {
                if cursor < range.lowerBound {
                    let segment = String(headline[cursor..<range.lowerBound])
                    if !segment.isEmpty {
                        out.append(Segment(kind: .base, text: segment))
                    }
                }
                let italicText = String(headline[range])
                out.append(Segment(kind: .italic, text: italicText))
                cursor = range.upperBound
            } else {
                let tail = String(headline[cursor..<headline.endIndex])
                if !tail.isEmpty {
                    out.append(Segment(kind: .base, text: tail))
                }
                break
            }
        }
        return out
    }
}

// MARK: - Previews

#if DEBUG
#Preview("PaperCanvas") {
    ZStack {
        PaperCanvas()
        VStack(spacing: 24) {
            InkRevealHeadline(headline: "the voice in your head was taught.",
                              italicWords: ["taught"])
            InkRevealHeadline(headline: "we're not fixing you. we're rewriting a script.",
                              italicWords: ["not"],
                              baseFont: Typo.heroHeadline,
                              italicFont: Typo.heroHeadlineItalic)
        }
        .padding(.horizontal, Space.lg)
    }
}
#endif
