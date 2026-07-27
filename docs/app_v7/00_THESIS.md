# app v7 — THE CARE PLAN (2026-07-27)

Founder brief: a complete redesign from first principles. Stop feeling
like a calorie tracker / food logger / habit tracker / fitness
dashboard; feel like *an AI companion quietly taking care of her
health every day*. The felt sentence: **"I don't have to think about
everything anymore. jeni is already paying attention."** Calm,
minimal, premium, editorial, Apple-like, timeless. Consumer app
today; quietly architecture-ready for white-label obesity-clinic
deployment tomorrow (never exposed in UI). Question every
assumption; delete what no longer deserves to exist.

This doc is the synthesis of an 11-expert independent critique panel
(HIG/ADA juror, interaction, typography/editorial, motion+haptics,
accessibility, luxury brand, behavioral psychology, obesity
medicine, clinic operations, health coaching, product strategy —
full critiques in `docs/app_v7/panel/`) + a behavior-change
literature lane on JeniMethod's fate, over the v6.5 baseline
(screenshots + code + live PostHog data). Synthesized with
judgment, not averaged. It supersedes v6.4's checkable-list founder
override (the v7 brief reverses it explicitly) and v5 §6's Home
re-steer where they disagree; the v6 signals engine law
(00_RESEARCH §4) stands untouched.

---

## 0. The diagnosis (what the panel converged on)

Nine of eleven experts, working independently, named the same root
problem and the same fix:

**The app's genuine moat — a deterministic, provenance-only,
safety-gated understanding machine (Signals + CoachSummary +
DailyBriefEngine) — is rendered upside down.** The one-move
coaching synthesis lives on page ~11 of a 12-page swipe-only pager
almost nobody reaches. Home, the surface seen 20+ times a week,
opens on a static-slot-table task list with empty check rings —
which, for the 83% of paying users who never log food
(03_CONVERSION.md), is a morning report card they are failing.
The copy says supported autonomy; the structure says assigned
homework. Meanwhile the day is composed by calendar arithmetic
(`workoutSlots [1,0,2,4,3,5]`, weigh Mon/Thu) that reads nothing
about her actual week — the exact "static rules" the brief bans.

Everything else the panel found hangs off that inversion, plus a
material layer (glossy sticker tiles, gradient charts, 181 hearts,
to-do rings) that drags the most-seen surfaces from "premium care
product" toward "cute consumer app," and a below-surface finish
layer (contrast floors, VoiceOver contracts, haptic semantics,
sheet grammar) that separates award-caliber craft from what ships.

## 1. The inversion (the one structural move)

> Home stops being a list she grades herself against and becomes
> daily proof that jeni already thought. — interaction critique

The new Home, top to bottom:

1. **Masthead, compressed.** One position line under the date
   eyebrow: `day 12 · week 2 of 20 · finding steady` (opens the
   journey). The seven-cell day rail dies — its dots were
   semantically unreadable (kept? passed?) and it was program
   chrome standing where care should stand. Camera and settings
   marks stay.
2. **THE UNDERSTANDING.** jeni's reading, promoted from a line to
   the page's reason: the serif reading register, one calm
   fused observation of her current state with its because
   ("you slept 5h 48m. hunger runs louder on days like this —
   today's plan is lighter on purpose."). Composed by the grown
   DailyBriefEngine: care outranks logistics, yesterday's feeling
   answer is read back, anticipation clauses see tomorrow.
   Tap = the full letter, in the one thread (see §3).
3. **TODAY'S CARE PLAN.** 1–3 moves, composed by
   `CarePlanEngine` (the CoachSummary clinical-priority ladder
   generalized to daily composition — §4), each carrying its
   spoken reason in the direct register. The lead move keeps the
   elevated-card treatment (it earned it); supporting moves are
   quiet rows. **Ring policy (SDT):** a completion mark renders
   only on moves — things she can do. Observations (steps, the
   overnight window, sleep) render as *received care* — receipts
   of what jeni noticed, never pass/fail. The overnight-fast row
   keeps the founder's plain name and loses its ≥12h ring (four
   experts independently: a ring at 12h is a target in UI grammar;
   00_RESEARCH §4 rule 1 wins mechanically even where vocabulary
   was consciously overridden).
