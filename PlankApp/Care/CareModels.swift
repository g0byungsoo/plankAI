import Foundation

// MARK: - Care connection models (app v8 S4)
//
// docs/app_v8/10_S4_CLINIC_LOOP.md. The patient side of the clinic
// loop: the relationship she accepted, the scopes she granted, and
// the shapes the care_* RPCs return. Everything here is READ or a
// consented action — the patient never authors clinician care; she
// accepts it, records against it, and can request a correction or
// revoke access.

enum CareScope: String, CaseIterable, Codable {
    case visitPacket = "visit_packet_view"
    case observations = "observation_view"
    case assignment = "care_assignment"

    var title: String {
        switch self {
        case .visitPacket: return "your visit packet"
        case .observations: return "your daily records"
        case .assignment: return "your care plan"
        }
    }
    var detail: String {
        switch self {
        case .visitPacket: return "the 4-week summary you already prepare for a visit."
        case .observations: return "your dose marks, how meals sat, hydration, and weigh-ins."
        case .assignment: return "so your clinic can set the medication plan and protocol you follow."
        }
    }
}

struct CareInvitationPreview: Codable {
    let ok: Bool
    let reason: String?
    let orgId: String?
    let orgName: String?
    let patientLabel: String?
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case ok, reason
        case orgId = "org_id"
        case orgName = "org_name"
        case patientLabel = "patient_label"
        case expiresAt = "expires_at"
    }
}

struct CareAcceptResult: Codable {
    let ok: Bool
    let reason: String?
    let orgId: String?
    let orgName: String?

    enum CodingKeys: String, CodingKey {
        case ok, reason
        case orgId = "org_id"
        case orgName = "org_name"
    }
}

/// A connected clinic, as the patient app knows it. Derived from
/// care_relationships + consent_grants (read directly under RLS).
struct CareConnection: Identifiable, Equatable {
    let id: String            // relationship id
    let orgId: String
    let orgName: String
    let status: String        // active | revoked | ended
    let scopes: Set<CareScope>
    let establishedAt: Date?

    var isActive: Bool { status == "active" }
}

/// The correction categories a patient may report about a care-team
/// medication record (10_S4 §8; 164.526-shaped). A request never
/// mutates the plan — it files an auditable ask for the care team.
enum CorrectionCategory: String, CaseIterable, Identifiable {
    case name, strength, schedule, not_taking, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .name: return "the medication name looks wrong"
        case .strength: return "the dose looks wrong"
        case .schedule: return "the day looks wrong"
        case .not_taking: return "this isn't the medication i'm taking"
        case .other: return "something else"
        }
    }
}
