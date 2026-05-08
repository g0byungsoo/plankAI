import SwiftUI

// MARK: - StickerName
//
// Type-safe handle for the 17 sticker assets bundled in
// Assets.xcassets/Stickers/ (Phase 14a). The Stickers group has
// provides-namespace = false so the raw asset names are flat
// — Image("sticker_xxx") works.
//
// `style` partitions the catalog into two visual languages:
//   .lineArt   — single-color hand-drawn ink, full opacity
//   .painterly — saturated 3D / painted illustrations, knocked
//                back to 85% so they recede behind content.

enum StickerName: String, CaseIterable {
    case ribbonLineart
    case starLineart
    case cameraLineart
    case heartsLineart
    case heartGlossy
    case sparkleGlossy
    case bowSatin
    case bowIridescent
    case flower3D
    case tulipBouquet
    case seashell
    case cherries
    case strawberry
    case balloonDog
    case teddyPlaid
    case teddyPink
    case gummyBear
    // Phase 19c additions — 10 painterly stickers (iridescent / dreamy
    // palette, match the existing painterly style).
    case candyIridescent
    case discoBall
    case iceCream
    case candyLong
    case heartLock
    case cherub
    case strawberryRipe
    case perfume
    case candyPearl
    case butterflyRing

    var assetName: String {
        switch self {
        case .ribbonLineart:  return "sticker_ribbon_lineart"
        case .starLineart:    return "sticker_star_lineart"
        case .cameraLineart:  return "sticker_camera_lineart"
        case .heartsLineart:  return "sticker_hearts_lineart"
        case .heartGlossy:    return "sticker_heart_glossy"
        case .sparkleGlossy:  return "sticker_sparkle_glossy"
        case .bowSatin:       return "sticker_bow_satin"
        case .bowIridescent:  return "sticker_bow_iridescent"
        case .flower3D:       return "sticker_flower_3d"
        case .tulipBouquet:   return "sticker_tulip_bouquet"
        case .seashell:       return "sticker_seashell"
        case .cherries:       return "sticker_cherries"
        case .strawberry:     return "sticker_strawberry"
        case .balloonDog:     return "sticker_balloon_dog"
        case .teddyPlaid:     return "sticker_teddy_plaid"
        case .teddyPink:      return "sticker_teddy_pink"
        case .gummyBear:      return "sticker_gummy_bear"
        case .candyIridescent: return "sticker_candy_iridescent"
        case .discoBall:       return "sticker_disco_ball"
        case .iceCream:        return "sticker_ice_cream"
        case .candyLong:       return "sticker_candy_long"
        case .heartLock:       return "sticker_heart_lock"
        case .cherub:          return "sticker_cherub"
        case .strawberryRipe:  return "sticker_strawberry_ripe"
        case .perfume:         return "sticker_perfume"
        case .candyPearl:      return "sticker_candy_pearl"
        case .butterflyRing:   return "sticker_butterfly_ring"
        }
    }

    var style: StickerStyle {
        switch self {
        case .ribbonLineart, .starLineart, .cameraLineart, .heartsLineart:
            return .lineArt
        default:
            return .painterly
        }
    }
}

// MARK: - StickerStyle

enum StickerStyle {
    case lineArt
    case painterly

    var opacity: Double {
        switch self {
        case .lineArt:   return 1.0
        case .painterly: return 0.85
        }
    }
}

// MARK: - StickerPlacement
//
// Pure data describing one sticker's slot in a layout. Position is
// relative (0.0–1.0 on each axis) so the same scatter scales
// across phone widths. Rotation should fall in ±15°. phaseDelay
// (0.0–1.0) drives both the entrance stagger and the idle drift
// desync — adjacent stickers should pick distinct values so the
// cluster never breathes in unison.

struct StickerPlacement: Identifiable {
    let id = UUID()
    let sticker: StickerName
    let position: CGPoint
    let size: CGFloat
    let rotation: Double
    let phaseDelay: Double

    init(
        sticker: StickerName,
        position: CGPoint,
        size: CGFloat,
        rotation: Double,
        phaseDelay: Double
    ) {
        self.sticker = sticker
        self.position = position
        self.size = size
        self.rotation = rotation
        self.phaseDelay = phaseDelay
    }
}

// MARK: - Sticker (single)
//
// Renders one StickerPlacement with the entrance + idle drift
// language defined in the sticker style spec. Three independent
// state flags drive the animation: `appeared` for the entrance
// scale/fade/rotate-in, `wobbleActive` for the rotation breath,
// `floatActive` for the Y-axis drift. Wobble and float run on
// different periods so the motion never reads as a single pulse.
//
// reduceMotion snaps to the final state on appear and skips both
// loops — decorative motion is the first thing to drop on the
// accessibility flag.

struct Sticker: View {
    let placement: StickerPlacement

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared = false
    @State private var wobbleActive = false
    @State private var floatActive = false

    private let entranceDuration: Double = 0.7

