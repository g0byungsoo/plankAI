import SwiftUI
import SwiftData
import PlankFood
import PlankSync

// MARK: - HomeEvening (v11 T3)
//
// EveningClose + EveningJournalLine, extracted verbatim from
// TodayStateBand.swift when the band died with the v11 Home.
// The evening state machine is law; its skin gets its own loop
// pass on the evening walk.

// MARK: - EveningClose
//
// After 18:00 the day gets a closing beat: the receipt (only rows
// with real data), a one-tap feeling, and the tomorrow whisper.
// Skippable forever; never a guilt state.

// E8.2 — slimmed to the CARE ASKS (adequacy net · dose mark · shot-day
// anchor · sit-check). The record ledger, the protein door, the feeling
// row and the drafted tomorrow intention all live in HomeEveningMoment
// now; the crossfading show/hide flags this carried died with them.
struct EveningClose: View {
    let snapshot: TodaySnapshot

    // v8 — the chart writes ride the same taps (legacy keys stay
    // dual-written until every reader migrates).
    @Environment(\.modelContext) private var modelContext
    private var obsUserId: String { snapshot.plan?.userId ?? "" }

    // v3 on-medication: "how did today sit?" — one optional tap,
    // device-local; tomorrow's reading reflects HER answer back
    // (never an asserted medication cycle).
    @State private var pickedSit: String? =
        UserDefaults.standard.string(
            forKey: "day.sit.\(TodayStateService.dayKey())"
        )
    // Clinical checklist #1 (docs/app_v7/04_CLINICAL_CHECKLIST.md):
    // the dose-day mark — adherence is the between-visit question
    // clinics most lack, and one tap answers it. Generic wording
    // only (Apple 5.2.1: no drug brand names); observed, never
    // prescribed; skipped forever = fine.
    @State private var doseAnswer: String? =
        UserDefaults.standard.string(
            forKey: "day.dose.\(TodayStateService.dayKey())"
        )
    // v8 — the one-time shot-day ask: revealed after her first
    // "yes" while no regimen exists (the anchor collects itself
    // where the dose already lives — one ask per beat).
    @State private var shotDayAskVisible = false
    @State private var shotDayPickedWord: String?

