import SwiftUI

// MARK: - Option model

struct OV5Option: Identifiable, Equatable {
    let key: String
    let label: String
    var sub: String? = nil
    var icon: String? = nil          // SF Symbol, optional
    var leadingAsset: String? = nil  // bundled image (attribution logos)
    var id: String { key }
}

// MARK: - OV5SelectRow (the cross-off signature)
//
// her75 IMG_6262/6263 promoted to the system-wide single-select: rows
// are LEFT-anchored radio rows (not full-width cards). On pick, the
// chosen radio fills cocoa with a drawn check; every other row draws a
// 1.5pt strikethrough left-to-right (180ms, 40ms stagger) while fading
// to 38%, then the flow auto-advances. Strike = "decided" — multi-
// selects never strike.

struct OV5SelectRow: View {
    let option: OV5Option
    let isSelected: Bool
    let isStruck: Bool
    let strikeDelay: Double
    let action: () -> Void

    @State private var strikeProgress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? Palette.cocoaPrimary : Palette.cocoaPrimary.opacity(0.28),
                            lineWidth: 1.5
                        )
                        .frame(width: 26, height: 26)
                    if isSelected {
                        Circle()
                            .fill(Palette.cocoaPrimary)
                            .frame(width: 26, height: 26)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.textInverse)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }
                .animation(Motion.bloom, value: isSelected)

                if let asset = option.leadingAsset {
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .saturation(isStruck ? 0 : 1)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label)
                        .font(.custom("DMSans-Medium", size: 19))
                        .foregroundStyle(Palette.textPrimary)
                        .overlay(alignment: .leading) {
                            // The cross-off line, drawn over the label only.
                            GeometryReader { geo in
                                Capsule()
                                    .fill(Palette.textPrimary.opacity(0.55))
                                    .frame(width: geo.size.width * strikeProgress, height: 1.5)
                                    .frame(maxHeight: .infinity, alignment: .center)
                            }
                            .allowsHitTesting(false)
                        }
                    if let sub = option.sub {
                        Text(sub)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }

                Spacer(minLength: 0)

                if let icon = option.icon, !isStruck {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(Palette.cocoaTertiary)
                }
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .opacity(isStruck ? 0.38 : 1)
            .animation(.easeOut(duration: 0.25).delay(strikeDelay), value: isStruck)
        }
        .buttonStyle(.plain)
        .onChange(of: isStruck) { _, struck in
            guard struck else { strikeProgress = 0; return }
            if reduceMotion { strikeProgress = 1; return }
            withAnimation(.easeOut(duration: 0.18).delay(strikeDelay)) {
                strikeProgress = 1
            }
        }
        .onAppear {
            // Back-nav re-entry: render the decided state statically.
            strikeProgress = isStruck ? 1 : 0
        }
    }
}

// MARK: - OV5SelectList (single-select + auto-advance)

struct OV5SelectList: View {
    let options: [OV5Option]
    @Binding var selection: String
    /// Sensitive screens (GLP-1, medication, hormonal) pass false and
    /// dock an explicit continue — deliberateness reads as respect.
    var autoAdvance: Bool = true
    /// Per-answer auto-advance dwell. Screens that reply to specific
    /// answers with an inline acknowledgment return a longer dwell for
    /// those keys so the line is readable before the advance; nil =
    /// the standard 0.45s everywhere. Runs through the same committed
    /// guard as the default, so back-nav + same-answer re-taps still
    /// advance (the onChange-driven variants this replaces could
    /// strand that path — no value change, no advance, no CTA).
    var advanceDelay: ((String) -> Double)? = nil
    var onCommit: (() -> Void)? = nil

    @State private var committed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.element.key) { idx, opt in
                    OV5SelectRow(
                        option: opt,
                        isSelected: selection == opt.key,
                        isStruck: !selection.isEmpty && selection != opt.key,
                        strikeDelay: Double(strikeOrder(of: idx)) * 0.04,
                        action: { pick(opt.key) }
                    )
                    .ov5Beat2(extraDelay: Double(idx) * Motion.revealStagger)
                    if idx < options.count - 1 {
                        Rectangle()
                            .fill(Palette.hairlineCocoa)
                            .frame(height: 0.33)
                            .ov5Beat2(extraDelay: Double(idx) * Motion.revealStagger)
                    }
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.md)
            .padding(.bottom, Space.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollEdgeFade()
        .onAppear { committed = false }
    }

    /// Strike stagger runs top-to-bottom over the rows that strike
    /// (haptic ticks capped at 4 so long lists don't buzz).
    private func strikeOrder(of index: Int) -> Int { index }

    private func pick(_ key: String) {
        guard !committed || !autoAdvance else { return }
        Haptics.soft()
        withAnimation(Motion.tap) { selection = key }
        // Soft ticks as strikes land — one per row, max 4.
        let struckCount = min(options.count - 1, 4)
        for i in 1...max(struckCount, 1) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04 * Double(i)) {
                Haptics.tick()
            }
        }
        if autoAdvance, !committed {
            committed = true
            let dwell = advanceDelay?(key) ?? 0.45
            DispatchQueue.main.asyncAfter(deadline: .now() + dwell) {
                onCommit?()
            }
        }
    }
}

