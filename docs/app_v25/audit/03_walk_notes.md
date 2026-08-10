# v25 audit — 03 · walk notes (the shipping app, as walked)

Walked 2026-08-10 on the dedicated QA sim `QA-iPhone16`
(259952D4-444F-4EFE-864A-F3DD5FBA5D22), iOS 26.2.
Build: **installed from DerivedData product of 2026-08-09 21:20**
(ship-day v24 build, clean tree at e3bb8f4; `plankAI.debug.dylib`
verified to contain the v24 door strings; Info.plist 1.1.7 (28)).
No rebuild. All media under
`/private/tmp/claude-501/-Users-bko-plankAI/63c2419e-a466-4a37-93bf-edc870a04838/scratchpad/walk/`.

Base args used: `--uitest-inapp-qa --uitest-pro-access
--uitest-seed-program --uitest-seed-week --uitest-seed-medication <v>`.
`--uitest-seed-program` is NOT optional — without it a fresh install
lands on the program-ready gate, not Home (see §1).

## 0 · door ledger (what responded in this build)

WORKED
- `--uitest-inapp-qa --uitest-pro-access` (entitlement + QA phase)
- `--uitest-seed-program` (skips the "start my program" gate)
- `--uitest-seed-week` (860 kcal logged, plates, weight line)
- `--uitest-seed-medication injectable|oral|b2b|history` — with a
  caveat: a later SELF seed does not supersede an existing CLINIC
  (b2b) regimen. injectable→oral swapped fine; b2b→history left the
  b2b Wegovy plan standing; `history` only seeded after wiping app
  data. Coherent with supersede-law (clinic authority), but it makes
  seed order matter for QA.
- `--uitest-open-dose-sheet`, `--uitest-open-regimen`
- `--uitest-care-mode`, `--uitest-start-tab jeni|scan|becoming`
- `--uitest-today-bottom`; `--uitest-becoming-bottom` (only when
  combined with `--uitest-start-tab becoming`; alone it stays on Home)

NOT RESPONDING (film doors — every one produced a static Home film)
- `--uitest-walk-carousel`, `--uitest-walk-book`,
  `--uitest-walk-medication`, `--uitest-walk-scope`,
  `--uitest-walk-strip`, `--debug-gallery-tour` (given 180s)
- `--uitest-open-food-journal` (stays on Home)

Read on the failures: these `walk-*` args appear to be XCUITest
walker ARMS (the walker test passes them and drives externally), not
in-app self-driving tours — consistent with the eras' "walker legs
run SOLO" notes. Nothing self-navigated in 80-180s; the hero page
dot never left face 1. Films exist but show a still Home; frames
02-carousel/frames/f_016.png and f_160.png are identical.

## 1 · the program-ready gate (before Home exists)

`.../walk/01-home-still/home_settled.png` (base args WITHOUT
seed-program on a fresh install)
- "your program is ready." serif hero + italic *ready*; body copy
  "we used what you told us in onboarding…".
- WHAT'S INSIDE ledger rows: each day "a *ritual* of 3 to 5 beats",
  food "*paced*, never a strict diet", movement "matched to *your*
  energy", the method "a 2-minute *read*, most days".
- Full-width ink pill "start my program"; the 4-tab bar is ALREADY
  visible behind the gate (gate rides inside the today tab, not as a
  modal cover).

## 2 · HOME (today tab), top to bottom

Frames: `01-home-still/home_settled_2.png` (top),
`13-depth/today_bottom.png` (bottom).

Top → bottom IA as walked:
1. Greeting "morning, *maya*." (serif ink + greyed italic name) ·
   blush pill "day 12" · settings gear (top-right, per law).
2. Week strip S-9 … S-15, selected day = ink disc (M 10). Chevron
   hint at right edge.
3. "calories" label → HERO ring: 96pt-class numeral 860, "of 1,473
   kcal", "613 left" bold; berry progress arc on blush track.
   5 page dots (hero carousel; only face 1 reachable by doors).
