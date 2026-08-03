import SwiftUI
import HealthKit

// MARK: - Act V — almost hers
// Spec: docs/onboarding_v5/FLOW.md #43-46. The dossier (endowment) →
// the signature moment (consent + disclaimer, one legal beat) → the
// HealthKit ask with its payoff promised → hold-to-build.

struct OV5HerFileScreen: View {
    let flow: OV5Flow

    var body: some View {
        let store = flow.store
        VStack(spacing: 0) {
            Spacer().frame(height: 30)
            OV5Header(title: "her file, ready.", italic: ["file"])

            // The dossier: white shadow-only artifact card. Leaving now
            // means abandoning a concrete object (endowment mechanic).
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(store.name.isEmpty ? "her" : "\(store.name.lowercased())'s")
                        .font(.custom("JeniHeroSerif-Italic", size: 30))
                    Text("file")
                        .font(.custom("JeniHeroSerif-Regular", size: 30))
                    Spacer()
                }
                .foregroundStyle(Palette.textPrimary)
                .padding(.bottom, 14)

                Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.66)
                    .padding(.bottom, 4)

                ForEach(Array(rows(store).enumerated()), id: \.offset) { idx, row in
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.0)
                            .font(Typo.captionTracked)
                            .kerning(1.4)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.cocoaTertiary)
                        Spacer(minLength: 12)
                        Text(row.1)
                            .font(.custom("DMSans-Medium", size: 15))
                            .foregroundStyle(Palette.textPrimary)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, 11)
                    if idx < rows(store).count - 1 {
                        Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.33)
                    }
                }

                HStack {
                    Text("JENI · HER PLAN")
                        .font(Typo.captionTracked)
                        .kerning(1.98)
                        .foregroundStyle(Palette.cocoaTertiary)
                    Spacer()
                    Circle()
                        .fill(Palette.accent)
                        .frame(width: 5, height: 5)
                }
                .padding(.top, 16)
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Palette.bgElevated)
                    .shadow(color: Palette.cocoaPrimary.opacity(0.08), radius: 24, x: 0, y: 8)
            )
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.lg)
            .ov5Beat2()

            Spacer()
        }
        .ov5CTA("this is me") { flow.advance() }
    }

    private func rows(_ store: OV5Store) -> [(String, String)] {
        var out: [(String, String)] = []
        let outcomes: [String: String] = [
            "myself": "feel like myself again", "noise": "quiet the food noise",
            "energy": "steady energy", "clothes": "clothes that fit right",
            "keep": "keep off what i lost",
        ]
        if let o = outcomes[store.outcome] { out.append(("here for", o)) }
        if store.deltaKg >= 1 {
            out.append(("the distance", "\(Int((store.deltaKg * 2.20462).rounded())) lb, honest pace"))
        } else {
            out.append(("the mode", "maintenance rhythm"))
        }
        let identity: [String: String] = [
            "powerful": "the powerful one", "calm": "the calm one",
            "light": "the light one", "strong": "the strong one",
            "radiant": "the radiant one",
        ]
        if let i = identity[store.identityFeeling] { out.append(("becoming", i)) }
        switch store.glp1Status {
        case "current": out.append(("chapter", "alongside the shot"))
        case "past": out.append(("chapter", "the after. keeping it"))
        default: break
        }
        let cuisine = store.cuisines.filter { $0 != "everything" }.sorted().prefix(2)
        if !cuisine.isEmpty { out.append(("her table", cuisine.joined(separator: " + "))) }
        return out
    }
}

