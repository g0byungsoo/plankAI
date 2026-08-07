import SwiftUI

// MARK: - Chapter content model
//
// Chapters are the ink pages: the system declares, in cascade, on
// `Palette.bgInverse`. Content is computed against the live store by
// the script (V8Beats) so every line passes the falsifiability test.

enum V8StructuredKind: String {
    case snapDemo, safetyGate, signature, healthKit, hold
}

enum V8ChapterKind: String {
    case arrival, mirror, evidence, file
}

struct V8EvidencePage: Equatable, Identifiable {
    var id: String { caption }
    var numeral: String? = nil
    var headline: String? = nil
    var headlineItalic: [String] = []
    var caption: String
    var citation: String? = nil
    /// Drawn evidence on the page — draws on arrival (charts steer).
    var figure: V8Figure? = nil
}

struct V8ChapterContent {
    var eyebrow: String? = nil
    /// The arrival's spoken greeting. A quieter register than the
    /// declaration beneath it: jeni SPEAKS (small, human), then the
    /// product STATES (display). Same serif — size carries the
    /// hierarchy, never family (v15).
    var greeting: String? = nil
    var greetingItalic: [String] = []
    var lines: [V8Line] = []
    var pages: [V8EvidencePage] = []
    var rows: [(label: String, value: String)] = []
    var cta: String = "continue"
    var secondary: String? = nil
    /// Declarations (arrival, mirror) speak in the display register;
    /// working chapters (evidence, file) keep the conversation size.
    var display: Bool = false
}

// MARK: - V8Cascade
//
// her75's line cascade, promoted to the chapter register: lines rise
// in whole, one at a time, a soft tick each. The chapter's voice.

struct V8Cascade: View {
    let lines: [V8Line]
    var lineDelay: Double = V8Tempo.cascadeStagger
    /// Wait before the first line — the arrival lets the mark finish.
    var startDelay: Double = 0.35
    var display: Bool = false
    var onDone: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0

    var body: some View {
        VStack(alignment: .leading, spacing: display ? 14 : 18) {
            ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                V8LineText(
                    line: line,
                    revealed: .max,
                    font: display ? Typo.questionHero : V8Type.message,
                    italicFont: display ? Typo.questionHeroItalic : V8Type.messageItalic,
                    color: Palette.textInverse
                )
                .lineSpacing(display ? -6 : V8Type.messageLineGap)
                .opacity(idx < shown ? 1 : 0)
                .offset(y: idx < shown || reduceMotion ? 0 : 10)
                .animation(V8Tempo.cascade.delay(0), value: shown)
            }
        }
        .task {
            guard shown < lines.count else { return }
            try? await Task.sleep(nanoseconds: UInt64(startDelay * 1_000_000_000))
            for i in 0..<lines.count {
                guard !Task.isCancelled else { return }
                withAnimation(V8Tempo.cascade) { shown = i + 1 }
                if !reduceMotion { JeniHaptic.tick() }
                try? await Task.sleep(
                    nanoseconds: UInt64((reduceMotion ? 0.12 : lineDelay) * 1_000_000_000)
                )
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
            onDone?()
        }
    }
}

// MARK: - The inverse pill (paper on ink)

struct V8InversePill: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.medium()
            action()
        } label: {
            Text(label)
                .font(.custom("DMSans-SemiBold", size: 17, relativeTo: .body))
                .foregroundStyle(Palette.bgInverse)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Capsule().fill(Palette.textInverse))
                .contentShape(Capsule())
        }
        .buttonStyle(JeniPressable())
    }
}

// MARK: - V8Chapter
//
// The ink page shell: blooms behind, cascade (or bespoke content),
// one paper pill. The CTA arrives only after the cascade has said
// its piece — nothing appears, everything arrives.

struct V8Chapter: View {
    let kind: V8ChapterKind
    let content: V8ChapterContent
    let onContinue: () -> Void
    var onSecondary: (() -> Void)? = nil

