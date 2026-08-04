import SwiftUI
import SwiftData
import PlankSync

// MARK: - BodyScanFlowView
//
// app v9 P1 — Body Vision's lived surface: consent (once) → the
// guided capture → the landed moment → her record. The register is
// clinical-calm (L6) and the chrome is subtractive (L7): one
// coaching line, one countdown, no shutter button unless the pose
// gate can't fire, nothing decorated.
//
// She stands in front of the camera; the app does the rest.

struct BodyScanFlowView: View {
    let userId: String
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext

    private enum Stage: Equatable {
        case consent
        case capture
        case landed
        case record
    }

    @State private var stage: Stage = .record
    @State private var session = BodyCaptureSession()
    @State private var arming = BodyScanAlignment.Arming()
    @State private var verdict: BodyScanAlignment.Verdict = .searching
    @State private var countdown: Int? = nil
    @State private var manualDoorOpen = false
    @State private var capturedPhoto: UIImage?
    @State private var capturedSilhouette: UIImage?
    @State private var capturedQuality: Double = 0
    @State private var capturedAnchors: (top: Double, bottom: Double, centerX: Double)?
    @State private var consentMode = "silhouette"
    @State private var appeared = false

    private var scans: [BodyScanRecord] {
        BodyScanStore.all(userId: userId, in: modelContext)
    }

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            switch stage {
            case .consent: consentView
            case .capture: captureView
            case .landed: landedView
            case .record: recordView
            }
        }
        .animation(Motion.crossFade, value: stage)
        .onAppear {
            guard !appeared else { return }
            appeared = true
            if !BodyScanStore.consentSeen {
                stage = .consent
            } else if scans.isEmpty {
                stage = .capture
            } else {
                stage = .record
            }
        }
        .onChange(of: stage) { _, new in
            if new == .capture {
                Task { await session.requestPermissionAndStart() }
            } else {
                session.stop()
            }
        }
        .task(id: stage == .capture) {
            guard stage == .capture else { return }
            if BodyScanQA.allowManual { manualDoorOpen = true }
            await session.requestPermissionAndStart()
        }
        .onChange(of: session.joints) { _, joints in
            guard stage == .capture, countdown == nil else {
                // Movement mid-countdown disarms — stillness is the
                // contract, not a suggestion.
                if countdown != nil,
                   BodyScanAlignment.verdict(session.joints) != .aligned {
                    countdown = nil
                    arming.disarm()
                }
                return
            }
            let v = BodyScanAlignment.verdict(joints)
            if v != verdict {
                withAnimation(Motion.crossFade) { verdict = v }
            }
            let wasArmed = arming.isArmed
            arming.ingest(v)
            if arming.isArmed, !wasArmed {
                Haptics.medium()
                beginCountdown()
            }
        }
    }

    // MARK: - Consent (once; the truth, then her choice)

    private var consentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            closeRow
            Spacer()
            Text("BODY VISION")
                .font(Typo.eyebrow)
                .kerning(1.4)
                .foregroundStyle(Palette.cocoaTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, Space.sm)
            Text("your record, private.")
                .font(Typo.title)
                .foregroundStyle(Palette.cocoaPrimary)
                .fixedSize(horizontal: false, vertical: true)   // XXXL wraps, never truncates
                .padding(.bottom, Space.lg)

            VStack(alignment: .leading, spacing: Space.md) {
                truthRow("your scans live on this iPhone. nowhere else, unless you turn on backup.")
                truthRow("no number is ever read from a photo. a scan is evidence, not a measurement.")
                truthRow("delete any scan, or all of them, anytime.")
            }
            .padding(.bottom, Space.xl)

            Text("HOW YOUR RECORD SHOWS YOU")
                .font(Typo.eyebrow)
                .kerning(1.4)
                .foregroundStyle(Palette.cocoaTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, Space.sm)
            HStack(spacing: Space.sm) {
                modeCard("silhouette", title: "as a silhouette",
                         line: "an ink figure. the shape of change.")
                modeCard("photo", title: "as photographs",
                         line: "the mirror, kept honestly.")
            }
            Spacer()
            primaryCTA("begin") {
                BodyScanStore.recordConsent(renderMode: consentMode)
                stage = .capture
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.lg)
    }

    private func truthRow(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
            Circle()
                .fill(Palette.accent)
                .frame(width: 4, height: 4)
                .offset(y: -3)
            Text(text)
                .font(Typo.body)
                .foregroundStyle(Palette.cocoaSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func modeCard(_ mode: String, title: String, line: String) -> some View {
        let selected = consentMode == mode
        return Button {
            Haptics.light()
            consentMode = mode
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(Typo.heading)
                    .foregroundStyle(selected ? Palette.bgPrimary : Palette.cocoaPrimary)
                    .fixedSize(horizontal: false, vertical: true)   // XXXL wraps
                Text(line)
                    .font(Typo.caption)
                    .foregroundStyle(selected ? Palette.bgPrimary.opacity(0.75) : Palette.cocoaTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Space.md)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? Palette.cocoaPrimary : Palette.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Palette.cocoaPrimary.opacity(selected ? 0 : 0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Capture (the guided moment)

    private var captureView: some View {
        ZStack {
            BodyCameraPreview(session: session)
                .ignoresSafeArea()

            if let frozen = session.frozenFrame {
                Image(uiImage: frozen)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }

            // Her last silhouette as the alignment ghost — stand
            // where you stood.
            if let last = scans.first,
               let ghost = BodyScanPhotoStore.silhouette(scanId: last.id),
               session.frozenFrame == nil {
                Image(uiImage: ghost)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.12)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }

            VStack {
                HStack {
                    quietClose {
                        if scans.isEmpty { onClose() } else { stage = .record }
                    }
                    Spacer()
                }
                .padding(.horizontal, Space.lg)
                Spacer()

                if let count = countdown {
                    Text("\(count)")
                        .font(Typo.display)
                        .foregroundStyle(Palette.bgPrimary)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .id("count-\(count)")
                }
                Spacer()

                VStack(spacing: Space.md) {
                    if session.permissionDenied {
                        Text("jeni needs the camera for this — settings › privacy › camera")
                            .font(Typo.body)
                            .foregroundStyle(Palette.bgPrimary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text(BodyScanAlignment.coachingLine(verdict))
                            .font(Typo.readingItalic)
                            .foregroundStyle(Palette.bgPrimary)
                            .multilineTextAlignment(.center)
                            .contentTransition(.opacity)
                    }
                    if manualDoorOpen, countdown == nil {
                        Button("capture now") { Task { await fire() } }
                            .font(Typo.caption)
                            .foregroundStyle(Palette.bgPrimary.opacity(0.8))
                    }
                }
                .padding(.horizontal, Space.lg)
                .padding(.bottom, Space.xl)
            }
            .background(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.35)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 220)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
        .task {
            // The quiet fallback: never trap her behind a gate the
            // room's light won't satisfy.
            try? await Task.sleep(for: .seconds(8))
            if stage == .capture, countdown == nil {
                withAnimation(Motion.crossFade) { manualDoorOpen = true }
            }
        }
    }

    private func beginCountdown() {
        Task {
            for n in [3, 2, 1] {
                guard stage == .capture, arming.isArmed else {
                    withAnimation(Motion.crossFade) { countdown = nil }
                    return
                }
                withAnimation(Motion.crossFade) { countdown = n }
                Haptics.light()
                try? await Task.sleep(for: .milliseconds(650))
            }
            guard stage == .capture, arming.isArmed else {
                withAnimation(Motion.crossFade) { countdown = nil }
                return
            }
            countdown = nil
            await fire()
        }
    }

    private func fire() async {
        let quality = session.poseQuality
        capturedAnchors = BodyScanAlignment.anchors(session.joints)
        var still = await session.captureStill()
        #if DEBUG
        // The sim has no camera device at all — the QA flow proof
        // fabricates a paper still so the REAL downstream pipeline
        // (segmentation → keep → record) still exercises.
        if still == nil, BodyScanQA.allowManual {
            still = BodyScanQA.blankStill()
        }
        #endif
        guard let photo = still else {
            arming.disarm()
            return
        }
        Haptics.success()
        capturedQuality = quality
        capturedPhoto = photo
        let silhouette = await Task.detached(priority: .userInitiated) {
            BodySilhouetteRenderer.render(from: photo)
        }.value
        capturedSilhouette = silhouette
        withAnimation(Motion.crossFade) { stage = .landed }
    }

    // MARK: - Landed (keep it / retake)

    private var landedView: some View {
        VStack(spacing: 0) {
            closeRow
            Spacer()
            if let image = landedFace {
                mattedImage(image)
                    .padding(.horizontal, Space.xl)
            }
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()).lowercased())
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.top, Space.md)
            Spacer()
            VStack(spacing: Space.sm) {
                primaryCTA("keep it") { keep() }
                Button("retake") {
                    capturedPhoto = nil
                    capturedSilhouette = nil
                    arming.disarm()
                    stage = .capture
                }
                .font(Typo.body)
                .foregroundStyle(Palette.cocoaTertiary)
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.lg)
    }

    private var landedFace: UIImage? {
        BodyScanStore.renderMode == "photo"
            ? (capturedPhoto ?? capturedSilhouette)
            : (capturedSilhouette ?? capturedPhoto)
    }

    private func keep() {
        guard let photo = capturedPhoto,
              let silhouette = capturedSilhouette else { return }
        BodyScanStore.keep(
            photo: photo,
            silhouette: silhouette,
            poseQuality: capturedQuality,
            userId: userId,
            in: modelContext,
            anchors: capturedAnchors
        )
        Analytics.track(.bodyScanKept, properties: [
            "total": BodyScanStore.count(userId: userId, in: modelContext)
        ])
        Haptics.soft()
        capturedPhoto = nil
        capturedSilhouette = nil
        capturedAnchors = nil
        arming.disarm()
        withAnimation(Motion.crossFade) { stage = .record }
    }

    // MARK: - Record (her scans so far; P2 grows this into the timeline)

    private var recordView: some View {
        VStack(spacing: 0) {
            closeRow
            Spacer()
            if let latest = scans.first,
               let image = BodyScanPhotoStore.image(
                   scanId: latest.id, preferring: latest.renderMode
               ) {
                mattedImage(image)
                    .padding(.horizontal, Space.xl)
                Text(recordLine)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .padding(.top, Space.md)
            }
            if scans.count > 1 {
                priorStrip.padding(.top, Space.lg)
            }
            Spacer()
            primaryCTA(scans.isEmpty ? "first scan" : "scan again") {
                stage = .capture
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.lg)
    }

    private var recordLine: String {
        guard let first = scans.last, let latest = scans.first else { return "" }
        if scans.count == 1 {
            return "first scan · " + latest.capturedAt
                .formatted(.dateTime.month(.abbreviated).day()).lowercased()
        }
        return "\(scans.count) scans · began " + first.capturedAt
            .formatted(.dateTime.month(.abbreviated).day()).lowercased()
    }

    private var priorStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.sm) {
                ForEach(scans.dropFirst(), id: \.id) { scan in
                    if let thumb = BodyScanPhotoStore.image(
                        scanId: scan.id, preferring: scan.renderMode
                    ) {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 74)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, Space.lg)
        }
    }

    // MARK: - Shared chrome

    private var closeRow: some View {
        HStack {
            quietClose { onClose() }
            Spacer()
        }
        .padding(.top, Space.md)
    }

    private func quietClose(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.cocoaSecondary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Palette.bgElevated.opacity(0.9)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("close")
    }

    private func mattedImage(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Palette.bgElevated)
                    .shadow(color: Palette.cocoaPrimary.opacity(0.07), radius: 18, x: 0, y: 6)
            )
    }

    private func primaryCTA(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Text(label)
                .font(Typo.heading)
                .foregroundStyle(Palette.bgPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule().fill(Palette.cocoaPrimary)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview layer host

private struct BodyCameraPreview: UIViewRepresentable {
    let session: BodyCaptureSession

    func makeUIView(context: Context) -> PreviewHostView {
        let view = PreviewHostView()
        view.backgroundColor = .black
        session.previewLayer.frame = view.bounds
        view.layer.addSublayer(session.previewLayer)
        view.hostedLayer = session.previewLayer
        return view
    }

    func updateUIView(_ view: PreviewHostView, context: Context) {}

    final class PreviewHostView: UIView {
        var hostedLayer: CALayer?
        override func layoutSubviews() {
            super.layoutSubviews()
            hostedLayer?.frame = bounds
        }
    }
}

// MARK: - QA doors

enum BodyScanQA {
    /// --uitest-scan-allow-manual: the sim shows no person, so the
    /// pose gate can never arm — surface the manual door instantly
    /// for flow proofs. DEBUG-only; release builds never honor it.
    static var allowManual: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--uitest-scan-allow-manual")
        #else
        false
        #endif
    }

    #if DEBUG
    /// A paper still for the camera-less sim — the downstream
    /// pipeline treats it like any personless frame.
    static func blankStill() -> UIImage {
        let size = CGSize(width: 1080, height: 1440)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(red: 252/255, green: 250/255, blue: 247/255, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// --uitest-reset-body-scan: wipe consent/intro/backup prefs +
    /// every scan so a leg can start from the untouched state on a
    /// shared install (legs pollute each other otherwise).
    @MainActor
    static func resetIfRequested(userId: String, in context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("--uitest-reset-body-scan"),
              !userId.isEmpty else { return }
        for key in [BodyScanStore.consentSeenKey, BodyScanStore.renderModeKey,
                    BodyScanStore.backupOnKey, "bodyScan.introSeenAt",
                    "bodyScan.coverOptIn"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        BodyScanStore.deleteAll(userId: userId, in: context)
    }

    /// --uitest-seed-scans: three synthetic weekly scans (drawn ink
    /// figures, slightly narrowing) so the timeline + compare render
    /// REAL visual change on the camera-less sim. Marks consent +
    /// intro seen for deterministic QA runs.
    @MainActor
    static func seedScansIfRequested(userId: String, in context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("--uitest-seed-scans"),
              !userId.isEmpty,
              BodyScanStore.count(userId: userId, in: context) == 0 else { return }
        BodyScanStore.recordConsent(renderMode: "silhouette")
        UserDefaults.standard.set(
            ISO8601DateFormatter().string(from: .now), forKey: "bodyScan.introSeenAt")
        let widths: [CGFloat] = [0.34, 0.31, 0.285]
        for (i, daysAgo) in [21, 14, 7].enumerated() {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
            let figure = drawnFigure(torsoWidth: widths[i])
            BodyScanStore.keep(
                photo: figure, silhouette: figure,
                poseQuality: 0.9, userId: userId, in: context,
                capturedAt: date,
                anchors: (top: 0.88, bottom: 0.10, centerX: 0.5)
            )
        }
    }

    private static func drawnFigure(torsoWidth: CGFloat) -> UIImage {
        let size = CGSize(width: 1080, height: 1440)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(red: 252/255, green: 250/255, blue: 247/255, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 42/255, green: 31/255, blue: 30/255, alpha: 1).setFill()
            let w = size.width, h = size.height
            // head
            let headR = w * 0.075
            let head = CGRect(x: w/2 - headR, y: h * 0.12, width: headR * 2, height: headR * 2)
            ctx.cgContext.fillEllipse(in: head)
            // torso-to-legs capsule, width varies across seeds
            let torso = CGRect(x: w/2 - w * torsoWidth / 2, y: h * 0.27,
                               width: w * torsoWidth, height: h * 0.62)
            let path = UIBezierPath(roundedRect: torso, cornerRadius: w * torsoWidth / 2.4)
            path.fill()
        }
    }
    #endif
}
