import SwiftUI

enum SettingsSheet: Identifiable {
    case editProfile
    case trainer
    case notifications
    case account
    case feedback

    var id: String { "\(self)" }
}

struct SettingsView: View {
    let sheet: SettingsSheet
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch sheet {
                case .editProfile: EditProfileView()
                case .trainer: ChangeTrainerView()
                case .notifications: NotificationSettingsView()
                case .account: AccountView()
                case .feedback: FeedbackView()
                }
            }
            .background(Palette.bgPrimary)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(Palette.bgElevated)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
}
