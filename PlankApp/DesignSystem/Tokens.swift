import SwiftUI
import UIKit

// MARK: - Typography
//
// Two families:
//   - Fraunces (serif, editorial) for hero/title/italic-accent slots
//   - DM Sans (utility sans) for heading/body/caption/eyebrow
//
// Fraunces ships per-optical-size in the upstream repo. We bundle the 72pt
// optical (designed for ≥24pt usage) since title (32pt) and display (56pt)
// both sit comfortably in that range. PostScript names: Fraunces72pt-Light,
// Fraunces72pt-Regular, Fraunces72pt-SemiBold, Fraunces72pt-SemiBoldItalic.
//
// "Medium" doesn't ship at 72pt opsz — SemiBold is the closest weight and
// reads as more emphatic anyway, which matches the editorial intent.

enum Typo {
    /// Custom-font helper that's Dynamic Type-aware via `relativeTo:`.
    /// SwiftUI's `Font.custom(_:size:relativeTo:)` scales the size
    /// relative to a system text style as the user adjusts Larger
    /// Text in iOS settings. The previous bridge through UIFont
    /// produced a fixed-size font that ignored accessibility scaling.
    private static func font(_ name: String, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(name, size: size, relativeTo: style)
    }

    static let display = font("Fraunces72pt-Light", size: 56, relativeTo: .largeTitle).leading(.tight)
    static let title = font("Fraunces72pt-SemiBold", size: 32, relativeTo: .title)
    static let titleItalic = font("Fraunces72pt-SemiBoldItalic", size: 32, relativeTo: .title)
    static let heading = font("DMSans-SemiBold", size: 20, relativeTo: .headline)
    static let body = font("DMSans-Regular", size: 16, relativeTo: .body)
    static let caption = font("DMSans-Medium", size: 13, relativeTo: .caption)
    static let eyebrow = font("DMSans-SemiBold", size: 12, relativeTo: .caption2)

    // MARK: - v1.0.7 aggressive Gen-Z luxury editorial tokens
    //
    // Per docs/aggressive_genz_luxury_2026_06_06.md §4. Fraunces ships
    // optical-size axes at 9pt / 72pt / 144pt; editorial typography
    // MUST use the axis. Until v1.0.8 wires actual variable-font
    // optical-axis instances, we map these to the SemiBold / Light
    // weights that ship with the bundled Fraunces72pt cuts — the
    // SwiftUI rendering still reads as more editorial because the
    // sizing + tracking + line-height are tuned per token.

    /// JenisNote masthead. Italic Fraunces, 19pt display, tracking -0.2
    /// (editorial display always tightens). Editorial 72pt-optical
    /// register.
    static let mastheadDisplay = font("Fraunces72pt-SemiBoldItalic", size: 19, relativeTo: .title3)

    /// Becoming chapter cover title. Italic Fraunces 36pt, tracking
    /// -0.5 for the display-cut shrink. Magazine-masthead register.
    static let chapterCover = font("Fraunces72pt-SemiBoldItalic", size: 36, relativeTo: .title)

    /// Editorial eyebrow — 11pt UPPERCASE tracking 3 (Acne Paper +
    /// Cereal convention). Fraunces SemiBold for the editorial weight;
    /// not DM Sans (this is the wider-tracked, page-numbered eyebrow
    /// register).
    static let editorialEyebrow = font("Fraunces72pt-SemiBold", size: 11, relativeTo: .caption2)

    /// Pull-quote between chapters / on Sunday Feature. Italic
    /// Fraunces 22pt, lh 1.45 — pull-quotes should breathe.
    static let pullQuote = font("Fraunces72pt-SemiBoldItalic", size: 22, relativeTo: .title3)

    /// Section / chapter title where it's not a full cover (smaller
    /// inline use). Italic Fraunces 26pt, lh 1.2.
    static let sectionTitle = font("Fraunces72pt-SemiBoldItalic", size: 26, relativeTo: .title2)

    // MARK: - v1.0.7 minimal-functional-aesthetic dashboard tokens
    //
    // Per docs/becoming_home_minimal_spec_2026_06_06.md. The
    // founder's verdict on italic numerals: "i don't like italic
    // numbers." Italic-Fraunces stays on COPY punch words (the
    // *becoming* in "you're becoming steady") — for numerals it
    // dies. These tokens lock the new numeral system:
    //   - Hero: Fraunces *Light* 64pt (NOT SemiBold — SemiBold
    //     reads banking-app; Light at display size carries Aesop
    //     warmth). Tabular via the call-site .monospacedDigit().
    //   - Secondary: DM Sans Medium 22pt for stat-row numbers,
    //     deltas, anything that's "supporting metric." Tabular.
    //   - Tertiary: DM Sans Regular 13pt for units, day-counts,
    //     "of N" fragments. Tracking +0.1 (small upright digits
    //     breathe without bolding — Things 3 move).
    //   - Stat label: DM Sans Regular 11pt, uppercase, tracking
    //     +0.06em via .kerning() at call site, cocoa 48%. Aesop's
    //     specimen-label move; 60% of the difference between a
    //     warm tool and a tracker.
    //   - Roman ornament: Fraunces SemiBold UPRIGHT (not italic)
    //     at 11pt for chapter pagination. Romans are typographic
    //     furniture (Penguin Classics convention), not metrics —
    //     italic on them would be redundant decoration.