4. **THE RECEIPTS.** What already happened, quietly: plates +
   food chemistry as a sentence (kcal and protein numbers stay —
   direct register — but the budget progress bar dies; a bar
   counting down to "~600 left" is tracker grammar), window /
   night / moves receipts, steps counted for her.
5. **THE EVENING CLOSE** stays — the panel unanimously kept it —
   with one change: the feeling she gives it is *read back the
   next morning* (write-only disclosure teaches her the check-in
   is decorative; closing the loop is the cheapest trust move in
   the whole redesign).

What this deletes from Home: the day rail, HowItWorksBlock (a
reading that leads with understanding teaches the contract by
existing), the "IF YOU FEEL LIKE IT" caps seam (optional moves are
simply *offered* some days, by state — a care plan does not
enumerate its own leniency), the sticker row tiles, the kcal
progress bar, the cycle-connect promo row (growth surface out of
the care surface; it moves to settings + one care moment).

## 2. becoming: from slideshow to index

The 12–14-page serial pager taxed every visit (9–11 swipes to the
best content, 5pt dots at ~1.3:1 contrast, per-swipe re-arm
theater). Rebuilt as **overview → drill-in**:

- Landing: **jeni's read of the week** (the CoachSummary page,
  promoted from ~page 11 to first) — headline move + provenance
  receipts + the chat door.
- Beneath: a vertical index of signal cards (weight trend, food,
  window, sleep, sugar, consistency, plates, plan) — each a
  figure thumbnail + its current one-line read. Tap **pushes**
  the existing full-bleed story page (NavigationStack, back-swipe,
  zoom transition) — the pages themselves were Kinfolk-grade and
  survive intact; only their access grammar changes.
- Motion: draw-in on first arrival and on data change; settled on
  revisit (data that redraws itself performs; data that is simply
  there reads as truth).
- The 12-dot rail dies; drilled pages carry the roman-ornament
  folio (`iv · of ix`) the token system already specced.

## 3. one jeni (the relationship layer)

Three generators currently speak as jeni on three surfaces, and
she never speaks first — "all the care in the engine is filed
under 'available on request', and that is an app, not a coach"
(health-coach critique).

- **One thread.** The daily understanding IS the day's letter in
  the jeni tab; Home's "from jeni ↗" deep-links to it. The
  dead-end full-screen note cover dies.
- **First moves.** jeni earns 2–3 *unprompted* letters a week,
  event-triggered (never scheduled): the evening after a "tender"
  check-in; the night before her statistically hardest day; a
  plateau breaking; day 2 of silence (with a watched-fact from
  the gap — steps kept counting while she was away). Lands as a
  real unread badge. One per day max; BreakState silences all.
- **Memory.** yesterdayFeeling joins the brief context (tender →
  tomorrow opens gentler, one fewer ask, no trend talk).
  Comeback calibrates by absence length (2–3 days ≠ 10 ≠ 45) and
  cites what auto-tracked during the gap.
- **Celebration ladder.** Three amplitudes matched to rarity:
  quiet receipt (default) / named win (first-ever down week,
  plateau break) / the earned moment (milestones — where the
  sticker scatter and silk belong). Everything at one volume
  habituates to wallpaper.

## 4. CarePlanEngine (the brain, and the platform seam)

Not a rewrite — a promotion. `CoachSummary` proved the pattern:
read the signal week, name ONE move by fixed clinical priority.
v7 generalizes it to daily composition:

```
CarePlanEngine.compose(snapshot, signals, cohort, dayContext)
  -> CarePlan { understanding: Understanding
                moves: [CareMove]        // 1–3, reasoned
                receipts: [CareReceipt]  // observed, never graded
                tone: .standard | .gentle | .celebration }
```

- **Priority ladder** (clinical, fixed, unit-tested): safety
  clauses first (rapid-loss guard, under-fuel net) → physiology
  pre-frames (short night, cycle, dose-day when known) →
  the chapter's anchor behavior (snap days 1–2; protein-first
  for on-medication) → trend/cadence maintenance (weigh only on
  cadence or staleness) → practice (breath, a matched rep) →
  "change nothing" (a legitimate plan; some days the care is no
  asks).
