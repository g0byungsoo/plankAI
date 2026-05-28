import SwiftUI

enum SettingsSheet: Identifiable {
    case profileHub       // the settings hub (entry point from home avatar)
    case editProfile
    case trainer
    case notifications
    case account
    case feedback
    case jeniMethod       // Phase 7: read-only re-read index
    #if DEBUG
    case debugAuth
    #endif

    var id: String { "\(self)" }
}

struct SettingsView: View {
    let sheet: SettingsSheet
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch sheet {
                case .profileHub: ProfileHubView()
                case .editProfile: EditProfileView()
                case .trainer: ChangeTrainerView()
                case .notifications: NotificationSettingsView()
                case .account: AccountView()
                case .feedback: FeedbackView()
                case .jeniMethod: JeniMethodReReadView()
                #if DEBUG
                case .debugAuth: DebugAuthView()
                #endif
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
                            .tappableArea()
                    }
                    .accessibilityLabel("Close settings")
                }
            }
        }
    }
}
