import SwiftUI
import SwiftData
import Auth
import PlankSync
import PlankFood

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
            // v11.5 — THE DESK opens the tab when the transcript is
            // quiet (the founder's Lovi reference); the conversation
            // itself takes the page the moment there is one.
            // Quiet = she has not spoken yet. (`entries.isEmpty` was
            // wrong: the session seeds jeni's opening line, so the
            // desk never appeared — caught on the first capture.)
            if deskIsShowing {
                ScrollView(showsIndicators: false) {
                    JeniDesk(
                        starters: stateAwareChips,
                        past: pastDays,
                        awareness: deskAwareness,
                        onStart: { text in
                            session.composerText = text
                            session.send()
                        }
                    )
                }
            } else {
                VStack(spacing: 0) {
                    deskHeader
                    transcript
                }
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
            // v25 E3 QA — THE READ LOOP, on film. The question goes
            // through the real session, the real router and the real
            // stores; only the model's CHOICE of tool is mocked. Pair
            // with --uitest-seed-week for a record worth reading, or
            // run it bare to film the honest-empty answer.
            //
            //   --uitest-chat-read <food-day|food-week|weight|dose|
            //                       program|activity>
            if let i = ProcessInfo.processInfo.arguments
                .firstIndex(of: "--uitest-chat-read"),
               i + 1 < ProcessInfo.processInfo.arguments.count {
                let which = ProcessInfo.processInfo.arguments[i + 1]
                let question: String
                switch which {
                case "food-week": question = "how was my week?"
                case "weight":    question = "am i actually losing?"
                case "dose":      question = "how have my doses been going?"
                case "program":   question = "who decided my plan?"
                case "activity":  question = "am i moving more?"
                default:          question = "what did i eat yesterday?"
                }
                // The door waits for identity: an erased sim resolves
                // anonymous auth late, and a read fired against an
                // empty userId films the wrong answer (the E2 lesson).
                func askWhenReady(_ attempts: Int = 0) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        if !userId.isEmpty {
                            if ProcessInfo.processInfo.arguments
                                .contains("--uitest-seed-week") {
                                FoodBookQASeeder.seedWeek(userId: userId)
                            }
                            session.composerText = question
                            session.send()
                        } else if attempts < 10 {
                            askWhenReady(attempts + 1)
                        }
                    }
                }
                askWhenReady()
            }
            // v25 E3 QA — THE PLAN, CHANGED IN WORDS. Sends a real
            // sentence, gets a real confirm card, and (with
            // --uitest-chat-auto-confirm) taps it, so the film shows
            // the whole chokepoint: proposal → consent → the fact
            // landing as a preference → jeni acknowledging what the
            // store actually kept.
            //
            //   --uitest-chat-propose <steps|remember>
            if let i = ProcessInfo.processInfo.arguments
                .firstIndex(of: "--uitest-chat-propose"),
               i + 1 < ProcessInfo.processInfo.arguments.count {
                let which = ProcessInfo.processInfo.arguments[i + 1]
                let sentence = which == "remember"
                    ? "remember that i don't eat before 11"
                    : "can you make my step goal 6000?"
                func askWhenReady(_ attempts: Int = 0) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        if !userId.isEmpty {
                            session.composerText = sentence
                            session.send()
                            if ProcessInfo.processInfo.arguments
                                .contains("--uitest-chat-auto-confirm") {
                                autoConfirmWhenProposed()
                            }
                        } else if attempts < 10 {
                            askWhenReady(attempts + 1)
                        }
                    }
                }
                askWhenReady()
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

    /// The conversation's own header: the mark, her name, the day.
    /// Lighter than the old masthead — the transcript is the page.
    private var deskHeader: some View {
        HStack(spacing: 10) {
            JeniMark(height: 20, color: Palette.textPrimary)
            VStack(alignment: .leading, spacing: 0) {
                Text("jeni")
                    .font(.custom("JeniHeroSerif-Italic", size: 19, relativeTo: .title3))
                    .foregroundStyle(Palette.textPrimary)
                Text(Date.now.formatted(.dateTime.weekday(.wide)).lowercased())
                    .font(Typo.statLabel)
                    .foregroundStyle(Palette.cocoaTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.blockGap)
        .padding(.bottom, Space.sm)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// Her real days, newest first, each shown by the line she opened
    /// it with. Never a fabricated thread — the transcript's own
    /// grouping, read back (L8).
    private var pastDays: [(day: String, line: String)] {
        let cal = Calendar.current
        var seen: Set<Date> = []
        var out: [(String, String)] = []
        for entry in session.entries.reversed() where entry.kind == .user {
            let day = cal.startOfDay(for: entry.createdAt)
            guard !seen.contains(day), !cal.isDateInToday(day) else { continue }
            seen.insert(day)
            out.append((
                day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).lowercased(),
                entry.text
            ))
            if out.count == 3 { break }
        }
        return out
    }

    /// v25 E3 — the identity line the CA/IL/TX statutes require, in
    /// the place the eye already goes. It replaces the old
    /// "supports your plan — not medical care", which carried a
    /// banned em-dash and disclosed nothing about what jeni is.
    /// Statute outranks the never-say-"AI" style law where they
    /// collide (00_THE_SYSTEM §8); "digital coach, not a person"
    /// is the plainer true sentence and clears both.
    private var disclaimer: some View {
        Text("jeni is a digital coach. not a person, not your clinician.")
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
                        Text("your file")
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
                .accessibilityLabel("your file, \(fileExpanded ? "expanded" : "collapsed")")

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
            // v11.5: collapsed, her file is a LABEL, not a container.
            // The bordered pill around a lone word read as a broken
            // empty component (frame-caught); the surface appears only
            // when there is something inside it to hold.
            .padding(.horizontal, fileExpanded ? Space.md : 0)
            .padding(.vertical, fileExpanded ? 12 : 2)
            .background {
                if fileExpanded {
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .fill(Palette.bgElevated)
                        .shadow(color: Palette.textPrimary.opacity(0.05), radius: 12, y: 5)
                }
            }
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
        // E8.1 — one hour source app-wide (AppClock).
        switch AppClock.hourOfDay {
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
                    // Inside a bubble the text reads LEADING: trailing
                    // alignment is a margin-note grammar, and the
                    // bubble is not a margin.
                    // v11.5: sans in the bubble. Serif italic is a
                    // READING face — set as a message it read as a
                    // book, not a conversation (founder). Her voice is
                    // carried by the rose and the blush now, not by
                    // the slant.
                    Text(entry.text)
                        .font(.custom("DMSans-Regular", size: 16.5, relativeTo: .body))
                        .foregroundStyle(Palette.jeweledRose)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(3)
                        .userBubble(hasTail: tail)
                }

            case .jeni, .careLine:
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 7) {
                        Group {
                            if entry.text.isEmpty && entry.isStreaming {
                                ChatTypingDots()
                            } else {
                                JeniProse(text: entry.text, isLive: entry.isStreaming)
                            }
                        }
                        .jeniBubble(hasTail: tail)

                        // v25 E3 — while she is actually reading the
                        // record, say so. Honest theater: a real
                        // lookup is in flight and it names itself, in
                        // her register, and it leaves when the answer
                        // starts. Nothing renders when nothing is
                        // being read.
                        if entry.isStreaming, let line = session.readingLine {
                            Text(line)
                                .font(Typo.caption)
                                .foregroundStyle(Palette.cocoaTertiary)
                                .padding(.leading, 6)
                                .transition(
                                    .opacity.combined(with: .offset(y: -3))
                                )
                        }
                    }
                    .animation(JeniMotion.settle, value: session.readingLine)
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
                    // v11.5: you TYPE in sans. A serif field read as
                    // a manuscript, not a message box.
                    TextField("talk to jeni…", text: $session.composerText, axis: .vertical)
                        .font(.custom("DMSans-Regular", size: 16.5, relativeTo: .body))
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

    /// The DESK owns the openers when she hasn't spoken; the
    /// composer's rail would repeat them word for word (caught on
    /// the first desk capture).
    private var deskIsShowing: Bool {
        !session.entries.contains(where: { $0.kind == .user })
    }

    private var showsStarterChips: Bool {
        if deskIsShowing { return false }
        return legacyShowsStarterChips
    }

    private var legacyShowsStarterChips: Bool {
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

    #if DEBUG
    /// QA: press "yes" on the first proposed card the moment one
    /// exists. The REAL confirm path runs (jeni proposes, the tap
    /// disposes) — only the finger is synthesized, because
    /// synthesized touches don't reach this simulator reliably.
    private func autoConfirmWhenProposed(_ attempts: Int = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let proposed = session.entries.first { entry in
                if case let .toolCard(card) = entry.kind {
                    return card.status == .proposed
                }
                return false
            }
            if let proposed {
                session.confirmTool(proposed.id)
            } else if attempts < 12 {
                autoConfirmWhenProposed(attempts + 1)
            }
        }
    }
    #endif

    /// v25 E6 THE DESK — what she already has on file, from the SAME
    /// snapshot the starters read. One source, two renderings.
    private var deskAwareness: JeniAwarenessLine {
        guard !userId.isEmpty else {
            return .init(text: "ask me anything about your record. i can read it.", isProof: false)
        }
        let snap = TodayStateService.snapshot(userId: userId, in: modelContext)
        let record = recordDepth
        return JeniDeskAwareness.compose(.init(
            plates: snap.plates.count,
            proteinEatenG: snap.proteinEatenG,
            weighedToday: snap.lastWeighInDaysAgo == 0,
            daysSinceLastOpen: snap.daysSinceLastOpen,
            isCareConnected: UserDefaults.standard.bool(forKey: "care_entitlement_active"),
            yesterdayPlates: record.yesterdayPlates,
            yesterdayProteinG: record.yesterdayProteinG,
            daysOnFile: record.daysOnFile
        ))
    }

    /// Her record BEYOND today, off the same store every food read uses.
    /// The snapshot is a picture of one day; the desk needs to know the
    /// record outlives it (see `JeniDeskAwareness`). One walk of the
    /// in-memory journal — no new engine, no new source of truth.
    private struct RecordDepth {
        var yesterdayPlates = 0
        var yesterdayProteinG = 0
        var daysOnFile = 0
    }

    private var recordDepth: RecordDepth {
        guard !userId.isEmpty else { return RecordDepth() }
        let entries = FoodLogPersister.allEntries(userId: userId)
        guard !entries.isEmpty else { return RecordDepth() }
        var out = RecordDepth()
        let yesterdayKey = TodayStateService.dayKey(
            for: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        )
        var days = Set<String>()
        var yesterdayProtein = 0.0
        for entry in entries {
            let key = TodayStateService.dayKey(for: entry.loggedAt)
            days.insert(key)
            if key == yesterdayKey {
                out.yesterdayPlates += 1
                yesterdayProtein += entry.protein
            }
        }
        // Protein only speaks when it is a real reading — a plate logged
        // with no macro detail must never render "0 g" (the same rule
        // the today branch already keeps).
        out.yesterdayProteinG = Int(yesterdayProtein.rounded())
        out.daysOnFile = days.count
        return out
    }

    private var stateAwareChips: [String] {
        var chips: [String] = []
        let snap = TodayStateService.snapshot(userId: userId, in: modelContext)
        let hour = AppClock.hourOfDay

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
        // v25 E3 — openers the RECORD can answer. Before this era the
        // starters offered only what today's snapshot held, because
        // that was all she could see; the reads mean a question about
        // last week now has a real answer behind it. Each is offered
        // only when the record could carry it, so a starter never
        // walks someone into "i don't have that".
        if snap.hasMedicationRegimen {
            chips.append("how have my doses been going?")
        }
        // THIS GATE WAS INVERTED. It offered "what did i eat yesterday?"
        // exactly when TODAY was empty, without ever checking that
        // yesterday held anything — so the one starter that asks the
        // record a question appeared on the emptiest records and
        // vanished the moment there was something to answer. The comment
        // three lines up claims "a starter never walks someone into 'i
        // don't have that'"; this one walked her straight into it.
        if snap.plates.isEmpty, hour >= 12, recordDepth.yesterdayPlates > 0 {
            chips.append("what did i eat yesterday?")
        }
        if snap.trendIsEstablished {
            chips.append("am i actually losing?")
        }
        // Steady-state fills.
        for fallback in ["what's my plan today?", "i had a rough day", "how was my week?"] {
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
// spans converted to the house italic punch (Fraunces) at render
// time — markers never reach the eye. While live, a soft breathing
// dot rides the tail. v11.5: the base was SERIF here despite this
// comment, which is what made the bubbles read as a book.

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
        // v11.5: the guard was an ENUMERATED LIST (2764, 1F495, 1F497,
        // 1F49E) and every heart outside it reached the eye — a red
        // heart was caught in a live reply. The rule is categorical
        // now: no heart glyph of any colour, weight or variant
        // survives, plus the sparkle-heart family. The brand heart is
        // the text glyph and nothing else (voice law).
        let heartScalars: Set<UInt32> = [
            0x2764,                       // ❤ (any variant selector)
            0x2665,                       // ♥
            0x1F493, 0x1F494, 0x1F495,    // 💓 💔 💕
            0x1F496, 0x1F497, 0x1F498,    // 💖 💗 💘
            0x1F499, 0x1F49A, 0x1F49B,    // 💙 💚 💛
            0x1F49C, 0x1F49D, 0x1F49E,    // 💜 💝 💞
            0x1F49F, 0x1F5A4, 0x1F90D,    // 💟 🖤 🤍
            0x1F90E, 0x1FA75, 0x1FA76,    // 🤎 🩵 🩶
            0x1FA77,                      // 🩷
        ]
        var out = String.UnicodeScalarView()
        // Track the previous SOURCE scalar, not the last output one:
        // the heart is already dropped by then, so an FE0F would find
        // the space before it and survive as an orphan (test-caught).
        var previousWasHeart = false
        for scalar in text.unicodeScalars {
            if heartScalars.contains(scalar.value) {
                previousWasHeart = true
                continue
            }
            if previousWasHeart, scalar.value == 0xFE0F || scalar.value == 0x200D {
                // Stay armed: "❤️‍🔥" is heart + FE0F + ZWJ + fire.
                continue
            }
            previousWasHeart = false
            out.append(scalar)
        }
        return String(out)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    #if DEBUG
    /// Test seam for the voice guard (the render path is private).
    var normalizedTextForTesting: String { normalizedText }
    #endif

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
                // The house punch: italic Fraunces inside sans body,
                // exactly as ItalicAccentText sets it everywhere else.
                output = output + Text(buffer)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16.5))
                    .foregroundColor(Palette.textPrimary)
            } else {
                output = output + Text(buffer)
                    .font(.custom("DMSans-Regular", size: 16.5))
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
