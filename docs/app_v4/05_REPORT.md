# app v4 — the program rebuild: final report

Date: 2026-07-06/07. Branch `feat/app-v2`, commits eef399a…9fa1750
(8 commits, 109 files, +14,946/−8,988). Every claim below has a
test, a capture, or a recording behind it; the evidence archive is
`docs/app_v4/evidence/` (gitignored per repo screenshot policy —
on disk, not in history). 195/195 unit tests; 7/7 SurfaceInventory
walker legs; verified on iPhone 16e, iPhone SE class (375pt), and
Dynamic Type XXL.

---

## 1. The program thesis (what changed at the root)

The founder's "it doesn't feel like a clear program" had a literal
cause: **the program didn't exist as an object.** The engine stamped
a 7-slot weekly rotation across `totalDays` (140 days for the QA
user) — no phases, no named weeks, no learning loop, nothing to
render as "your plan." Every earlier redesign polished surfaces
above that hole.

v4's answer, in one sentence: **one weight-care program with a
visible spine — named phases made of named weeks, each week closing
with a consented re-signing, and one place where all of it is
visible over time.**

- **ProgramArc** — phases per chapter. Losing: finding steady (wk
  1-2) → the early read (wk 3-4) → the build → the bend → the last
  stretch → the hold. On-medication: arriving → the practice
  (rolling 4-week blocks), open-ended. Keeping: the settle (wk 1-6)
  → kept, open-ended. Pure math, coverage-law table tests across
  plan lengths 7-180 days.
- **WeekIntent** — every week has a name and one sentence of intent
  ("the protein week", "the begin-again week"), deterministic,
  zone-aware in keeping (a drift opens "the steadying week"),
  honoring re-signing picks.
- **THE RE-SIGNING** — at her week's boundary jeni reads the week
  back from her real data and proposes at most ONE change with the
  reason attached; she keeps, adjusts, or declines (recorded,
  respected). Proposals come from a closed safe set (protein ±5g
  inside the advisory clamp, moves ±1, weigh softening, intent
  pick, hold-steady-with-reason) and apply through knobs the
  engines already read. A provenance floor keeps the rules honest
  (no protein claims on thin logging data).

Evidence anchors (docs/app_v4/research/, all verified passes):
DPP's session arc + the week 3-4 early-response gate [strong];
stability-first weeks in women (Kiernan 2013) [strong]; automated
weekly tailored feedback matching human coaching (Tate 2006)
[strong]; adaptation-as-named-consented-moment (MacroFactor
anatomy); week units minting Monday fresh starts (Dai/Milkman) and
the midpoint framing flip (Koo & Fishbach); active practice beating
reading (Chien 2020 N=54k; RESiLIENT 2025); menu-picked
implementation intentions (Armitage).

## 2. The plan-over-time answer (the calendar-strip problem)

The old strip died twice for good reasons (Home busyness, then an
undiscoverable sheet). v4 didn't restore it — it gave time a real
surface and Home a thread:

