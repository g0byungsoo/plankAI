import SwiftUI
import AppTrackingTransparency

// MARK: - BuildingPlanLoadingView
//
// The ~8s "we're computing your becoming plan" beat in the reveal
// sequence. Per Noom research this is the reciprocity peak — users who
// watch a personalized plan "build" out of their own answers convert at
// materially higher rates than users who get the reveal instantly,
// because the wait makes the plan feel earned + investment-anchored.
//
// v5 receipt-tape rewrite (2026-07-02, panel finding): the previous
// narration cited fields the flow stopped collecting in v4 R3
// (bodyFocus / sessionLength / commitmentDays defaults) and mapped
// "pace" off VOICE PREFERENCE — default-value theater to a scam-wary
// cohort, the exact fabricated-personalization tell the provenance rule
// exists to prevent. Every line below now interpolates a LIVE AppStorage
// key and drops out when unanswered. As each line finishes "consuming,"
// it lands in a checked receipt stack under the bar — labor illusion +
// reciprocity fused, zero fabrication surface.
//
// Kept from the tuned v4.5 build: the two-phase whip progress curve,
// the ATT prompt at ~30%, the completion frame with tap-to-continue,
// reduce-motion collapse, the her75 IMG_6280 silence register.

struct BuildingPlanLoadingView: View {
    // Signature preserved for the legacy v4.5 call site; bodyFocus and
    // the derived keys are deliberately no longer narrated.
    let bodyFocus: Set<String>
    let sessionLengthKey: String
    let voicePreference: String
    let commitmentDaysKey: String
    let onComplete: () -> Void

    @State private var subLabelIndex: Int = 0
    @State private var subLabelVisible = false
    @State private var heroVisible = false
    @State private var showCompletionFrame = false
    @State private var attPromptFired = false
    @State private var consumed: [String] = []
    @State private var progress: Double = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Live keys only. Empty / "prefer not to say" values drop their
    // label — the loader narrates only what she actually gave us.
    @AppStorage("onboardingSleepHours") private var sleepHours: String = ""
    @AppStorage("onboardingStressLevel") private var stressLevel: String = ""
    @AppStorage("onboardingEatingCadence") private var eatingCadence: String = ""
    @AppStorage("onboardingPriorAttempts") private var priorAttempts: String = ""
    @AppStorage("onboardingHormonalStage") private var hormonalStage: String = ""
    @AppStorage("onboarding_glp1_status") private var glp1Status: String = ""
    @AppStorage("onboarding_glp1_stop_window") private var glp1StopWindow: String = ""
    @AppStorage("onb_v5_appetite_rhythm") private var appetiteRhythm: String = ""
    @AppStorage("onboardingCuisinePreference") private var cuisineCSV: String = ""
    @AppStorage("onboarding_dietary") private var dietaryCSV: String = ""
    @AppStorage("onboardingNsvPriority") private var nsvCSV: String = ""
    @AppStorage("onb_v4_movement_baseline") private var movementBaseline: String = ""
    @AppStorage("onb_v5_snap_demo_meal") private var snapDemoMeal: String = ""
    @AppStorage("program_mode") private var programMode: String = "loss"

    var body: some View {
        ZStack {
            Palette.programBgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 120)

                ItalicAccentText(
                    showCompletionFrame ? "your plan, ready." : "personalizing your plan",
                    italic: ["your"],
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    color: Palette.textPrimary,
                    alignment: .center
                )
                .kerning(-0.4)
                .lineSpacing(Typo.heroHeadlineLineGap)
                .padding(.horizontal, Space.lg)
                .opacity(heroVisible ? 1 : 0)
                .scaleEffect(heroVisible ? 1.0 : 0.97)
                .animation(Motion.entrance, value: showCompletionFrame)

                Spacer().frame(height: Space.lg + 4)

                if !showCompletionFrame {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Palette.divider.opacity(0.6))
                            .frame(width: 200, height: 2)
                        Capsule()
                            .fill(Palette.bgInverse)
                            .frame(width: 200 * CGFloat(progress), height: 2)
                    }
                    .opacity(heroVisible ? 1 : 0)

                    Spacer().frame(height: Space.lg)

                    // The line being consumed — the reading zone, directly
                    // under the bar (not parked at the screen's foot).
                    subLabel(at: subLabelIndex)
                        .padding(.horizontal, Space.lg)
                        .opacity(subLabelVisible ? 0.9 : 0)
                        .id(subLabelIndex)

                    Spacer().frame(height: Space.lg)

