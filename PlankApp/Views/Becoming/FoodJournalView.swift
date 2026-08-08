import SwiftUI
import PlankFood

// MARK: - FoodJournalView (v23 THE STILL LIFE §7 — THE BOOK)
//
// The journal reborn as a magazine, not a database: a day is a
// SPREAD. The serif date leads, the day's ledger line is stated once
// and never graded (L10), and the plates run as photographs — the
// newest full-width, the rest two across, photo-less meals as
// typographic menu rows. Month seams mark the chapters; the current
// week's read (FoodWeekRead — bands, never scores) leads the book
// when its floors are met.
//
// "log it again" lives HERE now (context menu + the plate page) —
// history belongs where history is; the camera stays a window.

struct FoodJournalView: View {
    let userId: String
    let onClose: () -> Void

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
            LazyVStack(alignment: .leading, spacing: 0) {
                masthead
                    .jeniArrive(arrived, index: 0)

                if let read = currentWeekRead {
                    weekReadLine(read)
                        .jeniArrive(arrived, index: 1)
                }

                if days.isEmpty {
                    emptyState
                        .jeniArrive(arrived, index: 1)
                } else {
                    ForEach(Array(days.enumerated()), id: \.element.day) { idx, group in
                        if monthSeamNeeded(at: idx) {
                            JeniSectionHeader(monthWord(days[idx].day))
                        }
                        daySpread(group.day, plates: group.plates)
                            .jeniArrive(arrived, index: min(idx + 2, 6))
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

    // MARK: - Masthead

    private var masthead: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("your plates")
                    .font(Typo.questionHero)
                    .foregroundStyle(Palette.textPrimary)
                if let count = countLine {
                    Text(count)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
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

    /// "214 plates since june" — the book's own weight, no grade.
    private var countLine: String? {
        guard !entries.isEmpty else { return nil }
        let count = entries.count
        guard let oldest = entries.map(\.loggedAt).min() else { return nil }
        let month = oldest.formatted(.dateTime.month(.wide)).lowercased()
        let plates = count == 1 ? "plate" : "plates"
        if cal.isDate(oldest, equalTo: .now, toGranularity: .month) {
            return "\(count) \(plates) this month"
        }
        return "\(count) \(plates) since \(month)"
    }

    // MARK: - The current week's read (bands, never scores)

    private var currentWeekRead: FoodWeekRead.Read? {
        FoodWeekRead.compose(
            plates: entries.map {
                FoodWeekRead.Plate(loggedAt: $0.loggedAt, kcal: $0.kcal, protein: $0.protein)
            },
            proteinTargetG: FoodModule.proteinTargetProvider?()
        )
    }

    @ViewBuilder
    private func weekReadLine(_ read: FoodWeekRead.Read) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("THIS WEEK")
                .font(Typo.statLabel)
                .kerning(1.2)
                .foregroundStyle(Palette.cocoaTertiary)
            ItalicAccentText(
                read.line,
                italic: read.italic,
                baseFont: .custom("JeniHeroSerif-Regular", size: 18, relativeTo: .body),
                italicFont: .custom("JeniHeroSerif-Italic", size: 18, relativeTo: .body)
            )
            .foregroundStyle(Palette.textPrimary)
        }
        .padding(.top, Space.md)
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

    // MARK: - Month seams

    private func monthSeamNeeded(at idx: Int) -> Bool {
        guard idx > 0 else { return false }
        return !cal.isDate(days[idx].day, equalTo: days[idx - 1].day, toGranularity: .month)
    }

    private func monthWord(_ day: Date) -> String {
        day.formatted(.dateTime.month(.wide).year()).lowercased()
    }

    // MARK: - A day is a spread

    @ViewBuilder
    private func daySpread(
        _ day: Date, plates: [FoodLogPersister.FoodLogEntry]
    ) -> some View {
        let kcal = Int(plates.reduce(0) { $0 + $1.kcal }.rounded())
        let protein = Int(plates.reduce(0) { $0 + $1.protein }.rounded())
        let withPhotos = plates.filter { FoodPhotoStore.photo(entryId: $0.id) != nil }
        let hero = withPhotos.first
        let gridPlates = withPhotos.dropFirst()
        let typographic = plates.filter { FoodPhotoStore.photo(entryId: $0.id) == nil }

        VStack(alignment: .leading, spacing: 0) {
            // The spread's head: the date leads in serif, the day's
            // numbers follow once, never graded.
            Text(dayLabel(day))
                .font(.custom("JeniHeroSerif-Regular", size: 20, relativeTo: .title3))
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, Space.sectionGap)
            Text("\(kcal.formatted()) kcal · \(protein)g protein")
                .font(Typo.statLabel)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.top, 3)
                .padding(.bottom, Space.md)

            VStack(spacing: 10) {
                if let hero {
                    heroCard(hero)
                }
                if !gridPlates.isEmpty {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10),
                        ],
                        spacing: 10
                    ) {
                        ForEach(Array(gridPlates), id: \.id) { plate in
                            squareCard(plate)
                        }
                    }
                }
                if !typographic.isEmpty {
                    menuRows(typographic)
                }
            }
        }
    }

    private func dayLabel(_ day: Date) -> String {
        if cal.isDateInToday(day) { return "today" }
        if cal.isDateInYesterday(day) { return "yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.wide).day())
            .lowercased()
    }

    // MARK: - The photographs

    /// The day's newest photograph, full width — a magazine plate.
    @ViewBuilder
    private func heroCard(_ plate: FoodLogPersister.FoodLogEntry) -> some View {
        plateButton(plate) {
            JeniSurface(radius: 22, padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    photo(plate)
                        .aspectRatio(4.0 / 3.0, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                        Text(plate.title.lowercased())
                            .font(.custom("JeniHeroSerif-Regular", size: 17, relativeTo: .body))
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: Space.sm)
                        Text("\(Int(plate.kcal.rounded())) kcal")
                            .font(.custom("DMSans-SemiBold", size: 14, relativeTo: .footnote))
                            .foregroundStyle(Palette.textSecondary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    /// The rest of the day's photographs, two across.
    @ViewBuilder
    private func squareCard(_ plate: FoodLogPersister.FoodLogEntry) -> some View {
        plateButton(plate) {
            JeniSurface(radius: 18, padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    photo(plate)
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plate.title.lowercased())
                            .font(.custom("DMSans-Medium", size: 13, relativeTo: .footnote))
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)
                        Text("\(Int(plate.kcal.rounded())) kcal · \(timeLabel(plate))")
                            .font(Typo.statLabel)
                            .foregroundStyle(Palette.cocoaTertiary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    /// Meals without a photograph — a typographic menu, hairline-ruled
    /// (a ledger may rule lines). Type carries what has no photograph.
    @ViewBuilder
    private func menuRows(_ plates: [FoodLogPersister.FoodLogEntry]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(plates.enumerated()), id: \.element.id) { idx, plate in
                plateButton(plate) {
                    HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                        Text(plate.title.lowercased())
                            .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: Space.sm)
                        Text(timeLabel(plate))
                            .font(Typo.statLabel)
                            .foregroundStyle(Palette.cocoaTertiary)
                        Text("\(Int(plate.kcal.rounded())) kcal")
                            .font(.custom("DMSans-SemiBold", size: 13, relativeTo: .footnote))
                            .foregroundStyle(Palette.textSecondary)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                if idx < plates.count - 1 {
                    Rectangle()
                        .fill(Palette.textPrimary.opacity(0.07))
                        .frame(height: 0.5)
                }
            }
        }
    }

    // MARK: - Shared plumbing

    /// Tap opens the plate; a long-press offers the relog — history
    /// lives where history is.
    @ViewBuilder
    private func plateButton<Content: View>(
        _ plate: FoodLogPersister.FoodLogEntry,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button {
            JeniHaptic.tick()
            detail = plate
        } label: {
            content()
        }
        .buttonStyle(JeniPressable())
        .contextMenu {
            Button {
                relog(plate)
            } label: {
                Label("log it again", systemImage: "arrow.counterclockwise")
            }
        }
        .accessibilityLabel(
            "\(plate.title), \(Int(plate.kcal.rounded())) kcal. opens the plate"
        )
    }

    private func relog(_ plate: FoodLogPersister.FoodLogEntry) {
        JeniHaptic.land()
        FoodLogPersister.relog(plate, userId: userId)
        FoodAnalytics.track(.logSaved, properties: [
            "items_count": 0,
            "source": "relog",
        ])
    }

    @ViewBuilder
    private func photo(_ plate: FoodLogPersister.FoodLogEntry) -> some View {
        if let image = FoodPhotoStore.photo(entryId: plate.id) {
            Color.clear
                .overlay(
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                )
        }
    }

    private func timeLabel(_ plate: FoodLogPersister.FoodLogEntry) -> String {
        plate.loggedAt.formatted(.dateTime.hour().minute()).lowercased()
    }
}
