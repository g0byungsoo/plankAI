import SwiftUI

// MARK: - V8Option

struct V8Option: Identifiable, Equatable {
    let id: String
    let label: String
    var sub: String? = nil

    init(_ id: String, _ label: String, sub: String? = nil) {
        self.id = id
        self.label = label
        self.sub = sub
    }
}

// MARK: - V8Input — what arrives after a question finishes typing

enum V8Input: Equatable {
    /// Tall single-select cards (option + optional sub-line).
    case options([V8Option])
    /// Compact single-select — two-column grid of small cards.
    case chips([V8Option])
    /// Multi-select rows with drawn marks + one continue pill.
    case multi([V8Option], min: Int, cta: String, skip: String? = nil)
    /// Inline name entry — a bare serif field in the transcript column.
    case name(placeholder: String, skip: String)
    /// The tick ruler (age / height / weight / goal).
    case ruler(V8RulerSpec)
    /// Quiet weekday list (shot day), skippable.
    case weekday(skip: String)
    /// No input — jeni is talking; the beat auto-advances.
    case statement

    var isStatement: Bool { if case .statement = self { return true }; return false }
    var risesToTop: Bool {
        switch self {
        case .options, .chips, .multi, .ruler, .weekday: return true
        case .name, .statement: return false
        }
    }
}

struct V8RulerSpec: Equatable {
    var range: ClosedRange<Double>
    var step: Double = 1
    var majorEvery: Int = 5
    var initial: Double
    var anchor: Double? = nil
    var unitTabs: [String] = []
    var initialUnit: Int = 0
    var cta: String = "continue"
    static func == (a: V8RulerSpec, b: V8RulerSpec) -> Bool {
        a.range == b.range && a.step == b.step && a.initial == b.initial
            && a.anchor == b.anchor && a.unitTabs == b.unitTabs
    }
    /// Display-value formatting + canonical conversion live with the
    /// beat (closures aren't Equatable; keep them beside the spec).
    var readout: (Double, Int) -> String = { v, _ in "\(Int(v))" }
    var readoutUnit: (Int) -> String? = { _ in nil }
    var majorLabel: ((Double, Int) -> String)? = nil
    /// Re-seed the display value when the unit tab flips.
    var convert: (Double, _ from: Int, _ to: Int) -> Double = { v, _, _ in v }
}

// MARK: - V8AnswerPayload

enum V8AnswerPayload: Equatable {
    case choice(String)
    case set(Set<String>)
    case text(String)
    case value(Double, unit: Int)
    case none
}

// MARK: - Selection card (single-select, tall)

struct V8OptionCard: View {
    let option: V8Option
    let selected: Bool
    let action: () -> Void

    @Environment(\.v8OnInk) private var onInk

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(option.label)
                    .font(.custom("DMSans-Medium", size: 17, relativeTo: .body))
                    .foregroundStyle(selected ? Palette.textInverse : V8InkAware.text(onInk))
                if let sub = option.sub {
                    Text(sub)
                        .font(V8Type.caption)
                        .foregroundStyle(
                            selected
                                ? Palette.textInverse.opacity(0.72)
                                : V8InkAware.secondary(onInk)
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, option.sub == nil ? 18 : 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? Palette.bgInverse : Palette.bgElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                selected ? Color.clear : Palette.hairlineCocoa,
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: Palette.textPrimary.opacity(selected ? 0.10 : 0.045),
                        radius: 14, x: 0, y: 6
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(JeniPressable())
        .animation(JeniMotion.morph, value: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - The single-select stacks

struct V8OptionsList: View {
    let options: [V8Option]
    let selected: String?
    let onPick: (String) -> Void

    var body: some View {
        VStack(spacing: 10) {
            ForEach(options) { opt in
                V8OptionCard(
                    option: opt,
                    selected: selected == opt.id,
                    action: { onPick(opt.id) }
                )
            }
        }
    }
}

struct V8ChipsGrid: View {
    let options: [V8Option]
    let selected: String?
    let onPick: (String) -> Void

    private let cols = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        LazyVGrid(columns: cols, spacing: 10) {
            ForEach(options) { opt in
                V8OptionCard(
                    option: opt,
                    selected: selected == opt.id,
                    action: { onPick(opt.id) }
                )
            }
        }
    }
}

// MARK: - Multi-select rows

struct V8MultiRow: View {
    let option: V8Option
    let isOn: Bool
    /// Fear rows strike through on selection (the carried v5 ritual).
    var strikes: Bool = false
    let toggle: () -> Void

    @Environment(\.v8OnInk) private var onInk

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            V8InkAware.text(onInk).opacity(isOn ? 0 : 0.20),
                            lineWidth: 1.5
                        )
                    Circle()
                        .fill(V8InkAware.text(onInk))
                        .scaleEffect(isOn ? 1 : 0.001)
                    V8CheckStroke()
                        .trim(from: 0, to: isOn ? 1 : 0)
                        .stroke(
                            V8InkAware.surface(onInk),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: 10, height: 10)
                }
                .frame(width: 24, height: 24)
                .animation(JeniMotion.morph, value: isOn)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label)
                        .font(.custom("DMSans-Regular", size: 17, relativeTo: .body))
                        .foregroundStyle(V8InkAware.text(onInk))
                        .overlay(alignment: .leading) {
                            if strikes {
                                // The strike draws itself across the words.
                                Rectangle()
                                    .fill(V8InkAware.text(onInk).opacity(0.7))
                                    .frame(height: 1.5)
                                    .scaleEffect(x: isOn ? 1 : 0.001, anchor: .leading)
                                    .animation(JeniMotion.morph, value: isOn)
                            }
                        }
                    if let sub = option.sub {
                        Text(sub)
                            .font(V8Type.caption)
                            .foregroundStyle(V8InkAware.secondary(onInk))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct V8CheckStroke: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.05))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY - rect.height * 0.08))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.1))
        return p
    }
}

