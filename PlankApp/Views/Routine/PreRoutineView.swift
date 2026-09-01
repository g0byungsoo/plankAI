import SwiftUI
import PlankSync

/// Shown after the user taps Start on the Home card and before the live
/// session player. Surfaces the workout's name, calorie estimate, total
/// time, exercise count, a one-line "why this works" tip, and a list of
/// every exercise with its duration and category.
struct PreRoutineView: View {
    let workout: WorkoutPreset
    let onStart: () -> Void
    let onCancel: () -> Void
    /// v2.4 — the five-minute floor: regenerates today's session at
    /// 5 minutes (17_FEATURE_EVALUATION §2). nil hides the door
    /// (already at the floor, or hosts that don't support it).
    var onShrink: (() -> Void)? = nil

    /// Phase 9.26 — content opacity for the fade-in appear animation.
    /// The fullScreenCover binding is set with `Transaction.disablesAnimations`
    /// upstream (HomeView), so the cover materializes instantly with
    /// no slide-up; this fade then handles the visual reveal. v1.1
    /// module pass: paired with an 8pt upward settle (the TabBloom
    /// "card laid down" vocabulary) so every module arrives the same way.
    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 8

    // (kcal estimate deleted 2026-06-11 — it ran on a fabricated 65kg
    // reference weight (data-provenance violation) and put a flame +
    // burn number on the pre-workout brief (the framing the post-
    // Ozempic locks kill). Rounds replaced it as the third stat.)

    /// Distinct primary areas across main slots, in original order.
    private var primaryAreas: [TargetArea] {
        var seen: Set<TargetArea> = []
        var ordered: [TargetArea] = []
        for slot in workout.exercises where slot.category == .main {
            if let area = slot.exercise?.primaryArea, !seen.contains(area) {
                seen.insert(area); ordered.append(area)
            }
        }
        return ordered
    }

    // App v2.3 — the brief's one sentence, in her coach's voice.
    // The old template ("Builds the muscles in your…") was legacy
    // sentence-case content inside the redesigned frame. The line is
    // now short, lowercase, cohort-aware, and ends in permission —
    // the emotional unlock the 26%-completion data says this doorway
    // needs (start small beats start strong).
    private var tip: String {
        // v5.1 — the gentle session speaks its own contract: what it
        // is, what it isn't, and where the bar sits. The area-tip
        // reads as a training promise; this one reads as permission.
        if workout.isGentle {
            return "two moves, twice through, no jumps. halfway already counts"
        }
        let names = primaryAreas.map { $0.rawValue.camelCaseToWords.lowercased() }
        let areas: String = {
            switch names.count {
            case 0: return "your whole body"
            case 1: return "your \(names[0])"
            case 2: return "your \(names[0]) and \(names[1])"
            default: return "your \(names.dropLast().joined(separator: ", ")), and \(names.last!)"
            }
        }()
        if CohortStore.isGLP1Current {
            return "\(areas), kept strong while the weight moves. muscle is the part you keep"
        }
        if CohortStore.isPostGLP1 {
            return "\(areas), steady. this is how the routine outlives the loss."
        }
        return "\(areas), built gently. showing up small still counts"
    }

    var body: some View {
        ZStack {
            // v8 P8.4: program-era pink continuity from PlanView → workout brief.
            Palette.programEraBg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.lg) {
                        header
                        statsRow
                        tipCard
                        exerciseList
                            .padding(.bottom, 100)   // breathe over the start button
                    }
                    .padding(.horizontal, Space.screenPadding)
                    .padding(.top, Space.md)
                }

