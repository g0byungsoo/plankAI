import SwiftUI
import UIKit
import UserNotifications

// MARK: - OnboardingAtmosphere
//
// The premium ambient background for the onboarding question flow (v1.1
// "quiet luxury" pass). A cream rect with the `onboardingAtmosphere` Metal
// shader: three glacially-drifting warm-light pools + a fine breathing
// grain, so the background feels alive and considered without ever
// competing with the question copy. Texture-free + closed-form, so it's
// cheap (same approach as the JeniMethod PaperCanvas). Reduce-Motion
// freezes the drift + grain (time = 0) — still renders, just static. The
// cream fill is always present, so even if the shader no-ops the bg holds.
struct OnboardingAtmosphere: View {
    /// Max blend toward the warm tints at a light pool's center. 0.14
    /// reads as a whisper of warmth, not a gradient.
    var intensity: Float = 0.14
    var base: Color = Palette.bgPrimary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { ctx in
                let t = reduceMotion
                    ? Float(0)
                    : Float(ctx.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: 3600))
                Rectangle()
                    .fill(base)
                    .colorEffect(ShaderLibrary.onboardingAtmosphere(
                        .float(t),
                        .float(intensity),
                        .float2(Float(geo.size.width), Float(geo.size.height))
                    ))
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Scroll Edge Fade
//
// v1.1 polish (2026-06-26): a soft dissolve at the top & bottom edges of an
// internally-scrolling list, so cards melt into the canvas when scrolled
// past instead of hard-cutting at the ScrollView's clip boundary. The fade
// bands are fixed-height and live INSIDE the scroll's content inset, so a
// card at rest is never dimmed — only content that scrolls into the band
// dissolves. Pairs with the option-list top/bottom padding in jfQuestion /
// jfMulti (the padding clears the first/last card's border + shadow; this
// makes the scroll motion feel premium rather than clipped).
struct ScrollEdgeFade: ViewModifier {
    var top: CGFloat = 16
    var bottom: CGFloat = 22

    func body(content: Content) -> some View {
        content.mask(
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: top)
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: bottom)
            }
        )
    }
}

extension View {
    /// Softly fades the top & bottom edges of a scrolling region so content
    /// dissolves at the clip boundary instead of shearing off.
    func scrollEdgeFade(top: CGFloat = 16, bottom: CGFloat = 22) -> some View {
        modifier(ScrollEdgeFade(top: top, bottom: bottom))
    }
}

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
    // MARK: Day-1 promise notification

    /// Canonical identifier for the one-shot Day-1 promise nudge.
    static let day1PromiseIdentifier = "day1_promise"

    /// Pure body builder - replays the user's own words back to her.
    /// No nagging, no imperatives. Period between anchor + action clauses
    /// (no em-dash per brand voice).
    static func day1PromiseBody(action: String, anchor: String, userName: String?) -> String {
        let who = (userName?.isEmpty == false) ? "\(userName!), " : ""
        return "\(who)it's your \(anchor) moment. you said you'd \(action). ready when you are \u{2665}"
    }

    /// One-shot Day-1 nudge in her own words, at the time she chose in the ritual.
    static func scheduleDay1Promise(at date: Date, body: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [day1PromiseIdentifier])
        let content = UNMutableNotificationContent()
        content.title = "tomorrow, you begin."
        content.body = body
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(.init(identifier: day1PromiseIdentifier, content: content, trigger: trigger))
    }

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

// MARK: - Safety screening (v1.2 medical-grade Phase 1, 2026-06-25)
//
// SCOFF eating-disorder screen + crisis resources, anti-shame and
// wellness-side ("a gentle check, first" — never a diagnosis). Scoring +
// routing live in `ProgramGoalCalculator.safetyAssessment`; this is the UI.
// Housed in OnboardingComponents for now (zero new-file/pbxproj risk);
// extract to Views/Safety/ later. Spec:
// docs/medical_grade_implementation_spec_2026_06_25.md

/// SCOFF (Morgan 1999): five yes/no items, >= 2 yes = positive screen.
struct SCOFFScreenView: View {
    /// Called once all answered, with (totalYes, coreYes). `coreYes`
    /// excludes the two GLP-1-expected items (rapid unintentional loss +
    /// food dominates), so the safety gate can screen a current GLP-1 user
    /// on genuine ED signals without false-positiving expected drug effects
    /// (T3 / T7). Callers that don't need the split can ignore the second
    /// value.
    let onComplete: (_ totalYes: Int, _ coreYes: Int) -> Void