    /// v3 adequacy net (on-medication / restriction-risk): a very
    /// light day flips the receipt's posture from score to care —
    /// under-eating is the documented risk on medication, and the
    /// question no calorie app asks.
    /// p54 — delegates to the snapshot's own property. This view held
    /// a verbatim copy of that rule, which is the two-derivations
    /// defect the snapshot property's doc comment says it exists to
    /// prevent; a future threshold change would have forked them.
    private var showsEnoughNet: Bool { snapshot.showsAdequacyNet }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsEnoughNet {
                // The adequacy net outranks the score — a care line,
                // not a ledger row (under-eating is the documented
                // risk on medication).
                ItalicAccentText(
                    "did you eat enough? even a small plate counts",
                    italic: ["enough?"],
                    baseFont: .custom("JeniHeroSerif-Regular", size: 17, relativeTo: .body),
                    italicFont: .custom("JeniHeroSerif-Italic", size: 17, relativeTo: .body),
                    color: Palette.cocoaSecondary
                )
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.md)
            }

            // On-medication: the dose-day mark, then the sit-check —
            // the same bare-word grammar, one register down. Skipped
            // forever = fine; answered = tomorrow's plates speak to
            // it, and the week's marks become the adherence thread a
            // clinic reads.
            // v25 E2 — the ask scopes to evenings where a dose is
            // actually in play: daily cadence, a weekly dose day, an
            // open late slot, or no regimen yet (the v8 pre-anchor
            // window keeps its job). A weekly injector's other five
            // evenings stay quiet (recon correction 5).
            if snapshot.chapter == .onMedication,
               snapshot.eveningDoseAskRelevant {
                VStack(alignment: .leading, spacing: 8) {
                    Text("medication day?")
                        .font(.custom("JeniHeroSerif-Italic", size: 15, relativeTo: .subheadline))
                        .foregroundStyle(Palette.cocoaSecondary)
                    HStack(spacing: 10) {
                        doseWord("yes")
                        doseWord("no")
                    }
                }
                .padding(.top, Space.lg)

                // v8 — the shot-day anchor, asked ONCE where the dose
                // already lives. One optional weekday; every engine
                // reads it; changeable anytime in the medication row.
                if shotDayAskVisible {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("which day is your shot, usually?")
                            .font(.custom("JeniHeroSerif-Italic", size: 15, relativeTo: .subheadline))
                            .foregroundStyle(Palette.cocoaSecondary)
                        HStack(spacing: 8) {
                            shotWord("mon", 1); shotWord("tue", 2)
                            shotWord("wed", 3); shotWord("thu", 4)
                        }
                        HStack(spacing: 8) {
                            shotWord("fri", 5); shotWord("sat", 6)
                            shotWord("sun", 7)
                        }
                    }
                    .padding(.top, Space.lg)
                    .transition(.opacity.combined(with: .offset(y: 6)))
                } else if let shotDayPickedWord {
                    Text("\(shotDayPickedWord). dose days follow it.")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.top, 10)
                        .transition(.opacity)
                }
            }

            // The sit-check reaches the post-medication chapter too —
            // GI comfort outlasts titration (04_CLINICAL_CHECKLIST),
            // and "backed up" joins the vocabulary: the most
            // persistent complaint was unrepresentable in three words.
            if snapshot.chapter == .onMedication || CohortStore.isPostGLP1 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("how did today sit?")
                        .font(.custom("JeniHeroSerif-Italic", size: 15, relativeTo: .subheadline))
                        .foregroundStyle(Palette.cocoaSecondary)
                    // Four words fit one line on most widths; SE +
                    // AX sizes wrap the long one beneath (bare-word
                    // grammar either way).
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            sitWord("fine")
                            sitWord("heavy")
                            sitWord("queasy")
                            sitWord("backed up")
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                sitWord("fine")
                                sitWord("heavy")
                                sitWord("queasy")
                            }
                            sitWord("backed up")
                        }
                    }
                    if let pickedSit {
                        Text(sitAck(pickedSit))
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                            .transition(.opacity)
                    }
                }
                .padding(.top, Space.lg)
            }

        }
        .onAppear { revealShotDayAskIfPending() }
    }

    /// A pre-filled "yes" with no anchor yet re-offers the shot-day
    /// ask on arrival (she may have closed the app mid-evening).
    func revealShotDayAskIfPending() {
        guard snapshot.chapter == .onMedication,
              doseAnswer == "yes",
              RegimenService.activeMedicationPlan(
                userId: obsUserId, in: modelContext
              ) == nil
        else { return }
        shotDayAskVisible = true
    }

    /// v25 E8 (founder steer: "the clickables always need to be pill
    /// formatted or button formatted"). These were bare 28pt serif
    /// words carrying no affordance — indistinguishable from the
    /// headline three inches above, on the one beat of the evening that
    /// asks her to DO something. (The feeling row itself lives in
    /// HomeEveningMoment now, one size down — E8.2.)
    private func doseWord(_ word: String) -> some View {
        Button {
            // v25 E2 — an open late slot is the slot the evening
            // "yes" means (takenAt stays now; a late log is honest).
            let key = (!snapshot.isDoseDay ? snapshot.openLateSlotDayKey : nil)
                ?? TodayStateService.dayKey()
            withAnimation(Motion.entranceSoft) { doseAnswer = word }
            // v24 — "yes" flows through THE chokepoint (event +
            // observation + key + check + reminder retirement,
            // converging with every other surface). "no" stays an
            // ANSWER, not a skip: the observation records it, the
            // slot stays open for a late log, nothing scolds.
            if word == "yes" {
                MedicationLog.resolve(
                    .taken(site: nil, note: nil, at: .now),
                    slotDayKey: key,
                    source: .evening,
                    userId: obsUserId,
                    in: modelContext
                )
                if RegimenService.activeMedicationPlan(
                    userId: obsUserId, in: modelContext
                ) == nil {
                    withAnimation(Motion.entranceSoft) { shotDayAskVisible = true }
                }
            } else {
                UserDefaults.standard.set(word, forKey: "day.dose.\(key)")
                ObservationStore.record(
                    .doseTaken, valueText: word,
                    payload: ObservationStore.regimenPayload(
                        RegimenService.activeMedicationPlanId(userId: obsUserId, in: modelContext)
                    ),
                    dayKey: key,
                    userId: obsUserId, in: modelContext
                )
                withAnimation(Motion.entranceSoft) { shotDayAskVisible = false }
            }
            Haptics.soft()
        } label: {
            Text(word)
                .font(.custom("JeniHeroSerif-Regular", size: 19, relativeTo: .title3))
                .foregroundStyle(
                    doseAnswer == word ? Palette.textInverse : Palette.textPrimary
                )
                .modifier(EveningPill(selected: doseAnswer == word, tone: .clinical))
        }
        .buttonStyle(JKPress())
        .accessibilityLabel("medication day, \(word)")
        .accessibilityAddTraits(doseAnswer == word ? [.isButton, .isSelected] : .isButton)
    }

    /// A weekday as a bare short word — the shot-day anchor's
    /// one-time collection (RegimenSheet holds the full editor).
    private func shotWord(_ word: String, _ iso: Int) -> some View {
        Button {
            RegimenService.setShotDay(iso, userId: obsUserId, in: modelContext)
            withAnimation(Motion.entranceSoft) {
                shotDayAskVisible = false
                shotDayPickedWord = word
            }
            Haptics.soft()
        } label: {
            Text(word)
                .font(.custom("JeniHeroSerif-Regular", size: 17, relativeTo: .body))
                .foregroundStyle(Palette.textPrimary)
                .modifier(EveningPill(selected: false, tone: .clinical))
        }
        .buttonStyle(JKPress())
        .accessibilityLabel("shot day \(word)")
    }

    private func sitWord(_ word: String) -> some View {
        Button {
            let key = TodayStateService.dayKey()
            withAnimation(Motion.entranceSoft) { pickedSit = word }
            UserDefaults.standard.set(word, forKey: "day.sit.\(key)")
            ObservationStore.record(
                .sitCheck, valueText: word,
                payload: ObservationStore.regimenPayload(
                    RegimenService.activeMedicationPlanId(userId: obsUserId, in: modelContext)
                ),
                dayKey: key,
                userId: obsUserId, in: modelContext
            )
            Haptics.soft()
        } label: {
            Text(word)
                .font(.custom("JeniHeroSerif-Regular", size: 17, relativeTo: .body))
                .foregroundStyle(
                    pickedSit == word ? Palette.textInverse : Palette.textPrimary
                )
                .lineLimit(1)
                .fixedSize()
                .modifier(EveningPill(selected: pickedSit == word, tone: .clinical))
        }
        .buttonStyle(JKPress())
        .accessibilityAddTraits(pickedSit == word ? [.isButton, .isSelected] : .isButton)
    }

    /// p54 — the acknowledgment copy moved into `EveningCloseEngine`
    /// (the §36 law: GI advice in a view body is a health rule nothing
    /// can test, and one of these three lines was folklore the tests
    /// then caught).
    private func sitAck(_ word: String) -> String {
        EveningCloseEngine.sitAck(word)
    }

}

