import SwiftUI
import SwiftData
import Auth

// MARK: - JeniChatView
//
// App v2 (docs/app_v2/05_CHAT.md). The jeni tab. Deliberately not a
// bubble app: jeni's words render as editorial paragraphs on the
// cream (a letter, not a chat log) with serif-italic punch words
// parsed from the model's *asterisk* convention; the user's words
// sit right-aligned in a soft capsule. Tool calls render as hairline
// action cards; mutating ones carry confirm pills.

struct JeniChatView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var auth = AuthService.shared
    @State private var router = AppRouter.shared
    @State private var session = ChatSession()
    @FocusState private var composerFocused: Bool

    private var userId: String { auth.currentUser?.id.uuidString ?? "" }

    var body: some View {
        JKScreenChrome {
            VStack(spacing: 0) {
                JKMasthead(
                    lead: .title("jeni", italic: ["jeni"]),
                    eyebrow: "your coach"
                )
                .padding(.top, Space.hero)
                .jkBeat1()

                disclaimer
                    .padding(.top, Space.sm)

                transcript
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer
        }
        .onAppear {
            session.modelContext = modelContext
            session.userId = userId
            session.loadHistory()
            router.jeniHasUnread = false
            Analytics.track(.jeniChatOpened)
            #if DEBUG
            // QA: exercise streaming + the tool-card flow without
            // typing (pairs with --uitest-mock-chat).
            if ProcessInfo.processInfo.arguments.contains("--uitest-chat-demo"),
               session.entries.count <= 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    session.composerText = "i weighed 74.2 this morning"
                    session.send()
                }
            }
            #endif
        }
        .onChange(of: router.tab) { _, tab in
            guard tab == .jeni else { return }
            router.jeniHasUnread = false
            if let seed = router.pendingChatSeed {
                router.pendingChatSeed = nil
                session.openWithSeed(seed)
            }
        }
    }

    // MARK: - Chrome

    private var disclaimer: some View {
        Text("jeni supports your plan. she's not medical care.")
            .font(Typo.caption)
            .foregroundStyle(Palette.cocoaTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Space.lg)
    }

    // MARK: - Transcript

    private var transcript: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Space.lg) {
                ForEach(session.entries) { entry in
                    entryView(entry)
                        .id(entry.id)
                }
                if session.entries.isEmpty {
                    JKEmptyState(
                        line: "ask her anything about your plan",
                        italic: ["anything"]
                    )
                    .padding(.top, Space.xl)
                }
                Color.clear.frame(height: 8).id("chat.tail")
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.lg)
        }
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.bottom)
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture { composerFocused = false }
    }

    @ViewBuilder
    private func entryView(_ entry: ChatSession.Entry) -> some View {
        switch entry.kind {
        case .user:
            HStack {
                Spacer(minLength: 44)
                Text(entry.text)
                    .font(.custom("DMSans-Regular", size: 15))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Palette.accentSubtle.opacity(0.55))
                    )
            }
            .transition(.opacity.combined(with: .offset(y: 6)))

        case .jeni, .careLine:
            VStack(alignment: .leading, spacing: 6) {
                Text("jeni")
                    .font(Typo.captionTracked)
                    .kerning(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
                if entry.text.isEmpty && entry.isStreaming {
                    JeniThinkingIndicator()
                } else {
                    JeniProse(text: entry.text, isLive: entry.isStreaming)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)

        case .toolCard(let card):
            toolCardView(entry: entry, card: card)
                .transition(.opacity.combined(with: .offset(y: 6)))
        }
    }

    // MARK: - Tool cards

    @ViewBuilder
    private func toolCardView(entry: ChatSession.Entry, card: ChatSession.ChatToolCard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: ChatToolRouter.glyph(for: card.call.name))
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Palette.cocoaSecondary)
                Text(entry.text)
                    .font(.custom("DMSans-Medium", size: 15))
                    .foregroundStyle(Palette.textPrimary)
                Spacer(minLength: 0)
                if card.status == .executed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.stateGood)
                }
            }
            if card.status == .proposed {
                JKConfirmPills(
                    confirmLabel: "yes",
                    cancelLabel: "not now",
                    onConfirm: { session.confirmTool(entry.id) },
                    onCancel: { session.declineTool(entry.id) }
                )
            }
            if card.status == .declined {
                Text("okay, skipped.")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Palette.hairlineCocoa, lineWidth: 0.66)
        )
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 10) {
            if session.entries.count <= 1 && !session.isStreaming {
                suggestionChips
            }
            HStack(spacing: 10) {
                TextField("talk to jeni…", text: $session.composerText, axis: .vertical)
                    .font(.custom("DMSans-Regular", size: 15))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1...4)
                    .focused($composerFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Palette.bgElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Palette.hairlineCocoa, lineWidth: 0.66)
                    )
                    .onSubmit { sendTapped() }

                Button(action: sendTapped) {
                    Image(systemName: session.isStreaming ? "stop.fill" : "arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.textInverse)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(sendEnabled ? Palette.cocoaPrimary : Palette.cocoaPrimary.opacity(0.35)))
                }
                .buttonStyle(JKPress())
                .disabled(!sendEnabled && !session.isStreaming)
                .accessibilityLabel(session.isStreaming ? "stop" : "send")
            }
            .padding(.horizontal, Space.lg)
        }
        .padding(.top, Space.sm)
        .padding(.bottom, Space.sm)
        .background(
            LinearGradient(
                colors: [Palette.bgPrimary.opacity(0), Palette.bgPrimary.opacity(0.94), Palette.bgPrimary],
                startPoint: .top, endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    private var sendEnabled: Bool {
        !session.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendTapped() {
        if session.isStreaming {
            session.stopStreaming()
            return
        }
        guard sendEnabled else { return }
        Analytics.track(.jeniChatMessageSent)
        session.send()
    }

    // v2.5 — chips are STATE-AWARE: the empty composer offers the
    // conversation she actually needs right now, computed from the
    // live snapshot. Max three; provenance rule applies (no chip
    // references data that doesn't exist).
    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(stateAwareChips, id: \.self) { text in
                    chip(text)
                }
            }
            .padding(.horizontal, Space.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var stateAwareChips: [String] {
        var chips: [String] = []
        let snap = TodayStateService.snapshot(userId: userId, in: modelContext)
        let hour = Calendar.current.component(.hour, from: .now)

        if snap.daysSinceLastOpen >= 2 {
            chips.append("i fell off. help me restart")
        }
        if let target = snap.targets.proteinG,
           hour >= 15, snap.proteinEatenG < Int(Double(target) * 0.7) {
            chips.append("what should i eat tonight?")
        }
        if let delta = snap.emaDelta7dKg, delta >= 0.25 {
            chips.append("why is my weight up?")
        }
        if hour >= 20 || CohortStore.isHighStress {
            chips.append("i'm having a craving")
        }
        // Steady-state fills.
        for fallback in ["what's my plan today?", "i had a rough day", "explain my trend"] {
            if chips.count >= 3 { break }
            if !chips.contains(fallback) { chips.append(fallback) }
        }
        return Array(chips.prefix(3))
    }

    private func chip(_ text: String) -> some View {
        Button {
            session.composerText = text
            session.send()
        } label: {
            Text(text)
                .font(.custom("DMSans-Medium", size: 13))
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .overlay(
                    Capsule().strokeBorder(Palette.cocoaPrimary.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(JKPress())
    }
}

// MARK: - JeniProse
//
// Renders jeni's words: DMSans body with the model's *asterisk*
// spans converted to serif italics at render time (markers never
// reach the eye). While live, a soft breathing dot rides the tail.

struct JeniProse: View {
    let text: String
    var isLive: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { idx, para in
                (composed(para) + liveTail(isLast: idx == paragraphs.count - 1))
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    private var paragraphs: [String] {
        let parts = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? [text] : parts
    }

    private func liveTail(isLast: Bool) -> Text {
        guard isLive, isLast else { return Text("") }
        return Text(" ●")
            .font(.system(size: 8))
            .foregroundColor(Palette.accent)
    }

    /// *span* → serif italic; everything else DMSans 16.
    private func composed(_ para: String) -> Text {
        var output = Text("")
        var italic = false
        var buffer = ""
        func flush() {
            guard !buffer.isEmpty else { return }
            if italic {
                output = output + Text(buffer)
                    .font(.custom("JeniHeroSerif-Italic", size: 17))
                    .foregroundColor(Palette.textPrimary)
            } else {
                output = output + Text(buffer)
                    .font(.custom("DMSans-Regular", size: 16))
                    .foregroundColor(Palette.textPrimary)
            }
            buffer = ""
        }
        for ch in para {
            if ch == "*" {
                flush()
                italic.toggle()
            } else {
                buffer.append(ch)
            }
        }
        // Unclosed marker mid-stream: render the tail as plain text.
        if italic && isLive {
            italic = false
        }
        flush()
        return output
    }
}

// MARK: - JeniThinkingIndicator

struct JeniThinkingIndicator: View {
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Palette.cocoaTertiary)
                    .frame(width: 5, height: 5)
                    .opacity(pulse ? 0.9 : 0.3)
                    .animation(
                        reduceMotion ? .none :
                            Motion.breathing
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.18),
                        value: pulse
                    )
            }
        }
        .padding(.vertical, 6)
        .onAppear { pulse = true }
        .accessibilityLabel("jeni is thinking")
    }
}