struct OV5SignatureScreen: View {
    let flow: OV5Flow
    // Round 2: nothing arrives pre-checked — a signature she didn't
    // make is worthless. UI state is local; commit writes the store
    // explicitly so downstream consent readers get REAL values (their
    // own @AppStorage defaults are true, so an unwritten key would
    // silently read as consent).
    @State private var consentPersonalize = false
    @State private var consentDay2 = false
    @State private var ackMedical = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 44)
            OV5Header(
                title: "sign her in.",
                italic: ["sign"],
                sub: flow.store.name.isEmpty ? nil : "the fine print, \(flow.store.name.lowercased()). all of it honest."
            )

            VStack(spacing: 0) {
                signatureRow(
                    isOn: $consentPersonalize,
                    title: "use my answers to personalize my plan",
                    sub: "the whole point. pace, food, lessons. tuned to your file."
                )
                Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.33)
                signatureRow(
                    isOn: $consentDay2,
                    title: "check on me in the first days",
                    sub: "a gentle nudge or two while the habit is newborn."
                )
                Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.33)
                signatureRow(
                    isOn: $ackMedical,
                    title: "i know this is a plan, not medical advice",
                    sub: "for medication, pregnancy, or health conditions, your clinician leads."
                )
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
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.lg)
            .ov5Beat2()

            Spacer()
        }
        .ov5CTA("signed", isEnabled: ackMedical) {
            // Explicit writes for all three — including false — so the
            // consent keys carry HER choices, never a reader's default.
            flow.store.consentPersonalize = consentPersonalize
            flow.store.consentDay2 = consentDay2
            // The disclaimer acknowledgment folds into this signature
            // moment — same key the reveal's old disclaimer step wrote.
            flow.store.disclaimerAcked = true
            flow.advance()
        }
        .onAppear {
            ackMedical = flow.store.disclaimerAcked
        }
    }

    private func signatureRow(isOn: Binding<Bool>, title: String, sub: String) -> some View {
        Button {
            Haptics.soft()
            withAnimation(Motion.tap) { isOn.wrappedValue.toggle() }
        } label: {
            HStack(alignment: .top, spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(
                            isOn.wrappedValue ? Palette.cocoaPrimary : Palette.cocoaPrimary.opacity(0.28),
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
                .animation(Motion.bloom, value: isOn.wrappedValue)
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.custom("DMSans-Medium", size: 15))
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
    }
}

struct OV5HealthKitScreen: View {
    let flow: OV5Flow
    @State private var requesting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 44)
            OV5Header(
                title: "your steps already count.",
                italic: ["count."],
                sub: "connect health and the plan cites your real week, not a guess."
            )

            // Miniature Health-rings artifact, tilted 2° like a lent
            // object (UI-artifacts-as-objects; zero AI-generation risk).
            VStack(alignment: .leading, spacing: 10) {
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
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Palette.bgElevated)
                    .shadow(color: Palette.cocoaPrimary.opacity(0.07), radius: 18, x: 0, y: 6)
            )
            .rotationEffect(.degrees(-2))
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.xl)
            .ov5Beat2()

            Spacer()
        }
        .ov5CTA(
            requesting ? "connecting…" : "connect health",
            isEnabled: !requesting,
            secondaryLabel: "not now",
            secondaryAction: { flow.advance() }
        ) {
            requestHealthKit()
        }
    }

    private func requestHealthKit() {
        guard HKHealthStore.isHealthDataAvailable() else { flow.advance(); return }
        requesting = true
        let store = HKHealthStore()
        var readTypes: Set<HKObjectType> = []
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { readTypes.insert(steps) }
        if let mass = HKObjectType.quantityType(forIdentifier: .bodyMass) { readTypes.insert(mass) }
        store.requestAuthorization(toShare: [], read: readTypes) { _, _ in
            DispatchQueue.main.async {
                UserDefaults.standard.set(true, forKey: "healthKitStepsRequested")
                requesting = false
                flow.advance()
            }
        }
    }
}

struct OV5HoldToBuildScreen: View {
    let flow: OV5Flow

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ItalicAccentText(
                "everything's here.",
                italic: ["everything's"],
                baseFont: Typo.displayHero,
                italicFont: Typo.displayHeroItalic,
                alignment: .center
            )
            .lineSpacing(Typo.displayHeroLineGap)
            .kerning(-0.4)
            .ov5Beat1()

            Text("\(flow.store.answeredCount) answers. one plan.")
                .font(Typo.teachSub)
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, Space.md)
                .ov5Beat2()

            Spacer()

            HoldToPromiseButton(
                label: "hold to build it",
                onSeal: { flow.advance() },
                holdDuration: 1.2
            )
            .ov5Beat2(extraDelay: 0.1)
        }
        .padding(.bottom, Space.sm)
    }
}
