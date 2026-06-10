import Foundation

// MARK: - CoachNoteAPIClient
//
// SHELVED 2026-06-10 — see CoachNoteService.swift header. Feature
// unwired from AnalyticsView; file dormant on disk for v1.0.8+
// revival. No Anthropic key is consumed in current builds.
//
// v3 P11.5b (2026-06-10) — the LLM seam for the weekly coach note.
// Calls Anthropic Claude Sonnet 4.6 directly via the Messages API.
// Returns a fully-formed CoachNote (via JSON tool-call response).
// On ANY failure (missing key, network error, parse failure, schema
// mismatch), throws CoachNoteAPIError so CoachNoteService can fall
// back to its templated mock — the user always sees a note, even
// offline or when the API is down.
//
// ⚠️ Production note: this is a CLIENT-SIDE Anthropic call. Per
// Anthropic's security guidance, client-embedded API keys are
// extractable from the iOS binary. The right production posture is
// a proxy endpoint that holds the secret server-side. Until that
// proxy lands, the integration is DEBUG-gated + reads the key from
// Bundle.main Info.plist (injected from a gitignored xcconfig at
// build time). Release builds without a proxy fall straight through
// to the mock — the API is never called and no key is ever
// embedded.
//
// Key loading priority:
//   1. Bundle.main Info.plist key `ANTHROPIC_API_KEY` (from xcconfig)
//   2. UserDefaults `debug_anthropic_api_key` (debug-menu override)
//   3. nil → throws .missingKey → CoachNoteService falls back to mock
//
// Voice contract enforced in the system prompt itself — the model
// is instructed to return guillemets («…») around italic punch
// words, lowercase casual, no labor verbs, no "AI" word, no
// fabrication of numbers. Response is parsed via a strict JSON
// schema so off-spec output fails closed.

public enum CoachNoteAPIError: Error, Sendable {
    case missingKey
    case networkError(Error)
    case httpError(status: Int, body: String)
    case parseError(String)
    case schemaError(String)
}

@MainActor
public enum CoachNoteAPIClient {

    /// Anthropic Messages API endpoint.
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    /// Model ID. Sonnet 4.6 is the default text-generation tier per
    /// [[feedback-claude-model-selection]] — high enough for the
    /// voice nuance, far below the cost ceiling at ~$0.02/wk/user.
    private static let model = "claude-sonnet-4-6"

    /// Generation params. Coach notes are short (≤300 tokens output);
    /// the budget is bounded by the system prompt + response schema.
    private static let maxTokens = 400

    public static func generate(inputs: CoachNoteService.Inputs) async throws -> CoachNote {
        guard let apiKey = loadAPIKey() else {
            throw CoachNoteAPIError.missingKey
        }

        let payload = buildRequestPayload(inputs: inputs)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(payload)
        request.timeoutInterval = 12  // honest budget; mock fallback is fine if we miss

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw CoachNoteAPIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw CoachNoteAPIError.parseError("not an HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            throw CoachNoteAPIError.httpError(status: http.statusCode, body: body)
        }

        return try parseResponse(data, weekStartDate: currentWeekStart())
    }

    // MARK: - Request shape

    private struct AnthropicRequest: Encodable {
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [Message]
        let temperature: Double
        struct Message: Encodable {
            let role: String
            let content: String
        }
    }

    private static func buildRequestPayload(inputs: CoachNoteService.Inputs) -> AnthropicRequest {
        AnthropicRequest(
            model: model,
            max_tokens: maxTokens,
            system: systemPrompt,
            messages: [
                .init(role: "user", content: userPrompt(inputs: inputs))
            ],
            temperature: 0.7  // some variety in voice without losing the contract
        )
    }

