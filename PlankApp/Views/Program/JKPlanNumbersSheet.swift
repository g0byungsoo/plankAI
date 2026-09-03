import SwiftUI
import SwiftData
import PlankSync

// MARK: - JKPlanNumbersSheet
//
// THE REPAIR DOOR — the four facts her daily numbers are made of, each
// one stated, each one changeable.
//
// Before 2026-08-13 none of them could be changed at all: the goal
// weight had no surface, and height and movement still had none after
// it. The support answer for "my calorie target looks wrong" was
// *delete your account and start over*, which for a paid weight-loss
// program is not a missing feature — it is a missing floor.
//
// It is also the door the EMPTY DENOMINATOR needed. When
// `TargetsService.calorieTarget` returns nil, exactly one of these four
// is why: no weight, no height, no goal, or a maintenance instruction.
// Home used to render "860 kcal" with no denominator, no reason and
// nowhere to go. It now says which one is missing and opens here.
//
// Design: rows, not a form. Each row states what we hold — the number
// itself, so she can confirm we still have it without opening anything —
// and "not set" is the honest empty, never a placeholder that looks like
// an answer. Editing happens IN PLACE (a page swap, never a sheet inside
// a sheet: the nested-sheet keypad was the last old-JeniFit input
// surface and JKWeightRitual retired it).

struct JKPlanNumbersSheet: View {

    /// Which fact to open on, when the caller already knows what is
    /// missing. `.none` lands on the list.
    var focus: Fact? = nil
    let onClose: () -> Void

    enum Fact: String, Identifiable {
        case weight, height, goal, activity, sex, age, pace, direction
        var id: String { rawValue }

        /// The fact in her words, for the "we need X" line. Never
        /// "invalid", never "required field".
        var word: String {
            switch self {
            case .weight:    return "a weight"
            case .height:    return "your height"
            case .goal:      return "a goal weight"
            case .activity:  return "how you move"
            case .sex:       return "which equation to use"
            case .age:       return "your age"
            case .pace:      return "a pace"
            case .direction: return "to know if this plan is losing or holding"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var page: Fact? = nil
    @State private var bump = 0            // forces the rows to re-read
    @State private var appeared = false

    @AppStorage("weightUnit") private var weightUnitRaw: String = "lb"
    @AppStorage("heightUnit") private var heightUnitRaw: String = "ftin"

    private var unit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lb }
    private var usesFtIn: Bool { heightUnitRaw != "cm" }
    private var userId: String { AppSync.shared.currentUserId ?? "" }

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            switch page {
            case .none:      list
            case .weight:    weightEditor
            case .height:    heightEditor
            case .goal:      goalEditor
            case .activity:  activityEditor
            case .sex:       sexEditor
            case .age:       ageEditor
            case .pace:      paceEditor
            case .direction: directionEditor
            }
        }
        .animation(Motion.crossFade, value: page)
        .onAppear {
            page = focus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { appeared = true }
        }
    }

    // MARK: - The list

