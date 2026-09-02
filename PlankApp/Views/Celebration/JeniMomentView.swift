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

struct JeniMomentView: View {
    let moment: FoodModule.PlateMoment
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var act = 0
    @State private var burstPlay = 0

    private var tier: JeniBurst.Tier {
        switch moment.tier {
        case "moment": return .moment
        case "crest": return .crest
        default: return .spark
        }
    }

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 14) {
                    if let eyebrow = moment.eyebrow {
                        Text(eyebrow)
                            .font(Typo.statLabel)
                            .kerning(1.4)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.cocoaTertiary)
                    }
                    headline
                        // The burst rises from BEHIND the words being
                        // celebrated — origin-anchored to the moment's
                        // own headline, never screen confetti from
                        // nowhere (the p64 law, kept).
                        .overlay {
                            JeniBurst(tier: tier, play: burstPlay)
                                .frame(width: 400, height: 400)
                                .accessibilityHidden(true)
                        }
                    if let fact = moment.fact {
                        Text(fact)
                            .font(.custom("DMSans-Regular", size: 17, relativeTo: .body))
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .jeniAct(1, current: act)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)

                Spacer(minLength: 0)

                JFContinueButton(label: moment.cta, action: onContinue)
                    .padding(.horizontal, Space.lg)
                    .padding(.bottom, Space.lg)
                    .jeniAct(2, current: act)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            JeniActs.complete($act, to: 2)
        }
        .task {
            // The haptic lands WITH the burst — one event (§8, HIG
            // causality/harmony). The moment tier keeps the crest's
            // hand: rarity is carried by the two-wave visual.
            switch tier {
            case .spark: JeniHaptic.spark()
            case .crest, .moment: JeniHaptic.crest()
            }
            if !reduceMotion { burstPlay += 1 }
            await JeniActs.run($act, to: 2, reduceMotion: reduceMotion)
        }
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
            .foregroundStyle(Palette.textPrimary)
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
