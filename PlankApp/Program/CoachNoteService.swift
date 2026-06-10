import Foundation
import SwiftUI

// MARK: - CoachNote
//
// SHELVED 2026-06-10 — feature unwired from AnalyticsView (founder
// call: not core to v1.0.7 redesign + the "AI coach note" surface
// conflicts with the no-"AI" voice). Files kept on disk for v1.0.8+
// revival when the long-term AI coach agent vision in
// [[project-jenifit-vision]] is ready to ship. To re-enable: restore
// the Group + .task block in AnalyticsView.body around line 520 (see
// the shelved-2026-06-10 comment there).
//
// v3 P11.5 (2026-06-10) — narrow LLM seam: a short weekly note from
// jeni that references the user's actual data (sessions completed,
// weight delta, streak, cohort flags) and ends with ONE small
// actionable suggestion in JeniFit voice.
//
// Persistence: AppStorage-JSON (NOT SwiftData @Model) per the
// PlankAIApp.swift modelContainer comment — adding @Models to the
// container risks the v1.0.7 food-rail hang. Coach notes are
// small + few (≤ ~12 weekly notes per quarter), so JSON-in-AppStorage
// is the right scope. Migrate to SwiftData when food rail v2 lands
// the proper integration.
//
// LLM call: STUBBED for v1.0.7 scaffolding. `generateMock(...)`
// returns a templated note from real user inputs so the UI is
// clickable end-to-end. `generateForCurrentWeek(...)` is the async
// API method to wire to Anthropic Claude Sonnet 4.6 when the
// provider auth lands (see voice contract memory for prompt spec).
//
// Voice contract (locked, see `feedback_coach_note_voice` memory):
//   - lowercase casual register
//   - italic-Fraunces punch words via ItalicAccentText (call site)
//   - heart ♥ as terminal punctuation OK, NEVER mid-sentence
//   - post-Ozempic vocab: food noise, satiety, fits, tomorrow resets
//   - NEVER: crush, shred, burn, earn, deficit, "AI"
//   - reference REAL user data; NO fabrication ([[feedback-data-provenance]])
//   - 2-3 short paragraphs; ONE small actionable suggestion at end
//   - heart-terminal closing line OK ("see you monday ♥")

public struct CoachNote: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    /// Monday-anchored ISO date for the week this note covers.
    /// Single note per (userId, weekStartDate); regenerate replaces.
    public let weekStartDate: Date
    public let generatedAt: Date

    /// 2-3 short paragraphs in jeni's voice. Italic punch is encoded
    /// by surrounding the punch words with `«»` (guillemets), which
    /// the UI splits and renders via ItalicAccentText. We pick
    /// guillemets specifically because the literal-asterisk lock
    /// ([[feedback-no-italic-markdown-markers]]) rejects `*word*` —
    /// guillemets are unambiguous, paste-safe, and never appear in
    /// English copy by accident.
    public let body: String

    /// One small actionable suggestion line. Rendered with a small
    /// sticker glyph. Examples: "try one matcha before noon this week."
    /// "log one rest-day photo — bed counts." Always concrete.
    public let suggestion: String

    /// Optional mood tag the model emits — drives card chrome tint
    /// (sage = grounded, cocoa = neutral, accent = celebratory).
    /// Codable enum so the storage format is stable across schema
    /// changes; unknown values fall back to .neutral.
    public let mood: Mood

    public enum Mood: String, Codable, Sendable {
        case grounded
        case neutral
        case celebratory
    }

    public init(
        id: UUID = UUID(),
        weekStartDate: Date,
        generatedAt: Date = Date(),
        body: String,
        suggestion: String,
        mood: Mood = .neutral
    ) {
        self.id = id
        self.weekStartDate = weekStartDate
        self.generatedAt = generatedAt
        self.body = body
        self.suggestion = suggestion
        self.mood = mood
    }
}

// MARK: - CoachNoteService
//
// @Observable singleton (SwiftUI 17+ pattern). UI reads `.latest`;
// service handles generation + persistence behind the scenes.
//
// Threading: persistence is synchronous (small JSON, AppStorage on
// main). API calls are async and run off-main; the result hops
// back to main via @MainActor for storage + UI update.

