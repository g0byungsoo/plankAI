import SwiftUI

// MARK: - OV5Ruler
//
// her75's tick-ruler (IMG_6270/6271) as JeniFit's biometric input.
// Full-bleed ticks (the edge bleed IS the luxury tell), fixed center
// indicator, serif digit-roll readout pill riding above, haptic detent
// per unit + a firmer tick on majors. Values live in DISPLAY units —
// the owning screen converts to canonical kg/cm on commit.
//
// `anchor` renders the dusty-rose delta band between a fixed reference
// value (current weight) and the live value (goal), with a small delta
// pill riding the band — the calai11 shaded-magnitude trick in her75
// chrome. Rose is a selected-state color, which is exactly what the
// band is.

struct OV5Ruler: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var majorEvery: Int = 5
    var unitSpacing: CGFloat = 11
    var anchor: Double? = nil
    var majorLabel: ((Double) -> String)? = nil

    @State private var dragBase: Double? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let tickAreaHeight: CGFloat = 92

    var body: some View {
        GeometryReader { geo in
            let centerX = geo.size.width / 2

            ZStack {
                // Delta band (under the ticks).
                if let anchor {
                    let anchorX = centerX + CGFloat((anchor - value) / step) * unitSpacing
                    let bandRect = bandFrame(anchorX: anchorX, centerX: centerX)
                    if bandRect.width > 2 {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Palette.accentSubtle.opacity(0.55))
                            .frame(width: bandRect.width, height: 40)
                            .position(x: bandRect.midX, y: tickAreaHeight / 2)
                    }
                }

                // Ticks.
                Canvas { ctx, size in
                    let midY = tickAreaHeight / 2
                    let visibleUnits = Int(size.width / unitSpacing) + 2
                    let centerUnit = Int((value / step).rounded())
                    for du in -visibleUnits...visibleUnits {
                        let unit = centerUnit + du
                        let v = Double(unit) * step
                        guard v >= range.lowerBound - step / 2,
                              v <= range.upperBound + step / 2 else { continue }
                        let x = centerX + CGFloat((v - value) / step) * unitSpacing
                        guard x > -10, x < size.width + 10 else { continue }
                        let isMajor = unit % majorEvery == 0
                        let h: CGFloat = isMajor ? 34 : 18
                        let w: CGFloat = isMajor ? 2.4 : 1.6
                        let distance = abs(x - centerX) / (size.width / 2)
                        let opacity = max(0.22, 1.0 - Double(distance) * 0.85)
                        let rect = CGRect(x: x - w / 2, y: midY - h / 2, width: w, height: h)
                        ctx.fill(
                            Path(roundedRect: rect, cornerRadius: w / 2),
                            with: .color(Palette.cocoaPrimary.opacity(opacity))
                        )
                        if isMajor, let majorLabel {
                            let text = Text(majorLabel(v))
                                .font(.custom("DMSans-Regular", size: 11))
                                .foregroundColor(Palette.cocoaTertiary)
                            ctx.draw(ctx.resolve(text), at: CGPoint(x: x, y: midY + 30))
                        }
                    }
                }
                .frame(height: tickAreaHeight)

                // Fixed center indicator.
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Palette.cocoaPrimary)
                    .frame(width: 3, height: 44)
                    .position(x: centerX, y: tickAreaHeight / 2)

                // Delta pill riding the band.
                if let anchor, abs(anchor - value) >= step {
                    let anchorX = centerX + CGFloat((anchor - value) / step) * unitSpacing
                    let bandRect = bandFrame(anchorX: anchorX, centerX: centerX)
                    Text(deltaLabel(from: anchor))
                        .font(.custom("DMSans-SemiBold", size: 12))
                        .monospacedDigit()
                        .foregroundStyle(Palette.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Palette.bgElevated))
                        .overlay(Capsule().strokeBorder(Palette.accentSubtle, lineWidth: 1))
                        .position(
                            x: min(max(bandRect.midX, 46), geo.size.width - 46),
                            y: tickAreaHeight + 14
                        )
                        .animation(.none, value: value)
                }
            }
            .contentShape(Rectangle())
            .gesture(drag(centerX: centerX))
        }
        .frame(height: tickAreaHeight + 28)
        // Shared hook for the XCUITest onboarding walker (same id the
        // v4.5 walker's rulerDrag helper targets).
        .accessibilityIdentifier("biometric_ruler")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("value ruler")
        .accessibilityValue("\(Int(value))")
        .accessibilityAdjustableAction { direction in
            let next = direction == .increment ? value + step : value - step
            value = min(max(next, range.lowerBound), range.upperBound)
        }
    }

    private func bandFrame(anchorX: CGFloat, centerX: CGFloat) -> CGRect {
        let minX = min(anchorX, centerX)
        let maxX = max(anchorX, centerX)
        return CGRect(x: minX, y: 0, width: maxX - minX, height: 40)
    }

    private func deltaLabel(from anchor: Double) -> String {
        let delta = value - anchor
        let sign = delta < 0 ? "\u{2212}" : "+"
        return "\(sign)\(Int(abs(delta).rounded()))"
    }

    private func drag(centerX: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { g in
                if dragBase == nil { dragBase = value }
                guard let base = dragBase else { return }
                let rawValue = base - Double(g.translation.width / unitSpacing) * step
                let snapped = (rawValue / step).rounded() * step
                let clamped = min(max(snapped, range.lowerBound), range.upperBound)
                if clamped != value {
                    let crossedMajor = Int((clamped / step).rounded()) % majorEvery == 0
                    if crossedMajor { Haptics.soft() } else { Haptics.tick() }
                    // Snap live — the digit roll in the readout pill is
                    // the motion; the ruler itself must feel mechanical.
                    var t = Transaction(); t.disablesAnimations = true
                    withTransaction(t) { value = clamped }
                }
            }
            .onEnded { g in
                guard let base = dragBase else { return }
                dragBase = nil
                guard !reduceMotion else { return }
                // A short momentum carry toward the predicted end keeps
                // the release feeling physical without free-spinning.
                let predicted = base - Double(g.predictedEndTranslation.width / unitSpacing) * step
                let carried = value + (predicted - value) * 0.25
                let snapped = (carried / step).rounded() * step
                let clamped = min(max(snapped, range.lowerBound), range.upperBound)
                if clamped != value {
                    withAnimation(.interpolatingSpring(stiffness: 180, damping: 26)) {
                        value = clamped
                    }
                }
            }
    }
}

