# 77 — THE PRODUCT CRITIC

**feat/app-v2 · built 2026-09-04, after 76.** A new-session product
quality pass under an explicit mandate to NOT inherit prior
confidence: fresh research first (four parallel external sweeps —
long-term weight-loss needs · GLP-1 lived workflows · competitor
retention/review mining · longitudinal-value patterns — plus a full
current-surface map), then realistic customer walks over the seeded
multi-month personas, then the smallest set of changes the evidence
demanded. Most of what previous passes built survived the attack;
four things did not.

## 1 · What the fresh research established (77_evidence/00)

The four sweeps converged on a short list:

- **The category's #1 daily loop is the morning verdict**: weigh →
  open app → see the smoothed trend answer the anxious question
  ("did today wreck it?"). Happy Scale's decade-tenure reviews are
  this loop as a product. The single densest community-question
  cluster is scale interpretation ("why did my weight jump
  overnight", "is this a plateau") — and incumbents answer it in
  blog posts, not at the moment of the spike.
- **The GLP-1 category's open seam is the CONNECTED record**: dose ↔
  weight ↔ symptoms ↔ food noise on one timeline. Every companion
  app owns a fragment (Shotsy the dose rhythm, Happy Scale the
  trend, MFP the food); nobody credibly unifies them with honest
  interpretation. The standard 2026 GLP-1 stack is 3–4 apps glued by
  Apple Health. Jeni's p74 dose-era work sits exactly on this seam.
- **"Where am I in my dose week" is the cohort's most-loved daily
  read** (Shotsy's level curve, Glapp's per-dose reports; "my candy
  thoughts come back on day six"). Jeni refuses the modeled PK curve
  rightly — but the event-anchored position + her own recorded
  patterns is measured, not modeled, and Jeni computed it for the
  coach envelope while never showing it to HER.
- **Grade-shaped zeros are a named trust failure** (red numbers, "0
  of N" scores, streak debt): they truncate logging and corrupt the
  record (BJPsych qualitative work; MacroFactor's adherence-neutral
  law is the reference behavior).
- **What makes accumulation feel valuable**: insight traceable to
  her own rows · silence floors before speech · derived numbers with
  visible derivation · absence as context, never debt · recaps of
  the life, not the app. Jeni's engines already encode most of this
  (sufficiency ladder, floor-gated observations, era honesty gates).

## 2 · What the walks convicted (films in 77_evidence)

Walked as a customer over `--uitest-seed-becoming glp1/stall/sparse`
on QA-iPhone16, driven by the walker-arm plus a new `openurl` script
command (below).

1. **The weigh-in moment answered with a fortune cookie** (the
   category's #1 loop, missed). Every kept beat after the second
   weigh-in said "single days bounce. the 7-day trend is what
   counts." — the same aphorism, every morning, forever — while the
   verdict it points at sat one engine call away. The morning the
   scale spikes, the product had NO answer at the moment of the
   spike; the "usually water, not fat" copy lived a tab away inside
   a weekly review (`InsightEngine.trendStory`'s one consumer).
2. **Chat answered the record's own questions generically** (walked
   live, `07`): "why is my weight up today?" → "water retention,
   sodium intake, or just normal day-to-day variation… check the
   7-day view" — the exact ChatGPT-without-the-record failure, with
   `read_weight_trend` unused, `ema_delta_7d_kg` unread in the
   envelope, and her own record showing sodium DOWN 35% while the
   model guessed "sodium intake". "appointment tomorrow, what should
   I bring up?" → "great to hear you have an appointment!" + a
   generic listicle, with the visit packet unmentioned. The tool
   descriptions were already directive; the model skips opaque keys
   and skips tools it doesn't need — it quotes sentences.
3. **The weekly read still carried a p74-class zero-grade** (`01`):
   the stat band rendered "protein goal · 0 days" beside an easing
   proposal — a score of the exact shape p74 killed on the body
   review ("protein reached 130g on 0 of N days").
4. **The dose-week position was invisible product-wide.** Home's
   standing frames only the future ("in 6 days"); the regimen page
   said "next dose · thursday" but never "day 2 of your dose week"
   (`08`) — the felt rhythm the cohort plans meals and workouts
   around, already computed honestly for the envelope.

**Walked and left alone (the honest half):** Becoming's hero answers
job #1 in one card (trend ink over raw gray, whole distance always,
`02`); the year lens draws labeled dose seams (`03`); the weight
page's era ledger answers "what happened at each dose" exactly
(`04`); the stall persona gets the flat-week/moving-month
reassurance in the right slot (`05`); the sparse persona keeps its
dignity ("a few more weigh-ins and your trend line starts", "still
filling in", `06`); the regimen page's facts-as-doors + dose ledger
with sites; the visit packet discoverable under "your record" for
every cohort; chat's instant insert + honest dots (p76). The sodium
delta card was challenged (statistic leads, meaning trails) and
left — floor-gated, honest, meaning present; deletion wasn't earned.

## 3 · What shipped

① **THE WEIGH-IN ANSWERS WITH HER TREND** — `WeighInReceipt`
(pure, 13 pins): the kept beat's sub speaks the SAME fold Becoming
draws, recomputed AFTER the save so this morning's number is inside
it. "done · your trend reads down about 1.6 lb this week." — and on
a spike morning (saved ≥ 0.45 kg above the fold), the answer the
whole category outsources to Reddit, at the exact anxious moment:
"this morning sits above your line. the trend still reads down about
1.6 lb this week." (filmed both ways, `09` `10`). A flat week passes
through `BecomingStory.steadyContext` when the month is moving (the
reassurance lands where the anxiety is); an up trend is stated
plainly, never scolded, never wrapped in water reassurance a
week-scale fact doesn't support; provisional speaks direction
without numerals ("an early read: trending down."); insufficient /
stale / suppressed → nil and the ritual keeps its standing copy.
Deltas only, never the smoothed absolute — a second numeral beside
the one she just typed is Happy Scale's own documented confusion
tax. Wired via a post-save closure (`keptWhisper`) from
TodayModuleHost; the keeping chapter's band whisper keeps
precedence (maintenance has its own verdict).

② **CHAT SPEAKS THE RECORD WITHOUT A TOOL CALL** — the envelope
gains sentence-shaped facts the model actually quotes:
- `weight.trend_read` (`WeighInReceipt.modelLine`, pinned): "her
  smoothed weight trend reads down about 1.6 lb over the last week,
  resting on 17 weigh-ins. quote this fold for 'am i losing' and
  'why is my weight up', never a single day's number." Provisional
  carries an early-read marker; stale names its age and asks for a
  weigh-in instead of a direction.
- `medication.eras_newest_first` + `weeks_at_dose` — per-era weight
  response from the SAME builder as the dose seat and the weight
  page's era rows (`BecomingStory.doseSeat`): "on 1 mg: down 7.5 lb
  · 8 wks". Young era says "early to read"; numeric suppression
  strips numerals inside the builder; an `eras_note` pins timing-
  never-causality and no dosing advice.
- `read_dose_history`'s description now routes the appointment
  question: read doses + symptoms + trend, answer from her record,
  then point at the visit packet.
Re-walked live: "why is my weight up today?" now closes with "your
smoothed weight trend reads down about 1.6 lb over the last week"
— her record, in the answer (the generic preamble that remains is
the EF system prompt's register, deploy-gated, named below).

③ **THE ZERO-GRADE DIES IN THE WEEKLY READ** — the "protein goal ·
0 days" stat cell and the "protein goal hit 0 of N days" observation
both require ≥1 met day now (+1 pin). A week that never reached the
floor speaks through the easing proposal — a change, not a score.
The proposal's own evidence sentence ("130g landed 0 of 7 days. a 5g
lower floor fits this week.") deliberately survives: it justifies
lowering the bar, the adherence-neutral direction.

④ **THE FELT WEEK, STATED** — the regimen page carries "day 2 of
your dose week" under the next-dose line (filmed, `11`), from
`MedicationScheduleEngine.cyclePosition` — event-anchored from her
own recorded doses, nil while an open slot outranks the rhythm, nil
for cycle-less rhythms (daily / as-needed / splits), interval
rhythms say "day N of M in this dose cycle". Facts only; the
pattern reads below it carry any earned timing observations.

⑤ **Walker-arm: `openurl`** — deep-link driving (jenifit://weigh-in)
for surfaces below the fold synthesized drags can't scroll to (the
standing v12 sim class).

## 4 · Refused / deferred, with reasons

- **Weight-number milestones and celebration** (Happy Scale's
  ratchet, the research's strongest longitudinal mechanic) — the
  standing celebration law (p63, founder-decided) bans celebrating
  weight numbers, for reasons the research itself supports for this
  cohort (regain reads as failure; ED-risk). The whole-distance ink
  scene remains the chosen milestone surface, reached by her own
  hand. Not re-litigated in an autonomous pass.
- **An adaptive expenditure model** (MacroFactor's moat; the #1
  "app learns me" request class) — the highest-value NOT-built thing
  in the product. Jeni's targets are formula+pace; an
  expenditure fold learned from her own intake+trend would compound
  exactly the way the research says retention compounds. It needs
  its own pass: error-bar honesty, weeks of validation against
  seeded histories, a trust-explanation surface, and founder
  alignment on presenting a derived energy number. Named, not
  smuggled.
- **A modeled medication-level curve** — re-refused (v24 law;
  modeled ≠ measured), even though it is Shotsy's most-loved
  surface. The event-anchored position (④) is the honest fraction.
- **Cycle-phase weight context** — real repeated pain (whole apps
  exist for it), but CycleService's stand-down rules are narrow by
  design and the founder flagged this territory (p62) as a
  founder-thought; not expanded autonomously.
- **A new `show_visit_packet` chat tool** — tool NAMES are
  allowlisted server-side; a new name is an EF deploy (founder-
  gated). The description routing in ② is the no-deploy fraction.
- **Sodium delta card demotion** — challenged, left standing
  (floor-gated, honest, meaning present, p73/p74 filmed).

## 5 · Verified

- `WeighInReceiptTests` 13/13 (new-behavior pins, not RED→GREEN
  repairs — a brand-new pure engine has no before-state to go red).
- `WeeklyReadComposerTests` 13/13 incl. the new zero-grade pin;
  `JeniToolsTests` 26/26 (description sweep) — full suite + Release
  build below.
- Films: kept beat ordinary + spike (`09` `10`), regimen position
  (`11`), chat before/after (`07` vs the walk11 tree), as-found
  states (`01`–`08`).
- The live dose-era chat answer was NOT verified end-to-end (a
  walker keyboard artifact ate the second message twice); the
  mechanism is verified through the same builder's on-screen rows
  and the envelope unit path. Named below.

## 6 · Why does someone keep Jeni? (the honest answer, end of pass)

Because it is the one place the scale, the dose, the plates and the
felt week explain each other — and it answers the questions those
connections raise AT THE MOMENT they're asked: the kept beat answers
the spike, Becoming answers the period, the era ledger answers the
dose change, the weekly read proposes the next adjustment, and chat
now quotes the same folds. The basics are competitive alone (trend
verdict, dose ledger, effortless plates); the connections are the
part no shipping competitor owns. What it does NOT yet earn: an
energy model that learns her (named above), and the six-month
lookback register. The record compounds; the interpretation now
reaches most of the moments — that is this pass's honest delta.

## 7 · Named, not done

- The EF system prompt still opens the weight-spike answer with
  generic causes before her record (deploy-gated; the envelope now
  outranks it in practice but the register fix is server-side).
- Live end-to-end film of the dose-era chat answer (walker keyboard
  artifact; the envelope path is unit-verified).
- The adaptive expenditure pass (see §4 — the biggest justified
  build this critic found).
- Kept-beat AX5 film (JeniReceiptBeat is the p63 kit receipt with
  Dynamic Type handling; the new sub is two lines at standard).
- A `--uitest-open-weigh-in` door existed in no form; `openurl`
  covers it — but the QA regimen hydrate overwrites seeded regimens
  on unseeded relaunches (walked, documented p51 class): re-seed
  every launch when walking GLP-1 personas.
- p70–p76 standing lists.

**No migration, no schema, no SQL, no deploy, no production
mutation. Chat/EF calls were the shipping read paths on the standing
QA account. NOT ARCHIVED, NOT UPLOADED, NOT SUBMITTED.**