// MARK: - OV5MultiList (chips-free multi-select rows, no strike)

struct OV5MultiList: View {
    let options: [OV5Option]
    @Binding var selection: Set<String>
    /// Picking an exclusive key (e.g. "none") clears the rest.
    var exclusiveKeys: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.element.key) { idx, opt in
                    let isOn = selection.contains(opt.key)
                    Button {
                        Haptics.soft()
                        withAnimation(Motion.tap) {
                            if isOn { selection.remove(opt.key) }
                            else if exclusiveKeys.contains(opt.key) { selection = [opt.key] }
                            else {
                                selection.insert(opt.key)
                                selection.subtract(exclusiveKeys)
                            }
                        }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(
                                        isOn ? Palette.cocoaPrimary : Palette.cocoaPrimary.opacity(0.28),
                                        lineWidth: 1.5
                                    )
                                    .frame(width: 24, height: 24)
                                if isOn {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(Palette.cocoaPrimary)
                                        .frame(width: 24, height: 24)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Palette.textInverse)
                                }
                            }
                            .animation(Motion.bloom, value: isOn)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(opt.label)
                                    .font(.custom("DMSans-Medium", size: 18))
                                    .foregroundStyle(Palette.textPrimary)
                                if let sub = opt.sub {
                                    Text(sub)
                                        .font(Typo.caption)
                                        .foregroundStyle(Palette.textSecondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .ov5Beat2(extraDelay: Double(idx) * Motion.revealStagger)

                    if idx < options.count - 1 {
                        Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.33)
                            .ov5Beat2(extraDelay: Double(idx) * Motion.revealStagger)
                    }
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.md)
            .padding(.bottom, Space.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollEdgeFade()
    }
}

// MARK: - OV5TrustLine
//
// The one-line "we ask because" anchor under sensitive headers. Quiet
// by design: lock glyph + caption, max one per screen.

struct OV5TrustLine: View {
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock")
                .font(.system(size: 10, weight: .medium))
            Text(text)
                .font(Typo.caption)
        }
        .foregroundStyle(Palette.cocoaTertiary)
        .padding(.horizontal, Space.lg)
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
    }
}

// MARK: - OV5StatementYesNo (the fears register)
//
// Giant centered serif first-person statement + two docked pills.
// Answering "no" strikes the statement itself through (she crosses out
// a fear that isn't hers); "yes" pins it with a quiet promise line.
// Auto-advances ~0.7s after the answer lands.

struct OV5StatementYesNo: View {
    let statement: String
    let italic: [String]
    let onAnswer: (Bool) -> Void

    @State private var answer: Bool? = nil
    @State private var strike: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ItalicAccentText(
                statement,
                italic: italic,
                baseFont: Typo.heroHeadline,
                italicFont: Typo.heroHeadlineItalic,
                alignment: .center
            )
            .lineSpacing(Typo.heroHeadlineLineGap)
            .kerning(-0.4)
            .padding(.horizontal, Space.lg)
            .overlay {
                if answer == false {
                    GeometryReader { geo in
                        Capsule()
                            .fill(Palette.textPrimary.opacity(0.6))
                            .frame(width: (geo.size.width - Space.lg * 2) * strike, height: 2)
                            .offset(x: Space.lg)
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .allowsHitTesting(false)
                }
            }
            .ov5Beat1()

            if answer == true {
                Text("we'll come back for this one.")
                    .font(Typo.teachSub)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, Space.lg)
                    .transition(.opacity.combined(with: .offset(y: 6)))
            }

            Spacer()

