import SwiftUI

// MARK: - StepsPulseTile
//
// The home anchor for movement — small scrapbook card under the workout
// card. Three states drive the UI:
//
//   .notDetermined → calm "tap to connect" CTA over a soft ring stencil,
//                    so the tile feels intentional, not stub-y. Tap fires
//                    StepsService.requestAccess() which surfaces the iOS
//                    HealthKit share sheet.
//   .authorized    → the actual moving-today read: small progress ring
//                    against the 7,500 anchor, current count, italic
//                    Fraunces punch word, anti-shame helper line.
//   .denied / .unavailable → a non-judgmental fallback line that doesn't
//                    re-prompt or shame; the deeper bento tile carries
//                    the same fallback so the home anchor stays clean.
//
// Anti-shame guarantee: under-goal renders the SAME palette as over-goal
// (no red, no warning chrome). The line below the count adapts — "every
// step counts" until you cross the goal, "you went above today" after —
// but the chrome stays warm. Reduce-motion gates the ring-fill spring.

struct StepsPulseTile: View {
    @Bindable var service: StepsService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("steps.last_goal_hit_day") private var lastGoalHitDay: String = ""

    @State private var ringProgress: Double = 0
    @State private var didAnimate = false

    var body: some View {
        Button {
            tap()
        } label: {
            content
                .padding(Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(chrome)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(
            (service.authStatus == .notDetermined || service.authStatus == .denied)
                ? [.isButton] : []
        )
        .task {
            await service.bootstrap()
            await service.refresh()
            await MainActor.run { animateRingIfNeeded() }
            stampGoalHitIfNeeded()
            Analytics.track(.stepsViewedHome, properties: [
                "auth_status": authStatusString,
                "count": service.todayCount
            ])
        }
        .onChange(of: service.todayCount) { _, _ in
            animateRingIfNeeded()
            stampGoalHitIfNeeded()
        }
    }

    // MARK: - Content states

    @ViewBuilder
    private var content: some View {
        switch service.authStatus {
        case .authorized:
            authorizedRow
        case .notDetermined:
            connectRow
        case .denied:
            // v1.0.7 — distinct from .unavailable. Apple's HealthKit
            // won't let us re-prompt the sheet after the user has
            // been asked once, so we surface a deep-link affordance
            // ("tap to open apple health") that takes them to the
            // Sources tab. .unavailable stays passive (no recovery
            // possible).
            reconnectRow
        case .unavailable:
            fallbackRow
        }
    }

    private var authorizedRow: some View {
        HStack(alignment: .center, spacing: Space.md) {
            ring
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("moving")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 18))
                        .foregroundStyle(Palette.textPrimary)
                    Text("today")
                        .font(Typo.body).fontWeight(.semibold)
                        .foregroundStyle(Palette.textSecondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(service.todayCount.formatted(.number))
                        .font(.custom("Fraunces72pt-SemiBold", size: 24))
                        .foregroundStyle(Palette.textPrimary)
                        .contentTransition(.numericText())
                    Text("/ \(StepsService.dailyGoal.formatted(.number))")
                        .font(Typo.caption).foregroundStyle(Palette.textSecondary)
                }
                Text(helperLine)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var connectRow: some View {
        HStack(alignment: .center, spacing: Space.md) {
            ringStencil
            VStack(alignment: .leading, spacing: 2) {
                Text("steps + jeni")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 18))
                    .foregroundStyle(Palette.textPrimary)
                Text("tap to connect apple health")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textPrimary)
                Text("she'll quietly notice the days you moved more ♥")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    /// v1.0.7 — recovery row for the .denied state. Looks the same as
    /// .notDetermined (the cohort can't be expected to remember the
    /// fine distinction between "I tapped allow then said no" vs
    /// "I skipped the prompt"). Tap opens Apple Health → Sources so
    /// the user can flip Steps access back on.
    private var reconnectRow: some View {
        HStack(alignment: .center, spacing: Space.md) {
            ringStencil
            VStack(alignment: .leading, spacing: 2) {
                Text("steps + jeni")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 18))
                    .foregroundStyle(Palette.textPrimary)
                Text("tap to open apple health")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textPrimary)
                Text("turn on steps under sources → jenifit ♥")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    /// .unavailable only — HealthKit isn't supported on this device
    /// (vanishingly rare on iPhone, possible on some iPad variants).
    /// No recovery path possible; copy stays passive and gentle.
    private var fallbackRow: some View {
        HStack(alignment: .center, spacing: Space.md) {
            ringStencil
            VStack(alignment: .leading, spacing: 2) {
                Text("steps live in apple health")
                    .font(Typo.body).fontWeight(.semibold)
                    .foregroundStyle(Palette.textPrimary)
                Text("not available on this device ♥")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Ring

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Palette.divider, lineWidth: 6)
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(Palette.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(StickerName.shoeIridescent.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
                .opacity(StickerName.shoeIridescent.style.opacity * 0.85)
        }
        .frame(width: 56, height: 56)
        .accessibilityHidden(true)
    }

    private var ringStencil: some View {
        ZStack {
            Circle()
                .stroke(Palette.divider, lineWidth: 6)
            Image(StickerName.shoeIridescent.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
                .opacity(StickerName.shoeIridescent.style.opacity * 0.65)
        }
        .frame(width: 56, height: 56)
        .accessibilityHidden(true)
    }

    private var chrome: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Palette.accent.opacity(0.14))
                .offset(x: 4, y: 4)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Palette.bgElevated)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Palette.accent.opacity(0.5), lineWidth: 1.5)
        }
    }

