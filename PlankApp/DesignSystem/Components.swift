import SwiftUI

// MARK: - CTAButtonStyle
//
// Three semantic variants that map to JeniFit's button hierarchy:
//   .primary   — cocoa pill, cream label. The "do the thing" button. Used for
//                Get Started, Continue, Subscribe, etc. Single per screen.
//   .secondary — accent (dusty rose) pill, cream label. Reserved for
//                celebratory or selection-confirming actions (e.g., paywall
//                "Continue" once a plan is picked).
//   .tertiary  — text-only, cocoa label. Inline / dismissive actions
//                (Skip, Cancel, "Already have an account").
//
// All variants share the same press feedback (scale 0.98 + opacity 0.85) so
// the touch language reads consistent across hierarchies.

struct CTAButtonStyle: ButtonStyle {
    enum Variant { case primary, secondary, tertiary }

    let variant: Variant
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(labelFont)
            .foregroundStyle(foreground)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, Space.lg)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(backgroundShape)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var labelFont: Font {
        switch variant {
        case .primary, .secondary: return Typo.heading
        case .tertiary: return Typo.body
        }
    }

    private var foreground: Color {
        switch variant {
        case .primary, .secondary: return Palette.textInverse
        case .tertiary: return Palette.textPrimary
        }
    }

    private var verticalPadding: CGFloat {
        switch variant {
        case .primary, .secondary: return Space.md
        case .tertiary: return Space.sm
        }
    }

    @ViewBuilder
    private var backgroundShape: some View {
        switch variant {
        case .primary:
            Capsule().fill(Palette.bgInverse)
        case .secondary:
            Capsule().fill(Palette.accent)
        case .tertiary:
            Color.clear
        }
    }
}

extension ButtonStyle where Self == CTAButtonStyle {
    static var ctaPrimary: CTAButtonStyle { .init(variant: .primary) }
    static var ctaSecondary: CTAButtonStyle { .init(variant: .secondary) }
    static var ctaTertiary: CTAButtonStyle { .init(variant: .tertiary, fullWidth: false) }
}

// MARK: - ItalicAccentText
//
// Renders a base string with selected substrings rendered in Fraunces italic
// for editorial emphasis (e.g., "Become *her* in 30 days"). Implementation
// concatenates Text fragments via the `+` operator — Text concatenation
// preserves per-fragment fonts and produces a single layout-aware Text node,
// which avoids the wrapping artifacts an HStack of Texts would introduce.
//
// Deliberately avoids AttributedString / NSAttributedString so the
// implementation surface is small and predictable. Headlines are short, so
// the linear scan to locate italic substrings is not a performance concern.
//
// Usage:
//   ItalicAccentText(
//       "Become her in 30 days.",
//       italic: ["her"],
//       baseFont: Typo.title,
//       italicFont: Typo.titleItalic
//   )

struct ItalicAccentText: View {
    let base: String
    let italic: [String]
    var baseFont: Font = Typo.title
    var italicFont: Font = Typo.titleItalic
    var color: Color = Palette.textPrimary
    var alignment: TextAlignment = .leading

    init(_ base: String,
         italic: [String],
         baseFont: Font = Typo.title,
         italicFont: Font = Typo.titleItalic,
         color: Color = Palette.textPrimary,
         alignment: TextAlignment = .leading) {
        self.base = base
        self.italic = italic
        self.baseFont = baseFont
        self.italicFont = italicFont
        self.color = color
        self.alignment = alignment
    }

    var body: some View {
        composed
            .foregroundStyle(color)
            .multilineTextAlignment(alignment)
    }

    private var composed: Text {
        var output = Text("")
        var cursor = base.startIndex
        let end = base.endIndex
        while cursor < end {
            // Find the earliest italic substring at or after cursor across
            // all candidates. First-match-wins so callers can pass overlapping
            // candidates without surprising precedence.
            var nearest: Range<String.Index>? = nil
            for needle in italic where !needle.isEmpty {
                if let r = base.range(of: needle, range: cursor..<end),
                   nearest == nil || r.lowerBound < nearest!.lowerBound {
                    nearest = r
                }
            }
            if let match = nearest {
                if match.lowerBound > cursor {
                    output = output + Text(String(base[cursor..<match.lowerBound])).font(baseFont)
                }
                output = output + Text(String(base[match])).font(italicFont)
                cursor = match.upperBound
            } else {
                output = output + Text(String(base[cursor..<end])).font(baseFont)
                cursor = end
            }
        }
        return output
    }
}