    private struct SCOFFItem: Identifiable { let id: Int; let text: String }
    private let items: [SCOFFItem] = [
        .init(id: 0, text: "do you ever make yourself sick because you feel uncomfortably full?"),
        .init(id: 1, text: "do you worry you have lost control over how much you eat?"),
        .init(id: 2, text: "have you recently lost more than 6 kg (about 13 lb) in three months?"),
        .init(id: 3, text: "do you believe yourself to be fat when others say you are thin?"),
        .init(id: 4, text: "would you say that food dominates your life?"),
    ]
    /// Item ids that are EXPECTED drug effects for current GLP-1 users:
    /// rapid unintentional loss (id 2) + food/thoughts dominating (id 4).
    /// Excluded from the core count so the GLP-1-aware SCOFF path screens
    /// the remaining genuine ED items only.
    private let glp1ExpectedItemIDs: Set<Int> = [2, 4]
    @State private var answers: [Int: Bool] = [:]

    private var allAnswered: Bool { answers.count == items.count }
    private var yesCount: Int { answers.values.filter { $0 }.count }
    private var coreYesCount: Int {
        answers.filter { !glp1ExpectedItemIDs.contains($0.key) && $0.value }.count
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.lg) {
                header
                ForEach(items) { item in row(item) }
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.xl)
            .padding(.bottom, Space.md)
        }
        .background(Palette.bgPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            JFContinueButton(
                label: "continue",
                action: { Haptics.light(); onComplete(yesCount, coreYesCount) },
                isEnabled: allAnswered
            )
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.lg)
            .background(Palette.bgPrimary)
            .overlay(alignment: .top) { Rectangle().fill(Palette.divider.opacity(0.7)).frame(height: 1) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            ItalicAccentText(
                "a gentle check, first.",
                italic: ["gentle"],
                baseFont: Typo.heroHeadline,
                italicFont: Typo.heroHeadlineItalic,
                color: Palette.textPrimary,
                alignment: .leading
            )
            .lineSpacing(Typo.heroHeadlineLineGap)
            .fixedSize(horizontal: false, vertical: true)
            Text("before we build your plan, a few questions so we can make sure this is genuinely good for you. there are no wrong answers, and nothing here is judged \u{2661}")
                .font(.custom("DMSans-Regular", size: 15))
                .lineSpacing(4)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, Space.sm)
    }

    private func row(_ item: SCOFFItem) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text(item.text)
                .font(.custom("DMSans-Regular", size: 16))
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Space.sm) {
                choice("no", selected: answers[item.id] == false) { answers[item.id] = false }
                choice("yes", selected: answers[item.id] == true) { answers[item.id] = true }
            }
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.bgElevated))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.divider, lineWidth: 1))
    }

    private func choice(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { Haptics.soft(); action() } label: {
            Text(label)
                .font(.custom("DMSans-Medium", size: 15))
                .foregroundStyle(selected ? Palette.textInverse : Palette.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selected ? Palette.bgInverse : Palette.bgPrimary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(selected ? Color.clear : Palette.divider, lineWidth: 1)
                )
                // Whole pill is the tap target (clear fills aren't hit-tested).
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Crisis-resource card — surfaced on a positive ED screen. Tappable rows
/// open the dialer / messages (US resources).
struct SafetyResourcesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("support, any time")
                .font(.custom("DMSans-Medium", size: 12))
                .kerning(1.5)
                .foregroundStyle(Palette.textSecondary)
            resourceRow(title: "NEDA helpline", detail: "1-800-931-2237", urlString: "tel:18009312237")
            resourceRow(title: "988 suicide & crisis lifeline", detail: "call or text 988", urlString: "tel:988")
            resourceRow(title: "crisis text line", detail: "text \u{201C}NEDA\u{201D} to 741741", urlString: "sms:741741")
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.bgElevated))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Palette.divider, lineWidth: 1))
    }

    private func resourceRow(title: String, detail: String, urlString: String) -> some View {
        Button {
            Haptics.light()
            if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.custom("DMSans-Medium", size: 15)).foregroundStyle(Palette.textPrimary)
                    Text(detail).font(.custom("DMSans-Regular", size: 13)).foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The non-loss safety outcomes. Variant drives the copy; crisis resources
/// surface only for the eating-disorder path.
enum SafetyTerminalVariant: Equatable {
    case eatingDisorder, lowBMI, underage, pregnant, breastfeeding
    /// v3 T7 (2026-06-29) - medication / hypoglycemia terminal. Routed from
    /// ProgramMode.clinicianFirst (insulin or sulfonylurea-class meds). A
    /// calorie deficit on these classes is something to set up with a
    /// clinician first. No drug brand names (Apple 5.2.1); no deficit; no
    /// goal weight. Replaces the T3 placeholder that reused .pregnant copy.
    case clinicianFirst
    /// (safety fix) maintenance terminal - pre-paywall gate only.
    /// lowBMI=true when reasonKey=="bmi_low" (current BMI < 18.5);
    /// false for pregnant / breastfeeding / ttc (no-deficit season).
    /// Dead-end: no app access, no paywall, no loss plan. On-brand,
    /// anti-shame, no em-dashes, no "AI", only locked tokens.
    case maintenance(lowBMI: Bool)

    var headline: String {
        switch self {
        case .eatingDisorder: return "let's take this gently."
        case .lowBMI:         return "you're already there."
        case .underage:       return "we'll be here."
        case .pregnant:       return "steady is perfect."
        case .breastfeeding:  return "fed and steady."
        case .clinicianFirst: return "let's loop in your clinician."
        case .maintenance(let isLowBMI):
            return isLowBMI
                ? "you're already in a good place."
                : "let's not chase a number right now."
        }
    }
    var headlineItalic: [String] {
        switch self {
        case .eatingDisorder: return ["gently"]
        case .lowBMI:         return ["there"]
        case .underage:       return ["here"]
        case .pregnant:       return ["perfect"]
        case .breastfeeding:  return ["steady"]
        case .clinicianFirst: return ["clinician"]
        case .maintenance(let isLowBMI):
            return isLowBMI ? ["good"] : ["now"]
        }
    }
    var bodyText: String {
        switch self {
        case .eatingDisorder:
            return "some of what you shared tells us a numbers-and-goal-weight plan might not be the kindest thing for you right now. so we're going to skip it. no calorie counting, no goal weight, no pressure.\n\nyour relationship with food matters more than any number, and you deserve real support for it \u{2661}"
        case .lowBMI:
            return "your weight is already in a healthy range for your height, so a loss plan isn't the kindest fit. we'll focus on feeling strong and steady instead, no deficit, no goal weight \u{2661}"
        case .underage:
            return "jenifit's plans are built for 18 and up. please be gentle with yourself, and come find us when the time is right \u{2661}"
        case .pregnant:
            return "weight loss isn't the goal during pregnancy. we'll keep things gentle and supportive and skip the deficit and goal weight. your clinician is the best guide for what's right for you \u{2661}"
        case .breastfeeding:
            return "while you're breastfeeding, your body needs steady fuel, not a deficit. we'll keep things gentle and protein-forward instead of chasing a goal weight \u{2661}"
        case .clinicianFirst:
            return "what you shared tells us a calorie plan is one to set up together with your clinician first. some medications change how your body handles a deficit, so this is a plan to make with them, not on your own.\n\nonce you've checked in with them, we'll be right here when you're ready \u{2661}"
        case .maintenance(let isLowBMI):
            return isLowBMI
                ? "your weight is already in a healthy range for your height, so a loss plan isn't the right fit right now. we'll be here when your goals shift \u{2661}"
                : "this season is about nourishing yourself, not a deficit. come back when the time is right, and we'll build your plan then \u{2661}"
        }
    }
    var ctaLabel: String {
        switch self {
        case .eatingDisorder: return "continue gently"
        case .underage:       return "okay"
        case .clinicianFirst: return "okay"
        case .maintenance:    return "okay"
        default:              return "sounds good"
        }
    }
    var showsResources: Bool { self == .eatingDisorder }
}

/// Terminal "this isn't the right fit" screen for a non-loss safety
/// outcome. No goal weight, no calories; ED path also shows resources.
struct SafetyRecoveryView: View {
    var variant: SafetyTerminalVariant = .eatingDisorder
    let onContinueGently: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.lg) {
                ItalicAccentText(
                    variant.headline,
                    italic: variant.headlineItalic,
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                .lineSpacing(Typo.heroHeadlineLineGap)
                .fixedSize(horizontal: false, vertical: true)

                Text(variant.bodyText)
                    .font(.custom("DMSans-Regular", size: 16))
                    .lineSpacing(5)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if variant.showsResources { SafetyResourcesCard() }
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.xl)
            .padding(.bottom, Space.md)
        }
        .background(Palette.bgPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            JFContinueButton(label: variant.ctaLabel, action: { Haptics.light(); onContinueGently() })
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.lg)
                .background(Palette.bgPrimary)
                .overlay(alignment: .top) { Rectangle().fill(Palette.divider.opacity(0.7)).frame(height: 1) }
        }
    }
}

