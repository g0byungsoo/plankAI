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
    /// E8.2 — the guided-session door, passed by the host. Move became
    /// the "move" tile's destination, so the workout library keeps a
    /// door on this surface and its retirement trigger (workout_start
    /// vs recorded strength) stays a fair comparison.
    var openSession: (() -> Void)? = nil

    @State private var steps = StepsService.shared
    @State private var movement = MovementService.shared
    @State private var manual: [MoveManualStore.Entry] = []
    @State private var recording = false
    /// E8.2 — steps can be authorized (onboarding asked) while the
    /// movement types were never asked at all, because no shipped
    /// sheet ever included them. When iOS says the ask would still
    /// show something new, Move offers it here — the surface that
    /// renders the answer (L5).
    @State private var offerMovementConnect = false

    var body: some View {
        JKSheetChrome(
            title: "move",
            italic: ["move"],
            eyebrow: "what your body did"
        ) {
            // E8.2 — the sheet chrome is a plain VStack, and a VStack
            // taller than its fixed detent CENTER-clips, pushing the
            // header off the top. The E8.1 films never saw it because
            // the debug harness seeds only the steps row; the first
            // real HealthKit day (four rows + provenance words) is
            // taller than `tallFixed`. The header stays pinned; the
            // record scrolls.
            ScrollView(showsIndicators: false) {
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
                    recordedList
                case .denied, .unavailable:
                    deniedState
                    strengthBlock
                    recordedList
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
            // p66 — THE ACTION HIERARCHY. Move's one action wore a
            // left-aligned mechanism riddle ("add what health missed")
            // mid-scroll, and the guided-session door was a bare serif
            // line with no affordance at all. The screen's decision now
            // has the onboarding's own anatomy: ONE standing CTA in the
            // thumb zone, with the quieter path as its built-in
            // secondary — and the label names HER action, not our
            // backfill mechanism.
            .safeAreaInset(edge: .bottom) {
                JFContinueButton(
                    label: "record a session",
                    action: {
                        Haptics.soft()
                        recording = true
                    },
                    firesHaptic: false,
                    secondaryLabel: openSession != nil ? "or a guided session" : nil,
                    secondaryAction: openSession
                )
                .padding(.top, Space.sm)
                .background {
                    // The record scrolls under the action on paper, not
                    // through it (the p62 bottom-fade law).
                    Palette.bgPrimary
                        .overlay(alignment: .top) {
                            LinearGradient(
                                colors: [Palette.bgPrimary.opacity(0), Palette.bgPrimary],
                                startPoint: .top, endPoint: .bottom
                            )
                            .frame(height: 22)
                            .offset(y: -22)
                        }
                        .ignoresSafeArea(edges: .bottom)
                        .allowsHitTesting(false)
                }
                .accessibilityIdentifier("move.recordSession")
            }
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
            offerMovementConnect = await movement.shouldOfferAsk()
            #if DEBUG
            // Film door: the connect row's real population is devices
            // that granted health BEFORE this release (every new ask
            // now includes the movement types, so a fresh simulator
            // can never re-enter the state).
            if ProcessInfo.processInfo.arguments.contains("--uitest-move-offer-connect") {
                offerMovementConnect = true
            }
            #endif
        }
        .onAppear { manual = MoveManualStore.lastWeek() }
        // Pass 57 (D1) — this sat at `brief` (a single 0.42 fraction)
        // with a fixed VStack: two chip clouds, an estimate and the
        // record button, whose bottom half fell below a fold the sheet
        // could neither scroll past nor be dragged above. `brief`'s own
        // doc says "one question, one answer"; this asks two and shows
        // an estimate. Tall, with the body on the scroll law.
        .jeniSheet(isPresented: $recording) {
            MoveRecordSheet(
                weightKg: weightKg,
                strengthThisWeekBefore: record.totalStrengthLast7
            ) {
                manual = MoveManualStore.lastWeek()
            }
        }
    }

    // MARK: - The record, resolved

    private var record: MoveRecord {
        MoveRecord(
            // A zero here is an absence, not a reading — see
            // `MoveRecord.resolvedStepsToday`. This line used to render
            // `steps 0 · from health` at 7am.
            stepsToday: MoveRecord.resolvedStepsToday(
                authorized: steps.authStatus == .authorized,
                count: steps.todayCount
            ),
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

    /// SEVEN FAINT DOTS AND A LABEL IS NOT INFORMATION.
    ///
    /// `MoveRecord.isEmpty` was written for exactly this — its own
    /// comment calls it "the honest empty state, which is different from
    /// 'she did not move'" — and no view ever referenced it. Filming the
    /// rhythm row on a week with nothing above the faint threshold and
    /// no baseline showed a section whose entire content was seven grey
    /// specks over a header. The block earns its place when the week has
    /// a shape or she has a usual to be compared to.
    private var weekHasShape: Bool {
        record.weeklySteps.contains { $0 >= goal / 2 } || baseline != nil
    }

    @ViewBuilder private var connected: some View {
        strengthBlock
        todayBlock
        if weekHasShape { weekBlock }
        if let line = MoveEnergy.nextLine(record) {
            // v25 E9 — this rendered as a whole sentence in italic
            // serif, which breaks §12.13 twice over: italic is the
            // 1-3 word PUNCH, never a clause, and a sentence inside an
            // instrument panel is a CAPTION (§6.1), not an editorial
            // line. It also carried a raw size, so it did not scale.
            Text(line)
                .font(.custom("DMSans-Regular", size: 14, relativeTo: .footnote))
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.sm)
        }
        recordedList
        Spacer().frame(height: Space.sm)
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

            // A COUNT IS A HERO ONLY WHEN THERE IS SOMETHING TO COUNT.
            // At zero the reading is a sentence; the numeral arrives
            // with the first session. See `MoveEnergy.strengthHeadline`.
            switch MoveEnergy.strengthHeadline(record) {
            case .nothingYet(let line):
                Text(line)
                    .font(.custom("JeniHeroSerif-Regular", size: 26, relativeTo: .title))
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("no strength sessions on file this week")
                    .accessibilityIdentifier("move.strengthCount.0")

            case .count(let done, let of):
                HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                    Text("\(done)")
                        .font(.custom("JeniHeroSerif-Regular", size: 44, relativeTo: .largeTitle))
                        .foregroundStyle(Palette.textPrimary)
                    // THE DENOMINATOR DROPS ONCE THE TARGET IS MET. E7
                    // established this on protein ("123 of 90 g" read as
                    // a typo) and E8 carried it into the evening close;
                    // filming caught Move rendering "3 of 2", which reads
                    // as an error rather than as three sessions. Once it
                    // is met the ratio stops being the interesting fact.
                    if let of {
                        Text("of \(of)")
                            .font(.custom("JeniHeroSerif-Italic", size: 20, relativeTo: .title3))
                            .foregroundStyle(Palette.cocoaSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    of == nil
                        ? "\(done) strength sessions this week"
                        : "\(done) of \(of!) strength sessions this week"
                )
                .accessibilityIdentifier("move.strengthCount.\(done)")
            }

            // ONE clause, not two. The caption's only job is to justify
            // the denominator — a published frequency rather than a
            // number this product made up. The second sentence
            // ("protein is the material; loading is the signal") was the
            // TEACHING, which `MoveEnergy.nextLine` already carries and
            // the Method owns; a two-sentence paragraph inside an
            // instrument panel is an editorial line where §6.1 asks for
            // a caption.
            Text(strengthCaption)
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

    /// At zero the headline already says the week has not happened, so
    /// the caption carries the ASK. Once something is on file it carries
    /// the guidance the denominator quotes.
    private var strengthCaption: String {
        record.totalStrengthLast7 == 0
            ? "twice is the whole ask, and it is what keeps the muscle while the weight moves."
            : "twice a week is the guidance while the weight is coming off."
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
            if offerMovementConnect {
                // The honest reason those rows are missing is that iOS
                // was never asked — saying "nothing came through" here
                // would blame her data for our missing sheet.
                connectRow
            } else if record.stepsToday == nil && record.activeEnergy == nil
                && record.distanceKm == nil && record.workoutMinutesToday == nil {
                Text("nothing has come through from health today.")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
            }
        }
    }

    /// One quiet ask, in the row grammar the block already speaks.
    private var connectRow: some View {
        Button {
            Haptics.soft()
            Task {
                await movement.requestAccess()
                offerMovementConnect = await movement.shouldOfferAsk()
            }
        } label: {
            HStack(alignment: .firstTextBaseline) {
                Text("workouts and distance can come through on their own")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: Space.sm)
                // AN UNDERLINED INLINE TEXT LINK EXISTS NOWHERE ELSE IN
                // THIS PRODUCT — it is web grammar, and it was the one
                // thing on this surface that still read as the older
                // app. A hairline capsule is the secondary affordance
                // the system already speaks (the plate page's "off?
                // remove this plate", the wall's exits).
                Text("connect")
                    .font(.custom("DMSans-Medium", size: 13, relativeTo: .footnote))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        Capsule().strokeBorder(Palette.hairlineCocoa, lineWidth: 0.66)
                    )
                    .contentShape(Capsule())
            }
        }
        .buttonStyle(JKPress())
        .accessibilityIdentifier("move.connectHealth")
    }

    @ViewBuilder private var weekBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
                .padding(.bottom, Space.sm)
            // Rhythm, not magnitude — kept from the sheet this replaces.
            //
            // THE THIRD MARK WAS A DASH, and E9 recorded the result as
            // "a dashed divider that exists nowhere else in the
            // product". There is no divider. Seven below-half days each
            // drew a 6×1.5 capsule, and a row of seven horizontal
            // dashes sitting directly above a section label IS a dashed
            // rule to every eye that meets it. A low-step week is
            // completely ordinary in this cohort, so the state is
            // reachable, not theoretical.
            //
            // Three states, three CIRCLES — the calendar strip's own
            // vocabulary. A row of circles cannot become a line.
            // p66 — the marks grew to a legible size and their tracked-
            // caps label died: five uppercase labels on one panel was a
            // form, not a page, and 6pt specks read as dust on film.
            // The baseline sentence alone carries the block's meaning.
            HStack(spacing: 14) {
                ForEach(Array(record.weeklySteps.enumerated()), id: \.offset) { _, count in
                    Group {
                        if count >= goal {
                            Circle().fill(Palette.cocoaPrimary).frame(width: 9, height: 9)
                        } else if count >= goal / 2 {
                            Circle().strokeBorder(Palette.cocoaSecondary, lineWidth: 1.2)
                                .frame(width: 9, height: 9)
                        } else {
                            Circle().fill(Palette.hairlineCocoa).frame(width: 8, height: 8)
                        }
                    }
                    .frame(height: 9)
                }
                Spacer(minLength: 0)
            }
            if let baseline {
                Text("your usual is \(baseline.formatted(.number)) a day")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(weekAccessibilityLabel)
    }

    private var weekAccessibilityLabel: String {
        let reached = record.weeklySteps.filter { $0 >= goal }.count
        return "the week's rhythm. \(reached) of 7 days reached your step goal."
    }

    // MARK: recorded by you (p53 — the write-only hole closed)
    //
    // A recorded session used to be invisible forever: a `.walk`
    // entry changed no pixel on any screen, and nothing could ever be
    // viewed or removed (the store's `delete` had zero callers). The
    // record's own laws demand a record be readable and correctable.
    @ViewBuilder private var recordedList: some View {
        if !manual.isEmpty {
            Text("RECORDED BY YOU")
                .font(Typo.eyebrow)
                .kerning(1.4)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.top, Space.sm)
            VStack(spacing: 0) {
                ForEach(manual) { entry in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(entry.kind.label)
                            .font(.custom("DMSans-Medium", size: 14, relativeTo: .subheadline))
                            .foregroundStyle(Palette.textPrimary)
                        Text("\(entry.minutes) min · \(manualDayWord(entry.at))")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.cocoaTertiary)
                        Spacer(minLength: 8)
                        Button {
                            Haptics.soft()
                            withAnimation(JeniMotion.settle) {
                                MoveManualStore.delete(id: entry.id)
                                manual = MoveManualStore.lastWeek()
                            }
                        } label: {
                            Text("remove")
                                .font(Typo.caption)
                                .foregroundStyle(Palette.cocoaTertiary)
                                // p63 — a destructive word at a
                                // caption's own hit height; the
                                // shape meets the floor, the row
                                // keeps its height.
                                .padding(.vertical, 14)
                                .padding(.horizontal, 8)
                                .contentShape(Rectangle())
                                .padding(.vertical, -14)
                                .padding(.horizontal, -8)
                                .underline()
                        }
                        .buttonStyle(JKPress())
                        .accessibilityLabel("remove \(entry.kind.label), \(entry.minutes) minutes")
                    }
                    .padding(.vertical, 8)
                    Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
                }
            }
        }
    }

    private func manualDayWord(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "today" }
        if cal.isDateInYesterday(date) { return "yesterday" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEEE"
        return f.string(from: date).lowercased()
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
                    .font(.custom("JeniHeroSerif-Regular", size: 20, relativeTo: .title3))
                    .foregroundStyle(Palette.textPrimary)
                // PROVENANCE IS A WORD, on every number, always. Never a
                // colour and never a tooltip: a measurement and an
                // estimate that look alike are the same number.
                //
                // It was `.system(size: 10)`, which does NOT scale —
                // that is the real Dynamic Type defect E9's note
                // describes, and it sat on the one label the design law
                // says must always be readable. At AX5 the numbers grew
                // three times and their provenance stayed at 10pt.
                Text(provenance.word)
                    .font(.custom("DMSans-Regular", size: 10, relativeTo: .caption2))
                    .foregroundStyle(Palette.cocoaTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value), \(provenance.word)")
    }

    private func provenanceNote(_ text: String) -> some View {
        Text(text)
            .font(.custom("DMSans-Regular", size: 10, relativeTo: .caption2))
            .foregroundStyle(Palette.cocoaTertiary)
            .fixedSize(horizontal: false, vertical: true)
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
    /// p63 — the week's strength count BEFORE this entry, so the
    /// receipt can answer against the two-a-week ask without asking a
    /// store mid-commit.
    var strengthThisWeekBefore: Int = 0
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var kind: MoveEnergy.ManualKind = .strength
    @State private var minutes: Int = 30
    /// p63 — the receipt phase. "record it" used to dismiss on the
    /// same runloop as the record haptic: the strongest confirm in
    /// the grammar against a vanishing sheet. The commit now answers
    /// in words (the weight ritual's own kept pattern) and dwells
    /// `receiptDwell` before the sheet excuses itself.
    @State private var kept: (line: String, italic: [String], sub: String)?
    /// p64 — the spark burst riding the ask-met receipt ("that's
    /// twice this week"): the week's strength ask, met, is a
    /// completed useful behavior. Ledger-latched once per day.
    @State private var askMetBurst = 0

    private static let minuteChoices = [10, 20, 30, 45, 60]

    var body: some View {
        ZStack {
            form
                .opacity(kept == nil ? 1 : 0)
                .allowsHitTesting(kept == nil)
            JeniReceiptBeat(
                line: kept?.line ?? "",
                italic: kept?.italic ?? [],
                sub: kept?.sub,
                shown: kept != nil
            )
            .allowsHitTesting(false)
            .accessibilityHidden(kept == nil)
            .overlay {
                JeniBurst(tier: .spark, play: askMetBurst)
                    .frame(width: 320, height: 320)
            }
        }
    }

    private var form: some View {
        JKSheetChrome(
            title: "what did you do?",
            italic: ["do?"],
            // p66 — the eyebrow speaks the provenance vocabulary her
            // record already uses ("recorded by you" is the list this
            // entry lands in), not our backfill mechanism.
            eyebrow: "recorded by you"
        ) {
            ScrollView {
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
                            .font(.custom("JeniHeroSerif-Regular", size: 22, relativeTo: .title2))
                            .foregroundStyle(Palette.textPrimary)
                        Text("estimated from how long and how heavy that usually is. it is not a measurement, and it is not a number to eat back.")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.cocoaTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // p62 — a strength session is a FACT entering the
                // record: it speaks the record hand, not the
                // button's default hero medium. p63 — and the commit
                // answers in words before the sheet leaves: receipt,
                // then dwell, then dismissal. `onSaved` runs with the
                // write so the list behind is fresh even if she
                // swipes the sheet away mid-dwell.
                JFContinueButton(label: "record it", action: {
                    guard kept == nil else { return }
                    let receipt = MoveEnergy.receipt(
                        kind: kind, strengthThisWeekBefore: strengthThisWeekBefore
                    )
                    JeniHaptic.record()
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
                    withAnimation(reduceMotion ? nil : Motion.entranceSoft) {
                        kept = receipt
                    }
                    // p64 — the week's ask, met by THIS session (the
                    // second strength session), earns the spark's
                    // visual over its own receipt. The record haptic
                    // above stays the hand's confirm — a fact entered
                    // the record; the flecks carry the celebration.
                    let today = TodayStateService.dayKey()
                    if kind.countsAsStrength, strengthThisWeekBefore == 1,
                       CelebrationLedger.shouldCelebrate(.moveAskMet, dayKey: today) {
                        CelebrationLedger.recordCelebrated(.moveAskMet, dayKey: today)
                        askMetBurst += 1
                        Analytics.track(.celebrationShown, properties: [
                            "tier": "spark", "moment": "move_ask_met",
                        ])
                    }
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + JeniMotion.receiptDwell
                    ) { dismiss() }
                }, firesHaptic: false)
            }
            .padding(.top, Space.lg)
            .padding(.bottom, Space.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
