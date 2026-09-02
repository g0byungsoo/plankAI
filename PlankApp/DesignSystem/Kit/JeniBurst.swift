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
    /// Increment to play. 0 = never played; the first change (or a
    /// mount with `playsOnAppear`) fires the burst. Idempotence lives
    /// in the caller's ledger — this view plays exactly once per
    /// token change.
    var play: Int
    /// Play once when the view first appears (the answer-surface
    /// case, where the burst mounts at the moment it should fire).
    var playsOnAppear: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var elapsed: Double = 0
    @State private var running = false
    @State private var seed: UInt64 = 1

    var body: some View {
        ZStack {
            if running, !reduceMotion {
                Canvas { context, size in
                    let origin = CGPoint(x: size.width / 2, y: size.height / 2)
                    for p in Self.particles(tier: tier, seed: seed) {
                        guard elapsed >= p.birth else { continue }
                        let t = elapsed - p.birth
                        guard t < p.life else { continue }
                        let fade = Self.opacity(t: t, life: p.life)
                        // Constant-velocity launch decayed by drag,
                        // pulled down by gravity — integrated in
                        // closed form so the draw is pure in `t`.
                        let decay = (1 - exp(-Self.drag * t)) / Self.drag
                        let x = origin.x + p.vx * decay
                        let y = origin.y + p.vy * decay
                            + Self.gravity * t * t / 2
                        var ctx = context
                        ctx.opacity = fade
                        ctx.translateBy(x: x, y: y)
                        ctx.rotate(by: Angle(radians: p.spin * t + p.tilt))
                        let rect = CGRect(
                            x: -p.size / 2, y: -p.size * 0.35,
                            width: p.size, height: p.size * 0.7
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
            let total = tier.life + Self.lastBirth(tier: tier)
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
    }

    /// The burst's palette: the rose ramp carries it, ink accents
    /// ground it in the product's own hand. Never more than these.
    private static let palette: [Color] = [
        Palette.roseBerry,
        Palette.accent,
        Palette.roseBlush,
        Palette.textPrimary.opacity(0.85),
    ]

    private static func lastBirth(tier: Tier) -> Double {
        tier == .moment ? 0.16 : 0.05
    }

    static func particles(tier: Tier, seed: UInt64) -> [Particle] {
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
            // Ink is the ACCENT: roughly one fleck in six.
            let color = rng.range(0...1) < 0.17
                ? palette[3]
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