4. TODAY + "0 of 2" counter. Cap rows as white surfaces w/ chip +
   render-only circle: "take today's shot / your dose day" (pill
   glyph, grey chip) and "add a meal / protein still anchors the
   day" (rose fork chip).
5. Support rows OUTSIDE the cap, visually distinct: dashed-outline
   ghost chips, no circles — "water / water sits easier than food
   these weeks. small sips…" and "move / 10 min · steady". The v24
   cadence-outside-the-cap law is visible in the pixels.
6. TOOLS grid (2-col): snap a meal ("2 plates today", camera chip) ·
   weigh in ("logged today", ink spark line) · body check-in ("stays
   on your phone") · the method ("your inner critic has a script") ·
   breathe ("one minute", live blush disc) · move (rose ring
   instrument). Live states on tiles read honestly against seeds.
7. Floating pill tab bar: today ✦ · jeni 💬 · scan ⌞⌟ · becoming ▤.

Oddity: hero target flips between 1,473 and 1,596 kcal depending on
which medication seed ran last after a reinstall (history reseed →
1,596). Seed-order determinism, worth one look.

## 3 · THE DOSE SHEET

Frames: `08-dose-sheet/dose_sheet.png` (injectable),
`08-dose-sheet/dose_sheet_oral.png` (oral).

- Presented as a tall sheet; Home dims grey behind it (ring still
  legible through the veil). Grab handle present.
- Injectable: eyebrow "OZEMPIC · 0.5 MG" (catalog product named
  in-app — user's own data, never in notifications), serif hero
  "today's shot", "the site" 6-cell 2-col grid (left abdomen
  pre-selected as solid ink — rotation suggestion visible), free
  field "anything to note", ink CTA "mark it taken", quiet
  underlined "not today" beneath.
- Oral: "RYBELSUS · 7 MG", hero "today's pill", guidance line "water
  only, then a quiet half hour before food.", note field, same CTA
  pair, and the privacy line "only you see this. never named in
  notifications." (on the injectable face that footer sits below the
  fold, if present — unverified).
- Not reached: skip-reason faces, late face, b2b sheet face.

## 4 · THE REGIMEN home (your medication sheet)

Frames: `09-oral/regimen_oral.png` (self),
`09-b2b/regimen_b2b.png` (clinic),
`09-history/regimen_history_clean.png` (history, clean store),
`09-history/regimen_history.png` (the b2b-sticky capture).

- SELF (oral + history): "your medication" serif hero; facts-as-doors
  rows — label left in grey sans, value right in serif italic w/
  chevron: medication "rybelsus/ozempic", dose "7 mg/0.5 mg", rhythm
  "every morning"/"weekly · mondays", reminder "morning"/"evening".
  Italic status line "next dose · today, 8:00am" (6:00pm on
  history). Row "how it's sitting / log a side effect ›". Then "the
  record" era ledger (history shows "ozempic · 0.5 mg … since jul
  20" at the fold; deeper eras below the fold, unreachable by
  screenshot).
- CLINIC (b2b): subhead "recorded by your care team." Facts are
  READ-ONLY (no chevrons), values Capitalized verbatim ("Wegovy",
  "1 mg", "weekly · mondays"), labels differ (schedule/how vs
  rhythm/reminder), free-text how: "evening. thigh or abdomen is
  fine." Underlined "something look wrong?" + footer "only you see
  this. never named in notifications. this is the plan your clinic
  recorded, not a prescription." Register split self/clinic reads
  clean and deliberate.

## 5 · BECOMING (consumer)

Frames: `12-tabs/becoming.png` (top),
`13-depth/becoming_bottom2.png` (bottom).

Top: "becoming" serif header + "mon, aug 10". BODY card: "191.9 lb"
hero numeral, verdict "down about 1 lb this week.", ink trend line
vs grey comparison line, rose terminal dot, "read the whole week ›".
SODIUM insight card: "down 30% *vs last week*", 14 rose bars (last
bar berry), reading "less held water. the scale reads truer."
Scope bar: today · **week** (ink pill) · month · 3 months · year ·
all. Tile grid: WEIGHT 191.9 lb (line face) · CALORIES 1,499 /day
(bar face) · PROTEIN 102 g/day · STEPS 6,831 /day · sugar intake
34 g/day · sodium 2,094 mg.

