import SwiftUI

// MARK: - MoveSheet (v25 E8.1) — JENI MOVE
//
// Replaces `TodayStepsSheet`, whose whole content was a ring, seven
// dots and one line — while `MovementService` quietly read four more
// signals out of HealthKit and dropped every one.
//
// The order on the page IS the product's priority, not the numbers'
// sizes:
//
//   1. STRENGTH, twice a week. The only judgement Move makes, and the
//      lever that decides what the weight loss is made of.
//   2. TODAY, measured. Steps, and the rows Health supplies, each
//      wearing its provenance.
//   3. THE WEEK, as rhythm rather than magnitude (kept from the old
//      sheet: bars invite comparing a 10k day against a 2k day; dots
//      read as days that happened).
//   4. ONE LINE, from her own baseline.
//
// What is deliberately absent: a second ring, a score, a goal to close,
// and any arithmetic between movement and food. "you ate 500, burn 500"
// is on the vocabulary kill list and is the fastest way to teach
// compensation.
//
// The HealthKit permission states are kept verbatim from the sheet this
// replaces — never-asked invites, denied explains the path back through
// Health — because they were already right.

struct MoveSheet: View {
    let goal: Int
    /// Her latest weight, for the manual-entry estimate. nil = no
    /// estimate is offered at all (the model has no scale).
    var weightKg: Double?

