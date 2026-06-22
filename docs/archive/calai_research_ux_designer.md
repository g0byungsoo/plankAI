# Cal AI Onboarding — UX/UI Teardown for JeniFit

**Date:** 2026-06-05 · **For:** JeniFit (v1.0.7+ onboarding) · **Author:** UX/UI designer research agent (Gen-Z women iOS apps, visual + interaction lens). Research only — no code changes.

---

## 0. Framing

This brief looks at Cal AI's 43-screen onboarding strictly through a **visual + interaction** lens — typography, color, spacing, widget choice, motion, button placement. Question content, weight-loss expertise, pricing mechanics, and cultural fit are scoped to the other agents.

The lens I'm applying: which of Cal AI's visual choices are **earning the conversion** for a TikTok-acquired Gen-Z calorie-tracker cohort, and which of those choices JeniFit should adopt *without dissolving its brand chrome* — italic-Fraunces punch words, lowercase casual copy, hearts ♥, coquette sticker scatter, cocoa CTA pills, scrapbook borders, hard offset shadow, "becoming" verbal motif. JeniFit's design north star is **clean + luxury layered over coquette warmth** (Chanel/Tiffany composition, not Cal AI's clinical sterility). Visual richness research lock is also non-negotiable: layer restraint *onto* the brand, never replace it.

---

## 1. Visual system teardown

**Typography.** Cal AI uses a single sans-serif throughout — Inter or SF Pro (the marks are indistinguishable at screenshot resolution; the round-stem g and double-storey a read Inter). One family, three weights — Bold for headlines (~34pt), Semibold for option labels (~17pt), Regular for subheads and captions (~15pt). Zero serif anywhere. Zero italics anywhere. The entire system is one humanist sans in a near-black-on-white frame. That single-family-three-weight discipline is what makes Cal AI feel "fast and modern" — there is nothing else for the eye to parse.

**Headline-to-subhead ratio** is dramatic. Headlines (calai2 "Choose your Gender", calai10 "What is your goal?", calai18 "What's stopping you from reaching your goals?") sit at ~34pt Bold with tight leading (~38pt line-height). Subheads (calai2 "This will be used to calibrate your custom plan") sit at ~15pt Regular in textSecondary grey, with generous ~20pt line-height. The ratio is roughly **2.2:1** — large enough that the headline is the only thing the eye sees, the subhead is acknowledged as a footnote. Compare to JeniFit's onboarding where italic-Fraunces SemiBold sits at 30–34pt and subhead body sits at ~17pt — JeniFit's ratio is closer to 2:1, but the *serif vs. serif* contrast makes both feel weighted equally. Cal AI's sans-vs-sans treatment lets the headline punch harder.