            HStack(spacing: 12) {
                pill("not really", filled: false) { commit(false) }
                pill("yes, that's me", filled: true) { commit(true) }
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.lg)
            .ov5Beat2()
        }
    }

    private func pill(_ label: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.custom("DMSans-SemiBold", size: 16))
                .foregroundStyle(filled ? Palette.textInverse : Palette.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule().fill(filled ? Palette.cocoaPrimary : Palette.bgElevated)
                )
                .overlay(
                    Capsule().strokeBorder(
                        filled ? Color.clear : Palette.cocoaPrimary.opacity(0.22),
                        lineWidth: 1.5
                    )
                )
        }
        .buttonStyle(PressFeedbackStyle())
        .disabled(answer != nil)
    }

    private func commit(_ yes: Bool) {
        guard answer == nil else { return }
        Haptics.soft()
        withAnimation(Motion.entranceSoft) { answer = yes }
        if !yes {
            if reduceMotion { strike = 1 } else {
                withAnimation(.easeOut(duration: 0.22).delay(0.05)) { strike = 1 }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { onAnswer(yes) }
    }
}

// MARK: - OV5PhotoGrid (identity + cuisine)
//
// 2-column 4:5 cards: image fills the top, radio + 2-4 word label row
// below, bgElevated + 0.33pt hairline, no shadow. Selected: 2pt cocoa
// border + others dim to 60%.

struct OV5PhotoCard: View {
    let option: OV5Option
    let asset: String
    let isSelected: Bool
    let isDimmed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Image(asset)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(0.92, contentMode: .fit)
                    .clipped()
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .strokeBorder(
                                    isSelected ? Palette.cocoaPrimary : Palette.cocoaPrimary.opacity(0.28),
                                    lineWidth: 1.5
                                )
                                .frame(width: 20, height: 20)
                            if isSelected {
                                Circle().fill(Palette.accent).frame(width: 11, height: 11)
                            }
                        }
                        Text(option.label)
                            .font(.custom("DMSans-Medium", size: 15))
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                }
                .background(Palette.bgElevated)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? Palette.cocoaPrimary : Palette.hairlineCocoa,
                        lineWidth: isSelected ? 2 : 0.66
                    )
            )
            .opacity(isDimmed ? 0.6 : 1)
            .animation(Motion.tap, value: isSelected)
        }
        .buttonStyle(PressFeedbackStyle())
    }
}

// MARK: - OV5TeachView (conviction register)

struct OV5TeachPoint: Identifiable {
    let numeral: String
    let punch: String
    let gloss: String
    var id: String { numeral }
}

/// v6 P2 — drawn teach figures. The teach screens carry the flow's
/// densest conviction copy on its flattest compositions; each figure
/// is a small ink-and-rose drawing in the OV5ReboundCurve family
/// (shape only, no fabricated axis numbers — the data-provenance
/// rule applies to pictures too). Housed here per the house pattern
/// (zero new-file/pbxproj risk).
enum OV5TeachFigureKind {
    /// Food noise as a waveform that quiets: loud jitter settling to
    /// a calm line with the rose dose-dot at the terminus.
    case foodNoiseWave
    /// What's lost on the shot: a loss bar whose smaller share is
    /// muscle — the share protein + movement protect. Proportions
    /// visually honest (~60/40 per STEP-1 lean-mass sub-analysis),
    /// no percentage printed.
    case muscleComposition
}

/// Deterministic "noise" waveform (summed fixed-phase sines under a
/// decaying envelope) that settles calm. Draws on via trim; the rose
/// dot lands at the quiet end. Reduce-motion renders complete.
struct OV5FoodNoiseWaveFigure: View {
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let midY = h * 0.52
            ZStack(alignment: .topLeading) {
                wavePath(w: w, h: h)
                    .trim(from: 0, to: progress)
                    .stroke(Palette.cocoaPrimary,
                            style: StrokeStyle(lineWidth: 1.6, lineCap: .round))

                // The dose-dot lands where the noise has settled.
                Circle()
                    .fill(Palette.accent)
                    .frame(width: 6, height: 6)
                    .position(x: w - 4, y: midY)
                    .opacity(progress > 0.97 ? 1 : 0)
                    .animation(.easeOut(duration: 0.25), value: progress > 0.97)

                Text("the noise")
                    .font(.custom("DMSans-Regular", size: 11))
                    .foregroundStyle(Palette.cocoaSecondary)
                    .offset(x: w * 0.02, y: h * 0.02)
                    .opacity(progress > 0.3 ? 1 : 0)
                Text("quieter")
                    .font(.custom("DMSans-Regular", size: 11))
                    .foregroundStyle(Palette.accent)
                    .offset(x: w * 0.78, y: midY + 12)
                    .opacity(progress > 0.85 ? 1 : 0)
            }
            .animation(.easeOut(duration: 0.3), value: progress > 0.3)
            .animation(.easeOut(duration: 0.3), value: progress > 0.85)
        }
        .frame(height: 88)
        .onAppear {
            if reduceMotion { progress = 1; return }
            withAnimation(.easeOut(duration: 1.1).delay(0.45)) { progress = 1 }
        }
        .accessibilityLabel("A waveform that starts loud and jittery and settles into a calm quiet line.")
    }

    private func wavePath(w: CGFloat, h: CGFloat) -> Path {
        var p = Path()
        let midY = h * 0.52
        let steps = 160
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            // Envelope: loud through the first third, settling to a
            // near-flat murmur by the last quarter.
            let settle = max(0, min(1, (t - 0.18) / 0.62))
            let envelope = (1 - smoothstep(settle)) * 0.92 + 0.06
            let a = h * 0.34 * envelope
            let y = midY
                + a * (sin(t * 29 + 0.8) * 0.55
                       + sin(t * 71 + 2.1) * 0.30
                       + sin(t * 131) * 0.15)
            let pt = CGPoint(x: t * w, y: y)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }

    private func smoothstep(_ x: CGFloat) -> CGFloat { x * x * (3 - 2 * x) }
}

