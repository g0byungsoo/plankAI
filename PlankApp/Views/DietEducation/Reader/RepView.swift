import SwiftUI

// MARK: - RepView (app v3 phase 3)
//
// The method's daily practice moment: one scenario, two or three
// doors, a warm mechanism line behind whichever she chooses (no
// wrong answers), a kept chip, and the reader one tap deeper. The
// whole interaction is 20-40 seconds — practice, never homework.
//
// Register: OV5 option grammar (tall pill doors), serif scenario,
// receipt-quiet close. The chosen door holds; the others step back.

struct RepView: View {
    let rep: MethodRep
    /// nil on the (edge) days with no resolvable lesson — the rep
    /// still runs; the reader bridge simply doesn't render.
    var resolution: MethodResolver.Resolution? = nil
    /// Fires ONCE when she completes the rep (chooses a door) — host
    /// marks the lesson beat.
    let onKept: () -> Void
    let onClose: () -> Void

    @State private var chosen: Int? = nil
    @State private var showResponse = false
    @State private var showClose = false
    @State private var showReader = false
    @State private var keptFired = false
    @State private var router = AppRouter.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if showReader, let resolution {
            LessonReaderView(
                scheduled: resolution.ref.scheduled,
                slot: resolution.ref.slot,
                variant: resolution.ref.variant,
                onComplete: { onClose() },
                onSkip: { _ in onClose() }
            )
        } else {
            repBody
        }
    }

    private var repBody: some View {
        JKScreenChrome {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(resolution.map { "the method · day \($0.ordinal)" } ?? "the method")
                            .font(Typo.captionTracked)
                            .kerning(1.6)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.cocoaTertiary)
                        Spacer()
                        JKQuietMark(systemName: "xmark", accessibilityLabel: "close") {
                            onClose()
                        }
                    }
                    .padding(.top, Space.hero)
                    .jkBeat1()

                    ItalicAccentText(
                        rep.scenario,
                        italic: rep.scenarioItalic,
                        baseFont: .custom("JeniHeroSerif-Regular", size: 30, relativeTo: .title),
                        italicFont: .custom("JeniHeroSerif-Italic", size: 30, relativeTo: .title),
                        color: Palette.textPrimary,
                        alignment: .leading
                    )
                    .lineSpacing(-2)
                    .kerning(-0.3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.xl)
                    .jkBeat2()

                    Text("what's the move?")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.top, Space.md)
                        .jkBeat2(extraDelay: 0.06)

                    VStack(spacing: Space.optionGap) {
                        ForEach(Array(rep.doors.enumerated()), id: \.offset) { idx, door in
                            doorView(idx: idx, door: door)
                                .jkBeat2(extraDelay: 0.1 + Double(idx) * Motion.revealStagger)
                        }
                    }
                    .padding(.top, Space.lg)

                    if showClose {
                        closeBlock
                            .padding(.top, Space.section)
                            .transition(.opacity.combined(with: .offset(y: 8)))
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, Space.lg)
            }
        }
    }

    // MARK: - Doors

    @ViewBuilder
    private func doorView(idx: Int, door: MethodRep.Door) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                choose(idx)
            } label: {
                HStack(spacing: 10) {
                    // The chosen door earns its mark — a drawn check
                    // settling in ahead of the label.
                    if chosen == idx {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.cocoaPrimary)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                    Text(door.label)
                        .font(.custom("DMSans-Medium", size: 16, relativeTo: .body))
                        .foregroundStyle(Palette.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Space.md)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .fill(chosen == idx
                              ? Palette.accentSubtle.opacity(0.35)
                              : Palette.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(
                            chosen == idx ? Palette.cocoaPrimary : Palette.hairlineCocoa,
                            lineWidth: chosen == idx ? 1.2 : 0.66
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            }
            .buttonStyle(JKPress())
            .disabled(chosen != nil)
            .opacity(chosen == nil || chosen == idx ? 1 : 0.38)
            .offset(y: chosen != nil && chosen != idx ? 3 : 0)
            .scaleEffect(chosen != nil && chosen != idx ? 0.99 : 1, anchor: .top)

            if chosen == idx, showResponse {
                VStack(alignment: .leading, spacing: 10) {
                    Text(door.response)
                        .font(Typo.body)
                        .foregroundStyle(Palette.textPrimary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if let route = door.route {
                        JKChainLine(
                            lead: "next:",
                            suggestion: routeWord(route),
                            italic: [],
                            action: {
                                onClose()
                                router.open(route)
                            }
                        )
                    } else if let seed = door.chatSeed {
                        JKChainLine(
                            lead: "next:",
                            suggestion: "talk it through with jeni",
                            italic: ["jeni"],
                            action: {
                                onClose()
                                router.openChat(seed: seed)
                            }
                        )
                    }
                }
                .padding(.horizontal, Space.md)
                .padding(.top, 12)
                .transition(.opacity.combined(with: .offset(y: 6)))
            }
        }
        .animation(reduceMotion ? nil : Motion.entranceSoft, value: chosen)
        .animation(reduceMotion ? nil : Motion.entranceSoft, value: showResponse)
    }

    private func choose(_ idx: Int) {
        guard chosen == nil else { return }
        // Two-stage: the decision lands (medium), the mark settles
        // (tick) — one gesture, one voice.
        Haptics.medium()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { Haptics.tick() }
        chosen = idx
        if !keptFired {
            keptFired = true
            onKept()
        }
        if reduceMotion {
            showResponse = true
            showClose = true
            return
        }
        withAnimation(Motion.entranceSoft.delay(0.15)) { showResponse = true }
        withAnimation(Motion.entranceSoft.delay(0.9)) { showClose = true }
    }

    // MARK: - Close block

    private var closeBlock: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                Text("kept. it's on today")
                    .font(Typo.caption)
            }
            .foregroundStyle(Palette.textInverse)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Palette.cocoaPrimary))

            if resolution != nil {
                Rectangle()
                    .fill(Palette.hairlineCocoa)
                    .frame(height: 0.5)

                Button {
                    Haptics.light()
                    showReader = true
                } label: {
                    HStack(spacing: 6) {
                        Text("the whole idea")
                            .font(.custom("JeniHeroSerif-Italic", size: 17, relativeTo: .body))
                            .foregroundStyle(Palette.textPrimary)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Palette.cocoaSecondary)
                        Spacer()
                        Text("2 min")
                            .font(Typo.captionTracked)
                            .kerning(1.2)
                            .foregroundStyle(Palette.cocoaTertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(JKPress())
            }

            Button {
                Haptics.light()
                onClose()
            } label: {
                Text("done for today")
                    .font(.custom("DMSans-SemiBold", size: 14, relativeTo: .footnote))
                    .foregroundStyle(Palette.cocoaPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .overlay(
                        Capsule().strokeBorder(Palette.cocoaPrimary.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(JKPress())
            .padding(.top, 2)
        }
    }

    private func routeWord(_ route: AppRouter.Route) -> String {
        switch route {
        case .breath: return "60 seconds of breath"
        case .snap: return "snap the next plate"
        case .trend: return "see your line"
        case .weighIn: return "weigh in"
        case .lesson: return "the whole idea"
        case .workout: return "today's session"
        case .steps: return "your steps"
        case .bodyScan: return "your check-in"
        }
    }
}
