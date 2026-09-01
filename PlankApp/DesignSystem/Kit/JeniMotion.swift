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
    /// p62 — the beat between a commit and its dismissal: long enough
    /// for the haptic and the state change to land, short enough that
    /// the surface feels like it got out of her way. Four hand-picked
    /// values (0.35 / 0.4 / 0.45 / 0.45) used to make the same
    /// gesture at four speeds across the dose sheet, the letter's
    /// seal, the weekly read's decline and the program commit.
    static let commitDwell: TimeInterval = 0.45
    /// The dwell on a written RECEIPT (the weight ritual's kept
    /// line) — a sentence she reads, not just a haptic she feels.
    /// Deliberately longer than `commitDwell`; a receipt that flashes
    /// for half a second is worse than no receipt.
    static let receiptDwell: TimeInterval = 1.5
}

// MARK: - JeniActs (p63 — the speech arrival)
//
// Two arrival grammars, deliberately distinct:
//
//   ASSEMBLY (`jeniArrive`, 0.055s stagger) — a page builds as one
//   breath. Ordinary navigation; never slower than this.
//
//   SPEECH (`jeniAct`, 0.55s beat) — a surface where JENI is saying
//   something: a moment cover, a read's tail, a clinical statement.
//   One idea arrives, then the next, then the action — the reader
//   absorbs each before the next lands (the consult's principle,
//   extracted; the typewriter stays the consult's own register).
//
// Laws carried by the primitive:
//   · a tap anywhere completes the remaining acts at once — §5.7,
//     impatience is a valid input; repeat visitors wait for nothing
//   · an act that has not arrived cannot be hit — an invisible door
//     is not a door (the letter shipped opacity-0 buttons that were
//     tappable; this class dies here)
//   · Reduce Motion presents everything immediately — the reader
//     sets the pace, not the choreography
//   · the schedule rides the surface's own `.task`, so leaving the
//     surface cancels the walk — no timers outlive the view
//
// Use sparingly: a surface earns acts only when Jeni initiated it.

enum JeniActs {
    /// Seconds between acts. Slower than assembly's 0.055 on purpose,
    /// in the letter cascade's cadence family (0.42s/line): a BLOCK
    /// of meaning needs a touch more air than a line.
    static let beat: TimeInterval = 0.55

    /// Advance `current` one act per beat until `last`. Call from the
    /// surface's `.task`; cancellation (the view leaving) ends the
    /// walk wherever it stands. Reduce Motion arrives whole.
    static func run(
        _ current: Binding<Int>, to last: Int, reduceMotion: Bool
    ) async {
        guard current.wrappedValue < last else { return }
        if reduceMotion {
            current.wrappedValue = last
            return
        }
        while current.wrappedValue < last {
            try? await Task.sleep(nanoseconds: UInt64(beat * 1_000_000_000))
            guard !Task.isCancelled else { return }
            guard current.wrappedValue < last else { return }
            withAnimation(JeniMotion.arrive) { current.wrappedValue += 1 }
        }
    }

    /// Complete every remaining act now (the tap-to-skip half).
    static func complete(_ current: Binding<Int>, to last: Int) {
        guard current.wrappedValue < last else { return }
        withAnimation(JeniMotion.arrive) { current.wrappedValue = last }
    }
}

private struct JeniActModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var act: Int
    var current: Int

    func body(content: Content) -> some View {
        let on = current >= act
        content
            .opacity(on ? 1 : 0)
            .offset(y: on || reduceMotion ? 0 : JeniMotion.rise)
            .allowsHitTesting(on)
            .accessibilityHidden(!on)
    }
}

extension View {
    /// Join a speech arrival at `act` (0 = with the surface itself).
    /// The advance is animated by `JeniActs.run`/`complete`, so the
    /// modifier carries no animation of its own.
    func jeniAct(_ act: Int, current: Int) -> some View {
        modifier(JeniActModifier(act: act, current: current))
    }
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
// Four words, used sparingly. `tick` for detents and staggered
// landings; `land` for a completed action; `record` for a FACT
// entering the record; `swell` for the ONE hero moment a flow is
// allowed.
//
// p58 — `record` closes an audited drift: the three record-writing
// commits spoke three signatures (dose mark = soft, weight save =
// success, plate file = success), and the most consequential daily
// commit — the dose — had the weakest hand. One word now: a record
// landing always feels the same, and it is the strongest confirm the
// product makes. (PlankFood's plate-file already speaks notification
// .success inline — the package cannot see this type; its signature
// is the same by construction and pinned by this comment.)

enum JeniHaptic {
    static func tick() { Haptics.tick() }
    static func land() { Haptics.soft() }
    static func record() { Haptics.success() }
    static func swell() { Haptics.medium() }
    /// p63 — the CREST: the day's one genuine peak. A composed
    /// CoreHaptics phrase (touch · landing · a warm bloom) reserved
    /// for a crossing that happens at most once a day by construction
    /// — today that is the protein floor. Everything else that enters
    /// the record keeps `record`; a crest that fired twice a day
    /// would just be a loud `record`. Falls back to the stock success
    /// on hardware without CoreHaptics.
    static func crest() { ActivationHaptics.shared.crest() }
}
