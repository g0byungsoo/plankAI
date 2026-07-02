import SwiftUI

// MARK: - Act I — her arrival
// Spec: docs/onboarding_v5/FLOW.md #2-6. The welcome collage lives in
// OV5Collage.swift.

struct OV5AntiShameScreen: View {
    let flow: OV5Flow
    var body: some View {
        OV5TeachView(
            title: "the last plan failed you. not the other way around.",
            titleItalic: ["you"],
            lead: "no clean slates needed. no earning your way in. we build around your actual life, starting with how you actually eat.",
            ctaLabel: "okay",
            onContinue: { flow.advance() }
        )
    }
}

struct OV5OutcomeScreen: View {
    let flow: OV5Flow
    var body: some View {
        @Bindable var store = flow.store
        OV5Screen {
            OV5Header(title: "what are you here for, mostly?", italic: ["here"])
            OV5SelectList(
                options: [
                    .init(key: "myself", label: "feel like myself again"),
                    .init(key: "noise", label: "quiet the food noise"),
                    .init(key: "energy", label: "steady energy"),
                    .init(key: "clothes", label: "clothes that fit right"),
                    .init(key: "keep", label: "keep off what i lost"),
                ],
                selection: $store.outcome,
                onCommit: { flow.advance() }
            )
        }
    }
}

struct OV5AttributionScreen: View {
    let flow: OV5Flow
    var body: some View {
        @Bindable var store = flow.store
        OV5Screen {
            OV5Header(title: "where'd you find us?", italic: ["find"])
            OV5SelectList(
                options: [
                    .init(key: "tiktok", label: "tiktok", leadingAsset: "onb-logo-tiktok"),
                    .init(key: "instagram", label: "instagram", leadingAsset: "onb-logo-instagram"),
                    .init(key: "friend", label: "a friend told me"),
                    .init(key: "app_store", label: "app store", leadingAsset: "onb-logo-appstore"),
                    .init(key: "google", label: "google", leadingAsset: "onb-logo-google"),
                    .init(key: "other", label: "somewhere else"),
                ],
                selection: $store.acquisitionSource,
                onCommit: { flow.advance() }
            )
        }
    }
}

struct OV5CredibilityScreen: View {
    let flow: OV5Flow
    var body: some View {
        OV5ReceiptView(
            title: "you're in the right place.",
            titleItalic: ["right"],
            sub: "women who've tried everything. women alongside the shot, or after it. women done with all-or-nothing.\nthe plan listens either way.",
            onContinue: { flow.advance() }
        )
    }
}

struct OV5NameScreen: View {
    let flow: OV5Flow
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var store = flow.store
        VStack(spacing: 0) {
            Spacer().frame(height: 44)
            OV5Header(title: "what do we call you?", italic: ["call"])

            TextField("your name", text: $store.name)
                .font(.custom("JeniHeroSerif-Regular", size: 30))
                .foregroundStyle(Palette.textPrimary)
                .tint(Palette.accent)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .focused($focused)
                .onSubmit { commit() }
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.xl)
                .ov5Beat2()

            Rectangle()
                .fill(focused ? Palette.accent.opacity(0.5) : Palette.hairlineCocoa)
                .frame(width: 180, height: 1)
                .padding(.top, 10)
                .animation(Motion.tap, value: focused)
                .ov5Beat2()

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        // Keyboard-attached CTA: safeAreaInset rides the keyboard curve.
        .safeAreaInset(edge: .bottom) {
            JFContinueButton(
                label: "continue",
                action: { commit() },
                isEnabled: !store.name.trimmingCharacters(in: .whitespaces).isEmpty,
                secondaryLabel: "later",
                secondaryAction: {
                    store.name = ""
                    flow.advance()
                }
            )
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.sm)
        }
        .task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            focused = true
        }
    }

    private func commit() {
        flow.store.name = flow.store.name.trimmingCharacters(in: .whitespaces)
        guard !flow.store.name.isEmpty else { return }
        focused = false
        flow.advance()
    }
}
