import Foundation
import PlankSync
import SwiftData

// MARK: - SideEffectLog (app v24 THE REGIMEN)
//
// The lightweight side-effect logger's store: gentle vocabulary,
// three severities, one row per day per symptom (composed
// deterministic ids over ObservationStore's .symptom kind — the
// chart the care packet already reads). Not medical, not scary:
// plain words, no scales, no scores. Notes ride the payload
// (device-local, like every payload).

enum SideEffectSymptom: String, CaseIterable, Identifiable {
    case nausea
    case constipation
    case looseStomach = "loose_stomach"
    case fatigue
    case headache
    case reflux
    case siteTenderness = "site_tenderness"
    case appetiteGone = "appetite_gone"
    case appetiteBack = "appetite_back"

    var id: String { rawValue }

    /// The gentle word she taps (post-ozempic vocabulary law).
    var word: String {
        switch self {
        case .nausea: return "queasy"
        case .constipation: return "backed up"
        case .looseStomach: return "loose stomach"
        case .fatigue: return "worn down"
        case .headache: return "headache"
        case .reflux: return "reflux"
        case .siteTenderness: return "tender at the site"
        case .appetiteGone: return "appetite gone"
        case .appetiteBack: return "appetite back"
        }
    }

    /// The word patterns speak ("the queasiness…").
    var nounWord: String {
        switch self {
        case .nausea: return "queasiness"
        case .constipation: return "the backed-up feeling"
        case .looseStomach: return "the loose stomach"
        case .fatigue: return "the worn-down feeling"
        case .headache: return "the headaches"
        case .reflux: return "the reflux"
        case .siteTenderness: return "the site tenderness"
        case .appetiteGone: return "the vanished appetite"
        case .appetiteBack: return "the returning appetite"
        }
    }
}

enum SideEffectSeverity: Int, CaseIterable, Identifiable {
    case aTouch = 1
    case noticeable = 2
    case rough = 3

    var id: Int { rawValue }

    var word: String {
        switch self {
        case .aTouch: return "a touch"
        case .noticeable: return "noticeable"
        case .rough: return "rough"
        }
    }
}

@MainActor
enum SideEffectLog {

    static func id(userId: String, symptom: String, dayKey: String) -> String {
        "\(userId.lowercased())-symptom-\(symptom)-\(dayKey)"
    }

    @discardableResult
    static func record(
        _ symptom: SideEffectSymptom,
        severity: SideEffectSeverity,
        note: String? = nil,
        dayKey: String = TodayStateService.dayKey(),
        userId: String,
        in context: ModelContext
    ) -> ObservationRecord? {
        guard !userId.isEmpty else { return nil }
        var payload: Data?
        if let note, !note.isEmpty {
            payload = try? JSONSerialization.data(withJSONObject: ["note": note])
        }
        return ObservationStore.record(
            .symptom,
            valueText: symptom.rawValue,
            valueNum: Double(severity.rawValue),
            payload: payload,
            dayKey: dayKey,
            userId: userId,
            in: context,
            id: id(userId: userId, symptom: symptom.rawValue, dayKey: dayKey)
        )
    }

    static func remove(
        _ symptom: SideEffectSymptom,
        dayKey: String = TodayStateService.dayKey(),
        userId: String,
        in context: ModelContext
    ) {
        ObservationStore.delete(
            id: id(userId: userId, symptom: symptom.rawValue, dayKey: dayKey),
            in: context
        )
    }

    struct Entry: Equatable {
        let dayKey: String
        let symptom: SideEffectSymptom
        let severity: SideEffectSeverity
    }

    /// Newest-first typed entries (the pattern engine + sheets read
    /// these).
    static func entries(
        userId: String, limit: Int = 120, in context: ModelContext
    ) -> [Entry] {
        ObservationStore.series(.symptom, userId: userId, limit: limit, in: context)
            .compactMap { record in
                guard let symptom = record.valueText
                    .flatMap(SideEffectSymptom.init(rawValue:)),
                    let severity = record.valueNum
                        .flatMap({ SideEffectSeverity(rawValue: Int($0)) })
                else { return nil }
                return Entry(
                    dayKey: record.dayKey, symptom: symptom, severity: severity
                )
            }
    }

    static func todaySeverity(
        _ symptom: SideEffectSymptom,
        userId: String, in context: ModelContext
    ) -> SideEffectSeverity? {
        let today = TodayStateService.dayKey()
        return entries(userId: userId, limit: 30, in: context)
            .first { $0.dayKey == today && $0.symptom == symptom }?
            .severity
    }
}
