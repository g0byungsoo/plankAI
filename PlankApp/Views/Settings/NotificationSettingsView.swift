import SwiftUI
import UserNotifications

/// "notifications." — v1.1 clean-luxury pass: hairline rows replace
/// the boxed toggle cards, the coach preview sits unboxed like a
/// pull-quote, and the save action is a slim cocoa capsule.
struct NotificationSettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("notificationHour") private var notificationHour = 7
    @AppStorage("notificationMinute") private var notificationMinute = 0
    // Retention extras — independent of the daily reminder. Default ON;
    // only ever deliver when notifications are authorized (see
    // RetentionNotifications). Same keys the scheduler reads.
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
                        title: "a note from jeni",
                        subtitle: "one check-in a day, at your time",
                        isOn: $notificationsEnabled
                    )
                }
                .onChange(of: notificationsEnabled) { _, enabled in
                    if enabled {
                        requestPermission()
                        scheduleNotification()
                    } else {
                        // Release audit 2026-08-08 — the master toggle
                        // off used to drop only the daily reminder,
                        // leaving the week's already-scheduled anchor
                        // rungs, the re-signing knock, and today's
                        // lapse ping live: up to ~9 pushes over 7 days
                        // AFTER an explicit opt-out. Off means off.
                        // (The trial-end reminder keeps its own toggle.)
                        // p54 — OFF MEANS OFF, at last measured against
                        // a census: the old list swept six families
                        // while the evening review (a daily repeat!),
                        // the winback, the day-1/day-5 pushes and the
                        // whole retired set survived an explicit
                        // opt-out — and reschedule() re-armed them on
                        // the next launch. One census, every id.
                        UNUserNotificationCenter.current()
                            .removePendingNotificationRequests(
                                withIdentifiers: NotificationCensus.allNonMedicationIds
                            + NotificationOrchestrator.ladderIds
                            + NotificationOrchestrator.jitaiIds
                            // v24 — dose reminders honor the master
                            // switch too (their per-regimen opt-in
                            // re-arms them when this comes back on).
                            + MedicationReminders.allIds)
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
                // p54 — the "daily affirmations" row is gone with its
                // family (clock-fired motivational filler; the
                // presumption of deletion). A toggle that controls a
                // send the product no longer makes would be a lie in
                // switch's clothing.
                SettingsSection(title: "gentle extras") {
                    SettingsToggleRow(
                        title: "a nudge if you go quiet",
                        subtitle: "jeni reaches out if a few days slip by",
                        isOn: $winbackEnabled
                    )
                }
                .onChange(of: winbackEnabled) { _, enabled in
                    if enabled { requestPermission() }
                    RetentionNotifications.applyTogglesChanged()
                }

                if !permissionGranted && notificationsEnabled {
                    Spacer().frame(height: 24)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.custom("DMSans-Light", size: 12, relativeTo: .caption))
                            .foregroundStyle(Palette.stateWarn)
                        Text("notifications are off in iOS settings. enable them under Settings → Jeni → Notifications.")
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
        // p69 — the last 52pt italic-Fraunces capsules join
        // JFContinueButton (its own header has named that drift class
        // since v3 P11.6; these settings CTAs never made the move).
        JFContinueButton(
            label: saved ? "saved" : "save time",
            action: { saveTime() },
            padded: false
        )
        .animation(Motion.crossFade, value: saved)
    }

    // MARK: - "from your coach" preview
    //
    // The reminder reframed as the coach checking in (parasocial-Jeni)
    // rather than a system nag — avatar + the exact voice-adaptive
    // message that will land, at the saved time. Unboxed; reads like a
    // pull-quote between hairlines.

    /// p54 — the standalone daily reminder retired; the hour she picks
    /// here is the MORNING READ's delivery time (the anchor ladder has
    /// always read these stored values). The preview shows the read's
    /// own rung-1 shape. Drift note: the real body is record-dependent
    /// ("yesterday: 3 plates and 84 g protein, on file"), so this is
    /// the shape, not a quote — the title IS the literal title.
    private var coachMessage: String {
        "yesterday: your plates and protein, logged. jeni read it back this morning"
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
            Text("what jeni sends at \(reminderTimeLabel)")
                .font(Typo.editorialEyebrow)
                .textCase(.uppercase)
                .kerning(1.8)
                .foregroundStyle(Palette.cocoaTertiary)

            HStack(alignment: .top, spacing: Space.sm) {
                // p69 — the sender is jeni, always (the morning read
                // is hers no matter which voice reads a workout), and
                // jeni's face is the drawn j mark, never a photograph
                // ("jeni is a digital coach. not a person").
                ZStack {
                    Circle()
                        .fill(Palette.bgElevated)
                        .frame(width: 38, height: 38)
                    JeniMark(height: 17, color: Palette.textPrimary)
                }
                .overlay(Circle().stroke(Palette.accent.opacity(0.4), lineWidth: 1))
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("your morning read is ready")
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
