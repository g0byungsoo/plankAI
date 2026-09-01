import SwiftUI

// MARK: - JeniAtmosphere (v11.5 — the light behind the day)
//
// The founder's two references both open on a coloured atmosphere
// rather than a flat field. This is Jeni's: warm paper light, drawn
// by a Metal shader (jeniAtmosphere) whose two blooms drift on slow
// mutually-prime orbits, so the top of the page is never perfectly
// still and never visibly loops.
//
// The phase self-drives from a `.task` — the v10.1 law (never
// withAnimation over @State for a continuously-redrawn layer).
// Reduce Motion holds the light still rather than removing it: the
// depth is the point, the drift is the flourish.

struct JeniAtmosphere: View {
    /// How tall the lit band is. It fades out well before the end.
    var height: CGFloat = 340
    /// p61 — the host can hold the light still while it is not the
    /// visible surface (a full-screen cover over Home used to leave
    /// TWO of these redrawing behind the paper). A paused atmosphere
    /// keeps its last frame; the drift resumes where it left off.
    var paused: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var t: Double = 0

    var body: some View {
        Rectangle()
            .fill(Palette.bgPrimary)
            .frame(height: height)
            .colorEffect(
                ShaderLibrary.jeniAtmosphere(
                    .float2(430, height),
                    .float(t),
                    .float(1.0)
                )
            )
            .mask(
                // The band dissolves into the page — no seam, ever.
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.55),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task(id: "\(scenePhase)-\(paused)") {
                guard scenePhase == .active, !reduceMotion, !paused else { return }
                // p61 — 20fps, and the drift keeps its speed (dt rides
                // the tick). Light this slow cannot show the
                // difference, and a third of the redraws leave the
                // scroll thread.
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    t += 0.05
                }
            }
    }
}
