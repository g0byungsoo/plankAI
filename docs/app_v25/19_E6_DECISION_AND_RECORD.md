# E6 — THE DESK: decision + record

2026-08-11 · branch feat/app-v2 · rides RC 1.2.0 (30) · no migration,
no EF deploy, no paywall change. Follows the founder steer of the same
date (E5 ships OFF; keep redesigning).

---

## 1 · WHAT THE DATA SAID — AND WHERE IT STOPPED

The steer kept the hard paywall, which changes who the next era can
serve: **payers only.** That population is ~2/day, with a median of
**2.0 active days** and 12% alive at day 28 (n=151, `18_E5_EVIDENCE`).

I tried to let the data pick the era and **it could not.** Recording
the attempt because the failure is the finding.

**Query**: among payers, which day-0 action separates those who reach a
third active day?

| day-0 action | n did it | reached ≥3 days | if not |
|---|---|---|---|
| lesson | 89 | 47.2% | 31.3% |
| breathwork | 67 | 53.7% | 30.5% |
| food | 53 | 50.9% | 34.5% |
| workout | 46 | 58.7% | 32.5% |
| weight | 37 | 43.2% | 38.5% |
| chat | 12 | 41.7% | 39.4% |

Read naively this says the roadmap is backwards: workout (slated for
REMOVAL) has the biggest lift, and lessons (audited "evidence-dead") are
the most-used day-0 action. **All three readings are wrong**, for two
independent reasons found by checking rather than assuming:

1. **Breathwork is not a chosen action.** `PostPurchaseFlowView` is
   `forging → coachIntro → breathworkPrimer → breathworkSession →
   promiseConfirmation`. Day-0 breathwork means "got through the
   post-purchase ceremony", so its lift is "people who finished setup
   stay longer than people who bounced during setup" — a selection
   artifact.
2. **The population is contaminated.** 105 of 160 `main_tab_appeared`
   users never purchased, on an app that is hard-gated. Those are
   internal/TestFlight builds with debug entitlement (version 1.2.0
   alone: 43 onboarded, 11 main, 4 paid). Cross-surface comparisons
   inherit the contamination.

What survives: the per-version reach numbers and payer active-days from
`17_E5_DECISION` §1.1 (both computed within a single version, with
`purchase_completed` as the anchor — the one event that does not lie).

**So the honest position is: production data cannot currently
discriminate between in-app features.** ~2 payers/day, version-fragmented
instrumentation, and a branch five eras ahead of anything measured. An
era claiming a data mandate here would be manufacturing one.

The binding constraint is therefore quality, which is what the steer
already said.

## 2 · THE RANKED LIST (from walking, not from docs)

Twelve surfaces walked in the simulator at HEAD and compared against
the redesigned onboarding / Home / Becoming.

**The next product problem.** A payer's median life is 2.0 days, and
every compounding mechanic E1-E4 built needs a week. E4 (DAY TWO)
already targets exactly this and is unshipped and unmeasured. Building
it again would be redundant, so the product problem this era can move
is narrower: **jeni is more capable than she looks.** E3 shipped eight
read tools; nothing at rest reveals that she can see anything.

**The largest remaining UX problem.** The chat desk's resting state
greets and offers, but never demonstrates. It is the surface the
founder named, it is where "is this thing actually intelligent?" gets
decided, and it answered with a tagline.

**The largest visual-quality discontinuity.** Ranked, observed:
1. the steps detail's **orange gradient ring** — outside the eight
   locked tokens and outside the rose ramp (blush · dusty · berry).
   Observed, **not fixed** (§6).
2. the Method reader's photography and copy (§5).
3. the reading's hierarchy: kcal leads with the ring while protein is a
   secondary card, contradicting the product's own "protein floor
   leads, kcal quiet" law (`00_THE_SYSTEM` §9). Observed, not fixed.

## 3 · WHAT I EXPECTED AND FOUND TO BE WRONG

Three, all caught by checking before building:

1. **"The food reading is a nutrition spreadsheet."** It is not. I had
   screenshotted the wrong surface: `--uitest-plate-detail` opens the
   plate-detail sheet from Home, not the post-scan reading. The real
   reading (`--debug-result-carousel`) is chart-driven — understanding
   chips landing on the photo, a metric grid with rose bars, a portion
   stepper, a fiber/sugar/sodium band. I nearly built an era on a
   mis-identified screen.
