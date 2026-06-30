import SwiftUI
import SwiftData
import PlankSync

// MARK: - ProgramSetupSubflow
//
// v1.1 program pivot. 3-page internal flow that asks the user to
// commit to a program: GoalDateReveal → ProgramIntensity →
// CommitmentSignature. Used in two host contexts:
//
//   (1) OnboardingView case 171 — new users post-paywall
//   (2) ProgramOnrampView — Today tab pre-enrollment
//
// Reads collected onboarding values (currentWeightKg, goalWeightKg,
// age, sex, GLP-1, hormonal) from @AppStorage so the subflow can
// run anywhere without needing every host to plumb the data through.
//
// Writes:
//   - ProgramService.startProgram(input:) on Page 3 commit
//   - @AppStorage("hasEnrolledInProgram") = true so the host knows
//     to dismiss + route to PlanView
//
// Founder decisions wired:
//   - Hard tier visible-but-locked via HardTierGate (page 2)
//   - Dynamic in-page reframe per BetterMe pattern #4 (page 1)
//   - "make *it* official" italic-Fraunces ritual copy (page 3)

struct ProgramSetupSubflow: View {

    /// Fires once user completes the subflow (commits in page 3).
    /// Host should dismiss + route the user to PlanView. nil means
    /// the user bailed out (back button on page 1, or host swipe-dismiss).
    let onComplete: (_ committed: Bool) -> Void

    @Environment(\.modelContext) private var modelContext

    // Inputs collected earlier in onboarding — @AppStorage reads them
    // wherever the subflow is hosted (onboarding mid-flow OR the
    // ProgramOnrampView).
    @AppStorage("onboardingCurrentWeightKg") private var currentWeightKg: Double = 65
    @AppStorage("onboardingGoalWeightKg") private var goalWeightKg: Double = 60
    @AppStorage("onboardingAgeRange") private var ageRange: String = ""
    @AppStorage("onboardingActivityLevel") private var activityLevel: String = ""
    @AppStorage("onboarding_glp1_status") private var glp1Status: String = ""
    @AppStorage("onboardingHormonalStage") private var hormonalStage: String = ""
    // v3 P11.2 (2026-06-10) — sleep load-bearing in engine.
    @AppStorage("onboardingSleepHours")    private var sleepHours: String = ""
    // T2 (2026-06-29): weight trend + GLP-1 phase now move pacing.
    @AppStorage("onboarding_weight_trend") private var weightTrend: String = ""
    @AppStorage("onboarding_glp1_phase")   private var glp1Phase: String = ""
    // FIX 4 (2026-06-29): collected gender (case 130) -> BMR-formula sex.
    @AppStorage("onboardingGender")        private var gender: String = ""

    // Height (persisted by onboarding) still feeds the BMI 18.5 goal-weight
    // clamp at program build (safeGoalWeightKg). The safety SCREEN itself
    // moved pre-paywall in T7 (2026-06-29); this subflow no longer reads
    // the safety_* output keys - it trusts the pre-paywall gate.
    @AppStorage("onboardingHeightCm") private var heightCm: Double = 0

    // Authenticated user id used by ProgramService.startProgram.
    // Read from the same source other AppSync calls use (AppSync.shared.currentUserId).
    @State private var userId: String = ""

    // v9 P9.4 — Subflow page state.
    //
    // The page LAYOUT still has 3 phases for existing-user opt-in
    // (via ProgramOnrampView), but new users coming through
    // the v9 onboarding flow have ALREADY picked their pace + seen
    // their derived date in OnboardingRevealView's PacePicker +
    // GoalDateReveal steps. For those users we skip straight to the
    // commitment page so the post-paywall beat is a single celebratory
    // confirmation, not a re-pick.
    //
    // Source of truth: `onboardingPickedTier` AppStorage. If set,
    // hydrate `pickedTier` from it + start on `.commitment`. If unset
    // (existing-user opt-in path), keep the full 3-page flow.
    @AppStorage("onboardingPickedTier") private var onboardingPickedTierRaw: String = ""

