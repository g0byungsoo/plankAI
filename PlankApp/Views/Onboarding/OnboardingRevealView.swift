import SwiftUI
import UserNotifications

// MARK: - OnboardingRevealView
//
// Onboarding v2 reveal sequence — sits between the last onboarding
// question and the existing onComplete(data) hand-off. Composes 3 screens:
//
//   1. BuildingPlanLoadingView   — 25s of "we're computing your becoming
//                                  plan" with personalized sub-labels.
//   2. ProjectionPresentation    — full-bleed BecomingProjectionCard so
//                                  the curve is the whole hero, not a
//                                  small tile inside a paywall.
//   3. PairedPermissionsAsk      — HealthKit + Notifications on one
//                                  screen with one Continue. Post-reveal
//                                  asks land far better than mid-onboarding
//                                  asks because the user has already
//                                  emotionally signed in to the plan.
//
// The original 4-screen plan had a MirrorSummary "your X → plan choice"
// beat between projection + permissions. Cut because the founder felt it
// read as filler — the user has just answered 60+ questions, reflecting
// 3 of them back doesn't add new information.
//
// When the projection step is unavailable (no weight-loss goal set, so
// the curve can't render), the sequence skips it rather than showing
// an empty card. Continue from the final step calls onRevealComplete()
// which hands back to OnboardingView's existing onComplete(data) flow.

struct OnboardingRevealView: View {
    let bodyFocus: Set<String>
    let sessionLengthKey: String
    let voicePreference: String
    let commitmentDaysKey: String
    let currentWeightKg: Double?
    let goalWeightKg: Double?
    let onRevealComplete: () -> Void

    @State private var step: Step

    init(
        bodyFocus: Set<String>,
        sessionLengthKey: String,
        voicePreference: String,
        commitmentDaysKey: String,
        currentWeightKg: Double?,
        goalWeightKg: Double?,
        onRevealComplete: @escaping () -> Void,
        debugStartAtFirstWeek: Bool = false,
        debugStartAtAssessment: Bool = false,
        debugStartAtCommitment: Bool = false
    ) {
        self.bodyFocus = bodyFocus
        self.sessionLengthKey = sessionLengthKey
        self.voicePreference = voicePreference
        self.commitmentDaysKey = commitmentDaysKey
        self.currentWeightKg = currentWeightKg
        self.goalWeightKg = goalWeightKg
        self.onRevealComplete = onRevealComplete
        // DEBUG harness can jump straight to the first-week beat so the
        // screen is screenshot-able without the building loader (and its
        // ATT modal / manual "see your plan" tap). Production always
        // starts at .building.
        self._step = State(initialValue: debugStartAtCommitment ? .commitment : debugStartAtAssessment ? .assessment : debugStartAtFirstWeek ? .firstWeek : .building)
    }

    private enum Step: Int {
        case building
        case projection
        // v9 P9.1/P9.2 (her75 onboarding restructure): the user holds
        // her plan BEFORE paywall. pacePicker → goalDate → assessment
        // → firstWeek form the Program Design chapter. Pace persists
        // via AppStorage so the (eventually trimmed) ProgramSetup
        // post-paywall just reads it back - no second pick.
        case pacePicker
        case goalDate
        // Assessment-as-payoff: lands after the goal-date reveal so
        // the user sees her arc validated by the inputs she gave us
        // before we advance to the first-week preview. Dual-register
        // card (JeniHeroSerif identity + DMSans data + provenance +
        // credibility beat + earned-progress label).
        case assessment
        case firstWeek
        case permissions
        // Task 7 (2026-06-28) - commitment ritual. The LAST
        // pre-paywall screen: one small promise the user makes for
        // tomorrow, in her own words, which schedules a Day-1 nudge.
        // Replaces the now-dead TrialPromisePresentation (no-trial
        // decision landed as part of the phase-1a activation pass).
        case commitment
    }

    private var hasProjection: Bool {
        if let curr = currentWeightKg, let goal = goalWeightKg, curr > goal {
            return true
        }
        return false
    }

    var body: some View {
        ZStack {
            switch step {
            case .building:
                BuildingPlanLoadingView(
                    bodyFocus: bodyFocus,
                    sessionLengthKey: sessionLengthKey,
                    voicePreference: voicePreference,
                    commitmentDaysKey: commitmentDaysKey,
                    onComplete: { advanceFromBuilding() }
                )
                .transition(.opacity)
            case .projection:
                ProjectionPresentation(
                    currentWeightKg: currentWeightKg,
                    goalWeightKg: goalWeightKg,
                    voicePreference: voicePreference,
                    onContinue: { withAnimation(Motion.crossFade) { step = .pacePicker } }
                )
                .transition(.opacity)
            case .pacePicker:
                PacePickerPresentation(
                    currentWeightKg: currentWeightKg ?? 65,
                    goalWeightKg: goalWeightKg ?? 60,
                    onContinue: { withAnimation(Motion.crossFade) { step = .goalDate } }
                )
                .transition(.opacity)
            case .goalDate:
                GoalDateRevealPresentation(
                    currentWeightKg: currentWeightKg ?? 65,
                    goalWeightKg: goalWeightKg ?? 60,
                    onContinue: { withAnimation(Motion.crossFade) { step = .assessment } }
                )
                .transition(.opacity)
            case .assessment:
                AssessmentPresentation(
                    currentWeightKg: currentWeightKg ?? 65,
                    goalWeightKg: goalWeightKg ?? 60,
                    onContinue: { withAnimation(Motion.crossFade) { step = .firstWeek } }
                )
                .transition(.opacity)
            case .firstWeek:
                FirstWeekPresentation(
                    onContinue: { withAnimation(Motion.crossFade) { step = .permissions } }
                )
                .transition(.opacity)
            case .permissions:
                PairedPermissionsAsk(onContinue: {
                    withAnimation(Motion.crossFade) { step = .commitment }
                })
                .transition(.opacity)
            case .commitment:
                CommitmentRitualPresentation(onContinue: onRevealComplete)
                    .transition(.opacity)
            }
        }
    }

    private func advanceFromBuilding() {
        // v9 P9.1/P9.2: building → projection → pacePicker → goalDate
        // → firstWeek → permissions when we have weight data; without
        // weight, skip all derivation-dependent steps and land on
        // firstWeek directly (it still renders with default tier).
        withAnimation(Motion.crossFade) {
            step = hasProjection ? .projection : .firstWeek
        }
    }
}

// MARK: - ProjectionPresentation
//
// Full-bleed wrapper around BecomingProjectionCard. Headline frames the
// card as "your becoming, plotted" — italic-Fraunces punch word per the
// brand voice. The card itself already renders the scrapbook chrome +
// curve + endpoint sticker, so this view only adds the surrounding
// composition (header + Continue).

private struct ProjectionPresentation: View {
    let currentWeightKg: Double?
    let goalWeightKg: Double?
    let voicePreference: String
    let onContinue: () -> Void

    @State private var heroVisible = false
    @State private var calorieVisible = false
    @State private var cardVisible = false
    @State private var contextVisible = false
    @State private var ctaVisible = false
    // v3 P11.6+ (2026-06-10) — per-tile cascade counter for the 6
    // proof tiles. Driven by an async chain that fires after
    // calorieVisible flips true; uses `Motion.cascadeTight = 0.06s`
    // per [[feedback-her75-motion-vocabulary]] so the cluster reads
    // as one moment with a hint of order, not a list animation.
    // Reduce-motion gate: when env value is true, all 6 land
    // immediately (revealedTiles set to 6 in the body's task).
    @State private var revealedTiles: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Delta v7 D68 — diet-first reveal: calorie target hero, weight
    // curve secondary, workout tertiary. Calorie estimate is a rough
    // starting number (Helms-style 22 kcal/kg w/ 1300-2000 clamp); the
    // MacroFactor honesty caption ("we'll learn your real number…")
    // is the trust signal that lets us ship without a full TDEE
    // computation in v1.0.7. Real adaptive TDEE lands in v1.0.8.
    @AppStorage("foodDailyTarget") private var foodDailyTarget: Double = 0

