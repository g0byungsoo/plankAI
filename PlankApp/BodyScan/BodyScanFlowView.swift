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
        /// v10.3 — THE KEPT MOMENT: the result is the comparison
        /// (today beside last week + the record's standing line),
        /// the arc the best scan experiences share.
        case kept
        case record
    }

    @State private var stage: Stage = .record
    @State private var session = BodyCaptureSession()
    // v10.1 — THE MIRROR CHECK-IN: the fire decision is a person
    // holding steady (~1s) or her own thumb; no countdown, no pose
    // theater. The gate is pure and unit-tested.
    @State private var gate = MirrorGate()
    @State private var firing = false
    /// v11.5 — the day's composed state, read once when the result
    /// renders: the weekly trend delta and today's lead. The result
    /// closes on an action, so it needs the plan.
    @State private var resultSnapshot: TodaySnapshot?
    @State private var flash = false
    @State private var personAnnounced = false
    // v10.3 — the kept moment's material.
    @State private var keptPlate: UIImage?
    @State private var priorPlate: UIImage?
    @State private var priorDate: Date?
    @State private var keptLine: String?
    // v10.4 — THE RESULT: progress leads, the estimate supports.
    @State private var progressRead: BandProfile.Read?
    @State private var fatEstimate: BodyFatEstimate.Read?
    @State private var capturedPhoto: UIImage?
    @State private var capturedSilhouette: UIImage?
    @State private var capturedQuality: Double = 0
    @State private var capturedAnchors: (top: Double, bottom: Double, centerX: Double)?
    @State private var consentMode = "silhouette"
    @State private var appeared = false

    private var scans: [BodyScanRecord] {
        BodyScanStore.all(userId: userId, in: modelContext)
    }

    // The estimate's inputs — her own profile answers, never the
    // photograph (L3; the consent sheet's promise, kept).
    private static var profileHeightCm: Double? {
        let cm = UserDefaults.standard.double(forKey: "onboardingHeightCm")
        return cm > 100 ? cm : nil
    }

    private static var profileAgeYears: Int? {
        let years = UserDefaults.standard.integer(forKey: "onb_v5_age_years")
        return years >= 18 ? years : nil
    }

    /// Her onboarding weight — used only until a real weigh-in
    /// exists, so the panel can speak on day one.
    private static var profileStartWeightKg: Double? {
        let kg = UserDefaults.standard.double(forKey: "onboardingCurrentWeightKg")
        return kg > 25 ? kg : nil
    }

    private static var profileIsFemale: Bool? {
        switch (UserDefaults.standard.string(forKey: "onboardingGender") ?? "").lowercased() {
        case "female": return true
        case "male": return false
        default: return nil   // never assumed
        }
    }

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            switch stage {
            case .consent: consentView
            case .capture: captureView
            case .landed: landedView
            case .kept: keptView
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
            await session.requestPermissionAndStart()
            #if DEBUG
            // v10 QA: the scripted person — the check-in's feel,
            // walkable on a camera-less sim.
            if BodyScanQA.simulatePose {
                await BodyScanQA.runPoseScript(into: session)
            }
            #endif
        }
        .onChange(of: session.joints) { _, joints in
            guard stage == .capture, !firing else { return }
            let sawPerson = gate.personSeen
            gate.ingest(joints)
            if gate.personSeen, !sawPerson, !personAnnounced {
                // One quiet tick when the mirror first finds her.
                personAnnounced = true
                Haptics.light()
            }
            if gate.shouldFire {
                Task { await fire() }
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
                         line: "an ink line of your waist. the shape of change.")
                modeCard("photo", title: "as photographs",
                         line: "the mirror, kept honestly.")
            }
            Spacer()
            // v10.4 — the ritual is taught ONCE, here, the way Face
            // ID teaches at setup: the instrument itself never
            // instructs (D10 draft).
            Text("stand so your waist fills the window. hold still. it takes itself.")
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, Space.sm)
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

    // MARK: - Capture (THE INSTRUMENT)

    // v10.4 (the founder's redesign) — the capture is no longer a
    // camera; it is an instrument. The page is paper with ONE drawn
    // figure on it, and the figure's midsection is a live window —
    // the only region the record analyzes. Because the drawn torso
    // continues above and below that window, alignment needs no
    // words: when her body's edges continue the drawn lines, she is
    // standing where she stood last week. The illustration teaches
    // the behavior (Face ID's inevitability), so nothing instructs:
    // no arrows, no overlays, no coaching paragraphs, no captions.
    // VoiceOver still gets every word through the element's value —
    // the guidance moved channels, it did not disappear (ADA bar).

    /// The figure's own geometry, in figure-local fractions: the
    /// abdomen band spans y 0.314…0.570 of the drawn figure, and the
    /// figure's rect is 0.593 as wide as it is tall (BodyFigure's
    /// proportions — the same drawing the seeds and the ghost use).
    private static let figureBandTop = 0.3140
    private static let figureBandBottom = 0.5698
    private static let figureAspect = 0.593

    private var captureView: some View {
        GeometryReader { geo in
            // The window is as large as the page can hold the whole
            // figure — height decides, width is capped so the
            // instrument never touches the margins.
            let bandFraction = Self.figureBandBottom - Self.figureBandTop
            let hFromHeight = geo.size.height * bandFraction
            let w = min(hFromHeight * WaistCrop.windowAspect, geo.size.width * 0.86)
            let h = w / WaistCrop.windowAspect
            let figureHeight = h / bandFraction
            let figureWidth = figureHeight * Self.figureAspect
            // Center the BAND on the page, not the figure: the drawn
            // body hangs from its own waist.
            let bandCenter = (Self.figureBandTop + Self.figureBandBottom) / 2

            ZStack {
                InstrumentFigure(
                    recognized: gate.personSeen,
                    settled: gate.progress
                )
                .frame(width: figureWidth, height: figureHeight)
                .offset(y: (0.5 - bandCenter) * figureHeight)

                apertureWindow
                    .frame(width: w, height: h)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .overlay(alignment: .topLeading) {
            quietClose {
                if scans.isEmpty { onClose() } else { stage = .record }
            }
            .padding(.leading, Space.lg)
            .padding(.top, Space.md)
        }
        .overlay(alignment: .bottom) {
            // The ONLY words on this page, and only when the
            // instrument cannot work at all.
            if session.permissionDenied {
                Text(mirrorCaption)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Space.lg)
                    .padding(.bottom, Space.xl)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Her thumb is the shutter — she is holding the phone.
            guard !firing else { return }
            Task { await fire() }
        }
        .accessibilityElement()
        .accessibilityIdentifier("mirror.capture")
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("capture")
        .accessibilityValue(mirrorCaption)
        .accessibilityHint("captures your check-in now")
    }

    /// The live window: the figure's midsection, and the ONLY region
    /// the record analyzes. Its aspect is the kept crop's
    /// (WaistCrop.windowAspect — tested law) and the feed is enlarged
    /// behind it so the aperture shows the default band exactly:
    /// what she frames is what is kept, pixel for pixel. Sizing
    /// belongs to the instrument, which hangs it on the drawn body.
    private var apertureWindow: some View {
        GeometryReader { geo in
            let feedWidth = geo.size.width / (WaistCrop.halfWidth * 2)
            let feedHeight = feedWidth * 4 / 3
            ZStack {
                BodyCameraPreview(session: session)
                    .frame(width: feedWidth, height: feedHeight)
                if let frozen = session.frozenFrame {
                    Image(uiImage: frozen)
                        .resizable()
                        .scaledToFill()
                        .frame(width: feedWidth, height: feedHeight)
                }
                // The paper flash — the shutter light, in the plate.
                Palette.bgPrimary
                    .opacity(flash ? 0.9 : 0)
                    .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                // Glass, not a hole in the page: a breath of tone
                // under the feed so the aperture reads as an
                // instrument even before the first frame lands.
                .fill(Palette.cocoaPrimary.opacity(0.045))
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Palette.bgPrimary)
                )
                .shadow(color: Palette.cocoaPrimary.opacity(0.07), radius: 18, x: 0, y: 6)
        )
        // The frame is the meter: a legible rest line (this window
        // must say "your waist goes HERE" even before video fills
        // it) that inks in as she holds still.
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    Palette.cocoaPrimary.opacity(0.18 + 0.45 * gate.progress),
                    lineWidth: 1.0 + 0.9 * gate.progress
                )
                .animation(.linear(duration: 0.15), value: gate.progress)
        )
        // v11.5 — THE STILLNESS RING: the same rounded rect, trimmed.
        // Holding still literally DRAWS the frame closed. This is the
        // "hold still. it takes itself." promise made visible, and the
        // only progress indicator the instrument needs.
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .trim(from: 0, to: gate.progress)
                .stroke(
                    Palette.cocoaPrimary.opacity(0.85),
                    style: StrokeStyle(lineWidth: 2.4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.15), value: gate.progress)
                .allowsHitTesting(false)
        )
        // v11.5 — THE BRACKETS: the universal lock-on grammar (Face
        // ID / camera). They sit OUTSIDE the aperture and converge
        // onto its corners the moment a person is found, so
        // recognition is felt before it is read. Wordless, per L3.
        .overlay(
            ApertureBrackets(locked: gate.personSeen)
                .allowsHitTesting(false)
        )
    }

    private var mirrorCaption: String {
        if session.permissionDenied {
            return "jeni needs the camera for this. settings › privacy › camera"
        }
        if !gate.personSeen {
            return "find your waist in the frame · or tap"
        }
        // Repeatability over precision: the window is a fixed target,
        // so distance words steer toward FILLING it — the live band's
        // thickness against the window's own band. Works from scan
        // one; never a number (L3).
        if let live = WaistCrop.band(from: session.joints) {
            let ratio = live.height / WaistCrop.defaultBand.height
            if ratio > 1.3 { return "a step back" }
            if ratio < 0.75 { return "a touch closer" }
        }
        return "hold still"
    }

    private func fire() async {
        guard !firing else { return }
        firing = true
        // The paper flash — the shutter, visible in her mirror.
        withAnimation(.easeOut(duration: 0.08)) { flash = true }
        withAnimation(.easeIn(duration: 0.30).delay(0.10)) { flash = false }
        let quality = session.poseQuality
        // v10.3c — THE WINDOW is the record: the aperture showed the
        // default band exactly, so the keep stores exactly that. One
        // fixed window every week = consistency by construction (the
        // crop no longer chases the pose; she aligns to the frame).
        // The band's bounds ride the anchor fields; the full frame
        // is never written (L4).
        let band = WaistCrop.defaultBand
        capturedAnchors = (top: band.top, bottom: band.bottom, centerX: band.centerX)
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
        guard let full = still else {
            gate.reset()
            firing = false
            return
        }
        Haptics.success()
        capturedQuality = quality
        let photo = WaistCrop.image(full, band: band)
        capturedPhoto = photo
        var silhouette = await Task.detached(priority: .userInitiated) {
            BodySilhouetteRenderer.render(from: photo)
        }.value
        #if DEBUG
        // The simulate-pose door's still is a DRAWING — Vision finds
        // no person in it, so the real render washes to blank paper.
        // Substitute the deterministic ink band so the develop and
        // the record read honestly on the sim. (The real renderer
        // still ran above; devices never take this branch.)
        if BodyScanQA.simulatePose {
            // Narrower than the newest seed (0.95) so the sim walks
            // the leaner branch of the progress read end to end.
            silhouette = BodyFigure.inkBand(waist: 0.90)
        }
        #endif
        capturedSilhouette = silhouette
        withAnimation(Motion.crossFade) { stage = .landed }
    }

    // MARK: - Landed (keep it / retake)

    private var landedView: some View {
        VStack(spacing: 0) {
            closeRow
            // v11.5: the plate is the page's subject, not an object
            // adrift — a title register above it, the actions below.
            // (The centering Spacers left ~600pt of dead air; caught
            // on film.)
            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR CHECK-IN")
                    .font(Typo.eyebrow)
                    .kerning(1.4)
                    .foregroundStyle(Palette.cocoaTertiary)
                JeniHeadline("kept, if you like it.", italic: ["kept,"])
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.blockGap)
            .padding(.bottom, Space.sectionGap)
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
            Spacer(minLength: Space.sectionGap)
            VStack(spacing: Space.sm) {
                primaryCTA("keep it") { keep() }
                Button("retake") {
                    capturedPhoto = nil
                    capturedSilhouette = nil
                    gate.reset()
                    firing = false
                    personAnnounced = false
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
        // The comparison's other half, BEFORE today replaces it.
        let today = TodayStateService.dayKey()
        let prior = scans.first(where: { $0.dayKey != today })
        if let prior {
            priorPlate = BodyScanPhotoStore.image(
                scanId: prior.id, preferring: prior.renderMode
            )
            priorDate = prior.capturedAt
        } else {
            priorPlate = nil
            priorDate = nil
        }
        // v10.4 — BODY PROGRESS: today's band against the last one,
        // read from her own silhouettes. Only the fixed-window era
        // compares (an older pose-derived crop is not the same window
        // twice), and only the ink faces — a photograph's light is
        // not a shape (L3: words out, never numbers).
        let body = BodyStateService.current(userId: userId, in: modelContext)
        let falling = (body.weight?.trendEstablished ?? false)
            && (body.weight?.emaDelta7dKg ?? 0) <= -0.1
        if let prior, prior.region == "waist",
           let priorInk = BodyScanPhotoStore.silhouette(scanId: prior.id),
           let now = BandProfile.profile(of: silhouette),
           let then = BandProfile.profile(of: priorInk) {
            progressRead = BandProfile.read(now: now, then: then, trendFalling: falling)
        } else {
            progressRead = nil
        }
        fatEstimate = BodyFatEstimate.read(
            healthPct: body.composition?.bodyFatPct,
            weightKg: body.weight?.latestKg ?? Self.profileStartWeightKg,
            heightCm: Self.profileHeightCm,
            ageYears: Self.profileAgeYears,
            isFemale: Self.profileIsFemale
        )
        BodyScanStore.keep(
            photo: photo,
            silhouette: silhouette,
            poseQuality: capturedQuality,
            userId: userId,
            in: modelContext,
            anchors: capturedAnchors,
            region: "waist"
        )
        Analytics.track(.bodyScanKept, properties: [
            "total": BodyScanStore.count(userId: userId, in: modelContext)
        ])
        Haptics.soft()
        keptPlate = landedFace
        keptLine = BodyChangeRead.line(
            scans: scans.map {
                .init(capturedAt: $0.capturedAt, poseQuality: $0.poseQuality)
            },
            trendEstablished: false,
            trendDeltaKg: nil
        )
        capturedPhoto = nil
        capturedSilhouette = nil
        capturedAnchors = nil
        gate.reset()
        firing = false
        withAnimation(Motion.crossFade) { stage = .kept }
    }

    // MARK: - THE RESULT (v10.4 — progress is the story)
    //
    // The founder's law for this screen: users care more about "am I
    // changing?" than "what percentage am I?". So BODY PROGRESS is
    // the hero — her two plates side by side, the change named in
    // words, the regions that moved called out — and the estimated
    // body fat is a quiet second panel that supports the story
    // without pretending to be a measurement.

    private var keptView: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                resultContent
                    .frame(minHeight: geo.size.height, alignment: .top)
            }
        }
        .task { await loadResultSnapshot() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("scan.result")
    }

    private var resultContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            closeRow
            Spacer(minLength: Space.lg)

            Text("YOUR CHECK-IN")
                .font(Typo.eyebrow)
                .kerning(1.4)
                .foregroundStyle(Palette.cocoaTertiary)
            Text(dateline)
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.top, 2)

            progressBlock
                .padding(.top, Space.lg)

            weeklyChangeBlock
                .padding(.top, Space.sectionGap)

            if let estimate = fatEstimate {
                estimateBlock(estimate)
                    .padding(.top, Space.sectionGap)
            }

            nextStepBlock
                .padding(.top, Space.sectionGap)

            returnLine
                .padding(.top, Space.sectionGap)

            Spacer(minLength: Space.xl)
            primaryCTA("done") {
                withAnimation(Motion.crossFade) { stage = .record }
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.lg)
    }

    private var dateline: String {
        Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()).lowercased()
    }

    /// v11.5 — WHAT THE WEEK DID. The founder's result brief asks
    /// for the weekly change beside the plates: the scale's own
    /// trend delta, floor-gated (an unestablished trend says so
    /// rather than inventing a number), plus the confidence the
    /// plates themselves earn.
    @ViewBuilder
    private var weeklyChangeBlock: some View {
        JeniSurface {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("THIS WEEK")
                    .font(Typo.eyebrow)
                    .kerning(1.4)
                    .foregroundStyle(Palette.cocoaTertiary)

                HStack(alignment: .firstTextBaseline, spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(weeklyChangeValue)
                            .font(.custom("JeniHeroSerif-Regular", size: 26, relativeTo: .title2))
                            .foregroundStyle(Palette.textPrimary)
                        Text("on the scale")
                            .font(Typo.statLabel)
                            .foregroundStyle(Palette.cocoaTertiary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(confidenceWord)
                            .font(.custom("JeniHeroSerif-Regular", size: 26, relativeTo: .title2))
                            .foregroundStyle(Palette.textPrimary)
                        Text("confidence in this read")
                            .font(Typo.statLabel)
                            .foregroundStyle(Palette.cocoaTertiary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The scale's week, in her units — or the honest absence of one.
    private var weeklyChangeValue: String {
        guard let snap = resultSnapshot, snap.trendIsEstablished,
              let delta = snap.emaDelta7dKg else { return "not yet" }
        let unit = WeightUnit(
            rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "lb"
        ) ?? .lb
        let shown = abs(unit.display(fromKg: delta))
        if shown < 0.05 { return "steady" }
        return String(format: "%@%.1f %@", delta < 0 ? "−" : "+", shown, unit.label)
    }

    /// Confidence is the PLATES' confidence: BandProfile says whether
    /// the two frames were comparable enough to speak plainly.
    private var confidenceWord: String {
        guard let read = progressRead else { return "building" }
        return read.confident ? "clear" : "soft"
    }

    /// v11.5 — TODAY, FROM HERE. The result closes on an action, not
    /// on a number: the day's composed lead (CarePlanEngine), so the
    /// scan hands her straight back into the plan.
    @ViewBuilder
    private var nextStepBlock: some View {
        if let lead = resultSnapshot?.carePlan.lead {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("TODAY, FROM HERE")
                    .font(Typo.eyebrow)
                    .kerning(1.4)
                    .foregroundStyle(Palette.cocoaTertiary)
                JeniSurface {
                    VStack(alignment: .leading, spacing: 4) {
                        JeniHeadline(leadWords(lead.beat), italic: [])
                        if let because = lead.because {
                            Text(because)
                                .font(Typo.caption)
                                .foregroundStyle(Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func leadWords(_ beat: ProgramDayPrescription) -> String {
        switch beat {
        case .snapMeal: return "add your next meal."
        case .workout(_, let minutes, _): return "move for \(minutes) minutes."
        case .lesson: return "today's 2-minute lesson."
        case .weighIn: return "weigh in."
        case .breath: return "60 seconds of breath."
        case .medication: return "mark today's dose."
        case .bodyScan: return "your check-in is kept."
        case .steps(let goal): return "\(goal.formatted()) steps."
        case .plank, .water, .measurements: return "keep the day gentle."
        }
    }

    /// The hero: the comparison, then what it says.
    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("BODY PROGRESS")
                .font(Typo.kicker)
                .kerning(2.0)
                .foregroundStyle(Palette.cocoaSecondary)
                .padding(.bottom, Space.sm)

            // Her two plates, the same size, so the eye does the
            // comparing before a word is read.
            HStack(alignment: .top, spacing: Space.sm) {
                if let prior = priorPlate {
                    platePanel(prior, caption: priorCaption, dimmed: true)
                }
                if let plate = keptPlate {
                    platePanel(plate, caption: "today", dimmed: false,
                               focus: progressRead?.region)
                }
            }
            .padding(.bottom, Space.md)

            ItalicAccentText(
                progressRead?.headline ?? keptLine ?? "your first frame is kept.",
                italic: [],
                baseFont: .custom("JeniHeroSerif-Regular", size: 27, relativeTo: .title2),
                italicFont: .custom("JeniHeroSerif-Italic", size: 27, relativeTo: .title2),
                color: Palette.textPrimary,
                alignment: .leading
            )
            .lineSpacing(-3)
            .kerning(-0.3)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("result.progress")

            if let read = progressRead {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(read.notes, id: \.self) { note in
                        Text(note)
                            .font(Typo.body)
                            .foregroundStyle(Palette.cocoaSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !read.confident {
                        Text("a photograph carries the light and the hour with it.")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.cocoaTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, Space.sm)
            } else if priorPlate == nil {
                Text("next week's frame turns this into a comparison.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.cocoaSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.sm)
            }
        }
    }

    private var priorCaption: String {
        guard let priorDate else { return "last time" }
        let days = Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: priorDate),
            to: Calendar.current.startOfDay(for: .now)
        ).day ?? 0
        if days >= 13 { return "\(max(2, days / 7)) weeks ago" }
        if days >= 6 { return "last week" }
        return "last time"
    }

    private func platePanel(
        _ image: UIImage, caption: String, dimmed: Bool,
        focus: BandProfile.Region? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(faceAspect(image), contentMode: .fit)
                .frame(maxWidth: .infinity)
                .opacity(dimmed ? 0.5 : 1)
                // The region that moved keeps its full ink while the
                // rest of the plate softens — the eye is walked to
                // the change instead of being pointed at it.
                .mask(focusMask(focus))
            Text(caption)
                .font(Typo.caption)
                .foregroundStyle(dimmed ? Palette.cocoaTertiary : Palette.cocoaSecondary)
        }
    }

    /// Emphasis, not instrumentation: the plate breathes a little
    /// quieter away from the region that moved. A hard-edged band
    /// read like a redaction bar — this is a vignette the eye obeys
    /// without ever noticing it was steered.
    @ViewBuilder
    private func focusMask(_ focus: BandProfile.Region?) -> some View {
        if let focus {
            let center: Double = {
                switch focus {
                case .upper: return 0.17
                case .middle: return 0.5
                case .lower: return 0.83
                }
            }()
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(weight(at: 0, center: center)), location: 0),
                    .init(color: .black.opacity(weight(at: 0.25, center: center)), location: 0.25),
                    .init(color: .black.opacity(weight(at: 0.5, center: center)), location: 0.5),
                    .init(color: .black.opacity(weight(at: 0.75, center: center)), location: 0.75),
                    .init(color: .black.opacity(weight(at: 1, center: center)), location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
        } else {
            Rectangle().fill(.black)
        }
    }

    private func weight(at point: Double, center: Double) -> Double {
        1 - min(0.24, abs(point - center) * 0.42)
    }

    /// The supporting panel. Never the hero, never a claim: the value
    /// carries its provenance and its limits in the same breath.
    private func estimateBlock(_ estimate: BodyFatEstimate.Read) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Palette.cocoaPrimary.opacity(0.12))
                .frame(height: 0.5)
                .padding(.bottom, Space.md)
            Text("ESTIMATED BODY FAT")
                .font(Typo.kicker)
                .kerning(2.0)
                .foregroundStyle(Palette.cocoaSecondary)
            Text(estimate.value)
                .font(.custom("JeniHeroSerif-Regular", size: 30, relativeTo: .title))
                .foregroundStyle(Palette.cocoaPrimary)
                .padding(.top, 4)
                .accessibilityIdentifier("result.estimate")
            Text(estimate.provenance)
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
            Text(estimate.caveat)
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.sm)
        }
    }

    /// The reason to come back: the record only pays in weeks.
    private var returnLine: some View {
        let next = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        return HStack(spacing: 6) {
            Text("next check-in")
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)
            Text(next.formatted(.dateTime.month(.wide).day()).lowercased())
                .font(.custom("JeniHeroSerif-Regular", size: 17, relativeTo: .body))
                .foregroundStyle(Palette.cocoaPrimary)
        }
    }

    /// One read of the day's state, shared by the result and the
    /// record (both speak about the same week).
    private func loadResultSnapshot() async {
        guard resultSnapshot == nil, !userId.isEmpty else { return }
        resultSnapshot = TodayStateService.snapshot(userId: userId, in: modelContext)
    }

    // MARK: - Record (her scans so far; P2 grows this into the timeline)

    private var recordView: some View {
        VStack(spacing: 0) {
            closeRow
            // v11.5: a record is a PAGE — it names itself and says
            // where it stands. (The bare plate floated in ~600pt of
            // dead air; caught on film.)
            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR RECORD")
                    .font(Typo.eyebrow)
                    .kerning(1.4)
                    .foregroundStyle(Palette.cocoaTertiary)
                JeniHeadline(recordHeadline.text, italic: recordHeadline.italic)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.blockGap)
            .padding(.bottom, Space.sectionGap)

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
        .task { await loadResultSnapshot() }
    }

    /// What the record says about itself: the floor-gated change
    /// line when it has earned one, else its own standing.
    private var recordHeadline: (text: String, italic: [String]) {
        if let line = BodyChangeRead.line(
            scans: scans.map { .init(capturedAt: $0.capturedAt, poseQuality: $0.poseQuality) },
            trendEstablished: resultSnapshot?.trendIsEstablished ?? false,
            trendDeltaKg: resultSnapshot?.emaDelta7dKg
        ) {
            return (line, [])
        }
        if scans.count <= 1 { return ("one frame in. the record starts here.", ["starts"]) }
        return ("\(scans.count) frames kept.", ["kept."])
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
                // The finished print, no traveling wash — a fast
                // mask sweep is still motion.
                wash = 1.2
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

// MARK: - InstrumentFigure (v10.4 — the guide that is not a camera)
//
// The drawn body the live window hangs inside. It is a fine ink line
// on paper — furniture, never anyone's photograph — and it does the
// whole job of instruction:
//
// • ALIGNMENT: the torso continues above and below the window, so a
//   body standing at the right distance CONTINUES the drawn lines.
//   Misaligned reads as a broken line. No arrow ever has to say it.
// • RECOGNITION: the line deepens the moment the frame finds a
//   person — the instrument acknowledging her, the way Face ID does.
// • BREATH: a barely-there rise and fall keeps the page alive
//   without ever asking for anything (Reduce Motion holds it still).
//
// The figure fades into the paper at both ends: an illustration on a
// page, not a drawing clipped by a screen.

private struct InstrumentFigure: View {
    let recognized: Bool
    /// The stillness meter, 0…1 — the line settles as she holds.
    let settled: Double

    @State private var breathing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // A printed body, not a wireframe: the faintest ink
                // wash gives the illustration its paper weight.
                BodyGuideShape()
                    .fill(Palette.cocoaPrimary.opacity(recognized ? 0.07 : 0.05))
                BodyGuideShape()
                    .stroke(
                        Palette.cocoaPrimary.opacity(lineOpacity),
                        style: StrokeStyle(lineWidth: 1.6 + 0.9 * settled,
                                           lineCap: .round, lineJoin: .round)
                    )
                // v11.5 — THE PHONE IN HER HAND. The founder's brief
                // asks the illustration to show how to position the
                // PHONE and the waist. One small ink rectangle at hip
                // height, angled as a held phone is, teaches the whole
                // pose without a word: this is a mirror photograph.
                PhoneInHand()
                    .stroke(
                        Palette.cocoaPrimary.opacity(recognized ? 0.5 : 0.3),
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.16),
                    .init(color: .black, location: 0.82),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
        .scaleEffect(breathing ? 1.006 : 0.998, anchor: .center)
        .animation(.easeInOut(duration: 0.55), value: recognized)
        .animation(.linear(duration: 0.15), value: settled)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 4.2).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
        .accessibilityHidden(true)
    }

    private var lineOpacity: Double {
        // A drawing must be VISIBLE at rest — at 0.18 the figure read
        // as a ghost placeholder, teaching nothing (frame-caught).
        recognized ? 0.52 : 0.30
    }
}

/// THE PHONE, held at her hip and angled at the mirror (v11.5). Drawn
/// in the figure's own coordinate space so it rides every size. Its
/// rectangle sits just outside the right hip, tilted the way a hand
/// holds a phone when the screen faces a mirror.
private struct PhoneInHand: Shape {
    func path(in rect: CGRect) -> Path {
        // Hip height on BodyFigure's proportions, just past the arm.
        let w = rect.width * 0.088
        let h = w * 1.95
        let cx = rect.minX + rect.width * 0.845
        let cy = rect.minY + rect.height * 0.545
        let body = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)

        var p = Path()
        p.addRoundedRect(in: body, cornerSize: CGSize(width: w * 0.26, height: w * 0.26))
        // The lens: a dot near the top, so the rectangle reads as a
        // phone's back rather than a card.
        let lens = min(w, h) * 0.22
        p.addEllipse(in: CGRect(
            x: body.minX + w * 0.24,
            y: body.minY + h * 0.10,
            width: lens, height: lens
        ))
        return p.applying(
            CGAffineTransform(translationX: cx, y: cy)
                .rotated(by: -0.20)
                .translatedBy(x: -cx, y: -cy)
        )
    }
}

// MARK: - ApertureBrackets (v11.5 — recognition, felt)
//
// Four corner marks that hover outside the window and CONVERGE onto
// it when the frame finds a person. Nothing is written; the motion
// is the message (the Face ID grammar in paper and ink).

private struct ApertureBrackets: View {
    let locked: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inset: CGFloat { locked ? 0 : 14 }
    private var arm: CGFloat { locked ? 20 : 14 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<4, id: \.self) { corner in
                    BracketMark(arm: arm)
                        .stroke(
                            Palette.cocoaPrimary.opacity(locked ? 0.55 : 0.22),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: arm, height: arm)
                        .rotationEffect(.degrees(Double(corner) * 90))
                        .position(
                            x: corner == 0 || corner == 3
                                ? -inset + arm / 2
                                : geo.size.width + inset - arm / 2,
                            y: corner < 2
                                ? -inset + arm / 2
                                : geo.size.height + inset - arm / 2
                        )
                }
            }
        }
        .animation(reduceMotion ? nil : JeniMotion.morph, value: locked)
        .accessibilityHidden(true)
    }
}

