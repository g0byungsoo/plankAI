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
// number). Saving earns a count-aware confirmation beat — the first
// two weigh-ins get their milestone sentences; after that the beat
// answers with the trend verdict itself (pass 78: the number stays
// standing, "saved" receipts the action, the verdict is the hero) —
// then the sheet excuses itself. A tap skips the dwell.

struct JKWeightRitual: View {
    let startingFromKg: Double
    /// Weigh-ins already on file BEFORE this one — drives the
    /// confirmation copy (first / second / steady-state).
    let priorLoggedCount: Int
    let isUpdatingToday: Bool
    /// v3 keeping chapter: the band whisper replaces the steady-state
    /// sub when the host computes one ("inside your band. steady").
    var bandWhisper: String? = nil
    /// Pass 77 — the morning verdict. Evaluated AFTER the save with
    /// the kg she kept, so the whisper reads the fold that already
    /// contains this morning's number (WeighInReceipt at the host).
    /// nil keeps the standing aphorism.
    var keptWhisper: ((Double) -> String?)? = nil
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
    @State private var keptShown = false
    @State private var finished = false
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
        if reduceMotion {
            keptShown = true
        } else {
            withAnimation(.easeOut(duration: 0.45).delay(0.1)) { keptShown = true }
        }
        // A sentence needs longer than the one-breath receiptDwell —
        // the verdict dwell scales with the words on screen, and a tap
        // anywhere lands the exit early.
        DispatchQueue.main.asyncAfter(deadline: .now() + keptDwell) { finish() }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onDone()
    }

    // MARK: - The kept beat
    //
    // Pass 78 — the verdict is the hero. The old beat swapped the
    // whole canvas for one display-scale word ("done" / "fixed") with
    // the actual morning answer beneath it in caption type — an
    // inverted hierarchy on the product's most repeated moment,
    // filmed as a near-empty sheet (77_evidence 09/10). Now the
    // number she just committed stays standing (cause and effect
    // share one frame), a quiet "saved" receipts the action, and the
    // trend verdict speaks in the serif register.

    private struct KeptCopy {
        let eyebrow: String
        let line: String
        let italic: [String]
        let sub: String?
    }

    private var keptCopy: KeptCopy {
        // Precedence for the verdict: the keeping chapter's band
        // whisper (maintenance has its own verdict) › the trend
        // verdict (computed post-save, so this morning's number is
        // inside the fold) › the aphorism.
        let verdict = bandWhisper
            ?? keptWhisper?(unit.toKg(displayed: displayValue))
            ?? "single days bounce. the 7-day trend is what counts."
        let eyebrow = isUpdatingToday ? "updated" : "saved"
        switch priorLoggedCount {
        case 0:
            return KeptCopy(eyebrow: eyebrow,
                            line: "first weigh-in, logged",
                            italic: ["first"],
                            sub: "one more starts your trend line.")
        case 1:
            return KeptCopy(eyebrow: eyebrow,
                            line: "second weigh-in. your trend line starts now",
                            italic: ["trend line"],
                            sub: "watch the line, not single days.")
        default:
            return KeptCopy(eyebrow: eyebrow, line: verdict,
                            italic: [], sub: nil)
        }
    }

    /// Reading time, not a fixed beat: ~3 words a second, floored at
    /// the one-breath receiptDwell, capped so the ritual stays brisk.
    private var keptDwell: TimeInterval {
        let copy = keptCopy
        let words = copy.line.split(separator: " ").count
            + (copy.sub?.split(separator: " ").count ?? 0)
        return min(3.6, max(JeniMotion.receiptDwell, Double(words) * 0.3))
    }

    private var keptBeat: some View {
        let copy = keptCopy
        return VStack(spacing: 0) {
            Spacer()

            // The number she just kept — same register as the entry's
            // readout, so the phase crossfade reads as the room
            // settling, not a new page.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", displayValue))
                    .font(.custom("JeniHeroSerif-Regular", size: 58))
                    .kerning(-0.5)
                    .foregroundStyle(Palette.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Text(unit.label)
                    .font(.custom("JeniHeroSerif-Italic", size: 24))
                    .foregroundStyle(Palette.accent)
                    .baselineOffset(6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(.horizontal, Space.lg)

            Text(copy.eyebrow)
                .font(Typo.captionTracked)
                .kerning(1.98)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.top, 12)
                .opacity(keptShown ? 1 : 0)

            ItalicAccentText(
                copy.line,
                italic: copy.italic,
                // relativeTo — the verdict is primary content and
                // scales with Dynamic Type (the milestone sub and
                // eyebrow already ride scaling tokens).
                baseFont: .custom("JeniHeroSerif-Regular", size: 21, relativeTo: .title3),
                italicFont: .custom("JeniHeroSerif-Italic", size: 21, relativeTo: .title3),
                color: Palette.textPrimary,
                alignment: .center
            )
            .padding(.top, Space.lg)
            .padding(.horizontal, Space.xl)
            .opacity(keptShown ? 1 : 0)
            .offset(y: keptShown || reduceMotion ? 0 : 8)

            if let sub = copy.sub {
                Text(sub)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                    .padding(.horizontal, Space.xl)
                    .opacity(keptShown ? 1 : 0)
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 0.45).delay(0.3),
                        value: keptShown
                    )
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .accessibilityElement(children: .combine)
    }
}

// p68 — the entry column's measured height (the ruler-safe scroll).
private struct RitualColumnHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