    // v2-A5: surface the credibility-grade inputs back to the user
    // below the projection card so she sees her vulnerable answers
    // were actually used. Only renders chips for fields she filled —
    // empty / "prefer not to say" values drop out so the row never
    // narrates context she didn't give us.
    @AppStorage("onboardingSleepHours")    private var sleepHours: String = ""
    @AppStorage("onboardingEatingCadence") private var eatingCadence: String = ""
    @AppStorage("onboardingHormonalStage") private var hormonalStage: String = ""
    @AppStorage("onboarding_glp1_status")  private var glp1Status: String = ""

    var body: some View {
        ZStack {
            // v8 P8.5: reveal hero — the moment the program clicks
            // into focus. Pink directly (not the conditional helper)
            // so the user crosses INTO the program era visually here.
            Palette.programBgPrimary.ignoresSafeArea()

            // Delta v8 (2026-06-06) — wrapped scrollable content with
            // pinned CTA. Adding the 5-tile multi-proof grid (D74)
            // grew total content height past the viewport on most
            // devices, cutting headline + CTA. Now content scrolls;
            // CTA stays fixed at the bottom.
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.lg) {
                        Spacer().frame(height: Space.md)

                        // v3 P11.6 (2026-06-10) — promoted to heroHeadline
                        // (42pt SemiBold). Plan reveal is THE hero
                        // moment of onboarding; questionHero (34pt)
                        // read as too small after the her75
                        // standardization pass.
                        // v4 R1 (2026-06-10) — CLIP FIX. Founder device
                        // screenshot showed this hero bleeding off both
                        // screen edges: no horizontal padding + no wrap
                        // allowance at 38pt. Padding + fixedSize lets it
                        // wrap inside the safe width.
                        ItalicAccentText(
                            "your becoming, plotted",
                            italic: ["plotted"],
                            baseFont: Typo.heroHeadline,
                            italicFont: Typo.heroHeadlineItalic,
                            color: Palette.textPrimary,
                            alignment: .center
                        )
                        .kerning(-0.4)
                        .lineSpacing(Typo.heroHeadlineLineGap)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Space.screenPadding)
                        .opacity(heroVisible ? 1 : 0)
                        .scaleEffect(heroVisible ? 1.0 : 0.96)

                        Text("here's the shape of the next 12 weeks, drawn from your answers.")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Space.lg)
                            .opacity(heroVisible ? 1 : 0)

                        if let kcal = estimatedCalorieTarget {
                            calorieTargetHero(kcal: kcal)
                                .padding(.horizontal, Space.lg)
                                .opacity(calorieVisible ? 1 : 0)
                                .scaleEffect(calorieVisible ? 1.0 : 0.97)
                        }

                        BecomingProjectionCard(
                            currentWeightKg: currentWeightKg,
                            goalWeightKg: goalWeightKg
                        )
                        .padding(.horizontal, Space.md)
                        .opacity(cardVisible ? 1 : 0)
                        .scaleEffect(cardVisible ? 1.0 : 0.97)

                        if !contextChips.isEmpty {
                            VStack(alignment: .center, spacing: 6) {
                                Text("your actual context")
                                    .font(.system(size: 10, weight: .medium))
                                    .textCase(.lowercase)
                                    .tracking(0.6)
                                    .foregroundStyle(Palette.textSecondary)
                                FlowingChips(items: contextChips)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, Space.lg)
                            .opacity(contextVisible ? 1 : 0)
                        }

                        Spacer().frame(height: Space.md)
                    }
                }

                // Pinned CTA — always visible regardless of scroll
                // position. Subtle separator above so the boundary
                // reads as intentional, not clipped.
                Button(action: onContinue) {
                    Text("continue")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                        .foregroundStyle(Palette.textInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Palette.bgInverse)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, Space.lg)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .background(Palette.programBgPrimary)
                .opacity(ctaVisible ? 1 : 0)
            }
        }
        .task {
            // Reveal cascade per D68: headline → CALORIE HERO → weight
            // curve → context chips → continue. Calorie lands first
            // because that's the diet-first signal.
            withAnimation(Motion.entrance) { heroVisible = true }
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(Motion.entrance) { calorieVisible = true }
            // Stamp foodDailyTarget so Home reads the same number she
            // saw at reveal (avoids the "where did 1650 come from?"
            // moment on first Home open).
            if let kcal = estimatedCalorieTarget, foodDailyTarget == 0 {
                foodDailyTarget = Double(kcal)
            }
            // v3 P11.6+ — fire the per-tile cascade. Tiles 0-5 land
            // 0.06s apart starting from when the card itself appears,
            // so the cluster reveal feels choreographed instead of
            // a bulk fade. Reduce-motion: snap to 6 immediately.
            if reduceMotion {
                revealedTiles = 6
            } else {
                for i in 0..<6 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * Motion.cascadeTight) {
                        withAnimation(Motion.entranceSoft) {
                            revealedTiles = i + 1
                        }
                    }
                }
            }
            try? await Task.sleep(nanoseconds: 450_000_000)
            withAnimation(Motion.entrance) { cardVisible = true }
            try? await Task.sleep(nanoseconds: 450_000_000)
            withAnimation(Motion.entranceSoft) { contextVisible = true }
            try? await Task.sleep(nanoseconds: 350_000_000)
            withAnimation(Motion.entranceSoft) { ctaVisible = true }
        }
    }

    // MARK: - Calorie target hero (D68)

    /// Compute a starting calorie estimate from current weight using
    /// the Helms-derived rule of thumb for women weight-loss:
    /// ~22 kcal/kg with 1300-2000 clamp. The number is intentionally
    /// rough — the reveal copy + MacroFactor-borrow caption set the
    /// honesty expectation that the app will learn the real number
    /// over the first 2-4 weeks of logged food data. Returns nil if
    /// we don't have a current weight (skip the card entirely).
    private var estimatedCalorieTarget: Int? {
        guard let kg = currentWeightKg, kg > 0 else {
            #if DEBUG
            print("[D68] calorie hero SKIPPED — currentWeightKg=\(currentWeightKg ?? -1)")
            #endif
            return nil
        }
        let raw = Int(kg * 22)
        let clamped = min(max(raw, 1300), 2000)
        #if DEBUG
        print("[D68] calorie hero rendering — kg=\(kg) kcal=\(clamped)")
        #endif
        return clamped
    }

    /// Protein floor — 1.6g/kg current weight (Helms 2014 satiety +
    /// muscle preservation evidence base). Clamps 70-130g.
    private var estimatedProteinFloor: Int? {
        guard let kg = currentWeightKg, kg > 0 else { return nil }
        let raw = Int(kg * 1.6)
        return min(max(raw, 70), 130)
    }

    /// Delta v8 D79 — specific date target ("august 14") for the plan
    /// reveal pill. Routed through ProjectionMath at the user's picked
    /// pace so it matches the pace selector, day-one card, and paywall.
    private var goalDateText: String? {
        guard let curr = currentWeightKg, let goal = goalWeightKg else { return nil }
        return ProjectionMath.formattedLongDate(
            currentKg: curr,
            goalKg: goal,
            paceKey: UserDefaults.standard.string(forKey: ProjectionMath.paceDefaultsKey)
        )
    }

    /// Delta v8 D74 — multi-proof plan reveal. Replaces the single-
    /// number calorie hero with a 5-tile grid per the WL + UX +
    /// monetization briefs studying Cal AI (calai25/24). Tiles surface
    /// the daily-decision proofs the cohort came for: calorie target,
    /// protein floor, date target, plank ritual, becoming arc. Plank
    /// + becoming arc are JeniFit's two non-cloneable program proofs
    /// that Cal AI structurally cannot show.
    @ViewBuilder
    private func calorieTargetHero(kcal: Int) -> some View {
        // v3 P11.6+ — each tile wrapped in `staggeredTile(at:)` so
        // the 6 proof tiles cascade in 0.06s apart instead of all
        // fading together. Driven by `revealedTiles` 0-5 counter
        // that the parent's task animates on reveal.
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                staggeredTile(at: 0) {
                    proofTile(
                        eyebrow: "calories",
                        value: "\(kcal)",
                        valueFont: .custom("Fraunces72pt-SemiBold", size: 36),
                        sub: estimatedProteinFloor.map { "\($0)g protein floor" } ?? "starting target"
                    )
                }
                if let date = goalDateText {
                    staggeredTile(at: 1) {
                        proofTile(
                            eyebrow: "by",
                            value: date,
                            valueFont: .custom("Fraunces72pt-SemiBoldItalic", size: 22),
                            sub: "your becoming date"
                        )
                        .frame(width: 130)
                    }
                }
            }

            HStack(spacing: 10) {
                staggeredTile(at: 2) {
                    proofTile(
                        eyebrow: "ritual",
                        value: "5-min",
                        valueFont: .custom("Fraunces72pt-SemiBold", size: 22),
                        sub: "plank a day"
                    )
                }
                staggeredTile(at: 3) {
                    proofTile(
                        eyebrow: "method",
                        value: "14-day",
                        valueFont: .custom("Fraunces72pt-SemiBold", size: 22),
                        sub: "becoming arc"
                    )
                }
            }

            // v3 P11.1.C — BetterMe S5 5-rail expansion (now 6 with
            // movement + breath). Multi-anchor reveal: every prior
            // Q pays off in a number she can see.
            HStack(spacing: 10) {
                staggeredTile(at: 4) {
                    proofTile(
                        eyebrow: "movement",
                        value: "7,500",
                        valueFont: .custom("Fraunces72pt-SemiBold", size: 22),
                        sub: "steps anchor"
                    )
                }
                staggeredTile(at: 5) {
                    proofTile(
                        eyebrow: "evenings",
                        value: "5-min",
                        valueFont: .custom("Fraunces72pt-SemiBold", size: 22),
                        sub: "breath reset"
                    )
                }
            }

            Text("a starting plan. we'll tune yours over the first few weeks ♥")
                .font(.system(size: 12))
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Palette.accent.opacity(0.18))
                    .offset(x: 5, y: 5)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Palette.bgElevated)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Palette.accent, lineWidth: 1.5)
            }
        )
    }

    /// v3 P11.6+ (2026-06-10) — per-tile cascade wrapper. Tile at
    /// `index` shows once `revealedTiles > index`; off-state is
    /// opacity 0 + 8pt y-offset (matches LineCascadeText's settle).
    /// Animation tied to `revealedTiles` so the parent's stepwise
    /// counter advances drive the per-tile reveal.
    @ViewBuilder
    private func staggeredTile<Content: View>(at index: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(reduceMotion || index < revealedTiles ? 1 : 0)
            .offset(y: reduceMotion || index < revealedTiles ? 0 : 8)
            .animation(.easeOut(duration: 0.32), value: revealedTiles)
    }

    @ViewBuilder
    private func proofTile(eyebrow: String, value: String, valueFont: Font, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(eyebrow)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .tracking(0.8)
                .textCase(.lowercase)
            Text(value)
                .font(valueFont)
                .foregroundStyle(Palette.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(sub)
                .font(.system(size: 11))
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.bgPrimary.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Palette.textPrimary.opacity(0.06), lineWidth: 0.5)
        )
    }

    /// Compose the 2-3 muted context chips from the user's filled
    /// credibility-grade inputs. Each chip is a short lowercase phrase
    /// matching the brand voice — no labels, no values, just the
    /// derived context ("6-7 hr sleep" not "sleep: six7"). Order is
    /// stable so the row reads the same way every time.
    private var contextChips: [String] {
        var chips: [String] = []
        switch sleepHours {
        case "under5":    chips.append("under 5 hr sleep")
        case "five6":     chips.append("5-6 hr sleep")
        case "six7":      chips.append("6-7 hr sleep")
        case "seven8":    chips.append("7-8 hr sleep")
        case "eightPlus": chips.append("8+ hr sleep")
        default: break
        }
        switch eatingCadence {
        case "one_meal":    chips.append("one-meal pattern")
        case "two_meals":   chips.append("two-meal rhythm")
        case "three_meals": chips.append("steady three meals")
        case "grazing":     chips.append("graze pattern")
        case "chaotic":     chips.append("chaos pattern")
        default: break
        }
        switch hormonalStage {
        case "cycling":       chips.append("cycling regularly")
        case "irregular":     chips.append("irregular cycle")
        case "postpartum":    chips.append("postpartum")
        case "perimenopause": chips.append("peri")
        case "postmenopause": chips.append("post")
        default: break
        }
        if glp1Status == "current" {
            chips.append("on GLP-1")
        }
        // Cap at 4 chips so the row never wraps to more than 2 lines.
        return Array(chips.prefix(4))
    }
}

