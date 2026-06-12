import SwiftUI

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

    @State private var step: Step = .building

    private enum Step: Int {
        case building
        case projection
        // v9 P9.1/P9.2 (her75 onboarding restructure): the user holds
        // her plan BEFORE paywall. pacePicker → goalDate → firstWeek
        // form the Program Design chapter. Pace persists via AppStorage
        // so the (eventually trimmed) ProgramSetup post-paywall just
        // reads it back — no second pick.
        case pacePicker
        case goalDate
        case firstWeek
        case permissions
        // v4.5 (2026-06-11) — trial-promise commit beat. The LAST
        // pre-paywall screen: makes the existing TrialEndNotification
        // promise visible before price appears (Cal AI calai40/43,
        // −22% refunds / +10-14% trial start in the 2026 teardowns).
        case trialPromise
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
                    onContinue: { withAnimation(Motion.crossFade) { step = .firstWeek } }
                )
                .transition(.opacity)
            case .firstWeek:
                FirstWeekPresentation(
                    bodyFocus: bodyFocus,
                    sessionLengthKey: sessionLengthKey,
                    onContinue: { withAnimation(Motion.crossFade) { step = .permissions } }
                )
                .transition(.opacity)
            case .permissions:
                PairedPermissionsAsk(onContinue: {
                    withAnimation(Motion.crossFade) { step = .trialPromise }
                })
                .transition(.opacity)
            case .trialPromise:
                TrialPromisePresentation(onContinue: onRevealComplete)
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
// ask. Surfaces 7 tiles — actual workouts generated from her bodyFocus
// + sessionLengthPref — so the user holds her plan before the paywall.
//
// Tier defaults to .medium until the inline pace picker ships in
// P9.2 (designer-recommended). Once that screen lands, the picked
// tier is wired through here instead of the constant.

private struct FirstWeekPresentation: View {

    let bodyFocus: Set<String>
    let sessionLengthKey: String
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

                        Text("seven days, built around what you told us.")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Space.lg)
                            .opacity(heroVisible ? 1 : 0)

                        FirstWeekPreview(
                            tier: IntensityTier(rawValue: pickedTierRaw) ?? .medium,
                            bodyFocus: parsedFocus,
                            sessionLengthMinutes: parsedSessionLength
                        )
                        .opacity(weekVisible ? 1 : 0)
                        .offset(y: weekVisible ? 0 : 12)

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

    private var parsedFocus: [BodyFocus] {
        bodyFocus.compactMap { BodyFocus(rawValue: $0) }
    }

    private var parsedSessionLength: Int {
        switch sessionLengthKey {
        case "five":    return 5
        case "ten":     return 10
        case "fifteen": return 15
        case "twenty":  return 20
        default:        return 7
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
                dot(big: true, tinted: true)
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


// MARK: - TrialPromisePresentation (v4.5, 2026-06-11)
//
// The trial-promise commit beat — final pre-paywall screen. Every row
// states something the app ACTUALLY does (TrialEndNotificationService
// schedules the renewal reminder; the day-2 check-in only fires when
// she consented on case 284). No fabricated promises, no countdown
// theater. her75 register: Didone cascade hero, thin rows, one CTA.

private struct TrialPromisePresentation: View {
    let onContinue: () -> Void

    @AppStorage("onb_consent_day2") private var consentDay2 = false
    @State private var rowsVisible = false
    @State private var ctaVisible = false

    var body: some View {
        ZStack {
            Palette.programBgPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: Space.xl + Space.lg)

                LineCascadeText(
                    lines: [
                        .plain("before the numbers,"),
                        .composite(base: "four promises.", italic: ["promises"]),
                    ],
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    lineSpacing: Typo.heroHeadlineLineGap
                )
                .padding(.horizontal, Space.screenPadding)

                Spacer().frame(height: Space.xl)

                VStack(alignment: .leading, spacing: Space.md) {
                    promiseRow(
                        symbol: "checkmark.circle",
                        line: "your full plan opens today. all of it."
                    )
                    promiseRow(
                        symbol: consentDay2 ? "heart.text.square" : "moon.zzz",
                        line: consentDay2
                            ? "day 2 — one gentle check-in. that's it."
                            : "week one stays quiet. no spam, ever."
                    )
                    promiseRow(
                        symbol: "bell.badge",
                        line: "if you start a trial, we remind you before anything renews."
                    )
                    promiseRow(
                        symbol: "hand.raised",
                        line: "cancel takes two taps in settings. no maze."
                    )
                }
                .padding(.horizontal, Space.screenPadding)
                .opacity(rowsVisible ? 1 : 0)
                .offset(y: rowsVisible ? 0 : 10)

                Spacer()

                // True-alpha it-girl cutout floating on cream (founder
                // round 8: the balcony photo card still carried its own
                // background). Seated tea girl matches the settled,
                // no-tricks mood the promises are making.
                Image("onb-itgirl-promise")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 250)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                    .opacity(rowsVisible ? 1 : 0)

                Spacer().frame(height: Space.lg)
            }
        }
        .safeAreaInset(edge: .bottom) {
            JFContinueButton(label: "continue", action: onContinue)
                .padding(.horizontal, Space.lg)
                .padding(.bottom, Space.md)
                .opacity(ctaVisible ? 1 : 0)
        }
        .task {
            // Rows land after the 2-line cascade (~0.84s) finishes.
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            withAnimation(Motion.entrance) { rowsVisible = true }
            try? await Task.sleep(nanoseconds: 350_000_000)
            withAnimation(Motion.entrance) { ctaVisible = true }
        }
    }

    private func promiseRow(symbol: String, line: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Palette.accent)
                .frame(width: 22)
            Text(line)
                .font(Typo.body)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
