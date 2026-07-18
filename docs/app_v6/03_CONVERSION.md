# app v6.3 — THE CONVERSION + RETENTION PASS (2026-07-17)

Data-driven pass: fresh PostHog pull + three expert lenses
(conversion / retention / cohort psychology). Everything here traces
to a query run today; the expert syntheses are summarized inline.

## The diagnosis (from live data)

1. **Acquisition is the binding constraint.** Weekly installs:
   499 (wk 6/15) → 460 → 414 → 258 → ~87. The "app feels dying"
   feeling is 80% this. App-side work below helps conversion of
   whoever arrives; the installs line is a marketing emergency.
2. **July 1 (trial removal / pay-upfront) changed the wall's job**
   from persuading to filtering: view→CTA fell ~44% → 11-28%;
   `paywall_dismiss_attempted` exploded ~25% → 80-85% of viewers;
   `trial_start` flatlined. Purchases held (2-5/day) purely through
   self-selection (sheet→paid improved 10-15% → 25-40%).
3. **The save moment converted ~zero** (183 exit-intent downsell
   views / ~8 taps in 10 days) because it was tier-mismatched: the
   discounted YEAR ($34.99 today — more cash than the $24.99 anchor
   just refused) offered to commitment-objectors. The wall's own
   tier picks run weekly-first (27/68) — she pays a 2.4x premium
   for the right to quit. That is reversibility-seeking, not price
   sensitivity.
4. **Retention is a first-plate problem.** D0 behavior → D1 return
   (n=405): food loggers 61% vs 19.5% baseline (3.1x), weigh 52%,
   breath 48%, chat 71% (tiny n) — lessons (pushed to everyone)
   retain at exactly baseline. Only 17% ever log; 83% of PAYING
   users decide about tomorrow against an empty signals band.
5. Crashes are low and falling — not a stability story.

## What shipped (v6.3)

**Conversion (no pricing/SKU changes):**
- **Recovery ladder v3 — the data reversal** (`WallView`):
  X-dismiss + quarterly/weekly abandons → the WEEK-FIRST save sheet;
  yearly abandons keep the discounted year; the year stays reachable
  via the sheet's own second door + the reclaim row. (Reverses the
  07-07 year-first founder call on 10 days of contrary data — one
  routing block to flip back.)
- **The save moment rebuilt** (`SmallerStepSheet`, variant
  `week_one_v2`): "what if it was just *a week?*" · "same plan. same
  jeni. $5.99, then it's your call." · receipt rows today /
  plan-stays / **leaving: settings, two taps, before next week**
  (the trial substitute) · CTA "try the week · $5.99 today" ·
  quiet "or the year, 30% off →" · "not today". Analytics gains
  `lead_tier` + `variant`.
