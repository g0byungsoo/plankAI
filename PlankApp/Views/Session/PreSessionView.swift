import SwiftUI
import AVFoundation

/// Pre-session instruction screen. Shows the rationale, "what your time
/// means" reference, phone setup + form guide before entering the camera
/// session. Research-grounded — the WHY block cites McGill's Waterloo lab
/// norms and the Biering-Sørensen LBP-prediction study so the user
/// understands the check-in measures something real, not a vanity stat.
/// Also handles the three camera-permission states.
struct PreSessionView: View {
    let exerciseType: String
    let dayNumber: Int
    /// User's most recent plank benchmark hold (seconds). Surfaced inline
    /// so they see their starting line — `nil` for first-ever check-in.
    let lastBenchmarkSeconds: Int?
    let onStart: () -> Void
    let onDismiss: () -> Void

    init(
        exerciseType: String,
        dayNumber: Int,
        lastBenchmarkSeconds: Int? = nil,
        onStart: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.exerciseType = exerciseType
        self.dayNumber = dayNumber
        self.lastBenchmarkSeconds = lastBenchmarkSeconds
        self.onStart = onStart
        self.onDismiss = onDismiss
    }

    @State private var cameraStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var showWhyExpanded = false

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                // Authorized → scrollable brief; permission states render
                // their own non-scrolling layout (smaller content, fits a
                // single screen without scroll affordance).
                switch cameraStatus {
                case .authorized:
                    ScrollView(showsIndicators: false) {
                        setupInstructions
                            .padding(.horizontal, Space.screenPadding)
                            .padding(.top, Space.md)
                            .padding(.bottom, Space.xl)
                    }
                case .denied:
                    Spacer(); cameraBlockedView; Spacer()
                case .restricted:
                    Spacer(); cameraRestrictedView; Spacer()
                default:
                    Spacer(); cameraRequestView; Spacer()
                }

