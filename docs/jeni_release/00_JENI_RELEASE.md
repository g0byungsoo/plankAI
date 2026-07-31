# The Jeni release — 1.2.0 (27) · 2026-07-30

The execution release: the same product the founder already signed,
polished as if the same designer had six more months. No redesign, no
new features — brand, palette maturation, one new signature element,
and craftsmanship bugs. This document is the release law + record.

## 1. The brand: JeniFit → Jeni

- **The wordmark is now "jeni."** — lowercase serif "jeni" closed by
  a rose terminal period. The middot separator died with "fit"; the
  rose full-stop is the brand's quiet punctuation (the same restraint
  family as terminal hearts, and the same signature the clinician
  product wears as "jeni care."). One canonical component renders it
  everywhere: `JeniWordmark` (display register = Jeni Hero Serif;
  micro register = Fraunces SemiBold + 0.3 kerning) — loader,
  onboarding bar, external-session idle + watermark, lesson share
  watermark.
- **On-device name**: CFBundleDisplayName = "Jeni" (app + widget
  gallery). Every user-visible "jenifit" copy line became "jeni"
  (settings plan/version lines, "the jeni method", the iOS Settings
  path line, steps/health-access lines, playlist label, safety line,
  migration moment, notification-preview a11y label, live activity).
- **Identifiers deliberately unchanged** (they are plumbing, not
  brand): bundle id `com.bk.plankAI`, `jenifit://` scheme,
  `jenifit.app` URLs + `support@jenifit.app`, RevenueCat product ids
  `jenifit_*`, protocol id `jenifit.default`, stored `musicSource`
  value, target/folder names. The App Store product-page rename is a
  founder act at submission (ASC metadata; the existing v1.2+
  bundle-id plan is untouched by this release).
- **App icon**: interim on-system icon generated from the brand serif
  — ink "jeni." on warm paper (light), paper-on-ink (dark), white
  mask (tinted). **The founder's official logo file
  ("Jeni Identity.dc.html", claude.ai design share) could not be
  fetched from this session** (403 + no Chrome extension); when the
  founder lands it in the repo, the icon + `JeniWordmark` are the two
  swap points.

## 2. The palette maturation (pink-first → paper + ink)

Same warmth, quieter ground. All in `Tokens.swift` (+ FoodTheme
mirror; pins updated):

| token | was | is |
|---|---|---|
| bgPrimary | #FDF6F4 pink-cream | **#FCFAF7 warm paper white** |
| bgElevated | #FFFAF8 | **#FFFFFF** |
| textPrimary / bgInverse / cocoa scale | #3D2A2A | **#2A1F1E deep warm ink** |
| textSecondary | #7B5959 | **#6E5451** |
| divider | #EFE0DC | #EDE7E2 |
| pageIvory | #F8F0EC | #F8F4EF |
| LuxuryCard gradient | #FFFAF8→#FBF2EE | #FFFFFF→#FBF7F3 |
| PlankShadow rose alpha | 0.10 | 0.08 |
| LaunchBackground | #EFB9CF pink | **#FCFAF7 = bgPrimary** |

Unchanged on purpose: accent rose #C4677A, accentSubtle, jeweledRose,
state colors, sticky pastels, every typography/motion/radius token —
warmth now lives in the rose accent, the stickers, and the
photography, not in a pink field. Launch → loader → app is one
continuous paper (verified by pixel: #FCFAF7 at 0.4s/0.9s/steady;
note: iOS regenerates the launch-screen cache on version update, so
upgrading users get the clean paper on first launch of 1.2.0).

Contrast floors improve across the board (cocoaTertiary ~4.6→~5.4:1;
textSecondary ~5.8→~6.6:1; textPrimary ~12→~15:1). The
TokensContrastTests law holds untouched.

## 3. Border Beam (`JKBorderBeam`) — a signature element

A slow warm highlight traveling the border of a premium surface —
light along the edge of good paper. Design-system law (in the file
header): earned/premium surfaces only; never medication or clinical
surfaces (FR4); one region per screen; peak opacity ≤0.5, ~12% arc,
8-10s per lap; reduce-motion renders a static faint gradient. If the
beam itself is noticed, it is too strong.

Placements this release (restraint over coverage):
1. The paywall's **chosen plan card** — selection light.
2. The **program-ready CTA** — the earned arrival moment.

Verified live by frame-differencing a 6s recording: the arc travels;
at a glance the surface just reads finished.

## 4. Craftsmanship fixes

- Paywall tier rows no longer truncate ("your whole plan · save 8…" /
  "$47.99 per year, to…"): billed lines tightened to the disclosure
  essentials ("$49.99 per year" — "today" already lives on the CTA),
  and the sub claims its ideal width (it is always narrower than the
  fixed title row). Verified against live RevenueCat pricing.
- Yearly renewal line disambiguated: "renews jul 30" (always today's
  month-day for an annual plan) → "renews jul 30, 2027".

## 5. Verified (this session, on-sim)

- 396/396 unit tests with the new palette (contrast floors, voice
  pins, FoodTheme parity).
- Full v5 onboarding walker leg green (new-customer funnel to the
  wall) under the new system; live RevenueCat offerings render (the
  purchase surface reaches Apple's sheet; sandbox purchase completion
  remains TestFlight territory per house posture).
- Core in-app flows + settings walker legs green (existing-customer
  navigation).
- Launch continuity by pixel; paywall/wall, onboarding welcome +
  beats, daily Home (evening act), chat, S4 reconciliation sheet
  (clinical register intact, beam-free by law), loader brand moment.
- Border beam motion verified by frame differencing.

## 6. Founder follow-ups

1. **The official Jeni logo/identity file** — unreachable from this
   session; hand it over (repo file, or enable the Claude Chrome
   extension) and the interim icon + wordmark swap in minutes.
2. App Store metadata rename (JeniFit → Jeni) + subtitle/keywords at
   1.2.0 submission; screenshots need recapturing on the new system.
3. The v1.2+ bundle-id/project rename plan is unchanged and separate.
