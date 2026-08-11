import Foundation
import SwiftData
import SwiftUI
import PlankSync

// MARK: - ChatSession
//
// App v2 (docs/app_v2/05_CHAT.md). The conversation state machine:
// send → safety screen → stream tokens → tool calls → (confirm) →
// continuation → persist. One instance lives behind the jeni tab.
//
// Transcript truth lives in SwiftData (ChatMessageRecord); the
// in-memory `messages` array mirrors it plus the live streaming
// entry. Mutating tools (log_weight, set_reminder_hour) render a
// confirm card and only execute on her tap — jeni proposes, she
// disposes.

@MainActor
@Observable
final class ChatSession {

    // MARK: - Display model

    struct Entry: Identifiable, Equatable {
        enum Kind: Equatable {
            case user
            case jeni
            case careLine                 // safety response (local)
            case toolCard(ChatToolCard)
        }
        let id: String
        var kind: Kind
        var text: String
        var isStreaming: Bool = false
        let createdAt: Date
    }

    struct ChatToolCard: Equatable {
        let call: ChatToolCall
        var status: Status
        enum Status: Equatable { case proposed, confirmed, declined, executed }
        static func == (lhs: ChatToolCard, rhs: ChatToolCard) -> Bool {
            lhs.call == rhs.call && lhs.status == rhs.status
        }
    }

    private(set) var entries: [Entry] = []
    private(set) var isStreaming = false
    /// v3.0 — set when the last turn ended in the friendly error line;
    /// drives the quiet "try again" affordance under the transcript.
    private(set) var lastTurnFailed = false
    /// v25 E3 — what jeni is looking up right now ("reading your
    /// plates"), rendered under the typing bubble. Honest theater: a
    /// real lookup is happening and it names itself.
    private(set) var readingLine: String?
    var composerText = ""

    // Injected by the host view.
    @ObservationIgnored var modelContext: ModelContext?
    @ObservationIgnored var userId: String = ""
    @ObservationIgnored var transport: ChatTransporting = ChatSession.defaultTransport()

    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var pendingToolContinuation: ChatToolCall?

    /// v25 E3 — how many read round-trips one user turn may spend.
    /// Two is enough for "how did last week compare to the week
    /// before" and small enough that a confused model cannot spin.
    static let maxReadRounds = 2
    @ObservationIgnored private var readRoundsThisTurn = 0