- **THE JOURNEY (becoming, rebuilt)** — arc header (phase name +
  ribbon + intent line), the one-story trend canvas, THIS WEEK as
  the open chapter, then the week-chaptered ledger: receipt cards
  with standing dots in tense ink (solid past / distinct today /
  dotted future / a moon for held days), jeni's week story, signed
  adaptation stamps. Quiet weeks compress to a seam; absence never
  renders (the Cordeiro/Eikey law — clinical risk in this cohort).
  Tap a week → the week page (seven day rows, the week's plates
  strip, the signed record); tap a day → a read-only day receipt
  (what happened, never what didn't; today wears no verdict).
  Ahead: next week as dotted shape, never a locked list.
- **THE WEEK RIBBON (Today)** — one line of typography under the
  masthead: seven standing dots + "finding steady · week 2". It and
  the day pill open the journey. Home stays five things.
- Becoming's masthead leads with presence ("6 kept") early and
  flips to distance ("44 to go") past the program midpoint.

Evidence: `journey_arc_top.png`, `week_page.png`, `day_receipt.png`,
`4x_resigning_*.png`, `resigning_final.mp4`, SE + XL sets.

## 3. Home / Today

Kept v3's reading-first bones (they were right) and added the
missing answers:

- how today connects → the week ribbon (new).
- how am I doing → **THE PLATE STORY**: plates filmstrip leads, ONE
  protein gauge (the twin steps ring died — steps live on their
  rhythm row), and the kcal sentence finally answers out loud:
  "860 of ~1,473 today · room for about 600" in permission grammar;
  suppressed cohorts keep protein-as-care with zero calorie
  numerals. Live-data verified (`plate_story_live.png`).
- The evening now ends on her words: receipt → still-open rows →
  plate story → the one-line journal. The close also offers **THE
  TONIGHT PLAN** (four if-then chips, 15 seconds); the next
  morning's reading names the plan back — a closed loop with a
  receipt, never a grade.
- Object count held: masthead · ribbon · reading · one thing ·
  rhythm · plate story. Entrance cascade frame-verified
  (`today_entrance_frames.png`).

## 4. Feature by feature (what actually changed)

- **Food** — the same-screen contradiction is dead at the root
  (unscoped `todayKcalTotal` let one account's plates mark another's
  beat kept — fixed + unit-pinned). The plate story answers "on
  track?"; HER PLATES replaced the v1 journal interior (holiday
  stock photo, pink FAB) with day-grouped receipt rows,
  protein-first, quiet-hours mornings, long-press delete. Snap
  capture/carousel untouched (the signature).
- **Weight** — ONE story: the canvas badge is now a direction word
  (easing / steady / drifting up, gently) from the same EMA source
  as the field note; the raw "−2.2 lb this week" second-window badge
  died. The keeping band always fits the y-domain now.
- **The method** — practice-first widened: the rep stands; the
  tonight plan adds a daily DO with d≈0.65 evidence; the wave dial
  gives the craving-occasion breath a before/after ("the wave:
  4 → 2" — her data, not a claim). The reader deliberately keeps
  its long-form role (see §7).
- **Breathwork** — rebuilt at the core. The scaled PNG + countdown
  numeral + Timer tick-train died. JKBreathField draws a generative
  petal bloom per frame (sinusoidal clock, zero velocity at every
  turn, petals trailing the core, anticipation glow before turns,
  holds as stillness with micro-drift); BreathHaptics rides the
  same clock with continuous CoreHaptics envelopes (swell in, long
  decay out, silence through holds, ghost transients before turns
  — per the research, no major breath app ships this). Cycle
  progress = filling dots. Honesty pass: the day-1 receipt line
  dropped its craving-suppression claim for the urge-surfing frame.
  Pure clock is table-tested; the session is frame-verified organic
  (`breath_frames_strip.png`, `breath_session.mp4`).
- **Workouts** — demotion holds; the ending joined the register.
  PostRoutineView's v1 celebration (fire Lottie, stat pills, star
  row + feel row, scatter) became the kept receipt: "kept." + fact
  rows + ONE feeling row (the effort signal that tunes the next
  session, preserved through the unchanged onRate pipe). Star
  ratings died app-wide.
- **Jeni chat** — the envelope now carries phase, named week,
  intent line, and the last re-signing, so "why is this week like
  this?" answers itself. Engine/EF untouched.
- **Notifications** — the anchor ladder announces named weeks on
  their opening day (intents are deterministic — safe where live
  readings never were), and THE RE-SIGNING KNOCK lands one quiet
  evening one-shot at her week's close (4-site id protocol,
  cancelled on sign, silent on breaks, deep-links to the journey).
- **Settings** — "your plan" door to the journey; the break row
  stands.
- **Hygiene** — the her-days sheet family, the legacy Becoming
  dashboard family, Plan atoms, FoodLogTimelineView/DailyShare*,
  and retired debug harnesses: deleted (−6.4k lines net beyond the
  feature code). `jenifit://` finally registered (external opens
  errored -10814 since the scheme shipped). All three tab trees
  stay mounted — a real a11y/product class of bug surfaced there:
  the re-signing auto-offered from the HIDDEN becoming tree and
  covered Today mid-scroll. Frame-verified, gated to the visible
  tab, and the walker that caught it now guards it.

## 5. More useful, not just prettier (the founder's test)

