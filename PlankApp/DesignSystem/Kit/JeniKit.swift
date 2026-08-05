import SwiftUI

// MARK: - JeniKit (v11 — the editorial kit)
//
// The seven primitives. Nothing else may appear on a v11 surface
// (docs/app_v11/00_REBIRTH.md §4). The kit is the onboarding's
// register promoted in-app: typography carries hierarchy (L1),
// whitespace is the divider (L2), rows carry words not icons (L3),
// one ink action per screen (L4), no borders or shadows (L5).

// MARK: - JeniPage
//
// The paper shell. Owns the screen's single arrival flag (L12) and
// publishes it through `\.jeniArrived`; children join the sequence
// with `.jeniArrive(index:)`. The title block is index 0.

struct JeniPage<Content: View>: View {
    var title: String? = nil
    var subtitle: String? = nil
    @ViewBuilder var content: () -> Content

    @State private var arrived = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if title != nil || subtitle != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        if let title {
                            Text(title)
                                .font(Typo.questionHero)
                                .foregroundStyle(Palette.textPrimary)
                        }
                        if let subtitle {
                            Text(subtitle)
                                .font(Typo.body)
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                    .jeniArrive(index: 0)
                    // The onboarding's top air — a title breathes
                    // before it speaks (Space.hero, not blockGap).
                    .padding(.top, Space.hero)
                    .padding(.bottom, Space.sm)
                    .accessibilityAddTraits(.isHeader)
                }
                content()
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.heroGap)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.bgPrimary.ignoresSafeArea())
        .environment(\.jeniArrived, arrived)
        .task {
            // One orchestrated arrival per screen. The 50ms beat lets
            // the push transition land before the choreography begins.
            guard !arrived else { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
            arrived = true
        }
    }
}

// MARK: - JeniSectionHeader
//
// THE only separator in the app (L2). Air above, a letterspaced
// whisper, then the section's content.
//
// ARRIVAL GRAMMAR (L12, learned from the frames): the arrival unit
// is the SECTION — wrap header + content together in ONE
// `.jeniArrive(index:)`. A header must never be left unindexed; it
// would render instantly and float on empty paper like a skeleton
// screen while its content is still arriving.

struct JeniSectionHeader: View {
    let label: String

    init(_ label: String) { self.label = label }

    var body: some View {
        Text(label.uppercased())
            .font(.custom("DMSans-SemiBold", size: 11, relativeTo: .caption2))
            .tracking(1.6)
            .foregroundStyle(Palette.cocoaTertiary)
            .padding(.top, Space.sectionGap)
            .padding(.bottom, Space.sm)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - JeniHeadline
//
// The serif line with the italic punch, in three registers. Wraps
// `ItalicAccentText` — the punch is composition, never `*markers*`.

struct JeniHeadline: View {
    enum Register {
        case page   // 34pt — screen titles
        case hero   // 38pt — the moment a screen leads with
        case band   // 26pt — a section's leading line

        var fonts: (base: Font, italic: Font) {
            switch self {
            case .page: return (Typo.questionHero, Typo.questionHeroItalic)
            case .hero: return (Typo.displayHero, Typo.displayHeroItalic)
            case .band: return (
                .custom("JeniHeroSerif-Regular", size: 26, relativeTo: .title2),
                .custom("JeniHeroSerif-Italic", size: 26, relativeTo: .title2)
            )
            }
        }
    }

    let base: String
    var italic: [String] = []
    var register: Register = .band

    init(_ base: String, italic: [String] = [], register: Register = .band) {
        self.base = base
        self.italic = italic
        self.register = register
    }

    var body: some View {
        ItalicAccentText(
            base,
            italic: italic,
            baseFont: register.fonts.base,
            italicFont: register.fonts.italic
        )
    }
}

// MARK: - JeniRow
//
// The universal list row. 60pt, borderless, dividerless, iconless.
// Tap enters the module; the trailing state is render-only; the
// optional long-press is the override (never a tap target).

struct JeniRow: View {
    enum Trailing {
        case none
        case done
        case count(String)
        case chevron
    }

    let title: String
    var detail: String? = nil
    var trailing: Trailing = .none
    let action: () -> Void
    var onLongPress: (() -> Void)? = nil

    init(_ title: String,
         detail: String? = nil,
         trailing: Trailing = .none,
         action: @escaping () -> Void,
         onLongPress: (() -> Void)? = nil) {
        self.title = title
        self.detail = detail
        self.trailing = trailing
        self.action = action
        self.onLongPress = onLongPress
    }

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: Space.md) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.custom("DMSans-Regular", size: 17, relativeTo: .body))
                        // Done rows dim; the trailing dot confirms. One
                        // state, two quiet signals — never a strike.
                        .foregroundStyle(done ? Palette.cocoaTertiary : Palette.textPrimary)
                    if let detail {
                        Text(detail)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                Spacer(minLength: Space.sm)
                trailingView
            }
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(JeniRowPressStyle())
        .simultaneousGesture(
            onLongPress.map { press in
                LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                    JeniHaptic.land()
                    press()
                }
            }
        )
        .accessibilityHint(onLongPress != nil ? Text("double-tap to open. long-press to mark.") : Text(""))
    }

    private var done: Bool {
        if case .done = trailing { return true }
        return false
    }

    @ViewBuilder private var trailingView: some View {
        switch trailing {
        case .none:
            EmptyView()
        case .done:
            Circle()
                .fill(Palette.textPrimary)
                .frame(width: 7, height: 7)
                .accessibilityLabel(Text("done"))
        case .count(let text):
            Text(text)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.cocoaTertiary)
        }
    }
}