- **Every move carries `because`** — a provenance clause spoken
  in the direct register ("protein first — yesterday landed 40g
  under your floor"). No live data → no claim; the static
  slot tables remain only as the data-floor fallback, and even
  then the day renders at most three moves.
- **Gentle days are composed, not decorated:** after a tender
  evening or a big celebrated win, the plan drops to one move
  and zero new asks by rule.
- **The white-label seam (invisible today):** `CarePlan` /
  `CareMove` / `Understanding` are typed, brand-free records.
  Clinical constants (protein g/kg + clamps, pace floors, window
  tone thresholds, band zones) gather into one injectable
  `CareProtocol` config. Voice renders in one place
  (`BrandVoice`: jeni's strings as the default implementation) so
  rules never fork when a clinic changes the words. Subjective
  answers (sit-check, feelings, tonight-plans) move from
  UserDefaults strings into a typed, userId-scoped, append-only
  `ObservationStore` — the record a future care team reads, and
  the fix for sign-out data loss today. None of this renders.

## 5. the method: from curriculum to interventions

Live data: lessons pushed daily to everyone retain at exactly
baseline while every chosen behavior retains 2.5–3.6x. Behavioral
verdict (two experts + literature lane): the objective is not
teaching a method; assigned curricula produce introjected
compliance, while state-matched micro-interventions (JITAI) are
where digital behavior change actually performs. So: **the method
becomes invisible infrastructure.** The daily required "the
method" row dies. The 84-lesson curriculum + 16 authored reps
survive as a content library the CarePlanEngine draws from *when
a signal fires* (evening sugar rising → the craving-wave rep
tonight; scale morning after a salty weekend → the scale rep
before the weigh invitation; inner-critic language in chat → that
lesson offered once). Lessons remain browsable one level in
(never pushed), and the share-card acquisition lever survives.
*(Final wording pending the method lane's citations; direction is
converged and the founder brief authorizes it.)*

## 6. material law (the luxury calibration)

The brand splits into two materials, and the seam is enforced:

- **Daily surfaces** render exclusively in the cocoa typographic
  register: serif reading voice, hairlines, line-art marks
  (the moon row proved it), flat tonal charts (hairline cocoa
  trend line, single rose endpoint dot, serif numeral headline —
  the chat sparkline is the app-wide chart grammar now), tracked
  caps, whitespace.
- **Earned moments** carry the glossy warmth: stickers, bloom,
  scatter, ♥ — completions, THE LANDED moment, milestones, the
  three scatter moments. The one-thing card's peach becomes a
  tonal debossed seal at rest; the glossy sticker lands ON
  completion, as the reward. (Sticker identity preserved —
  relocated to where it reads as earned, per the founder's own
  earned-moments law.)
- **Heart budget:** ♥ terminates only lines jeni authors — the
  reading, letters, the evening close, celebrations. ~181 sites
  fall to ~30. Utility surfaces go dry.
- **Type constitution:** one display serif above 18pt
  (JeniHeroSerif; Fraunces retreats to 11pt eyebrows + body punch
  words), a 7-slot ladder, italic rationed to ONE punch word per
  screen, numerals always roman (the founder's own ruling),
  16pt serif floor. New sizes require a token, not a literal.
- **Accessibility floors as design-system law:** cocoaTertiary
  retints 0.48 → 0.66 opacity (~4.5:1 — quiet must mean calm,
  not faint; the audience is 35+ women, some on medication with
  documented transient vision effects); small rose text moves to
  jeweledRose; a Tokens contrast unit test joins the suite so no
  future restraint pass can ship below the floor.

## 7. feel (motion + haptics)

The brief: haptics matter more than animations. The inversion
found by the motion critique: the bespoke haptic vocabulary lives
in the one-time onboarding funnel while the daily loop speaks
~317 stock taps.

- **JeniHaptics** semantic layer, six patterns by meaning:
  `touch / kept / landed / dayDone / received / caution` —
  CoreHaptics envelopes, stock-generator fallback. The daily loop
  rewires to it; navigation goes silent (Apple's own tab bars
  fire nothing).
- **Fix the landed collision:** the visual modifier stops owning
  feel (`Haptics.success()` leaves JKSilkSweep); call sites own
  meaning; the crafted swell finally gets heard.
- **One entrance system** (jkBeat), one ambient period
  (3.0s breath, harmonics only), first-open-of-day gets the full
  develop-in and later opens settle instantly — the fourth cold
  open of a day is a glance, not a premiere.
- **Sheet contract:** one JKSheet grammar (cream background,
  visible grabber, content-fitted detents, no conditional-blank
  closures — the blank-sheet bug class dies structurally).

## 8. clinical care gaps (the physician's transformatives)

Both fit the brief's data philosophy ("collect only information
that meaningfully improves care" — medication is on its list) and
both are consumer-legal (a weekday is a calendar fact, no brand
names, no dosing advice):

- **The shot-day anchor** (on-medication): one optional field.
  The engines gain the injection week — day-after softening
  (smaller-plates permission, fluids-first), day 5–7
  hunger-return normalization ("hunger returning is the rhythm,
  not failure"), sit-check answers gain context. The #1
  between-visit question, answered before she asks.
- **The post-medication arc:** route `glp1Status == "past"` to
  its own chapter that arms the existing band-zone machinery
  from her stop-date settle weight, normalizes returning
  appetite in the forgiveness register, carries protein +
  strength forward 12 weeks. The highest-regain-risk cohort in
  the market currently gets a noun phrase; the app already owns
  every mechanic this needs.
- Supporting: strength promoted to required-with-receipt for
  on-medication strength days (protein alone does not preserve
  lean mass); a monthly visit-prep summary card assembled from
  data already held ("for your next appointment"); live
  CareState (safety flags may move after intake on new
  evidence, always by consent).

## 9. reliability + platform floors

- The blank-sheet class: no conditional content inside sheet
  closures, ever (gate presentation on data existing).
- VoiceOver contract for the day: custom "mark as done" actions,
  live values on auto rows, hearts stripped from spoken labels.
- AX sizes: negative serif leading relaxes to 0 at accessibility
  sizes; page-class content scrolls.
- Dark mode: declared light-only this pass (honest > seamed);
  the cocoa night appearance is a named future candidate.
- 44pt targets on camera, send, chips (tappableArea exists).

## 10. what is deliberately NOT changing

- The three tabs (today / jeni / becoming) — right count, right
  names, native TabView + Liquid Glass.
- The signals engine + its safety law (§4 rules) — untouched.
- The snap rail, weigh ritual, breath interiors — interiors
  polish later; their entry grammar changes with the plan.
- Targets math, cohort pace floors, paywall/pricing, auth/sync,
  data contract — production fences, zero changes.
- Onboarding v5 — its own pass, separately founder-reviewed.
- The direct register + "overnight fast" naming (founder
  overrides stand; only the *ring* reverts to observation).
- The evening close, the re-signing, the comeback frame, the
  provenance law — the panel's unanimous keeps.

## 11. build order (each phase: 4-6 changes, build, screenshot, commit)

1. **THE CARE PLAN** — CarePlanEngine + Home inversion
   (understanding → moves → receipts), ring policy, de-ringed
   fast row, masthead compression, sticker→line-mark rows, kcal
   sentence, evening feeling loop. Quick floors ride along:
   cocoaTertiary retint, landed-collision fix, jeweledRose small
   text, 44pt targets.
2. **BECOMING INVERTED** — coach's read first, signal index,
   NavigationStack pushes, folio, settle-on-revisit.
3. **ONE JENI** — the letter thread unification, first-move
   letters, comeback v2, celebration ladder.
4. **MATERIAL + FEEL** — chart grammar port, type-ladder sweep,
   heart budget, JeniHaptics, entrance/ambient consolidation,
   sheet contract, light-only declaration.
5. **THE PLATFORM SEAM** — ObservationStore, CareProtocol,
   BrandVoice split, method→interventions, shot-day anchor,
   post-medication arc, visit-prep card. (Order within phase 5
   may split across releases; records land first.)

Verification per phase: build + install on the dedicated sim,
screenshot every touched surface, walker legs where they exist;
final pass records full journeys and audits frames.

---

*Panel artifacts: `docs/app_v7/panel/` (11 critiques + method
verdict, JSON). Baseline screenshots: session scratchpad
`baseline/` (gitignored per screenshot hygiene). Every decision
above cites its critique lineage in the panel files.*
