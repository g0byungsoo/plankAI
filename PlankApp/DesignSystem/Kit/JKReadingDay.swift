import SwiftUI
import Auth
import PlankFood
import PlankSync

// MARK: - JKReadingDay (app v3, docs/app_v3/02_DESIGN_LANGUAGE.md)
//
// The reading-first day's components: THE READING (jeni's morning
// note — the screen's hero), THE ONE THING (the single ask, the
// screen's only filled container), THE RHYTHM (hairline rows — the
// day's shape, present but never debt), and the BREAK card.
//
// Register: serif editorial + receipt grammar from onboarding v5.
// No at-rest circles, no locks, no counts. Completion stays her75:
// the strike IS the satisfaction.

// MARK: - JeniNoteView

/// THE NOTE — jeni's full reading as a RECEIVED moment (the minimal
/// correction, 06_MINIMAL_CORRECTION.md). Home carries only her
/// line; tapping it opens this full-screen letter: the dateline, the
/// sentences cascading in line by line with a soft haptic each (the
/// her75 reveal — the app's one cinematic gesture), the mechanism as
/// a caption, her signature, REPLY into the chat, and a quiet keep.
struct JeniNoteView: View {
    let brief: DailyBriefEngine.Brief
    /// Lowercase weekday for the dateline ("sunday").
    var dateline: String = ""
    let onReply: () -> Void
    let onClose: () -> Void

    @State private var tailSettled = false
    /// p63 — §5.7, impatience is a valid input: a tap lands the whole
    /// letter at once. The default rhythm is untouched (p62 kept it
    /// as design); the tap is the reader's own hand on the page.
    @State private var skipped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var sealed = false

    var body: some View {
        JKScreenChrome {
            // Pass 52 — the letter had NO scroll container, the exact
            // defect class `48` closed on the consult: at accessibility
            // sizes the column overflowed and SwiftUI compressed the
            // serif hero into tail-truncation ("your first d…" — filmed
            // on the SE at AX5, the first-day letter unreadable). The
            // min-height frame keeps the optical-center composition
            // byte-identical whenever the content fits; the scroll
            // exists only when it does not.
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Mission 2 (02_VISUAL.md §2): the block floats at
                // optical center — the emptiness reads composed, not
                // leftover.
                Spacer(minLength: Space.hero)

                // Dateline. The two words never wrap mid-word (AX5
                // rendered "tuesd/ay"); the hairline absorbs the loss.
                HStack(spacing: 10) {
                    Text("jeni")
                        .font(Typo.captionTracked)
                        .kerning(2.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.cocoaTertiary)
                        .fixedSize()
                    Rectangle()
                        .fill(Palette.hairlineCocoa)
                        .frame(height: 0.5)
                        .frame(minWidth: 12)
                    if !dateline.isEmpty {
                        Text(dateline)
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 11, relativeTo: .caption2))
                            .foregroundStyle(Palette.cocoaTertiary)
                            .fixedSize()
                    }
                }

                // The letter — line by line, a breath apart.
                LineCascadeText(
                    lines: cascadeLines,
                    baseFont: .custom("JeniHeroSerif-Regular", size: 28, relativeTo: .title),
                    italicFont: .custom("JeniHeroSerif-Italic", size: 28, relativeTo: .title),
                    color: Palette.textPrimary,
                    completed: skipped
                )
                .padding(.top, Space.xl)

