import SwiftUI
import SwiftData
import PlankSync

// MARK: - ProgramSetupSubflow
//
// v1.1 program pivot; pass 52 made it ONE page per arrival: the pace
// decision (which commits) for a tier-less arrival, or the single
// commitment confirmation when the pre-wall pace pick already stored a
// tier. Used in two host contexts:
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

// MARK: - SubflowPagePlan (pass 52 — THE FIRST DAY)
//
// The setup subflow's routing as a pure table, so the pages between a
// purchase and Home are countable in a test (FirstDayActivationTests).
// The view reads THIS; there is no second copy of the plan.
enum SubflowPagePlan {
    enum Page: Equatable {
        case pace             // the one real decision the consult did not collect
        case commitment       // the pre-picked-tier path's single confirmation
    }

    /// The first page for a given arrival. A v8 payer whose pre-wall
    /// pace pick stored a tier gets the single confirmation page; a
    /// tier-less arrival gets the pace decision — and nothing else.
    /// The goal-date explainer page died in pass 52: its only
    /// interaction was "continue", the onramp intro already restates
    /// the arc, and the pace page carries the per-tier weeks itself.
    static func firstPage(hasPickedTier: Bool) -> Page {
        hasPickedTier ? .commitment : .pace
    }

    /// Whether the given page's primary CTA COMMITS the program.
    /// Every path is ONE page: pick and start are the same screen.
    static func commits(on page: Page) -> Bool {
        switch page {
        case .pace, .commitment: return true
        }
    }

    /// The primary CTA's label per page.
    static func ctaTitle(for page: Page) -> String {
        switch page {
        case .pace: return "i'm in"
        case .commitment: return "i'm in"
        }
    }
}

struct ProgramSetupSubflow: View {

    /// Fires once user completes the subflow (commits in page 3).
    /// Host should dismiss + route the user to PlanView. nil means
    /// the user bailed out (back button on page 1, or host swipe-dismiss).
    let onComplete: (_ committed: Bool) -> Void

    @Environment(\.modelContext) private var modelContext

    // Inputs collected earlier in onboarding — @AppStorage reads them
    // wherever the subflow is hosted (onboarding mid-flow OR the
    // ProgramOnrampView).
    // 0 = no weight on file, and this defaulted to 65 kg — 143 lb, a
    // body belonging to nobody, PERSISTED into the plan record as her
    // start weight by `commit()`. It is the same class as the 60 kg goal
    // the 2026-08-13 pass removed two properties down, left behind in
    // the one view that writes the plan every user's targets derive
    // from. `commit()` now refuses rather than inventing.
    @AppStorage("onboardingCurrentWeightKg") private var currentWeightKg: Double = 0
    // 0 = no goal on file. It used to default to 60 kg — a goal
    // belonging to nobody, handed to anyone whose key was missing
    // (a fresh sign-in sweeps it; see AppSync.clearOnboardingUserDefaults).
    @AppStorage("onboardingGoalWeightKg") private var goalWeightKg: Double = 0
    @AppStorage("onboardingAgeRange") private var ageRange: String = ""
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
    // v1.2 safety (2026-06-29): the pre-paywall gate persisted the adaptation
    // here. -1 = no cap; 0 = zero-deficit (pregnant / ED / low-BMI) -> build a
    // genuine maintenance plan; 0.0025 = gentle 0.25%/wk -> clamp every tier.
    // Read so the SHIPPED program matches the adapted projection, not a normal
    // loss plan. (The screen itself ran pre-paywall; this only reads the cap.)
    @AppStorage("safety_pace_cap") private var safetyPaceCap: Double = -1
    // v1.1.3 (2026-06-29): explicit goal direction (case 1330). A "recomp"
    // (tone-up) choice builds a GENTLE deficit (~0.25%/wk) so the shipped plan
    // matches the gentler reveal. maintain / maintain_kept arrive with goal ==
    // current, which already yields a maintenance window (no special-case).
    @AppStorage("onboarding_goal_direction") private var goalDirection: String = ""

