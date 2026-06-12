# The It-Girl Illustration System

Canonical reference for every illustrated surface in onboarding (and the
pattern any future surface should follow). Built across 12 founder-QA
rounds, 2026-06-11/12. Supersedes the AI-3D-sticker era and the
canvas-background photo-card era. Companion to `docs/THEME.md` (palette,
type, spacing) and `docs/art_direction_synthesis_2026_06_10.md`
(Direction A guardrails, amended for Grok editorial cutouts).

The register in one line: **real-photo-style editorial cutouts with true
alpha, floating directly on the cream canvas, pinterest it-girl styling,
one subject per screen.**

---

## 1. What an illustration is here

- A **cutout**, never a photo card. No background rectangle, no rounded
  frame, no mat. The cream (`Palette.bgPrimary` / `programEraBg`) is the
  paper; the subject is adhered to it.
- **One subject per screen.** A girl, an object, a plate. Clusters and
  collages flattened every screen they touched; the single subject is
  the luxury read.
- **It-girl styling**: shot-on-film warmth, quiet luxury, the objects
  this cohort screenshots onto mood boards (matcha, claw clips, gold
  hoops, taper candles, bouquets, platform sneakers, scalloped bowls).
- Faces stay obscured on generated images: sunglasses, from behind,
  eyes down, phone over face, cropped. Founder-supplied images may show
  faces (his call, his sourcing).

## 2. The generation hierarchy (hard-won)

Reliability tiers, learned by failure. When a screen fights you, move
DOWN a tier instead of re-prompting the same idea.

| Tier | Subject | Reliability |
|---|---|---|
| 1 | **Single object** (candle, bowl, bouquet, hourglass, tree) | Never fails |
| 2 | **Full body, from behind / three-quarter back** | Works |
| 3 | Shoulders-up bust, face obscured | Works, watch background leak |
| 4 | **Hands holding things** | FAILS. Three attempts, three deformed hands. Do not retry; occlusion tricks ("hand hidden behind phone") only partially help. Switch to tier 1 and let the copy carry the verb. |

Other generation laws:
- Subject at **~2/3 frame height with cream margin** — frame-filling
  subjects leak background through the Vision mask.
- Never prompt "face not visible" on a frontal pose (produces erased
  faces). Use "from behind" or a concrete obscuring device.
- Cropped-by-canvas subjects are fine ONLY if the cropped edge will sit
  flush against a screen edge in layout (see §4).

## 3. Pipeline

```
prompt → Grok Imagine (grok-imagine-image-quality, b64) → raw JPEG
       → /tmp/cutout (Scripts/cutout.swift, Vision foreground mask,
         2.5px erosion kills the halo) → true-alpha PNG
       → Assets.xcassets single-@3x imageset
```

- Scripts: `Scripts/generate_itgirl_set.py` (batch pattern),
  `Scripts/cutout.swift` (compile: `swiftc -O Scripts/cutout.swift -o /tmp/cutout`).
- Raws + cuts live in `generated_illustrations/itgirl_set/{raw,cut}/`
  (gitignored; founder iteration material).
- Style suffix every prompt: editorial photograph, luxury women's
  wellness magazine, pinterest it-girl, shot on film, warm natural
  light, quiet luxury, SOLID FLAT cream background, no surface line,
  no text, no watermark.
- Gemini/nanobanana: dead until the founder enables API billing (the
  key 429s on all image models; AI Pro covers the app, not the API).
- **Founder-supplied PNGs** (roses, chicken plate, plateau woman) wire
  in as-is. Never regenerate over them.
- Asset naming: `onb-itgirl-*` (screen-specific subjects),
  `onb-filler-*` (reusable objects), `onb-profile-*` (marquee busts),
  `onb-cuisine-*` (food cards), `onb-cohort-*` (legacy marquee trio).

## 4. Placement grammar

The teach screens use `educationalScreen(...)` in OnboardingView, which
exposes the full knob set. The rules generalize to any surface:

- **Full subject** → floats bottom-trailing with margin
  (`padding(.trailing, Space.lg)`).
