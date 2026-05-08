import SwiftUI
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
        content.title = "Time to work"
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
    /// (same key NotificationSettingsView uses) so the reminder reads
    /// in the trainer's voice. Default = encouraging (Jeni → "Sarah"
    /// voice copy still pending the rename pass).
    private static func dailyReminderBody() -> String {
        let pref = UserDefaults.standard.string(forKey: "voicePreference") ?? "encouraging"
        switch pref {
        case "encouraging": return "Your workout is ready. Your coach is waiting."
        case "balanced":    return "Your workout is ready. Sam's got something for you."
        default:            return "Your workout is ready. Don't make Kira wait."
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
