import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("notificationHour") private var notificationHour = 7
    @AppStorage("notificationMinute") private var notificationMinute = 0
    @AppStorage("voicePreference") private var voicePreference = "encouraging"
    @State private var pickerTime = Date()
    @State private var permissionGranted = false
    @State private var saved = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.lg) {
                header

                // Toggle row — scrapbook chrome.
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("daily check-in")
                            .font(Typo.body)
                            .foregroundStyle(Palette.textPrimary)
                        Text("\(coachName) taps in once a day ♥")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: $notificationsEnabled)
                        .tint(Palette.accent)
                        .labelsHidden()
                }
                .padding(Space.md)
                .background(scrapbookChrome())
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
                    VStack(alignment: .leading, spacing: Space.sm) {
                        Text("reminder time")
                            .font(Typo.eyebrow).tracking(3)
                            .foregroundStyle(Palette.textSecondary)
                            .padding(.bottom, 2)

                        DatePicker("Time", selection: $pickerTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            .padding(Space.sm)
                            .background(scrapbookChrome())

                        saveButton

                        reminderPreviewCard
                    }
                    .transition(.opacity.combined(with: .offset(y: 8)))
                }

                if !permissionGranted && notificationsEnabled {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Palette.stateWarn)
                        Text("notifications are off in iOS settings. enable them under Settings → JeniFit → Notifications.")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Space.md)
                    .background(scrapbookChrome(tint: Palette.stateWarn))
                }

                Spacer().frame(height: Space.xl)
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.md)
        }
        .background(Palette.bgPrimary)
        .onAppear {
            pickerTime = Calendar.current.date(from: DateComponents(hour: notificationHour, minute: notificationMinute)) ?? Date()
        }
        .task { await checkPermission() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("settings")
                .font(Typo.eyebrow).tracking(2)
                .foregroundStyle(Palette.accent)
            Text("notifications.")
                .font(Typo.titleItalic)
                .foregroundStyle(Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Sparkle sticker — gentle nudge, not alarm.
        .overlay(alignment: .topTrailing) {
            Image(StickerName.sparkleGlossy.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .rotationEffect(.degrees(-12))
                .offset(x: 4, y: -8)
                .opacity(StickerName.sparkleGlossy.style.opacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        Button {
            Haptics.medium()
            saveTime()
        } label: {
            HStack {
                Text(saved ? "saved" : "save time")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 18))
                Spacer()
                Image(systemName: saved ? "checkmark" : "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(saved ? Palette.stateGood : Palette.accent)
            }
            .foregroundStyle(Palette.textInverse)
            .padding(.horizontal, Space.lg)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Palette.accent.opacity(0.18))
                        .offset(x: 4, y: 4)
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Palette.bgInverse)
                }
            )
        }
        .buttonStyle(NotifPressStyle())
    }

    // MARK: - "from your coach" preview
    //
    // Reframes the reminder as the coach checking in (the parasocial-Jeni
    // vision) rather than a system nag — shows the coach avatar + the exact
    // voice-adaptive message that will land, at the saved time.

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

    private var reminderPreviewCard: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("what \(coachName) sends at \(reminderTimeLabel)")
                .font(Typo.eyebrow).tracking(2)
                .foregroundStyle(Palette.textSecondary)

            HStack(alignment: .top, spacing: Space.sm) {
                Image(CoachAsset.imageName(for: voicePreference))
                    .resizable().scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Palette.accentSubtle, lineWidth: 1.5))
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
            .padding(Space.md)
            .background(scrapbookChrome())
        }
    }

    private func scrapbookChrome(tint: Color = Palette.accent) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(tint.opacity(0.15))
                .offset(x: 4, y: 4)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Palette.bgElevated)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(tint, lineWidth: 1.5)
        }
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
    /// onboarding completion path. Removed the local duplicate +
    /// `removeAllPendingNotificationRequests()` which was nuking the
    /// trial-end reminder as a side effect.
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

private struct NotifPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(Motion.tap, value: configuration.isPressed)
    }
}
