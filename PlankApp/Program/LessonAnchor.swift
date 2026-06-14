import SwiftUI

// MARK: - LessonAnchor
//
// Round-4 anchor register for a JeniMethod lesson page. Replaces the
// 8-case `VisualTreatment` enum with a 4-case anchor that names a real
// asset slug at the type level: `HeroPhotoSlug`, `ArtifactSlug`,
// `AccentSlug` are enum-backed, so the renderer cannot reference a
// missing asset. This eliminates the round-3 smudge-or-placeholder
// failure mode where Grok-generated cutouts shipped at 14-20% canvas
// width read as visual noise.
//
// Synthesis 2026-06-13 (round-4 expert panel): 105 imagesets already
// in the brand library cover every page-kind we need; ZERO new Grok
// generations this round. The 18 jm_obj_* assets are retained on disk
// but unwired from the renderer.

public enum LessonAnchor: Equatable, Hashable, Sendable {
    /// No visual anchor. Optional dingbat above headline on close pages
    /// (P4 of milestone days). ~55% of all 336 pages — the base register
    /// that ages well across 84 mornings.
    case typographyOnly(dingbat: Dingbat? = nil)

    /// One onb-itgirl-* or jm_hero_* photo at 260pt height (44% of body
    /// region), edge-bled with a 60pt cream-gradient pocket on the
    /// typography side. ~32 pages.
    case singleHeroPhoto(slug: HeroPhotoSlug, bleed: BleedDirection)

    /// One filler / accent / edu / identity / breath / profile / cohort
    /// asset at ~32% canvas width, pinned to one corner with -16pt
    /// edge bleed. ABSOLUTE OVERLAY — costs ZERO vertical space.
    /// ~110 pages.
    case singleArtifactPinned(slug: ArtifactSlug, pin: CornerPin)

    /// Two `accent-*` stickers on opposite diagonal corners, 78pt each,
    /// framing the typography column. ≤8 pages across all 84 lessons.
    case twinAccentCorners(leading: AccentSlug,
                           trailing: AccentSlug,
                           diagonal: Diagonal)

    /// Round-5: Pinterest-scrapbook spread. 2-3 brand assets composed
    /// AROUND + WITHIN the typography column at varied scales /
    /// rotations / opacities / edge-bleeds. The recipe defines the
    /// compositional grammar; the slots fill it. Headline + body
    /// render OVER the stickers; the lowest-z slot ducks to 0.78-0.85
    /// opacity so typography stays legible.
    case scrapbookSpread(recipe: ScrapbookRecipe, slots: [ScrapbookSlot])

    /// Round-6: hand-crafted layout archetype per the her75 reference
    /// (IMG_6256-6282). The archetype names a single compositional
    /// grammar (BREATH_BEAT / TUCKED_HEADLINE / WINDOW_PORTRAIT /
    /// FLAT_LAY_PINBOARD / TOP_PIN). The slots fill it with sized +
    /// rotated brand assets. The reader dispatches per archetype to
    /// a renderer that guarantees text-never-overlaps by construction:
    /// VStack flow for bleed/decoration, HStack for window-portrait,
    /// computed bottom-cream-only positioning for scatter.
    case layoutArchetype(LayoutArchetype, slots: [LayoutSlot])
}

// MARK: - LayoutArchetype (round-6)
//
// Five named layout archetypes the round-6 expert panel extracted
// from the her75 App Store reference set. Each is a SwiftUI render
// pattern, not just a metadata enum — see `LayoutArchetypeView` for
// the dispatch.

