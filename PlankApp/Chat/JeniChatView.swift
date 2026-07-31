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
            // typing (pairs with --uitest-mock-chat). Guarded at FIRE
            // time by transcript content — the old count guard raced
            // re-fired onAppears and seeded a duplicate exchange per
            // visit (mission-3 panel bug #2).
            if ProcessInfo.processInfo.arguments.contains("--uitest-chat-demo") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    let demo = "i weighed 74.2 this morning"
                    guard !session.entries.contains(where: {
                        $0.kind == .user && $0.text == demo
                    }) else { return }
                    session.composerText = demo
                    session.send()
                }
            }
            // QA: the rich inline cards (plan / trend) without typing.
            // No history guard — these fire on every launch so the
            // walker can re-shoot against persisted transcripts.
            if ProcessInfo.processInfo.arguments.contains("--uitest-chat-plan-demo") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    session.composerText = "what's my plan today?"
                    session.send()
                }
            }
            if ProcessInfo.processInfo.arguments.contains("--uitest-chat-trend-demo") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    session.composerText = "explain my trend"
                    session.send()
                }
            }
            // QA: pinned mid-stream entry — the shimmer holds still
            // for the camera.
            if ProcessInfo.processInfo.arguments.contains("--uitest-chat-shimmer") {
                session.seedShimmerDemo()
            }
            if ProcessInfo.processInfo.arguments.contains("--uitest-chat-typing") {
                session.seedTypingDemo()
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
        // The received buzz — a soft tap the moment her reply lands
        // (stream true → false), the receiving half of the iMessage feel.
        .onChange(of: session.isStreaming) { wasStreaming, nowStreaming in
            if wasStreaming && !nowStreaming { Haptics.soft() }
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
            LazyVStack(alignment: .leading, spacing: 4) {
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
                    entryView(entry, at: idx)
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
            // Bubbles pop in on a bounce when a message lands; the tail
            // group re-tails without a jump (count-scoped so per-token
            // stream text never re-animates the whole run).
            .animation(.spring(response: 0.36, dampingFraction: 0.74), value: session.entries.count)
        }
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.bottom)
        .scrollDismissesKeyboard(.interactively)
        // Mission-3 panel bug #1: scrolled turns bled a sliver into
        // the masthead — the transcript now fades under it (the same
        // scrim law Today's masthead carries).
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [Palette.bgPrimary, Palette.bgPrimary.opacity(0)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 24)
            .allowsHitTesting(false)
        }
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
        case 5..<12: return ("good morning. what's on your mind?", ["morning"])
        case 12..<18: return ("what's on your mind this afternoon?", ["afternoon"])
        default: return ("good evening. what's on your mind?", ["evening"])
        }
    }

    // MARK: - Bubble grouping
    //
    // iMessage groups a run of same-sender messages: tight spacing, one
    // tail on the last of the run. `sender` collapses the kinds into a
    // group key; a day boundary always breaks a run so a new day's first
    // message re-tails.

    private func groupKey(_ e: ChatSession.Entry) -> Int {
        switch e.kind {
        case .user: return 0
        case .toolCard: return 2
        default: return 1   // jeni + careLine read as one voice
        }
    }

    private func isFirstInGroup(at idx: Int) -> Bool {
        guard idx > 0 else { return true }
        let prev = session.entries[idx - 1], cur = session.entries[idx]
        if !Calendar.current.isDate(prev.createdAt, inSameDayAs: cur.createdAt) { return true }
        return groupKey(prev) != groupKey(cur)
    }

    private func isLastInGroup(at idx: Int) -> Bool {
        let entries = session.entries
        guard idx < entries.count - 1 else { return true }
        let next = entries[idx + 1], cur = entries[idx]
        if !Calendar.current.isDate(next.createdAt, inSameDayAs: cur.createdAt) { return true }
        return groupKey(next) != groupKey(cur)
    }

    @ViewBuilder
    private func entryView(_ entry: ChatSession.Entry, at idx: Int) -> some View {
        let tail = isLastInGroup(at: idx)
        let fromUser = groupKey(entry) == 0
        // A run of same-sender bubbles sits tight; a change of voice (or a
        // new day) opens a breath above the first bubble.
        let topGap: CGFloat = isFirstInGroup(at: idx) ? Space.sm : 3

        Group {
            switch entry.kind {
            case .user:
                HStack(spacing: 0) {
                    // Mission 3 (03_EDITORIAL.md §5): the measures
                    // narrow so the gutter reads as a white river.
                    Spacer(minLength: 96)
                    // Her words answer as marginalia — italic serif
                    // in her rose ink, never a mirrored column.
                    Text(entry.text)
                        .font(.custom("JeniHeroSerif-Italic", size: 17, relativeTo: .body))
                        .foregroundStyle(Palette.jeweledRose)
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(3)
                        .userBubble(hasTail: tail)
                }

            case .jeni, .careLine:
                HStack(spacing: 0) {
                    Group {
                        if entry.text.isEmpty && entry.isStreaming {
                            ChatTypingDots()
                        } else {
                            JeniProse(text: entry.text, isLive: entry.isStreaming)
                        }
                    }
                    .jeniBubble(hasTail: tail)
                    Spacer(minLength: 84)
                }

            case .toolCard(let card):
                toolCardView(entry: entry, card: card)
            }
        }
        .padding(.top, topGap)
        .transition(
            {
                if case .toolCard = entry.kind {
                    return .scale(scale: 0.97, anchor: .bottomLeading)
                        .combined(with: .opacity).combined(with: .offset(y: 8))
                }
                return .bubblePop(fromUser: fromUser)
            }()
        )
    }

    // MARK: - Tool cards

    /// Rich tools render their content inline (the answer IS the
    /// card); everything else renders the compact action card.
    @ViewBuilder
    private func toolCardView(entry: ChatSession.Entry, card: ChatSession.ChatToolCard) -> some View {
        switch card.call.name {
        case "show_today_plan":
            JKChatPlanCard(createdAt: entry.createdAt, userId: userId)
        case "show_weight_trend":
            JKChatTrendCard(userId: userId)
        default:
            actionCard(entry: entry, card: card)
        }
    }

    @ViewBuilder
    private func actionCard(entry: ChatSession.Entry, card: ChatSession.ChatToolCard) -> some View {
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
            // Mission 3 (03_EDITORIAL.md §5): the composer is a bare
            // baseline — she writes ON a hairline that inks rose
            // while she writes, and the send mark is the rose seal
            // (capsule field + grey disc dead; one grammar with the
            // evening journal).
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    TextField("talk to jeni…", text: $session.composerText, axis: .vertical)
                        .font(.custom("JeniHeroSerif-Regular", size: 17, relativeTo: .body))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1...4)
                        .focused($composerFocused)
                        .onSubmit { sendTapped() }

                    Button(action: sendTapped) {
                        Image(systemName: session.isStreaming ? "stop.fill" : "sparkle")
                            .symbolVariant(session.isStreaming ? .none : .fill)
                            .font(.system(size: 17))
                            .foregroundStyle(
                                (sendEnabled || session.isStreaming)
                                    ? Palette.jeweledRose
                                    : Palette.cocoaPrimary.opacity(0.28)
                            )
                            .scaleEffect((sendEnabled || session.isStreaming) ? 1 : 0.88)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6),
                                       value: sendEnabled || session.isStreaming)
                            .frame(width: 34, height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(JKPress())
                    .disabled(!sendEnabled && !session.isStreaming)
                    .accessibilityLabel(session.isStreaming ? "stop" : "send")
                }
                Rectangle()
                    .fill(composerFocused ? Palette.jeweledRose : Palette.hairlineCocoa)
                    .frame(height: composerFocused ? 1 : 0.5)
                    .animation(Motion.entranceSoft, value: composerFocused)
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
            Haptics.light()
            session.stopStreaming()
            return
        }
        guard sendEnabled else { return }
        // The send pop — the bubble launches off the composer.
        Haptics.light()
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
        .modifier(JeniStreamShimmer(active: isLive))
    }

    /// v3.0 voice guard — the model occasionally emits emoji hearts;
    /// the brand heart is the text glyph. Mapped at render time so
    /// the transcript never code-switches.
    private var normalizedText: String {
        text
            .replacingOccurrences(of: "\u{2764}\u{FE0F}", with: "")
            .replacingOccurrences(of: "\u{2764}", with: "")
            .replacingOccurrences(of: "\u{1F495}", with: "")
            .replacingOccurrences(of: "\u{1F497}", with: "")
            .replacingOccurrences(of: "\u{1F49E}", with: "")
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

    /// *span* → serif italic; everything else the serif letter voice
    /// (mission 3, 03_EDITORIAL.md §5: jeni reads as a letter, not an
    /// interface reply — two voices, one cocoa, one rose).
    private func composed(_ para: String) -> Text {
        var output = Text("")
        var italic = false
        var buffer = ""
        func flush() {
            guard !buffer.isEmpty else { return }
            if italic {
                output = output + Text(buffer)
                    .font(.custom("JeniHeroSerif-Italic", size: 17.5))
                    .foregroundColor(Palette.textPrimary)
            } else {
                output = output + Text(buffer)
                    .font(.custom("JeniHeroSerif-Regular", size: 17.5))
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

// MARK: - JeniStreamShimmer
//
// v5.1 — while jeni writes, a slow sheen travels through the glyphs
// themselves (the text masks the highlight): no box, no skeleton,
// just the letters catching light. Wall-clock phase via TimelineView
// so streaming re-renders never restart it; the band parks off-frame
// at both ends of the loop so the wrap is invisible. Gone the frame
// the stream ends; gone entirely under reduce-motion.

private struct JeniStreamShimmer: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let period: TimeInterval = 2.4

    func body(content: Content) -> some View {
        content.overlay(
            Group {
                if active && !reduceMotion {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                        GeometryReader { geo in
                            let phase = timeline.date.timeIntervalSinceReferenceDate
                                .truncatingRemainder(dividingBy: Self.period) / Self.period
                            let band = geo.size.width * 0.45
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: Palette.accent.opacity(0.4), location: 0.5),
                                    .init(color: .clear, location: 1)
                                ],
                                startPoint: .leading, endPoint: .trailing
                            )
                            .frame(width: band)
                            .offset(x: -band + (geo.size.width + band * 2) * phase)
                        }
                    }
                    .mask(content)
                }
            }
            .allowsHitTesting(false)
        )
    }
}
// JeniThinkingIndicator retired 1.1.5 — the loading state is now
// ChatTypingDots inside a jeni bubble (see ChatBubbles.swift).
