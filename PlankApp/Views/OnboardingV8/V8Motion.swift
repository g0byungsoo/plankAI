import SwiftUI

// MARK: - Onboarding v8 — THE CONSULT motion layer
//
// docs/onboarding_v8/00_DIRECTION.md §6 is the law for every number
// here. The consult is ONE continuous experience: jeni writes ink on
// paper (char-typed serif), the system declares on ink chapters
// (line cascade), and surfaces crossfade in place. Nothing pushes,
// nothing slides, nothing appears.

enum V8Tempo {
    /// Base typing clock. Punctuation breathes (the reference's
    /// human cadence): commas hold, sentence ends hold longer.
    static let perChar: Double = 0.034
    static let commaPause: Double = 0.16
    static let sentencePause: Double = 0.32
    /// Between messages of the same beat.
    static let interLine: Double = 0.42
    /// Question finished → options arrive.
    static let optionsDelay: Double = 0.22
    /// Selected state holds before the options dissolve.
    static let selectedHold: Double = 0.20
    /// Options gone → ack starts typing.
    static let ackDelay: Double = 0.14
    /// Statement beats hold before auto-advancing.
    static let statementHold: Double = 1.05
    /// Surface flips (paper ↔ ink) — in place, never a slide.
    static let surfaceFlip: Double = 0.55

    /// The transcript's advance (previous line dims + rises).
    static let advance = Animation.spring(response: 0.55, dampingFraction: 0.90)
    /// The anchor's travel between talk (mid) and ask (top) modes.
    static let anchorShift = Animation.spring(response: 0.60, dampingFraction: 0.88)
    /// Input arrival — the kit's quiet rise.
    static let inputArrive = Animation.spring(response: 0.50, dampingFraction: 0.86)
    /// Input dissolve on answer.
    static let inputDissolve = Animation.easeIn(duration: 0.20)

    /// Chapter cascade: line-by-line, a tick per line (her75).
    static let cascadeStagger: Double = 0.36
    static let cascade = Animation.spring(response: 0.62, dampingFraction: 0.92)

    /// Transcript opacity ladder: active → previous → older → gone.
    static let dim1: Double = 0.42
    static let dim2: Double = 0.16
}

// MARK: - The ink environment
//
// One flag flips a subtree between paper (ink type) and ink (paper
// type). Chrome, transcript and pills all read it — the surface flip
// is a background crossfade plus this bit.

private struct V8OnInkKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var v8OnInk: Bool {
        get { self[V8OnInkKey.self] }
        set { self[V8OnInkKey.self] = newValue }
    }
}

enum V8InkAware {
    static func text(_ onInk: Bool) -> Color {
        onInk ? Palette.textInverse : Palette.textPrimary
    }
    static func secondary(_ onInk: Bool) -> Color {
        onInk ? Palette.textInverse.opacity(0.66) : Palette.textSecondary
    }
    static func tertiary(_ onInk: Bool) -> Color {
        onInk ? Palette.textInverse.opacity(0.45) : Palette.cocoaTertiary
    }
    static func hairline(_ onInk: Bool) -> Color {
        onInk ? Palette.textInverse.opacity(0.16) : Palette.hairlineCocoa
    }
    static func surface(_ onInk: Bool) -> Color {
        onInk ? Palette.bgInverse : Palette.bgPrimary
    }
}

// MARK: - V8Line
//
// One utterance = one transcript message. `italic` words carry the
// brand's punch (composition, never markers). `user` marks her own
// words (the typed name) — same ink, same serif: the consult is one
// written page.

struct V8Line: Equatable {
    var text: String
    var italic: [String] = []
    var user: Bool = false
    /// Evidence rides inside the conversation: a quiet source line
    /// that fades in once the message finishes writing (evidence law).
    var citation: String? = nil
    /// Drawn evidence: a figure that draws itself under the message
    /// once the ink has finished arriving (the founder's charts steer).
    var figure: V8Figure? = nil

    init(_ text: String, italic: [String] = [], user: Bool = false,
         citation: String? = nil, figure: V8Figure? = nil) {
        self.text = text
        self.italic = italic
        self.user = user
        self.citation = citation
        self.figure = figure
    }
}