    /// Dashboard hero number — weight digit, plank PR, the single
    /// largest numeral on the surface. Fraunces Light at 64pt.
    /// Apply `.monospacedDigit()` at the call site for tabular.
    static let numeralHero = font("Fraunces72pt-Light", size: 64, relativeTo: .largeTitle).leading(.tight)

    /// Stat-row number — streak count, plank time, sessions this
    /// week. DM Sans Medium 22pt. Apply `.monospacedDigit()` at
    /// the call site so deltas re-render without horizontal shift.
    static let numeralStat = font("DMSans-Medium", size: 22, relativeTo: .title3)

    /// Tertiary digits — units ("lb"), day counts ("12 of 14"),
    /// inline meta. DM Sans Regular 13pt. Add `.kerning(0.1)` at
    /// the call site so small upright digits breathe.
    static let numeralMeta = font("DMSans-Regular", size: 13, relativeTo: .footnote)

    /// Stat-row label — uppercase one-word labels above stat
    /// numerals ("STREAK", "PLANK PR", "THIS WEEK"). DM Sans
    /// Regular 11pt. Apply `.kerning(0.06 * 11)` (~0.66pt) and
    /// `.textCase(.uppercase)` at the call site.
    static let statLabel = font("DMSans-Regular", size: 11, relativeTo: .caption2)

    /// Roman numeral chapter pagination — "i.", "ii.", "iii.",
    /// "iv.", "v." Upright Fraunces SemiBold 11pt, lowercase
    /// (Penguin Classics convention). Apply `.kerning(0.3)` at
    /// the call site.
    static let romanOrnament = font("Fraunces72pt-SemiBold", size: 11, relativeTo: .caption2)

    // MARK: - v1.1 program-surface tokens (Her75 register)
    //
    // Program surfaces (PlanView, ProgramHomeView, IntensityPickerView,
    // ProgressGridView, ProgramDayShareCard) get a parallel typographic
    // layer that's louder than the existing display/title cuts and
    // amplifies the italic-Fraunces voice signal to every program
    // header. NOT used on existing celebration surfaces.

    /// Program-surface hero header — "follow your routine", "your
    /// program is ready". Fraunces Light 52pt with `.leading(.tight)`.
    /// Pair with a manually 2-line `VStack(spacing: -10)` of Text
    /// components so the line gap is hand-controlled instead of
    /// natural-wrapped (which left a fat 56pt gutter between lines
    /// on the 48pt size). Founder direction 2026-06-09: "like her75,
    /// reduce line heights and make texts bigger throughout."
    /// her75 Phase 2 re-ladder (2026-06-10): 52pt → 44pt. The
    /// celebration peak stays earned (one step above the 38pt
    /// in-app hero) but 52pt read as oversized against the new
    /// 38pt question default. ChapterCompleteView is the only
    /// consumer of this register.
    // v4 R2 reverted with heroHeadline — celebration back on Fraunces
    // pending the font-designer verdict.
    static let programHeroDisplay = font("Fraunces72pt-Light", size: 44, relativeTo: .largeTitle).leading(.tight)

    /// Italic accent at the program-hero size. Pair with
    /// programHeroDisplay on the same Text via inline +.
    static let programHeroItalic = font("Fraunces72pt-SemiBoldItalic", size: 44, relativeTo: .largeTitle).leading(.tight)

    /// Recommended negative spacing for a 2-line her75-style hero
    /// VStack at programHeroDisplay/Italic size. Brings the two
    /// lines visually together so the block reads as a single
    /// editorial unit instead of two stacked sentences. **Founder
    /// QA 2026-06-09:** tightened from -10 to -16 after the second
    /// pass showed lines still felt separated. -16 is the her75
    /// "lines almost touch" register; pair with single-line VStack
    /// rows (no internal wrap) so the gap is uniform throughout.
    // her75 Phase 2 re-ladder (2026-06-10): -16 → -20 at the new
    // 44pt size (-45% ratio, matching the heroHeadline cadence).
    static let programHeroLineGap: CGFloat = -20