/// One corner: two arms meeting at the top-left, rotated into place.
private struct BracketMark: Shape {
    let arm: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

/// The drawn figure as a strokable outline (the union path — no
/// internal seams where the arms meet the body).
private struct BodyGuideShape: Shape {
    func path(in rect: CGRect) -> Path {
        BodyFigure.path(in: rect)
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
            // v10.3c: the crop is the fixed WINDOW now, so the script
            // no longer needs to match the drawn figure — it needs to
            // FILL the window: shoulder→hip axis 0.31 puts the live
            // band at ≈ the window's own 0.24, so the caption reads
            // "hold still" (the leg samples it), not a distance word.
            [
                .leftShoulder: .init(0.42 + jitter, 0.76),
                .rightShoulder: .init(0.58 + jitter, 0.76),
                .leftHip: .init(0.44 + jitter, 0.45),
                .rightHip: .init(0.56 + jitter, 0.45),
                .leftAnkle: .init(0.46 + jitter, 0.16),
                .rightAnkle: .init(0.54 + jitter, 0.16)
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
        let d = UserDefaults.standard
        d.set(ISO8601DateFormatter().string(from: .now), forKey: "bodyScan.introSeenAt")
        // A profile so THE RESULT's estimate panel is deterministic
        // on a camera-less sim (the engine itself is unit-tested).
        if d.double(forKey: "onboardingHeightCm") <= 100 { d.set(165.0, forKey: "onboardingHeightCm") }
        if d.integer(forKey: "onb_v5_age_years") < 18 { d.set(34, forKey: "onb_v5_age_years") }
        if (d.string(forKey: "onboardingGender") ?? "").isEmpty { d.set("female", forKey: "onboardingGender") }
        if d.double(forKey: "onboardingCurrentWeightKg") <= 25 { d.set(70.0, forKey: "onboardingCurrentWeightKg") }
        // v10.2: the seeds wear the waist era — ink bands whose
        // waist narrows week to week, so every design frame and
        // reel over seeded data looks honest.
        let waists: [CGFloat] = [1.10, 1.02, 0.95]
        for (i, daysAgo) in [21, 14, 7].enumerated() {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
            let plate = BodyFigure.inkBand(waist: waists[i])
            BodyScanStore.keep(
                photo: plate, silhouette: plate,
                poseQuality: 0.9, userId: userId, in: context,
                capturedAt: date,
                anchors: (top: 0.66, bottom: 0.44, centerX: 0.5),
                region: "waist"
            )
        }
    }
    #endif
}