- "Am I on track today?" — answered in words on Today.
- "What is my plan and where am I in it?" — the ribbon, the arc,
  the ledger.
- "What did past days amount to?" — every day is a tappable
  receipt; every week a chapter with a story and (when it happened)
  a signed adaptation.
- "Is this program paying attention?" — the re-signing is a weekly,
  visible, consented act of attention; the reading names her plan
  back the next morning; chat can explain the week.
- "Does low effort still count?" — kept days, standing that counts
  ANY meaningful action (a weigh-in without its check no longer
  reads "quiet"), steps ambient, the 15-second plan, the 60-second
  wave.

## 6. Premium parity with onboarding

The dialect is now one voice end to end: serif editorial + receipt
grammar + hairlines + tracked caps + the strike + quiet hearts. The
app's cinematic gestures are few and earned: the note cascade
(v3), the re-signing cascade + consent thunk (new), the breath
bloom (new), the silk sweep (v3). Evidence is motion, not stills:
`today_open.mp4` (entrance cascade), `resigning_final.mp4` (the
received moment end to end), `breath_session.mp4` (the bloom
breathing). SE (375pt) and Dynamic Type XXL hold on every new
surface (one SE wrap found and fixed; captures in `evidence/se/`,
`evidence/xl/`).

## 7. Deliberately left alone (and why)

- **Snap capture + result carousel** — founder-approved signature.
- **Onboarding v5, paywall, gating, goal math, pace floors** —
  production fences; the arc layers on top of plan length, it
  doesn't change it.
- **The reader's long-form format** — the rep + tonight plan + wave
  dial are the practice layer; re-pacing the reader into tap-cards
  would double-ask the same muscle. If reading engagement stays
  low after the practice layer beds in, Imprint-izing the reader is
  a contained follow-up (the research file carries the spec).
- **Workout in-session player** — v3's quiet-mark pass stands;
  demotion policy unchanged.
- **BandModel thresholds, PresenceLedger, BreakState, the note,
  sit-check, QuietHours** — verified v3 spine, untouched.
- **Chat letter register + her-file card** — already right.

## 8. Honest remaining gaps

1. **Rep content** is still 16 authored scenarios — the 84-slot
   pass remains founder-present work (v3 fence, unchanged).
2. **The weekly share artifact** (WeeklyReceiptCard PNG) lost its
   becoming block in the rebuild; the renderer survives but has no
   door. Candidate home: the signed week page. Small.
3. **Journey depth**: earlier-than-window weeks render as a named
   seam but don't expand yet; day receipts don't reconstruct that
   morning's reading; steps history beyond the trailing week isn't
   queried (HealthKit day-window work).
4. **Steps sheet** wasn't regrown to the full research catalog
   (trend-vs-usual sentence, gentle-floor fact, post-meal walk
   framing are specified in STEPS_VALUE.md; the v3 sheet stands).
5. **On-medication "the maybe-after" card** (the stopping-plan
   door) and the keeping **graduation moment** are designed in
   01_PROGRAM but not built.
6. **The re-signing knock** fires at a fixed 19:00; it should
   eventually ride her anchor-hour preference. The anchor-ask
   placement stays founder-gated (v3 gap, unchanged).
7. **BreathHaptics needs a device pass** — the simulator can't play
   CoreHaptics, so the envelopes are code-verified + fallback-
   tested, not skin-verified. Audio phase cues (soft breath sounds)
   were deferred pending asset quality; the lo-fi bed + voice
   bookends stand.
8. **Snap E2E motion recording** still owed (needs the deployed
   food-vision EF + a real camera; sim camera is black).
9. **Widget** (JenifitWidgets target exists) untouched — the ribbon
   + kept-days are the obvious widget content; jenifit:// now
   supports it.
10. **PostHog dashboards** for the new events (weekly_review_signed,
    journey_week_opened, journey_day_opened) not yet built; the
    thesis' success metrics (reading-open rate, one-thing rate,
    re-signing consent rate) need instrumented queries.
11. Three retired debug harnesses (`--debug-protein-hero`,
    `--debug-rapid-loss`, `--debug-adaptive-pace`) are referenced in
    the 2026-06-26 medical review guide; rebuild against live views
    if that guide is still exercised.