    // MARK: - Question hero (v8 P8.9 typography insights)
    //
    // Her75 typography reference set (2026-06-10): in-app question
    // screens (not App Store / marketing heroes) render their hero
    // copy in Fraunces SemiBold at ~38pt with tight negative leading
    // and a hanging italic punch when desired. ONE register lighter
    // than programHero (52pt Light): question heroes carry decision
    // intent, not the editorial-display weight of a chapter beat.
    //
    // The pair below is the canonical token for OnboardingView's
    // jfHeader and any other in-app question-class hero. Use
    // ItalicAccentText directly when a screen needs the italic punch
    // — no markdown `*word*` markers per [[feedback-no-italic-
    // markdown-markers]].

    /// Upright display Fraunces at the question-hero size.
    ///
    /// **Re-tuned 2026-06-10 (third pass):** 40pt was still spilling
    /// on questions like "any weight-related medication right now?"
    /// which wrap to 4 lines and crowd out the option pills + CTA.
    /// 34pt is the right register — slightly bigger than the original
    /// 32pt `Typo.title` (which used to drive jfHeader before the
    /// her75 push), keeps her75's display-heavy register, and fits
    /// the longest medical-phrase questions on 2 lines.
    static let questionHero = font("Fraunces72pt-SemiBold", size: 34, relativeTo: .largeTitle)

    /// Italic accent at the question-hero size. Pair with
    /// `questionHero` inline (`Text(base).font(.questionHero) + Text(punch).font(.questionHeroItalic)`)
    /// or via `ItalicAccentText(... baseFont: .questionHero, italicFont: .questionHeroItalic)`.
    static let questionHeroItalic = font("Fraunces72pt-SemiBoldItalic", size: 34, relativeTo: .largeTitle)

    /// `.lineSpacing(_)` for question-hero stacks. Founder reference
    /// (her75 App Store screens 2026-06-10): lines visually TOUCH on
    /// 2-line heroes like "Become / that girl". -14 at 34pt produces
    /// the same clamp — lines almost overlap at descenders/ascenders
    /// without becoming illegible. This is the "luxurious" her75
    /// signature; don't loosen past -12.
    static let questionHeroLineGap: CGFloat = -14

    /// Display hero — the BIGGEST register. Re-tuned 2026-06-10:
    /// 44pt was clipping pinned CTAs on the goal-date reveal +
    /// paywall heroes that have stacked content below. 38pt Light
    /// still reads as chapter-cover scale at her75's cadence, just
    /// shorter — pairs with the much tighter -16 lineGap below so
    /// the visual weight is preserved.
    static let displayHero = font("Fraunces72pt-Light", size: 38, relativeTo: .largeTitle).leading(.tight)

    /// Italic accent at the display-hero size. Heavy weight against
    /// the upright Light creates the her75 weight juxtaposition.
    static let displayHeroItalic = font("Fraunces72pt-SemiBoldItalic", size: 38, relativeTo: .largeTitle).leading(.tight)

    /// Negative leading for display-hero stacks. -16 at 38pt = the
    /// her75 "lines touch" cadence on the App Store hero shots
    /// (founder reference 2026-06-10).
    static let displayHeroLineGap: CGFloat = -16

    /// Numeral on ProgramStickyNote — the 1-5 row markers on
    /// DailyChecklistCard. Italic Fraunces 28pt. Hand-cut paper
    /// register; the ONE craft signal per program screen.
    static let stickyNumeral = font("Fraunces72pt-SemiBoldItalic", size: 28, relativeTo: .title2)

    // MARK: - v3 her75 typography (2026-06-10)
    //
    // Five tokens extracted from the her75 8-screen App Store reference
    // set (IMG_6275–IMG_6282). Adds the missing +1 register above
    // `displayHero` (38pt) — her75's silent brand-statement screens
    // (IMG_6275 / IMG_6280) sit at ~42pt. Plus the social-proof pill,
    // masthead-sticker numeral, and luxury-tracked editorial caption
    // they use as supporting typography. Apply `.kerning(-0.4)` at the
    // call site for the hero size to match her75's measured -1%
    // tracking. See `docs/her75_design_extraction_2026_06_10.md`.

    /// `heroHeadline` — THE in-app hero register.
    ///
    /// v4 R2 (2026-06-10, founder-authorized typeface swap per
    /// docs/onboarding_v4_rebuild_plan_2026_06_10.md §B): Fraunces →
    /// **Bodoni Moda Display** (opsz 48 static cut, wght 600). her75's
    /// serif is a high-contrast fashion-Didone — razor hairlines,
    /// vertical stress, dramatic italics. Fraunces (soft, wonky,
    /// low-contrast) never read her75 at any size. Founder verbatim:
    /// "when you copy font design, copy it almost as it is. if our
    /// existing font style doesn't work, we can also change it."
    ///
    /// 40pt Didone ≈ 38pt Fraunces optical size (smaller x-height).
    /// ONE register for all hero surfaces. Pair with
    /// `heroHeadlineItalic`; kerning handled by the face itself —
    /// drop the -0.4 call-site kerning when migrating (Didones are
    /// already tight; extra negative tracking clogs hairlines).
    // v4 R2 REVERTED (2026-06-10) — founder device QA: "the new font
    // style looks horrible." Bodoni Moda opsz48/600 read wrong on
    // device. Heroes back on Fraunces while the font-designer agent
    // identifies her75's actual face + the correct copy (candidates:
    // DM Serif Display — designed sibling of our DM Sans body face —
    // Playfair Display, Prata, different Bodoni cut). TTFs stay
    // bundled pending the verdict.
    static let heroHeadline = font("Fraunces72pt-SemiBold", size: 38, relativeTo: .largeTitle)