    private var list: some View {
        JKSheetChrome(
            title: "what your plan is built on.",
            italic: ["built on."],
            eyebrow: "your numbers"
        ) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    let _ = bump
                    row(.weight, lead: "weight today", value: weightValue)
                    row(.height, lead: "height", value: heightValue)
                    row(.goal, lead: "goal weight", value: goalValue)
                    // FRAME REVIEW: the ambiguous row said "regular-ish"
                    // beside "we lost the detail on this one", which
                    // states a specific answer and disowns it in the same
                    // breath. The value is what the MATH is using — she
                    // should see that — and the note names the other
                    // answer it could have been instead of implying the
                    // number on screen is a guess about nothing.
                    row(.activity, lead: "how you move", value: activityValue,
                        note: BodyFactsStore.activityIsAmbiguous()
                            ? "this is what your target is using. it could also have been \"walks here and there\". tap to say which."
                            : nil)
                    // The last three inputs to the same equation. They
                    // were asked once, in the consult, and no surface
                    // could show or change any of them — while two of the
                    // three screens that ask them PRINT a promise that
                    // she can ("you can change this anytime" on sex,
                    // "you can change it later" on pace).
                    row(.sex, lead: "calorie equation", value: sexValue,
                        note: BodyFactsStore.sexUsesConservativeEquation()
                            ? "we run the more conservative equation, which gives the lower target."
                            : nil)
                    row(.age, lead: "age", value: ageValue,
                        note: TargetsService.ageIsApproximate()
                            ? "close, from your age range. tap to set it exactly."
                            : nil)
                    row(.pace, lead: "pace", value: paceValue, note: paceNote)

                    // THE ANSWER AN ACCOUNT TRANSITION LOSES. It appears
                    // only while it is genuinely missing — a woman whose
                    // device still holds her direction is asked nothing,
                    // and the sheet stays seven rows for everyone else.
                    if directionIsMissing {
                        row(.direction, lead: "this plan", value: nil,
                            note: "your plan is set to hold steady. we can't tell from this device whether that was your choice or a health reason we checked at sign-up. tap to say which.")
                    }

                    Text(closingLine)
                        .font(.custom("DMSans-Regular", size: 13))
                        .foregroundStyle(Palette.cocoaTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.lg)
                }
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.md)
                .padding(.bottom, Space.lg)
            }
            // The CTA is pinned, not trailing the content. Frame review:
            // a capsule floating mid-page over ~800pt of paper reads as an
            // unfinished screen, and no other list surface in the app puts
            // its primary action anywhere but the bottom. (The RULER faces
            // are a different composition on purpose — the instrument sits
            // in thumb reach and the negative space above it is the
            // register JKGoalRitual established.)
            JFContinueButton(label: "done", action: onClose)
                .pinnedFooter()
        }
    }

    /// Says what these four DO, so the sheet reads as her plan's
    /// arithmetic rather than as a settings form. It names the missing
    /// one when one is missing — that is the whole reason a user arrives
    /// here from Home.
    private var closingLine: String {
        if missing.isEmpty {
            return "your daily food target is built from these. change one and it recomputes."
        }
        let words = missing.map(\.word)
        let list = words.count == 1
            ? words[0]
            : words.dropLast().joined(separator: ", ") + " and " + words[words.count - 1]
        return "your daily food target needs \(list). we won't guess it."
    }

    private var missing: [Fact] {
        var out: [Fact] = []
        if currentKg == nil { out.append(.weight) }
        if heightCm <= 100 { out.append(.height) }
        if storedGoalKg == nil, !CohortStore.isMaintenanceMode { out.append(.goal) }
        if directionIsMissing { out.append(.direction) }
        return out
    }

    /// Her plan states a hold and this device cannot say whether the
    /// hold was asked for. The one resolver, so the row, the closing
    /// line and `TargetsService` cannot disagree about whether to ask.
    private var directionIsMissing: Bool {
        guard !userId.isEmpty else { return false }
        return TargetsService.planHoldsWithUnknownDirection(
            ProgramService.shared.activePlan(userId: userId, in: modelContext))
    }

    @ViewBuilder
    private func row(_ fact: Fact, lead: String, value: String?, note: String? = nil) -> some View {
        Button {
            Haptics.light()
            page = fact
        } label: {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(lead)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 12)
                    Text(value ?? "not set")
                        .font(.custom(value == nil ? "DMSans-Regular" : "DMSans-Medium", size: 15))
                        .foregroundStyle(value == nil ? Palette.cocoaTertiary : Palette.textPrimary)
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.cocoaTertiary)
                }
                if let note {
                    Text(note)
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundStyle(Palette.cocoaSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
                Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.33)
                    .padding(.top, 14)
            }
            .padding(.top, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(lead), \(value ?? "not set")")
        .accessibilityHint("opens the editor")
    }

    // MARK: - Values on file

    private var currentKg: Double? {
        let onboarding = UserDefaults.standard
            .double(forKey: "onboardingCurrentWeightKg")
        let fallback: Double? = onboarding > 0 ? onboarding : nil
        guard !userId.isEmpty else { return fallback }
        return TargetsService.latestWeightKg(userId: userId, in: modelContext) ?? fallback
    }

    private var heightCm: Double {
        UserDefaults.standard.double(forKey: "onboardingHeightCm")
    }

    private var storedGoalKg: Double? {
        let kg = UserDefaults.standard.double(forKey: "onboardingGoalWeightKg")
        return kg > 30 ? kg : nil
    }

    private var weightValue: String? {
        currentKg.map { "\(PlanSummary.formatted(unit.display(fromKg: $0))) \(unit.label)" }
    }

    private var heightValue: String? {
        guard heightCm > 100 else { return nil }
        if usesFtIn {
            let inches = Int((heightCm / 2.54).rounded())
            return "\(inches / 12)'\(inches % 12)\""
        }
        return "\(Int(heightCm.rounded())) cm"
    }

    private var goalValue: String? {
        if CohortStore.isMaintenanceMode, storedGoalKg == nil { return "holding steady" }
        return storedGoalKg.map {
            "\(PlanSummary.formatted(unit.display(fromKg: $0))) \(unit.label)"
        }
    }

    private var activityValue: String? { BodyFactsStore.activityWords() }

    private var sexValue: String? { BodyFactsStore.sexWords() }

    private var ageValue: String? {
        guard let years = TargetsService.knownAge() else { return nil }
        return TargetsService.ageIsApproximate() ? "about \(years)" : "\(years)"
    }

    /// The pace on the PLAN she is living in, not the preference — those
    /// two can differ for a user who never finished the onramp, and the
    /// one that decides her horizon is the plan's.
    private var paceTier: IntensityTier? {
        if !userId.isEmpty,
           let plan = ProgramService.shared.activePlan(userId: userId, in: modelContext),
           let tier = IntensityTier(rawValue: plan.intensityTier) { return tier }
        return IntensityTier(rawValue: UserDefaults.standard
            .string(forKey: "onboardingPickedTier") ?? "")
    }

    /// The SAME three words every other surface shows her. This screen
    /// said "quick" for `.hard` in its first draft, which was a FIFTH
    /// display vocabulary for three tiers (`32` §2). v25 §37: the word
    /// is decided once, in `IntensityTier.paceWord`, so a copy in this
    /// file can no longer drift from a copy in Home.
    private var paceValue: String? { paceTier?.paceWord }

    private var paceNote: String? {
        guard !userId.isEmpty,
              let plan = ProgramService.shared.activePlan(userId: userId, in: modelContext)
        else { return nil }
        let weeks = max(1, plan.totalDays / 7)
        return "your plan runs \(weeks) weeks at this pace. changing it moves the finish line, never your start date or your log."
    }

    // MARK: - Weight (the weigh-in, unchanged)

    private var weightEditor: some View {
        JKWeightRitual(
            startingFromKg: currentKg ?? unit.toKg(displayed: 150),
            priorLoggedCount: priorWeighIns,
            isUpdatingToday: false,
            onSave: { kg in
                guard !userId.isEmpty else { return }
                // The one shared write path — the same one Home's ritual
                // and chat's log_weight tool use. A second writer for the
                // same fact is how two sources start disagreeing.
                WeightLogWriter.persist(kg: kg, userId: userId, in: modelContext)
            },
            onDone: { bump += 1; page = nil },
            onCancel: { page = nil }
        )
    }

    private var priorWeighIns: Int {
        guard !userId.isEmpty else { return 0 }
        let descriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Goal (the ritual, unchanged)

    private var goalEditor: some View {
        JKGoalRitual(
            currentKg: currentKg,
            existingGoalKg: storedGoalKg,
            heightCm: heightCm,
            isFirstTime: storedGoalKg == nil,
            onSave: { kg in
                guard !userId.isEmpty else { page = nil; return }
                GoalWeightStore.setGoalWeightKg(kg, userId: userId, in: modelContext)
                bump += 1
                page = nil
            },
            onCancel: { page = nil }
        )
    }

    // MARK: - Height

    @State private var heightDisplay: Double = 0

    private var heightEditor: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    VStack(spacing: 6) {
                        Text("your height")
                            .font(Typo.captionTracked)
                            .kerning(1.98)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.cocoaTertiary)
                        Text("it sets your energy estimate.")
                            .font(.custom("JeniHeroSerif-Regular", size: 22))
                            .foregroundStyle(Palette.textPrimary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, Space.lg)

                    Text(heightReadout)
                        .font(.custom("JeniHeroSerif-Regular", size: 52))
                        .foregroundStyle(Palette.textPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.15), value: heightDisplay)
                        .padding(.top, 18)
                        .accessibilityLabel("height \(heightReadout)")

                    heightUnitToggle.padding(.top, 10)

                    Text("we never share it. it only feeds the arithmetic.")
                        .font(.custom("DMSans-Regular", size: 13))
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, Space.lg)
                        .padding(.top, 14)
                        .padding(.bottom, 16)
                }
            }

            OV5Ruler(
                value: $heightDisplay,
                range: usesFtIn ? 48...84 : 122...214,
                step: 1,
                majorEvery: usesFtIn ? 12 : 10,
                majorLabel: { v in
                    guard usesFtIn else { return "\(Int(v.rounded()))" }
                    return "\(Int(v.rounded()) / 12)'"
                }
            )
            .padding(.bottom, 8)

            JFContinueButton(
                label: "save it",
                action: {
                    Haptics.success()
                    let cm = usesFtIn ? heightDisplay * 2.54 : heightDisplay
                    guard !userId.isEmpty else { page = nil; return }
                    BodyFactsStore.setHeightCm(cm, userId: userId, in: modelContext)
                    bump += 1
                    page = nil
                },
                firesHaptic: false,
                secondaryLabel: "not now",
                secondaryAction: { page = nil }
            )
        }
        .onAppear { seedHeight() }
    }

    private func seedHeight() {
        let cm = heightCm > 100 ? heightCm : 165
        heightDisplay = (usesFtIn ? cm / 2.54 : cm).rounded()
    }

    private var heightReadout: String {
        let v = Int(heightDisplay.rounded())
        return usesFtIn ? "\(v / 12)'\(v % 12)\"" : "\(v) cm"
    }

    private var heightUnitToggle: some View {
        HStack(spacing: 18) {
            heightUnitWord("ft · in", isFtIn: true)
            Rectangle().fill(Palette.hairlineCocoa).frame(width: 0.66, height: 12)
            heightUnitWord("cm", isFtIn: false)
        }
    }

    private func heightUnitWord(_ label: String, isFtIn: Bool) -> some View {
        let active = usesFtIn == isFtIn
        return Button {
            guard !active else { return }
            Haptics.tick()
            let cm = usesFtIn ? heightDisplay * 2.54 : heightDisplay
            heightUnitRaw = isFtIn ? "ftin" : "cm"
            heightDisplay = (isFtIn ? cm / 2.54 : cm).rounded()
        } label: {
            Text(label)
                .font(.custom(active ? "Fraunces72pt-SemiBoldItalic" : "DMSans-Regular", size: 14))
                .foregroundStyle(active ? Palette.cocoaPrimary : Palette.cocoaTertiary)
                .padding(.vertical, 4)
        }
        .buttonStyle(JKPress())
        .accessibilityLabel("\(label)\(active ? ", selected" : "")")
    }

    // MARK: - Activity
    //
    // The four options are the consult's own, verbatim — she is not being
    // asked a new question, she is correcting an answer she already gave.

    private static let activityOptions: [(key: String, label: String, note: String)] = [
        ("barely", "barely, honestly", "we start where you actually are"),
        ("walks", "walks here and there", "most people are here"),
        ("regular_ish", "regular-ish", "a few sessions most weeks"),
        ("very_active", "very active", "training, or on your feet all day"),
    ]

    private var activityEditor: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("how you move")
                            .font(Typo.captionTracked)
                            .kerning(1.98)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.cocoaTertiary)
                        Text("most weeks, honestly.")
                            .font(.custom("JeniHeroSerif-Regular", size: 22))
                            .foregroundStyle(Palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 20)

                    Text("this is the biggest single input to your food target, and steps you log never change it.")
                        .font(.custom("DMSans-Regular", size: 13))
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                        .padding(.bottom, Space.md)

                    ForEach(Self.activityOptions, id: \.key) { option in
                        activityChoice(option)
                    }
                }
                .padding(.horizontal, Space.lg)
                .padding(.bottom, Space.lg)
            }
            JFContinueButton(
                label: "done",
                action: { page = nil },
                firesHaptic: false
            )
            .pinnedFooter()
        }
    }

    private func activityChoice(_ option: (key: String, label: String, note: String)) -> some View {
        let selected = TargetsService.activityKey() == option.key
        return Button {
            Haptics.light()
            guard !userId.isEmpty else { return }
            BodyFactsStore.setActivityBaseline(option.key, userId: userId, in: modelContext)
            bump += 1
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.label)
                        .font(.custom("DMSans-Medium", size: 16))
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(option.note)
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundStyle(Palette.cocoaTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                // Selection is ink, never colour (design law), and a mark
                // rather than a checkbox circle. Reserved width so the
                // rows do not shift as the selection moves.
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.cocoaPrimary)
                    .opacity(selected ? 1 : 0)
                    .frame(width: 16, alignment: .trailing)
                    .padding(.top, 3)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.33)
            }
        }
        .buttonStyle(JKPress())
        .accessibilityLabel("\(option.label)\(selected ? ", selected" : "")")
    }

    // MARK: - Sex
    //
    // An energy-equation input, presented as one. The consult's own four
    // answers, verbatim, and each says which equation it runs — because
    // "we use the more conservative equation" is a real assumption and
    // presenting it as neutral arithmetic would be the same lie as a
    // maintenance number labelled a loss target.

    private static let sexOptions: [(key: String, label: String, note: String)] = [
        ("female", "female", "10w + 6.25h − 5a − 161"),
        ("male", "male", "10w + 6.25h − 5a + 5"),
        ("nonbinary", "non-binary", "we run the conservative equation, the lower target"),
        ("private", "prefer not to say", "we run the conservative equation, the lower target"),
    ]

    private var sexEditor: some View {
        choiceEditor(
            eyebrow: "calorie equation",
            title: "which equation should we use?",
            blurb: "mifflin-st jeor carries one constant that differs by body. it is worth about 166 kcal a day, and it is the only thing this answer changes.",
            options: Self.sexOptions,
            selectedKey: (UserDefaults.standard.string(forKey: "onboardingGender") ?? ""),
            onPick: { key in
                guard !userId.isEmpty else { return }
                BodyFactsStore.setSex(key, userId: userId, in: modelContext)
            }
        )
    }

    // MARK: - Age

    @State private var ageDisplay: Double = 0

    private var ageEditor: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    VStack(spacing: 6) {
                        Text("your age")
                            .font(Typo.captionTracked)
                            .kerning(1.98)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.cocoaTertiary)
                        Text("five calories a year.")
                            .font(.custom("JeniHeroSerif-Regular", size: 22))
                            .foregroundStyle(Palette.textPrimary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, Space.lg)

                    Text("\(Int(ageDisplay.rounded()))")
                        .font(.custom("JeniHeroSerif-Regular", size: 52))
                        .foregroundStyle(Palette.textPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.15), value: ageDisplay)
                        .padding(.top, 18)
                        .accessibilityLabel("age \(Int(ageDisplay.rounded()))")

                    Text("if you sign out, your age comes back as a range and we use its midpoint. we say so when that happens.")
                        .font(.custom("DMSans-Regular", size: 13))
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, Space.lg)
                        .padding(.top, 14)
                        .padding(.bottom, 16)
                }
            }

            OV5Ruler(
                value: $ageDisplay, range: 13...100, step: 1, majorEvery: 10,
                majorLabel: { "\(Int($0.rounded()))" }
            )
            .padding(.bottom, 8)

            JFContinueButton(
                label: "save it",
                action: {
                    Haptics.success()
                    guard !userId.isEmpty else { page = nil; return }
                    BodyFactsStore.setAgeYears(
                        Int(ageDisplay.rounded()), userId: userId, in: modelContext)
                    bump += 1
                    page = nil
                },
                firesHaptic: false,
                secondaryLabel: "not now",
                secondaryAction: { page = nil }
            )
        }
        .onAppear { ageDisplay = Double(TargetsService.knownAge() ?? 32) }
    }

    // MARK: - Pace
    //
    // The pace screen in the onramp prints "pick the rhythm. you can
    // change it later." This is later. Hard keeps the same
    // `HardTierGate` lock it has in the picker — an editor that could
    // unlock it would be a safety gate with a back door.

    @State private var paceRefusal: String? = nil

    private var paceOptions: [(key: String, label: String, note: String)] {
        [
            ("soft", "gentle", "the slowest glide. the one that finishes most often."),
            ("medium", "steady", "the middle. most people are here."),
            ("hard", "strong",
             GoalWeightStore.hardIsUnlocked()
                ? "the fastest we will go. still inside the safe band."
                : "locked for now. tap to see why."),
        ]
    }

    private var paceEditor: some View {
        choiceEditor(
            eyebrow: "pace",
            title: "how fast, honestly?",
            blurb: "this moves your finish line. it never moves your start date, your starting weight, your goal, or anything you have logged.",
            options: paceOptions,
            selectedKey: paceTier?.rawValue ?? "",
            footnote: paceRefusal,
            onPick: { key in
                guard !userId.isEmpty, let tier = IntensityTier(rawValue: key) else { return }
                let result = GoalWeightStore.setPaceTier(
                    tier, userId: userId, in: modelContext)
                paceRefusal = result.wasRefused
                    ? HardTierGate.lockReason(.init(
                        isGLP1User: ProgramGoalCalculator.isGLP1User(
                            from: UserDefaults.standard
                                .string(forKey: "onboarding_glp1_status") ?? ""),
                        hasGentlerPaceStage: ProgramGoalCalculator.gentlerPaceStage(
                            from: UserDefaults.standard
                                .string(forKey: "onboardingHormonalStage") ?? ""),
                        age: TargetsService.knownAge(),
                        activityLevel: GoalWeightStore.hardGateActivity(
                            TargetsService.activityKey())))
                    : result.weeks.map { "your plan runs \($0) weeks now." }
            }
        )
    }

    // MARK: - Direction
    //
    // THE ONE QUESTION THE PRODUCT ASKS BECAUSE IT CANNOT KNOW.
    //
    // `safety_pace_cap`, `program_mode` and `onboarding_goal_direction`
    // are swept on sign-out (correctly — user A's clinical answers must
    // never bend user B's program) and no restore path puts them back.
    // Her plan row still says HOLD, and that row is ambiguous between the
    // two most opposite meanings in this product: a clinical instruction
    // to hold, and a goal the old build lost.
    //
    // So the app asks, and it asks the thing it actually lost — never
    // "are you pregnant", never a screening question, never a label. The
    // conditions are not named because naming them is not the app's
    // business and because "a health reason we checked at sign-up" is
    // both true and sufficient. Nothing is pre-selected: the honest
    // state is that we do not know.

    @State private var directionAck: String? = nil

    private var directionEditor: some View {
        choiceEditor(
            eyebrow: "this plan",
            title: "is this plan losing, or holding?",
            blurb: "your plan is set to hold steady. no calorie deficit. we can't tell from this device whether that was your choice or a health reason we checked at sign-up, and we won't guess. if a health reason set it, keep holding.",
            options: [
                ("hold", "hold steady",
                 "no deficit. this is what your plan says today."),
                ("lose", "aiming to lose",
                 "we'll use your saved goal weight and give you a daily number."),
            ],
            selectedKey: directionSelection,
            footnote: directionAck,
            onPick: { key in
                GoalWeightStore.setDirection(holding: key == "hold")
                directionAck = key == "hold"
                    ? "holding. no deficit, and you can change this any time from goal weight."
                    : "your daily number is back, built from your saved goal weight."
            }
        )
    }

    /// Nothing is selected until she answers — the whole point is that
    /// the app does not hold this fact.
    private var directionSelection: String {
        let _ = bump
        if TargetsService.directionIsUnknown() { return "" }
        return CohortStore.isMaintenanceMode ? "hold" : "lose"
    }

    // MARK: - The shared choice face
    //
    // Sex and pace are the same shape as activity: her own answers, a
    // drawn mark for the selection, ink never colour. One composition so
    // three surfaces cannot drift apart.

    private func choiceEditor(
        eyebrow: String,
        title: String,
        blurb: String,
        options: [(key: String, label: String, note: String)],
        selectedKey: String,
        footnote: String? = nil,
        onPick: @escaping (String) -> Void
    ) -> some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(eyebrow)
                            .font(Typo.captionTracked)
                            .kerning(1.98)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.cocoaTertiary)
                        Text(title)
                            .font(.custom("JeniHeroSerif-Regular", size: 22))
                            .foregroundStyle(Palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 20)

                    Text(blurb)
                        .font(.custom("DMSans-Regular", size: 13))
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                        .padding(.bottom, Space.md)

                    ForEach(options, id: \.key) { option in
                        Button {
                            Haptics.light()
                            onPick(option.key)
                            bump += 1
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(option.label)
                                        .font(.custom("DMSans-Medium", size: 16))
                                        .foregroundStyle(Palette.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(option.note)
                                        .font(.custom("DMSans-Regular", size: 12))
                                        .foregroundStyle(Palette.cocoaTertiary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 12)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Palette.cocoaPrimary)
                                    .opacity(selectedKey == option.key ? 1 : 0)
                                    .frame(width: 16, alignment: .trailing)
                                    .padding(.top, 3)
                            }
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.33)
                            }
                        }
                        .buttonStyle(JKPress())
                        .accessibilityLabel(
                            "\(option.label)\(selectedKey == option.key ? ", selected" : "")")
                    }

                    if let footnote {
                        Text(footnote)
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundStyle(Palette.cocoaSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, Space.md)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, Space.lg)
                .padding(.bottom, Space.lg)
            }
            .animation(Motion.crossFade, value: footnote)
            JFContinueButton(label: "done", action: { page = nil }, firesHaptic: false)
                .pinnedFooter()
        }
    }
}

// MARK: - Pinned footer
//
// FRAME REVIEW, AX5: the pinned CTA had no ground under it, so the
// scrolling options ran straight into the capsule and the two read as one
// overlapping object. Every other pinned footer in the app (the onramp's,
// the subflow's) stands on the paper with a hairline above it. This is
// that, once, so the two faces cannot drift apart.
private extension View {
    func pinnedFooter() -> some View {
        self
            .padding(.horizontal, Space.lg)
            .padding(.top, 12)
            .padding(.bottom, Space.sm)
            .background(
                Palette.bgPrimary
                    .overlay(
                        Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.33),
                        alignment: .top
                    )
            )
    }
}
