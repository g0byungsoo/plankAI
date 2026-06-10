import SwiftUI
import UserNotifications

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
                .editorialCard()
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

                        // Two fixes layered:
                        //
                        // 1. iOS 17+ regression: `.datePickerStyle(.wheel)`
                        //    inside a styled-background container without
                        //    an explicit height mis-measures its intrinsic
                        //    height and the wheel collapses (digits hidden,
                        //    only the selection bar shows). Pinning to a
                        //    200pt frame restores the digits.
                        //
                        // 2. Color scheme override: the wheel is UIKit-
                        //    backed and resolves digit text from
                        //    UIColor.label, which goes WHITE under system
                        //    dark mode. JeniFit's palette is hardcoded
                        //    (cream chrome regardless of mode), so white
                        //    digits land on cream chrome and read as
                        //    invisible. Forcing the subtree's environment
                        //    color scheme to .light makes UIColor.label
                        //    resolve dark, matching the brand palette.
                        //    `.tint(Palette.accent)` keeps the selection
                        //    bar dusty-rose either way.
                        VStack(spacing: 0) {
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
                        }
                        .environment(\.colorScheme, .light)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.xs)
                        .padding(.horizontal, Space.sm)
                        .editorialCard()

                        saveButton

                        reminderPreviewCard
                    }
                    .transition(.opacity.combined(with: .offset(y: 8)))
                }

                // Gentle extras — independent retention nudges, each
                // toggleable + frequency-capped, delivered only when
                // notifications are authorized. Default on.
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text("gentle extras")
                        .font(Typo.eyebrow).tracking(3)
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.bottom, 2)

                    extraToggleRow(
                        title: "daily affirmations",
                        subtitle: "little notes from \(coachName), a couple times a week ♥",
                        isOn: $affirmationsEnabled
                    )
                    extraToggleRow(
                        title: "a nudge if you go quiet",
                        subtitle: "\(coachName) reaches out if a few days slip by",
                        isOn: $winbackEnabled
                    )
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
                    .scrapbookCard(tint: Palette.stateWarn)
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
            .editorialCard()
        }
    }

    private func extraToggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textPrimary)
                Text(subtitle)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .tint(Palette.accent)
                .labelsHidden()
        }
        .padding(Space.md)
        .editorialCard()
        .onChange(of: isOn.wrappedValue) { _, enabled in
            if enabled { requestPermission() }
            RetentionNotifications.applyTogglesChanged()
        }
    }

    // v8 P8.10: local scrapbookChrome removed — unified to
    // `View.scrapbookCard(tint:)` in DesignSystem/Tokens.swift.

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