    private var entranceDelay: Double { placement.phaseDelay * 0.1 }

    // Per-sticker periods derived from phaseDelay so two stickers
    // with the same baseline never share a cycle.
    private var wobblePeriod: Double { 6.0 + placement.phaseDelay * 2.0 }   // 6...8s
    private var floatPeriod: Double { 5.0 + placement.phaseDelay * 2.0 }    // 5...7s

    var body: some View {
        Image(placement.sticker.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: placement.size, height: placement.size)
            .opacity(placement.sticker.style.opacity * (appeared ? 1.0 : 0.0))
            .scaleEffect(appeared ? 1.0 : 0.6)
            .rotationEffect(.degrees(rotationValue))
            .offset(y: floatActive ? -6 : 0)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            .onAppear { startAnimations() }
    }

    private var rotationValue: Double {
        let entranceRotation: Double = appeared ? 0 : -5
        let wobbleRotation: Double = wobbleActive ? 2 : -2
        return placement.rotation + entranceRotation + wobbleRotation
    }

    private func startAnimations() {
        if reduceMotion {
            // Skip the entrance + idle loops entirely. Note: leaving
            // wobbleActive at false anchors the resting rotation at
            // -2° rather than the placement's exact base, which is
            // imperceptible at the ±2 amplitude and avoids a jump
            // into a center the loop never actually visits.
            appeared = true
            return
        }

        let entrance = Animation.timingCurve(0.16, 1, 0.3, 1, duration: entranceDuration)
            .delay(entranceDelay)
        withAnimation(entrance) {
            appeared = true
        }

        // Kick off idle drift after the entrance settles. phaseDelay
        // adds a per-sticker offset so a cluster of 5 starts their
        // wobble/float at staggered moments inside the cycle.
        let driftStart = entranceDelay + entranceDuration + placement.phaseDelay * 0.4
        DispatchQueue.main.asyncAfter(deadline: .now() + driftStart) {
            withAnimation(
                .easeInOut(duration: wobblePeriod / 2.0).repeatForever(autoreverses: true)
            ) {
                wobbleActive = true
            }
            withAnimation(
                .easeInOut(duration: floatPeriod / 2.0).repeatForever(autoreverses: true)
            ) {
                floatActive = true
            }
        }
    }
}

// MARK: - StickerScatter
//
// Container that resolves relative placements to absolute screen
// coordinates and renders each Sticker in a ZStack. The view is
// hit-test transparent so taps fall through to whatever the
// composing view places on top.
//
// To sit behind content, compose like:
//   ZStack {
//       StickerScatter(placements: ...)
//       VStack { /* foreground */ }
//   }
// The first ZStack child renders behind subsequent ones.

struct StickerScatter: View {
    let placements: [StickerPlacement]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(placements) { p in
                    Sticker(placement: p)
                        .position(
                            x: p.position.x * geo.size.width,
                            y: p.position.y * geo.size.height
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Default placements

extension StickerScatter {
    /// 5-sticker scatter for the Welcome / hero screen. Mixes
    /// three line-art stickers (heart pair, star, camera) in the
    /// primary corners with two painterly accents (iridescent bow,
    /// gummy bear) for warmth. Positions hug the margins so the
    /// center column stays clear for the wordmark + CTA.
    static func welcomeDefault() -> [StickerPlacement] {
        [
            StickerPlacement(
                sticker: .heartsLineart,
                position: CGPoint(x: 0.13, y: 0.18),
                size: 40,
                rotation: -12,
                phaseDelay: 0.0
            ),
            StickerPlacement(
                sticker: .starLineart,
                position: CGPoint(x: 0.86, y: 0.10),
                size: 34,
                rotation: 14,
                phaseDelay: 0.25
            ),
            StickerPlacement(
                sticker: .bowIridescent,
                position: CGPoint(x: 0.82, y: 0.42),
                size: 42,
                rotation: -10,
                phaseDelay: 0.45
            ),
            StickerPlacement(
                sticker: .cameraLineart,
                position: CGPoint(x: 0.88, y: 0.82),
                size: 36,
                rotation: -8,
                phaseDelay: 0.65
            ),
            StickerPlacement(
                sticker: .gummyBear,
                position: CGPoint(x: 0.12, y: 0.86),
                size: 44,
                rotation: 11,
                phaseDelay: 0.85
            ),
        ]
    }
}

// MARK: - Preview

#Preview("Welcome scatter") {
    ZStack {
        Palette.bgPrimary.ignoresSafeArea()
        StickerScatter(placements: StickerScatter.welcomeDefault())
        VStack(spacing: 12) {
            Text("JeniFit")
                .font(Typo.display)
                .foregroundStyle(Palette.textPrimary)
            Text("Strong is gorgeous.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
        }
    }
}

#Preview("Pink background") {
    ZStack {
        Palette.accentSubtle.ignoresSafeArea()
        StickerScatter(placements: StickerScatter.welcomeDefault())
    }
}