    @State private var steps = StepsService.shared
    @State private var movement = MovementService.shared
    @State private var manual: [MoveManualStore.Entry] = []
    @State private var recording = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        JKSheetChrome(
            title: "move",
            italic: ["move"],
            eyebrow: "what your body did"
        ) {
            VStack(alignment: .leading, spacing: Space.lg) {
                switch steps.authStatus {
                case .authorized:
                    connected
                case .notDetermined:
                    // The invite still leads, but Move is useful without
                    // Health now: a recorded session counts either way.
                    JKEmptyState(
                        line: "your movement can count itself",
                        italic: ["count itself"],
                        actionLabel: "connect apple health",
                        action: { Task { await steps.requestAccess() } }
                    )
                    strengthBlock
                    recordRow
                case .denied, .unavailable:
                    deniedState
                    strengthBlock
                    recordRow
                }
            }
            // JKSheetChrome pads its own header and rule but hands the
            // content closure an unpadded width. Filming caught it: every
            // row sat flush to the leading edge and today's step count was
            // clipped off the trailing one.
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            // In DEBUG the harness seeds a representative week through
            // StepsService's QA seam; refreshing would immediately
            // overwrite it with the simulator's empty HealthKit and the
            // surface would be unfilmable — the same trap E7 recorded when
            // `--uitest-seed-program` re-seeded after `--uitest-wipe-food`.
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--debug-move") { return }
            #endif
            await steps.refresh()
            await movement.refresh()
        }
        .onAppear { manual = MoveManualStore.lastWeek() }
        .sheet(isPresented: $recording) {
            MoveRecordSheet(weightKg: weightKg) {
                manual = MoveManualStore.lastWeek()
            }
            .presentationDetents(JeniSheetHeight.brief)
            .presentationBackground(Palette.bgPrimary)
            .presentationCornerRadius(28)
        }
    }

    // MARK: - The record, resolved

    private var record: MoveRecord {
        MoveRecord(
            stepsToday: steps.authStatus == .authorized ? steps.todayCount : nil,
            stepsGoal: goal,
            stepsBaseline: baseline,
            weeklySteps: steps.weeklyCounts,
            activeEnergy: movement.activeEnergyTodayKcal.map {
                MoveValue(amount: Double($0), provenance: .measured)
            },
            distanceKm: movement.distanceTodayKm.map {
                MoveValue(amount: $0, provenance: .measured)
            },
            workoutMinutesToday: movement.workoutMinutesToday > 0
                ? movement.workoutMinutesToday : nil,
            strengthSessionsLast7: movement.strengthSessionsLast7,
            enteredSessionsLast7: manual.filter { $0.kind.countsAsStrength }.count
        )
    }

    /// Her own 28-day mean, which is the only baseline Move ever
    /// compares her to. nil until there is enough of it to mean
    /// anything.
    private var baseline: Int? {
        let counts = steps.dailyCounts28
        guard counts.contains(where: { $0 > 0 }) else { return nil }
        return counts.reduce(0, +) / counts.count
    }

    // MARK: - Sections

    @ViewBuilder private var connected: some View {
        strengthBlock
        todayBlock
        weekBlock
        if let line = MoveEnergy.nextLine(record) {
            Text(line)
                .font(.custom("JeniHeroSerif-Italic", size: 16))
                .foregroundStyle(Palette.cocoaSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.sm)
        }
        recordRow
        Spacer().frame(height: Space.xl)
    }

    /// THE HEADLINE. A count of what happened, never a plan, and never a
    /// verdict: a week with one session says "one", not "you missed one".
    @ViewBuilder private var strengthBlock: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("strength this week")
                .font(Typo.statLabel)
                .kerning(0.66)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)

            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Text("\(record.totalStrengthLast7)")
                    .font(.custom("JeniHeroSerif-Regular", size: 44))
                    .foregroundStyle(Palette.textPrimary)
                // THE DENOMINATOR DROPS ONCE THE TARGET IS MET. E7
                // established this on protein ("123 of 90 g" read as a
                // typo) and E8 carried it into the evening close; filming
                // caught Move rendering "3 of 2", which reads as an error
                // rather than as three sessions. Once it is met the ratio
                // stops being the interesting fact.
                if !record.strengthMet {
                    Text("of \(MoveRecord.strengthTargetPerWeek)")
                        .font(.custom("JeniHeroSerif-Italic", size: 20))
                        .foregroundStyle(Palette.cocoaSecondary)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                record.strengthMet
                    ? "\(record.totalStrengthLast7) strength sessions this week"
                    : "\(record.totalStrengthLast7) of \(MoveRecord.strengthTargetPerWeek) strength sessions this week"
            )

            // The denominator is genuinely earned here, unlike most: it
            // is a published frequency, not a number this product made
            // up, so it gets to be stated as one.
            Text("twice a week is the guidance while weight is coming off. protein is the material; loading is the signal to keep it.")
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)
                .fixedSize(horizontal: false, vertical: true)

            if record.enteredSessionsLast7 > 0 && record.strengthSessionsLast7 > 0 {
                // Mixed provenance must be visible: part sensor, part
                // her word. Neither is wrong; conflating them would be.
                provenanceNote(
                    "\(record.strengthSessionsLast7) from health, "
                        + "\(record.enteredSessionsLast7) you recorded"
                )
            } else if record.enteredSessionsLast7 > 0 {
                provenanceNote(MoveProvenance.entered.word)
            } else if record.strengthSessionsLast7 > 0 {
                provenanceNote(MoveProvenance.measured.word)
            }
        }
    }

    @ViewBuilder private var todayBlock: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)

            Text("today")
                .font(Typo.statLabel)
                .kerning(0.66)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)

            if let stepsToday = record.stepsToday {
                measuredRow(
                    label: "steps",
                    value: stepsToday.formatted(.number),
                    provenance: .measured
                )
            }
            // ENERGY IS ONLY EVER SHOWN WHEN A DEVICE MEASURED IT. The
            // sheet this replaces printed steps × body weight × a
            // constant in the same typeface as everything else; that
            // number is a guess wearing a sensor's clothes.
            if let energy = record.activeEnergy {
                measuredRow(
                    label: "active energy",
                    value: "\(Int(energy.amount.rounded())) kcal",
                    provenance: energy.provenance
                )
            }
            if let distance = record.distanceKm {
                measuredRow(
                    label: "distance",
                    value: String(format: "%.1f km", distance.amount),
                    provenance: distance.provenance
                )
            }
            if let minutes = record.workoutMinutesToday {
                measuredRow(
                    label: "workout time",
                    value: "\(minutes) min",
                    provenance: .measured
                )
            }
            if record.stepsToday == nil && record.activeEnergy == nil
                && record.distanceKm == nil {
                Text("nothing has come through from health today.")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
            }
        }
    }

    @ViewBuilder private var weekBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
                .padding(.bottom, Space.sm)
            // Rhythm, not magnitude — kept from the sheet this replaces.
            HStack(spacing: 12) {
                ForEach(Array(record.weeklySteps.enumerated()), id: \.offset) { _, count in
                    Group {
                        if count >= goal {
                            Circle().fill(Palette.cocoaPrimary).frame(width: 6, height: 6)
                        } else if count >= goal / 2 {
                            Circle().strokeBorder(Palette.cocoaSecondary, lineWidth: 1)
                                .frame(width: 6, height: 6)
                        } else {
                            Capsule().fill(Palette.hairlineCocoa).frame(width: 6, height: 1.5)
                        }
                    }
                    .frame(height: 6)
                }
                Spacer(minLength: 0)
            }
            // At accessibility sizes the joined caption truncated to
            // "THE WE… · YOUR…", which is not a label. Caught at XXXL by
            // filming, and the same shape as the header fix HomeView made
            // when a name became "aft…m…".
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("the week's rhythm")
                        if let baseline {
                            Text("your usual is \(baseline.formatted(.number))")
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        Text("the week's rhythm")
                        if let baseline {
                            Text("\u{00B7}")
                            Text("your usual is \(baseline.formatted(.number))")
                        }
                    }
                }
            }
            .font(Typo.statLabel)
            .kerning(0.66)
            .textCase(.uppercase)
            .foregroundStyle(Palette.cocoaTertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(weekAccessibilityLabel)
    }

    private var weekAccessibilityLabel: String {
        let reached = record.weeklySteps.filter { $0 >= goal }.count
        return "the week's rhythm. \(reached) of 7 days reached your step goal."
    }

    private var recordRow: some View {
        Button {
            Haptics.soft()
            recording = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text("record something health missed")
                    .font(.custom("JeniHeroSerif-Regular", size: 18, relativeTo: .title3))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Capsule(style: .continuous).fill(Palette.roseBlush))
        }
        .buttonStyle(JKPress())
    }

    // MARK: - Atoms

    private func measuredRow(
        label: String, value: String, provenance: MoveProvenance
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
            Spacer(minLength: Space.sm)
            VStack(alignment: .trailing, spacing: 1) {
                Text(value)
                    .font(.custom("JeniHeroSerif-Regular", size: 20))
                    .foregroundStyle(Palette.textPrimary)
                // PROVENANCE IS A WORD, on every number, always. Never a
                // colour and never a tooltip: a measurement and an
                // estimate that look alike are the same number.
                Text(provenance.word)
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.cocoaTertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value), \(provenance.word)")
    }

    private func provenanceNote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundStyle(Palette.cocoaTertiary)
    }

    private var deniedState: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            JKEmptyState(line: "health access is off for jeni", italic: ["off"])
            Text("settings, then health, then data access. we'll be here. anything you record by hand still counts.")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - MoveRecordSheet
