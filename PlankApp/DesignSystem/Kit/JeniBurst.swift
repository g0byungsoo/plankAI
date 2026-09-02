import SwiftUI

// MARK: - JeniBurst (p64 — THE DELIGHT LAYER)
//
// The house particle burst: a short, physical celebration that
// ORIGINATES from the thing being celebrated — never a screen-edge
// confetti rain. Founder decision (p64): Jeni carries a real visual
// celebration layer; this is its one particle engine.
//
// Design laws carried here:
//   · the burst rides an eligible moment the CALLER decided
//     (CelebrationLedger owns once-per-day; this view owns pixels)
//   · it never blocks input (`allowsHitTesting(false)`), never loops,
//     and costs nothing at rest — the Canvas leaves the tree when the
//     last particle dies
//   · palette is the rose ramp + ink, 3 hues, never rainbow
//   · Reduce Motion renders NOTHING here — the state change, words
//     and haptic carry the meaning (§10.3: remove motion, never
//     information)
//   · deterministic per play (seeded LCG), so films are comparable
//     and tests reproducible
//
// Three tiers, proportional by construction:
//   · .spark  — a completed useful behavior (water done, first plate
//               of the day): ~18 flecks, one wave, ~0.9s
//   · .crest  — the day's one peak (the protein floor crossing):
//               ~32 flecks, wider cone, ~1.1s
//   · .moment — once-per-lifetime beats (the record's first plate):
//               two waves, ~46 flecks, ~1.4s
//
// Visual register: torn-paper flecks in the stationery voice (small
// rounded rectangles that tumble), with a few ink accents so the
// burst reads as Jeni's paper, not party confetti. Chosen on film
// against two live alternatives (§26): thin light-rays read as cold
// debris, soft petal-dots read as drifting bubbles — the paper
// fleck was the one that read as JOY in Jeni's own material
// (films in docs/app_v25/64_evidence/).

struct JeniBurst: View {
    /// p66 — the engine gains a second register. `.pop` is p64's
    /// origin-anchored burst (unchanged). `.shower` is THE CELEBRATION:
    /// a full-screen volley of the same torn paper, launched from the
    /// bottom corners like cannons, rising past the words and
    /// fluttering down under a terminal velocity — the recognizable
    /// confetti moment, rendered in Jeni's own material. Chosen on
    /// film against six bundled Lottie candidates (p66 bake-off): the
    /// Lottie comps were candy-magenta, 0.6-2s, and their action
    /// filled a fraction of the frame — none read as a celebration on
    /// this paper. Native won on color truth, scale, determinism and
    /// honest Reduce Motion.
    enum Mode {
        case pop
        case shower
    }

    enum Tier {
        case spark
        case crest
        case moment

        var count: Int {
            switch self {
            case .spark: return 18
            case .crest: return 32
            case .moment: return 46
            }
        }

        /// Particle count in `.shower` mode — the full-screen volley.
        var showerCount: Int {
            switch self {
            case .spark: return 0
            case .crest: return 78
            case .moment: return 130
            }
        }

        var life: Double {
            switch self {
            case .spark: return 0.9
            case .crest: return 1.1
            case .moment: return 1.4
            }
        }

        /// Launch speed range, points/second.
        var speed: ClosedRange<Double> {
            switch self {
            case .spark: return 170...300
            case .crest: return 200...360
            case .moment: return 210...400
            }
        }

        /// Half-angle of the upward launch cone, radians.
        var cone: Double {
            switch self {
            case .spark: return 0.85
            case .crest: return 1.05
            case .moment: return 1.25
            }
        }
    }

    let tier: Tier
    var mode: Mode = .pop
    /// Increment to play. 0 = never played; the first change (or a
    /// mount with `playsOnAppear`) fires the burst. Idempotence lives
    /// in the caller's ledger — this view plays exactly once per
    /// token change.
    var play: Int
    /// Play once when the view first appears (the answer-surface
    /// case, where the burst mounts at the moment it should fire).
    var playsOnAppear: Bool = false
    /// p67 — true when the burst plays over an INK scene: the accent
    /// flecks swap from ink to paper so every fleck stays visible.
    /// The rose ramp carries on both surfaces; determinism is
    /// untouched (the LCG walk is identical either way).
    var onInk: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var elapsed: Double = 0
    @State private var running = false
    @State private var seed: UInt64 = 1

