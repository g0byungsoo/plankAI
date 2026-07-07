import SwiftUI
import SwiftData
import Auth
import PlankSync

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
                    eyebrow: "your coach · \(Date.now.formatted(.dateTime.weekday(.wide)).lowercased())"
                )
                .padding(.top, Space.hero)
                .jkBeat1()

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
            // Her file greets a quiet desk open; folds once the
            // conversation is the point.
            fileExpanded = session.entries.count <= 1
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

    // MARK: - Her file (the v5 dossier, alive)

    @State private var fileExpanded = false

    @ViewBuilder
    private var herFileCard: some View {
        let rows = fileRows()
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    Haptics.light()
                    withAnimation(Motion.entranceSoft) { fileExpanded.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Text("her file")
                            .font(Typo.captionTracked)
                            .kerning(1.6)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.cocoaTertiary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(Palette.cocoaTertiary)
                            .rotationEffect(.degrees(fileExpanded ? 180 : 0))
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("her file, \(fileExpanded ? "expanded" : "collapsed")")

                if fileExpanded {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                            JKReceiptRow(
                                lead: row.0,
                                punch: row.1,
                                punchItalic: [],
                                showsRule: idx > 0
                            )
                        }
                    }
                    .padding(.top, 6)
                    .transition(.opacity.combined(with: .offset(y: -4)))
                }
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(Palette.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(Palette.hairlineCocoa, lineWidth: 0.66)
            )
        }
    }

    /// Every row traces to a stored field; absent data = absent row
    /// (the provenance rule — no dossier theater).
    private func fileRows() -> [(String, String)] {
        var rows: [(String, String)] = []
        guard !userId.isEmpty else { return rows }
        let plan = ProgramService.shared.activePlan(userId: userId, in: modelContext)
        rows.append(("the chapter", CohortStore.chapter.fileWord))
        if let plan {
            let tier = IntensityTier(rawValue: plan.intensityTier) ?? .medium
            let word = tier == .soft ? "gentle" : (tier == .medium ? "steady" : "strong")
            rows.append(("the pace", "\(word), \(plan.totalDays) days"))
        }
        let targets = TargetsService.current(userId: userId, in: modelContext)
        if let protein = targets.proteinG, !targets.numericsSuppressed {
            let note = CohortStore.chapter == .onMedication ? "g, lean-mass first" : "g, most days"
            rows.append(("protein floor", "\(protein)\(note)"))
        }
        if CohortStore.chapter == .keeping,
           BandModel.settleWeightKg(plan: plan) != nil {
            rows.append(("the band", "about 3 lb, watched for you"))
        }
        return rows
    }

    // MARK: - Transcript

    private var transcript: some View {
        ScrollViewReader { proxy in
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Space.lg) {
                // v3 — HER FILE: the v5 dossier alive in the app. The
                // desk never opens empty; every row traces to a stored
                // field and taps into the right surface.
                herFileCard

                // v5: the transcript reads as dated letters — a quiet
                // seam opens each prior day's group (the undated echo
                // of a deterministic reading looked like a stutter).
                ForEach(Array(session.entries.enumerated()), id: \.element.id) { idx, entry in
                    if let mark = dayMark(at: idx) {
                        JKQuietSeam(line: mark)
                            .padding(.vertical, 2)
                    }
                    entryView(entry)
                        .id(entry.id)
                }
                if session.lastTurnFailed && !session.isStreaming {
                    Button {
                        session.retryLastTurn()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11, weight: .medium))
                            Text("try again")
                                .font(.custom("DMSans-Medium", size: 13))
                        }
                        .foregroundStyle(Palette.cocoaSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(
                            Capsule().strokeBorder(Palette.hairlineCocoa, lineWidth: 0.66)
                        )
                    }
                    .buttonStyle(JKPress())
                    .transition(.opacity)
                }
                if session.entries.isEmpty {
                    VStack(spacing: 10) {
                        JKEmptyState(
                            line: emptyGreeting.line,
                            italic: emptyGreeting.italic
                        )
                        Text("jeni supports your plan. she's not medical care.")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.cocoaTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
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
        // v3.0 — the transcript stays pinned to the tail while jeni
        // writes: a sentence being written, never content escaping
        // under the composer (the audit frame caught a clipped
        // bubble mid-keyboard).
        .onChange(of: session.entries.last?.text) { _, _ in
            guard session.isStreaming else { return }
            proxy.scrollTo("chat.tail", anchor: .bottom)
        }
        .onChange(of: session.entries.count) { _, _ in
            withAnimation(Motion.entranceSoft) {
                proxy.scrollTo("chat.tail", anchor: .bottom)
            }
        }
        .onChange(of: composerFocused) { _, focused in
            guard focused else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                proxy.scrollTo("chat.tail", anchor: .bottom)
            }
        }
        }
    }

    /// The seam label above a day's letter group: nothing for today's
    /// (the open page), "yesterday", then the weekday date.
    private func dayMark(at idx: Int) -> String? {
        let entry = session.entries[idx]
        let cal = Calendar.current
        if idx > 0,
           cal.isDate(session.entries[idx - 1].createdAt,
                      inSameDayAs: entry.createdAt) {
            return nil
        }
        if cal.isDateInToday(entry.createdAt) {
            return idx == 0 ? nil : "today"
        }
        if cal.isDateInYesterday(entry.createdAt) { return "yesterday" }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMMM d"
        return fmt.string(from: entry.createdAt).lowercased()
    }

    /// Time-aware greeting — the only inputs are the clock and her
    /// name-free register (provenance rule: nothing invented).
    private var emptyGreeting: (line: String, italic: [String]) {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: return ("good morning \u{2665}\u{FE0E} what's on your mind?", ["morning"])
        case 12..<18: return ("what's on your mind this afternoon?", ["afternoon"])
        default: return ("good evening \u{2665}\u{FE0E} what's on your mind?", ["evening"])
        }
    }

    /// v3.0 — the "JENI" kicker marks the START of her turn, not
    /// every paragraph: consecutive jeni entries group like a letter.
    private func showsKicker(before entry: ChatSession.Entry) -> Bool {
        guard let idx = session.entries.firstIndex(where: { $0.id == entry.id }),
              idx > 0 else { return true }
        let prev = session.entries[idx - 1]
        // v5: a new day's letter signs itself again (a date seam
        // between two unsigned jeni groups read as one run-on).
        if !Calendar.current.isDate(prev.createdAt, inSameDayAs: entry.createdAt) {
            return true
        }
        switch prev.kind {
        case .jeni, .careLine: return false
        default: return true
        }
    }

    @ViewBuilder
    private func entryView(_ entry: ChatSession.Entry) -> some View {
        switch entry.kind {
        case .user:
            HStack {
                Spacer(minLength: 56)
                Text(entry.text)
                    .font(.custom("DMSans-Regular", size: 15))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Palette.accentSubtle.opacity(0.42))
                    )
            }
            .transition(.opacity.combined(with: .offset(y: 6)))

        case .jeni, .careLine:
            VStack(alignment: .leading, spacing: 6) {
                if showsKicker(before: entry) {
                    Text("jeni")
                        .font(Typo.captionTracked)
                        .kerning(1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.cocoaTertiary)
                }
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
                .transition(
                    .scale(scale: 0.97, anchor: .bottomLeading)
                        .combined(with: .opacity)
                        .combined(with: .offset(y: 8))
                )
        }
    }

    // MARK: - Tool cards

    @ViewBuilder
    private func toolCardView(entry: ChatSession.Entry, card: ChatSession.ChatToolCard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: ChatToolRouter.glyph(for: card.call.name))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.cocoaPrimary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Palette.accentSubtle.opacity(0.5)))
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
            // v5: starters show whenever she hasn't spoken TODAY —
            // the old count<=1 gate meant one day of history buried
            // them forever.
            if showsStarterChips {
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

    private var showsStarterChips: Bool {
        guard !session.isStreaming else { return false }
        return !session.entries.contains {
            $0.kind == .user && Calendar.current.isDateInToday($0.createdAt)
        }
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

    /// v3.0 voice guard — the model occasionally emits emoji hearts;
    /// the brand heart is the text glyph. Mapped at render time so
    /// the transcript never code-switches.
    private var normalizedText: String {
        text
            .replacingOccurrences(of: "\u{2764}\u{FE0F}", with: "\u{2665}\u{FE0E}")
            .replacingOccurrences(of: "\u{2764}", with: "\u{2665}\u{FE0E}")
            .replacingOccurrences(of: "\u{1F495}", with: "\u{2665}\u{FE0E}")
            .replacingOccurrences(of: "\u{1F497}", with: "\u{2665}\u{FE0E}")
            .replacingOccurrences(of: "\u{1F49E}", with: "\u{2665}\u{FE0E}")
    }

    private var paragraphs: [String] {
        let parts = normalizedText
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? [normalizedText] : parts
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