public enum LayoutArchetype: String, Codable, Sendable, Hashable, CaseIterable {
    /// IMG_6267 + IMG_6280 — pure typography breath beat. No photo.
    case pureTypography     = "pure_typography"
    /// IMG_6275 + IMG_6268 — one large portrait bleeds off bottom
    /// 55-70% of canvas. Headline tucks into the upper cream void.
    case bottomBleedHero    = "bottom_bleed_hero"
    /// IMG_6278 — one photo extends from one side 40-55% width.
    /// Text on opposite side. RETIRED in round-7 (founder feedback —
    /// 52% column shredded readability). Map to .wrapBleed instead.
    case sideBleedHalf      = "side_bleed_half"
    /// IMG_6270 + IMG_6271 + IMG_6272 — three stickers VARIED sizes
    /// (large + medium + small) scattered in bottom cream zone.
    case flatLayPinboard    = "scatter_trio"
    /// IMG_6282 + IMG_6261 — single small/medium sticker pinned
    /// between top bar and kicker.
    case topPin             = "top_decoration"
    /// Round-7: magazine-style text-wrap around a sticker via
    /// UITextView.exclusionPaths. Replaces sideBleedHalf.
    case wrapBleed          = "wrap_bleed"
}

// MARK: - LayoutSlot

public struct LayoutSlot: Codable, Equatable, Hashable, Sendable {
    public var assetSlug: String
    public var sizePct: CGFloat       // size relative to canvas
    public var xPct: CGFloat          // 0..1 horizontal anchor
    public var yPct: CGFloat          // 0..1 vertical anchor
    public var rotationDeg: Double
    public var role: SlotRole

    public init(assetSlug: String,
                sizePct: CGFloat,
                xPct: CGFloat = 0.5,
                yPct: CGFloat = 0.5,
                rotationDeg: Double = 0,
                role: SlotRole = .primary) {
        self.assetSlug = assetSlug
        self.sizePct = sizePct
        self.xPct = xPct
        self.yPct = yPct
        self.rotationDeg = rotationDeg
        self.role = role
    }
}

public enum SlotRole: String, Codable, Sendable, Hashable {
    case primary, secondary, tertiary
}

// MARK: - ScrapbookRecipe
//
// Named compositional grammars for the round-5 scrapbook spread.
// Each recipe describes WHERE 2-3 stickers sit relative to the
// typography column. Per-lesson assignment picks the recipe + fills
// in which asset slugs go in which slot positions.

public enum ScrapbookRecipe: String, Codable, Sendable, Hashable, CaseIterable {
    /// Hero photo bleeds off the right edge + small accent tucked
    /// into the top-left drop-cap void. The "this is a magazine
    /// spread" register. Used for foundational + breakthrough lessons.
    case editorialBleed = "editorial_bleed"
    /// Text-primary; two small stickers sit in the right gutter only.
    /// Used for instruction/behavioral-skill lessons where the
    /// stickers function as journal-pinned marginalia.
    case marginaliaNote = "marginalia_note"
    /// Mid-left margin + mid-right inline. The "everyday register" —
    /// stickers flank the body like art-directed flat-lay edges.
    case kitchenWindow = "kitchen_window"
    /// Bottom-left anchor + top-right peek. Calm closer for late-
    /// program reflection lessons.
    case bedsideSpread = "bedside_spread"
}

// MARK: - SlotPosition
//
// Round-5b (founder absolute rule 2026-06-13): **text never overlaps
// anything**. Sticker slots LIVE EXCLUSIVELY in cream-only zones —
// the top band above the headline + the gap between body's end and
// the folio + edge-bleed corners. The previous "under-text" + "over-
// body" positions are retired because they put stickers in the
// typography's path.
//
// All sticker sizes shrink to 12-22% of canvas width (was 14-62%)
// because in a peripheral-only zone, smaller objects read as jewelry
// not as content blocks.

public enum SlotPosition: String, Codable, Sendable, Hashable, CaseIterable {
    /// Tucked into top-left corner, slight off-canvas bleed.
    case topLeftCorner
    /// Tucked into top-right corner, slight off-canvas bleed.
    case topRightCorner
    /// Single accent centered above the kicker — restrained, ornamental.
    case topCenterTuck
    /// Marginal accent below the body, above the folio rule.
    case bottomLeftGap
    /// Marginal accent below the body, above the folio rule (right side).
    case bottomRightGap
    /// LEGACY — round-5a positions retained for backward decode only.
    /// All map into the round-5b positions via the renderer's
    /// `safeZone` mapping; the spec table below treats them as aliases.
    case topLeftVoid
    case topLeftAnchor
    case topRightGutter
    case rightBleedHero
    case midLeftMargin
    case midRightInline
    case bottomLeftAnchor
    case bottomRightGutter

