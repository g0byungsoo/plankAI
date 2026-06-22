# capture flow design spec (2026-06-11)

her75 UX pass on the food capture flow. Founder note: "the background is still black.
we need the design consistent with the rest of the app while we keep the good things."
Scope: `Packages/PlankFood/Sources/PlankFood/Capture/*`. The package can't import the
app target, so every chrome decision below is written in FoodTheme terms. Fonts are
registered process-wide, so `Font.custom("JeniHeroSerif-Regular", ...)` works inside
PlankFood without any import.

## 0. The core call: cream desk, polaroid viewfinder

Cameras are conventionally black, but JeniFit's camera is NOT a general camera. It is a
small 9:16 inset frame (Phase M already built this), and the inset-frame pattern is
exactly what premium warm-brand scanners do: Vivino's wine scan, Picture This, Notion's
doc scan all run a light surround with the live feed inset as a framed object. Full-bleed
black is for cameras where the photo IS the screen (Apple Camera, Cal AI). Ours isn't.

**Decision: the surround goes cream. The viewfinder interior stays dark.**
The camera becomes a polaroid being composed on the cream desk, which makes the existing
matchedGeometry morph into PolaroidHero semantically continuous instead of a context jump.

- `Color.black.ignoresSafeArea()` backdrop → `FoodTheme.bgPrimary` (#FDF6F4).
- Remove `.preferredColorScheme(.dark)` from PhotoCaptureView (it exists to force dark
  status bar + dark glass; both invert on cream). Status bar reads dark-content on cream.
- `cameraLayer`'s inner `Color.black` STAYS (functional: letterbox behind live feed,
  exposure floor while the session boots). This is the only intentional black left.
- Chrome rule: anything floating OVER live video keeps dark glass (`.ultraThinMaterial`
  + `.colorScheme(.dark)`, white glyphs). Anything on the cream surround switches to the
  app register (cocoa glyphs, bgElevated fills). Glass-on-cream is invisible; never mix.

New FoodTheme tokens needed (mirror app Palette): `divider` = textPrimary @ 12%,
`textInverse` = alias of bgPrimary. Nothing else.

## 1. Camera screen (live viewfinder)

```
┌─────────────────────────────────┐  cream #FDF6F4 edge to edge
│  the scan                   (x) │  kicker DMSans-Medium 11, kerning 1.98,
│ ┌───────────────────────────┐   │  lowercase, textSecondary. X = 36pt circle,
│ │ ∘cherries                 │   │  bgElevated fill + divider hairline, cocoa glyph
│ │                           │   │
│ │      LIVE  CAMERA         │   │  inset 9:16 frame, 28pt corners
│ │      (dark interior)      │   │  border at rest: 1.5pt cocoa + hard offset
│ │                           │   │  shadow (3,3 @ 22%), the scrapbook chrome
│ │        [ 1.5× ]           │   │  zoom pill: dark glass (over video), keep
│ │     (your moment ♥)       │   │  microcopy pill: dark glass, keep copy
│ │  (⚡)      ◉ shutter      │   │  torch: dark glass 44pt, keep
│ └───────────────────────────┘   │
│  (▣ gallery)  [snap][quick log] │  cream toolbar, see below
└─────────────────────────────────┘
```

- **Border**: idle drops the pink. Rest state = `FoodTheme.Stroke.scrapbook` 1.5pt
  cocoa stroke + hard offset shadow, identical chrome to PolaroidHero, Home, Settings.
  The pink wedge is NOT lost: it becomes the scanning state only (RotatingScanBorder
  swaps to `cameraScanPink` 4pt + white shimmer when `isCapturing`). Rationale: a 5pt
  neon ring at rest on cream shouts; the founder's earlier "uniform hot pink at rest"
  direction predates the cream surround. Fallback if rejected on device QA: keep
  `cameraIdlePink` at rest but thin to 2.5pt. Pink-on-scan is non-negotiable keep.
- **Shutter**: KEEP exactly. 78pt `cameraScanPink` ring (the pink lives here at rest
  now), white 64pt disc, `sticker_camera_lineart` at -4°, 6s breathe, CCW spin during
  scan. This unit is engineering-tuned (pre-warmed haptic, same-frame freeze). Don't touch.
