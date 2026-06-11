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
    @State private var bodyMassImport = BodyMassImportService.shared
    @Environment(\.modelContext) private var modelContext

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
        // v8 P8.10: programEraBg keeps cream for legacy users + pink
        // for program-era. Hub is reached from PlanView + ProgressGrid
        // ellipsis on every session so the canvas must flip.
        .background(Palette.programEraBg)
        .onAppear {
            Analytics.track(.settingsHubOpened)
            withAnimation { revealed = true }
        }
    }

    // MARK: - Hub list (staggered reveal)

    private var hubList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.lg) {
                // her75 Phase 6 — Archetype D page hero (audit §7).
                JFPageHero(title: "your space.", italic: ["your"], alignment: .leading)
                    .reveal(0, revealed)

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
                    weightImportRowIfNeeded(index: 5)
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
        // her75 Phase 6 — breadcrumb eyebrow dropped; the page hero
        // ("*your* space.") renders at hubList level ABOVE this card.
        // This view is now the pure identity module (avatar + name +
        // pills) in editorialCard chrome.
        return VStack(alignment: .leading, spacing: Space.md) {
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
        .editorialCard()
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
            .editorialCard()
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

    /// v1.1 Becoming P2 — body-mass import recovery/enable surface.
    /// Smart scales + other apps write weight to Apple Health; one tap
    /// here turns the typed-weight stream passive (the import respects
    /// the one-per-day policy and never overwrites a manual log).
    /// Hidden once the permission sheet has been shown (HK read status
    /// is opaque; re-prompting is impossible) and when HK unavailable.
    @ViewBuilder
    private func weightImportRowIfNeeded(index: Int) -> some View {
        if bodyMassImport.authStatus == .notDetermined {
            Button {
                Haptics.light()
                guard let userId = AuthService.shared.currentUser?.id.uuidString,
                      !userId.isEmpty else { return }
                Task {
                    await bodyMassImport.requestAccessAndImport(
                        userId: userId, into: modelContext
                    )
                }
            } label: {
                HStack(spacing: Space.md) {
                    ZStack {
                        Circle().fill(Palette.accentSubtle.opacity(0.45)).frame(width: 40, height: 40)
                        Image(StickerName.butterflyRing.assetName)
                            .resizable().scaledToFit().frame(width: 26, height: 26)
                            .opacity(StickerName.butterflyRing.style.opacity)
                    }
                    .accessibilityHidden(true)
                    rowText(title: "weight from apple health",
                            subtitle: "your scale syncs, no typing")
                    Spacer(minLength: 0)
                    chevron
                }
                .padding(Space.md)
                .frame(maxWidth: .infinity)
                .editorialCard()
            }
            .buttonStyle(.plain)
            .reveal(index, revealed)
            .accessibilityLabel("Weight from Apple Health. Your scale syncs, no typing.")
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
            .editorialCard()
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
            .editorialCard()
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

    // v8 P8.10: local scrapbookChrome helper removed — unified into
    // `View.scrapbookCard(tint:)` in DesignSystem/Tokens.swift. The
    // shared version uses `Palette.programCard` (#FFFFFF) instead of
    // the old `bgElevated` cream, which fixes the muddy-cream-on-pink
    // look once the hub flipped to programEraBg.
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
