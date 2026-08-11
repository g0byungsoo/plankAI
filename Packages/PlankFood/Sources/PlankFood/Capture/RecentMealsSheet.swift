#if canImport(UIKit)
import SwiftUI

// MARK: - RecentMealsSheet
//
// v1.2 snap-food rebuild (2026-07-01) — the "again" mode. Most meals
// are repeats; the fastest and most accurate log is a one-tap relog of
// a meal she's already corrected once. MacroFactor's tap-count math
// and Cal AI's bookmark-relog both converge here — JeniFit's version
// is a quiet cream sheet, newest plates first, one tap to keep.
//
// Tap → persist (fresh timestamp) → a soft "kept ♡" beat on the row →
// the whole capture flow dismisses. No confirmation modal: the act is
// tiny, reversible from the journal, and the sheet closing IS the
// receipt.

public struct RecentMealsSheet: View {

    let userId: String
    /// Analytics surface tag ("chooser" today; the debug harness
    /// passes its own).
    let surface: String
    /// Called after a relog persists; host dismisses the capture flow.
    let onLogged: () -> Void
    let onClose: () -> Void

    @State private var meals: [FoodLogPersister.FoodLogEntry] = []
    @State private var keptId: String? = nil

    public init(
        userId: String,
        surface: String = "chooser",
        onLogged: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.userId = userId
        self.surface = surface
        self.onLogged = onLogged
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 6)

            if meals.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(Array(meals.enumerated()), id: \.element.id) { idx, meal in
                            mealRow(meal)
                            if idx < meals.count - 1 {
                                Rectangle()
                                    .fill(FoodTheme.textPrimary.opacity(0.08))
                                    .frame(height: 0.5)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(FoodTheme.bgPrimary.ignoresSafeArea())
        .onAppear {
            meals = FoodLogPersister.recentMeals(userId: userId, limit: 6)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            (Text("add it ")
                .font(.custom("JeniHeroSerif-Regular", size: 24))
            + Text("again")
                .font(.custom("JeniHeroSerif-Italic", size: 24)))
                .foregroundStyle(FoodTheme.textPrimary)
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(FoodTheme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(Color.black.opacity(0.05), in: Circle())
            }
            .accessibilityLabel("close")
        }
    }

    // MARK: - Rows

    @ViewBuilder private func mealRow(_ meal: FoodLogPersister.FoodLogEntry) -> some View {
        let isKept = keptId == meal.id
        Button {
            guard keptId == nil else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeOut(duration: 0.22)) { keptId = meal.id }
            FoodLogPersister.relog(meal, userId: userId)
            FoodAnalytics.track(.relogUsed, properties: ["surface": surface])
            // Let the "kept ♡" beat land before the flow closes.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                onLogged()
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(meal.title.lowercased())
                        .font(.custom("DMSans-Medium", size: 15))
                        .foregroundStyle(FoodTheme.textPrimary)
                        .lineLimit(1)
                    Text(subtitle(meal))
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundStyle(FoodTheme.textSecondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 8)
                if isKept {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                        Text("kept")
                            .font(.custom("DMSans-Medium", size: 13))
                    }
                    .foregroundStyle(FoodTheme.accent)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FoodTheme.textPrimary.opacity(0.45))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.65)))
                        .overlay(Circle().stroke(FoodTheme.textPrimary.opacity(0.10), lineWidth: 0.75))
                }
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("log \(meal.title) again")
    }

    private func subtitle(_ meal: FoodLogPersister.FoodLogEntry) -> String {
        // "kcal", matching the reading + the recap (one unit word
        // across the product).
        var parts = ["\(Int(meal.kcal.rounded())) kcal"]
        if meal.protein > 0 { parts.append("\(Int(meal.protein.rounded()))g protein") }
        parts.append(relativeDay(meal.loggedAt))
        return parts.joined(separator: "  \u{00B7}  ")
    }

    private func relativeDay(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "today" }
        if cal.isDateInYesterday(date) { return "yesterday" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: date),
                                      to: cal.startOfDay(for: Date())).day ?? 0
        return days <= 7 ? "\(days) days ago" : "a while back"
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            (Text("your plates will ")
                .font(.custom("JeniHeroSerif-Regular", size: 19))
            + Text("gather")
                .font(.custom("JeniHeroSerif-Italic", size: 19))
            + Text(" here")
                .font(.custom("JeniHeroSerif-Regular", size: 19)))
                .foregroundStyle(FoodTheme.textPrimary)
            Text("add a meal once and it's one tap forever.")
                .font(.custom("DMSans-Regular", size: 13))
                .foregroundStyle(FoodTheme.textSecondary)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }
}
#endif
