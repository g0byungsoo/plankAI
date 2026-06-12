import SwiftUI
import UserNotifications

/// "notifications." — v1.1 clean-luxury pass: hairline rows replace
/// the boxed toggle cards, the coach preview sits unboxed like a
/// pull-quote, and the save action is a slim cocoa capsule.
struct NotificationSettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("notificationHour") private var notificationHour = 7
    @AppStorage("notificationMinute") private var notificationMinute = 0
    @AppStorage("voicePreference") private var voicePreference = "encouraging"
    // Retention extras — independent of the daily reminder. Default ON;
    // only ever deliver when notifications are authorized (see
    // RetentionNotifications). Same keys the scheduler reads.
    @AppStorage("notif.affirmations_enabled") private var affirmationsEnabled = true
    @AppStorage("notif.winback_enabled") private var winbackEnabled = true
    @State private var pickerTime = Date()
    @State private var permissionGranted = false
    @State private var saved = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                JFPageHero(title: "notifications.", italic: ["notifications"], alignment: .leading)
                    .padding(.horizontal, -Space.screenPadding)

                Spacer().frame(height: 28)

                SettingsSection(title: "daily check-in") {
                    SettingsToggleRow(
                        title: "a note from \(coachName)",
                        subtitle: "she taps in once a day ♥\u{FE0E}",
                        isOn: $notificationsEnabled
                    )
                }
                .onChange(of: notificationsEnabled) { _, enabled in
                    if enabled {
                        requestPermission()
                        scheduleNotification()
                    } else {
                        // Surgical — drop only the daily reminder (and
                        // its legacy id from the pre-rebrand). The
                        // trial-end notification has its own identifier
                        // and stays scheduled regardless.
                        UNUserNotificationCenter.current()
                            .removePendingNotificationRequests(withIdentifiers: [
                                NotificationPermission.dailyReminderIdentifier,
                                "daily-plank"  // legacy
                            ])
                    }
                }

                if notificationsEnabled {
                    VStack(alignment: .leading, spacing: 0) {
                        // iOS 17+ wheel fixes preserved: explicit 200pt
                        // height (the wheel collapses without it) +
                        // forced .light scheme (UIKit-backed digits
                        // resolve white in dark mode against our
                        // hardcoded cream).
                        DatePicker(
                            "Time",
                            selection: $pickerTime,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .tint(Palette.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipped()
                        .environment(\.colorScheme, .light)

                        saveButton

                        Spacer().frame(height: 24)

                        reminderPreview
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
                            }
                    }
                    .transition(.opacity.combined(with: .offset(y: 8)))
                }

                Spacer().frame(height: 36)

                // Gentle extras — independent retention nudges, each
                // toggleable + frequency-capped, delivered only when
                // notifications are authorized. Default on.
                SettingsSection(title: "gentle extras") {
                    SettingsToggleRow(
                        title: "daily affirmations",
                        subtitle: "little notes from \(coachName), a couple times a week",
                        isOn: $affirmationsEnabled
                    )
                    SettingsToggleRow(
                        title: "a nudge if you go quiet",
                        subtitle: "\(coachName) reaches out if a few days slip by",
                        isOn: $winbackEnabled
                    )
                }
                .onChange(of: affirmationsEnabled) { _, enabled in
                    if enabled { requestPermission() }
                    RetentionNotifications.applyTogglesChanged()
                }
                .onChange(of: winbackEnabled) { _, enabled in
                    if enabled { requestPermission() }
                    RetentionNotifications.applyTogglesChanged()
                }

                if !permissionGranted && notificationsEnabled {
                    Spacer().frame(height: 24)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 12, weight: .light))
                            .foregroundStyle(Palette.stateWarn)
                        Text("notifications are off in iOS settings. enable them under Settings → JeniFit → Notifications.")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer().frame(height: Space.xl)
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.md)
        }
        .background(Palette.programEraBg)
        .onAppear {
            pickerTime = Calendar.current.date(from: DateComponents(hour: notificationHour, minute: notificationMinute)) ?? Date()
        }
        .task { await checkPermission() }
    }

    // MARK: - Save

    private var saveButton: some View {
        Button {
            Haptics.medium()
            saveTime()
        } label: {
            HStack(spacing: 8) {
                Text(saved ? "saved" : "save time")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                if saved {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .foregroundStyle(Palette.textInverse)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Capsule().fill(Palette.bgInverse))
        }
        .buttonStyle(SettingsGlowPressStyle())
        .animation(Motion.crossFade, value: saved)
    }

    // MARK: - "from your coach" preview
    //
    // The reminder reframed as the coach checking in (parasocial-Jeni)
    // rather than a system nag — avatar + the exact voice-adaptive
    // message that will land, at the saved time. Unboxed; reads like a
    // pull-quote between hairlines.

    private var coachName: String { CoachAsset.displayName(for: voicePreference) }

    /// Mirrors NotificationPermission.dailyReminderBody() so the preview
    /// matches what actually gets scheduled.
    private var coachMessage: String {
        switch voicePreference {
        case "balanced":   return "sam picked a short one. easy to finish."
        case "keepItReal": return "kira's got a short one ready today."
        default:           return "five minutes is enough today. small moves still count."
        }
    }

    private var reminderTimeLabel: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        let d = Calendar.current.date(
            from: DateComponents(hour: notificationHour, minute: notificationMinute)
        ) ?? Date()
        return f.string(from: d).lowercased()
    }

    private var reminderPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("what \(coachName) sends at \(reminderTimeLabel)")
                .font(Typo.editorialEyebrow)
                .textCase(.uppercase)
                .kerning(1.8)
                .foregroundStyle(Palette.cocoaTertiary)

            HStack(alignment: .top, spacing: Space.sm) {
                Image(CoachAsset.imageName(for: voicePreference))
                    .resizable().scaledToFill()
                    .frame(width: 38, height: 38)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Palette.accent.opacity(0.4), lineWidth: 1))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("today's short session.")
                        .font(Typo.body).fontWeight(.semibold)
                        .foregroundStyle(Palette.textPrimary)
                    Text(coachMessage)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.bottom, 20)
    }

    private func saveTime() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: pickerTime)
        notificationHour = components.hour ?? 7
        notificationMinute = components.minute ?? 0
        scheduleNotification()
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { saved = false }
        }
    }

    /// Schedule the daily reminder via the shared helper. Routes through
    /// `NotificationPermission.scheduleDailyReminder` so the identifier,
    /// title, and voice-adaptive body stay consistent with the
    /// onboarding completion path.
    private func scheduleNotification() {
        let time = Calendar.current.date(
            from: DateComponents(hour: notificationHour, minute: notificationMinute)
        ) ?? Date()
        NotificationPermission.scheduleDailyReminder(at: time)
    }

    private func requestPermission() {
        Task {
            let granted = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            permissionGranted = granted ?? false
        }
    }

    private func checkPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionGranted = settings.authorizationStatus == .authorized
    }
}
