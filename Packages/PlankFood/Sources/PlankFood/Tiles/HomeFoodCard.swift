#if canImport(UIKit)
import SwiftUI

// MARK: - HomeFoodCard
//
// Per v5 Home redesign + D33: food card hero for Slot 4 of HomeView.
// Replaces the StepsPulseTile-only Slot 4 with a food-first card
// (because food usage will exceed workout usage per founder thesis),
// with steps + breath pills demoted to lateral siblings (rendered
// by the parent TodayHealthStrip composite).
//
// V1.0.7 STOP-GAP (2026-06-04): originally used SwiftData @Query
// over FoodLogRecord but cross-package @Model integration caused
// the app to hang on launch. Reads from FoodLogPersister's in-
// memory store instead. Data lost across app restart in v1.0.7;
// v1.0.8 ships proper SwiftData integration with explicit migration
// plan.

public struct HomeFoodCard: View {

    public let userId: String
    public let dailyTarget: Double
    public let onTap: () -> Void

    @State private var todayKcal: Double = 0
    @State private var weeklyAvg: Double? = nil

    public init(
        userId: String,
        dailyTarget: Double,
        onTap: @escaping () -> Void
    ) {
        self.userId = userId
        self.dailyTarget = dailyTarget
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: FoodTheme.Space.md) {
                    header

                    if todayKcal == 0 {
                        emptyState
                    } else {
                        WeeklyAvgBar(
                            todayKcal: todayKcal,
                            dailyTarget: dailyTarget,
                            weeklyAvgKcal: weeklyAvg
                        )

                        if isEveningReviewWindow {
                            eveningReviewLine
                        }
                    }

                    Spacer(minLength: 0)

                    addCTAPill
                }
                .padding(FoodTheme.Space.lg)
                .frame(maxWidth: .infinity, alignment: .leading)

                // v1.0.7 founder feedback round 5 (2026-06-06) per
                // Lasta WL designer brief: cherries 56pt sticker
                // top-right -12° overlap. The cute anchor for the
                // food card. sparkleGlossy 14pt bottom-left adds
                // the second beat (Lasta's two-sticker rule for the
                // visual signature card). Both via Bundle.main
                // since PlankFood is a leaf package.
                Image("sticker_cherries", bundle: .main)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-12))
                    .opacity(0.95)
                    .offset(x: 10, y: -12)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .background(
                // v1.0.7 Lasta treatment — solid accentSubtle
                // (#F5D5D8) fill, 28pt radius. "Pink + outline reads
                // weak" — solid pink fill carries the warmth so the
                // cocoa pill below stays the sole CTA without
                // chrome competition. The card becomes Home's
                // visual signature.
                Color(red: 245/255, green: 213/255, blue: 216/255)
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                Image("sticker_sparkle_glossy", bundle: .main)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .opacity(0.85)
                    .padding(.leading, 14)
                    .padding(.bottom, 12)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("tap to log a meal")
        .onAppear { refresh() }
        .onReceive(FoodLogPersister.changeNotifier) { _ in refresh() }
    }

    /// Solid jeweledRose pink CTA pill — replaces the old quiet
    /// tapHint per Lasta's verdict: "Pink + outline reads weak;
    /// solid jeweledRose ('+ add ↗') is the right register on a
    /// pink card." Italic-Fraunces punch on "add" (copy word).
    @ViewBuilder private var addCTAPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .bold))
            Text("add")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color(red: 122/255, green: 46/255, blue: 63/255)) // jeweledRose #7A2E3F
        .clipShape(Capsule())
    }

    // MARK: - Evening review

    /// 7pm-11pm local. The 8:30pm push lands in this window; the home
    /// card stays in evening-review state for ~4h around it so a user
    /// who opens late still sees the review surface.
    private var isEveningReviewWindow: Bool {
        let hour = Calendar.current.component(.hour, from: Date.now)
        return (19...22).contains(hour)
    }

    @ViewBuilder private var eveningReviewLine: some View {
        Text(eveningReviewCopy)
            .font(.system(size: 13))
            .foregroundStyle(FoodTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
    }

    /// Voice-locked reflection line. Branches on today vs target so the
    /// register matches the day. No shame anywhere — over-target reads
    /// as "happens" not "you failed" (anti-shame food UX lock per
    /// feedback_food_ux_antishame).
    private var eveningReviewCopy: String {
        guard dailyTarget > 0 else {
            return "today, logged. tomorrow opens fresh ♥"
        }
        let ratio = todayKcal / dailyTarget
        if ratio < 0.7 {
            return "easy today. listen to hunger tomorrow ♥"
        } else if ratio < 1.05 {
            return "today's gentle. tomorrow opens fresh ♥"
        } else if ratio < 1.25 {
            return "a bit more today — happens. tomorrow resets ♥"
        } else {
            return "today was a higher one. tomorrow resets ♥"
        }
    }

    // MARK: - Subviews

    /// v1.0.7 Lasta-treatment header — italic-Fraunces "*what you
    /// ate*" eyebrow in jeweledRose. The emoji + Fraunces SemiBold
    /// "today's plate" combo from v1.0.6 retired; the card's
    /// 56pt cherries sticker now carries the food semantic cue,
    /// so the eyebrow can compress to a single editorial line.
    @ViewBuilder private var header: some View {
        HStack(spacing: 0) {
            (Text("what you ")
                .font(.custom("DMSans-Regular", size: 13))
             + Text("ate")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13)))
                .foregroundStyle(Color(red: 122/255, green: 46/255, blue: 63/255)) // jeweledRose
                .textCase(.lowercase)
            Spacer(minLength: 0)
        }
    }

    /// v1.0.7 §6 editorial empty state. Inline implementation
    /// (PlankFood is a leaf package and can't import the app's
    /// EditorialEmptyState component) — same locked pattern:
    /// italic-Fraunces headline + DM Sans CTA + signature
    /// sticker (cherries, top-right). 22pt headline instead of
    /// 28pt because the card is constrained chrome, not a full-
    /// screen mark. No hairline rule for the same reason — the
    /// card's own border already serves as the section break.
    /// v1.0.7 Lasta-treatment empty state. Card's 56pt overlapping
    /// cherries already carries the visual food cue; the empty
    /// state copy alone — italic-Fraunces "*the table is set.*"
    /// headline + DM Sans hint — handles the editorial moment.
    /// No second sticker inside the content (the chrome stickers
    /// already pull weight).
    @ViewBuilder private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("the table is set.")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22))
                .foregroundStyle(FoodTheme.textPrimary)
            Text("tap to log your first plate.")
                .font(.system(size: 13))
                .foregroundStyle(FoodTheme.textSecondary)
        }
        .padding(.vertical, FoodTheme.Space.sm)
    }

    @ViewBuilder private var tapHint: some View {
        HStack(spacing: 4) {
            Text("tap to log")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(FoodTheme.textSecondary)
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(FoodTheme.textSecondary)
        }
    }

    // MARK: - Refresh

    private func refresh() {
        let (today, weekly) = FoodLogPersister.todayAndWeekly(userId: userId)
        todayKcal = today
        weeklyAvg = weekly
    }

    private var accessibilityLabel: String {
        if todayKcal == 0 {
            return "today's plate. the table is set. tap the camera to begin."
        }
        return "today's plate, \(Int(todayKcal.rounded())) calories logged today"
    }
}
#endif  // canImport(UIKit)
