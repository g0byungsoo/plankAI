import SwiftUI

// MARK: - JeniMotion (v11 — the motion layer)
//
// L12: nothing appears; everything arrives. One orchestrated arrival
// per screen — a page owns ONE `arrived` flag, flips it once in
// `.task`, and children join the choreography by index. Charts draw,
// bars grow, numbers count, sheets settle. Haptics reinforce moments
// (tick / land / swell); they never decorate.
//
// Default SwiftUI transitions are banned on v11 surfaces
// (docs/app_v11/00_REBIRTH.md §4). This file is the replacement.

enum JeniMotion {
    /// The standard entry — a quiet rise. v13 (the reduction pass):
    /// shorter and more confident; effortless, never theatrical.
    static let arrive = Animation.spring(response: 0.42, dampingFraction: 0.88)
    /// Chart trace-in. v13: 0.90 → 0.72 — a chart should feel
    /// inevitable, not performed.
    static let draw = Animation.timingCurve(0.30, 0.8, 0.30, 1.0, duration: 0.72)
    /// Physical settles — sheets, scrub release, pressed states.
    static let settle = Animation.spring(response: 0.4, dampingFraction: 0.88)
    /// Selection morphs (the strip's disc, tile expansion) — snappier
    /// than settle, still soft-landing.
    static let morph = Animation.spring(response: 0.36, dampingFraction: 0.84)
    /// The press acknowledgment — quick in, soft out.
    static let press = Animation.spring(response: 0.3, dampingFraction: 0.7)
    /// v21 — the hero shape's physics: a trace that overshoots ~4%
    /// and settles. Reserved for the ring and the completion pulse;
    /// charts keep `draw` (curves draw, springs touch).
    static let elastic = Animation.spring(response: 0.8, dampingFraction: 0.68)
    /// Seconds between siblings in an arrival sequence. v13: 0.07 →
    /// 0.055 — the page assembles as one breath, not a parade.
    static let stagger: Double = 0.055
    /// Arrival rise, in points. Small on purpose — a breath, not a slide.
    static let rise: CGFloat = 6
}

// MARK: - The arrival flag (environment)
//
// `JeniPage` owns the flag and publishes it here; `.jeniArrive(index:)`
// reads it. Defaults to `true` so kit pieces rendered outside a
// JeniPage (sheets, previews, legacy hosts) never sit invisible.

private struct JeniArrivedKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var jeniArrived: Bool {
        get { self[JeniArrivedKey.self] }
        set { self[JeniArrivedKey.self] = newValue }
    }
}

// MARK: - .jeniArrive

private struct JeniArriveModifier: ViewModifier {
    @Environment(\.jeniArrived) private var envArrived
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Explicit override for screens that drive their own flag.
    var arrived: Bool?
    var index: Int

    private var isOn: Bool { arrived ?? envArrived }

    func body(content: Content) -> some View {
        content
            .opacity(isOn ? 1 : 0)
            .offset(y: isOn || reduceMotion ? 0 : JeniMotion.rise)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.2)
                    : JeniMotion.arrive.delay(Double(index) * JeniMotion.stagger),
                value: isOn
            )
    }
}

extension View {
    /// Join the page's arrival sequence at `index` (environment-driven).
    func jeniArrive(index: Int) -> some View {
        modifier(JeniArriveModifier(arrived: nil, index: index))
    }

    /// Explicit-flag variant for screens without a `JeniPage` shell.
    func jeniArrive(_ arrived: Bool, index: Int) -> some View {
        modifier(JeniArriveModifier(arrived: arrived, index: index))
    }
}

// MARK: - JeniCountingNumeral
//
// A numeral that counts to its value on arrival (L12: numbers count).
// Rides `.contentTransition(.numericText)` so digits roll rather than
// crossfade. The value it settles on is always the true value — the
// count is presentation, never data (L8).

struct JeniCountingNumeral: View {
    let value: Double
    var unit: String? = nil
    var font: Font = Typo.numeralHero
    var unitFont: Font = Typo.numeralMeta
    var color: Color = Palette.textPrimary
    /// Defaults to grouped whole numbers ("1,240") — numeral grammar
    /// matches meta copy everywhere. Pass a closure for decimals/units.
    var format: (Double) -> String = { value in
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? String(Int(value))
    }

    @Environment(\.jeniArrived) private var arrived
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0
    /// v12 — numbers count where the eye is: below-fold numerals wait
    /// for their first moment on screen (the visibility gate).
    @State private var seen = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(format(shown))
                .font(font)
                .contentTransition(.numericText(value: shown))
            if let unit {
                Text(unit)
                    .font(unitFont)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .foregroundStyle(color)
        .accessibilityLabel(Text("\(format(value))\(unit.map { " \($0)" } ?? "")"))
        .jeniArmOnVisible($seen)
        .onChange(of: arrived) { _, _ in count() }
        .onChange(of: seen) { _, _ in count() }
        .onAppear { count() }
        .onChange(of: value) {
            // A re-keyed value morphs to the new number (§4.5) — a
            // scope change re-counts, it never swaps.
            guard shown != 0 || value == 0 else { return count() }
            withAnimation(reduceMotion ? nil : JeniMotion.morph) {
                shown = value
            }
        }
    }

    private func count() {
        guard arrived, seen else { return }
        if reduceMotion {
            shown = value
            return
        }
        withAnimation(JeniMotion.arrive) { shown = value }
    }
}

// MARK: - JeniHaptic (the grammar)
//
// Three words, used sparingly. `tick` for detents and staggered
// landings; `land` for a completed action; `swell` for the ONE hero
// moment a flow is allowed.

enum JeniHaptic {
    static func tick() { Haptics.tick() }
    static func land() { Haptics.soft() }
    static func swell() { Haptics.medium() }
}
