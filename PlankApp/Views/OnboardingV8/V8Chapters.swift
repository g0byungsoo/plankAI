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
    /// One chapter, one advance — a double-fire can never walk the
    /// flow two beats (loop-1 ghost-advance defense).
    @State private var advanced = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func fireContinue() {
        guard !advanced else { return }
        advanced = true
        onContinue()
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            V8Blooms()

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)

                if kind == .arrival {
                    JeniMark(height: 96, color: Palette.textInverse)
                        .opacity(markShown ? 1 : 0)
                        .scaleEffect(markShown ? 1 : 1.035, anchor: .center)
                        .mask(
                            // The mark writes itself: a soft-edged wipe
                            // travelling the stroke's direction.
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
                        .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.9), value: markShown)
                        .padding(.bottom, Space.xl)
                        .accessibilityLabel("jeni")
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
                        startDelay: kind == .arrival ? 1.5 : 0.35,
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
                revealCTA()
            }
        }
        .task {
            if kind == .arrival {
                try? await Task.sleep(nanoseconds: 300_000_000)
                markShown = true
                if !reduceMotion { JeniHaptic.land() }
            }
        }
        .environment(\.v8OnInk, true)
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