    /// The full voice contract lives in the system prompt. Locked in
    /// [[project-onboarding-v3-locked]] + [[feedback-voice-signals]] +
    /// [[feedback-post-ozempic-vocabulary]]. The "respond as JSON"
    /// instruction at the end forces a parseable object.
    private static let systemPrompt = """
    you are jeni, a coach inside the jenifit ios app — a women's
    weight-loss program with a post-ozempic, anti-femvertising voice.
    you write the user a short weekly note acknowledging her actual
    week.

    voice contract (must obey):
    - lowercase casual register; never title case
    - italic-fraunces punch words: wrap them with guillemets («like this»)
      in the body string. the renderer converts to italic. NEVER use
      asterisks (*word*) — those render as literal asterisks.
    - heart ♥ as terminal punctuation only (end of a line, not mid-sentence)
    - 2-3 short paragraphs. one small actionable suggestion at the end.
    - reference the user's REAL numbers from the inputs. never fabricate
      sessions, weight, streak — if the value is missing or zero, name
      that, don't invent.
    - no labor verbs: never use crush, shred, burn, earn, deficit, hustle,
      grind, smash, dominate, conquer.
    - no "AI", no "algorithm", no "data shows you". you are jeni; speak
      as jeni.
    - no scale shame. weight delta language should be neutral or absent —
      energy/clothes/sleep cues precede scale cues.
    - post-ozempic vocab is encouraged: food noise, satiety, fits, permission,
      tomorrow resets, container.
    - reference the user's FIRST NAME if provided.

    respond with ONLY a json object, no markdown fences, no preamble:
    {
      "body": "2-3 short paragraphs with «guillemets» around italic words",
      "suggestion": "one short actionable line with one «guillemet» italic word ♥",
      "mood": "grounded" | "neutral" | "celebratory"
    }
    """

    private static func userPrompt(inputs: CoachNoteService.Inputs) -> String {
        let weight = inputs.weightDeltaThisWeekKg.map { String(format: "%+.1f kg", $0) } ?? "no log this week"
        var lines: [String] = []
        lines.append("first name: \(inputs.firstName.isEmpty ? "she" : inputs.firstName.lowercased())")
        lines.append("sessions completed this week: \(inputs.sessionsCompletedThisWeek)")
        lines.append("weight delta this week: \(weight)")
        lines.append("current streak days: \(inputs.currentStreakDays)")
        lines.append("picked program tier: \(inputs.pickedTier)")
        if inputs.isGLP1User       { lines.append("on a glp-1 — acknowledge satiety + lean-mass protection if mentioning food") }
        if inputs.isPerimenopausal { lines.append("perimenopausal — acknowledge cycle + recovery shifts if relevant") }
        if inputs.isShortSleeper   { lines.append("habitually short sleep (<6h) — acknowledge recovery cost without scolding") }
        return "her week:\n" + lines.joined(separator: "\n")
    }

    // MARK: - Response shape

    private struct AnthropicResponse: Decodable {
        let content: [Block]
        struct Block: Decodable {
            let type: String
            let text: String?
        }
    }

    private struct ParsedNoteJSON: Decodable {
        let body: String
        let suggestion: String
        let mood: String
    }

    private static func parseResponse(_ data: Data, weekStartDate: Date) throws -> CoachNote {
        let decoded: AnthropicResponse
        do {
            decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        } catch {
            throw CoachNoteAPIError.parseError("anthropic envelope decode failed: \(error)")
        }
        guard let textBlock = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw CoachNoteAPIError.parseError("no text block in response")
        }
        // Strip any accidental markdown fence the model emitted.
        let cleaned = textBlock
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```",     with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonData = cleaned.data(using: .utf8) else {
            throw CoachNoteAPIError.parseError("body not utf-8")
        }
        let parsed: ParsedNoteJSON
        do {
            parsed = try JSONDecoder().decode(ParsedNoteJSON.self, from: jsonData)
        } catch {
            throw CoachNoteAPIError.parseError("note json decode failed: \(error)\nbody was: \(cleaned)")
        }
        // Schema guard: empty body or suggestion = unusable.
        guard !parsed.body.trimmingCharacters(in: .whitespaces).isEmpty,
              !parsed.suggestion.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw CoachNoteAPIError.schemaError("empty body or suggestion")
        }
        let mood: CoachNote.Mood = {
            switch parsed.mood {
            case "grounded":    return .grounded
            case "celebratory": return .celebratory
            default:            return .neutral
            }
        }()
        return CoachNote(
            weekStartDate: weekStartDate,
            body: parsed.body,
            suggestion: parsed.suggestion,
            mood: mood
        )
    }

    // MARK: - Helpers

    private static func loadAPIKey() -> String? {
        // 1. Info.plist (injected from gitignored xcconfig at build time)
        if let key = Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String,
           !key.isEmpty,
           // xcconfig substitution leaves the literal "$(ANTHROPIC_API_KEY)"
           // when the value is empty — guard against that footgun.
           !key.contains("$(") {
            return key
        }
        // 2. Debug-menu override (UserDefaults)
        #if DEBUG
        if let key = UserDefaults.standard.string(forKey: "debug_anthropic_api_key"),
           !key.isEmpty {
            return key
        }
        #endif
        // 3. Nil — service falls back to generateMock
        return nil
    }

    private static func currentWeekStart() -> Date {
        let cal = Calendar(identifier: .iso8601)
        return cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    }
}