// MARK: - Inline name entry
//
// The reference's bare caret, jeni's serif. No field chrome — the
// answer is written INTO the page.

struct V8NameEntry: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void

    @FocusState private var focused: Bool
    @Environment(\.v8OnInk) private var onInk

    var body: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(placeholder)
                .font(V8Type.message)
                .foregroundStyle(V8InkAware.tertiary(onInk).opacity(0.5))
        )
        .font(V8Type.message)
        .foregroundStyle(V8InkAware.text(onInk))
        .tint(Palette.accent)
        .textInputAutocapitalization(.words)
        .autocorrectionDisabled()
        .submitLabel(.done)
        .focused($focused)
        .onSubmit { onSubmit() }
        .accessibilityLabel("your name")
        .task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            focused = true
        }
    }
}

// MARK: - Weekday list (shot day — quiet, clinical, skippable)

struct V8WeekdayList: View {
    let selected: String?
    let onPick: (String) -> Void

    private static let days: [(String, String)] = [
        ("mon", "monday"), ("tue", "tuesday"), ("wed", "wednesday"),
        ("thu", "thursday"), ("fri", "friday"), ("sat", "saturday"),
        ("sun", "sunday"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Self.days, id: \.0) { key, label in
                Button {
                    onPick(key)
                } label: {
                    HStack {
                        Text(label)
                            .font(.custom("DMSans-Regular", size: 17, relativeTo: .body))
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Circle()
                            .fill(Palette.textPrimary)
                            .frame(width: 7, height: 7)
                            .opacity(selected == key ? 1 : 0)
                    }
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected == key ? .isSelected : [])
            }
        }
    }
}

// MARK: - The ruler, seated in the consult

struct V8RulerInput: View {
    let spec: V8RulerSpec
    @Binding var value: Double
    @Binding var unit: Int
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(spec.readout(value, unit))
                    .font(.custom("JeniHeroSerif-Regular", size: 44))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.18), value: spec.readout(value, unit))
                    .foregroundStyle(Palette.textPrimary)
                if let u = spec.readoutUnit(unit) {
                    Text(u)
                        .font(.custom("JeniHeroSerif-Italic", size: 20))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Capsule().fill(Palette.bgElevated))
            .overlay(Capsule().strokeBorder(Palette.hairlineCocoa, lineWidth: 1))

            Color.clear.frame(height: Space.lg)

            OV5Ruler(
                value: $value,
                range: spec.range,
                step: spec.step,
                majorEvery: spec.majorEvery,
                anchor: spec.anchor,
                majorLabel: spec.majorLabel.map { ml in { v in ml(v, unit) } }
            )

            if spec.unitTabs.count > 1 {
                HStack(spacing: 22) {
                    ForEach(Array(spec.unitTabs.enumerated()), id: \.offset) { idx, u in
                        Button {
                            Haptics.tick()
                            let old = unit
                            unit = idx
                            value = spec.convert(value, old, idx)
                        } label: {
                            VStack(spacing: 4) {
                                Text(u)
                                    .font(.custom("DMSans-Medium", size: 14))
                                    .foregroundStyle(
                                        unit == idx ? Palette.cocoaPrimary : Palette.cocoaTertiary
                                    )
                                Rectangle()
                                    .fill(unit == idx ? Palette.cocoaPrimary : Color.clear)
                                    .frame(width: 22, height: 1.5)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, Space.md)
            }
        }
    }
}

// MARK: - The quiet skip link

struct V8SkipLink: View {
    let label: String
    let action: () -> Void

    @Environment(\.v8OnInk) private var onInk

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.custom("DMSans-Medium", size: 14, relativeTo: .footnote))
                .foregroundStyle(V8InkAware.tertiary(onInk))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