// MARK: - HomeEveningMoment (E8.2 — redesigned on the founder's steer)
//
// The founder's read of the E8 close: the pills were too big, the big
// serif prose was ugly, and the nightly education line added nothing.
// The evidence agrees with all three (see EveningCloseEngine's headers):
// the record's value is the fact, not a sentence narrating the fact;
// education-as-fixture is the least-evidenced JITAI component; and the
// one element with same-night value is the protein close and its door.
//
// The new anatomy, top to bottom — nothing else renders, ever:
//   eyebrow  "closing the day" + a quiet day chip (no denominator: 12
//            of 140 reads as how little has happened, not progress)
//   hero     ONE sentence: the protein close on a gap night, one calm
//            confirmation otherwise
//   door     gap nights only — into E7's describe path
//   ledger   the record as right-aligned facts (plates · protein · plan)
//   intent   the drafted one-tap tomorrow plan, gap nights only; her
//            accepted plan reads back in the morning brief
//   anchor   tomorrow's real hold (dose day > adopted scale morning)
//   feeling  one small row — kept because the morning read pays it
//            back (E4's "proud" seasoning), one size down
//   asks     EveningClose: adequacy net + dose/shot/sit, when relevant
//   cta      goodnight. zero required taps to leave.

struct HomeEveningMoment: View {
    let snapshot: TodaySnapshot
    let onReflect: (String) -> Void
    let onDismiss: () -> Void