                if let mechanism = brief.mechanism {
                    Text(mechanism)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.lg)
                        .opacity(tailSettled ? 1 : 0)
                        .offset(y: tailSettled ? 0 : 6)
                }

                // v25 E4 — yesterday's receipt: the quiet ledger line
                // that proves the file is being kept. Only when
                // yesterday left a record (absence renders nothing).
                if let receipt = brief.receipt, !receipt.ledgerLine.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Rectangle()
                            .fill(Palette.hairlineCocoa)
                            .frame(width: 44, height: 0.5)
                        HStack(spacing: 8) {
                            Text("yesterday")
                                .font(Typo.captionTracked)
                                .kerning(1.8)
                                .textCase(.uppercase)
                                .foregroundStyle(Palette.cocoaTertiary)
                            Text(receipt.ledgerLine)
                                .font(Typo.caption.monospacedDigit())
                                .foregroundStyle(Palette.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.top, Space.lg)
                    .opacity(tailSettled ? 1 : 0)
                    .offset(y: tailSettled ? 0 : 6)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("yesterday: \(receipt.ledgerLine)")
                }

                HStack {
                    Spacer()
                    Text("— jeni")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16, relativeTo: .footnote))
                        .foregroundStyle(Palette.cocoaSecondary)
                }
                .padding(.top, Space.lg)
                .opacity(tailSettled ? 1 : 0)

                Spacer(minLength: 0)

                // The doors: reply leads, keep excuses quietly.
                VStack(spacing: Space.md) {
                    Button {
                        Haptics.soft()
                        onReply()
                    } label: {
                        Text("reply")
                            .font(.custom("DMSans-SemiBold", size: 16, relativeTo: .body))
                            .foregroundStyle(Palette.textInverse)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(Palette.cocoaPrimary))
                    }
                    .buttonStyle(JKPress())

                    // Mission 2: keeping the letter is the SEAL —
                    // jeni's mark fills at her touch, the her-file
                    // commit haptic lands, the page files itself.
                    Button {
                        guard !sealed else { return }
                        sealed = true
                        ActivationHaptics.shared.commit()
                        DispatchQueue.main.asyncAfter(deadline: .now() + JeniMotion.commitDwell) {
                            onClose()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 12, weight: sealed ? .medium : .light))
                                .symbolVariant(sealed ? .fill : .none)
                                .foregroundStyle(
                                    sealed ? Palette.jeweledRose : Palette.cocoaSecondary
                                )
                                .scaleEffect(sealed ? 1.2 : 1)
                                .animation(Motion.bloom, value: sealed)
                            Text("keep it")
                                .font(.custom("DMSans-Medium", size: 14, relativeTo: .footnote))
                                .foregroundStyle(Palette.cocoaSecondary)
                        }
                        .padding(.vertical, 6)
                        // p63 — a 26pt-tall filing action; the target
                        // meets the HIG floor, the chrome stays quiet.
                        .tappableArea()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, Space.lg)
                .opacity(tailSettled ? 1 : 0)
                .offset(y: tailSettled ? 0 : 8)
                // p63 — a door that has not arrived is not a door:
                // both exits were tappable at opacity 0 all through
                // the cascade.
                .allowsHitTesting(tailSettled)
            }
            .padding(.horizontal, Space.lg)
            .frame(minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .onAppear {
            if reduceMotion { tailSettled = true; return }
            // The tail (mechanism + signature + doors) follows the
            // cascade: ~0.5s per line + a settling breath. The VALUE
            // flips at the beat, not before it — p63: a delayed
            // `withAnimation` changes the state instantly and only
            // delays the paint, which is exactly how the doors ended
            // up tappable at opacity 0 for the whole cascade.
            let delay = 0.4 + Double(cascadeLines.count) * 0.5
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard !tailSettled else { return }
                withAnimation(Motion.entranceSoft) { tailSettled = true }
            }
        }
        .simultaneousGesture(TapGesture().onEnded {
            guard !tailSettled else { return }
            Analytics.track(.arrivalSkipped, properties: ["surface": "letter"])
            skipped = true
            withAnimation(Motion.entranceSoft) { tailSettled = true }
        })
        .accessibilityElement(children: .contain)
        .accessibilityLabel("a note from jeni. \([brief.line, brief.second, brief.mechanism].compactMap { $0 }.joined(separator: " "))")
    }

    private var cascadeLines: [LineCascadeText.Line] {
        var lines: [LineCascadeText.Line] = [
            .composite(base: brief.line, italic: brief.italic)
        ]
        if let second = brief.second {
            lines.append(.composite(base: second, italic: brief.secondItalic))
        }
        return lines
    }
}

// v7: JKDayRail deleted — the position line on Today carries
// the week's place in one legible line (docs/app_v7 §1).

// p63 — JKTapWithLongPress deleted: its last live site (the
// dateline's hidden hold-for-settings) became a plain Button when the
// hold died. JeniTaskRow and JKBeatRow carry their own copies of the
// tap-swallow latch, documented in place.

// MARK: - Spoken-label hygiene (v7)

extension String {
    /// Strips the brand's terminal hearts (and trailing space) from
    /// text bound for VoiceOver — "♥" reads as "black heart suit" at
    /// the end of most sentences otherwise, degrading jeni's voice
    /// for exactly the users who only ever hear her.
    var a11yStripped: String {
        self
            .replacingOccurrences(of: "\u{2665}\u{FE0E}", with: "")
            .replacingOccurrences(of: "\u{2665}", with: "")
            .replacingOccurrences(of: "\u{2661}", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - JKBreakCard

/// The "on a break" state — permission, not absence. One gentle
/// return door; ending the break is warm, never a catch-up.
struct JKBreakCard: View {
    let onReturn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ItalicAccentText(
                "on a break.",
                italic: ["break"],
                baseFont: .custom("JeniHeroSerif-Regular", size: 24, relativeTo: .title3),
                italicFont: .custom("JeniHeroSerif-Italic", size: 24, relativeTo: .title3),
                color: Palette.textPrimary,
                alignment: .leading
            )
            Text("the rhythm and the reminders are asleep. coming back is one tap.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Haptics.soft()
                onReturn()
            } label: {
                Text("i'm back")
                    .font(.custom("DMSans-SemiBold", size: 14, relativeTo: .footnote))
                    .foregroundStyle(Palette.cocoaPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .overlay(
                        Capsule().strokeBorder(Palette.cocoaPrimary.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(JKPress())
            .padding(.top, 4)
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(Palette.hairlineCocoa, lineWidth: 0.66)
        )
    }
}

// MARK: - JKFlowLayout
//
// A wrapping row layout: lays children left-to-right and wraps to a new
// line the moment the next child would overflow the proposed width. Each
// child keeps its ideal size, so chips hug their labels and never
// truncate (the fix for the breathwork occasion chips that got squeezed
// into one HStack). iOS 16+. Left-aligned; equal spacing horizontally
// and between lines.
struct JKFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                y += rowHeight + lineSpacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        let total = y + rowHeight
        return CGSize(width: min(maxWidth, widest), height: total)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let maxX = bounds.maxX
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > maxX {
                y += rowHeight + lineSpacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

