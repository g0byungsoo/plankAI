# JeniFit Paywall — UX Research Brief v4 (benefits list, the empty-feeling fix)

**Date**: 2026-06-05
**Author**: senior UX research, on commission for founder (Han)
**Status**: targeted brief on a single question — does a benefits list belong on the paywall, and if so, where + what + how. The horizontal-3-tier layout from v3 ships untouched.
**Builds on**: [v1](paywall_research_ux_2026_06_06.md), [v2](paywall_research_ux_v2_2026_06_06.md), [v3](paywall_research_ux_v3_2026_06_06.md).

---

## TL;DR — Executive recommendation

**Yes, ship a benefits list — but reframe the question first.** The right move is not "fill the empty space below Quarterly/Weekly." The right move is to put a **3-row "what's included ♥" benefits block** in the slot **between hero and tier row** (not below tiers), visible **for all three tiers**, with the **trial timeline strip continuing to render only when Annual is selected** below the tier row. This solves the "empty-when-Quarterly-selected" complaint by **moving the variable-height slot to a place where the eye expects narrative** (top of screen, after the headline) rather than a place where the eye expects a finalizing detail (just above CTA). It also adds the value-stack signal that every successful 2026 WL paywall carries (Adapty's audit of fitness paywalls calls a benefits list "near-universal" — [Adapty 2026 designing-effective-paywalls](https://adapty.io/blog/designing-effective-paywalls-for-mobile-apps/)). Three rows, each one **icon + 2-3 word label + 5-7 word voice-locked sub-line**, italic-Fraunces punch word on the label per row (not on a section header — there is **no section header**, per the v3 voice principle that headers redundancy-stack the screen). Include **food rail / calorie tracking as row 3 with a "soon ♥" tag** because (a) it ships in v1.0.7 which is the very next release, (b) Cal AI evidence shows future-feature disclosure on the paywall is conversion-positive when honest, and (c) hiding it would force a paywall redesign in 4 weeks. Row stack: **(1) full workouts + plank training, (2) becoming dashboard + weight + steps, (3) food coming soon ♥**. ~88pt total, replaces no existing slot, fits cleanly in the 108pt headroom the v3 composition left on iPhone 13 mini.

The "empty-when-Quarterly-selected" complaint is a real conversion issue, not just aesthetic — the gap below tier row reads as **"the recommended option costs more but I get less"** when the trial timeline disappears, which is the exact opposite of what the tier row's center-stage hierarchy is supposed to communicate. But solving it *below* the tier row is wrong; the trial timeline is a contractual disclosure that should logically attach to the Annual tier and disappear when other tiers are selected. Solving it *above* the tier row, where a value-stack is genre-canonical, fixes both the conversion gap and the layout integrity.

---

## Q1 — Should we add a benefits list at all?

### Verdict: **Yes. The 2026 evidence is one-sided.**

**Genre-universal**: Adapty's [2026 paywall audit](https://adapty.io/blog/designing-effective-paywalls-for-mobile-apps/) calls a benefits list "near-universal" in fitness/wellness paywalls — "almost all apps show a list of features or benefits their pro versions bring." MyFitnessPal Premium ($13M MRR), YAZIO Pro ($3.3M MRR), Noom, BetterMe, Lasta, MacroFactor — every public teardown of a fitness paywall above $1M MRR carries some form of value-stack. The handful of apps that ship without one (Duolingo Super gets called out in the [Funnelfox 2026 teardown](https://blog.funnelfox.com/effective-paywall-screen-designs-mobile-apps/) — "the paywall doesn't explain what 'Super' includes — no ads? offline access? progress boosts?") are diagnosed as leaving money on the table, not pioneering.

**Million-dollar app pattern**: [Superwall's 5 paywall patterns analysis](https://superwall.com/blog/5-paywall-patterns-used-by-million-dollar-apps/) — "million-dollar apps use bulleted lists to make benefits scannable and digestible, with icons next to each benefit since visuals are processed faster than text and make the list look more professional."

**Conversion delta** (note: I could not find a clean A/B isolation for "benefits list on vs off" — most public tests measure *count* or *copy* of items, not presence vs absence; that gap is real and worth caveating to the founder). What we *do* have:
- [Stormy AI's 4,500 A/B test compilation](https://stormy.ai/blog/how-to-design-a-high-converting-mobile-app-paywall-lessons-from-4500-ab-tests) — the winning paywall benchmark composition includes "3 to 5 clear, high-value bullet points" as a load-bearing component, with bullets outperforming comparison tables when tested head-to-head.
- [Adapty 2026 high-performing paywall benchmark](https://adapty.io/blog/high-performing-paywall-2026/) — Free vs. Pro comparison tables (which are a feature-list variant) are "one of the most consistent paywall additions among top apps right now — appearing across fitness, education, productivity, design, and AI tools."

**Is the "empty-when-Quarterly-selected" complaint a real conversion issue?** Yes — and it's more diagnostic than the founder may be giving it credit for. The trial timeline renders only when Annual is selected because Annual is the only tier with a free trial. Mechanically that's correct. But the *visual experience* for a user who taps Quarterly is: **(a)** tier row reorganizes to emphasize Quarterly, **(b)** the 88pt strip below collapses to a 36pt plan recap, **(c)** the CTA snaps up 52pt. The user reads this as "I picked the upsell tier and lost a benefit." Even if every individual piece is correct, the **layout collapse signals loss**, which on a paywall is the worst possible micro-moment.

The fix is not to add chrome to the recap line (option C below). The fix is to put the value-stack somewhere the layout doesn't move when tier selection changes — **above the tier row** — so tier interaction has zero side effects on the rest of the screen except the contractual-detail strip immediately below the row.

---

## Q2 — Where does the benefits list live?

### Verdict: **Between hero and tier row. Replace the BecomingProjectionChip slot.**

Wait — the projection chip was already cut in v3 (re-homed to plan-reveal). So the slot is empty. The current shipped composition has:

```
topBar (44pt)
heroPermission (~52pt)              ← headline "jen, sized for *your* timeline ♥"
becomingProjectionChip (~110pt)     ← per Han's current ship, this is back on the paywall
pricingRowAnchorLine (~24pt)        ← "$99.96 strikethrough + save $51.97 ♥"
tierRowHorizontal (~156pt)          ← the 3 cards
trialOrPlanRecap (~88pt / 36pt)     ← THE EMPTY-FEELING SLOT
ctaButtonV2 (~56pt)
trustAndLegalFooter (~32pt)
```

The empty-feeling slot is the `trialOrPlanRecap` row. **Do not put the benefits list there.** Reasons:

1. **The trial timeline is a contractual disclosure tied to the Annual tier.** It should logically appear and disappear with tier selection. A benefits list that lives in the same slot fights with the trial timeline for that slot. You either show benefits + lose trial timeline visibility on Annual (bad — trial reminders carry the [Sunflower 46% trial-conversion lift Superwall documented](https://superwall.com/blog/17-revenue-boost-with-transaction-abandon-paywalls-a-case-study/)), or you flip-flop between benefits and trial-strip based on tier (worse — same layout collapse the founder is trying to fix).

2. **Eye-tracking on paywall composition** (referenced in Adapty's 2026 ordering — pricing experiments first, visuals second) consistently shows the value-stack pulls best when it sits **between the emotional hook and the pricing decision** — hero → benefits → tier row. The user reads "here's why" → "here's what you get" → "here's what it costs." Putting benefits *after* the price decision flips that order: "here's what it costs" → "here's what you get" — at which point the price feels expensive before the value is on screen.

3. **Above-tier placement makes the benefits visible for ALL three tier states.** Tier interaction below it doesn't collapse the screen. The benefits act as a layout anchor that holds the top half of the screen still while the bottom half adapts to the selected tier.

### Where it goes, concretely:

```
topBar (44pt)
heroPermission (52pt)               ← "jen, sized for *your* timeline ♥"
benefitsList (88pt)                 ← NEW: 3 rows × ~26pt + 8pt + 2pt header gap
pricingRowAnchorLine (24pt)         ← "usually $99.96 · $51.97 off ♥"
tierRowHorizontal (158pt)           ← 3 cards (incl. 8pt floating ribbon overhang)
trialOrPlanRecap (88pt / 36pt)     ← stays exactly as is; trial timeline lives here only on Annual
ctaButtonV2 (56pt)
trustAndLegalFooter (32pt)
```

Total worst-case (Annual selected): 44 + 52 + 88 + 24 + 158 + 88 + 56 + 32 = **542pt content**. Adding ~24pt of inter-slot rhythm puts us at ~566pt. iPhone 13 mini usable: 728pt. **Headroom: ~162pt**, safely above the 108pt v3 budget.

**Replace the BecomingProjectionChip if it's still in the ship.** If it's already been removed per v3, this slot is net-new. Either way, the 88pt benefits list fits with margin to spare. (If the projection chip is shipping and Han wants to keep it, see the "chip stays" alternative in the appendix — the answer is the benefits list still goes where I'm putting it, the projection chip is the part that has to move.)

### Option C (the "expand the recap line" alternative): rejected

The founder's question framed three solution shapes:
- (a) global benefits list visible regardless of tier — **what I'm recommending**
- (b) tier-specific benefits per selection
- (c) expand planRecapLine to be richer for non-yearly tiers

**(b) is rejected**: tier-specific benefit lists are anti-pattern — they re-litigate the tier decision the user just made, force the user to re-read three different value props instead of committing to the one they picked, and they make the screen feel like a sales pitch instead of a confirmation. None of Cal AI, MFP, YAZIO, MacroFactor, BetterMe ship tier-specific benefits in 2026 reviews.

**(c) is rejected**: "expand the recap line" is treating the symptom. The recap line is a contractual disclosure ("plan recap: quarterly billed every 12 weeks ♥"). Loading it with marketing copy ("plus calorie tracking, weight tracking, breathwork...") confuses the cognitive frame — is this a receipt or an ad? Adapty 2026 calls this out specifically — "do not mix contractual / disclosure copy with value-stack copy in the same slot; they fight each other for register."

---

## Q3 — What benefits get listed?

### Verdict: **Three rows, opinionated, mapping to product depth that exists today + signaling food rail as "soon ♥".**

I'm going to be aggressive about merging items into single rows. Million-dollar paywalls list 3-5 items but the post-Ozempic / Gen-Z cohort responds better to **fewer-but-richer** lines than to a long checklist of small features — the long-checklist register reads as MFP / Lose It (utility / tracker), and JeniFit is positioning against that. Pick three rows. Each row carries a 2-3 word label + a 5-7 word sub-line that elaborates with concrete product depth.

### Row 1 — Workouts + Plank training

**Label**: "full *workouts* ♥"
**Sub-line**: "rules-built sessions + plank baseline"

Why: the workout engine is the original product and the deepest piece of IP. Listing it first signals "we have the goods" before food/scan hype. The "rules-built" phrase is voice-distinctive (other apps say "AI-personalized" — banned in our locks; "rules-built" reads as honest + serious without using AI language). "plank baseline" is a hat-tip to the original product's research depth (McGill Waterloo norms) without geeking out.

**Why not "personalized workouts"** — every fitness app says that. "Rules-built" is the differentiator we can actually claim, and it lines up with the founder's [data provenance rule](feedback_data_provenance.md): no fabricated personalization.

### Row 2 — Becoming dashboard + weight + steps

**Label**: "your *becoming* dashboard"
**Sub-line**: "weight trend, steps, breathwork"

Why: bundles three real, shipped, research-grade features into the Becoming tab's identity. The italic-Fraunces *becoming* is the brand voice signature carrying through. "weight trend" not "weight tracking" (trend > number per [weightloss UX principles memory](feedback_weightloss_ux_principles.md)). "steps" is HealthKit-grounded (real, no marketing). "breathwork" is the depth signal Cal AI / MFP can't claim.

**Cut deliberately**: JeniMethod lessons, notifications, sticker chrome. Lessons could be its own row if you wanted 4 rows — but the 88pt total is right for 3, and lessons sit better inside the Becoming dashboard narrative than as their own surface. Notifications are infrastructure, never list them. Stickers are aesthetic, never list them.

### Row 3 — Food rail (soon ♥)

**Label**: "*food* coming soon ♥"
**Sub-line**: "snap a meal — log without thinking"

Why: see Q4 for the full argument. Short version — food rail ships in v1.0.7 (the next release), every competitor anchors on it, hiding it forces a paywall redesign in 4 weeks, and the "soon ♥" tag is honest disclosure of pre-release status. The sub-line is voice-locked post-Ozempic ("without thinking" → permission frame, not labor; "snap a meal" → product mechanic, not AI claim).

### What I explicitly did NOT list

- **AI coach agent** — long-term vision, not shipped, fabrication risk if listed
- **Body scan** — long-term vision, not shipped
- **Notifications** — infrastructure
- **JeniMethod lessons** — fits under Becoming row, listing separately fragments
- **Cross-device sync / iCloud** — table-stakes, listing trivializes the row
- **Ad-free** — we have no ads to remove
- **Unlimited X** — table-stakes for a $48/yr subscription

---

## Q4 — Food rail / calorie tracking — list it before users have it?

### Verdict: **List it, with "soon ♥" tag. Net-positive for conversion, neutral-to-positive for trust if you disclose honestly.**

The tension is real. Cal AI's paywall lists every food feature the moment you complete onboarding, before you've scanned a single meal — and Cal AI's [trial-to-paid lifted 31%](https://superwall.com/case-studies/cal-ai) across that iteration. The pattern works. The question is whether Cal AI's pattern works because of *forward disclosure of upcoming features* or *forward disclosure of features the user could use the same day*.

For us, the food rail ships in v1.0.7, which per the [v1.0.6 build 11 SHIPPED memory](project_v106_build11_pending.md) is the very next release after the current one. We're talking about a 2-4 week gap between paywall promise and feature availability for someone subscribing today.

### Three reasons to list it now

**1. Roadmap-as-pitch is genre-canonical in 2026.** Adapty's 2026 paywall audit and Funnelfox's teardowns both note the "soon" tag as an established pattern — Lasta, BetterMe, and Fastic all list features that ship in upcoming releases on their paywalls with explicit "coming soon" or "new" tags. Users read it as "this app is in active development," which is a trust signal, not a deception flag — *if* the tag is explicit.

**2. We pay for it operationally either way.** If we ship the paywall without food rail copy, then v1.0.7 lands in 2-4 weeks, we redesign the paywall, re-test, re-iterate — and the cohort that subscribed pre-v1.0.7 doesn't know food rail exists in the app they're already paying for, so we have to push it through in-app announcements anyway. Shipping the "soon ♥" row now means v1.0.7 doesn't require a paywall change, just a copy swap on the row label (drop "soon ♥").

**3. The competitive frame demands it.** Cal AI / MFP / YAZIO / Noom all anchor on calorie tracking on their paywalls. A 2026 WL paywall that doesn't mention food is reading as "this is just a workout app" — which we are *positioning against* per the [diet-first pivot memory](project_pivot_diet_first_2026_06_05.md). Even if food rail is 2-4 weeks out, the brand-position cost of omitting it on the paywall is real.

### One reason against, and how to mitigate it

**Trust risk if the disclosure isn't crystal-clear.** A user who subscribes seeing "food calorie tracking" listed without a "soon" tag, then opens the app and can't find it, is the worst possible churn pattern (App Store review damage + refund request + word-of-mouth). The mitigation is **literal copy honesty**: the row label says "*food* coming soon ♥" — soon is in the visible copy, not buried in fine print. This is non-negotiable. If product wants to drop "soon" before v1.0.7 ships, the row stays out of the paywall until v1.0.7 ships.

**Belt-and-suspenders**: when food rail ships in v1.0.7, swap the row label from "food coming soon ♥" to "*food*, snap a meal ♥" and the sub-line from "snap a meal — log without thinking" to "calories, macros, no math". Same row position, same icon, same height — just a copy swap. Two-line PR change.

---

## Q5 — Visual treatment

### Verdict: **Icon (24pt) + 2-3 word label + 5-7 word sub-line. No animation. No checkmarks.**

The 2026 evidence converges on **icon + text rows** as the bullet treatment that beats both text-only and checkmark-style — referenced by [Superwall's 5 patterns review](https://superwall.com/blog/5-paywall-patterns-used-by-million-dollar-apps/) ("icons next to each benefit since visuals are processed faster than text") and [Adapty 2026 designing-effective-paywalls](https://adapty.io/blog/designing-effective-paywalls-for-mobile-apps/) ("use icons next to each benefit. visuals are processed faster than text and make the list look more professional and feature-rich").

### Specifically rejected:

**Checkmarks**: checkmarks are conversion-positive on utility apps where the value-prop is "you get all of these things" — they read as a contract. For an anti-femvertising weight-loss brand, checkmarks read as a diet-app trope (Noom green checks, MFP greens). Visually adjacent to "complete this checklist" register, which is the labor frame we banned in voice locks. Skip them.

**Comparison tables**: Adapty 2026 directly notes "table components rarely outperform simple bullets." For a 3-row list on a narrow viewport, a Free vs Pro table eats 2× the vertical space and forces the user to scan four cells per row. Skip.

**Animated checks** / animated reveals: Reduce-motion violation risk per the accessibility passes already shipped. Adds zero conversion lift in any documented test. Skip.

**Bullet dots**: too utility-app, no brand affordance. Skip.

### The visual treatment that ships:

```
┌────────────────────────────────────────────────────────────┐
│ [icon 24]  full *workouts* ♥                              │
│            rules-built sessions + plank baseline          │
├────────────────────────────────────────────────────────────┤
│ [icon 24]  your *becoming* dashboard                      │
│            weight trend, steps, breathwork                │
├────────────────────────────────────────────────────────────┤
│ [icon 24]  *food* coming soon ♥                           │
│            snap a meal — log without thinking             │
└────────────────────────────────────────────────────────────┘
```

**Row construction**:
- Container: 358pt wide (full content width), no border, no fill, no shadow.
- Per row: 24pt icon, 12pt gap, text column. Vertical centering on the icon against the 2-line text block.
- **Label**: Fraunces Semibold 13pt, italic on the punch word (*workouts*, *becoming*, *food*), color #2B1F1A.
- **Sub-line**: Inter Regular 11pt, #7B5959. Sits 2pt below the label.
- **Row height**: ~26pt each (12pt label + 2pt gap + 12pt sub-line = 26pt content).
- **Row gap**: 6pt between rows.
- Total list height: 3 × 26 + 2 × 6 + 4pt top + 4pt bottom = **90pt** (rounded to 88pt in the layout budget; the math is loose by 2pt to leave breathing room).

### Icon style

**Use the scrapbook sticker register**, not SF Symbols. The brand is coquette y2k 3D glossy — SF Symbols would read as utility/system and break the aesthetic. Three custom 24pt icons in the same sticker style as the rest of the app:

- Row 1 (workouts): a small dumbbell sticker OR a tiny plank-pose silhouette (the plank-pose silhouette is the brand-distinctive choice — every fitness app uses a dumbbell; the plank silhouette is uniquely ours and lines up with the original product identity).
- Row 2 (becoming): the becoming tab's existing icon, scaled to 24pt — a small bloom / flower3D sticker (matches the iridescent bow / gummy bear register already locked).
- Row 3 (food): a tiny sparkle-fork or a sticker-bowl, deliberately soft (do NOT use a camera/scanner icon — that's the Cal AI register and we're positioning against it). A small bowl sticker is voice-locked to "permission" not "tracking."

If sticker assets aren't ready for v1.0.7, the **fallback** is to use 18pt × 18pt cream-on-cocoa hand-drawn glyphs, but the sticker register is the right answer; ship it if it's possible.

### Color

- Label: cocoa #2B1F1A (highest contrast on cream background, WCAG AA cleared).
- Sub-line: textSecondary #7B5959 (the WCAG-darkened palette per accessibility lock).
- Icon: full-color sticker on cream background (no monochrome treatment — the stickers ARE the visual richness, per [feedback_visual_richness_over_restraint memory](feedback_visual_richness_over_restraint.md)).

---

## Q6 — Copy style per item

### Verdict: **Label = 2-3 words with italic-Fraunces punch word; sub-line = 5-7 words, voice-locked, no banned verbs.**

This is the load-bearing decision after Q5. Most paywalls fail copy by writing labels like "Personalized Workouts" or "AI Calorie Tracking" — descriptive utility-app register that says nothing about *why*. JeniFit's voice is concrete, lowercase, italic-Fraunces on the punch word. The label needs to do that *and* be short enough to read in a single eye-flick.

### Length

**Label: 2-3 words.** Stormy's 4,500 A/B test summary: "Feature names should be concise and scannable — 'Offline maps,' 'No ads,' 'Unlimited practice' — avoiding lengthy explanations." Cal AI's paywall uses 2-3 word labels per row ("unlimited scans," "detailed breakdowns," "progress charts"). We follow that length convention but swap the utility-app register for our voice.

**Sub-line: 5-7 words.** Long enough to carry the elaboration, short enough to read with one fixation. Concrete > abstract per [copy_succinct_for_genz memory](feedback_copy_succinct_genz.md) — no literary register, no "the war's been long enough" abstract phrasing, just concrete product mechanic + voice.

### Italic-Fraunces punch word per row, NOT on a section title

The v3 voice signal pattern is "italic-Fraunces on the punch word" — applied per row in this case. Each label gets exactly one italic word:

- "full *workouts* ♥" — *workouts* is the noun + punch
- "your *becoming* dashboard" — *becoming* is the brand-voice anchor
- "*food* coming soon ♥" — *food* is the noun

**There is NO section title** ("what's included" / "your becoming plan" / "you get"). See Q7. The italic punch lives on the row labels.

### Voice register examples

Banned words per the [post-ozempic vocabulary memory](feedback_post_ozempic_vocabulary.md): crush, shred, burn, earn, deficit, AI, transform. Add: "personalized" (utility-app reflex), "smart" (AI register tell), "advanced" (empty descriptor), "premium" (talks about the tier not the user).

Voice-locked alternatives that I considered and rejected for each row:

**Row 1 alternatives**:
- "personalized workouts" — banned register
- "*workouts* built for you" — too long for label
- "real workouts" — implies others are fake (false flag)
- "*workouts* that adapt" — "adapt" is AI register
- WINNER: "full *workouts* ♥" — short, lowercase, italic punch, "full" means "not the limited free tier" without saying so

**Row 2 alternatives**:
- "weight tracking" — utility register, also "tracking" is overloaded by Cal AI
- "your *becoming* dashboard" — brand-voice anchor, "dashboard" is concrete
- WINNER: same as above

**Row 3 alternatives**:
- "AI calorie counting" — banned
- "snap your meals" — verb-led, OK but "snap" leads with mechanic before the value
- "*food*, no math" — fits with "no math" being the value, lowercase, italic punch
- WINNER: "*food* coming soon ♥" — declares status honestly, the noun carries

### Sub-line construction

Sub-lines elaborate with **concrete product depth** — not marketing claims. Each sub-line names actual mechanics that exist (or will exist in v1.0.7).

- Row 1 sub-line: "rules-built sessions + plank baseline" — "rules-built" is voice-distinct, "plank baseline" hat-tips original product depth
- Row 2 sub-line: "weight trend, steps, breathwork" — three concrete features, comma-separated, no "and" (Gen-Z register prefers comma lists over coordinating conjunctions)
- Row 3 sub-line: "snap a meal — log without thinking" — em-dash for cadence, "without thinking" = permission frame post-Ozempic vocabulary, no "AI" / "smart" / "instant"

### Anti-shame compliance check

Each row is reviewed against the [anti-shame food UX memory](feedback_food_ux_antishame.md) and [voice signals lock](feedback_voice_signals.md):
- No labor verbs (crush / shred / burn / earn / hit / smash) ✓
- No deficit / restriction language ✓
- No before/after framing ✓
- No body imagery references ✓
- No scale-shame ✓
- Italic-Fraunces on punch word, hearts as terminal punctuation, lowercase casual ✓

---

## Q7 — Section header copy

### Verdict: **No header. The brand voice + the visual treatment carry the meaning.**

The instinct to add "what's included ♥" or "your becoming plan" as a section header is a reflex from utility-app paywalls where the benefits list reads as a contract ("here is the list of what you get"). For JeniFit, a header would:

1. **Stack redundancy on top of the already-italic-Fraunces hero**. The hero is "jen, sized for *your* timeline ♥". Adding "what's included ♥" makes the screen read as two competing italic-heart hooks back to back, dilutes both.
2. **Read as utility-app register**. Cal AI / MFP / YAZIO all use a "what you get with Premium" header. We're positioning against that voice.
3. **Cost vertical space we'd rather give to row breathing room**. A header at Fraunces 14pt would eat ~18-22pt + a gap. The 3 rows feel cleaner without it.

The visual treatment + the icon scrapbook stickers + the position-between-hero-and-tier-row carry the meaning. The eye reads:

```
"jen, sized for your timeline ♥"
[3 sticker rows of what that means]
[the tier cards]
```

The narrative flow is implicit. No header is needed.

### What if Han wants a header anyway?

The least-bad header copy, voice-locked:

1. **"what's *included* ♥"** — utility register but italic punch saves it; lowercase casual; would work at Fraunces 12pt taking ~16pt of additional height. Cuts headroom from 162pt to 146pt — still safe.
2. **"your *becoming* plan ♥"** — voice-aligned but creates a noun collision with Row 2's "*becoming* dashboard" label. Reject.
3. **"*here's* what you get"** — too casual, lands as filler.

If forced, ship (1). But the stronger choice is **no header** and let the visual register do the work. This is the same principle as the v3 decision to cut the hero subhead — voice-signal-once-per-screen.

---

## Q8 — The "empty-when-Quarterly-selected" complaint, decisively answered

### Verdict: **(a) global benefits list above the tier row. Reject (b) and (c) on conversion + design integrity grounds.**

Restating the founder's three options:
- (a) global benefits list visible regardless of tier
- (b) tier-specific benefits per selection
- (c) expand the planRecapLine for non-yearly tiers

### Why (a) wins

The benefits list **doesn't move when the tier selection changes**. That's the actual fix for the "empty-feeling" problem. The empty-feeling is a layout collapse problem — the screen contracts visually when Quarterly is selected because the only variable-height slot on the screen is below the tier row. Moving a meaningful information block *above* the tier row means the screen retains its visual mass regardless of which tier the user has selected, and the only thing that changes below the tier row is the trial timeline strip (which correctly attaches to Annual as a contractual disclosure).

This also fixes a problem the founder hasn't articulated yet: the **current Annual-selected state is visually bottom-heavy**. The trial timeline + CTA + footer eats ~176pt of bottom-screen real estate. The screen reads as "the action is at the bottom." Moving the benefits block to above-tier-row rebalances the screen — the value frame is up high (where the eye lands first), the decision is in the middle, the contractual detail is at the bottom near the CTA. Cleaner cognitive hierarchy.

### Why (b) loses

**Tier-specific benefits** force the user to re-evaluate the tier decision they just made. The premise is "different tiers offer different things" — which is *not true for us* (all three tiers offer identical product access; the difference is only billing cadence + trial-on-annual). Pretending tiers offer different value would either be dishonest (faking feature gates we don't have) or trivial (showing the same 3 items with cosmetic tweaks per tier).

Even if we *did* have feature differences, Adapty 2026 and Stormy 4,500 tests converge on bullet-list-stable > tier-variable-list for conversion: variable-content slots increase cognitive load and reduce decision velocity. Users prefer to make the tier decision *once* and then commit.

### Why (c) loses

**Expanding the plan recap line** is the path of least resistance and the lowest conversion ceiling. The recap line is currently:
- Annual selected: "today free · day 2 reminder · day 3 $47.99 ♥" (trial timeline)
- Quarterly selected: "quarterly billed every 12 weeks ♥" (plan recap)
- Weekly selected: "weekly billed every 7 days ♥" (plan recap)

Loading the recap line with marketing copy mixes contractual disclosure with value-stack — Adapty 2026 specifically flags this as anti-pattern ("do not mix contractual / disclosure copy with value-stack copy in the same slot"). The user can't tell if the line is what-you'll-be-billed or what-you'll-get, and both meanings degrade.

The recap line is doing its job. The empty-feeling problem is **not** that the recap line is too sparse — it's that the *screen's variable-height slot is in the wrong place*. Fix the place, not the slot.

---

## What ships, slot by slot (the locked composition)

```
┌────────────────────────────────────────────────────────────────┐
│ [restore]                                                  44pt │  topBar
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│     jen, sized for *your* timeline ♥                       52pt │  headline
│                                                                 │   (italic on "your")
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [💪]  full *workouts* ♥                                        │
│        rules-built sessions + plank baseline                    │
│                                                                 │
│  [🌸]  your *becoming* dashboard                           88pt │  benefits list
│        weight trend, steps, breathwork                          │   (3 rows, no header)
│                                                                 │
│  [🍓]  *food* coming soon ♥                                     │
│        snap a meal — log without thinking                       │
│                                                                 │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│              usually $99.96 · $51.97 off ♥                 24pt │  row-anchor
│                                                                 │
├────────────────────────────────────────────────────────────────┤
│              ┌──────────────────────────┐                       │
│              │ recommended for      ♥   │   floating ribbon     │
│              │ your 12-week goal        │   (conditional)       │
│              └──────────────┬───────────┘                       │
│ ┌───────┐    ┌──────────────v─────────────┐    ┌───────┐  158pt │  tier row
│ │ANN    │    │      QUARTERLY              │    │WEEK   │       │
│ │104×135│    │      130×150                │    │104×135│       │
│ │ [BEST]│    │                             │    │       │       │
│ │$47.99 │    │      $24.99                 │    │$5.99  │       │
│ │3-day  │    │  12 weeks of *becoming* ♥   │    │flexi  │       │
│ │free ♥ │    │      $2.08/wk               │    │$5.99  │       │
│ │$4.00mo│    │                       [●]   │    │ /wk   │       │
│ │  [○]  │    │                             │    │  [○]  │       │
│ └───────┘    └─────────────────────────────┘    └───────┘       │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│ [today free]──[day 2 reminder]──[day 3 $47.99 ♥]      88/36pt   │  trial strip
│                                                                 │   (Annual: 88pt)
│                                                                 │   (else: 36pt)
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│             ┌──────────────────────────┐                        │
│             │       continue           │                   56pt │  CTA (cocoa pill)
│             └──────────────────────────┘                        │
├────────────────────────────────────────────────────────────────┤
│   data stays yours · terms · privacy                       32pt │  footer
└────────────────────────────────────────────────────────────────┘

Total content height by tier state:
  44 + 52 + 88 + 24 + 158 + 88 + 56 + 32  = 542pt  (Annual selected)
  44 + 52 + 88 + 24 + 158 + 36 + 56 + 32  = 490pt  (Quarterly / Weekly selected)

Plus inter-slot rhythm (~24pt total at 4pt × 6 gaps) → ~566 / 514pt
Plus 50pt + 34pt safe areas                            → ~650 / 598pt
iPhone 13 mini usable: 728pt
Headroom: ~78pt (Annual) / ~130pt (Quarterly/Weekly)
```

**The empty-feeling is now structurally impossible**: the top half of the screen (headline + benefits list + price anchor) is fixed-height across all tier states; the tier row's height is identical regardless of selection; only the bottom strip (trial timeline) varies, and that variance is now tied to the legitimate contractual difference between the tiers (Annual has a trial; the others don't).

---

## Copy-locked benefits-list draft

```
[icon: dumbbell sticker OR plank silhouette sticker, 24pt]
full *workouts* ♥
rules-built sessions + plank baseline

[icon: bloom / flower3D sticker, 24pt]
your *becoming* dashboard
weight trend, steps, breathwork

[icon: bowl / sparkle-fork sticker, 24pt, NOT a camera or scanner]
*food* coming soon ♥
snap a meal — log without thinking
```

**v1.0.7 copy swap** for row 3 (when food rail ships):
```
[icon: same bowl / sparkle-fork sticker]
*food*, snap a meal ♥
calories, macros, no math
```

---

## Build order recommendation

1. **Add the benefits list slot** between hero and pricing row anchor. Wire up the SwiftUI VStack with 3 HStack rows. Use placeholder system icons first (`figure.strengthtraining.traditional`, `figure.mind.and.body`, `fork.knife`) until sticker assets land.
2. **Confirm the composition fits iPhone 13 mini** with the 88pt benefits list added. Check headroom in both Annual-selected and Quarterly-selected states.
3. **Drop in copy** with italic-Fraunces punch words. Use `Text("full ").font(.fraunces) + Text("workouts").font(.frauncesItalic) + Text(" ♥")` pattern per voice-signal locks.
4. **Confirm WCAG AA** on label (#2B1F1A on cream) and sub-line (#7B5959 on cream). Both already cleared per existing palette.
5. **Swap in sticker icons** when assets are ready. Pre-asset, system icons are fine for build verification.
6. **Test tier interaction** — confirm that changing tier selection does NOT visually shift the benefits list (it shouldn't, because tier row sits below). Confirm trial timeline still renders only on Annual.
7. **Reduce-motion check** — no animation on the benefits list, but verify the parent screen's existing animateIn cascade still works with the added 88pt content block.
8. **Accessibility** — `accessibilityElement(children: .combine)` on each row so each becomes a single VoiceOver swipe target with label + sub-line read together.
9. **v1.0.7 prep** — register the row 3 copy swap as a one-line change for the v1.0.7 launch PR.

---

## Caveats, gaps, and what I'd watch in production

**Caveat #1 — A/B test data on "list on vs off" specifically is missing in the public record.** Adapty + Superwall + Funnelfox + Stormy all assert benefits lists improve conversion, but they isolate things like *count of items*, *icon vs text*, *order*, *copy phrasing* — not presence vs absence. The "near-universal in fitness" pattern is strong directional evidence; the absence of clean A/B isolation means we're reasoning from genre convergence, not from a single measured delta. Honest framing for Han.

**Caveat #2 — the v3 brief recommended cutting BecomingProjectionChip from the paywall, but the current ship (commit e76ebc5) appears to have it back.** If projection chip is staying on the paywall, the 88pt benefits list still fits (162pt of v3-budgeted headroom less the chip's 110pt = ~52pt remaining, plus the v3 chip-cut → ~88pt would be ~162pt). Whichever way the projection chip resolves, benefits list location is above-tier-row, full stop.

**Caveat #3 — the "soon ♥" tag on food rail is a 2-4 week disclosure liability**. Watch the v1.0.7 ship date. If v1.0.7 slips, the row 3 copy ages from "honest pre-announcement" to "vapor" fast. The mitigation is to swap the row to "*becoming* lessons + breathwork ♥" or similar real-shipped feature if v1.0.7 slips past 6 weeks from paywall ship.

**Caveat #4 — sticker icons are a brand register commitment**. If sticker assets aren't ready, system icons or simple hand-drawn glyphs are fine fallbacks — but do not ship SF Symbols for v1.0.7 if it's avoidable; SF Symbols register as utility, which the brand is positioning against.

**Caveat #5 — the row 3 voice "without thinking" is post-Ozempic-permission framed but verges on a moderation risk**. Apple's April 2026 enforcement focused on misleading per-period displays, not value-prop language, but if review pushes back on "without thinking" as glamorizing inattentive eating, the fallback is "snap a meal — see the numbers ♥". Less voice-distinct but cleaner.

---

## Sources

- [Adapty — High-performing paywall 2026](https://adapty.io/blog/high-performing-paywall-2026/) — Free vs Pro comparison tables near-universal in fitness; bullets > tables; pricing-then-visuals testing order
- [Adapty — Designing effective paywalls for mobile apps](https://adapty.io/blog/designing-effective-paywalls-for-mobile-apps/) — "almost all apps show a list of features or benefits"; icons next to each benefit; MyFitnessPal Premium ($13M MRR) icon-rich list reference; YAZIO Pro ($3.3M MRR) testimonial pairing; sliders + dots + arrows for "illusion of continuity"
- [Adapty — iOS Paywall Design Guide 2026](https://adapty.io/blog/how-to-design-ios-paywall/) — multi-signal visual hierarchy guidance; Cal AI compliance discipline for per-period display
- [Adapty paywall library — Cal AI](https://adapty.io/paywall-library/cal-ai-food-calorie-tracker/) — 3-tier horizontal canonical, food-feature-on-paywall reference
- [Adapty paywall library](https://adapty.io/paywall-library/) — broad WL/fitness paywall visual reference
- [Superwall — 5 paywall patterns used by million-dollar apps](https://superwall.com/blog/5-paywall-patterns-used-by-million-dollar-apps/) — "million-dollar apps use bulleted lists with icons" recommendation
- [Superwall — Cal AI case study](https://superwall.com/case-studies/cal-ai) — 123 experiments, 31% trial-to-paid lift, 3× monthly revenue; food-feature paywall reference
- [Superwall — 17% revenue boost via transaction-abandon paywalls](https://superwall.com/blog/17-revenue-boost-with-transaction-abandon-paywalls-a-case-study/) — Sunflower 46% trial-conversion lift via reminders (the reason the trial timeline still lives on Annual-selected state)
- [Stormy AI — How to design a high-converting paywall: lessons from 4,500+ A/B tests](https://stormy.ai/blog/how-to-design-a-high-converting-mobile-app-paywall-lessons-from-4500-ab-tests) — 3-5 bullets; bullets > tables; concise scannable labels
- [Funnelfox 2026 — Paywall teardowns](https://blog.funnelfox.com/effective-paywall-screen-designs-mobile-apps/) — "highlight benefits not features"; Duolingo Super critique on missing value-stack; BetterMe colorful-pillars pattern; Fastic + KetoCycle + MyNetDiary 2026 references
- [Mobbin paywall library](https://mobbin.com/explore/mobile/screens/subscription-paywall) — visual reference index for horizontal-3 + benefits-list patterns
- [Mobbin — Fitness app design inspiration](https://mobbin.com/explore/mobile/app-categories/health-fitness) — fitness-genre paywall visual reference
- [TechCrunch — Apple's Cal AI crackdown April 2026](https://techcrunch.com/2026/04/21/apples-cal-ai-crackdown-signals-its-still-policing-the-app-store/) — compliance discipline for per-period display + value-prop language
- v1 + v2 + v3 internal: [paywall_research_ux_2026_06_06.md](paywall_research_ux_2026_06_06.md) + [paywall_research_ux_v2_2026_06_06.md](paywall_research_ux_v2_2026_06_06.md) + [paywall_research_ux_v3_2026_06_06.md](paywall_research_ux_v3_2026_06_06.md) — strategy + layout decisions inherited, not re-litigated
