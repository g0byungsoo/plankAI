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

struct EveningClose: View {
    let snapshot: TodaySnapshot
    let onReflect: (String) -> Void
    /// The 52pt "closing the day." block is the MOMENT's job now
    /// (founder steer: Home never wears a takeover headline). Hosted
    /// inside JeniMoment the receipt starts straight at the ledger.
    var showsHeadline: Bool = true
    /// The moment TYPES tomorrow's shape as its second sentence, so
    /// the ledger must not say it again three inches below.
    var showsTomorrowRow: Bool = true
    /// v25 E8 — same law, new offender. The moment's FIRST sentence is
    /// now the day's record ("4 plates. 123 g of protein."), so the
    /// ledger's protein row would restate the identical number three
    /// inches below. E4 pinned this de-dup law after a frame catch;
    /// this keeps it holding now that the prose finally carries numbers.
    var showsProteinRow: Bool = true

    // v8 — the chart writes ride the same taps (legacy keys stay
    // dual-written until every reader migrates).
    @Environment(\.modelContext) private var modelContext
    private var obsUserId: String { snapshot.plan?.userId ?? "" }

    @State private var pickedFeeling: String? =
        UserDefaults.standard.string(
            forKey: "day.reflection.\(TodayStateService.dayKey())"
        )
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
    private var showsEnoughNet: Bool {
        guard snapshot.chapter == .onMedication || CohortStore.isRestrictiveRisk
        else { return false }
        let floor = (snapshot.targets.proteinG ?? 80) / 2
        return snapshot.proteinEatenG < floor && snapshot.plates.count <= 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Mission 3 (03_EDITORIAL.md §3): the close is the
            // evening's one owner — the vow's sibling, two lines at
            // 52pt. One grammar follows it top to bottom.
            if showsHeadline {
            ItalicAccentText(
                "closing\nthe day.",
                italic: ["day."],
                baseFont: .custom("JeniHeroSerif-Regular", size: 52, relativeTo: .largeTitle),
                italicFont: .custom("JeniHeroSerif-Italic", size: 52, relativeTo: .largeTitle),
                color: Palette.textPrimary
            )
            .lineSpacing(-12)
            .kerning(-0.5)
            .fixedSize(horizontal: false, vertical: true)
            }

            if showsEnoughNet {
                // The adequacy net outranks the score — a care line,
                // not a ledger row (under-eating is the documented
                // risk on medication).
                ItalicAccentText(
                    "did you eat enough? a gentle plate still counts",
                    italic: ["enough?"],
                    baseFont: .custom("JeniHeroSerif-Regular", size: 17, relativeTo: .body),
                    italicFont: .custom("JeniHeroSerif-Italic", size: 17, relativeTo: .body),
                    color: Palette.cocoaSecondary
                )
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.md)
            }

            // The receipt is a ledger — the same beat-19 rows as the
            // day's foot, so the close reads as the day settling.
            VStack(spacing: 0) {
                if showsProteinRow, !showsEnoughNet, snapshot.proteinEatenG > 0,
                   let target = snapshot.targets.proteinG {
                    FootLedgerRow(label: "protein", value: proteinWord(target: target))
                }
                if snapshot.completedBeatCount > 0 {
                    FootLedgerRow(label: "the plan", value: planReceipt)
                }
                // v9 P2 (D1's one granted whisper): the trend word
                // joins the ledger — render-only, established-floor-
                // gated, suppressed cohorts never see it.
                if snapshot.trendIsEstablished,
                   !snapshot.targets.numericsSuppressed,
                   let word = BodyStateService.trendWord(deltaKg: snapshot.emaDelta7dKg) {
                    FootLedgerRow(label: "trend", value: word)
                }
                if showsTomorrowRow {
                    FootLedgerRow(label: "tomorrow", value: tomorrowWhisper)
                }
            }
            .padding(.top, Space.md)

