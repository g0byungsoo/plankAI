import SwiftUI
import SwiftData
import PlankSync
import PlankFood
import Auth

/// The profile/settings hub. Closes via the morphing ☰↔X mark that floats in
/// HomeView's top-right (kept above this layer), so this view has NO close
/// button — only a clean "back" when inside a sub-screen. The whole thing
/// fades in and the rows reveal one-by-one (staggered), per the mindful-motion
/// rule. State-driven navigation (no NavigationStack) keeps back/close clean.
///
/// Identity header values trace to collected fields (data-provenance):
/// name, nurturing "shown up N times" (day_progress count, NOT a streak),
/// goal (bodyFocus), coach (voicePreference), "becoming since" (earliest
/// session date). Anything with no real data is omitted.
struct ProfileHubView: View {
    /// Closes the whole hub (HomeView animates it out).
    var onClose: () -> Void = {}

    @AppStorage("userName") private var userName = ""
    @AppStorage("bodyFocus") private var bodyFocusValue = ""
    @AppStorage("voicePreference") private var voicePreference = "encouraging"
    @AppStorage("jenimethod.last_lesson_completed_id") private var jeniMethodLastCompletedId = 0
    @AppStorage("jenimethod.feature_enabled") private var jeniMethodFlagEnabled = true

    @State private var stepsService = StepsService.shared

    @State private var auth = AuthService.shared
    @State private var route: HubRoute?
    @State private var revealed = false
    @Query(sort: \DayProgressRecord.date, order: .reverse) private var allDayProgress: [DayProgressRecord]
    @Query(sort: \SessionLogRecord.completedAt, order: .forward) private var allSessionLogs: [SessionLogRecord]

    enum HubRoute: Hashable {
        case myPlan, coach, reminders, account, feedback, jeniMethod, foodSettings
        #if DEBUG
        case debug
        #endif
    }

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
            // Top bar: "back" only inside a sub-screen (left) + a clean close (right).
            HStack {
                if route != nil {
                    Button {
                        Haptics.light()
                        withAnimation(slow) { route = nil }
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
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
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("close")
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.sm)
            .animation(slow, value: route)

            ZStack {
                if let route {
                    destination(for: route).transition(.opacity)
                } else {
                    hubList.transition(.opacity)
                }
            }
            .animation(slow, value: route)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bgPrimary)
        .onAppear {
            Analytics.track(.settingsHubOpened)
            withAnimation { revealed = true }
        }
    }

    // MARK: - Hub list (staggered reveal)

    private var hubList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.lg) {
                identityHeader
                    .padding(.horizontal, Space.screenPadding)
                    .reveal(0, revealed)

                VStack(spacing: Space.sm) {
                    hubRow("my plan", "focus area · session length", .bowSatin, .myPlan, 1)
                    coachRow(2)
                    if FoodFlags.isEnabled {
                        hubRow("food", "calories · cuisine · privacy", .cherries, .foodSettings, 3)
                    }
                    hubRow("reminders", "when jeni checks in", .sparkleGlossy, .reminders, 4)
                    appleHealthRowIfNeeded(index: 4)
                    hubRow("account", "sign-in & subscription", .heartLock, .account, 5)
                    hubRow("feedback", "tell us anything ♥", .starLineart, .feedback, 6)
                    if jeniMethodFlagEnabled && jeniMethodLastCompletedId >= 14 {
                        hubRow("the jenifit method", "re-read your lessons", .flower3D, .jeniMethod, 7)
                    }
                    #if DEBUG
                    hubRow("debug auth", "dev only", .discoBall, .debug, 8)
                    #endif
                }
                .padding(.horizontal, Space.screenPadding)
            }
            .padding(.top, Space.sm)
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private func destination(for route: HubRoute) -> some View {
        switch route {
        case .myPlan:        EditProfileView()
        case .coach:         ChangeTrainerView()
        case .reminders:     NotificationSettingsView()
        case .account:       AccountView()
        case .feedback:      FeedbackView()
        case .jeniMethod:    JeniMethodReReadView()
        case .foodSettings:  FoodSettingsView()
        #if DEBUG
        case .debug:         DebugAuthView()
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

    private func coachRow(_ index: Int) -> some View {
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
        .reveal(index, revealed)
    }

    /// v1.0.7 — recovery surface for users who declined Apple Health
    /// during onboarding and have no other path to enable it. Hidden
    /// when authorized (the home pulse tile already shows live data)
    /// and when unavailable (no recovery possible). The two recoverable
    /// states get distinct tap behavior:
    ///   - .notDetermined → calls `requestAccess()` which fires the
    ///     iOS sheet (first time only — Apple disallows re-prompting).
    ///   - .denied → opens Apple Health → Sources, the only path
    ///     Apple gives us back after the initial decline.
    @ViewBuilder
    private func appleHealthRowIfNeeded(index: Int) -> some View {
        switch stepsService.authStatus {
        case .notDetermined:
            appleHealthRow(
                subtitle: "tap to connect steps",
                action: {
                    Task { await stepsService.requestAccess() }
                },
                index: index + 1
            )
        case .denied:
            appleHealthRow(
                subtitle: "tap to reconnect in apple health",
                action: {
                    if let url = StepsService.openAppleHealthURL,
                       UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    }
                },
                index: index + 1
            )
        case .authorized, .unavailable:
            EmptyView()
        }
    }

    private func appleHealthRow(subtitle: String, action: @escaping () -> Void, index: Int) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: Space.md) {
                ZStack {
                    Circle().fill(Palette.accentSubtle.opacity(0.45)).frame(width: 40, height: 40)
                    Image(StickerName.shoeIridescent.assetName)
                        .resizable().scaledToFit().frame(width: 26, height: 26)
                        .opacity(StickerName.shoeIridescent.style.opacity)
                }
                .accessibilityHidden(true)
                rowText(title: "apple health", subtitle: subtitle)
                Spacer(minLength: 0)
                chevron
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity)
            .background(scrapbookChrome())
        }
        .buttonStyle(.plain)
        .reveal(index, revealed)
        .accessibilityLabel("Apple Health. \(subtitle).")
    }

    private func hubRow(_ title: String, _ subtitle: String, _ sticker: StickerName, _ dest: HubRoute, _ index: Int) -> some View {
        Button {
            Haptics.light()
            withAnimation(slow) { route = dest }
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
        .reveal(index, revealed)
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

// MARK: - Staggered reveal
//
// Each item fades + lifts in, delayed by its index, so the hub reveals
// one-by-one (mindful, no abrupt pop). Driven by a `revealed` flag the hub
// flips true on appear.
private struct RevealModifier: ViewModifier {
    let index: Int
    let revealed: Bool
    func body(content: Content) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 16)
            .animation(.easeOut(duration: 0.5).delay(Double(index) * 0.07), value: revealed)
    }
}

private extension View {
    func reveal(_ index: Int, _ revealed: Bool) -> some View {
        modifier(RevealModifier(index: index, revealed: revealed))
    }
}