                startButton  // JFContinueButton carries its own insets
            }
        }
        .opacity(contentOpacity)
        .offset(y: contentOffset)
        .onAppear {
            #if DEBUG
            print("[FUNNEL] preroutine_appeared | workout cover rendered successfully")
            #endif
            // v1.1 module pass — the shared arrival: fade + 8pt settle
            // on gentleSpring, matching the tab switch and the lesson
            // page-turn so every surface lands in the same voice.
            withAnimation(Motion.gentleSpring) {
                contentOpacity = 1
                contentOffset = 0
            }
            // v8: voice intro (chained focus_intro → duration_intro)
            // removed from the workout preview per founder direction.
            // The screen is a reading beat now — voice resumes once
            // the user taps in and RoutineAudioManager takes over.
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Palette.bgElevated)
                    .clipShape(Circle())
                    .tappableArea()
            }
            .accessibilityLabel("Close")
            Spacer()
        }
        .padding(.horizontal, Space.screenPadding)
        .padding(.top, Space.sm)
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            VStack(spacing: Space.xs) {
                // v1.1 — tracked-lowercase kicker (the lesson player's
                // magazine register), not accent-pink caps.
                Text("today's workout")
                    .font(.custom("DMSans-Medium", size: 11))
                    .kerning(1.98)
                    .foregroundStyle(Palette.textSecondary)

                Text(workout.name.lowercased())
                    .font(Typo.titleItalic)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                // App v2.3: the preset description retired from the
                // header — jeni's line below carries the meaning.
            }

            // Two accents framing the header — gives the screen visual
            // punctuation without competing with the title. The glossy
            // pink dumbbells (founder-supplied real-photo cutout, her75
            // technique) replaced the generic candy sticker: same
            // footprint, workout-true subject.
            HStack {
                Image("accent-dumbbells")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 54, height: 54)
                    .rotationEffect(.degrees(-12))
                Spacer()
                Image(StickerName.starLineart.assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(18))
                    .opacity(StickerName.starLineart.style.opacity)
            }
            .padding(.horizontal, Space.lg)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    // MARK: - The brief (App v2.2)
    //
    // The doorway to the app's weakest-completing feature (26% of
    // purchasers ever finish a workout) was also its busiest screen:
    // three hard-offset stat cards + a bordered tip box. v2.2 makes
    // it one breath — the receipt grammar the rest of the app speaks
    // (quiet cause -> serif consequence) and the tip as jeni's line,
    // unboxed. Less to read = less reason to back out.

    private var statsRow: some View {
        let rounds = workout.exercises.map { $0.round }.max() ?? 1
        // Gentle sessions promise "two moves, twice through" — the
        // receipt must count what she has to learn (unique mains),
        // not every slot, or the same screen contradicts itself.
        let mainUnique = Set(
            workout.exercises.filter { $0.category == .main }.map(\.exerciseId)
        ).count
        return VStack(spacing: 0) {
            JKReceiptRow(
                lead: "time",
                punch: "\(workout.estimatedDuration) minutes",
                punchItalic: ["minutes"],
                showsRule: false
            )
            JKReceiptRow(
                lead: "moves",
                punch: workout.isGentle && rounds > 1
                    ? "\(mainUnique), twice through"
                    : rounds == 1
                        ? "\(workout.exercises.count), one round"
                        : "\(workout.exercises.count), in \(rounds) rounds",
                punchItalic: []
            )
            JKReceiptRow(
                lead: "you can",
                punch: "pause or end anytime",
                punchItalic: ["anytime"]
            )
        }
        .padding(.horizontal, Space.sm)
    }

    // MARK: - Jeni's line (was: tip card)

    private var tipCard: some View {
        ItalicAccentText(
            tip,
            italic: tipItalicWords,
            baseFont: .custom("JeniHeroSerif-Regular", size: 19),
            italicFont: .custom("JeniHeroSerif-Italic", size: 19),
            color: Palette.textPrimary,
            alignment: .leading
        )
        .lineSpacing(-2)
        .kerning(-0.2)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.sm)
        .padding(.top, Space.xs)
    }

    /// Punch word for the tip line — first brand verb found.
    private var tipItalicWords: [String] {
        let candidates = ["steady", "gentle", "strong", "yours", "showing up",
                          "counts", "energy", "pace"]
        let lower = tip.lowercased()
        return Array(candidates.filter { lower.contains($0) }.prefix(1))
    }

    // MARK: - Exercise list

    private var exerciseList: some View {
        // Insert "round N" dividers when slot.round changes — Pamela
        // Reif's "and now repeat" pattern (rules §4). Most sessions are
        // round 1 only, so no dividers render. For long sessions we get
        // one divider before the first slot of each round.
        let entries = Array(workout.exercises.enumerated())
        let totalRounds = workout.exercises.map { $0.round }.max() ?? 1

        return VStack(alignment: .leading, spacing: Space.sm) {
            Text("the plan")
                .font(Typo.titleItalic)
                .foregroundStyle(Palette.textPrimary)
                .padding(.bottom, Space.xs)

            ForEach(entries, id: \.offset) { idx, slot in
                if shouldShowRoundDivider(idx: idx, slot: slot, totalRounds: totalRounds) {
                    roundDivider(round: slot.round, of: totalRounds)
                }
                exerciseRow(idx: idx, slot: slot)
            }
        }
    }

    /// Show a divider when (a) the session has multiple rounds, AND (b)
    /// this is the first slot of its round (or main category transitions
    /// happen — warmup → round 1 main → round 2 main → cooldown).
    private func shouldShowRoundDivider(idx: Int, slot: ExerciseSlot, totalRounds: Int) -> Bool {
        guard totalRounds > 1 else { return false }
        guard slot.category == .main else { return false }
        if idx == 0 { return true }
        let prev = workout.exercises[idx - 1]
        // First main slot, or round changed within main.
        return prev.category != .main || prev.round != slot.round
    }

    private func roundDivider(round: Int, of total: Int) -> some View {
        HStack(spacing: Space.sm) {
            Text("round \(round) · of \(total)")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                .tracking(2)
                .foregroundStyle(Palette.accent)
            Rectangle()
                .fill(Palette.divider)
                .frame(height: 1)
        }
        .padding(.top, Space.xs)
    }

    private func exerciseRow(idx: Int, slot: ExerciseSlot) -> some View {
        HStack(spacing: Space.md) {
            Text("\(idx + 1)")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                .foregroundStyle(Palette.accent)
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(slot.exercise?.name.lowercased() ?? slot.exerciseId)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textPrimary)

                HStack(spacing: 6) {
                    Text(categoryLabel(slot.category))
                        .font(Typo.caption)
                        .foregroundStyle(categoryColor(slot.category))
                    // Surface body position so the user sees the flow
                    // through the session (standing → quadruped → plank
                    // → supine, etc.) before they start.
                    if let pos = slot.exercise?.position {
                        Text("·")
                            .foregroundStyle(Palette.textSecondary)
                        Text(positionLabel(pos))
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    if let side = slot.side {
                        Text("·")
                            .foregroundStyle(Palette.textSecondary)
                        Text(side.rawValue)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            }

            Spacer()

            Text("\(slot.duration)s")
                .font(.custom("Fraunces72pt-SemiBold", size: 16))
                .foregroundStyle(Palette.textPrimary)
        }
        // Compound exercise row — VoiceOver reads "1, squat, main,
        // standing, 30 seconds" as one phrase per row instead of
        // walking 5 separate elements.
        .accessibilityElement(children: .combine)
        .padding(.vertical, Space.sm + 2)
        .padding(.horizontal, Space.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                .fill(Palette.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                        .stroke(Palette.divider, lineWidth: 1)
                )
        )
    }

    private func categoryLabel(_ c: ExerciseCategory) -> String {
        switch c {
        case .warmup:   return "warm up"
        case .main:     return "main"
        case .cooldown: return "cool down"
        }
    }

    private func categoryColor(_ c: ExerciseCategory) -> Color {
        switch c {
        case .warmup:   return Palette.accent
        case .main:     return Palette.textSecondary
        case .cooldown: return Palette.stateGood
        }
    }

    private func positionLabel(_ p: ExercisePosition) -> String {
        switch p {
        case .standing:   return "standing"
        case .quadruped:  return "quadruped"
        case .plank:      return "plank"
        case .prone:      return "prone"
        case .sideLying:  return "side-lying"
        case .supine:     return "supine"
        case .seated:     return "seated"
        }
    }

    // MARK: - Start

    // v1.1 module pass — the one-CTA system (never italic serif
    // inside a button; her75 buttons are plain sans).
    private var startButton: some View {
        JFContinueButton(
            label: "start workout",
            action: { onStart() },
            // v5.1 — the downshift at the drop-off moment. Any
            // non-gentle session offers the gentle five: the smallest
            // real session beats the optimal one she closes the app
            // on. (The old door said "make it 5 minutes" and rebuilt
            // the same intensity, smaller — a five-minute version of
            // the problem.)
            secondaryLabel: (onShrink != nil && !workout.isGentle)
                ? "running on empty? the gentle five" : nil,
            secondaryAction: onShrink
        )
    }
}
