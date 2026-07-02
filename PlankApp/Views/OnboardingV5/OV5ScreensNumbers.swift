import SwiftUI

// MARK: - Act III — the numbers, gently
// Spec: docs/onboarding_v5/FLOW.md #17-33. The four rulers share one
// composition so the biometric run reads as a single input ritual. The
// goal ruler carries the rose delta band + a LIVE weeks line from
// ProgramGoalCalculator (real math only). The care cluster (medication
// + relocated SafetyGate) closes the act.

private let lbPerKg = 2.20462
private let cmPerIn = 2.54

struct OV5NumbersBridgeScreen: View {
    let flow: OV5Flow
    var body: some View {
        OV5ReceiptView(
            title: "the numbers, gently.",
            titleItalic: ["gently."],
            sub: "sixty seconds. never shown back as a grade.\nnever shared.",
            onContinue: { flow.advance() }
        )
    }
}

struct OV5MovementScreen: View {
    let flow: OV5Flow
    var body: some View {
        @Bindable var store = flow.store
        OV5Screen {
            OV5Header(title: "how does movement fit right now?", italic: ["fit"])
            OV5SelectList(
                options: [
                    .init(key: "barely", label: "barely, honestly"),
                    .init(key: "walks", label: "walks here and there"),
                    .init(key: "regular_ish", label: "regular-ish"),
                    .init(key: "very_active", label: "very active"),
                ],
                selection: $store.movementBaseline,
                onCommit: { flow.advance() }
            )
        }
    }
}

struct OV5SleepScreen: View {
    let flow: OV5Flow
    var body: some View {
        @Bindable var store = flow.store
        OV5Screen {
            OV5Header(title: "how much sleep, honestly?", italic: ["honestly"])
            OV5SelectList(
                options: [
                    .init(key: "under5", label: "under 5 hours"),
                    .init(key: "five6", label: "5 to 6"),
                    .init(key: "six7", label: "6 to 7"),
                    .init(key: "seven8", label: "7 to 8"),
                    .init(key: "eightPlus", label: "8 or more"),
                ],
                selection: $store.sleepHours,
                onCommit: { flow.advance() }
            )
        }
    }
}

struct OV5StressScreen: View {
    let flow: OV5Flow
    var body: some View {
        @Bindable var store = flow.store
        OV5Screen {
            OV5Header(title: "and the stress level?", italic: ["stress"])
            OV5SelectList(
                options: [
                    .init(key: "low", label: "low"),
                    .init(key: "manageable", label: "manageable"),
                    .init(key: "heavy", label: "heavy"),
                    .init(key: "overwhelmed", label: "overwhelmed"),
                ],
                selection: $store.stressLevel,
                onCommit: { flow.advance() }
            )
        }
    }
}

struct OV5GenderScreen: View {
    let flow: OV5Flow
    var body: some View {
        @Bindable var store = flow.store
        OV5Screen {
            OV5Header(
                title: "which body does the math use?",
                italic: ["math"],
                sub: "calorie math differs by sex. answer however fits."
            )
            OV5SelectList(
                options: [
                    .init(key: "female", label: "female"),
                    .init(key: "male", label: "male"),
                    .init(key: "nonbinary", label: "non-binary"),
                    .init(key: "private", label: "prefer not to say", icon: "lock"),
                ],
                selection: $store.gender,
                onCommit: { flow.advance() }
            )
        }
    }
}

struct OV5AgeScreen: View {
    let flow: OV5Flow
    @State private var age: Double = 25

    var body: some View {
        OV5RulerScreen(
            title: "how many years in?",
            titleItalic: ["years"],
            value: $age,
            range: 16...80,
            majorEvery: 5,
            majorLabel: { v in Int(v) % 10 == 0 ? "\(Int(v))" : "" },
            readout: { "\(Int($0))" },
            readoutUnit: "years",
            derivedLine: { EmptyView() },
            onContinue: {
                flow.store.ageYears = Int(age)
                flow.advance()
            }
        )
        .onAppear { age = Double(flow.store.ageYears) }
    }
}

struct OV5HeightScreen: View {
    let flow: OV5Flow
    @State private var displayValue: Double = 65   // inches by default
    @State private var unitIndex = 0               // 0 = ft/in · 1 = cm

