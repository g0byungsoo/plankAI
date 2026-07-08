# Program-over-time UX — how the best consumer apps render the past/today/future arc (2026-07-06, verified)

Method: 5 parallel research tracks (~85 searches, ~70 source fetches;
primary sources fetched directly where possible: Duolingo's design blog +
research whitepaper PDF, MacroFactor/Runna/Sweat/Oura/Gentler Streak help
docs, Kivetz/Bonezzi/Dai PDFs) → 6 load-bearing claims re-verified against
primary sources in a second pass (0 refuted, 2 sourcing corrections).
Confidence tags: HIGH (primary/official source) / MEDIUM (reputable
secondary or converging secondaries) / LOW (forum/single source).
First-party (company-reported) numbers labeled. "Not found" is stated
rather than guessed; nothing below is invented.

Question: how do the best consumer apps (2024-2026) render a multi-week
program over time — past days, today, upcoming days — and what interaction
grammars make it feel like *a real program I'm inside* vs a todo list?

---

## 0. The one-line answers

1. **Nobody locks the future anymore.** The one tested lock (Peloton
   Programs 2.0: padlocked future classes + miss-a-day-restart) generated
   four years of complaints and was publicly reversed in Programs 3.0
   (June 2025) whose headline features are the negation: preview any week,
   pick up where you left off, credit below 100%. HIGH.