// MARK: - OV5RulerScreen
//
// The shared biometric input composition: serif readout pill above a
// full-bleed ruler, optional unit tabs (hairline underline — her75
// IMG_6268), optional live derived line beneath (real math only; height
// and age render nothing per the provenance rule).

struct OV5RulerScreen<DerivedLine: View>: View {
    let title: String
    var titleItalic: [String] = []
    var trust: String? = nil
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var majorEvery: Int = 5
    var anchor: Double? = nil
    var majorLabel: ((Double) -> String)? = nil
    let readout: (Double) -> String
    var readoutUnit: String? = nil
    var units: [String] = []
    var selectedUnit: Binding<Int>? = nil
    @ViewBuilder var derivedLine: () -> DerivedLine
    var ctaLabel: String = "continue"
    let onContinue: () -> Void

    var body: some View {
        OV5Screen {
            VStack(spacing: 0) {
                OV5Header(title: title, italic: titleItalic)

                if let trust {
                    OV5TrustLine(text: trust)
                        .padding(.top, Space.sm)
                        .ov5Beat2()
                }

                Spacer().frame(height: Space.xl)

                // Readout pill — digit roll, serif numeral, unit italic.
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(readout(value))
                        .font(.custom("JeniHeroSerif-Regular", size: 44))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.18), value: readout(value))
                        .foregroundStyle(Palette.textPrimary)
                    if let readoutUnit {
                        Text(readoutUnit)
                            .font(.custom("JeniHeroSerif-Italic", size: 20))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(Palette.bgElevated)
                        .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 4)
                )
                .ov5Beat2()

                Spacer().frame(height: Space.lg)

                OV5Ruler(
                    value: $value,
                    range: range,
                    step: step,
                    majorEvery: majorEvery,
                    anchor: anchor,
                    majorLabel: majorLabel
                )
                .ov5Beat2(extraDelay: 0.08)

                if !units.isEmpty, let selectedUnit {
                    HStack(spacing: 22) {
                        ForEach(Array(units.enumerated()), id: \.offset) { idx, u in
                            Button {
                                Haptics.tick()
                                selectedUnit.wrappedValue = idx
                            } label: {
                                VStack(spacing: 4) {
                                    Text(u)
                                        .font(.custom("DMSans-Medium", size: 14))
                                        .foregroundStyle(
                                            selectedUnit.wrappedValue == idx
                                                ? Palette.cocoaPrimary : Palette.cocoaTertiary
                                        )
                                    Rectangle()
                                        .fill(selectedUnit.wrappedValue == idx
                                              ? Palette.cocoaPrimary : Color.clear)
                                        .frame(width: 22, height: 1.5)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, Space.md)
                    .ov5Beat2(extraDelay: 0.12)
                }

                derivedLine()
                    .padding(.top, Space.lg)
                    .padding(.horizontal, Space.lg)

                Spacer()
            }
        }
        .ov5CTA(ctaLabel, action: onContinue)
    }
}