    @AppStorage("userName") private var userName: String = ""
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// p63 — the close SPEAKS instead of assembling: nine 0.055s
    /// indices used to land the hero, the receipt and three asks in
    /// one 0.44s breath. Three acts now — the statement, the
    /// receipt, the asks — on the speech beat; a tap completes them.
    @State private var act = 0
    /// p63 — the terminus phase: "goodnight" answers with a receipt
    /// and dwells before the cover excuses itself.
    @State private var closedReceipt: (line: String, italic: [String], sub: String)?
    /// p67 — THE INK SCENE at the terminus: the day literally goes
    /// dark as it closes. "goodnight" flips the whole surface to ink
    /// under the receipt, dwells, then returns to paper before the
    /// cover excuses itself (light → dark → light; Reduce Motion
    /// arrives on ink as a state).
    @State private var onInk = false
    @State private var pickedFeeling: String? =
        UserDefaults.standard.string(
            forKey: "day.reflection.\(TodayStateService.dayKey())"
        )
    @State private var intentionSet: Bool =
        UserDefaults.standard.string(
            forKey: "day.intention.\(TodayStateService.tomorrowDayKey())"
        ) != nil

    private var adequacyNetShowing: Bool { snapshot.showsAdequacyNet }

    /// Tomorrow anchors, computed from the same engines the composer
    /// uses. Dose: scheduled non-daily plans only — a daily cadence
    /// would make every evening "your dose day", which is noise, not
    /// an anchor.
    ///
    /// p53 [CORR]: this used to compare Apple's weekday (1 = sunday)
    /// against the ISO anchor (1 = monday), so the line fired the
    /// evening BEFORE the day before her shot — and never at all for
    /// sunday shots. The engine is the one weekday authority now,
    /// and interval rhythms come along for free.
    private var tomorrowIsDoseDay: Bool {
        guard let plan = RegimenService.activeMedicationPlan(
            userId: snapshot.plan?.userId ?? "", in: modelContext
        ), plan.scheduleRule != "daily", plan.scheduleRule != "asNeeded"
        else { return false }
        let tomorrow = Calendar.current.date(
            byAdding: .day, value: 1, to: .now
        ) ?? .now
        let facts = RegimenService.facts(for: plan)
        let events = DoseEventStore.slotEvents(
            userId: plan.userId, limit: 30, in: modelContext
        )
        return MedicationScheduleEngine.isDoseDay(
            tomorrow, facts: facts, events: events
        )
    }

    /// p55 — the rhythm behind tomorrow's dose day, so the anchor
    /// line can speak the plan she actually keeps.
    private var tomorrowDoseCadence: MedicationScheduleEngine.Cadence? {
        guard let plan = RegimenService.activeMedicationPlan(
            userId: snapshot.plan?.userId ?? "", in: modelContext
        ) else { return nil }
        return MedicationScheduleEngine.cadence(RegimenService.facts(for: plan))
    }

    private var tomorrowIsWeighDay: Bool {
        let context = PrescriptionEngineV2.Context.live(
            lastWeighInDaysAgo: snapshot.lastWeighInDaysAgo,
            lastSnapDaysAgo: nil
        )
        return PrescriptionEngineV2.weighInSlots(context: context)
            .contains(PrescriptionEngineV2.dayInWeek(snapshot.programDay + 1))
    }

    private var close: EveningCloseEngine.Close {
        EveningCloseEngine.close(
            EveningCloseEngine.Input(
                name: userName,
                proteinEatenG: snapshot.proteinEatenG,
                proteinFloorG: snapshot.targets.proteinG,
                plateCount: snapshot.plates.count,
                beatsDone: snapshot.completedBeatCount,
                beatsTotal: snapshot.carePlan.actionableBeats.count,
                weighedInToday: snapshot.lastWeighInDaysAgo == 0,
                numericsSuppressed: snapshot.targets.numericsSuppressed,
                adequacyNetShowing: adequacyNetShowing,
                tomorrowIsDoseDay: tomorrowIsDoseDay,
                tomorrowDoseCadence: tomorrowDoseCadence,
                tomorrowIsWeighDay: tomorrowIsWeighDay,
                weighAdopted: snapshot.lastWeighInDaysAgo != nil
            )
        )
    }

