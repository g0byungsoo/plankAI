import SwiftUI
import HealthKit

// MARK: - Structured moments
//
// The consult's non-conversational beats, re-dressed in the v8
// grammar: a written serif lead (fully-arrived, not typed — these are
// instruments, not dialogue), the working surface, one action. Logic
// is ported from OV5 byte-for-byte where it carries contracts
// (consent writes, HealthKit request, gate analytics).

// MARK: - Shared lead header

private struct V8MomentLead: View {
    let line: V8Line
    var sub: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            V8LineText(
                line: line,
                revealed: .max,
                font: V8Type.message,
                italicFont: V8Type.messageItalic,
                color: Palette.textPrimary
            )
            .lineSpacing(V8Type.messageLineGap)
            if let sub {
                Text(sub)
                    .font(.custom("DMSans-Regular", size: 15, relativeTo: .body))
                    .lineSpacing(3)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Signature

struct V8SignatureMoment: View {
    let store: OV5Store
    let onDone: () -> Void

    // Nothing arrives pre-checked — a signature she didn't make is
    // worthless. Explicit writes on commit, including false.
    @State private var consentPersonalize = false
    @State private var consentDay2 = false
    @State private var ackMedical = false
    @State private var arrived = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            V8MomentLead(
                line: V8Line("sign yourself in.", italic: ["sign"]),
                sub: store.name.isEmpty
                    ? "the fine print. all of it honest."
                    : "the fine print, \(store.name.lowercased()). all of it honest."
            )
            .jeniArrive(arrived, index: 0)

            Color.clear.frame(height: Space.lg)

            VStack(spacing: 0) {
                row($consentPersonalize,
                    "use my answers to personalize my plan",
                    "the whole point. pace, food, lessons. tuned to your file.")
                Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.33)
                row($consentDay2,
                    "check on me in the first days",
                    "one or two check-ins while the habit sets. that's all.")
                Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.33)
                row($ackMedical,
                    "i know this is a plan, not medical advice",
                    "for medication, pregnancy, or health conditions, your clinician leads.")
            }
            .padding(.horizontal, Space.sm)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Palette.hairlineCocoa, lineWidth: 1)
            )
            .jeniArrive(arrived, index: 1)

            Spacer(minLength: Space.md)

            JeniPrimaryButton("signed") {
                guard ackMedical else { return }
                store.consentPersonalize = consentPersonalize
                store.consentDay2 = consentDay2
                store.disclaimerAcked = true
                onDone()
            }
            .opacity(ackMedical ? 1 : 0.35)
            .jeniArrive(arrived, index: 2)
        }
        .padding(.horizontal, Space.gutter)
        .padding(.bottom, Space.sm)
        .onAppear { ackMedical = store.disclaimerAcked }
        .task {
            try? await Task.sleep(nanoseconds: 60_000_000)
            arrived = true
        }
    }

    private func row(_ isOn: Binding<Bool>, _ title: String, _ sub: String) -> some View {
        Button {
            Haptics.soft()
            withAnimation(JeniMotion.morph) { isOn.wrappedValue.toggle() }
        } label: {
            HStack(alignment: .top, spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(
                            isOn.wrappedValue
                                ? Palette.cocoaPrimary
                                : Palette.cocoaPrimary.opacity(0.28),
                            lineWidth: 1.5
                        )
                        .frame(width: 24, height: 24)
                    if isOn.wrappedValue {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Palette.cocoaPrimary)
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.textInverse)
                    }
                }
                .animation(JeniMotion.morph, value: isOn.wrappedValue)
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
                        .foregroundStyle(Palette.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(sub)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, Space.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn.wrappedValue ? .isSelected : [])
    }
}

// MARK: - Health connection

struct V8HealthMoment: View {
    let onDone: () -> Void

    @State private var requesting = false
    @State private var arrived = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            V8MomentLead(
                line: V8Line("one connection, and the numbers arrive on their own.", italic: ["on their own."]),
                sub: "steps, sleep, weight. you never type them. the plan cites your real week, not a guess."
            )
            .jeniArrive(arrived, index: 0)