    @State private var ctaShown = false
    @State private var markShown = false
    /// The arrival ritual, in three moves: the mark writes itself
    /// large, TRAVELS into its masthead slot, and the product rises
    /// into the room it leaves.
    @State private var markSettled = false
    @State private var deviceShown = false
    @State private var greetingShown = false
    /// One chapter, one advance — a double-fire can never walk the
    /// flow two beats (loop-1 ghost-advance defense).
    @State private var advanced = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    /// The mark's resting height. With the product on the page the
    /// mark shrinks to CHROME (22) and sits where the consult's own
    /// mark will sit on the very next beat — the same size, the same
    /// centre line, so walking forward never moves it. Without a demo
    /// — small screens, big type — it stays the brand moment it has
    /// always been (96) and the arrival renders exactly as it shipped.
    private static let markSlot: CGFloat = 22
    private static let markDisplay: CGFloat = 96
    /// Puts the settled mark's centre 30pt below the content top,
    /// which is where `chrome()` seats its 19pt mark (2pt hairline +
    /// 6pt air + half a 44pt row).
    private static let markTopAir: CGFloat = 19

    private func fireContinue() {
        guard !advanced else { return }
        advanced = true
        onContinue()
    }

    var body: some View {
        GeometryReader { geo in
            chapterBody(available: geo.size.height)
        }
    }

    /// What the arrival can spend on the demo, measured rather than
    /// guessed: everything else on the page is fixed (the mark slot,
    /// two display lines, the pill and its door), so the device takes
    /// what is left and nothing more. Below a floor it does not
    /// render at all, and at accessibility type sizes the words win —
    /// a fixed frame around scaling type is always a bug (v19.1).
    private func deviceHeight(available: CGFloat) -> CGFloat {
        guard kind == .arrival, !typeSize.isAccessibilitySize else { return 0 }
        // Everything else on the page, measured on film rather than
        // estimated: the mark's chrome slot and its air, ONE display
        // line, the pill, its door — plus the breath the hero needs
        // above the pill. (Loop 1 budgeted 390 against a four-line
        // hero and the last line sat ON the pill; loop 2 budgeted 430
        // and it touched. Each line the hero gave back went straight
        // into the demo, which is why the copy pass and the size pass
        // were the same pass.)
        let left = available - 414
        guard left >= 168 else { return 0 }
        return min(left, 440)
    }