            // v7 phase 3 — the weigh-eve pre-frame: anticipation is
            // the coach's highest-value move. Spoken the night BEFORE
            // a scale morning, so tomorrow's number is already framed
            // as data, not verdict.
            if tomorrowIsWeighDay, !snapshot.targets.numericsSuppressed {
                Text("the scale tomorrow reads the week, not tonight")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, 8)
            }

            // v25 E8 (expert review) — THE DOOR under the protein
            // close. The sentence above says there is still time
            // tonight; without a door that is an observation, and the
            // review's whole point is that this screen observed seven
            // times and acted once. E7's describe path already exists,
            // so the highest-value beat on the evening costs one chip.
            if let gap = proteinGapTonight {
                Button {
                    JeniHaptic.tick()
                    // Empty text + spoken:false = E7's "open the field
                    // and wait". Jeni never authors a plate, and an
                    // evening nudge must not pre-fill words she did not
                    // say.
                    AppRouter.shared.open(.foodDescribe(text: "", spoken: false))
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("add something")
                            .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
                    }
                    .foregroundStyle(Palette.textPrimary)
                    .modifier(EveningPill(selected: false, tone: .rose))
                }
                .buttonStyle(JKPress())
                .padding(.top, Space.md)
                .accessibilityLabel("add something, \(gap) grams of protein left today")
            }

            // The feeling — three rose chips (v25 E8 founder steer;
            // the note that used to sit here said "capsules dead, the
            // word IS the button" and was left standing after the
            // capsules came back). Blush at rest, jeweled rose when
            // chosen. Re-tappable: an evening may change its mind.
            VStack(alignment: .leading, spacing: 10) {
                Text("how did today feel?")
                    .font(.custom("JeniHeroSerif-Italic", size: 17, relativeTo: .body))
                    .foregroundStyle(Palette.cocoaSecondary)
                HStack(spacing: 10) {
                    feelingWord("proud")
                    feelingWord("okay")
                    feelingWord("tender")
                }
            }
            .padding(.top, Space.lg)

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

            // v4 — THE TONIGHT PLAN (docs/app_v4/03_FEATURES.md §5):
            // a 15-second if-then for the evening's one predictable
            // moment. Mission 3: the options are a menu of hairline
            // lines; the pick becomes her sentence in her ink.
            if let plannedKey {
                if let plan = TonightPlan.option(for: plannedKey) {
                    Text("\(plan.plan)")
                        .font(.custom("JeniHeroSerif-Italic", size: 17, relativeTo: .body))
                        .foregroundStyle(Palette.jeweledRose)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.lg)
                        .transition(.opacity)
                }
            } else if pickedFeeling != nil {
                // Mission 2 (one ask per beat): the tonight plan
                // waits its turn — only an answered evening is
                // offered the if-then.
                VStack(alignment: .leading, spacing: 0) {
                    Text("tonight's plan, if cravings hit:")
                        .font(.custom("JeniHeroSerif-Italic", size: 17, relativeTo: .body))
                        .foregroundStyle(Palette.cocoaSecondary)
                        .padding(.bottom, 4)
                    ForEach(TonightPlan.options) { option in
                        planLine(option)
                    }
                }
                .padding(.top, Space.lg)
                .transition(.opacity.combined(with: .offset(y: 6)))
            }

        }
        .onAppear { revealShotDayAskIfPending() }
    }

    @State private var plannedKey: String? =
        TonightPlan.planned(dayKey: TodayStateService.dayKey())?.key

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

    /// A tonight-plan option as a hairline menu line — the rule is
    /// the row's only chrome.
    private func planLine(_ option: TonightPlan.Option) -> some View {
        Button {
            Haptics.soft()
            let key = TodayStateService.dayKey()
            TonightPlan.set(option.key, dayKey: key)
            ObservationStore.record(
                .tonightPlan, valueText: option.key, dayKey: key,
                userId: obsUserId, in: modelContext
            )
            withAnimation(Motion.entranceSoft) { plannedKey = option.key }
        } label: {
            VStack(spacing: 0) {
                Text(option.label)
                    .font(.custom("JeniHeroSerif-Regular", size: 17, relativeTo: .body))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 11)
                Rectangle()
                    .fill(Palette.hairlineCocoa)
                    .frame(height: 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
    }

    /// v25 E8 (founder steer: "the clickables always need to be pill
    /// formatted or button formatted"). These were bare 28pt serif
    /// words carrying no affordance — indistinguishable from the
    /// headline three inches above, on the one beat of the evening that
    /// asks her to DO something. The earlier note here read "capsules
    /// dead; the word IS the button" — overridden, and for the same
    /// reason E7 gave when the side-effect rows became a pill cloud: a
    /// capsule is the one shape in this system that always means "tap
    /// me". Selection still reads as ink, not as chrome.
    private func feelingWord(_ word: String) -> some View {
        Button {
            withAnimation(Motion.entranceSoft) { pickedFeeling = word }
            onReflect(word)
        } label: {
            Text(word)
                .font(.custom("JeniHeroSerif-Regular", size: 21, relativeTo: .title3))
                .foregroundStyle(
                    pickedFeeling == word ? Palette.textInverse : Palette.textPrimary
                )
                .modifier(EveningPill(selected: pickedFeeling == word, tone: .rose))
        }
        .buttonStyle(JKPress())
        .accessibilityAddTraits(pickedFeeling == word ? [.isButton, .isSelected] : .isButton)
    }

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

    /// Clinical register (founder refinement): the symptom stream
    /// acknowledges as fact — no hearts, no reward vocabulary.
    /// v25 E8 (expert review) — every one of these used to end in
    /// "tomorrow", at the exact moment she said she felt bad. GI
    /// symptoms are the leading reason people stop these medicines, and
    /// the moment of the complaint is the only moment the help is
    /// wanted. Clinical register unchanged: observed, never prescribed,
    /// no dosing guidance, no reassurance she has not earned.
    private func sitAck(_ word: String) -> String {
        switch word {
        case "heavy": return "noted. staying upright a while tends to help"
        case "queasy": return "noted. cold and plain sits easier than warm and rich"
        case "backed up": return "noted. water tonight. fiber and a walk tomorrow"
        default: return "noted"
        }
    }

    /// "2 of 2 done" when the day closed clean; the count either
    /// way. v7: the denominator is TODAY'S CARE PLAN (lead +
    /// supporting) — offered rows and observations never read as
    /// debt, and a gentle day's receipt matches its smaller plan.
    private var planReceipt: String {
        let done = snapshot.completedBeatCount
        let total = snapshot.carePlan.actionableBeats.count
        guard total > 0 else { return "\(done) done" }
        return done >= total ? "\(done) of \(total) done" : "\(done) of \(total) done"
    }

    /// The grams still open tonight, or nil when there is nothing
    /// honest to act on: no floor on file (E7's law), the floor already
    /// met, numerics suppressed, or the adequacy net already owning the
    /// very-light day with its own gentler line.
    private var proteinGapTonight: Int? {
        guard !snapshot.targets.numericsSuppressed, !showsEnoughNet,
              let floor = snapshot.targets.proteinG, floor > 0
        else { return nil }
        let gap = floor - snapshot.proteinEatenG
        return gap > 0 ? gap : nil
    }

    private func proteinWord(target: Int) -> String {
        let g = snapshot.proteinEatenG
        if g >= target { return "\(g) of \(target)g · hit" }
        return "\(g) of \(target)g"
    }

    /// Whether tomorrow carries a weigh-in (same cadence math the
    /// composer uses; stale-fallback weigh-ins don't pre-frame — the
    /// eve line is for scheduled scale mornings only).
    private var tomorrowIsWeighDay: Bool {
        let context = PrescriptionEngineV2.Context.live(
            lastWeighInDaysAgo: snapshot.lastWeighInDaysAgo,
            lastSnapDaysAgo: nil
        )
        return PrescriptionEngineV2.weighInSlots(context: context)
            .contains(PrescriptionEngineV2.dayInWeek(snapshot.programDay + 1))
    }

    private var tomorrowArchetype: ProgramDayArchetype {
        ProgramDayArchetype.archetype(
            forProgramDay: snapshot.programDay + 1,
            glp1Status: CohortStore.glp1StatusKey,
            restrictiveFoodRelationship: CohortStore.isRestrictiveRisk
        )
    }

    private var tomorrowWhisper: String {
        switch tomorrowArchetype {
        case .protein: return "a protein day"
        case .movement: return "a movement day"
        case .balanced: return "a balanced day"
        case .rest: return "a rest day"
        }
    }
}

// MARK: - HomeEveningMoment
//
// The close, given the room it always wanted. Founder steer
// (2026-08-06): Home must never be taken over by a headline — the
// day's declarations belong on a full screen, typed sentence by
// sentence the way the consult speaks. Home keeps its anatomy
// (nutrition · what's left · tools) and this arrives over it.
//
// The receipt, the feeling, the dose marks and every write inside
// EveningClose are unchanged — only the room changed.

struct HomeEveningMoment: View {
    let snapshot: TodaySnapshot
    let onReflect: (String) -> Void
    let onDismiss: () -> Void

    @AppStorage("userName") private var userName: String = ""

    /// Mirrors `EveningClose.showsEnoughNet` — the moment's typed line
    /// must not count grams at a person the care net is about to speak
    /// to gently. Same predicate, same source of truth.
    /// E8.1 — one derivation, on the snapshot, because the Method needs
    /// the same answer and two copies would drift.
    private var adequacyNetShowing: Bool { snapshot.showsAdequacyNet }

    private var tomorrowWhisper: String {
        switch ProgramDayArchetype.archetype(
            forProgramDay: snapshot.programDay + 1,
            glp1Status: CohortStore.glp1StatusKey,
            restrictiveFoodRelationship: CohortStore.isRestrictiveRisk
        ) {
        case .protein: return "a protein day"
        case .movement: return "a movement day"
        case .balanced: return "a balanced day"
        case .rest: return "a rest day"
        }
    }

    /// v25 E8 (founder steer) — "that's the day, maya." / "tomorrow: a
    /// balanced day." told her nothing. Both sentences now come from
    /// `EveningCloseEngine`: the first is her actual record, the second
    /// carries tomorrow's REASON rather than its label. Every honesty
    /// rule (protein leads, no denominator without a floor, never "0 g",
    /// no verdict, suppression) lives in the engine and is tested there.
    private var closeLines: EveningCloseEngine.Close {
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
                tomorrow: ProgramDayArchetype.archetype(
                    forProgramDay: snapshot.programDay + 1,
                    glp1Status: CohortStore.glp1StatusKey,
                    restrictiveFoodRelationship: CohortStore.isRestrictiveRisk
                )
            )
        )
    }

    private var lines: [V8Line] {
        [
            V8Line(closeLines.today.text, italic: closeLines.today.punch),
            V8Line(closeLines.tomorrow.text, italic: closeLines.tomorrow.punch),
        ]
    }

    var body: some View {
        JeniMoment(
            eyebrow: "closing the day",
            // R6 — the day number stands as the fact of progress,
            // massive, counted in (docs/app_v12 §2.4).
            heroValue: snapshot.isEnrolled ? Double(max(1, snapshot.programDay)) : nil,
            heroWord: snapshot.isEnrolled ? "of \(snapshot.totalDays) days" : nil,
            lines: lines,
            cta: "goodnight",
            onDismiss: onDismiss
        ) {
            EveningClose(
                snapshot: snapshot,
                onReflect: onReflect,
                showsHeadline: false,
                showsTomorrowRow: false,
                // the typed line above already said the protein
                showsProteinRow: !closeLines.today.text.contains("protein")
            )
        }
    }
}