- **Canvas-cropped edge** → that edge must EXIT a screen edge:
  - `accentFlushTrailing: true` (+20pt push) — pre-eat arms era.
  - `accentFlushLeading: true` (−6pt) — chicken plate kisses left.
  - bottom-cropped subjects sit on the bottom edge (286 sneakers).
- **Emerge-from-button**: `accentFlushBottom: true` + `accentOffsetY`
  (positive sinks the subject under the CTA dock, which draws on top) —
  plateau woman, 335pt / x+26 / y+36.
- **Off-center subject in its own canvas** → `accentOffsetX` (roses +90
  to side them right).
- Photos stay axis-aligned; only stickers tilt. No drop shadows on
  cutouts (the marquee circles are the exception: framed avatars get
  white 2.5pt rings + soft shadow).
- Size band: 250–400pt for hero accents; never overlap the body copy
  (the 400pt-into-the-text era lasted one screenshot).

## 5. Current surface inventory (post round 12)

| Screen | Asset | Treatment |
|---|---|---|
| Welcome | live SwiftUI device mock (plan/camera/steps cycler, 2.6s) | not an illustration; cutout thumbs inside rows |
| Launch splash | `onb-identity-powerful` | bottom bleed, type underneath, "this is your *that girl* era." |
| 230 built for real life | `onb-filler-roses` (founder PNG) | 380pt, sided right (+90) |
| 283 cohort | 12× circular avatars (`onb-cohort-*` + `onb-profile-*`) | 64/72pt circles, conveyor: new woman enters right every 1.6s |
| 166 pre-eat | `onb-itgirl-preeat` (founder chicken PNG) | 300pt, flush LEFT edge |
| 286 realistic target | `onb-movement-sneakers` (legs-up v2) | flush bottom edge |
| 8/140 identity grid | `onb-identity-*` ×5 | photo cards, fit-mode, bottom-aligned |
| 169 cuisine | `onb-cuisine-*` ×6 | photo multi grid |
| 171/172/173 psych | water / hoodie / stretch girls | centered above statement, ≤290pt |
| 234 plateau | `onb-itgirl-plateau` (founder PNG) | 335pt, emerges from continue button |
| first week (reveal) | `onb-itgirl-firstweek` | fills below the day strip |
| trial promise | `onb-itgirl-promise` (tea girl) | 250pt float, no card |
| Unwired bench | cactus, olive tree, anthurium, hourglass, candle, matcha, books, bracelets, tumbler, journal, bouquet(gen) | `onb-filler-*`, ready to slot |

## 6. Motion language

- `StaggeredReveal` — every option row cascades in 0.06s apart
  (`Motion.cascadeTight`), 0.18s base delay. This is THE entrance for
  list screens; the reveal sequence's choreography is the same voice.
- Conveyors/cyclers: marquee 1.6s, welcome demo 2.6s, both
  `Motion.gentleSpring` / `Motion.crossFade`, both reduce-motion gated
  (hold first state).
- Splash: composition complete at frame 0; one settle (y+10, scale
  1.015 → rest); min dwell max(1.8s, bootstrap); 0.45s crossFade out.
- Notification mock: Apple-banner drop-in (spring from −72pt, soft
  haptic on land).
- Reduce-motion: every animation above snaps to its end state.

## 7. Copy laws that touch illustration

- The illustration never carries text. No text in generated images,
  ever (also: generation can't spell).
- When an illustration replaces a literal scene (hands snapping food),
  the COPY carries the verb and the image carries the mood.
- No em-dashes, no double hyphens, lowercase casual, one italic punch
  word per line, banned vocabulary per the post-Ozempic list.

## 8. Adding a new illustrated screen — checklist

1. Pick the subject at the highest reliable tier (§2). Single object
   unless the screen truly needs a person.
2. Generate via the batch-script pattern; cut with /tmp/cutout; check
   edges at full res (halo, leaked background, canvas crops).
3. Wire as single-@3x imageset, `onb-` prefix.
4. Place by the grammar (§4): full subject floats; cropped edge exits a
   screen edge; never into the body copy.
5. Founder eyeballs on device. Expect 1-2 taste iterations; keep each a
   one-knob change.