/// The loss-composition bar: what leaves on the shot is not all fat.
/// Rose block = the fat share; ink-hatched block = the muscle share,
/// bracketed as the part protein + movement protect.
struct OV5MuscleCompositionFigure: View {
    @State private var revealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Visual split only (no % printed): STEP-1 sub-analysis puts the
    /// lean-mass share of GLP-1 loss near 40%.
    private let muscleShare: CGFloat = 0.38

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let barH: CGFloat = 26
            let fatW = w * (1 - muscleShare)
            VStack(alignment: .leading, spacing: 8) {
                Text("what the scale loses")
                    .font(.custom("DMSans-Regular", size: 11))
                    .foregroundStyle(Palette.cocoaSecondary)
                    .opacity(revealed ? 1 : 0)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Palette.accentSubtle)
                        .frame(width: revealed ? fatW : 0, height: barH)
                    HatchedBlock()
                        .frame(width: revealed ? w * muscleShare : 0, height: barH)
                        .offset(x: fatW)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .frame(width: w, height: barH, alignment: .leading)

                HStack(alignment: .firstTextBaseline) {
                    Text("fat")
                        .font(.custom("DMSans-Regular", size: 11))
                        .foregroundStyle(Palette.cocoaSecondary)
                    Spacer()
                    Text("muscle · the share we protect")
                        .font(.custom("DMSans-Medium", size: 11))
                        .foregroundStyle(Palette.textPrimary)
                }
                .opacity(revealed ? 1 : 0)
            }
        }
        .frame(height: 84)
        .onAppear {
            if reduceMotion { revealed = true; return }
            withAnimation(.easeOut(duration: 0.7).delay(0.5)) { revealed = true }
        }
        .accessibilityLabel("A bar showing weight lost on the medication: the larger share is fat, and a meaningful share is muscle, the part protein and movement protect.")
    }
}

/// Thin diagonal ink hatching — the drawn "lean mass" texture.
private struct HatchedBlock: View {
    var body: some View {
        Canvas { context, size in
            var line = Path()
            let spacing: CGFloat = 6
            var x: CGFloat = -size.height
            while x < size.width {
                line.move(to: CGPoint(x: x, y: size.height))
                line.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += spacing
            }
            context.stroke(line, with: .color(Palette.cocoaPrimary.opacity(0.75)), lineWidth: 1.2)
        }
        .background(Palette.cocoaPrimary.opacity(0.06))
        .accessibilityHidden(true)
    }
}

struct OV5TeachView: View {
    let title: String
    var titleItalic: [String] = []
    var lead: String? = nil
    /// v6 P2 — optional drawn figure between the lead and the points
    /// (the whyItCameBack rebound-curve slot, generalized).
    var figure: OV5TeachFigureKind? = nil
    var points: [OV5TeachPoint] = []
    var closing: String? = nil
    var closingItalic: [String] = []
    var citation: String? = nil
    var ctaLabel: String = "continue"
    let onContinue: () -> Void