/// The row's press acknowledgment — a settle, not a highlight box.
private struct JeniRowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .animation(JeniMotion.settle, value: configuration.isPressed)
    }
}

// MARK: - JeniPrimaryButton
//
// The ONE ink pill (L4). Promotes JFContinueButton so onboarding and
// the app share a single button — same capsule, same haptic, same
// scale-not-ellipsize contract.

struct JeniPrimaryButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        JFContinueButton(label: title, action: action)
    }
}

// MARK: - jeniSheet
//
// The sheet grammar: paper, 28pt radius, grabber, medium-first.
// Content composes kit primitives; exactly one primary action inside.

extension View {
    func jeniSheet<C: View>(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = [.medium, .large],
        @ViewBuilder content: @escaping () -> C
    ) -> some View {
        sheet(isPresented: isPresented) {
            content()
                .presentationDetents(detents)
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
                .presentationBackground(Palette.bgPrimary)
        }
    }
}

// MARK: - JeniCard
//
// The ONLY card (L5): white on paper, 20pt radius, no border, no
// shadow. Earned by content that is a single object — a reading, a
// tile — never used to box a list.

struct JeniCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(Space.blockGap)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.bgElevated)
            )
    }
}

// MARK: - Gallery (DEBUG)

#if DEBUG
/// `--debug-v11-gallery` — every primitive on one page, the arrival
/// choreography restartable by tapping the title (for THE LOOP's
/// frame captures).
struct JeniKitGallery: View {
    @State private var run = 0
    @State private var sheetUp = false

    var body: some View {
        JeniPage(title: "the kit", subtitle: "v11 · every primitive, arriving") {
            // The arrival unit is the section: header + content, one index.
            VStack(alignment: .leading, spacing: 0) {
                JeniSectionHeader("headlines")
                VStack(alignment: .leading, spacing: Space.blockGap) {
                    JeniHeadline("down 2.1 lb, and your waist reads narrower.",
                                 italic: ["narrower."], register: .hero)
                    JeniHeadline("what the week actually did", italic: ["actually"],
                                 register: .band)
                }
            }
            .jeniArrive(index: 1)

            VStack(alignment: .leading, spacing: 0) {
                JeniSectionHeader("numerals count")
                JeniCountingNumeral(value: 1240, unit: "of 2,060 kcal")
            }
            .jeniArrive(index: 2)

            VStack(alignment: .leading, spacing: 0) {
                JeniSectionHeader("today")
                JeniRow("add protein before noon", detail: "about 30 g to go",
                        action: {}, onLongPress: {})
                JeniRow("10 min movement", trailing: .count("in the evening"),
                        action: {})
                JeniRow("body check-in", trailing: .done, action: {})
                JeniRow("this week, in words", trailing: .chevron,
                        action: { sheetUp = true })
            }
            .jeniArrive(index: 3)

            VStack(alignment: .leading, spacing: 0) {
                JeniSectionHeader("the card")
                JeniCard {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        JeniHeadline("sodium ran high thursday.", italic: ["thursday."])
                        Text("the scale follows for a day or two. water, not fat.")
                            .font(Typo.body)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            }
            .jeniArrive(index: 4)

            VStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: Space.sectionGap)
                JeniPrimaryButton("continue") {}
            }
            .jeniArrive(index: 5)
        }
        .id(run)
        .onTapGesture(count: 2) { run += 1 } // restart the choreography
        .jeniSheet(isPresented: $sheetUp) {
            JeniPage(title: "the sheet", subtitle: "paper, 28pt, one action") {
                JeniSectionHeader("grammar")
                Text("a sheet composes the same primitives as a page.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                Color.clear.frame(height: Space.sectionGap)
                JeniPrimaryButton("done") { sheetUp = false }
            }
        }
    }
}
#endif
