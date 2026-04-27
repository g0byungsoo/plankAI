import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 7)) ?? Date()
    @State private var permissionGranted = false

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
                    if enabled { requestPermission() }
                }

                // Time picker
                if notificationsEnabled {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        Text("REMINDER TIME")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Palette.textSecondary)
                            .tracking(2)

                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(Palette.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .plankShadow()
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
        .task { await checkPermission() }
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
