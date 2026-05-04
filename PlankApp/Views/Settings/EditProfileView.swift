import SwiftUI
import SwiftData
import PlankSync
import Auth

struct EditProfileView: View {
    @AppStorage("userName") private var userName = ""
    // The bodyFocus AppStorage mirror stays as the on-device fast path
    // (PaywallView still reads it). Cross-device truth lives on the
    // UserRecord row pulled from Supabase — when present, it overrides
    // the local mirror so a user signed in on a fresh device sees their
    // synced selection.
    @AppStorage("bodyFocus") private var bodyFocus = ""
    @AppStorage("userGoal") private var userGoal = ""
    @AppStorage("sessionLengthPref") private var sessionLengthPref = 7

    @Environment(\.modelContext) private var modelContext
    @Query private var userRecords: [UserRecord]
    @State private var auth = AuthService.shared

    @State private var editName = ""
    @State private var saved = false

    /// Cross-device-synced UserRecord row for the current auth user, if
    /// hydrated. Returns nil for legacy users whose record predates the
    /// Phase 4 columns or for fresh installs that haven't synced yet.
    private var currentUserRecord: UserRecord? {
        guard let userId = auth.currentUser?.id.uuidString, !userId.isEmpty else { return nil }
        return userRecords.first { $0.id == userId }
    }

    /// Selected bodyFocus, preferring the synced UserRecord value over
    /// the @AppStorage mirror. Falls back to the mirror for legacy users
    /// whose UserRecord.onboardingBodyFocus is still empty (pre-DB-migration).
    private var currentBodyFocus: String {
        if let record = currentUserRecord, let first = record.onboardingBodyFocus.first {
            return first
        }
        return bodyFocus
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
                        let selected = currentBodyFocus == option.value
                        Button {
                            Haptics.light()
                            selectBodyFocus(option.value)
                        } label: {
                            HStack {
                                Text(option.label)
                                    .font(Typo.body)
                                    .foregroundStyle(Palette.textPrimary)
                                Spacer()
                                if selected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Palette.accent)
                                }
                            }
                            .padding(14)
                            .background(selected ? Palette.accent.opacity(0.08) : Palette.bgElevated)
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

    /// Persist a bodyFocus selection to all three surfaces:
    ///   - @AppStorage mirror   (PaywallView fast read on this device)
    ///   - legacy userGoal      (HomeView WorkoutGoal resolution)
    ///   - UserRecord + Supabase (cross-device sync)
    /// All three writes are best-effort; the AppStorage + userGoal
    /// updates never fail, the SwiftData/Supabase write swallows errors
    /// the same way handleOnboardingComplete does.
    private func selectBodyFocus(_ value: String) {
        bodyFocus = value
        userGoal = legacyUserGoal(for: value)

        if let record = currentUserRecord {
            record.onboardingBodyFocus = [value]
            record.onboardingFocusArea = focusAreaFromBodyFocus(value)
            try? modelContext.save()
            Task { await AppSync.shared.upsertUser(record) }
        }
    }

    /// Match PlankAIApp's bodyFocus → focusArea mapping so the legacy
    /// `onboarding_focus_area` column stays in sync when EditProfile
    /// changes the selection.
    private func focusAreaFromBodyFocus(_ value: String) -> String {
        switch value {
        case "flatBelly": return "abs"
        default:          return "fullCore"
        }
    }
}
