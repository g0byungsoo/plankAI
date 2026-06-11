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
    @State private var shareImage: UIImage? = nil
    @State private var showShareSheet: Bool = false

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
        }
        .onAppear { refresh() }
        .onReceive(FoodLogPersister.changeNotifier) { _ in refresh() }
        // v1.0.9 D3.C — UIActivityViewController share sheet, hosted
        // via a SwiftUI sheet. Reusing the existing ShareSheet UIKit
        // wrapper pattern from PhotoCaptureView's result share would
        // mean importing it across files; for one call site, inline
        // the wrap.
        .sheet(isPresented: $showShareSheet) {
            if let img = shareImage {
                ShareActivityView(items: [img], onComplete: {
                    showShareSheet = false
                })
                .ignoresSafeArea()
            }
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
                                FoodLogRowView(entry: entry)
                                    .padding(.horizontal, FoodTheme.Space.lg)
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
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
            // Italic-Fraunces punch word on "log" per voice lock.
            (
                Text("your ")
                    .font(.custom("DMSans-Regular", size: 22))
                + Text("log")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 26))
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
                    shareImage = DailyShareRenderer.render(
                        userId: userId,
                        dailyTarget: dailyTarget
                    )
                    showShareSheet = (shareImage != nil)
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
}

// MARK: - FoodLogRowView

private struct FoodLogRowView: View {

    let entry: FoodLogPersister.FoodLogEntry

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
        Group {
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