// MARK: - OnboardingOptionCard
//
// Tappable row used in onboarding multi-choice screens. Layout:
//   [icon circle] [title / optional subtitle] ......... [radio]
// Selected state swaps the border to accent + lights the radio dot. Card bg
// stays bgElevated in both states so the selected row reads as "highlighted"
// rather than "filled" — closer to JustFit / CalAI than to the chunkier iOS
// settings cell.

struct OnboardingOptionCard: View {
    var icon: String? = nil
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.md) {
                ZStack {
                    Circle()
                        .fill(Palette.accentSubtle)
                        .frame(width: 44, height: 44)
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(Palette.accent)
                    }
                }

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(title)
                        .font(.custom("DMSans-SemiBold", size: 16))
                        .foregroundStyle(Palette.textPrimary)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundStyle(Palette.textSecondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .truncationMode(.tail)
                    }
                }

                Spacer(minLength: Space.sm)

                ZStack {
                    Circle()
                        .stroke(isSelected ? Palette.accent : Palette.divider, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Palette.accent)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.md)
            .frame(minHeight: 72)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.bgElevated, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(isSelected ? Palette.accent : Palette.divider,
                            lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PricingCard
//
// Used on the paywall to present a single plan. The yearly card carries a
// floating "Save N%" badge and the selected plan gets a 2pt accent border.
// Weekly stays bordered with the divider color so the visual weight tilts
// toward the yearly choice even before selection.
//
// Pricing copy (price + perWeekEquivalent) is passed in as already-formatted
// strings — the caller (PaywallView) sources these from RevenueCat offerings,
// not hardcoded.

struct PricingCard: View {
    let title: String
    let price: String
    var perWeekEquivalent: String? = nil
    var savings: String? = nil
    var badge: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: Space.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Typo.heading)
                        .foregroundStyle(Palette.textPrimary)
                    if let perWeekEquivalent {
                        Text(perWeekEquivalent)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                Spacer(minLength: Space.sm)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(price)
                        .font(Typo.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.textPrimary)
                    if let savings {
                        Text(savings)
                            .font(Typo.eyebrow)
                            .tracking(1.5)
                            .foregroundStyle(Palette.accent)
                    }
                }
            }
            .padding(Space.md)
            .background(Palette.bgElevated, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(isSelected ? Palette.accent : Palette.divider,
                            lineWidth: isSelected ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(Typo.eyebrow)
                        .foregroundStyle(Palette.textInverse)
                        .padding(.horizontal, Space.sm)
                        .padding(.vertical, 4)
                        .background(Palette.accent, in: Capsule())
                        .offset(x: -Space.md, y: -10)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - DayBadge
//
// Small editorial pill used for day-count labels in the activity calendar,
// streak indicators, and "Day 7 of 30" copy on the paywall. AccentSubtle bg
// keeps it quiet enough to drop into a card without competing.

struct DayBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(Typo.eyebrow)
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, Space.sm)
            .padding(.vertical, 4)
            .background(Palette.accentSubtle, in: Capsule())
    }
}

// MARK: - JeniFitWordmark
//
// The brand mark: lowercase Fraunces SemiBold flanking a thin Light-weight
// bullet ("jeni • fit"). Used on AuthBootstrapSplash and the onboarding
// splash screen. Single canonical size so the brand reads identically
// everywhere; if a future surface needs scale variants, parametrize then.
//
// The bullet uses Fraunces72pt-Light at a smaller size with thin spaces
// (U+2009) padding either side — SemiBold's bullet glyph reads chunky next
// to the lowercase letterforms, so we step it down for breathing room.

struct JeniFitWordmark: View {
    var color: Color = Palette.textPrimary

