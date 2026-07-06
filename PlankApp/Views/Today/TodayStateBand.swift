import SwiftUI
import Auth
import PlankFood
import PlankSync

// MARK: - TodayStateBand
//
// "today so far" — the living state module: protein arc (the hero),
// steps ring, the kcal sentence, and the plates filmstrip. One
// module, not three tiles reading the same value (the Becoming
// density lesson). Numeric-suppressed cohorts get protein + steps
// only — protein is care, calories are the thing being suppressed.

struct TodayStateBand: View {
    let snapshot: TodaySnapshot
    let liveSteps: Int
    let onSnap: () -> Void
    var onTapPlate: (JKPlateStripItem) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("today so far")
                .font(Typo.captionTracked)
                .kerning(1.98)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.horizontal, Space.lg)

            HStack(alignment: .top, spacing: 0) {
                Spacer(minLength: 0)
                if let proteinTarget = snapshot.targets.proteinG {
                    JKProteinArc(
                        grams: snapshot.proteinEatenG,
                        targetG: proteinTarget,
                        note: snapshot.targets.proteinNote
                    )
                }
                Spacer(minLength: 0)
                JKStepsRing(
                    steps: liveSteps,
                    goal: snapshot.targets.steps,
                    diameter: 84
                )
                Spacer(minLength: 0)
            }
            .padding(.top, Space.xs)

            if !snapshot.targets.numericsSuppressed, snapshot.kcalEaten > 0 {
                JKKcalLine(kcal: snapshot.kcalEaten, target: snapshot.targets.kcal)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, Space.sm)
            }

            // THE QUIET HOURS — insight with zero input: her plates'
            // timestamps already know the overnight rhythm. Purely
            // observational; hard-gated off for restriction-risk +
            // suppressed identities (QuietHours.mayNarrate).
            if let hours = QuietHours.liveOvernight(
                userId: AuthService.shared.currentUser?.id.uuidString ?? ""
            ), hours >= 11 {
                HStack(spacing: 8) {
                    JKMark(kind: .moon, size: 13,
                           color: Palette.cocoaSecondary.opacity(0.8))
                    Text(QuietHours.overnightLine(hours: hours))
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 6)
            }

            if snapshot.plates.isEmpty {
                JKEmptyState(
                    line: "your first plate starts the day's story",
                    italic: ["story"],
                    actionLabel: "snap it",
                    action: onSnap
                )
                .padding(.vertical, -Space.md)
            } else {
                JKPlateStrip(
                    items: plateItems,
                    onAdd: onSnap,
                    onTapItem: onTapPlate
                )
                .padding(.top, Space.sm)
            }
        }
    }

    private var plateItems: [JKPlateStripItem] {
        snapshot.plates.map { entry in
            JKPlateStripItem(
                id: entry.id,
                time: entry.loggedAt.formatted(date: .omitted, time: .shortened).lowercased(),
                title: entry.title.isEmpty ? "a plate" : entry.title,
                image: FoodPhotoStore.photo(entryId: entry.id),
                kcal: Int(entry.kcal.rounded())
            )
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
                HStack(spacing: 10) {
                    feelingChip("proud")
                    feelingChip("okay")
                    feelingChip("tender")
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

            // v2.5 — one line for her file (Journal v1). A guided,
            // archetype-aware prompt; one optional line, never an
            // essay. Device-local by dayKey; joins the cloud
            // day_reflections table with the sync batch.
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
            .padding(.top, Space.md)
        }
    }

    @State private var noteDraft: String = ""
    @State private var savedNote: String =
        UserDefaults.standard.string(
            forKey: "day.note.\(TodayStateService.dayKey())"
        ) ?? ""

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
