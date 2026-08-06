import Foundation
import SwiftData

// MARK: - WeeklySummaryPublisher (app v9 P6)
//
// Publishes the CURRENT week's CareWeekSummary for every connected
// org holding the visit_packet_view scope — the packet's cadence
// exactly (fires only when her app runs; nothing watches her in
// real time). One row per patient × org × ISO week: the current
// week upserts, prior weeks accrete — the longitudinal series
// visit_packets (latest-snapshot by design) never kept. RLS is the
// real gate: insert/update require an active packet consent.

@MainActor
enum WeeklySummaryPublisher {

    static func publishIfConnected(userId: String, in context: ModelContext) async {
        guard !userId.isEmpty else { return }
        let connections = await CareConnectionService.connections()
        let targets = connections.filter { $0.isActive && $0.scopes.contains(.visitPacket) }
        guard !targets.isEmpty else { return }

        let summary = CareWeekSummary.compose(
            CareWeekSummary.gather(userId: userId, in: context)
        )
        guard let data = try? JSONSerialization.data(withJSONObject: summary.payload)
        else { return }

        for c in targets {
            await AppSync.shared.publishWeeklySummary(
                id: "\(userId)-\(c.orgId)-\(summary.weekKey)",
                userId: userId, orgId: c.orgId,
                weekKey: summary.weekKey,
                payload: data, appVersion: "ios-p6"
            )
        }
    }
}
