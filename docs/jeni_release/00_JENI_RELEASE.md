# The Jeni release — 1.2.0 (27) · 2026-07-30

The execution release: the same product the founder already signed,
polished as if the same designer had six more months. No redesign, no
new features — brand, palette maturation, one new signature element,
and craftsmanship bugs. This document is the release law + record.

## 1. The brand: JeniFit → Jeni

- **The official identity landed** (founder's spec:
  `docs/jeni_release/identity/Design.pdf`, "Jeni — AI care
  operations · Mark 01"). **The mark is a hand-drawn lowercase j**:
  a dose above, the vessel below, a load-bearing gap between —
  "the distance is the idea." Its law, now encoded in the
  `JeniMark`/`JeniWordmark` header: gap = half the dose; clear space
  = one sphere diameter; never rotate, never mirror, never outline
  (mass, not line); **one colour — ink on ceramic, ceramic on ink**,
  no gradients inside the mark, never rose.
- **The lockup** ("set quietly beside its name"): the mark beside
  Title-case "Jeni" in the rounded utility sans (DM Sans SemiBold).
  One canonical component renders it everywhere: `JeniWordmark`
  (mark height = 1.18 × text size, gap = 0.42 × size; `markOnly:`
  for mark-alone slots) — loader, onboarding bar, external-session
  idle + watermark. An earlier same-day interim ("jeni." serif +
  rose period) was replaced by the official identity within the
  release; no interim ever shipped.
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
- **App icon**: the official matte-ceramic tiles — ink j on ceramic
  (light), ceramic j on deep black (dark), white-mass mask (tinted,
  derived from the official transparent cut). "Matte, never glossy."
  Verified on the springboard as **Jeni**. The clinician site's
  favicon now carries the same mark (family coherence).

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

## 3½. The voice pass (founder re-steer, same release)

The copy evolved with the identity: **clear · calm · confident ·
direct · precise · supportive without being emotional — Apple
Health, not Instagram wellness.** Every sentence must help the user
understand, decide, or act. The sweep was surgical (the v6→v8
register passes had already moved most copy to plain language; the
remaining old-brand layer was decoration):

- **Hearts retired app-wide** (~90 shipping strings + 13 ornament
  glyph views + widget states; zero remain). The sentences beneath
  were already direct — the hearts were bolted on. Rose ornament
  slots became a plain rose dose-dot (the mark's own sphere) or the
  ink JeniMark for seal moments; the live-activity "ready" state
  wears a checkmark. The chat normalizer now strips heart emoji
  from streamed coach replies, so the voice holds regardless of the
  server prompt.
- **Cheer clauses cut**: "· you've got this" (workout rows),
  ", i'll be right here" (paywall footer), "keep going ♥" (winback
  CTA), "she taps in once a day" (reminder subtitle → "one check-in
  a day, at your time"). Crisis/ED care responses keep their human
  warmth — words, not hearts.
- **Affirmation pool speaks product truths** now: "the trend
  matters. the day doesn't." · "steady is a pace." · "it adds up
  quietly." · "built for real days." — the old poetics ("you are
  becoming her", "soft is strong", "she is already in you")
  retired with the brand.
- **Kept deliberately**: lowercase casual (calm, not cute, on the
  new paper), italic punch words (typographic identity), the verb
  law, anti-shame framing, the letter register (signature now
  "— jeni"), and OV5's intake vocabulary (audited clean — "food is
  love" is her answer option, not brand cheer).
- Legacy v4.5 onboarding (gated behind `--onboarding-v4`) was left
  as-is; the JeniMethod lesson CONTENT (42 CBT lessons) is
  editorial material, already plain-toned — named as the follow-up
  surface if the founder wants a content-level pass.

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
