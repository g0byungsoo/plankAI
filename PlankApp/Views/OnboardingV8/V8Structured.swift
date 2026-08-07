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
            // v20 §6.1 — the consent card separates by fill, not by
            // a drawn edge.
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.bgElevated)
                    .shadow(color: Palette.textPrimary.opacity(0.05), radius: 10, y: 3)
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
    @State private var shownRows = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Every Health type an engine in this app actually consumes.
    /// Adding a row here without a reader would be a promise we don't
    /// keep (L8) — the set matches the authorization request below.
    fileprivate static let reads: [(name: String, source: String)] = [
        ("steps", "your phone counts them"),
        ("sleep", "your watch or phone"),
        ("weight", "when your scale syncs"),
        ("body fat", "if your scale reports it"),
        ("active energy", "what you actually burned"),
        ("resting heart rate", "the recovery signal"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            V8MomentLead(
                line: V8Line("one connection, and the numbers arrive on their own.", italic: ["on their own."]),
                sub: "you never type them. the plan reads your real week, not a guess."
            )
            .jeniArrive(arrived, index: 0)

            Color.clear.frame(height: Space.lg)

            // Everything Jeni actually reads from Health — one row per
            // real type (L8: nothing listed that no engine consumes).
            // Rows land one at a time with a whisper tick.
            VStack(spacing: 0) {
                ForEach(Array(Self.reads.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Circle()
                            .fill(Palette.textPrimary)
                            .frame(width: 5, height: 5)
                            .offset(y: -4)
                        Text(item.name)
                            .font(.custom("DMSans-Medium", size: 16, relativeTo: .body))
                            .foregroundStyle(Palette.textPrimary)
                        Spacer(minLength: Space.sm)
                        Text(item.source)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.cocoaTertiary)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, 11)
                    .opacity(shownRows > idx ? 1 : 0)
                    .offset(y: shownRows > idx ? 0 : 6)
                    .animation(JeniMotion.arrive, value: shownRows)
                    .overlay(alignment: .bottom) {
                        if idx < Self.reads.count - 1 {
                            Rectangle()
                                .fill(Palette.hairlineCocoa)
                                .frame(height: 0.5)
                                .opacity(shownRows > idx ? 1 : 0)
                        }
                    }
                }
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.bgElevated)
                    .shadow(color: Palette.cocoaPrimary.opacity(0.06), radius: 18, x: 0, y: 6)
            )
            .jeniArrive(arrived, index: 1)

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
            guard !reduceMotion else { shownRows = Self.reads.count; return }
            try? await Task.sleep(nanoseconds: 260_000_000)
            for i in 1...Self.reads.count {
                guard !Task.isCancelled else { return }
                shownRows = i
                JeniHaptic.tick()
                try? await Task.sleep(nanoseconds: 90_000_000)
            }
        }
    }

    private func requestHealthKit() {
        guard HKHealthStore.isHealthDataAvailable() else { onDone(); return }
        guard !requesting else { return }
        requesting = true
        let hk = HKHealthStore()
        // The ask matches the list on screen, one for one.
        var readTypes: Set<HKObjectType> = []
        for id: HKQuantityTypeIdentifier in [
            .stepCount, .bodyMass, .bodyFatPercentage,
            .activeEnergyBurned, .restingHeartRate,
        ] {
            if let t = HKObjectType.quantityType(forIdentifier: id) { readTypes.insert(t) }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(sleep)
        }
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
    /// The seal's celebration: confetti falls, then the plan builds.
    @State private var sealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                V8LineText(
                    line: V8Line("everything's here.", italic: ["everything's"]),
                    revealed: .max,
                    font: Typo.displayHero,
                    italicFont: Typo.displayHeroItalic,
                    color: Palette.textPrimary,
                    alignment: .center
                )
                .lineSpacing(Typo.displayHeroLineGap)
                .jeniArrive(arrived, index: 0)

                Text("\(store.answeredCount) answers. one plan.")
                    .font(Typo.teachSub)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Space.md)
                    .jeniArrive(arrived, index: 1)

                Spacer(minLength: 0)

                HoldToPromiseButton(
                    label: "hold to build it",
                    onSeal: { seal() },
                    holdDuration: 1.2
                )
                .jeniArrive(arrived, index: 2)
                .opacity(sealed ? 0 : 1)
                .animation(.easeOut(duration: 0.3), value: sealed)
            }
            // The gutter the ceremony beat never had: the 38pt display
            // line was running off both edges (founder-caught).
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.sm)

            if sealed {
                LottieEffectView(.confettiSoft)
                    .scaleEffect(1.25)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 60_000_000)
            arrived = true
        }
    }

    private func seal() {
        guard !sealed else { return }
        JeniHaptic.swell()
        withAnimation(.easeOut(duration: 0.25)) { sealed = true }
        // Reduce Motion skips the confetti, so it skips its dwell too.
        let dwell: UInt64 = reduceMotion ? 220_000_000 : 1_150_000_000
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: dwell)
            onSealed()
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
