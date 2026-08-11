import Foundation

// MARK: - ChatTransport
//
// App v2 (docs/app_v2/05_CHAT.md). The wire to jeni-chat. Live
// transport speaks SSE against the edge function (same auth shape
// as FoodVisionService: bearer JWT + apikey); the mock streams
// canned coaching so the full UI is verifiable offline and in
// walkers (--uitest-mock-chat) before the EF is deployed.

protocol ChatTransporting {
    /// v25 E3 — plural results: one turn may resolve two reads.
    func stream(
        messages: [ChatWireMessage],
        contextJSON: [String: Any],
        toolResults: [ChatToolResult]
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
        toolResults: [ChatToolResult]
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
                        // v25 E3 — the tool surface travels with the
                        // request. The function allowlists what it
                        // recognises and falls back to its own list for
                        // older clients, so a new tool never needs a
                        // redeploy again.
                        "tools": JeniToolCatalog.wireTools,
                    ]
                    if !toolResults.isEmpty {
                        body["tool_results"] = toolResults.map { result in
                            [
                                "call_id": result.callId,
                                "name": result.name,
                                "arguments": result.arguments,
                                "result": result.result,
                            ] as [String: Any]
                        }
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
//
// v25 E3 — the mock now speaks the FULL contract, reads included, so
// the loop that matters most can be walked and filmed on a simulator
// with no edge-function deploy. It is a stand-in for the model's
// CHOICES, never for the data: a read it triggers runs against the
// real stores through the real router, and the reply it composes is
// built from whatever actually came back.

struct MockChatTransport: ChatTransporting {
    func stream(
        messages: [ChatWireMessage],
        contextJSON: [String: Any],
        toolResults: [ChatToolResult]
    ) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                let lastUser = messages.last(where: { $0.role == "user" })?
                    .content.lowercased() ?? ""
                var reply: String
                var tool: ChatToolCall? = nil

                if let result = toolResults.first {
                    // The continuation turn: answer FROM the record.
                    reply = Self.answer(for: result)
                } else if let read = Self.readIntent(lastUser) {
                    // A question the record can answer. No preamble:
                    // the real model is told to answer from the read.
                    reply = ""
                    tool = read
                } else if lastUser.contains("step goal") || lastUser.contains("6000")
                            || lastUser.contains("6,000") {
                    reply = "your call. want me to make it official?"
                    tool = ChatToolCall(
                        id: "mock-fact-\(UUID().uuidString.prefix(6))",
                        name: "propose_program_fact",
                        arguments: ["kind": "stepGoal", "steps": 6000]
                    )
                } else if lastUser.contains("remember") || lastUser.contains("don't eat before") {
                    reply = "noted."
                    tool = ChatToolCall(
                        id: "mock-mem-\(UUID().uuidString.prefix(6))",
                        name: "remember",
                        arguments: [
                            "note": "doesn't eat before 11am",
                            "topic": "food",
                        ]
                    )
                } else if lastUser.contains("plan") {
                    reply = "here's today. tap any row to open it."
                    tool = ChatToolCall(
                        id: "mock-plan-\(UUID().uuidString.prefix(6))",
                        name: "show_today_plan", arguments: [:]
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

    /// Which read a sentence would send a real model to.
    private static func readIntent(_ text: String) -> ChatToolCall? {
        func call(_ name: String, _ args: [String: Any] = [:]) -> ChatToolCall {
            ChatToolCall(
                id: "mock-\(name)-\(UUID().uuidString.prefix(6))",
                name: name, arguments: args
            )
        }
        if text.contains("yesterday") && (text.contains("eat") || text.contains("ate")) {
            return call("read_food_day", ["days_ago": 1])
        }
        for day in ["monday", "tuesday", "wednesday", "thursday",
                    "friday", "saturday", "sunday"] where text.contains(day) {
            if text.contains("eat") || text.contains("ate") || text.contains("log") {
                return call("read_food_day", ["weekday": day])
            }
        }
        if text.contains("my week") || text.contains("this week")
            || text.contains("protein") && text.contains("enough") {
            return call("read_food_week", ["days": 7])
        }
        if text.contains("losing") || text.contains("trend")
            || text.contains("plateau") || text.contains("why am i up") {
            return call("read_weight_trend")
        }
        if text.contains("dose") || text.contains("shot") || text.contains("consistent") {
            return call("read_dose_history")
        }
        if text.contains("nausea") || text.contains("symptom")
            || text.contains("side effect") {
            return call("read_symptoms", ["days": 30])
        }
        if text.contains("notice") || text.contains("pattern") {
            return call("read_patterns")
        }
        if text.contains("steps") || text.contains("moving") || text.contains("walk") {
            return call("read_activity")
        }
        if text.contains("my plan") || text.contains("who decided")
            || text.contains("my target") || text.contains("my goal") {
            return call("read_program")
        }
        return nil
    }

    /// Compose a reply from what the read actually returned — so a
    /// walked demo can never show an answer the record can't support.
    private static func answer(for result: ChatToolResult) -> String {
        let payload = result.result
        if let have = payload["have"] as? Bool, have == false {
            let why = (payload["why"] as? String) ?? "there isn't enough in your record yet."
            return "i looked. \(why)"
        }
        switch result.name {
        case "read_food_day":
            let day = (payload["day"] as? String) ?? "that day"
            let count = (payload["plate_count"] as? Int) ?? 0
            var line = "\(day) you logged \(count) plate\(count == 1 ? "" : "s")"
            if let kcal = payload["kcal_total"] as? Int,
               let protein = payload["protein_total_g"] as? Int {
                line += ", about \(kcal) calories and \(protein)g of protein"
            }
            return line + "."
        case "read_food_week":
            let days = (payload["days_logged"] as? Int) ?? 0
            var line = "you logged on \(days) of the last 7 days"
            if let protein = payload["avg_protein_g_on_logged_days"] as? Int {
                line += ", averaging \(protein)g protein on those days"
            }
            if (payload["sparse"] as? Bool) == true {
                line += ". that's a thin week to read much from"
            }
            return line + "."
        case "read_weight_trend":
            let direction = (payload["direction"] as? String) ?? "not_established"
            if direction == "not_established" {
                return "not enough weigh-ins to call a direction yet. the line needs a few more mornings."
            }
            let unit = (payload["unit"] as? String) ?? ""
            let change = payload["weekly_change"].map { "\($0) \(unit)" } ?? "a little"
            return "your trend is \(direction.replacingOccurrences(of: "_", with: " ")), about \(change) over the week."
        case "read_program":
            let facts = (payload["facts"] as? [[String: Any]]) ?? []
            return "you've got \(facts.count) fact\(facts.count == 1 ? "" : "s") in force right now."
        case "read_activity":
            let typical = (payload["typical_day"] as? Int) ?? 0
            return "a typical day for you is about \(typical) steps."
        case "propose_program_fact":
            if (payload["applied"] as? Bool) == true {
                return "done. that's yours now."
            }
            return (payload["say"] as? String) ?? "i couldn't change that one."
        case "remember":
            if (payload["remembered"] as? Bool) == true { return "got it, i'll keep that." }
            return "i won't write that one down."
        default:
            return "done. it's on your record now."
        }
    }
}