/// Tiny wrap-aware chip row. Each chip is a soft outlined capsule with
/// lowercase text. Used here for the projection context row and any
/// future "her actual answers" surfacing moments. Wraps to multiple
/// rows when the chip count exceeds the available width.
private struct FlowingChips: View {
    let items: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().stroke(Palette.divider, lineWidth: 1)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - PairedPermissionsAsk
//
// HealthKit + Notifications on one screen with one Continue. Each row
// is independently tappable to fire its own iOS permission sheet, but
// the user can press Continue at any time — the design intentionally
// makes both opt-in (not gates). Per peak-end research, asking after
// the reveal (vs. mid-onboarding) materially increases grant rate
// because the user has already emotionally signed in.
//
// Wires to existing services so the grant + scheduling flow stays
// consistent with the Settings tab + StepsPulseTile path:
//   - HealthKit: StepsService.shared.requestAccess()
//   - Notifications: NotificationPermission.request() + scheduleDailyReminder

private struct PairedPermissionsAsk: View {
    let onContinue: () -> Void

    @State private var heroVisible = false
    @State private var rowsVisible = false
    @State private var ctaVisible = false
    @State private var healthRequested = false
    @State private var notifsRequested = false
    @State private var requestingHealth = false
    @State private var requestingNotifs = false

    var body: some View {
        ZStack {
            // v8 P8.5: permissions screen ships at the tail of the
            // reveal cascade — keep the pink continuity through to
            // the paywall handoff.
            Palette.programBgPrimary.ignoresSafeArea()

            VStack(spacing: Space.lg) {
                Spacer(minLength: Space.xl)

                // v3 P11.1.C (2026-06-10) — HK ask moved to mid-
                // onboarding (case 285, Cal AI S5). This screen is now
                // notifications-only. Headline updated from "two quiet
                // things" → "one quiet ritual ping ♥" per her75 editorial
                // register (silent sub, single hero).
                // her75 Phase 4 — promoted 26pt custom → 38pt
                // heroHeadline (the ONE in-app register, Archetype B).
                ItalicAccentText(
                    "one quiet ritual ping.",
                    italic: ["quiet"],
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    color: Palette.textPrimary,
                    alignment: .center
                )
                .kerning(-0.4)
                .lineSpacing(Typo.heroHeadlineLineGap)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Space.screenPadding)
                .opacity(heroVisible ? 1 : 0)
                .scaleEffect(heroVisible ? 1.0 : 0.96)

                VStack(spacing: Space.md) {
                    permissionRow(
                        title: "a daily ritual ping",
                        body: "one gentle nudge a day. no streak-loss threats.",
                        requested: notifsRequested,
                        loading: requestingNotifs,
                        action: requestNotifications
                    )
                }
                .padding(.horizontal, Space.md)
                .opacity(rowsVisible ? 1 : 0)

                Spacer()

                JFContinueButton(label: "continue", action: onContinue)
                    .padding(.horizontal, Space.lg)
                    .padding(.bottom, 32)
                    .opacity(ctaVisible ? 1 : 0)
            }
        }
        .task {
            withAnimation(Motion.entrance) { heroVisible = true }
            try? await Task.sleep(nanoseconds: 320_000_000)
            withAnimation(Motion.entrance) { rowsVisible = true }
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(Motion.entranceSoft) { ctaVisible = true }
        }
    }

    private func permissionRow(
        title: String,
        body: String,
        requested: Bool,
        loading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Space.md) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.custom("Fraunces72pt-SemiBold", size: 17))
                        .foregroundStyle(Palette.textPrimary)
                    Text(body)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if loading {
                    ProgressView()
                        .controlSize(.small)
                } else if requested {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Palette.accent)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("allow")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                        .foregroundStyle(Palette.accent)
                }
            }
            .padding(16)
            .scrapbookCardBackground()
        }
        .buttonStyle(.plain)
        .disabled(requested || loading)
    }

    private func requestHealthAccess() {
        guard !requestingHealth, !healthRequested else { return }
        requestingHealth = true
        Task {
            await StepsService.shared.requestAccess()
            await MainActor.run {
                withAnimation(Motion.entranceSoft) {
                    requestingHealth = false
                    healthRequested = true
                }
            }
        }
    }

    private func requestNotifications() {
        guard !requestingNotifs, !notifsRequested else { return }
        requestingNotifs = true
        Task {
            let granted = await NotificationPermission.requestOrOpenSettings()
            if granted {
                // Schedule the default 8am reminder. Settings tab still
                // lets the user change time + voice afterwards; this is
                // just so a granted permission produces an actual cue
                // by tomorrow instead of waiting for a manual schedule.
                let cal = Calendar.current
                let defaultTime = cal.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
                NotificationPermission.scheduleDailyReminder(at: defaultTime)
            }
            await MainActor.run {
                withAnimation(Motion.entranceSoft) {
                    requestingNotifs = false
                    notifsRequested = true
                }
            }
        }
    }
}

