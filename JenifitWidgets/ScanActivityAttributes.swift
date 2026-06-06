import ActivityKit
import Foundation

// MARK: - ScanActivityAttributes
//
// Shared between the main app and the JenifitWidgets extension via
// being added to both targets. Drives the Dynamic Island + Lock Screen
// Live Activity that runs during a food scan (1.5–3s typical, up to
// the 90s timeout if the GPT chain chains hard).
//
// Per docs/home_becoming_research_ios_ux_2026_06_06.md:
// > "Ship the Dynamic Island food scan in v1.0.7. This is the highest-
// >  ROI iOS-native build available and the most screenshottable
// >  moment for TikTok demos. Dynamic Island = scan-in-progress
// >  (3–8s event, textbook ActivityKit fit)."
//
// Three states for the ContentState — the iOS UX brief explicitly
// recommended a 3-phase rhythm here to match the in-viewfinder
// scan label rotator so the surfaces feel like one app:
//   .reading   "*reading* your plate"
//   .matching  "*matching* ingredients"
//   .tallying  "*tallying* portions"

public struct ScanActivityAttributes: ActivityAttributes {
    public typealias ContentState = ScanContentState

    /// Static attribute (kept tiny — Dynamic Island activities have
    /// strict size caps). The user's first name when known so the
    /// system surface reads as their app, not a generic one.
    public var displayName: String

    public init(displayName: String) {
        self.displayName = displayName
    }

    // MARK: - Content state

    public struct ScanContentState: Codable, Hashable {
        public enum Phase: String, Codable, Hashable, Sendable {
            case reading
            case matching
            case tallying
            case ready
        }

        public var phase: Phase
        public var startedAt: Date

        public init(phase: Phase, startedAt: Date) {
            self.phase = phase
            self.startedAt = startedAt
        }

        public var label: (verb: String, tail: String) {
            switch phase {
            case .reading:  return ("reading",   " your plate")
            case .matching: return ("matching",  " ingredients")
            case .tallying: return ("tallying",  " portions")
            case .ready:    return ("ready",     " ♥")
            }
        }
    }
}
