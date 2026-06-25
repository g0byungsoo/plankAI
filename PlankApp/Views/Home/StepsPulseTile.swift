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
    // v1.1.2 (2026-06-25) — the authorized tap now opens the steps deep-read.
    @State private var showDetail = false

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
        .sheet(isPresented: $showDetail) {
            StepsDetailSheet(service: service)
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
        case .authorized:
            // v1.1.2 (2026-06-25) — was a no-op ("nothing pops up").
            // Now opens the premium steps deep-read: iridescent energy
            // ring, calories-from-steps + distance derived from her
            // weight, and the 7-day rhythm.
            showDetail = true
            Analytics.track(.stepsViewedHome, properties: [
                "surface": "detail",
                "count": service.todayCount
            ])
        case .unavailable:
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

// MARK: - StepsEnergy
//
// Transparent, body-derived estimate of distance + energy from a step
// count. Distance = steps × an average walking stride (0.74m — height
// isn't collected, so we use the population mean rather than fabricate a
// per-user value); energy = distance(km) × weight(kg) × 0.57, the
// widely-used net cost of walking. Both are honest derivations of REAL
// inputs (HealthKit steps + onboarding weight), never device-measured —
// the UI says "from your steps" so the provenance reads true, and the
// voice avoids the "burn" labor verb (post-ozempic vocabulary): it is
// "energy," framed the same calm way as the Becoming "moved" tile.
struct StepsEnergy {
    let steps: Int
    let weightKg: Double

    /// Average adult walking stride. Height isn't collected; this is the
    /// population mean, not a per-user fabrication.
    private var strideM: Double { 0.74 }
    var distanceKm: Double { Double(steps) * strideM / 1000.0 }
    var distanceMi: Double { distanceKm * 0.621371 }
    /// Net walking energy cost ≈ 0.57 kcal per kg per km.
    var kcal: Int { max(0, Int((distanceKm * weightKg * 0.57).rounded())) }
}

// MARK: - StepsDetailSheet
//
// The premium deep-read behind the home steps tile (authorized tap was
// previously a no-op — "nothing pops up"). An iridescent energy ring
// (custom `iridescentRingFlow` Metal shader) with a count-up center,
// the body-derived energy + distance the rail was missing, and a 7-day
// rhythm chart. Cream restraint, anti-shame chrome (no red, no
// "behind"), her75 voice. Reduce-Motion safe throughout.
struct StepsDetailSheet: View {
    @Bindable var service: StepsService
    #if DEBUG
    /// Sim has no HealthKit data; the `--debug-steps-detail` harness
    /// injects representative values so the screen can be screenshotted.
    var debugToday: Int? = nil
    var debugWeek: [Int]? = nil
    #endif

    @AppStorage("onboardingCurrentWeightKg") private var weightKg: Double = 0
    @AppStorage("weightUnit") private var weightUnitRaw: String = "lb"
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var ringProgress: Double = 0
    @State private var countShown: Int = 0
    @State private var revealStats = false
    @State private var revealBars = false

    // MARK: Derived data

    private var todayCount: Int {
        #if DEBUG
        if let debugToday { return debugToday }
        #endif
        return service.todayCount
    }
    private var weeklyCounts: [Int] {
        #if DEBUG
        if let debugWeek { return debugWeek }
        #endif
        return service.weeklyCounts
    }
    private var weekTotal: Int { weeklyCounts.reduce(0, +) }
    private var weekAvg: Int { weeklyCounts.isEmpty ? 0 : weekTotal / weeklyCounts.count }
    private var todayProgress: Double {
        min(1, Double(todayCount) / Double(StepsService.dailyGoal))
    }
    private var effectiveWeightKg: Double { weightKg > 0 ? weightKg : 65 }
    private var energy: StepsEnergy { StepsEnergy(steps: todayCount, weightKg: effectiveWeightKg) }
    private var imperial: Bool { weightUnitRaw == "lb" }
    private var distanceValue: String {
        String(format: "%.1f", imperial ? energy.distanceMi : energy.distanceKm)
    }

    // MARK: Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Space.xl) {
                header
                ringHero
                statTrio
                weekSection
                footnote
                Spacer(minLength: Space.md)
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.lg)
        }
        .background(Palette.bgPrimary.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .task { await service.refresh() }
        .onAppear { runIn() }
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            (Text("moving ").font(.custom("Fraunces72pt-SemiBoldItalic", size: 26))
             + Text("today").font(.custom("Fraunces72pt-SemiBold", size: 26)))
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Palette.bgElevated))
                    .overlay(Circle().stroke(Palette.divider, lineWidth: 1))
            }
            .accessibilityLabel("Close")
        }
    }

    private var ringHero: some View {
        VStack(spacing: Space.md) {
            ZStack {
                Circle().stroke(Palette.divider.opacity(0.55), lineWidth: 14)
                StepsIridescentArc(progress: ringProgress, lineWidth: 14, reduceMotion: reduceMotion)
                VStack(spacing: 1) {
                    Text(countShown.formatted(.number))
                        .font(.custom("Fraunces72pt-SemiBold", size: 42))
                        .foregroundStyle(Palette.textPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("of \(StepsService.dailyGoal.formatted(.number)) steps")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                .padding(.horizontal, 30)
            }
            .frame(width: 232, height: 232)

            Text(helperLine)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                .foregroundStyle(Palette.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(todayCount) steps of \(StepsService.dailyGoal). \(helperLine)")
    }

    private var statTrio: some View {
        HStack(spacing: Space.sm) {
            StepsStatChip(value: "\(energy.kcal)", unit: "kcal", caption: "energy", accent: true)
            StepsStatChip(value: distanceValue, unit: imperial ? "mi" : "km", caption: "walked")
            StepsStatChip(value: weekAvg.formatted(.number), unit: "/day", caption: "this week")
        }
        .opacity(revealStats ? 1 : 0)
        .offset(y: revealStats ? 0 : 12)
    }

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .firstTextBaseline) {
                (Text("your ").font(.custom("Fraunces72pt-SemiBold", size: 18))
                 + Text("week").font(.custom("Fraunces72pt-SemiBoldItalic", size: 18)))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text("\(weekTotal.formatted(.number)) steps")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            StepsWeekBars(
                counts: weeklyCounts,
                goal: StepsService.dailyGoal,
                reveal: revealBars,
                reduceMotion: reduceMotion
            )
            .frame(height: 132)
        }
        .padding(Space.md)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.bgElevated))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Palette.divider, lineWidth: 1))
    }

    private var footnote: some View {
        Text("energy + distance are gentle estimates from your steps ♥")
            .font(.custom("DMSans-Regular", size: 11))
            .foregroundStyle(Palette.textSecondary.opacity(0.8))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: Copy

    private var helperLine: String {
        if todayCount >= StepsService.dailyGoal { return "you went above today ♥" }
        if todayCount == 0 { return "a little walk later ♥" }
        return "every step counts ♥"
    }

    // MARK: Choreography

    private func runIn() {
        if reduceMotion {
            ringProgress = todayProgress
            countShown = todayCount
            revealStats = true
            revealBars = true
            return
        }
        Haptics.light()
        withAnimation(Motion.gentleSpring.delay(0.12)) { ringProgress = todayProgress }
        animateCount(to: todayCount)
        withAnimation(.easeOut(duration: 0.5).delay(0.28)) { revealStats = true }
        withAnimation(.easeOut(duration: 0.4).delay(0.4)) { revealBars = true }
    }

    /// Eased count-up on the ring center. ~0.9s, ease-out cubic so the
    /// last digits settle slowly (the Apple Fitness "number roll" feel).
    private func animateCount(to target: Int) {
        guard target > 0 else { countShown = 0; return }
        let frames = 26
        let duration = 0.9
        for i in 0...frames {
            let p = Double(i) / Double(frames)
            let eased = 1 - pow(1 - p, 3)
            DispatchQueue.main.asyncAfter(deadline: .now() + duration * p) {
                countShown = Int((Double(target) * eased).rounded())
            }
        }
    }
}

