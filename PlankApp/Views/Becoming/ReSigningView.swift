import SwiftUI

// MARK: - ReSigningView (app v4, docs/app_v4/01_PROGRAM.md §0)
//
// THE RE-SIGNING — the week read back, one proposal with its reason,
// and her consent. A received full-screen moment in the note
// register (cream field, line cascade, quiet doors): the app's
// weekly cinematic gesture, the moment the plan visibly learns or
// visibly holds. Declining is never punished; "not this week" is a
// recorded, respected answer.

struct ReSigningView: View {
    let due: JourneyModel.DueReview
    let userId: String
    /// Called after a decision lands (keep / adjust / decline) with
    /// the stamp line — the journey refreshes + stamps.
    let onSigned: (String) -> Void
    let onClose: () -> Void

    @State private var tailSettled = false
    @State private var signedStamp: String? = nil
    @State private var chosenIntentKey: String? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        JKScreenChrome {
            VStack(alignment: .leading, spacing: 0) {
                // Dateline — with a quiet exit (a received moment
                // never traps; the journey's due card re-offers).
                // fixedSize on the words: the hairline is the only
                // element allowed to compress (SE wrapped the label).
                HStack(spacing: 10) {
                    Text("your weekly review")
                        .font(Typo.captionTracked)
                        .kerning(2.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.cocoaTertiary)
                        .fixedSize()
                    Rectangle()
                        .fill(Palette.hairlineCocoa)
                        .frame(height: 0.5)
                        .frame(minWidth: 12)
                    Text("week \(due.weekIndex)")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 11, relativeTo: .caption2))
                        .foregroundStyle(Palette.cocoaTertiary)
                        .fixedSize()
                    JKQuietMark(systemName: "xmark", accessibilityLabel: "later") {
                        onClose()
                    }
                }
                .padding(.top, Space.hero + 24)

                // The week, read back — the cascade.
                LineCascadeText(
                    lines: cascadeLines,
                    baseFont: .custom("JeniHeroSerif-Regular", size: 26, relativeTo: .title),
                    italicFont: .custom("JeniHeroSerif-Italic", size: 26, relativeTo: .title),
                    color: Palette.textPrimary
                )
                .padding(.top, Space.xl)

                // The week's dots — the receipt beneath the words.
                JKStandingDots(
                    days: due.slice.days.map {
                        JKStandingDots.Day(
                            id: $0.programDay, standing: $0.standing,
                            isToday: false, isFuture: $0.isFuture,
                            isPaused: $0.isPaused
                        )
                    },
                    spacing: 9
                )
                .padding(.top, Space.lg)
                .opacity(tailSettled ? 1 : 0)

                // The proposal.
                proposalBlock
                    .padding(.top, Space.xl)
                    .opacity(tailSettled ? 1 : 0)
                    .offset(y: tailSettled ? 0 : 8)

                Spacer(minLength: 0)

