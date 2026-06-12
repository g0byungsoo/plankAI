import SwiftUI
import SwiftData
import PlankSync

// MARK: - ChapterCompleteView
//
// v1.1 program pivot. Graduation sentinel — fires once when
// `ProgramService.isPostGoal(userId:in:) == true` on first home open
// after the user crosses goalDate. Free emotional moment + 4-card
// next-program picker.
//
// Per [[project-program-duration-custom]] the hero shows the user's
// actual totalDays from their plan, not a hardcoded 75. Two users
// might graduate on day 28 (Soft + small goal) and day 175 (Hard +
// big goal) and both deserve the same emotional moment.
//
// Founder decision 2026-06-09: the celebration is a free moment;
// enrollment in the next program is a separate tap (Phase 5 wires
// the actual transitions for Maintenance 30 / Recomp 60 / New Goal 75
// / Soft Pause). Phase 1 ships the picker UI with ONE working option
// (re-running with a new goal weight) so the sentinel doesn't trap
// the user.

struct ChapterCompleteView: View {

    /// Duration of the just-completed plan. Drives the dynamic
    /// "day {totalDays}." hero — never hardcoded.
    let totalDays: Int
    let userId: String
    let onDismiss: () -> Void
    let onPickNextProgram: (NextProgramKind) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var animateIn: Bool = false
    @AccessibilityFocusState private var titleFocused: Bool

    enum NextProgramKind: String, CaseIterable {
        case maintenance30
        case recomp60
        case newGoal75
        case softPause

        var title: String {
            switch self {
            case .maintenance30: return "Maintenance 30"
            case .recomp60:      return "Recomp 60"
            case .newGoal75:     return "New Goal 75"
            case .softPause:     return "Soft Pause"
            }
        }

        var subtitle: String {
            switch self {
            case .maintenance30: return "keep what you built. 30 days."
            case .recomp60:      return "build the shape. 60 days."
            case .newGoal75:     return "go again. same vibe, new target."
            case .softPause:     return "just walks, just lessons. 4 weeks."
            }
        }

        var isRecommended: Bool {
            self == .maintenance30
        }

        /// Phase 1 only ships .newGoal75 as a working transition.
        /// Other tracks are visible but tap shows a "coming soon"
        /// disclosure — locked until Phase 5 lands the engine.
        var isAvailableInPhase1: Bool {
            self == .newGoal75
        }
    }