    var body: some View {
        let base = Typo.title
        let separator = Font(UIFont(name: "Fraunces72pt-Light", size: 26)
                             ?? .systemFont(ofSize: 26))

        return (Text("jeni").font(base)
                + Text("\u{2009}•\u{2009}").font(separator)
                + Text("fit").font(base))
            .foregroundStyle(color)
    }
}

// MARK: - EditorialPlaceholder
//
// Holds the slot where coach photography will eventually live. Until the
// shoot happens, we render a diagonal-stripe block with a small label tag
// in the corner so the placeholder reads "intentionally unfinished" rather
// than "broken layout". Stripes use accent over accentSubtle for a quiet
// pink-on-pink hash; the label uses the eyebrow token in inverse on a 60%
// black scrim so it stays legible regardless of stripe contrast.

struct EditorialPlaceholder: View {
    let label: String
    var cornerRadius: CGFloat = Radius.lg

    var body: some View {
        ZStack(alignment: .topLeading) {
            Palette.accentSubtle

            Canvas { context, size in
                let spacing: CGFloat = 18
                let diag = sqrt(size.width * size.width + size.height * size.height)
                var x: CGFloat = -diag
                while x < size.width + diag {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: -diag))
                    path.addLine(to: CGPoint(x: x + diag, y: diag))
                    context.stroke(path,
                                   with: .color(Palette.accent.opacity(0.18)),
                                   lineWidth: 6)
                    x += spacing
                }
            }

            Text(label)
                .font(Typo.eyebrow)
                .foregroundStyle(Color.white)
                .padding(.horizontal, Space.sm)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.6), in: Capsule())
                .padding(Space.md)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - OnboardingProgressBar
//
// 4pt-tall capsule progress indicator that lives at the top of every
// onboarding screen. Fill is dusty rose on a soft divider track. Animates
// the width between screens with easeOut so forward motion always reads
// as forward (a spring would overshoot on small fraction deltas like
// 69% → 73% and look like a regression).

struct OnboardingProgressBar: View {
    let fraction: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.divider)
                    .frame(height: 4)
                Capsule().fill(Palette.accent)
                    .frame(width: max(8, geo.size.width * fraction), height: 4)
                    .animation(.easeOut(duration: 0.35), value: fraction)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - SectionDividerScreen
//
// Brief interstitial between the six onboarding parts. Auto-advances after
// `dwellSeconds` so the user gets a moment to register the section name
// without having to tap. Layout is intentionally sparse: small "Part N"
// eyebrow, then the section name in Fraunces title, then a short
// supporting line.
//
// Used as a screen body inside OnboardingView; the parent owns the
// dispatch to the next screen.

struct SectionDividerScreen: View {
    let partNumber: Int
    let title: String
    let supporting: String
    let dwellSeconds: Double
    let onAdvance: () -> Void

    @State private var visible = false

    var body: some View {
        VStack(spacing: Space.md) {
            Spacer()

            Text("PART \(partNumber)")
                .font(Typo.eyebrow)
                .tracking(2)
                .foregroundStyle(Palette.accent)
                .opacity(visible ? 1 : 0)
                .offset(y: visible ? 0 : 12)

            Text(title)
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.lg)
                .opacity(visible ? 1 : 0)
                .offset(y: visible ? 0 : 16)

            Text(supporting)
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.xl)
                .opacity(visible ? 1 : 0)
                .offset(y: visible ? 0 : 16)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { visible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + dwellSeconds) {
                onAdvance()
            }
        }
    }
}

// MARK: - ConfirmationBadge
//
// Centered toast shown for ~1.2s after major onboarding commits. Used
// sparingly (5–7 times across the full flow, not after every question)
// so each appearance reads as a moment of acknowledgement rather than
// noise. Cocoa pill, cream label, dusty rose checkmark dot.

struct ConfirmationBadge: View {
    let message: String

    var body: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.textInverse)
                .frame(width: 22, height: 22)
                .background(Palette.accent, in: Circle())

            Text(message)
                .font(Typo.body)
                .fontWeight(.semibold)
                .foregroundStyle(Palette.textInverse)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.md)
        .background(Palette.bgInverse, in: RoundedRectangle(cornerRadius: Radius.md))
        .padding(.horizontal, Space.lg)
    }
}

