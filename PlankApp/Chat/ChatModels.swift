import Foundation
import SwiftData

// MARK: - Chat models
//
// App v2 (docs/app_v2/05_CHAT.md). Local-first conversation store.
// One record per message, day-keyed for transcript grouping. Cloud
// sync of transcripts is deliberately deferred (the table ships in
// the migration SQL; the EF + telemetry are the server side that
// matters for v2.0) — chat is fully functional device-local.

@Model
final class ChatMessageRecord {
    @Attribute(.unique) var id: String
    var userId: String
    /// "user" | "jeni" | "tool"
    var role: String
    var body: String
    /// Tool-call cards persist their identity so history re-renders.
    var toolName: String?
    var toolPayload: Data?
    var dayKey: String
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        role: String,
        body: String,
        toolName: String? = nil,
        toolPayload: Data? = nil,
        dayKey: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.role = role
        self.body = body
        self.toolName = toolName
        self.toolPayload = toolPayload
        self.dayKey = dayKey
        self.createdAt = createdAt
    }
}

// MARK: - Wire types

/// One turn on the wire (trailing window sent to the EF).
struct ChatWireMessage: Codable {
    let role: String       // "user" | "jeni"
    let content: String
}

/// A tool call streamed back from the model, executed client-side.
struct ChatToolCall: Equatable, Identifiable {
    let id: String
    let name: String
    let arguments: [String: Any]

    static func == (lhs: ChatToolCall, rhs: ChatToolCall) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}

/// Events emitted by a transport stream.
enum ChatEvent {
    case token(String)
    case toolCall(ChatToolCall)
    case done(inputTokens: Int, outputTokens: Int)
    case error(String)
}

/// Continuation payload after the client executed a tool.
///
/// v25 E3 — carries the ARGUMENTS back too. A read like
/// `read_food_day{day:"friday"}` is meaningless to the model on the
/// continuation turn if the assistant message replays it with `{}`,
/// which is what the v2 wire did (survivable only while every tool
/// took no arguments).
struct ChatToolResult {
    let callId: String
    let name: String
    let arguments: [String: Any]
    let result: [String: Any]

    init(
        callId: String,
        name: String,
        arguments: [String: Any] = [:],
        result: [String: Any]
    ) {
        self.callId = callId
        self.name = name
        self.arguments = arguments
        self.result = result
    }
}
