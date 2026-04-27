import SwiftUI

struct EditProfileView: View {
    @AppStorage("userName") private var userName = ""
    @AppStorage("userGoal") private var userGoal = ""
    @AppStorage("sessionLengthPref") private var sessionLengthPref = 7

    @State private var editName = ""
    @State private var saved = false

    private var goalLabel: String {
        switch userGoal {
        case "definition": return "Abs Definition"
        case "sculpting": return "Waist Sculpting"
        case "strength": return "Core Strength"
        default: return "Full Core"
        }
    }

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
                            userGoal = option.value
                        } label: {
                            HStack {
                                Text(option.label)
                                    .font(Typo.body)
                                    .foregroundStyle(Palette.textPrimary)
                                Spacer()
                                if userGoal == option.value {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Palette.accent)
                                }
                            }
                            .padding(14)
                            .background(userGoal == option.value ? Palette.accent.opacity(0.08) : Palette.bgElevated)
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

                // Save confirmation
                if saved {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Palette.stateGood)
                        Text("Saved")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.stateGood)
                    }
                    .transition(.opacity)
                }
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
            ("Abs Definition", "definition"),
            ("Waist Sculpting", "sculpting"),
            ("Core Strength", "strength"),
            ("Full Core", "fullCore"),
        ]
    }
}
