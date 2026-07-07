import SwiftUI
import SwiftData
import PlankFood
import PlankSync
import Auth

// MARK: - JourneyWeekPage (app v4, docs/app_v4/02_JOURNEY.md §5)
//
// Tap a week → the week page: the seven days as receipt rows, the
// week's plates as a photo strip, the signed re-signing record, and
// day taps swapping IN-PAGE to the day receipt (never a sheet over
// a sheet — the her-days lesson kept). A day receipt is read-only
// memory: what happened, never what didn't.

struct JourneyWeekPage: View {
    let entry: JourneyModel.WeekEntry
    let snapshot: TodaySnapshot
    let userId: String
    let onAskJeni: (String) -> Void
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext

    private enum Page: Equatable {
        case week
        case day(Int)   // programDay
    }
    @State private var page: Page = .week
    @State private var dayDetail: DayDetail? = nil

    var body: some View {
        Group {
            switch page {
            case .week:
                weekPage
                    .transition(.opacity)
            case .day(let programDay):
                dayPage(programDay)
                    .transition(.opacity)
            }
        }
        .onAppear {
            Analytics.track(.journeyWeekOpened, properties: [
                "week": entry.weekIndex,
            ])
            #if DEBUG
            // QA: land on a day receipt directly (pairs with
            // --uitest-open-week). --uitest-open-day 15
            let args = ProcessInfo.processInfo.arguments
            if let idx = args.firstIndex(of: "--uitest-open-day"),
               idx + 1 < args.count, let dayIdx = Int(args[idx + 1]),
               let fact = entry.slice.days.first(where: { $0.programDay == dayIdx }),
               !fact.isFuture {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    loadDay(fact)
                }
            }
            #endif
        }
    }

    // MARK: - The week

    private var weekPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                Text(entry.story)
                    .font(Typo.body)
                    .lineSpacing(3)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.md)

                if let record = entry.record {
                    signedBlock(record)
                        .padding(.top, Space.lg)
                }

                // The seven days.
                VStack(spacing: 0) {
                    ForEach(Array(entry.slice.days.enumerated()), id: \.element.programDay) { idx, day in
                        VStack(spacing: 0) {
                            if idx > 0 {
                                Rectangle()
                                    .fill(Palette.hairlineCocoa)
                                    .frame(height: 0.5)
                            }
                            dayRow(day)
                        }
                    }
                }
                .padding(.top, Space.lg)

                // The week's plates — a memory strip, newest last.
                weekPlates

                Spacer(minLength: Space.xl)
            }
            .padding(.horizontal, Space.lg)
        }
        .scrollIndicators(.hidden)
        .background(Palette.bgPrimary)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.custom("JeniHeroSerif-Regular", size: 24, relativeTo: .title3))
                    .foregroundStyle(Palette.textPrimary)
                Text("week \(entry.weekIndex) · \(dateRange)")
                    .font(Typo.captionTracked)
                    .kerning(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
            }
            Spacer()
            JKQuietMark(systemName: "xmark", accessibilityLabel: "close") {
                onDismiss()
            }
        }
        .padding(.top, Space.lg)
    }

    private var dateRange: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        guard let first = entry.slice.days.first?.date,
              let last = entry.slice.days.last?.date
        else { return "" }
        return "\(fmt.string(from: first)) to \(fmt.string(from: last))".lowercased()
    }

    private func signedBlock(_ record: ReviewRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                JKMark(kind: .door, size: 12, color: Palette.accent)
                Text("signed")
                    .font(Typo.captionTracked)
                    .kerning(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
            }
            ItalicAccentText(
                record.stampLine,
                italic: [],
                baseFont: .custom("JeniHeroSerif-Regular", size: 17, relativeTo: .body),
                italicFont: .custom("JeniHeroSerif-Italic", size: 17, relativeTo: .body),
                color: Palette.textPrimary,
                alignment: .leading
            )
            Text(record.reasonLine)
                .font(Typo.caption)
                .lineSpacing(2)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Palette.hairlineCocoa, lineWidth: 0.66)
        )
    }

    // MARK: - Day rows

    @ViewBuilder
    private func dayRow(_ day: ProgramWeekSlice.DayFact) -> some View {
        let isToday = Calendar.current.isDateInToday(day.date)
        Button {
            guard !day.isFuture else { return }
            Haptics.light()
            loadDay(day)
        } label: {
            HStack(spacing: 12) {
                JKStandingDots(days: [.init(
                    id: day.programDay, standing: day.standing,
                    isToday: isToday, isFuture: day.isFuture,
                    isPaused: day.isPaused
                )])
                .frame(width: 12)

                Text(weekdayName(day.date))
                    .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
                    .foregroundStyle(
                        day.isFuture ? Palette.textSecondary.opacity(0.6) : Palette.textPrimary
                    )

                Text("· \(factsLine(day))")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 8)

                if !day.isFuture {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Palette.cocoaTertiary)
                }
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
            .opacity(day.isFuture ? 0.65 : 1)
        }
        .buttonStyle(JKPress())
        .disabled(day.isFuture)
        .accessibilityIdentifier("journey.day.\(day.programDay)")
        .accessibilityLabel("\(weekdayName(day.date)), \(factsLine(day))")
        .accessibilityHint(day.isFuture ? "" : "opens the day")
    }

    private func weekdayName(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE"
        return fmt.string(from: date).lowercased()
    }

    private func factsLine(_ day: ProgramWeekSlice.DayFact) -> String {
        if day.isPaused { return "held" }
        if day.isFuture { return "to come" }
        if Calendar.current.isDateInToday(day.date) { return "today, still open" }
        var parts: [String] = []
        switch day.standing {
        case .kept: parts.append("kept")
        case .partial: parts.append("some of it")
        case .quiet: parts.append("quiet")
        }
        if day.plateCount > 0 {
            parts.append(day.plateCount == 1 ? "a plate" : "\(day.plateCount) plates")
        }
        if day.weighKg != nil { parts.append("weighed in") }
        return parts.joined(separator: " · ")
    }

    // MARK: - The week's plates strip

    @ViewBuilder private var weekPlates: some View {
        let entries = weekPlateEntries
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("the plates")
                    .font(Typo.captionTracked)
                    .kerning(1.98)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(entries, id: \.id) { plate in
                            plateThumb(plate)
                        }
                    }
                }
            }
            .padding(.top, Space.xl)
        }
    }

    private var weekPlateEntries: [FoodLogPersister.FoodLogEntry] {
        guard let first = entry.slice.days.first?.date,
              let lastDay = entry.slice.days.last?.date,
              let end = Calendar.current.date(byAdding: .day, value: 1, to: lastDay)
        else { return [] }
        return FoodLogPersister.allEntries(userId: userId)
            .filter { $0.loggedAt >= Calendar.current.startOfDay(for: first) && $0.loggedAt < end }
            .sorted { $0.loggedAt < $1.loggedAt }
    }

    @ViewBuilder
    private func plateThumb(
        _ plate: FoodLogPersister.FoodLogEntry,
        size: CGFloat = 64,
        titled: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                if let image = FoodPhotoStore.photo(entryId: plate.id) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Palette.bgElevated)
                        .overlay(
                            JKMark(kind: .plate, size: size * 0.25,
                                   color: Palette.cocoaTertiary)
                        )
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Palette.hairlineCocoa, lineWidth: 0.5)
            )
            if titled {
                Text(plate.title.isEmpty ? "a plate" : plate.title)
                    .font(.custom("DMSans-Regular", size: 10))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                    .frame(width: size, alignment: .leading)
            }
        }
    }

    // MARK: - The day receipt (in-page)

    private struct DayDetail {
        let fact: ProgramWeekSlice.DayFact
        let keptBeats: [String]
        let plates: [FoodLogPersister.FoodLogEntry]
    }

    @MainActor
    private func loadDay(_ day: ProgramWeekSlice.DayFact) {
        guard let planId = snapshot.plan?.id else { return }
        let programDay = day.programDay
        let checks = (try? modelContext.fetch(FetchDescriptor<ProgramDayCheckRecord>(
            predicate: #Predicate {
                $0.userId == userId
                && $0.programPlanId == planId
                && $0.programDay == programDay
            }
        ))) ?? []
        let kept = checks
            .filter { $0.state == "complete" || $0.state == "autoCompleted" }
            .compactMap { beatMemoryLine($0.itemKey) }

        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day.date)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let plates = FoodLogPersister.allEntries(userId: userId)
            .filter { $0.loggedAt >= dayStart && $0.loggedAt < dayEnd }
            .sorted { $0.loggedAt < $1.loggedAt }

        dayDetail = DayDetail(fact: day, keptBeats: kept, plates: plates)
        withAnimation(Motion.crossFade) { page = .day(day.programDay) }
        Analytics.track(.journeyDayOpened, properties: ["program_day": day.programDay])
    }

    private func beatMemoryLine(_ itemKey: String) -> String? {
        switch itemKey {
        case "snap_meal": return "the plates were seen"
        case "move": return "she moved"
        case "lesson": return "the practice held"
        case "breath": return "a breath taken"
        case "weigh_in": return "the trend fed"
        case "steps": return "her legs covered the day"
        default: return nil
        }
    }

    @ViewBuilder
    private func dayPage(_ programDay: Int) -> some View {
        if let detail = dayDetail {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dayTitle(detail.fact.date))
                                .font(.custom("JeniHeroSerif-Regular", size: 24, relativeTo: .title3))
                                .foregroundStyle(Palette.textPrimary)
                            Text("day \(detail.fact.programDay) · \(standingWord(detail.fact))")
                                .font(Typo.captionTracked)
                                .kerning(1.4)
                                .textCase(.uppercase)
                                .foregroundStyle(Palette.cocoaTertiary)
                        }
                        Spacer()
                        JKQuietMark(systemName: "chevron.left", accessibilityLabel: "back to the week") {
                            withAnimation(Motion.crossFade) { page = .week }
                        }
                    }
                    .padding(.top, Space.lg)

                    // What happened — receipts only.
                    if detail.keptBeats.isEmpty && detail.plates.isEmpty
                        && detail.fact.weighKg == nil {
                        Text(detail.fact.isPaused
                             ? "a held day. your place was kept."
                             : "a quiet day. it still belongs to the story.")
                            .font(Typo.body)
                            .foregroundStyle(Palette.textSecondary)
                            .padding(.top, Space.lg)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(detail.keptBeats.enumerated()), id: \.offset) { idx, line in
                                VStack(spacing: 0) {
                                    if idx > 0 {
                                        Rectangle()
                                            .fill(Palette.hairlineCocoa)
                                            .frame(height: 0.5)
                                    }
                                    HStack(spacing: 10) {
                                        Text("\u{2665}\u{FE0E}")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Palette.accent)
                                        Text(line)
                                            .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
                                            .foregroundStyle(Palette.textPrimary)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 12)
                                }
                            }
                        }
                        .padding(.top, Space.md)

                        if let kg = detail.fact.weighKg {
                            weighRow(kg)
                        }

                        if !detail.plates.isEmpty {
                            dayPlates(detail.plates)
                                .padding(.top, Space.lg)
                        }
                    }

                    // One door: the day, talked through.
                    JKJourneyDoor(
                        lead: "ask jeni",
                        punch: "about this day",
                        italic: ["this day"],
                        action: {
                            onAskJeni(
                                "tell me about day \(detail.fact.programDay) — "
                                + "\(dayTitle(detail.fact.date))"
                            )
                        }
                    )
                    .padding(.top, Space.xl)

                    Spacer(minLength: Space.xl)
                }
                .padding(.horizontal, Space.lg)
            }
            .scrollIndicators(.hidden)
            .background(Palette.bgPrimary)
        }
    }

    private func dayTitle(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMMM d"
        return fmt.string(from: date).lowercased()
    }

    private func standingWord(_ fact: ProgramWeekSlice.DayFact) -> String {
        if fact.isPaused { return "held" }
        // Today never wears a verdict — it's still being written.
        if Calendar.current.isDateInToday(fact.date) { return "still open" }
        switch fact.standing {
        case .kept: return "kept"
        case .partial: return "some of it landed"
        case .quiet: return "quiet"
        }
    }

    private func weighRow(_ kg: Double) -> some View {
        let unitRaw = UserDefaults.standard.string(forKey: "weightUnit") ?? "lb"
        let unit = WeightUnit(rawValue: unitRaw) ?? .lb
        return HStack(spacing: 10) {
            JKMark(kind: .line, size: 13, color: Palette.cocoaSecondary)
            Text("weighed in")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
            Spacer(minLength: 8)
            Text(String(format: "%.1f %@", unit.display(fromKg: kg), unit.label))
                .font(.custom("DMSans-Medium", size: 14, relativeTo: .footnote))
                .foregroundStyle(Palette.textPrimary)
                .monospacedDigit()
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func dayPlates(_ plates: [FoodLogPersister.FoodLogEntry]) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("the plates")
                .font(Typo.captionTracked)
                .kerning(1.98)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
            VStack(spacing: 0) {
                ForEach(Array(plates.enumerated()), id: \.element.id) { idx, plate in
                    VStack(spacing: 0) {
                        if idx > 0 {
                            Rectangle()
                                .fill(Palette.hairlineCocoa)
                                .frame(height: 0.5)
                        }
                        HStack(spacing: 12) {
                            plateThumb(plate, size: 44, titled: false)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plate.title.isEmpty ? "a plate" : plate.title)
                                    .font(.custom("DMSans-Medium", size: 14, relativeTo: .footnote))
                                    .foregroundStyle(Palette.textPrimary)
                                    .lineLimit(1)
                                Text(plateFacts(plate))
                                    .font(Typo.caption)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }

    private func plateFacts(_ plate: FoodLogPersister.FoodLogEntry) -> String {
        let time = plate.loggedAt.formatted(date: .omitted, time: .shortened).lowercased()
        let protein = Int(plate.protein.rounded())
        return protein > 0 ? "\(time) · about \(protein)g protein" : time
    }
}