// MARK: - EveningJournalLine
//
// v4 order fix (docs/app_v4/03_FEATURES.md §9): the one-line journal
// closes the evening AFTER the still-open rows — the receipt reads,
// the rows stay reachable, the page ends on her words. Extracted
// from EveningClose so TodayView owns the order.

struct EveningJournalLine: View {
    let snapshot: TodaySnapshot

    @Environment(\.modelContext) private var modelContext
    @State private var noteDraft: String = ""
    @State private var savedNote: String =
        UserDefaults.standard.string(
            forKey: "day.note.\(TodayStateService.dayKey())"
        ) ?? ""
    @FocusState private var isWriting: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(reflectionPrompt)
                .font(.custom("JeniHeroSerif-Italic", size: 17, relativeTo: .body))
                .foregroundStyle(Palette.cocoaSecondary)
            if savedNote.isEmpty {
                // Mission 3 (03_EDITORIAL.md §3): the boxed field is
                // dead — the rule IS the field. She writes on a bare
                // hairline; the rule inks rose while she writes; a
                // bare seal saves. Her line commits in her ink.
                VStack(spacing: 7) {
                    HStack(spacing: 12) {
                        TextField("one line, if you want", text: $noteDraft)
                            .font(.custom("JeniHeroSerif-Regular", size: 17, relativeTo: .body))
                            .foregroundStyle(Palette.textPrimary)
                            .textFieldStyle(.plain)
                            .focused($isWriting)
                            .onSubmit { saveNote() }
                        if !noteDraft.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button {
                                saveNote()
                            } label: {
                                Image(systemName: "sparkle")
                                    .symbolVariant(.fill)
                                    .font(.system(size: 16))
                                    .foregroundStyle(Palette.jeweledRose)
                            }
                            .buttonStyle(JKPress())
                            .accessibilityLabel("save your line")
                            .transition(.opacity)
                        }
                    }
                    Rectangle()
                        .fill(isWriting ? Palette.jeweledRose : Palette.hairlineCocoa)
                        .frame(height: isWriting ? 1 : 0.5)
                        .animation(Motion.entranceSoft, value: isWriting)
                }
                .animation(Motion.entranceSoft, value: noteDraft.isEmpty)
            } else {
                Text("\u{201C}\(savedNote)\u{201D}")
                    .font(.custom("JeniHeroSerif-Italic", size: 17, relativeTo: .body))
                    .foregroundStyle(Palette.jeweledRose)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
    }

    private func saveNote() {
        let text = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let dayKey = TodayStateService.dayKey()
        UserDefaults.standard.set(text, forKey: "day.note.\(dayKey)")
        // v8 — her line joins the chart (typed, survives sign-out
        // under her userId; the legacy key stays dual-written).
        ObservationStore.record(
            .journalNote, valueText: text, dayKey: dayKey,
            userId: snapshot.plan?.userId ?? "", in: modelContext
        )
        withAnimation(Motion.entranceSoft) { savedNote = text }
        Haptics.soft()
        // v2.6 — jeni's memory seam: local-first, cloud when the
        // migration lands (fire-and-forget, silent until then).
        let feeling = UserDefaults.standard.string(forKey: "day.reflection.\(dayKey)") ?? "noted"
        Task {
            await AppSync.shared.upsertDayReflection(
                userId: snapshot.plan?.userId ?? "",
                dayKey: dayKey, feeling: feeling, note: text
            )
        }
    }

    /// Archetype-aware guided prompt — reflection with a direction,
    /// never homework.
    private var reflectionPrompt: String {
        switch snapshot.day?.archetype {
        case .protein: return "best plate today?"
        case .movement: return "what did moving change?"
        case .rest: return "did the rest help?"
        default: return "anything to remember about today?"
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
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
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