//
// Two taps. What, and how long. Nothing else, because the only judgement
// Move makes is "did something heavy happen twice this week", and sets,
// reps, load and RPE do not change that answer.

struct MoveRecordSheet: View {
    var weightKg: Double?
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: MoveEnergy.ManualKind = .strength
    @State private var minutes: Int = 30

    private static let minuteChoices = [10, 20, 30, 45, 60]

    var body: some View {
        JKSheetChrome(
            title: "what did you do?",
            italic: ["do?"],
            eyebrow: "health missed it"
        ) {
            VStack(alignment: .leading, spacing: Space.lg) {
                // The onboarding's own chip cloud, single-select. E7
                // made the side-effect rows a pill cloud for the same
                // reason: a capsule is the one shape in this system that
                // always means "tap me".
                OV5ChipCloud(
                    options: MoveEnergy.ManualKind.allCases.map { ($0.rawValue, $0.label) },
                    selection: Binding(
                        get: { [kind.rawValue] },
                        set: { picked in
                            guard let raw = picked.subtracting([kind.rawValue]).first,
                                  let match = MoveEnergy.ManualKind(rawValue: raw)
                            else { return }
                            kind = match
                        }
                    )
                )

                VStack(alignment: .leading, spacing: Space.sm) {
                    Text("for how long")
                        .font(Typo.statLabel)
                        .kerning(0.66)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.cocoaTertiary)
                    OV5ChipCloud(
                        options: Self.minuteChoices.map { ("\($0)", "\($0) min") },
                        selection: Binding(
                            get: { ["\(minutes)"] },
                            set: { picked in
                                guard let raw = picked.subtracting(["\(minutes)"]).first,
                                      let value = Int(raw) else { return }
                                minutes = value
                            }
                        )
                    )
                }

                // The estimate, shown BEFORE she saves and labelled as
                // one. Absent entirely when there is no weight on file:
                // a MET model with no body mass has no scale, and a
                // number without a scale is decoration.
                if let kcal = MoveEnergy.estimatedKcal(
                    kind: kind, minutes: minutes, weightKg: weightKg
                ) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("about \(kcal) kcal")
                            .font(.custom("JeniHeroSerif-Regular", size: 22))
                            .foregroundStyle(Palette.textPrimary)
                        Text("estimated from how long and how heavy that usually is. it is not a measurement, and it is not a number to eat back.")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.cocoaTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                JFContinueButton(label: "record it") {
                    MoveManualStore.record(
                        kind: kind, minutes: minutes, weightKg: weightKg
                    )
                    Analytics.track(.moveActivityRecorded, properties: [
                        "kind": kind.rawValue,
                        "minutes": minutes,
                        "counts_as_strength": kind.countsAsStrength,
                        "has_estimate": MoveEnergy.estimatedKcal(
                            kind: kind, minutes: minutes, weightKg: weightKg
                        ) != nil,
                    ])
                    onSaved()
                    dismiss()
                }
            }
            .padding(.top, Space.lg)
        }
    }
}
