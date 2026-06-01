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
    // Phase 9.9 additions — 6 painterly iridescent stickers added by
    // product to expand the lesson-ritual icon vocabulary. Used both
    // as decorative scatter AND as inline iconography (e.g., peach to
    // illustrate body / hydration moments, teacup for "morning ritual",
    // peace sign / finger-heart for affirmations).
    case fingerHeart
    case fluffyHeart
    case peaceSign
    case peach
    case teacup
    case toteBag
    // v1.0.7 — pink iridescent mary-jane platform. Bound to the steps
    // rail (StepsPulseTile, StepsBentoTile, BecomingMetric.movement)
    // so "moving / walking" reads as a single visual signal across
    // the app. Painterly style, same opacity treatment as the other
    // iridescent stickers.
    case shoeIridescent

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
        case .fingerHeart:     return "sticker_finger_heart"
        case .fluffyHeart:     return "sticker_fluffy_heart"
        case .peaceSign:       return "sticker_peace_sign"
        case .peach:           return "sticker_peach"
        case .teacup:          return "sticker_teacup"
        case .toteBag:         return "sticker_tote_bag"
        case .shoeIridescent:  return "sticker_shoe_iridescent"
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
    /// Coach intro — dense corner + side scatter framing the central
    /// coach portrait + sparkle burst. All placements hug the left/right
    /// margins and the top so the center column (portrait, greeting,
    /// focal beat) and bottom CTA stay clear. Mixes the y2k coquette pack
    /// (bow, flower, cherries, butterfly, gummy bear) with line-art
    /// accents (star) for variety.
    static func coachIntroDefault() -> [StickerPlacement] {
        [
            // top band
            StickerPlacement(sticker: .bowIridescent, position: CGPoint(x: 0.12, y: 0.07), size: 40, rotation: -12, phaseDelay: 0.0),
            StickerPlacement(sticker: .starLineart, position: CGPoint(x: 0.86, y: 0.06), size: 28, rotation: 13, phaseDelay: 0.2),
            // upper sides
            StickerPlacement(sticker: .cherries, position: CGPoint(x: 0.08, y: 0.24), size: 34, rotation: -8, phaseDelay: 0.35),
            StickerPlacement(sticker: .sparkleGlossy, position: CGPoint(x: 0.91, y: 0.22), size: 26, rotation: 12, phaseDelay: 0.5),
            // mid sides
            StickerPlacement(sticker: .flower3D, position: CGPoint(x: 0.09, y: 0.5), size: 38, rotation: 9, phaseDelay: 0.6),
            StickerPlacement(sticker: .butterflyRing, position: CGPoint(x: 0.92, y: 0.48), size: 32, rotation: 10, phaseDelay: 0.7),
            // lower sides (above CTA)
            StickerPlacement(sticker: .gummyBear, position: CGPoint(x: 0.11, y: 0.74), size: 36, rotation: 11, phaseDelay: 0.85),
            StickerPlacement(sticker: .fluffyHeart, position: CGPoint(x: 0.89, y: 0.72), size: 36, rotation: -9, phaseDelay: 1.0),
        ]
    }

    /// Breathwork primer — denser scatter mixing "morning ritual"
    /// vocabulary (teacup) with coquette accents. Text-heavy + scrolling,
    /// so placements hug the left/right margins and the very top/bottom
    /// where the scroll content has room.
    static func breathworkPrimerDefault() -> [StickerPlacement] {
        [
            StickerPlacement(sticker: .teacup, position: CGPoint(x: 0.13, y: 0.06), size: 42, rotation: -10, phaseDelay: 0.0),
            StickerPlacement(sticker: .heartsLineart, position: CGPoint(x: 0.5, y: 0.035), size: 26, rotation: 6, phaseDelay: 0.15),
            StickerPlacement(sticker: .sparkleGlossy, position: CGPoint(x: 0.88, y: 0.07), size: 26, rotation: 12, phaseDelay: 0.3),
            StickerPlacement(sticker: .cherub, position: CGPoint(x: 0.08, y: 0.34), size: 34, rotation: -8, phaseDelay: 0.45),
            StickerPlacement(sticker: .bowSatin, position: CGPoint(x: 0.92, y: 0.5), size: 32, rotation: 11, phaseDelay: 0.6),
            StickerPlacement(sticker: .flower3D, position: CGPoint(x: 0.11, y: 0.88), size: 38, rotation: 9, phaseDelay: 0.75),
            StickerPlacement(sticker: .fluffyHeart, position: CGPoint(x: 0.89, y: 0.9), size: 34, rotation: -8, phaseDelay: 0.9),
        ]
    }

    /// Breathwork session — soft scatter kept to the top band so the
    /// centered breath bloom and bottom choice/CTA stay completely
    /// clear. Denser than before but still calm; the gentle idle drift
    /// reads as ambient, not busy.
    static func breathworkSessionDefault() -> [StickerPlacement] {
        [
            StickerPlacement(sticker: .cherub, position: CGPoint(x: 0.5, y: 0.05), size: 28, rotation: 5, phaseDelay: 0.0),
            StickerPlacement(sticker: .flower3D, position: CGPoint(x: 0.12, y: 0.1), size: 36, rotation: -10, phaseDelay: 0.2),
            StickerPlacement(sticker: .butterflyRing, position: CGPoint(x: 0.88, y: 0.11), size: 34, rotation: 11, phaseDelay: 0.4),
            StickerPlacement(sticker: .sparkleGlossy, position: CGPoint(x: 0.24, y: 0.18), size: 24, rotation: 8, phaseDelay: 0.6),
            StickerPlacement(sticker: .fluffyHeart, position: CGPoint(x: 0.78, y: 0.19), size: 28, rotation: -7, phaseDelay: 0.8),
        ]
    }

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