// MARK: - BiometricSlider
//
// Vertical ruler scroll picker for height / weight / target weight.
// Replaced the horizontal Slider in 2026-05-04 — horizontal sliders had a
// passive-default problem (users hit Continue without engaging, leaving
// the value at its initial position). The ruler reads as a tape measure /
// scale, encourages active scrolling, and fires a soft haptic on each
// tick passed so the input feels mechanical and intentional.
//
// Drag-to-scroll, no momentum (kept simple for v1.0 — flick fling can
// land later). Big Fraunces value above the ruler, unit caption below
// the value, centered horizontal indicator across the ruler showing the
// selected tick.

struct BiometricSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String
    var unitLabel: String? = nil

    @State private var dragStartValue: Double?
    @State private var lastTickValue: Double?

    private let tickHeight: CGFloat = 10
    private let rulerHeight: CGFloat = 240
    private let majorTickWidth: CGFloat = 36
    private let minorTickWidth: CGFloat = 18
    private let majorTickEvery: Int = 5

    private var totalSteps: Int {
        Int(((range.upperBound - range.lowerBound) / step).rounded()) + 1
    }

    private var stepIndex: Double {
        (value - range.lowerBound) / step
    }

    /// Vertical offset that places tick `stepIndex` at the ruler's
    /// vertical center (y = rulerHeight / 2 in ZStack-local space). Each
    /// tick row sits at VStack-y `(i + 0.5) * tickHeight`; we shift the
    /// whole VStack so the selected tick aligns with the center
    /// indicator. Without the rulerHeight/2 anchor, step 0 ended up at
    /// the top of the viewport and high steps got clipped past the
    /// center indicator's frame — the cause of the "ruler breaks past
    /// 5'9"" walkthrough report.
    private var contentOffset: CGFloat {
        rulerHeight / 2 - (CGFloat(stepIndex) + 0.5) * tickHeight
    }

    var body: some View {
        VStack(spacing: Space.sm) {
            Text(format(value))
                .font(Typo.display)
                .foregroundStyle(Palette.textPrimary)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.12), value: value)

            if let unitLabel {
                Text(unitLabel)
                    .font(Typo.caption)
                    .tracking(1.5)
                    .foregroundStyle(Palette.textSecondary)
            }

            Spacer().frame(height: Space.md)

            // ZStack(alignment: .top) is intentional. With the default
            // .center alignment, SwiftUI auto-centers the VStack
            // (natural height ~770pt for the 77-tick height ruler)
            // vertically inside the 240pt ZStack frame — every tick
            // ends up ~rulerHeight/2 above where the contentOffset
            // formula expects it. That's the cause of the
            // "ruler-stops-rendering-past-6'2"" walkthrough report:
            // ticks rendered correctly within the data range, but the
            // visible viewport was offset so high stepIndex values
            // landed beyond the clipped frame's bottom edge.
            //
            // With alignment: .top the VStack's top pins to ZStack-y=0
            // and the contentOffset formula
            //   rulerHeight/2 - (stepIndex + 0.5) * tickHeight
            // places tick `stepIndex` exactly at the center indicator
            // for any value across the full range.
            ZStack(alignment: .top) {
                // Tick column. Each tick is a horizontal accent bar
                // centered horizontally in the ruler; every 5th tick
                // reads bolder so the eye picks up scale at a glance.
                VStack(spacing: 0) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        let major = (i % majorTickEvery == 0)
                        Rectangle()
                            .fill(Palette.accent.opacity(major ? 0.7 : 0.28))
                            .frame(width: major ? majorTickWidth : minorTickWidth,
                                   height: major ? 2 : 1.5)
                            .frame(maxWidth: .infinity)
                            .frame(height: tickHeight)
                    }
                }
                .offset(y: contentOffset)

                // Center selection indicator — a thicker cocoa bar
                // marking the currently selected tick. Wrapping in
                // frame(maxHeight: .infinity) makes it fill the ZStack
                // vertically; default frame alignment (.center) then
                // places the indicator at the ruler's vertical center.
                RoundedRectangle(cornerRadius: 2)
                    .fill(Palette.bgInverse)
                    .frame(width: majorTickWidth + 16, height: 3)
                    .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity)
            .frame(height: rulerHeight)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if dragStartValue == nil {
                            dragStartValue = value
                            lastTickValue = value
                        }
                        guard let start = dragStartValue else { return }
                        let stepsDelta = -gesture.translation.height / tickHeight
                        let startIndex = (start - range.lowerBound) / step
                        let newIndex = (startIndex + stepsDelta).rounded()
                        let clampedIndex = max(0, min(Double(totalSteps - 1), newIndex))
                        let newValue = range.lowerBound + clampedIndex * step
                        if newValue != value {
                            value = newValue
                            if let last = lastTickValue, last != newValue {
                                Haptics.soft()
                            }
                            lastTickValue = newValue
                        }
                    }
                    .onEnded { _ in
                        dragStartValue = nil
                        lastTickValue = nil
                    }
            )
        }
        .padding(.vertical, Space.md)
    }
}