    @ViewBuilder
    private func chapterBody(available: CGFloat) -> some View {
        let device = deviceHeight(available: available)

        ZStack(alignment: .topLeading) {
            V8Blooms()

            VStack(alignment: .leading, spacing: 0) {
                // With the demo present the arrival hangs from the
                // top — the mark is a masthead and the slack belongs
                // BELOW the words, between the hero and the pill.
                // Every other chapter still floats between two spacers.
                if kind != .arrival || device == 0 { Spacer(minLength: 0) }

                if kind == .arrival {
                    // The SLOT never moves; the artwork travels into
                    // it. The mark is drawn at its display size and
                    // only ever scaled DOWN, so the raster stays
                    // clean-edged at every step of the journey.
                    let slot = device > 0 ? Self.markSlot : Self.markDisplay
                    Color.clear
                        .frame(height: slot)
                        .overlay {
                            JeniMark(height: 96, color: Palette.textInverse)
                                .opacity(markShown ? 1 : 0)
                                .mask(
                                    // The mark writes itself: a soft-edged
                                    // wipe travelling the stroke's direction.
                                    GeometryReader { geo in
                                        LinearGradient(
                                            stops: [
                                                .init(color: .black, location: 0),
                                                .init(color: .black, location: markShown ? 1 : 0),
                                                .init(color: .clear, location: markShown ? 1 : 0.02),
                                            ],
                                            startPoint: .top, endPoint: .bottom
                                        )
                                        .frame(height: geo.size.height * 1.3)
                                    }
                                )
                                .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.9),
                                           value: markShown)
                                .scaleEffect(markSettled ? slot / Self.markDisplay
                                                         : (markShown ? 1 : 1.035),
                                             anchor: .center)
                                // Nothing to make room for, no journey.
                                .offset(y: markSettled || device == 0
                                        ? 0 : available * 0.24)
                                .animation(.spring(response: 0.62, dampingFraction: 0.90),
                                           value: markSettled)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, device > 0 ? Self.markTopAir : 0)
                        .padding(.bottom, device > 0 ? Space.md : Space.xl)
                        .accessibilityLabel("jeni")

                    if device > 0 {
                        V8DeviceDemo(height: device)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .opacity(deviceShown ? 1 : 0)
                            .scaleEffect(deviceShown || reduceMotion ? 1 : 0.96)
                            .offset(y: deviceShown || reduceMotion ? 0 : 26)
                            .animation(.spring(response: 0.58, dampingFraction: 0.88),
                                       value: deviceShown)
                            .padding(.bottom, Space.md)
                    }
                }

                if let greeting = content.greeting {
                    V8LineText(
                        line: V8Line(greeting, italic: content.greetingItalic),
                        revealed: .max,
                        font: .custom("JeniHeroSerif-Regular", size: 19,
                                      relativeTo: .title3),
                        italicFont: .custom("JeniHeroSerif-Italic", size: 19,
                                            relativeTo: .title3),
                        color: Palette.textInverse.opacity(0.72)
                    )
                    .padding(.bottom, 6)
                    .opacity(greetingShown ? 1 : 0)
                    .offset(y: greetingShown || reduceMotion ? 0 : JeniMotion.rise)
                    .animation(V8Tempo.inputArrive, value: greetingShown)
                }

                if let eyebrow = content.eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.custom("DMSans-SemiBold", size: 11, relativeTo: .caption2))
                        .tracking(1.6)
                        .foregroundStyle(Palette.textInverse.opacity(0.45))
                        .padding(.bottom, Space.md)
                }

                if kind == .evidence {
                    V8EvidencePager(pages: content.pages) {
                        revealCTA()
                    }
                } else if kind == .file {
                    V8FileAssembly(lines: content.lines, rows: content.rows) {
                        revealCTA()
                    }
                } else {
                    V8Cascade(
                        lines: content.lines,
                        // The arrival's words wait for the ritual: the
                        // mark writes, travels, and the product lands
                        // before jeni says who she is.
                        startDelay: kind == .arrival
                            ? (reduceMotion ? 0.5 : (device > 0 ? 2.05 : 1.5))
                            : 0.35,
                        display: content.display
                    ) { revealCTA() }
                }

                Spacer(minLength: 0)

                V8InversePill(label: content.cta) {
                    // Two-stage: an early tap completes the page; the
                    // next one continues. Hit-testing never gates —
                    // a tap can never fall through the pill (loop-2:
                    // the walker's tap passed through a fading pill
                    // and the flow froze on the mirror).
                    if ctaShown { fireContinue() } else { revealCTA() }
                }
                .opacity(ctaShown ? 1 : 0)
                .offset(y: ctaShown || reduceMotion ? 0 : JeniMotion.rise)
                .animation(V8Tempo.inputArrive, value: ctaShown)

                if let secondary = content.secondary {
                    Button {
                        onSecondary?()
                    } label: {
                        Text(secondary)
                            .font(.custom("DMSans-Medium", size: 14, relativeTo: .footnote))
                            .foregroundStyle(Palette.textInverse.opacity(0.55))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .opacity(ctaShown ? 1 : 0)
                    .animation(V8Tempo.inputArrive.delay(0.08), value: ctaShown)
                } else {
                    Color.clear.frame(height: Space.sm)
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            // First tap completes the page; once the CTA is up, a tap
            // anywhere continues (the reference's chapter grammar).
            if ctaShown && kind != .arrival {
                fireContinue()
            } else {
                if kind == .arrival { hurryArrival() }
                revealCTA()
            }
        }
        .task {
            guard kind == .arrival else { return }
            try? await Task.sleep(nanoseconds: 300_000_000)
            markShown = true
            if !reduceMotion { JeniHaptic.land() }
            guard !reduceMotion else { hurryArrival(); return }
            // The wipe finishes writing before the mark moves.
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !markSettled else { return }
            withAnimation(.spring(response: 0.62, dampingFraction: 0.90)) {
                markSettled = true
            }
            try? await Task.sleep(nanoseconds: 240_000_000)
            guard !deviceShown else { return }
            withAnimation(.spring(response: 0.58, dampingFraction: 0.88)) {
                deviceShown = true
            }
            // She says hello once the product has landed, and the
            // declaration follows her.
            try? await Task.sleep(nanoseconds: 260_000_000)
            guard !greetingShown else { return }
            withAnimation(V8Tempo.inputArrive) { greetingShown = true }
        }
        .environment(\.v8OnInk, true)
    }

    /// A tap during the ritual lands it (tap-anywhere = complete —
    /// §6 of the direction; the page never makes her wait twice).
    private func hurryArrival() {
        guard !markSettled || !deviceShown || !greetingShown else { return }
        markShown = true
        withAnimation(reduceMotion ? nil : JeniMotion.arrive) {
            markSettled = true
            deviceShown = true
            greetingShown = true
        }
    }

    private func revealCTA() {
        guard !ctaShown else { return }
        withAnimation(V8Tempo.inputArrive) { ctaShown = true }
    }
}

