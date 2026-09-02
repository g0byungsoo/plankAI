import SwiftUI
import PlankFood

// MARK: - JeniMomentView (p65 — THE MOMENT SYSTEM)
//
// THE ONE full-page celebration surface. The founder's correction of
// p64: a meaningful committed event — especially a meal — deserves its
// own moment, not particles over the sheet it happens to share. The
// rhythm is COMMIT → CELEBRATION → CONTINUE → HOME.
//
// One module, many moments: content and intensity vary from semantic
// inputs (occasion · eyebrow · headline · fact · tier · cta). A new
// moment is a payload, never a new screen — the visual system, the
// arrival grammar, the particles and the haptic all live here once.
//
// Laws:
//   · presented only AFTER the commit persisted — a celebration may
//     never outrun the record (p61: a save that failed may never look
//     like one that worked).
//   · one moment per commit, the biggest fact wins (PlateMomentClaim
//     owns priority; this view renders exactly one payload).
//   · speech arrival (JeniActs): headline → fact → the way out, one
//     idea at a time; a tap anywhere lands all; the CTA cannot be hit
//     before it arrives.
//   · Reduce Motion: everything arrives whole, zero particles — the
//     page, the words and the haptic still carry "this mattered"
//     (never "nothing happened").
//   · the haptic and the burst are ONE event, at mount, tier-mapped
//     to the p63/64 grammar (spark · crest; the moment tier keeps
//     the crest's hand — rarity lives in the visual, not a new hand).
//   · never celebrated here or anywhere: restriction, eating less,
//     calories left, weight numbers, streaks (the standing boundary).

/// p66 — the celebration layer above the page. The founder's
/// correction of p65: the peak was too weak — ~30 flecks beside one
/// word read as tasteful, not celebratory. Decided by a filmed
/// bake-off in `--debug-moment-gallery` against the six bundled
/// effect Lotties (glossy fireworks · line-art pink fireworks ×2 ·
/// confetti ×3): every Lottie lost — candy-magenta against the rose
/// ramp, 0.6-2s comps, action filling a fraction of the frame. The
/// native full-page shower (JeniBurst `.shower`) won on color truth,
/// scale, determinism and honest Reduce Motion; the losers' plumbing
/// was deleted with the verdict.
enum MomentFX: Equatable {
    /// The shipping mapping — resolved from the moment's tier:
    ///   spark  — the word-anchored pop only (several times a week
    ///            must stay light)
    ///   crest  — pop + a medium full-page shower (once a day by
    ///            construction)
    ///   moment — pop + the full shower (once per lifetime)
    case tierDefault
    /// Pop only (p65's behavior) — the bake-off baseline.
    case none
    /// The native full-page confetti volley (JeniBurst .shower).
    case shower

    func wantsShower(for tier: JeniBurst.Tier) -> Bool {
        switch self {
        case .tierDefault: return tier != .spark
        case .shower: return true
        case .none: return false
        }
    }
}

struct JeniMomentView: View {
    let moment: FoodModule.PlateMoment
    var celebration: MomentFX = .tierDefault
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var act = 0
    @State private var burstPlay = 0
    /// p67 — THE INK SCENE. Crest and moment tiers earn the flip: the
    /// page mounts on the same paper as the surface beneath (the cut
    /// disappears), holds one anticipation beat, then the whole
    /// surface crossfades to ink and the celebration plays against
    /// the dark. Spark stays paper — several-times-a-week must stay
    /// light, and the tier system is the rule for when the surface
    /// may go dark. Reduce Motion arrives ON ink (state, not motion).
    @State private var onInk = false
    @State private var leaving = false

    private var tier: JeniBurst.Tier {
        switch moment.tier {
        case "moment": return .moment
        case "crest": return .crest
        default: return .spark
        }
    }

    private var wantsInk: Bool { tier != .spark }
    private var ink: Bool { onInk && !leaving }

    private var textColor: Color {
        ink ? Palette.textInverse : Palette.textPrimary
    }
    private var factColor: Color {
        ink ? Palette.textInverse.opacity(0.66) : Palette.textSecondary
    }

    /// p68 — THE DOODLE IS THE CELEBRATION'S OBJECT. The page was
    /// typography floating in a void (founder: "a protein-goal
    /// celebration probably should not be almost entirely typography
    /// in empty space"). Each occasion carries one big hand-drawn
    /// illustration from the founder's set — the celebrated thing,
    /// drawn: the crossing gets the dartboard with the arrow in it,
    /// the first plate ever gets applause, the day's first plate gets
    /// the dish. Mapped here (not in the payload) so the package
    /// contract is untouched and a new occasion degrades to the
    /// words-only page.
    private var doodleName: String? {
        switch moment.occasion {
        case "floor_crossing":    "doodle-target"
        case "first_plate_ever":  "doodle-clap"
        case "first_plate_today": "doodle-dish"
        default:                  nil
        }
    }

    @State private var doodleArrived = false