// MARK: - NumericWheelPicker
//
// Native Picker.wheel-based replacement for the custom vertical ruler.
// Three rounds of geometry fixes on BiometricSlider couldn't fully
// resolve scrollable-range clipping at the boundaries — every patch
// shifted the bug instead of removing it. iOS's UIPickerView (under
// .pickerStyle(.wheel)) handles arbitrary ranges, snap-to-tick,
// haptics, accessibility, and overflow without any custom math.
//
// Storage stays in metric (cm / kg). The unit toggle flips display
// only — pickers iterate over metric values via stride(); the format
// closure converts at render time. Toggling preserves the underlying
// value so a 65 kg selection stays 65 kg whether shown as "65.0 kg"
// or "143 lb."

struct NumericWheelPicker<Annotation: View>: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    /// (value, isImperial) → display string. Caller owns the
    /// conversion math so the same closure handles both unit modes.
    let format: (Double, Bool) -> String
    let metricUnit: String
    let imperialUnit: String
    /// Optional content rendered below the picker (BMI on case 132,
    /// goal-loss tier text on case 133). EmptyView default for screens
    /// that don't need it.
    @ViewBuilder var annotation: () -> Annotation

    @State private var imperial: Bool = true   // default to lb / ft for US-first

    private var pickerValues: [Double] {
        Array(stride(from: range.lowerBound, through: range.upperBound, by: step))
    }

    var body: some View {
        VStack(spacing: Space.sm) {
            // Unit toggle pill — two-segment capsule, accent fill on
            // the active side, divider stroke around the whole thing.
            HStack(spacing: 0) {
                unitButton(label: imperialUnit, isImperial: true)
                unitButton(label: metricUnit, isImperial: false)
            }
            .padding(2)
            .background(Palette.bgElevated, in: Capsule())
            .overlay(Capsule().stroke(Palette.divider, lineWidth: 1))

            // Big Fraunces value display above the picker. Reads as
            // the headline number; the wheel below is the input.
            Text(format(value, imperial))
                .font(Typo.display)
                .foregroundStyle(Palette.textPrimary)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.12), value: value)

            // Native wheel picker. .pickerStyle(.wheel) gives us
            // momentum scroll, snap-to-tick, haptic feedback, and
            // accessibility for free.
            Picker("", selection: $value) {
                ForEach(pickerValues, id: \.self) { v in
                    Text(format(v, imperial))
                        .font(.system(size: 20, weight: .medium))
                        .tag(v)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 200)
            .clipped()
            // Re-rendering the picker when the unit toggle flips
            // forces UIPickerView to rebuild its row labels with the
            // new format. Without the .id, iOS caches the old label
            // strings and the wheel reads stale until next scroll.
            .id(imperial ? "imperial" : "metric")

            annotation()
        }
        .padding(.vertical, Space.md)
    }

    private func unitButton(label: String, isImperial: Bool) -> some View {
        Button {
            Haptics.light()
            withAnimation(.easeOut(duration: 0.18)) { imperial = isImperial }
        } label: {
            Text(label)
                .font(Typo.eyebrow)
                .tracking(1.5)
                .foregroundStyle(imperial == isImperial ? Palette.textInverse : Palette.textSecondary)
                .padding(.horizontal, Space.md)
                .padding(.vertical, 6)
                .background(
                    imperial == isImperial ? Palette.bgInverse : Color.clear,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - BodyTypeSlider
//
// 6-position discrete slider (0–5) for "where are you now" /
// "where do you want to be" body-shape questions. Renders the
// current and target as illustrative labels above the slider.

struct BodyTypeSlider: View {
    @Binding var position: Int
    let labels: [String]   // length must be 6
    /// Optional upper bound on the slider (inclusive). Renders dots
    /// above this index in a disabled state so the user sees the full
    /// range with a clear "out of reach" affordance, rather than a
    /// shortened track that reads as a render bug.
    var maxPosition: Int? = nil
    /// Optional read-only marker showing a reference position on the
    /// track (e.g., "where you said you currently are" on the goal
    /// body type screen). Renders as a small accent dot below the row
    /// with a "you" caption.
    var markerPosition: Int? = nil

    private let dotSize: CGFloat = 14
    private let selectedDotSize: CGFloat = 22
    private let trackHeight: CGFloat = 2
    private let rowHeight: CGFloat = 60   // dot row + space for "you" marker

    private var effectiveMax: Int {
        let cap = maxPosition ?? (labels.count - 1)
        return max(0, min(labels.count - 1, cap))
    }

    private var clampedPosition: Int {
        max(0, min(effectiveMax, position))
    }

    var body: some View {
        VStack(spacing: Space.lg) {
            Text(labels[clampedPosition])
                .font(Typo.heading)
                .foregroundStyle(Palette.textPrimary)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.15), value: position)

            GeometryReader { geo in
                let count = labels.count
                let denom = max(1, count - 1)
                let dotX: (Int) -> CGFloat = { i in
                    geo.size.width * CGFloat(i) / CGFloat(denom)
                }

                ZStack {
                    // Background track — full width, divider gray.
                    Rectangle()
                        .fill(Palette.divider)
                        .frame(height: trackHeight)
                        .position(x: geo.size.width / 2, y: rowHeight / 2)

                    // Filled portion of the track up to effectiveMax —
                    // visualizes the reachable range in soft accent.
                    Rectangle()
                        .fill(Palette.accent.opacity(0.45))
                        .frame(width: dotX(effectiveMax), height: trackHeight)
                        .position(x: dotX(effectiveMax) / 2, y: rowHeight / 2)

                    // Position dots. Filled accent for valid, hollow
                    // divider for disabled, outlined cocoa for selected.
                    ForEach(0..<count, id: \.self) { i in
                        let valid = i <= effectiveMax
                        let selected = i == clampedPosition && valid
                        ZStack {
                            if selected {
                                Circle()
                                    .fill(Palette.bgInverse)
                                    .frame(width: selectedDotSize, height: selectedDotSize)
                                Circle()
                                    .stroke(Palette.accent, lineWidth: 2)
                                    .frame(width: selectedDotSize, height: selectedDotSize)
                            } else if valid {
                                Circle()
                                    .fill(Palette.accent)
                                    .frame(width: dotSize, height: dotSize)
                            } else {
                                Circle()
                                    .stroke(Palette.divider, lineWidth: 1.5)
                                    .frame(width: dotSize, height: dotSize)
                            }
                        }
                        .position(x: dotX(i), y: rowHeight / 2)
                        .onTapGesture {
                            if valid {
                                Haptics.light()
                                position = i
                            } else {
                                Haptics.warning()
                            }
                        }
                    }

                    // "you" marker at markerPosition. Reads as the
                    // user's current body type when this slider is
                    // editing the goal — context for the gradient
                    // they're moving along.
                    if let marker = markerPosition {
                        let markerIdx = max(0, min(count - 1, marker))
                        VStack(spacing: 2) {
                            Circle()
                                .fill(Palette.accent)
                                .frame(width: 6, height: 6)
                            Text("you")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(0.5)
                                .foregroundStyle(Palette.accent)
                        }
                        .position(x: dotX(markerIdx), y: rowHeight / 2 + 22)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            // Snap to nearest valid dot (cap at
                            // effectiveMax so the thumb can't drag
                            // past the disabled positions).
                            let x = max(0, min(geo.size.width, gesture.location.x))
                            let raw = (x / geo.size.width) * CGFloat(denom)
                            let nearest = min(effectiveMax, max(0, Int(raw.rounded())))
                            if nearest != position {
                                Haptics.soft()
                                position = nearest
                            }
                        }
                )
            }
            .frame(height: rowHeight)
            .padding(.horizontal, Space.md)

            HStack {
                Text(labels.first ?? "")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                // Right-edge label always shows the actual upper bound
                // ("Cut") even when disabled — makes the gradient direction
                // unambiguous (lean ←→ heavier).
                Text(labels.last ?? "")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, Space.md)
        }
        .padding(.vertical, Space.lg)
    }
}

// MARK: - Previews
//
// Visual scratchpad for the design system primitives. Run in the Xcode
// canvas (Editor → Canvas) to inspect each component in isolation against
// the JeniFit palette. These previews are #if DEBUG-gated implicitly by
// the #Preview macro — they don't ship in release builds.

#Preview("CTA buttons") {
    VStack(spacing: Space.md) {
        Button("Get started") {}.buttonStyle(.ctaPrimary)
        Button("Subscribe") {}.buttonStyle(.ctaSecondary)
        Button("Skip for now") {}.buttonStyle(.ctaTertiary)
    }
    .padding(Space.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bgPrimary)
}