    /// Italic accent at the hero-headline size.
    static let heroHeadlineItalic = font("Fraunces72pt-SemiBoldItalic", size: 38, relativeTo: .largeTitle)

    /// `.lineSpacing()` for hero-headline stacks (-47% ratio at 38pt
    /// Fraunces per the her75 measured cadence).
    static let heroHeadlineLineGap: CGFloat = -18

    /// `heroSubpill` — DM Sans SemiBold 13pt for the cocoa-fill
    /// social-proof pill that sits BELOW (never above) the hero
    /// headline. The IMG_6275 "Among 24,000+ women" / IMG_6277
    /// "+30% success with friends" slot. Always anchored to a real
    /// number per the data-provenance rule; use `SocialProofPill`
    /// component when wiring. Apply `.kerning(0.2)` at call site.
    static let heroSubpill = font("DMSans-SemiBold", size: 13, relativeTo: .caption)

    /// `mastheadSticker` italic register — Fraunces SemiBoldItalic
    /// 30pt for the italic word in a 2-tone sticker masthead
    /// ("*day* one" — `mastheadStickerItalic` on "day",
    /// `mastheadSticker` upright on "one"). The IMG_6279 sticker
    /// masthead. Differs from `stickyNumeral` (28pt, for row
    /// numerals on DailyChecklistCard); this is for screen-level
    /// titles like ProgramStickyNoteHeader.
    static let mastheadSticker = font("Fraunces72pt-SemiBold", size: 30, relativeTo: .title2)
    static let mastheadStickerItalic = font("Fraunces72pt-SemiBoldItalic", size: 30, relativeTo: .title2)

    /// `captionTracked` — DM Sans Medium 11pt with `+0.18em` wider
    /// tracking than `statLabel` (which uses `+0.06em`). Luxury-
    /// magazine eyebrow convention; the IMG_6279 footer "HER 75
    /// CHALLENGE • BY HER 75" register. Apply `.textCase(.uppercase)`
    /// + `.kerning(0.18 * 11)` (~1.98pt) at call site.
    static let captionTracked = font("DMSans-Medium", size: 11, relativeTo: .caption2)
}

// MARK: - Spacing (4pt base)

enum Space {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 48

    static let screenPadding: CGFloat = md
    static let cardPadding: CGFloat = md
    static let minTapTarget: CGFloat = 44

    // MARK: - v1.1 program-surface spacing (Her75 whitespace rhythm)
    //
    // Her75's actual luxury signal is radical vertical whitespace —
    // ~80pt below status bar before hero, ~64pt between major sections.
    // Most apps ship 24pt for both; Her75 doubles/triples it.
    // Program surfaces only — existing screens keep lg=24.

    /// Top inset before program greeting on PlanView / ProgramHomeView
    /// / IntensityPickerView. 40pt — tightened from 80pt 2026-06-09
    /// after founder review: 80pt pushed bodies below the fold on
    /// iPhone 15 and made every screen feel half-empty. 40pt still
    /// breathes well above safeArea without over-asserting.
    static let hero: CGFloat = 40

    /// Vertical gutter between major program blocks (hero → card →
    /// footer). 36pt — tightened from 64pt 2026-06-09 along with
    /// Space.hero. Pairs cleanly with Space.lg=24 row paddings.
    static let section: CGFloat = 36
}

// MARK: - Colors
//
// JeniFit palette — dusty rose accent on a soft pink-cream base.
// Cocoa (bgInverse / textPrimary share the same hex) anchors the dark
// surfaces. Pink (accent / accentSubtle) is reserved for selected states,
// celebrations, and badges — primary CTAs use cocoa, not pink.

enum Palette {
    static let bgPrimary = Color(hex: "#FDF6F4")
    static let bgElevated = Color(hex: "#FFFAF8")
    static let bgInverse = Color(hex: "#3D2A2A")

    static let textPrimary = Color(hex: "#3D2A2A")
    /// Muted body color. Deepened from #8E6D6D (was 4.31:1 on bgPrimary —
    /// just below WCAG AA's 4.5:1 normal-text threshold) to #7B5959
    /// which lands at 5.76:1 (AA pass). Visually a touch darker but
    /// keeps the rose-cocoa hue.
    static let textSecondary = Color(hex: "#7B5959")
    static let textInverse = Color(hex: "#FDF6F4")

