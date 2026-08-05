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
                if !showsEnoughNet, snapshot.proteinEatenG > 0,
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
                FootLedgerRow(label: "tomorrow", value: tomorrowWhisper)
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

            // The feeling — three bare serif words; the chosen word
            // inks rose (capsules dead; the word IS the button, the
            // ink IS the record). Re-tappable: an evening may change
            // its mind.
            VStack(alignment: .leading, spacing: 10) {
                Text("how did today feel?")
                    .font(.custom("JeniHeroSerif-Italic", size: 17, relativeTo: .body))
                    .foregroundStyle(Palette.cocoaSecondary)
                HStack(spacing: 26) {
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
            if snapshot.chapter == .onMedication {
                VStack(alignment: .leading, spacing: 8) {
                    Text("medication day?")
                        .font(.custom("JeniHeroSerif-Italic", size: 15, relativeTo: .subheadline))
                        .foregroundStyle(Palette.cocoaSecondary)
                    HStack(spacing: 22) {
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
                        HStack(spacing: 16) {
                            shotWord("mon", 1); shotWord("tue", 2)
                            shotWord("wed", 3); shotWord("thu", 4)
                        }
                        HStack(spacing: 16) {
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
                        HStack(spacing: 18) {
                            sitWord("fine")
                            sitWord("heavy")
                            sitWord("queasy")
                            sitWord("backed up")
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 18) {
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

    /// A feeling as a bare serif word. Unpicked evenings hold all
    /// three at full ink; the pick inks rose and the others recede.
    private func feelingWord(_ word: String) -> some View {
        Button {
            withAnimation(Motion.entranceSoft) { pickedFeeling = word }
            onReflect(word)
        } label: {
            Text(word)
                .font(.custom("JeniHeroSerif-Regular", size: 28, relativeTo: .title2))
                .foregroundStyle(wordInk(word, picked: pickedFeeling))
        }
        .buttonStyle(JKPress())
        .accessibilityAddTraits(pickedFeeling == word ? [.isButton, .isSelected] : .isButton)
    }

    private func doseWord(_ word: String) -> some View {
        Button {
            let key = TodayStateService.dayKey()
            withAnimation(Motion.entranceSoft) { doseAnswer = word }
            UserDefaults.standard.set(word, forKey: "day.dose.\(key)")
            // v8 — the chart + the checklist agree: a "yes" marks
            // the day's medication row kept (when today composed
            // one), and the answer lands as a typed observation.
            ObservationStore.record(
                .doseTaken, valueText: word,
                payload: ObservationStore.regimenPayload(
                    RegimenService.activeMedicationPlanId(userId: obsUserId, in: modelContext)
                ),
                dayKey: key,
                userId: obsUserId, in: modelContext
            )
            if word == "yes" {
                if snapshot.carePlan.actionableBeats.contains(where: {
                    if case .medication = $0 { return true } else { return false }
                }) {
                    _ = ProgramService.shared.markChecklistItem(
                        prescription: .medication, state: .complete,
                        userId: obsUserId, in: modelContext
                    )
                }
                if RegimenService.activeMedicationPlan(
                    userId: obsUserId, in: modelContext
                ) == nil {
                    withAnimation(Motion.entranceSoft) { shotDayAskVisible = true }
                }
            } else {
                withAnimation(Motion.entranceSoft) { shotDayAskVisible = false }
            }
            Haptics.soft()
        } label: {
            Text(word)
                .font(.custom("JeniHeroSerif-Regular", size: 21, relativeTo: .title3))
                .foregroundStyle(clinicalInk(word, picked: doseAnswer))
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
                .font(.custom("JeniHeroSerif-Regular", size: 19, relativeTo: .title3))
                .foregroundStyle(Palette.textPrimary)
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
                .font(.custom("JeniHeroSerif-Regular", size: 19, relativeTo: .title3))
                .foregroundStyle(clinicalInk(word, picked: pickedSit))
                .lineLimit(1)
                .fixedSize()
        }
        .buttonStyle(JKPress())
        .accessibilityAddTraits(pickedSit == word ? [.isButton, .isSelected] : .isButton)
    }

    private func wordInk(_ word: String, picked: String?) -> Color {
        guard let picked else { return Palette.textPrimary }
        return picked == word
            ? Palette.jeweledRose
            : Palette.textPrimary.opacity(0.3)
    }

    /// Founder refinement 2026-07-28: rose never appears on a
    /// medication surface. The dose + sit answers select by
    /// CONTRAST (full ink vs receded), not by accent color —
    /// clinical register, same bones.
    private func clinicalInk(_ word: String, picked: String?) -> Color {
        guard let picked else { return Palette.textPrimary }
        return picked == word
            ? Palette.textPrimary
            : Palette.textPrimary.opacity(0.3)
    }

    /// Clinical register (founder refinement): the symptom stream
    /// acknowledges as fact — no hearts, no reward vocabulary.
    private func sitAck(_ word: String) -> String {
        switch word {
        case "heavy": return "noted. smaller plates tomorrow"
        case "queasy": return "noted. mild plates + fluids tomorrow"
        case "backed up": return "noted. fluids, fiber, a walk tomorrow"
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