    public var defaultX: CGFloat {
        // Round-5d: stickers live exclusively in the BOTTOM CREAM GAP —
        // the empty space between body text's end and the folio rule.
        // This guarantees zero text overlap, large recognizable size,
        // and a single semantic anchor per page.
        switch self {
        case .topLeftCorner:     return 0.50  // → topCenterTuck (single slot)
        case .topRightCorner:    return 0.50
        case .topCenterTuck:     return 0.50
        case .bottomLeftGap:     return 0.30
        case .bottomRightGap:    return 0.72
        // Legacy aliases → bottom cream zone centered.
        case .topLeftVoid, .topLeftAnchor, .midLeftMargin:   return 0.50
        case .topRightGutter, .rightBleedHero, .midRightInline: return 0.50
        case .bottomLeftAnchor:  return 0.30
        case .bottomRightGutter: return 0.72
        }
    }
    public var defaultY: CGFloat {
        // All sticker slots land in the bottom cream zone — between
        // where the body text ends (~0.55) and the folio (~0.84). A
        // sticker centered at y=0.70 with size 0.30 (≈120pt @ 393pt
        // width) fits cleanly between body and footer.
        switch self {
        case .topLeftCorner, .topRightCorner, .topCenterTuck: return 0.70
        case .bottomLeftGap, .bottomRightGap:                 return 0.72
        case .topLeftVoid, .topLeftAnchor, .midLeftMargin:    return 0.70
        case .topRightGutter, .rightBleedHero, .midRightInline: return 0.70
        case .bottomLeftAnchor, .bottomRightGutter:           return 0.72
        }
    }
    public var defaultSizePct: CGFloat {
        // Larger so the asset is RECOGNIZABLE — when it's a candle,
        // user sees a candle; when it's books, user sees books. The
        // bottom cream gap can comfortably hold ~120pt sticker on
        // iPhone 17 width (393pt). 30% width = ~118pt.
        switch self {
        case .topLeftCorner, .topRightCorner, .topCenterTuck: return 0.30
        case .bottomLeftGap, .bottomRightGap:                 return 0.22
        default:                                              return 0.28
        }
    }
    public var defaultRotation: Double {
        // Round-5d: rotation kept subtle (±5°) since the sticker is the
        // single visual focus of the bottom cream zone — bigger angles
        // read as careless not editorial.
        switch self {
        case .topLeftCorner:     return -4
        case .topRightCorner:    return  4
        case .topCenterTuck:     return -3
        case .bottomLeftGap:     return  3
        case .bottomRightGap:    return -3
        case .topLeftVoid, .topLeftAnchor, .midLeftMargin:   return -4
        case .topRightGutter, .rightBleedHero, .midRightInline: return  4
        case .bottomLeftAnchor:  return  3
        case .bottomRightGutter: return -3
        }
    }
    public var defaultZIntent: ZIntent {
        // Round-5b: every position is "marginalia" — they live in cream-
        // only zones, never overlapping text. The ZIntent enum stays
        // for shadow + animation registers.
        return .marginalia
    }
}

public enum ZIntent: String, Codable, Sendable, Hashable {
    case underText   // 0.78-0.85 opacity, behind text column
    case overCream   // 0.92-1.0 opacity, beside text (no overlap)
    case marginalia  // 0.92-1.0 opacity, in gutters with hard-offset shadow
}

// MARK: - ScrapbookSlot

public struct ScrapbookSlot: Equatable, Hashable, Sendable, Codable {
    public var position: SlotPosition
    public var assetSlug: String        // raw imageset name (must exist)
    public var sizePct: CGFloat         // 0.12...0.32
    public var rotationDeg: Double      // -14...+14
    public var offsetXPct: CGFloat      // -0.20...+0.20 of canvas width
    public var offsetYPct: CGFloat      // -0.12...+0.12 of canvas height
    public var zIntent: ZIntent
    public var edgeBleedPct: CGFloat    // 0.0...0.30
    public var opacity: Double          // 0.62...1.00

