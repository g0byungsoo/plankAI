import SwiftUI

struct EditProfileView: View {
    @AppStorage("userName") private var userName = ""
    // Phase 8: edits persist to bodyFocus (the new Phase 4 truth). The
    // legacy userGoal mirror keeps HomeView's WorkoutGoal(rawValue:)
    // resolution working until that surface migrates off the legacy
    // enum (separate phase). Both writes happen on selection.
    @AppStorage("bodyFocus") private var bodyFocus = ""
    @AppStorage("userGoal") private var userGoal = ""
    @AppStorage("sessionLengthPref") private var sessionLengthPref = 7

    @State private var editName = ""
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("Edit Profile")
                    .font(Typo.title)
                    .foregroundStyle(Palette.textPrimary)

                // Name
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text("NAME")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.textSecondary)
                        .tracking(2)

                    TextField("Your name", text: $editName)
                        .font(Typo.body)
                        .foregroundStyle(Palette.textPrimary)
                        .padding(14)
                        .background(Palette.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .plankShadow()
                        .onSubmit { saveName() }
                }

                // Goal
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text("FOCUS AREA")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.textSecondary)
                        .tracking(2)

                    ForEach(goalOptions, id: \.value) { option in
                        Button {
                            Haptics.light()
                            bodyFocus = option.value
                            userGoal = legacyUserGoal(for: option.value)
                        } label: {
                            HStack {
                                Text(option.label)
                                    .font(Typo.body)
                                    .foregroundStyle(Palette.textPrimary)
                                Spacer()
                                if bodyFocus == option.value {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Palette.accent)
                                }
                            }
                            .padding(14)
                            .background(bodyFocus == option.value ? Palette.accent.opacity(0.08) : Palette.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }

                // Session length
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text("SESSION LENGTH")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.textSecondary)
                        .tracking(2)

                    HStack(spacing: Space.sm) {
                        ForEach([5, 7, 10], id: \.self) { mins in
                            Button {
                                Haptics.light()
                                sessionLengthPref = mins
                            } label: {
                                Text("\(mins) min")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(sessionLengthPref == mins ? Palette.textInverse : Palette.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(sessionLengthPref == mins ? Palette.bgInverse : Palette.bgElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }
                }

                // Save button
                Button {
                    Haptics.medium()
                    saveName()
                } label: {
                    Text(saved ? "Saved" : "Save Changes")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(saved ? Palette.stateGood : Palette.textInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(saved ? Palette.stateGood.opacity(0.12) : Palette.bgInverse)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.top, Space.sm)
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.md)
        }
        .background(Palette.bgPrimary)
        .onAppear { editName = userName }
    }

    private func saveName() {
        guard !editName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        userName = editName.trimmingCharacters(in: .whitespaces)
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { saved = false }
        }
    }

    private var goalOptions: [(label: String, value: String)] {
        [
            ("Flat belly",                "flatBelly"),
            ("Toned arms",                "tonedArms"),
            ("Round butt",                "roundButt"),
            ("Slim legs",                 "slimLegs"),
            ("Full body transformation",  "fullBody"),
        ]
    }

    /// Mirror bodyFocus → legacy userGoal so HomeView's WorkoutGoal
    /// resolution stays correct. Same mapping pipeline as
    /// PlankAIApp.handleOnboardingComplete (focusAreaFromBodyFocus →
    /// userGoal switch).
    private func legacyUserGoal(for bodyFocusValue: String) -> String {
        switch bodyFocusValue {
        case "flatBelly": return "definition"
        default:          return "fullCore"
        }
    }
}