// MARK: - Evidence pager
//
// Reference grammar: pages DISSOLVE in place (never slide), dots
// whisper the count, numerals count up on arrival.

struct V8EvidencePager: View {
    let pages: [V8EvidencePage]
    var onLastPage: () -> Void

    @State private var index = 0
    @State private var arrived = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if let page = pages.indices.contains(index) ? pages[index] : nil {
                    VStack(alignment: .leading, spacing: Space.md) {
                        if let numeral = page.numeral {
                            Text(numeral)
                                .font(.custom("JeniHeroSerif-Regular", size: 72, relativeTo: .largeTitle))
                                .foregroundStyle(Palette.textInverse)
                                .contentTransition(.numericText())
                        }
                        if let headline = page.headline {
                            V8LineText(
                                line: V8Line(headline, italic: page.headlineItalic),
                                revealed: .max,
                                font: V8Type.message,
                                italicFont: V8Type.messageItalic,
                                color: Palette.textInverse
                            )
                            .lineSpacing(V8Type.messageLineGap)
                        }
                        Text(page.caption)
                            .font(.custom("DMSans-Regular", size: 16, relativeTo: .body))
                            .lineSpacing(4)
                            .foregroundStyle(Palette.textInverse.opacity(0.72))
                        if let figure = page.figure {
                            V8FigureView(figure: figure)
                                .padding(.vertical, 6)
                                .id("fig-\(index)")
                        }
                        if let citation = page.citation {
                            Text(citation)
                                .font(.custom("DMSans-Regular", size: 13, relativeTo: .footnote))
                                .foregroundStyle(Palette.textInverse.opacity(0.45))
                        }
                    }
                    .id(index)
                    .transition(.opacity)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: index)

            if pages.count > 1 {
                HStack(spacing: 7) {
                    ForEach(pages.indices, id: \.self) { i in
                        Circle()
                            .fill(Palette.textInverse.opacity(i == index ? 0.9 : 0.28))
                            .frame(width: 5, height: 5)
                            .animation(.easeInOut(duration: 0.25), value: index)
                    }
                }
                .padding(.top, Space.lg)
                .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { advancePage() }
        .task {
            arrived = true
            guard !reduceMotion else { onLastPage(); return }
            // Self-paced reading with a generous auto-advance.
            while !Task.isCancelled, index < pages.count - 1 {
                try? await Task.sleep(nanoseconds: 4_200_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.4)) {
                    index = min(index + 1, pages.count - 1)
                }
                if index == pages.count - 1 { onLastPage() }
            }
            if pages.count <= 1 { onLastPage() }
        }
        .accessibilityElement(children: .contain)
    }

    private func advancePage() {
        if index < pages.count - 1 {
            withAnimation(.easeInOut(duration: 0.4)) { index += 1 }
            if index == pages.count - 1 { onLastPage() }
        } else {
            onLastPage()
        }
    }
}

// MARK: - The file assembly
//
// The dossier writes itself: cascade opener, then hairline rows land
// one at a time. Every value traces to a collected field (L8).

struct V8FileAssembly: View {
    let lines: [V8Line]
    let rows: [(label: String, value: String)]
    var onDone: () -> Void

    @State private var shownRows = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            V8Cascade(lines: lines, onDone: { startRows() })
            Color.clear.frame(height: Space.lg)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.label)
                            .font(.custom("DMSans-Regular", size: 14, relativeTo: .footnote))
                            .foregroundStyle(Palette.textInverse.opacity(0.55))
                        Spacer(minLength: Space.md)
                        Text(row.value)
                            .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
                            .foregroundStyle(Palette.textInverse)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, 11)
                    .overlay(alignment: .bottom) {
                        if idx < rows.count - 1 {
                            Rectangle()
                                .fill(Palette.textInverse.opacity(0.12))
                                .frame(height: 0.5)
                        }
                    }
                    .opacity(idx < shownRows ? 1 : 0)
                    .offset(y: idx < shownRows || reduceMotion ? 0 : 8)
                }
            }
        }
    }

    private func startRows() {
        Task { @MainActor in
            for i in 0..<rows.count {
                guard !Task.isCancelled else { return }
                withAnimation(V8Tempo.cascade) { shownRows = i + 1 }
                if !reduceMotion { JeniHaptic.tick() }
                try? await Task.sleep(nanoseconds: UInt64((reduceMotion ? 0.05 : 0.14) * 1_000_000_000))
            }
            onDone()
        }
    }
}
