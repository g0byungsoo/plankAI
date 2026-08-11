import Foundation

// MARK: - ChatTransport
//
// App v2 (docs/app_v2/05_CHAT.md). The wire to jeni-chat. Live
// transport speaks SSE against the edge function (same auth shape
// as FoodVisionService: bearer JWT + apikey); the mock streams
// canned coaching so the full UI is verifiable offline and in
// walkers (--uitest-mock-chat) before the EF is deployed.

protocol ChatTransporting {
    func stream(
        messages: [ChatWireMessage],
        contextJSON: [String: Any],
        toolResult: ChatToolResult?
    ) -> AsyncThrowingStream<ChatEvent, Error>
}

// MARK: - Live SSE transport

struct LiveChatTransport: ChatTransporting {
    let supabaseURL: URL
    let anonKey: String
    let tokenProvider: @Sendable () async -> String?

    func stream(
        messages: [ChatWireMessage],
        contextJSON: [String: Any],
        toolResult: ChatToolResult?
    ) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(
                        url: supabaseURL.appendingPathComponent("functions/v1/jeni-chat")
                    )
                    request.httpMethod = "POST"
                    request.timeoutInterval = 60
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(anonKey, forHTTPHeaderField: "apikey")
                    if let token = await tokenProvider() {
                        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    }

                    var body: [String: Any] = [
                        "coach_context": contextJSON,
                        "messages": messages.map { ["role": $0.role, "content": $0.content] },
                    ]
                    if let toolResult {
                        body["tool_result"] = [
                            "call_id": toolResult.callId,
                            "name": toolResult.name,
                            "result": toolResult.result,
                        ]
                    }
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw URLError(.badServerResponse)
                    }
                    guard http.statusCode == 200 else {
                        #if DEBUG
                        NSLog("[JeniChatWire] non-200: %d", http.statusCode)
                        #endif
                        continuation.yield(.error(errorLine(for: http.statusCode)))
                        continuation.finish()
                        return
                    }

                    var eventName = ""
                    for try await line in bytes.lines {
                        if line.hasPrefix("event:") {
                            eventName = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                            guard
                                let data = payload.data(using: .utf8),
                                let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                            else { continue }
                            switch eventName {
                            case "token":
                                if let t = obj["t"] as? String {
                                    continuation.yield(.token(t))
                                }
                            case "tool_call":
                                continuation.yield(.toolCall(ChatToolCall(
                                    id: obj["id"] as? String ?? UUID().uuidString,
                                    name: obj["name"] as? String ?? "",
                                    arguments: obj["arguments"] as? [String: Any] ?? [:]
                                )))
                            case "done":
                                let usage = obj["usage"] as? [String: Any]
                                continuation.yield(.done(
                                    inputTokens: usage?["input"] as? Int ?? 0,
                                    outputTokens: usage?["output"] as? Int ?? 0
                                ))
                            case "error":
                                continuation.yield(.error(
                                    obj["message"] as? String ?? "something slipped"
                                ))
                            default:
                                break
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    #if DEBUG
                    NSLog("[JeniChatWire] threw: %@", String(describing: error))
                    #endif
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func errorLine(for status: Int) -> String {
        switch status {
        case 429:
            return "that's today's chat limit. it resets tomorrow."
        case 401:
            return "your session needs a refresh. close and reopen the app."
        default:
            return "jeni couldn't answer just now. try again in a moment."
        }
    }
}

// MARK: - Mock transport (DEBUG + previews + walkers)

struct MockChatTransport: ChatTransporting {
    func stream(
        messages: [ChatWireMessage],
        contextJSON: [String: Any],
        toolResult: ChatToolResult?
    ) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                let lastUser = messages.last(where: { $0.role == "user" })?.content.lowercased() ?? ""
                let reply: String
                var tool: ChatToolCall? = nil
                if toolResult != nil {
                    reply = "done. it's on your trend line now."
                } else if lastUser.contains("plan") {
                    reply = "here's today. tap any row to open it."
                    tool = ChatToolCall(
                        id: "mock-plan-\(UUID().uuidString.prefix(6))",
                        name: "show_today_plan", arguments: [:]
                    )
                } else if lastUser.contains("trend") || lastUser.contains("line") {
                    reply = "here's your line."
                    tool = ChatToolCall(
                        id: "mock-trend-\(UUID().uuidString.prefix(6))",
                        name: "show_weight_trend", arguments: [:]
                    )
                } else if lastUser.contains("weigh") || lastUser.contains("74") {
                    reply = "got it. want me to put that on your trend line?"
                    tool = ChatToolCall(
                        id: "mock-1", name: "log_weight", arguments: ["kg": 74.2]
                    )
                } else if lastUser.contains("eat") {
                    reply = "you're at 61g protein with room in your day. something warm with chicken or tofu gets you close to your 90g without feeling like a project. keep it one pan."
                } else if lastUser.contains("rough") || lastUser.contains("blew") {
                    reply = "okay. first, nothing is broken. one loud day doesn't move a trend line, it just feels like it does.\n\ntonight: water, an early night if you can get it. tomorrow's plan is already set, and it's a gentle one. the next plate is the reset, not a punishment."
                } else {
                    reply = "i'm here. your plan today is light on purpose. one plate at a time, and the steps count themselves."
                }

                for word in reply.split(separator: " ", omittingEmptySubsequences: false) {
                    try? await Task.sleep(nanoseconds: 40_000_000)
                    if Task.isCancelled { break }
                    continuation.yield(.token(String(word) + " "))
                }
                if let tool {
                    continuation.yield(.toolCall(tool))
                }
                continuation.yield(.done(inputTokens: 0, outputTokens: 0))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
