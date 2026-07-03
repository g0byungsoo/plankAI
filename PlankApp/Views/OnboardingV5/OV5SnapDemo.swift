import SwiftUI
import PlankFood

// MARK: - OV5SnapDemoScreen
//
// The flow's single luminance inversion: cream → she picks one of three
// staged plates → the photo expands full-bleed (matched geometry) → the
// REAL Metal snapSweep pass runs over it → the plate panel rises with
// the product's exact count-up register → back to cream.
//
// Honesty armor: the plates are OURS and say so ("one of our plates, so
// you can feel it"); the numbers are real values computed for these
// staged meals and rendered with the product's ±range honesty. The demo
// models the anti-shame posture — the pasta gets the same calm read as
// the bowl. Exit writes onb_v5_snap_demo_meal so the commitment ritual
// can prefill "snap your first real meal" as her Day-1 promise.

private struct DemoMeal: Identifiable, Equatable {
    let key: String
    let asset: String
    let title: String
    let kcal: Int          // pre-rounded to 5 (product display rule)
    let range: Int         // ± band
    let protein: Int
    let rows: [(String, Int)]
    /// Vertical shift (fraction of screen height) for the full-bleed
    /// stage. Portrait photos fill by HEIGHT, so alignment alone can't
    /// re-crop — a negative shift lifts a low-sitting plate into the
    /// visible band above the result panel; the vacated strip hides
    /// behind the panel.
    var bleedShift: CGFloat = 0
    var id: String { key }
    static func == (a: DemoMeal, b: DemoMeal) -> Bool { a.key == b.key }
}

struct OV5SnapDemoScreen: View {
    let flow: OV5Flow

    private enum Phase { case pick, scanning, result }
    @State private var phase: Phase = .pick
    @State private var picked: DemoMeal? = nil
    @State private var burstId = 0
    @Namespace private var ns
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Founder photography — real plates from real days (round 2: the
    // demo must taste like the actual product, not stock). Estimates
    // are honest reads of these exact plates, ±band carried like the
    // shipping result card.
    private static let meals: [DemoMeal] = [
        .init(key: "poke", asset: "onb-v5-demo-poke",
              title: "ahi poke bowl", kcal: 500, range: 75, protein: 41,
              rows: [("ahi tuna", 165), ("sushi rice", 300), ("shoyu + limu", 35)],
              bleedShift: -0.22),
        .init(key: "toast", asset: "onb-v5-demo-toast",
              title: "avocado toast, eggs + berries", kcal: 445, range: 65, protein: 19,
              rows: [("sourdough", 100), ("avocado", 120), ("scrambled eggs", 190), ("strawberries", 35)]),
        .init(key: "oysters", asset: "onb-v5-demo-oysters",
              title: "fried oysters + tartar", kcal: 600, range: 110, protein: 22,
              rows: [("fried oysters", 480), ("tartar", 120)]),
    ]

    var body: some View {
        ZStack {
            switch phase {
            case .pick:
                pickStage
                    .transition(.opacity)
            case .scanning, .result:
                scanStage
                    .transition(.opacity)
            }
        }
        .animation(Motion.crossFade, value: phase)
    }

    // MARK: pick

    private var pickStage: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 30)
            OV5Header(
                title: "watch what one photo can tell us.",
                italic: ["tell"],
                sub: "pick one. they're ours, from real days."
            )

            // Capped so the fan rides upper-middle instead of sinking
            // into a dead center (round-2 rhythm pass).
            Spacer(minLength: Space.lg).frame(maxHeight: 110)

            // Three prints, fanned — the ONE place photos tilt (they
            // read as physical prints, not UI).
            HStack(spacing: -34) {
                ForEach(Array(Self.meals.enumerated()), id: \.element.key) { idx, meal in
                    mealCard(meal)
                        .rotationEffect(.degrees(idx == 0 ? -5 : idx == 1 ? 1 : 5.5))
                        .offset(y: idx == 1 ? -18 : 0)
                        .zIndex(idx == 1 ? 2 : 1)
                        .ov5Beat2(extraDelay: Double(idx) * 0.08)
                }
            }
            .padding(.horizontal, Space.md)

            Spacer()