    // Authenticated user id used by ProgramService.startProgram.
    // Read from the same source other AppSync calls use (AppSync.shared.currentUserId).
    @State private var userId: String = ""

    // v9 P9.4 / pass 52 — Subflow page state. Source of truth:
    // `onboardingPickedTier` AppStorage. Set (the shipping v8 path —
    // the pre-wall PacePicker stores it, even at its default) → the
    // single commitment confirmation. Unset (existing-user opt-in, or
    // an account-transition sweep) → the pace decision, which commits
    // itself. SubflowPagePlan is the routing authority.
    @AppStorage("onboardingPickedTier") private var onboardingPickedTierRaw: String = ""

    @State private var page: SubflowPagePlan.Page = .pace
    @State private var pickedTier: IntensityTier = .medium
    @State private var commitWorking: Bool = false
    /// True once a commit has been refused for want of a weight — the
    /// repair door, not an error.
    @State private var missingWeight: Bool = false

    var body: some View {
        // T7 (2026-06-29): the safety gate now runs PRE-paywall inside
        // OnboardingRevealView (SafetyGatePresentation), exactly once. This
        // subflow no longer screens - a screened-out user never reaches the
        // paywall, so by the time we are here the user has passed the gate.
        // ProgramSetupSubflow now only builds the program (pace + commit).
        programBody
            .onAppear { onSetupAppear() }
            .jeniSheet(isPresented: $missingWeight, detents: JeniSheetHeight.full) {
                JKPlanNumbersSheet(
                    focus: .weight,
                    onClose: { missingWeight = false }
                )
            }
    }