- **In-frame chrome**: torch, zoom pill, microcopy "your moment ♥" all stay dark glass
  inside the frame (they sit over video). The X close MOVES OUT of the frame to the
  cream top bar (top-right, app-standard close), freeing the top-right frame corner.
- **Cherries idle sticker**: KEEP, top-left in frame (≤2 stickers per screen rule: cherries
  + camera-lineart-on-shutter = exactly 2).
- **Bottom toolbar (cream now)**:
  - gallery button: 44pt circle, bgElevated fill + divider hairline, cocoa
    `photo.on.rectangle.angled` glyph (thin mark per clean-luxury memo).
  - mode chips: BreathworkIntro chip register. Selected = textPrimary (cocoa) fill,
    bgPrimary label; unselected = bgElevated fill + divider hairline, textPrimary label.
    DMSans-SemiBold 14, height 38. **Drop the 📷 / ✍ emoji** (onboarding v4 kill-list:
    no emoji). Labels stay "snap" / "quick log".
  - kill the dark `.ultraThinMaterial` outer capsule; chips sit bare on cream.
- Permission-denied placeholder: copy stays white (it renders inside the dark frame). Keep.

## 2. Analyzing state (in-frame, no separate screen)

Analyzing correctly happens inside the viewfinder. No new screen. On cream it reads:

```
│ ┌───────────────────────────┐   │  border: cameraScanPink 4pt + white shimmer (KEEP)
│ │   FROZEN PHOTO            │   │  pink scan line sweep (KEEP, untouched)
│ │  ───────────────          │   │  ScanLabelRotator pill: dark glass over photo (KEEP)
│ │  (looking at your plate)  │   │
│ │         ◉ spinning        │   │  shutter spins CCW vs border CW parallax (KEEP)
│ └───────────────────────────┘   │
│   (▣ 35%)   [✦ scanning ♥]      │  scanning pill on cream: KEEP accent-rose fill,
└─────────────────────────────────┘  white text, breathe 1.4s. Pops harder on cream.
```

Keep all engineering work: synchronous freeze+haptic+sound, Canvas prewarm, 0.10s
toolbar snap, 0.08s disc snap. Zero motion changes in this phase.

## 3. Pre/post camera phases (no viewfinder excuse: full cream + new register)

These are already cream but speak the OLD register (Fraunces 26-28pt heroes, italic CTA).
Upgrade to her75:

**Consent (FoodAIConsentSheet)**: keep structure (headline / body / scrapbook detail
card / CTA stack). Changes:
- kicker above headline: "before you scan" DMSans-Medium 11, kerning 1.98, textSecondary.
- headline → Jeni Hero Serif 34pt (questionHero register, it has a sub), lineSpacing -17,
  kerning -0.4: roman "before we" + italic "read" + roman "your plate". Drop the
  headline heart (hearts are terminal punctuation on warm copy, not on a disclosure).
- body 15pt + detail card: KEEP verbatim (locked Apple 5.1.2(i) copy).
- CTA → JFContinueButton-equivalent: DMSans-SemiBold 16 on textPrimary capsule, 56pt
  height, label "continue" (NOT "accept ♥", CTAs are functional per the one-CTA system).
  Secondary "not now" text link 14pt textSecondary. Medium haptic on continue.

**First-scan onboarding (FoodOnboardingSheet)**: header → Jeni Hero Serif 34pt with
kicker "make it yours". Section titles stay Fraunces (sub-19pt, below the JHS floor).
Chips restyle to the BreathworkIntro register above. CTA → 56pt cocoa capsule "continue".

**Quick add (QuickAddView)**: header "what'd you eat ♥" → Jeni Hero Serif 28pt
(roman + italic "eat"). Input card + suggestion chips: KEEP (already scrapbook).
Loading overlay: replace `Color.black.opacity(0.4)` scrim with `bgPrimary.opacity(0.88)`
+ cocoa ScanLabelRotator line, light register, no dark takeover.