// MARK: - StepsIridescentArc
//
// The trimmed progress arc, its accent stroke recolored every frame by
// the `iridescentRingFlow` Metal shader so a warm rose→peach shimmer
// rotates slowly around the filled portion. The shader respects the
// stroke's alpha, so round caps + the trim endpoint stay crisp. A soft
// accent glow sits under it for depth. Reduce-Motion freezes the sweep.
private struct StepsIridescentArc: View {
    let progress: Double
    let lineWidth: CGFloat
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { geo in
            let s = geo.size
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { ctx in
                let t = reduceMotion
                    ? Float(0)
                    : Float(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600))
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Palette.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .colorEffect(ShaderLibrary.iridescentRingFlow(
                        .float(t),
                        .float2(Float(s.width), Float(s.height))
                    ))
                    .shadow(color: Palette.accent.opacity(0.28), radius: 9)
            }
        }
    }
}

// MARK: - StepsStatChip

private struct StepsStatChip: View {
    let value: String
    let unit: String
    let caption: String
    var accent: Bool = false

    var body: some View {
        VStack(spacing: 3) {
            (Text(value).font(.custom("Fraunces72pt-SemiBold", size: 21))
             + Text(" \(unit)").font(.custom("DMSans-Medium", size: 11)))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.md)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accent ? Palette.accent.opacity(0.12) : Palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent ? Palette.accent.opacity(0.45) : Palette.divider, lineWidth: 1)
        )
    }
}

