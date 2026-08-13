import SwiftUI

// MARK: - JKGoalRitual
//
// SET OR CHANGE THE GOAL WEIGHT — the surface that did not exist.
//
// Onboarding asked for a goal weight, stored it, fed it to the energy
// target, and then no screen in the app could show it or change it.
// A user who mis-set it, or reached it, or decided on a different
// number, had one repair available: delete her account.
//
// The interaction is deliberately the SAME one as the weigh-in
// (`JKWeightRitual`) and the same one onboarding taught her on day
// zero: the tick ruler with haptic detents. A goal is not a new skill
// to learn, and the two weights should feel like the same instrument
// pointed at different questions.
//
// Steps in whole display units, never tenths — a goal weight in
// tenths is false precision about an intention.

struct JKGoalRitual: View {

    /// Her current weight, for the anchor mark and the live distance.
    let currentKg: Double?
    /// The goal already on file, if any.
    let existingGoalKg: Double?
    /// Height, for the healthy-weight floor. 0 = unknown (no clamp).
    let heightCm: Double
    /// Nudges the copy when this is the first goal she has ever set —
    /// the post-purchase repair path, not a settings edit.
    var isFirstTime: Bool = false
    let onSave: (Double) -> Void
    let onCancel: () -> Void

    @State private var displayValue: Double = 0
    @State private var appeared = false
    @AppStorage("weightUnit") private var weightUnitRaw: String = "lb"
    private var unit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lb }

    private var goalKg: Double { unit.toKg(displayed: displayValue) }

    /// The lowest goal we will store, BMI 18.5 for her height. The
    /// same floor the program build enforces — surfaced here so she
    /// meets it as guidance rather than as a silent correction.
    private var floorDisplay: Double? {
        let floor = ProgramGoalCalculator.minimumGoalWeightKg(heightCm: heightCm)
        return floor > 0 ? unit.display(fromKg: floor) : nil
    }

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Everything ABOVE the instrument scrolls. Frame review
                // caught the alternative at AX5: the title ran off the
                // top under the status bar and the CTA left the screen
                // entirely — the sheet became unusable at the text size
                // most likely to belong to someone who needs it. The
                // ruler stays outside the ScrollView so its drag is
                // never contested, and the CTA is always reachable.
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        VStack(spacing: 6) {
                            Text(isFirstTime ? "one more number" : "your goal")
                                .font(Typo.captionTracked)
                                .kerning(1.98)
                                .textCase(.uppercase)
                                .foregroundStyle(Palette.cocoaTertiary)
                            Text("where would you like to land?")
                                .font(.custom("JeniHeroSerif-Regular", size: 22))
                                .foregroundStyle(Palette.textPrimary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 20)
                        .padding(.horizontal, Space.lg)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(Int(displayValue.rounded()))")
                                .font(.custom("JeniHeroSerif-Regular", size: 58))
                                .kerning(-0.5)
                                .foregroundStyle(Palette.textPrimary)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.4)
                                .contentTransition(.numericText())
                                .animation(.easeOut(duration: 0.15), value: displayValue)
                            Text(unit.label)
                                .font(.custom("JeniHeroSerif-Italic", size: 24))
                                .foregroundStyle(Palette.accent)
                                .baselineOffset(6)
                        }
                        .padding(.top, 18)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("goal weight \(Int(displayValue.rounded())) \(unit.label)")

                        unitToggle.padding(.top, 10)

                        liveLine
                            .padding(.horizontal, Space.lg)
                            .padding(.top, 14)
                            .padding(.bottom, 16)
                    }
                }

                OV5Ruler(
                    value: $displayValue,
                    range: unit.displayRange,
                    step: 1,
                    majorEvery: 10,
                    majorLabel: { v in "\(Int(v.rounded()))" }
                )
                .padding(.bottom, 8)

                JFContinueButton(
                    label: isFirstTime ? "set my goal" : "update it",
                    action: {
                        Haptics.success()
                        onSave(goalKg)
                    },
                    firesHaptic: false,
                    secondaryLabel: isFirstTime ? nil : "not now",
                    secondaryAction: isFirstTime ? nil : onCancel
                )
            }
        }
        .onAppear {
            let seed = existingGoalKg
                ?? (currentKg.map { $0 * 0.9 })
                ?? unit.toKg(displayed: 150)
            displayValue = unit.display(fromKg: seed).rounded()
            appeared = true
        }
    }

    // MARK: - The honest line

    /// Distance and horizon, both derived, both said as estimates.
    /// Below the healthy floor the register changes and the CTA still
    /// works — the store clamps, and says it clamped.
    @ViewBuilder private var liveLine: some View {
        if let floorDisplay, displayValue < floorDisplay - 0.5 {
            Text("that sits under the healthy range for your height. we'll aim you at \(Int(floorDisplay.rounded())) \(unit.label) instead.")
                .font(.custom("DMSans-Regular", size: 13))
                .foregroundStyle(Palette.stateGood)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        } else if let currentKg, currentKg - goalKg >= unit.toKg(displayed: 1) {
            let deltaDisplay = unit.display(fromKg: currentKg - goalKg)
            Text(horizonPhrase(deltaDisplay: deltaDisplay))
                .font(.custom("DMSans-Regular", size: 13))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        } else if currentKg != nil {
            Text("holding where you are. the plan becomes a maintenance rhythm.")
                .font(.custom("DMSans-Regular", size: 13))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
    }

    private func horizonPhrase(deltaDisplay: Double) -> String {
        let distance = "\(Int(deltaDisplay.rounded())) \(unit.label) from where you are"
        guard let currentKg else { return distance }
        let window = ProgramGoalCalculator.compute(.init(
            currentWeightKg: currentKg,
            goalWeightKg: goalKg,
            sex: ProgramGoalCalculator.sex(
                fromGenderKey: UserDefaults.standard.string(forKey: "onboardingGender") ?? ""),
            age: nil,
            isGLP1User: CohortStore.isGLP1Current,
            isPerimenopausal: CohortStore.isPerimenopausal,
            isShortSleeper: CohortStore.isShortSleeper,
            weightTrendKey: CohortStore.weightTrendKey,
            glp1PhaseKey: CohortStore.glp1PhaseKey
        ))
        guard !window.isMaintenance else { return distance }
        let tier = IntensityTier(
            rawValue: UserDefaults.standard.string(forKey: "onboardingPickedTier") ?? ""
        ) ?? .medium
        return "\(distance) · about \(window.weeks(for: tier)) weeks at your pace. an estimate, not a promise."
    }

    private var unitToggle: some View {
        HStack(spacing: 18) {
            unitWord(.lb)
            Rectangle()
                .fill(Palette.hairlineCocoa)
                .frame(width: 0.66, height: 12)
            unitWord(.kg)
        }
    }

    private func unitWord(_ u: WeightUnit) -> some View {
        let active = unit == u
        return Button {
            guard !active else { return }
            Haptics.tick()
            let kg = unit.toKg(displayed: displayValue)
            weightUnitRaw = u.rawValue
            displayValue = u.display(fromKg: kg).rounded()
        } label: {
            Text(u.label)
                .font(.custom(active ? "Fraunces72pt-SemiBoldItalic" : "DMSans-Regular", size: 14))
                .foregroundStyle(active ? Palette.cocoaPrimary : Palette.cocoaTertiary)
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(u.label)\(active ? ", selected" : "")")
    }
}