#Preview {
    OnboardingRevealView(
        bodyFocus: ["flatBelly"],
        sessionLengthKey: "ten",
        voicePreference: "encouraging",
        commitmentDaysKey: "five",
        currentWeightKg: 75,
        goalWeightKg: 65,
        onRevealComplete: {}
    )
}

// MARK: - FirstWeekPresentation
//
// v9 P9.1 (her75 onboarding restructure). The "your first week" beat
// that lands between the weight projection and the paired permissions
// ask, so the user holds her plan before the paywall. The 7-day strip
// (FirstWeekPreview) mirrors the real program rhythm — archetype day
// identity + tier-driven workout cadence + real week-1 minutes — all
// keyed off the tier the user just picked on PacePicker (read back
// from the onboardingPickedTier AppStorage key, default .medium).

private struct FirstWeekPresentation: View {

    let onContinue: () -> Void

    // v9 P9.2: tier is now read from AppStorage so the week reflects
    // whatever the user just picked on PacePicker. The pickedTier
    // value also persists across to ProgramSetup post-paywall (one
    // pick, two consumers).
    @AppStorage("onboardingPickedTier") private var pickedTierRaw: String = "medium"

    @State private var heroVisible = false
    @State private var weekVisible = false
    @State private var ctaVisible = false

    var body: some View {
        ZStack {
            // Same pink canvas as the projection step — continuity into
            // the next reveal beat.
            Palette.programBgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.lg) {
                        Spacer().frame(height: Space.xl)

                        // v3 P11.6 — promoted to heroHeadline 42pt.
                        ItalicAccentText(
                            "your first week.",
                            italic: ["first"],
                            baseFont: Typo.heroHeadline,
                            italicFont: Typo.heroHeadlineItalic,
                            color: Palette.textPrimary,
                            alignment: .center
                        )
                        .kerning(-0.4)
                        .lineSpacing(Typo.heroHeadlineLineGap)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Space.screenPadding)
                        .opacity(heroVisible ? 1 : 0)
                        .scaleEffect(heroVisible ? 1.0 : 0.96)

                        Text("the rhythm your plan runs on.")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Space.lg)
                            .opacity(heroVisible ? 1 : 0)

                        // The strip owns its own reveal — tiles deal in
                        // on a left→right cascade (see DayTile.task), so
                        // no group opacity/offset gating here.
                        FirstWeekPreview(
                            tier: IntensityTier(rawValue: pickedTierRaw) ?? .medium
                        )

                        Text("you can change pace or rest days anytime.")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.textSecondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Space.lg)
                            .opacity(weekVisible ? 1 : 0)

                        // v4.6 (2026-06-11) — it-girl cutout fills the
                        // dead space under the strip (founder QA: screen
                        // read as empty below the cards).
                        Image("onb-itgirl-firstweek")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 280)
                            .frame(maxWidth: .infinity)
                            .accessibilityHidden(true)
                            .opacity(weekVisible ? 1 : 0)
                            .offset(y: weekVisible ? 0 : 12)

                        Spacer().frame(height: Space.lg)
                    }
                }

                Button(action: onContinue) {
                    Text("continue")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                        .foregroundStyle(Palette.textInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Palette.bgInverse)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, Space.lg)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .background(Palette.programBgPrimary)
                .opacity(ctaVisible ? 1 : 0)
            }
        }
        .task {
            withAnimation(Motion.entrance) { heroVisible = true }
            try? await Task.sleep(nanoseconds: 280_000_000)
            withAnimation(Motion.entrance) { weekVisible = true }
            try? await Task.sleep(nanoseconds: 320_000_000)
            withAnimation(Motion.entranceSoft) { ctaVisible = true }
        }
    }
}

// MARK: - PacePickerPresentation (v9 P9.2)
//
// "how fast feels right?" — the her75-onboarding-register intensity
// picker. Three scrapbookCards stacked (NOT pills; pills compress
// too much for first contact). Per-tier subtitle pulls from
// ProgramGoalCalculator.Window so the user sees their actual derived
// week count inline. Selection writes onboardingPickedTier; both
// FirstWeekPresentation and (eventually) ProgramSetupSubflow read
// from the same key — one pick, every downstream consumer respects it.

private struct PacePickerPresentation: View {

    let currentWeightKg: Double
    let goalWeightKg: Double
    let onContinue: () -> Void

    @AppStorage("onboardingPickedTier") private var pickedTierRaw: String = "medium"
    @AppStorage("onboardingHormonalStage") private var hormonalStage: String = ""
    @AppStorage("onboarding_glp1_status")  private var glp1Status: String = ""
    // v3 P11.2 (2026-06-10) — sleep now load-bearing in the engine.
    @AppStorage("onboardingSleepHours")    private var sleepHours: String = ""

    @State private var heroVisible = false
    @State private var rowsVisible = false
    @State private var ctaVisible = false

    private var window: ProgramGoalCalculator.Window {
        ProgramGoalCalculator.compute(.init(
            currentWeightKg: currentWeightKg,
            goalWeightKg: goalWeightKg,
            sex: .female,
            age: nil,
            // v3 P11.2 (2026-06-10) — routed through engine-v2 helpers
            // so cohort-flag mappings stay DRY. Sleep now adjusts the
            // window per Nedeltcheva 2010 (~55% fat-loss penalty at
            // <6h, mostly traded for lean-mass cost).
            isGLP1User:        ProgramGoalCalculator.isGLP1User(from: glp1Status),
            isPerimenopausal:  ProgramGoalCalculator.isPerimenopausal(from: hormonalStage),
            isShortSleeper:    ProgramGoalCalculator.isShortSleeper(from: sleepHours)
        ))
    }

    var body: some View {
        ZStack {
            Palette.programBgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.lg) {
                        Spacer().frame(height: Space.xl)

                        // v3 P11.6 — promoted to heroHeadline 42pt.
                        ItalicAccentText(
                            "how fast feels right?",
                            italic: ["right"],
                            baseFont: Typo.heroHeadline,
                            italicFont: Typo.heroHeadlineItalic,
                            color: Palette.textPrimary,
                            alignment: .center
                        )
                        .kerning(-0.4)
                        .lineSpacing(Typo.heroHeadlineLineGap)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Space.screenPadding)
                        .opacity(heroVisible ? 1 : 0)
                        .scaleEffect(heroVisible ? 1.0 : 0.96)

                        Text("ACSM-safe range. you can change this later.")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.textSecondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Space.lg)
                            .opacity(heroVisible ? 1 : 0)

                        VStack(spacing: 12) {
                            paceRow(tier: .soft,   title: "soft",   tagline: "0.5% a week. room for life.")
                            paceRow(tier: .medium, title: "steady", tagline: "0.75% a week. most chosen.")
                            paceRow(tier: .hard,   title: "focused", tagline: "1% a week. fastest healthy pace.")
                        }
                        .padding(.horizontal, Space.lg)
                        .opacity(rowsVisible ? 1 : 0)
                        .offset(y: rowsVisible ? 0 : 12)