#Preview("OnboardingOptionCard") {
    VStack(spacing: Space.md) {
        OnboardingOptionCard(
            icon: "figure.core.training",
            title: "Definition",
            subtitle: "Visible abs, sculpted lines",
            isSelected: true,
            action: {}
        )
        OnboardingOptionCard(
            icon: "flame.fill",
            title: "Strength",
            subtitle: "Build a stronger core",
            isSelected: false,
            action: {}
        )
        OnboardingOptionCard(
            icon: "heart.fill",
            title: "Just feel better",
            isSelected: false,
            action: {}
        )
    }
    .padding(Space.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bgPrimary)
}

#Preview("PricingCard") {
    VStack(spacing: Space.md) {
        PricingCard(
            title: "Yearly",
            price: "$59.99",
            perWeekEquivalent: "$1.15 / week",
            badge: "SAVE 76%",
            isSelected: true,
            action: {}
        )
        PricingCard(
            title: "Weekly",
            price: "$4.99",
            perWeekEquivalent: nil,
            badge: nil,
            isSelected: false,
            action: {}
        )
    }
    .padding(Space.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bgPrimary)
}

#Preview("DayBadge") {
    HStack(spacing: Space.sm) {
        DayBadge(label: "DAY 1")
        DayBadge(label: "DAY 7")
        DayBadge(label: "DAY 30")
    }
    .padding(Space.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bgPrimary)
}

