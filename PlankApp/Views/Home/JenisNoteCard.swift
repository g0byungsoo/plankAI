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
        // Voice, not a card — the single coach line at the top of Home.
        // Kept chrome-light (avatar + one line, no card fill/border/shadow)
        // so the hero session card below stays the only visual hero and
        // the screen reads as one cohesive voice, not stacked widgets.
        // The note body already carries the time-of-day greeting + daily
        // message (JenisNoteTemplate), so this replaces the old separate
        // greeting entirely. This is also the seed of the future coach-
        // agent surface (it grows into Jeni's conversation/recommendations).
        let line = HStack(alignment: .top, spacing: Space.md) {
            Circle()
                .fill(Palette.accentSubtle)
                .frame(width: 40, height: 40)
                .overlay(
                    Text("j")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22, relativeTo: .body))
                        .foregroundStyle(Palette.accent)
                )
                .accessibilityHidden(true)

            ItalicAccentText(note.body,
                             italic: note.italicTerms,
                             baseFont: bodyFont,
                             italicFont: bodyItalicFont,
                             color: Palette.textPrimary,
                             alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        if let onTap = onTap {
            Button(action: onTap) { line }
                .buttonStyle(.plain)
        } else {
            line
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