    var body: some View {
        OV5RulerScreen(
            title: "how tall are you?",
            titleItalic: ["tall"],
            value: $displayValue,
            range: unitIndex == 0 ? 54...78 : 137...198,
            majorEvery: unitIndex == 0 ? 6 : 5,
            majorLabel: { v in
                if unitIndex == 0 {
                    return Int(v) % 6 == 0 ? "\(Int(v) / 12)'\(Int(v) % 12)\"" : ""
                }
                return Int(v) % 10 == 0 ? "\(Int(v))" : ""
            },
            readout: { v in
                unitIndex == 0 ? "\(Int(v) / 12)'\(Int(v) % 12)\"" : "\(Int(v))"
            },
            readoutUnit: unitIndex == 0 ? nil : "cm",
            units: ["ft / in", "cm"],
            selectedUnit: Binding(
                get: { unitIndex },
                set: { newIndex in
                    guard newIndex != unitIndex else { return }
                    displayValue = newIndex == 0
                        ? (displayValue / cmPerIn).rounded()
                        : (displayValue * cmPerIn).rounded()
                    unitIndex = newIndex
                    flow.store.usesFtIn = newIndex == 0
                }
            ),
            derivedLine: { EmptyView() },
            onContinue: {
                flow.store.heightCm = unitIndex == 0 ? displayValue * cmPerIn : displayValue
                flow.advance()
            }
        )
        .onAppear {
            unitIndex = flow.store.usesFtIn ? 0 : 1
            let cm = flow.store.heightCm
            displayValue = unitIndex == 0 ? (cm / cmPerIn).rounded() : cm.rounded()
        }
    }
}

struct OV5WeightScreen: View {
    let flow: OV5Flow
    @State private var displayValue: Double = 160
    @State private var unitIndex = 0               // 0 = lb · 1 = kg
    @State private var committed = false

    var body: some View {
        OV5RulerScreen(
            title: "where's the scale today?",
            titleItalic: ["today"],
            trust: "sets your starting point. never shown back as a grade.",
            value: $displayValue,
            range: unitIndex == 0 ? 80...400 : 36...181,
            majorEvery: 5,
            majorLabel: { v in
                let every = unitIndex == 0 ? 20 : 10
                return Int(v) % every == 0 ? "\(Int(v))" : ""
            },
            readout: { "\(Int($0))" },
            readoutUnit: unitIndex == 0 ? "lb" : "kg",
            units: ["lb", "kg"],
            selectedUnit: Binding(
                get: { unitIndex },
                set: { newIndex in
                    guard newIndex != unitIndex else { return }
                    displayValue = newIndex == 0
                        ? (displayValue * lbPerKg).rounded()
                        : (displayValue / lbPerKg).rounded()
                    unitIndex = newIndex
                    flow.store.usesLb = newIndex == 0
                }
            ),
            derivedLine: {
                if committed {
                    ItalicAccentText(
                        "okay. that's the hard one ♥",
                        italic: ["hard"],
                        baseFont: .custom("DMSans-Regular", size: 14),
                        italicFont: .custom("JeniHeroSerif-Italic", size: 16),
                        color: Palette.textSecondary,
                        alignment: .center
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity.combined(with: .offset(y: 6)))
                }
            },
            ctaLabel: committed ? "continue" : "that's me",
            onContinue: {
                let kg = unitIndex == 0 ? displayValue / lbPerKg : displayValue
                flow.store.currentWeightKg = kg
                if committed {
                    flow.advance()
                } else {
                    // The one earned confirmation in the numbers act: a
                    // beat of acknowledgment before moving on, not a toast.
                    withAnimation(Motion.entranceSoft) { committed = true }
                    Haptics.soft()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
                        flow.advance()
                    }
                }
            }
        )
        .onAppear {
            unitIndex = flow.store.usesLb ? 0 : 1
            let kg = flow.store.currentWeightKg
            displayValue = unitIndex == 0 ? (kg * lbPerKg).rounded() : kg.rounded()
            committed = false
        }
    }
}

struct OV5WeightTrendScreen: View {
    let flow: OV5Flow
    @State private var showRegainAck = false

