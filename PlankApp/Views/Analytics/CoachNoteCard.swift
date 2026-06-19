import SwiftUI

// MARK: - CoachNoteCard
//
// SHELVED 2026-06-10 — see CoachNoteService.swift header. Card
// unwired from AnalyticsView; file dormant for v1.0.8+ revival.
//
// v3 P11.5 (2026-06-10) — weekly note from jeni, rendered on the
// Becoming tab. Reads `CoachNoteService.shared.latest`; falls
// through to a soft empty state when no note exists yet.
//
// Voice contract enforced at the renderer:
//  - Body is rendered via ItalicAccentText, splitting on guillemets
//    (« »). Per [[feedback-no-italic-markdown-markers]] the literal
//    asterisk syntax is banned; guillemets are the safe stand-in
//    chosen for this surface.
//  - Mood drives a single tint accent (sage / cocoa / accent) — no
//    big chrome swap, just the small "from jeni" pill color.
//  - Suggestion line gets a heart-locket sticker glyph at the head
//    so the suggestion reads as personal, not a CTA.

struct CoachNoteCard: View {
    let note: CoachNote
    var onRegenerate: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            header

            bodyText

            suggestionLine

            if let onRegenerate {
                regenerateLink(onRegenerate)
            }
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Palette.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Palette.accent.opacity(0.45), lineWidth: 1.5)
                )
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(moodTint)
                .frame(width: 8, height: 8)
            Text("a note from jeni")
                .font(.system(size: 11, weight: .medium))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Palette.textSecondary)
            Spacer(minLength: 0)
            Text(weekLabel)
                .font(.system(size: 11))
                .foregroundStyle(Palette.textSecondary)
        }
    }

    /// Body text — splits on guillemets so the italic punch lands
    /// without violating the no-asterisk-markers rule. The split is
    /// done greedily; if the model emits unbalanced guillemets the
    /// fallback is rendering as plain text (still readable, just
    /// missing the italic emphasis).
    private var bodyText: some View {
        // Extract the italic substrings between «...»
        let (cleaned, italics) = stripGuillemets(note.body)
        return ItalicAccentText(
            cleaned,
            italic: italics,
            baseFont: .custom("Fraunces72pt-Regular", size: 17),
            italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 17),
            color: Palette.textPrimary,
            alignment: .leading
        )
        .lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var suggestionLine: some View {
        let (cleanedSuggestion, suggestionItalics) = stripGuillemets(note.suggestion)
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Palette.accent)
                .offset(y: 1)
            ItalicAccentText(
                cleanedSuggestion,
                italic: suggestionItalics,
                baseFont: .system(size: 14, weight: .medium),
                italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 14),
                color: Palette.textPrimary,
                alignment: .leading
            )
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private func regenerateLink(_ action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.light(); action() }) {
            Text("refresh")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .underline()
        }
        .buttonStyle(.plain)
    }

    private var weekLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "week of \(f.string(from: note.weekStartDate).lowercased())"
    }

    private var moodTint: Color {
        switch note.mood {
        case .grounded:     return Palette.stateGood
        case .neutral:      return Palette.accent
        case .celebratory:  return Palette.accent
        }
    }

    /// Parses `«…»` substrings out of the body. Returns the cleaned
    /// text (guillemets removed) and the array of italic substrings
    /// in the order they appeared. Unbalanced guillemets fall through
    /// safely — the cleaned text just loses the orphan markers.
    private func stripGuillemets(_ s: String) -> (cleaned: String, italics: [String]) {
        var cleaned = ""
        var italics: [String] = []
        var cursor = s.startIndex
        while cursor < s.endIndex {
            if let openRange = s.range(of: "«", range: cursor..<s.endIndex),
               let closeRange = s.range(of: "»", range: openRange.upperBound..<s.endIndex) {
                cleaned.append(contentsOf: s[cursor..<openRange.lowerBound])
                let italic = String(s[openRange.upperBound..<closeRange.lowerBound])
                italics.append(italic)
                cleaned.append(italic)
                cursor = closeRange.upperBound
            } else {
                cleaned.append(contentsOf: s[cursor..<s.endIndex])
                cursor = s.endIndex
            }
        }
        return (cleaned, italics)
    }
}

// MARK: - CoachNoteEmptyCard
//
// Shown when CoachNoteService.shared.latest is nil. Sets expectation
// ("your first note lands monday morning") + drives engagement by
// making the absence feel intentional, not broken.

struct CoachNoteEmptyCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Palette.accent.opacity(0.4))
                    .frame(width: 8, height: 8)
                Text("a note from jeni")
                    .font(.system(size: 11, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Palette.textSecondary)
            }
            ItalicAccentText(
                "your first weekly note lands after one full week.",
                italic: ["first", "week"],
                baseFont: .custom("Fraunces72pt-Regular", size: 17),
                italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 17),
                color: Palette.textPrimary,
                alignment: .leading
            )
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Palette.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Palette.divider, lineWidth: 1)
                )
        )
    }
}

#Preview("filled") {
    CoachNoteCard(
        note: CoachNote(
            weekStartDate: Date(),
            body: "jen, this week you showed up «three times». that's the rhythm we were aiming for. the «consistency» matters more than any single session.\n\nkeep the same windows next week; we don't need to add anything yet.",
            suggestion: "before adding intensity, hold this rhythm for one more «week» ♥",
            mood: .celebratory
        )
    )
    .padding()
    .background(Palette.bgPrimary)
}

#Preview("empty") {
    CoachNoteEmptyCard()
        .padding()
        .background(Palette.bgPrimary)
}
