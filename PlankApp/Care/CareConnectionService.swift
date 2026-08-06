import Foundation
import Supabase
import SwiftData
import PlankSync

// MARK: - CareConnectionService (app v8 S4)
//
// The patient's side of the clinic loop. Wraps the care_* RPCs and
// the two RLS-readable tables (care_relationships, consent_grants)
// through the shared client. Enum service (house idiom; no isolated
// class deinit — see CareProtocolStore). Every method is a consented
// action or a read; the patient never writes clinician care.

@MainActor
enum CareConnectionService {

    // MARK: Reads

    private struct RelRow: Decodable {
        let id: String
        let org_id: String
        let status: String
        let established_at: String?
    }
    private struct OrgRow: Decodable { let id: String; let name: String }
    private struct ConsentRow: Decodable { let org_id: String?; let scope: String; let revoked_at: String? }

    /// The patient's connections, richest-first. Reads three RLS
    /// tables and stitches them locally — no server trust needed
    /// (each table is `auth.uid() = user_id`-scoped for her rows).
    static func connections() async -> [CareConnection] {
        do {
            let rels: [RelRow] = try await supabase.from("care_relationships")
                .select("id, org_id, status, established_at").execute().value
            guard !rels.isEmpty else { return [] }
            let orgIds = Array(Set(rels.map(\.org_id)))
            let orgs: [OrgRow] = try await supabase.from("organizations")
                .select("id, name").in("id", values: orgIds).execute().value
            let orgName = Dictionary(orgs.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
            let grants: [ConsentRow] = try await supabase.from("consent_grants")
                .select("org_id, scope, revoked_at").execute().value

            let iso = ISO8601DateFormatter()
            return rels.map { rel in
                let scopes = Set(grants
                    .filter { $0.org_id == rel.org_id && $0.revoked_at == nil }
                    .compactMap { CareScope(rawValue: $0.scope) })
                return CareConnection(
                    id: rel.id, orgId: rel.org_id,
                    orgName: orgName[rel.org_id] ?? "your clinic",
                    status: rel.status, scopes: scopes,
                    establishedAt: rel.established_at.flatMap { iso.date(from: $0) }
                )
            }
            .sorted { ($0.isActive ? 1 : 0, $0.establishedAt ?? .distantPast) > ($1.isActive ? 1 : 0, $1.establishedAt ?? .distantPast) }
        } catch {
            #if DEBUG
            print("[Care] connections load failed: \(error)")
            #endif
            return []
        }
    }

    static func activeConnection() async -> CareConnection? {
        await connections().first { $0.isActive }
    }

    // MARK: Invitation

    static func preview(code: String) async throws -> CareInvitationPreview {
        try await callRPC("care_preview_invitation", ["p_code": code])
    }

    static func accept(code: String, lookbackDays: Int, scopes: [CareScope]) async throws -> CareAcceptResult {
        try await callRPC("care_accept_invitation", [
            "p_code": .string(code),
            "p_lookback_days": .integer(lookbackDays),
            "p_scopes": .array(scopes.map { .string($0.rawValue) }),
        ])
    }

    // MARK: Correction (164.526-shaped — never mutates the plan)

    static func submitCorrection(
        orgId: String, regimenPlanId: String, category: CorrectionCategory, note: String?
    ) async throws {
        _ = try await supabase.rpc("care_submit_correction", params: [
            "p_org": .string(orgId),
            "p_regimen_plan_id": .string(regimenPlanId),
            "p_category": .string(category.rawValue),
            "p_note": note.map { AnyJSON.string($0) } ?? .null,
        ]).execute()
    }

    // MARK: Reconciliation (FR2 — server half)

    static func confirmReconciliation(planId: String, action: String, priorSelfPlanId: String?) async throws {
        _ = try await supabase.rpc("care_confirm_reconciliation", params: [
            "p_plan_id": .string(planId),
            "p_action": .string(action),
            "p_prior_self_plan_id": priorSelfPlanId.map { AnyJSON.string($0) } ?? .null,
        ]).execute()
    }

    // MARK: Revocation (prospective; access ≠ treatment)

    static func revoke(orgId: String, scope: CareScope? = nil, disconnect: Bool = false) async throws {
        _ = try await supabase.rpc("care_revoke_consent", params: [
            "p_org": .string(orgId),
            "p_scope": scope.map { AnyJSON.string($0.rawValue) } ?? .null,
            "p_disconnect": .bool(disconnect),
        ]).execute()
    }

    // MARK: Helper

    private static func callRPC<T: Decodable>(_ fn: String, _ params: [String: AnyJSON]) async throws -> T {
        let response = try await supabase.rpc(fn, params: params).execute()
        return try JSONDecoder().decode(T.self, from: response.data)
    }
    private static func callRPC<T: Decodable>(_ fn: String, _ simple: [String: String]) async throws -> T {
        try await callRPC(fn, simple.mapValues { AnyJSON.string($0) })
    }
}
