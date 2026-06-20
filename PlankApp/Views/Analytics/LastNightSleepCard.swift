import SwiftUI

// MARK: - LastNightSleepCard
//
// Becoming tab card surfacing last-night sleep from Apple Health. Lives
// alongside StepsBentoTile + BreathworkBentoTile as a peer Becoming
// module. The card is read-only (we don't prompt the user to log sleep —
// it's passive HK only) and gracefully degrades through three states:
//
//   .authorized + data → premium hero + topography visualization
//   .notDetermined     → quiet "connect" prompt with rose CTA
//   .denied            → recovery line + "open apple health" deep-link
//
// Design discipline:
//   - Scrapbook chrome (24pt radius, 1.5pt accent border, hard offset
//     shadow) — matches existing Becoming module convention.
//   - Italic-Fraunces hero number ("8h 23m") at 40pt — punch is the
//     duration itself, no separate "punch word" needed.
//   - Reflective subhead: "you slept *deeply* ♥" / "*lightly* ♥" /
//     "*well* ♥" — italic on the qualifier word, derived from the
//     deep-sleep ratio.
//   - Sleep topography (the visual moat): 80 hand-drawn-feel vertical
//     "depth" bars across the night, each colored by the active sleep
//     stage. Deep sleep = thick cocoa, REM = thinner rose, core =
//     medium pink, inBed = short accentSubtle, awake = amber tick.
//     Renders as a soft mountain range that the eye scans left to
//     right — the cohort sees their own night as a landscape, not a
//     spreadsheet.
//   - Entrance staggers: card slide-up 12pt + fade 0.55s, hero number
//     after 180ms, subhead 280ms, topography draws in 380ms over
//     0.9s. Reduce-motion gates everything to snap-final.
//   - NO scatter sticker — Becoming is a dashboard, scatter is locked
//     to the 3 earned moments (welcome / plan reveal / graduation)
//     per [[feedback-scatter-milestone-rule]].

struct LastNightSleepCard: View {

    let sleep: LastNightSleep?
    let authStatus: SleepService.Authorization
    var onConnect: () -> Void = {}
    var onOpenHealth: () -> Void = {}