Bottom: section "NOT ENOUGH TO READ YET" — rows: **your medication
(0.5 mg)** · sleep (no nights read yet) · movement (not connected) ·
waist (needs two check-ins) · body fat (37-43% · estimated). Then
"YOUR RECORD": new check-in (a few seconds · stays on your phone) ·
your plates (every meal, with its photo) · visit packet (for your
clinician, when you choose).

Flag: the v24 medication tile lives in the not-enough bucket even
with an active seeded regimen + dose day — either the tally
strip/era tile needs more history than seed-week provides, or the
gate is too strict. Worth a deliberate look in v25.

Note the honesty grammar everywhere in this bucket ("no nights read
yet", "not connected", "estimated") — provenance made visible.

## 6 · BECOMING (care mode)

Frame: `10-care-mode/care_becoming.png`.
- Same skeleton, different composition: BODY card (163.6 lb, care
  seed data, "2 weeks") → section "YOUR CARE" (visit packet "your
  last 28 days, ready for your clinician" · new check-in · your
  plates) → SODIUM card. Care artifacts promoted above insights;
  consumer keeps them de-emphasized at the bottom as YOUR RECORD.
  The becoming tab pill carries a soft rose halo when selected.

## 7 · JENI tab (chat, empty state)

Frame: `12-tabs/jeni.png`.
- White disc with the hand-drawn j mark, serif "hi. i'm *jeni*.",
  sub "your coach between visits." START A CHAT: three tappable
  bubbles w/ ink send arrows — "what's my plan today?", "i had a
  rough day", "explain my trend". Honesty caption "jeni supports
  your plan. she's not medical care." Bare-hairline composer "talk
  to jeni…" + sparkle glyph right.
- "between visits" is care-flavored copy; verify it is cohort-gated
  (this profile is GLP-1-seeded) and not shown to a plain consumer.

## 8 · SCAN tab (the chooser)

Frame: `12-tabs/scan.png`.
- Full-screen cover over a blurred live-camera field: serif "what
  are we looking at?" + two white cards — "your body / the waist,
  week to week" (silhouette) and "a meal / counted from one photo"
  (the SnapDial glyph — nice motif echo). X dismiss disc below. No
  tab bar (true cover). Camera perm was pre-granted by prior QA use
  of this sim; fresh devices will interleave the perm prompt.

## 9 · NO ARGS (the true resting state)

Frame: `11-noargs/noargs.png`.
- Launch without doors lands on THE KEEP WALL, personalized "maya,
  your plan is ready." — the QA entitlement is per-launch, so the
  real account state is unpaid. Wall: year pre-selected (ink border,
  check, "most popular" blush badge, $0.96/wk · $49.99 per year ·
  save 84%) · quarter ($2.31/wk · $29.99) · one week ($5.99/wk ·
  "$311/year if billed weekly" — honest anti-anchor) · "paced to
  ACSM guidance · built for sustainable loss." · YOUR PLAN ON ONE
  PAGE (PROTEIN FLOOR 90g a day "protects muscle while you lose") ·
  WHY THIS WORKS bullets ("slow is the strategy… 0.5-1% a week band
  clinicians use") · sticky footer: money-back guarantee · "renews
  aug 10, 2027 unless you cancel · two taps in settings" · ink CTA
  "keep my plan · $49.99 today" · "apple will ask to confirm ·
  that's the whole plan". Billed-today law visible everywhere.

## 10 · visual language, as-walked

- One surface: cream everywhere; the only "second background" is the
  iOS sheet dim (grey veil) behind dose/regimen sheets.
- Type system holds: serif ink heroes w/ italic accents; grey sans
  labels; serif italic VALUES on regimen rows (fact-as-door register
  is distinctive and consistent).
- Rose ramp = data, everywhere data appears (ring, insight bars,
  tile faces, live tool instruments); ink = trajectory lines;
  clinical/care text stays unadorned. No hearts anywhere. Lowercase
  voice throughout except clinic-verbatim "Wegovy".
- Support vs task register on Home (dashed ghost chips vs solid
  surfaces) is a genuinely legible hierarchy device.
- Status-bar time pinned 12:00; day pill and strip agree (day 12,
  M 10 selected).

## 11 · broken / odd / worth a look

1. All six film doors dead as self-driving tours in the shipped
   build (walk-carousel/book/medication/scope/strip, gallery-tour).
   If v25 wants filmable walks, the doors need in-app drivers.
2. `--uitest-open-food-journal` no-ops — likely points at the
   pre-v23 journal; THE BOOK has no direct door except walk-book
   (which is walker-armed). THE BOOK was therefore UNREACHABLE this
   session.
3. Becoming's medication tile sits under NOT ENOUGH TO READ YET with
   an active regimen seeded (see §5).
4. `--uitest-becoming-bottom` requires `--uitest-start-tab becoming`
   to act; alone it silently stays on today.
5. Self med-seed cannot replace a clinic regimen (by design?), so
   `b2b` then `history` QA sequences silently show stale b2b data.
6. Calorie target drifts with seed order after reinstall
   (1,473 → 1,596 for the same "injectable" label).
7. Hero carousel faces 2-5 undiscoverable by doors; face 1 only.
8. Program-ready gate sits INSIDE the tab shell (tabs visible and
   presumably tappable behind an unstarted program) — check whether
   becoming/scan behave sanely pre-start.

## 12 · representative frames (all under scratchpad /walk/)

- Home top/bottom: `01-home-still/home_settled_2.png`,
  `13-depth/today_bottom.png`
- Program gate: `01-home-still/home_settled.png`
- Dose sheet: `08-dose-sheet/dose_sheet.png`,
  `08-dose-sheet/dose_sheet_oral.png`
- Regimen: `09-oral/regimen_oral.png`, `09-b2b/regimen_b2b.png`,
  `09-history/regimen_history_clean.png`
- Becoming: `12-tabs/becoming.png`, `13-depth/becoming_bottom2.png`,
  `10-care-mode/care_becoming.png`
- Jeni / scan / wall: `12-tabs/jeni.png`, `12-tabs/scan.png`,
  `11-noargs/noargs.png`
- Static-film proof: `02-carousel/frames/f_016.png` vs
  `02-carousel/frames/f_160.png` (identical); films in
  `02-carousel|03-book|04-medication|05-scope|06-strip/walk.mp4`,
  `07-gallery/tour.mp4`

## 13 · WHAT THE WALK COULD NOT REACH

No door reached these; they exist per the laws/binary but were not
observed:
- Hero carousel faces 2-5; the evening close row/page.
- THE BOOK (day spreads, month seams, week read) and THE READING —
  entire v23 food interior; also the dial/immersion capture flow
  (camera modes, barcode, label) beyond the chooser.
- Chat in conversation (streamed letter + marginalia; medication{}
  envelope behavior). Mock doors exist (`--uitest-mock-chat`,
  `--uitest-chat-demo`) but were out of matrix.
- Settings depth behind the gear; profile hub.
- Regimen editors behind the fact doors (dose picker, rhythm,
  reminder), side-effect logger sheet, THE RECORD past-era rows,
  dose-sheet skip reasons / late face / b2b dose face.
- Becoming tile detail pages (ledger · WHAT THE PLAN DOES ·
  provenance), weekly insight carousel pages beyond page 1, visit
  packet interior, new check-in flow (body scan capture), waist
  read, body-fat provenance page.
- The 4 consult medication beats (onboarding v8 interior) and the
  whole onboarding; clinic connect (`--uitest-care-connect-code`)
  round trip; notifications (the actionable dose category); paywall
  downsell sheets; breathwork; the method lesson interior.
