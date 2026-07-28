import SwiftUI
import PlankFood
import PlankSync

// MARK: - TodayStateBand — TODAY'S PLATES
//
// App v4 (docs/app_v4/03_FEATURES.md §1), v5 language pass: the
// module speaks plainly. One food module, one grammar: the plates
// lead (the photos ARE the story), the protein arc is the single
// gauge, and the kcal sentence answers the founder's question out
// loud: "room for about 600." Suppressed cohorts keep
// protein-as-care and lose every calorie numeral.

struct TodayStateBand: View {
    let snapshot: TodaySnapshot
    /// v6 — THE LANDED moment: bumps when a plate just persisted via
    /// the capture cover. The band answers with a silk sweep, a
    /// serif receipt line, and a completion swell — the celebration
    /// the flow never had. Inline, ephemeral, never a popup.
    var landedPulse: Int = 0

    @State private var showsLanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // v1.1.5 — the plate thumbnails moved to becoming's plates page;
        // Home keeps the calorie glance (the v5 "calories stay on Home"
        // steer). v6: the overnight moon line grew into its own signals
        // band (TodaySignalsBand) — this module is food-today only.
        // Collapses to nothing on a foodless morning so the rhythm rows
        // aren't trailed by an orphaned header.
        let showKcal = !snapshot.targets.numericsSuppressed && snapshot.kcalEaten > 0

        if showKcal || snapshot.targets.numericsSuppressed {
            // v7.2 (founder: "100x more minimal"): the tracked-caps
            // section seam died — the numbers stand alone as a quiet
            // receipt column, no dashboard chrome.
            VStack(alignment: .leading, spacing: Space.md) {
                VStack(alignment: .leading, spacing: 7) {
                    // THE LANDED line — rises when a plate just
                    // persisted, breathes for a few seconds, leaves
                    // the numbers to carry on.
                    if showsLanded {
                        // v7 a11y floor: 16pt rose fails AA at
                        // Palette.accent (3.53:1); jeweledRose is the
                        // same family at 8.59:1.
                        Text("that plate landed \u{2665}\u{FE0E}")
                            .font(.custom("JeniHeroSerif-Italic", size: 16, relativeTo: .body))
                            .foregroundStyle(Palette.jeweledRose)
                            .transition(.opacity.combined(with: .offset(y: 5)))
                            .padding(.bottom, 2)
                    }

                    if showKcal {
                        // Founder 2026-07-27: the word-ledger read as
                        // boring — the foot is now THE METRIC STRIP,
                        // her progress as quiet rings (fill = done,
                        // never overflow-shamed; caps at full).
                        JKMetricStrip(snapshot: snapshot)
                    } else if snapshot.targets.numericsSuppressed {
                        JKMetricStrip(snapshot: snapshot)
                        Text("protein first today \u{2665}\u{FE0E}")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, Space.lg)
            }
            .jkSilkSweep(trigger: landedPulse)
            .onChange(of: landedPulse) { _, pulse in
                guard pulse > 0 else { return }
                ActivationHaptics.shared.arcComplete()
                if reduceMotion {
                    showsLanded = true
                } else {
                    withAnimation(Motion.gentleSpring) { showsLanded = true }
                }
                Task {
                    try? await Task.sleep(for: .seconds(3.4))
                    withAnimation(Motion.exit) { showsLanded = false }
                }
            }
        }
    }

}

// MARK: - JKMetricStrip
//
// Founder 2026-07-27: "we need visualizations of metrics like
// charts… cut the unnecessary stuff." Her day as four quiet rings —
// calories, protein, steps (tappable → detail), resting heart. Ring
// law: fill is her own progress against her own target, rounded
// caps, jeweledRose on a hairline track; over-target caps at full
// (the anti-shame floor — no red, no overflow). Resting heart wears
// a plain frame, never a ring (no target exists — observed only).

struct JKMetricStrip: View {
    let snapshot: TodaySnapshot

    @State private var vitals = VitalsService.shared
    @State private var showStepsSheet = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if !snapshot.targets.numericsSuppressed, let kcalTarget = snapshot.targets.kcal {
                ringTile(
                    fraction: min(1, Double(snapshot.kcalEaten) / Double(max(kcalTarget, 1))),
                    number: "\(snapshot.kcalEaten)",
                    label: "calories"
                )
            }
            if let target = snapshot.targets.proteinG {
                ringTile(
                    fraction: min(1, Double(snapshot.proteinEatenG) / Double(max(target, 1))),
                    number: "\(snapshot.proteinEatenG)g",
                    label: "protein"
                )
            }
            Button {
                Haptics.soft()
                showStepsSheet = true
            } label: {
                ringTile(
                    fraction: min(1, Double(snapshot.steps) / Double(max(snapshot.targets.steps, 1))),
                    number: stepsWord(snapshot.steps),
                    label: "steps"
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(JKPress())
            .accessibilityLabel("\(snapshot.steps.formatted()) steps")
            .accessibilityHint("opens the detail")
            .sheet(isPresented: $showStepsSheet) {
                TodayStepsSheet(goal: snapshot.targets.steps)
                    .presentationDetents([.fraction(0.7), .large])
            }
            if let heart = restingHeart {
                heartTile(heart)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var restingHeart: (number: Int, word: String?)? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitest-force-signals") {
            return (62, "steady")
        }
        #endif
        guard let current = vitals.read.restingHR7d else { return nil }
        let word = vitals.read.restingHRBaseline.flatMap { base -> String? in
            base > 0 ? VitalsTrend.word(current: current, baseline: base) : nil
        }
        return (current, word)
    }

    private func stepsWord(_ count: Int) -> String {
        count >= 1000
            ? String(format: "%.1fk", Double(count) / 1000)
            : "\(count)"
    }

    @ViewBuilder
    private func ringTile(fraction: Double, number: String, label: String) -> some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .stroke(Palette.cocoaPrimary.opacity(0.1), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: max(0.02, fraction))
                    .stroke(
                        Palette.jeweledRose,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text(number)
                    .font(.custom("JeniHeroSerif-Regular", size: 15, relativeTo: .footnote))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 6)
            }
            .frame(width: 56, height: 56)
            Text(label)
                .font(Typo.statLabel)
                .kerning(0.66)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(number)")
    }

    @ViewBuilder
    private func heartTile(_ heart: (number: Int, word: String?)) -> some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .stroke(Palette.cocoaPrimary.opacity(0.1), lineWidth: 3)
                Text("\(heart.number)")
                    .font(.custom("JeniHeroSerif-Regular", size: 15, relativeTo: .footnote))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary)
            }
            .frame(width: 56, height: 56)
            Text(heart.word.map { "heart · \($0)" } ?? "heart")
                .font(Typo.statLabel)
                .kerning(0.66)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("resting heart, \(heart.number)\(heart.word.map { ", \($0)" } ?? "")")
    }
}

