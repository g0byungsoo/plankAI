#if DEBUG
import SwiftUI

// MARK: - JKGallery (--debug-jenikit)
//
// Every JeniKit component with sample data in one scroll so the
// premium register can be iterated + screenshot without navigating
// the app. Launch:
//   xcrun simctl launch booted com.bk.plankAI --debug-jenikit

struct JKGalleryHarness: View {
    @State private var tab: JKTab = .today
    @State private var beatDone = false
    @State private var protein = 61

    var body: some View {
        JKScreenChrome {
            ScrollViewReader { proxy in
                galleryScroll
                    .onAppear {
                        // --debug-jenikit-bottom → land on the lower half
                        // (simctl can't synthesize scroll gestures).
                        if ProcessInfo.processInfo.arguments.contains("--debug-jenikit-bottom") {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                withAnimation(.none) { proxy.scrollTo("jk.bottom", anchor: .bottom) }
                            }
                        }
                    }
            }
        }
        .safeAreaInset(edge: .bottom) {
            JKTabBar(selection: $tab, badge: .jeni)
        }
        .statusBarHidden(false)
    }

    private var galleryScroll: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    JKMasthead(
                        lead: .dayPill(day: 12, note: "a protein day \u{2665}\u{FE0E}"),
                        eyebrow: "thursday, july 3",
                        marks: [
                            JKMastheadMark(systemName: "camera", label: "snap a meal", action: {}),
                            JKMastheadMark(systemName: "line.3.horizontal", label: "settings", action: {}),
                        ]
                    )
                    .padding(.top, Space.hero)

                    section("coach line") {
                        JKCoachLine(
                            text: "a protein day. one strong plate at a time.",
                            italic: ["strong"],
                            onOpenChat: {}
                        )
                        .padding(.horizontal, Space.lg)
                    }

                    section("beat rows — tap the first to toggle") {
                        VStack(spacing: Space.optionGap) {
                            JKBeatRow(
                                title: "snap a meal",
                                subtitle: "before you eat",
                                glyph: "camera",
                                state: .init(isDone: beatDone, isAuto: false, progress: nil),
                                isHero: true,
                                onTap: { beatDone.toggle() }
                            )
                            JKBeatRow(
                                title: "move",
                                subtitle: "15 min · gentle strength",
                                glyph: "figure.run",
                                state: .init(isDone: true, isAuto: true, progress: nil),
                                onTap: {}
                            )
                            JKBeatRow(
                                title: "7,500 steps",
                                subtitle: "counted for you",
                                glyph: "figure.walk",
                                state: .init(isDone: false, isAuto: false, progress: 0.62),
                                onTap: {}
                            )
                        }
                        .padding(.horizontal, Space.lg)
                    }

                    section("gauges — tap arc to add protein") {
                        HStack(alignment: .top, spacing: Space.xl) {
                            JKProteinArc(grams: protein, targetG: 112, note: "lean-mass first")
                                .onTapGesture { protein += 17 }
                            JKStepsRing(steps: 4_680, goal: 7_500)
                        }
                        .frame(maxWidth: .infinity)
                        JKKcalLine(kcal: 980, target: 1_640)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, Space.md)
                    }

                    section("plate strip") {
                        JKPlateStrip(
                            items: [
                                .init(id: "1", time: "8:12", title: "greek yogurt bowl", image: nil, kcal: 320),
                                .init(id: "2", time: "12:40", title: "poke bowl", image: nil, kcal: 520),
                            ],
                            onAdd: {}
                        )
                    }

                    section("receipt rows") {
                        VStack(spacing: 0) {
                            JKReceiptRow(lead: "protein", punch: "84g · landed", punchItalic: ["landed"], showsRule: false)
                            JKReceiptRow(lead: "you moved", punch: "15 minutes", punchItalic: [])
                            JKReceiptRow(lead: "the method", punch: "one lesson, kept", punchItalic: ["kept"])
                        }
                        .padding(.horizontal, Space.lg + Space.sm)
                    }

                    section("chain line + coach mark + empty state") {
                        JKChainLine(
                            lead: "next",
                            suggestion: "60 seconds of breath",
                            italic: ["breath"],
                            action: {}
                        )
                        .padding(.horizontal, Space.lg)
                        JKCoachMark(
                            text: "tap a row to begin it. it strikes through when it's done.",
                            seenKey: "jk.gallery.mark"
                        )
                        JKEmptyState(
                            line: "your first plate starts the story",
                            italic: ["story"],
                            actionLabel: "snap it",
                            action: {}
                        )
                    }

                    section("confirm pills") {
                        JKConfirmPills(
                            confirmLabel: "log 74.2 kg",
                            cancelLabel: "not now",
                            onConfirm: {}, onCancel: {}
                        )
                        .padding(.horizontal, Space.lg)
                    }

                    Spacer(minLength: 90)
                        .id("jk.bottom")
                }
            }
            .scrollIndicators(.hidden)
    }

    @ViewBuilder private func section(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text(label)
                .font(Typo.captionTracked)
                .kerning(1.98)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.horizontal, Space.lg)
            content()
        }
    }
}
#endif
