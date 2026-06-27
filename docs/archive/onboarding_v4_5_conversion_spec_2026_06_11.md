# Onboarding v4.5 — conversion + her75 design rebuild (2026-06-11)

Merges: v4 rebuild plan (R3-R5 remaining) + fresh conversion synthesis
(Cal AI × BetterMe dark-magic audit) + data-wiring audit + founder's
her75 reference set (30 screenshots). One coherent edit, not five.

## What the research changed

Already shipped in v3 (agent flagged "missing" but they exist — keep):
reciprocity beat (282), chapter IA + eyebrow, mid-flow Apple Health
(285), sunk-cost Q (168), attribution (100), consent (284), downsell.

Net-new conversion mechanics to build (ranked by US-gap impact):
1. **Live date math on pace selector (167)** — "around august 14" pill
   recomputed per pace from ProgramGoalCalculator. Cal AI calai13-15.
2. **Dynamic goal-weight reframe (inline on 133)** — benefit-stack card
   states: too-low / on-pace / ambitious. BetterMe 24-26, anti-shame
   vocabulary (no "47.5%" drama).
3. **Realistic-target reframe (NEW case 286)** — after 133, cited
   (Hollis 2008 / Wing & Phelan), effort-down framing.
4. **Notification pre-prime (upgrade case 11)** — mockup notification
   card preview → real dialog. ~+34% allow (Singular).
5. **Trial-promise commit beat (NEW case 287)** — last screen before
   paywall: bell + "we remind you before anything renews" + no-payment-
   today line. TrialEndNotificationService already exists; make the
   promise visible. −22% refunds, +10-14% trial start.
6. **Quantified plan reveal (21 restyle)** — day-one card (her75-3
   register) + 4-5 rails each carrying a real number + date pill +
   "sources" sheet with REAL citations (we actually have them).
7. **Loader = luxury labor illusion (restyle, not gut)** — her75 chrome
   (Didone hero + hairline bar, silence) BUT keep 15-20s + rotating
   personalized sub-line + ATT at ~30%. Conversion agent is right that
   v4's "NOTHING else" plan deleted a proven S-tier lever; her75
   register and labor illusion are compatible.

NOT copied (brand locks): fabricated counts/laurels, auto rating sheet
mid-flow, scale-shame decimals, ED-adjacent teases, body imagery on
screen 1.

## R3 cuts (founder-locked, v4 plan §D)

Cut from flow: 110 (bodyFocus), 2 (experience), 25 (session length),
17 (commit days). Case 8 body REPLACED with movement-baseline Q:
"how does movement fit your life right now?" → `onb_v4_movement_baseline`
(barely / walks / regular_ish / very_active) + derived mirror writes to
`onboardingActivityLevel` + `userExperience` so every downstream consumer
(ProgramSetupSubflow:63-66, WorkoutGenerator, AppSync) keeps reading
valid values. Old columns untouched. NO Supabase schema change.

## R4 kill list (v4 plan §E, confirmed)

- Dividers 6→3: 200 "your story" / 280 "the numbers" / 205 "almost
  yours" — single Didone line, no PART label, no supporting line.
  Cut 203 + 281 from flow. Keep 282 (reciprocity) + 283 (cohort).
- Teach beats: merge 230+231 into one; cut 233 (hormonal Q covers it);
  keep 234 plateau (sets up reveal value) + 166 food wedge.
- Psychometrics 171-173: statement-only center, two docked pills.
- Loader: per mechanic 7 above. "ready ♥" → "ready." Didone.
- Method preview 250: kill AI portrait → typographic 5-row card.
- Plan reveal 21: per mechanic 6.

## Dead-field wiring (data-provenance wins, zero new questions)

- fears (171-173 flags) → paywall closing line variant (cohort-tuned).
- priorWin (159) → plan reveal rail copy ("we lean into what worked").
- stress (155) → already narrated by loader; add to reveal rail line.

## her75 visual language (from founder's 30-screenshot set)

- Strikethrough non-selected options after pick (attribution screen
  micro-delight, IMG_6256/6257 pattern) — case 100 + 168.
- Ruler-tick sliders already match her75's D-75 picker ✓.
- Photo cards (2-col, radio chip) for identity Q 140 — Grok cutouts.
- Edge-bleed transparent-look cutouts: generated on EXACT cream
  #FDF6F4 so they read as cutouts on our background (her75 technique,
  white-on-white).
- Day-one card: white, shadow-only, serif "day one" masthead.
- Line-cascade + haptic per line on every 2+ line hero.

## Illustrations (Grok Imagine, GROK_IMAGINE_API_KEY)

New script `Scripts/generate_her75_onboarding_set.sh`. Luxury-magazine
editorial, faceless (shoulder-down / behind / arm-over-face / sunglasses),
warm natural light, film grain, cream #FDF6F4 flat background, NO text.
Set: welcome ×3 (stretch pose, matcha, journal), movement ×1 (sneakers/
jump-rope bottom bleed), identity ×5 (per Q140 option), cohort ×3
(round-crop faceless portraits), reveal backdrop ×1, paywall ×4.
Direction A guardrail amendment (founder-directed 2026-06-11): Grok
editorial cutouts authorized; faces stay obscured.

## Out of scope (unchanged, locked)

Pricing/tiers/downsell. Paywall structure (single-screen projection
hero) — typography + photo-accent + fear-cohort closing line only.
Supabase schema. Post-paywall app surfaces.

## Order of work

1. R3 cuts + movement baseline + flow reorder + new 286/287 cases
2. R4 restyles + loader + reveal quantified rails
3. Conversion upgrades on 133/167/11 + strikethrough delight
4. Grok set generation + asset wiring
5. Motion/haptic pass (cascade audit) + Metal sheen on day-one card
6. Build → sim walk → screenshots
