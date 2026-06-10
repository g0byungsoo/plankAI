import SwiftUI
import UIKit
import AVKit

// MARK: - AirPlay picker
//
// `AVRoutePickerView` is UIKit-only — wrap it for SwiftUI. Tinted to match
// the scrapbook circle button so the tap target sits flush with the rest
// of the right-side stack. The system handles the actual route sheet.

struct AirPlayPickerView: UIViewRepresentable {
    let tint: UIColor

    func makeUIView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView()
        v.activeTintColor = tint
        v.tintColor = tint
        v.prioritizesVideoDevices = false
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.activeTintColor = tint
        uiView.tintColor = tint
    }
}

// MARK: - Volume mixer sheet
//
// Three-channel mixer mirroring Justfit's pattern: exercise voice
// (trainer cues), background music, and prep beeps. Each slider is bound
// to a UserDefaults double so the audio services read fresh values on the
// next playback without needing a publisher chain.

struct VolumeSheet: View {
    @AppStorage("voiceVolume") private var voiceVolume: Double = 1.0
    @AppStorage("bgmVolume") private var bgmVolume: Double = 0.35
    @AppStorage("prepBeepVolume") private var prepBeepVolume: Double = 0.85
    @Environment(\.dismiss) private var dismiss

    /// Called on slider change so audio services can apply the new volume
    /// to any actively-playing player. Without this, the volume change only
    /// takes effect on the NEXT playback.
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            header
            slider(label: "exercise voice", icon: "speaker.wave.2.fill",
                   value: $voiceVolume)
            slider(label: "background music", icon: "music.note",
                   value: $bgmVolume)
            slider(label: "prep time beeps", icon: "speaker.wave.1.fill",
                   value: $prepBeepVolume)
            Spacer(minLength: Space.md)
            doneButton
        }
        .padding(.horizontal, Space.screenPadding)
        .padding(.top, Space.lg)
        .padding(.bottom, Space.lg)
        .background(Palette.bgPrimary)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("session")
                    .font(Typo.eyebrow).tracking(2)
                    .foregroundStyle(Palette.accent)
                Text("set volume.")
                    .font(Typo.titleItalic)
                    .foregroundStyle(Palette.textPrimary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Palette.bgElevated)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Close volume")
        }
    }

    private func slider(label: String, icon: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                .foregroundStyle(Palette.textPrimary)
            HStack(spacing: Space.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 22)
                Slider(value: value, in: 0...1) { editing in
                    if !editing { onChange() }
                }
                .tint(Palette.accent)
                .onChange(of: value.wrappedValue) { _, _ in onChange() }
                Text("\(Int(value.wrappedValue * 100))")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .monospacedDigit()
                    .frame(width: 32, alignment: .trailing)
            }
        }
    }

    private var doneButton: some View {
        Button {
            Haptics.medium()
            dismiss()
        } label: {
            HStack {
                Text("done")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 18))
                Spacer()
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.accent)
            }
            .foregroundStyle(Palette.textInverse)
            .padding(.horizontal, Space.lg)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Palette.accent.opacity(0.18))
                        .offset(x: 4, y: 4)
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Palette.bgInverse)
                }
            )
        }
    }
}

// MARK: - Music source sheet
//
// Justfit-shaped picker for the background-music source. Only renders
// options we actually support — Jenifit's bundled playlist and "no music".
// Spotify / Apple Music integration is intentionally omitted in v1.0;
// each requires its own SDK + auth flow and isn't justified yet.

struct MusicSourceSheet: View {
    /// "jenifit" = our bundled BGM playing; "none" = music silenced.
    /// Bound to AppStorage so the choice survives between sessions.
    @AppStorage("musicSource") private var source: String = "jenifit"
    @Environment(\.dismiss) private var dismiss

