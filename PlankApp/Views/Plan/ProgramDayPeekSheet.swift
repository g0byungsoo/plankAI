import SwiftUI

// MARK: - ProgramDayPeekSheet (Home Phase 2, 2026-06-19)
//
// Synthesized from the 4-expert panel — Panel 4 GLP-1 RD's lock:
//   "On tap, a single warm sentence: 'day 14 is a movement day —
//    we'll meet you there ♡'. No row list. No prescribed minutes.
//    No lesson title."
//
// The pitfall this defangs: a locked future checklist becomes
// visualized debt for the perfectionism cohort (Sherry & Hall 2009;
// Stoeber & Childs 2010). Lesson titles specifically would spoil the
// body-image / identity arc lessons that need to land when they land.
//
// Visual register: cream cocoa palette, JeniHeroSerif Display +
// italic-Fraunces punch on the archetype keyword. Hairline rule
// above the close button. Single CTA: "got it." Tap dismisses;
// nothing else navigates.

struct ProgramDayPeekSheet: View {

    let day: Int
    let archetype: ProgramDayArchetype?
    let onDismiss: () -> Void

    /// Maps the archetype to the body sentence the cohort lands on.
    /// Each is one line, italic-Fraunces punch on the archetype word,
    /// hearts terminal-only on the warm ones (protein + rest);
    /// movement gets no heart (it's an action register), balanced
    /// gets the casual "we'll meet you there".
    private var bodySentence: (prefix: String, italic: String, suffix: String) {
        guard let archetype else {
            return ("we'll meet you ", "there", " \u{2661}")
        }
        switch archetype {
        case .protein:
            return ("a ", "protein", " day. lean into satiety \u{2661}")
        case .movement:
            return ("a ", "movement", " day. we'll meet you there.")
        case .balanced:
            return ("a ", "balanced", " day. keep your rhythm.")
        case .rest:
            return ("a ", "gentle", " day. your plan accounts for it \u{2661}")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Tiny day eyebrow
            (Text("day ")
                .font(.custom("DMSans-Regular", size: 13))
            + Text("\(day)")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                .foregroundColor(Palette.cocoaSecondary))
                .foregroundStyle(Palette.cocoaTertiary)
                .kerning(0.4)

            // Hero sentence — italic-Fraunces punch on the archetype word
            let s = bodySentence
            (Text(s.prefix)
                .font(.custom("JeniHeroSerif-Regular", size: 30, relativeTo: .title2))
            + Text(s.italic)
                .font(.custom("JeniHeroSerif-Italic", size: 32, relativeTo: .title2))
            + Text(s.suffix)
                .font(.custom("JeniHeroSerif-Regular", size: 30, relativeTo: .title2)))
                .foregroundStyle(Palette.cocoaPrimary)
                .kerning(-0.3)
                .lineSpacing(-2)
                .fixedSize(horizontal: false, vertical: true)

            // Footnote — light meta the cohort can carry forward
            Text(footnoteCopy)
                .font(.custom("DMSans-Regular", size: 13))
                .foregroundStyle(Palette.cocoaTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            // Hairline rule
            Rectangle()
                .fill(Palette.cocoaPrimary.opacity(0.10))
                .frame(height: 0.75)

            // CTA — single button, gentle voice
            HStack {
                Spacer()
                Button {
                    Haptics.light()
                    onDismiss()
                } label: {
                    (Text("got ")
                        .font(.custom("DMSans-SemiBold", size: 14))
                    + Text("it")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 15)))
                        .foregroundStyle(Palette.textInverse)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Palette.cocoaPrimary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.programCard.ignoresSafeArea())
    }

    private var footnoteCopy: String {
        guard let archetype else {
            return "we'll be here when you arrive."
        }
        switch archetype {
        case .protein:
            return "we'll center your plate when you get there."
        case .movement:
            return "your movement is queued. nothing to rush."
        case .balanced:
            return "your usual rhythm. nothing to rush."
        case .rest:
            return "soft on yourself ahead of time. nothing's required."
        }
    }
}