    @State private var page: Page = .goalDateReveal
    @State private var pickedTier: IntensityTier = .medium
    @State private var commitWorking: Bool = false

    private enum Page: Int {
        case goalDateReveal = 0
        case intensityPick = 1
        case commitment = 2

        var progress: Double {
            Double(rawValue + 1) / 3.0
        }
    }

    var body: some View {
        // T7 (2026-06-29): the safety gate now runs PRE-paywall inside
        // OnboardingRevealView (SafetyGatePresentation), exactly once. This
        // subflow no longer screens - a screened-out user never reaches the
        // paywall, so by the time we are here the user has passed the gate.
        // ProgramSetupSubflow now only builds the program (pace + commit).
        programBody
            .onAppear { onSetupAppear() }
    }

    private var programBody: some View {
        ZStack {
            Palette.programBgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    Group {
                        switch page {
                        case .goalDateReveal: pageGoalDateReveal
                        case .intensityPick:  pageIntensityPick
                        case .commitment:     pageCommitment
                        }
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                }
                footer
            }
        }
    }

    // T7 (2026-06-29): no safety gate here anymore. Just hydrate the user
    // id and, if onboarding already collected the pace, jump to the commit
    // page (existing-user opt-in keeps the full 3-page flow).
    private func onSetupAppear() {
        userId = AppSync.shared.currentUserId ?? ""
        if let tier = IntensityTier(rawValue: onboardingPickedTierRaw) {
            pickedTier = tier
            page = .commitment
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Space.sm) {
            Button {
                Haptics.light()
                back()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Palette.cocoaPrimary)
                    .frame(width: 40, height: 40)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.divider).frame(height: 4)
                    Capsule().fill(Palette.cocoaPrimary)
                        .frame(width: max(8, geo.size.width * CGFloat(page.progress)), height: 4)
                        .animation(Motion.entrance, value: page)
                }
            }
            .frame(height: 4)
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, 12)
    }

    // MARK: - Page 1: Goal-date reveal
    //
    // Shows the realistic window (min/max weeks) computed from
    // current + goal weight + cohort flags. ACSM 0.5-1%/wk band
    // displayed as a credibility chip. Per BetterMe pattern #4:
    // dynamic reframe based on the picked numbers — % of body weight,
    // benefit stack, BMI safety chip when goal is at-risk.

    private var goalWindow: ProgramGoalCalculator.Window {
        ProgramGoalCalculator.compute(goalInputs)
    }

    private var pctOfWeight: Double {
        ProgramGoalCalculator.pctOfBodyWeight(goalInputs)
    }

    private var goalInputs: ProgramGoalCalculator.Inputs {
        .init(
            currentWeightKg: currentWeightKg,
            goalWeightKg: safeGoalWeightKg,
            sex: ProgramGoalCalculator.sex(fromGenderKey: gender),  // FIX 4: collected gender (case 130)
            age: parsedAge,
            // v3 P11.2 (2026-06-10) — routed through engine-v2 helpers.
            // NB: ProgramSetupSubflow's old check accepted both
            // "perimenopause" and "menopause"; the helper is stricter
            // (perimenopause only). That matches the case 163 option
            // keys (no "menopause" option exists; "postmenopause" has
            // different physiology and stays at default rate).
            isGLP1User:       ProgramGoalCalculator.isGLP1User(from: glp1Status),
            isPerimenopausal: ProgramGoalCalculator.isPerimenopausal(from: hormonalStage),
            isShortSleeper:   ProgramGoalCalculator.isShortSleeper(from: sleepHours),
            weightTrendKey:   weightTrend,
            glp1PhaseKey:     glp1Phase
        )
    }

    // v1.2 medical-grade (2026-06-25) — never build a program targeting a
    // goal below BMI 18.5. The picker already warns (goalWeightAnnotation's
    // under-target state); this enforces it at build so the program math +
    // goal date use the safe floor even if the user slid past the warning.
    // Height comes from onboarding. The gate only checks CURRENT BMI, so
    // without this a healthy-weight user could target an unsafe goal.
    private var safeGoalWeightKg: Double {
        guard heightCm > 0 else { return goalWeightKg }
        return max(goalWeightKg, ProgramGoalCalculator.weightForBMI(18.5, heightCm: heightCm))
    }

    private var parsedAge: Int? {
        switch ageRange {
        case "18-24": return 22
        case "25-34": return 30
        case "35-44": return 39
        case "45-54": return 50
        case "55+":   return 60
        default:      return nil
        }
    }

    private var pageGoalDateReveal: some View {
        VStack(alignment: .leading, spacing: 28) {
            // 1-line hero — short possessive phrases shouldn't be
            // split across 2 lines; orphans the adjective. her75's
            // 2-line pattern needs substance on both halves.
            (
                Text("your ")
                    .font(Typo.programHeroDisplay)
                    .foregroundStyle(Palette.cocoaPrimary)
                +
                Text("plan.")
                    .font(Typo.programHeroItalic)
                    .foregroundStyle(Palette.cocoaPrimary)
            )
            .fixedSize(horizontal: false, vertical: true)

            // Window display: "12 to 25 weeks · realistic glide"
            VStack(alignment: .leading, spacing: 12) {
                if goalWindow.isMaintenance {
                    Text("you're already at or near your goal.")
                        .font(Typo.body)
                        .foregroundStyle(Palette.cocoaSecondary)
                    Text("we'll set you up on a maintenance plan instead.")
                        .font(Typo.body)
                        .foregroundStyle(Palette.cocoaSecondary)
                } else {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text("\(goalWindow.minWeeks)")
                            .font(Typo.numeralHero)
                            .foregroundStyle(Palette.cocoaPrimary)
                            .monospacedDigit()
                        Text("–")
                            .font(Typo.numeralHero)
                            .foregroundStyle(Palette.cocoaTertiary)
                        Text("\(goalWindow.maxWeeks)")
                            .font(Typo.numeralHero)
                            .foregroundStyle(Palette.cocoaPrimary)
                            .monospacedDigit()
                        Text("weeks")
                            .font(Typo.body)
                            .foregroundStyle(Palette.cocoaSecondary)
                            .padding(.leading, 6)
                    }

                    // v8 P8.8: markdown bold `**...**` was rendering
                    // literally inside Typo.body (SwiftUI Text needs
                    // Text(.init(...)) for markdown). Use AttributedString
                    // so the percent stays the visual punch without
                    // changing copy intent.
                    Text(boldedPercentLine(pct: pctOfWeight))
                        .font(Typo.body)
                        .foregroundStyle(Palette.cocoaSecondary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.programCard)
                    .fill(Palette.programCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.programCard)
                    .stroke(Palette.accent.opacity(0.5), lineWidth: 1.5)
            )
            .programPaperShadow()

            // ACSM citation chip — credibility move.
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.stateGood)
                VStack(alignment: .leading, spacing: 4) {
                    Text("the science we follow")
                        .font(Typo.eyebrow)
                        .foregroundStyle(Palette.stateGood)
                        .textCase(.uppercase)
                    Text("0.5 to 1% of your body weight per week. faster than that and the weight comes back. ACSM 2009, Wing & Phelan 2005.")
                        .font(Typo.body)
                        .foregroundStyle(Palette.cocoaSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Palette.stateGood.opacity(0.08))
            )

            // Benefit stack (BetterMe pattern #4 — only on non-maintenance).
            if !goalWindow.isMaintenance {
                VStack(alignment: .leading, spacing: 10) {
                    Text("what changes")
                        .font(Typo.eyebrow)
                        .foregroundStyle(Palette.cocoaTertiary)
                        .textCase(.uppercase)
                    benefitRow("more energy through the afternoon")
                    benefitRow("clothes start fitting how you remember")
                    benefitRow("food noise quiets down")
                    benefitRow("sleep finally feels like rest")
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Radius.programCard)
                        .fill(Palette.programCard)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.programCard)
                        .stroke(Palette.accent.opacity(0.5), lineWidth: 1.5)
                )
                .programPaperShadow()
            }
        }
    }

    /// Builds the percent sentence as an AttributedString so the
    /// number renders bold inside body copy — SwiftUI's Text(_:String)
    /// strips markdown unless wrapped this way.
    private func boldedPercentLine(pct: Double) -> AttributedString {
        var attr = AttributedString("you're aiming to lose ")
        var percent = AttributedString("\(String(format: "%.0f", pct))%")
        percent.font = .custom("Fraunces72pt-SemiBold", size: 16)
        let tail = AttributedString(" of your weight. that's where doctors call it sustainable.")
        attr.append(percent)
        attr.append(tail)
        return attr
    }

    private func benefitRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.stateGood)
                .padding(.top, 4)
            Text(text)
                .font(Typo.body)
                .foregroundStyle(Palette.cocoaSecondary)
        }
    }

    // MARK: - Page 2: Intensity pick (Soft / Medium / Hard)
    //
    // 3 pills. Hard visible-but-locked via HardTierGate. Lock copy
    // explains why — anti-shame, evidence-honest. Founder decision
    // 2026-06-09.

    private var hardGateInputs: HardTierGate.Inputs {
        .init(
            // v3 P11.2 (2026-06-10) — DRY via engine-v2 helpers.
            // HardTierGate doesn't need short-sleep gating (separate
            // gate policy from goal-rate computation), but the GLP-1 +
            // peri mapping benefits from the shared source of truth.
            isGLP1User:       ProgramGoalCalculator.isGLP1User(from: glp1Status),
            isPerimenopausal: ProgramGoalCalculator.isPerimenopausal(from: hormonalStage),
            age: parsedAge,
            activityLevel: mappedActivity
        )
    }

    private var mappedActivity: HardTierGate.Inputs.ActivityLevel {
        switch activityLevel.lowercased() {
        case "sedentary": return .sedentary
        case "lightly_active", "light", "lightly active": return .light
        case "moderate", "moderately_active": return .moderate
        case "active", "very_active": return .active
        case "athlete", "very active": return .veryActive
        default: return .light  // gentle default — won't gate Hard for missing data
        }
    }

    private var hardUnlocked: Bool { HardTierGate.isUnlocked(hardGateInputs) }

    @State private var showHardLockSheet: Bool = false

    private var pageIntensityPick: some View {
        VStack(alignment: .leading, spacing: 28) {
            (
                Text("your ")
                    .font(Typo.programHeroDisplay)
                    .foregroundStyle(Palette.cocoaPrimary)
                +
                Text("pace.")
                    .font(Typo.programHeroItalic)
                    .foregroundStyle(Palette.cocoaPrimary)
            )
            .fixedSize(horizontal: false, vertical: true)

            Text("pick the rhythm. you can change it later.")
                .font(Typo.body)
                .foregroundStyle(Palette.cocoaSecondary)

            VStack(spacing: 14) {
                intensityPill(.soft, isLocked: false)
                intensityPill(.medium, isLocked: false)
                intensityPill(.hard, isLocked: !hardUnlocked)
            }
        }
        .sheet(isPresented: $showHardLockSheet) {
            hardLockSheet
                .presentationDetents([.medium])
        }
    }

    private func intensityPill(_ tier: IntensityTier, isLocked: Bool) -> some View {
        let isSelected = pickedTier == tier
        let profile = IntensityProfile.from(tier: tier)
        let weeks = goalWindow.weeks(for: tier)
        let goalDateString = ProgramScheduleCalculator.dateRangeLowercase(
            startDate: .now,
            totalDays: weeks * 7
        )

        return Button {
            if isLocked {
                Haptics.light()
                showHardLockSheet = true
            } else {
                Haptics.success()
                withAnimation(Motion.gentleSpring) {
                    pickedTier = tier
                }
            }
        } label: {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(tier.label)
                            .font(Typo.heading)
                            .foregroundStyle(Palette.cocoaPrimary)
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.cocoaTertiary)
                        }
                    }
                    Text("\(Int((profile.lossRatePctPerWeek * 100).rounded() * 10) / 10)% per week · \(weeks) weeks")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaSecondary)
                    Text(goalDateString)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaTertiary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(isSelected ? Palette.cocoaPrimary : Palette.cocoaTertiary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.programCard)
                    .fill(isSelected ? Palette.accentSubtle.opacity(0.4) : Palette.programCard)
            )
            // v8 P8.8: selection state stroke wins (cocoaPrimary 1.5pt);
            // unselected state gets the scrapbook accent border so it
            // still reads as the same family as PlanView rows.
            .overlay(
                RoundedRectangle(cornerRadius: Radius.programCard)
                    .stroke(
                        isSelected ? Palette.cocoaPrimary : Palette.accent.opacity(0.5),
                        lineWidth: 1.5
                    )
            )
            .programPaperShadow()
            .opacity(isLocked ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tier.label) intensity, \(weeks) weeks\(isLocked ? ", locked for safety" : "")\(isSelected ? ", selected" : "")")
    }

    private var hardLockSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Capsule()
                .fill(Palette.hairlineCocoa)
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            Text("about Hard")
                .font(Typo.title)
                .foregroundStyle(Palette.cocoaPrimary)

            Text(HardTierGate.lockReason(hardGateInputs))
                .font(Typo.body)
                .foregroundStyle(Palette.cocoaSecondary)

            Text("you can unlock Hard anytime in settings. Soft and Medium are what we'd recommend for now.")
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)

            Spacer()

            Button {
                showHardLockSheet = false
            } label: {
                Text("got it")
                    .font(Typo.heading)
                    .foregroundStyle(Palette.textInverse)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Palette.cocoaPrimary)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.lg)
    }

    // MARK: - Page 3: Commitment ritual
    //
    // "make *it* official" hero + day-1 preview card. Final tap
    // calls ProgramService.startProgram + sets hasEnrolledInProgram.

    private var pageCommitment: some View {
        VStack(alignment: .leading, spacing: 28) {
            // v8 P8.8: hero collapsed to single line per
            // [[feedback-hero-typography-rule]] — 2-letter "it" as
            // the italic punch was orphaned. "official" carries the
            // intent + the visual weight.
            (
                Text("make it ")
                    .font(Typo.programHeroDisplay)
                    .foregroundStyle(Palette.cocoaPrimary)
                +
                Text("official.")
                    .font(Typo.programHeroItalic)
                    .foregroundStyle(Palette.cocoaPrimary)
            )
            .fixedSize(horizontal: false, vertical: true)

            // v8 P8.8: collapsed from "we'll start your program tomorrow.
            // day one." (read doubled). Italic punch on the temporal word.
            (
                Text("your program starts ")
                    .font(Typo.body)
                    .foregroundStyle(Palette.cocoaSecondary)
                +
                Text("tomorrow.")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                    .foregroundStyle(Palette.cocoaSecondary)
            )

            // Day 1 preview card — what tomorrow looks like.
            VStack(alignment: .leading, spacing: 14) {
                Text("day one")
                    .font(Typo.editorialEyebrow)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .textCase(.uppercase)
                    .kerning(0.66)

                let profile = IntensityProfile.from(tier: pickedTier)
                ritualRow(num: 1, title: "today's lesson", subtitle: "3 min · before lunch")
                ritualRow(num: 2, title: "snap a meal", subtitle: "one photo · any time")
                ritualRow(num: 3, title: "move", subtitle: "\(profile.workoutMinutes(forProgramWeek: 1)) min")
                ritualRow(num: 4, title: "\(profile.stepsDailyGoal.formatted(.number.grouping(.automatic))) steps", subtitle: "auto-tracked")
                ritualRow(num: 5, title: "breathe", subtitle: "1 min · before bed")
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.programCard)
                    .fill(Palette.programCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.programCard)
                    .stroke(Palette.accent.opacity(0.5), lineWidth: 1.5)
            )
            .programPaperShadow()
        }
    }

    private func ritualRow(num: Int, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(stickyColor(index: num - 1))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(num % 2 == 0 ? 2 : -2))
                Text("\(num)")
                    .font(Typo.stickyNumeral)
                    .foregroundStyle(Palette.cocoaPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typo.body)
                    .foregroundStyle(Palette.cocoaPrimary)
                Text(subtitle)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaSecondary)
            }
            Spacer()
        }
    }

    private func stickyColor(index: Int) -> Color {
        switch index % 4 {
        case 0: return Palette.stickyMint
        case 1: return Palette.stickyButter
        case 2: return Palette.stickyRose
        default: return Palette.stickyOlive
        }
    }

    // MARK: - Footer + nav

    private var footer: some View {
        VStack(spacing: 0) {
            Button {
                advance()
            } label: {
                HStack(spacing: 8) {
                    if commitWorking {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Palette.textInverse)
                    }
                    Text(ctaTitle)
                        .font(Typo.heading)
                        .foregroundStyle(Palette.textInverse)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Palette.cocoaPrimary)
                .clipShape(Capsule())
            }
            .disabled(commitWorking)
        }
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.lg)
        .padding(.top, 12)
        .background(Palette.programBgPrimary)
    }

    private var ctaTitle: String {
        switch page {
        case .goalDateReveal: return "see your options"
        case .intensityPick:  return "continue"
        case .commitment:     return "i'm in"
        }
    }

    private func advance() {
        Haptics.light()
        switch page {
        case .goalDateReveal:
            withAnimation(Motion.crossFade) { page = .intensityPick }
        case .intensityPick:
            withAnimation(Motion.crossFade) { page = .commitment }
        case .commitment:
            commit()
        }
    }

    private func back() {
        switch page {
        case .goalDateReveal:
            // First page back = user bails out
            onComplete(false)
        case .intensityPick:
            withAnimation(Motion.crossFade) { page = .goalDateReveal }
        case .commitment:
            // v9 P9.4: when onboarding has already collected the pace
            // (onboardingPickedTier set), commitment IS the only page,
            // so "back" means dismiss. Existing-user opt-in path walks
            // back to intensityPick as before.
            if onboardingPickedTierRaw.isEmpty {
                withAnimation(Motion.crossFade) { page = .intensityPick }
            } else {
                onComplete(false)
            }
        }
    }

    private func commit() {
        guard !commitWorking else { return }
        commitWorking = true
        Haptics.success()

        let input = ProgramService.StartProgramInput(
            currentWeightKg: currentWeightKg,
            goalWeightKg: safeGoalWeightKg,
            tier: pickedTier,
            goalCalculator: goalInputs,
            startDate: Calendar.current.startOfDay(for: .now)
        )

        let plan = ProgramService.shared.startProgram(
            input: input,
            userId: userId,
            in: modelContext
        )

        // Fire cloud sync — fire-and-forget like other writes.
        Task {
            await AppSync.shared.upsertProgramPlan(plan)
        }

        // Set the enrollment flag so PlanView gates on it.
        UserDefaults.standard.set(true, forKey: "hasEnrolledInProgram")
        UserDefaults.standard.set(true, forKey: "programEraEnabled")

        // Brief beat so the user reads the haptic before the dismiss.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            commitWorking = false
            onComplete(true)
        }
    }
}

// MARK: - IntensityTier display extension

extension IntensityTier {
    var label: String {
        switch self {
        case .soft:   return "soft"
        case .medium: return "medium"
        case .hard:   return "hard"
        }
    }
}
