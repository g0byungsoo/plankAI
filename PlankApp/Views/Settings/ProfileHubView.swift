import SwiftUI
import SwiftData
import PlankSync
import Auth

/// The profile/settings hub — a full-screen layer (no leaked home wordmark)
/// with its own minimal top bar: a clean "back" when inside a sub-screen and
/// an X to close. Navigation is state-driven (not a NavigationStack) so the
/// back/close affordances are centralized + clean, and every transition is a
/// slow, mindful crossfade (no abrupt slides) per the JeniFit motion rule.
///
/// Identity header values trace to collected fields (data-provenance):
/// name, nurturing "shown up N times" (day_progress count, NOT a streak),
/// goal (bodyFocus), coach (voicePreference), "becoming since" (earliest
/// session date). Anything with no real data is omitted.
struct ProfileHubView: View {
    /// Called by the X to dismiss the whole hub (HomeView animates it out).
    var onClose: () -> Void = {}

    @AppStorage("userName") private var userName = ""
    @AppStorage("bodyFocus") private var bodyFocusValue = ""
    @AppStorage("voicePreference") private var voicePreference = "encouraging"
    @AppStorage("jenimethod.last_lesson_completed_id") private var jeniMethodLastCompletedId = 0
    @AppStorage("jenimethod.feature_enabled") private var jeniMethodFlagEnabled = true

    @State private var auth = AuthService.shared
    @State private var route: HubRoute?
    @Query(sort: \DayProgressRecord.date, order: .reverse) private var allDayProgress: [DayProgressRecord]
    @Query(sort: \SessionLogRecord.completedAt, order: .forward) private var allSessionLogs: [SessionLogRecord]

    enum HubRoute: Hashable {
        case myPlan, coach, reminders, account, feedback, jeniMethod
        #if DEBUG
        case debug
        #endif
    }

    /// Slow, mindful crossfade used for every hub transition.
    private let slow = Animation.easeInOut(duration: 0.5)

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
        VStack(spacing: 0) {
            hubTopBar
            ZStack {
                if let route {
                    destination(for: route)
                        .transition(.opacity)
                } else {
                    hubList
                        .transition(.opacity)
                }
            }
            .animation(slow, value: route)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bgPrimary)
        .onAppear { Analytics.track(.settingsHubOpened) }
    }

    // MARK: - Top bar (back + close)

    private var hubTopBar: some View {
        HStack {
            if route != nil {
                Button {
                    Haptics.light()
                    withAnimation(slow) { route = nil }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text("back").font(Typo.body)
                    }
                    .foregroundStyle(Palette.textSecondary)
                    .tappableArea()
                }
                .transition(.opacity)
            }
            Spacer()
            Button {
                Haptics.light()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Palette.bgElevated)
                    .clipShape(Circle())
                    .tappableArea()
            }
            .accessibilityLabel("close")
        }
        .padding(.horizontal, Space.screenPadding)
        .padding(.vertical, Space.sm)
        .animation(slow, value: route)
    }

    // MARK: - Hub list

    private var hubList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.lg) {
                identityHeader
                    .padding(.horizontal, Space.screenPadding)

                VStack(spacing: Space.sm) {
                    hubRow(title: "my plan", subtitle: "focus area · session length",
                           sticker: .bowSatin, route: .myPlan)
                    coachRow
                    hubRow(title: "reminders", subtitle: "when jeni checks in",
                           sticker: .sparkleGlossy, route: .reminders)
                    hubRow(title: "account", subtitle: "sign-in & subscription",
                           sticker: .heartLock, route: .account)
                    hubRow(title: "feedback", subtitle: "tell us anything ♥",
                           sticker: .starLineart, route: .feedback)
                    if jeniMethodFlagEnabled && jeniMethodLastCompletedId >= 14 {
                        hubRow(title: "the jenifit method", subtitle: "re-read your lessons",
                               sticker: .flower3D, route: .jeniMethod)
                    }
                    #if DEBUG
                    hubRow(title: "debug auth", subtitle: "dev only",
                           sticker: .discoBall, route: .debug)
                    #endif
                }
                .padding(.horizontal, Space.screenPadding)
            }
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private func destination(for route: HubRoute) -> some View {
        switch route {
        case .myPlan:     EditProfileView()
        case .coach:      ChangeTrainerView()
        case .reminders:  NotificationSettingsView()
        case .account:    AccountView()
        case .feedback:   FeedbackView()
        case .jeniMethod: JeniMethodReReadView()
        #if DEBUG
        case .debug:      DebugAuthView()
        #endif
        }
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
        Button {
            Haptics.light()
            withAnimation(slow) { route = .coach }
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

    private func hubRow(title: String, subtitle: String, sticker: StickerName, route: HubRoute) -> some View {
        Button {
            Haptics.light()
            withAnimation(slow) { self.route = route }
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
