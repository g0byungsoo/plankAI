import SwiftUI
import SwiftData
import PlankSync

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
                    Text("your week, read")
                        .font(Typo.captionTracked)
                        .kerning(2.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.cocoaTertiary)
                        .fixedSize()
                    Rectangle()
                        .fill(Palette.hairlineCocoa)
                        .frame(height: 0.5)
                        .frame(minWidth: 12)
                    Text(datelineFragment)
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

                // v25 E1 — WHAT HAPPENED: her week against her own
                // usual (no signal without data; the composer's
                // floors already spoke).
                if !due.model.signals.isEmpty {
                    readSignals
                        .padding(.top, Space.lg)
                        .opacity(tailSettled ? 1 : 0)
                }

                // WHAT MATTERS: ≤2 quiet observations + one teaching
                // line, provenance-backed.
                if !due.model.observations.isEmpty || due.model.teaching != nil {
                    readObservations
                        .padding(.top, Space.lg)
                        .opacity(tailSettled ? 1 : 0)
                        .offset(y: tailSettled ? 0 : 6)
                }

                // WHAT TO TRY NEXT: the one offer.
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
            Analytics.track(.weeklyReadShown, properties: [
                "anchor": due.resolution.kind.rawValue,
                "offer": due.model.offer.key,
                "signals": due.model.signals.count,
            ])
            #if DEBUG
            // Film door: the read self-drives to consent so the
            // whole loop can be recorded (walker-armed doors can't
            // film — the T1 lesson).
            if ProcessInfo.processInfo.arguments.contains("--uitest-walk-read") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                    sign(decision: "kept")
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.6) {
                    onClose()
                }
            }
            #endif
            if reduceMotion { tailSettled = true; return }
            let delay = 0.4 + Double(cascadeLines.count) * 0.5
            withAnimation(Motion.entranceSoft.delay(delay)) { tailSettled = true }
        }
        .accessibilityElement(children: .contain)
    }

    private var cascadeLines: [LineCascadeText.Line] {
        let title: LineCascadeText.Line
        switch due.resolution.kind {
        case .enrollment:
            title = .composite(base: "\(due.weekName), reviewed.", italic: [due.weekName])
        case .doseDay:
            title = .composite(base: "your dose week, read.", italic: ["dose week"])
        case .preference:
            title = .composite(base: "your week, read.", italic: ["read"])
        }
        return [
            title,
            .composite(base: due.model.heroLine, italic: due.model.heroItalics),
        ]
    }

    private var datelineFragment: String {
        switch due.resolution.kind {
        case .enrollment: return "week \(due.weekIndex)"
        case .doseDay: return "after the dose"
        case .preference: return "your morning"
        }
    }

    // MARK: - v25 E1 — the signals band (her week vs her own usual)

    private var readSignals: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(due.model.signals.enumerated()), id: \.element.key) { index, signal in
                if index > 0 {
                    Rectangle()
                        .fill(Palette.hairlineCocoa)
                        .frame(width: 0.5)
                        .padding(.vertical, 4)
                        .padding(.horizontal, Space.md)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(signal.thisWeek)
                        .font(.custom("JeniHeroSerif-Regular", size: 22, relativeTo: .title2))
                        .foregroundStyle(Palette.textPrimary)
                    Text(signal.label)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let versus = signal.versus {
                        Text(versus)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.cocoaTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var readObservations: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(due.model.observations, id: \.text) { line in
                ItalicAccentText(
                    line.text,
                    italic: line.italics,
                    baseFont: Typo.caption,
                    italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 13, relativeTo: .footnote),
                    color: Palette.textSecondary,
                    alignment: .leading
                )
                .fixedSize(horizontal: false, vertical: true)
            }
            if let teaching = due.model.teaching {
                ItalicAccentText(
                    teaching,
                    italic: [],
                    baseFont: .custom("JeniHeroSerif-Italic", size: 15, relativeTo: .subheadline),
                    italicFont: .custom("JeniHeroSerif-Italic", size: 15, relativeTo: .subheadline),
                    color: Palette.cocoaSecondary,
                    alignment: .leading
                )
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
            }
        }
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
                    Circle()
                        .fill(Palette.accent)
                        .frame(width: 6, height: 6)
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
                    due.model.offer.title,
                    italic: [],
                    baseFont: .custom("JeniHeroSerif-Regular", size: 21, relativeTo: .title3),
                    italicFont: .custom("JeniHeroSerif-Italic", size: 21, relativeTo: .title3),
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                Text(due.model.offer.reason)
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
                Text("done")
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
                    Text(due.model.offer.acceptLabel)
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

    @Environment(\.modelContext) private var modelContext

    private func sign(decision: String) {
        let offer = due.model.offer
        let stamp: String
        var writtenFactId: String? = nil

        if decision == "declined" {
            stamp = "kept as is"
        } else if case .v4(.intentPick) = offer {
            // The week intent stays the v4 week-scoped knob (a pick,
            // not program memory).
            stamp = WeeklyReview.apply(
                due.proposal,
                forWeek: due.weekIndex,
                chosenIntentKey: chosenIntentKey
            )
        } else {
            // v25 E1 — consent lands in PROGRAM MEMORY through the
            // one writer; the legacy knobs mirror via write-through.
            writtenFactId = WeeklyReadOffers.applyAccepted(
                offer, userId: userId, in: modelContext
            )?.id
            stamp = offer.stampLine
        }

        // The canonical record (deterministic per window; devices
        // converge) + the v4 JSONL for the journey ledger's stamps.
        WeeklyReadStore.recordDecision(
            windowStartDay: due.resolution.windowStartDay,
            anchor: due.resolution.kind,
            shown: shownSummary,
            offer: offer,
            decision: decision == "declined" ? "declined" : "accepted",
            factId: writtenFactId,
            userId: userId,
            in: modelContext
        )
        WeeklyReview.record(ReviewRecord(
            id: UUID().uuidString,
            userId: userId,
            weekIndex: due.weekIndex,
            decidedAtISO: ISO8601DateFormatter().string(from: .now),
            proposalKey: offer.key,
            decision: decision,
            stampLine: stamp,
            reasonLine: offer.reason,
            weekName: due.weekName
        ))
        // The knock never nags a signed week (4-site id protocol).
        NotificationOrchestrator.cancelReSigningKnock()
        Analytics.track(.weeklyReadDecision, properties: [
            "anchor": due.resolution.kind.rawValue,
            "offer": offer.key,
            "decision": decision == "declined" ? "declined" : "accepted",
            "fact_written": writtenFactId != nil,
        ])
        withAnimation(Motion.entranceSoft) { signedStamp = stamp }
        onSigned(stamp)
        // Declines exit quietly; keeps let her read the signature.
        if decision == "declined" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onClose() }
        }
    }

    /// Compact categorical summary for the record (hygiene law:
    /// keys, never values).
    private var shownSummary: String {
        let sig = due.model.signals.map(\.key).joined(separator: ",")
        return "sig:\(sig)|obs:\(due.model.observations.count)|teach:\(due.model.teaching != nil ? 1 : 0)"
    }
}