    public init(position: SlotPosition,
                assetSlug: String,
                sizePct: CGFloat? = nil,
                rotationDeg: Double? = nil,
                offsetXPct: CGFloat = 0,
                offsetYPct: CGFloat = 0,
                zIntent: ZIntent? = nil,
                edgeBleedPct: CGFloat = 0,
                opacity: Double = 1.0) {
        self.position = position
        self.assetSlug = assetSlug
        self.sizePct = sizePct ?? position.defaultSizePct
        self.rotationDeg = rotationDeg ?? position.defaultRotation
        self.offsetXPct = offsetXPct
        self.offsetYPct = offsetYPct
        self.zIntent = zIntent ?? position.defaultZIntent
        self.edgeBleedPct = edgeBleedPct
        self.opacity = opacity
    }
}

// MARK: - ScrapbookRecipe defaults

public extension ScrapbookRecipe {
    /// Round-5d: every recipe ships ONE sticker centered in the bottom
    /// cream gap between body's end and folio. ~30% canvas width so the
    /// asset is recognizable. Topic-semantic asset assignment lives in
    /// the manifest's `heroFill`/`accent1Fill`/`accent2Fill` per lesson —
    /// see scripts/assign_semantic_assets.py for the pillar+keyword
    /// rules. Sticker NEVER overlaps text by construction (y=0.70 is
    /// below body's max extent on a one-viewport page).
    func defaultSlots(fillingHero: String?,
                      fillingAccent1: String?,
                      fillingAccent2: String? = nil) -> [ScrapbookSlot] {
        // Recipe variants are kept but they all map to a single
        // centered sticker now. The recipe metadata still drives the
        // entrance animation register + per-act feel.
        let asset = fillingHero ?? fillingAccent1 ?? fillingAccent2
        switch self {
        case .editorialBleed:
            return [
                ScrapbookSlot(position: .topCenterTuck,
                              assetSlug: asset ?? "onb-filler-books",
                              opacity: 1.0),
            ]
        case .marginaliaNote:
            return [
                ScrapbookSlot(position: .topCenterTuck,
                              assetSlug: asset ?? "onb-filler-tumbler",
                              opacity: 1.0),
            ]
        case .kitchenWindow:
            return [
                ScrapbookSlot(position: .topCenterTuck,
                              assetSlug: asset ?? "onb-filler-matcha",
                              opacity: 1.0),
            ]
        case .bedsideSpread:
            return [
                ScrapbookSlot(position: .topCenterTuck,
                              assetSlug: asset ?? "onb-filler-candle",
                              opacity: 1.0),
            ]
        }
    }
}

public enum BleedDirection: String, Codable, Sendable {
    case leftBleed, rightBleed, topBleedCentered
}

public enum CornerPin: String, Codable, Sendable {
    case topRightPin, bottomLeftBleed
}

public enum Diagonal: String, Codable, Sendable {
    case topRightToBottomLeft, topLeftToBottomRight
}

// MARK: - Dingbat
//
// Small typographic ornament that appears above a P4 close-page
// headline when the lesson is `typographyOnly` (the dominant page-kind
// after the round-4 scroll-kill collapse). Five glyphs picked for
// magazine-page provenance; the act-class mapping in `DingbatLookup`
// assigns each act its rotating ornament.

public enum Dingbat: String, Codable, Sendable {
    case aldusLeaf       // ·❧·   foundation / identity / maintenance
    case threeDots       // · · · thought-patterns / relapse-prevention
    case openDiamond     // ◇     body-signals / movement
    case filledDiamond   // ◈     environment / plateaus
    case flower          // ❀     relationships / emotional-eating / graduation

    public var glyph: String {
        switch self {
        case .aldusLeaf:     return "·❧·"
        case .threeDots:     return "· · ·"
        case .openDiamond:   return "◇"
        case .filledDiamond: return "◈"
        case .flower:        return "❀"
        }
    }
}

// MARK: - Slug enums (compile-time-guaranteed asset names)
//
// Each case's rawValue IS the imageset name in Assets.xcassets. Adding
// a new slug REQUIRES adding a case here AND shipping the imageset —
// there's no string path to a missing asset.