/// Informed-consent acknowledgment — the honest "education, not medical
/// care" frame, shown first in the safety gate.
struct SafetyConsentView: View {
    let onAccept: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.lg) {
                ItalicAccentText(
                    "before we begin.",
                    italic: ["begin"],
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                .lineSpacing(Typo.heroHeadlineLineGap)
                .fixedSize(horizontal: false, vertical: true)

                Text("jenifit is here to help you build kind, steady habits. a couple of things to be clear about, because they matter:")
                    .font(.custom("DMSans-Regular", size: 16))
                    .lineSpacing(5)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: Space.sm) {
                    bullet("this is an educational program, not medical care.")
                    bullet("it doesn't replace your doctor or prescriber.")
                    bullet("if anything ever feels off, please reach out to a professional.")
                }

                Text("by continuing, you're saying you understand \u{2661}")
                    .font(.custom("DMSans-Regular", size: 15))
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.xl)
            .padding(.bottom, Space.md)
        }
        .background(Palette.bgPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            JFContinueButton(label: "i understand", action: { Haptics.light(); onAccept() })
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.lg)
                .background(Palette.bgPrimary)
                .overlay(alignment: .top) { Rectangle().fill(Palette.divider.opacity(0.7)).frame(height: 1) }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Circle().fill(Palette.cocoaPrimary).frame(width: 5, height: 5).padding(.top, 7)
            Text(text)
                .font(.custom("DMSans-Regular", size: 15))
                .lineSpacing(3)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Pregnancy / lactation / TTC screen. `pregnant`/`breastfeeding` route the