                    // The receipt: consumed lines compress into a checked
                    // stack — visible proof her answers went somewhere.
                    receiptStack
                        .padding(.horizontal, Space.xl + Space.sm)
                }

                if showCompletionFrame {
                    JFContinueButton(label: "see your plan", action: onComplete)
                        .padding(.horizontal, Space.xl)
                        .padding(.top, Space.lg)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()
            }
        }
        .task { await runChoreography() }
    }

    // MARK: - Receipt stack

    @ViewBuilder private var receiptStack: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(consumed.suffix(5).enumerated()), id: \.element) { _, line in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.accent)
                    Text(line)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                        // Long interpolated lines ("keeping japanese +
                        // korean on the table") compress instead of
                        // ellipsizing mid-word (founder walk catch).
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                }
                .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(Motion.entranceSoft, value: consumed)
    }

    // MARK: - ATT prompt

    private func requestATTIfNeeded() async {
        if ProcessInfo.processInfo.arguments.contains("--debug-building") { return }
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            return
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
        if Task.isCancelled { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    // MARK: - Sub-label content (live keys only)

    @ViewBuilder
    private func subLabel(at index: Int) -> some View {
        let labels = subLabels
        if index >= labels.count {
            ItalicAccentText(
                "your becoming, ready",
                italic: ["becoming"],
                baseFont: .custom("Fraunces72pt-Regular", size: 14),
                italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 14),
                color: Palette.textSecondary,
                alignment: .center
            )
        } else {
            Text(labels[index])
                .font(.system(size: 14))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    /// Every line interpolates a value SHE gave. Order mirrors the flow
    /// so the loading reads as a recap of her own answers.
    private var subLabels: [String] {
        var labels: [String] = []
        if !movementBaseline.isEmpty {
            labels.append("starting from \(movementLabel)…")
        }
        if !eatingCadence.isEmpty {
            labels.append("shaping around \(cadenceLabel)…")
        }
        let cuisines = cuisineCSV.split(separator: ",").map(String.init)
            .filter { $0 != "everything" }
        if !cuisines.isEmpty {
            labels.append("keeping \(cuisines.prefix(2).joined(separator: " + ")) on the table…")
        }
        let dietary = dietaryCSV.split(separator: ",").map(String.init)
            .filter { $0 != "none" }
        if !dietary.isEmpty {
            let d = dietaryLabel(dietary)
            if !d.isEmpty { labels.append("remembering \(d)…") }
        }
        if snapDemoMeal != "" && snapDemoMeal != "skipped" {
            labels.append("your practice plate, read in seconds…")
        }
        if !priorAttempts.isEmpty && priorAttempts != "none" {
            labels.append("learning from every start-over…")
        }
        if !sleepHours.isEmpty {
            labels.append(sleepLoaderLabel)
        }
        if stressLevel == "heavy" || stressLevel == "overwhelmed" {
            labels.append("weighting recovery for the load you carry…")
        }
        if !hormonalStage.isEmpty && hormonalStage != "prefer_not_say" {
            labels.append("adjusting for where your body is…")
        }
        switch glp1Status {
        case "current":
            labels.append("pacing for the shot · protein first…")
            if appetiteRhythm == "after_shot" {
                labels.append("easing the days after your shot…")
            }
        case "past":
            labels.append(stopWindowLabel)
        default: break
        }
        let nsv = nsvCSV.split(separator: ",").map(String.init)
        if !nsv.isEmpty, let firstNsv = nsvLabel(nsv) {
            labels.append("aiming at \(firstNsv)…")
        }
        if programMode == "maintenance" {
            labels.append("building your maintenance rhythm…")
        } else {
            labels.append("setting your calorie window…")
        }
        labels.append("no forbidden foods. nothing to earn…")
        labels.append("computing your projection curve…")
        return labels
    }

    private var totalLabelCount: Int { subLabels.count + 1 }  // +1 closer

    private var movementLabel: String {
        switch movementBaseline {
        case "barely": return "stillness, gently"
        case "walks": return "your walks"
        case "regular_ish": return "your regular-ish rhythm"
        case "very_active": return "a strong base"
        default: return "where you are"
        }
    }

    private var cadenceLabel: String {
        switch eatingCadence {
        case "one_meal": return "your one-meal days"
        case "two_meals": return "two meals + snacks"
        case "three_meals": return "your three steady meals"
        case "grazing": return "grazing days"
        case "chaotic": return "no-pattern days"
        default: return "how you eat"
        }
    }

    private func dietaryLabel(_ keys: [String]) -> String {
        let words: [String: String] = [
            "vegetarian": "vegetarian", "vegan": "vegan",
            "pescatarian": "pescatarian", "dairy_free": "dairy-free",
            "gluten_free": "gluten-free", "nut_allergy": "the nut allergy",
            "shellfish_allergy": "the shellfish allergy",
            "egg_allergy": "the egg allergy", "halal": "halal",
            "kosher": "kosher", "low_carb": "low-carb",
        ]
        return keys.compactMap { words[$0] }.prefix(2).joined(separator: " + ")
    }

    private func nsvLabel(_ keys: [String]) -> String? {
        let words: [String: String] = [
            "core": "a core that holds", "energy": "energy that lasts",
            "clothes": "clothes that fit right", "sleep": "sleep that resets",
            "muscle": "keeping your muscle", "trust": "trusting food again",
            "quiet": "quiet around food",
        ]
        for k in keys { if let w = words[k] { return w } }
        return nil
    }

    private var sleepLoaderLabel: String {
        switch sleepHours {
        case "under5", "five6": return "pacing gentler for your short nights…"
        case "six7": return "accounting for your 6-to-7 hours…"
        case "seven8": return "accounting for your solid sleep…"
        case "eightPlus": return "banking your deep recovery…"
        default: return "accounting for your sleep window…"
        }
    }

    // Tape lines render lineLimit(1) — keep every variant ≤ ~40 chars so
    // nothing ellipsizes at 390pt-wide devices (device catch 2026-07-03).
    private var stopWindowLabel: String {
        switch glp1StopWindow {
        case "under3": return "fresh off the shot · defending it…"
        case "three6": return "3-6 months off · defending it…"
        case "six12": return "6-12 months off · defending it…"
        case "overyear": return "a year off the shot · keeping it yours…"
        default: return "the after-chapter · keeping it yours…"
        }
    }

    // MARK: - Choreography (two-phase whip curve, v4.5-tuned)

    @MainActor
    private func runChoreography() async {
        withAnimation(Motion.entranceSoft) { heroVisible = true }

        try? await Task.sleep(nanoseconds: 300_000_000)

        if reduceMotion {
            subLabelVisible = true
        } else {
            withAnimation(Motion.entranceSoft) { subLabelVisible = true }
        }

        // Unified tick loop — drives the bar + sub-label rotation +
        // receipt landings in lockstep. Two-phase whip curve per the
        // founder-tuned v3 pacing: gentle ease-in to 50% over the first
        // 60% of wall-clock, exponential whip 50→100% over the last 40%.
        let allLabels = subLabels
        let totalLabels = totalLabelCount
        let totalSeconds = reduceMotion
            ? 3.0
            : min(9.5, Double(totalLabels) * 1.0 + 0.5)
        let tickCount = 100
        let perTickNs = UInt64((totalSeconds * 1_000_000_000) / Double(tickCount))
        let ticksPerLabel = max(1, tickCount / totalLabels)

        let phase2K: Double = 3.0
        let phase2Norm: Double = 1.0 / (1.0 - exp(-phase2K))

        for tick in 1...tickCount {
            try? await Task.sleep(nanoseconds: perTickNs)
            if Task.isCancelled { return }
            let t = Double(tick) / Double(tickCount)
            if t < 0.6 {
                let s = t / 0.6
                progress = 0.50 * pow(s, 1.2)
            } else {
                let s = (t - 0.6) / 0.4
                progress = 0.50 + 0.50 * (1.0 - exp(-phase2K * s)) * phase2Norm
            }

            // ATT prompt at ~30% perceived progress — the system dialog
            // pauses the loop via await; progress holds (deliberate).
            if !attPromptFired, progress >= 0.30 {
                attPromptFired = true
                await requestATTIfNeeded()
            }

            let nextIndex = min(tick / ticksPerLabel, totalLabels - 1)
            if nextIndex > subLabelIndex {
                // The finished line lands on the receipt with a tick —
                // her answer, visibly consumed. Ellipsis drops on land.
                let finished = subLabelIndex < allLabels.count
                    ? allLabels[subLabelIndex] : nil
                if reduceMotion {
                    subLabelIndex = nextIndex
                    if let finished { consumed.append(receiptForm(of: finished)) }
                } else {
                    withAnimation(.easeIn(duration: 0.2)) { subLabelVisible = false }
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    if Task.isCancelled { return }
                    subLabelIndex = nextIndex
                    if let finished {
                        consumed.append(receiptForm(of: finished))
                        if consumed.count <= 6 { Haptics.tick() }
                    }
                    withAnimation(.easeOut(duration: 0.3)) { subLabelVisible = true }
                }
            }
        }

        // Completion frame — bar fills, beat of silence, hero swaps to
        // "your plan, ready." + cocoa CTA. Tap-to-continue; the dwell
        // is owned by the user. 8s auto-advance safety net.
        try? await Task.sleep(nanoseconds: 700_000_000)
        if Task.isCancelled { return }
        withAnimation(.easeOut(duration: 0.45)) {
            showCompletionFrame = true
        }
        try? await Task.sleep(nanoseconds: 8_000_000_000)
        if Task.isCancelled { return }
        if showCompletionFrame {
            onComplete()
        }
    }

    private func receiptForm(of label: String) -> String {
        label.replacingOccurrences(of: "…", with: "")
    }
}

#Preview {
    BuildingPlanLoadingView(
        bodyFocus: [],
        sessionLengthKey: "ten",
        voicePreference: "encouraging",
        commitmentDaysKey: "five",
        onComplete: {}
    )
}
