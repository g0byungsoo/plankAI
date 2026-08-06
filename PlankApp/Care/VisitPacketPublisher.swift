import Foundation
import SwiftData

// MARK: - VisitPacketPublisher (app v8 S4)
//
// Serializes the canonical S3 VisitPacket into the wire shape the
// clinician dashboard reads, and publishes it for every connected
// org that holds the visit_packet_view scope. S3's projection is the
// ONE implementation of the rules — this transports her output, it
// never recomputes it. RLS is the real gate: the insert policy
// requires an active packet consent, so a revoked patient can't
// publish even if this fires.

@MainActor
enum VisitPacketPublisher {

    private static let unitKey = "weightUnit"

    /// Build the wire payload (matches the dashboard's
    /// VisitPacketPayload). unrecordedCount is encoded explicitly
    /// (it is computed on the Swift side).
    static func payloadData(_ packet: VisitPacket, displayUnit: String) -> Data? {
        var dict: [String: Any] = [
            "window": ["label": packet.window.label],
            "displayUnit": displayUnit,
        ]
        if let r = packet.regimen {
            dict["regimen"] = [
                "displayLine": r.displayLine,
                "authorityLabel": r.authorityLabel,
                "anchorWeekdayWord": r.anchorWeekdayWord as Any,
                "scheduledCount": r.scheduledCount,
                "takenCount": r.takenCount,
                "skippedCount": r.skippedCount,
                "unrecordedCount": r.unrecordedCount,
            ]
        }
        if let w = packet.weight {
            dict["weight"] = [
                "entryCount": w.entryCount,
                "firstKg": w.firstKg as Any,
                "latestKg": w.latestKg as Any,
                "directionWord": w.directionWord as Any,
            ]
        }
        if !packet.symptoms.isEmpty {
            dict["symptoms"] = packet.symptoms.map {
                ["word": $0.word, "count": $0.count, "timingNote": $0.timingNote as Any]
            }
        }
        if let n = packet.nutrition {
            dict["nutrition"] = [
                "loggedDays": n.loggedDays, "proteinDaysMet": n.proteinDaysMet, "targetG": n.targetG,
            ]
        }
        if let m = packet.movement {
            dict["movement"] = ["movedDays": m.movedDays, "stepsWeekAvg": m.stepsWeekAvg as Any]
        }
        dict["questions"] = packet.questions.map { ["id": $0.id, "text": $0.text, "origin": $0.origin] }
        dict["gaps"] = packet.gaps
        return try? JSONSerialization.data(withJSONObject: dict)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Publish to every connected org holding packet consent. Called
    /// after hydrate (launch) and when the patient opens her packet.
    /// No-op when she has no active connection with that scope.
    static func publishIfConnected(userId: String, in context: ModelContext) async {
        guard !userId.isEmpty else { return }
        let connections = await CareConnectionService.connections()
        let targets = connections.filter { $0.isActive && $0.scopes.contains(.visitPacket) }
        guard !targets.isEmpty else { return }

        let packet = VisitPacketBuilder.build(userId: userId, in: context)
        let unit = UserDefaults.standard.string(forKey: unitKey) ?? "lb"
        guard let data = payloadData(packet, displayUnit: unit) else { return }
        let start = dayFormatter.string(from: packet.window.start)
        let end = dayFormatter.string(from: packet.window.end)

        for c in targets {
            await AppSync.shared.publishVisitPacket(
                id: "\(userId)-\(c.orgId)", userId: userId, orgId: c.orgId,
                payload: data, windowStart: start, windowEnd: end, appVersion: "ios-s4"
            )
        }
    }
}
