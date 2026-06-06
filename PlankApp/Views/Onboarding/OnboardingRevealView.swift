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
        case permissions
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
                    onContinue: { withAnimation(Motion.crossFade) { step = .permissions } }
                )
                .transition(.opacity)
            case .permissions:
                PairedPermissionsAsk(onContinue: onRevealComplete)
                    .transition(.opacity)
            }
        }
    }

    private func advanceFromBuilding() {
        withAnimation(Motion.crossFade) {
            step = hasProjection ? .projection : .permissions
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
            Palette.bgPrimary.ignoresSafeArea()

            // Delta v8 (2026-06-06) — wrapped scrollable content with
            // pinned CTA. Adding the 5-tile multi-proof grid (D74)
            // grew total content height past the viewport on most
            // devices, cutting headline + CTA. Now content scrolls;
            // CTA stays fixed at the bottom.
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.lg) {
                        Spacer().frame(height: Space.md)

                        ItalicAccentText(
                            "your becoming, plotted",
                            italic: ["plotted"],
                            baseFont: .custom("Fraunces72pt-SemiBold", size: 28),
                            italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 28),
                            color: Palette.textPrimary,
                            alignment: .center
                        )
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
                            goalWeightKg: goalWeightKg,
                            voicePreference: voicePreference
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
                .background(Palette.bgPrimary)
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
    /// reveal pill. ACSM 0.5-1%/wk midpoint (0.75%) of current body
    /// weight projected to goal. Returns lowercase month + day, no
    /// year. Nil when no weight-loss goal is set.
    private var goalDateText: String? {
        guard let curr = currentWeightKg, let goal = goalWeightKg,
              curr > goal else { return nil }
        let toLose = curr - goal
        let weeklyLossKg = curr * 0.0075  // 0.75% of body weight per ACSM
        let weeks = max(2.0, toLose / weeklyLossKg)
        let days = Int((weeks * 7).rounded())
        guard let date = Calendar.current.date(byAdding: .day, value: days, to: .now) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: date).lowercased()
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
        VStack(alignment: .leading, spacing: 12) {
            // Top row: calorie + date — the two anchors of the program.
            HStack(alignment: .top, spacing: 10) {
                proofTile(
                    eyebrow: "calories",
                    value: "\(kcal)",
                    valueFont: .custom("Fraunces72pt-SemiBold", size: 36),
                    sub: estimatedProteinFloor.map { "\($0)g protein floor" } ?? "starting target"
                )
                if let date = goalDateText {
                    proofTile(
                        eyebrow: "by",
                        value: date,
                        valueFont: .custom("Fraunces72pt-SemiBoldItalic", size: 22),
                        sub: "your becoming date"
                    )
                    .frame(width: 130)
                }
            }

            // Bottom row: program proofs Cal AI can't show.
            HStack(spacing: 10) {
                proofTile(
                    eyebrow: "ritual",
                    value: "5-min",
                    valueFont: .custom("Fraunces72pt-SemiBold", size: 22),
                    sub: "plank a day"
                )
                proofTile(
                    eyebrow: "method",
                    value: "14-day",
                    valueFont: .custom("Fraunces72pt-SemiBold", size: 22),
                    sub: "becoming arc"
                )
            }

            Text("a starting plan — we'll tune yours over the first few weeks ♥")
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
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: Space.lg) {
                Spacer(minLength: Space.xl)

                ItalicAccentText(
                    "two quiet things to switch on",
                    italic: ["quiet"],
                    baseFont: .custom("Fraunces72pt-SemiBold", size: 26),
                    italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 26),
                    color: Palette.textPrimary,
                    alignment: .center
                )
                .opacity(heroVisible ? 1 : 0)
                .scaleEffect(heroVisible ? 1.0 : 0.96)

                Text("optional. you can change either later in settings.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg)
                    .opacity(heroVisible ? 1 : 0)

                VStack(spacing: Space.md) {
                    permissionRow(
                        title: "steps from health",
                        body: "we read your step count to show one calm tile, never to score you.",
                        requested: healthRequested,
                        loading: requestingHealth,
                        action: requestHealthAccess
                    )
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
            let granted = await NotificationPermission.request()
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
