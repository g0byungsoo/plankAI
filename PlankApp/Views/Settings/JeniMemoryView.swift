import SwiftUI
import SwiftData

// MARK: - JeniMemoryView (v25 E3 ONE JENI)
//
// docs/app_v25/12_E3_ONE_JENI.md §4. What jeni was told, in the words
// it was told in, with a way to take any of it back.
//
// This page is the second half of the consent law. The first half is
// that nothing is written without a card; the second is that what WAS
// written stays visible and removable forever. A memory a person
// cannot audit is a profile, and Jeni does not keep profiles.
//
// Design: the settings drawer's own vocabulary (hairline sections, no
// card chrome), the notes as plain sentences rather than data rows,
// and the empty state written as a fact about jeni rather than an
// apology for a missing feature.

struct JeniMemoryView: View {

    let userId: String

    @Environment(\.modelContext) private var modelContext
    @State private var notes: [JeniMemoryRecord] = []
    @State private var confirmingForgetAll = false

    private var grouped: [(topic: JeniMemoryTopic, notes: [JeniMemoryRecord])] {
        JeniMemoryTopic.allCases.compactMap { topic in
            let inTopic = notes.filter { $0.topic == topic.rawValue }
            return inTopic.isEmpty ? nil : (topic, inTopic)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                JFPageHero(
                    title: "what jeni remembers.",
                    italic: ["remembers."],
                    alignment: .leading
                )
                .padding(.horizontal, -Space.screenPadding)

                Spacer().frame(height: 20)

                // Jeni takes no pronoun (the 2026-08-10 voice rule: where a
                // sweep flattened jeni, the pronoun is REMOVED rather than
                // assigned). Frame-caught: this page shipped "her" twice.
                Text("things you've told jeni that still matter. nothing is kept unless you say yes, and you can take any of it back.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if notes.isEmpty {
                    Spacer().frame(height: 36)
                    emptyState
                } else {
                    ForEach(grouped, id: \.topic) { group in
                        Spacer().frame(height: 36)
                        SettingsSection(title: group.topic.heading) {
                            ForEach(group.notes) { note in
                                noteRow(note)
                            }
                        }
                    }
                    Spacer().frame(height: 40)
                    forgetAllRow
                }

                Spacer().frame(height: 36)
                identityFootnote
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.md)
            .padding(.bottom, 48)
        }
        .background(Palette.programEraBg)
        .onAppear(perform: load)
    }

    // MARK: - Rows

    private func noteRow(_ note: JeniMemoryRecord) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Text(note.note)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    Haptics.light()
                    withAnimation(JeniMotion.settle) {
                        JeniMemoryStore.forget(
                            id: note.id, userId: userId, in: modelContext
                        )
                        load()
                    }
                } label: {
                    Text("forget")
                        .font(Typo.statLabel)
                        .foregroundStyle(Palette.cocoaTertiary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 2)
                }
                .buttonStyle(JKPress())
                .accessibilityLabel("forget: \(note.note)")
            }
            .padding(.vertical, 14)
            Rectangle()
                .fill(Palette.hairlineCocoa)
                .frame(height: 0.5)
        }
    }

    private var forgetAllRow: some View {
        Button {
            Haptics.light()
            if confirmingForgetAll {
                withAnimation(JeniMotion.settle) {
                    JeniMemoryStore.forgetAll(userId: userId, in: modelContext)
                    confirmingForgetAll = false
                    load()
                }
            } else {
                withAnimation(JeniMotion.settle) { confirmingForgetAll = true }
            }
        } label: {
            Text(confirmingForgetAll ? "tap again to forget everything" : "forget all of it")
                .font(Typo.body)
                .foregroundStyle(
                    confirmingForgetAll ? Palette.jeweledRose : Palette.textSecondary
                )
        }
        .buttonStyle(JKPress())
    }

    private var emptyState: some View {
        // p67 — the illustration register (§5.9).
        VStack(spacing: Space.md) {
            JKEmptyState(
                line: "nothing yet.",
                doodle: "doodle-user"
            )
            Text("tell jeni something about how you eat, when you're free, or how you want to be talked to. nothing gets written down without a yes.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.xl)
    }

    /// The statutory identity line, repeated where the CA/IL/TX laws
    /// expect it: at first chat AND in settings.
    private var identityFootnote: some View {
        Text("jeni is a digital coach. not a person, not your clinician.")
            .font(Typo.statLabel)
            .foregroundStyle(Palette.cocoaTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func load() {
        notes = JeniMemoryStore.active(userId: userId, in: modelContext)
    }
}