public enum HeroPhotoSlug: String, Codable, Sendable {
    case onbItgirlPromise           = "onb-itgirl-promise"
    case onbItgirlJournal           = "onb-itgirl-journal"
    case onbItgirlPlateau           = "onb-itgirl-plateau"
    case onbItgirlPreeat            = "onb-itgirl-preeat"
    case onbItgirlPsychHoodie       = "onb-itgirl-psych-hoodie"
    case onbItgirlPsychStretch      = "onb-itgirl-psych-stretch"
    case onbItgirlPsychWater        = "onb-itgirl-psych-water"
    case onbItgirlReshape           = "onb-itgirl-reshape"
    case onbItgirlFirstweek         = "onb-itgirl-firstweek"
    case jmHeroFloorAgainstBed_d7   = "jm_hero_floor_against_bed_d7"
    case jmHeroKitchenWaterMidnight = "jm_hero_kitchen_water_glass_midnight_d14"
    case jmHeroWindowMorningCoffee  = "jm_hero_window_morning_coffee_d28"
}

public enum ArtifactSlug: String, Codable, Sendable {
    case onbFillerAnthurium  = "onb-filler-anthurium"
    case onbFillerBooks      = "onb-filler-books"
    case onbFillerBouquet    = "onb-filler-bouquet"
    case onbFillerBracelets  = "onb-filler-bracelets"
    case onbFillerCactus     = "onb-filler-cactus"
    case onbFillerCandle     = "onb-filler-candle"
    case onbFillerHourglass  = "onb-filler-hourglass"
    case onbFillerMatcha     = "onb-filler-matcha"
    case onbFillerOlivetree  = "onb-filler-olivetree"
    case onbFillerRoses      = "onb-filler-roses"
    case onbFillerTumbler    = "onb-filler-tumbler"
    case accentDumbbells     = "accent-dumbbells"
    case accentGift          = "accent-gift"
    case accentPlateRibbon   = "accent-plate-ribbon"
    case accentSunglasses    = "accent-sunglasses"
    case eduBodyPrimer       = "edu-body-primer"
    case eduCycle            = "edu-cycle"
    case eduFiveMinutes      = "edu-five-minutes"
    case eduPlateau          = "edu-plateau"
    case eduRealLife         = "edu-real-life"
    case onbIdentityCalm     = "onb-identity-calm"
    case onbIdentityLight    = "onb-identity-light"
    case onbIdentityPowerful = "onb-identity-powerful"
    case onbIdentityRadiant  = "onb-identity-radiant"
    case onbIdentityStrong   = "onb-identity-strong"
    case breathBloom         = "breath_bloom"
    case itgirlBreathe       = "itgirl-breathe"
    case onbProfileBook      = "onb-profile-book"
    case onbProfileLatte     = "onb-profile-latte"
    case onbProfilePhone     = "onb-profile-phone"
    case onbProfileSmoothie  = "onb-profile-smoothie"
    case onbCohort1          = "onb-cohort-1"
    case onbCohort2          = "onb-cohort-2"
}

/// Restricted subset for `twinAccentCorners` — prevents accidentally
/// using a hero portrait or filler object at 18% canvas (where it
/// would render as smudge).
public enum AccentSlug: String, Codable, Sendable {
    case accentSunglasses  = "accent-sunglasses"
    case accentPlateRibbon = "accent-plate-ribbon"
    case accentGift        = "accent-gift"
    case accentDumbbells   = "accent-dumbbells"
}

// MARK: - DingbatLookup
//
// Per-act P4 close-page dingbat. The act number is 1-12 (84 days / 7
// days per micro-act). The mapping rotates through the 5 dingbats so
// each act-class gets a glyph that semantically fits its theme.

public enum DingbatLookup {
    public static func dingbat(forCanonicalDay day: Int) -> Dingbat {
        let microAct = max(1, ((day - 1) / 7) + 1)
        switch microAct {
        case 1, 6, 11:  return .aldusLeaf
        case 2, 7:      return .openDiamond
        case 3, 10:     return .threeDots
        case 4, 8:      return .filledDiamond
        case 5, 9, 12:  return .flower
        default:        return .aldusLeaf
        }
    }
}
