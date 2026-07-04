#if canImport(UIKit)
import SwiftUI

// MARK: - FoodLogTimelineView
//
// v1.0.9 D3.B — chronological food log timeline. Per plan synthesis
// §D3 + founder lock (HomeFoodCard tap → log, not camera).
//
// Layout:
//   - Cream backdrop (FoodTheme.bgPrimary), italic-Fraunces "your *log*"
//     hero with cherries sticker overhang (matches HomeFoodCard chrome).
//   - Day-grouped sections: "today" / "yesterday" / "tuesday, june 3"
//     (lowercase Fraunces; italic only on the punch word per voice lock).
//   - Rows sorted newest-first within each day:
//       [icon] [title]                                       [Nkcal]
//                                                            [P g · C g · F g]
//       [soft timestamp, "2:14pm"]
//   - Empty state mirrors HomeFoodCard's editorial register.
//   - Floating + button bottom-right opens the camera (parent handles
//     the present-after-dismiss chain so we never stack fullScreenCovers).
//   - Swipe-to-delete on each row → FoodLogPersister.deleteEntry. Soft
//     haptic confirms.
//
// NO meal-grouping (anti-MFP — "is a 4pm smoothie lunch or snack?" forces
// taxonomy decisions the cohort hates). NO red over-target language.
// NO total-summary header that recreates calorie-shame UX. The HomeFoodCard
// already carries the kcal/macro hero; this screen is the receipt.

@MainActor
public struct FoodLogTimelineView: View {

    public let userId: String
    /// v1.0.9 D3.C — passed in so the share renderer can compute the
    /// protein pill against the real onboarding target. Falls back to
    /// 1950 internally if 0.
    public let dailyTarget: Double
    /// v1.0.10 — today's program-day archetype string ("protein" /
    /// "balanced" / "movement" / "rest"). When present the daily share
    /// render uses archetype-themed pull quotes; nil falls back to the
    /// universal 12-quote rotation.
    public let archetypeHint: String?
    /// Fires when the floating + button is tapped. Parent dismisses
    /// this screen then presents the camera; we don't stack
    /// fullScreenCovers here.
    public let onAddTapped: () -> Void
    public let onDismiss: () -> Void

    @State private var entries: [FoodLogPersister.FoodLogEntry] = []
    /// v1.0.9 D3.B — long-press on a row sets this id; the
    /// confirmationDialog mounted on the root surface reads it to
    /// know which entry to delete.
    @State private var pendingDeleteEntryId: String? = nil
    /// v1.0.9 D3.C — lazy-rendered 1080×1920 share image. Built on
    /// tap so we don't re-render on every log change.
    /// Identifiable wrapper — .sheet(item:) instead of
    /// .sheet(isPresented:) so the first tap can't present the sheet
    /// against a stale nil image (showed black until a second tap).
    private struct ShareItem: Identifiable {
        let id = UUID()
        let image: UIImage
    }
    @State private var shareItem: ShareItem? = nil
    /// v1.1 journal — meal detail. The detail lives in the SAME view
    /// hierarchy as the rows (overlay, not a sheet) so the photo
    /// matte can morph row→hero via matchedGeometryEffect (the
    /// Morsel "tiles flow between views" move; iOS 17 target rules
    /// out navigationTransition(.zoom)).
    @State private var selectedEntry: FoodLogPersister.FoodLogEntry? = nil
    @Namespace private var heroNS