// MARK: - JKStandingDots (rehomed from JourneyAtoms with the v11 T4
// journal deletion — the re-signing is its only consumer now)


struct JKStandingDots: View {
    struct Day: Identifiable {
        let id: Int              // programDay
        let standing: DayStanding
        let isToday: Bool
        let isFuture: Bool
        let isPaused: Bool
    }

    let days: [Day]
    var spacing: CGFloat = 7

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(days) { day in
                dot(day)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11y)
    }

    @ViewBuilder
    private func dot(_ day: Day) -> some View {
        if day.isPaused {
            // A held place, not a hole.
            JKMark(kind: .moon, size: 7, color: Palette.cocoaTertiary)
                .frame(width: 9, height: 9)
        } else if day.isFuture {
            Circle()
                .strokeBorder(
                    Palette.hairlineCocoa,
                    style: StrokeStyle(lineWidth: 1, dash: [1.6, 2.2])
                )
                .frame(width: 8, height: 8)
        } else {
            switch day.standing {
            case .kept:
                Circle()
                    .fill(day.isToday ? Palette.cocoaPrimary : Palette.cocoaSecondary)
                    .frame(width: day.isToday ? 9 : 8, height: day.isToday ? 9 : 8)
            case .partial:
                Circle()
                    .fill(Palette.cocoaSecondary.opacity(0.55))
                    .frame(width: 7, height: 7)
            case .quiet:
                // Less ink, never an absence mark.
                Circle()
                    .fill(day.isToday ? Palette.cocoaSecondary.opacity(0.6)
                                      : Palette.cocoaTertiary.opacity(0.35))
                    .frame(width: day.isToday ? 6.5 : 4, height: day.isToday ? 6.5 : 4)
            }
        }
    }

    private var a11y: String {
        let kept = days.filter { !$0.isFuture && !$0.isPaused && $0.standing == .kept }.count
        return kept == 1 ? "one day kept this week" : "\(kept) days kept this week"
    }
}