#Preview("ItalicAccentText") {
    VStack(spacing: Space.lg) {
        ItalicAccentText("Become her in 30 days.", italic: ["her"])
        ItalicAccentText(
            "Sculpt your strongest body, at home.",
            italic: ["strongest"]
        )
    }
    .padding(Space.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bgPrimary)
}

#Preview("JeniFitWordmark") {
    VStack(spacing: Space.lg) {
        JeniFitWordmark()
        JeniFitWordmark(color: Palette.accent)
    }
    .padding(Space.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bgPrimary)
}

#Preview("EditorialPlaceholder") {
    EditorialPlaceholder(label: "EDITORIAL · COACH PHOTO")
        .frame(width: 280, height: 380)
        .padding(Space.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bgPrimary)
}

// dwellSeconds set to 9999 so the preview doesn't auto-advance —
// this is a render-only static preview, not a working onboarding step.
#Preview("SectionDividerScreen") {
    SectionDividerScreen(
        partNumber: 1,
        title: "Your story",
        supporting: "Three quick reads on what brought you here.",
        dwellSeconds: 9999,
        onAdvance: {}
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bgPrimary)
}

#Preview("ConfirmationBadge") {
    VStack {
        Spacer()
        ConfirmationBadge(message: "Got it. Your plan starts here.")
            .padding(.bottom, Space.xl)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bgPrimary)
}