**Color system.** Cal AI is a four-color system: near-black (#0F0F12 or thereabouts) for headlines and selected pills + CTAs; pure white (#FFFFFF) for surface; pale lavender-grey (~#F5F4F8) for unselected option pills and "this will be used to calibrate" subhead background tint; warm gold-orange accent (#E8A268-ish) reserved exclusively for *progress, achievement, callouts* — the highlighted "5.3 kg" on calai12, the "4 months" pill on calai13, the wreath laurels around "4.8 ★" on calai27, the highlighted animal-pace icon on calai13/14/15. Red (#E04E4E) is the **danger signal** — appears only on calai15's "Fast loss can cause fatigue or loose skin" warning. Pink/coral pastel (calai22, calai31) is reserved for the trust/gratitude haloed circle behind the hand-clasp / finger-heart illustrations. That's it. **No gradients except progress bars (calai34/35).** No drop shadows. No textures. Pure flat.

JeniFit's palette (cream `#FDF6F4`, dusty rose accent `#C4677A`, pale pink subtle `#F5D5D8`, cocoa CTAs) is richer by design — and is the brand. The lesson from Cal AI is not "go white." It's **role discipline**: every color has one job, no color does two jobs. JeniFit's accentSubtle pink already does this well — but the cocoa pill does both "primary CTA" and "selected pill" duty in places, which can blur.

**White space.** Cal AI is **generous**. Headlines start ~120pt from top after a 60pt status-bar reserve. Option pills sit ~280–320pt from top — there's a full vertical third of empty space between the headline+subhead block and the option stack on calai10, calai9, calai41. Bottom CTA reserves ~120pt of safe-area at the floor. The screens feel **calm**. There is never more than 4–6 interactive elements visible at once.

**Tap targets.** Option pills are full-width minus 30pt horizontal margin, **70pt tall** with 16pt internal corner radius. The Continue CTA is full-width minus 30pt margin, **56pt tall**, fully rounded capsule (28pt radius). Back chevron sits in a **44pt circle pill** (~#F2F1F6 surface) top-left at status-bar-bottom + 16pt. All HIG-compliant, all generous. The progress bar is **~6pt thick**, full-width minus chevron + 16pt gap, rounded ends.

**Corner radius system.** Three levels: 12pt for inline mini-cards (calai13's "You will reach your goal" callout), 16pt for option pills + result cards (calai17's chart card, calai25's calorie tiles), 28pt-ish capsules for CTAs and the chevron pill. The **same 16pt corner** is used everywhere a pill needs to read as "tappable." JeniFit's 24pt scrapbook + 16pt CTA is busier than Cal AI's grammar — but JeniFit's scrapbook border *is* the brand signal, so the discipline is "match Cal AI's hierarchy logic, not Cal AI's specific values."

---

## 2. Interaction widgets — what works

**Animal-icon pace slider (calai13/14/15).** Three icons across the slider track — sloth, hamster, panther — with the selected one tinting to the gold accent and labelling below. Drag the thumb, the icon under it lights up, the projected timeline below recomputes ("4 months," "2 months," "25 days"), and a context callout card updates ("Going slow means a gentler and more sustainable daily calorie goal" / "This is the most balanced pace, motivating and ideal for most users" / "This pace moves quickly, staying consistent will be key"). At the fast end, a red warning chip appears: "⚠ Fast loss can cause fatigue or loose skin." **Why it works**: it converts an abstract slider into a concrete identity choice; the animal metaphor smuggles in personality without breaking the clinical visual register; the live result callout converts a question into a preview. **Adopt for JeniFit when**: any "how intense / how fast / how committed" question. Replace the animals with brand-aligned coquette glyphs — slow bow / steady heart / determined flame — but **keep the live-result callout pattern**. **Conflicts with brand when**: the red-warning chip is jarring. JeniFit should ship the same warning in italic-Fraunces "the body needs rest at this pace ♥" register, not a clinical red triangle.

**Wheel pickers (calai6 date, calai7 height & weight).** Triple-column wheel for date; dual-column with imperial/metric toggle pill above for height/weight. The **selected row is highlighted with a 24pt-radius pill** in pale lavender behind the centered text, while neighbors fade to ~30% opacity. The wheel has a 4–5 row visible window. **Why it works**: feels native iOS, fast to flick, low cognitive cost vs. text-entry. **Adopt for JeniFit when**: date-of-birth and weight pickers (note: JeniFit already uses wheel for activity slider at line 2487; verify per memory `feedback_swiftui_picker_wheel` — onChange leakage is a known SwiftUI freeze trap, so the implementation has to mirror state on Continue, not per-tick). **Conflicts with brand when**: never — the pill highlight can simply use Palette.accentSubtle instead of Cal AI's lavender. Brand-safe.

**Check-pill multi-select (calai18 barriers, calai19 diet, calai20 accomplish).** Tall pills with a leading icon glyph (calendar, hamburger, scale, etc.) in a circular surface, label centered-left, no trailing checkmark — selection is communicated entirely by the pill flipping to **black fill + white text + white-circle icon glyph**. **Why it works**: zero ambiguity about selected state; the inverted pill is impossible to misread; no trailing checkbox to add visual noise. **Adopt for JeniFit when**: every multi-select onboarding question. JeniFit currently uses chips with check glyphs in some places — flip to "selected = cocoa fill + cream text + cream-circle glyph" matches both Cal AI's clarity and JeniFit's chrome. **Conflicts with brand when**: never — this is purely an interaction grammar swap.

**Big binary toggles (calai5 yes/no apps tried, calai9 yes/no nutritionist, calai24 yes/no rollover, calai25 add-back).** Two pills with a thumb-up/thumb-down (calai5) or check/X (calai9) glyph in the same circular surface treatment. Selected state again = inverted black fill. **Why it works**: zero hesitation, no third option to distract. **Adopt for JeniFit when**: any pure yes/no. Note calai25 puts the two pills **side-by-side** at the bottom in place of a single Continue — this is the **answer-as-CTA** pattern where the user's choice IS the continue action. Powerful for binary moments. **Conflicts with brand when**: JeniFit uses italic-Fraunces "yes / no thanks ♥" register elsewhere and shouldn't fully retreat to icon-only.

**Ruler/tick weight slider (calai11 desired weight).** A horizontal ruler with major + minor ticks, centered current value displayed huge ("88.7 kg") above, the *shaded right half* visually marking "where you came from" so the user sees magnitude of the choice. **Why it works**: makes "set your goal" tactile and gives instant magnitude feedback. **Adopt for JeniFit when**: desired weight selection. **Conflicts with brand when**: never — JeniFit can re-skin ticks with hand-drawn doodle marks to brand-align without losing the gesture.

**Full-width Continue CTA pinned to bottom (every screen).** Cocoa pill, ~56pt tall, ~28pt capsule radius, ~30pt horizontal margin, **never a secondary button next to it** (calai22's "Skip" is rendered as a *text link below* the CTA, not a sibling button). Disabled state = ~30% opacity grey pill (calai26 paywall before TAT prompt resolves). **Why it works**: the user's eye never has to hunt. One primary action, always in the same place, always the same shape. **Adopt for JeniFit when**: every onboarding screen. JeniFit's `ctaBtn` already uses 56pt height in cocoa (OnboardingView.swift line 7923–7943) — good. But JeniFit uses a 16pt rounded-rect, not a capsule. **Recommendation**: keep 16pt rounded-rect (matches scrapbook chrome), but enforce the "single primary CTA, always bottom" rule even on the welcome screen.

**Thin top progress bar (every screen).** ~6pt thick, full-width minus chevron, filled cocoa from left, lavender-grey empty. **Always visible, always advancing.** The user gets a constant sense of "how much is left." **Adopt for JeniFit when**: every onboarding screen post-welcome. JeniFit's existing progress logic already keys off flowOrder; the visual treatment can simply match Cal AI's thinness — but in cocoa over accentSubtle, not lavender.

**Back chevron always top-left (every screen).** Small chevron in a 44pt circle, identical position every screen. Zero ambiguity, zero hidden behavior. **Adopt for JeniFit when**: every screen. JeniFit should match.

---

## 3. Pacing + screen rhythm

Cal AI ships **three loading screens** stacked: 67% "Estimating your metabolic age…" (calai33), 91% "Finalizing results…" (calai34), 97% "Finalizing results…" (calai35) — followed by the plan reveal at calai36. Below the percent number is a thin gradient progress bar (red→purple→blue, the only gradient in the app) and a checkpoint list ("Daily recommendation for: Calories ✓ / Carbs ✓ / Protein ✓ / Fats / Health Score") where checkmarks **fill in sequentially** as the percent advances.

**Why three?** This is the Noom labor-illusion pattern (Carmel & Norton 2011) applied with restraint. One loader feels arbitrary. Three loaders feel like *real work is happening*. The checkpoint list at the bottom converts time into evidence — the user watches deliverables materialize. The micro-copy under each percent ("Estimating your metabolic age" → "Finalizing results") narrates the work so the perceived effort transfers to perceived value. The aggregate dwell time is probably 6–10 seconds. Noom famously sits at 30+ seconds; Cal AI dialed this down to a tolerable luxury.

**JeniFit current state.** Per onboarding v2 plan (memory `project_onboarding_v2_plan`), JeniFit has an "analyzing your relationship with food…" loader proposed at 87% with cuisine/eating-window line items. Single-screen.

**Recommendations for JeniFit.**

1. **Ship three milestone loaders, not one.** Match Cal AI's 67% → 91% → 97% cadence, ~3 seconds per beat. Total dwell 9 seconds.
2. **Keep the checkpoint-list metaphor but cast it in JeniFit voice.** Instead of "Calories ✓ / Carbs ✓," use "your eating story ♥ / cuisine match / calorie window / movement floor / *becoming* arc." Sequential check-fills.
3. **Replace Cal AI's red-purple-blue gradient with JeniFit's accent → cocoa gradient.** Cal AI's gradient is the only place in their app that uses gradient — JeniFit can use the same restraint logic.
4. **NO percent for the brand voice screens** — only on the loader trio. Percent feels clinical; reserve it for the moment when clinical precision earns trust.

---

## 4. Continue button affordance + progress bar

Cal AI is **religiously consistent**: every screen has exactly one bottom-anchored cocoa-capsule Continue, exactly one top-anchored thin progress bar, exactly one top-left circular back chevron. The user develops instant muscle memory by screen 5. Variation only appears at three liminal moments: the plan reveal (calai36) where Continue becomes "Let's get started!", the auth screen (calai38) where three identity buttons replace the single CTA, and the paywall (calai41) where the CTA becomes "Start My 3-Day Free Trial."

**Cost to brand voice if JeniFit adopts.** JeniFit's onboarding currently has more chrome variation — different welcome treatment, different reshape/celebration screens, different name-entry screens, different coach-selector. Some of this variation is brand load-bearing (italic-Fraunces headline + sticker scatter + video hero on welcome IS the brand per `feedback_visual_richness_over_restraint`). Some is just inconsistency.

**Recommendation.** Adopt Cal AI's button consistency for **the Q&A spine** (cases that ask single questions and advance) while keeping bespoke chrome for the **set-piece moments** (welcome, reshape, plan reveal, coach selector). The rule: every "user picks an option, then advances" screen uses the identical cocoa-pill + top-progress-bar + top-left-chevron grammar. The set pieces are allowed to break form for emotional reasons but should still respect the bottom-cocoa-CTA invariant.

**Specific:** JeniFit's existing `ctaBtn` helper is the right component. The fix is **eliminate every other CTA variant in the Q&A spine** (anything that calls `Button` inline at lines 2366, 2469, 2579, 2638, 2673, 2713, 2781 — these are bespoke per-case Continue buttons that should route through `ctaBtn`). The progress bar should be the only top chrome on Q&A screens; welcomeTopBar (JeniFit wordmark) stays on the set-piece screens but yields to the progress bar on the Q&A spine.

---

## 5. Headline pattern

Cal AI headlines are **direct question-form, 4–7 words, sentence-case, 34pt sans Bold**. "Choose your Gender" (calai2 — note "Gender" capitalized as proper noun in their grammar). "How many workouts do you do per week?" (calai3). "When were you born?" (calai6). "What is your goal?" (calai10). "How fast do you want to reach your goal?" (calai13). "What's stopping you from reaching your goals?" (calai18). "Do you follow a specific diet?" (calai19). "Be reminded to log meals" (calai29 — declarative, the only non-question). Subheads are factual one-liners: "This will be used to calibrate your custom plan."

**JeniFit's current register.** Italic-Fraunces SemiBold on punch words ("i've started over *so many times*", line 2122), peer-confession voice, lowercase casual. Reads as a friend's text, not a brand promise. Headlines are typically 6–10 words.

**Adapt — don't fully shift.** Cal AI's direct-question headline is correct for the **Q&A spine** because:
- The user is in answer-mode, not feeling-mode.
- A direct question accelerates decisions.
- Sentence-case sans-serif respects the user's time.

But JeniFit's italic-Fraunces is the **single most differentiated brand signal** (memory `feedback_voice_signals`) and dilution kills it.

**Recommendation — register-pair the screens.**

| Screen type | Headline register | Why |
|---|---|---|
| Welcome (case 1, v2) | italic-Fraunces, peer confession | brand identity moment |
| Q&A spine (all single-question cases) | **DM Sans / system semibold, 28–32pt, direct question, sentence-case, lowercase** | Cal AI-speed for answer-mode |
| Set-piece education (form lessons, social proof, founder note) | italic-Fraunces with one accent word | brand voice for emotional load |
| Plan reveal | italic-Fraunces hero ("here's your *becoming* ♥") + Cal AI-style data tiles below | brand+data split |
| Permission asks | italic-Fraunces, peer voice | identity moment |
| Paywall | italic-Fraunces, peer voice | brand-load close |

**Lowercase casual stays everywhere** — Cal AI's "Choose your Gender" becomes JeniFit's "what's your gender" or "tell us about your body." The lock per `feedback_voice_signals` is firm.

This pairing preserves the brand signal while letting the Q&A spine breathe at Cal AI tempo. The italic-Fraunces stays sacred to ~10 set-piece moments instead of being applied to all 50 screens.

---

## 6. Plan reveal moment (calai36 + calai37)

Cal AI's reveal is a two-screen sequence visible by scroll on a single page. **calai36** opens with a confident black checkmark in a 44pt circle, then **"Congratulations / your custom plan is ready!"** as a 34pt three-line Bold sans headline. Below: "You should lose:" subhead, then a pale-lavender pill containing "5.3 kg by May 18" — the date target. Below that: a scrapbook-rounded "Daily recommendation / You can edit this anytime" card containing **four equal-weight square tiles** — Calories (flame icon, "918" in a ring), Carbs (sprout icon, "41g" in a ring), Protein, Fats. **calai37** continues the scroll: Health Score pill with progress bar ("7/10" green bar), then "How to reach your goals" list with 4 cells: "Use health scores to improve your routine / Track your food / Follow your daily calorie recommendation / Balance your carbs, proteins, and fat." Each list cell has a 40pt circular glyph (heart-lightning, avocado, ring, three rings). Bottom CTA: "Let's get started!" in cocoa capsule.

**Why this works.** Cal AI converts a single weight number into **five separate identity proofs** in 90 seconds: (1) calories, (2) macro split, (3) date target, (4) health score, (5) action roadmap. Each proof is a tile, the tiles are visually equal-weight (no "the real answer is calories"), and the roadmap explicitly names how each proof will be used. The user walks away with five things they can talk about, not one.

**JeniFit's current reveal.** Weight curve + (newly added) calorie hero. Two proofs.

**What to adopt.**
1. **Multi-proof tile grid.** JeniFit should ship 4–6 tiles in a 2×2 or 3×2 scrapbook-bordered grid: calorie target, protein floor, plank ritual, *becoming* arc, weight target by date, anchor habits (steps + breath). This is data + identity in equal balance.
2. **Date target pill format.** "5.3 kg by May 18" is concrete, near-future, anchorable. JeniFit should ship "−6 lbs by Aug 14 ♥" in italic-Fraunces with the heart, in an accentSubtle pill.
3. **"How to reach your goals" list.** This is a contract — the user knows what they're signing up for. JeniFit should ship "this is your becoming arc / track what you eat / show up for the 5-min ritual / let the trend speak louder than the daily" with stickers replacing Cal AI's geometric glyphs.

**What conflicts.**
1. **"Congratulations" is brand-flat for JeniFit.** Use italic-Fraunces "here's your *becoming* ♥" or "this is your *next chapter*" — the voice signature.
2. **Health Score 7/10** is a quantified judgment Cal AI gets away with because they're clinical. JeniFit's anti-shame lock means **no score with a denominator** (memory `feedback_food_ux_antishame`). Replace with a non-judgmental anchor: "your starting place" with no number.
3. **"Let's get started!"** is brand-coined-verb territory (memory `feedback_voice_signals`). Use "continue ♥" or "i'm ready" in JeniFit voice.

**Net.** Adopt the multi-tile grid + date target pill + action roadmap. Reject the score + the brand-coined verb + the congratulations frame.

---

## 7. Permission ask choreography

Cal AI primes **every system prompt with a pre-screen**.

- **Apple Health (calai22)**: 4-corner glyph composition (Walking / Running / Yoga / Sleep icons orbiting an Apple Health heart) above headline "Connect to Apple Health" and subhead explaining the value exchange ("Sync your daily activity between Cal AI and the Health app to have the most thorough data"). Bottom: black "Continue" + text-link "Skip."
- **App Tracking Transparency (calai32)**: appears as an iOS system dialog over a half-faded loader screen — Cal AI doesn't pre-prime ATT, it just lets it fire mid-loader so the user reads "21%" through the dialog and feels they're interrupting their own plan generation. Clever conversion lever; ethics-debatable.
- **Notifications (calai29 + calai30)**: pre-prime screen "Be reminded to log meals" + a *mockup of the actual iOS system dialog* with a yellow pointing-finger emoji highlighting "Allow." Then calai30 is the real iOS dialog. This is the **prime-with-preview** pattern and it lifts opt-in 15–25 percentage points (Persuaded.io 2024, OneSignal 2023 benchmarks).

**Why this works.** The pre-prime gives the user the value-exchange before the system dialog gives them the binary decision. Crucially, the pre-prime makes "Allow" the path of least resistance because the user has already mentally committed. The mockup-with-pointer (calai29) is the most aggressive version — it almost guides the tap before the real dialog appears.

**JeniFit's current state.** Notifications scheduled at end of onboarding via `NotificationPermission.scheduleDailyReminder`, with no pre-prime screen. Apple Health prime exists in onboarding v2 plan but isn't shipped yet.

**Adopt the prime-with-preview pattern.**
1. **Notification prime** (in JeniFit voice): "we'll send one gentle nudge a day ♥ / never about the scale" + a mockup iOS notification preview showing "JeniFit · 8:00 AM — *gentle morning* — today's lesson is waiting whenever you are." Pointing-finger emoji is too memey for JeniFit; replace with a subtle hand-drawn doodle arrow.
2. **Apple Health prime** (when steps is configured): 4-corner glyph composition with steps / heart / sleep / mindful-minutes stickers, JeniFit's existing "connect to apple health" copy.
3. **NEVER pre-prime ATT** the Cal AI way (during loader). It's manipulative and TikTok-acquired women 22–35 increasingly recognize and resent the pattern. JeniFit should fire ATT as a discrete screen with honest framing.

**When.** Pre-prime appears **immediately before** the system dialog, in the same screen-flight, with the same back chevron and progress bar — visually continuous with the rest of onboarding so it doesn't feel like an interruption.

---

## 8. Onboarding visual gridwork — 20 rules to adopt

Each rule preserves brand chrome.

1. **Single sans-serif for Q&A spine.** Use DM Sans (already in the project per `welcomeCTA` line 2176) across all single-question cases. Italic-Fraunces reserved for set pieces. *Why*: speed + restraint. *Apply*: Q&A spine cases only.
2. **34pt Bold headline, 15pt Regular subhead, 2.2:1 ratio.** *Why*: the headline is the only thing the eye sees. *Apply*: Q&A spine. Translate to JeniFit values — 30pt DMSans Semibold / 14pt textSecondary.
3. **Full-width 70pt-tall option pills, 16pt corners.** *Why*: HIG-compliant fat tap targets, zero ambiguity. *Apply*: every multi-choice + single-choice question. Use accentSubtle for unselected, cocoa for selected.
4. **Selected pill = inverted (dark fill, cream text, cream-circle glyph).** *Why*: state un-missable. *Apply*: every selection widget. Drop trailing checkmarks.
5. **Leading circular glyph in pill** at ~32pt circle. *Why*: faster scan than text-only. *Apply*: barriers, diet types, sources, accomplishments. Use brand stickers for glyphs where possible.
6. **One primary CTA bottom-anchored, never two side-by-side except for binary answer-as-CTA moments.** *Why*: muscle memory. *Apply*: every screen; route every CTA through `ctaBtn`.
7. **CTA at 56pt tall, full-width minus 30pt.** JeniFit `ctaBtn` already complies (line 7928). *Why*: thumb-zone optimal. *Apply*: don't change.
8. **Thin top progress bar, ~6pt, full-width minus chevron, cocoa over accentSubtle.** *Why*: constant sense of remaining. *Apply*: Q&A spine.
9. **44pt circle back chevron, top-left, every screen.** *Why*: zero hidden behavior. *Apply*: Q&A spine. Use Palette.accentSubtle surface, cocoa chevron stroke.
10. **3 loading screens at ~67% / 91% / 97% with sequential checkpoint-list checkmarks.** *Why*: labor illusion calibrated. *Apply*: post-Q&A, pre-plan-reveal.
11. **Live-update result callout under sliders + wheels.** Cal AI's "You will reach your goal in 4 months" updates with slider drag. *Why*: converts a question into a preview. *Apply*: pace slider, weight slider, calorie slider if any.
12. **Wheel picker selected row highlighted with a pill background.** *Why*: HIG-aligned + readable. *Apply*: DOB + height + weight. Use accentSubtle highlight.
13. **Sentence-case throughout** (Cal AI has minor inconsistencies — "Choose your Gender" — JeniFit should be cleanly lowercase per voice lock). *Why*: voice lock. *Apply*: every headline.
14. **One accent color reserved for "this is the moment" callouts.** Cal AI uses orange-gold. JeniFit's equivalent is the dusty-rose accent — reserve it for the calorie target, the date target, the goal pill. Don't use it elsewhere. *Why*: role discipline.
15. **No drop shadows on Q&A spine, scrapbook shadow only on set-piece cards.** *Why*: the shadow is brand-load for hero moments; using it everywhere flattens the signal. *Apply*: Q&A pills are flat; set-piece cards (welcome, reveal, paywall) keep scrapbook chrome.
16. **Ruler-tick widget for weight goals.** *Why*: tactile + magnitude legible. *Apply*: desired weight question.
17. **Direct-question headlines for spine, italic-Fraunces for set-pieces.** *Why*: register-pair preserves brand. *Apply*: per §5 table.
18. **Animal / glyph-pace slider for pace question** with brand stickers replacing animals. *Why*: identity smuggled into a slider. *Apply*: "how fast" question.
19. **Skip rendered as text link below CTA, never as a sibling button.** Cal AI calai22. *Why*: visual hierarchy = primary action wins. *Apply*: optional screens.
20. **Generous vertical space — minimum 280pt between headline-block and option-stack on simple Q&A screens.** *Why*: calm. *Apply*: every Q&A spine screen. JeniFit currently compresses some onboarding screens; honor this air.

---

## 9. Anti-patterns — 10 Cal AI choices to reject

1. **Clinical pure-white background.** JeniFit's cream `bgPrimary #FDF6F4` is brand. Pure white reads as Cal AI clone. *Reject everywhere.*
2. **All-caps "3 DAYS FREE" badge on calai41/43.** Bro-fitness shouty register. JeniFit lowercase voice lock kills this. *Replace*: "3-day trial · cancel anytime" in lowercase pill.
3. **Confident-clinical headline voice ("This will be used to calibrate your custom plan").** Reads as algorithm-cold. *Replace*: "this helps us build your becoming ♥" or absorb the subhead into a smaller anti-shame caption.
4. **Male / Female / Other binary on calai2.** Insufficient nuance for the cohort. *Replace*: skip-friendly self-ID with cycle-aware follow-up — JeniFit needs hormonal cycle data anyway per memory `project_onboarding_v2_fields`.
5. **"Congratulations" frame on calai36.** Brand-flat. *Replace*: italic-Fraunces "here's your *becoming* ♥."
6. **Health Score 7/10 with denominator.** Quantified judgment. *Replace*: non-judgmental anchor per `feedback_food_ux_antishame`.
7. **Red warning triangle on fast-pace.** Visual shame trigger. *Replace*: italic-Fraunces "the body needs rest at this pace ♥" caption.
8. **Mid-loader ATT prompt on calai32.** Manipulative pattern increasingly resented by cohort. *Replace*: discrete ATT screen with honest framing.
9. **"Let's get started!" CTA copy.** Brand-coined verb territory. *Replace*: "continue ♥" or "i'm ready."
10. **Heavy-emoji touches (calai29 pointing-finger, calai30 pointing-finger).** Reads meme-y, dilutes coquette aesthetic. *Replace*: subtle hand-drawn doodle arrow sticker — sticker scatter is brand-aligned, emoji isn't.

---

## 10. Concrete recommendations — top 15 ranked

Brand-voice column: Yes / No / Adapt. Effort: S (<1 day) / M (1–3 days) / L (3+ days).

| # | Change | Cal AI ref | Brand preserved? | Effort | Expected lift |
|---|---|---|---|---|---|
| 1 | Adopt 70pt-tall full-width option pill grammar across every Q&A spine case; selected = cocoa fill + cream text + cream-circle glyph; unselected = accentSubtle | calai10, 18, 19, 20 | Yes (cocoa/cream are brand) | M | High — selection clarity is a top funnel-leak driver |
| 2 | Add thin 6pt cocoa-on-accentSubtle top progress bar to every Q&A spine screen | every Cal AI screen | Yes | S | Medium-high — perceived-progress lift |
| 3 | Add 44pt-circle back chevron top-left to every Q&A spine screen | every Cal AI screen | Yes | S | Medium — reduces drop-offs from "i can't fix what i picked" anxiety |
| 4 | Ship three milestone loaders (67% / 91% / 97%) with sequential checkpoint-list, JeniFit voice line-items | calai33, 34, 35 | Adapt (replace gradient with cocoa→accent) | M | High — labor illusion converts intent to commitment |
| 5 | Add multi-proof tile grid (5–6 tiles) to plan reveal: calorie target, protein floor, plank ritual, becoming arc, date target, anchor habits | calai36 + calai37 | Yes | L | High — multi-proof = multi-anchor = harder to abandon |
| 6 | Add date-target pill ("−6 lbs by Aug 14 ♥") to plan reveal | calai36 | Yes (italic-Fraunces, heart) | S | Medium |
| 7 | Add "how to reach your goals" action roadmap with 4 cells + brand stickers | calai37 | Yes | M | Medium — explicit contract reduces churn |
| 8 | Ship animal-pace-slider equivalent (brand sticker glyphs: bow / heart / flame) for "how fast" question with live-result callout | calai13, 14, 15 | Adapt | M | Medium-high — identity-as-pace |
| 9 | Adopt ruler-tick widget for desired weight question | calai11 | Yes (re-skin with doodle marks) | M | Medium |
| 10 | Pre-prime notification permission with iOS-style mockup notification + JeniFit voice ("we'll send one gentle nudge a day ♥") before system dialog | calai29 + 30 | Yes | M | High — opt-in lift = retention multiplier |
| 11 | Pre-prime Apple Health (4-corner glyph composition with brand stickers) before system dialog | calai22 | Yes | M | Medium — only when steps/HK is required |
| 12 | Route every Q&A spine CTA through `ctaBtn` to eliminate bespoke per-case Continue buttons (lines 2366/2469/2579/2638/2673/2713/2781) | every Cal AI screen | Yes | S | Low-medium (mainly debt cleanup) but unlocks consistent A/B testing |
| 13 | Register-pair headlines: DM Sans Semibold direct questions for Q&A spine, italic-Fraunces for set-piece moments only | calai2, 10, 18 vs italic-Fraunces welcome | Adapt | M | Medium — preserves brand by *reserving* it |
| 14 | Adopt binary answer-as-CTA pattern (two side-by-side pills replace single Continue) for yes/no questions where the answer IS the advance | calai24, 25 | Yes | S | Low-medium — shaves taps on binary moments |
| 15 | Enforce single-color-role discipline: dusty-rose accent reserved for "this is the moment" callouts (calorie target, date target, goal pill), cocoa for primary CTA + selected state, accentSubtle for unselected pills + subhead surfaces, never blur roles | role discipline visible across all Cal AI screens | Yes | M | Medium — sharpens visual hierarchy across the whole flow |

---

## Cross-references

- §5 register-pair recommendation interacts with memory `feedback_voice_signals` (italic-Fraunces only on punch words). The recommendation is consistent with the lock: by reserving italic-Fraunces for set pieces, the Q&A spine doesn't dilute it.
- §6 plan reveal proposes adding tiles + roadmap; conflicts to surface with the WL-expert agent's calorie-tracker-content recommendations.
- §7 notification pre-prime is the highest-ROI single change; should land in same sprint as the trial-week notification work (memory `project_trial_week_notifications`).
- §9.6 "no Health Score" interacts with `feedback_food_ux_antishame` — confirm with founder before any plan-reveal score lands.
- §8 rule 10 (3-screen loader) overlaps with memory `project_onboarding_v2_plan` single-loader proposal — supersede.
- The full Cal AI screenshots calai38–calai43 (Save your progress → Try Now → trial reminder → 3-day trial paywall → "Unlock to reach your goals" monthly close → tier-locked annual close) are scoped to the monetization agent; visual lens here only — the auth screen on calai38 is **clean restraint done well**: single 34pt headline, three identity buttons (Apple in cocoa pill, Google + Email in cream pills with cream stroke), bottom-anchored vertical stack with generous 60pt+ spacing between buttons. JeniFit's existing auth flow should match this exact composition.