    var body: some View {
        ZStack {
            if running, !reduceMotion {
                Canvas { context, size in
                    for p in Self.particles(tier: tier, mode: mode, seed: seed, onInk: onInk) {
                        guard elapsed >= p.birth else { continue }
                        let t = elapsed - p.birth
                        guard t < p.life else { continue }
                        let fade = Self.opacity(t: t, life: p.life)
                        let origin = CGPoint(
                            x: p.originX * size.width,
                            y: p.originY * size.height
                        )
                        var x: Double
                        var y: Double
                        switch mode {
                        case .pop:
                            // Constant-velocity launch decayed by drag,
                            // pulled down by gravity — integrated in
                            // closed form so the draw is pure in `t`.
                            let decay = (1 - exp(-Self.drag * t)) / Self.drag
                            x = origin.x + p.vx * decay
                            y = origin.y + p.vy * decay
                                + Self.gravity * t * t / 2
                        case .shower:
                            // Linear drag on the WHOLE velocity, so a
                            // fleck rises like a shot and falls at a
                            // paper terminal velocity — plus a slow
                            // sideways flutter. Still pure in `t`.
                            let d = Self.showerDrag
                            let vT = Self.gravity / d
                            let decay = (1 - exp(-d * t)) / d
                            x = origin.x + p.vx * decay
                                + sin(t * p.swayFreq + p.tilt) * p.sway
                            y = origin.y + vT * t + (p.vy - vT) * decay
                        }
                        var ctx = context
                        ctx.opacity = fade
                        ctx.translateBy(x: x, y: y)
                        ctx.rotate(by: Angle(radians: p.spin * t + p.tilt))
                        // Paper flutter: the fleck's width breathes as
                        // it tumbles, reading as a 3D turn without any
                        // 3D cost.
                        let flutter = mode == .shower
                            ? 0.45 + 0.55 * abs(sin(t * p.swayFreq * 1.7 + p.tilt))
                            : 1.0
                        let rect = CGRect(
                            x: -p.size * flutter / 2, y: -p.size * 0.35,
                            width: p.size * flutter, height: p.size * 0.7
                        )
                        ctx.fill(
                            Path(roundedRect: rect, cornerRadius: p.size * 0.24),
                            with: .color(p.color)
                        )
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .transition(.opacity)
            }
        }
        .onChange(of: play) { _, newValue in
            guard newValue > 0 else { return }
            fire(token: newValue)
        }
        .onAppear {
            guard playsOnAppear else { return }
            fire(token: max(1, play))
        }
    }

    private func fire(token: Int) {
        guard !reduceMotion else { return }
        seed = UInt64(truncatingIfNeeded: token &* 0x9E37_79B9)
        elapsed = 0
        running = true
        Task { @MainActor in
            let start = Date()
            let life = mode == .shower ? Self.showerLife : tier.life
            let total = life + Self.lastBirth(tier: tier, mode: mode)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_000_000)
                elapsed = Date().timeIntervalSince(start)
                if elapsed >= total { break }
            }
            running = false
        }
    }

    // MARK: Physics constants

    /// Gravity in points/s² — light, so paper flecks float rather
    /// than plummet.
    private static let gravity: Double = 560
    /// Air drag, 1/s — sets the bloom radius (terminal spread ≈
    /// speed/drag). Filmed at 3.1 first: the burst died on the
    /// control before it ever opened.
    private static let drag: Double = 1.55

    /// Shower drag, 1/s — lower, so the cannon volley actually
    /// reaches the top of the page before terminal velocity
    /// (gravity/drag ≈ 470 pt/s) takes it down as a flutter-fall.
    private static let showerDrag: Double = 1.2
    /// Shower particle lifetime ceiling, seconds. Long enough for a
    /// fleck launched from the bottom to rise past the headline and
    /// leave the screen falling; the page never waits on it (the
    /// canvas is decorative and non-blocking).
    private static let showerLife: Double = 2.6

    private static func opacity(t: Double, life: Double) -> Double {
        let tail = life * 0.35
        guard t > life - tail else { return 1 }
        return max(0, (life - t) / tail)
    }

    // MARK: Deterministic particle field

    struct Particle {
        var vx: Double
        var vy: Double
        var birth: Double
        var life: Double
        var size: Double
        var spin: Double
        var tilt: Double
        var color: Color
        /// Launch origin as a fraction of the canvas (0.5, 0.5 =
        /// center — the pop's anchor; showers launch from the bottom
        /// corners).
        var originX: Double = 0.5
        var originY: Double = 0.5
        /// Sideways flutter amplitude (pt) and frequency (rad/s) —
        /// shower only; zero for the pop.
        var sway: Double = 0
        var swayFreq: Double = 0
    }

