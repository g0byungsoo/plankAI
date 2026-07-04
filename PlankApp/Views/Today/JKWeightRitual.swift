import SwiftUI

// MARK: - JKWeightRitual
//
// App v3.0 (docs/app_v2/31). The weigh-in as a calm ritual — replaces
// the pre-v2 LogWeightSheet (program-pink background, offset-shadow
// stepper circles, italic-Fraunces CTA, keypad-sheet-in-a-sheet: the
// last old-JeniFit input surface reachable in v2).
//
// The input IS the onboarding's signature interaction: the OV5 tick
// ruler with haptic detents — the same gesture she learned on day
// zero, now her daily instrument. No steppers, no nested sheets, no
// keyboard by default (a quiet "type it instead" fallback exists for
// accessibility and preference).
//
// Emotional contract: entry is judgment-free (no delta, no color
// states — the TREND reads the week, this sheet only receives the
// number). Saving earns a count-aware confirmation beat:
//   first weigh-in  → "first morning, logged ♥"
//   second          → "two mornings. your line begins ♥"
//   after           → "kept ♥ — the line does the thinking."
// then the sheet excuses itself.

struct JKWeightRitual: View {
    let startingFromKg: Double
    /// Weigh-ins already on file BEFORE this one — drives the
    /// confirmation copy (first / second / steady-state).
    let priorLoggedCount: Int
    let isUpdatingToday: Bool
    let onSave: (Double) -> Void
    /// Fired after the confirmation beat — the host dismisses here,
    /// NOT in onSave, so the beat is never cut short.
    let onDone: () -> Void
    let onCancel: () -> Void

    private enum Phase { case entry, kept }
    @State private var phase: Phase = .entry
    @State private var displayValue: Double = 0
    @State private var typing = false
    @FocusState private var typeFieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("weightUnit") private var weightUnitRaw: String = "lb"
    private var unit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lb }

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            switch phase {
            case .entry: entry
            case .kept: keptBeat
            }
        }
        .onAppear {
            displayValue = unit.display(fromKg: startingFromKg)
        }
    }

    // MARK: - Entry

    private var entry: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("the trend check")
                    .font(Typo.captionTracked)
                    .kerning(1.98)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
                Text(isUpdatingToday ? "fix this morning's number" : "this morning's number")
                    .font(.custom("JeniHeroSerif-Regular", size: 22))
                    .foregroundStyle(Palette.textPrimary)
            }
            .padding(.top, 20)

            Spacer(minLength: 6)

            // The readout — serif digits roll; the unit sits italic.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", displayValue))
                    .font(.custom("JeniHeroSerif-Regular", size: 58))
                    .kerning(-0.5)
                    .foregroundStyle(Palette.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.15), value: displayValue)
                Text(unit.label)
                    .font(.custom("JeniHeroSerif-Italic", size: 24))
                    .foregroundStyle(Palette.accent)
                    .baselineOffset(6)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("weight \(String(format: "%.1f", displayValue)) \(unit.label)")

            unitToggle
                .padding(.top, 10)

            Spacer(minLength: 8)

            if typing {
                typeField
                    .padding(.horizontal, Space.xl)
                    .transition(.opacity)
            } else {
                OV5Ruler(
                    value: $displayValue,
                    range: unit.displayRange,
                    step: 0.1,
                    majorEvery: 10,
                    majorLabel: { v in "\(Int(v.rounded()))" }
                )
                .transition(.opacity)
            }

            Button {
                Haptics.light()
                withAnimation(Motion.entranceSoft) { typing.toggle() }
                typeFieldFocused = typing
            } label: {
                Text(typing ? "back to the ruler" : "type it instead")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.cocoaTertiary)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            JFContinueButton(
                label: isUpdatingToday ? "update it" : "keep it",
                action: keep,
                firesHaptic: false,
                secondaryLabel: "not now",
                secondaryAction: onCancel
            )
        }
    }

    private var unitToggle: some View {
        HStack(spacing: 18) {
            unitWord(.lb)
            Rectangle()
                .fill(Palette.hairlineCocoa)
                .frame(width: 0.66, height: 12)
            unitWord(.kg)
        }
    }

    private func unitWord(_ u: WeightUnit) -> some View {
        let active = unit == u
        return Button {
            guard !active else { return }
            Haptics.tick()
            let kg = unit.toKg(displayed: displayValue)
            weightUnitRaw = u.rawValue
            displayValue = u.display(fromKg: kg)
        } label: {
            Text(u.label)
                .font(.custom(active ? "Fraunces72pt-SemiBoldItalic" : "DMSans-Regular", size: 14))
                .foregroundStyle(active ? Palette.cocoaPrimary : Palette.cocoaTertiary)
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(u.label)\(active ? ", selected" : "")")
    }

    private var typeField: some View {
        TextField("", value: $displayValue, format: .number.precision(.fractionLength(1)))
            .keyboardType(.decimalPad)
            .focused($typeFieldFocused)
            .multilineTextAlignment(.center)
            .font(.custom("JeniHeroSerif-Regular", size: 34))
            .foregroundStyle(Palette.textPrimary)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Palette.hairlineCocoa, lineWidth: 0.66)
            )
            .onSubmit { clampTyped() }
            .onChange(of: typeFieldFocused) { _, focused in
                if !focused { clampTyped() }
            }
    }

    private func clampTyped() {
        let r = unit.displayRange
        displayValue = min(max(displayValue, r.lowerBound), r.upperBound)
    }

    // MARK: - Keep

    private func keep() {
        clampTyped()
        Haptics.success()
        Analytics.track(.weightLogged, properties: [
            "unit": unit.rawValue, "is_update": isUpdatingToday,
        ])
        onSave(unit.toKg(displayed: displayValue))
        withAnimation(reduceMotion ? nil : Motion.entranceSoft) { phase = .kept }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { onDone() }
    }

    // MARK: - The kept beat

    private var keptLine: (line: String, italic: [String], sub: String) {
        if isUpdatingToday && priorLoggedCount > 1 {
            return ("fixed \u{2665}\u{FE0E}", [],
                    "the line does the thinking, not today's number.")
        }
        switch priorLoggedCount {
        case 0:
            return ("first morning, logged \u{2665}\u{FE0E}", ["first"],
                    "one more morning and your line begins.")
        case 1:
            return ("two mornings. your line begins \u{2665}\u{FE0E}", ["begins"],
                    "from here we read the line, never one day.")
        default:
            return ("kept \u{2665}\u{FE0E}", [],
                    "the line does the thinking, not today's number.")
        }
    }

    private var keptBeat: some View {
        let copy = keptLine
        return VStack(spacing: 10) {
            ItalicAccentText(
                copy.line,
                italic: copy.italic,
                baseFont: .custom("JeniHeroSerif-Regular", size: 26),
                italicFont: .custom("JeniHeroSerif-Italic", size: 26),
                color: Palette.textPrimary,
                alignment: .center
            )
            .opacity(phase == .kept ? 1 : 0)
            .offset(y: phase == .kept ? 0 : 8)
            .animation(.easeOut(duration: 0.45), value: phase)

            Text(copy.sub)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, Space.xl)
                .opacity(phase == .kept ? 1 : 0)
                .animation(.easeOut(duration: 0.45).delay(0.3), value: phase)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