// MARK: - V8LineText — the stable-layout typewriter
//
// The whole line is laid out from the first frame; unrevealed
// characters are painted clear. Wrapping therefore never reflows
// mid-type — the ink simply arrives. (The reference visibly re-wraps
// as words pop to the next line; this is the part we do better.)

struct V8LineText: View {
    let line: V8Line
    /// Characters revealed. `.max` = fully written.
    var revealed: Int = .max
    var font: Font
    var italicFont: Font
    var color: Color

    var body: some View {
        Text(composed)
            .lineSpacing(-2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(Text(line.text))
    }

    private var composed: AttributedString {
        var attr = AttributedString(line.text)
        attr.font = font
        attr.foregroundColor = color

        // The italic punch — exact-substring runs, composed.
        for word in line.italic {
            if let range = attr.range(of: word) {
                attr[range].font = italicFont
            }
        }

        // Reveal by paint: everything past `revealed` is clear.
        if revealed < line.text.count {
            let chars = attr.characters
            if let cut = chars.index(chars.startIndex, offsetBy: revealed, limitedBy: chars.endIndex) {
                attr[cut...].foregroundColor = .clear
            }
        }
        return attr
    }
}

// MARK: - Typing clock
//
// The stage drives reveals through this one helper so cadence lives
// in a single place. Returns the delay to hold AFTER revealing the
// character at `index`.

enum V8TypeClock {
    static func delay(after index: Int, in text: String) -> Double {
        let chars = Array(text)
        guard index < chars.count else { return 0 }
        let c = chars[index]
        let next = index + 1 < chars.count ? chars[index + 1] : " "
        if (c == "." || c == "!" || c == "?"), next == " " || index == chars.count - 1 {
            return V8Tempo.perChar + V8Tempo.sentencePause
        }
        if c == "," { return V8Tempo.perChar + V8Tempo.commaPause }
        if c == "\n" { return V8Tempo.perChar + V8Tempo.sentencePause }
        return V8Tempo.perChar
    }
}

// MARK: - V8Blooms — ambient life for ink chapters
//
// The reference's drifting blobs, translated: two ultra-soft paper
// blooms (≤4%) on mutually-prime orbits. Self-driven from `.task`
// (the Canvas law); Reduce Motion holds them still, present.

struct V8Blooms: View {
    var strength: Double = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var t: Double = 0

    var body: some View {
        Canvas { ctx, size in
            func bloom(cx: Double, cy: Double, r: Double, alpha: Double) {
                let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                let gradient = Gradient(stops: [
                    .init(color: Palette.textInverse.opacity(alpha * strength), location: 0),
                    .init(color: Palette.textInverse.opacity(0), location: 1),
                ])
                ctx.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        gradient,
                        center: CGPoint(x: cx, y: cy),
                        startRadius: 0, endRadius: r
                    )
                )
            }
            let w = size.width, h = size.height
            // Mutually-prime periods so the pair never visibly loops.
            bloom(
                cx: w * (0.24 + 0.10 * sin(t / 13.0)),
                cy: h * (0.20 + 0.08 * cos(t / 17.0)),
                r: w * 0.52, alpha: 0.045
            )
            bloom(
                cx: w * (0.78 + 0.09 * cos(t / 19.0)),
                cy: h * (0.68 + 0.10 * sin(t / 23.0)),
                r: w * 0.60, alpha: 0.035
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 33_000_000)
                t += 0.033
            }
        }
    }
}

// MARK: - V8ProgressHairline
//
// The consult's only chrome besides the chevron: a 2pt hairline that
// fills as the file does. Ink-aware; animates on a spring.

struct V8ProgressHairline: View {
    let fraction: Double
    @Environment(\.v8OnInk) private var onInk

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(V8InkAware.hairline(onInk))
                Capsule()
                    .fill(V8InkAware.text(onInk).opacity(onInk ? 0.85 : 0.72))
                    .frame(width: max(6, geo.size.width * fraction))
                    .animation(V8Tempo.advance, value: fraction)
            }
        }
        .frame(height: 2)
        .accessibilityHidden(true)
    }
}