- **The wall** (`PaywallView`): first-24-hours proof rows above the
  tiers (tonight jeni's note / tomorrow morning the reading /
  tomorrow lunch snap chemistry — all live features; she can't
  believe week 12, she can believe a Tuesday); the guarantee
  promoted to the lead line ("money-back guarantee · no forms, no
  guilt") over the renewal truth; the Apple-sheet bridge under the
  CTA ("apple will ask to confirm · that's the whole plan, i'll be
  right here ♥"); weekly tier captioned "start small · same plan".

**Retention (the first-plate war):**
- Days 1-2 the one-thing IS the snap (engine-level:
  `Day.programDay` + `oneThing` override) with the in-session ask
  "snap the **last** thing you ate" + pre-forgiveness sub "even
  coffee counts. no grading here ♥".
- Day-1 reading's second line points at the camera ("your file
  starts with one plate").
- **The forming signals band** (endowed progress): before her data
  exists the band shows the dashed horizon, "your overnight window
  draws itself from tonight's plates ♥", "N already arriving"
  (steps/weight), and a one-tap sleep grant — never a blank.

**QA:** `--uitest-save-moment` lands inside the save sheet.

## Round 6 (2026-07-17) — the two-plan anchor wall + checkable Home

**Founder directives applied:** the two-plan anchor paywall (yearly
badged "most popular" + pre-selected, per-week rate leading with
the billed year in clear text beneath; weekly as the honest anchor
with "$X/year if billed weekly" said out loud; save-% computed
against the VISIBLE alternative); weekly price rising to $7.99
(founder changes the SKU; the app renders live prices); the
projection chart confirmed as the wall's hero (it was conditionally
hidden for goal-less users — QA now previews it via
`--debug-paywall`). Deviation from the reference layout: NO
fabricated strikethrough — every number is a live StoreKit price or
arithmetic on one (Apple 2.3/FTC exposure + the no-fabricated-stats
brand lock). Quarterly is hidden from the wall (SKU + restore paths
intact).

**Home (founder overrides recorded):** the day is a CHECKABLE list
again (reverses the v3/v5 no-checkbox law — trailing check rings on
required rows); workouts + breath are OPTIONAL under "if you feel
like it" and excluded from receipt arithmetic (unless promoted to
the one-thing, e.g. rest days); the overnight fast is now an ITEM,
not a dashboard module — an auto-checking row ("overnight fast ·
13h between plates" strikes itself through) with the detail sheet
one tap away. FASTING IS NAMED (founder override of the
never-say-fasting rail): "the overnight fast" everywhere, with a
plain why-it-helps explainer (12-14h framing, trimmed intake,
insulin sensitivity, earlier-stores-less) — the safety rails hold
underneath (no targets, no timers, care at 16h+, cohort gates).
jeni-chat now receives the full signal week (fast avg, pacing
shares, sweetness direction).

**Round 7a — the discounted-year facelift + a crash fix:** the
dense triple-row receipt became ONE anchor card in the wall's
family grammar ("the year · save 30%" + "renews at this price,
every year" + $0.67/wk lead + REAL struck $49.99 + "$34.99 per
year"); top spacer eased; the "this offer shows once" small print
became "saved to your wall · yours to reclaim anytime" (the true
durable-state behavior). While wiring the QA preview
(`--uitest-downsell-preview`, app-root cover with a deliberate
no-op setter — a boot-phase transition cancels early presentations
and would otherwise disarm it), a REAL latent crash surfaced and
died: `DownsellPaywallView.loadOfferings` called `Purchases.shared`
without the `isConfigured` guard its sibling sheet always had —
any presentation racing PaymentService.configure() fatalErrored
the app. Guarded now; degrades to the honest failure row.

**Round 8 (2026-07-17) — the coach closes the loop + THE PLAIN
REGISTER:** (1) **JENI'S COACHING page** closes the becoming pager
(before the reflection): `CoachSummary` engine
(`Signals.swift`) reads the whole signal week and names EXACTLY ONE
move by fixed clinical priority — 3+ short nights → sleep;
evening-heavy protein → timing; fast avg <11h (4+ nights) → stop
eating earlier; sugar rising → cut back; <2 weigh-ins/14d (only
when 3+ plate-days show engagement) → weigh once; else "change
nothing". Page = headline + provenance receipt rows (only stories
that exist) + FOR-YOUR-BODY why + luteal overlay note + chat door
seeded with the pick. Floor: 2+ stories. Tests cover the ladder.
(2) **Tap-interactivity** on all four becoming figures
(`JKSignalVisuals`): full-column tap strips (never a 7pt target),
selection wash + darkened day letter, shared `JKSignalCallout`
reserved line ("thursday · 13h 21m · 7:54pm to 9:15am", "last
night · 6h 12m asleep", "evenings · 52% of your sugar", "today ·
weighed in"). Taps only — pager swipes untouched; selection clears
on page swap; second tap deselects. QA `--uitest-select-figure`
pre-selects for screenshots. (3) **FOUNDER DIRECTIVE — direct
coach language:** "sweetness" → **"sugar intake"** everywhere it
renders (page eyebrow, headlines, stats, BodyLine, chat context
key `sugar_direction` with down/steady/up values); poetic phrasing
swept app-wide on the daily surfaces: "the trend eased" → "your
trend is down", "quiet hours" → "overnight fast" (brief, journey
receipts), "your season" → "your cycle", "protein pacing" →
"protein timing", "nights" → "sleep", "rhythm" → "consistency",
"usual close" → "usual last plate", fuel/season/sleep rows told
plainly ("expect stronger hunger today. that's chemistry, not
weakness"). Onboarding v5 + method reader authored flows NOT
swept (own register, founder reviews separately). 248 tests
green.

**Round 9 (2026-07-17) — THE DAY-6 UPGRADE MOMENT + the register
audit closes:** (1) **UpgradeMomentView** — founder memo #3 built:
the weekly→quarterly moment. Trigger (`TodayView`): active product
is a weekly SKU (`PaymentService.activeProductId`, new) + program
day ≥ 6 + no cover in flight + Today visible; PREFLIGHTED (the
quarter must price via RC before the once-per-install flag
`upgradeMoment.shownV1` is spent — a pricing outage never burns
the showing). The screen: "week one, kept" + "keep going for
$X a week." (live quarterly ÷ 13) + her week's receipt rows
(plates / fasts measured / weighed in — provenance-only) + ONE
anchor card (save% vs visible weekly, billed price said plainly,
renews/cancel line) + "switch to the quarter" CTA + Apple-handles-
the-timing bridge + first-class "stay weekly" exit. Sandbox
verified live math: $29.99/qtr → $2.31/wk, save 61% vs $5.99
weekly. Analytics: `upgrade_moment_viewed/cta_tapped/
sheet_shown/dismissed` (+day, save_pct, price_resolved). QA:
`--uitest-upgrade-moment`. Apple handles upgrade proration in the
subscription group; nothing app-side asserts timing. (2) **The
register audit of the authored flows** (the founder's "both"):
onboarding v5, method-reader chrome, chat starter chips, insight
engine, weekly review, and the re-signing were grepped for the
poetic vocabulary — all already in the direct register (concrete
questions, "up X. usually water, not fat.", "what's the move?").
Two borderline act-receipt lines left as authored ("your food
story, heard." / "the numbers, gently."); lesson BODY content
(manifest curriculum) untouched. 248 tests green.

**Round 10 (2026-07-17) — THE QUARTER RETURNS to the wall
(founder call, reverses round 6's two-plan hide):** `PaywallView`
is a THREE-tier anchor again — the year (badged "most popular",
pre-selected) → the quarter → one week — a descending per-week
ladder ($0.92 → $1.92 → $5.99/wk in mock) so the year reads as the
obvious value against the two rows beneath. The quarter row
`quarterlySubLine` ("three months · save X%") + `quarterlySavePct`
(quarterly ÷13 vs the visible weekly rate — checkable arithmetic,
live prices only) + per-week lead (÷13) + "$X per quarter, today"
billed line, all parallel to the year's grammar. **Self-gating
preserved:** `showsQuarterlyTier` renders the row only when
`quarterlyPackage` resolves (or a debug preview) — a build whose
offering lacks `jenifit_quarterly` falls back cleanly to the
two-plan wall, no permanent skeleton. The default stays the YEAR
(round 6 call intact); the `.task` guard only demotes off quarterly
if that SKU vanishes. Tall-bucket Metrics reverted to the
known-good 3-tier fold values (chartHeight 80, tiersTop 14,
tierVPad 15, tierGap 9 — commit 26c79a8) so all three rows + the
docked CTA clear the fold on first paint; tiny/compact buckets
were never de-tiered so they're untouched. WallView
smaller-step/downsell exit routing already handles quarterly
abandons → no change. **FOUNDER ACTION:** the quarter shows in
production only once `jenifit_quarterly` is in the live RC
`default` offering (same contract the tier has always held). 248
tests green.

## Measurement plan
- Save-take: `smaller_step_cta` / dismissers (target 3-6% vs ~0).
- Wall CTA rate weekly (watch for recovery off the 11-28% floor).
- First-session `food_first_log_saved` rate (17% → 40% target).
- D1 by cohort week (baseline 21-37%).

## FOUNDER MEMO (decisions that are yours, not made here)

1. **Acquisition is the fire.** 87 installs/week makes every
   in-app change statistically slow. The TikTok pipeline is the
   lever this week.
2. **Trial-on-annual reinstatement:** your own re-entry condition
   ("earn the 7-day annual trial back once D1 clears ~25-30%") is
   arguably met (D1 21-37% band). Recommended sequence: take 2
   weeks of save-moment data first, then trial on ANNUAL ONLY
   (keep pay-upfront self-selection on quarterly), keep it if
   trial→paid clears ~35-40%.
   **FOUNDER DECISION (2026-07-17): no trial — pay-upfront stays.**
   The save-moment ladder + first-24h proof carry conversion; the
   weekly door is the commitment-averse path.
3. **Weekly is your honest front door**, not a leak — the cohort
   buys reversibility at a 2.4x premium. The LTV answer is a day-6
   weekly→quarterly upgrade moment fed by her own kept week
   (unbuilt; next round's top conversion candidate).
4. Held follow-ups: one-tap StoreKit refund request (makes the
   guarantee structural), durable "your saved price" wall row,
   day-0 push re-aim to data receipts ("your first overnight
   window is ready").
