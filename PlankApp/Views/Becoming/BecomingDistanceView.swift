import SwiftUI
import SwiftData

// MARK: - BecomingDistanceView (p74 — THE WHOLE DISTANCE)
//
// Becoming's one ink scene. Dark is not decoration here: paper is
// the working record, ink is the pause — the page she opens on
// purpose to see the whole story at once (and the one she'd show
// someone). Grammar: paper → a chosen door → INK → meaning → paper
// (§4.8's ceremony family, without a ceremony's timers — this is a
// place, not an interruption).
//
// Contents, all from the record: the whole-record trend drawn in
// paper stroke, dose-change seams where they happened, the distance
// sentence, the remaining distance when a goal exists. RM: arrives
// whole. Suppressed cohorts never reach this page (the door gates).

struct BecomingDistanceView: View {
    @Environment(\.modelContext) private var modelContext
    let userId: String
    let onClose: () -> Void

    @State private var arrived = false
    @State private var trend: [WeightWeekReadEngine.TrendPoint] = []
    @State private var seams: [(fraction: Double, label: String)] = []
    @State private var distanceLine: String = ""
    @State private var distanceItalic: [String] = []
    @State private var goalLine: String?
    @State private var sinceWord: String = ""

    var body: some View {
        ZStack(alignment: .topLeading) {
            Palette.textPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Text("THE WHOLE DISTANCE")
                        .font(Typo.statLabel)
                        .kerning(1.4)
                        .foregroundStyle(Palette.bgPrimary.opacity(0.55))
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.bgPrimary.opacity(0.8))
                            .frame(width: 34, height: 34)
                            .background(
                                Circle().fill(Palette.bgPrimary.opacity(0.10))
                            )
                            .tappableArea()
                    }
                    .buttonStyle(JeniPressable())
                    .accessibilityLabel("done. back to the weight page")
                }
                .padding(.top, 8)

                Spacer(minLength: 0)

                ItalicAccentText(
                    distanceLine,
                    italic: distanceItalic,
                    baseFont: .custom("JeniHeroSerif-Regular", size: 40,
                                      relativeTo: .largeTitle),
                    italicFont: .custom("JeniHeroSerif-Italic", size: 40,
                                        relativeTo: .largeTitle),
                    color: Palette.bgPrimary,
                    alignment: .leading
                )
                .fixedSize(horizontal: false, vertical: true)
                .jeniArrive(arrived, index: 0)

                if let goalLine {
                    Text(goalLine)
                        .font(Typo.body)
                        .foregroundStyle(Palette.bgPrimary.opacity(0.6))
                        .padding(.top, Space.sm)
                        .jeniArrive(arrived, index: 1)
                }

                distanceChart
                    .frame(height: 190)
                    .padding(.top, Space.sectionGap)
                    .jeniArrive(arrived, index: 2)

                HStack {
                    Text(sinceWord)
                    Spacer()
                    Text("today")
                }
                .font(Typo.numeralMeta)
                .foregroundStyle(Palette.bgPrimary.opacity(0.5))
                .padding(.top, 6)
                .jeniArrive(arrived, index: 2)

                Text("from your weigh-ins, the whole way. the marks are where your dose changed.")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.bgPrimary.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.blockGap)
                    .jeniArrive(arrived, index: 3)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.gutter)
        }
        // The scene owns its clock (p67's ink-on-ink lesson): the
        // status bar reads paper on ink while the scene stands.
        .preferredColorScheme(.dark)
        .task {
            compose()
            guard !arrived else { return }
            try? await Task.sleep(nanoseconds: 60_000_000)
            arrived = true
        }
        .accessibilityElement(children: .contain)
    }

    /// The whole record, paper on ink. A dedicated tiny canvas — the
    /// kit chart draws the working palette; this page is its own
    /// scene, one stroke, no wash.
    private var distanceChart: some View {
        Canvas { ctx, size in
            let values = trend.map(\.trendKg)
            guard values.count > 1,
                  let lo = values.min(), let hi = values.max() else { return }
            let span = max(hi - lo, 0.5)
            let pad = span * 0.14
            func point(_ i: Int) -> CGPoint {
                CGPoint(
                    x: size.width * CGFloat(i) / CGFloat(values.count - 1),
                    y: size.height * CGFloat(
                        1 - ((values[i] - lo + pad) / (span + pad * 2))
                    )
                )
            }
            // The dose seams first — context under the line.
            for seam in seams {
                let x = size.width * CGFloat(seam.fraction)
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(
                    line,
                    with: .color(Palette.bgPrimary.opacity(0.28)),
                    style: StrokeStyle(lineWidth: 1, dash: [1, 3])
                )
                let label = ctx.resolve(
                    Text(seam.label)
                        .font(Typo.numeralMeta)
                        .foregroundStyle(Palette.bgPrimary.opacity(0.6))
                )
                let ls = label.measure(in: size)
                let lx = min(max(2, x + 5), size.width - ls.width - 2)
                ctx.draw(label, at: CGPoint(x: lx, y: 2), anchor: .topLeading)
            }
            var path = Path()
            path.move(to: point(0))
            for i in 1..<values.count { path.addLine(to: point(i)) }
            ctx.stroke(
                path,
                with: .color(Palette.bgPrimary),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round,
                                   lineJoin: .round)
            )
            // The now-dot, berry on ink (the ramp's deepest word
            // stays the present, on every line in the app).
            let last = point(values.count - 1)
            let cx = min(max(last.x, 6), size.width - 6)
            let cy = min(max(last.y, 6), size.height - 6)
            ctx.fill(
                Path(ellipseIn: CGRect(x: cx - 6, y: cy - 6, width: 12, height: 12)),
                with: .color(Palette.textPrimary)
            )
            ctx.fill(
                Path(ellipseIn: CGRect(x: cx - 4, y: cy - 4, width: 8, height: 8)),
                with: .color(Palette.roseBerry)
            )
        }
        .accessibilityLabel(
            "your whole weight record, drawn from the start to today. "
            + distanceLine
        )
    }

    private func compose() {
        let cal = Calendar.current
        let samples = WeightSeries.samples(userId: userId, in: modelContext)
        guard let first = samples.first else { return }
        let spanDays = cal.dateComponents(
            [.day], from: cal.startOfDay(for: first.day),
            to: cal.startOfDay(for: .now)
        ).day ?? 0
        trend = WeightWeekReadEngine.trendSeries(
            samples: samples, now: .now,
            windowDays: spanDays + 2, calendar: cal
        )

        let unit = WeightUnit.current
        if let start = trend.first?.trendKg, let end = trend.last?.trendKg {
            let delta = unit.display(fromKg: abs(end - start))
            let word = end <= start ? "down" : "up"
            let month = first.day.formatted(.dateTime.month(.wide))
                .lowercased()
            distanceLine = "\(word) \(WeightLedger.number(delta)) \(unit.label) since \(month)."
            distanceItalic = [word]
            sinceWord = month
        }
        let snap = TodayStateService.snapshot(userId: userId, in: modelContext)
        if let journey = snap.weightJourney, let goal = journey.goalLine() {
            goalLine = "\(goal)."
        }

        // Dose seams by their day's share of the drawn span.
        guard spanDays > 0 else { return }
        let eras = RegimenEras.eras(RegimenEras.versions(
            of: RegimenService.medicationHistory(userId: userId, in: modelContext)
        ))
        guard eras.count >= 2 else { return }
        var out: [(Double, String)] = []
        for i in 1..<eras.count {
            guard let before = eras[i - 1].strengthValue,
                  let after = eras[i].strengthValue,
                  before != after else { continue }
            let day = cal.dateComponents(
                [.day], from: cal.startOfDay(for: first.day),
                to: cal.startOfDay(for: eras[i].startedAt)
            ).day ?? -1
            guard day > 0, day < spanDays else { continue }
            out.append((
                Double(day) / Double(spanDays),
                "\(MedicationProduct.doseWord(after)) \(eras[i].strengthUnit)"
            ))
        }
        seams = out
    }
}