            Button {
                flow.store.snapDemoMeal = "skipped"
                flow.advance()
            } label: {
                Text("skip the practice run")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .underline()
            }
            .buttonStyle(.plain)
            .padding(.bottom, Space.lg)
            .ov5Beat2(extraDelay: 0.3)
        }
    }

    private func mealCard(_ meal: DemoMeal) -> some View {
        Button {
            pick(meal)
        } label: {
            Image(meal.asset)
                .resizable()
                .scaledToFill()
                .frame(width: 150, height: 196)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Palette.cocoaPrimary.opacity(0.15), radius: 13, x: 0, y: 7)
                )
                .matchedGeometryEffect(id: meal.key, in: ns, isSource: phase == .pick)
        }
        .buttonStyle(PressFeedbackStyle())
        .accessibilityIdentifier("demo_meal_\(meal.key)")
        .accessibilityLabel(meal.title)
    }

    private func pick(_ meal: DemoMeal) {
        Haptics.medium()
        picked = meal
        withAnimation(reduceMotion ? Motion.crossFade : Motion.gentleSpring) {
            phase = .scanning
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.8 : 2.0)) {
            guard phase == .scanning else { return }
            Haptics.success()
            burstId += 1
            withAnimation(Motion.gentleSpring) { phase = .result }
        }
    }

    // MARK: scan + result

    @ViewBuilder private var scanStage: some View {
        if let meal = picked {
            ZStack(alignment: .bottom) {
                // Full-bleed photo — the dark frame that makes every
                // cream screen after feel airier.
                GeometryReader { geo in
                    Color.clear
                        .overlay(
                            Image(meal.asset)
                                .resizable()
                                .scaledToFill()
                                .offset(y: geo.size.height * meal.bleedShift)
                        )
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .matchedGeometryEffect(id: meal.key, in: ns, isSource: phase != .pick)
                        .overlay(
                            LinearGradient(
                                colors: [Color.black.opacity(0.22), Color.black.opacity(0.02), Color.black.opacity(0.35)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .overlay(SnapSweepOverlay(isActive: phase == .scanning))
                }
                .ignoresSafeArea()

                if phase == .scanning {
                    VStack(spacing: 6) {
                        Text("reading the plate…")
                            .font(.custom("JeniHeroSerif-Italic", size: 20))
                            .foregroundStyle(Color.white.opacity(0.92))
                        Text("calm, not judging")
                            .font(Typo.caption)
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    .padding(.bottom, 120)
                    .transition(.opacity)
                }

                if phase == .result {
                    resultPanel(meal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                FoodResultExplosion(triggerId: burstId)
                    .allowsHitTesting(false)
            }
        }
    }

    private func resultPanel(_ meal: DemoMeal) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Palette.cocoaPrimary.opacity(0.16))
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 12)

            Text(meal.title)
                .font(.custom("DMSans-Medium", size: 14))
                .kerning(0.2)
                .foregroundStyle(Palette.textSecondary)
                .padding(.bottom, 4)

            // The product's exact hero register (SnapResultView).
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                CountUpNumber(
                    target: meal.kcal,
                    fontName: "JeniHeroSerif-Regular",
                    italicFontName: "JeniHeroSerif-Italic",
                    size: 54,
                    color: Palette.textPrimary
                )
                VStack(alignment: .leading, spacing: 0) {
                    Text("calories")
                        .font(.custom("JeniHeroSerif-Italic", size: 19))
                        .foregroundStyle(Palette.textSecondary)
                    Text("\u{00B1} \(meal.range)")
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundStyle(Palette.textPrimary.opacity(0.45))
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
            }

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                (Text("\(meal.protein)")
                    .font(.custom("JeniHeroSerif-Regular", size: 30))
                + Text("g")
                    .font(.custom("JeniHeroSerif-Italic", size: 15))
                    .foregroundStyle(Palette.accent))
                    .monospacedDigit()
                Text("protein")
                    .font(.custom("JeniHeroSerif-Italic", size: 17))
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                if isGlp1Cohort {
                    Text("your number now")
                        .font(.custom("JeniHeroSerif-Italic", size: 14))
                        .foregroundStyle(Palette.stateGood)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Palette.stateGood.opacity(0.12)))
                }
            }
            .padding(.top, 6)

            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.33)
                .padding(.vertical, 12)

            ForEach(meal.rows, id: \.0) { row in
                HStack {
                    Text(row.0)
                        .font(.custom("DMSans-Regular", size: 14))
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Text("\(row.1)")
                        .font(.custom("DMSans-Regular", size: 13))
                        .monospacedDigit()
                        .foregroundStyle(Palette.cocoaTertiary)
                }
                .padding(.vertical, 4)
            }

            ItalicAccentText(
                jeniLine,
                italic: jeniLineItalic,
                baseFont: .custom("DMSans-Regular", size: 14),
                italicFont: .custom("JeniHeroSerif-Italic", size: 16),
                color: Palette.textSecondary,
                alignment: .leading
            )
            .padding(.top, 12)

            JFContinueButton(label: "day one, you do this for real", action: {
                flow.store.snapDemoMeal = picked?.key ?? ""
                Analytics.track("ov5_demo_completed", properties: [
                    "meal": picked?.key ?? "",
                    "glp1": flow.store.glp1Status.isEmpty ? "unset" : flow.store.glp1Status,
                ])
                flow.advance()
            })
            .padding(.top, 16)
        }
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.md)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 28, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 28,
                style: .continuous
            )
            .fill(Palette.bgPrimary)
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var isGlp1Cohort: Bool {
        flow.store.isCurrentGlp1 || flow.store.isPastGlp1
    }

    private var jeniLine: String {
        if isGlp1Cohort {
            return "see the protein line? that's the one we watch together."
        }
        return "it fits. no drama either way."
    }
    private var jeniLineItalic: [String] {
        isGlp1Cohort ? ["protein"] : ["fits"]
    }
}