            Color.clear.frame(height: Space.xl)

            // The lent object: a miniature rings artifact, tilted 2°.
            HStack(spacing: 10) {
                ZStack {
                    Circle().stroke(Palette.accentSubtle, lineWidth: 5)
                        .frame(width: 34, height: 34)
                    Circle().trim(from: 0, to: 0.68)
                        .stroke(Palette.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 34, height: 34)
                        .rotationEffect(.degrees(-90))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("steps")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                    Text("7,500 goal")
                        .font(.custom("DMSans-SemiBold", size: 15))
                        .monospacedDigit()
                        .foregroundStyle(Palette.textPrimary)
                }
                Spacer()
                Text("counted for you")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Palette.bgElevated)
                    .shadow(color: Palette.cocoaPrimary.opacity(0.07), radius: 18, x: 0, y: 6)
            )
            .rotationEffect(.degrees(-2))
            .padding(.horizontal, Space.lg)
            .jeniArrive(arrived, index: 1)
            .accessibilityHidden(true)

            Spacer(minLength: Space.md)

            JeniPrimaryButton(requesting ? "connecting…" : "connect health") {
                requestHealthKit()
            }
            .jeniArrive(arrived, index: 2)

            V8SkipLink(label: "not now") { onDone() }
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Space.gutter)
        .padding(.bottom, Space.sm)
        .task {
            try? await Task.sleep(nanoseconds: 60_000_000)
            arrived = true
        }
    }

    private func requestHealthKit() {
        guard HKHealthStore.isHealthDataAvailable() else { onDone(); return }
        guard !requesting else { return }
        requesting = true
        let hk = HKHealthStore()
        var readTypes: Set<HKObjectType> = []
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { readTypes.insert(steps) }
        if let mass = HKObjectType.quantityType(forIdentifier: .bodyMass) { readTypes.insert(mass) }
        hk.requestAuthorization(toShare: [], read: readTypes) { _, _ in
            DispatchQueue.main.async {
                UserDefaults.standard.set(true, forKey: "healthKitStepsRequested")
                Task { @MainActor in
                    BodyMassImportService.shared.noteSystemAskIncludedBodyMass()
                }
                requesting = false
                onDone()
            }
        }
    }
}

// MARK: - The hold

struct V8HoldMoment: View {
    let store: OV5Store
    let onSealed: () -> Void

    @State private var arrived = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            V8LineText(
                line: V8Line("everything's here.", italic: ["everything's"]),
                revealed: .max,
                font: Typo.displayHero,
                italicFont: Typo.displayHeroItalic,
                color: Palette.textPrimary
            )
            .lineSpacing(Typo.displayHeroLineGap)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .jeniArrive(arrived, index: 0)

            Text("\(store.answeredCount) answers. one plan.")
                .font(Typo.teachSub)
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, Space.md)
                .jeniArrive(arrived, index: 1)

            Spacer()

            HoldToPromiseButton(
                label: "hold to build it",
                onSeal: { onSealed() },
                holdDuration: 1.2
            )
            .jeniArrive(arrived, index: 2)
        }
        .padding(.bottom, Space.sm)
        .task {
            try? await Task.sleep(nanoseconds: 60_000_000)
            arrived = true
        }
    }
}

// MARK: - Safety gate (presentation owned by the care cluster)

struct V8SafetyGateMoment: View {
    let onPassed: () -> Void

    var body: some View {
        SafetyGatePresentation(
            onPassed: {
                let d = UserDefaults.standard
                Analytics.track("ov5_gate_outcome", properties: [
                    "mode": d.string(forKey: "program_mode") ?? "loss",
                    "numeric_suppression": d.bool(forKey: "safety_numeric_suppression"),
                ])
                V6Funnel.track("care_safety_completed", once: true, properties: [
                    "mode": d.string(forKey: "program_mode") ?? "loss",
                    "numeric_suppression": d.bool(forKey: "safety_numeric_suppression"),
                ])
                onPassed()
            }
        )
    }
}
