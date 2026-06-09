import SwiftUI
import SwiftData
import PlankSync

// MARK: - ChapterCompleteView
//
// v1.1 program pivot. Day-75 graduation sentinel — fires once when
// `ProgramService.isPostGoal(userId:in:) == true` on first home open
// after the user crosses goalDate. Free emotional moment + 4-card
// next-program picker.
//
// Founder decision 2026-06-09: the celebration is a free moment;
// enrollment in the next program is a separate tap (Phase 5 wires
// the actual transitions for Maintenance 30 / Recomp 60 / New Goal 75
// / Soft Pause). Phase 1 ships the picker UI with ONE working option
// (re-running 75-day with a new goal weight) so the sentinel doesn't
// trap the user.
//
// Anti-shame body copy locked: "30% of women who finish stop here.
// They regain within a year. Stay with us — pick what's next."
// Cited from Wing & Phelan 2005 NWCR (maintenance-phase pattern).

struct ChapterCompleteView: View {

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
        .background(Palette.bgPrimary.ignoresSafeArea())
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
        VStack(alignment: .leading, spacing: Typo.programHeroLineGap) {
            Text("day 75.")
                .font(Typo.programHeroDisplay)
                .foregroundStyle(Palette.cocoaPrimary)
                .accessibilityFocused($titleFocused)
            (
                Text("you ")
                    .font(Typo.programHeroDisplay)
                    .foregroundStyle(Palette.cocoaPrimary)
                +
                Text("became")
                    .font(Typo.programHeroItalic)
                    .foregroundStyle(Palette.cocoaPrimary)
                +
                Text(" her.")
                    .font(Typo.programHeroDisplay)
                    .foregroundStyle(Palette.cocoaPrimary)
            )
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modernEntrance(animateIn)
    }

    private var manifesto: some View {
        // Anti-shame body, NWCR-cited. Two short sentences instead
        // of an em-dash phrase. Founder voice rule 2026-06-09.
        // Renamed from `body` (collides with View protocol's required
        // `var body: some View`, causes recursive-getter compile error).
        Text("30% of women who finish stop here. they regain within a year. stay with us. pick what's next.")
            .font(Typo.body)
            .foregroundStyle(Palette.cocoaSecondary)
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
            Button { onDismiss() } label: {
                Text("give me a beat")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaSecondary)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
        .background(
            Palette.bgPrimary
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
                            Text("soon")
                                .font(Typo.eyebrow)
                                .foregroundStyle(Palette.cocoaTertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(Palette.hairlineCocoa)
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
            .programPaperShadow()
            .opacity(kind.isAvailableInPhase1 ? 1.0 : 0.78)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kind.title), \(kind.subtitle)\(kind.isRecommended ? ", recommended" : "")\(kind.isAvailableInPhase1 ? "" : ", coming soon")")
    }
}
