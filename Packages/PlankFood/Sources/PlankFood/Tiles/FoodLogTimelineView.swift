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
        onAddTapped: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.userId = userId
        self.dailyTarget = dailyTarget
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
        .onAppear { refresh() }
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

    @ViewBuilder private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            // v1.1 journal — "plates" is the surface's name now
            // (Becoming's teaser says "her plates"; in here it's hers
            // in first person). Serif italic punch per voice lock.
            (
                Text("your ")
                    .font(.custom("DMSans-Regular", size: 22))
                + Text("plates")
                    .font(.custom("JeniHeroSerif-Italic", size: 26))
            )
            .foregroundStyle(FoodTheme.textPrimary)

            Spacer()

            // v1.0.9 D3.C — share button. Renders the daily 9:16
            // card via ImageRenderer on tap (lazy — we don't want to
            // re-render on every log change). Hidden when the day is
            // empty (no content to share).
            if !entries.isEmpty {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if let img = DailyShareRenderer.render(
                        userId: userId,
                        dailyTarget: dailyTarget
                    ) {
                        shareItem = ShareItem(image: img)
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FoodTheme.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.6), in: Circle())
                        .overlay(
                            Circle().stroke(FoodTheme.accent.opacity(0.35), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("share today")
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FoodTheme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.6), in: Circle())
                    .overlay(
                        Circle().stroke(FoodTheme.accent.opacity(0.35), lineWidth: 1)
                    )
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
                Text("about \(Int(kcalTotal.rounded())) cal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FoodTheme.textSecondary)
                    .monospacedDigit()
            }
        }
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
        VStack(alignment: .leading, spacing: 8) {
            Text("nothing logged yet.")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22))
                .foregroundStyle(FoodTheme.textPrimary)
            Text("tap the + to scan or jot what you ate.")
                .font(.system(size: 14))
                .foregroundStyle(FoodTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text("\(Int(entry.kcal.rounded()))")
                        .font(.custom("JeniHeroSerif-Regular", size: 40))
                        .monospacedDigit()
                        .foregroundStyle(FoodTheme.textPrimary)
                    Text("cal")
                        .font(.custom("DMSans-Regular", size: 15))
                        .foregroundStyle(FoodTheme.textSecondary)
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
        guard dayRows.count > 1, dayTotal > 0 else { return time }
        let pct = Int((entry.kcal / dayTotal * 100).rounded())
        return "\(pct)% of the day · \(time)"
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

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            iconBubble

            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle)
                    .font(.custom("Fraunces72pt-Regular", size: 15))
                    .foregroundStyle(FoodTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(timeLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(FoodTheme.textSecondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(entry.kcal.rounded())) kcal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FoodTheme.textPrimary)
                    .monospacedDigit()
                macroLine
                    .foregroundStyle(FoodTheme.textSecondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FoodTheme.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FoodTheme.accent.opacity(0.18), lineWidth: 1)
        )
        .shadow(
            color: FoodTheme.textPrimary.opacity(0.06),
            radius: 0, x: 2, y: 2
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
        let matte = Group {
            if let photo = FoodPhotoStore.photo(entryId: entry.id) {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(FoodTheme.bgElevated)
                        .frame(width: 56, height: 56)
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(FoodTheme.textSecondary)
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

    /// Matches CaptureSource raw values from CapturedFood.swift —
    /// "photo" / "quick_add" / "im_out" / "text" etc. SF Symbols
    /// chosen to read at small bubble size (40pt) without color tint.
    private var iconName: String {
        switch entry.source {
        case "im_out":              return "fork.knife"
        case "quick_add", "text":   return "pencil"
        case "photo":               return "camera"
        case "restaurant_estimate": return "fork.knife"
        default:                    return "fork.knife.circle"
        }
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

    @ViewBuilder private var macroLine: some View {
        let p = Int(entry.protein.rounded())
        let c = Int(entry.carbs.rounded())
        let f = Int(entry.fat.rounded())
        // Render the macro footnote only when there's something to
        // show — pre-D3.B entries (no macros) just show kcal.
        if p + c + f > 0 {
            Text("p \(p) · c \(c) · f \(f)")
                .font(.system(size: 11))
                .monospacedDigit()
        }
    }

    private var accessibilityLabel: String {
        let title = displayTitle
        let time = timeLabel
        let kcal = Int(entry.kcal.rounded())
        return "\(title), \(time), \(kcal) calories"
    }
}

#endif  // canImport(UIKit)
