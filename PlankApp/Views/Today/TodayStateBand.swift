import SwiftUI
import Auth
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

    var body: some View {
        // v1.1.5 — the plate thumbnails moved to becoming's plates page;
        // Home keeps the calorie glance (the v5 "calories stay on Home"
        // steer) plus the zero-input overnight line. Collapses to nothing
        // on a foodless morning so the rhythm rows aren't trailed by an
        // orphaned header.
        let showKcal = !snapshot.targets.numericsSuppressed && snapshot.kcalEaten > 0
        let quietHours = QuietHours.liveOvernight(
            userId: AuthService.shared.currentUser?.id.uuidString ?? ""
        )
        let hasQuiet = (quietHours ?? 0) >= 11

        if showKcal || snapshot.targets.numericsSuppressed || hasQuiet {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("today's food")
                    .font(Typo.captionTracked)
                    .kerning(1.98)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .padding(.horizontal, Space.lg)

                VStack(alignment: .leading, spacing: 7) {
                    if showKcal {
                        // Fulfillment at a GLANCE — the bar answers "how
                        // much of my day have I used?" before the words do.
                        if let kcalTarget = snapshot.targets.kcal {
                            JKKcalBar(kcal: snapshot.kcalEaten, target: kcalTarget)
                                .padding(.top, 2)
                        } else {
                            JKKcalLine(kcal: snapshot.kcalEaten, target: snapshot.targets.kcal)
                        }
                        if let target = snapshot.targets.proteinG {
                            Text("protein \(snapshot.proteinEatenG) of \(target)g")
                                .font(Typo.caption)
                                .monospacedDigit()
                                .foregroundStyle(Palette.textSecondary)
                        }
                    } else if snapshot.targets.numericsSuppressed {
                        Text("protein is what matters today \u{2665}\u{FE0E}")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // THE QUIET HOURS — zero-input insight, kept.
                    if let hours = quietHours, hours >= 11 {
                        HStack(spacing: 7) {
                            JKMark(kind: .moon, size: 12,
                                   color: Palette.cocoaSecondary.opacity(0.8))
                            Text(QuietHours.overnightLine(hours: hours))
                                .font(Typo.caption)
                                .foregroundStyle(Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, Space.lg)
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
            Text("closing the day")
                .font(Typo.captionTracked)
                .kerning(1.98)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)

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
                    // Standing grammar, not arithmetic — the same
                    // vocabulary as the strip dots and the day review.
                    JKReceiptRow(
                        lead: "the plan",
                        punch: DayStanding.from(completedCount: snapshot.completedBeatCount) == .kept
                            ? "kept \u{2665}\u{FE0E}"
                            : "some of it landed",
                        punchItalic: [DayStanding.from(completedCount: snapshot.completedBeatCount) == .kept ? "kept" : "landed"],
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
                    Text("tonight, if the kitchen calls…")
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
        case "heavy": return "noted. tomorrow's plates will run gentler \u{2665}\u{FE0E}"
        case "queasy": return "noted. mild and slow tomorrow, fluids first \u{2665}\u{FE0E}"
        default: return "good. noted \u{2665}\u{FE0E}"
        }
    }

    private func proteinWord(target: Int) -> String {
        let g = snapshot.proteinEatenG
        if g >= target { return "\(g)g · landed" }
        if g >= Int(Double(target) * 0.7) { return "\(g)g · close" }
        return "\(g)g today"
    }

    private func proteinPunchWord(target: Int) -> String {
        let g = snapshot.proteinEatenG
        if g >= target { return "landed" }
        if g >= Int(Double(target) * 0.7) { return "close" }
        return "today"
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
                Text("\u{201C}\(savedNote)\u{201D} · kept in her file")
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
        case .protein: return "what did a strong plate look like today?"
        case .movement: return "what felt possible once you started?"
        case .rest: return "what did the rest give back?"
        default: return "what should tomorrow-you remember about today?"
        }
    }
}