    // MARK: - Copy

    /// Anti-shame helper line. Three reads:
    ///   - over goal → soft praise
    ///   - at/under goal with movement → "every step counts" affirmation
    ///   - zero today → quiet invite ("a little walk later ♥")
    private var helperLine: String {
        let count = service.todayCount
        let goal = StepsService.dailyGoal
        if count >= goal { return "you went above today ♥" }
        if count == 0 { return "a little walk later ♥" }
        return "every step counts ♥"
    }

    private var accessibilityLabel: String {
        switch service.authStatus {
        case .authorized:
            return "Moving today, \(service.todayCount) steps of \(StepsService.dailyGoal). \(helperLine)"
        case .notDetermined:
            return "Steps and Jeni. Tap to connect Apple Health."
        case .denied:
            return "Steps and Jeni. Tap to open Apple Health and turn on steps access."
        case .unavailable:
            return "Steps live in Apple Health. Not available on this device."
        }
    }

    private var authStatusString: String {
        switch service.authStatus {
        case .authorized:    return "authorized"
        case .notDetermined: return "not_determined"
        case .denied:        return "denied"
        case .unavailable:   return "unavailable"
        }
    }

    // MARK: - Behavior

    private func tap() {
        Haptics.light()
        switch service.authStatus {
        case .notDetermined:
            Task { await service.requestAccess() }
        case .denied:
            // v1.0.7 — open Apple Health → Sources tab so the user
            // can navigate to JeniFit and toggle Steps access back
            // on. Apple's HealthKit API doesn't expose a way to
            // re-prompt the system sheet after the first ask, so
            // this deep-link is the only recovery path.
            if let url = StepsService.openAppleHealthURL,
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                Analytics.track(.stepsConnected, properties: [
                    "auth_status": "denied",
                    "action": "opened_apple_health"
                ])
            }
        case .authorized, .unavailable:
            // No-op — the deeper bento tile holds the trend; the
            // pulse stays a glanceable anchor.
            break
        }
    }

    private func animateRingIfNeeded() {
        let target = service.todayProgress
        if reduceMotion {
            ringProgress = target
            return
        }
        // First arrival uses a calmer spring; subsequent updates animate
        // in place via the same token so the ring eases between states.
        if !didAnimate {
            didAnimate = true
            withAnimation(Motion.gentleSpring.delay(0.1)) { ringProgress = target }
        } else {
            withAnimation(Motion.gentleSpring) { ringProgress = target }
        }
    }

    /// Fire `steps_goal_hit` at most once per calendar day, the first
    /// time today's count crosses the goal. UserDefaults-backed day key
    /// survives an app restart so we don't double-fire after a relaunch.
    private func stampGoalHitIfNeeded() {
        guard service.todayCount >= StepsService.dailyGoal else { return }
        let today = todayKey
        guard lastGoalHitDay != today else { return }
        lastGoalHitDay = today
        Analytics.track(.stepsGoalHit, properties: [
            "count": service.todayCount,
            "goal": StepsService.dailyGoal
        ])
    }

    private var todayKey: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

#if DEBUG
#Preview("not determined") {
    StepsPulseTile(service: StepsService.shared)
        .padding()
        .background(Palette.bgPrimary)
}
#endif