                        Spacer().frame(height: Space.lg)
                    }
                }

                Button(action: onContinue) {
                    Text("continue")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                        .foregroundStyle(Palette.textInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Palette.bgInverse)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, Space.lg)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .background(Palette.programBgPrimary)
                .opacity(ctaVisible ? 1 : 0)
            }
        }
        .task {
            withAnimation(Motion.entrance) { heroVisible = true }
            try? await Task.sleep(nanoseconds: 250_000_000)
            withAnimation(Motion.entrance) { rowsVisible = true }
            try? await Task.sleep(nanoseconds: 280_000_000)
            withAnimation(Motion.entranceSoft) { ctaVisible = true }
        }
    }

    private func paceRow(tier: IntensityTier, title: String, tagline: String) -> some View {
        let selected = pickedTierRaw == tier.rawValue
        // Pace unification (2026-06-11): row weeks come from the same
        // ProjectionMath the pace selector + paywall use, so the number
        // here never disagrees with the dates she already saw.
        let weeks = ProjectionMath.projectedWeeks(
            currentKg: currentWeightKg,
            goalKg: goalWeightKg,
            paceKey: ProjectionMath.paceKey(forTier: tier.rawValue)
        ) ?? window.weeks(for: tier)
        return Button {
            Haptics.light()
            pickedTierRaw = tier.rawValue
            // Write back to the canonical pace key so every downstream
            // surface (goal-date reveal, paywall chart, day-one card)
            // re-dates with the re-picked pace.
            UserDefaults.standard.set(
                ProjectionMath.paceKey(forTier: tier.rawValue),
                forKey: ProjectionMath.paceDefaultsKey
            )
        } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Typo.heading)
                        .foregroundStyle(Palette.cocoaPrimary)
                    Text(tagline)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(weeks)")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22))
                        .foregroundStyle(Palette.accent)
                    Text("weeks")
                        .font(Typo.eyebrow)
                        .tracking(1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.cocoaTertiary)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(selected ? Palette.accentSubtle.opacity(0.45) : Palette.programCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        selected ? Palette.cocoaPrimary : Palette.accent.opacity(0.5),
                        lineWidth: 1.5
                    )
            )
            .programPaperShadow()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) pace, \(weeks) weeks, \(tagline)\(selected ? ", selected" : "")")
    }
}

// MARK: - GoalDateRevealPresentation (v9 P9.2)
//
// "you'll get there by {Month Day}." — derived from picked tier +
// ProgramGoalCalculator.Window. Read-only on purpose; the designer
// rejected a free scrubber because the math is the trust, not the
// editability.

private struct GoalDateRevealPresentation: View {

    let currentWeightKg: Double
    let goalWeightKg: Double
    let onContinue: () -> Void

    @AppStorage("onboardingPickedTier") private var pickedTierRaw: String = "medium"
    @AppStorage("onboardingHormonalStage") private var hormonalStage: String = ""
    @AppStorage("onboarding_glp1_status")  private var glp1Status: String = ""
    // v3 P11.2 (2026-06-10) — sleep load-bearing in engine.
    @AppStorage("onboardingSleepHours")    private var sleepHours: String = ""

    @State private var heroVisible = false
    @State private var dateVisible = false
    @State private var ctaVisible = false

    private var tier: IntensityTier {
        IntensityTier(rawValue: pickedTierRaw) ?? .medium
    }

    /// v3 P11.2 (2026-06-10) — single source of truth for the
    /// window. Was inlined twice (goalDate + totalWeeks computed it
    /// separately). Now both share one Inputs construction so a
    /// future signal addition only touches one place.
    private var window: ProgramGoalCalculator.Window {
        ProgramGoalCalculator.compute(.init(
            currentWeightKg: currentWeightKg,
            goalWeightKg: goalWeightKg,
            sex: .female,
            age: nil,
            isGLP1User:       ProgramGoalCalculator.isGLP1User(from: glp1Status),
            isPerimenopausal: ProgramGoalCalculator.isPerimenopausal(from: hormonalStage),
            isShortSleeper:   ProgramGoalCalculator.isShortSleeper(from: sleepHours)
        ))
    }

    // Pace unification (2026-06-11): the reveal date IS the projection
    // date at the picked tier's pace. Window (cohort science) still
    // drives program length elsewhere; the user-facing goal date stays
    // one family across pace selector, day-one card, here, and paywall.
    private var goalDate: Date {
        ProjectionMath.projectedGoalDate(
            currentKg: currentWeightKg,
            goalKg: goalWeightKg,
            paceKey: ProjectionMath.paceKey(forTier: tier.rawValue)
        ) ?? window.goalDate(from: Date(), tier: tier)
    }

    private var goalDateFormatted: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM d"
        return f.string(from: goalDate).lowercased()
    }

    private var totalWeeks: Int {
        ProjectionMath.projectedWeeks(
            currentKg: currentWeightKg,
            goalKg: goalWeightKg,
            paceKey: ProjectionMath.paceKey(forTier: tier.rawValue)
        ) ?? window.weeks(for: tier)
    }

    var body: some View {
        ZStack {
            Palette.programBgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // her75 Phase 4 — Archetype B goal-date reveal.
                // displayHero tokens deprecated per the re-ladder
                // (merged into heroHeadline). Lead-in body line sets
                // the prompt; the date lands as the 38pt italic beat
                // with a paired haptic.
                LineCascadeText(
                    lines: [
                        .plain("you'll get there by"),
                        .italic(goalDateFormatted)
                    ],
                    baseFont: Typo.body,
                    italicFont: Typo.heroHeadlineItalic,
                    color: Palette.cocoaPrimary,
                    alignment: .center,
                    lineSpacing: Typo.heroHeadlineLineGap,
                    perLineDelay: 0.55
                )
                .padding(.horizontal, Space.lg)

                Spacer().frame(height: Space.xl)

                miniTimeline
                    .padding(.horizontal, Space.xl)
                    .opacity(dateVisible ? 1 : 0)

                Spacer()

                Button(action: onContinue) {
                    Text("continue")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                        .foregroundStyle(Palette.textInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Palette.bgInverse)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, Space.lg)
                .padding(.bottom, 24)
                .opacity(ctaVisible ? 1 : 0)
            }
        }
        .task {
            withAnimation(Motion.entrance) { heroVisible = true }
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(Motion.entrance) { dateVisible = true }
            try? await Task.sleep(nanoseconds: 350_000_000)
            withAnimation(Motion.entranceSoft) { ctaVisible = true }
        }
    }

    /// Five dots Today → 25% → 50% → 75% → Goal. Today + Goal are
    /// emphasized; the three quarter ticks are quiet markers so the
    /// horizon reads as substantial without being a literal ruler.
    private var miniTimeline: some View {
        VStack(spacing: 12) {
            HStack {
                Text("today")
                    .font(Typo.eyebrow)
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
                Spacer()
                Text("\(totalWeeks) weeks")
                    .font(Typo.eyebrow)
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
                Spacer()
                Text("goal")
                    .font(Typo.eyebrow)
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
            }
            HStack(spacing: 0) {
                dot(big: true)
                Spacer()
                dot(big: false)
                Spacer()
                dot(big: false)
                Spacer()
                dot(big: false)
                Spacer()
                // v1.6 PEAK #2 (peak-end): a single whisper sparkle on the
                // GOAL endpoint dot the moment the date lands — restrained
                // (one element, ~52pt, one-shot), reduce-motion-gated inside
                // LottieEffectView. The reward is ON the focal point, not
                // scattered across the screen.
                dot(big: true, tinted: true)
                    .overlay {
                        if dateVisible {
                            LottieEffectView(.sparklingHearts, loop: false)
                                .frame(width: 52, height: 52)
                                .allowsHitTesting(false)
                        }
                    }
            }
            .overlay(
                Rectangle()
                    .fill(Palette.cocoaPrimary.opacity(0.12))
                    .frame(height: 1.5)
                    .padding(.horizontal, 6),
                alignment: .center
            )
        }
    }

    private func dot(big: Bool, tinted: Bool = false) -> some View {
        Circle()
            .fill(tinted ? Palette.accent : Palette.cocoaPrimary)
            .frame(width: big ? 12 : 6, height: big ? 12 : 6)
    }
}