// MARK: - FootLedgerRow
//
// Mission 3 (03_EDITORIAL.md §1.6) — THE LEDGER grammar: caps label
// left, serif value right, a hairline beneath. One grammar for every
// number the day carries (Home's foot, the closing receipt) so the
// foot always reads as ONE ledger.

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

// MARK: - EveningClose
//
// After 18:00 the day gets a closing beat: the receipt (only rows
// with real data), a one-tap feeling, and the tomorrow whisper.
// Skippable forever; never a guilt state.

struct EveningClose: View {
    let snapshot: TodaySnapshot
    let onReflect: (String) -> Void

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
                    "did you eat enough? a gentle plate still counts \u{2665}\u{FE0E}",
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
                FootLedgerRow(label: "tomorrow", value: tomorrowWhisper)
            }
            .padding(.top, Space.md)

            // v7 phase 3 — the weigh-eve pre-frame: anticipation is
            // the coach's highest-value move. Spoken the night BEFORE
            // a scale morning, so tomorrow's number is already framed
            // as data, not verdict.
            if tomorrowIsWeighDay, !snapshot.targets.numericsSuppressed {
                Text("the scale tomorrow reads the week, not tonight \u{2665}\u{FE0E}")
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("how did today sit?")
                        .font(.custom("JeniHeroSerif-Italic", size: 15, relativeTo: .subheadline))
                        .foregroundStyle(Palette.cocoaSecondary)
                    HStack(spacing: 22) {
                        sitWord("fine")
                        sitWord("heavy")
                        sitWord("queasy")
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
                    Text("\(plan.plan) \u{2665}\u{FE0E}")
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
    }

    @State private var plannedKey: String? =
        TonightPlan.planned(dayKey: TodayStateService.dayKey())?.key

    /// A tonight-plan option as a hairline menu line — the rule is
    /// the row's only chrome.
    private func planLine(_ option: TonightPlan.Option) -> some View {
        Button {
            Haptics.soft()
            TonightPlan.set(option.key, dayKey: TodayStateService.dayKey())
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
            withAnimation(Motion.entranceSoft) { doseAnswer = word }
            UserDefaults.standard.set(
                word, forKey: "day.dose.\(TodayStateService.dayKey())"
            )
            Haptics.soft()
        } label: {
            Text(word)
                .font(.custom("JeniHeroSerif-Regular", size: 21, relativeTo: .title3))
                .foregroundStyle(wordInk(word, picked: doseAnswer))
        }
        .buttonStyle(JKPress())
        .accessibilityLabel("medication day, \(word)")
        .accessibilityAddTraits(doseAnswer == word ? [.isButton, .isSelected] : .isButton)
    }

    private func sitWord(_ word: String) -> some View {
        Button {
            withAnimation(Motion.entranceSoft) { pickedSit = word }
            UserDefaults.standard.set(
                word, forKey: "day.sit.\(TodayStateService.dayKey())"
            )
            Haptics.soft()
        } label: {
            Text(word)
                .font(.custom("JeniHeroSerif-Regular", size: 21, relativeTo: .title3))
                .foregroundStyle(wordInk(word, picked: pickedSit))
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

    private func sitAck(_ word: String) -> String {
        switch word {
        case "heavy": return "noted. smaller plates tomorrow \u{2665}\u{FE0E}"
        case "queasy": return "noted. mild plates + fluids tomorrow \u{2665}\u{FE0E}"
        default: return "good. noted \u{2665}\u{FE0E}"
        }
    }

    /// "2 of 2 done ♥" when the day closed clean; the count either
    /// way. v7: the denominator is TODAY'S CARE PLAN (lead +
    /// supporting) — offered rows and observations never read as
    /// debt, and a gentle day's receipt matches its smaller plan.
    private var planReceipt: String {
        let done = snapshot.completedBeatCount
        let total = snapshot.carePlan.actionableBeats.count
        guard total > 0 else { return "\(done) done" }
        return done >= total ? "\(done) of \(total) done \u{2665}\u{FE0E}" : "\(done) of \(total) done"
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
        case .rest: return "a rest day \u{2665}\u{FE0E}"
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