    static func defaultTransport() -> ChatTransporting {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitest-mock-chat") {
            return MockChatTransport()
        }
        #endif
        return LiveChatTransport(
            supabaseURL: SupabaseConfig.url,
            anonKey: SupabaseConfig.anonKey,
            tokenProvider: { await AuthService.shared.freshAccessToken() }
        )
    }

    // MARK: - History

    func loadHistory() {
        guard let modelContext, !userId.isEmpty else { return }
        let uid = userId
        #if DEBUG
        // v25 E6 — `--uitest-wipe-chat`. The desk's RESTING state (the
        // one a new user meets, and the only state where the awareness
        // line does its job) was unfilmable: the deterministic QA
        // account carries a stored conversation, so the view always
        // resolved to the transcript. Same shape as --uitest-wipe-food.
        if ProcessInfo.processInfo.arguments.contains("--uitest-wipe-chat") {
            let all = (try? modelContext.fetch(
                FetchDescriptor<ChatMessageRecord>(
                    predicate: #Predicate { $0.userId == uid }
                )
            )) ?? []
            for record in all { modelContext.delete(record) }
            try? modelContext.save()
            entries = []
            return
        }
        #endif
        var descriptor = FetchDescriptor<ChatMessageRecord>(
            predicate: #Predicate { $0.userId == uid },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 60
        let records = ((try? modelContext.fetch(descriptor)) ?? []).reversed()
        entries = records
            .filter { !$0.body.hasPrefix(Self.hiddenPrefix) }   // seeds stay off-screen
            .map { record in
                Entry(
                    id: record.id,
                    kind: kind(for: record),
                    text: record.body,
                    createdAt: record.createdAt
                )
            }
        #if DEBUG
        healDuplicatedDemoForQA()
        #endif
        seedDailyBriefIfNeeded()
    }

    #if DEBUG
    /// QA-store heal (mission-3 panel bug #2): earlier builds' demo
    /// seed raced re-fired onAppears and persisted the same exchange
    /// more than once. On QA launches, keep the first "i weighed…"
    /// pair and delete the echoes — records included, so walker
    /// captures stop inheriting the stutter. QA-only: real users can
    /// legitimately repeat themselves.
    private func healDuplicatedDemoForQA() {
        guard ProcessInfo.processInfo.arguments.contains("--uitest-inapp-qa"),
              let modelContext else { return }
        let demo = "i weighed 74.2 this morning"
        var seenDemo = false
        var dropIds = Set<String>()
        var i = 0
        while i < entries.count {
            let entry = entries[i]
            if entry.kind == .user, entry.text == demo {
                if seenDemo {
                    dropIds.insert(entry.id)
                    // Its reply (the next jeni entry, if adjacent) echoes too.
                    if i + 1 < entries.count, entries[i + 1].kind == .jeni {
                        dropIds.insert(entries[i + 1].id)
                    }
                } else {
                    seenDemo = true
                }
            }
            i += 1
        }
        guard !dropIds.isEmpty else { return }
        entries.removeAll { dropIds.contains($0.id) }
        for id in dropIds { deletePersisted(id: id) }
        try? modelContext.save()
    }
    #endif

    #if DEBUG
    /// QA: pin a long jeni entry mid-stream so the live shimmer can
    /// be photographed (pairs with --uitest-chat-shimmer).
    func seedShimmerDemo() {
        entries.append(Entry(
            id: "qa-user-ctx", kind: .user,
            text: "i had a rough day", createdAt: .now.addingTimeInterval(-2)
        ))
        entries.append(Entry(
            id: "qa-shimmer",
            kind: .jeni,
            text: "okay. first, nothing is broken. one loud day doesn't move a trend line, it just feels like it does.\n\ntonight: water, an early night if you can get it. tomorrow's plan is already set, and it's a *gentle* one",
            isStreaming: true,
            createdAt: .now
        ))
    }

    /// QA: pin an empty streaming jeni entry so the typing bubble holds
    /// still for the camera (pairs with --uitest-chat-typing).
    func seedTypingDemo() {
        entries.append(Entry(
            id: "qa-user-typing", kind: .user,
            text: "what should i eat tonight?", createdAt: .now.addingTimeInterval(-2)
        ))
        entries.append(Entry(
            id: "qa-typing", kind: .jeni, text: "",
            isStreaming: true, createdAt: .now
        ))
    }
    #endif

    private func kind(for record: ChatMessageRecord) -> Entry.Kind {
        switch record.role {
        case "user": return .user
        case "tool":
            let name = record.toolName ?? ""
            let args = (record.toolPayload.flatMap {
                try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
            }) ?? [:]
            return .toolCard(ChatToolCard(
                call: ChatToolCall(id: record.id, name: name, arguments: args),
                status: .executed
            ))
        default: return .jeni
        }
    }

    /// Jeni opens each day with the brief — deterministic, local,
    /// instant. The chat's first message costs nothing.
    func seedDailyBriefIfNeeded() {
        guard let modelContext, !userId.isEmpty else { return }
        let dayKey = TodayStateService.dayKey()
        let alreadySeeded = entries.contains {
            $0.kind == .jeni && Calendar.current.isDateInToday($0.createdAt)
        }
        guard !alreadySeeded else { return }
        let snapshot = TodayStateService.snapshot(userId: userId, in: modelContext)
        guard snapshot.isEnrolled else { return }
        let brief = snapshot.brief
        // v3: the letter opens with the WHOLE reading (line + the
        // thread's second sentence) — same engine as Today, so the
        // desk and the tab never disagree.
        let text = [brief.line, brief.second]
            .compactMap { $0 }
            .joined(separator: " ")
        // v5: letters don't repeat themselves — when the engine's
        // deterministic reading matches yesterday's seeded line
        // verbatim (a held trend does this), the desk stays quiet
        // rather than stuttering the same sentence twice in a row.
        let lastJeniText = entries.last(where: { $0.kind == .jeni })?.text
        guard text != lastJeniText else { return }
        appendPersisted(role: "jeni", text: text, dayKey: dayKey)
    }

    /// A coach-line tap arrives with a seed — jeni expands on it as
    /// her next message (goes through the model for a real answer).
    func openWithSeed(_ seed: String?) {
        guard let seed, !seed.isEmpty, !isStreaming else { return }
        sendSystemSeed(seed)
    }

    // MARK: - Send

    func send() {
        let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }
        // v3.0 — double-send protection: an identical message inside
        // 3s is a stutter (double-tap, submit+tap), not intent.
        if let lastUser = entries.last(where: { $0.kind == .user }),
           lastUser.text == text,
           Date.now.timeIntervalSince(lastUser.createdAt) < 3 {
            composerText = ""
            return
        }
        composerText = ""
        Haptics.soft()

        // Safety pre-filter: crisis turns never reach the model.
        let screen = ChatSafety.screen(text)
        appendPersisted(role: "user", text: text, dayKey: TodayStateService.dayKey())
        if screen.blocked, let care = screen.careResponse {
            appendPersisted(role: "jeni", text: care, dayKey: TodayStateService.dayKey())
            Analytics.track(.jeniChatCareRouted)
            return
        }

        readRoundsThisTurn = 0
        stream(toolResults: [])
    }

    /// v3.0 — the failed turn's second chance: drop the error line
    /// (screen + store) and re-ask the model. The wire window still
    /// ends with her original message, so nothing needs retyping.
    func retryLastTurn() {
        guard lastTurnFailed, !isStreaming else { return }
        if let last = entries.last, last.kind == .jeni {
            let failedId = last.id
            entries.removeLast()
            deletePersisted(id: failedId)
        }
        lastTurnFailed = false
        readRoundsThisTurn = 0
        Haptics.soft()
        stream(toolResults: [])
    }

    private func deletePersisted(id: String) {
        guard let modelContext else { return }
        let d = FetchDescriptor<ChatMessageRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if let record = (try? modelContext.fetch(d))?.first {
            modelContext.delete(record)
            try? modelContext.save()
        }
    }

    private func sendSystemSeed(_ seed: String) {
        // The seed rides as a quiet user turn so the model answers it;
        // rendered as jeni-context, not shown as her words.
        appendPersisted(
            role: "user",
            text: seed,
            dayKey: TodayStateService.dayKey(),
            hidden: true
        )
        readRoundsThisTurn = 0
        stream(toolResults: [])
    }

    // MARK: - Streaming

    private func stream(
        toolResults: [ChatToolResult],
        reusingEntryId: String? = nil
    ) {
        guard let modelContext, !userId.isEmpty else { return }
        isStreaming = true
        lastTurnFailed = false

        // A read continuation streams INTO the bubble that was already
        // typing, so the user sees one answer arriving, not a card
        // followed by a second bubble.
        let streamingId: String
        if let reusingEntryId,
           entries.contains(where: { $0.id == reusingEntryId }) {
            streamingId = reusingEntryId
        } else {
            streamingId = UUID().uuidString
            entries.append(Entry(
                id: streamingId, kind: .jeni, text: "", isStreaming: true, createdAt: .now
            ))
        }

        let wire = wireWindow()
        let context = CoachContextAssembler.assemble(userId: userId, in: modelContext)

        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            var collected = ""
            var toolCalls: [ChatToolCall] = []
            do {
                for try await event in transport.stream(
                    messages: wire, contextJSON: context, toolResults: toolResults
                ) {
                    if Task.isCancelled { break }
                    switch event {
                    case .token(let t):
                        collected += t
                        self.lastTurnFailed = false
                        self.updateStreaming(id: streamingId, text: collected)
                    case .toolCall(let call):
                        toolCalls.append(call)
                    case .done:
                        break
                    case .error(let message):
                        if collected.isEmpty {
                            collected = message
                            self.lastTurnFailed = true
                        }
                        self.updateStreaming(id: streamingId, text: collected)
                    }
                }
            } catch {
                if collected.isEmpty {
                    collected = "jeni couldn't answer just now. try again in a moment."
                    self.lastTurnFailed = true
                    self.updateStreaming(id: streamingId, text: collected)
                }
            }
            self.finishStreaming(id: streamingId, finalText: collected, toolCalls: toolCalls)
        }
    }

    private func updateStreaming(id: String, text: String) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx].text = text
    }

    private func finishStreaming(id: String, finalText: String, toolCalls: [ChatToolCall]) {
        isStreaming = false
        readingLine = nil

        // v25 E3 — THE READ ROUND TRIP.
        //
        // Before this era, a non-confirming tool executed and the turn
        // simply ENDED ("navigation tools act immediately; no
        // continuation needed"). That was survivable when every tool
        // opened a screen; it made a read tool impossible, because the
        // model would never see what came back.
        //
        // Reads now resolve here and the SAME bubble keeps typing:
        // execute → continuation → jeni answers from the record.
        let reads = toolCalls.filter { ChatToolRouter.isRead($0.name) }
        if !reads.isEmpty, readRoundsThisTurn < Self.maxReadRounds {
            readRoundsThisTurn += 1
            // Anything she wrote BEFORE deciding to look something up
            // is a preamble; the answer replaces it.
            if let idx = entries.firstIndex(where: { $0.id == id }) {
                entries[idx].text = ""
                entries[idx].isStreaming = true
            }
            readingLine = ChatToolRouter.readingLine(for: reads[0])
            let results = reads.map { call in
                ChatToolResult(
                    callId: call.id,
                    name: call.name,
                    arguments: call.arguments,
                    result: ChatToolRouter.execute(
                        call, userId: userId, modelContext: modelContext
                    )
                )
            }
            // Any ACT tools in the same turn still get their cards
            // after the answer lands.
            let acts = toolCalls.filter { !ChatToolRouter.isRead($0.name) }
            stream(toolResults: results, reusingEntryId: id)
            for call in acts { handleToolCall(call) }
            return
        }

        if let idx = entries.firstIndex(where: { $0.id == id }) {
            if finalText.isEmpty && !toolCalls.isEmpty {
                entries.remove(at: idx)   // tool-only turn: the card is the message
            } else if finalText.isEmpty && toolCalls.isEmpty {
                // A read that came back empty and left her with
                // nothing to say. Rather than a blank bubble, own it.
                entries[idx].isStreaming = false
                entries[idx].text = "i don't have enough in your record to answer that yet."
                persist(role: "jeni", text: entries[idx].text, id: id)
            } else {
                entries[idx].isStreaming = false
                entries[idx].text = finalText
                persist(role: "jeni", text: finalText, id: id)
            }
        }
        for call in toolCalls where !ChatToolRouter.isRead(call.name) {
            handleToolCall(call)
        }
        // A read that arrived past the round cap is dropped rather
        // than executed: the answer she already wrote stands.
    }

    func stopStreaming() {
        streamTask?.cancel()
        isStreaming = false
        if let idx = entries.lastIndex(where: { $0.isStreaming }) {
            entries[idx].isStreaming = false
            if !entries[idx].text.isEmpty {
                persist(role: "jeni", text: entries[idx].text, id: entries[idx].id)
            }
        }
    }

    // MARK: - Tools

    private func handleToolCall(_ call: ChatToolCall) {
        // A confirmable tool whose arguments don't parse would render
        // a card with no sentence on it. Drop it rather than show a
        // button that promises nothing.
        if ChatToolRouter.needsConfirmation(call.name),
           call.name == "propose_program_fact",
           JeniActTools.parseProposal(call.arguments) == nil {
            return
        }
        let card = ChatToolCard(
            call: call,
            status: ChatToolRouter.needsConfirmation(call.name) ? .proposed : .executed
        )
        entries.append(Entry(
            id: call.id,
            kind: .toolCard(card),
            text: ChatToolRouter.cardLabel(for: call),
            createdAt: .now
        ))
        if !ChatToolRouter.needsConfirmation(call.name) {
            // Navigation tools act immediately; no continuation needed.
            ChatToolRouter.execute(call, userId: userId, modelContext: modelContext)
            persistTool(call)
        }
        Analytics.track(.jeniChatToolCalled, properties: ["tool": call.name])
    }

    func confirmTool(_ entryId: String) {
        guard
            let idx = entries.firstIndex(where: { $0.id == entryId }),
            case .toolCard(var card) = entries[idx].kind
        else { return }
        card.status = .executed
        entries[idx].kind = .toolCard(card)
        Haptics.success()
        let result = ChatToolRouter.execute(
            card.call, userId: userId, modelContext: modelContext
        )
        persistTool(card.call)
        // One continuation round-trip so jeni acknowledges the action.
        // The result is what ACTUALLY happened (a refused proposal
        // comes back refused), so she can never claim a change the
        // store declined.
        stream(toolResults: [ChatToolResult(
            callId: card.call.id,
            name: card.call.name,
            arguments: card.call.arguments,
            result: result
        )])
    }

    func declineTool(_ entryId: String) {
        guard
            let idx = entries.firstIndex(where: { $0.id == entryId }),
            case .toolCard(var card) = entries[idx].kind
        else { return }
        card.status = .declined
        entries[idx].kind = .toolCard(card)
        Haptics.soft()
    }

    // MARK: - Persistence

    /// Hidden turns (chat seeds) reach the model but not the eye —
    /// they persist with a marker prefix stripped at render time.
    private static let hiddenPrefix = "\u{200B}seed:"

    private func appendPersisted(role: String, text: String, dayKey: String, hidden: Bool = false) {
        let id = UUID().uuidString
        if !hidden {
            entries.append(Entry(
                id: id,
                kind: role == "user" ? .user : .jeni,
                text: text,
                createdAt: .now
            ))
        }
        persist(role: role, text: hidden ? Self.hiddenPrefix + text : text, id: id)
    }

    private func persist(role: String, text: String, id: String) {
        guard let modelContext, !userId.isEmpty, !text.isEmpty else { return }
        let record = ChatMessageRecord(
            id: id,
            userId: userId,
            role: role,
            body: text,
            dayKey: TodayStateService.dayKey()
        )
        modelContext.insert(record)
        try? modelContext.save()
    }

    private func persistTool(_ call: ChatToolCall) {
        guard let modelContext, !userId.isEmpty else { return }
        let payload = try? JSONSerialization.data(withJSONObject: call.arguments)
        let record = ChatMessageRecord(
            id: call.id,
            userId: userId,
            role: "tool",
            body: ChatToolRouter.cardLabel(for: call),
            toolName: call.name,
            toolPayload: payload,
            dayKey: TodayStateService.dayKey()
        )
        modelContext.insert(record)
        try? modelContext.save()
    }

    /// Trailing window for the wire — visible turns plus hidden
    /// seeds, minus tool cards and care lines.
    private func wireWindow() -> [ChatWireMessage] {
        guard let modelContext, !userId.isEmpty else { return [] }
        let uid = userId
        var descriptor = FetchDescriptor<ChatMessageRecord>(
            predicate: #Predicate { $0.userId == uid && $0.role != "tool" },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 12
        let records = ((try? modelContext.fetch(descriptor)) ?? []).reversed()
        return records.map { record in
            var body = record.body
            if body.hasPrefix(Self.hiddenPrefix) {
                body = String(body.dropFirst(Self.hiddenPrefix.count))
            }
            return ChatWireMessage(role: record.role, content: body)
        }
    }
}
