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
            #if DEBUG
            // v10 QA: the scripted person — the guided flow's feel,
            // walkable on a camera-less sim.
            if BodyScanQA.simulatePose {
                await BodyScanQA.runPoseScript(into: session)
            }
            #endif
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
        // Composes to one screen; the largest type sizes scroll as
        // overflow instead of shoving the close row past the safe
        // area (the TodayView no-scroll-law pattern).
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                consentContent
                    .frame(minHeight: geo.size.height, alignment: .top)
            }
        }
    }

    private var consentContent: some View {
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
                    // XXXL wraps; long single words ("photographs")
                    // tighten instead of character-breaking.
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
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

    // v10 (docs/app_v10 §4c) — THE CHAMBER: the camera lives inside
    // a matted aperture on the house paper; the app's identity holds
    // through its most important moment. The words live in ink on
    // paper below the glass — legibility never depends on her room.
    // THE ARMING FRAME finally renders the streak (`Arming.progress`
    // shipped v9 as a dead accessor): the aperture's border inks in
    // as she holds still, drains when she drifts, and the countdown
    // begins when the frame is fully drawn.
    private var captureView: some View {
        VStack(spacing: 0) {
            HStack {
                quietClose {
                    if scans.isEmpty { onClose() } else { stage = .record }
                }
                Spacer()
            }
            .padding(.horizontal, Space.lg)

            aperture
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.sm)

            // The word row — ink on paper, one voice at a time:
            // the countdown numeral when it runs, else the coaching.
            VStack(spacing: Space.sm) {
                if let count = countdown {
                    Text("\(count)")
                        .font(Typo.display)
                        .monospacedDigit()
                        .foregroundStyle(Palette.cocoaPrimary)
                        .contentTransition(.numericText(countsDown: true))
                        .accessibilityLabel("capturing in \(count)")
                } else if session.permissionDenied {
                    Text("jeni needs the camera for this — settings › privacy › camera")
                        .font(Typo.body)
                        .foregroundStyle(Palette.cocoaSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text(BodyScanAlignment.coachingLine(verdict))
                        .font(Typo.readingItalic)
                        .foregroundStyle(Palette.cocoaPrimary)
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)
                }
                if manualDoorOpen, countdown == nil {
                    Button("capture now") { Task { await fire() } }
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaTertiary)
                }
            }
            .frame(minHeight: 96)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.md)
            .animation(Motion.crossFade, value: countdown)
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

    private var aperture: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return ZStack {
            BodyCameraPreview(session: session)

            if let frozen = session.frozenFrame {
                Image(uiImage: frozen)
                    .resizable()
                    .scaledToFill()
            }

            // Her last silhouette as the alignment ghost — stand
            // where you stood.
            if let last = scans.first,
               let ghost = BodyScanPhotoStore.silhouette(scanId: last.id),
               session.frozenFrame == nil {
                Image(uiImage: ghost)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.18)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(
                Palette.cocoaPrimary.opacity(0.12 + 0.78 * arming.progress),
                lineWidth: 0.5 + 2.0 * arming.progress
            )
            .animation(.linear(duration: 0.15), value: arming.progress)
        )
        .accessibilityElement()
        .accessibilityLabel("camera")
        .accessibilityValue(BodyScanAlignment.coachingLine(verdict))
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
        // The sim has no camera device at all — the QA flow proofs
        // fabricate a still so the REAL downstream pipeline
        // (segmentation → keep → record) still exercises. The
        // simulate-pose door supplies a photo-like figure so the
        // develop wash is visible motion.
        if still == nil, BodyScanQA.simulatePose {
            still = BodyScanQA.simulatedStill()
        } else if still == nil, BodyScanQA.allowManual {
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
        var silhouette = await Task.detached(priority: .userInitiated) {
            BodySilhouetteRenderer.render(from: photo)
        }.value
        #if DEBUG
        // The simulate-pose door's still is a DRAWING — Vision finds
        // no person in it, so the real render washes to blank paper.
        // Substitute the deterministic ink figure so the develop and
        // the record read honestly on the sim. (The real renderer
        // still ran above; devices never take this branch.)
        if BodyScanQA.simulatePose {
            silhouette = BodyFigure.inkImage(
                size: CGSize(width: 1080, height: 1440), waist: 1.0
            )
        }
        #endif
        capturedSilhouette = silhouette
        withAnimation(Motion.crossFade) { stage = .landed }
    }

    // MARK: - Landed (keep it / retake)

    private var landedView: some View {
        VStack(spacing: 0) {
            closeRow
            Spacer()
            // v10 (§4c) — THE DEVELOP: when her record keeps the ink
            // face, the photograph develops INTO the silhouette in
            // front of her — the privacy promise performed, not
            // claimed. Photo-mode keeps the mirror, undeveloped.
            if BodyScanStore.renderMode != "photo",
               let photo = capturedPhoto, let silhouette = capturedSilhouette {
                DevelopingMat(photo: photo, silhouette: silhouette)
                    .padding(.horizontal, Space.xl)
            } else if let image = landedFace {
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

    // v10: the one mat grammar (BodyMat) — the figure sits on its
    // own paper; a hairline and the ink shadow give it the print's
    // edge. No white card, no pillarbox seam.
    private func mattedImage(_ image: UIImage) -> some View {
        BodyMat(image: image)
            .aspectRatio(faceAspect(image), contentMode: .fit)
    }

    private func faceAspect(_ image: UIImage) -> CGFloat {
        guard image.size.height > 0 else { return 3.0 / 4.0 }
        return image.size.width / image.size.height
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

// MARK: - DevelopingMat (v10 — the signature moment)
//
// The photograph develops into ink: a soft wash rises through the
// mat, and what it has passed is silhouette — the pixels become
// evidence on paper while she watches. One pass, ~1.2s, a quiet
// settle haptic when the ink dries. Reduce Motion receives the
// finished print (a crossfade), never the wash.

private struct DevelopingMat: View {
    let photo: UIImage
    let silhouette: UIImage

    /// 0 = the photograph; climbs past 1 so the wash's soft edge
    /// clears the top of the mat.
    @State private var wash: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Image(uiImage: photo)
                .resizable()
                .scaledToFit()
            Image(uiImage: silhouette)
                .resizable()
                .scaledToFit()
                .mask {
                    // A soft-edged column rising through the mat:
                    // wash 0 parks it below the print; 1.2 carries
                    // the feathered edge clear of the top.
                    GeometryReader { geo in
                        let h = geo.size.height
                        VStack(spacing: 0) {
                            LinearGradient(
                                colors: [.clear, .black],
                                startPoint: .top, endPoint: .bottom
                            )
                            .frame(height: h * 0.18)
                            Rectangle().fill(.black)
                                .frame(height: h)
                        }
                        .offset(y: h - wash * h)
                    }
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Palette.bgPrimary)
                .shadow(color: Palette.cocoaPrimary.opacity(0.07), radius: 18, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Palette.cocoaPrimary.opacity(0.10), lineWidth: 0.5)
        )
        .accessibilityLabel("your scan, kept as an ink silhouette")
        .onAppear {
            guard wash == 0 else { return }
            if reduceMotion {
                withAnimation(Motion.crossFade) { wash = 1.2 }
                return
            }
            withAnimation(.easeInOut(duration: 1.15).delay(0.3)) {
                wash = 1.2
            } completion: {
                Haptics.soft()
            }
        }
    }
}

// MARK: - Preview layer host

private struct BodyCameraPreview: UIViewRepresentable {
    let session: BodyCaptureSession

    func makeUIView(context: Context) -> PreviewHostView {
        let view = PreviewHostView()
        // v10: the chamber never shows a black void — before the
        // first frame arrives (and on the camera-less sim) the
        // aperture holds the house paper.
        view.backgroundColor = UIColor(
            red: 252 / 255, green: 250 / 255, blue: 247 / 255, alpha: 1
        )
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

    /// --uitest-scan-simulate-pose (v10): script a person into the
    /// camera-less sim — a beat of searching, then a held aligned
    /// pose — so the guided flow itself (coaching line → arming
    /// frame → countdown → shutter → develop) walks end to end on
    /// the simulator. DEBUG-only.
    static var simulatePose: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--uitest-scan-simulate-pose")
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

    /// A photo-like still for the simulate-pose door: the drawn
    /// figure on a warm-gray field, so the develop wash (photo →
    /// ink-on-paper) is VISIBLE motion on the sim regardless of
    /// what segmentation makes of a drawing.
    static func simulatedStill() -> UIImage {
        let size = CGSize(width: 1080, height: 1440)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(red: 214/255, green: 208/255, blue: 200/255, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 62/255, green: 50/255, blue: 46/255, alpha: 1).setFill()
            let inset = CGRect(origin: .zero, size: size)
                .insetBy(dx: size.width * 0.16, dy: size.height * 0.07)
            for sub in BodyFigure.subpaths(in: inset, waist: 1.0) {
                ctx.cgContext.addPath(sub.cgPath)
                ctx.cgContext.fillPath(using: .winding)
            }
        }
    }

    /// The pose script: ~1.2s of searching (two joints only), then
    /// a held aligned pose with per-frame jitter so every tick lands
    /// as a fresh frame in the engine. Runs until the stage leaves
    /// capture; the caller owns cancellation by scoping the task.
    @MainActor
    static func runPoseScript(into session: BodyCaptureSession) async {
        func aligned(_ jitter: CGFloat) -> [BodyScanAlignment.Key: BodyScanAlignment.Joint] {
            [
                .leftShoulder: .init(0.42 + jitter, 0.72),
                .rightShoulder: .init(0.58 + jitter, 0.72),
                .leftHip: .init(0.44 + jitter, 0.45),
                .rightHip: .init(0.56 + jitter, 0.45),
                .leftAnkle: .init(0.46 + jitter, 0.12),
                .rightAnkle: .init(0.54 + jitter, 0.12)
            ]
        }
        // Searching: shoulders only — the gate wants the whole
        // figure. Long enough (~2.4s) that the coaching beat is
        // legible on a recording and assertable by the proof leg.
        for i in 0..<24 {
            guard !Task.isCancelled else { return }
            let jitter = CGFloat(i % 2) * 0.001
            session.qaInject(joints: [
                .leftShoulder: .init(0.42 + jitter, 0.70),
                .rightShoulder: .init(0.58 + jitter, 0.70)
            ], quality: 0.3)
            try? await Task.sleep(for: .milliseconds(100))
        }
        // Aligned, held: the streak arms, the countdown runs, the
        // shutter fires. Keep injecting through the countdown so the
        // stillness re-checks read fresh aligned frames.
        for i in 0..<60 {
            guard !Task.isCancelled else { return }
            let jitter = CGFloat(i % 2) * 0.001
            session.qaInject(joints: aligned(jitter), quality: 0.92)
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    /// --uitest-reset-body-scan: wipe every scan RECORD so a leg can
    /// start from the untouched state on a shared install. The PREFS
    /// half lives synchronously in PlankAIApp.init (the consent
    /// race) — wiping them again here, in the async launch task,
    /// raced a leg's own begin-tap and erased freshly-recorded
    /// consent (v10: the P1 persist assert caught it).
    @MainActor
    static func resetIfRequested(userId: String, in context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("--uitest-reset-body-scan"),
              !userId.isEmpty else { return }
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
        // v10: the seeds wear the shared BodyFigure — a believable
        // human silhouette whose waist narrows week to week, so every
        // design frame and reel over seeded data looks honest.
        let waists: [CGFloat] = [1.10, 1.02, 0.95]
        for (i, daysAgo) in [21, 14, 7].enumerated() {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
            let figure = BodyFigure.inkImage(
                size: CGSize(width: 1080, height: 1440), waist: waists[i]
            )
            BodyScanStore.keep(
                photo: figure, silhouette: figure,
                poseQuality: 0.9, userId: userId, in: context,
                capturedAt: date,
                anchors: (top: 0.93, bottom: 0.05, centerX: 0.5)
            )
        }
    }
    #endif
}