    var body: some View {
        OV5Screen {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    ItalicAccentText(
                        title,
                        italic: titleItalic,
                        baseFont: Typo.heroHeadline,
                        italicFont: Typo.heroHeadlineItalic,
                        alignment: .leading
                    )
                    .lineSpacing(Typo.heroHeadlineLineGap)
                    .kerning(-0.4)
                    .fixedSize(horizontal: false, vertical: true)
                    .ov5Beat1()

                    Group {
                        if let lead {
                            Text(lead)
                                .font(Typo.teachSub)
                                .lineSpacing(Typo.teachSubLineSpacing)
                                .foregroundStyle(Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        switch figure {
                        case .foodNoiseWave:
                            OV5FoodNoiseWaveFigure()
                                .padding(.vertical, Space.xs)
                        case .muscleComposition:
                            OV5MuscleCompositionFigure()
                                .padding(.vertical, Space.xs)
                        case nil:
                            EmptyView()
                        }

                        ForEach(Array(points.enumerated()), id: \.element.id) { idx, p in
                            VStack(alignment: .leading, spacing: 0) {
                                if idx > 0 {
                                    Rectangle().fill(Palette.hairlineCocoa)
                                        .frame(height: 0.33)
                                        .padding(.bottom, Space.md)
                                }
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Text(p.numeral)
                                        .font(Typo.teachNumeral)
                                        .foregroundStyle(Palette.accent)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(p.punch)
                                            .font(Typo.teachPunch)
                                            .foregroundStyle(Palette.textPrimary)
                                        Text(p.gloss)
                                            .font(Typo.teachBody)
                                            .lineSpacing(Typo.teachBodyLineSpacing)
                                            .foregroundStyle(Palette.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }

                        if let closing {
                            ItalicAccentText(
                                closing,
                                italic: closingItalic,
                                baseFont: Typo.teachClosing,
                                italicFont: Typo.teachClosingItalic,
                                alignment: .leading
                            )
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, Space.sm)
                        }

                        if let citation {
                            OV5CitationChip(text: citation)
                        }
                    }
                    .ov5Beat2()
                }
                .padding(.horizontal, Space.lg)
                .padding(.bottom, Space.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .ov5CTA(ctaLabel, action: onContinue)
    }
}

// MARK: - OV5ReceiptView (act-end receipts + data-mirror)
//
// The value-back interstitial: her answers mirrored back as hairline-
// ruled editorial rows. Tap-through anywhere, no timed dwell, no CTA
// pill — a receipt, not a form.

struct OV5ReceiptRowData: Identifiable {
    let lead: String        // quiet cause, DMSans
    let punch: String       // consequence, serif italic accent
    let punchItalic: [String]
    var id: String { lead + punch }
}

struct OV5ReceiptView: View {
    let title: String
    var titleItalic: [String] = []
    var sub: String? = nil
    var rows: [OV5ReceiptRowData] = []
    var footnote: String? = nil
    let onContinue: () -> Void

    var body: some View {
        Button(action: {
            Haptics.soft()
            onContinue()
        }) {
            VStack(spacing: 0) {
                Spacer()

                ItalicAccentText(
                    title,
                    italic: titleItalic,
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    alignment: .center
                )
                .lineSpacing(Typo.heroHeadlineLineGap)
                .kerning(-0.4)
                .padding(.horizontal, Space.lg)
                .ov5Beat1()

                if let sub {
                    Text(sub)
                        .font(Typo.teachSub)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, Space.md)
                        .padding(.horizontal, Space.lg)
                        .ov5Beat2()
                }

                if !rows.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                            VStack(spacing: 0) {
                                if idx > 0 {
                                    Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.33)
                                }
                                HStack(alignment: .firstTextBaseline) {
                                    Text(row.lead)
                                        .font(Typo.caption)
                                        .foregroundStyle(Palette.cocoaTertiary)
                                    Spacer(minLength: 16)
                                    ItalicAccentText(
                                        row.punch,
                                        italic: row.punchItalic,
                                        baseFont: .custom("DMSans-Medium", size: 15),
                                        italicFont: .custom("JeniHeroSerif-Italic", size: 17),
                                        alignment: .trailing
                                    )
                                }
                                .padding(.vertical, 14)
                            }
                            .ov5Beat2(extraDelay: 0.12 + Double(idx) * 0.1)
                        }
                    }
                    .padding(.horizontal, Space.lg + Space.sm)
                    .padding(.top, Space.xl)
                }

                if let footnote {
                    Text(footnote)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, Space.lg)
                        .padding(.horizontal, Space.lg)
                        .ov5Beat2(extraDelay: 0.4)
                }

                Spacer()

                Text("tap to continue")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary.opacity(0.7))
                    .padding(.bottom, Space.lg)
                    .ov5Beat2(extraDelay: 0.6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
