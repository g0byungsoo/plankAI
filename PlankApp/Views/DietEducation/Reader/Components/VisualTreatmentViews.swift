import SwiftUI

// MARK: - VisualTreatmentViews
//
// Round-2 redesign: per-treatment SwiftUI surface that LessonReaderView
// dispatches into above the typography column. Each treatment is a
// pure view (no model writes, no nav) that takes the resolved
// `LessonSlot` + current `CBTLessonPage` and renders the visual
// register. Treatments not present in this file (`typographyOnly`,
// `pullQuoteSpread`, `milestoneSealClose`) render inline in the
// reader or are still in spec.
//
// Asset resolution: when an asset is missing from the bundle, every
// view falls back gracefully — most degrade to typography-only so a
// missing illustration never breaks the read. Asset slugs come from
// the manifest's `illustrationAsset` field on each LessonSlot (the
// Grok generation pipeline writes asset slugs that match these
// imageset names).
//
// All treatments are Reduce-Motion safe: shimmer/parallax animations
// gate via `@Environment(\.accessibilityReduceMotion)`.

// MARK: HeroPhotoBleed (round-3 full-bleed redesign)
//
// Photo occupies 65-74% of canvas height + ≥100% of width, bleeding off
// the top + one side per the magazine designer's spec. The bottom 22-28%
// is the headline pocket — a cream-to-transparent vertical gradient
// gives the typography its read against the photo's lower edge.
//
// Use this as a FULL-PAGE replacement for hookpage content (not just
// an above-column slot). It returns its own headline layer; the
// reader's standard headline column is suppressed on hero pages.

// Round-3 HeroPhotoBleedView retired. The round-4 HeroPhotoAnchorView
// replaces it with a fixed-260pt anchored hero that doesn't suppress
// the standard headline column.

// MARK: SingleArtifact
//
// One photographed-real-object cutout floating beside body text.
// Smaller than hero, sized to feel like an editorial-margin specimen
// (Cereal / Acne Paper register).

struct SingleArtifactView: View {
    let assetSlug: String
    var size: CGFloat = 140
    var alignment: Alignment = .center
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floated = false

    var body: some View {
        Group {
            if let ui = AssetResolver.image(named: assetSlug) {
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .offset(y: floated ? 0 : 6)
                    .opacity(floated ? 1 : 0)
            } else {
                Color.clear.frame(width: size, height: size)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .padding(.vertical, 16)
        .accessibilityHidden(true)
        .onAppear {
            if reduceMotion { floated = true } else {
                withAnimation(.easeOut(duration: 0.65)) { floated = true }
            }
        }
    }
}

// MARK: PhotoEdgeBleed
//
// Photograph bleeds off one edge, occupying ~25-35% of the canvas.
// Atmosphere, not subject. Typically top-right or top-left corner.

struct PhotoEdgeBleedView: View {
    let assetSlug: String
    var edge: Edge = .topTrailing
    var sizeFraction: CGFloat = 0.42
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    enum Edge { case topLeading, topTrailing, bottomLeading, bottomTrailing }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width * sizeFraction
            ZStack {
                if let ui = AssetResolver.image(named: assetSlug) {
                    Image(uiImage: ui)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: w)
                        .opacity(settled ? 1 : 0)
                        .frame(maxWidth: .infinity,
                               maxHeight: .infinity,
                               alignment: edgeAlignment)
                }
            }
        }
        .frame(height: 220)
        .accessibilityHidden(true)
        .onAppear {
            if reduceMotion { settled = true } else {
                withAnimation(.easeOut(duration: 0.7)) { settled = true }
            }
        }
    }

    private var edgeAlignment: Alignment {
        switch edge {
        case .topLeading: return .topLeading
        case .topTrailing: return .topTrailing
        case .bottomLeading: return .bottomLeading
        case .bottomTrailing: return .bottomTrailing
        }
    }
}

// MARK: CollageScatter (round-3 per-object runtime composition)
//
// 6-9 individual transparent-PNG object cutouts placed via GeometryReader
// + .position(x:y:) + .rotationEffect(.degrees) + sizing relative to the
// reader's inner rect. Replaces the round-2 pre-composed-PNG approach.
//
// The scatter occupies the FULL page (not a top-block). Two objects
// intersect the headline band by design; 1-2 bleed off canvas edges.
// Headline + body render OVER the scatter in the reader's standard
// column — the lowest-z scatter objects are at 0.85 opacity so they
// read as "background" beneath the typography.
//
// Layout coordinates are looked up from `LessonScatterLayouts.layout(forCanonicalDay:)`.
// Reduce-Motion: rotation + entrance stagger gate off; objects render
// at their final position with a single crossFade.

// CollageScatterView retired in round-4. The 18 jm_obj_* assets
// remain on disk as ArtifactSlug candidates but the per-object
// scatter composition no longer renders. See HeroPhotoAnchorView +
// ArtifactPinnedOverlay for the round-4 anchor surfaces.

// MARK: GradientOrbSelection
//
// 2-4 radial-gradient soft orbs as tappable reflection options inline.
// Selected orb gets an inner-bright bloom; the user's pick persists
// locally + the lesson body's adapted-line (if any) renders below.

