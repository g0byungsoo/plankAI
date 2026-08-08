import SwiftUI
import PlankFood

// MARK: - PlateDetailSheet (v5.1)
//
// A logged plate, understood — the surface that never existed: tap a
// plate anywhere (today's strip, her plates) and the meal explains
// itself. What it was, what it carried, how it sat in its day, and
// what to do when the read was off. Receipt grammar, no charts, no
// verdicts. Suppressed cohorts get protein-words only (the standing
// law); numbers appear only where the pipeline stored them.

struct PlateDetailSheet: View {
    let entry: FoodLogPersister.FoodLogEntry
    let userId: String
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var confirmDelete = false

    private var suppressed: Bool { CohortStore.isNumericSuppressed }

    /// Every plate from the same day — the contribution lines compare
    /// against the day the plate actually fed, so past plates stay
    /// honest ("that day") and today's stay live ("today").
    private var dayEntries: [FoodLogPersister.FoodLogEntry] {
        let key = TodayStateService.dayKey(for: entry.loggedAt)
        return FoodLogPersister.allEntries(userId: userId)
            .filter { TodayStateService.dayKey(for: $0.loggedAt) == key }
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(entry.loggedAt)
    }

    private var dayWord: String { isToday ? "today" : "that day" }

    var body: some View {
        JKSheetChrome(
            title: entry.title.isEmpty ? "a plate" : entry.title.lowercased(),
            eyebrow: eyebrowLine
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let image = FoodPhotoStore.photo(entryId: entry.id) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 216)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Palette.hairlineCocoa, lineWidth: 0.5)
                            )
                            .padding(.top, Space.md)
                            .accessibilityHidden(true)
                    }

                    hero
                        .padding(.top, Space.lg)

                    chemistryRows
                        .padding(.top, Space.lg)

                    dayRows
                        .padding(.top, Space.section)

                    if let details = entry.itemsDetail, !details.isEmpty {
                        itemLedger(details)
                            .padding(.top, Space.section)
                    }

                    againRow
                        .padding(.top, Space.section)

                    honesty
                        .padding(.top, Space.section)

                    Spacer(minLength: Space.xl)
                }
                .padding(.horizontal, Space.lg)
            }
            .scrollIndicators(.hidden)
        }
        .confirmationDialog(
            "let this plate go?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("remove it", role: .destructive) {
                FoodLogPersister.deleteEntry(id: entry.id)
                Haptics.soft()
                onDismiss()
            }
            Button("keep it", role: .cancel) {}
        } message: {
            Text("removing it takes it out of \(dayWord)'s count. you can snap a fresh one anytime.")
        }
    }

    private var eyebrowLine: String {
        let time = entry.loggedAt.formatted(date: .omitted, time: .shortened).lowercased()
        if isToday { return "today \u{00B7} \(time)" }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMM d"
        return "\(fmt.string(from: entry.loggedAt).lowercased()) \u{00B7} \(time)"
    }

    // MARK: the relog (v23 §7 — history lives where history is)

    private var againRow: some View {
        Button {
            Haptics.soft()
            FoodLogPersister.relog(entry, userId: userId)
            FoodAnalytics.track(.logSaved, properties: [
                "items_count": 0,
                "source": "relog",
            ])
            onDismiss()
        } label: {
            HStack(spacing: Space.sm) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.textPrimary.opacity(0.7))
                Text("log it again")
                    .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
                    .foregroundStyle(Palette.textPrimary)
                Spacer(minLength: Space.sm)
                Text("a fresh entry, today")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("log it again as a fresh entry today")
    }

    // MARK: hero — the two numbers that matter (or the one that's allowed)

    @ViewBuilder private var hero: some View {
        if suppressed {
            ItalicAccentText(
                "about \(Int(entry.protein.rounded()))g of protein",
                italic: ["protein"],
                baseFont: .custom("JeniHeroSerif-Regular", size: 22, relativeTo: .title3),
                italicFont: .custom("JeniHeroSerif-Italic", size: 22, relativeTo: .title3),
                color: Palette.textPrimary,
                alignment: .leading
            )
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Int(entry.kcal.rounded()))")
                    .font(.custom("JeniHeroSerif-Regular", size: 44, relativeTo: .largeTitle))
                    .foregroundStyle(Palette.textPrimary)
                    .monospacedDigit()
                Text("calories")
                    .font(.custom("JeniHeroSerif-Italic", size: 18, relativeTo: .body))
                    .foregroundStyle(Palette.textSecondary)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: chemistry — what the plate was made of

    @ViewBuilder private var chemistryRows: some View {
        VStack(spacing: 0) {
            if entry.protein >= 1 {
                JKReceiptRow(
                    lead: "protein",
                    punch: "\(Int(entry.protein.rounded()))g",
                    showsRule: false
                )
            }
            if !suppressed {
                if entry.carbs >= 1 {
                    JKReceiptRow(lead: "carbs", punch: "\(Int(entry.carbs.rounded()))g")
                }
                if entry.fat >= 1 {
                    JKReceiptRow(lead: "fat", punch: "\(Int(entry.fat.rounded()))g")
                }
                if entry.fiber >= 1 {
                    JKReceiptRow(lead: "fiber", punch: "\(Int(entry.fiber.rounded()))g")
                }
                // v1.1.5 — sugar sits with the other macros: an honest
                // number, no red, no verdict (anti-shame law). Silent when
                // the pipeline didn't carry a value.
                if entry.sugar >= 1 {
                    JKReceiptRow(lead: "sugar", punch: "\(Int(entry.sugar.rounded()))g")
                }
            }
        }
    }

    // MARK: the day around it — contribution with provenance

    @ViewBuilder private var dayRows: some View {
        let dayProtein = dayEntries.reduce(0.0) { $0 + $1.protein }
        let dayKcal = dayEntries.reduce(0.0) { $0 + $1.kcal }

        VStack(alignment: .leading, spacing: 0) {
            Text(isToday ? "in today" : "in its day")
                .font(Typo.captionTracked)
                .kerning(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.bottom, 4)

            if entry.protein >= 1, dayProtein >= 1 {
                JKReceiptRow(
                    lead: "of \(dayWord)'s protein",
                    punch: "\(Int(entry.protein.rounded())) of \(Int(dayProtein.rounded()))g",
                    showsRule: false
                )
            }

            if !suppressed, entry.kcal >= 1, dayKcal >= 1 {
                JKReceiptRow(
                    lead: "share of \(dayWord)'s calories",
                    punch: shareWords(entry.kcal / dayKcal),
                    punchItalic: [shareWords(entry.kcal / dayKcal)]
                )
            }

            // Today only: where the day stands after everything so far
            // — the same voice as the snap result's day line, so the
            // app never says this two ways.
            if !suppressed, isToday,
               let target = TargetsService.current(
                   userId: userId,
                   in: modelContext
               ).kcal, target > 0 {
                let room = target - Int(dayKcal.rounded())
                JKReceiptRow(
                    lead: "the day so far",
                    punch: roomWords(room: room),
                    punchItalic: []
                )
            }
        }
    }

    private func shareWords(_ ratio: Double) -> String {
        switch ratio {
        case ..<0.18: "a small part"
        case ..<0.3: "about a quarter"
        case ..<0.42: "about a third"
        case ..<0.62: "about half"
        case ..<0.95: "most of it"
        default: isToday ? "all of it so far" : "the whole day"
        }
    }

    private func roomWords(room: Int) -> String {
        if room >= 150 { return "room for about \((room / 50) * 50)" }
        if room >= -60 { return "right around your target" }
        return "a little over \u{00B7} tomorrow resets"
    }

    // MARK: on the plate — the per-item read (device-local detail)

    @ViewBuilder private func itemLedger(_ details: [FoodLogPersister.ItemDetail]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("on the plate")
                .font(Typo.captionTracked)
                .kerning(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.bottom, 4)

            ForEach(Array(details.enumerated()), id: \.offset) { idx, item in
                JKReceiptRow(
                    lead: item.name.lowercased(),
                    punch: suppressed
                        ? "\(Int(item.portionG.rounded()))g"
                        : "\(Int(item.portionG.rounded()))g \u{00B7} \(Int(item.kcal.rounded())) cal",
                    showsRule: idx > 0
                )
            }
        }
    }

    // MARK: honesty — what this is, and the way out when it's wrong

    @ViewBuilder private var honesty: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text(entry.source == "photo"
                 ? "read from your photo \u{00B7} ranges, not exact"
                 : "logged from your words \u{00B7} ranges, not exact")
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)

            Button {
                Haptics.light()
                confirmDelete = true
            } label: {
                Text("off? remove this plate")
                    .font(.custom("DMSans-Medium", size: 13, relativeTo: .footnote))
                    .foregroundStyle(Palette.cocoaSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .overlay(
                        Capsule().strokeBorder(Palette.hairlineCocoa, lineWidth: 0.66)
                    )
                    .contentShape(Capsule())
            }
            .buttonStyle(JKPress())
            .accessibilityHint("removes this plate from the day")
        }
    }
}