    /// The gap the door names; nil on met/suppressed/net nights.
    private var proteinGapTonight: Int? {
        guard !snapshot.targets.numericsSuppressed, !adequacyNetShowing,
              let floor = snapshot.targets.proteinG, floor > 0
        else { return nil }
        let gap = floor - snapshot.proteinEatenG
        return gap > 0 ? gap : nil
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(onInk ? Palette.bgInverse : Palette.bgPrimary)
                .ignoresSafeArea()
            content
                .opacity(closedReceipt == nil ? 1 : 0)
                .allowsHitTesting(closedReceipt == nil)
            // p68 — the goodnight's moon: one quiet drawn object on
            // the ink, above the receipt. No burst, no haptic change —
            // the close stays calm; the moon just makes the dark feel
            // like night instead of absence. Decorative only.
            JeniDoodle(
                name: "doodle-moon", size: 110,
                tint: Palette.textInverse.opacity(0.85)
            )
            .offset(y: -180)
            .opacity(closedReceipt != nil && onInk ? 1 : 0)
            .animation(.easeInOut(duration: JeniScene.flip), value: onInk)
            .allowsHitTesting(false)
            JeniReceiptBeat(
                line: closedReceipt?.line ?? "",
                italic: closedReceipt?.italic ?? [],
                sub: closedReceipt?.sub,
                shown: closedReceipt != nil,
                onInk: onInk
            )
            .allowsHitTesting(false)
            .accessibilityHidden(closedReceipt == nil)
        }
        .preferredColorScheme(onInk ? .dark : nil)
        // §5.7 — impatience is a valid input: a tap anywhere lands the
        // remaining acts. Simultaneous, so a visible control still
        // receives its own tap.
        .simultaneousGesture(TapGesture().onEnded {
            if act < 2 { Analytics.track(.arrivalSkipped, properties: ["surface": "close"]) }
            JeniActs.complete($act, to: 2)
        })
        .task {
            // What stood on the screen tonight — booleans only. The
            // morning read's `has_intention` is the payout half.
            Analytics.track(.eveningCloseShown, properties: [
                "protein_met": proteinGapTonight == nil,
                "has_intention": close.intention != nil,
            ])
            await JeniActs.run($act, to: 2, reduceMotion: reduceMotion)
        }
    }

    private var content: some View {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .jeniAct(0, current: act)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: Space.bandGap)

                        ItalicAccentText(
                            close.hero.text,
                            italic: close.hero.punch,
                            baseFont: .custom("JeniHeroSerif-Regular", size: 30, relativeTo: .title),
                            italicFont: .custom("JeniHeroSerif-Italic", size: 30, relativeTo: .title),
                            color: Palette.textPrimary
                        )
                        .kerning(-0.3)
                        .fixedSize(horizontal: false, vertical: true)
                        .jeniAct(0, current: act)

                        if let gap = proteinGapTonight {
                            Button {
                                JeniHaptic.tick()
                                // E7's "open the field and wait" — jeni
                                // never authors a plate.
                                AppRouter.shared.open(.foodDescribe(text: "", spoken: false))
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("add something")
                                        .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
                                }
                                .foregroundStyle(Palette.textInverse)
                                .modifier(EveningPill(selected: true, tone: .rose))
                            }
                            .buttonStyle(JKPress())
                            .padding(.top, Space.lg)
                            .accessibilityLabel("add something, \(gap) grams of protein left today")
                            .jeniAct(1, current: act)
                        }

                        if !close.ledger.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(Array(close.ledger.enumerated()), id: \.offset) { idx, row in
                                    FootLedgerRow(
                                        label: row.label, value: row.value,
                                        rule: idx < close.ledger.count - 1
                                    )
                                }
                            }
                            .padding(.top, Space.bandGap)
                            .jeniAct(1, current: act)
                        }

                        if let intention = close.intention {
                            intentionRow(intention)
                                .padding(.top, Space.bandGap)
                                .jeniAct(2, current: act)
                        }

                        if let anchor = close.anchor {
                            Text(anchor)
                                .font(Typo.caption)
                                .foregroundStyle(Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, close.intention == nil ? Space.bandGap : Space.md)
                                .jeniAct(2, current: act)
                        }

                        feelingRow
                            .padding(.top, Space.bandGap)
                            .jeniAct(2, current: act)

                        EveningClose(snapshot: snapshot)
                            .jeniAct(2, current: act)

                        Color.clear.frame(height: Space.xl)
                    }
                    .padding(.horizontal, Space.gutter)
                }
                // p62 — paper fades at both fold lines (frame-caught:
                // the hero scrolled THROUGH the pinned eyebrow, and
                // the last chip row sat half-clipped against the
                // goodnight capsule; scrolled content fades before it
                // touches the pinned chrome).
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [Palette.bgPrimary, Palette.bgPrimary.opacity(0)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 34)
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [Palette.bgPrimary.opacity(0), Palette.bgPrimary],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 24)
                    .allowsHitTesting(false)
                }

                // p63 — the terminus: the ritual answers before the
                // cover excuses itself. The breath haptic
                // (arcComplete) is the goodnight's own hand — a
                // swell, not a record thunk: closing the day files
                // nothing new, it settles what the day already holds.
                JFContinueButton(label: "goodnight", action: {
                    guard closedReceipt == nil else { return }
                    Analytics.track(.eveningCloseCompleted)
                    ActivationHaptics.shared.arcComplete()
                    let receipt = EveningCloseEngine.goodnight(name: userName)
                    // p67 — the scene: the surface flips to ink AS the
                    // receipt speaks; the day ends in the dark, then
                    // the paper returns before the cover leaves.
                    if reduceMotion {
                        onInk = true
                        closedReceipt = receipt
                    } else {
                        withAnimation(.easeInOut(duration: JeniScene.flip)) {
                            onInk = true
                        }
                        // The receipt's own 0.45s ease rides under the
                        // 0.55s surface flip — the consult's
                        // deliberately-mismatched overlap (§4.4), and
                        // no delayed withAnimation (the p63 value-flip
                        // law: schedule the flip, never the paint).
                        withAnimation(reduceMotion ? nil : Motion.entranceSoft) {
                            closedReceipt = receipt
                        }
                    }
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + JeniScene.flip + JeniMotion.receiptDwell
                    ) {
                        if reduceMotion { return onDismiss() }
                        // Only the SURFACE returns to paper — the
                        // receipt keeps standing through the flip
                        // (film-caught: resetting it re-showed the
                        // close's content for the exit beat).
                        withAnimation(.easeInOut(duration: JeniScene.exitFlip)) {
                            onInk = false
                        }
                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + JeniScene.exitFlip * 0.9
                        ) { onDismiss() }
                    }
                }, firesHaptic: false)
                    .padding(.horizontal, Space.gutter)
                    .padding(.bottom, Space.sm)
                    .jeniAct(2, current: act)
            }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("closing the day")
                .font(Typo.captionTracked)
                .kerning(1.98)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
            Spacer(minLength: Space.sm)
            if snapshot.isEnrolled {
                // The day stands without its denominator: 12 of 140
                // reads as how little has happened. The chip matches
                // Home's own.
                Text("day \(max(1, snapshot.programDay))")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaSecondary)
            }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.lg)
    }

    /// The drafted tomorrow plan: one tap turns the offer into her
    /// sentence, in her ink, and the morning brief reads it back.
    @ViewBuilder
    private func intentionRow(_ intention: EveningCloseEngine.Intention) -> some View {
        if intentionSet {
            ItalicAccentText(
                intention.text,
                italic: intention.punch,
                baseFont: .custom("JeniHeroSerif-Regular", size: 17, relativeTo: .body),
                italicFont: .custom("JeniHeroSerif-Italic", size: 17, relativeTo: .body),
                color: Palette.jeweledRose
            )
            .fixedSize(horizontal: false, vertical: true)
            .transition(.opacity)
            .accessibilityLabel("set for tomorrow: \(intention.text)")
        } else {
            Button {
                Haptics.soft()
                let tomorrowKey = TodayStateService.tomorrowDayKey()
                UserDefaults.standard.set(
                    intention.key, forKey: "day.intention.\(tomorrowKey)"
                )
                UserDefaults.standard.set(
                    intention.text, forKey: "day.intention.text.\(tomorrowKey)"
                )
                ObservationStore.record(
                    .tonightPlan, valueText: intention.key,
                    dayKey: TodayStateService.dayKey(),
                    userId: snapshot.plan?.userId ?? "", in: modelContext
                )
                Analytics.track(.eveningIntentionSet)
                withAnimation(Motion.entranceSoft) { intentionSet = true }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                    ItalicAccentText(
                        intention.text,
                        italic: intention.punch,
                        baseFont: .custom("JeniHeroSerif-Regular", size: 17, relativeTo: .body),
                        italicFont: .custom("JeniHeroSerif-Italic", size: 17, relativeTo: .body),
                        color: Palette.textPrimary
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: Space.sm)
                    Text("set it")
                        .font(.custom("DMSans-Medium", size: 14, relativeTo: .callout))
                        .foregroundStyle(Palette.textPrimary)
                        .modifier(EveningPill(selected: false, tone: .rose, compact: true))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(JKPress())
            .accessibilityLabel("set for tomorrow: \(intention.text)")
        }
    }

    /// One small optional row. Kept — not as a mood diary, but because
    /// the morning read pays "proud" back and jeni's next-morning
    /// register gates on "tender" (E4). One size down from E8's
    /// display-serif capsules, per the founder's read and the absence
    /// of any outcome evidence for a nightly mood rating at hero size.
    private var feelingRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("how did today feel?")
                .font(.custom("JeniHeroSerif-Italic", size: 15, relativeTo: .subheadline))
                .foregroundStyle(Palette.cocoaSecondary)
            HStack(spacing: 10) {
            ForEach(["proud", "okay", "tender"], id: \.self) { word in
                Button {
                    withAnimation(Motion.entranceSoft) { pickedFeeling = word }
                    onReflect(word)
                } label: {
                    Text(word)
                        .font(.custom("DMSans-Medium", size: 14, relativeTo: .callout))
                        .foregroundStyle(
                            pickedFeeling == word ? Palette.textInverse : Palette.textPrimary
                        )
                        .modifier(EveningPill(
                            selected: pickedFeeling == word, tone: .rose, compact: true
                        ))
                }
                .buttonStyle(JKPress())
                .accessibilityAddTraits(
                    pickedFeeling == word ? [.isButton, .isSelected] : .isButton
                )
            }
            }
        }
    }
}

