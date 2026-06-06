import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - ScanLiveActivity
//
// Lock Screen + Dynamic Island Live Activity for the food scan
// in-progress moment. Mirrors the in-viewfinder ScanLabelRotator
// label rhythm so the system surface feels like the same scan beat
// the user just kicked off, not a separate UI.
//
// Per docs/home_becoming_research_ios_ux_2026_06_06.md §3-4.
//
// Voice signal locks observed:
//   - Italic-Fraunces on the punch verb (reading / matching /
//     tallying / ready)
//   - Hearts ♥ only as terminal punctuation (the "ready ♥" final
//     beat) — never during loading
//   - Lowercase casual register

struct ScanLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScanActivityAttributes.self) { context in
            // Lock Screen presentation
            lockScreenView(state: context.state, attributes: context.attributes)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded — appears when the user taps & holds the
                // pill, or briefly when the activity starts.
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color(red: 0.77, green: 0.40, blue: 0.48))  // rose
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("♥")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(red: 0.77, green: 0.40, blue: 0.48))
                }
                DynamicIslandExpandedRegion(.center) {
                    expandedCenter(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("a snapshot is being read.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 0.77, green: 0.40, blue: 0.48))
            } compactTrailing: {
                compactTrailing(state: context.state)
            } minimal: {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 0.77, green: 0.40, blue: 0.48))
            }
            .keylineTint(Color(red: 0.77, green: 0.40, blue: 0.48))
        }
    }

    // MARK: - Lock Screen

    @ViewBuilder
    private func lockScreenView(
        state: ScanActivityAttributes.ContentState,
        attributes: ScanActivityAttributes
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color(red: 0.77, green: 0.40, blue: 0.48))
                .frame(width: 44, height: 44)
                .background(Color(red: 0.96, green: 0.84, blue: 0.85).opacity(0.5))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    Text(state.label.verb)
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                    Text(state.label.tail)
                        .font(.custom("Fraunces72pt-Regular", size: 16))
                }
                .foregroundStyle(.primary)
                Text(attributes.displayName.isEmpty
                     ? "jenifit · reading your plate"
                     : "\(attributes.displayName.lowercased()) · reading your plate")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(.background)
    }

    // MARK: - Dynamic Island regions

    @ViewBuilder
    private func expandedCenter(state: ScanActivityAttributes.ContentState) -> some View {
        HStack(spacing: 0) {
            Text(state.label.verb)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 17))
            Text(state.label.tail)
                .font(.custom("Fraunces72pt-Regular", size: 17))
        }
        .foregroundStyle(.primary)
    }

    @ViewBuilder
    private func compactTrailing(state: ScanActivityAttributes.ContentState) -> some View {
        if state.phase == .ready {
            Text("♥")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.77, green: 0.40, blue: 0.48))
        } else {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.65)
                .tint(Color(red: 0.77, green: 0.40, blue: 0.48))
        }
    }
}