    private var programBody: some View {
        ZStack {
            Palette.programBgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    Group {
                        switch page {
                        case .pace:       pageIntensityPick
                        case .commitment: pageCommitment
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

    // T7 (2026-06-29): no safety gate here anymore. Just hydrate the
    // user id and open on the plan's one page: commitment when the
    // pace already lives on file, the pace decision otherwise
    // (SubflowPagePlan is the routing authority, pinned in tests).
    private func onSetupAppear() {
        #if DEBUG
        // Sim QA: land directly on a page for capture.
        if ProcessInfo.processInfo.arguments.contains("--debug-program-setup-commit") {
            page = .commitment
        }
        if ProcessInfo.processInfo.arguments.contains("--debug-program-setup-pace") {
            page = .pace
            return   // skip the pace-already-picked jump below
        }
        #endif
        userId = AppSync.shared.currentUserId ?? ""
        if let tier = IntensityTier(rawValue: onboardingPickedTierRaw) {
            pickedTier = tier
        }
        page = SubflowPagePlan.firstPage(
            hasPickedTier: IntensityTier(rawValue: onboardingPickedTierRaw) != nil
        )
    }

    // MARK: - Header
    //
    // Pass 52 — the progress track died with the page count: every
    // arrival sees exactly ONE page, and a progress bar over a single
    // page is ceremony. The back chevron stays (it is the bail-out).

    private var header: some View {
        HStack(spacing: Space.sm) {
            Button {
                Haptics.light()
                back()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Palette.cocoaPrimary)
                    .frame(width: 40, height: 40)
            }
            Spacer()
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

    private var goalInputs: ProgramGoalCalculator.Inputs {
        .init(
            currentWeightKg: startWeightKg ?? 0,
            goalWeightKg: safetyAdjustedGoalWeightKg,
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
            glp1PhaseKey:     glp1Phase,
            // Positive cap clamps every tier to the gentler glide. A 0 cap is
            // handled via safetyAdjustedGoalWeightKg (goal == current -> the
            // calculator returns a maintenance window) so the stored plan also
            // carries no deficit, not just a clamped rate.
            paceCapPctPerWeek: effectiveLossCap
        )
    }

    // v1.1.3 (2026-06-29): the loss-rate cap the built program glides at.
    // A safety cap (gate) wins when present — it is the more protective
    // signal. Otherwise a recomp choice clamps to the gentle 0.25%/wk glide.
    // A 0 safety cap returns nil here (it is realized via the goal == current
    // path in safetyAdjustedGoalWeightKg, not a rate clamp).
    private var effectiveLossCap: Double? {
        if safetyPaceCap > 0 { return safetyPaceCap }
        if goalDirection == "recomp" { return 0.0025 }
        return nil
    }

    // v1.2 safety (2026-06-29): a zero pace cap (pregnant / ED / low-BMI)
    // builds a genuine zero-deficit plan. Setting the effective goal weight to
    // current weight makes ProgramGoalCalculator.compute return a maintenance
    // window AND persists goalWeightKg == currentWeightKg on the plan record,
    // so the shipped program carries no deficit at all - matching the
    // suppressed projection. Any other cap leaves the BMI-18.5-clamped goal.
    private var safetyAdjustedGoalWeightKg: Double {
        safetyPaceCap == 0 ? (startWeightKg ?? 0) : safeGoalWeightKg
    }

    // v1.2 medical-grade (2026-06-25) — never build a program targeting a
    // goal below BMI 18.5. The picker already warns (goalWeightAnnotation's
    // under-target state); this enforces it at build so the program math +
    // goal date use the safe floor even if the user slid past the warning.
    // Height comes from onboarding. The gate only checks CURRENT BMI, so
    // without this a healthy-weight user could target an unsafe goal.
    private var safeGoalWeightKg: Double {
        // No goal on file is NOT "aim her at BMI 18.5" — which is what
        // max(0, floor) silently did: the lowest healthy weight for her
        // height, invented and never shown to her. Absent stays absent;
        // the onramp collects it before this screen can commit.
        guard goalWeightKg > 0 else { return 0 }
        guard heightCm > 0 else { return goalWeightKg }
        return max(goalWeightKg, ProgramGoalCalculator.weightForBMI(18.5, heightCm: heightCm))
    }

    /// 2026-08-14 — THE THIRD DEAD VOCABULARY IN THIS FILE.
    ///
    /// This switched on `"18-24"` / `"25-34"` / `"55+"`. Nothing writes
    /// those. `OV5Store.ageRangeBucket` writes `"18to24"` / `"25to34"` /
    /// `"55plus"`; the legacy flow wrote `"18_24"`. So `parsedAge`
    /// returned nil for **every user**, and `HardTierGate`'s
    /// `guard let age = inputs.age, age < 40` locked Hard for everyone —
    /// with `lockReason` falling through to its generic last line, which
    /// names no reason at all. A safety gate stuck closed is safe and
    /// still a lie on screen: it told her we hid Hard, and could not say
    /// why, because it did not know her age.
    ///
    /// `TargetsService.knownAge` is the one resolver, and it returns nil
    /// when the age is genuinely unknown — so the gate's
    /// missing-signal-locks-Hard contract is preserved exactly.
    private var parsedAge: Int? { TargetsService.knownAge() }

    // Pass 52 — the goal-date explainer page is GONE: its only
    // interaction was "continue", the onramp intro already restates
    // her arc, and the pace pills carry the per-tier weeks. Its ACSM
    // credibility line moved onto the pace page, which is where the
    // rate is actually chosen.

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

    /// Her movement answer, through the ONE resolver every other reader
    /// uses. This view used to declare
    /// `@AppStorage("onboardingActivityLevel")` — a key with **zero
    /// writers in the app**, present only in the sign-out sweep list,
    /// which is what made it look written. It therefore always read `""`,
    /// always mapped to `.light`, and the activity dimension of
    /// `HardTierGate` had never once fired: the fastest pace tier was
    /// offered to a "barely, honestly" user on every device.
    private var activityLevel: String { TargetsService.activityKey() }

    private var mappedActivity: HardTierGate.Inputs.ActivityLevel {
        switch activityLevel.lowercased() {
        // The RAW movement-baseline vocabulary, which is what the live
        // consult actually stores. Its absence here is why the mapping
        // "worked" — everything fell to the default.
        case "barely": return .sedentary
        case "walks": return .light
        case "regular_ish": return .moderate
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

            // Pass 52 — the credibility line the deleted explainer page
            // carried, kept where the rate is actually chosen; and the
            // truth the commit deserves to sit next to.
            VStack(alignment: .leading, spacing: 10) {
                Text("the science we follow: 0.5 to 1% of your body weight per week. faster than that and the weight comes back. ACSM 2009, Wing & Phelan 2005.")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                (
                    Text("day one is ")
                        .font(Typo.body)
                        .foregroundStyle(Palette.cocoaSecondary)
                    +
                    Text("today.")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                        .foregroundStyle(Palette.cocoaSecondary)
                )
            }
        }
        .jeniSheet(isPresented: $showHardLockSheet) {
            hardLockSheet
        }
    }

    private func intensityPill(_ tier: IntensityTier, isLocked: Bool) -> some View {
        let isSelected = pickedTier == tier
        let profile = IntensityProfile.from(tier: tier)
        let weeks = goalWindow.weeks(for: tier)
        // v1.1.6: an "on track for" estimate, not a hard start→end window.
        // The paywall sells a shorter motivating date (ProjectionMath) while
        // the program engine's safe pace runs longer; framing the per-tier
        // date as an estimate (matching the paywall's hedge) stops the setup
        // flow from asserting a hard total that contradicts it. Full
        // unification of the two date models is a follow-up design pass.
        let goalDateString: String = {
            let end = Calendar(identifier: .gregorian)
                .date(byAdding: .day, value: weeks * 7 - 1, to: .now) ?? .now
            let f = DateFormatter(); f.dateFormat = "MMM d"
            return "on track for \(f.string(from: end).lowercased())"
        }()

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
            .shadow(color: .black.opacity(0.04), radius: 5, y: 2)
            .opacity(isLocked ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tier.label) intensity, \(weeks) weeks\(isLocked ? ", locked for safety" : "")\(isSelected ? ", selected" : "")")
    }

    private var hardLockSheet: some View {
        // Pass 57 (D5) — the hand-drawn grabber is gone: the grammar's
        // system indicator is always visible, and a static counterfeit
        // in the same place tracked nothing and doubled the chrome.
        VStack(alignment: .leading, spacing: 20) {
            Text("about Hard")
                .padding(.top, Space.lg)
                .font(Typo.title)
                .foregroundStyle(Palette.cocoaPrimary)

            Text(HardTierGate.lockReason(hardGateInputs))
                .font(Typo.body)
                .foregroundStyle(Palette.cocoaSecondary)

            Text("you can unlock Hard anytime in settings. Soft and Medium are what we'd recommend for now.")
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .modifier(JeniScrollingSheetBody())
        .safeAreaInset(edge: .bottom) {
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
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.lg)
            .background(Palette.bgPrimary)
        }
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

            // v2.6 RC — the mechanics start the plan TODAY
            // (startDate = startOfDay(.now)); the old "tomorrow" copy
            // was factually wrong AND surrendered day-0 activation,
            // the exact cliff in the retention data. Say the truth:
            (
                Text("day one is ")
                    .font(Typo.body)
                    .foregroundStyle(Palette.cocoaSecondary)
                +
                Text("today.")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                    .foregroundStyle(Palette.cocoaSecondary)
            )

            // Day 1 preview card — what tomorrow looks like.
            VStack(alignment: .leading, spacing: 14) {
                Text("today, day one")
                    .font(Typo.editorialEyebrow)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .textCase(.uppercase)
                    .kerning(0.66)

                let profile = IntensityProfile.from(tier: pickedTier)
                // Pass 52 — the rows tell the truth about THIS product.
                // The old card promised "today's lesson · 3 min · before
                // lunch" and "breathe · before bed": the day-indexed
                // curriculum retired eras ago, and nothing schedules a
                // bedtime breath. A ritual card that describes a retired
                // product is a broken promise on the commit screen.
                ritualRow(num: 1, title: "tell jeni what you eat", subtitle: "a sentence or a photo · any time")
                ritualRow(num: 2, title: "\(profile.stepsDailyGoal.formatted(.number.grouping(.automatic))) steps", subtitle: "auto-tracked · offered never owed")
                ritualRow(num: 3, title: "the morning read", subtitle: "tomorrow, built from today")
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.programCard)
                    .fill(Palette.programCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.programCard)
                    .stroke(Palette.hairlineCocoa, lineWidth: 0.66)
            )
            .shadow(color: .black.opacity(0.04), radius: 5, y: 2)

            // v2.6 RC — what jeni carries (so she knows the program
            // watches FOR her, not the other way around).
            VStack(alignment: .leading, spacing: 10) {
                Text("jeni carries")
                    .font(Typo.editorialEyebrow)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .textCase(.uppercase)
                    .kerning(0.66)
                carriesLine("your protein number, sized to you")
                carriesLine("your trend line, read weekly, never daily")
                carriesLine("your plan, resized when life happens")
            }

            Text("sized to your floor, not your best day. that's why it holds.")
                .font(.custom("JeniHeroSerif-Italic", size: 16))
                .foregroundStyle(Palette.cocoaSecondary)
                .fixedSize(horizontal: false, vertical: true)
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
        SubflowPagePlan.ctaTitle(for: page)
    }

    private func advance() {
        Haptics.light()
        // Pass 52 — every page commits (SubflowPagePlan.commits): the
        // pace pick and the start are ONE screen, so nothing stands
        // between the decision and day one.
        if SubflowPagePlan.commits(on: page) {
            commit()
        }
    }

    private func back() {
        // One page per arrival, so back is always the bail-out.
        onComplete(false)
    }

    private func carriesLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Palette.cocoaPrimary.opacity(0.35))
                .frame(width: 4, height: 4)
                .padding(.top, 7)
            Text(text)
                .font(Typo.body)
                .foregroundStyle(Palette.cocoaSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The weight the plan's baseline is made of, through the same ladder
    /// every other reader uses. There is no fabricated fallback: this
    /// view's `@AppStorage` default was 65 kg, and `commit()` wrote that
    /// invented 143 lb body into the plan record as her START WEIGHT,
    /// where it then became the numerator of her energy target's implied
    /// rate and the anchor of "how much have I lost".
    private var startWeightKg: Double? {
        // Her own stored answer FIRST, so the normal path is byte-identical
        // to before this change: the window on screen and the baseline
        // written to the record must be the same weight, and `goalInputs`
        // reads this too. A logged weigh-in only RESCUES the case where the
        // key is absent — it must never become a second opinion (§3).
        if currentWeightKg > 30 { return currentWeightKg }
        return TargetsService.latestWeightKg(userId: userId, in: modelContext)
    }

    private func commit() {
        guard !commitWorking else { return }
        // A plan with no body is not a plan. The host's onramp asks for
        // the missing number instead (JKPlanNumbersSheet), and until then
        // nothing is written — an unbuilt plan is recoverable, a plan
        // built on a stranger's weight is not.
        guard let startWeightKg else {
            missingWeight = true
            return
        }
        commitWorking = true
        Haptics.success()

        let input = ProgramService.StartProgramInput(
            currentWeightKg: startWeightKg,
            // safetyAdjustedGoalWeightKg == currentWeightKg for a 0 pace cap,
            // so the persisted plan is genuinely zero-deficit. goalInputs (the
            // window source) reads the same adjusted goal + the >0 cap clamp.
            goalWeightKg: safetyAdjustedGoalWeightKg,
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
    /// v25 §36 — ONE PACE VOCABULARY IN THE PAID PRODUCT.
    ///
    /// The same three stored values had four names. `32` §16 found it,
    /// removed the fifth (its own `quick`), and classified the rest P2
    /// on the grounds that a release candidate is not a naming pass.
    /// `36` made it one word: she picked `medium` on the screen that
    /// builds her plan, and Home, `your numbers`, the pace editor and
    /// the coach all called it `steady` from that moment on.
    ///
    /// v25 §37 — and it had THREE AUTHORITIES. `36` agreed the three
    /// copies by editing one of them, which holds only until someone
    /// edits another. The word is decided once now, in
    /// `IntensityTier.paceWord`; this stays as the display name this
    /// file already reads.
    var label: String { paceWord }
}