    static let accent = Color(hex: "#C4677A")
    static let accentSubtle = Color(hex: "#F5D5D8")

    /// v1.0.7 aggressive Gen-Z luxury (Sweet July + Acne Paper
    /// editorial register). Two-cream paper-layering — bgPrimary
    /// is the standard scroll, pageIvory is the chapter-cover /
    /// TOC stock. Like a real magazine has cover stock + interior
    /// stock. Per docs/aggressive_genz_luxury_2026_06_06.md §5.
    static let pageIvory = Color(hex: "#F8F0EC")

    /// Heirloom oxblood-rose for Roman numerals, drop caps, pull-
    /// quote first letter, Sunday Feature byline, pagination active
    /// state. Sits between rose and cocoa — adds richness without
    /// breaking warmth. Per the 2026 jewel-tone trend (Envato
    /// color-scheme research). Reserved for editorial moments;
    /// never a CTA color.
    static let jeweledRose = Color(hex: "#7A2E3F")

    /// State colors deepened to pass WCAG AA (4.5:1) on bgPrimary
    /// for normal-weight body text. Previously failed even AA-Large
    /// (sage at 2.32:1, amber at 2.12:1). New values are in the same
    /// hue family — sage stays sage, amber stays honey-bronze. stateBad
    /// at 3.52:1 is AA-Large only; left as-is because the only places
    /// it surfaces (Delete Account warning, error toasts) already use
    /// large bold copy that qualifies for AA-Large.
    static let stateGood = Color(hex: "#5F7345")  // 4.89:1 — was #9CAA7E
    static let stateWarn = Color(hex: "#8D6A2E")  // 4.65:1 — was #D4A464
    static let stateBad = Color(hex: "#B47272")

    static let divider = Color(hex: "#EFE0DC")

    // MARK: - v1.0.7 minimal-functional 3-tier cocoa scale
    //
    // Per docs/becoming_home_minimal_spec_2026_06_06.md "Linear-
    // grade detail" — most apps ship 2 cocoa tiers (primary +
    // 60% secondary) and look bolted-together. The third middle
    // step at 72% is the move nobody ships, and it's what makes
    // Things 3 / Linear / Reflect feel composed.
    //
    // Mapping:
    //   cocoaPrimary   — hero numerals, section heads (100%)
    //   cocoaSecondary — stat labels, tertiary digits (72%)
    //   cocoaTertiary  — meta ("logged 2h ago", roman numerals,
    //                    "of 14" fragments, hairline-context
    //                    captions) (48%)
    //
    // Plus a paired 0.5pt hairline color at cocoa-12%. Always 0.5pt,
    // never 1pt — that distinction is the whole difference.
    static let cocoaPrimary = Color(hex: "#3D2A2A").opacity(1.0)
    static let cocoaSecondary = Color(hex: "#3D2A2A").opacity(0.72)
    static let cocoaTertiary = Color(hex: "#3D2A2A").opacity(0.48)
    static let hairlineCocoa = Color(hex: "#3D2A2A").opacity(0.12)

    /// Activity-calendar "frozen day" cell. Aliased to accentSubtle so the
    /// calendar reads cohesive with the rest of the palette. Promoted from
    /// the inline `Color(hex: "#D6EBF5")` literal noted in the screen audit.
    static let frozenDay = accentSubtle

    // MARK: - v1.1 program-surface palette (Her75 register)
    //
    // bgPrimary #FDF6F4 stays the locked scroll background. Program
    // surfaces layer a TRUE WHITE card on top of the pink — closest
    // we can get to Her75 paperwhite without dropping the brand
    // pink. ProgramPaperShadow (defined below) replaces .plankShadow()
    // on program surfaces only.

    /// Program home (PlanView) background.
    ///
    /// **Rolled back 2026-06-10 (founder QA):** previously rendered
    /// the saturated pink #FBECEC across program surfaces. Founder
    /// re-locked the canonical Color tokens (bgPrimary cream #FDF6F4
    /// is the app's only background). Kept as an alias to bgPrimary
    /// so existing program-surface call sites compile + render the
    /// correct cream without a wholesale per-file sweep. Future
    /// refactors should resolve this directly to `bgPrimary`.
    static let programBgPrimary: Color = bgPrimary

    /// Conditional background — was pink for program-era users, cream
    /// for legacy. **Rolled back 2026-06-10:** founder unified to the
    /// canonical bgPrimary regardless of enrollment state. Alias kept
    /// for the same compile-safety reason as `programBgPrimary` above.
    static var programEraBg: Color { bgPrimary }

    /// Card surface for program rows (PlanView, ProgressGridView,
    /// IntensityPickerView).
    ///
    /// **Rolled back 2026-06-10 (founder QA):** previously rendered
    /// pure white #FFFFFF to crisp against the program-pink bg. Now
    /// that the bg is back to the canonical cream `bgPrimary`, pure
    /// white reads off-spec — founder relocked the color tokens with
    /// `bgElevated #FFFAF8` as the only elevated surface. Aliased so
    /// call sites stay compile-safe.
    static let programCard: Color = bgElevated

