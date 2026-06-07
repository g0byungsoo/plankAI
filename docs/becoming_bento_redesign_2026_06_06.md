# Becoming sharable-card bento redesign

**Date:** 2026-06-06 (founder feedback round 6)
**Trigger:** Founder reviewed the just-shipped compact Becoming and pushed back hard:
> "becoming screen looks so empty now. i was envisioning compacted card style (that's sharable) with cute charts and metrics that matter in this app in one snapshot ... and the screen lost jenifit theme with pink card design entirely."

2 expert briefs spawned: **WL shareable-card data-viz designer** + **Gen-Z women WL user researcher**.

---

## The user-research verdict (most important)

**What this cohort ACTUALLY opens Becoming for** (ranked by emotional weight):
1. **Cumulative weight delta since started** — NOT today's number. Today's 142.4 triggers bad-scale-day anxiety. She wants "down 3.2 since I started."
2. **Trend direction last 7-14 days** — am I still going down or did I plateau?
3. **Goal-distance / projection** — when will I get there?
4. **Identity affirmation tied to her own onboarding answer** — "becoming *powerful*" if she answered Q140 powerful
5. **Last workout / recency proof** — not "you did 7 sessions" but "you showed up Tuesday"

**What she SHARES to her story:**
1. NSV milestones — jeans button, mirror, ring fits (NOT weight numbers)
2. Identity affirmation card — "becoming powerful, day 47" screenshot-perfect
3. Trend graph with *down* slope visible (no absolute numbers exposed)
4. Milestone day counts — "60 days" beats "down 6 lb" 2:1
5. **Never shared:** absolute weight, BMI, calorie totals, projected goal date (too revealing of starting point)

**What she AVOIDS:**
1. BMI (clinical shame trigger)
2. Today's raw weight digit on bad scale day
3. Calorie deficit framing
4. Steps leaderboards / social comparison
5. Before/after photo prompts on default dashboard

**The honest answer:** "She opens Becoming to confirm she's *still going down* and that *the version of herself she's becoming is real*. The current tab gives her the digit (anxiety on bad days), a sparkline (good — keep), a streak (post-Duolingo fatigued), a plank PR (zero share value, zero emotional weight — she didn't download a WL app to deadlift her core), and an identity line (correct instinct, wrong placement — buried)."

---

## The data-viz brief — sharable card anatomy

**The shareable card:** 4:5 portrait ratio (Instagram story-native), pastel fill (not white-on-cream — fill carries the brand into the screenshot), serif Fraunces Light numeral, one curated sticker at corner -8° to -12° rotation, italic-Fraunces wordmark bottom-left to anchor identity.

**Cute charts that work for this cohort:**
- **Gradient-filled sparkline + endpoint dot + halo** — weight trend. Soft hill, not stock chart.
- **Dot-bloom (pearl row)** — 7 dots filled/ring for the week. Pearl row reads cute, not progress-bar.
- **Mini-stacked-pills** — 3-5 accentSubtle capsules, current solid jeweledRose. Macarons, not bars.
- **Blob scatter** — organic circles, slightly varied sizes, NOT grid-aligned. Confetti, not data.
- **Ring with sticker center** — accentSubtle ring + flower3D sticker dead-center.

**KILL:** bar charts with axes, line charts with grid, donut charts with legend, ring-with-number-inside (Cal AI's signature).

---

## Synthesis — 6-card bento for Becoming

Combining the user research (what she cares about) with the data-viz brief (how it looks shareable):

### Card 1 — Trend hero (full-width, ~200pt, signature card)
- accentSubtle #F5D5D8 fill, 24pt corners, **1.5pt jeweledRose hairline border**, hard offset shadow (scrapbook chrome BACK)
- **Hero: "down 3.2"** Fraunces Light 56-64pt cocoa-primary (delta-as-hero per user research — NOT absolute weight)
- Subline: "lb since you started ♥" DM Sans 13pt cocoa-secondary
- **Gradient sparkline** at bottom — accentSubtle fill 60% opacity fading + 1.5pt jeweledRose stroke + 6pt jeweledRose endpoint dot + 12pt accentSubtle halo
- **flower3D 36pt** top-right -12° rotation
- **Bottom-left wordmark**: "*becoming* lighter ♥" DM Sans 12pt italic on "becoming"
- Tap reveals absolute weight (founder may want to keep absolute visible by default — open question)

### Card 2 — Streak (left half, 160×160pt, pageIvory fill)
- "23" Fraunces Light 56pt
- "days *showing up*" italic punch 12pt
- **Pearl-row dot-bloom** — 7 dots last 7 days, filled jeweledRose / accentSubtle ring
- **heartGlossy 28pt** top-right +10°

### Card 3 — Plank PR (right half, 160×160pt, cream + jeweledRose hairline)
- "1:00" Fraunces Light 56pt
- "*personal best*" italic 12pt
- **Mini-pills trio** — last 3 holds as horizontal capsules, current solid jeweledRose
- **sparkleGlossy 14pt** top-left -8°

### Card 4 — Goal projection (full-width thin, 140pt, pageIvory)
- "aug 14" Fraunces Light 32pt
- "on pace for *110 lb* ♥" italic punch 12pt
- No chart — date is the visual
- **bowSatin 32pt** top-right +6°

### Card 5 — Identity affirmation (full-width thin, 80pt, accentSubtle fill)
- "becoming *powerful*, day 47 ♥" italic on "powerful"
- One line, no chart, no chrome beyond fill
- This is the share-card asset the cohort actually wants

### Card 6 — "more depth ↗" link strip (~32pt)
- Demoted to a single text link
- Routes to depth sheet (barriers / plank curve / sessions / NSV)

**Total: ~600-720pt.** Slightly over single-viewport for iPhone Pro 6.1" — acceptable since each card is screenshot-targeted and a single scroll-paw reveals all.

---

## Open decisions for founder

1. **Hero numeral — delta-as-hero ("down 3.2") or absolute weight ("117.4")?** User research strongly says delta. But founder may have brand-conviction reason to keep absolute. Big call.
2. **Trend hero card chrome — bring back the scrapbook chrome** (24pt corners + 1.5pt jeweledRose border + hard offset shadow)? Previously stripped, now data viz brief says it's the JeniFit visual moat.
3. **NSV journal entry point — build now or defer?** User researcher said this is the #1 missing share asset. Net-new module, bigger build.
4. **Identity affirmation card promotion** — currently buried as a single bottom line, brief says promote to its own card with sticker + share-worthiness.