// MARK: - StepsWeekBars
//
// Seven days, oldest → today. Today is the filled accent bar; prior days
// are quiet cocoa. A faint dashed line marks the 7,500 anchor. Bars rise
// with a left→right cascade. Anti-shame: no red, no "behind" — a missed
// day is just a short bar, never a warning.
private struct StepsWeekBars: View {
    let counts: [Int]
    let goal: Int
    let reveal: Bool
    let reduceMotion: Bool

    private var maxCount: Int { max(goal, counts.max() ?? 1, 1) }

    var body: some View {
        GeometryReader { geo in
            let n = max(counts.count, 1)
            let labelH: CGFloat = 16
            let areaH = max(0, geo.size.height - labelH - 6)
            let spacing: CGFloat = 9
            let barW = max(6, (geo.size.width - spacing * CGFloat(n - 1)) / CGFloat(n))
            let goalY = areaH - areaH * CGFloat(min(1.0, Double(goal) / Double(maxCount)))

            ZStack(alignment: .topLeading) {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: goalY))
                    p.addLine(to: CGPoint(x: geo.size.width, y: goalY))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                .foregroundStyle(Palette.textSecondary.opacity(0.3))

                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(0..<n, id: \.self) { i in
                        let isToday = i == n - 1
                        let frac = Double(counts[i]) / Double(maxCount)
                        let h = max(counts[i] > 0 ? 6 : 3, areaH * CGFloat(frac))
                        VStack(spacing: 6) {
                            Color.clear
                                .frame(width: barW, height: areaH)
                                .overlay(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(isToday ? Palette.accent : Palette.accent.opacity(0.22))
                                        .frame(width: barW, height: reveal ? h : 0)
                                        .animation(
                                            reduceMotion ? nil : Motion.gentleSpring.delay(Double(i) * 0.05),
                                            value: reveal
                                        )
                                }
                            Text(dayLabel(i))
                                .font(.custom("DMSans-Medium", size: 10))
                                .foregroundStyle(isToday ? Palette.textPrimary : Palette.textSecondary)
                        }
                    }
                }
            }
        }
    }

    /// Very-short weekday initial for the bar `i` (index 6 = today).
    private func dayLabel(_ i: Int) -> String {
        let cal = Calendar.current
        let daysAgo = (counts.count - 1) - i
        guard let date = cal.date(byAdding: .day, value: -daysAgo, to: Date()) else { return "" }
        let wd = cal.component(.weekday, from: date) - 1
        let syms = cal.veryShortWeekdaySymbols
        return (wd >= 0 && wd < syms.count) ? syms[wd] : ""
    }
}

#if DEBUG
/// Root preview for `--debug-steps-detail` — injects representative
/// values (the sim has no HealthKit data) so the deep-read renders.
struct StepsDetailDebugHarness: View {
    var body: some View {
        StepsDetailSheet(
            service: StepsService.shared,
            debugToday: 6243,
            debugWeek: [4120, 8900, 5600, 9100, 3200, 7450, 6243]
        )
    }
}
#endif