    var body: some View {
        @Bindable var store = flow.store
        OV5Screen {
            OV5Header(title: "lately, your weight has been…", italic: ["lately"])
            OV5SelectList(
                options: [
                    .init(key: "climbing", label: "climbing"),
                    .init(key: "stable", label: "about the same"),
                    .init(key: "declining", label: "slowly coming down"),
                    .init(key: "cycling", label: "up and down"),
                ],
                selection: $store.weightTrend,
                autoAdvance: !regainAckApplies,
                onCommit: { flow.advance() }
            )
            if showRegainAck {
                ItalicAccentText(
                    "that's the regain window. it's exactly what we build for.",
                    italic: ["exactly"],
                    baseFont: .custom("DMSans-Regular", size: 14),
                    italicFont: .custom("JeniHeroSerif-Italic", size: 16),
                    color: Palette.textSecondary,
                    alignment: .center
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, Space.lg)
                .transition(.opacity.combined(with: .offset(y: 6)))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        flow.advance()
                    }
                }
            }
            Spacer()
        }
        .onChange(of: flow.store.weightTrend) { _, newValue in
            // Post-GLP-1 + climbing = the regain window: the branch's one
            // duty-of-care acknowledgment, worth the extra beat.
            if regainAckApplies && (newValue == "climbing" || newValue == "cycling") {
                withAnimation(Motion.entranceSoft) { showRegainAck = true }
            } else if regainAckApplies {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { flow.advance() }
            }
        }
    }

    private var regainAckApplies: Bool { flow.store.isPastGlp1 }
}

struct OV5GoalDirectionScreen: View {
    let flow: OV5Flow
    var body: some View {
        @Bindable var store = flow.store
        let past = flow.store.isPastGlp1
        var options: [OV5Option] {
            let lose = OV5Option(key: "lose", label: "lose weight")
            let maintain = OV5Option(key: "maintain", label: "maintain where i am")
            let kept = OV5Option(key: "maintain_kept", label: "keep off what i've lost")
            let recomp = OV5Option(key: "recomp", label: "tone up and get stronger")
            // Post-GLP-1 sees "keep what you built" FIRST — the
            // maintenance-first posture from the medical audit.
            return past ? [kept, lose, maintain, recomp] : [lose, maintain, kept, recomp]
        }
        return OV5Screen {
            OV5Header(title: "what are we working toward?", italic: ["working toward"])
            OV5SelectList(
                options: options,
                selection: $store.goalDirection,
                onCommit: { flow.advance() }
            )
        }
    }
}

struct OV5GoalWeightScreen: View {
    let flow: OV5Flow
    @State private var displayValue: Double = 145
    @State private var unitIndex = 0

    var body: some View {
        let isMaintain = flow.store.goalDirection == "maintain"
            || flow.store.goalDirection == "maintain_kept"
        OV5RulerScreen(
            title: isMaintain ? "the weight you're keeping." : "what number feels like yours?",
            titleItalic: isMaintain ? ["keeping."] : ["yours"],
            value: $displayValue,
            range: unitIndex == 0 ? 80...400 : 36...181,
            majorEvery: 5,
            anchor: anchorDisplay,
            majorLabel: { v in
                let every = unitIndex == 0 ? 20 : 10
                return Int(v) % every == 0 ? "\(Int(v))" : ""
            },
            readout: { "\(Int($0))" },
            readoutUnit: unitIndex == 0 ? "lb" : "kg",
            units: ["lb", "kg"],
            selectedUnit: Binding(
                get: { unitIndex },
                set: { newIndex in
                    guard newIndex != unitIndex else { return }
                    displayValue = newIndex == 0
                        ? (displayValue * lbPerKg).rounded()
                        : (displayValue / lbPerKg).rounded()
                    unitIndex = newIndex
                    flow.store.usesLb = newIndex == 0
                }
            ),
            derivedLine: { liveLine },
            onContinue: {
                flow.store.goalWeightKg = goalKg
                flow.advance()
            }
        )
        .onAppear {
            unitIndex = flow.store.usesLb ? 0 : 1
            let seeded = flow.store.goalWeightKg > 0
                ? flow.store.goalWeightKg
                : flow.store.currentWeightKg * 0.9
            displayValue = unitIndex == 0 ? (seeded * lbPerKg).rounded() : seeded.rounded()
        }
    }

