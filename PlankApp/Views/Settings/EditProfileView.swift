import SwiftUI
import SwiftData
import PlankSync
import Auth

struct EditProfileView: View {
    // The bodyFocus AppStorage mirror stays as the on-device fast path
    // (PaywallView still reads it). Cross-device truth lives on the
    // UserRecord row pulled from Supabase — when present, it overrides
    // the local mirror so a user signed in on a fresh device sees their
    // synced selection.
    @AppStorage("bodyFocus") private var bodyFocus = ""
    @AppStorage("userGoal") private var userGoal = ""
    @AppStorage("sessionLengthPref") private var sessionLengthPref = 7
    /// Persistent workout-level baseline (-1 gentle · 0 steady · +1 more).
    /// Local device pref (no DB sync); the home card regenerates on change.
    @AppStorage("workoutLevel") private var workoutLevel = 0

    @Environment(\.modelContext) private var modelContext
    @Query private var userRecords: [UserRecord]
    @State private var auth = AuthService.shared

    /// Cross-device-synced UserRecord row for the current auth user, if
    /// hydrated. Returns nil for legacy users whose record predates the
    /// Phase 4 columns or for fresh installs that haven't synced yet.
    private var currentUserRecord: UserRecord? {
        guard let userId = auth.currentUser?.id.uuidString, !userId.isEmpty else { return nil }
        // Prefer @Query (auto-refreshes the view); fall back to a direct
        // SwiftData fetch on the write path so a brief snapshot lag right
        // after hydration doesn't silently skip the upsert.
        if let hit = userRecords.first(where: { $0.id == userId }) { return hit }
        let descriptor = FetchDescriptor<UserRecord>(predicate: #Predicate { $0.id == userId })
        return try? modelContext.fetch(descriptor).first
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

    /// Persistent level options — feeling words, no numbers/RPE/"tier".
    private var levelOptions: [(label: String, value: Int)] {
        [("keep it gentle", -1), ("steady", 0), ("a little more", 1)]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.lg) {
                header

                section(title: "focus area") {
                    VStack(spacing: Space.sm) {
                        ForEach(goalOptions, id: \.value) { option in
                            optionRow(
                                label: option.label,
                                selected: currentBodyFocus == option.value
                            ) {
                                Haptics.light()
                                selectBodyFocus(option.value)
                            }
                        }
                    }
                }

                section(title: "session length") {
                    // Match the onboarding options exactly so a user can
                    // change to any value they could have picked during
                    // onboarding (the "7" default is a legacy fallback for
                    // users who skipped — never offered as a real choice).
                    HStack(spacing: Space.sm) {
                        ForEach([5, 10, 15, 20], id: \.self) { mins in
                            lengthChip(mins)
                        }
                    }
                }

                section(title: "my level") {
                    VStack(spacing: Space.sm) {
                        ForEach(levelOptions, id: \.value) { option in
                            optionRow(label: option.label, selected: workoutLevel == option.value) {
                                Haptics.light()
                                workoutLevel = option.value
                            }
                        }
                    }
                }

                Spacer().frame(height: Space.xl)
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.md)
        }
        .background(Palette.programEraBg)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("your program")
                .font(Typo.eyebrow).tracking(2)
                .foregroundStyle(Palette.accent)
            Text("my plan.")
                .font(Typo.titleItalic)
                .foregroundStyle(Palette.textPrimary)
            Text("jeni built this for you. tweak it anytime.")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Heart sticker — caring-for-self framing, low-key on the page.
        .overlay(alignment: .topTrailing) {
            Image(StickerName.heartGlossy.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(12))
                .offset(x: 4, y: -8)
                .opacity(StickerName.heartGlossy.style.opacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Section

    private func section<Content: View>(
        title: String,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(title)
                .font(Typo.eyebrow).tracking(3)
                .foregroundStyle(Palette.textSecondary)
                .padding(.bottom, 2)
            content()
        }
    }

    // MARK: - Rows

    private func optionRow(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(Typo.body)
                    .foregroundStyle(selected ? Palette.textInverse : Palette.textPrimary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Palette.textInverse)
                }
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Palette.accent.opacity(0.15))
                        .offset(x: 4, y: 4)
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(selected ? Palette.accent : Palette.bgElevated)
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Palette.accent, lineWidth: 1.5)
                }
            )
        }
        .buttonStyle(SettingsPressStyle())
    }

    private func lengthChip(_ mins: Int) -> some View {
        let isSelected = sessionLengthPref == mins
        return Button {
            Haptics.light()
            selectSessionLength(mins)
        } label: {
            Text("\(mins) min")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                .foregroundStyle(isSelected ? Palette.textInverse : Palette.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Palette.accent.opacity(0.15))
                            .offset(x: 3, y: 3)
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(isSelected ? Palette.bgInverse : Palette.bgElevated)
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(isSelected ? Palette.bgInverse : Palette.accent, lineWidth: 1.5)
                    }
                )
        }
        .buttonStyle(SettingsPressStyle())
    }

    // v8 P8.10: local scrapbookChrome removed (was unused — the
    // pickerCard above inlines its own selected-state chrome).
    // Unified scrapbook surface: `View.scrapbookCard(tint:)`.

    /// Persist session length to AppStorage + UserRecord + Supabase.
    /// pendingUpsert guarantees the cloud push happens even if the
    /// fire-and-forget Task dies before completing (force-quit, network
    /// drop) — retryPendingUpserts on next launch picks it up before
    /// hydrate would overwrite local with the stale cloud value.
    private func selectSessionLength(_ mins: Int) {
        sessionLengthPref = mins
        if let record = currentUserRecord {
            record.onboardingSessionLengthPref = mins
            record.pendingUpsert = true
            try? modelContext.save()
            Task { await AppSync.shared.upsertUser(record) }
        }
    }

    private var goalOptions: [(label: String, value: String)] {
        [
            ("flat belly",                "flatBelly"),
            ("toned arms",                "tonedArms"),
            ("round butt",                "roundButt"),
            ("slim legs",                 "slimLegs"),
            ("full body transformation",  "fullBody"),
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
            record.pendingUpsert = true
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

/// Subtle press feedback shared by every scrapbook tappable in settings.
private struct SettingsPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(Motion.tap, value: configuration.isPressed)
    }
}
