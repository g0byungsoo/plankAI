# R3 — Competitor friction and retention, 2025-2026

Researched 2026-09-04 via live web search. Scope: recent user sentiment (App Store /
Google Play reviews, Reddit-sourced sentiment analyses, Trustpilot, forums, press,
court filings) for MyFitnessPal, Lose It!, MacroFactor, Cronometer, Cal AI, BetterMe,
Shotsy, MeAgain, Happy Scale, Fastic, Simple — plus abandonment research and the
2025-2026 product-move ledger. Every claim carries its source URL. Quotes are as
reported by the cited source.

---

## 1. What people complain about, per app (2025-2026)

### MyFitnessPal — the trust collapse deepened into litigation

The category's reference brand is now the category's reference cautionary tale, and
in 2026 the complaints stopped being anecdotes and became a measured distribution
and two lawsuits.

- **The May 1, 2026 paywall move**: scan-a-meal photo logging, recipe URL import,
  and macro-by-meal goal tracking moved behind Premium while the app kept marketing
  itself as "free." A class action filed in the Northern District of California
  alleges deceptive "free" marketing; it challenges the categorization, not the
  right to monetize. User reaction ran across r/loseit, r/CICO, and MFP's own
  forums — "downgrading workflows, switching apps, or reluctantly paying."
  (https://consumertechwire.com/news/myfitnesspal-class-action-may-2026-paywall-changes/)
- **A separate privacy class action survived dismissal** (Shah v. MyFitnessPal,
  N.D. Cal., order Jan 27, 2026): advertising cookies placed after users expressly
  opted out; claims for invasion of privacy, intrusion upon seclusion, unjust
  enrichment allowed to proceed.
  (https://topclassactions.com/lawsuit-settlements/lawsuit-news/myfitnesspal-class-action-over-tracking-cookies-survives-dismissal/,
  https://case-law.vlex.com/vid/shah-v-myfitnesspal-inc-1103498703)
- **The measured complaint distribution** (unstar.app, July 2026; 202 negative
  reviews of 300 recent US Google Play reviews analyzed; 35 of 49 newest App Store
  reviews were 1-3 stars):
  - paywall / Premium issues **29%**
  - barcode scanner paywalled **13%**
  - 2026 UI redesign problems **11%** — "You turned simple tasks into 4-5 clicks
    instead of 1-2. Tracking food should be fast, not a scavenger hunt"
  - sync failures **10%**, ads in free tier **9%**, logouts / lost history **8%**
  - broken food search **7%** — "Lentils? Don't exist. Different flavor of yogurt?
    Never heard of it"
  - billing after cancellation **5%**
  - the signature quote: *"Making barcode scanning premium after users built the
    database is classic enshittification."*
  - and the verdict that matters most: **paying subscribers report the identical
    crashes, logouts, and search failures as free users** — Premium ($79.99/yr;
    Premium+ $99.99/yr) mostly "buys back the scanner."
  (https://unstar.app/blog/is-myfitnesspal-premium-worth-it-paywall-app-reviews-2026)
- Reviewer-named exits: Cronometer, Lose It!, FatSecret, MyNetDiary. A 2026 review
  concluded MFP Premium is "competing on brand loyalty rather than feature value" —
  everything it unlocks "is available for free or cheaper elsewhere."
  (https://www.amyfoodjournal.com/blog/myfitnesspal-review)

### Lose It! — ads, Snap It's double disappointment, database rot

- Most common complaint: **full-screen interstitial ads interrupting logging** on
  the free tier, with rising ad density.
- **Snap It (photo logging) is Premium-only** — users install *because* they heard
  about photo logging, discover the gate within a day or two; "the gap between
  marketing and free-tier reality is a recurring criticism."
- Among those who **paid** for Snap It, **accuracy is the top complaint**:
  misidentified foods, inconsistent portions, frequent manual correction; the model
  is judged behind the 2025-2026 AI-first apps.
- **Paywall creep**: long-tenure users list macros (once free), reports, meal
  scanning, planning as progressively moved behind Premium.
- **Database quality**: duplicates, mislabeled items, wrong portion sizes, "no
  reliable way to verify accuracy."
- What still earns praise: "the cleanest, simplest, most approachable calorie
  tracking app on iOS," a fast barcode scanner, the weight graph, community
  challenges.
  (https://nutrola.app/en/blog/what-do-reddit-users-say-about-lose-it-2026,
  https://nutriscan.app/blog/posts/lose-it-premium-worth-it-2026-who-should-pay-4eb070ea9d)

### MacroFactor — loved for honesty, dinged on price and no camera

- Complaints: **price** (subscription, no permanent free tier) is the #1
  reservation in 2026 threads; **no AI photo logging** is #2 and growing as
  multimodal became table stakes; English-mostly localization; beginner overwhelm.
- Praise (the retention story, see §2): the adaptive TDEE algorithm "feels
  **honest** — it does not pretend to know your metabolism better than your own
  data"; Stronger By Science credibility; in-app education that teaches energy
  balance instead of demanding obedience.
  (https://nutrola.app/en/blog/what-do-reddit-users-say-about-macrofactor-2026)

### Cronometer — small frictions, big trust

- Complaints are mostly mechanical, filed on its own forums: device/integration
  sync bugs (Garmin, Qardio), macros not summing to calories in edge cases,
  water entries changing on locked days, exercise-data quirks.
  (https://forums.cronometer.com/discussions/p15)
- The trust engine that mutes those complaints: **no user-submitted entries in the
  main database** (970K verified entries vs MFP's 14M crowd entries), seven
  lab-analyzed sources (USDA, NCCDB, CNF, NUTTAB, CoFID, NEVO, IFCDB), 84
  nutrients — and the company has been **independent, not VC-funded, not acquired,
  not pivoting since 2011**.
  (https://calorie-trackers.com/reviews/cronometer/, https://clinicalappreport.com/en/reviews/cronometer/)
- Notable 2025-2026 fix: energy setting now auto-resets to maintenance when the
  weight goal is reached — a long-requested transition users said "threw them off"
  when it was instant/manual elsewhere.
  (https://forums.cronometer.com/discussion/2003/automate-weight-gain-loss-calorie-deficit-settings)

### Cal AI — the speed champion whose billing nearly killed it

- **Apple removed Cal AI from the App Store in April 2026** for: bypassing IAP via
  embedded Stripe checkout; deceptive billing design (weekly-equivalent price shown
  more prominently than the actual charge); manipulative flows (declining the first
  offer routed users into a different purchase flow). Restored after fixes.
- Accuracy complaints: inconsistent re-scans (same plate, different number),
  overestimated portions, weak on home-cooked and mixed dishes, misreads
  (ground turkey as ground beef); price hidden until after the onboarding quiz.
- Praise: **speed** ("actually stick with this one" after abandoning traditional
  trackers), barcode scanning, polish; post-acquisition it now sits on MFP's 20M
  foods / 68,500 brands.
- Scale: ~4.8 stars across ~337K iOS ratings, ~15M downloads, $30-50M annual
  revenue ($50M ARR per the founder). MFP's CEO on the positioning: *"Cal AI is
  for those preferring speed over accuracy."*
  (https://calzy-app.com/blog/cal-ai-review,
  https://techcrunch.com/2026/03/02/myfitnesspal-has-acquired-cal-ai-the-viral-calorie-app-built-by-teens/)

### BetterMe — the billing complaint factory

- The dominant complaint class is **subscription capture**: charges continuing
  after cancellation (one user billed 6 months after same-day cancel), $8/week
  charges "without approval," payment info saved without consent, 50% refund
  offers under pressure, password-reset links that never arrive so accounts can't
  be accessed to cancel. Context: the FTC found ~76% of subscription apps use at
  least one dark pattern.
  (https://www.sikayetvar.com/en/betterme-us/betterme-fails-to-cancel-subscription-or-refund-unauthorized-charges,
  https://complain.biz/betterme/, https://discussions.apple.com/thread/254944758)

### Shotsy — the free, single-purpose darling

- Praise: the **estimated-medication-level curve** ("really fascinating to
  follow"), clarity without overwhelm, "the most comprehensive GLP-1 tracker,"
  side-effect list users bring to their doctor, and **free** core.
- Friction: deliberately narrow — injections/site rotation/reminders only; users
  pair it with a food app. (Jeni note: the curve users love is the modeled-PK
  surface Jeni refused on measured-vs-modeled grounds; the pull is real even if
  the physics is theater.)
  (https://apps.apple.com/us/app/shotsy-glp-1-tracker/id6499510249,
  https://learnmuscles.com/blog/2025/11/27/6-best-glp-1-tracking-apps-compared-which-app-actually-works-in-2026/)

### MeAgain — all-in-one GLP-1, high floor, PR-heavy

- 4.8 stars / ~25K App Store ratings; praised as all-in-one (shots/pills, sites,
  food, protein, fiber, water, side effects, weight, progress photos, AI coach).
  *"Unlike the barebones app from my semaglutide provider (which only tracks
  weight and doses), this one is incredibly useful."* Public friction is thin —
  much of its visibility is syndicated press naming itself #1.
  (https://apps.apple.com/us/app/meagain-glp-1-tracker-app/id6744178534,
  https://meagain.com/, https://longeviters.com/apps/meagain-app-review)

### Happy Scale — the anti-anxiety instrument people keep for a decade

- Users report using it "for YEARS… the best weightloss tracking app I have seen."
  Built by one developer for 11+ years (now a team of three). Design philosophy in
  the developer's own words: **"reduce the anxiety around weighing yourself"** via
  smoothing/averages; customization (e.g., changing the color of gains) exists to
  **"protect your psychology when things aren't going as planned"**; the long-term
  perspective is the product. Retention comes from "refinement… just as important
  as addition." iOS-only remains the limitation.
  (https://www.tiktok.com/discover/happy-scale-app-review,
  https://indie.watch/issue-34-happy-scale-by-russ-shanahan/,
  https://syntopikon.substack.com/p/an-interview-with-russ-shanahan)

### Fastic / Simple — cancellation black holes and a coach that contradicts itself

- **Fastic**: Trustpilot is dominated by cancellation/refund failure — repeated
  unanswered emails since December, charges without use, "service cancelled but
  no refund," deleting-the-app-isn't-cancelling confusion.
  (https://www.trustpilot.com/review/fastic.com)
- **Simple** (AI coach "Avo"): bulk sentiment is positive (11,616 Trustpilot
  reviews, "keeps me honest and focused"), but the revealing complaints are tone
  integrity and tooling: *"When telling Avo that you can't weigh in, you're always
  prompted to do it anyway after she tells you it's ok"* — the coach says the kind
  thing and the system does the nagging thing — plus "the scan function doesn't
  work."
  (https://www.trustpilot.com/review/simple-life-app.com,
  https://apps.apple.com/us/app/simple-ai-weight-loss-coach/id1467720176)

---

## 2. What keeps people for months/years

Four distinct retention engines show up in long-tenure testimony:

1. **The app tells the truth about ME** (MacroFactor). The adaptive expenditure is
   praised as "honest… it does not pretend to know your metabolism better than
   your own data." Long-term users stay because the number *responds* to their
   record, building understanding, not obedience.
   (https://nutrola.app/en/blog/what-do-reddit-users-say-about-macrofactor-2026)
2. **The data can be trusted forever** (Cronometer). Verified-only database, a
   14-year-stable curation method, and an independent company that is "not
   acquired, not pivoting." Trust in the institution is part of the retention.
   (https://calorie-trackers.com/reviews/cronometer/)
3. **The app protects my psychology** (Happy Scale). Smoothing exists to remove
   weigh-in anxiety; the interface literally lets you recolor bad news. A decade
   of refinement over feature-chasing. Users measure tenure in years.
   (https://syntopikon.substack.com/p/an-interview-with-russ-shanahan)
4. **The app is instant and frictionless** (Cal AI's one retention claim; Lose It
   praise). "I actually stick with this one" is about seconds-per-meal, and Lose It
   users cite the fast scanner and clean iOS design as why they stay despite ads.
   (https://www.intakenutrition.io/blog/is-cal-ai-accurate-what-public-reviews-and-ai-research-actually-suggest,
   https://nutrola.app/en/blog/what-do-reddit-users-say-about-lose-it-2026)

Common thread: none of the four is a streak, a badge, or a coach persona. They are
honesty, data custody, psychological safety, and speed.

---

## 3. Why people abandon trackers after weeks

The strongest 2025 evidence is the **UCL + Loughborough study** (British Journal of
Health Psychology, Oct 22, 2025): AI-assisted analysis of 58,881 tweets about five
apps (MyFitnessPal, Strava, WW, Muscle Booster, FitCoach), 13,799 negative posts.

- Users reported **shame, disappointment, demotivation** — some abandoning health
  goals entirely, not just the app.
- Named mechanisms: **rigid calorie targets** and unrealistic algorithm-generated
  goals ("If you allow [MFP] to prescribe your calories you'll end up with a
  deficit that's unachievable"); **feeling "pestered" by notifications**;
  **loss of streaks triggering avoidance**; **guilt from logging "unhealthy"
  foods**.
- What users wanted instead: wellbeing-oriented, intrinsically motivated,
  personalized guidance.
  (https://www.eurekalert.org/news-releases/1102616,
  https://www.ucl.ac.uk/news/2025/oct/emotional-strain-fitness-and-calorie-counting-apps-revealed)

Supporting numbers from adjacent research and syntheses:

- Logging burden: **15-20 minutes/day**, with "behavioural fatigue" the primary
  disengagement driver; only **~23%** of people who start calorie tracking are
  still tracking at 6 months.
- **Perfectionism is the leading psychological predictor of abandonment** —
  perfectionist trackers reported 3.1× more likely to quit within 30 days than
  "good-enough" trackers; missing one day doesn't hurt habit formation, but the
  **guilt of a broken streak** frequently ends the behavior entirely.
- For users with dieting history, tracking apps "exacerbate cycles of restriction,
  binging and guilt"; app-for-weight users report more all-or-nothing thinking and
  food preoccupation.
  (https://www.hootfitness.com/blog/why-most-people-quit-food-logging-(and-how-to-make-it-stick),
  https://kcalm.app/blog/psychology-of-calorie-counting/,
  https://pmc.ncbi.nlm.nih.gov/articles/PMC5332530/,
  https://nutrola.app/en/blog/food-guilt-and-calorie-tracking-therapist-approved-approach)

The abandonment story and the retention story are mirror images: people leave when
the product grades an imperfect week; they stay when it explains one.

---

## 4. AI photo logging in 2026 — the user verdict

- **Accuracy band is now well characterized**: image-based estimates land within
  ~10-30% of truth — simple separated foods 10-15% error; mixed dishes (curry,
  burrito, creamy pasta, casserole) 25-30%+; hidden cooking fats are the single
  biggest miss; restaurant meals are the repeated pain point. Context defenders
  cite: human self-report underestimates by 20%+ anyway.
- **The trust-breakers are inconsistency and confidence**: the same meal
  photographed twice returning different numbers, and confident misjudgment of
  mixed dishes, do more damage than the average error size.
- **What users do when it's wrong**: edit the AI's guess (which "meaningfully
  improves results"), add a note like "cooked in a tablespoon of olive oil," and
  fall back to barcode for packaged items. Users who treat the number as "a
  starting point rather than a verdict" report satisfaction; users who expected
  precision churn.
- The verdict in one sentence, from MFP's own CEO after buying the category
  leader: *"Cal AI is for those preferring speed over accuracy."*
- **Billing distrust contaminates accuracy trust**: Cal AI's April 2026 App Store
  removal for deceptive billing sits next to its accuracy complaints in reviews;
  Lose It's Snap It shows the second failure mode — pay first, *then* discover the
  accuracy ceiling.
  (https://www.intakenutrition.io/blog/is-cal-ai-accurate-what-public-reviews-and-ai-research-actually-suggest,
  https://calzy-app.com/blog/cal-ai-review,
  https://nutrola.app/en/blog/what-do-reddit-users-say-about-lose-it-2026)

---

## 5. The 2025-2026 product-move ledger: backlash and praise

| Move | Date | Reception |
|---|---|---|
| **MFP moves scan-a-meal, recipe import, macro-by-meal behind Premium** | May 1, 2026 | Backlash → class action over "free" marketing; forum exodus threads; the defining negative move of the period (https://consumertechwire.com/news/myfitnesspal-class-action-may-2026-paywall-changes/) |
| **MFP 2026 winter redesign** | Feb 2026 | Backlash: "4-5 clicks instead of 1-2" on the core task; 11% of negative reviews (https://unstar.app/blog/is-myfitnesspal-premium-worth-it-paywall-app-reviews-2026) |
| **MFP GLP-1 Support** (med logging, reminders, side effects) — **free for all users** | Apr 28, 2026 | Neutral-positive; notable asymmetry: the GLP-1 surface is free while food features got paywalled — GLP-1 is the acquisition wedge now (https://www.mobihealthnews.com/news/nutrition-app-myfitnesspal-announces-tools-glp-1-medication-support) |
| **MFP AI Coach** (Premium/Premium+ iOS) | Jun 2026 | Muted; framed as answering "what should I eat" from your own history; reviewers already skeptical Premium competes "on brand loyalty rather than feature value" (https://9to5mac.com/2026/06/16/myfitnesspal-adds-ai-powered-coach-for-personalized-nutrition-guidance/) |
| **MFP acquires Cal AI** (~$50M ARR, teen founders retained) | Dec 2025, announced Mar 2, 2026 | Industry-praised consolidation; Cal AI stays independent, gains MFP database (https://techcrunch.com/2026/03/02/myfitnesspal-has-acquired-cal-ai-the-viral-calorie-app-built-by-teens/) |
| **Apple pulls Cal AI** (Stripe bypass, deceptive billing, manipulative flows) | Apr 2026 | Public enforcement precedent — platform now polices subscription dark patterns in this category (https://calzy-app.com/blog/cal-ai-review) |
| **Lose It ground-up redesign** ("biggest update in a decade") + **Photo Logging 2.0 to GA** | Apr 2026 | Mixed-positive on design; Snap It paywall + accuracy still the sore spot (https://consumertechwire.com/news/lose-it-photo-logging-2-promoted-to-ga/) |
| **Lose It GLP-1 Logging** (meds incl. estimated med-level curve, protein/fiber targets) — Premium | 2026 | Quiet; mainstream trackers now copy Shotsy's curve (https://loseit.zendesk.com/hc/en-us/articles/50221250242964-GLP-1-Logging) |
| **WeightWatchers GLP-1 Med+ integrated platform** (prescribing + nutrition + coaching + community) | Dec 16, 2025 | Positive survey PR; criticism: strict **12-month commitment, no early cancel**, meds cost separate, cash-pay disadvantage (https://hitconsultant.net/2025/12/17/weight-watchers-launches-new-glp-1-program-and-ai-app-features/, https://bestguide.com/review/weightwatchers/) |
| **Cronometer auto-switch to maintenance at goal** | 2025-2026 | Praised; closed a years-old forum request (https://forums.cronometer.com/discussion/2003/automate-weight-gain-loss-calorie-deficit-settings) |
| **UCL/Loughborough emotional-strain study lands in press** | Oct 2025 | Reframed streaks/notifications/rigid targets as harms in mainstream coverage — external validation for anti-shame design (https://www.ucl.ac.uk/news/2025/oct/emotional-strain-fitness-and-calorie-counting-apps-revealed) |

---

## 6. The whitespace — what nobody does well and users keep asking for

1. **The GLP-1 off-ramp.** "Food noise does come back if you come off the
   medicine… its return can feel like losing a safety net" (MUSC, Apr 2026). No
   mainstream tracker has a discontinuation/transition capability; clinicians call
   the companion-app evidence base thin and name nutritional adequacy on GLP-1s
   (muscle loss, protein/micronutrient deficiency) as the unmanaged risk
   (Medscape 2026; an active clinical trial NCT07554417 exists precisely because
   apps don't cover it).
   (https://www.musc.edu/content-hub/News/2026/04/06/coming-off-glp-1s,
   https://www.medscape.com/viewarticle/glp-1-apps-helpful-companions-or-false-sense-security-2026a1000i9n,
   https://clinicaltrials.gov/study/NCT07554417)
2. **Protein/lean-mass adequacy under appetite suppression**, treated as a
   first-class product goal rather than a target line. Trackers highlight protein;
   none is built around "eating enough is the hard part now."
3. **Non-punitive imperfection.** The BJHP study, the perfectionism-abandonment
   data, and the Simple/Avo contradiction all point at the same hole: an app that
   structurally cannot shame you (no streaks, no red, absence ≠ zero, missed days
   explained not graded) is still rare enough to be a differentiator.
4. **Data portability.** No major tracker supports direct import of another's
   export; MFP's most complete export is web-only and partly behind Premium;
   Lose It buries export in its website. "Which apps let you leave?" is now a
   review-site genre. Custody is a trust wedge nobody claims.
   (https://nutriscan.app/blog/posts/nutrition-app-data-export-options-2026-6d34327efa,
   https://calorie-apps.com/articles/export-myfitnesspal-history-migration-guide-2026)
5. **The maintenance era.** Cronometer just automated the deficit→maintenance
   switch; nobody has built the *product* for the person who arrived (identity,
   grammar, and goals after the loss). WW's answer is a 12-month contract.
6. **Low-effort capture for low-energy users.** Voice/words logging is repeatedly
   framed as the GLP-1-friendly door — "those on Ozempic… don't have the energy to
   type a meal three times a day" — yet remains an afterthought or paywalled
   add-on in mainstream apps.
   (https://www.healthyoneapp.com/blog/best-voice-food-tracker-app-2026,
   https://calorie-apps.com/articles/calorie-tracking-with-adhd-2026)
7. **AI that shows its uncertainty and remembers corrections.** The 2026 verdict
   is "estimator, not verdict" — but no major app *presents* it that way; users
   discover the epistemics through disappointment, and corrections rarely persist
   into memory.

---

## What this means for Jeni

### Ranked opportunities

1. **Own the honesty position the market just vacated.** MFP converted its trust
   into lawsuits; Cal AI got pulled for billing design; BetterMe/Fastic are
   cancellation complaint factories. Jeni's pay-upfront, no-dark-pattern,
   billed-today-everywhere stance is now a *market* differentiator, not just an
   Apple-compliance one. Say it plainly at the wall; never let a shipped feature
   move behind an upgrade (the MFP class action is the legal ceiling on that
   move).
2. **Ship the "estimator, not verdict" grammar as visible product.** Users' stable
   AI verdict: fast, useful, wrong on mixed dishes/oils, and trustworthy only when
   editable. Jeni already has verbatim stated numbers, corrections that persist,
   usuals memory, provenance lines, absence honesty — the gap competitors can't
   close quickly is *presented epistemics* (why this number, how sure, what would
   fix it) plus rescan consistency. This is the food moat; MacroFactor's
   "honest algorithm" testimony proves honesty itself retains for years.
3. **Build the GLP-1 off-ramp.** Nobody has it; clinicians name it; users fear it
   ("losing a safety net"). Jeni already carries `medication_ended_v1` and the
   food-noise-return signature observation — this is one era from being the only
   product with a real discontinuation companion (paired with the maintenance-era
   founder flag).
4. **Lead with protein adequacy under suppression as the product's spine, out
   loud.** The clinical world's #1 stated worry about GLP-1 companions (muscle
   loss, under-eating protein) is Jeni's existing §9 law and count-up-never-"over"
   grammar. Market-validate it in copy and the packet; it's defensible because it
   is arithmetic over her record, not content.
5. **Anti-shame as a stated law, not an absence.** BJHP 2025 gives citable cover:
   streak loss, notification pestering, and rigid targets measurably end health
   attempts. Jeni's never-a-grade / no-streak / interruption-policy laws are the
   retention design the study prescribes — the opportunity is making the
   difference perceptible in the first week (the Simple/Avo lesson: the *system*
   must be kind, not the copy — Jeni's one-director/discharge rules are exactly
   this, keep them absolute).
6. **Data custody as a trust feature.** A clean export (record, corrections,
   provenance) costs little and positions against the "which apps let you leave"
   genre; it also reinforces claim #1.
7. **Words/voice door as the GLP-1 capture story.** The market keeps saying
   low-energy users need sub-10-second, no-typing capture. Jeni's words door +
   usuals is already this; consider it the headline capture claim over the camera.

### Confirmed traps

- **Never relocate the record or the scanner.** The paywall-move backlash is now
  litigated, measured (29% + 13% of MFP's negative reviews), and the single
  fastest trust-burn in the category. (Standing Jeni law since p62 — now with a
  court docket behind it.)
- **Never add taps to the core loop.** MFP's redesign complaint ("4-5 clicks
  instead of 1-2") drew 11% of its negative reviews on its own.
- **No streaks, XP, adherence grades, or guilt-shaped pushes** — the BJHP study
  turned these from taste into documented harm; perfectionist users are the
  likeliest quitters and the product must absorb imperfect data gracefully.
- **No modeled-PK curve** despite its popularity (Shotsy, now Lose It): it's the
  category's most seductive piece of measured-looking theater. Jeni's
  refusal stands; the need it serves ("is it working / when does it wane") should
  be answered from her record (cycle position, waning band) instead.
- **No billing cleverness of any kind.** Apple is now enforcing (Cal AI pulled);
  the FTC's 76% dark-pattern figure means clean billing is rare enough to notice.
- **No 12-month commitments** (WW's most-cited criticism) and no "free" language
  anywhere near a paid gate.
- **Don't ship an "AI Coach" as a premium upsell persona.** MFP's lands as brand
  theater; the retained products (MacroFactor, Cronometer, Happy Scale) win with
  explanation, custody, and psychological safety — Jeni's jeni-reads-the-record
  approach is the right shape; keep it grounded in her numbers, never a paywalled
  personality.

### One-line synthesis

The 2025-2026 market punished paywall relocation, billing tricks, confident wrong
numbers, and shame mechanics — and rewarded exactly four things Jeni is already
built on: honesty about her own data, speed of capture, psychological safety, and
data custody. The open ground is the GLP-1 off-ramp, the maintenance era, and
making the honesty *visible*.