    @State private var hasAppeared: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        cardBody
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Palette.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Palette.accent.opacity(0.5), lineWidth: 1.5)
            )
            .shadow(color: Palette.textPrimary.opacity(0.16), radius: 0, x: 3, y: 3)
            .onAppear {
                if reduceMotion {
                    hasAppeared = true
                } else {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                        hasAppeared = true
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Body switch

    @ViewBuilder
    private var cardBody: some View {
        if let sleep {
            populated(sleep)
        } else {
            empty
        }
    }

    // MARK: - Populated state

    @ViewBuilder
    private func populated(_ sleep: LastNightSleep) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            eyebrow(date: sleep.wakeTime)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 8)

            hero(asleep: sleep.asleepDuration)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 10)
                .animation(.spring(response: 0.55, dampingFraction: 0.86).delay(0.18),
                           value: hasAppeared)

            subhead(for: sleep)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 8)
                .animation(.spring(response: 0.55, dampingFraction: 0.86).delay(0.28),
                           value: hasAppeared)

            topography(sleep)
                .opacity(hasAppeared ? 1 : 0)
                .animation(.easeOut(duration: 0.9).delay(0.38), value: hasAppeared)

            timeLabels(bedtime: sleep.bedtime, wakeTime: sleep.wakeTime)
                .opacity(hasAppeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.55), value: hasAppeared)
        }
    }

    // MARK: - Eyebrow

    @ViewBuilder
    private func eyebrow(date: Date) -> some View {
        HStack(spacing: 6) {
            Text("last night")
                .font(.system(size: 11, weight: .medium, design: .default))
                .foregroundStyle(Palette.textSecondary)
                .tracking(0.6)
                .textCase(.lowercase)
            Circle()
                .fill(Palette.textSecondary.opacity(0.4))
                .frame(width: 3, height: 3)
            Text(Self.eyebrowDateFormatter.string(from: date).lowercased())
                .font(.system(size: 11, weight: .regular, design: .default))
                .foregroundStyle(Palette.textSecondary)
                .tracking(0.4)
        }
    }

    // MARK: - Hero number

    @ViewBuilder
    private func hero(asleep: TimeInterval) -> some View {
        let parts = formatDurationParts(asleep)
        // Custom composition: italic Fraunces for the number, smaller
        // sans for the units. Avoids monolithic display in one font.
        (
            Text(parts.hours).font(.custom("Fraunces72pt-SemiBoldItalic", size: 44))
            + Text("h ").font(.custom("Fraunces72pt-Regular", size: 22))
                .foregroundColor(Palette.textPrimary.opacity(0.55))
            + Text(parts.minutes).font(.custom("Fraunces72pt-SemiBoldItalic", size: 44))
            + Text("m").font(.custom("Fraunces72pt-Regular", size: 22))
                .foregroundColor(Palette.textPrimary.opacity(0.55))
        )
        .foregroundStyle(Palette.textPrimary)
        .tracking(-1.0)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Subhead

    @ViewBuilder
    private func subhead(for sleep: LastNightSleep) -> some View {
        let parts = subheadParts(for: sleep)
        ItalicAccentText(
            parts.base,
            italic: parts.italic,
            baseFont: .custom("Fraunces72pt-Regular", size: 14),
            italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 14),
            color: Palette.textSecondary,
            alignment: .leading
        )
    }

    private func subheadParts(for sleep: LastNightSleep) -> (base: String, italic: [String]) {
        // Deep sleep ratio → qualifier word. Thresholds reflect the
        // common ranges in adult sleep research (Patel 2017): >20%
        // deep is meaningfully restorative; 12-20% normal; <12% light.
        let deep = sleep.stages
            .filter { $0.kind == .asleepDeep }
            .map(\.duration)
            .reduce(0, +)
        let ratio = sleep.asleepDuration > 0 ? deep / sleep.asleepDuration : 0
        let qualifier: String
        switch ratio {
        case 0.20...:  qualifier = "deeply"
        case 0.12...:  qualifier = "well"
        default:       qualifier = "lightly"
        }
        return ("you slept \(qualifier) ♥", [qualifier])
    }

    // MARK: - Topography (the visual)

    @ViewBuilder
    private func topography(_ sleep: LastNightSleep) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                Self.topographyBackground

                ForEach(Array(topoBands(for: sleep, width: proxy.size.width).enumerated()),
                        id: \.offset) { _, band in
                    Capsule()
                        .fill(band.color)
                        .frame(width: band.width, height: band.height)
                        .position(x: band.x, y: proxy.size.height - band.height / 2)
                }
            }
        }
        .frame(height: 64)
    }

    private static var topographyBackground: some View {
        // Soft horizon line at the baseline + a barely-visible "deep
        // sleep" horizon at ~70% height. The cohort gets a quiet
        // chrome reference without a heavy grid.
        VStack(spacing: 0) {
            Spacer()
            Rectangle()
                .fill(Palette.textPrimary.opacity(0.06))
                .frame(height: 0.5)
        }
    }

    private func topoBands(for sleep: LastNightSleep, width totalWidth: CGFloat)
        -> [TopographyBand]
    {
        let bandCount = 80
        let columnWidth = totalWidth / CGFloat(bandCount)
        let totalDuration = sleep.inBedDuration
        guard totalDuration > 0 else { return [] }

        // For each of N x-positions, find the stage active at that
        // moment. We pick the "deepest" stage if multiple bands
        // overlap (deep > REM > core > asleep > inBed > awake), so
        // the visual signal favors the restorative signal.
        return (0..<bandCount).map { i in
            let t = (Double(i) + 0.5) / Double(bandCount) * totalDuration
            let kind = deepestStage(at: t, in: sleep.stages)
            let depth = depthMultiplier(for: kind)
            let color = bandColor(for: kind)
            // Slight per-band height variance (deterministic — same input
            // = same output) gives the bars a hand-drawn "ink unevenness"
            // rather than a perfectly clinical bar chart.
            let jitter = sin(Double(i) * 0.7 + 1.3) * 0.05
            let h = max(2, CGFloat((depth + jitter) * 40))
            let x = (CGFloat(i) + 0.5) * columnWidth
            return TopographyBand(
                color: color,
                width: max(1.5, columnWidth - 1.4),
                height: h,
                x: x
            )
        }
    }

    private func deepestStage(at offset: TimeInterval, in stages: [LastNightSleep.Stage])
        -> LastNightSleep.Stage.Kind?
    {
        // Stages can overlap (some loggers emit redundant samples).
        // Pick the deepest at this moment so the visualization shows
        // the most-meaningful signal.
        let priority: [LastNightSleep.Stage.Kind] = [
            .asleepDeep, .asleepREM, .asleepCore, .asleep, .inBed, .awake
        ]
        let active = stages.filter { offset >= $0.startOffset && offset < $0.startOffset + $0.duration }
        for kind in priority where active.contains(where: { $0.kind == kind }) {
            return kind
        }
        return nil
    }

    private func depthMultiplier(for kind: LastNightSleep.Stage.Kind?) -> Double {
        // Visual depth: deep is tallest, REM medium, core medium-low,
        // awake a small amber tick. Tuned so the average night reads
        // as a soft mountain range, not a flat bar.
        switch kind {
        case .asleepDeep:  return 1.00
        case .asleepREM:   return 0.78
        case .asleepCore:  return 0.55
        case .asleep:      return 0.55  // legacy unspecified — treated as core
        case .inBed:       return 0.18
        case .awake:       return 0.08
        case .none:        return 0
        }
    }

    private func bandColor(for kind: LastNightSleep.Stage.Kind?) -> Color {
        switch kind {
        case .asleepDeep:  return Palette.textPrimary.opacity(0.85)
        case .asleepREM:   return Palette.accent.opacity(0.92)
        case .asleepCore:  return Palette.accent.opacity(0.55)
        case .asleep:      return Palette.accent.opacity(0.55)
        case .inBed:       return Palette.accentSubtle
        case .awake:       return Palette.stateWarn.opacity(0.55)
        case .none:        return Palette.textPrimary.opacity(0.08)
        }
    }

    // MARK: - Time labels

    @ViewBuilder
    private func timeLabels(bedtime: Date, wakeTime: Date) -> some View {
        HStack {
            Text(Self.timeOnlyFormatter.string(from: bedtime).lowercased())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.textSecondary.opacity(0.75))
                .tracking(0.3)
            Spacer()
            Text(Self.timeOnlyFormatter.string(from: wakeTime).lowercased())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.textSecondary.opacity(0.75))
                .tracking(0.3)
        }
    }

    // MARK: - Empty states

    @ViewBuilder
    private var empty: some View {
        switch authStatus {
        case .notDetermined:
            connectPrompt
        case .requesting:
            requestingPrompt
        case .denied:
            recoveryPrompt
        case .unavailable, .authorized:
            // .authorized with sleep == nil = genuinely no data tonight
            // yet (fresh install, no watch, etc.). Calm fallback.
            noDataYet
        }
    }

    // Interim state while iOS settles the permission sheet. Two reasons
    // to surface this: (1) tap feedback so the user sees something
    // happen, (2) silent no-op handling — iOS suppresses the sheet on
    // a re-ask after a prior grant/deny, and without this state the
    // card looks unresponsive.
    private var requestingPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("sleep")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .tracking(0.6)
                .textCase(.lowercase)
            ItalicAccentText(
                "trying to connect ♥",
                italic: ["trying"],
                baseFont: .custom("Fraunces72pt-Regular", size: 22),
                italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 22),
                color: Palette.textPrimary,
                alignment: .leading
            )
            Text("apple health will ask you in a sec. say yes and jeni reads sleep only.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var connectPrompt: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text("sleep")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .tracking(0.6)
                    .textCase(.lowercase)
                Circle().fill(Palette.textSecondary.opacity(0.4)).frame(width: 3, height: 3)
                Text("becoming")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Palette.textSecondary)
                    .tracking(0.4)
            }

            ItalicAccentText(
                "let jeni notice the nights you slept ♥",
                italic: ["notice"],
                baseFont: .custom("Fraunces72pt-Regular", size: 22),
                italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 22),
                color: Palette.textPrimary,
                alignment: .leading
            )
            .fixedSize(horizontal: false, vertical: true)

            Text("we read your sleep duration from apple health. it stays on your phone, never sent anywhere.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onConnect) {
                Text("connect ♥")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.bgPrimary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Palette.textPrimary))
            }
            .buttonStyle(.plain)
        }
    }

    private var recoveryPrompt: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("sleep")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .tracking(0.6)
                .textCase(.lowercase)
            ItalicAccentText(
                "almost there ♥",
                italic: ["almost"],
                baseFont: .custom("Fraunces72pt-Regular", size: 22),
                italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 22),
                color: Palette.textPrimary,
                alignment: .leading
            )

            // Two-line bullet copy that names both possible causes
            // honestly — iOS doesn't tell us which (privacy by design)
            // and either path resolves through Apple Health.
            VStack(alignment: .leading, spacing: 8) {
                bulletRow("either jeni doesn't have sleep access yet,")
                bulletRow("or your watch / phone hasn't synced a night yet.")
            }

            Text("either way, the fix lives in apple health → sources → jenifit.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // Primary capsule (not a text link) — matches the connect
            // CTA visual weight so the recovery path is as discoverable
            // as the entry path.
            Button(action: onOpenHealth) {
                Text("open apple health ♥")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.bgPrimary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Palette.textPrimary))
            }
            .buttonStyle(.plain)
        }
    }

    /// Small bullet row used by the recovery copy. Two-tone (cocoa dot
    /// + secondary text) so the eye scans the line as a path, not a
    /// sentence.
    @ViewBuilder
    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(Palette.accent)
                .frame(width: 4, height: 4)
                .offset(y: -2)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Palette.textPrimary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var noDataYet: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("sleep")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .tracking(0.6)
                .textCase(.lowercase)
            ItalicAccentText(
                "no rest data yet ♥",
                italic: ["yet"],
                baseFont: .custom("Fraunces72pt-Regular", size: 20),
                italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 20),
                color: Palette.textPrimary,
                alignment: .leading
            )
            Text("your watch or phone will sync sleep when it lands.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.textSecondary)
        }
    }

    // MARK: - Formatters

    private static let timeOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mma"
        return f
    }()

    private static let eyebrowDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private func formatDurationParts(_ seconds: TimeInterval) -> (hours: String, minutes: String) {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        return (String(h), String(format: "%02d", m))
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        guard let s = sleep else {
            switch authStatus {
            case .notDetermined: return "Connect Apple Health to read your sleep"
            case .requesting:    return "Connecting to Apple Health"
            case .denied:        return "Open Apple Health to allow JeniFit to read sleep"
            case .unavailable:   return "Sleep data unavailable on this device"
            case .authorized:    return "No sleep data yet"
            }
        }
        let total = Int(s.asleepDuration)
        let h = total / 3600
        let m = (total % 3600) / 60
        return "Last night you slept \(h) hours and \(m) minutes"
    }
}

// MARK: - TopographyBand

private struct TopographyBand {
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let x: CGFloat
}

// MARK: - Preview

#if DEBUG
#Preview("LastNightSleepCard — populated") {
    LastNightSleepCard(
        sleep: .sample(),
        authStatus: .authorized
    )
    .padding(20)
    .background(Palette.bgPrimary)
}

#Preview("LastNightSleepCard — connect") {
    LastNightSleepCard(
        sleep: nil,
        authStatus: .notDetermined
    )
    .padding(20)
    .background(Palette.bgPrimary)
}

#Preview("LastNightSleepCard — denied") {
    LastNightSleepCard(
        sleep: nil,
        authStatus: .denied
    )
    .padding(20)
    .background(Palette.bgPrimary)
}
#endif
