import SwiftUI

// MARK: - MethodToldView (v25 E8.1)
//
// THE BROWSE SURFACE, and the argument for its shape.
//
// The brief asked to "preserve an appropriate way to browse or revisit
// useful material if users genuinely need one". This is it, and it is
// deliberately NOT a library. An 84-lesson shelf was the old answer, and
// the record says what happened to it: 464 people opened one lesson, 39
// ever finished one, 1.66 distinct days each. Nobody browses a shelf of
// things they have never seen.
//
// What people DO come back to is something they were told once and want
// again. So the browsable material is her own: every note Jeni has
// surfaced, when, why, and whether she acted on it. It grows only when
// something genuinely relevant happened, which means it can never
// contain filler.
//
// It sits beside `JeniMemoryView` on purpose, and mirrors its law. That
// page is what the person told Jeni; this is what Jeni told the person.
// Between them, the whole relationship is auditable from settings.
//
// The one thing this page must never do is imply debt. There is no
// unread badge, no count of what she skipped, no completion state.

struct MethodToldView: View {

    @State private var entries: [MethodLedger.Entry] = []

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                JFPageHero(
                    title: "what jeni has told you.",
                    italic: ["told you."],
                    alignment: .leading
                )
                .padding(.horizontal, -Space.screenPadding)

                Spacer().frame(height: 20)

                Text("jeni only says something when your own record gives a reason to. this is every one of those, kept.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if entries.isEmpty {
                    Spacer().frame(height: 36)
                    emptyState
                } else {
                    Spacer().frame(height: 36)
                    SettingsSection(title: "kept") {
                        ForEach(Array(entries.enumerated()), id: \.offset) { idx, entry in
                            row(entry, showsRule: idx > 0)
                        }
                    }
                }

                Spacer().frame(height: 60)
            }
            .padding(.horizontal, Space.screenPadding)
        }
        .background(Palette.bgPrimary)
        .onAppear { entries = MethodLedger.entries() }
    }

    // MARK: - Rows

    @ViewBuilder
    private func row(_ entry: MethodLedger.Entry, showsRule: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsRule {
                Rectangle()
                    .fill(Palette.hairlineCocoa)
                    .frame(height: 0.5)
                    .padding(.vertical, Space.md)
            }
            // The note's own sentence is NOT stored (the ledger keeps ids
            // and categoricals only, so a backup never carries a health
            // sentence). What renders is the same catalog entry, resolved
            // fresh — which also means a rewritten note reads in its
            // current words while the ledger keeps the version she saw.
            if let note = catalogNote(entry) {
                Text(note.because)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // A note that has since been retired. Say so plainly
                // rather than dropping the row: she was told something,
                // and that stays true.
                Text("a note jeni no longer shows.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
            }
            HStack(spacing: 6) {
                Text(whenWord(entry.shownAt))
                if entry.fromCareTeam {
                    Text("\u{00B7}")
                    Text("from your care team")
                }
                if entry.actionTaken {
                    Text("\u{00B7}")
                    Text("you acted on it")
                }
            }
            .font(Typo.caption)
            .foregroundStyle(Palette.cocoaTertiary)
            .padding(.top, 6)
        }
    }

    private func catalogNote(_ entry: MethodLedger.Entry) -> MethodNote? {
        MethodCatalog.notes.first { $0.id == entry.noteId }
    }

    private func whenWord(_ date: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents(
            [.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: .now)
        ).day ?? 0
        switch days {
        case 0: return "today"
        case 1: return "yesterday"
        case 2...13: return "\(days) days ago"
        default: return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }

    private var emptyState: some View {
        // p67 — the illustration register (§5.9): the empty face
        // carries one big doodle and one direct sentence.
        VStack(spacing: Space.md) {
            JKEmptyState(
                line: "nothing yet.",
                doodle: "doodle-book"
            )
            Text("jeni stays quiet until your record shows something worth saying. a few days of plates and a weigh-in is usually enough.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.xl)
    }
}