    /// v8 P8.8: celebration peak earns max sticker density per
    /// designer audit. Mixed gummy bears / bow / sparkle scatter
    /// behind the hero — anchored above the picker so the cards
    /// stay clear. All hit-disabled + a11y-hidden.
    private static let celebrationPlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .gummyBear, position: CGPoint(x: 0.86, y: 0.08), size: 56, rotation: -8, phaseDelay: 0.0),
        StickerPlacement(sticker: .bowIridescent, position: CGPoint(x: 0.12, y: 0.13), size: 44, rotation: 6, phaseDelay: 0.18),
        StickerPlacement(sticker: .sparkleGlossy, position: CGPoint(x: 0.74, y: 0.21), size: 28, rotation: -3, phaseDelay: 0.36),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    hero
                    manifesto
                    picker
                }
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.hero)
                .padding(.bottom, 24)
            }
            footer
        }
        .background(
            ZStack {
                Palette.programBgPrimary
                StickerScatter(placements: Self.celebrationPlacements)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                // Graduation gift — founder-supplied real-photo cutout
                // anchored mid-trailing, under the hero band the
                // sticker scatter occupies.
                GeometryReader { geo in
                    Image("accent-gift")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 92, height: 92)
                        .rotationEffect(.degrees(10))
                        .position(x: geo.size.width - 34, y: geo.size.height * 0.30)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .ignoresSafeArea()
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                animateIn = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                titleFocused = true
            }
        }
    }

    private var hero: some View {
        // v3 P11.1.A (2026-06-10) — converted from modernEntrance fade
        // to LineCascadeText with per-line haptic. Celebration peak
        // earns the her75 luxury cascade signal — the moment the
        // user crosses goalDate is one of the few hero beats that
        // benefits from the cadence per [[feedback-her75-line-cascade]].
        LineCascadeText(
            lines: [
                .plain("day \(totalDays)."),
                .composite(base: "you became her.", italic: ["became"]),
            ],
            baseFont: Typo.programHeroDisplay,
            italicFont: Typo.programHeroItalic,
            color: Palette.cocoaPrimary,
            alignment: .leading,
            lineSpacing: Typo.programHeroLineGap,
            perLineDelay: 0.55,
            trigger: animateIn
        )
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityFocused($titleFocused)
        .accessibilityLabel("Day \(totalDays). You became her.")
    }

    private var manifesto: some View {
        // v8 P8.8: softened from the NWCR scale-shame stat ("30% of
        // women… regain within a year") — that landed wrong on the
        // celebration peak. Anti-shame frame, italic punch on the
        // forward-looking word. Same NWCR-grounded intent, peer
        // register. Founder voice rule 2026-06-09.
        ItalicAccentText(
            "most women stop here. the ones who stay, stay changed. pick what's next.",
            italic: ["changed.", "next."],
            baseFont: Typo.body,
            italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 16),
            color: Palette.cocoaSecondary,
            alignment: .leading
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .modernEntrance(animateIn, delay: 0.08)
    }

    private var picker: some View {
        VStack(spacing: 12) {
            ForEach(Array(NextProgramKind.allCases.enumerated()), id: \.element) { idx, kind in
                ChapterCompleteCard(kind: kind) {
                    if kind.isAvailableInPhase1 {
                        onPickNextProgram(kind)
                    }
                }
                .modernEntrance(animateIn, delay: 0.16 + Double(idx) * 0.06)
            }
        }
    }

    private var footer: some View {
        VStack {
            // v8 P8.8: promoted from a quiet caption to a ghost pill —
            // a graduation deserves a real touch target. Cocoa text on
            // hairline stroke keeps it secondary (no primary action by
            // design — celebration is a free moment).
            Button { onDismiss() } label: {
                Text("give me a beat")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaSecondary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .overlay(
                        Capsule().stroke(Palette.hairlineCocoa, lineWidth: 1)
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            Palette.programBgPrimary
                .overlay(
                    Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5),
                    alignment: .top
                )
        )
        .modernEntrance(animateIn, delay: 0.45)
    }
}

// MARK: - Card

private struct ChapterCompleteCard: View {

    let kind: ChapterCompleteView.NextProgramKind
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(kind.title)
                            .font(Typo.heading)
                            .foregroundStyle(Palette.cocoaPrimary)
                        if kind.isRecommended {
                            Text("recommended")
                                .font(Typo.eyebrow)
                                .foregroundStyle(Palette.stateGood)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(Palette.stateGood.opacity(0.12))
                                )
                        }
                        if !kind.isAvailableInPhase1 {
                            // v8 P8.8: "soon" pill on hairlineCocoa
                            // read dead next to the recommended stateGood
                            // pill. Swap to accentSubtle so locked
                            // options still feel alive on the celebration.
                            Text("soon")
                                .font(Typo.eyebrow)
                                .foregroundStyle(Palette.cocoaTertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(Palette.accentSubtle.opacity(0.4))
                                )
                        }
                    }
                    Text(kind.subtitle)
                        .font(Typo.body)
                        .foregroundStyle(Palette.cocoaSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.cocoaTertiary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.programCard)
                    .fill(Palette.programCard)
            )
            // v8 P8.8: complete the scrapbook chrome — accent border
            // matches PlanView rows + Subflow cards.
            .overlay(
                RoundedRectangle(cornerRadius: Radius.programCard)
                    .stroke(Palette.accent.opacity(0.5), lineWidth: 1.5)
            )
            .programPaperShadow()
            .opacity(kind.isAvailableInPhase1 ? 1.0 : 0.78)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kind.title), \(kind.subtitle)\(kind.isRecommended ? ", recommended" : "")\(kind.isAvailableInPhase1 ? "" : ", coming soon")")
    }
}
