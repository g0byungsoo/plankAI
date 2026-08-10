# R6 — Retention + notification systems in health apps (2025-2026)

Research memo for APP v25. Domain: retention loops + notification intelligence for
Jeni (GLP-1-era weight companion; known weakness W1→W2 collapse; current
notifications: medication category with taken/hour/later actions, trial-window
anchors, daily reminder; <5/week ceiling; day-2 consent gate; no dark patterns).

Evidence labels used throughout:
- **PROVEN** — RCT / peer-reviewed / disclosed first-party data with plausible causality.
- **PROMISING** — directionally supported (academic pilots, credible case studies, correlational).
- **CLAIMED** — company or vendor numbers, no methodology; selection effects likely.
- **CONVENTION** — industry consensus practice; weak public evidence but low risk.
- **GIMMICK** — novelty with no retention evidence; often actively harmful.

---

## 1. Benchmarks: where health/weight apps actually sit

- Health & fitness category averages: **D1 ~23-27%, D7 ~7-10%, D30 ~3-4%**
  ([Business of Apps benchmarks](https://www.businessofapps.com/data/health-fitness-app-benchmarks/),
  [Lovable retention guide](https://lovable.dev/guides/what-is-a-good-retention-rate-for-an-app),
  [core-mba 13-vertical splits](https://www.core-mba.pro/tool-hub/mobile-app-retention)). PROVEN (aggregate panels).
- Behavior-change health apps (vs generic fitness) do far better: **D30 15-25%**; the claim
  that top performers hit **40%+ D30** by delivering visible outcome feedback is
  [CLAIMED](https://productgrowth.in/insights/healthtech/health-app-retention-guide/) but consistent
  with category spread.
- Fitness app monthly churn ~9.2% for paying subs ([RetentionCheck](https://retentioncheck.com/churn-benchmarks/fitness-apps)). CLAIMED.
- Meditation as cautionary tale: **Headspace D30 ≈ 4.7%** despite 50+ peer-reviewed efficacy studies
  ([Pauso analysis](https://www.pauso.com/blog/meditation-app-retention-rates),
  [PMC observational study](https://pmc.ncbi.nlm.nih.gov/articles/PMC10986332/)).
  Content quality does not retain; a loop does. PROMISING inference.
- Wearables show what a physiological daily loop buys: **Oura 80%+ subscription renewal**
  ([Sacra](https://sacra.com/c/oura/), [Ringing the Bell](https://ringingthebell.substack.com/p/whoop-vs-oura-the-10-billion-question)) — PROVEN (disclosed);
  **WHOOP "50%+ of members still daily at 18 months"** ([Contrary Research](https://research.contrary.com/company/whoop)) — CLAIMED.

### Where weight apps specifically lose people
1. **Days 1-14: logging fatigue.** Manual entry burden is the #1 named churn driver; most calorie-tracker
   users quit within ~3 weeks ([martechvibe week-one failure](https://martechvibe.com/article/why-health-app-retention-fails-in-week-one/),
   [Nutrola tracker retention](https://nutrola.app/en/blog/calorie-tracker-retention-rates-how-long-users-stick-with-each-app),
   [Sahha 90-day churn](https://sahha.ai/blog/health-app-churn-retention/)). PROVEN-adjacent (multiple independent sources).
   This is exactly Jeni's W1→W2 collapse window.
2. **Weeks 8-12: tracking burnout** even among motivated users — the ones who survived friction burn out
   psychologically ([Sahha](https://sahha.ai/blog/health-app-churn-retention/)). PROMISING.
3. **Seasonal resolutioner churn** (January cohort quality) ([Digital Yield Group](https://digitalyieldgroup.com/blog/health-fitness-apps-the-resolutioner-churn-problem/)). CONVENTION.
4. GLP-1-specific: engagement predicts **medication persistence** — Noom Med reports persistence of
   2.8 months (lowest engagement quartile) vs **6.2 months (highest)**; Omada's GLP-1 track reports 84%
   persistence at 24 weeks vs 42-74% real-world ([Medscape review of GLP-1 companions](https://www.medscape.com/viewarticle/glp-1-apps-helpful-companions-or-false-sense-security-2026a1000i9n),
   [Noom GLP-1 Companion](https://www.noom.com/med/glp1-companion/)). CLAIMED (selection effects), but the
   strategic point stands: for Jeni's cohort, retention IS adherence support.

---

## 2. Teardowns — the loop that defines each app

### MacroFactor — the weekly recalibration ritual
Loop: log anything → algorithm learns expenditure → **weekly check-in on a chosen day** delivers new
targets. Two design laws worth stealing:
(a) **adherence-neutral** — the algorithm never degrades or scolds when you deviate; a missed day
doesn't break the model or trigger guilt copy; (b) the coach **only surfaces information when it can
change the plan** ([check-ins intro](https://help.macrofactorapp.com/en/articles/247-introduction-to-check-ins-and-coaching-modules),
[adjustment logic](https://help.macrofactorapp.com/en/articles/222-how-does-macrofactor-make-adjustments-for-a-weight-gain-or-weight-loss-goal),
[MF Coach](https://macrofactor.com/mf-coach/)). No public retention numbers → design PROMISING, retention effect CLAIMED.
The critical property: **the weekly report ends in an adjustment, not a summary.** Reading it changes next week.

### Oura — the morning reveal
Loop: passive capture while you sleep → **morning readiness score reveal** → today's guidance. Zero
input burden; the payoff moment is anchored to a fixed daily time the user already wakes into.
80%+ renewal (PROVEN, disclosed above) is the strongest retention number in consumer health.
Mechanism inference: **passive data in, one anchored reveal moment out** ([readiness explainer](https://simplewearablereport.com/learn/metrics/readiness-score)). PROMISING as a transferable pattern.

### WHOOP — coach + weekly/monthly reflection
Loop: morning recovery score → daily strain target → **Monday Weekly Performance Assessment** +
monthly reports; WHOOP Coach (LLM) answers "why" questions on demand
([WPA](https://www.whoop.com/gb/en/thelocker/new-weekly-performance-assessment/),
[support docs](https://support.whoop.com/hc/en-us/sections/360005149993-Performance-Assessments)).
Daily-use-at-18-months claim above. The WPA compares this week vs your own 3-week average —
**self-referenced, never normative.** CLAIMED retention effect; the self-comparison grammar is CONVENTION-becoming-law in serious health products.

### Duolingo — streaks, and the 2025-2026 softening
The canonical loss-aversion loop. Claims: churn cut from 47% (2020) to ~28%; users with 7+ day
streaks 2.3x more likely to engage daily ([StriveCloud](https://www.strivecloud.io/duolingo-gamification-explained),
[TickerTrends churn analysis](https://blog.tickertrends.io/p/the-impact-of-churn-duol-duolingo),
[Lenny's/Jorge Mazal](https://www.lennysnewsletter.com/p/how-duolingo-reignited-user-growth)). CLAIMED (internal data, widely repeated).
**The correction arc matters more than the mechanic:**
- Streak **freezes/repair** added because raw streaks caused breakage-churn; teardowns report freezes
  *increase* long-term retention by lowering anxiety ([Sensor Tower](https://sensortower.com/blog/duolingo-streak-feature-app-engagement-growth)). CLAIMED.
- **June 2026 global streak revival**: lapsed users could restore their longest lost streak with 3
  lessons — streak restoration was the single most-requested feature; Duolingo explicitly treats
  lapsed users as recoverable, not churned ([ContentGrip](https://www.contentgrip.com/duolingo-streak-revival-campaign/)). PROMISING pattern.
- 2025 energy-system overhaul drew heavy backlash; critics note streaks optimize opens, not outcomes
  (4,003-day streaks without conversational fluency) ([Trophy case study](https://trophy.so/blog/duolingo-gamification-case-study),
  [donnalouissaint strategy critique](https://www.donnalouissaint.com/post/beyond-the-streak-a-product-strategy-to-fix-duolingo-s-churn-problem)).
- Notifications: bandit-optimized copy; the famous **"These reminders don't seem to be working.
  We'll stop sending them for now."** auto-silence after ~7 ignored days
  ([Duo, the Push, and the Bandits](https://vicki.substack.com/p/duo-the-push-and-the-bandits),
  [notification teardown](https://tinomwadeyi.substack.com/p/how-duolingo-perfected-the-art-of)).
  The auto-stop behavior is PROVEN-practice; the guilt-tinged copy is meme'd and off-brand for Jeni
  ([Debugger critique](https://debugger.medium.com/duolingo-needs-to-chill-8f1832745ca0)).

### Noom — the finite-curriculum trap + dark-pattern warning
Loop: daily CBT-flavored lessons. Fails structurally: **finite curriculum sold as ongoing
subscription** — after 8-12 weeks users have seen the core concepts repeatedly and churn
([SaaSweep review](https://www.saasweep.com/blog/noom-review), [Amy Food Journal](https://www.amyfoodjournal.com/blog/noom-review)). PROMISING (consistent across reviews).
Negative lesson: **~7 retention screens at cancellation**, thousands of BBB billing complaints —
direct trust damage for a health brand. What NOT to do.

### Cal AI — speed beats precision
Loop: snap → macros in seconds; everything else (streaks, badges, targets) is scaffolding around one
gesture. Retention "above 30%" (window unstated), 15M+ downloads, ~$30M ARR, acquired by MyFitnessPal
early 2026 ([Don'tSettle teardown](https://dontsettle.ai/lab/cal-ai-teardown)). CLAIMED. The
transferable law: **attack abandonment (logging cost), not accuracy** — people who log in <30s/meal
stick; minutes/meal quit. Jeni's v23 dial already embodies this.

### Simple — the daily AI check-in + visible-state surfaces
Loop: **Avo daily check-in** (mood/energy/symptoms) → plan adjustment + tasks; scale: 4.98M dialogues,
23.1M messages in Jan 2026 ([GlobeNewswire](https://www.globenewswire.com/news-release/2026/05/27/3302117/0/en/simple-s-avo-named-best-virtual-health-coach-in-medtech-breakthrough-awards-program.html),
[TechCrunch Series B](https://techcrunch.com/2025/10/01/kevin-harts-vc-firm-leads-35m-series-b-for-weight-loss-app-simple/)). CLAIMED (message volume ≠ retention).
Fasting timer lives on **Live Activity / Dynamic Island / lock screen** — the time-window-state
pattern every fasting app now ships ([Fastra](https://apps.apple.com/us/app/fastra-intermittent-fasting/id6736870610),
[LockFast](https://lockfast.io/)). CONVENTION for time-bounded states.

### Headspace — proof that efficacy ≠ retention
D30 ≈ 4.7% (above). Its one real retention signal: users hitting **10 consecutive days** show much
higher 6-month retention ([Pauso](https://www.pauso.com/blog/meditation-app-retention-rates)) — CLAIMED,
and likely selection. Lesson: a willpower-dependent single-player loop decays no matter how good the
content; the loop must ride on something that recurs by itself (for Jeni: the dose cycle).

---

## 3. JITAI literature — what's real, what's deployable

- **HeartSteps MRT** (44 adults, 6 weeks, 5 decision points/day, ~2 suggestions/day delivered):
  contextually tailored walking suggestions increased 30-min step counts; **effects decay over the
  study — habituation is real** ([Annals of Behavioral Medicine](https://academic.oup.com/abm/article/53/6/573/5091257),
  [time-varying effects analysis](https://arxiv.org/html/2410.15049v1)). PROVEN (micro-randomized trial), with decay caveat.
- Successors: HeartSteps → **JustWalk JITAI** (system-ID approach, up to 4 notifications/day targeting
  next-3-hour steps) ([JMIR protocol](https://www.researchprotocols.org/2023/1/e52161)); 2024 AJPM RCT of a
  just-in-time steps app ([AJPM](https://www.ajpmonline.org/article/S0749-3797(24)00315-5/fulltext)). PROMISING.
- **2025 BJHP scoping review**: 62 JITAIs; small benefits in physical activity + substance use;
  definitions and theory still inconsistent ([Hsu 2025](https://bpspsychub.onlinelibrary.wiley.com/doi/10.1111/bjhp.12766)). PROVEN-as-summary: effects are SMALL, not magic.
  (Older meta-analysis g=1.65 vs waitlist is inflated by weak comparators — [PubMed 31488002](https://pubmed.ncbi.nlm.nih.gov/31488002/).)
- **Receptivity**: ML timing models improve receptivity up to **~40% vs random delivery**; receptivity
  correlates with time of day, location, battery, phone interaction, personality
  ([JITAI frameworks overview](https://www.emergentmind.com/topics/just-in-time-adaptive-intervention-jitai-frameworks)). PROMISING.
- **Deployable-in-consumer-app translation** (the part that matters):
  1. Define explicit **decision points** (Jeni already has natural ones: dose day morning, post-dose
     window, her usual logging hour, weigh-in moment) — not arbitrary cron times.
  2. Use **tailoring variables you already collect** (dose schedule, last log time, sleep wake time
     from HealthKit, day-of-week pattern) — heuristics first; bandits only after volume exists.
  3. Randomize-and-log at the margin (send vs hold) so effects are measurable — micro-randomization-lite.
  4. Expect decay; rotate copy and **retire triggers that stop working per-user** (auto-silence).

---

## 4. Notification science

- **Volume thresholds.** Users receiving **>6 pushes/week from one brand were 3.4x more likely to
  uninstall within 30 days** vs 1-2/week (Klaviyo benchmark survey, n=6,200, 2026, via
  [MobiLoud stats roundup](https://www.mobiloud.com/blog/push-notification-statistics)). PROMISING (survey, large n).
  Older recycled stats (10% disable at 1/week; ~50% opt out at 2-5/week) trace to a 2010s Localytics
  survey — treat as CONVENTION, not law ([Business of Apps](https://www.businessofapps.com/marketplace/push-notifications/research/push-notifications-statistics/)).
  Vendor consensus ceiling: ≤1 behavioral/day, ≤3 per 24h all-types ([vmobify](https://vmobify.com/blog/push-notification-strategy)). CONVENTION.
  → **Jeni's <5/week cap sits exactly in the evidence-backed safe band. Keep it as a hard budget.**
- **Batching/digest.** RCT (n=237): notifications **batched 3x/day** improved attention, mood, sense
  of control, lowered stress vs default as-they-arrive; **zero notifications increased anxiety/FoMO**
  ([Fitz et al. 2019, CHB](https://www.sciencedirect.com/science/article/abs/pii/S0747563219302596)). PROVEN for wellbeing (not retention directly). Silence is not the goal; predictability is.
- **Personalized send-time.** Vendor data: 15-23% open-rate lift from per-user send-time optimization
  ([Klaviyo](https://www.klaviyo.com/blog/personalized-send-time-optimization), [Braze](https://www.braze.com/resources/articles/send-time-optimization)). CLAIMED.
  Academic receptivity work (+40% above) is the stronger citation. Combined verdict: PROMISING and cheap — learn her hour.
- **Interactive/rich.** Rich media +25% click, +56% open (vendor: [MoEngage](https://www.moengage.com/learn/rich-push-notifications/), [MobiLoud](https://www.mobiloud.com/blog/push-notification-statistics)). CLAIMED.
  Action buttons: universal vendor consensus that in-notification actions lift completion without
  requiring an open ([Braze](https://www.braze.com/resources/articles/key-push-features)). CONVENTION.
  For medication specifically: 2025 JMIR meta-analysis — reminder/adherence apps significantly improve
  medication adherence in 10 RCTs ([JMIR 2025](https://www.jmir.org/2025/1/e60822)). PROVEN for the
  category Jeni already shipped (taken/hour/later). This is Jeni's best-evidenced notification.
- **Opt-in mechanics.** iOS average opt-in ~56% (Pushwoosh 2025, 600+ apps,
  [via Pushwoosh](https://www.pushwoosh.com/blog/ios-push-notifications/)); pre-permission priming at a
  concrete value moment materially lifts acceptance ([OneSignal](https://onesignal.com/blog/how-to-create-more-compelling-opt-in-messages-for-ios-push/), [Batch](https://doc.batch.com/guides-and-best-practices/orchestration/how-to-improve-the-push-opt-in-rate)). CONVENTION.
  → Jeni's day-2 consent gate matches best practice; the strongest prime is the first dose logged
  ("want the next one held for you?").
- **Fatigue/habituation.** HeartSteps decay (above) + app-fatigue literature
  ([PLOS Digital Health 2025](https://journals.plos.org/digitalhealth/article?id=10.1371%2Fpdig.0001107)):
  every recurring notification loses effect; systems must detect ignore-streaks per user and quiet
  themselves. PROVEN direction.

---

## 5. Streak psychology — what fits an anti-shame brand

- **For:** 2025 multi-experiment study (~4,500 participants): streak-framed incentives drove more task
  completion than larger stable rewards ([via Cohorty synthesis](https://blog.cohorty.app/the-psychology-of-streaks-why-they-work-and-when-they-backfire/)). PROVEN (lab).
  Duolingo's 2.3x daily-engagement claim (CLAIMED). Loss aversion works.
- **Against:** the same mechanism produces breakage-churn — a broken streak converts motivation into
  abandonment ("what-the-hell effect"); obligation-based engagement, perfectionist burnout, quantity-
  over-quality lessons documented in the Duolingo record above
  ([habit-systems critique](https://medium.com/design-bootcamp/streaks-and-daily-rewards-as-habit-forming-systems-dab7f5a34539)). PROMISING (consistent).
- **The field's own correction:** freezes, repair, revival campaigns (Duolingo 2026), and
  **weekly-target alternatives** — consistency rate (%), N-of-7-days weekly goals, total completions,
  identity framing ([Cohorty](https://blog.cohorty.app/the-psychology-of-streaks-why-they-work-and-when-they-backfire/)). PROMISING.
- **Anti-shame fit for Jeni:** MacroFactor's adherence-neutral stance + weekly targets is the model.
  Jeni's v24 becoming tile already ships a **tally strip** (counts, not chains) — that is the right
  grammar. If any streak-like surface ever appears, it must be weekly ("5 of 7 days"), repairable,
  and never mourned in copy. Daily unbroken-chain streaks: DO-NOT-BUILD (below).

---

## 6. iOS-native surfaces — proven vs novelty

| Surface | Evidence | Verdict |
|---|---|---|
| **Live Activities** | Apps using LA show 23.7% higher avg D30 retention ([OneSignal](https://onesignal.com/blog/live-activities-vs-push-when-a-lock-screen-widget-beats-a-notification/)); 18-32% lift claims ([EngageLab](https://www.engagelab.com/blog/live-activities-examples)) — all correlational/vendor | CLAIMED overall; PROMISING for **time-bounded states** (delivery, fasting windows). Every serious fasting app ships one. A **dose-day live activity** (from morning until marked taken, site pre-selected, "taken" action) fits the pattern exactly. Always-on LA = GIMMICK. |
| **Home-screen widgets** | Gratitude: widget users retained 25% higher, 10% DAU adoption ([Android Devs Blog 2026](https://android-developers.googleblog.com/2026/05/how-gratitude-widgets-boosted-user-retention-25-percent.html)); retention.blog survey of Calm/Fabulous/Strava is explicitly non-empirical and flags selection bias ([retention.blog](https://www.retention.blog/p/widgets-and-live-activities)) | PROMISING with heavy selection caveat — widget adders were already engaged. Cheap to ship; real value is a zero-effort glance surface that keeps the app present. |
| **Lock-screen widgets / StandBy** | No public causal data found | CONVENTION at best; ship only as a byproduct of the widget family. |
| **Watch complications** | No public retention data | GIMMICK for Jeni's cohort until watch app exists. |
| **App Intents / Siri / Shortcuts / Action button** | No public retention numbers; strategic shelf-space in Siri/Spotlight/Apple Intelligence ([Apple](https://developer.apple.com/documentation/appintents), [analysis](https://blakecrosley.com/blog/app-intents-are-apples-new-api-to-your-app)) | PROMISING strategically (log-a-dose / log-a-meal intents are cheap and future-proof), unproven tactically. |
| **Interactive notification actions** | Medication adherence RCT base (JMIR 2025 above) + vendor consensus | PROVEN-adjacent — Jeni's taken/hour/later is the correct, already-shipped bet. Extend the grammar, don't multiply categories. |

---

## 7. Re-engagement + the ethics line

**What works (measured):**
- Segmented win-back beats generic by ~54%; subscription win-back recovers 5-15%, full-uninstall only
  1-5%; **20-40% of "wins" would have returned anyway** — use holdouts
  ([Airbridge](https://www.airbridge.io/en/blog/subscription-app-win-back-sequence), [MWM](https://mwm.ai/glossary/winback-campaign), [Monetizely](https://www.getmonetizely.com/articles/how-to-track-win-back-campaign-effectiveness-a-complete-guide-for-saas-executives)). PROMISING.
- First touch within 24h of cancellation intent; lapsed-but-installed users recover 10-20% via
  personalized re-engagement (same sources). CONVENTION.
- **Duolingo's June 2026 streak revival** — remove the shame barrier, restore the record, show what's
  new ([ContentGrip](https://www.contentgrip.com/duolingo-streak-revival-campaign/)). PROMISING pattern:
  *treat the lapsed user as someone whose record is intact, not someone who failed.*
- **Auto-silencing** after sustained ignores (Duolingo ~7 days) — respects the user AND protects
  opt-in; do the silence without the passive-aggressive copy. PROVEN practice.

**Dark patterns to explicitly avoid** (all documented as trust-destroying; regulation tightening
2025-2026 — [Usercentrics](https://usercentrics.com/knowledge-hub/dark-patterns-and-how-they-affect-consent/),
[Hall of Shame](https://hallofshame.design/), [design-guidelines review](https://www.researchgate.net/publication/394883405_DARK_PATTERNS_IN_MOBILE_APPS_ETHICAL_IMPLICATIONS_AND_DESIGN_GUIDELINES_FOR_TRANSPARENT_USER_EXPERIENCES)):
- **Fake urgency** (countdowns that reset, "3 spots left").
- **Phantom notifications** (fabricated social activity, fake "someone viewed your progress").
- **Confirmshaming / guilt copy** ("Duo is sad", "giving up on yourself?").
- **Streak-shame** (mourning a broken chain, "you lost your 40-day streak").
- **Cancellation mazes** (Noom's ~7 retention screens; thousands of BBB complaints).
- **Weight/body shame as re-engagement lever** — category-specific, radioactive for Jeni's brand and
  the anti-femvertising audience.

---

## 8. Weekly-review rituals — the strongest under-used loop

- **Underlying behavior is PROVEN:** weekly/daily self-weighing improves weight outcomes without
  psychological harm; accountability amplifies it (systematic reviews:
  [IJBNPA meta-analysis](https://ijbnpa.biomedcentral.com/articles/10.1186/s12966-015-0267-4),
  [Zheng 2015](https://onlinelibrary.wiley.com/doi/full/10.1002/oby.20946)).
- Best implementations: **MacroFactor's check-in** (report ends in new targets — reading it changes
  next week); **WHOOP's Monday WPA** (this week vs your own 3-week average); **Oura/WHOOP monthly
  reports**. Retention effects CLAIMED but the ritual grammar is consistent across every
  high-retention health product studied here.
- Recap-as-ritual at larger timescales: Spotify Wrapped (156M engaged 2022,
  [NoGood](https://nogood.io/blog/spotify-wrapped-marketing-strategy/)); Strava challenges/recaps
  (90-day retention 18%→32% CLAIMED, [Lucid](https://www.lucid.now/blog/retention-metrics-for-fitness-apps-industry-insights/)). CLAIMED but directionally strong: periodic
  self-referenced recaps are the healthiest engagement mechanic in the industry.
- **Jeni's structural advantage: the week already has a physiological anchor — dose day.** No
  competitor's week has a built-in Monday. MacroFactor invented an arbitrary check-in day; Jeni's is
  real (weekly injectable cadence, v24's late-window logic already knows it).

---

## IMPLICATIONS FOR JENI (ranked)

1. **Build THE WEEKLY READ anchored to dose day.** One weekly ritual: the day after her dose (or her
   chosen morning), a report in Jeni's voice — her week vs her own 3-week average (WHOOP grammar),
   what the record shows (v24 eras), ONE adjustment or observation that changes next week
   (MacroFactor law: end in an action, never a mere summary). This targets the W1→W2 collapse with
   the strongest evidence-backed loop (self-weighing/self-monitoring + weekly recalibration) and uses
   the one anchor competitors don't have. PROVEN mechanics, novel anchor.
2. **One notification brain, one budget.** All categories (medication, daily reminder, trial anchors,
   future weekly read) arbitrated by a single scheduler holding the <5/week cap as a hard budget.
   Every candidate notification must answer: why now (decision point), why her (tailoring variable),
   why open (payload from her own data). Medication actions always outrank everything else; support
   pings yield. This is the founder's "intelligence model" made concrete — JITAI-lite.
3. **Learn her hour, per user.** Receptivity heuristics first (wake time from HealthKit sleep, her
   habitual logging hour, dose hour), send-time learning later. +15-40% engagement is the cheapest
   evidence-backed lift available. No new data collection needed.
4. **Auto-silence with grace.** Per-category ignore-streak detection: after ~5-7 consecutive ignores,
   the category goes quiet and a soft in-app card says it stepped back ("i'll hold the reminders —
   turn them back on any time"). Duolingo's behavior, never Duolingo's copy.
5. **Dose-day Live Activity.** From dose-day morning until marked taken: site pre-selected by
   rotation, one "taken" action, then it ends. Time-bounded, zero-effort, matches the proven
   fasting-timer pattern; replaces 1-2 pushes on her heaviest-value day. PROMISING; ship as an
   experiment with a holdout.
6. **Weekly consistency grammar, never daily chains.** Anywhere consistency renders: "5 of 7 days,"
   tally strips (already the v24 grammar), totals, eras. Lapses are repairable and unmentioned;
   return flows say "your record is here — the week starts fresh." Duolingo's 2026 revival insight
   without ever building the streak that needs reviving.
7. **One small widget.** Today's state: next dose distance + today's protein/logging state. Cheap,
   PROMISING-with-selection-caveat; measure adders vs non-adders honestly (don't claim the selection
   effect as causation).
8. **Keep the day-2 consent gate; add a value-moment prime.** The strongest prime is right after the
   first dose is marked: "want the next one held for you?" — matches opt-in evidence and the
   medication category's PROVEN adherence base.
9. **Batch the support layer.** Non-medication content (patterns, food, becoming) rides in at most
   one predictable daily digest moment, never scattered pings — Fitz RCT: predictable batching beats
   ad-hoc delivery for attention and stress.
10. **Instrument like an MRT.** Randomized holdouts at the notification level from day one; per-user
    per-category open/dismiss/ignore ledger; opt-out and uninstall tracked against notification
    volume. Effects decay (HeartSteps) — the system must see its own decay.

### DO-NOT-BUILD
- **Daily unbroken-chain streaks** (breakage-churn + anti-shame violation; the industry that invented
  them spent 2025-2026 softening them).
- **Phantom/fabricated notifications** of any kind (fake activity, fake urgency, resetting countdowns).
- **Guilt or shame copy** in any notification or win-back ("don't give up on yourself", mourning
  language, body/weight shame as a lever) — confirmshaming is a named dark pattern.
- **Cancellation friction mazes** (Noom's 7 screens) — tier-matched downsell already exists; stop there.
- **Marketing/promotional pushes inside the medication category** — it is never named and never sells.
- **Always-on Live Activity or badge-count nagging** — novelty that reads as noise (GIMMICK).
- **Volume above the <5/week cap for growth reasons** — >6/week = 3.4x uninstall risk.
- **A "we miss you" push with no data payload** — every re-engagement touch carries her own record or
  nothing sends.