    /// Sticky-note row marker pastels. Cycled by row index on
    /// ProgramStickyNote — the ONE craft signal per program screen.
    /// Mint → Butter → Rose → Olive, repeat. Sourced from Her75's
    /// hand-cut paper register.
    static let stickyMint   = Color(hex: "#C8E6CB")
    static let stickyButter = Color(hex: "#FFE7A8")
    static let stickyRose   = Color(hex: "#F4D1D1")
    static let stickyOlive  = Color(hex: "#D9DBA8")
}

// MARK: - Corner Radius

enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 14
    static let lg: CGFloat = 24

    /// v1.1 program-card radius. Slightly tighter than `lg=24` —
    /// Her75 cards sit at ~20pt for the photo-mosaic / checklist
    /// register. Existing surfaces keep `lg`.
    static let programCard: CGFloat = 20
}

// MARK: - Motion (calm, mindful, magical defaults)
//
// Phase 20a: a small set of named animations replacing per-site magic
// numbers. The philosophy:
//   • slow swells over snap — entrance ≥0.55s so the eye can follow
//   • high-damping springs so taps respond without rubber-band bounce
//   • generous staggers so cascades feel intentional, not mechanical
//   • slow repeat-forever loops for ambient cues (loading, breathing)
//
// Migrate per-site, never globally. Drop-in via `.animation(Motion.x, …)`
// or `withAnimation(Motion.x) { … }`. Curves were tuned against the
// "screens feel rushed and laggy" feedback (2026-05-08 testing).

enum Motion {
    /// Element appearing on screen for the first time. Slow ease-out so
    /// the swell reads as deliberate. Default for top-of-screen heroes,
    /// list rows, modal contents.
    static let entrance: Animation = .easeOut(duration: 0.55)

    /// Subtle entrance — used when the parent is already visible and we
    /// want a quieter reveal (toasts, inline feedback, badges).
    static let entranceSoft: Animation = .easeOut(duration: 0.42)

    /// Element leaving — slightly faster than entrance so dismissals
    /// don't drag. Pair with `.transition(.opacity)` for the cleanest
    /// exit.
    static let exit: Animation = .easeIn(duration: 0.32)

    /// Content swaps inside the same surface — tab routing, list filter
    /// changes, image-vs-loading-vs-content. Symmetric ease so neither
    /// direction feels privileged.
    static let crossFade: Animation = .easeInOut(duration: 0.45)

    /// Press / tap response. Short enough to feel snappy, easeOut so the
    /// release rebound is calm. NEVER use a spring here — bounce on tap
    /// reads as cheap on a calm surface.
    static let tap: Animation = .easeOut(duration: 0.16)

    /// Tactile feedback that benefits from a physics rebound — drag
    /// release, scale-pop on confirm, sticker-stamp landings. High
    /// damping (0.88) means it settles in one bounce, not three.
    static let gentleSpring: Animation = .spring(response: 0.55, dampingFraction: 0.88)

    /// Inter-element delay for stagger cascades (lists, sticker scatter,
    /// section reveal). Pair with `.delay(Double(index) * Motion.stagger)`.
    /// 0.10 reads as deliberate without dragging on long lists.
    static let stagger: Double = 0.10

    /// Slow ambient loop — loaders, breathing pulses, idle heartbeats.
    /// Repeat-forever flavor; pair with `.repeatForever(autoreverses: true)`.
    static let breathing: Animation = .easeInOut(duration: 1.6)

    /// Loading-screen choreography baseline. Matches the magical
    /// 2.4s refresh window (HomeView Phase 19) so any new loading
    /// surface stays consistent without re-deriving the constant.
    static let loadingTotalSeconds: Double = 2.4

    // MARK: - v1.1 program-surface entrance (2026-06-09)
    //
    // Modern minimalist pop: opacity 0→1 + scale 0.96→1.0 with a
    // mild high-damping spring (no overshoot, no bounce). Replaces
    // the older `entrance: .easeOut(0.55)` on program surfaces so
    // every reveal feels tactile but never theatrical. Tuned for
    // 60fps on iPhone 12+ — no blur, no per-frame layout math.

    /// The spring program-surface elements animate IN with. response
    /// 0.45 + damping 0.86 = settles in one frame past the target,
    /// no visible bounce.
    static let modernPop: Animation = .spring(response: 0.45, dampingFraction: 0.86)

    /// Drag-release snap-back for the day-strip. Founder picked
    /// "slightly springier" over gentle 2026-06-09 — 0.78 damping
    /// gives one subtle bounce on settle that reads as "today is
    /// gravity, the strip wants to return here."
    static let snapBack: Animation = .spring(response: 0.45, dampingFraction: 0.78)