// MARK: - EveningPill (v25 E8 — founder steer)
//
// One capsule grammar for every tappable word in the close. Two tones:
// `.rose` for the feeling (the reflective register) and `.clinical` for
// the dose / sit / shot-day marks, where the 2026-07-28 founder
// refinement forbids rose on a medication surface — those select by
// CONTRAST (filled ink vs hairline), never by accent colour.

struct EveningPill: ViewModifier {
    enum Tone { case rose, clinical }
    let selected: Bool
    var tone: Tone = .rose
    /// E8.2 — the founder's read of the E8 chips: too big. The compact
    /// size serves the moment's feeling row and "set it".
    var compact: Bool = false

    /// v25 E8 (founder steer: "buttons need to be aesthetic, modern,
    /// minimalistic button or chips WITH COLORS to match the jeni design
    /// theme"). The first cut was a hairline outline on paper —
    /// unmistakably tappable but colourless, so a chip at rest was
    /// indistinguishable from a disabled one.
    ///
    /// Colour comes from the v21 rose ramp, which is already the app's
    /// data language: blush at rest (the same wash `JeniRing` uses for
    /// its track), jeweled rose when chosen. Nothing new enters the
    /// palette — the eight locked tokens hold.
    private var fill: Color {
        switch (tone, selected) {
        case (.rose, true):      return Palette.jeweledRose
        case (.rose, false):     return Palette.roseBlush.opacity(0.30)
        // The 2026-07-28 founder refinement stands: rose never appears
        // on a medication surface. Clinical chips carry a warm neutral
        // at rest and select by contrast, not by accent.
        case (.clinical, true):  return Palette.textPrimary
        case (.clinical, false): return Palette.textPrimary.opacity(0.05)
        }
    }

    private var stroke: Color {
        guard !selected else { return .clear }
        return tone == .rose
            ? Palette.roseBlush.opacity(0.65)
            : Palette.hairlineCocoa
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, compact ? 13 : 16)
            .padding(.vertical, compact ? 7 : 9)
            .background(Capsule().fill(fill))
            .overlay(Capsule().stroke(stroke, lineWidth: 1))
            .contentShape(Capsule())
    }
}

// MARK: - FootLedgerRow (moved with the evening — its only consumer)

struct FootLedgerRow: View {
    let label: String
    let value: String
    var rule: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                Spacer(minLength: 16)
                Text(value)
                    .font(.custom("JeniHeroSerif-Regular", size: 19, relativeTo: .body))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 12)
            if rule {
                Rectangle()
                    .fill(Palette.hairlineCocoa)
                    .frame(height: 0.5)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value.a11yStripped)")
    }
}
