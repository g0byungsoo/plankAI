import SwiftUI
import UIKit
import UserNotifications

// MARK: - Gradient Blob Background

/// Animated gradient blob that floats behind content. Each screen gets a unique color combo.
struct GradientBlob: View {
    let colors: [Color]
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [colors[i % colors.count].opacity(0.3), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 200
                        )
                    )
                    .frame(width: 300, height: 300)
                    .offset(
                        x: sin(phase + Double(i) * 2.1) * 60,
                        y: cos(phase + Double(i) * 1.7) * 40
                    )
                    .blur(radius: 60)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Answer Feedback Toast

/// Brief conversational feedback that appears after selecting an answer.
struct AnswerFeedback: View {
    let message: String
    @State private var show = false

    var body: some View {
        if show {
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.textInverse)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Palette.bgInverse.opacity(0.85))
                .clipShape(Capsule())
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .onAppear {
                    Haptics.soft()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeOut(duration: 0.3)) { show = false }
                    }
                }
        }
    }

    func trigger() -> AnswerFeedback {
        var copy = self
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                // This won't work on the copy — we use the binding approach instead
            }
        }
        return copy
    }
}

// MARK: - Photo Placeholder

/// Placeholder for stock fitness photos. Shows a gradient until real photo is added.
/// Usage: PhotoSlot("fitness-plank-hero") — looks for image in asset catalog, falls back to gradient.
struct PhotoSlot: View {
    let name: String
    let height: CGFloat
    private let assetExists: Bool

    init(_ name: String, height: CGFloat = 200) {
        self.name = name
        self.height = height
        self.assetExists = UIImage(named: name) != nil
    }

    var body: some View {
        Group {
            if assetExists {
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Gradient placeholder until real photo is added
                LinearGradient(
                    colors: [Palette.accentSubtle.opacity(0.3), Palette.accent.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    VStack(spacing: 4) {
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundStyle(Palette.textSecondary.opacity(0.4))
                        Text(name)
                            .font(.system(size: 10))
                            .foregroundStyle(Palette.textSecondary.opacity(0.3))
                    }
                )
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }
}

// MARK: - Confetti

struct ConfettiView: View {
    @State private var particles: [(id: Int, x: CGFloat, y: CGFloat, color: Color, size: CGFloat, rot: Double)] = []
    @State private var animate = false

    private let colors: [Color] = [
        Palette.accent, Palette.stateGood, Palette.accentSubtle,
        Palette.stateWarn, .white, Palette.textPrimary
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles, id: \.id) { p in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(p.color)
                        .frame(width: p.size, height: p.size * 0.4)
                        .rotationEffect(.degrees(animate ? p.rot + 360 : p.rot))
                        .position(x: p.x, y: animate ? geo.size.height + 50 : p.y)
                        .opacity(animate ? 0 : 1)
                }
            }
            .onAppear {
                particles = (0..<30).map { i in
                    (id: i,
                     x: CGFloat.random(in: 0...geo.size.width),
                     y: CGFloat.random(in: -100...geo.size.height * 0.3),
                     color: colors.randomElement()!,
                     size: CGFloat.random(in: 6...14),
                     rot: Double.random(in: 0...360))
                }
                withAnimation(.easeIn(duration: 2.5)) { animate = true }
            }
        }
    }
}

// MARK: - Notification Permission

struct NotificationPermission {
    /// Canonical identifier for the user's daily workout reminder.
    /// Both schedulers (onboarding completion + Settings tab) write to
    /// this so changing the time later doesn't leave a duplicate
    /// pending. The legacy `daily-plank` identifier (from the
    /// pre-JeniFit rebrand) is also removed during scheduling — covers
    /// users who set the reminder before this fix shipped.
    static let dailyReminderIdentifier = "daily_reminder"
    private static let legacyIdentifier = "daily-plank"

