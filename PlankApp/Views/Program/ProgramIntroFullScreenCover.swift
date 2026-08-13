import SwiftUI
import SwiftData
import PlankSync

// MARK: - ProgramOnrampView
//
// v1.1 program pivot. The Today tab's content for any user who has
// not yet committed to a program — new users straight out of
// onboarding AND existing users upgrading into the program era.
//
// Rendered INLINE as tab content, never presented. The previous
// fullScreenCover approach raced RootView's route cross-fade on the
// onboarding → MainTabView swap: the system cancelled the
// presentation mid-flight (a <1s flash) and stranded the user on the
// legacy HomeView. Structural rendering has no presentation to lose.
//
// There is deliberately no skip: the legacy HomeView is retired, so
// committing to the program is the only way into the Today surface.
// ProgramSetupSubflow sets programEraEnabled on commit, which swaps
// this view for PlanView on the next render.
//
// Layout architecture (founder QA 2026-06-09):
//   - VStack(spacing: 0): ScrollView (content) + Footer (CTA)
//   - Footer is OUTSIDE the ScrollView so the CTA never floats over rows.
//   - modernEntrance() for all visible elements — single shared
//     spring per Motion.modernPop.

struct ProgramOnrampView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var showSubflow: Bool = false
    @State private var appeared: Bool = false
    @State private var showGoalRitual = false
    @State private var summary: PlanSummary? = nil
    @State private var doseStanding: DoseStanding.Standing? = nil
    @State private var doseRouteIsOral = false

    @AppStorage("weightUnit") private var weightUnitRaw: String = "lb"
    private var unit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lb }

    var body: some View {
        ZStack {
            if showSubflow {
                ProgramSetupSubflow { committed in
                    // Commit flips programEraEnabled inside the subflow;
                    // MainTabView re-renders to PlanView on its own. A
                    // back-out returns to the intro beat.
                    if !committed {
                        showSubflow = false
                    }
                }
                .transition(.opacity)
            } else {
                intro
                    .transition(.opacity)
            }
        }
        .animation(Motion.crossFade, value: showSubflow)
        .onAppear {
            Analytics.captureScreen("ProgramOnramp")
            refresh()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                appeared = true
            }
        }
        .sheet(isPresented: $showGoalRitual) {
            JKGoalRitual(
                currentKg: summary?.currentKg,
                existingGoalKg: summary?.goalKg,
                heightCm: UserDefaults.standard.double(forKey: "onboardingHeightCm"),
                isFirstTime: summary?.needsGoal ?? false,
                onSave: { kg in
                    guard let uid = AppSync.shared.currentUserId
                    else { showGoalRitual = false; return }
                    GoalWeightStore.setGoalWeightKg(kg, userId: uid, in: modelContext)
                    showGoalRitual = false
                    refresh()
                },
                onCancel: { showGoalRitual = false }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.bgPrimary)
            .presentationCornerRadius(28)
        }
    }

    /// The plan is rebuilt from the live services every time this
    /// screen appears or she changes something — it is a READ of the
    /// record, never a cached copy that can drift from it.
    private func refresh() {
        guard let uid = AppSync.shared.currentUserId, !uid.isEmpty
        else { return }
        let targets = TargetsService.current(userId: uid, in: modelContext)
        summary = PlanSummary.build(
            plan: ProgramService.shared.activePlan(userId: uid, in: modelContext),
            latestWeightKg: TargetsService.latestWeightKg(userId: uid, in: modelContext),
            proteinG: targets.proteinG,
            stepsGoal: targets.steps,
            numericsSuppressed: targets.numericsSuppressed
        )
        // The same snapshot Home reads its standing from — one engine,
        // one sentence, whichever screen asks.
        let snapshot = TodayStateService.snapshot(userId: uid, in: modelContext)
        doseStanding = snapshot.doseStanding
        doseRouteIsOral = snapshot.doseRouteIsOral
    }

    // MARK: - Intro layout

    private var intro: some View {
        VStack(spacing: 0) {
            ScrollView {
                content
                    .padding(.horizontal, Space.lg)
                    .padding(.top, Space.hero)
                    .padding(.bottom, 24)
            }
            footer
        }
        .background(Palette.programBgPrimary.ignoresSafeArea(edges: .top))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Space.section) {
            hero
            arc
            whatsInsideCard
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Her75-style 2-line display: hand-stacked Text components
            // with negative spacing so the lines visually clamp
            // together. programHeroLineGap = -10 is tuned for 52pt.
            VStack(alignment: .leading, spacing: Typo.programHeroLineGap) {
                Text("your plan")
                    .font(Typo.programHeroDisplay)
                    .foregroundStyle(Palette.cocoaPrimary)
                (
                    Text("is ")
                        .font(Typo.programHeroDisplay)
                        .foregroundStyle(Palette.cocoaPrimary)
                    +
                    Text("here.")
                        .font(Typo.programHeroItalic)
                        .foregroundStyle(Palette.cocoaPrimary)
                )
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modernEntrance(appeared)
    }

    // MARK: - THE ARC — where she is, where she's going, in her numbers
    //
    // This screen used to say *"we used what you told us in onboarding
    // to build your plan"* and then list four promises identical for
    // every human alive. She had answered ~45 questions and paid ~$50,
    // and the payoff named not one of her own numbers. This is the
    // repair: the first thing she sees after buying is her own arc.
    //
    // And when the goal is the one thing missing, the screen ASKS for
    // it here rather than inventing one — which is what every path
    // that produced the 2026-08-13 report did instead.

    @ViewBuilder
    private var arc: some View {
        if let s = summary {
            VStack(alignment: .leading, spacing: 0) {
                if s.needsGoal {
                    goalPrompt
                } else if let current = s.currentKg {
                    arcNumbers(s, currentKg: current)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .modernEntrance(appeared, delay: 0.05)
        }
    }

    @ViewBuilder
    private func arcNumbers(_ s: PlanSummary, currentKg: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // The two weights, side by side, so the relationship
            // between them is the shape — not two numbers in a list.
            //
            // At accessibility sizes the pair STACKS. Frame review
            // caught the alternative: at AX5 the row could not fit and
            // SwiftUI wrapped inside the numeral itself — "124" became
            // "12" over "4". A weight-loss app showing a broken weight
            // is the worst frame in the product, so the numerals also
            // refuse to wrap at any size.
            let stacked = dynamicTypeSize.isAccessibilitySize
            AnyLayout(stacked
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 10))) {
                weightNumeral(currentKg, caption: "today")
                if case .losing(let goal) = s.intent {
                    Image(systemName: stacked ? "arrow.down" : "arrow.right")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Palette.cocoaTertiary)
                        .padding(.horizontal, stacked ? 0 : 2)
                    weightNumeral(goal, caption: "your goal")
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(arcVoiceOver(s, currentKg: currentKg))

            if case .holding = s.intent {
                Text("holding where you are")
                    .font(Typo.body)
                    .foregroundStyle(Palette.cocoaSecondary)
            } else {
                ItalicAccentText(
                    [s.distanceLine(unit: unit), s.horizonLine]
                        .compactMap { $0 }.joined(separator: " · "),
                    italic: [],
                    baseFont: Typo.body,
                    italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 16),
                    color: Palette.cocoaSecondary,
                    alignment: .leading
                )
            }

            Button {
                Haptics.light()
                showGoalRitual = true
            } label: {
                Text("change my goal")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.cocoaTertiary)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("opens the goal weight picker")
        }
    }

    private func weightNumeral(_ kg: Double, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(PlanSummary.formatted(unit.display(fromKg: kg)))
                    .font(.custom("JeniHeroSerif-Regular", size: 34))
                    .foregroundStyle(Palette.cocoaPrimary)
                    .monospacedDigit()
                    // A number never breaks across lines. Frame review
                    // caught "124" rendering as "12" over "4" at AX5.
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Text(unit.label)
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundStyle(Palette.cocoaTertiary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            Text(caption)
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// One sentence for VoiceOver, so the pair is not read as two
    /// unlabelled numbers.
    private func arcVoiceOver(_ s: PlanSummary, currentKg: Double) -> String {
        var parts = ["today, \(PlanSummary.formatted(unit.display(fromKg: currentKg))) \(unit.label)"]
        if case .losing(let goal) = s.intent {
            parts.append("your goal, \(PlanSummary.formatted(unit.display(fromKg: goal))) \(unit.label)")
        }
        return parts.joined(separator: ". ") + "."
    }

    /// The one thing we cannot compute for her, asked for plainly.
    private var goalPrompt: some View {
        Button {
            Haptics.light()
            showGoalRitual = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ItalicAccentText(
                    "one number is missing: where you'd like to land. it sets your pace and your daily food target.",
                    italic: ["where you'd like to land"],
                    baseFont: Typo.body,
                    italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 16),
                    color: Palette.cocoaSecondary,
                    alignment: .leading
                )
                Text("set my goal weight")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.cocoaPrimary)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 18)
                    .overlay(Capsule().stroke(Palette.hairlineCocoa, lineWidth: 0.66))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // App v2.1 — the bordered scrapbook card retired; the onramp
    // speaks the receipt grammar the rest of v2 speaks (hairline
    // rows, quiet cause -> serif consequence). This is the first
    // screen a new payer settles on: it must read as the same app
    // the onboarding was.
    /// EACH DAY — her numbers, not four promises.
    ///
    /// Every row states what the number IS as well as what it is: a
    /// maintenance energy target and a loss energy target are the same
    /// glyph and opposite instructions, and the app used to print them
    /// identically. A row with nothing true to say is not drawn.
    private var whatsInsideCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("each day")
                .font(Typo.captionTracked)
                .kerning(1.98)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.bottom, Space.sm)

            let s = summary
            var isFirst = true

            if let protein = s?.proteinG {
                JKReceiptRow(
                    lead: "protein",
                    punch: "\(protein) g, your floor",
                    punchItalic: ["floor"],
                    showsRule: false
                )
                let _ = { isFirst = false }()
            }

            if let kcal = s?.energyKcal, let kind = s?.energyKind {
                JKReceiptRow(
                    lead: "food",
                    punch: kind == .maintenance
                        ? "about \(kcal.formatted()) kcal to hold steady"
                        : "about \(kcal.formatted()) kcal, an estimate",
                    punchItalic: kind == .maintenance ? ["hold steady"] : ["estimate"],
                    showsRule: !isFirst
                )
                let _ = { isFirst = false }()
            } else if s?.needsGoal == true {
                JKReceiptRow(
                    lead: "food",
                    punch: "set your goal and this arrives",
                    punchItalic: ["arrives"],
                    showsRule: !isFirst
                )
                let _ = { isFirst = false }()
            }

            JKReceiptRow(
                lead: "movement",
                punch: "\((s?.stepsGoal ?? 7_500).formatted()) steps, offered never owed",
                punchItalic: ["offered"],
                showsRule: !isFirst
            )

            if let medicationLine {
                JKReceiptRow(
                    lead: "medication",
                    punch: medicationLine,
                    punchItalic: []
                )
            }

            JKReceiptRow(
                lead: "the method",
                punch: "a 2-minute read, most days",
                punchItalic: ["read"]
            )
        }
        .padding(.horizontal, Space.sm)
        .modernEntrance(appeared, delay: 0.10)
    }

    /// The dose rhythm, in the same discretion Home keeps: the product
    /// is never named on a screen she may hand to someone, and a pill
    /// is never called a shot. nil for a non-medicated user, so the
    /// non-GLP-1 plan gains zero medication pixels.
    private var medicationLine: String? {
        guard let standing = doseStanding else { return nil }
        return DoseStanding.read(standing, isOral: doseRouteIsOral).headline
    }


    // MARK: - Footer (pinned)

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                Haptics.light()
                Analytics.track(.programInviteTapped)
                withAnimation(Motion.crossFade) { showSubflow = true }
            } label: {
                Text("start my program")
                    .font(Typo.heading)
                    .foregroundStyle(Palette.textInverse)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Palette.cocoaPrimary)
                    .clipShape(Capsule())
                    // Her program's arrival is an earned moment — the
                    // screen's one border beam rides the CTA (JKBorderBeam law).
                    .jkBorderBeam(cornerRadius: 28, lineWidth: 1.25,
                                  tint: Palette.accentSubtle, intensity: 0.5, period: 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(
            Palette.programBgPrimary
                .overlay(
                    // Hairline divider above the footer so the
                    // scrollable content reads as a separate
                    // layer when the user scrolls past.
                    Rectangle()
                        .fill(Palette.hairlineCocoa)
                        .frame(height: 0.5),
                    alignment: .top
                )
        )
        .modernEntrance(appeared, delay: 0.20)
    }
}
