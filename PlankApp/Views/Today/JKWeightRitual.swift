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
//   first weigh-in  → "first morning, logged"
//   second          → "two mornings. your line begins"
//   after           → "kept — the line does the thinking."
// then the sheet excuses itself.

struct JKWeightRitual: View {
    let startingFromKg: Double
    /// Weigh-ins already on file BEFORE this one — drives the
    /// confirmation copy (first / second / steady-state).
    let priorLoggedCount: Int
    let isUpdatingToday: Bool
    /// v3 keeping chapter: the band whisper replaces the steady-state
    /// sub when the host computes one ("inside your band. steady").
    var bandWhisper: String? = nil
    /// v25 §34 — the same instrument, re-aimed at a PAST weigh-in.
    /// "this morning's number" is true for the daily ritual and false
    /// for a correction to last Tuesday, and a screen that names the
    /// wrong day while she edits a weight is the exact class of defect
    /// this line of work exists to close. nil keeps the daily copy
    /// byte-identical.
    var titleOverride: String? = nil
    /// v25 §34 — the destructive half of the repair, offered only when
    /// the host has a row to remove. A quiet third line under the CTA
    /// pair: never a swipe (undiscoverable), never a trash glyph
    /// (the design law has no icon buttons), and never above the fold.
    var removeLabel: String? = nil
    var onRemove: (() -> Void)? = nil
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

    /// p68 — reachability at accessibility sizes. `tallFixed` is the
    /// documented canvas exception (the ruler needs the room it has),
    /// but the sheet had NO scroll and no `.large` escape, so at AX
    /// sizes "not now" and the remove link fell off the bottom with no
    /// way to reach them. The p48 consult pattern: ONE ScrollView,
    /// disabled unless the measured column actually overflows — at
    /// standard sizes the ruler keeps its drag untouched.
    @State private var entryColumnHeight: CGFloat = 0

    private var entry: some View {
        GeometryReader { viewport in
            ScrollView {
                entryColumn
                    .frame(minHeight: viewport.size.height)
                    .background(
                        GeometryReader { g in
                            Color.clear.preference(
                                key: RitualColumnHeightKey.self,
                                value: g.size.height
                            )
                        }
                    )
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDisabled(entryColumnHeight <= viewport.size.height + 1)
            .onPreferenceChange(RitualColumnHeightKey.self) {
                entryColumnHeight = $0
            }
        }
    }

    private var entryColumn: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("the trend check")
                    .font(Typo.captionTracked)
                    .kerning(1.98)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(titleOverride
                     ?? (isUpdatingToday ? "fix this morning's number" : "this morning's number"))
                    .font(.custom("JeniHeroSerif-Regular", size: 22))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    // Frame review 2026-08-13: at AX5 this truncated to
                    // "this mornin…" for want of a wrap.
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 20)
            .padding(.horizontal, Space.lg)

            Spacer(minLength: 6)

            // The readout — serif digits roll; the unit sits italic.
            //
            // THE NUMBER NEVER TRUNCATES. Frame review caught "124.0"
            // rendering as "12…" at AX5 on the daily weigh-in — the
            // second most-used action in the product, showing an
            // ellipsis where the weight she is about to save should be.
            // It shrinks to fit; it never hides a digit.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", displayValue))
                    .font(.custom("JeniHeroSerif-Regular", size: 58))
                    .kerning(-0.5)
                    .foregroundStyle(Palette.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.15), value: displayValue)
                Text(unit.label)
                    .font(.custom("JeniHeroSerif-Italic", size: 24))
                    .foregroundStyle(Palette.accent)
                    .baselineOffset(6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(.horizontal, Space.lg)
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
            .buttonStyle(JKPress())

            Spacer(minLength: 4)

            JFContinueButton(
                label: isUpdatingToday ? "update it" : "keep it",
                action: keep,
                firesHaptic: false,
                secondaryLabel: "not now",
                secondaryAction: onCancel
            )

            if let removeLabel, let onRemove {
                Button {
                    Haptics.soft()
                    onRemove()
                } label: {
                    Text(removeLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.cocoaTertiary)
                        .padding(.vertical, 10)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                }
                .buttonStyle(JKPress())
                .accessibilityHint("removes this weigh-in from your record")
            }
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
        .buttonStyle(JKPress())
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
                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                    .fill(Palette.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
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
        JeniHaptic.record()   // p58 — one hand for a record landing
        Analytics.track(.weightLogged, properties: [
            "unit": unit.rawValue, "is_update": isUpdatingToday,
        ])
        onSave(unit.toKg(displayed: displayValue))
        withAnimation(reduceMotion ? nil : Motion.entranceSoft) { phase = .kept }
        DispatchQueue.main.asyncAfter(deadline: .now() + JeniMotion.receiptDwell) { onDone() }
    }

    // MARK: - The kept beat

    private var keptLine: (line: String, italic: [String], sub: String) {
        if isUpdatingToday && priorLoggedCount > 1 {
            return ("fixed", [],
                    "single days bounce. the 7-day trend is what counts.")
        }
        switch priorLoggedCount {
        case 0:
            return ("first weigh-in, logged", ["first"],
                    "one more starts your trend line.")
        case 1:
            return ("second weigh-in. your trend line starts now", ["trend line"],
                    "watch the line, not single days.")
        default:
            return ("done", [],
                    bandWhisper ?? "single days bounce. the 7-day trend is what counts.")
        }
    }

    private var keptBeat: some View {
        // p63 — the beat's composition became the kit's named receipt
        // (JeniReceiptBeat); this ritual is its reference call site.
        let copy = keptLine
        return JeniReceiptBeat(
            line: copy.line, italic: copy.italic, sub: copy.sub,
            shown: phase == .kept
        )
    }
}

// p68 — the entry column's measured height (the ruler-safe scroll).
private struct RitualColumnHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