    static func request() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            return false
        }
    }

    /// iOS shows the system dialog ONCE per install. After a prior
    /// denial, `requestAuthorization` resolves silently and the tap
    /// reads as broken (founder QA 2026-06-11). Route that case to the
    /// app's notification settings instead; already-granted resolves
    /// true without a dialog.
    @MainActor
    static func requestOrOpenSettings() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                _ = await UIApplication.shared.open(url)
            }
            return false
        default:
            return await request()
        }
    }

    /// Schedule the daily reminder at `time`. Idempotent — calling
    /// twice with different times replaces the prior pending request
    /// (single identifier) and clears any legacy `daily-plank`. Body
    /// adapts to the selected coach so the reminder reads in the same
    /// voice the user picked in onboarding.
    static func scheduleDailyReminder(at time: Date) {
        let center = UNUserNotificationCenter.current()
        // Remove BOTH the canonical and legacy identifiers — surgical,
        // doesn't touch the trial-end notification (different id) the
        // way removeAllPendingNotificationRequests() would have.
        center.removePendingNotificationRequests(withIdentifiers: [
            dailyReminderIdentifier,
            legacyIdentifier
        ])

        let content = UNMutableNotificationContent()
        // v2 (2026-06-16): dropped "today's short session." — "session"
        // is workout-coded and fights the diet-first product pivot. New
        // title is voice-agnostic + content-neutral, leaves the body to
        // carry the voice signal. Per the notification system spec,
        // body rotation across the week is a future improvement; for
        // now the body is voice-routed (encouraging/balanced/firm) but
        // single-string per voice — re-evaluates on each reschedule().
        content.title = "five minutes, today."
        content.body = dailyReminderBody()
        content.sound = .default

        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = calendar.component(.hour, from: time)
        components.minute = calendar.component(.minute, from: time)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: dailyReminderIdentifier,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    /// Voice-adaptive body. Pulls `voicePreference` from UserDefaults
    /// (same key NotificationSettingsView uses) so the reminder reads in
    /// the trainer's voice. Gentle-return register. Never uses labor
    /// verbs (work, push, grind), challenge language (don't break your
    /// streak), or imperatives. Lowercase matches in-app brand voice on
    /// the lock screen. v2 (2026-06-16): added name opener for
    /// consistency with other surfaces; tightened balanced + firm
    /// strings; dropped "easy to finish" (read as effort-pressure).
    private static func dailyReminderBody() -> String {
        let name = (UserDefaults.standard.string(forKey: "userName") ?? "").lowercased()
        let opener = name.isEmpty ? "" : "\(name), "
        let pref = UserDefaults.standard.string(forKey: "voicePreference") ?? "encouraging"
        switch pref {
        case "encouraging": return "\(opener)small moves still count. they always have ♥"
        case "balanced":    return "\(opener)sam picked a short one. open when you can."
        default:            return "\(opener)kira's got a short one ready."
        }
    }
}

// MARK: - FirstWeekPreview (v9 P9.1 → v1.1 program-real rewrite)
//
// The "your first week" strip the user holds before the paywall.
// REWRITTEN 2026-06-23 to mirror the program the app actually runs,
// not a workout-only mock. The old version called WorkoutGenerator
// once per workout day with identical input, so every tile collapsed
// to the same name + same duration (it read as one workout repeated),
// and it showed the raw session-length pref instead of the real
// tier-ramped minutes.
//
// The honest — and far more convincing — week:
//
//   • Day identity = ProgramDayArchetype.standardRotation (P-M-P-B-P-B-R),
//     the exact rotation Home frames every day with ("today is a
//     protein day"). The week reads as a real rhythm of nutrition,
//     movement, and recovery, not seven identical cards.
//   • Workout cadence = IntensityProfile.sessionsPerWeek (3 / 4 / 5 by
//     tier). The movement day always carries a workout; the rest day
//     (Sun) never does.
//   • Workout minutes = IntensityProfile.workoutMinutes(forProgramWeek: 1)
//     — the real week-1 value (soft 7 / medium 10 / hard 15).
//
// Every value traces to a shipping system, so the preview IS the
// program ([[feedback-data-provenance]]). Off-days reference only
// shipping features — snap (food rail) + breathe (breathwork)
// ([[feedback-no-feature-promises-until-shipped]]). Tiles deal in on a
// left→right cascade for a "plan being laid down" beat (reduce-motion
// settles instantly).