                doors
                    .padding(.bottom, Space.lg)
                    .opacity(tailSettled ? 1 : 0)
                    .offset(y: tailSettled ? 0 : 8)
            }
            .padding(.horizontal, Space.lg)
        }
        .onAppear {
            if reduceMotion { tailSettled = true; return }
            let delay = 0.4 + Double(cascadeLines.count) * 0.5
            withAnimation(Motion.entranceSoft.delay(delay)) { tailSettled = true }
        }
        .accessibilityElement(children: .contain)
    }

    private var cascadeLines: [LineCascadeText.Line] {
        [
            .composite(base: "\(due.weekName), read back.", italic: [due.weekName]),
            .composite(base: due.story, italic: []),
        ]
    }

    // MARK: - The proposal

    @ViewBuilder private var proposalBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(signedStamp == nil ? "the proposal" : "signed")
                .font(Typo.captionTracked)
                .kerning(2.0)
                .textCase(.uppercase)
                .foregroundStyle(signedStamp == nil ? Palette.cocoaTertiary : Palette.accent)

            if let stamp = signedStamp {
                HStack(spacing: 8) {
                    ItalicAccentText(
                        stamp,
                        italic: [],
                        baseFont: .custom("JeniHeroSerif-Regular", size: 21, relativeTo: .title3),
                        italicFont: .custom("JeniHeroSerif-Italic", size: 21, relativeTo: .title3),
                        color: Palette.textPrimary,
                        alignment: .leading
                    )
                    Text("\u{2665}\u{FE0E}")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.accent)
                }
                .transition(.opacity)
            } else if case .intentPick(let options, let reason) = due.proposal {
                Text(reason)
                    .font(Typo.caption)
                    .lineSpacing(2)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 8) {
                    ForEach(options, id: \.key) { option in
                        intentOption(option)
                    }
                }
                .padding(.top, 2)
            } else {
                ItalicAccentText(
                    due.proposal.title,
                    italic: [],
                    baseFont: .custom("JeniHeroSerif-Regular", size: 21, relativeTo: .title3),
                    italicFont: .custom("JeniHeroSerif-Italic", size: 21, relativeTo: .title3),
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                Text(due.proposal.reason)
                    .font(Typo.caption)
                    .lineSpacing(2)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .animation(Motion.entranceSoft, value: signedStamp)
    }

    private func intentOption(_ option: WeekIntentSpec) -> some View {
        Button {
            Haptics.soft()
            chosenIntentKey = option.key
            sign(decision: "adjusted")
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(option.name)
                    .font(.custom("JeniHeroSerif-Regular", size: 17, relativeTo: .body))
                    .foregroundStyle(Palette.textPrimary)
                Text(option.line)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Palette.hairlineCocoa, lineWidth: 0.66)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(JKPress())
    }

    // MARK: - The doors

    @ViewBuilder private var doors: some View {
        if signedStamp != nil {
            Button {
                Haptics.light()
                onClose()
            } label: {
                Text("back to the story")
                    .font(.custom("DMSans-SemiBold", size: 16, relativeTo: .body))
                    .foregroundStyle(Palette.textInverse)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(Palette.cocoaPrimary))
            }
            .buttonStyle(JKPress())
        } else if case .intentPick = due.proposal {
            // The options above ARE the consent; one quiet exit.
            Button {
                Haptics.light()
                sign(decision: "declined")
            } label: {
                Text("i'll pick later")
                    .font(.custom("DMSans-Medium", size: 14, relativeTo: .footnote))
                    .foregroundStyle(Palette.cocoaSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        } else {
            VStack(spacing: Space.md) {
                Button {
                    // The consent thunk — a felt signature.
                    Haptics.soft()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        Haptics.medium()
                    }
                    sign(decision: "kept")
                } label: {
                    Text("keep it")
                        .font(.custom("DMSans-SemiBold", size: 16, relativeTo: .body))
                        .foregroundStyle(Palette.textInverse)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(Palette.cocoaPrimary))
                }
                .buttonStyle(JKPress())

                Button {
                    Haptics.light()
                    sign(decision: "declined")
                } label: {
                    Text("not this week")
                        .font(.custom("DMSans-Medium", size: 14, relativeTo: .footnote))
                        .foregroundStyle(Palette.cocoaSecondary)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Signing

    private func sign(decision: String) {
        let stamp: String
        if decision == "declined" {
            stamp = "the plan holds. your call \u{2665}\u{FE0E}"
        } else {
            stamp = WeeklyReview.apply(
                due.proposal,
                forWeek: due.weekIndex,
                chosenIntentKey: chosenIntentKey
            )
        }
        WeeklyReview.record(ReviewRecord(
            id: UUID().uuidString,
            userId: userId,
            weekIndex: due.weekIndex,
            decidedAtISO: ISO8601DateFormatter().string(from: .now),
            proposalKey: due.proposal.key,
            decision: decision,
            stampLine: stamp,
            reasonLine: due.proposal.reason,
            weekName: due.weekName
        ))
        // The knock never nags a signed week (4-site id protocol).
        NotificationOrchestrator.cancelReSigningKnock()
        Analytics.track(.weeklyReviewSigned, properties: [
            "week": due.weekIndex,
            "proposal": due.proposal.key,
            "decision": decision,
        ])
        withAnimation(Motion.entranceSoft) { signedStamp = stamp }
        onSigned(stamp)
        // Declines exit quietly; keeps let her read the signature.
        if decision == "declined" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onClose() }
        }
    }
}
