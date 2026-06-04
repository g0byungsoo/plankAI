import SwiftUI

/// Sheet for logging today's weight. Presented from the WeightCard on the
/// Log tab; saves a `WeightLogRecord` via the host's `onSave` callback.
///
/// Design language: matches the JeniFit modal pattern — cream sheet with
/// large weight number in Fraunces, kg unit, +/- steppers, and a primary
/// accent CTA at the bottom. No spinner picker — the steppers + direct
/// numpad input feel snappier and avoid the iOS picker's compute cost
/// pattern that bit us in earlier phases.
struct LogWeightSheet: View {
    let startingFromKg: Double
    /// True when today already has a weight row. Drives header + button
    /// copy so the user understands they're updating, not appending. The
    /// host (AnalyticsView) handles the actual update-vs-insert decision
    /// via `todaysWeightLog`; this flag is purely for UI reflection.
    let isUpdatingToday: Bool
    let onSave: (Double) -> Void
    let onCancel: () -> Void

    @State private var weightKg: Double
    @State private var showKeypad = false
    @FocusState private var keypadFocused: Bool
    /// User-facing unit. Default is lb (set in WeightUnit). Storage is
    /// always kg — this just changes what we render + what step deltas
    /// mean.
    @AppStorage("weightUnit") private var weightUnitRaw: String = "lb"
    private var unit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lb }

    init(
        startingFromKg: Double,
        isUpdatingToday: Bool = false,
        onSave: @escaping (Double) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.startingFromKg = startingFromKg
        self.isUpdatingToday = isUpdatingToday
        self.onSave = onSave
        self.onCancel = onCancel
        self._weightKg = State(initialValue: (startingFromKg * 10).rounded() / 10)
    }

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: Space.lg) {
                grabber

                header

                weightDisplay

                steppers

                Spacer()

                saveButton
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.lg)
        }
    }

    private var grabber: some View {
        Capsule()
            .fill(Palette.divider)
            .frame(width: 36, height: 4)
            .padding(.top, 6)
    }

    private var header: some View {
        VStack(spacing: Space.xs) {
            Text(isUpdatingToday ? "update today" : "today's weight")
                .font(Typo.eyebrow).tracking(2)
                .foregroundStyle(Palette.accent)
            Text(isUpdatingToday ? "fix the number." : "how are you feeling?")
                .font(Typo.titleItalic)
                .foregroundStyle(Palette.textPrimary)
        }
        .padding(.top, Space.md)
        // Sticker accent — heart-lock floats off the upper-right of the
        // header. Reads as "your data, your pace".
        .overlay(alignment: .topTrailing) {
            Image(StickerName.heartLock.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(12))
                .offset(x: 0, y: -10)
                .opacity(StickerName.heartLock.style.opacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var weightDisplay: some View {
        VStack(spacing: Space.sm) {
            Button {
                Haptics.light()
                showKeypad = true
                keypadFocused = true
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(unit.display(fromKg: weightKg), specifier: "%.1f")")
                        .font(.custom("Fraunces72pt-SemiBold", size: 64, relativeTo: .largeTitle))
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .foregroundStyle(Palette.textPrimary)
                        .contentTransition(.numericText())
                    Text(unit.label)
                        .font(Typo.heading)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit weight")
            .sheet(isPresented: $showKeypad) {
                keypadSheet
                    .presentationDetents([.height(280)])
            }

            unitToggle
        }
    }

    /// Inline kg ↔ lb toggle. Sits under the headline number so the user
    /// can swap units without diving into Settings. Persists via
    /// `weightUnit` AppStorage so every other weight surface picks it up.
    private var unitToggle: some View {
        HStack(spacing: 0) {
            unitChip(.lb)
            unitChip(.kg)
        }
        .padding(3)
        .background(
            Capsule().fill(Palette.bgElevated)
                .overlay(Capsule().stroke(Palette.divider, lineWidth: 1))
        )
    }

    private func unitChip(_ u: WeightUnit) -> some View {
        let active = unit == u
        return Button {
            Haptics.tick()
            withAnimation(Motion.tap) { weightUnitRaw = u.rawValue }
        } label: {
            Text(u.label)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                .foregroundStyle(active ? Palette.textInverse : Palette.textSecondary)
                .frame(width: 56, height: 28)
                .background(
                    Capsule().fill(active ? Palette.bgInverse : Color.clear)
                )
        }
    }

    private var steppers: some View {
        HStack(spacing: Space.lg) {
            stepperButton(symbol: "minus", delta: -unit.smallStep)
            stepperButton(symbol: "minus.circle.fill", delta: -unit.largeStep, large: true)
            stepperButton(symbol: "plus.circle.fill", delta: +unit.largeStep, large: true)
            stepperButton(symbol: "plus", delta: +unit.smallStep)
        }
    }

    /// Stepper deltas are in DISPLAY units. We convert the current kg
    /// to display, apply the delta + clamp in display space, then
    /// convert back. Keeps the on-screen number stepping by 0.1 / 1.0
    /// in lb (or 0.1 / 1.0 in kg) without translation rounding errors.
    private func stepperButton(symbol: String, delta: Double, large: Bool = false) -> some View {
        Button {
            Haptics.tick()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                let cur = unit.display(fromKg: weightKg)
                let next = ((cur + delta) * 10).rounded() / 10
                let clamped = max(unit.displayRange.lowerBound, min(unit.displayRange.upperBound, next))
                weightKg = unit.toKg(displayed: clamped)
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Palette.accent.opacity(0.18))
                    .frame(width: large ? 56 : 44, height: large ? 56 : 44)
                    .offset(x: 3, y: 3)
                Image(systemName: symbol)
                    .font(.system(size: large ? 26 : 18, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(width: large ? 56 : 44, height: large ? 56 : 44)
                    .background(Palette.bgElevated)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Palette.accent, lineWidth: 1.5)
                    )
            }
            .frame(width: (large ? 56 : 44) + 3, height: (large ? 56 : 44) + 3)
        }
    }

    private var keypadSheet: some View {
        // Two-way binding that reads kg, displays in unit, writes kg
        // back. Keeps the canonical state in kg without duplicating it.
        let displayBinding = Binding<Double>(
            get: { unit.display(fromKg: weightKg) },
            set: { weightKg = unit.toKg(displayed: $0) }
        )
        return VStack(spacing: Space.md) {
            Capsule().fill(Palette.divider).frame(width: 36, height: 4).padding(.top, 6)
            Text("enter weight (\(unit.label))")
                .font(Typo.eyebrow).tracking(2)
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, Space.sm)

            TextField("", value: displayBinding, format: .number.precision(.fractionLength(1)))
                .keyboardType(.decimalPad)
                .focused($keypadFocused)
                .multilineTextAlignment(.center)
                .font(.custom("Fraunces72pt-SemiBold", size: 48))
                .foregroundStyle(Palette.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.md)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Palette.accent.opacity(0.15))
                            .offset(x: 4, y: 4)
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Palette.bgElevated)
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Palette.accent, lineWidth: 1.5)
                    }
                )

            Button {
                // Clamp in display units, store in kg.
                let cur = unit.display(fromKg: weightKg)
                let clamped = max(unit.displayRange.lowerBound, min(unit.displayRange.upperBound, cur))
                weightKg = unit.toKg(displayed: clamped)
                showKeypad = false
            } label: {
                HStack {
                    Text("done")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(Palette.textInverse)
                .padding(.horizontal, 22)
                .frame(height: 60)
                .background(Palette.bgInverse)
                .clipShape(Capsule())
            }
            .padding(.bottom, Space.md)
        }
        .padding(.horizontal, Space.screenPadding)
        .background(Palette.bgPrimary)
        .onAppear {
            Analytics.captureScreen("LogWeight")
            keypadFocused = true
        }
    }

    private var saveButton: some View {
        VStack(spacing: Space.sm) {
            Button {
                Haptics.success()
                Analytics.track(.weightLogged, properties: [
                    "unit": unit.rawValue, "is_update": isUpdatingToday
                ])
                onSave(weightKg)
            } label: {
                HStack {
                    Text(isUpdatingToday ? "update" : "save")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(Palette.textInverse)
                .padding(.horizontal, 22)
                .frame(height: 60)
                .background(Palette.accent)
                .clipShape(Capsule())
            }

            Button(action: onCancel) {
                Text("cancel")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }
}