struct FirstWeekDay: Identifiable {
    let id = UUID()
    let weekdayLabel: String          // "mon" / "tue" / ...
    let archetype: ProgramDayArchetype
    let detailLine: String            // "10 min workout" / "snap + breathe"
    let isWorkoutDay: Bool
}

struct FirstWeekPreview: View {

    let tier: IntensityTier
    private let days: [FirstWeekDay]

    init(tier: IntensityTier) {
        self.tier = tier
        self.days = Self.makeDays(for: tier)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(days.enumerated()), id: \.element.weekdayLabel) { idx, day in
                    DayTile(day: day, index: idx)
                }
            }
            .padding(.horizontal, Space.screenPadding)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("your first week preview")
    }

    private static func makeDays(for tier: IntensityTier) -> [FirstWeekDay] {
        let labels = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
        let rotation = ProgramDayArchetype.standardRotation
        let workoutDays = workoutWeekdays(for: tier)
        let minutes = IntensityProfile.from(tier: tier).workoutMinutes(forProgramWeek: 1)
        return labels.enumerated().map { idx, label in
            let arch = rotation[idx]
            let isWorkout = workoutDays.contains(idx)
            let detail: String
            if isWorkout {
                detail = "\(minutes) min workout"
            } else if arch == .rest {
                detail = "breathe + reflect"
            } else {
                detail = "snap + breathe"
            }
            return FirstWeekDay(
                weekdayLabel: label,
                archetype: arch,
                detailLine: detail,
                isWorkoutDay: isWorkout
            )
        }
    }

    /// Weekdays that carry a workout. Count == IntensityProfile
    /// .sessionsPerWeek (3 / 4 / 5); always includes the movement day
    /// (index 1), never the rest day (index 6). The program scheduler
    /// picks the exact calendar days — the cadence + the never-on-rest
    /// rule are the honest invariants the preview surfaces.
    static func workoutWeekdays(for tier: IntensityTier) -> Set<Int> {
        switch tier {
        case .soft:   return [1, 3, 5]              // 3/wk — Tue Thu Sat
        case .medium: return [0, 1, 3, 5]           // 4/wk — Mon Tue Thu Sat
        case .hard:   return [0, 1, 2, 3, 5]        // 5/wk — Mon Tue Wed Thu Sat
        }
    }
}

// MARK: - DayTile
//
// One day of the first-week strip. Carries the archetype identity
// (Fraunces title + a quiet SF Symbol glyph) and the day's concrete
// anchor. Workout days take the brand-accent border + accent glyph so
// the active days read at a glance; lighter days recede to a divider
// hairline. Each tile deals in on a per-index delay for the cascade.

private struct DayTile: View {
    let day: FirstWeekDay
    let index: Int

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 4) {
                Text(day.weekdayLabel)
                    .font(Typo.eyebrow)
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
                Spacer(minLength: 0)
                Image(systemName: day.archetype.glyphName)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(day.isWorkoutDay ? Palette.accent : Palette.cocoaTertiary)
            }
            Spacer(minLength: 6)
            Text(title)
                .font(.custom("Fraunces72pt-SemiBold", size: 18, relativeTo: .headline))
                .foregroundStyle(Palette.cocoaPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(day.detailLine)
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaSecondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(width: 150, height: 132, alignment: .topLeading)
        .scrapbookCard(tint: day.isWorkoutDay ? Palette.accent : Palette.divider)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .task {
            guard !appeared else { return }
            if reduceMotion { appeared = true; return }
            let delay = 0.30 + Double(index) * 0.06
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            withAnimation(Motion.entranceSoft) { appeared = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(day.weekdayLabel), \(title), \(day.detailLine)")
    }

    private var title: String {
        switch day.archetype {
        case .protein:  return "protein"
        case .movement: return "movement"
        case .balanced: return "balanced"
        case .rest:     return "rest"
        }
    }
}

// MARK: - Animated SF Symbol

/// Wraps an SF Symbol with entrance animation.
struct AnimatedIcon: View {
    let name: String
    let size: CGFloat
    @State private var appeared = false

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size))
            .foregroundStyle(Palette.textPrimary)
            .symbolEffect(.bounce, value: appeared)
            .scaleEffect(appeared ? 1.0 : 0.5)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    appeared = true
                }
            }
    }
}