    private var goalKg: Double {
        unitIndex == 0 ? displayValue / lbPerKg : displayValue
    }
    private var anchorDisplay: Double {
        let kg = flow.store.currentWeightKg
        return unitIndex == 0 ? (kg * lbPerKg).rounded() : kg.rounded()
    }

    /// Below the healthy-BMI floor the line flips to the sage safety
    /// register and the CTA still proceeds — the SafetyGate downstream
    /// owns the hard routing; this line is honest guidance, not a wall.
    @ViewBuilder private var liveLine: some View {
        let store = flow.store
        let bmi = goalBMI
        if bmi > 0 && bmi < 18.5 {
            Text("that number sits under the healthy range for your height. we'll aim you at the floor instead.")
                .font(.custom("DMSans-Regular", size: 13))
                .foregroundStyle(Palette.stateGood)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        } else if store.currentWeightKg - goalKg >= 1 {
            let window = ProgramGoalCalculator.compute(.init(
                currentWeightKg: store.currentWeightKg,
                goalWeightKg: goalKg,
                sex: .unspecified,
                age: nil,
                isGLP1User: store.isCurrentGlp1,
                isPerimenopausal: ProgramGoalCalculator.isPerimenopausal(from: store.hormonalStage),
                isShortSleeper: ProgramGoalCalculator.isShortSleeper(from: store.sleepHours),
                weightTrendKey: store.weightTrend,
                glp1PhaseKey: store.glp1Phase
            ))
            HStack(spacing: 5) {
                Text("about")
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundStyle(Palette.textSecondary)
                Text("\(window.maxWeeks) weeks")
                    .font(.custom("JeniHeroSerif-Italic", size: 17))
                    .foregroundStyle(Palette.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.2), value: window.maxWeeks)
                Text("at the gentlest pace. room for life.")
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundStyle(Palette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        } else {
            Text("holding steady. the plan becomes a maintenance rhythm.")
                .font(.custom("DMSans-Regular", size: 13))
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var goalBMI: Double {
        let h = flow.store.heightCm / 100
        guard h > 0 else { return 0 }
        return goalKg / (h * h)
    }
}

struct OV5TargetReframeScreen: View {
    let flow: OV5Flow

    var body: some View {
        let store = flow.store
        let deltaKg = store.deltaKg
        let deltaLb = Int((deltaKg * lbPerKg).rounded())
        if deltaKg < 1 {
            OV5TeachView(
                title: "steady is a real goal.",
                titleItalic: ["real"],
                lead: "maintenance is its own practice. protein, movement, the trend line. we build the rhythm that holds it.",
                ctaLabel: "continue",
                onContinue: { flow.advance() }
            )
        } else if deltaKg <= store.currentWeightKg * 0.12 {
            OV5TeachView(
                title: "\(deltaLb) lb is an honest target.",
                titleItalic: ["honest"],
                lead: "the women who keep it off lose slowly, on purpose. even the first few pounds change how clothes sit.",
                closing: "no crash math here. just a pace that survives real weeks.",
                closingItalic: ["survives"],
                citation: "wing & phelan · national weight control registry",
                onContinue: { flow.advance() }
            )
        } else {
            OV5TeachView(
                title: "\(deltaLb) lb is a real journey. we pace it honestly.",
                titleItalic: ["honestly."],
                lead: "big deltas work when the pace protects your muscle and your sanity. we'll break yours into arcs, with maintenance built in.",
                closing: "slower is what makes it stick.",
                closingItalic: ["stick."],
                citation: "hollis 2008 · weight-loss maintenance trial",
                onContinue: { flow.advance() }
            )
        }
    }
}

struct OV5NsvScreen: View {
    let flow: OV5Flow
    var body: some View {
        @Bindable var store = flow.store
        let cohortExtras: [OV5Option] = {
            if flow.store.isCurrentGlp1 {
                return [.init(key: "muscle", label: "keeping muscle while i lose")]
            }
            if flow.store.isPastGlp1 {
                return [.init(key: "trust", label: "trusting food again")]
            }
            return [.init(key: "quiet", label: "quiet around food")]
        }()
        return OV5Screen {
            OV5Header(
                title: "what would you love back?",
                italic: ["love"],
                sub: "beyond the scale. pick what matters."
            )
            OV5MultiList(
                options: [
                    .init(key: "core", label: "a core that holds"),
                    .init(key: "energy", label: "energy that lasts"),
                    .init(key: "clothes", label: "clothes that fit right"),
                    .init(key: "sleep", label: "sleep that resets"),
                ] + cohortExtras,
                selection: $store.nsvPriority
            )
        }
        .ov5CTA("continue", isEnabled: !flow.store.nsvPriority.isEmpty) {
            flow.advance()
        }
    }
}

struct OV5CareBridgeScreen: View {
    let flow: OV5Flow
    var body: some View {
        OV5ReceiptView(
            title: "the care part.",
            titleItalic: ["care"],
            sub: "a few questions we ask every woman.\nmost apps skip this.",
            onContinue: { flow.advance() }
        )
    }
}

struct OV5MedicationScreen: View {
    let flow: OV5Flow
    var body: some View {
        @Bindable var store = flow.store
        OV5Screen {
            OV5Header(title: "any blood-sugar medication?", italic: ["blood-sugar"])
            OV5TrustLine(text: "changes how we pace fuel around movement. private, always.")
                .padding(.top, Space.sm)
                .ov5Beat2()
            OV5SelectList(
                options: [
                    .init(key: "insulin_or_sulfonylurea", label: "insulin, or a daily pill for blood sugar"),
                    .init(key: "other_glucose", label: "another blood-sugar medication"),
                    .init(key: "none", label: "no"),
                    .init(key: "prefer_not_say", label: "prefer not to say", icon: "lock"),
                ],
                selection: $store.medicationStatus,
                autoAdvance: false
            )
            Spacer()
        }
        .ov5CTA("continue", isEnabled: !flow.store.medicationStatus.isEmpty) {
            flow.advance()
        }
    }
}

/// The relocated SafetyGate: SCOFF + pregnancy + BMI + medication
/// routing runs HERE (end of the numbers act) so a terminal state never
/// fires at the reveal's peak-anticipation moment. The gate machinery
/// is untouched — only its position moved. Terminal states park inside
/// the presentation; only .loss / maintenance-passed calls onPassed.
struct OV5SafetyGateScreen: View {
    let flow: OV5Flow
    var body: some View {
        SafetyGatePresentation(
            onPassed: { flow.advance() }
        )
    }
}

struct OV5NumbersReceiptScreen: View {
    let flow: OV5Flow

    var body: some View {
        let store = flow.store
        OV5ReceiptView(
            title: "what you carry, counted.",
            titleItalic: ["carry"],
            rows: rows(store),
            footnote: "your plan starts there.",
            onContinue: { flow.advance() }
        )
    }

    private func rows(_ store: OV5Store) -> [OV5ReceiptRowData] {
        var out: [OV5ReceiptRowData] = []
        if store.deltaKg >= 1 {
            let lb = Int((store.deltaKg * lbPerKg).rounded())
            out.append(.init(lead: "the distance", punch: "\(lb) lb, paced honestly", punchItalic: ["honestly"]))
        } else {
            out.append(.init(lead: "the goal", punch: "holding steady", punchItalic: ["steady"]))
        }
        let sleepWords: [String: String] = [
            "under5": "under 5 hours", "five6": "5 to 6 hours",
            "six7": "6 to 7 hours", "seven8": "7 to 8 hours",
            "eightPlus": "8+ hours",
        ]
        if let s = sleepWords[store.sleepHours] {
            out.append(.init(lead: "your nights", punch: s, punchItalic: []))
        }
        let movementWords: [String: String] = [
            "barely": "starting from stillness", "walks": "walks here and there",
            "regular_ish": "regular-ish movement", "very_active": "very active",
        ]
        if let m = movementWords[store.movementBaseline] {
            out.append(.init(lead: "your baseline", punch: m, punchItalic: []))
        }
        return out
    }
}
