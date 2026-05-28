import SwiftUI
import SwiftData
import PlankSync
import Auth

/// The profile/settings hub — entry point from the home top-bar avatar,
/// replacing the old SF-Symbol overflow menu. An emotional identity header
/// (the winner pattern across Sweat/Noom/Finch/Duolingo) over branded
/// sticker-icon rows that push the existing on-brand settings sub-screens.
///
/// Every header value traces to a collected field (data-provenance rule):
/// name (@AppStorage), nurturing "shown up N times" (day_progress count —
/// same metric as the home momentum strip, NOT a streak/flame), goal
/// (bodyFocus), coach (voicePreference), and "becoming since" (earliest
/// session date). Anything with no real data is omitted.
struct ProfileHubView: View {
    @AppStorage("userName") private var userName = ""
    @AppStorage("bodyFocus") private var bodyFocusValue = ""
    @AppStorage("voicePreference") private var voicePreference = "encouraging"
    @AppStorage("jenimethod.last_lesson_completed_id") private var jeniMethodLastCompletedId = 0
    @AppStorage("jenimethod.feature_enabled") private var jeniMethodFlagEnabled = true

    @State private var auth = AuthService.shared
    @Query(sort: \DayProgressRecord.date, order: .reverse) private var allDayProgress: [DayProgressRecord]
    @Query(sort: \SessionLogRecord.completedAt, order: .forward) private var allSessionLogs: [SessionLogRecord]

    private var userId: String? {
        guard let id = auth.currentUser?.id.uuidString, !id.isEmpty else { return nil }
        return id
    }
    private var shownUpCount: Int {
        guard let userId else { return 0 }
        return allDayProgress.filter { $0.userId == userId }.count
    }
    private var becomingSince: String? {
        guard let userId,
              let first = allSessionLogs.first(where: { $0.userId == userId })?.completedAt
        else { return nil }
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: first).lowercased()
    }
    private var goalLabel: String? {
        switch bodyFocusValue {
        case "flatBelly": return "flat belly"
        case "tonedArms": return "toned arms"
        case "roundButt": return "round butt"
        case "slimLegs":  return "slim legs"
        case "fullBody":  return "full body"
        default:          return nil
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.lg) {
                identityHeader
                    .padding(.horizontal, Space.screenPadding)

                VStack(spacing: Space.sm) {
                    coachRow
                    hubRow(title: "edit profile",
                           subtitle: "name · focus · session length",
                           sticker: .bowSatin) { EditProfileView() }
                    hubRow(title: "reminders",
                           subtitle: "when jeni checks in",
                           sticker: .sparkleGlossy) { NotificationSettingsView() }
                    hubRow(title: "account",
                           subtitle: "sign-in & subscription",
                           sticker: .heartLock) { AccountView() }
                    hubRow(title: "feedback",
                           subtitle: "tell us anything ♥",
                           sticker: .starLineart) { FeedbackView() }
                    if jeniMethodFlagEnabled && jeniMethodLastCompletedId >= 14 {
                        hubRow(title: "the jenifit method",
                               subtitle: "re-read your lessons",
                               sticker: .flower3D) { JeniMethodReReadView() }
                    }
                    #if DEBUG
                    hubRow(title: "debug auth",
                           subtitle: "dev only",
                           sticker: .discoBall) { DebugAuthView() }
                    #endif
                }
                .padding(.horizontal, Space.screenPadding)
            }
            .padding(.top, Space.sm)
            .padding(.bottom, 40)
        }
        .background(Palette.bgPrimary)
        .onAppear { Analytics.track(.settingsHubOpened) }
    }

    // MARK: - Identity header

    private var identityHeader: some View {
        let initial = userName.first.map { String($0).uppercased() } ?? ""
        return VStack(alignment: .leading, spacing: Space.md) {
            Text("settings")
                .font(Typo.eyebrow).tracking(2)
                .foregroundStyle(Palette.accent)

            HStack(spacing: Space.md) {
                ZStack {
                    Circle().fill(Palette.accentSubtle).frame(width: 60, height: 60)
                    if initial.isEmpty {
                        Image(StickerName.heartGlossy.assetName)
                            .resizable().scaledToFit().frame(width: 34, height: 34)
                            .opacity(StickerName.heartGlossy.style.opacity)
                    } else {
                        Text(initial)
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 28))
                            .foregroundStyle(Palette.accent)
                    }
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(userName.isEmpty ? "hi there" : userName.lowercased())
                        .font(Typo.heading)
                        .foregroundStyle(Palette.textPrimary)
                    if let becomingSince {
                        Text("becoming since \(becomingSince)")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }

            if shownUpCount > 0 || goalLabel != nil {
                HStack(spacing: Space.sm) {
                    if shownUpCount > 0 {
                        statPill(shownUpCount == 1 ? "shown up once" : "shown up \(shownUpCount)×")
                    }
                    if let goalLabel {
                        statPill(goalLabel)
                    }
                }
            }
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(scrapbookChrome())
    }

    private func statPill(_ text: String) -> some View {
        Text(text)
            .font(Typo.caption)
            .foregroundStyle(Palette.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Palette.accentSubtle.opacity(0.5)))
    }

    // MARK: - Rows

    private var coachRow: some View {
        NavigationLink {
            ChangeTrainerView()
        } label: {
            HStack(spacing: Space.md) {
                Image(CoachAsset.imageName(for: voicePreference))
                    .resizable().scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Palette.accentSubtle, lineWidth: 1.5))
                rowText(title: "your coach", subtitle: CoachAsset.displayName(for: voicePreference))
                Spacer(minLength: 0)
                chevron
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity)
            .background(scrapbookChrome())
        }
        .buttonStyle(.plain)
    }

    private func hubRow<Destination: View>(
        title: String,
        subtitle: String,
        sticker: StickerName,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: Space.md) {
                ZStack {
                    Circle().fill(Palette.accentSubtle.opacity(0.45)).frame(width: 40, height: 40)
                    Image(sticker.assetName)
                        .resizable().scaledToFit().frame(width: 26, height: 26)
                        .opacity(sticker.style.opacity)
                }
                .accessibilityHidden(true)
                rowText(title: title, subtitle: subtitle)
                Spacer(minLength: 0)
                chevron
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity)
            .background(scrapbookChrome())
        }
        .buttonStyle(.plain)
    }

    private func rowText(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(Typo.body).fontWeight(.semibold)
                .foregroundStyle(Palette.textPrimary)
            Text(subtitle)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Palette.textSecondary.opacity(0.6))
    }

    private func scrapbookChrome(tint: Color = Palette.accent) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(tint.opacity(0.15))
                .offset(x: 4, y: 4)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Palette.bgElevated)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(tint, lineWidth: 1.5)
        }
    }
}