@MainActor
@Observable
public final class CoachNoteService {

    public static let shared = CoachNoteService()

    /// JSON-encoded `[CoachNote]` keyed by `weekStartDate` (latest
    /// first, capped at 12 entries = one quarter of weekly notes).
    /// AppStorage key kept short + namespaced so a future SwiftData
    /// migration knows what to import.
    private static let storageKey = "coach_notes_v1"

    /// Hard cap on persisted notes. 12 = a full ~3-month program
    /// retrospective horizon. Older notes get dropped (oldest first)
    /// on append.
    private static let maxStored = 12

    public private(set) var notes: [CoachNote] = []

    private init() {
        self.notes = Self.loadStored()
    }

    // MARK: - Public reads

    /// Most recent note (highest weekStartDate). Drives the
    /// CoachNoteCard on the Becoming tab.
    public var latest: CoachNote? {
        notes.max(by: { $0.weekStartDate < $1.weekStartDate })
    }

    /// True when no note exists for the current ISO week OR the
    /// stored note is >7 days old (defensive — covers the "user
    /// skipped a week" case so the next open regenerates).
    public func isOverdue(now: Date = Date()) -> Bool {
        guard let latest = latest else { return true }
        let cal = Calendar(identifier: .iso8601)
        let currentWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        return latest.weekStartDate < currentWeek
    }

    // MARK: - Generation

    /// v1.0.7 scaffolding — returns a templated note built from real
    /// user inputs. Persists + sets `.latest`. Voice already matches
    /// the locked contract (lowercase, italic punch via guillemets,
    /// no labor verbs, references real data).
    ///
    /// Used as the offline / no-key fallback by
    /// `generateForCurrentWeek(...)` — also callable directly when
    /// the caller knows the API isn't available (e.g. test scaffolds).
    public func generateMock(inputs: Inputs, now: Date = Date()) -> CoachNote {
        let cal = Calendar(identifier: .iso8601)
        let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now

        let note = composeMockNote(inputs: inputs, weekStart: weekStart, now: now)
        appendOrReplace(note)
        return note
    }

    /// v3 P11.5b (2026-06-10) — the real LLM path. Calls
    /// `CoachNoteAPIClient.generate(...)` (Anthropic Claude Sonnet
    /// 4.6 Messages API) and persists the result. On ANY failure
    /// (missing key, network error, parse error, schema mismatch),
    /// logs the reason in DEBUG and silently falls back to the
    /// templated `generateMock(...)` so the user always sees a note.
    ///
    /// Threading: API call runs off-main inside URLSession; this
    /// method is @MainActor so the persist + UI update hop back
    /// safely. Idempotent — calling twice in the same ISO week
    /// returns the same week's note (mock or real).
    public func generateForCurrentWeek(inputs: Inputs, now: Date = Date()) async -> CoachNote {
        // Same-week idempotency: if we already have a note for the
        // current week, return it instead of re-billing the API.
        if let latest = latest, !isOverdue(now: now) {
            return latest
        }

        do {
            let note = try await CoachNoteAPIClient.generate(inputs: inputs)
            appendOrReplace(note)
            return note
        } catch {
            #if DEBUG
            switch error as? CoachNoteAPIError {
            case .missingKey:
                print("[CoachNote] no Anthropic key — falling back to mock. Set ANTHROPIC_API_KEY in Info.plist or `debug_anthropic_api_key` UserDefaults to enable.")
            case .networkError(let inner):
                print("[CoachNote] network error — falling back to mock. \(inner)")
            case .httpError(let status, let body):
                print("[CoachNote] http \(status) — falling back to mock. body: \(body.prefix(200))")
            case .parseError(let msg):
                print("[CoachNote] parse error — falling back to mock. \(msg)")
            case .schemaError(let msg):
                print("[CoachNote] schema error — falling back to mock. \(msg)")
            case .none:
                print("[CoachNote] unknown error — falling back to mock. \(error)")
            }
            #endif
            return generateMock(inputs: inputs, now: now)
        }
    }

    // MARK: - Composition (mock — replace with LLM call)