2. **"The three food entrances are separate utilities."** They are not.
   Camera, barcode and label all resolve to one `capturedResult` and
   one `SnapResultView` in `PhotoCaptureView`. v23 already did that
   work; the founder's structural concern is satisfied.
3. **"There is a banned heart emoji in the describe header."** It is a
   sanctioned brand mark: `JKMarks` states "jeni's own mark stays the
   text heart (♥ U+FE0E), never drawn, never replaced. Usage floors:
   rows and eyebrows only, one mark per row, never inside prose." The
   describe header uses it as terminal punctuation, which is exactly
   the sanctioned use.

## 4 · WHAT SHIPPED

**THE DESK.** The resting line under jeni's name changes from a claim
to a proof, in the same real estate:

```
before   your coach, day to day.
after    4 plates and 123 g of protein, on file.
```

`JeniDeskAwareness` is a pure engine (10-case table) reading the SAME
`TodayStateService.snapshot` the starters already read — one source,
two renderings, no new store:

- nothing on file → the claim, never invented proof (and the E4 G9 care
  gate survives: "between visits" only for connected patients)
- a plate with no macro detail never renders "0 g"
- a weigh-in alone is still something true
- a return after a gap is stated warmly and pinned against ten
  reprimand words across a 2..60 day range — guilt re-engagement is a
  named banned anti-loop (`00_THE_SYSTEM` §12)
- today's record outranks the gap
- lowercase, no em-dash, no heart, no percentage

No new buttons, no card, nothing dumped into a message — the smallest
interaction model that makes the desk aware of the rest of the product.

**Plus `--uitest-wipe-chat`**, because the desk's resting state was
unfilmable: the QA account carries a stored conversation, so the view
always resolved to the transcript.

## 5 · UNISEX AUDIT

New this era, found by walking rather than grepping:

- **The Method reader** (`--uitest-cbt-lesson`) renders female-only
  photography, and its day-one lesson body reads *"someone at the table
  says **she's** being good today."* Gendered copy inside the corpus,
  not in the UI strings a grep would catch.
- **Breathwork's protocol card** carries female-only photography.
- Both are **reported, not fixed**: the corpus is 84 lessons and the
  imagery is an asset library. Rewriting either inside an era about the
  chat desk would be exactly the uncontrolled expansion the brief
  warns against, and the Method's fate (dispersal vs retirement) is an
  open roadmap question that should decide the copy pass.
- **Left alone on purpose, again:** `BreathworkProtocols` cites
  "n=40 women" because that is the study's actual sample.

## 6 · WHAT IS STILL BELOW THE BAR (observed, not fixed)

1. The steps detail's orange gradient ring (off-palette).
2. The Method + breathwork female-only imagery and the "she's" lesson
   line.
3. The reading leads with kcal where the product's law says protein
   leads.
4. The desk still has ~150pt of dead space between the disclaimer and
   the composer.
5. The desk's starters fall back to three generic strings when no state
   condition fires — with four plates on file at 4pm, none matched.
6. QA pollution: `--uitest-wipe-food` holds for the launch it runs in
   but the empty-record desk could not be filmed; its behaviour is
   covered by the unit table instead.

## 7 · VERIFIED

- **869/869 app** (+10 this era) · **125/125 package** · zero
  regressions.
- E5 both flag states re-verified after the steer: OFF lands on the
  hard paywall (captured); ON walks 4/4.
- The desk captured with a record and with the copy fix; the empty-day
  face is table-covered, not filmed (§6.6).

## 8 · WHAT SHOULD BE MEASURED NEXT

Nothing in this era is measurable until `feat/app-v2` merges — now six
eras deep. Post-merge, the two questions worth instrumenting are
whether a desk that opens with a record raises the share of chat
sessions that get a first message (`jeni_chat_message_sent` /
`jeni_chat_opened`, today 36/84), and whether the E5 experiment moves
the purchase rate off the 5.8-10.5% band when the paywall test
concludes.