    /// The burst's palette: the rose ramp carries it, ink accents
    /// ground it in the product's own hand. Never more than these.
    private static let palette: [Color] = [
        Palette.roseBerry,
        Palette.accent,
        Palette.roseBlush,
        Palette.textPrimary.opacity(0.85),
    ]

    private static func lastBirth(tier: Tier, mode: Mode = .pop) -> Double {
        if mode == .shower { return 0.5 }
        return tier == .moment ? 0.16 : 0.05
    }

    static func particles(tier: Tier, mode: Mode = .pop, seed: UInt64, onInk: Bool = false) -> [Particle] {
        guard mode == .pop else { return showerParticles(tier: tier, seed: seed, onInk: onInk) }
        var rng = LCG(seed: seed)
        var out: [Particle] = []
        out.reserveCapacity(tier.count)
        for i in 0..<tier.count {
            // Upward cone around -90°, wider per tier.
            let angle = -Double.pi / 2
                + rng.range(-tier.cone...tier.cone)
            let speed = rng.range(tier.speed)
            // The moment tier launches a second wave a beat later.
            let secondWave = tier == .moment && i % 3 == 2
            let birth = secondWave
                ? rng.range(0.12...0.16)
                : rng.range(0...0.05)
            // Ink is the ACCENT: roughly one fleck in six (paper
            // when the burst plays over an ink scene).
            let color = rng.range(0...1) < 0.17
                ? (onInk ? Palette.textInverse.opacity(0.92) : palette[3])
                : palette[Int(rng.next() % 3)]
            out.append(Particle(
                vx: cos(angle) * speed,
                // Launch carries extra lift so the burst OPENS before
                // gravity takes it — the pop, then the fall.
                vy: sin(angle) * speed * 1.3,
                birth: birth,
                life: rng.range((tier.life * 0.62)...tier.life),
                size: rng.range(5.0...8.5),
                spin: rng.range(-5.2...5.2),
                tilt: rng.range(0...(2 * .pi)),
                color: color
            ))
        }
        return out
    }

    /// THE CELEBRATION volley (p66). Two cannons in the bottom
    /// corners aimed inward, a softer center lift, three pulses —
    /// flecks rise past the headline, hang, then flutter down at
    /// terminal velocity. Same paper, same palette, full page.
    private static func showerParticles(tier: Tier, seed: UInt64, onInk: Bool = false) -> [Particle] {
        var rng = LCG(seed: seed)
        var out: [Particle] = []
        let count = tier.showerCount
        out.reserveCapacity(count)
        for i in 0..<count {
            // Cannon assignment round-robins so every pulse carries
            // all three origins.
            let cannon = i % 3
            let (ox, baseAngle, speedRange): (Double, Double, ClosedRange<Double>) =
                switch cannon {
                case 0: (0.04, -Double.pi * 0.36, 1350...1950)   // bottom-left, aimed up-right
                case 1: (0.96, -Double.pi * 0.64, 1350...1950)   // bottom-right, aimed up-left
                default: (0.50, -Double.pi * 0.50, 1050...1600)  // center, straight lift
                }
            let angle = baseAngle + rng.range(-0.16...0.16)
            let speed = rng.range(speedRange)
            // Three pulses read as a real volley, not a single sneeze.
            let pulse = Double((i / 3) % 3)
            let birth = pulse * 0.18 + rng.range(0...0.08)
            let color = rng.range(0...1) < 0.13
                ? (onInk ? Palette.textInverse.opacity(0.92) : palette[3])
                : palette[Int(rng.next() % 3)]
            out.append(Particle(
                vx: cos(angle) * speed,
                vy: sin(angle) * speed,
                birth: birth,
                life: rng.range((showerLife * 0.72)...showerLife),
                size: rng.range(6.0...11.0),
                spin: rng.range(-6.0...6.0),
                tilt: rng.range(0...(2 * .pi)),
                color: color,
                originX: ox,
                originY: 1.04,
                sway: rng.range(8...26),
                swayFreq: rng.range(2.0...5.0)
            ))
        }
        return out
    }

    /// Tiny deterministic generator so a play token always produces
    /// the same field (films are comparable; nothing random survives
    /// into data).
    struct LCG {
        private var state: UInt64
        init(seed: UInt64) { state = seed == 0 ? 0x4d59_5df4_d0f3_3173 : seed }
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state >> 33
        }
        mutating func range(_ r: ClosedRange<Double>) -> Double {
            let unit = Double(next() % 1_000_000) / 1_000_000
            return r.lowerBound + unit * (r.upperBound - r.lowerBound)
        }
    }
}