    public init(
        userId: String,
        dailyTarget: Double,
        archetypeHint: String? = nil,
        onAddTapped: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.userId = userId
        self.dailyTarget = dailyTarget
        self.archetypeHint = archetypeHint
        self.onAddTapped = onAddTapped
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            FoodTheme.bgPrimary.ignoresSafeArea()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            floatingAddButton
                .padding(.trailing, 22)
                .padding(.bottom, 28)
                .opacity(selectedEntry == nil ? 1 : 0)

            if let entry = selectedEntry {
                mealDetail(for: entry)
                    .zIndex(10)
            }
        }
        .onAppear {
            refresh()
            #if DEBUG
            // Sim QA: `--debug-journal-detail` auto-opens the first
            // entry's detail overlay for screenshot capture.
            if ProcessInfo.processInfo.arguments.contains("--debug-journal-detail"),
               selectedEntry == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                        selectedEntry = entries.first
                    }
                }
            }
            #endif
        }
        .onReceive(FoodLogPersister.changeNotifier) { _ in refresh() }
        // v1.0.9 D3.C — UIActivityViewController share sheet, hosted
        // via a SwiftUI sheet. Reusing the existing ShareSheet UIKit
        // wrapper pattern from PhotoCaptureView's result share would
        // mean importing it across files; for one call site, inline
        // the wrap.
        .sheet(item: $shareItem) { item in
            ShareActivityView(items: [item.image], onComplete: {
                shareItem = nil
            })
            .ignoresSafeArea()
        }
        .confirmationDialog(
            "remove this log?",
            isPresented: Binding(
                get: { pendingDeleteEntryId != nil },
                set: { if !$0 { pendingDeleteEntryId = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("remove", role: .destructive) {
                guard let id = pendingDeleteEntryId else { return }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                FoodLogPersister.deleteEntry(id: id)
                pendingDeleteEntryId = nil
            }
            Button("cancel", role: .cancel) {
                pendingDeleteEntryId = nil
            }
        }
    }

    // MARK: - Content

    // MARK: - Share rendering
    //
    // v1.0.13 (2026-06-18) — handwritten variant is the only register
    // (founder approved across daily / weekly / snap in commits
    // 7e5c3b7 + c4ac98d + cc41fa1 + 49cc527).
    //
    // Top "your plates" header share button now produces the WEEKLY
    // 2×3 collage (founder request 2026-06-18). Per-day section
    // headers carry a small inline share icon that produces THAT
    // day's 2×2 daily card — moved here from the top header so each
    // day is shareable individually.

    private func renderWeeklyShareImage() -> UIImage? {
        HandwrittenWeeklyShareRenderer.render(
            userId: userId,
            archetype: archetypeHint
        )
    }

    private func renderDailyShareImage(for dayStart: Date) -> UIImage? {
        HandwrittenDailyShareRenderer.render(
            for: dayStart,
            userId: userId,
            archetype: archetypeHint
        )
    }

    @ViewBuilder private var content: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, FoodTheme.Space.lg)
                .padding(.top, 12)
                .padding(.bottom, 8)

            if entries.isEmpty {
                emptyState
                    .padding(.horizontal, FoodTheme.Space.lg)
                    .padding(.top, 24)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                        ForEach(groupedDays, id: \.dayStart) { day in
                            dayHeader(for: day.dayStart, kcalTotal: day.kcalTotal)
                                .padding(.horizontal, FoodTheme.Space.lg)
                                .padding(.top, 18)
                                .padding(.bottom, 8)

                            // v1.0.9 D3.B — long-press-to-delete via a
                            // confirmation dialog (not swipe — swipe
                            // actions don't fire inside LazyVStack on
                            // iOS 26.2, would silently no-op). The
                            // dialog keeps an accidental-delete guard
                            // without dragging List's section chrome
                            // into the cream-backdrop layout.
                            ForEach(day.rows) { entry in
                                FoodLogRowView(
                                    entry: entry,
                                    heroNS: heroNS,
                                    photoHidden: selectedEntry?.id == entry.id
                                )
                                    .padding(.horizontal, FoodTheme.Space.lg)
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                                            selectedEntry = entry
                                        }
                                    }
                                    .onLongPressGesture(minimumDuration: 0.4) {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        pendingDeleteEntryId = entry.id
                                    }
                            }
                        }

                        // Bottom inset so the last row clears the
                        // floating + button.
                        Color.clear.frame(height: 110)
                    }
                }
                .scrollDismissesKeyboard(.immediately)
            }
        }
    }

    // MARK: - Header

    // App v2.3 — the masthead register (matches Today/Becoming/jeni):
    // tracked eyebrow above a full-serif title with the italic punch;
    // the close mark loses its ringed circle for the quiet thin mark.
    @ViewBuilder private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text("her food story")
                    .font(.custom("DMSans-Medium", size: 11))
                    .kerning(1.98)
                    .textCase(.uppercase)
                    .foregroundStyle(FoodTheme.textPrimary.opacity(0.48))
                (
                    Text("your ")
                        .font(.custom("JeniHeroSerif-Regular", size: 26))
                    + Text("plates")
                        .font(.custom("JeniHeroSerif-Italic", size: 26))
                )
                .foregroundStyle(FoodTheme.textPrimary)
                .kerning(-0.4)
            }

            Spacer()

            // v1.0.13 (2026-06-18) — top share button now produces
            // the WEEKLY 2×3 collage. Per-day rows carry their own
            // inline share affordance via dayHeader.
            if !entries.isEmpty {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if let img = renderWeeklyShareImage() {
                        shareItem = ShareItem(image: img)
                    }
                } label: {
                    HerShareLabel()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("share this week")
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(FoodTheme.textPrimary.opacity(0.72))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("close")
        }
    }

    // MARK: - Day header

    /// v1.1 journal grammar (Morsel-calibrated, 2026-06-11): eyebrow
    /// date + serif day word, with the day total demoted to "about
    /// N cal" caption register ("about" is the honesty word — photo
    /// estimates carry 20-30% error; a precise-looking total would
    /// over-claim).
    ///
    /// v1.0.13 (2026-06-18) — small inline share icon tucked next to
    /// the kcal total. Tapping renders THIS day's 2×2 collage and
    /// hands it to the same ShareActivityView the top weekly share
    /// uses; weekly stays on the top header.
    @ViewBuilder private func dayHeader(for dayStart: Date, kcalTotal: Double) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(eyebrowDate(for: dayStart))
                .font(.system(size: 11, weight: .medium))
                .kerning(1.4)
                .textCase(.uppercase)
                .foregroundStyle(FoodTheme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(dayLabel(for: dayStart))
                    .font(.custom("JeniHeroSerif-Regular", size: 26))
                    .foregroundStyle(FoodTheme.textPrimary)
                Spacer()
                // App v2.5 — the day reads as a pattern, not a sum:
                // protein leads, plates count, kcal stays honest with
                // "about" (photo estimates carry real error bars).
                Text(dayReceipt(for: dayStart, kcalTotal: kcalTotal))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FoodTheme.textSecondary)
                    .monospacedDigit()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if let img = renderDailyShareImage(for: dayStart) {
                        shareItem = ShareItem(image: img)
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .rotationEffect(.degrees(-12))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle().fill(Color(red: 0.24, green: 0.16, blue: 0.16))
                        )
                        .shadow(
                            color: Color(red: 0.24, green: 0.16, blue: 0.16).opacity(0.16),
                            radius: 0, x: 1, y: 1.5
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("share \(dayLabel(for: dayStart))")
            }
        }
    }

    /// "62g protein · 3 plates · about 1,420 cal" — protein first.
    private func dayReceipt(for dayStart: Date, kcalTotal: Double) -> String {
        let cal = Calendar.current
        let dayEntries = entries.filter { cal.isDate($0.loggedAt, inSameDayAs: dayStart) }
        let protein = Int(dayEntries.map(\.protein).reduce(0, +).rounded())
        var parts: [String] = []
        if protein > 0 { parts.append("\(protein)g protein") }
        parts.append(dayEntries.count == 1 ? "1 plate" : "\(dayEntries.count) plates")
        parts.append("about \(Int(kcalTotal.rounded())) cal")
        return parts.joined(separator: " · ")
    }

    private func eyebrowDate(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM d"
        return fmt.string(from: date)
    }

    private func dayLabel(for date: Date) -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        if cal.isDate(date, inSameDayAs: today) {
            return "today"
        }
        if cal.isDate(date, inSameDayAs: yesterday) {
            return "yesterday"
        }
        // The eyebrow carries the date; the day word stays short.
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE"
        return fmt.string(from: date).lowercased()
    }

    // MARK: - Empty state

    @ViewBuilder private var emptyState: some View {
        // Editorial empty state — the ribboned plate (founder-supplied
        // real-photo cutout) sets the table before her first log.
        VStack(spacing: 18) {
            Image("accent-plate-ribbon", bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("the table is set.")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22))
                    .foregroundStyle(FoodTheme.textPrimary)
                Text("tap the + to scan or jot what you ate.")
                    .font(.system(size: 14))
                    .foregroundStyle(FoodTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 36)
    }

    // MARK: - Floating + button

    @ViewBuilder private var floatingAddButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onAddTapped()
        } label: {
            ZStack {
                Circle()
                    .fill(FoodTheme.accent)
                    .frame(width: 60, height: 60)
                    .shadow(
                        color: FoodTheme.accent.opacity(0.35),
                        radius: 10, x: 0, y: 4
                    )

                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("add a log")
    }

    // MARK: - Day grouping

    private struct DayGroup: Identifiable {
        let dayStart: Date
        let rows: [FoodLogPersister.FoodLogEntry]
        var kcalTotal: Double { rows.reduce(0) { $0 + $1.kcal } }
        var id: Date { dayStart }
    }

    private var groupedDays: [DayGroup] {
        let cal = Calendar.current
        var buckets: [Date: [FoodLogPersister.FoodLogEntry]] = [:]
        for entry in entries {
            let day = cal.startOfDay(for: entry.loggedAt)
            buckets[day, default: []].append(entry)
        }
        return buckets
            .map { (day, rows) in
                DayGroup(
                    dayStart: day,
                    rows: rows.sorted { $0.loggedAt > $1.loggedAt }
                )
            }
            .sorted { $0.dayStart > $1.dayStart }
    }

    private func refresh() {
        entries = FoodLogPersister.allEntries(userId: userId)
    }

    // MARK: - Meal detail (v1.1 journal)

    /// The Morsel meal-detail anatomy on JeniFit paper: photo hero
    /// (morphed from the row matte), name, serif cal numeral,
    /// "22% of today · 8:14am" context, macro rows, quiet actions.
    @ViewBuilder private func mealDetail(for entry: FoodLogPersister.FoodLogEntry) -> some View {
        let dayTotal = dayKcalTotal(for: entry)
        ZStack {
            // Cream scrim — tap anywhere outside to morph back.
            FoodTheme.bgPrimary.opacity(0.97)
                .ignoresSafeArea()
                .onTapGesture { closeDetail() }

            VStack(spacing: 0) {
                Group {
                    if let photo = FoodPhotoStore.photo(entryId: entry.id) {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 264, height: 264)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(FoodTheme.bgElevated)
                                .frame(width: 264, height: 264)
                            Image(systemName: "fork.knife")
                                .font(.system(size: 44, weight: .regular))
                                .foregroundStyle(FoodTheme.textSecondary)
                        }
                    }
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(.white))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(FoodTheme.textPrimary.opacity(0.08), lineWidth: 0.5)
                )
                .matchedGeometryEffect(id: entry.id, in: heroNS)
                .shadow(color: FoodTheme.textPrimary.opacity(0.10), radius: 18, x: 0, y: 10)

                Text(entry.title.isEmpty ? "scanned plate" : entry.title.lowercased())
                    .font(.custom("JeniHeroSerif-Regular", size: 26))
                    .foregroundStyle(FoodTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FoodTheme.Space.lg)
                    .padding(.top, 22)

                // App v3.0 — protein leads the plate (the same
                // hierarchy as the band, the day receipts, and the
                // evening close). Calories fold into the context line
                // below: useful, never the headline. Protein-less
                // entries keep the kcal hero as the honest fallback.
                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    if Int(entry.protein.rounded()) > 0 {
                        Text("\(Int(entry.protein.rounded()))g")
                            .font(.custom("JeniHeroSerif-Regular", size: 40))
                            .monospacedDigit()
                            .foregroundStyle(FoodTheme.textPrimary)
                        Text("protein")
                            .font(.custom("JeniHeroSerif-Italic", size: 17))
                            .foregroundStyle(FoodTheme.accent)
                    } else {
                        Text("\(Int(entry.kcal.rounded()))")
                            .font(.custom("JeniHeroSerif-Regular", size: 40))
                            .monospacedDigit()
                            .foregroundStyle(FoodTheme.textPrimary)
                        Text("cal")
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundStyle(FoodTheme.textSecondary)
                    }
                }
                .padding(.top, 8)

                Text(detailContextLine(for: entry, dayTotal: dayTotal))
                    .font(.custom("DMSans-Medium", size: 12))
                    .kerning(0.6)
                    .foregroundStyle(FoodTheme.textSecondary)
                    .padding(.top, 4)

                if entry.protein + entry.carbs + entry.fat > 0 {
                    VStack(spacing: 10) {
                        detailMacroRow("protein", grams: entry.protein)
                        detailMacroRow("carbs", grams: entry.carbs)
                        detailMacroRow("fat", grams: entry.fat)
                    }
                    .padding(.horizontal, 44)
                    .padding(.top, 24)
                }

                // v1.2 — per-ingredient ledger for entries written by
                // the rebuilt snap flow (itemsDetail persisted). Older
                // entries simply don't show the block.
                if let detail = entry.itemsDetail, detail.count > 1 {
                    VStack(spacing: 6) {
                        ForEach(Array(detail.prefix(4).enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .firstTextBaseline) {
                                Text(item.name.lowercased())
                                    .font(.custom("DMSans-Regular", size: 12))
                                    .foregroundStyle(FoodTheme.textSecondary)
                                    .lineLimit(1)
                                Spacer(minLength: 10)
                                Text("\(Int(item.kcal.rounded())) cal")
                                    .font(.custom("DMSans-Regular", size: 12))
                                    .foregroundStyle(FoodTheme.textSecondary.opacity(0.85))
                                    .monospacedDigit()
                            }
                        }
                    }
                    .padding(.horizontal, 44)
                    .padding(.top, 16)
                }

                HStack(spacing: FoodTheme.Space.md) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        pendingDeleteEntryId = entry.id
                        closeDetail()
                    } label: {
                        Text("remove")
                            .font(.custom("DMSans-SemiBold", size: 14))
                            .foregroundStyle(FoodTheme.textSecondary)
                            .padding(.horizontal, 18)
                            .frame(height: 40)
                            .background(Capsule().stroke(FoodTheme.textPrimary.opacity(0.15), lineWidth: 1))
                    }

                    // v1.2 — one-tap relog. The same meal, kept again
                    // with a fresh timestamp; the "kept ♡" beat lands,
                    // then the detail closes onto the refreshed list.
                    Button {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        FoodLogPersister.relog(entry, userId: userId)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            closeDetail()
                        }
                    } label: {
                        (Text("again ")
                            .font(.custom("DMSans-SemiBold", size: 14))
                        + Text("\u{2661}")
                            .font(.custom("DMSans-Regular", size: 13)))
                            .foregroundStyle(FoodTheme.accent)
                            .padding(.horizontal, 18)
                            .frame(height: 40)
                            .background(Capsule().stroke(FoodTheme.accent.opacity(0.45), lineWidth: 1))
                    }
                    .accessibilityLabel("log this again")

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        closeDetail()
                    } label: {
                        Text("done")
                            .font(.custom("DMSans-SemiBold", size: 14))
                            .foregroundStyle(FoodTheme.bgPrimary)
                            .padding(.horizontal, 24)
                            .frame(height: 40)
                            .background(Capsule().fill(FoodTheme.textPrimary))
                    }
                }
                .padding(.top, 28)
            }
            .padding(.vertical, FoodTheme.Space.lg)
        }
        .transition(.opacity)
        .accessibilityAddTraits(.isModal)
    }

    private func closeDetail() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            selectedEntry = nil
        }
    }

    /// "22% of today · 8:14am" — context, never a verdict. The share
    /// line hides when this is the day's only entry (100% of one
    /// plate says nothing).
    private func detailContextLine(for entry: FoodLogPersister.FoodLogEntry, dayTotal: Double) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mma"
        fmt.amSymbol = "am"
        fmt.pmSymbol = "pm"
        let time = fmt.string(from: entry.loggedAt)
        let dayRows = entries.filter {
            Calendar.current.isDate($0.loggedAt, inSameDayAs: entry.loggedAt)
        }
        // v3.0 — with protein in the hero slot, calories live here:
        // present, honest ("about"), never the headline.
        let kcalPart = Int(entry.protein.rounded()) > 0
            ? "about \(Int(entry.kcal.rounded())) cal · " : ""
        guard dayRows.count > 1, dayTotal > 0 else { return kcalPart + time }
        let pct = Int((entry.kcal / dayTotal * 100).rounded())
        return "\(kcalPart)\(pct)% of the day · \(time)"
    }

    private func dayKcalTotal(for entry: FoodLogPersister.FoodLogEntry) -> Double {
        entries
            .filter { Calendar.current.isDate($0.loggedAt, inSameDayAs: entry.loggedAt) }
            .reduce(0) { $0 + $1.kcal }
    }

    /// Label · thin track bar · right-aligned grams. Relative scale
    /// caps at 60g protein / 80g carbs / 40g fat per plate so the
    /// bars read composition without claiming a target.
    private func detailMacroRow(_ label: String, grams: Double) -> some View {
        let cap: Double = label == "carbs" ? 80 : (label == "fat" ? 40 : 60)
        let fraction = min(1.0, grams / cap)
        return HStack(spacing: 12) {
            Text(label)
                .font(.custom("DMSans-Medium", size: 12))
                .foregroundStyle(FoodTheme.textSecondary)
                .frame(width: 56, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(FoodTheme.accentSubtle.opacity(0.6))
                    Capsule().fill(FoodTheme.accent)
                        .frame(width: max(4, geo.size.width * fraction))
                }
            }
            .frame(height: 4)
            Text("\(Int(grams.rounded()))g")
                .font(.custom("DMSans-Medium", size: 12))
                .monospacedDigit()
                .foregroundStyle(FoodTheme.textPrimary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - FoodLogRowView

private struct FoodLogRowView: View {

    let entry: FoodLogPersister.FoodLogEntry
    /// v1.1 journal — the photo matte is the morph source for the
    /// meal detail (matchedGeometryEffect within one hierarchy).
    var heroNS: Namespace.ID? = nil
    var photoHidden: Bool = false

    // App v2 (docs/app_v2/10_DESIGN_SYSTEM.md §plate catalog): the
    // journal row stops being a database row. Photo-forward 4:5
    // matte, serif title, and PROTEIN as the only macro at rest —
    // the `p · c · f` monospaced footnote (the MFP-era grammar the
    // brand rejects) lives only inside the detail view now.
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            iconBubble

            VStack(alignment: .leading, spacing: 3) {
                Text(displayTitle)
                    .font(.custom("Fraunces72pt-Regular", size: 16))
                    .foregroundStyle(FoodTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(timeLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(FoodTheme.textSecondary)
                    .monospacedDigit()

                if Int(entry.protein.rounded()) > 0 {
                    Text("\(Int(entry.protein.rounded()))g protein")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(FoodTheme.accent)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(Int(entry.kcal.rounded()))")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(FoodTheme.textPrimary)
                    .monospacedDigit()
                Text("cal")
                    .font(.system(size: 10))
                    .foregroundStyle(FoodTheme.textSecondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(FoodTheme.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(FoodTheme.textPrimary.opacity(0.07), lineWidth: 0.66)
        )
        .shadow(
            color: FoodTheme.textPrimary.opacity(0.04),
            radius: 5, x: 0, y: 2
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    /// v1.1 journal — her REAL plate photo in a white matte (the
    /// her75 polaroid cue: 3pt matte + hairline, one continuous
    /// radius) when one exists; photo-less entries (quick-add /
    /// dining-out / pre-photo-store history) get the source glyph in
    /// the SAME matte shape so the rhythm holds — never a grey
    /// placeholder, never the old pink circle.
    @ViewBuilder private var iconBubble: some View {
        // 4:5 magazine crop — the plate leads the row. Text-only
        // entries render a cream recipe-card mini (serif initial) so
        // the grid never shows a dead grey glyph.
        let matte = Group {
            if let photo = FoodPhotoStore.photo(entryId: entry.id) {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(FoodTheme.bgElevated)
                        .frame(width: 64, height: 80)
                    Text(String(displayTitle.prefix(1)))
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 24))
                        .foregroundStyle(FoodTheme.accent)
                }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FoodTheme.textPrimary.opacity(0.08), lineWidth: 0.5)
        )

        Group {
            if let heroNS {
                matte
                    .matchedGeometryEffect(id: entry.id, in: heroNS, isSource: !photoHidden)
                    .opacity(photoHidden ? 0 : 1)
            } else {
                matte
            }
        }
        .accessibilityHidden(true)
    }

    private var displayTitle: String {
        let trimmed = entry.title.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "scanned plate" : trimmed.lowercased()
    }

    private var timeLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mma"
        fmt.amSymbol = "am"
        fmt.pmSymbol = "pm"
        return fmt.string(from: entry.loggedAt)
    }

    private var accessibilityLabel: String {
        let title = displayTitle
        let time = timeLabel
        let kcal = Int(entry.kcal.rounded())
        return "\(title), \(time), \(kcal) calories"
    }
}

#endif  // canImport(UIKit)