2. **Plan adaptation only builds trust as a *moment with a reason and a
   signature*** — a named ritual (MacroFactor weekly check-in, Runna Monday
   realignment popup) that explains the change from the user's own data and
   asks consent. Silent adaptation needed a "why" retrofit (Garmin, Nov
   2024); silent time-marching (Sweat's midnight Sunday roll) reads as the
   plan not caring. HIGH.
3. **The past renders as receipts of what happened, never as marks of what
   didn't.** Two layers everywhere: a light plan-state layer (dot/tick) +
   a permanent history ledger. Absence is absorbed by statuses (Sick /
   On a Break / Vacation), not rendered as holes. HIGH.
4. **"Inside a program" is carried by an interpretation layer above the
   data** — a voice that reads the arc (phase names, week themes, coach
   commentary, "Kudos for Taking Action"), plus a position index computed
   from *her own* data. A calendar shows time; a program *reads* it. HIGH.
5. **The science says: switch progress framing at the midpoint, use weeks
   as the motivational unit, endow day 1, count presence (never resets),
   and never render absence.** All five points have direct peer-reviewed
   support (§8). HIGH.

---

## 1. Training-program apps

### Runna (the reference for adaptive-plan grammar) — HIGH (official support docs, re-verified)

- **Past:** Training Calendar = "real-time view of everything happening in
  your plan: upcoming sessions, completed workouts, and how your week is
  taking shape" ([support.runna.com 10137793](https://support.runna.com/en/articles/10137793-how-to-use-your-training-calendar),
  ~2026). Complete/skip are explicit user actions. Separately, an
  Activities tab holds "all your workouts to date" forever, filterable
  ([10473504](https://support.runna.com/en/articles/10473504-your-quick-guide-to-navigating-the-runna-app)).
  Un-actioned past workouts are load-bearing state: leaving them unticked
  is what triggers adaptation (below).
- **Today:** a dedicated Today *tab* — the day's full session, weekly
  mileage, tips. Strongest "today has its own surface" pattern in the set.
- **Future:** fully previewable and manipulable — drag-and-drop any workout
  across weeks; preference changes re-arrange the whole remaining plan
  ([6206024](https://support.runna.com/en/articles/6206024-adjusting-your-running-schedule)). No locks.
- **Adaptation:** the **Plan Realignment popup** (verified 2026-07-06):
  triggers when "you've missed more than three workouts, or a week of
  training"; "typically … on a Monday"; options escalate with absence —
  1 wk: skip missed / rearrange; 2+ wks: extend plan / rebuild to end date /
  continue unchanged; 4+ wks: start new / restart / rebuild / continue —
  and continuing unchanged carries a stated why-not: "may increase injury
  risk as the plan has progressed beyond what your current fitness is
  capable of" ([10026375](https://support.runna.com/en/articles/10026375-how-to-use-the-plan-realignment-feature)).
  Single missed run gets the opposite advice: skip it, "one workout won't
  make too much difference." Adaptation = a decision screen, not a diff.
- **Weeks as narrative:** deload weeks and taper phases are real named
  mechanics (taper = −30% then −50% mileage, named "Taper Intervals"
  sessions; [6576215](https://support.runna.com/en/articles/6576215-top-tips-for-tapering-before-a-race)).
- **Anti-pattern reports (LOW, forums 2025-26):** "generates a plan based
  on initial input but doesn't recalibrate as you progress" (tendonitis by
  week 4); no pause-for-sickness option; paces too aggressive. I.e. even
  the best realignment moment is criticized for not re-asking *often*
  enough — silence between moments is the residual complaint.

### Nike Run Club — MEDIUM

Static plan documents (5K = 8 wks × 3 runs; marathon 18 wks × 4): "the
plans themselves are static. If you miss a workout, you'll need to adjust
manually" ([healthynexercise review, 2026-06-04](https://healthynexercise.com/running-programs-training/nike-run-club-training-plans-review/)).
Completed runs must be manually assigned to plan slots (friction documented
in an [Apple Communities thread](https://discussions.apple.com/thread/8134287)).
Adaptation is *rhetorical, not mechanical*: Coach Bennett's audio absorbs
the miss ("missing a workout doesn't mean failure"; plan "written in
pencil… you are both the athlete and the Head Coach"). The complaint
direction is too little structure, not too much.

### Peloton Programs — HIGH (best documented before/after case)

- **2.0 era (through mid-2025), the cautionary tale:** "if you don't follow
  this schedule to a tee, you don't get credit"; future classes carried "a
  locked icon"; skip a day → "you have to start the whole program over
  again" ([leahingram.com, updated 2024-09-15](https://www.leahingram.com/peloton-programs-where-to-find-and-how-they-work/)).
  Community threads from 2021 onward begged for pause/make-up options
  (r/pelotoncycle "Bummed out about the new programs", 2021-05).
- **3.0 era ([Pelobuddy, 2025-06-13](https://www.pelobuddy.com/programs-2025-relaunch/), verified):**
  browse "the entire schedule … without even joining"; "navigate to any
  week, and see the full list of classes"; open any class immediately;
  "easily pick up where you left off if you miss a day or need to take a
  break"; progress tracker ("how many classes you've taken and have left");
  completion receipt on the landing page ("when you last completed it, and
  how many of the classes you did that previous round"); "Mark as Done"
  below 100%.
- **Reading:** a four-year natural experiment. Locked-future +
  miss-equals-restart was the most complained-about mechanic; the relaunch
  monetized its negation.

### Future ($150-199/mo human coach) — MEDIUM-HIGH

The week is the atomic unit: coach "designs a new, personalized workout
plan for you every week" ([sports-nerd, 2025-12-07](https://sports-nerd.com/brand/future/));
beyond-this-week literally doesn't exist yet — a human writes it weekly.
Adaptation is delivered *in conversation*: coach sees watch data ("missed a
day, skipped sections, cut your session short"), pings you, asks why,
rewrites next week ([onbetterliving, 2026-01-31](https://onbetterliving.com/future-app/);
Forbes Health 2025). Anti-pattern: accountability reads as surveillance —
"hard to get away with skipping" (Healthline, undated).

### Ladder — MEDIUM-HIGH

Team-broadcast programming, zero per-user adaptation ("if you're recovering
from a tough week, the program doesn't know that" — [corahealth, 2026](https://www.corahealth.app/compare/ladder)).
History ledger is strong ("look back months — even years — … exactly which
workouts, how long, what weights"), but the *plan* forgets: "by Sunday at
6 p.m. EST, the entire weekly workout schedule resets" and unsaved workouts
are gone ([outdoorsynomad, 2026-02-05](https://www.outdoorsynomad.com/ladder-fitness-app-review/)).
Coach "video pep talks at the beginning of each new week" carry the
narrative; weekly "priority workouts" split must-do from nice-to-do.

### Sweat — MEDIUM

Planner month view renders sessions as **dots, pink when completed**; tap a
completed workout → read-only summary (date/time/duration)
([support.sweat.com 115006926987](https://support.sweat.com/hc/en-us/articles/115006926987), undated).
Week = a goal-count with a "sweat meter" that fills, not a day-grid. Any
week is jumpable. Anti-pattern: "On Sunday, at midnight, your account will
roll into a new week, regardless if your weekly goals are completed"
([Getting Started](https://support.sweat.com/hc/en-us/articles/360001043296-Getting-Started)) —
the silent roll-forward; a missed week just vanishes. Week-number identity
is the program culture ("BBG Week 2").

### Caliber — MEDIUM

Date navigation both directions; the real past-artifact is the coach's
weekly Loom video reviewing "your last week of workouts … reps and weights"
([garagegymreviews, 2025-05-09](https://www.garagegymreviews.com/caliber-app-review)).
Future is predictably same-shaped (progressive overload repeats exercises).
Progress is metric-shaped (opaque "strength score"), not week-shaped —
and the score's opacity is the documented complaint.

### Cross-pattern (training apps)

1. Future fully previewable (Runna, Peloton 3.0, NRC, Sweat) or honestly
   nonexistent-yet because a human writes it weekly (Future, Ladder,
   Caliber) — never visible-but-forbidden. HIGH.
2. Misses are handled by *asking*, not marking (Runna's fork). Nobody
   renders a red "missed" wall. HIGH.
3. Past = two layers: light plan-state + permanent history ledger. Tap on
   past = read-only recap everywhere; only Future/Peloton offer redo. HIGH.
4. The "inside-ness" carrier differs: countdown + phase arc for race apps;
   fraction trackers for content programs; a human voice narrating the week
   for coach apps. Weakest where a metric replaces the arc (Caliber). HIGH.

---

## 2. Path/journey grammars

### Duolingo path (Nov 2022 →) — HIGH (first-party blog + whitepaper read directly)

- **Past nodes:** completed levels turn **gold, stay tappable** — tap to
  revisit content (5 XP) or take a harder "Legendary" upgrade (40 XP)
  ([blog.duolingo.com, 2022-05-06](https://blog.duolingo.com/new-duolingo-home-screen-design/), verified;
  [duoplanet, 2024-03-27](https://duoplanet.com/duolingo-learning-path/)).
  Replay is *derated*, and targeted review got harder than the old tree —
  Duolingo later had to add a dedicated Practice Hub. MEDIUM-HIGH.
- **Current position:** active node carries a **START speech bubble** with
  the mascot beside it (whitepaper [DRR-24-04 Fig. 1](https://duolingo-papers.s3.amazonaws.com/reports/Duolingo_whitepaper_language_read_listen_write_speak_2024.pdf), 2024-04-26).
  Because the path is really a vertical scroll timeline, position drifts —
  so there's a **floating arrow FAB, bottom-right, that snaps you back to
  your current spot** (blog, 2022-05-06, verified). That FAB is the tell:
  every vertical timeline needs a re-anchor affordance.
- **Future nodes:** gray blank "pebble-shaped circles" — visible-but-locked,
  content undisclosed. Escape valves added: "Jump here?" test-outs at any
  future unit; chests that auto-open in passing (loot cadence). MEDIUM.
- **Adaptation:** the path *order* is identical for everyone; adaptivity
  hides inside fixed slots (personalized practice levels, spaced-repetition
  interleaving) — **static skeleton, adaptive filling**; the user never
  sees the path rearrange itself (whitepaper §1.1.3). HIGH.
- **Narrative:** Sections (CEFR) → Units (~10 levels, descriptive names —
  "get directions," not "City 3") → unit-end trophy; guidebooks per unit.
- **Backlash (the agency cost, HIGH):** "worst update ever"; Candy Crush
  comparisons; 1-star campaigns; change.org petition (~15k, MEDIUM);
  "sometimes you just want to do some easy lessons because you're tired"
  ([NBC via Yahoo, 2022-08-25](https://tech.yahoo.com/general/articles/duolingo-redesign-fans-arms-ceo-204849479.html)).
  Von Ahn refused rollback, claimed **equivalent engagement** (first-party,
  no numbers) and "people are change averse."
- **Outcomes (first-party, Duolingo-authored whitepaper, 2024-04-26):**
  path cohorts scored ~2 ACTFL sublevels higher on reading/listening than
  tree cohorts, **at a ~60-hour time premium** (+58.79h Spanish, +62.22h
  French to finish A2; ~2,900 sessions completed vs ~2,500 strictly
  necessary). Authors themselves flag comparisons as tentative.
- **Net read:** the path traded user agency for guidance + guaranteed
  pedagogy; it held engagement roughly flat short-term by the CEO's own
  account and ate a loud minority revolt. A path is a strong grammar for
  *content curricula*; it punishes users who want random access.

### Fabulous journeys — MEDIUM-HIGH

Journeys = multi-week themed chapters on an illustrated road; **weekly
letters** as connective tissue; storybook second-person chapter titles
("A Fabulous Night: In which [your name] learns how to manufacture a great
night's sleep") ([Google Design, ~2016](https://design.google/library/engagement-is-fabulous-health-app);
[help.thefabulous.co](https://help.thefabulous.co/en/support/solutions/articles/101000427409-what-is-a-journey-)).
Progress renders as roadmap completion % ("3% of the way through").
Future journeys hard-lock until the current completes. No adaptation;
personalization is *narrative* (letters address you by name; "Future
Jason" letters from your future self). First-party numbers: 300→5,000
daily downloads post-redesign (16x); 2x retention from customized
onboarding (Firebase case study). Critiques: letter overload ("seems like
reading a book"), behavioral-science-as-veneer, selection effects
([The Behavioral Scientist](https://www.thebehavioralscientist.com/articles/fabulous-app-product-critique-onboarding), undated;
[IXD@Pratt, 2018-09-15](https://ixd.prattsi.org/2018/09/design-critique-fabulous-motivate-me-ios-app/)).

### Headspace courses (the non-path control) — MEDIUM

Numbered session lists (10-30 sessions), resume at next session, **replay
anything anytime** ("If you have completed a course, you will be directed
to begin at the first session once more" — help center via search).
No road, no world. Personalization lives (and fails) at the
recommendation layer — [Growth.Design's teardown](https://growth.design/case-studies/headspace-user-onboarding)
found recommended courses misaligned with the user's stated goal. Warmth
comes from illustration; forgiveness from Streak Restore.

### Finch (the counter-example) — MEDIUM

Finch **retired its linear Journey grammar entirely on 2025-05-12**,
migrating to flexible per-area weekly levels ("Self-care Areas") — a
wellness app concluding linear paths don't fit fragile-identity domains.
A 2026 Pratt critique of Finch complains of decision fatigue and proposes
re-imposing sequence — the tension is live in both directions
([IXD@Pratt, 2026-02-17](https://ixd.prattsi.org/2026/02/design-critique-finch-self-care-pet-ios-app/)).

### Path-grammar verdict

The path buys concreteness, lapse-forgiveness (no dates = no holes; you
resume where you stopped, zero visual scar after two weeks away) and
narrative habitation (characters/chapters). It costs agency (documented
revolt), random access, and density (a path hides how much remains).
Game-design analysis adds a caution directly relevant to weight care:
linear level-maps work when failure feels like chance, and corrode when
failure reads as personal inadequacy — "'I feel stupid'"
([Game Developer, 2020-03-19](https://www.gamedeveloper.com/design/rethinking-progression-in-mobile-puzzle-games)). HIGH.

---

## 3. Cycle/phase grammars (a timeline that is HERS)

### Flo — HIGH (help docs + first-party design-team posts)

- **Today anchor = countdown-first**, not position-first: the home circle
  "first displays the countdown to ovulation, and after ovulation it
  counts down to your period"; cycle-day numbering is **opt-in** in
  settings ([help.flo.health](https://help.flo.health/hc/en-us/articles/4406826523284-Checking-your-cycle-predictions), undated).
  (The exact string "Day 14 · Ovulation" was **not found** — Flo's grammar
  is next-event urgency, not map position.)
- **Ink grammar:** logged period = solid pink; predicted period = **red
  dotted circles**; predicted ovulation = teal dotted; and under
  uncertainty Flo **withdraws**: "if a delay is displayed … ovulation and
  period predictions for future months are hidden" until new logs
  recalibrate. *The app would rather show nothing than a guess it no
  longer believes.* HIGH.
- **Daily insights** ship as story cards keyed to the cycle day; the
  contract is immediacy (log a symptom → insights react same-day); format
  "resulted in an increase in app engagement" (first-party, no number;
  [Flo design team on Medium, 2022-06-09](https://medium.com/flo-health/how-we-evolved-and-enriched-the-main-screen-of-the-flo-app-part-1-stories-cee6f4035e5)).
  Widgets deliver *verdicts, not data*: users loved "'Normal' with the
  little green check mark. It makes me feel relieved."

### Natural Cycles — HIGH

Today = a **binary instruction**: big red circle "Use Protection" or green
"Not fertile"; green is only shown when the algorithm is *certain* — red is
the default under uncertainty ([help.naturalcycles.com](https://help.naturalcycles.com/hc/en-us/articles/360003339574-What-are-Red-and-Green-Days)).
The cycle graph renders the follicular/luteal boundary from **her measured
temperature**, not a generic diagram — the phase boundary is discovered
from her data, which is why it reads personal. Predictions are an
**unlockable layer** ("once you have unlocked your predictions… starting
from the next day and for the coming six months") — forecast as earned
trust, not default.

### 28 (28.co) — HIGH on phase naming

Four phases renamed as **verbs/moods**: "Phase 1: Restore – Menstrual /
Phase 2: Awaken – Follicular / Phase 3: Perform – Ovulatory / Phase 4:
Balance – Luteal" ([womenlovetech, 2023-10-19](https://womenlovetech.com/the-28-app-teaches-you-to-work-with-your-cycle-not-against-it/)).
Each day arrives pre-interpreted with the day's workout keyed to phase
(menstrual = stretching/slow yoga up to HIIT at ovulation). The label does
the narrative work before any copy runs.

### Apple Health Cycle Tracking + Clue (glyph reference) — HIGH

The cleanest logged-vs-predicted ink system in the family: "solid red
circles mark your logged period days … red **stripes** on a circle mark
when your period is predicted … light blue oval marks your predicted
six-day fertile window"; retro-estimates arrive only after the fact
([support.apple.com/120356](https://support.apple.com/en-us/120356)).
Clue's Cycle View = the purest "you are HERE on a personal ring"
([helloclue.com](https://helloclue.com/articles/how-to-use-clue/how-to-use-clue-plus)).

### Family grammar (why cycle apps feel personal)

1. Today is a position inside a loop **computed from her own data** —
   "Day 9" means something no one else's Day 9 means. HIGH.
2. Phase names do narrative work (seasons metaphor industry-wide; 28's
   verb names). HIGH.
3. **Solid past / dotted-striped-pale future / withdrawal under
   uncertainty** — prediction humility rendered typographically. HIGH.
4. The day carries an instruction, not just a label. HIGH.

---

## 4. Passive-data timelines

### Oura — HIGH (first-party blog + support docs)

2024-10-03 redesign: 5 tabs → **Today / Vitals / My Health**
([ouraring.com blog](https://ouraring.com/blog/new-oura-app-experience/)).
Today = scores, then "a dynamic 'daily highlight'" (rotates by hour of
day), then a **vertical timeline of the day** — auto-detected activities,
naps, 15-minute stress graph, 100+ searchable tags. Past compresses into
Vitals baselines ("personal baseline ranges for context") + weekly/
quarterly/yearly reports; PM quote: "helping you focus on the 'so what?'
of your health." **Tomorrow is never rendered as a day** — the only
future surface is *tonight* (Bedtime Guidance card "appears only on the
current day," needs 2 weeks of data). Guilt valve: **Rest Mode** disables
activity goals when sick. (Note: Oct-2025 press describes a further
refresh + biometric-reactive coloring; rollout timing discrepancy flagged,
LOW on dates, HIGH on existence.)

### Whoop — HIGH/MEDIUM

Today = two dials (Strain/Recovery traffic light) + **Strain Target**
computed from last night ("based on your personal, daily metrics like last
night's sleep and today's recovery") + a **Daily Outlook** morning
briefing — the purest passive→prescriptive loop: *today's assignment is
computed from yesterday.* Journal answers correlate into monthly health
reports (a reviewer: discovering evening alcohol hurt recovery "made it
feel like they were being guided toward a goal" —
[everydayindustries, 2023-01-04](https://everydayindustries.com/whoop-wearable-health-fitness-user-experience-evaluation/)).
**The cautionary tale:** Whoop killed in-app Weekly/Monthly Performance
Assessments on 2025-05-08, replacing them with an emailed "Month in
Review" — users revolted: "just a letter with pictures"; "I used to take
the MPA to my doctor"; "for a wearable that prides itself on data… the
month in review provides none"
([community.whoop.com, threads 2025-10→2026-06](https://www.community.whoop.com/t/new-month-in-review-is-a-huge-disappointment/9035)).
**Users experience report depth as the product's memory; removing
narrative depth reads as the coach forgetting them.** Replacement Weekly
Plan includes a **"Vacation"** mode — the guilt-release valve.

### Gentler Streak (the aesthetic reference) — HIGH (docs re-verified)

- **The Activity Path:** home screen = a **green shaded band** (your
  optimal activity range: lower boundary = "minimum level of activity
  needed to maintain or build fitness"; upper = warns "against pushing too
  hard") with a **white line running through it — your activity levels
  over time** ([docs.gentler.app](https://docs.gentler.app/understanding-your-activity-path/what-is-the-activity-path), verified 2026-07-06).
  The band is recomputed from recent workout intensity/duration/frequency
  + recovery: "dynamic and uniquely yours."
- **Today** = the current end of the line, "a dot positioned relative to
  this band" ([neura.health hands-on, 2026-07-03](https://neura.health/insight/gentler-streak-app-hands-on-review), MEDIUM);
  position is a 3-state machine: upper zone → rest/light recovery
  suggested; middle → "a good balance"; lower → "well-rested and can
  handle a more intense workout if you choose." An interpretation headline
  sits above the path (e.g. **"Kudos for Taking Action"**).
- **Future:** none rendered. Tomorrow is implied only by today's position;
  "Go Gentler" converts position → a menu of suggested workouts.
- **Anti-streak stance (first-party copy, quotable):** "Streaks that
  celebrate rest. Gentler Streak rewards consistency over perfection, so
  taking a break never means starting over." / "No guilt, no punishment.
  The app keeps you moving for months and years, not just days"
  ([gentlerstories.com](https://gentlerstories.com/gentlerstreak/), undated).
  Manual statuses — **Active / On a Break / Sick / Injured** — pause goals
  "without losing your progress."
- **Receipts:** monthly recap headlined by *"days in a month when users
  met their body's needs"* — adherence-to-band, not volume
  ([9to5mac, 2024-04-05](https://9to5mac.com/2024/04/05/gentler-streak-monthly-activity-recap/));
  weekly recap added 2025-11-19 with mid-workout photos; dev quote: "You
  can present data, or you can present it beautifully… how it makes you
  feel matters just as much as how accurate it is"
  ([9to5mac, 2025-11-19](https://9to5mac.com/2025/11/19/gentler-streak-rolls-out-weekly-recaps/)).
- **Credentials:** 2022 Apple Watch App of the Year; 2023 ADA finalist;
  **2024 ADA winner (Social Impact)** ([apple.com newsroom, 2024-06](https://www.apple.com/newsroom/2024/06/apple-announces-winners-of-the-2024-apple-design-awards/)).
  Apple Behind the Design, CEO Katarina Lotrič: "We want it to feel like a
  compass"; "If a 15-minute walk is what your body can do at that moment,
  that's great" ([developer.apple.com, 2024-07-11](https://developer.apple.com/news/?id=3m0ht22s)).

### Apple Fitness Trends — HIGH

Past compressed into a *direction* (90-day vs 365-day arrows), future into
a **7-day micro-contract** ("Burn 30 more calories each day for 7 days").
The rings month-grid remains the guilt-prone foil reviewers cite against
Gentler Streak.

### Family grammar (what makes a passive timeline feel coached)

1. An interpretation layer physically above the data. HIGH.
2. A **band instead of a binary goal** — three readable states where rest
   is legitimate, even praised. HIGH.
3. Statuses that absorb life (Sick/Injured/Break/Vacation/Rest Mode) so
   the timeline never renders failure. HIGH.
4. Tomorrow never rendered as a day — only "tonight" or "this week." HIGH.
5. Weekly/monthly reports = the program's memory (Whoop backlash as
   direct evidence). HIGH.

---

## 5. Memory/receipt grammars

- **Day One "On This Day":** every past entry written on today's date
  across years; opt-in daily notification; private, quiet, input-coupled —
  the resurface *feeds the journaling habit*
  ([dayoneapp.com](https://dayoneapp.com/features/on-this-day/), undated). HIGH.
- **BeReal:** Memories = a private calendar-grid of every daily photo
  ("only you can view"); annual Recap = flip-book video that **cannot post
  to BeReal's own feed** — export-only. The receipt is a gift, not a
  broadcast. MEDIUM (help-center fetch blocked; press-corroborated).
- **Spotify Wrapped:** the canonical annual data story. 2023 "Sound Town"
  → **2024 backlash edition** (AI podcast + made-up microgenres; sentiment
  50.5%→41.5% positive, third-party social listening;
  [Forbes, 2024-12-05](https://www.forbes.com/sites/danidiplacido/2024/12/05/spotify-wrapped-2024-backlash-controversy-and-memes/);
  [TechCrunch, 2024-12-04](https://techcrunch.com/2024/12/04/spotify-users-are-disappointed-by-an-underwhelming-wrapped-this-year/))
  → 2025 repair edition (restored genres/albums, "Listening Age";
  [NPR, 2025-12-04](https://www.npr.org/2025/12/04/nx-s1-5632595/spotify-wrapped-listening-age)).
  500M+ shares 2025, +41% YoY (first-party via marketing analyses,
  MEDIUM). **The lesson: accuracy is the license.** The identity claim
  holds only while the mirror is recognizably *you*; the moment output
  reads as "AI slop about me" instead of "me, rendered beautifully," the
  whole mechanic collapses. HIGH.
- **Strava:** Year in Sport 2024 built on "the activity card … capturing
  135 million personal stories" (first-party; ECD's own case study,
  [khoibphan.com](https://www.khoibphan.com/portfolio/strava-year-in-sport-24));
  every scene has its own share button. Weekly Snapshot atop the feed;
  monthly recaps; and the quietly important **Relative Effort week bar:
  this week's effort plotted against a white band = your own trailing
  3-week average range** — green in range, red above, blue below; weekly
  push: "You kept it consistent this week. Kudos to you!"
  ([support.strava.com](https://support.strava.com/hc/en-us/articles/360000197364-Relative-Effort)).
  *The weekly receipt is normalized against your own baseline, not a
  universal goal.* HIGH.
- **Apple Journal/Photos Memories:** resurfacing as delight, but Six
  Colors' verdict — "introspection, surface-deep"
  ([sixcolors.com, 2023-12](https://sixcolors.com/post/2023/12/ios-17-2s-journal-app-offers-introspection-surface-deep/)) —
  shows resurfacing without narrative or effort-link produces delight,
  not meaning. MEDIUM.

### Receipt grammar synthesis — HIGH

1. **Deposited beats harvested.** Receipts of deliberate acts (entries,
   posts, workouts, plates) close a loop the user opened; passive exhaust
   needs the full Wrapped treatment to cross the line, and stays fragile
   there.
2. **Cadence ladder = privacy ladder.** Daily resurface: intimate,
   unshared. Weekly recap: self-regulatory, normalized vs your own
   trailing baseline. Annual: public identity artifact with per-slide
   share affordances. Shareability scales with the time horizon.
3. **Never post on the user's behalf.** Export-only sharing everywhere.
4. **Accuracy is the license; beauty is the delivery** (Wrapped 2024 vs
   Gentler Streak's "how it makes you feel matters as much as accuracy").

---

## 6. Plan adaptation made visible (the trust anatomy)

### MacroFactor weekly check-in — the reference implementation. HIGH (help docs re-verified 2026-07-06)

- **The user picks the check-in day**; when available, "a small alert
  indication on the Strategy tab"; the user initiates by tapping Check-In.
  Nothing changes until she does
  ([help.macrofactorapp.com/247](https://help.macrofactorapp.com/en/articles/247-introduction-to-check-ins-and-coaching-modules)).
- **Explanation before change:** the MF Coach introduces each Coaching
  Module and "explain[s] why the module is being surfaced at this Check-In
  at this precise moment." Modules: Partial Logging, Weigh-In, Fasting,
  Logging Break, **Program Update** (the new calorie/macro prescription).
- **Consent + escape hatches at every layer:** approve/decline each
  change; "permanently dismiss any module that you did not find useful";
  dismiss the whole check-in; or **Fast Check-In** ("skips past all
  Coaching Modules and jumps straight to updated macro recommendations").
- **Consent is a dial:** program styles **Coached** (app adjusts, with
  guardrails) / **Collaborative** (app adjusts weekly budget only) /
  **Manual** ([help/91](https://help.macrofactorapp.com/en/articles/91-program-styles)).
- **Adherence-neutral tone** (Nuckols: no "functional and visual elements…
  that would attempt to cajole people into adhering… or shame people for
  not adhering"; [macrofactor.com/adherence-neutral](https://macrofactor.com/adherence-neutral/), 2025-09-12) —
  because shame suppresses logging and the algorithm eats logs.
  Adjustments compute **forward from what she actually did**, so imperfect
  weeks still produce a valid new plan.
- **Trust evidence (review-shaped, MEDIUM):** "the app will auto adjust my
  calories and macros during check in is motivating" (App Store);
  reviewers repeatedly attribute trust to *showing the math* ("estimates
  your TDEE from your weight trend data and shows you the math").

### Garmin — the "why" retrofit. HIGH

Daily suggested workouts adapted silently for years; **Nov 2024 Garmin
added explanations** — what the workout targets, and why it changed: "due
to high run mileage," "to account for your significant jet lag"
([the5krunner, 2024-11-12](https://the5krunner.com/2024/11/12/garmin-adaptive-plans-get-improved-explanations/)).
Garmin Coach deliberately forbids rescheduling missed workouts — "adapts
to what you actually completed" — and forums show users frustrated *until
the philosophy is explained*. Silent adaptation without a why reads as
arbitrary; the same adaptation with a stated reason reads as coaching.

### Anatomy of a good adaptation moment (synthesis, HIGH)

1. **A named, scheduled ritual beats silent drift** — trust accrues to the
   moment (MacroFactor check-in day, Runna Monday popup, Whoop Monday).
2. **Explain from the user's own data, causally** ("your expenditure trend
   + your weight trend → this budget"; "due to high run mileage"; "vs your
   3-week average") — never population norms.
3. **Consent is a gradient** (approve-each / approve-budget / no-touch) +
   a Fast path for veterans.
4. **Escape hatches preserve trust** — dismiss/decline is never punished.
5. **Adherence-neutral:** compute forward from what happened; never scold
   what didn't.
6. Controlled evidence that explained changes increase plan trust: **not
   found** — evidence is review-shaped and behavioral (backlash cases).

---

## 7. Layout grammars — strip vs grid vs vertical timeline vs path

- **Horizontal week strip:** compact 7-day frame, one-row cost, today ± a
  few days one tap away ([setproduct calendar-UI guide, 2022-11-07](https://www.setproduct.com/blog/calendar-ui-design)).
  Weaknesses inherit NN/g's horizontal-scroll findings (content off-frame
  is systematically missed; partially-bled items are the reliable cue;
  [nngroup.com](https://www.nngroup.com/articles/horizontal-scrolling/)) and the
  **"Illusion of Completeness"** — a clean 7-day frame looks complete, so
  users never suspect the month behind it. Wins for date-scoped logging +
  short-horizon rhythm; loses for history density and long arcs. HIGH.
- **Month grid / heatmap:** at-a-glance pattern recognition; canonical 3
  states (filled/outline/today) ([RapidNative, 2025-10-29](https://www.rapidnative.com/blogs/habit-tracker-calendar)).
  Its pathology: **it renders absence** — every missed day is a visible
  hole. Hostile to lapse-prone/anti-shame cohorts (the direct opposite of
  the dateless path, where a two-week lapse leaves zero scar). HIGH.
- **Vertical timeline:** native scroll physics (every NN/g horizontal
  caveat disappears); unbounded past above / future below; "scroll up =
  history" needs no teaching; cards can be arbitrarily tall (photos,
  letters, receipts). Costs: current position drifts → **needs a snap-back
  FAB** (Duolingo's arrow is the canonical solution); low density (~5-8
  nodes per viewport vs 35 days in a grid). MEDIUM-HIGH.
- **Path/map:** a vertical timeline wearing a costume — nodes indexed by
  content, not time. Buys narrative habitation + lapse forgiveness; costs
  agency (documented revolt), random access, and honesty about density.
  Needs escape valves (jump-ahead, dedicated review surface). For
  fragile-identity domains, failure-on-a-path reads as personal
  inadequacy, not chance (Game Developer, 2020-03-19); Finch's 2025
  retreat from Journeys is the live wellness datapoint. HIGH.

**When each wins:** week strip = the rhythm surface; month grid =
retrospective pattern pride (dangerous for shame-prone cohorts); vertical
timeline = narrative sequence + unbounded history + resume; path = maximal
journey-feel for fixed content curricula, minimal agency.

---

## 8. Behavioral science (all verified; venue + finding per item)

1. **Fresh start effect** — Dai, Milkman & Riis, *Management Science*
   60(10) 2014 (PDF read): aspirational behavior (diet searches, gym
   visits, goal commitments) spikes after temporal landmarks — new week /
   month / year / semester, birthdays. Mechanism: landmarks open "new
   mental accounting periods" that relegate the past, imperfect self to a
   previous period. Follow-up (*Psych Science* 26(12) 2015, PMC full
   text): labeling March 20 "first day of spring" vs "third Thursday in
   March" lifted choosing it for goal pursuit **25.61% vs 7.23%** — a
   3.5x lift from pure relabeling; effect mediated by disassociation from
   the past imperfect self. **Manufactured landmarks work if framed as
   beginnings.** Caution (Dai 2018, OBHDP, LOW): anticipating a reset
   point can license pre-boundary slacking. HIGH.
2. **Goal-gradient** — Kivetz, Urminsky & Zheng, *JMR* 43(1) 2006 (PDF
   read): café interpurchase times "decrease by 20% or .7 days" as the
   reward nears; effort tracks the **proportion of distance remaining**;
   and there's a **post-reward reset** — effort drops after each earned
   milestone, then reaccelerates. Distance-to-goal displays accelerate
   only near the goal; "61 days left" early is demotivating. HIGH.
3. **Endowed progress** — Nunes & Drèze, *JCR* 32(4) 2006: 10-stamp card
   with 2 pre-stamped beats 8-stamp blank card — **34% vs 19% completion**
   (numbers via converging secondaries, MEDIUM; direction HIGH from
   abstract), faster completion, and the effect **requires a stated reason
   for the credit**. Never start a user at 0/M; onboarding is legitimately
   completed work. HIGH/MEDIUM.
4. **Small-area hypothesis** — Koo & Fishbach, *JCR* 39(3) 2012 (abstract
   fetched): motivation is higher attending to **whichever area is
   smaller** — accumulated progress early, remaining progress late.
   Mechanism: illusion of fast progress (each action is a larger share of
   the small area). **The single most applicable citation for day-N-of-M:
   the framing must switch at the midpoint.** HIGH.
5. **Stuck in the middle** — Bonezzi, Brendl & De Angelis, *Psych Science*
   22(5) 2011 (abstract read): motivation is U-shaped — high near start
   and end, lowest ~halfway, because marginal progress feels smallest far
   from both reference points. **Week-level units abolish the middle**: a
   user is never more than ~3 days from a start or an end. A 12-week
   program rendered as 12 small arcs has twelve acceleration zones and no
   dead center; one 84-day bar has a six-week swamp. HIGH.
6. **Streaks** — Silverman & Barasch, *JCR* 2023: the *logged streak
   record itself* (not behavior history) drives continuation, and once
   broken the force **reverses** — engagement drops below what history
   justifies, worst under self-attribution. Duolingo first-party: streak
   animations +1.7% new-learner D7 retention; second streak freeze +0.38%
   DAU; 7-day-streak learners 3.6x course completion
   ([blog.duolingo.com](https://blog.duolingo.com/how-duolingo-streak-builds-habit/)).
   Lally et al., *EJSP* 40(6) 2010 (verbatim confirmed): **"missing one
   opportunity to perform the behaviour did not materially affect the
   habit formation process"** (median 66 days to automaticity, range
   18-254). → **Presence counting (never resets) keeps the motivating
   property and deletes the reversal.** HIGH.
7. **Guilt/shame in tracking** — Cordeiro et al., CHI 2015 (141 journalers
   + 5,526 forum posts): apps' own **"negative nudges"** are a named
   abandonment cause. Eikey & Reddy, CHI 2017 (16 women with ED
   histories): weight-loss apps can exacerbate ED behaviors; **breaks from
   the app can be beneficial** — the app should tolerate, even support,
   absence. Diefenbach & Müssig, *IJHCS* 2019 (Habitica): punishment
   mechanics backfire — all participants experienced counterproductive
   effects. Breines & Chen, *PSPB* 2012: self-compassion *increases*
   self-improvement motivation; Sirois et al. 2015 meta (15 samples,
   N=3,252): self-compassion ↔ health behaviors r=.25. **Compassionate
   post-lapse copy is the empirically more motivating frame, not
   softness.** HIGH.
8. **Peak-end rule** — Redelmeier & Kahneman, *Pain* 1996: remembered
   experience = peak + final moments; duration largely neglected. Amabile
   & Kramer, HBR 2011 (~12,000 diary entries): progress in meaningful work
   is the top driver of inner work life; **setbacks loom larger than
   wins**. → The weekly recap IS the week, memory-wise: peak-forward,
   never ends on a deficit. MEDIUM-HIGH.

---

## 9. Anti-pattern ledger (what makes a guilt calendar)

Documented, with the app that paid for it:

1. **Locked future + miss-equals-restart** (Peloton 2.0 → reversed 2025).
2. **Empty-day graveyards / heatmaps of absence** (month grids render
   holes; Cordeiro's "negative nudges"; Apple rings as the cited foil).
3. **Silent time-marching** — the week rolls at midnight Sunday regardless
   (Sweat); content resets and unsaved work vanishes (Ladder Sunday 6pm).
4. **Silent adaptation** — plans that never re-ask after day 1 (Runna
   forum complaints; NRC static plans); or adapt invisibly with no why
   (Garmin pre-2024).
5. **Resettable streaks as the spine** — broken-streak reversal effect
   (Silverman); Duolingo's own repair is forgiveness mechanics.
6. **Report withdrawal** — killing narrative depth reads as the coach
   forgetting you (Whoop MIR revolt, 2025).
7. **Surveillance-flavored accountability** ("hard to get away with
   skipping" — Future); for an ED-adjacent cohort this is clinical risk,
   not just churn risk (Eikey).
8. **The mirror that isn't you** — machine-flavored recaps ("AI slop about
   me") collapse the identity claim (Wrapped 2024).
9. **Forced linearity without escape valves** — path backlash ("sometimes
   you just want to do some easy lessons because you're tired").

---

## 10. What makes it feel like "a program I'm inside" — the signal stack

Across all five families, the inside-a-program feeling decomposes into
seven signals (each with its best-in-class carrier):

1. **A position index computed from HER data** — "day 9" that means
   something only for her (cycle apps; Runna race countdown).
2. **Phase/chapter names that pre-interpret the day** (28's
   Restore/Awaken/Perform/Balance; Runna's taper/deload; Fabulous
   chapters).
3. **An interpretation line physically above the data** — the program
   *reads* the timeline out loud (Gentler Streak "Kudos for Taking
   Action"; Whoop Daily Outlook; Oura daily highlight; coach voice).
4. **Today as an instruction, not a highlight** (NC "Use Protection";
   Whoop strain target; 28's workout; Runna Today tab).
5. **A visible arc with shaped weeks** — the future has *shape* (lighter/
   heavier days, deload coming) without being a locked schedule.
6. **Adaptation as a signed moment** — the plan visibly answers her data
   at a named ritual (MacroFactor; Runna Monday).
7. **Accumulating memory** — receipts that only grow (history ledgers,
   weekly artifacts, completion receipts; "how many classes you did that
   previous round").

A todo list has none of these: undifferentiated items, no position, no
phases, no reader, no memory, no re-planning. **The difference between a
program and a checklist is that a program remembers, interprets, and
answers.**

---

## 11. Implications for the JeniFit plan-over-time surface

Context: v3 already holds the right primitives — PresenceLedger (kept
days, any action, never resets), BreakState, chapters (losing /
on-medication / keeping), BandModel zones, jeni's reading as the
interpretation layer, THE ONE THING as today's instruction. What's missing
is the *place where time is visible*: her position, her past, her arc.
The research says build it as follows.

1. **Grammar choice: a vertical journey ledger, chaptered by weeks — not a
   node path, not a month grid.** The month grid renders absence (anti-
   pattern #2, clinical risk for this cohort per Eikey); the Duolingo-
   style node path costs agency and reads gamified against the clean-
   luxury register; the vertical timeline gives unbounded past, tall
   editorial cards (plates, weigh-ins, jeni lines), native scroll, and
   lapse-forgiveness. Keep a compact **7-day strip on Today** for rhythm
   (its frame IS the week), and make the strip open the full journey — the
   strip alone creates the "illusion of completeness" trap. Gentler
   Streak's band-and-line is the aesthetic register to steal (organic
   line through a soft band, ADA-winning, anti-guilt by construction),
   not Duolingo's pebbles.
2. **Anchor: today at the bottom edge, scroll up = her past, with a
   snap-back-to-today affordance** (Duolingo's FAB is the canonical
   solution; position drift is the vertical grammar's one tax).
3. **The week is the narrative unit, named, week-N-of-M small.** Every
   week gets a title in jeni's voice keyed to chapter + engine state
   ("week 4 · the appetite settles"), because phase names pre-interpret
   days (28, Runna taper) and week units both mint a fresh-start landmark
   every Monday (Dai/Milkman) and abolish the mid-program swamp (Bonezzi).
   "Week 4 of 12" renders quietly; the name carries the meaning. M comes
   from `plan.totalDays` — never hardcoded.
4. **Past days render as receipts of what happened — never what didn't.**
   A kept day = a solid ink mark + tiny artifacts (plate thumbnails,
   weigh-in delta, steps, the rep). An absent day = compressed, unmarked
   paper — no grey X, no outline, no "missed" (Cordeiro, Diefenbach,
   GS's "no guilt, no punishment"). Days without action simply take less
   vertical space; stretches of absence collapse into a single quiet seam
   ("a few days passed"). Tap a past day → read-only day recap: what she
   did, what jeni observed that day (the her-file page for that date).
   Backfill only for weight/food via existing flows; the recap itself is
   memory, not homework.
5. **Solid past, distinct today, dotted future.** Steal the cycle-app ink
   caste system verbatim: logged = solid; today = the one large,
   instruction-bearing card (THE ONE THING + position line); future = pale
   /dashed *shape* previews — "tomorrow: a lighter day," the coming week's
   rhythm shape — never a locked list, never padlocks (v3 rule holds; the
   entire industry converged on preview-or-nothing). And **withdraw
   predictions under uncertainty** (Flo): if the engine isn't confident
   past ~3 days, show the week's shape, not day-by-day promises.
6. **Presence, not streak, is the spine number** — PresenceLedger is
   already the scientifically correct object (Silverman's reversal effect;
   Lally). Render "N days kept" as the header count early in the program
   and switch the lead to "N to go" past the midpoint (Koo & Fishbach) —
   at both program and week scale. Endow day 1 with a stated reason:
   her intake built the plan, so she starts at 1/M, never 0/M (Nunes &
   Drèze: credit needs a reason or it reads fake).
7. **BreakState renders ON the timeline as a held place, not a hole** —
   "on a break · your place is kept" (GS statuses; Whoop Vacation; Eikey:
   supporting absence is a feature). Re-entry gets a fresh-start frame
   ("Monday is a clean page") because the mechanism is disassociation from
   the past imperfect self — exactly what a lapsed user needs.
8. **Adaptation = jeni's weekly re-signing, MacroFactor-anatomy.** One
   named ritual on her chosen day: jeni explains what she saw in HER data
   (weight trend, protein adequacy, rhythm), proposes the next week's
   shape, asks consent — approve / adjust / "not now," dismissal never
   punished, with a fast path once trust exists. Mid-week breaks get the
   Runna fork (pick up where you left off / soften this week / extend the
   chapter) with the cost of each stated. Every plan change must be
   visible at a moment and attributed to her data — silent re-planning is
   anti-pattern #4.
9. **The receipts ladder:** daily = one quiet jeni line on the day card
   (private); weekly = the artifact of the week — peak-forward, normalized
   against her own trailing baseline (Strava RE band), never ending on a
   deficit (peak-end + Amabile's asymmetry), shareable by export only;
   chapter-end = the earned keepsake moment (sticker-scatter tier).
   Accuracy is the license: every receipt quotes her real logged data or
   it collapses the mirror (Wrapped 2024; data-provenance rule already in
   house).
10. **Depth stays accessible.** The journey is also the archive — food/
    weight/step history reachable from any day, her-file accumulating.
    Never shrink the memory surface once shipped (Whoop MIR revolt:
    report depth IS the relationship).
11. **What makes it a program, checked against §10:** position from her
    data (day N · week name · chapter) ✓; phases ✓ (chapters); the reader
    ✓ (jeni's line above the timeline, GS-style); today as instruction ✓
    (THE ONE THING); shaped future ✓ (dotted rhythm previews); signed
    adaptation ✓ (weekly re-signing); accumulating memory ✓ (receipts +
    her-file). The old calendar strip only ever provided navigation; this
    surface provides *testimony* — the program remembers her, interprets
    her, and answers her. That is the felt difference between "I have a
    todo list" and "I am inside a real program."

Open questions for design (not settled by evidence): how much of the
journey lives on Today vs its own surface (research supports strip-on-
Today + full vertical journey one tap deeper); whether chapter transitions
shift the visual atmosphere (Duolingo section-artwork evidence: not
found); exact recap-share appetite for this cohort (Wrapped mechanics are
annual-scale; weekly shares unproven — treat share as export-only, low
pressure).
