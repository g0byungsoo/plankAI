import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("notificationHour") private var notificationHour = 7
    @AppStorage("notificationMinute") private var notificationMinute = 0
    @State private var pickerTime = Date()
    @State private var permissionGranted = false
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("Notifications")
                    .font(Typo.title)
                    .foregroundStyle(Palette.textPrimary)

                // Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily Reminder")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Palette.textPrimary)
                        Text("Get reminded to work out")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: $notificationsEnabled)
                        .tint(Palette.accent)
                        .labelsHidden()
                }
                .padding(14)
                .background(Palette.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .plankShadow()
                .onChange(of: notificationsEnabled) { _, enabled in
                    if enabled {
                        requestPermission()
                        scheduleNotification()
                    } else {
                        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                    }
                }

                // Time picker
                if notificationsEnabled {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        Text("REMINDER TIME")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Palette.textSecondary)
                            .tracking(2)

                        DatePicker("Time", selection: $pickerTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(Palette.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .plankShadow()

                        Button {
                            Haptics.medium()
                            saveTime()
                        } label: {
                            Text(saved ? "Saved" : "Save Time")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(saved ? Palette.stateGood : Palette.textInverse)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(saved ? Palette.stateGood.opacity(0.12) : Palette.bgInverse)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .transition(.opacity.combined(with: .offset(y: 8)))
                }

                if !permissionGranted && notificationsEnabled {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Palette.stateWarn)
                        Text("Notifications are off in Settings. Go to Settings > absmaxxing > Notifications to enable.")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .padding(14)
                    .background(Palette.stateWarn.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
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

    private func scheduleNotification() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let content = UNMutableNotificationContent()
        content.title = "Time to work"
        content.body = "Your workout is ready. Don't make Kira wait."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = notificationHour
        dateComponents.minute = notificationMinute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)
        center.add(request)
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
