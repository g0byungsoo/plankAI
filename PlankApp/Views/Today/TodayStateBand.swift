import SwiftUI
import PlankFood

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

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("closing the day")
                .font(Typo.captionTracked)
                .kerning(1.98)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)

            VStack(spacing: 0) {
                if snapshot.proteinEatenG > 0, let target = snapshot.targets.proteinG {
                    JKReceiptRow(
                        lead: "protein",
                        punch: proteinWord(target: target),
                        punchItalic: [proteinPunchWord(target: target)],
                        showsRule: false
                    )
                }
                if snapshot.completedBeatCount > 0 {
                    JKReceiptRow(
                        lead: "the plan",
                        punch: "\(snapshot.completedBeatCount) of \(snapshot.day?.beats.count ?? 0) beats, kept",
                        punchItalic: ["kept"],
                        showsRule: snapshot.proteinEatenG > 0
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
