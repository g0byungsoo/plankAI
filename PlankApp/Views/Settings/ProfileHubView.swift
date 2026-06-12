import SwiftUI
import SwiftData
import PlankSync
import PlankFood
import Auth

/// The profile/settings hub. v1.1 clean-luxury pass: the scrapbook
/// card rows became hairline-ruled editorial lists (SettingsChrome),
/// the identity moment opens the page as a monogram + folio line, and
/// the one jewel is the mother-of-pearl sheen drifting across the
/// monogram ring.
///
/// State-driven navigation (no NavigationStack) keeps back/close clean.
/// Identity values trace to collected fields (data provenance): name,
/// program day (ProgramScheduleCalculator), "shown up N times"
/// (day_progress count, NOT a streak), "becoming since" (earliest
/// session date). Anything with no real data is omitted.
struct ProfileHubView: View {
    /// Closes the whole hub (host animates it out).
    var onClose: () -> Void = {}

    @AppStorage("userName") private var userName = ""
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
        case myPace, coach, reminders, account, feedback, jeniMethod, foodSettings
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
    /// "day N of M" from the active plan — nil pre-enrollment or
    /// post-goal so the folio never shows a stale frame.
    private var programDayLine: String? {
        guard let userId,
              let plan = ProgramService.shared.activePlan(userId: userId, in: modelContext)
        else { return nil }
        let schedule = ProgramScheduleCalculator.compute(
            .init(startDate: plan.startDate, totalDays: plan.totalDays)
        )
        guard !schedule.isPostGoal else { return nil }
        return "day \(schedule.programDay) of \(schedule.totalDays)"
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
        .background(Palette.programEraBg)
        .onAppear {
            Analytics.track(.settingsHubOpened)
            withAnimation { revealed = true }
        }
    }

    // MARK: - Hub list (staggered reveal)

    private var hubList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                identityHeader
                    .reveal(0, revealed)

                Spacer().frame(height: 40)

                SettingsSection(title: "program") {
                    SettingsNavRow(icon: "slider.horizontal.3", title: "my pace") {
                        go(.myPace)
                    }
                    SettingsNavRow(icon: "waveform", title: "coach",
                                   value: CoachAsset.displayName(for: voicePreference)) {
                        go(.coach)
                    }
                    if FoodFlags.isEnabled {
                        SettingsNavRow(icon: "fork.knife", title: "food") {
                            go(.foodSettings)
                        }
                    }
                    SettingsNavRow(icon: "bell", title: "reminders") {
                        go(.reminders)
                    }
                    appleHealthRowIfNeeded
                    weightImportRowIfNeeded
                }
                .reveal(1, revealed)

                Spacer().frame(height: 36)

                SettingsSection(title: "account") {
                    SettingsNavRow(icon: "person", title: "account") {
                        go(.account)
                    }
                    SettingsNavRow(icon: "envelope", title: "feedback") {
                        go(.feedback)
                    }
                    if jeniMethodFlagEnabled && jeniMethodLastCompletedId >= 14 {
                        SettingsNavRow(icon: "book.closed", title: "the jenifit method",
                                       value: "re-read") {
                            go(.jeniMethod)
                        }
                    }
                    #if DEBUG
                    SettingsNavRow(icon: "wrench.adjustable", title: "debug auth") {
                        go(.debug)
                    }
                    #endif
                }
                .reveal(2, revealed)
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.sm)
            .padding(.bottom, 48)
        }
    }

    private func go(_ dest: HubRoute) {
        withAnimation(slow) { route = dest }
    }

    @ViewBuilder
    private func destination(for route: HubRoute) -> some View {
        switch route {
        case .myPace:        EditProfileView()
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

    /// Open editorial composition — no card. Monogram in a thin ring
    /// with the pearl sheen, name in the hero serif, then a quiet
    /// folio line built only from real data.
    private var identityHeader: some View {
        let initial = userName.first.map { String($0).lowercased() } ?? "♥\u{FE0E}"
        return VStack(alignment: .leading, spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Palette.accent.opacity(0.55), lineWidth: 1)
                    .frame(width: 72, height: 72)
                Text(initial)
                    .font(.custom("JeniHeroSerif-Italic", size: 34))
                    .foregroundStyle(Palette.accent)
                    .offset(y: -2)
            }
            .iridescentSheen()
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                ItalicAccentText(
                    userName.isEmpty ? "your space." : "\(userName.lowercased())\u{2019}s space.",
                    italic: ["space."],
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                .kerning(-0.4)
                .lineSpacing(Typo.heroHeadlineLineGap)

                if let folio = folioLine {
                    Text(folio)
                        .font(Typo.caption)
                        .kerning(0.4)
                        .foregroundStyle(Palette.cocoaTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Space.md)
    }

    /// "day 12 of 154 · shown up 9 times · since june 2026" — only the
    /// segments backed by real data, dot-separated.
    private var folioLine: String? {
        var parts: [String] = []
        if let programDayLine { parts.append(programDayLine) }
        if shownUpCount > 0 {
            parts.append(shownUpCount == 1 ? "shown up once" : "shown up \(shownUpCount) times")
        }
        if let becomingSince { parts.append("since \(becomingSince)") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Recovery rows

    /// Recovery surface for users who declined Apple Health during
    /// onboarding. Hidden when authorized or unavailable.
    ///   - .notDetermined → requestAccess() fires the iOS sheet (once).
    ///   - .denied → opens Apple Health → Sources, Apple's only re-path.
    @ViewBuilder
    private var appleHealthRowIfNeeded: some View {
        switch stepsService.authStatus {
        case .notDetermined:
            SettingsNavRow(icon: "heart", title: "apple health", value: "connect steps") {
                Task { await stepsService.requestAccess() }
            }
        case .denied:
            SettingsNavRow(icon: "heart", title: "apple health", value: "reconnect") {
                if let url = StepsService.openAppleHealthURL,
                   UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
            }
        case .authorized, .unavailable:
            EmptyView()
        }
    }

    /// Body-mass import enable surface. Smart scales write weight to
    /// Apple Health; one tap turns the typed-weight stream passive
    /// (one-per-day policy, never overwrites a manual log). Hidden
    /// once the permission sheet has been shown (HK read status is
    /// opaque) and when HK unavailable.
    @ViewBuilder
    private var weightImportRowIfNeeded: some View {
        if bodyMassImport.authStatus == .notDetermined {
            SettingsNavRow(icon: "scalemass", title: "weight",
                           value: "syncs from apple health") {
                guard let userId = AuthService.shared.currentUser?.id.uuidString,
                      !userId.isEmpty else { return }
                Task {
                    await bodyMassImport.requestAccessAndImport(
                        userId: userId, into: modelContext
                    )
                }
            }
        }
    }
}

// MARK: - Staggered reveal
//
// Each block fades + lifts in, delayed by its index, so the page
// reveals top-down (mindful, no abrupt pop).
private struct RevealModifier: ViewModifier {
    let index: Int
    let revealed: Bool
    func body(content: Content) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 14)
            .animation(.easeOut(duration: 0.5).delay(Double(index) * 0.08), value: revealed)
    }
}

private extension View {
    func reveal(_ index: Int, _ revealed: Bool) -> some View {
        modifier(RevealModifier(index: index, revealed: revealed))
    }
}
