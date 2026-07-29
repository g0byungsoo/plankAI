import SwiftUI
import PlankFood

// MARK: - JourneyPlatesPage (app v4, docs/app_v4/03_FEATURES.md §1)
//
// HER PLATES — the food archive in the journey's receipt grammar.
// The v1 journal interior (holiday stock plate, floating FAB, "tap
// the + to scan or jot") dies; this is day-grouped memory: photo
// rows, protein-first at rest (kcal stays in the snap flow's
// detail), the quiet-hours line each morning earned, delete on
// long-press. Logging lives where it always did — the snap flow —
// reachable from one quiet door here.

struct JourneyPlatesPage: View {
    let userId: String
    let onSnap: () -> Void
    let onDismiss: () -> Void

    @State private var entries: [FoodLogPersister.FoodLogEntry] = []
    @State private var confirmDelete: FoodLogPersister.FoodLogEntry? = nil
    /// v5.1 — tap opens the plate's own page (long-press still removes).
    @State private var detailPlate: FoodLogPersister.FoodLogEntry? = nil

    private var days: [(dayKey: String, date: Date, plates: [FoodLogPersister.FoodLogEntry])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: entries) {
            TodayStateService.dayKey(for: $0.loggedAt)
        }
        return grouped
            .map { key, plates in
                (dayKey: key,
                 date: cal.startOfDay(for: plates[0].loggedAt),
                 plates: plates.sorted { $0.loggedAt < $1.loggedAt })
            }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        JKScreenChrome {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.top, Space.hero)

                    if days.isEmpty {
                        JKEmptyState(
                            line: "your first plate sets up the day",
                            italic: ["first"],
                            actionLabel: "add it",
                            action: onSnap
                        )
                        .padding(.top, Space.xl)
                    } else {
                        ForEach(days, id: \.dayKey) { day in
                            daySection(day)
                                .padding(.top, Space.section)
                        }
                    }

                    Spacer(minLength: 96)
                }
                .padding(.horizontal, Space.lg)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear { reload() }
        .onReceive(FoodLogPersister.changeNotifier) { _ in reload() }
        .sheet(item: $detailPlate) { plate in
            PlateDetailSheet(
                entry: plate,
                userId: userId,
                onDismiss: { detailPlate = nil }
            )
            .presentationDetents([.large])
            .presentationBackground(Palette.bgPrimary)
        }
        .confirmationDialog(
            "let this plate go?",
            isPresented: Binding(
                get: { confirmDelete != nil },
                set: { if !$0 { confirmDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("delete it", role: .destructive) {
                if let plate = confirmDelete {
                    FoodLogPersister.deleteEntry(id: plate.id)
                    Haptics.soft()
                }
                confirmDelete = nil
            }
            Button("keep it", role: .cancel) { confirmDelete = nil }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                ItalicAccentText(
                    "her plates",
                    italic: ["plates"],
                    baseFont: .custom("JeniHeroSerif-Regular", size: 28, relativeTo: .title2),
                    italicFont: .custom("JeniHeroSerif-Italic", size: 28, relativeTo: .title2),
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                Text("the food story, day by day")
                    .font(Typo.captionTracked)
                    .kerning(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
            }
            Spacer()
            JKQuietMark(systemName: "camera", accessibilityLabel: "add a meal") {
                onSnap()
            }
            JKQuietMark(systemName: "xmark", accessibilityLabel: "close") {
                onDismiss()
            }
        }
    }

    @ViewBuilder
    private func daySection(
        _ day: (dayKey: String, date: Date, plates: [FoodLogPersister.FoodLogEntry])
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(dayTitle(day.date))
                    .font(.custom("JeniHeroSerif-Regular", size: 17, relativeTo: .body))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                if dayProtein(day.plates) > 0 {
                    Text("about \(dayProtein(day.plates))g protein")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaSecondary)
                }
            }

            if let quiet = QuietHours.overnightForDay(userId: userId, day: day.date),
               quiet >= 11 {
                HStack(spacing: 7) {
                    JKMark(kind: .moon, size: 11,
                           color: Palette.cocoaSecondary.opacity(0.8))
                    Text("began after about a \(Int(quiet.rounded()))h overnight fast \u{2665}\u{FE0E}")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(day.plates.enumerated()), id: \.element.id) { idx, plate in
                    VStack(spacing: 0) {
                        if idx > 0 {
                            Rectangle()
                                .fill(Palette.hairlineCocoa)
                                .frame(height: 0.5)
                        }
                        plateRow(plate)
                    }
                }
            }
        }
    }

    private func plateRow(_ plate: FoodLogPersister.FoodLogEntry) -> some View {
        HStack(spacing: 12) {
            Group {
                if let image = FoodPhotoStore.photo(entryId: plate.id) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Palette.bgElevated)
                        .overlay(
                            JKMark(kind: .plate, size: 13,
                                   color: Palette.cocoaTertiary)
                        )
                }
            }
            .frame(width: 46, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Palette.hairlineCocoa, lineWidth: 0.5)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(plate.title.isEmpty ? "a plate" : plate.title)
                    .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                Text(plateFacts(plate))
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.light()
            detailPlate = plate
        }
        .onLongPressGesture(minimumDuration: 0.45) {
            Haptics.light()
            confirmDelete = plate
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(plate.title.isEmpty ? "a plate" : plate.title), \(plateFacts(plate))")
        .accessibilityHint("opens the plate. hold to remove")
    }

    private func dayTitle(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "today" }
        if Calendar.current.isDateInYesterday(date) { return "yesterday" }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMM d"
        return fmt.string(from: date).lowercased()
    }

    private func dayProtein(_ plates: [FoodLogPersister.FoodLogEntry]) -> Int {
        Int(plates.reduce(0) { $0 + $1.protein }.rounded())
    }

    private func plateFacts(_ plate: FoodLogPersister.FoodLogEntry) -> String {
        let time = plate.loggedAt.formatted(date: .omitted, time: .shortened).lowercased()
        let protein = Int(plate.protein.rounded())
        return protein > 0 ? "\(time) · about \(protein)g protein" : time
    }

    private func reload() {
        entries = FoodLogPersister.allEntries(userId: userId)
    }
}