    /// The scene's exit: flip back to paper, then leave — so the
    /// return to the page beneath is composed, not a cut from dark.
    private func leave() {
        guard wantsInk, onInk, !reduceMotion else { return onContinue() }
        withAnimation(.easeInOut(duration: JeniScene.exitFlip)) {
            leaving = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + JeniScene.exitFlip * 0.9) {
            onContinue()
        }
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(ink ? Palette.bgInverse : Palette.bgPrimary)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 14) {
                    if let eyebrow = moment.eyebrow {
                        Text(eyebrow)
                            .font(Typo.statLabel)
                            .kerning(1.4)
                            .textCase(.uppercase)
                            .foregroundStyle(ink
                                ? Palette.textInverse.opacity(0.45)
                                : Palette.cocoaTertiary)
                    }
                    headline
                        // p68 — the burst rises from behind the words
                        // only when no doodle carries the moment; with
                        // a doodle, the object itself is the origin
                        // (the p64 law: the pop comes FROM the thing
                        // celebrated).
                        .overlay {
                            if doodleName == nil {
                                JeniBurst(tier: tier, play: burstPlay, onInk: wantsInk)
                                    .frame(width: 400, height: 400)
                                    .accessibilityHidden(true)
                            }
                        }
                    if let fact = moment.fact {
                        Text(fact)
                            .font(.custom("DMSans-Regular", size: 17, relativeTo: .body))
                            .foregroundStyle(factColor)
                            .fixedSize(horizontal: false, vertical: true)
                            .jeniAct(1, current: act)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)

                if let doodleName {
                    Spacer(minLength: Space.lg)

                    // p68 — the celebrated thing, drawn large. It
                    // arrives WITH the burst and the haptic (one
                    // event): a spring pop from 0.6 scale, then the
                    // doodle's own ambient drift takes over. On ink it
                    // is paper-tinted (the one-colour law holds on
                    // both surfaces). Decorative — the words carry the
                    // meaning; Reduce Motion arrives whole and still.
                    JeniDoodle(
                        name: doodleName,
                        size: 190,
                        tint: ink
                            ? Palette.textInverse.opacity(0.92)
                            : Palette.textPrimary.opacity(0.9)
                    )
                    .overlay {
                        JeniBurst(tier: tier, play: burstPlay, onInk: wantsInk)
                            .frame(width: 400, height: 400)
                            .accessibilityHidden(true)
                    }
                    .scaleEffect(doodleArrived || reduceMotion ? 1 : 0.6)
                    .opacity(doodleArrived || reduceMotion ? 1 : 0)
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: Space.lg)
                } else {
                    Spacer(minLength: 0)
                }

                JFContinueButton(label: moment.cta, action: leave,
                                 inverse: ink)
                    .padding(.horizontal, Space.lg)
                    .padding(.bottom, Space.lg)
                    .jeniAct(2, current: act)
            }

            // p66 — the celebration above the page. Decorative only:
            // never hit-testable, hidden from VoiceOver, absent under
            // Reduce Motion (the page, words and haptic carry the
            // meaning). The shower shares the pop's engine, palette
            // and determinism — one celebration material, full page.
            if celebration.wantsShower(for: tier) {
                JeniBurst(tier: tier, mode: .shower, play: burstPlay,
                          onInk: wantsInk)
                    .ignoresSafeArea()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            JeniActs.complete($act, to: 2)
        }
        .task {
            // p67 — the scene: paper hold → surface flip → then the
            // celebration. The haptic + burst land as the ink settles
            // (one event, at the scene's own peak); words follow on
            // the speech grammar. Spark keeps its instant paper play.
            if wantsInk {
                if reduceMotion {
                    onInk = true
                } else {
                    try? await Task.sleep(nanoseconds: UInt64(JeniScene.warmHold * 1e9))
                    withAnimation(.easeInOut(duration: JeniScene.flip)) {
                        onInk = true
                    }
                    try? await Task.sleep(nanoseconds: UInt64(JeniScene.flip * 0.75 * 1e9))
                }
            }
            switch tier {
            case .spark: JeniHaptic.spark()
            case .crest, .moment: JeniHaptic.crest()
            }
            if !reduceMotion { burstPlay += 1 }
            // p68 — the doodle pops in as part of the same event as
            // the haptic and the burst (one celebration, one instant).
            withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) {
                doodleArrived = true
            }
            await JeniActs.run($act, to: 2, reduceMotion: reduceMotion)
        }
        // p67 — the scene declares itself dark so the system chrome
        // (the clock) stays legible over the ink. The app is
        // light-locked; this is scoped to the scene, not a theme.
        .preferredColorScheme(ink ? .dark : nil)
        .accessibilityElement(children: .contain)
    }

    /// The headline with its italic punch, split the way the answer
    /// block splits (degrades to flat prose if the punch drifts).
    private var headline: some View {
        let split = Self.split(moment.headline, punch: moment.punch)
        return (Text(split.prefix)
            .font(.custom("JeniHeroSerif-Regular", size: 34, relativeTo: .largeTitle))
         + Text(split.punch)
            .font(.custom("JeniHeroSerif-Italic", size: 34, relativeTo: .largeTitle))
         + Text(split.suffix)
            .font(.custom("JeniHeroSerif-Regular", size: 34, relativeTo: .largeTitle)))
            .foregroundStyle(textColor)
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
    }

    private static func split(
        _ text: String, punch: String?
    ) -> (prefix: String, punch: String, suffix: String) {
        guard let punch, !punch.isEmpty, let r = text.range(of: punch) else {
            return (text, "", "")
        }
        return (String(text[text.startIndex..<r.lowerBound]),
                punch,
                String(text[r.upperBound...]))
    }
}