    /// Fired after the source changes so the VM/audio service can toggle
    /// BGM playback to match the selection.
    let onChange: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            header
            VStack(spacing: 0) {
                row(value: "jenifit", label: "jenifit's playlist", caption: "calm tracks mastered to sit under the voice")
                Divider().background(Palette.divider)
                row(value: "none", label: "no music", caption: "voice only. play your own from another app")
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Palette.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Palette.accent.opacity(0.35), lineWidth: 1)
            )
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.screenPadding)
        .padding(.top, Space.lg)
        .padding(.bottom, Space.lg)
        .background(Palette.bgPrimary)
        .presentationDetents([.fraction(0.45)])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("session")
                    .font(Typo.eyebrow).tracking(2)
                    .foregroundStyle(Palette.accent)
                Text("music.")
                    .font(Typo.titleItalic)
                    .foregroundStyle(Palette.textPrimary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Palette.bgElevated)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Close music")
        }
    }

    private func row(value: String, label: String, caption: String) -> some View {
        let selected = source == value
        return Button {
            Haptics.light()
            source = value
            onChange(value)
        } label: {
            HStack(spacing: Space.md) {
                Image(systemName: value == "jenifit" ? "music.note" : "speaker.slash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selected ? Palette.accent : Palette.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(selected ? Palette.accent.opacity(0.15) : Palette.bgPrimary)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 17))
                        .foregroundStyle(Palette.textPrimary)
                    Text(caption)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(selected ? Palette.accent : Palette.divider, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if selected {
                        Circle().fill(Palette.accent).frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.md)
        }
    }
}

// MARK: - Exercise info sheet
//
// Justfit-shaped instructional sheet: huge animated Lottie at the top
// (X overlaid in the corner) → scrollable instructional sections below.
// Sections show only when content exists, so an exercise without an
// `ExerciseInstructionRegistry` entry gracefully degrades to the
// quick-facts panel (target areas + position + intensity).
//
// Content authoring guidelines live next to the registry in
// `ExerciseInstructions.swift`.

struct ExerciseInfoSheet: View {
    let exercise: Exercise
    let stepLabel: String
    @Environment(\.dismiss) private var dismiss

    private var instructions: ExerciseInstructions? {
        ExerciseInstructionRegistry.instructions(for: exercise.id)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                heroBanner
                bodyContent
            }
        }
        .background(Palette.bgPrimary)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .ignoresSafeArea(.container, edges: .top)
    }

    /// Top hero — large auto-playing Lottie with the X close button
    /// floated over the top-right corner (Justfit pattern). Sits flush
    /// against the safe area so the animation reads as the headline,
    /// not a thumbnail.
    private var heroBanner: some View {
        let rendering = ExerciseMirror.rendering(for: exercise, side: exercise.defaultSide)
        return ZStack(alignment: .topTrailing) {
            LottieExerciseView(rendering: rendering)
                .id(exercise.id + (rendering.side?.rawValue ?? ""))
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(Palette.bgElevated)

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(
                        ZStack {
                            Circle().fill(Palette.bgElevated.opacity(0.85))
                            Circle().stroke(Palette.accent.opacity(0.35), lineWidth: 1)
                        }
                    )
            }
            .accessibilityLabel("Close info")
            .padding(.top, Space.xl + Space.md)
            .padding(.trailing, Space.md)
        }
    }

    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            title
            quickFacts
            if let i = instructions {
                if !i.actionSteps.isEmpty {
                    bulletSection(title: "action steps", lines: i.actionSteps)
                }
                if !i.breathing.isEmpty {
                    bulletSection(title: "breathing", lines: i.breathing)
                }
                if !i.actionFeeling.isEmpty {
                    bulletSection(title: "action feeling", lines: i.actionFeeling)
                }
                if !i.commonMistakes.isEmpty {
                    bulletSection(title: "common mistakes", lines: i.commonMistakes)
                }
            } else {
                comingSoonNote
            }
        }
        .padding(.horizontal, Space.screenPadding)
        .padding(.top, Space.lg)
        .padding(.bottom, Space.xl + Space.xl)
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(stepLabel)
                .font(Typo.eyebrow).tracking(2)
                .foregroundStyle(Palette.accent)
            Text(exercise.name.lowercased() + ".")
                .font(Typo.titleItalic)
                .foregroundStyle(Palette.textPrimary)
        }
    }

    private var quickFacts: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            sectionTitle("what you're working")
            CapsuleFlowLayout(spacing: 6) {
                ForEach(exercise.targetAreas, id: \.self) { area in
                    Text(area.rawValue.camelCaseToWords.lowercased())
                        .font(Typo.caption)
                        .foregroundStyle(Palette.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Palette.accent.opacity(0.15)))
                        .overlay(Capsule().stroke(Palette.accent.opacity(0.4), lineWidth: 1))
                }
            }

            sectionTitle("set up")
            HStack(spacing: 8) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.accent)
                Text(positionDescription)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textPrimary)
            }

            sectionTitle("intensity")
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { dot in
                    Circle()
                        .fill(dot <= exercise.difficulty ? Palette.accent : Palette.divider)
                        .frame(width: 9, height: 9)
                }
                Text("· level \(exercise.difficulty)/5")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.leading, 4)
            }
        }
    }

    private func bulletSection(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            sectionTitle(title)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Palette.accent)
                            .frame(width: 5, height: 5)
                            .padding(.top, 8)
                        Text(line)
                            .font(Typo.body)
                            .foregroundStyle(Palette.textPrimary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    /// Quiet placeholder for exercises that don't yet have an entry in
    /// `ExerciseInstructionRegistry`. Reads as a deliberate "coming
    /// soon" rather than an empty screen.
    private var comingSoonNote: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            sectionTitle("guidance")
            Text("detailed coaching notes for this move are being written. for now, follow the animation + the on-screen timer.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .lineSpacing(4)
        }
        .padding(Space.md)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Palette.accent.opacity(0.3), lineWidth: 1)
        )
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(Typo.eyebrow).tracking(2)
            .foregroundStyle(Palette.textSecondary)
    }

    private var positionDescription: String {
        let p: String
        switch exercise.position {
        case .standing:  p = "standing"
        case .quadruped: p = "hands & knees"
        case .plank:     p = "plank position"
        case .prone:     p = "lying face-down"
        case .sideLying: p = "lying on your side"
        case .supine:    p = "lying on your back"
        case .seated:    p = "seated"
        }
        if exercise.symmetry == .unilateral {
            return p + " · alternates left + right"
        }
        return p
    }
}

// MARK: - FlowLayout
//
// Tiny wrap-on-overflow layout for the target-area capsules. Native
// `HStack` won't wrap; iOS 16's `Layout` protocol gives us this with
// minimal code. Used only inside the info sheet, kept private.

private struct CapsuleFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var width: CGFloat = 0
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if rowWidth + s.width > maxWidth {
                width = max(width, rowWidth - spacing)
                height += rowHeight + spacing
                rowWidth = s.width + spacing
                rowHeight = s.height
            } else {
                rowWidth += s.width + spacing
                rowHeight = max(rowHeight, s.height)
            }
        }
        width = max(width, rowWidth - spacing)
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}