    // MARK: - v3 P11.3 her75 motion vocabulary (2026-06-10)
    //
    // The "breath between screens" pattern her75 ships on its 8 App
    // Store screenshots reads as luxury because it has 3 distinct
    // beats per page change:
    //   1) Current page fades out FAST (~200ms easeIn).
    //   2) Brief silent gap (~60ms) — eyes settle, no visible
    //      element. The brain reads it as decision space.
    //   3) New page eases in SLOW (~350ms easeOut) — fully formed
    //      when it lands.
    //
    // Compare the existing `.transition(.opacity)` cross-fade: both
    // pages are alive simultaneously for ~250ms, which reads as
    // tumbling not deliberate. Apply `JFPageTransition` to anywhere
    // a screen swap should feel like turning a magazine page.

    /// Fast exit phase of the her75 page-turn. Pairs with `pageEntrance`.
    static let pageExit: Animation = .easeIn(duration: 0.20)

    /// Slow entrance phase of the her75 page-turn. Lands ~60ms after
    /// the exit completes (per `pageGap`), so the new screen reads
    /// as fully arriving rather than crossing the old one.
    static let pageEntrance: Animation = .easeOut(duration: 0.35)

    /// Inter-page breath window in seconds. 0.06s = the exact gap
    /// the her75 reference shipped; anything under 0.04 reads as
    /// crossfade, anything over 0.10 reads as latency.
    static let pageGap: Double = 0.06

    /// Tile / card expansion animation — proof tiles on the plan
    /// reveal, social-proof pill on the cohort screen. Spring with
    /// medium damping so the tile feels physical without bouncing
    /// past the target.
    static let bloom: Animation = .spring(response: 0.42, dampingFraction: 0.82)

    /// Chip / badge heartbeat — the cocoa "now" pill, accent dot on
    /// the goal-weight reframe, the small "live" indicator. Soft
    /// repeat-forever 0.9s sine to draw attention without being
    /// loud. Pair with `.repeatForever(autoreverses: true)`.
    static let chipPulse: Animation = .easeInOut(duration: 0.9)

    /// Tighter stagger for grouped-element reveals — the 4-6 tiles
    /// on the plan-reveal card, the 3-pace selector. 0.06s lands
    /// the cluster as ONE moment with a hint of order, vs the
    /// default 0.10s which reads as a list animation.
    static let cascadeTight: Double = 0.06
}

// MARK: - JFPageTransition (v3 P11.3 — her75 page-turn breath)
//
// AnyTransition that composes the fast-exit + silent-gap + slow-
// entrance trio. Apply via `.transition(JFPageTransition.standard)`
// on a screen-level container that uses `.id(screen)` to trigger
// the swap. The 60ms gap is encoded as the insertion animation's
// `.delay(Motion.pageGap)` — SwiftUI handles the timing without an
// intermediate state machine.
//
// Reduce-motion: the modifier still respects the env value via the
// underlying `.opacity` transition. No extra gate needed here; the
// shorter durations + delay still read OK without springs.

enum JFPageTransition {
    /// Asymmetric opacity: exit fast (easeIn 0.20s) → 60ms gap →
    /// entrance slow (easeOut 0.35s). Net 0.55s per turn but feels
    /// like 0.35 because the user only sees the entrance phase
    /// "actively arriving."
    static let standard: AnyTransition = .asymmetric(
        insertion: .opacity.animation(Motion.pageEntrance.delay(Motion.pageGap)),
        removal: .opacity.animation(Motion.pageExit)
    )
}

// MARK: - Modern entrance modifier
//
// Reusable per-element entrance animation for program surfaces.
// Hooks an `appeared: Bool` @State on the call site — flip it to
// true in `.onAppear { appeared = true }`. With `delay:` to stagger
// cascades. No expensive effects (blur/shadow on animation are
// 1080p framebuffer-cost on iOS; we only animate opacity + scale).

struct ModernEntrance: ViewModifier {
    let appeared: Bool
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1.0 : 0.96, anchor: .center)
            .animation(
                reduceMotion ? .none : Motion.modernPop.delay(delay),
                value: appeared
            )
    }
}

extension View {
    /// Mild spring entrance for program surfaces. `appeared`
    /// drives the animation; flip to true in `.onAppear`. `delay`
    /// indexes cascades — pair with `Double(index) * 0.06` for
    /// row staggers.
    func modernEntrance(_ appeared: Bool, delay: Double = 0) -> some View {
        modifier(ModernEntrance(appeared: appeared, delay: delay))
    }
}

// MARK: - Shadow
//
// Warm rose tint on the JeniFit shadow stack. Pink shadows fade more
// visually than brown, so alpha sits at 0.10 to keep elevation legible
// on the cream bg.

struct PlankShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(
            color: Color(red: 196/255, green: 103/255, blue: 122/255).opacity(0.10),
            radius: 12,
            x: 0,
            y: 2
        )
    }
}