/// program to a steady, non-deficit mode; this is a safety screen, not a
/// diagnosis. No drug brand names.
struct SafetyPregnancyView: View {
    let onComplete: (String) -> Void   // status key

    private let options: [(key: String, label: String)] = [
        ("none", "none of these"),
        ("pregnant", "i'm pregnant"),
        ("ttc", "trying to conceive"),
        ("breastfeeding", "breastfeeding"),
        ("prefer_not_say", "prefer not to say"),
    ]
    @State private var selected: String? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.lg) {
                ItalicAccentText(
                    "one more, just to be safe.",
                    italic: ["safe"],
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                .lineSpacing(Typo.heroHeadlineLineGap)
                .fixedSize(horizontal: false, vertical: true)

                Text("is any of this true for you right now? it helps us keep your plan right for your body \u{2661}")
                    .font(.custom("DMSans-Regular", size: 15))
                    .lineSpacing(4)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: Space.sm) {
                    ForEach(options, id: \.key) { opt in
                        SafetySelectRow(label: opt.label, selected: selected == opt.key) {
                            selected = opt.key
                        }
                    }
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.xl)
            .padding(.bottom, Space.md)
        }
        .background(Palette.bgPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            JFContinueButton(
                label: "continue",
                action: { Haptics.light(); onComplete(selected ?? "none") },
                isEnabled: selected != nil
            )
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.lg)
            .background(Palette.bgPrimary)
            .overlay(alignment: .top) { Rectangle().fill(Palette.divider.opacity(0.7)).frame(height: 1) }
        }
    }
}

/// Single-select radio row used by the safety screens.
struct SafetySelectRow: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button { Haptics.soft(); action() } label: {
            HStack {
                Text(label)
                    .font(.custom("DMSans-Medium", size: 16))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                ZStack {
                    Circle()
                        .stroke(selected ? Palette.cocoaPrimary : Palette.divider, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if selected {
                        Circle().fill(Palette.cocoaPrimary).frame(width: 12, height: 12)
                    }
                }
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.bgElevated))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? Palette.cocoaPrimary.opacity(0.5) : Palette.divider, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// One-time, NON-BLOCKING safety check-in for users who enrolled BEFORE the
/// gate existed. Same screens as the new-user gate, framed as care; "maybe
/// later" keeps it non-blocking, and it shows once (safety_checkin_seen).
/// On a non-loss outcome it records program_mode + surfaces support, but
/// never deletes the user's existing program.
struct SafetyCheckInView: View {
    let onFinish: () -> Void