// MARK: - AssessmentPresentation (Task 8, 2026-06-28)
//
// "assessment-as-payoff" - premium redesign using the phase-1a
// activation design foundation. 3 vertical zones:
//
//   TOP    - JeniHeroSerif statement headline + arrival date as
//            secondary serif display (the arc endpoint, the payoff).
//
//   MIDDLE - ArcSparkline proof: the shape the headline names.
//            EarnedStickerCluster blooms at the arc arrival side
//            (top trailing) after the draw completes. Plan-reveal
//            family = earned moment; single tasteful cluster, keep-out
//            by placement (bounded diameter x diameter corner overlay).
//
//   DATA   - LabReadoutBlock (pace / arrival / approach rows) +
//            conditional cohort provenance (quiet line) +
//            credibility beat.
//
//   GROUNDED CLOSE - HairlineRule + earned-progress label just above
//   the CTA so the eye lands on completion before the button.
//
// Background: GrainfieldBackground - the alive cream surface. Visually
// distinct from the flat bgPrimary that other screens use and more
// premium for the emotional peak screen.
//
// Motion cascade (reduce-motion safe - foundation components gate their
// own animation internally; all caller-added offset motion is gated on
// the reduceMotion env value):
//   headline -> arrival date -> arc draws -> sticker blooms ->
//   stat block -> provenance -> credibility -> footer -> CTA.
//
// Haptics: prepare() on appear (no-latency first play); arcComplete()
// fires at ~720ms after arcAnimate flips - matching the arc's 700ms
// draw-on duration.
//
// Hard constraints: no red, no em-dashes, no projected weight number,
// lowercase casual copy, reduce-motion safe throughout.

private struct AssessmentPresentation: View {
    let currentWeightKg: Double
    let goalWeightKg: Double
    let onContinue: () -> Void

    @AppStorage("onboarding_glp1_status")  private var glp1Status: String = ""
    @AppStorage("onboardingHormonalStage") private var hormonalStage: String = ""
    @AppStorage("onboardingSleepHours")    private var sleepHours: String = ""
    @AppStorage("onboardingPickedTier")    private var pickedTierRaw: String = "medium"

    // Cascade reveal states - each flips once in the .task chain below
    @State private var heroVisible        = false
    @State private var dateVisible        = false
    @State private var arcAnimate         = false
    @State private var stickerAnimate     = false
    @State private var dataBlockVisible   = false
    @State private var provenanceVisible  = false
    @State private var credibilityVisible = false
    @State private var footerVisible      = false
    @State private var ctaVisible         = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Compute the window once so loss-rate floor + dates share one source.
    private var window: ProgramGoalCalculator.Window {
        ProgramGoalCalculator.compute(.init(
            currentWeightKg: currentWeightKg,
            goalWeightKg: goalWeightKg,
            sex: .female,
            age: nil,
            isGLP1User:       ProgramGoalCalculator.isGLP1User(from: glp1Status),
            isPerimenopausal: ProgramGoalCalculator.isPerimenopausal(from: hormonalStage),
            isShortSleeper:   ProgramGoalCalculator.isShortSleeper(from: sleepHours)
        ))
    }

    /// Weekly loss rate for the lab readout. e.g. "0.5"
    private var lossRatePctText: String {
        String(format: "%.1f", window.lossRateFloor * 100)
    }

    /// Arrival date in "MMM d" format. Matches GoalDateReveal's date via
    /// the same ProjectionMath route (picked pace key). Falls back to "soon"
    /// so the rendered text reads "~soon" rather than crashing.
    private var arrivalDateText: String {
        let paceKey = UserDefaults.standard.string(forKey: ProjectionMath.paceDefaultsKey)
        return ProjectionMath.formattedShortDate(
            currentKg: currentWeightKg,
            goalKg: goalWeightKg,
            paceKey: paceKey
        ) ?? "soon"
    }

    /// One-line provenance explanation tied to the cohort flag that changed
    /// the floor rate. Returns nil when no modifier was applied (default
    /// 0.5%/wk) so the line is fully omitted, not rendered empty.
    private var provenanceLine: String? {
        if ProgramGoalCalculator.isShortSleeper(from: sleepHours) {
            return "because you sleep around 6 hours, we set a gentler pace."
        }
        if ProgramGoalCalculator.isGLP1User(from: glp1Status) {
            return "because of your body's signals right now, we paced this gently."
        }
        if ProgramGoalCalculator.isPerimenopausal(from: hormonalStage) {
            return "because of where your body is, we paced this gently."
        }
        return nil
    }

