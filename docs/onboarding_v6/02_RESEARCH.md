# Onboarding v6 — Research Digest

2026-08-02. Three independent web-research lanes, run before any
design decision (founder brief: "research before making decisions").
Full citations live with each claim; this digest keeps only what
changes decisions.

## Evidence classes + the no-forecast rule (release pass, F-audit)

Every number below carries one of these classes — read them as
DIFFERENT kinds of knowledge, not one:
- **[A/B]** a controlled experiment someone ran and reported. Only
  as strong as its reporter; single-company results (Blinkist,
  Runtastic) measure THAT product's audience and baseline.
- **[Bench]** an observational platform benchmark (RevenueCat /
  Adapty / Superwall aggregates). Correlational: apps that choose a
  pattern differ from apps that don't. Benchmarks rank hypotheses;
  they do not establish causation.
- **[Case]** a single product's before/after story, usually
  self-reported (Instories, PrayerLock). Weakest quantitative class.
- **[F]** founder-claimed, unaudited (Cal AI's "+10% interstitials").
- **[Consensus]/[Theory]** expert convergence / mechanism argument.

**No external number in this document is a prediction for Jeni.**
They justified DESIGN choices; Jeni's own numbers come only from the
v6 production funnel (03_RELEASE.md defines the events and the
metrics that gate the next decision). Statements like "the +37%
shape" name the pattern's source, not an expected lift here.

## Lane 1 — competitor teardowns

Nine funnels, verified-provenance pass (2025-2026 state). Two
reframing facts: **Cal AI was acquired by MyFitnessPal** (closed Dec
2025 — the incumbent bought the insurgent funnel), and **Cal AI was
briefly removed from the App Store in April 2026 over deceptive
billing design (weekly-equivalent price more prominent than the
billed amount, trial toggle obscuring auto-renewal, decline
rerouting) and reinstated after it changed the flagged billing
patterns** — the enforcement was real, and so was the correction
path. Glowly is already dead (removed within ~6 months) — the
blur-gate category consumes its own apps. Jeni's honesty mechanics
are survival infrastructure, not just brand.

**What each funnel teaches (compressed):**
- **Cal AI** (~28 screens, 2.5 min; 87% of installs see the wall,
  57% initiate [Case — Superwall client study]): animated
  "research-backed" interstitials between questions lifted
  conversion ~10% [F — founder-claimed, unaudited]; a speed slider
  live-updates her goal date; the plan is shown then gated. Its
  cheapeners (hidden dynamic pricing, spin-wheel discounts, $0.99
  streak restore, pre-value rating ask) are the do-not-copy list —
  the April 2026 removal-and-reinstatement above is what enforcement
  of that list looks like.
- **Noom** (113 screens, web2app): projection updates live as she
  answers; "selective empathy" acknowledgments fire off sensitive
  answers; processing theater before the wall. Carries a $56M
  auto-renewal dark-pattern settlement and stale 2021 social-proof
  counters — converts brilliantly AND is the cautionary tale.
- **PrayerLock**: founder tripled onboarding length (~5→15 min) and
  conversion rose [Case — founder-reported, no controls]; the
  product is itself a commitment device. Its guilt framing is the
  exact anti-shame anti-pattern.
- **Hallow** ($40M/yr): the patron purchase — a published founder
  essay on why they charge + scholarship path turns the paywall
  into patronage. The letter register fits a brand that signs
  "— jeni".
- **Bible Chat** ($15M ARR): denomination + named struggles in the
  first minute = identity alignment that earns disclosure; the
  personalized artifact is experienced BEFORE pricing.
- **MyFitnessPal**: the anti-quiz (utilitarian calculator) + gates
  ratcheting paid (barcode 2022, photo-scan 2026) = durable public
  anger; it bought Cal AI rather than fix its own funnel. Freemium
  ratchets are the most reputation-expensive lever.
- **WeightWatchers** (post-Chapter-11; clinical +42% YoY while
  behavioral −25%): five-step eligibility funnel with board-certified
  clinician review converts a MEDICAL decision on authority devices —
  then undercuts six decades of authority with "$10 today / save
  66%" coupon banners ON THE SAME PAGE as Lancet citations. The
  single most instructive anti-pattern for a premium clinical brand.
- **MacroFactor** (35k→400k users on word-of-mouth): published
  methodology under a NAMED expert including failure cases;
  **adherence neutrality as written doctrine** (no red numbers, no
  shame pop-ups, no "compensate for yesterday" — with the research
  cited). Trust-by-transparency at product level. Its ceiling:
  no funnel warmth, niche scale — Jeni gets to have both.
- **Hinge** ($690M FY2025, +25%/yr): "designed to be deleted" is
  operational (the We Met loop measures real-world outcomes and
  feeds ranking + marketing). Selling the END state is the deepest
  trust signal an engagement-farmed competitor cannot copy. Its one
  backlash: a $50/mo tier that read pay-to-be-seen.
- **Feeld** (£49M, profitable): editorial design taste as the safety
  signal for a vulnerable topic; privacy features ARE the paid
  product. Proof that premium register converts where the subject
  is sensitive — and that reliability is the bar premium sets.

**The synthesis ranking (10 patterns, fit-filtered for Jeni):**
1. Long personalizing onboarding → hard paywall (validates v5
   architecture; 5x download-to-paid vs freemium, identical
   retention).
2. The dated-outcome plan reveal selling HER plan (honest-projection
   form only).
3. Honest-trial/renewal transparency, monetized (Blinkist; already
   Jeni's constitution).
4. Personalization visibly REAL ("because you said X" receipts —
   shipped; the delta is density).
5. Authority by transparency (publish how the plan is computed,
   named sources; the MacroFactor move at WW-grade stakes).
6. Identity/cohort alignment in the first 60 seconds + **the stated
   refusal** ("what this app will never do to you") as positioning.
7. Consented real outcome-proof loops (the only social proof
   compatible with the no-fabrication law; long lever).
8. Patron framing of the subscription (founder-letter register;
   candidate, founder-gated).
9. Outcome-selling: designed to be outgrown (the program has an end;
   latent in product, unexploited in funnel copy).
10. Web2app quiz funnel for paid acquisition (infrastructure
    program; out of v6 scope, noted for the founder).

**Do-not-copy list (all constitution violations, all documented in
the wild):** fake countdowns · blur-gates/curiosity taxes · billing
prominence games + decline rerouting (the Cal AI removal conduct) ·
hidden/dynamic pricing · fabricated or stale social proof ·
guilt-flip framing · streak-shame economics · pre-value rating asks.

## Lane 2 — conversion science (the numbers)

**Benchmarks that define "dramatically better":**
- Hard-paywall apps: download → paid D35 median **10.7%**, top
  quartile **>20%**, P90 38.7% [Bench, RevenueCat SOSA 2026]. Hard
  paywalls earn 8-9x freemium revenue-per-install.
- Onboarding paywall open → purchase: single-page **9.07%** vs
  multi-page value-recap-then-price flows **12.41% (+37%)** across
  40M+ opens Feb-May 2026 [Bench, Superwall]. Only 24% of paywalls
  use the winning shape.
- 82-90% of all trial/purchase starts happen Day 0 [Bench, RC +
  Adapty] — the end-of-onboarding wall IS the business.
- H&F realized LTV per payer: $24 median month-1, top quartile >$39;
  high-priced apps convert BETTER (2.8% vs 1.4% D35) and hold 5.4-6x
  value — premium pricing co-selects for intent [Bench, RC 2026].
- Weekly-dominant monetization ≈ 1/3 the LTV of annual-dominant at
  equal CPI; 68% of H&F subscriptions sold are yearly [Bench].

**The five most decision-relevant findings:**
1. **Longer onboarding converts better until diminishing returns.**
   Lose It! A/B'd length repeatedly: "trial rates went up double
   digits as onboarding got longer" [A/B]. Instories +15.4%
   install→sub from LENGTHENING with personalization + progress +
   build screen [case]. Noom runs 113 screens. The mechanism is not
   sunk cost — it is give-back density: every sensitive answer earns
   acknowledgment, education, or a visible plan improvement. "Length
   isn't the enemy; emptiness is." Drop-off clusters at cliffs (first
   3 screens, sensitive asks without reassurance, permission dialogs,
   account walls), not per-screen.
2. **Transparency beats pressure — measured.** Blinkist: visible
   close, plain trial timeline, promised reminder → **+23% trial
   starts, −55% complaints** [A/B — single company, self-reported
   via Growth.Design; strong directionally, its magnitude belongs
   to Blinkist's audience]. The most on-brand result in the corpus:
   Jeni's anti-dark-pattern constitution is a conversion ASSET.
   Fake countdowns and fabricated proof are the only two high-usage
   tactics excluded by our laws, and both have honest substitutes
   with equal or better measured performance.
3. **One REAL proof element at the wall.** Runtastic swapped
   marketing claims for genuine user reviews + stars: **+44% paid
   subscriptions** [A/B, single app]. One element beats three;
   perceived-authenticity peaks at 4.2-4.5 stars, not 5.0.
4. **Plan pre-selection + decoy + per-week reframe all validated**
   [Bench + academic field experiments, Gourville "pennies-a-day":
   temporal reframing 10-40% more effective]. Jeni already ships all
   three (yearly pre-selected + badged; weekly as annualized-truth
   decoy; per-week lead numerals). Exit offers recover 8-15% of
   abandoners and account for ~17% of revenue where used [Bench] —
   Jeni already ships the downsell + reclaim row.
5. **Permission dialogs inside the install→wall corridor are
   measured killers.** ATT at cold open converts <15% vs ~65%
   contextualized post-value; push opt-in 6% → 74% when asked
   post-decision with a concrete payload [A/B, Blinkist]. Jeni's
   nudge ask (post-commitment, her promise as payload) is the
   textbook winning shape. ATT currently fires MID-LOADER at the
   reciprocity peak — an attribution-vs-conversion trade
   (→ founder decision F3 in 00_DIRECTION).

**Trial economics (context for the keep wall):** ≤4-day trials
convert their pool at 25.5% median with 55.4% Day-0 cancels vs 37.4%
for 5-9-day trials [Bench]. Jeni sells NO trial (2026-07-07 keep
wall). The benchmark argues a 7-day-trial arm is worth an A/B —
founder decision F4; nothing in v6 presumes it.

**Quiz-length verdict:** the founder brief's "around 3-4 screens"
instinct is contradicted by the category's only measured length
tests. v6 keeps the ~46-beat architecture (which the brief
separately locks: "the onboarding structure itself is good") and
spends the effort on give-back density + composition variety, which
is what the evidence actually rewards.

## Lane 3 — clinical credibility mechanics

**The five laws of credible health products (2024-2026 corpus:
Ro, Calibrate, Noom Med, Found, Sequence, Function, Superpower,
Oura, Whoop, Levels, Flo, Natural Cycles, One Medical, Tia, Midi,
Evvy):**
1. **Credibility is specificity** — number + unit + source, never
   adjectives ("99% HR accuracy r² vs ECG", "93% typical use,
   Contraceptive Technology 22nd ed").
2. **Credibility is the conditional mood** — "if eligible", "if
   clinically appropriate"; the provider is the subject of clinical
   verbs, the brand only of service verbs. A product that can refuse
   is believed when it accepts.
3. **Credibility is named humans with credentials** — "140+ medical
   experts" with names beats "our experts". (Requires REAL reviewers
   — founder gate F2; never fabricate.)
4. **Credibility is honest ceilings** — cite the limit of your own
   method next to the claim (Oura shows its 79% beside
   polysomnography's own 83% inter-scorer ceiling).
5. **Fake-clinical is legally expensive** — FTC v NextMed ($150k;
   fabricated stats + fake reviews + hidden costs), 100+ FDA GLP-1
   warning letters, Whoop "medical-grade" letter, BetterHelp fake
   HIPAA seal ($7.8M). The safe path and the premium path are the
   same path: **under-claim, over-cite.**

**The anchor citation for expectations:** 5% body weight =
clinically meaningful (FDA approval bar; DPP: ~5.5% average cut
diabetes incidence 58%). Citing what SCIENCE says about bodies is
legally and tonally different from claiming what the APP delivers —
this is the compliant projection grammar. (Jeni already ships the
5-7% milestone credential row — Stage A.)

**Visual mechanics of "medical grade":** two-typeface systems (one
warm serif for voice, one neutral sans for data — Jeni's
JeniHeroSerif/DMSans split already matches; enforce serif-never-
grades-data); paper-neutral field + ink + one accent (the 1.2.0
palette IS this); reference bands behind user lines; units on every
number; honest gaps never interpolated; no decorative gradients on
data. The sage-green-soft-serif wellness uniform now reads as
PERFORMED trust — differentiation comes from data-truth styling.

**The safety gate pattern:** screening presented correctly is the
product proving it has judgment, not friction. Grammar: state the
standard before asking → "why we ask" at the moment of asking →
refusal that is real and costless → route, never dead-end → say who
it's NOT for unprompted. Jeni's relocated gate + access-for-all
adapted plans already implement most of this; v6 ceremonializes it.

**The feminine-premium-clinical intersection** (Tia, Midi, Evvy,
Oura, Natural Cycles): warmth lives in voice, environment, pacing;
rigor lives in numbers, names, conditionals — **they never trade
places**. Emotional validation sentence first, institutional
citation second. The softest brands carry the hardest tables. This
is the register law for every v6 copy decision — and it resolves
the lowercase question: lowercase stays (voice = warmth), rigor
arrives through what the sentences SAY.

## What this means for v6 (one paragraph)

Jeni's architecture already matches the measured winning shape
(long generous quiz → earned reveal → transparent decision wall +
exit offer). The gaps the evidence funds: give-back density in the
quiz, a value-recap arc at the wall (the +37% shape), one REAL
proof element (founder-gated), reveal surfaces that carry the
current product truth with hero-grade craft, and a copy register
that moves every sentence from warm-generic to warm-specific
(unit + source + conditional). Everything else shipped is validated
— evolve, don't replace.