extension View {
    func plankShadow() -> some View {
        modifier(PlankShadow())
    }
}

// MARK: - Program paper shadow (v1.1, Her75 register)
//
// Replaces `.plankShadow()` on program surfaces only. Her75 cards
// have an almost-imperceptible drop — rgba(0,0,0,0.04) at y=4 with
// 20pt blur. No rose tint (that's PlankShadow's job for celebration
// surfaces). The card-on-pink layering does most of the work; the
// shadow just lifts it a hair.

struct ProgramPaperShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(
            color: Color.black.opacity(0.04),
            radius: 20,
            x: 0,
            y: 4
        )
    }
}

extension View {
    func programPaperShadow() -> some View {
        modifier(ProgramPaperShadow())
    }
}

// MARK: - ScrapbookCard (v8 P8.10, unified chrome)
//
// Single source-of-truth for the program-era card chrome that PlanView,
// ProgramSetup, ChapterComplete, and every settings sub-screen ship.
// Designer audit (her75 closing pass) flagged 6+ duplicated private
// `scrapbookChrome` helpers in the Settings folder rendering cream
// `bgElevated` inside what should be pure white `programCard` — on the
// pink program-era canvas the cream cards read muddy. This modifier
// locks the (`programCard` fill, 24pt corners, accent border, paper
// shadow) decision in one place so flipping to pink anywhere never
// surfaces the muddy state again.

struct ScrapbookCard: ViewModifier {
    var tint: Color = Palette.accent
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Palette.programCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(tint.opacity(0.5), lineWidth: 1.5)
            )
            .programPaperShadow()
    }
}

extension View {
    /// Wraps the receiver in the program-era scrapbook chrome: 24pt
    /// corners + pure white `programCard` fill + 1.5pt accent border +
    /// soft her75 paper shadow. Use on any card-class container that
    /// sits on `programBgPrimary` or `programEraBg`. Default tint =
    /// `Palette.accent`; pass a state color (e.g. `Palette.stateGood`)
    /// for callout cards.
    func scrapbookCard(tint: Color = Palette.accent) -> some View {
        modifier(ScrapbookCard(tint: tint))
    }
}

// MARK: - EditorialCard (v3 P11.9, her75 restraint pass 2026-06-10)
//
// The OTHER card chrome — her75 editorial register. Shadow-only, NO
// border, slightly more rounded corners (28pt vs scrapbookCard's
// 24pt). Per the art-direction composition expert brief: her75's
// cards are "pure white, ~28pt corners, shadow-only, no stroke."
//
// When to use which:
//   - `scrapbookCard` — accent-border + hard-offset shadow. Reads
//     as JeniFit-coquette playful. Welcome screen, plan-reveal hero,
//     celebration peaks. The brand-warmth surfaces.
//   - `editorialCard` — borderless + soft shadow. Reads as her75
//     editorial restraint. Settings sub-pages, Becoming bento tiles,
//     CoachNote-like body cards. The premium-tool surfaces.
//
// Founder QA 2026-06-10: "settings + becoming still look far from
// her75." This modifier unblocks those surfaces without ripping
// scrapbookCard from the celebration moments where it earns its
// keep. Both ship.

struct EditorialCard: ViewModifier {
    var cornerRadius: CGFloat = 28
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Palette.bgElevated)
                    .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 6)
            )
    }
}

extension View {
    /// Wraps the receiver in the her75 editorial chrome: 28pt corners,
    /// `bgElevated` fill, soft drop shadow, NO border. Use on
    /// premium-tool surfaces (Settings, Becoming bento tiles, body
    /// cards) where her75 editorial restraint reads as more premium
    /// than coquette warmth. Prefer over `scrapbookCard` when the
    /// surface is a list/dashboard/utility, not a brand celebration.
    func editorialCard(cornerRadius: CGFloat = 28) -> some View {
        modifier(EditorialCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Hit-target helper
//
// Expand the hit target to Apple HIG's 44×44 minimum without changing
// visible chrome. JeniFit's icon buttons (xmark close, refresh shuffle,
// eye toggle) sit at 30–32pt visually for design density; this modifier
// adds invisible padding around them so the tap area meets the
// guideline. Apply to the Button's *label*, not the Button itself —
// SwiftUI sizes the button to its label's intrinsic frame.

extension View {
    /// Expand hit target to at least `size` × `size` (default 44pt per
    /// Apple HIG) while keeping the visible chrome at its original
    /// size. Pair with `Button` labels that have a smaller visual
    /// frame. `contentShape(Rectangle())` ensures the whole padded
    /// area registers taps, not just the visible glyph.
    func tappableArea(_ size: CGFloat = 44) -> some View {
        self
            .frame(minWidth: size, minHeight: size)
            .contentShape(Rectangle())
    }
}

// MARK: - Color Hex Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