**Result (both paths)**: in-frame NutritionCarousel for camera path: KEEP (cards are
already cream/white). Cream-toolbar result actions: "log it" cocoa capsule KEEP;
skip + share buttons swap dark glass → bgElevated circle + cocoa glyph (44pt).
CaptureFlowView `.result` phase (quickAdd path): already cream, PolaroidHero hero. Keep.

**Palette violations to fix in the same pass** (hot magenta `Color(red:1.0,0.075,0.94)`
is outside the locked 8 tokens): GalleryConfirmSheet "scan this" + border,
SharePickerSheet share CTA + checkmarks, TerminalErrorSheet "got it ♥",
galleryPreviewActions "use this photo". All → textPrimary capsule CTAs; selection
checkmarks → FoodTheme.accent rose.

## 4. The keep-list (do not flatten)

| keeper | why |
|---|---|
| PolaroidHero develop (1.2s desaturate/blur ease + 0.9s sticker spring) | the brand reveal; the screenshot we're designing |
| pink scan line (ScanningOverlay, #FF7AD9/#FF4FA8 + sin gate) | the "magic line", founder-approved |
| RotatingScanBorder shimmer during scan | the energy beat; scan-only after this pass |
| shutter unit (ring + disc + lineart sticker, breathe, CCW spin) | engineering-tuned, sticker-on-coin idea |
| scanning pill (accent rose + Fraunces italic "scanning" + ♥) | brand voice in the wait state |
| ScanLabelRotator copy + 1.6s cadence | "looking / finding / tallying", anti-clinical |
| transitionBloom rose halo (0.55s, ≤0.22 opacity) | subliminal warmth at handoff |
| tweak pills + TweakSheet corrections | corrections are the moat |
| matchedGeometry photo morph viewfinder → polaroid | continuity, never hard-cut |
| sticker discipline (cherries + camera lineart only) | ≤2 per screen guardrail |
| synchronous freeze/haptic/sound + prewarms | founder lag fixes; regressions forbidden |
| in-frame microcopy "your moment ♥" | identity register over instruction |
| Fraunces italic punch words at 13-16pt | JHS floor is 16pt; micro punch stays Fraunces |

## 5. Transition + haptic map

| hop | motion | haptic |
|---|---|---|
| home → camera (cover) | system cover; camera frame settles with entranceSoft-equivalent (0.42s easeOut, opacity + 12pt y) | none (tap fired on home) |
| consent → onboarding → camera | JFPageTransition-equivalent: 200ms easeIn exit (opacity + 8pt up) / 60ms gap / 350ms easeOut entrance | medium on each continue (CTA-fired) |
| camera ↔ quick add (phase swap) | same page transition (currently a hard switch; fix) | light on chip tap |
| shutter tap → freeze | same-frame freeze + chrome snap (0.10s/0.08s) KEEP | medium impact (pre-warmed) + sound 1108 |
| freeze → analyzing | scan line fade-in 0.12s, border → pink 0.35s crossfade KEEP | none (the tap haptic owns this beat) |
| analyzing → result | in-frame spring (response 0.45, damping 0.82) KEEP + transitionBloom | soft impact on result-land KEEP |
| result → log it → dismiss | bloom + cover dismiss | medium on log it |
| result → skip → live camera | 0.3s easeInOut unfreeze KEEP | light |
| scan fail → banner | banner moves from top + frozen frame releases 0.25s easeOut | warning notification haptic (add; currently silent) |
| polaroid develop (quickAdd result) | KEEP timeline verbatim; reduce-motion snaps | none (visual-only beat) |

Reduce-motion: every entry above falls back to plain opacity, existing gates stay.

## 6. Build order

1. Token adds (divider, textInverse) + cream backdrop + drop `.preferredColorScheme(.dark)`.
2. Toolbar + top-bar restyle (chips, gallery, X relocation, emoji drop).
3. Border rest-state swap to scrapbook chrome (pink stays on scan).
4. Consent / onboarding / quick-add register upgrade (JHS heroes, kickers, cocoa CTAs).
5. Palette-violation sweep (magenta → cocoa/rose) + result-action glyph swap.
6. Phase-swap page transitions + fail-state haptic.

Device QA after 3 and 6: cream surround in low light (does the frame still read as a
viewfinder), scan line visibility on white plates, chip legibility at 320pt width.
