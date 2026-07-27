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
                        // v7 (docs/app_v7 §1): the numbers stay — the
                        // budget BAR dies. A bar counting down to
                        // "left" is tracker grammar; the sentence
                        // speaks the same facts as a receipt.
                        JKKcalLine(kcal: snapshot.kcalEaten, target: snapshot.targets.kcal)
                            .padding(.top, 2)
                        if let target = snapshot.targets.proteinG {
                            let plates = snapshot.plates.count
                            Text(
                                plates > 0
                                    ? "protein \(snapshot.proteinEatenG) of \(target)g · \(plates) plate\(plates == 1 ? "" : "s")"
                                    : "protein \(snapshot.proteinEatenG) of \(target)g"
                            )
                            .font(Typo.caption)
                            .monospacedDigit()
                            .foregroundStyle(Palette.textSecondary)
                        }
                    } else if snapshot.targets.numericsSuppressed {
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
        VStack(alignment: .leading, spacing: Space.md) {
            JKSectionSeam(title: "closing the day")

            VStack(spacing: 0) {
                if showsEnoughNet {
                    JKReceiptRow(
                        lead: "tonight",
                        punch: "did you eat enough? a gentle plate still counts",
                        punchItalic: ["enough"],
                        showsRule: false
                    )
                } else if snapshot.proteinEatenG > 0, let target = snapshot.targets.proteinG {
                    JKReceiptRow(
                        lead: "protein",
                        punch: proteinWord(target: target),
                        punchItalic: [proteinPunchWord(target: target)],
                        showsRule: false
                    )
                }
                if snapshot.completedBeatCount > 0 {
                    // v6: arithmetic, not standing grammar — "3 of 4
                    // done" answers the question the row is asking.
                    JKReceiptRow(
                        lead: "the plan",
                        punch: planReceipt,
                        punchItalic: planReceipt.hasSuffix("\u{2665}\u{FE0E}") ? ["done"] : [],
                        showsRule: snapshot.proteinEatenG > 0 || showsEnoughNet
                    )
                }
                JKReceiptRow(
                    lead: "tomorrow",
                    punch: tomorrowWhisper,
                    punchItalic: [tomorrowItalic],
                    showsRule: snapshot.completedBeatCount > 0 || snapshot.proteinEatenG > 0
                )
            }

            if pickedFeeling == nil {
                VStack(alignment: .leading, spacing: 8) {
                    // v5: the chips answer a visible question — three
                    // bare words floated context-free before.
                    Text("how did today feel?")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                    HStack(spacing: 10) {
                        feelingChip("proud")
                        feelingChip("okay")
                        feelingChip("tender")
                    }
                }
                .padding(.top, Space.xs)
            } else if let pickedFeeling {
                Text("you felt \(pickedFeeling) today. noted \u{2665}\u{FE0E}")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, Space.xs)
                    .transition(.opacity)
            }

            // v3 on-medication: the optional sit-check. Skipped
            // forever = fine; answered = tomorrow's plates speak to it.
            if snapshot.chapter == .onMedication {
                if pickedSit == nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("how did today sit?")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                        HStack(spacing: 10) {
                            sitChip("fine")
                            sitChip("heavy")
                            sitChip("queasy")
                        }
                    }
                    .padding(.top, Space.xs)
                } else if let pickedSit {
                    Text(sitAck(pickedSit))
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.top, Space.xs)
                        .transition(.opacity)
                }
            }

            // v4 — THE TONIGHT PLAN (docs/app_v4/03_FEATURES.md §5):
            // a 15-second if-then for the evening's one predictable
            // moment. Menu-picked plans carry the evidence; tomorrow's
            // reading names it back. Skipped forever = fine.
            if let plannedKey {
                if let plan = TonightPlan.option(for: plannedKey) {
                    Text("\(plan.plan) \u{2665}\u{FE0E}")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14, relativeTo: .footnote))
                        .foregroundStyle(Palette.cocoaSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.sm)
                        .transition(.opacity)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("tonight's plan, if cravings hit:")
                        .font(.custom("JeniHeroSerif-Italic", size: 16, relativeTo: .body))
                        .foregroundStyle(Palette.cocoaSecondary)
                    HStack(spacing: 8) {
                        planChip(TonightPlan.options[0])
                        planChip(TonightPlan.options[1])
                    }
                    HStack(spacing: 8) {
                        planChip(TonightPlan.options[2])
                        planChip(TonightPlan.options[3])
                    }
                }
                .padding(.top, Space.md)
            }

        }
    }

    @State private var plannedKey: String? =
        TonightPlan.planned(dayKey: TodayStateService.dayKey())?.key

    private func planChip(_ option: TonightPlan.Option) -> some View {
        Button {
            Haptics.soft()
            TonightPlan.set(option.key, dayKey: TodayStateService.dayKey())
            withAnimation(Motion.entranceSoft) { plannedKey = option.key }
        } label: {
            Text(option.label)
                .font(.custom("DMSans-Medium", size: 13, relativeTo: .footnote))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .overlay(
                    Capsule().strokeBorder(Palette.cocoaPrimary.opacity(0.22), lineWidth: 1)
                )
        }
        .buttonStyle(JKPress())
    }

    private func feelingChip(_ word: String) -> some View {
        Button {
            withAnimation(Motion.entranceSoft) { pickedFeeling = word }
            onReflect(word)
        } label: {
            Text(word)
                .font(.custom("DMSans-Medium", size: 14))
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .overlay(
                    Capsule().strokeBorder(Palette.cocoaPrimary.opacity(0.22), lineWidth: 1)
                )
        }
        .buttonStyle(JKPress())
    }

    private func sitChip(_ word: String) -> some View {
        Button {
            withAnimation(Motion.entranceSoft) { pickedSit = word }
            UserDefaults.standard.set(
                word, forKey: "day.sit.\(TodayStateService.dayKey())"
            )
            Haptics.soft()
        } label: {
            Text(word)
                .font(.custom("DMSans-Medium", size: 14))
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .overlay(
                    Capsule().strokeBorder(Palette.cocoaPrimary.opacity(0.22), lineWidth: 1)
                )
        }
        .buttonStyle(JKPress())
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

    private func proteinPunchWord(target: Int) -> String {
        snapshot.proteinEatenG >= target ? "hit" : "\(snapshot.proteinEatenG)"
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
        case .rest: return "a rest day. nothing heavy \u{2665}\u{FE0E}"
        }
    }

    private var tomorrowItalic: String {
        switch tomorrowArchetype {
        case .protein: return "protein"
        case .movement: return "movement"
        case .balanced: return "balanced"
        case .rest: return "rest"
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(reflectionPrompt)
                .font(.custom("JeniHeroSerif-Italic", size: 16))
                .foregroundStyle(Palette.cocoaSecondary)
            if savedNote.isEmpty {
                HStack(spacing: 10) {
                    TextField("one line, if you want", text: $noteDraft)
                        .font(.custom("DMSans-Regular", size: 14))
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Palette.bgElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Palette.hairlineCocoa, lineWidth: 0.66)
                        )
                        .onSubmit { saveNote() }
                    if !noteDraft.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button {
                            saveNote()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Palette.textInverse)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Palette.cocoaPrimary))
                        }
                        .buttonStyle(JKPress())
                    }
                }
            } else {
                Text("\u{201C}\(savedNote)\u{201D} · saved")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
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
