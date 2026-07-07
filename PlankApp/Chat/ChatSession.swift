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
    var composerText = ""

    // Injected by the host view.
    @ObservationIgnored var modelContext: ModelContext?
    @ObservationIgnored var userId: String = ""
    @ObservationIgnored var transport: ChatTransporting = ChatSession.defaultTransport()

    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var pendingToolContinuation: ChatToolCall?

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
        seedDailyBriefIfNeeded()
    }

    #if DEBUG
    /// QA: pin a long jeni entry mid-stream so the live shimmer can
    /// be photographed (pairs with --uitest-chat-shimmer).
    func seedShimmerDemo() {
        entries.append(Entry(
            id: "qa-shimmer",
            kind: .jeni,
            text: "okay. first, nothing is broken. one loud day doesn't move a trend line, it just feels like it does.\n\ntonight: water, an early night if you can get it. tomorrow's plan is already set, and it's a *gentle* one",
            isStreaming: true,
            createdAt: .now
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

        stream(toolResult: nil)
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
        Haptics.soft()
        stream(toolResult: nil)
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
        stream(toolResult: nil)
    }

    // MARK: - Streaming

    private func stream(toolResult: ChatToolResult?) {
        guard let modelContext, !userId.isEmpty else { return }
        isStreaming = true
        lastTurnFailed = false

        let streamingId = UUID().uuidString
        entries.append(Entry(
            id: streamingId, kind: .jeni, text: "", isStreaming: true, createdAt: .now
        ))

        let wire = wireWindow()
        let context = CoachContextAssembler.assemble(userId: userId, in: modelContext)

        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            var collected = ""
            var toolCalls: [ChatToolCall] = []
            do {
                for try await event in transport.stream(
                    messages: wire, contextJSON: context, toolResult: toolResult
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
                    collected = "she couldn't answer just now. try again in a moment."
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
        if let idx = entries.firstIndex(where: { $0.id == id }) {
            if finalText.isEmpty && !toolCalls.isEmpty {
                entries.remove(at: idx)   // tool-only turn: the card is the message
            } else {
                entries[idx].isStreaming = false
                entries[idx].text = finalText
                persist(role: "jeni", text: finalText, id: id)
            }
        }
        for call in toolCalls {
            handleToolCall(call)
        }
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
        stream(toolResult: ChatToolResult(
            callId: card.call.id, name: card.call.name, result: result
        ))
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
