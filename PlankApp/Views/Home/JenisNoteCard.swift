import SwiftUI

// MARK: - JenisNoteCard
//
// The daily "from jeni" card on HomeView. Renders a single templated
// note built from user signals (session history, name, identity feeling).
// Hides itself when JenisNoteTemplate returns nil.
//
// Per docs/product_direction_2026.md §8.3 — this is the daily-return
// hook (Noom's #1 retention engine, framed as coach voice not AI voice).
// Phase A.0 ships with templated copy; Phase D swaps templating for
// LLM-generated under the hood with identical surface.
//
// Fires `jenis_note_viewed` once per calendar day (deduped via a
// UserDefaults key) so the funnel reads "did the user see today's
// note" rather than "how many times did the view re-render."
//
// Voice rules per §4 enforced by the template; this view only renders.

struct JenisNoteCard: View {
    /// The composed note for today. Nil = card hides.
    let note: JenisNote?

    /// Optional tap handler. For Phase A.0 this is a no-op (the note is
    /// passive ambient text). Future iteration could open a "from jeni"
    /// archive or trigger a voice memo replay.
    var onTap: (() -> Void)? = nil

    var body: some View {
        if let note = note {
            content(for: note)
                .onAppear { trackOncePerDay() }
        }
    }

    @ViewBuilder
    private func content(for note: JenisNote) -> some View {
        let card = HStack(alignment: .top, spacing: Space.md) {
            // Small jeni accent — a sticker dot, not a portrait. Keeps
            // the card compact and lets the workout card stay the visual
            // hero. The portrait moment lives in CoachIntroView; this is
            // the daily lower-key continuation.
            Circle()
                .fill(Palette.accentSubtle)
                .frame(width: 36, height: 36)
                .overlay(
                    Text("j")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 20, relativeTo: .body))
                        .foregroundStyle(Palette.accent)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("FROM JENI")
                    .font(Typo.eyebrow)
                    .tracking(1.0)
                    .foregroundStyle(Palette.textSecondary)

                ItalicAccentText(note.body,
                                 italic: note.italicTerms,
                                 baseFont: bodyFont,
                                 italicFont: bodyItalicFont,
                                 color: Palette.textPrimary,
                                 alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Space.md)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Palette.accent.opacity(0.35), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 0, x: 3, y: 3)

        if let onTap = onTap {
            Button(action: onTap) { card }
                .buttonStyle(.plain)
        } else {
            card
        }
    }

    private var bodyFont: Font {
        Font.custom("Fraunces72pt-SemiBold", size: 17, relativeTo: .body)
    }

    private var bodyItalicFont: Font {
        Font.custom("Fraunces72pt-SemiBoldItalic", size: 17, relativeTo: .body)
    }

    // MARK: - Once-per-day analytics

    private func trackOncePerDay() {
        let key = "jenis_note_last_tracked_date"
        let today = Self.dayString(for: .now)
        let last = UserDefaults.standard.string(forKey: key)
        guard last != today else { return }
        UserDefaults.standard.set(today, forKey: key)
        Analytics.track(.jenisNoteViewed)
    }

    private static func dayString(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

#if DEBUG
#Preview("morning, day 1") {
    JenisNoteCard(note: JenisNoteTemplate.compose(
        name: "han",
        sessionsToday: 0,
        lastSessionDate: nil,
        identityFeeling: "strong"
    ))
    .padding()
    .background(Palette.bgPrimary)
}

#Preview("yesterday counted") {
    JenisNoteCard(note: JenisNoteTemplate.compose(
        name: "han",
        sessionsToday: 0,
        lastSessionDate: Calendar.current.date(byAdding: .day, value: -1, to: .now),
        identityFeeling: ""
    ))
    .padding()
    .background(Palette.bgPrimary)
}

#Preview("welcome back (4d gap)") {
    JenisNoteCard(note: JenisNoteTemplate.compose(
        name: "han",
        sessionsToday: 0,
        lastSessionDate: Calendar.current.date(byAdding: .day, value: -5, to: .now),
        identityFeeling: ""
    ))
    .padding()
    .background(Palette.bgPrimary)
}

#Preview("already did today") {
    JenisNoteCard(note: JenisNoteTemplate.compose(
        name: "han",
        sessionsToday: 1,
        lastSessionDate: .now,
        identityFeeling: ""
    ))
    .padding()
    .background(Palette.bgPrimary)
}
#endif