    var body: some View {
        ZStack {
            // Alive cream canvas - premium surface distinct from flat bgPrimary.
            // Intentional visual breath vs the pink reveal steps that bracket this
            // reflection beat.
            GrainfieldBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: Space.hero)

                    // ZONE 1 - statement: headline + arrival date as serif display
                    VStack(alignment: .leading, spacing: Space.xs) {
                        // Identity line - locked copy, JeniHeroSerif with italic punch
                        ItalicAccentText(
                            "here's your realistic arc.",
                            italic: ["realistic"],
                            baseFont: Typo.heroHeadline,
                            italicFont: Typo.heroHeadlineItalic,
                            color: Palette.textPrimary,
                            alignment: .leading
                        )
                        .kerning(-0.4)
                        .lineSpacing(Typo.heroHeadlineLineGap)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(heroVisible ? 1 : 0)
                        .offset(y: reduceMotion ? 0 : (heroVisible ? 0 : 10))
                        .animation(Motion.entrance, value: heroVisible)

                        // Arrival date promoted to secondary serif display.
                        // This IS the arc's endpoint - the emotional payoff of the
                        // assessment. Italic italic-Fraunces at questionHeroItalic (34pt)
                        // reads as direction + arrival; tilde signals "about" to
                        // match the clinical honesty of the lab readout.
                        Text("~\(arrivalDateText)")
                            .font(Typo.questionHeroItalic)
                            .foregroundStyle(Palette.textSecondary)
                            .opacity(dateVisible ? 1 : 0)
                            .offset(y: reduceMotion ? 0 : (dateVisible ? 0 : 8))
                            .animation(Motion.entrance, value: dateVisible)
                    }
                    .padding(.horizontal, Space.screenPadding)

                    Spacer().frame(height: Space.lg)

                    // ZONE 2 - proof: the arc the headline names.
                    //
                    // ArcSparkline: hairline bezier rising left (today) to right
                    // (arrival). Draw-on starts when arcAnimate flips; the arc
                    // takes ~700ms then a highlight travels and the endpoint blooms.
                    //
                    // EarnedStickerCluster: blooms at the arrival side (top trailing)
                    // after the arc draws. This IS an earned moment (plan-reveal
                    // family) so one tasteful cluster is on-brand. diameter=100 keeps
                    // the cluster bounded within its corner; it cannot bleed into text.
                    ArcSparkline(
                        animate: arcAnimate,
                        startLabel: "today",
                        endpointLabel: arrivalDateText
                    )
                    .frame(height: 120)
                    .padding(.horizontal, Space.md)
                    .earnedStickerCluster(
                        animate: stickerAnimate,
                        stickers: [.flower3D, .heartGlossy, .sparkleGlossy],
                        diameter: 100,
                        alignment: .topTrailing,
                        inset: 4
                    )

                    Spacer().frame(height: Space.section)

                    // ZONE 3 - data: calm lab readout.
                    //
                    // The whole block fades + rises in together when dataBlockVisible
                    // flips. Then provenance (conditional) and credibility stagger
                    // sequentially inside - compound opacity means they're invisible
                    // until the block itself appears, then emerge in order.
                    VStack(alignment: .leading, spacing: Space.md) {
                        LabReadoutBlock(rows: [
                            .init(label: "pace",     value: "\(lossRatePctText)%/wk"),
                            .init(label: "arrival",  value: "~\(arrivalDateText)"),
                            .init(label: "approach", value: "conservative"),
                        ])

                        // Conditional provenance - cohort-specific quiet note.
                        // Fully omitted (not just hidden) when provenanceLine is nil.
                        if let provenance = provenanceLine {
                            Text(provenance)
                                .font(Typo.body)
                                .foregroundStyle(Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .opacity(provenanceVisible ? 1 : 0)
                                .offset(y: reduceMotion ? 0 : (provenanceVisible ? 0 : 5))
                                .animation(Motion.entrance, value: provenanceVisible)
                        }

                        // Credibility beat - locked copy
                        Text("paced like a clinician would. slower is what lasts.")
                            .font(Typo.body)
                            .foregroundStyle(Palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(credibilityVisible ? 1 : 0)
                            .offset(y: reduceMotion ? 0 : (credibilityVisible ? 0 : 5))
                            .animation(Motion.entrance, value: credibilityVisible)
                    }
                    .padding(.horizontal, Space.screenPadding)
                    .opacity(dataBlockVisible ? 1 : 0)
                    .offset(y: reduceMotion ? 0 : (dataBlockVisible ? 0 : 8))
                    .animation(Motion.entrance, value: dataBlockVisible)

                    Spacer().frame(height: Space.lg)

                    // GROUNDED CLOSE - hairline + earned-progress label.
                    //
                    // Sits just above the pinned CTA. The eye travels:
                    //   arc endpoint -> data -> this footer -> button.
                    // Completion is felt before the tap.
                    VStack(alignment: .leading, spacing: Space.sm) {
                        HairlineRule()
                        Text("step 1 of your plan: complete (you did the assessment)")
                            .font(Typo.captionTracked)
                            .foregroundStyle(Palette.textSecondary.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, Space.screenPadding)
                    .opacity(footerVisible ? 1 : 0)
                    .animation(Motion.entranceSoft, value: footerVisible)

                    Spacer().frame(height: Space.lg)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            JFContinueButton(label: "continue", action: onContinue)
                .padding(.horizontal, Space.lg)
                .padding(.bottom, Space.md)
                .opacity(ctaVisible ? 1 : 0)
                .animation(Motion.entranceSoft, value: ctaVisible)
        }
        .task {
            // Warm the haptic engine on appear so the first play has no latency.
            ActivationHaptics.shared.prepare()

            // Cascade: headline -> arrival date -> arc draws ->
            // sticker blooms -> stat block -> provenance ->
            // credibility -> footer -> CTA
            withAnimation(Motion.entrance) { heroVisible = true }
            try? await Task.sleep(nanoseconds: 300_000_000)

            withAnimation(Motion.entrance) { dateVisible = true }
            try? await Task.sleep(nanoseconds: 250_000_000)

            // Arc draw starts. ArcSparkline drives internally:
            // draw-on (~700ms easeOut) -> travel highlight -> arrival bloom.
            // arcComplete() fires at the draw-on endpoint (~720ms).
            arcAnimate = true
            try? await Task.sleep(nanoseconds: 720_000_000)
            ActivationHaptics.shared.arcComplete()

            // Sticker blooms just after arc completes + haptic settles
            try? await Task.sleep(nanoseconds: 80_000_000)
            withAnimation(Motion.bloom) { stickerAnimate = true }

            // Data block fades up as a unit
            try? await Task.sleep(nanoseconds: 200_000_000)
            withAnimation(Motion.entrance) { dataBlockVisible = true }
            try? await Task.sleep(nanoseconds: 350_000_000)

            // Provenance + credibility stagger inside the visible block
            withAnimation(Motion.entrance) { provenanceVisible = true }
            try? await Task.sleep(nanoseconds: 280_000_000)
            withAnimation(Motion.entrance) { credibilityVisible = true }
            try? await Task.sleep(nanoseconds: 280_000_000)

            withAnimation(Motion.entranceSoft) { footerVisible = true }
            try? await Task.sleep(nanoseconds: 350_000_000)
            withAnimation(Motion.entranceSoft) { ctaVisible = true }
        }
    }
}

// MARK: - CommitmentRitualPresentation (Task 7, 2026-06-28 - premium redesign)
//
// Replaces the now-dead TrialPromisePresentation (no-trial decision,
// phase-1a activation pass). The emotional climax of the reveal: one
// small promise for tomorrow, in the user's own words, which schedules
// a Day-1 nudge at the time she chooses.
//
// Layout - three zones stacked tight to kill the hollow middle:
//
//   HERO     - "before the plan, one *promise*." (JeniHeroSerif)
//
//   PANEL    - One unified chip instrument. Rounded card with a
//              barely-there 4% cocoa fill + a visible 22% cocoa border
//              at 1pt. Inside: WHEN / WHAT / TIME groups in tracked-caps
//              micro-labels. Reads as a single instrument being SET,
//              not three loose floating rows.
//
//   PROMISE  - Bridge: tracked-caps "YOUR PROMISE:" in textSecondary
//              (visibly present) + a 20%-cocoa 0.75pt divider line.
//              Then the live replay in JeniHeroSerif below it, so
//              the bridge is visibly the OUTPUT of the panel above.
//
// Motion: staggered cascade (hero -> panel -> bridge label -> replay
// -> CTA). All offset-based motion gated on reduceMotion.
// Haptics: prepare() on appear; tick() on each chip select (scale
// pulse on the chosen chip); commit() on CTA before persist+schedule.
//
// GLP-1 thread: if onboarding_glp1_status == "current", the default
// action chip is "get protein in" and the replay body stays fixed to
// "you'll protect your muscle." Phase-1b deepens this.
//
// On Continue: persists day1PromiseAction/Anchor/TimeISO, schedules
// the one-shot Day-1 nudge via NotificationPermission.scheduleDay1Promise
// if notifications are authorized, then calls onContinue().

private struct CommitmentRitualPresentation: View {
    let onContinue: () -> Void

    @AppStorage("onboarding_glp1_status") private var glp1Status: String = ""
    @AppStorage("onboardingSleepHours")   private var sleepHours: String = ""
    @AppStorage("userName")              private var userName: String = ""

    // Persisted outputs - consumed by Task 10 Day-1 surfacing
    @AppStorage("day1PromiseAction")  private var storedAction: String = ""
    @AppStorage("day1PromiseAnchor")  private var storedAnchor: String = ""
    @AppStorage("day1PromiseTimeISO") private var storedTimeISO: String = ""

    // Chip selections initialized on appear to incorporate AppStorage values.
    @State private var selectedAnchor: String = ""
    @State private var selectedAction: String = ""
    @State private var selectedTime: String = "8am"

    // Cascade reveal states
    @State private var heroVisible         = false
    @State private var chipPanelVisible    = false
    @State private var promiseLabelVisible = false
    @State private var replayVisible       = false
    @State private var ctaVisible          = false

    // Chip pulse - the last chip tapped; cleared after 200ms
    @State private var pulsingChip: String = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: Chip options

    private let anchorChips = ["after coffee", "after i wake up", "after lunch"]
    private let timeChips   = ["8am", "12pm", "6pm"]

    private var actionChips: [String] {
        glp1Status == "current"
            ? ["get protein in", "snap what i eat", "log my first meal"]
            : ["log breakfast", "snap what i eat", "log my first meal"]
    }

    private var defaultAnchor: String {
        ProgramGoalCalculator.isShortSleeper(from: sleepHours) ? "after i wake up" : "after coffee"
    }

    private var defaultAction: String {
        glp1Status == "current" ? "get protein in" : "log breakfast"
    }

    // MARK: Replay line

    // GLP-1 thread: body is fixed to "protect your muscle." regardless
    // of which action chip is selected. Phase-1b ties the action chips
    // back to this line; for now the fixed framing is the safer signal.
    private var replayLine: String {
        if glp1Status == "current" {
            return "tomorrow, \(selectedAnchor), you'll protect your muscle."
        }
        return "tomorrow, \(selectedAnchor), you'll \(selectedAction)."
    }

    private var replayItalicWords: [String] {
        if glp1Status == "current" {
            return [selectedAnchor, "protect your muscle"]
        }
        return [selectedAnchor, selectedAction]
    }

    // Stable id for the replay view - changes on any chip tap that
    // affects the replay text, driving the soft cross-fade transition.
    private var replayID: String { selectedAnchor + selectedAction }

    // MARK: Time-chip to tomorrow Date

    private func tomorrowDate(forTimeChip chip: String) -> Date {
        let hour: Int
        switch chip {
        case "12pm": hour = 12
        case "6pm":  hour = 18
        default:     hour = 8
        }
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    // MARK: Body

    var body: some View {
        ZStack {
            // Premium alive-cream surface. Visually distinct from flat
            // bgPrimary and more grounded for the emotional close beat.
            GrainfieldBackground()

            VStack(alignment: .leading, spacing: 0) {
                // Balanced top inset - matches AssessmentPresentation's Space.hero
                // (was xl+lg=72pt which made the layout aggressively top-loaded).
                Spacer().frame(height: Space.hero)

                // ZONE 1 - Hero: JeniHeroSerif, italic punch on "promise"
                ItalicAccentText(
                    "before the plan, one promise.",
                    italic: ["promise"],
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                .kerning(-0.4)
                .lineSpacing(Typo.heroHeadlineLineGap)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Space.screenPadding)
                .opacity(heroVisible ? 1 : 0)
                .offset(y: reduceMotion ? 0 : (heroVisible ? 0 : 10))
                .animation(Motion.entrance, value: heroVisible)

                // section gap (36pt) between hero and panel - generous
                // but not so large the panel feels separated from the intent.
                Spacer().frame(height: Space.section)

                // ZONE 2 - Unified chip instrument panel.
                // Rounded card with a barely-there 4% cocoa fill and a
                // visible 22%-cocoa 1pt border. The card makes WHEN / WHAT /
                // TIME read as ONE object being set, not three loose rows.
                // 18pt corner radius, 20pt internal padding throughout.
                VStack(alignment: .leading, spacing: Space.md) {
                    chipGroup(label: "WHEN", chips: anchorChips, selected: $selectedAnchor)
                    chipGroup(label: "WHAT", chips: actionChips,  selected: $selectedAction)
                    chipGroup(label: "TIME", chips: timeChips,    selected: $selectedTime)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Palette.cocoaPrimary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Palette.cocoaPrimary.opacity(0.22), lineWidth: 1)
                )
                .padding(.horizontal, Space.screenPadding)
                .opacity(chipPanelVisible ? 1 : 0)
                .offset(y: reduceMotion ? 0 : (chipPanelVisible ? 0 : 10))
                .animation(Motion.entrance, value: chipPanelVisible)

                // Gap between panel and bridge - enough to breathe but
                // tight enough that the replay reads as connected OUTPUT.
                Spacer().frame(height: Space.lg)

                // Bridge: tracked-caps kicker + visible divider line.
                // Marks the transition from input (chip panel) to output
                // (live replay). Uses textSecondary for legibility (was
                // cocoaTertiary=48% which rendered near-invisible on cream).
                // Divider at 20% cocoa reads clearly as a section break
                // without being heavy.
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("your promise:")
                        .font(Typo.kicker)
                        .kerning(0.20 * 10)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.textSecondary)
                    Rectangle()
                        .fill(Palette.cocoaPrimary.opacity(0.20))
                        .frame(height: 0.75)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, Space.screenPadding)
                .opacity(promiseLabelVisible ? 1 : 0)
                .animation(Motion.entranceSoft, value: promiseLabelVisible)

                // Tight gap - replay sits RIGHT under the bridge label so
                // the eye reads "promise: [output below]" not two separate zones.
                Spacer().frame(height: Space.sm)

                // ZONE 3 - Live replay.
                // .id(replayID) + .transition: when a chip changes the
                // replay text, SwiftUI removes the old view and inserts a
                // new one, driving the soft cross-fade. The chip tap wraps
                // the selection in withAnimation so SwiftUI sees the id
                // change inside an animation context.
                ItalicAccentText(
                    replayLine,
                    italic: replayItalicWords,
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                .kerning(-0.4)
                .lineSpacing(Typo.heroHeadlineLineGap)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Space.screenPadding)
                .id(replayID)
                .transition(
                    .opacity.combined(with: .scale(scale: 0.96, anchor: .leading))
                )
                .opacity(replayVisible ? 1 : 0)
                .offset(y: reduceMotion ? 0 : (replayVisible ? 0 : 6))
                .animation(Motion.entrance, value: replayVisible)

                // Bottom breathing room - minLength keeps space for the
                // safeAreaInset CTA without creating a dead hollow zone.
                Spacer(minLength: Space.xl)
            }
        }
        .safeAreaInset(edge: .bottom) {
            JFContinueButton(label: "continue", action: confirmAndContinue)
                .padding(.horizontal, Space.lg)
                .padding(.bottom, Space.md)
                .opacity(ctaVisible ? 1 : 0)
                .animation(Motion.entranceSoft, value: ctaVisible)
        }
        .onAppear {
            // Initialize defaults on appear (not init) so AppStorage
            // values are already resolved before we read them.
            if selectedAnchor.isEmpty { selectedAnchor = defaultAnchor }
            if selectedAction.isEmpty { selectedAction = defaultAction }
        }
        .task {
            // Warm the haptic engine on appear - no latency on first play.
            ActivationHaptics.shared.prepare()

            // Staggered cascade: hero -> chip panel -> bridge label ->
            // replay -> CTA. Tighter gaps than the old version so the
            // screen populates without dragging.
            withAnimation(Motion.entrance) { heroVisible = true }
            try? await Task.sleep(nanoseconds: 400_000_000)
            withAnimation(Motion.entrance) { chipPanelVisible = true }
            try? await Task.sleep(nanoseconds: 350_000_000)
            withAnimation(Motion.entranceSoft) { promiseLabelVisible = true }
            try? await Task.sleep(nanoseconds: 120_000_000)
            withAnimation(Motion.entrance) { replayVisible = true }
            try? await Task.sleep(nanoseconds: 280_000_000)
            withAnimation(Motion.entranceSoft) { ctaVisible = true }
        }
    }