    private func composeMockNote(inputs: Inputs, weekStart: Date, now: Date) -> CoachNote {
        // The mock body picks a thread based on the most-salient input
        // signal. Always references at least one real value (sessions
        // completed, weight delta, or streak day) so the note can't
        // read as generic LLM filler.
        let sessions = inputs.sessionsCompletedThisWeek
        let weight = inputs.weightDeltaThisWeekKg
        let name = inputs.firstName.isEmpty ? "you" : inputs.firstName.lowercased()

        let (body, mood, suggestion): (String, CoachNote.Mood, String)
        if sessions >= 3 {
            // High-engagement week.
            body = """
            \(name), this week you showed up «three times» — that's the rhythm we were aiming for. \
            the «consistency» matters more than any single session, and it's already starting to read on the curve.

            keep the same windows next week; we don't need to add anything yet.
            """
            mood = .celebratory
            suggestion = "before adding intensity, hold this rhythm for one more week ♥"
        } else if sessions >= 1 {
            // Light-engagement week — never shame, always permission.
            body = """
            \(name), one session this week is «one more than zero» — and it's the week that counts most when life is loud. \
            the streak isn't broken; the «container» is still holding.

            tomorrow resets. nothing about your plan needs to change for a quiet week.
            """
            mood = .grounded
            suggestion = "pick one 5-min slot this weekend — that's enough to keep the line warm ♥"
        } else {
            // Zero sessions — anti-shame, soft re-entry.
            body = """
            \(name), this week was a «pause» — and pauses are part of the plan, not breaks from it. \
            we don't need to make up missed sessions; the program adapts when you come back.

            when you're ready, monday is a fresh page. nothing to undo, nothing to prove.
            """
            mood = .neutral
            suggestion = "open the app monday morning and tap «start» — that's the entire next step ♥"
        }

        // Override mood if the weight signal is strongly positive
        // (≥ 0.3 kg loss this week is meaningful for the cohort).
        let finalMood: CoachNote.Mood = (weight ?? 0) <= -0.3 ? .celebratory : mood

        return CoachNote(
            weekStartDate: weekStart,
            generatedAt: now,
            body: body,
            suggestion: suggestion,
            mood: finalMood
        )
    }

    // MARK: - Persistence

    /// Replace any existing note for the same weekStartDate, else
    /// prepend. Caps the array at `maxStored` (oldest dropped).
    private func appendOrReplace(_ note: CoachNote) {
        var list = notes
        list.removeAll { Calendar.current.isDate($0.weekStartDate, equalTo: note.weekStartDate, toGranularity: .weekOfYear) }
        list.insert(note, at: 0)
        if list.count > Self.maxStored {
            list = Array(list.prefix(Self.maxStored))
        }
        notes = list
        Self.persistStored(list)
    }

    private static func loadStored() -> [CoachNote] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([CoachNote].self, from: data)) ?? []
    }

    private static func persistStored(_ list: [CoachNote]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    // MARK: - Inputs (what the composer / future LLM reads)

    /// Input package handed to the composer (and, later, the LLM).
    /// Every field is a REAL user value sourced from existing stores
    /// (SessionLogRecord, WeightLogRecord, AppStorage). No
    /// fabrication per [[feedback-data-provenance]].
    public struct Inputs: Sendable {
        public let firstName: String
        public let sessionsCompletedThisWeek: Int
        public let weightDeltaThisWeekKg: Double?
        public let currentStreakDays: Int
        public let pickedTier: String           // "soft" / "medium" / "hard"
        public let isGLP1User: Bool
        public let isPerimenopausal: Bool
        public let isShortSleeper: Bool

        public init(
            firstName: String,
            sessionsCompletedThisWeek: Int,
            weightDeltaThisWeekKg: Double?,
            currentStreakDays: Int,
            pickedTier: String,
            isGLP1User: Bool = false,
            isPerimenopausal: Bool = false,
            isShortSleeper: Bool = false
        ) {
            self.firstName = firstName
            self.sessionsCompletedThisWeek = sessionsCompletedThisWeek
            self.weightDeltaThisWeekKg = weightDeltaThisWeekKg
            self.currentStreakDays = currentStreakDays
            self.pickedTier = pickedTier
            self.isGLP1User = isGLP1User
            self.isPerimenopausal = isPerimenopausal
            self.isShortSleeper = isShortSleeper
        }
    }
}