struct GradientOrbSelectionView: View {
    let lessonSlotId: String
    let page: Int
    let prompt: OrbPrompt
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage private var pickKey: String

    init(lessonSlotId: String, page: Int, prompt: OrbPrompt) {
        self.lessonSlotId = lessonSlotId
        self.page = page
        self.prompt = prompt
        let storage = "jenimethod.orbpick.\(lessonSlotId).\(page)"
        _pickKey = AppStorage(wrappedValue: "", storage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text(prompt.question.lowercased())
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 18))
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // 2-4 orbs in a flex row; cap at 4. Larger orbs for fewer
            // choices so the row reads weighty regardless of count.
            let perRowSize: CGFloat = {
                switch prompt.choices.count {
                case ...2: return 132
                case 3: return 108
                default: return 92
                }
            }()
            HStack(spacing: 14) {
                ForEach(prompt.choices, id: \.key) { choice in
                    OrbButton(
                        choice: choice,
                        selected: pickKey == choice.key,
                        size: perRowSize,
                        reduceMotion: reduceMotion
                    ) {
                        Haptics.light()
                        if reduceMotion {
                            pickKey = choice.key
                        } else {
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                                pickKey = choice.key
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Adapted line of body — appears beneath orbs only when a
            // pick exists AND the choice carries an `adaptedBodyLine`.
            if let picked = prompt.choices.first(where: { $0.key == pickKey }),
               let line = picked.adaptedBodyLine, !line.isEmpty {
                Text(line)
                    .font(.custom("DMSans-Regular", size: 15))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .offset(y: 6)))
                    .id(picked.key)
            }
        }
    }
}

private struct OrbButton: View {
    let choice: OrbChoice
    let selected: Bool
    let size: CGFloat
    let reduceMotion: Bool
    let onTap: () -> Void

    private var hue: Color { Color(hex: choice.hueHex) }

    private var orbGradient: RadialGradient {
        RadialGradient(
            colors: [hue, hue.opacity(0.7), hue.opacity(0.12)],
            center: .center,
            startRadius: 4,
            endRadius: size * 0.5
        )
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                orbStack
                Text(choice.label.lowercased())
                    .font(.custom("DMSans-Medium", size: 12))
                    .kerning(0.4)
                    .foregroundStyle(selected ? Palette.textPrimary : Palette.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("choose \(choice.label)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var orbStack: some View {
        ZStack {
            Circle()
                .fill(orbGradient)
                .frame(width: size, height: size)
                .shadow(color: hue.opacity(selected ? 0.35 : 0.0),
                        radius: selected ? 18 : 0, x: 0, y: 0)

            if selected {
                Circle()
                    .fill(Color.white.opacity(0.65))
                    .frame(width: size * 0.18, height: size * 0.18)
                    .blur(radius: 6)
            }

            Circle()
                .stroke(Palette.cocoaPrimary, lineWidth: selected ? 1.6 : 0)
                .padding(2)
                .frame(width: size, height: size)
        }
        .scaleEffect(selected ? 1.04 : 1.0)
    }
}

// MARK: - AssetResolver
//
// Centralized image lookup. UIImage(named:) returns nil for missing
// asset slugs (treatment views gracefully fall back). Bridges to
// SwiftUI's Image but returns UIImage so callers can size based on
// real intrinsic dimensions when needed.

enum AssetResolver {
    static func image(named slug: String) -> UIImage? {
        UIImage(named: slug)
    }

    static func exists(_ slug: String) -> Bool {
        UIImage(named: slug) != nil
    }
}

// MARK: - InkTraceUnderlineModifier
//
// Render layer for the long-press-save-line primitive. When a user
// long-presses a body sentence, the sentence's view gets this
// modifier with `active = true`; the underline traces in via the
// `inkTraceUnderline` Metal shader.

struct InkTraceUnderlineModifier: ViewModifier {
    let active: Bool
    var lineY: CGFloat = 36
    var lineThickness: CGFloat = 10
    var warmHueShift: CGFloat = 0.55
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .colorEffect(ShaderLibrary.inkTraceUnderline(
                .float(Float(progress)),
                .float2(0, 0), // size — supplied by GeometryReader in callers when needed
                .float(Float(lineY)),
                .float(Float(lineThickness)),
                .float(Float(warmHueShift))
            ))
            .onAppear {
                guard active else { progress = 0; return }
                if reduceMotion {
                    progress = 1
                } else {
                    withAnimation(.easeOut(duration: 0.60)) { progress = 1 }
                }
            }
            .onChange(of: active) { _, new in
                if !new { progress = 0; return }
                if reduceMotion {
                    progress = 1
                } else {
                    withAnimation(.easeOut(duration: 0.60)) { progress = 1 }
                }
            }
    }
}

extension View {
    /// Apply the warm-cream trace underline when `active` flips true.
    /// Used by long-press-save-line on body sentences.
    func inkTraceUnderline(active: Bool) -> some View {
        modifier(InkTraceUnderlineModifier(active: active))
    }
}