                if cameraStatus == .authorized {
                    cocoaCTA(text: "begin check-in") {
                        Haptics.heavy()
                        onStart()
                    }
                    .padding(.horizontal, Space.screenPadding)
                    .padding(.bottom, Space.lg)
                }
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Text("day \(dayNumber)")
                .font(Typo.eyebrow).tracking(2)
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Palette.bgElevated)
                    .clipShape(Circle())
                    .tappableArea()
                    .accessibilityLabel("Close")
            }
        }
        .padding(.horizontal, Space.screenPadding)
        .padding(.top, Space.md)
    }

    // MARK: - Cocoa CTA pill (shared by primary screens)

    private func cocoaCTA(text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 18))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.accent)
            }
            .foregroundStyle(Palette.textInverse)
            .padding(.horizontal, Space.lg)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Palette.accent.opacity(0.18))
                        .offset(x: 4, y: 4)
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Palette.bgInverse)
                }
            )
        }
    }

    // MARK: - Setup Instructions

    private var setupInstructions: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            hero
            if lastBenchmarkSeconds != nil {
                lastBenchmarkRow
            }
            whyThisCheckInCard
            formOverTimeCard
            timeBucketTable
            setupSteps
            phoneTip
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("your check-in")
                .font(Typo.eyebrow).tracking(2)
                .foregroundStyle(Palette.accent)
            (
                Text("60 seconds. ").font(Typo.title) +
                Text("what they mean.").font(Typo.titleItalic)
            )
            .foregroundStyle(Palette.textPrimary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)

            Text("stuart mcgill's lab at waterloo set the healthy-adult range above two minutes. most people land well under that the first time. yours is your starting line.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    // MARK: - Last benchmark inline

    private var lastBenchmarkRow: some View {
        let seconds = lastBenchmarkSeconds ?? 0
        let bucket = bucketLabel(forSeconds: seconds)
        return HStack(spacing: Space.sm) {
            Text("your last hold")
                .font(Typo.eyebrow).tracking(2)
                .foregroundStyle(Palette.textSecondary)
            Spacer(minLength: 0)
            Text("\(seconds)s")
                .font(.custom("Fraunces72pt-SemiBold", size: 22))
                .foregroundStyle(Palette.textPrimary)
            Text("·")
                .foregroundStyle(Palette.divider)
            Text(bucket)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                .foregroundStyle(Palette.accent)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(scrapbookChrome())
    }

    // MARK: - Research card 1: why holds matter

    private var whyThisCheckInCard: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("what holds predict")
                .font(Typo.eyebrow).tracking(3)
                .foregroundStyle(Palette.accent)
            (
                Text("a hold under ").font(Typo.body) +
                Text("30 seconds").font(.custom("Fraunces72pt-SemiBoldItalic", size: 16)) +
                Text(" is one of the few pre-symptom predictors of future low-back pain. building it up isn't vanity work — it's the part of fitness that protects every other part.").font(Typo.body)
            )
            .foregroundStyle(Palette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)

            Text("biering-sørensen, spine (1984) · n=928, 12-month follow-up")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 2)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(scrapbookChrome())
    }

    // MARK: - Research card 2: form over duration

    private var formOverTimeCard: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("form decides the score")
                .font(Typo.eyebrow).tracking(3)
                .foregroundStyle(Palette.stateGood)
            Text("a clean 30-second hold trains your spine to stay neutral under load. a sagging 90-second hold trains the opposite. we score your alignment, not just the clock.")
                .font(Typo.body)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("mcgill, ultimate back fitness and performance (2014)")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 2)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(scrapbookChrome(tint: Palette.stateGood))
    }

    // MARK: - "What your time means" reference table

    private var timeBucketTable: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("what your time means")
                .font(Typo.eyebrow).tracking(3)
                .foregroundStyle(Palette.textSecondary)
                .padding(.bottom, 2)

            VStack(spacing: 0) {
                bucketRow(range: "under 30s", label: "foundational",
                          note: "below the LBP-risk threshold. start with form.")
                Divider().padding(.horizontal, Space.md)
                bucketRow(range: "30 – 60s", label: "building",
                          note: "typical 2–4 week progression. past the riskiest band.")
                Divider().padding(.horizontal, Space.md)
                bucketRow(range: "60 – 120s", label: "solid",
                          note: "general-population functional range.")
                Divider().padding(.horizontal, Space.md)
                bucketRow(range: "120s+", label: "trained",
                          note: "meets mcgill's healthy young-adult norm.")
            }
            .background(scrapbookChrome())
        }
    }

    private func bucketRow(range: String, label: String, note: String) -> some View {
        HStack(alignment: .top, spacing: Space.md) {
            VStack(alignment: .leading, spacing: 1) {
                Text(range)
                    .font(.custom("Fraunces72pt-SemiBold", size: 15))
                    .foregroundStyle(Palette.textPrimary)
                Text(label)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                    .foregroundStyle(Palette.accent)
            }
            .frame(width: 90, alignment: .leading)

            Text(note)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Compound row — read the range, bucket, and note as one phrase
        // (e.g., "30 to 60s, building, typical 2-4 week progression").
        .accessibilityElement(children: .combine)
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm + 2)
    }

    /// Maps the user's hold to its research-aligned bucket label.
    private func bucketLabel(forSeconds s: Int) -> String {
        switch s {
        case ..<30:    return "foundational"
        case 30..<60:  return "building"
        case 60..<120: return "solid"
        default:       return "trained"
        }
    }

    // MARK: - Setup steps (condensed — was 3 stacked icons + paragraphs)

    private var setupSteps: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("set up")
                .font(Typo.eyebrow).tracking(3)
                .foregroundStyle(Palette.textSecondary)
                .padding(.bottom, 2)

            VStack(spacing: Space.sm) {
                setupRow(icon: "iphone.gen3",
                         title: "prop your phone up",
                         note: "~6 ft away, full body in frame.")
                setupRow(icon: "figure.core.training",
                         title: "forearms down",
                         note: "elbows under shoulders. body straight from head to heels.")
                setupRow(icon: "waveform",
                         title: "we watch your form",
                         note: "alignment + cues, processed on-device.")
            }
        }
    }

    private func setupRow(icon: String, title: String, note: String) -> some View {
        HStack(alignment: .top, spacing: Space.md) {
            ZStack {
                Circle()
                    .fill(Palette.accent.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Palette.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                    .foregroundStyle(Palette.textPrimary)
                Text(note)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        // Setup row reads as one instruction — "prop your phone up.
        // ~6 ft away, full body in frame." — not three separate beats.
        .accessibilityElement(children: .combine)
    }

    // MARK: - Phone unlocked tip

    private var phoneTip: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Image(systemName: "lock.open.display")
                .font(.system(size: 14))
                .foregroundStyle(Palette.accent)
                .padding(.top, 2)
            Text("keep your phone unlocked. locking or switching apps pauses the session.")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.sm + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.divider.opacity(0.25))
        )
    }

    // MARK: - Scrapbook chrome (matches the rest of the app)

    private func scrapbookChrome(tint: Color = Palette.accent) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(tint.opacity(0.15))
                .offset(x: 4, y: 4)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Palette.bgElevated)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(tint, lineWidth: 1.5)
        }
    }

    // MARK: - Camera Permission Request (.notDetermined)
    //
    // Pre-permission screen so the iOS system dialog never appears cold.
    // Pre-permission screens convert ~2× better than raw system dialogs
    // (App Store optimization studies, 2018-2024) and the user can't
    // un-deny once they've tapped "Don't Allow" — only Settings recovers.

    private var cameraRequestView: some View {
        VStack(spacing: Space.lg) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(Palette.accent)

            Text("Your coach\nneeds to see you")
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)

            Text("So we can guide your form\nand keep you safe through every rep.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    let granted = await AVCaptureDevice.requestAccess(for: .video)
                    // After the user responds, re-fetch the canonical status.
                    // requestAccess returns granted=false for both Don't Allow
                    // (.denied) and restricted-device cases — re-fetching
                    // disambiguates so we route to the right screen.
                    cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
                    _ = granted
                }
            } label: {
                Text("Enable Camera")
                    .font(Typo.body)
                    .fontWeight(.bold)
                    .foregroundStyle(Palette.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: Space.minTapTarget + 12)
                    .background(Palette.bgInverse)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            }
            .padding(.horizontal, Space.xl)
        }
        .padding(.horizontal, Space.screenPadding)
    }

    // MARK: - Camera Blocked (.denied)
    //
    // User tapped Don't Allow on the system dialog. They have to fix it in
    // Settings. The "Why do I need this?" expandable answers the implicit
    // question without taking the user out of the flow.

    private var cameraBlockedView: some View {
        VStack(spacing: Space.lg) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(Palette.stateBad)

            Text("Camera access\nis turned off")
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)

            Text("JeniFit watches your form during sessions. Without the camera, the coaching can't run.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: Space.sm) {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(Typo.body)
                        .fontWeight(.bold)
                        .foregroundStyle(Palette.textInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: Space.minTapTarget + 12)
                        .background(Palette.bgInverse)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                }

                Button {
                    withAnimation(Motion.crossFade) {
                        showWhyExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Why do I need this?")
                        Image(systemName: showWhyExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                }

                if showWhyExpanded {
                    Text("Your coach uses on-device pose tracking to watch your alignment, count time in good form, and call out hip sag or shoulder creep. Frames are processed live and never leave your phone — nothing is recorded or uploaded.")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.leading)
                        .padding(Space.sm)
                        .background(Palette.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, Space.xl)
        }
        .padding(.horizontal, Space.screenPadding)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }

    // MARK: - Camera Restricted (.restricted)
    //
    // Parental controls or MDM prevent camera access. Settings won't show
    // the toggle — guiding the user there would just leave them stuck. No
    // primary CTA; offer support contact as the only path forward.

    private var cameraRestrictedView: some View {
        VStack(spacing: Space.lg) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(Palette.stateBad)

            Text("Camera access\nis restricted")
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)

            Text("This device's settings prevent camera access (likely parental controls or a managed-device profile). The form-tracking session can't run without it.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                if let url = URL(string: "mailto:support@jenifit.app?subject=Camera%20access%20restricted") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Contact support")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .underline()
            }
        }
        .padding(.horizontal, Space.screenPadding)
    }
}
