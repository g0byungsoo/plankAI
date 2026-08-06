import SwiftUI
import SwiftData
import PlankFood

// MARK: - FoodJournalView (v11.5 — her plates, rebuilt)
//
// The food journal went missing: `JourneyPlatesPage` was deleted with
// the journal corpus in v11 T4 and never rehomed, so there was no way
// left to see what she had eaten. This is its replacement, in the
// modern material.
//
// It is a RECORD, not a scoreboard: days in her own order, each plate
// as the photograph she took, the day's total stated once and never
// graded (L10 — no red, no over-budget framing). Tapping a plate opens
// the same PlateDetailSheet the day surface uses, so there is exactly
// one place a meal can be corrected.

struct FoodJournalView: View {
    let userId: String
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var entries: [FoodLogPersister.FoodLogEntry] = []
    @State private var detail: FoodLogPersister.FoodLogEntry?
    @State private var arrived = false

    private var cal: Calendar { Calendar.current }

    /// Newest day first; within a day, newest plate first.
    private var days: [(day: Date, plates: [FoodLogPersister.FoodLogEntry])] {
        let grouped = Dictionary(grouping: entries) { cal.startOfDay(for: $0.loggedAt) }
        return grouped
            .map { (day: $0.key, plates: $0.value.sorted { $0.loggedAt > $1.loggedAt }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .jeniArrive(arrived, index: 0)

                if days.isEmpty {
                    emptyState
                        .jeniArrive(arrived, index: 1)
                } else {
                    ForEach(Array(days.enumerated()), id: \.offset) { idx, group in
                        daySection(group.day, plates: group.plates)
                            .jeniArrive(arrived, index: min(idx + 1, 6))
                    }
                }

                Spacer(minLength: Space.heroGap)
            }
            .padding(.horizontal, Space.gutter)
        }
        .background(Palette.bgPrimary.ignoresSafeArea())
        .environment(\.jeniArrived, arrived)
        .task {
            entries = FoodLogPersister.allEntries(userId: userId)
            guard !arrived else { return }
            try? await Task.sleep(nanoseconds: 40_000_000)
            arrived = true
        }
        .onReceive(FoodLogPersister.changeNotifier) { _ in
            entries = FoodLogPersister.allEntries(userId: userId)
        }
        .sheet(item: $detail) { plate in
            PlateDetailSheet(entry: plate, userId: userId, onDismiss: { detail = nil })
                .presentationDetents([.large])
                .presentationBackground(Palette.bgPrimary)
                .presentationCornerRadius(28)
        }
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR PLATES")
                    .font(Typo.statLabel)
                    .kerning(1.4)
                    .foregroundStyle(Palette.cocoaTertiary)
                Text("the food journal")
                    .font(Typo.questionHero)
                    .foregroundStyle(Palette.textPrimary)
            }
            Spacer(minLength: Space.md)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.cocoaSecondary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Palette.textPrimary.opacity(0.05)))
            }
            .buttonStyle(JeniPressable())
            .accessibilityIdentifier("journal.close")
            .accessibilityLabel("done. closes your plates")
        }
        .padding(.top, Space.hero)
        .padding(.bottom, Space.sm)
    }

    private var emptyState: some View {
        JeniSurface {
            VStack(alignment: .leading, spacing: 6) {
                JeniHeadline("nothing kept yet.", italic: ["yet."])
                Text("every meal you add lands here, with the photo you took.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, Space.sectionGap)
    }

    // MARK: - A day

    @ViewBuilder
    private func daySection(
        _ day: Date, plates: [FoodLogPersister.FoodLogEntry]
    ) -> some View {
        let kcal = Int(plates.reduce(0) { $0 + $1.kcal }.rounded())
        let protein = Int(plates.reduce(0) { $0 + $1.protein }.rounded())

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                JeniSectionHeader(dayLabel(day))
                Spacer(minLength: Space.sm)
                // The day's total, stated once. Never graded (L10).
                Text("\(kcal.formatted()) kcal · \(protein)g protein")
                    .font(Typo.statLabel)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .padding(.top, Space.sectionGap)
            }

            VStack(spacing: 10) {
                ForEach(plates, id: \.id) { plate in
                    plateCard(plate)
                }
            }
        }
    }

    private func dayLabel(_ day: Date) -> String {
        if cal.isDateInToday(day) { return "today" }
        if cal.isDateInYesterday(day) { return "yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
            .lowercased()
    }

    // MARK: - A plate

    @ViewBuilder
    private func plateCard(_ plate: FoodLogPersister.FoodLogEntry) -> some View {
        Button {
            JeniHaptic.tick()
            detail = plate
        } label: {
            JeniSurface(radius: 22, padding: 10) {
                HStack(spacing: Space.md) {
                    plateImage(plate)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(plate.title)
                            .font(.custom("DMSans-Medium", size: 16, relativeTo: .body))
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(macroLine(plate))
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                        Text(plate.loggedAt.formatted(.dateTime.hour().minute()).lowercased())
                            .font(Typo.statLabel)
                            .foregroundStyle(Palette.cocoaTertiary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.cocoaTertiary.opacity(0.7))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(JeniPressable())
        .accessibilityLabel("\(plate.title), \(macroLine(plate)). opens the plate")
    }

    /// Her own photograph when there is one; otherwise a quiet mark —
    /// never a stock illustration standing in for a meal she ate.
    @ViewBuilder
    private func plateImage(_ plate: FoodLogPersister.FoodLogEntry) -> some View {
        ZStack {
            if let photo = FoodPhotoStore.photo(entryId: plate.id) {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                Palette.textPrimary.opacity(0.05)
                Image(systemName: "fork.knife")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Palette.cocoaTertiary)
            }
        }
        .frame(width: 62, height: 62)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func macroLine(_ plate: FoodLogPersister.FoodLogEntry) -> String {
        "\(Int(plate.kcal.rounded())) kcal · \(Int(plate.protein.rounded()))g protein"
    }
}