    // MARK: - Chip group

    // label: tracked-caps micro-label (WHEN / WHAT / TIME).
    // On select: tick haptic + scale pulse on the chosen chip (reduce-motion
    // safe - pulse gate inside the scaleEffect). Selection wrapped in
    // withAnimation so the replay .id() change drives the cross-fade.
    @ViewBuilder
    private func chipGroup(label: String, chips: [String], selected: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Typo.kicker)
                .kerning(0.20 * 10)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)

            ChipFlowLayout(spacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    Button {
                        ActivationHaptics.shared.tick()
                        withAnimation(.easeInOut(duration: 0.22)) {
                            selected.wrappedValue = chip
                        }
                        // Scale pulse: set the pulsing chip, clear after the
                        // spring settles (~200ms). Gated via scaleEffect below.
                        guard !reduceMotion else { return }
                        pulsingChip = chip
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                            pulsingChip = ""
                        }
                    } label: {
                        Text(chip)
                            .font(.custom("Fraunces72pt-SemiBold", size: 14))
                            .foregroundStyle(
                                selected.wrappedValue == chip
                                    ? Palette.textInverse
                                    : Palette.cocoaPrimary
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(selected.wrappedValue == chip
                                          ? Palette.bgInverse
                                          : Palette.bgElevated)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        selected.wrappedValue == chip
                                            ? Color.clear
                                            : Palette.divider,
                                        lineWidth: 1
                                    )
                            )
                            // Scale pulse: 1.07 on the tick, springs back to 1.0.
                            // Gated on reduceMotion via the pulsingChip guard above.
                            .scaleEffect(pulsingChip == chip ? 1.07 : 1.0)
                            .animation(
                                .spring(response: 0.22, dampingFraction: 0.58),
                                value: pulsingChip
                            )
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.18), value: selected.wrappedValue)
                }
            }
            // Explicit maxWidth anchors the finite-width proposal that
            // ChipFlowLayout needs in sizeThatFits to compute row breaks.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Confirm + schedule

    private func confirmAndContinue() {
        // Premium haptic commit BEFORE any state mutation. The "this
        // counts" beat fires while the user's finger is still in contact.
        ActivationHaptics.shared.commit()

        // GLP-1 current: effective action matches the on-screen replay.
        let effectiveAction = (glp1Status == "current") ? "protect your muscle" : selectedAction

        // Persist the three AppStorage outputs
        storedAction = effectiveAction
        storedAnchor = selectedAnchor

        let chosenDate = tomorrowDate(forTimeChip: selectedTime)
        storedTimeISO = ISO8601DateFormatter().string(from: chosenDate)

        // Schedule one-shot Day-1 nudge if notifications are authorized.
        // Always build the body (uses her own words); only schedule when
        // the OS will actually deliver it (authorized/provisional).
        let body = NotificationPermission.day1PromiseBody(
            action: effectiveAction,
            anchor: selectedAnchor,
            userName: userName.isEmpty ? nil : userName
        )
        let date = chosenDate
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional {
                NotificationPermission.scheduleDay1Promise(at: date, body: body)
            }
            await MainActor.run { onContinue() }
        }
    }
}

// MARK: - ChipFlowLayout
//
// Left-aligned flow (wrapping) layout for chip rows. Chips size to their
// natural content width; when a chip would overflow the container it starts
// a new row. Keeps the premium capsule style without ever clipping a label.
private struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowH: CGFloat = 0
        for subview in subviews {
            let s = subview.sizeThatFits(.unspecified)
            if x > 0, x + s.width > width {
                y += rowH + spacing; x = 0; rowH = 0
            }
            x += (x > 0 ? spacing : 0) + s.width
            rowH = max(rowH, s.height)
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowH: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += rowH + spacing; x = bounds.minX; rowH = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
    }
}