    @AppStorage("onboardingCurrentWeightKg") private var currentWeightKg: Double = 65
    @AppStorage("onboardingGoalWeightKg") private var goalWeightKg: Double = 60
    @AppStorage("onboardingHeightCm") private var heightCm: Double = 0
    @AppStorage("onboardingAgeRange") private var ageRange: String = ""
    @AppStorage("safety_screen_completed") private var safetyScreenCompleted = false
    @AppStorage("safety_scoff_yes") private var safetyScoffYes = -1
    @AppStorage("safety_pregnancy_status") private var safetyPregnancyStatus = ""
    @AppStorage("program_mode") private var programMode = "loss"
    @AppStorage("safety_checkin_seen") private var checkinSeen = false
    // T7 (2026-06-29) - medication + GLP-1 signals so the legacy check-in
    // screens the same way the pre-paywall gate does.
    @AppStorage("onboarding_medication_status") private var medicationStatus = ""
    @AppStorage("onboarding_glp1_status") private var glp1Status = ""

    @State private var phase: CheckInPhase = .intro
    private enum CheckInPhase: Equatable {
        case intro, pregnancy, screening, terminal(SafetyTerminalVariant), allGood
    }

    var body: some View {
        switch phase {
        case .intro:
            intro
        case .pregnancy:
            SafetyPregnancyView(onComplete: { status in
                safetyPregnancyStatus = status
                withAnimation(Motion.crossFade) { phase = .screening }
            })
        case .screening:
            SCOFFScreenView(onComplete: handleScoff)
        case .terminal(let variant):
            SafetyRecoveryView(variant: variant, onContinueGently: { finish(markCompleted: true) })
        case .allGood:
            allGood
        }
    }

    private var intro: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.lg) {
                ItalicAccentText(
                    "a quick check-in.",
                    italic: ["check-in"],
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                .lineSpacing(Typo.heroHeadlineLineGap)
                .fixedSize(horizontal: false, vertical: true)
                Text("we've added a short safety check so we can make sure jenifit is still the kindest fit for you. it takes about a minute, and there are no wrong answers \u{2661}")
                    .font(.custom("DMSans-Regular", size: 16))
                    .lineSpacing(5)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.xl)
            .padding(.bottom, Space.md)
        }
        .background(Palette.bgPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Space.sm) {
                JFContinueButton(label: "start the check", action: {
                    Haptics.light()
                    withAnimation(Motion.crossFade) { phase = .pregnancy }
                })
                Button { Haptics.light(); finish(markCompleted: false) } label: {
                    Text("maybe later")
                        .font(.custom("DMSans-Medium", size: 15))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.lg)
            .background(Palette.bgPrimary)
            .overlay(alignment: .top) { Rectangle().fill(Palette.divider.opacity(0.7)).frame(height: 1) }
        }
    }

    private var allGood: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.lg) {
                ItalicAccentText(
                    "you're all set.",
                    italic: ["set"],
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                .lineSpacing(Typo.heroHeadlineLineGap)
                .fixedSize(horizontal: false, vertical: true)
                Text("thanks for checking in. your plan is a good fit, so carry on, just as you were \u{2661}")
                    .font(.custom("DMSans-Regular", size: 16))
                    .lineSpacing(5)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.xl)
            .padding(.bottom, Space.md)
        }
        .background(Palette.bgPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            JFContinueButton(label: "done", action: { Haptics.light(); finish(markCompleted: true) })
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.lg)
                .background(Palette.bgPrimary)
                .overlay(alignment: .top) { Rectangle().fill(Palette.divider.opacity(0.7)).frame(height: 1) }
        }
    }

    private func handleScoff(_ yes: Int, _ core: Int) {
        safetyScoffYes = yes
        let a = ProgramGoalCalculator.safetyAssessment(.init(
            currentWeightKg: currentWeightKg,
            goalWeightKg: goalWeightKg,
            heightCm: heightCm,
            ageRange: ageRange,
            scoffYesCount: yes,
            pregnancyStatus: safetyPregnancyStatus,
            medicationKey: medicationStatus,
            glp1StatusKey: glp1Status,
            weightTrendKey: "",
            scoffCoreYesCount: core
        ))
        programMode = a.mode.rawValue
        safetyScreenCompleted = true
        withAnimation(Motion.crossFade) {
            switch a.mode {
            case .loss:           phase = .allGood
            case .recovery:       phase = .terminal(.eatingDisorder)
            case .blocked:        phase = .terminal(.underage)
            case .maintenance:    phase = .terminal(a.reasonKey == "bmi_low" ? .lowBMI : .pregnant)
            case .clinicianFirst: phase = .terminal(.clinicianFirst)
            }
        }
    }

    private func finish(markCompleted: Bool) {
        checkinSeen = true
        if markCompleted { safetyScreenCompleted = true }
        onFinish()
    }
}
