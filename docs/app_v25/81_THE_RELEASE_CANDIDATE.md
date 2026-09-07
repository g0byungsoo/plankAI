# 81 · THE RELEASE CANDIDATE

**Built 2026-09-07, after 80.** The founder's brief: 1.1.7 is approved;
turn the current product into a release candidate we are proud to ship.
One founder-directed typography question first, then freeze scope,
triage everything the recent era named, fix only what is material,
audit the App Review boundaries against CURRENT policy, and produce
release proof up to (never across) the archive/upload/submit/deploy
boundary. Evidence in `81_evidence/` (23 items).

---

## 1 · The typography experiment

**The question: should Jeni's display serif become Newsreader?** The
founder named the shipped typography on "181.2 lb" and the dose-week
caption as a problem and suspected the serif family.

**What the serif was.** `JeniHeroSerif` = Playfair Display instanced
at wght 650 roman / 620 italic (the her75 identification, OFL-renamed)
— ONE heavy display cut carrying every serif slot from 16 to 64pt:
hero numerals, three-line felt-week prose, dose sheets, letters. A
fashion-poster face setting daily data. The desk specimens
(`18_specimen_playfair650.png`) show the complaint exactly: the 22pt
sentence renders as bold headline type.

**Newsreader, researched.** Commissioned by Google Fonts from
Production Type "primarily intended for continuous on-screen reading";
transitional serif; variable axes wght 200–800 and **opsz 6–72** with
true display/text/caption grades; single (lining-class) figure set
with `tnum`; SIL OFL 1.1 with **no Reserved Font Name** (renaming
permitted). Acquired from the upstream repo
(github.com/productiontype/Newsreader), license file verified before
anything was bundled.

**The experiment mechanism.** All bundled `.ttf` files register
programmatically at launch, so the whole app flips by swapping which
FILE carries the `JeniHeroSerif-Regular/-Italic` PostScript names — a
DEBUG launch flag registered candidate files from the sim container in
place of the bundled pair. Zero call-site churn; nothing could be left
half-migrated by construction. Three candidate weights (400/460/500)
were instanced with the **opsz axis left live** — CoreText applies
optical size per point size automatically, verified by render
(16pt = sturdy text grade, 64pt = high-contrast display grade), which
no single static cut of any face could do.

## 2 · The Newsreader decision

**YES — Newsreader materially improves Jeni, and the display system
migrated fully.** Chosen instance: **wght 460 roman / 430 italic,
opsz 6–72 live**. NR500 was filmed and rejected (its text-grade prose
drifts back toward bold; no display-scale advantage —
`12_weight_detail_newsreader500_rejected.png`). NR400 read a touch
thin against DMSans-Medium furniture at sentence sizes.

Judged on the founder's eleven criteria across the filmed matrix
(§3): legibility ↑ (text-grade shapes at reading sizes for the first
time), personality kept (still bookish-editorial, still serif-voiced),
warmth ↑ (literary instead of imposing), **numerals transformed** (the
weigh-in ritual's "143.3 lb" reads as a fine instrument, not a black
slab), italics ↑ (the roman/italic juxtaposition gains grace —
"*down* about 1.8 lb this week."), long reading ↑ (the letter and
method notes read as a book page), display use kept (opsz 72 has real
presence), information hierarchy ↑ (serif voice vs DMSans system
separates MORE cleanly because the serif stopped shouting), Dynamic
Type verified (relativeTo untouched; AX5 films clean), brand
distinctiveness kept (the division of roles — serif voice / DMSans
system / Fraunces ornament — IS the identity, and it survives),
repeated daily use ↑ (the whole reason: a calmer instrument).

**The division chosen:** Newsreader owns every `JeniHeroSerif` slot
(≥16pt serif voice); **DMSans stays the UI sans; Fraunces keeps its
micro/teach slots** (11pt eyebrows + the approved consult's teach
tokens — a deliberate role division, not an accident; consolidating
Fraunces out is available as a follow-up founder call, named in §7).

**The migration, done properly:**
- The two bundled font FILES replaced in place (internal family +
  PostScript names unchanged → all ~305 call sites, the tokens, and
  the widget flipped together; pbxproj untouched). OFL copyright +
  license records retained inside the files.
- **The negative-leading cadence re-derived**: Newsreader's natural
  line box is 1.0 em vs Playfair's 1.333 em, so the −0.505 × size
  constants would collide lines. All four token line-gaps retuned to
  −0.22 × size (`programHeroLineGap` −22→−10, `questionHeroLineGap`
  −17→−7, `displayHeroLineGap` −19→−8, `heroHeadlineLineGap` −19→−8)
  and the consult's own `V8Type.messageLineGap` −9→−1 (preserving its
  deliberately looser conversational rhythm, ≈1.45 × cap).
- Law + spec updated: `00_JENI_DESIGN_LANGUAGE.md` §2 carries the p81
  amendment; `her75_typeface_spec_2026_06_10.md` carries a
  superseded-in-part header. Tokens.swift's typography header rewritten.
- The DEBUG experiment hook removed with the decision.
- BodoniModa checked before touching: LIVE (SnapShareCard statement
  style) — left alone.

## 2a · FOUNDER TYPOGRAPHY AMENDMENT (2026-09-07, after review)

**The founder reviewed the completed migration and made the decision
definitive: "Newsreader is Jeni's serif. Finish the system."** One
coherent serif voice, system-wide; the burden of proof moved onto
every exception; Fraunces and Bodoni must not survive merely because
earlier passes gave them roles — those decisions predate the founder
seeing Newsreader in the real product. Typography consolidation only:
no product hierarchy change, no medical logic, no features, no
deploy/archive/upload/submit. The intended architecture:

    NEWSREADER (JeniHeroSerif) = Jeni's serif voice
    DMSANS                     = Jeni's functional / UI sans

**The audit.** Every remaining serif slot enumerated: 90 Fraunces
call sites across 45 files (5 `Typo` tokens — `editorialEyebrow` +
the four consult teach tokens; 11pt eyebrows/ornaments on Home's
dateline, JKReadingDay, JKGauges, ReSigningView, the projection
card; italic punch inside sans body across ~20 surfaces incl. the
package's `ItalicAccentText` defaults and three ruler active-words;
display slots up to 168pt on the workout timer; the share card's
"classic" face; the two Live Activity slots) + ONE Bodoni site (the
share card's "statement" face). No third family carries a live
role: `BradleyHandITCTT-Bold` (a system font, not bundled) appears
only on the DEBUG-harness handwritten share cards, whose renderer
has zero shipping consumers — reported, not expanded into.

**The verdict applied: no exception survived.** Every former
Fraunces slot migrated to the SAME two Newsreader instances —
roman → `JeniHeroSerif-Regular`, italic → `JeniHeroSerif-Italic` —
with zero new weights minted; the live opsz axis carries the micro
sizes (the 11pt eyebrow renders the sturdy text grade, not a
display hairline — the exact constraint that had kept Fraunces
alive under Playfair). The share card's face set is now three faces
from two families: editorial (Newsreader italic) · statement
(Newsreader ROMAN — the upright voice Bodoni used to fake) · clean
(DMSans); the "classic" Fraunces case deleted (persisted rawValue
falls back to `.editorial` at both decode sites). The consult's
teach register (teachPunch/Numeral/Closing) keeps its sizes in
Newsreader roman/italic.

**A defect the audit found: the Live Activity was never Fraunces.**
`ScanLiveActivity` named `Fraunces72pt-*` but the widget target
never embedded those files — the built product has been rendering a
silent system-font FALLBACK on the lock screen and Dynamic Island.
Now Newsreader, and `JeniHeroSerif-Italic.ttf` is embedded in the
widget target + its `UIAppFonts` (the one resource ADDED by this
amendment).

**Resources removed:** `Fraunces72pt-Light/-Regular/-SemiBold/
-SemiBoldItalic.ttf` + `BodoniModa.ttf` deleted from
`Resources/Fonts`, the app `UIAppFonts`, and the pbxproj (build
files + file refs + group + Resources phase). The app bundle now
carries exactly six fonts: JeniHeroSerif ×2 + DMSans ×4.
(A pbxproj lesson for the record: the first hand-minted build-file
id collided with `JenifitWidgets.entitlements`' object id — xcodebuild
reported "project damaged" while a piped `echo EXIT:$?` printed 0,
the §12.1/`Executed 0 tests` trap in new clothes; caught by reading
the log body, fixed with a UUID-derived id.)

**Docs made true NOW** (history left standing as history):
Tokens.swift's typography header (TWO families) ·
`00_JENI_DESIGN_LANGUAGE.md` §2 (two-family table + amendment note)
· `her75_typeface_spec` §4 micro-slot bullets struck through with
the supersession · `docs/STATE.md` typography + voice sections ·
`docs/THEME.md` §2 rewritten · `DESIGN.md` quick facts · ~50 code
comments that claimed "italic-Fraunces" as the live register now
say italic-serif; dated bake-off history (the v4 R2 verdict, the
v1.0.7 spec quotes) deliberately preserved.

**Visual verification (evidence 24–36):** weigh-in ritual (the
active `lb` — an ex-Fraunces slot — now serif italic against DMSans
`kg`; 16 + SE + SE-AX5, whole-word wraps, no shear) · Home dateline
("DAY 16" ex-Fraunces caps → Newsreader ornament caps, crisp at
11pt) · the weekly read's dose-week page (eyebrow caps + "*after
the dose*" ornament + "-1.3 lb") · the reveal's plan tiles ("1461",
"120g", italic "the trend") · the snap reading (serif-italic dish
title + "21 g" hero + "*right at* your target") · the paywall
("your plan to *143 lb*.", Newsreader prices, italic "dec 7") ·
weekly receipt · goal ritual · weigh-in ledger · SE-AX5 Becoming
("181.2 lb" — the founder's original complaint numeral — reads as a
fine instrument at accessibility size). Looked for and NOT found:
bad wrapping, changed hierarchy, over-delicate small text, colliding
lines, numeral/italic problems, Dynamic Type regressions. No former
serif surface needed to fall back to DMSans.

**Proof:** app **1744 · 2 skipped · 0 failed** (the exact §17
baseline — typography carries no contract) · PlankFood **321/321** ·
Release **BUILD SUCCEEDED from clean artifacts** · Release product:
6 fonts in the app, 5 in the widget (italic now present), app
`UIAppFonts` = DMSans ×4 · `strings` on BOTH Release binaries:
0 `Fraunces` · 0 `Bodoni` against the firing `JeniHeroSerif`
control (4 hits each). PlankSync untouched (zero font references).

**Live font families after the amendment: TWO.** Newsreader (as
JeniHeroSerif) + DM Sans. The only other family name in the tree is
Bradley Hand on the dead DEBUG harness cards — a founder call away
from deletion with that corpus, not a live voice.

## 3 · Screenshots / films

The matrix: 13 app states × {Playfair-650, NR460, NR500} on iPhone 16
via the scriptable walker-arm, plus SE standard, SE-AX5, fresh-seed
consistency, the letter, the consent gate, and the paywall — 23 items
in `81_evidence/`. The decisive pairs: weight detail (01↔02), Home
(03↔04), the weekly read (05↔06), the weigh-in ritual (07↔08), the
dose sheet (09↔10). Post-migration native films: the rebuilt Becoming
with the burn caption (13), SE weight detail (15), SE-AX5 becoming +
ritual (16, 17 — no shears, correct §5.2 stacking), the morning letter
(21 — the retuned cadence on a multi-line serif hero). The QA sims
were also used to verify the swap at accessibility sizes before the
decision was called migrated.

## 4 · Release-blocker inventory

Everything found this pass that could block, with verdicts:

| finding | verdict |
|---|---|
| Live jeni-chat EF emits an efficacy verdict ("this dose has been effective for you") — observed in the QA account's persisted live transcript (`20_live_ef_register_asfound.png`) | **PRODUCTION GATE — deploy required before ship (§12)** |
| Chat → OpenAI had NO disclosure or consent while the envelope carries compound/doses/symptoms/notes (5.1.2(i), Nov 2025 third-party-AI clause) | **FIXED — §9/§10, the consent gate** |
| ATT purpose string said "for women like you" (p78 neutral-language law; shipped in the approved binary) | **FIXED** |
| `WeeklyReadComposer` "holding here is the medicine's shape" — causal efficacy read of HER response | **FIXED (§11)** |
| Live privacy policy at jenifit.app/privacy is stale (still v1.1.4 per `docs/privacy_policy.md`'s own founder note) and does not describe the chat→OpenAI flow the new consent sheet discloses | **FOUNDER — must be published before submission (§20)** |
| No privacy/terms links reachable in-app past the paywall (5.1.1(i) "within the app") | **FIXED — settings rows** |
| App Store metadata: stale listing (still risks the v1.0.0 draft's "no advertising trackers" claim — false with TikTok; no Health-integration mention per 2.5.1; EULA line per the p60 rejection) | **FOUNDER — ASC step (§20)** |
| ASC age-rating questionnaire under the July 2025 overhaul (medical/wellness + AI chatbot questions; deadline passed Jan 2026) | **FOUNDER — verify in ASC (§20)** |
| Sign in with Apple token revocation on account deletion (Apple's account-deletion page; named P1 since p38) | **DEFERRED — needs the .p8 + an EF; founder infrastructure; documented risk accepted for this release, next-release item (§20)** |
| 191.9-vs-181.2 weight-hero/fold disagreement seen mid-films | **EXONERATED — QA cross-seed pollution (med seeder over becoming seed); fresh seed agrees exactly (`14_freshseed_one_fold_exonerated.png`); the one-fold law holds** |

## 5 · Recent-pass named-not-done triage

Collected from p70–p80's records in full (two reader agents; every
"named not done", deferral, gate, and known issue). Triage:

**SHIP BLOCKER (0 remaining in-client).** The only blocker found
anywhere is server-side: the EF register deploy (§12).

**FIX BEFORE RELEASE — fixed this pass:** the chat consent gap (new,
from the current-guidelines audit, not the pass records); the medical
register violations (§11); the ATT string; in-app privacy links.

**SAFE TO DEFER (named, unchanged):** oral pill-bottle supply (p70,
founder-shaped) · pen-count sync/VisitPacket line (p70) · SpokenDay V2
weekday names (p72) · §5.2 underline ruling vs the clinical-verb
family (p71, founder/law ruling) · food settings rose chips (p71) ·
sensor rails locked to one fixed week (p73) · remembered lens (p73,
one-liner if wanted) · protein/fiber delta cards (p73) ·
audio-graph descriptors (p74) · trend-established moment (p74) ·
Home's "the method" duplication (p80) · MethodCatalog/BrandVoice
register alignment with the waning line (p80) · steady-context card
film (p74) · new-user doodle empty state film (p74, blocked by the QA
identity's cloud history) · intake-inconsistent ask surface /
dose-day morning clause / maintenance proposals (p79 v2 items) ·
TODOS.md's v1.2 candidates (bundle-ID/SKU renames etc.).

**INTENTIONALLY REFUSED (stands):** PK curve · cross-user comparison ·
projected goal dates · weight-number milestones (p63 founder law) ·
card customization · auto-applied expenditure targets · per-lens
renames · paywall press-language migration (do-not-migrate).

**PRODUCTION-GATED (founder):** jeni-chat EF deploy (§12) ·
`energyAdjust` ProgramFactKind migration (p79 — device knob stands,
documented one-step loss) · `show_visit_packet` tool name ·
p53 migration standing gate · burn-card cohort framing judgment.

**DEVICE CHECKS (owed to the founder's phone, consolidated):** ruler
drag + chart hold-then-scrub + sheet physics + haptic timing +
ProMotion (p76) · entrance/trace/receipt feel (p75) · VoiceOver order
walks (p73/p74) · BreathHaptics (TODOS) · kept beat at SE (p78 —
partially covered by this pass's SE films) · **plus one new: the
Newsreader system on hardware** (rendering weight/contrast on a real
OLED; the sim films are the decision's basis).

## 6 · Fixes actually made (the complete list)

1. **The serif migration** (fonts ×2 in place, 5 leading constants,
   token/spec/law docs, experiment hook removed) — §2.
2. **The chat AI-consent gate** (§9): `ChatAIConsent` store +
   `ChatAIConsentSheet` (names OpenAI, names the file's contents,
   no-training + on-device-transcript facts, identity line, accept /
   not now); gated inside `ChatSession.send()` AND the card-tap seed
   path; accept replays the held send; decline drops nothing she
   typed; keys swept at sign-out with the food-consent keys; QA runs
   pre-accept (walkers unchanged) with `--uitest-chat-consent-fresh`
   to re-arm for films; consent-state line in "what jeni remembers";
   dead `disclaimer` var deleted (the identity line now actually
   renders at first chat, on the gate). **5 new pins**
   (`ChatConsentGateTests`) hold both doors, decline-reasks,
   accept-stamps-and-replays, never-reasks.
3. **Privacy/terms rows in Settings** (5.1.1(i) past the paywall).
4. **ATT purpose string** de-gendered ("for people like you").
5. **Medical register** (§11): the plateau chapter's efficacy read
   neutralized (+pin updated); `ProgramArc.arriving` latent verdict
   neutralized; "the medication lowers appetite" → class-plural
   hedged; "for everyone" → "for almost everyone"; MethodCatalog
   late-dose-week "the medicine runs lowest" → "these medicines run
   lowest" (v3 + fingerprint pin refreshed through the p54 tripwire,
   which fired exactly as designed).

Nothing else moved. No redesigns, no new product systems, no
migrations, no schema, no analytics vocabulary changes.

## 7 · Deliberately deferred

Everything in §5's defer/refuse lists, plus: ~~Fraunces consolidation
into Newsreader's caption grades (a coherence win, but it touches the
approved consult's teach register — founder call)~~ **← the founder
made that call; done, see §2a** · the sleep lines
"expect stronger hunger today" (prediction-as-certainty register,
judged non-medical and left) · `BecomingTiles` "timing, never blame."
(doctrine vocabulary in user copy; walked in prior passes, left) ·
consent analytics events (skipped deliberately — no hygiene-registry
churn in an RC pass) · the stale `.claude/worktrees` agent branches
(4 stray activation experiments, 0 dirty; not on the release path;
left for a housekeeping decision).

## 8 · App Review audit (current guidelines, fetched live)

Re-read 2026-09-07 from developer.apple.com (last revised 2026-06-08);
the full checklist is in the session record. What matters:

- **2.1 / 2.3.1(a)**: ATT reachable on first settled surface (p60
  architecture verified wired); review notes must state where + attach
  the device recording (founder step, §20).
- **3.1.2 + Schedule 2**: billed-today must be the most prominent
  price element — verified in code (`billedPrice` =
  `localizedPriceString` leads every row and the CTA) AND on film
  (`23_paywall_pricing_hierarchy.png`); duration + content stated;
  restore + sign-in present; renewal sentence renders. The metadata
  Terms-of-Use line is the founder's ASC step.
- **5.1.1(v)**: in-app deletion exists (deployed RPC); **SIWA token
  revocation still absent** — named risk, next release (§20).
- **5.1.2(i) incl. the Nov-2025 third-party-AI clause**: photos were
  covered by the food primer (names OpenAI); **chat is now covered by
  the new gate** (§6.2). Both consents are explicit, affirmative,
  and precede the data flow.
- **1.4.1/1.4.2**: no dosage computation anywhere (user-recorded
  only); estimates banded + provenance-named; check-with-your-doctor
  language present (visit packet, method notes, consent sheet).
- **5.1.3 / HealthKit**: purpose strings enumerate every read type;
  estimates never written to HealthKit; health data not in iCloud;
  no health values in analytics payloads (hygiene registry).
- **4.5.4**: app fully functional with notifications denied;
  consented cadences + master toggle; pushes carry no medication
  names/weights/symptoms (v24 law).
- **Age rating (July 2025 overhaul)**: ASC questionnaire must be
  verified re-answered (medical/wellness + AI chatbot) — founder (§20).

## 9 · Subscription audit

The two prior rejections, deliberately re-attacked on this binary:

- **5.6 (dismissal → another purchase surface)**: the machinery that
  caused it is DELETED (WallExitIntent, SmallerStepSheet,
  DownsellPaywallView — verified absent); dismissal stands the wall
  down; Apple-sheet cancellation logs analytics only.
  **Reproduction attempt: `WallExitWalkUITests.
  testWallCloseButtonAlwaysStandsDownAndNeverOffers` — PASSED**, plus
  `PurchaseFlowReviewWalkUITests.testDismissingTheWallPresentsNo
  SecondPurchaseSurface` and `testCancellingThePurchaseSheet
  PresentsNoSecondPurchaseSurface` — see §17. The defect is dead.
- **3.1.2(c) (price hierarchy)**: billed-today leads every row and
  the CTA at full contrast; per-week breakdowns subordinate; no
  hardcoded prices (RevenueCat localized only); pinned by
  `testEveryTierLeadsWithItsChargeAndTheCtaFollowsSelection` and
  filmed (evidence 23).

## 10 · ATT / privacy audit

The binary and the disclosures tell one story, with one founder-side
exception:

- `PrivacyInfo.xcprivacy`: NSPrivacyTracking=true, TikTok domains
  listed, UserDefaults CA92.1 — matches the ATT-gated TikTok init
  (`ATTService.configure`, p60 architecture verified this pass).
- ATT prompt: first settled surface; purpose string fixed (§6.4);
  denial leaves the app fully functional (SKAN-only attribution).
- Food photos → OpenAI: primer discloses + gates (pass-27 build).
- Chat + envelope → OpenAI: NOW disclosed + gated (§6.2).
- Clinic sharing: user-initiated, server-side revocable grant.
- **THE MISMATCH, named per the brief**: the LIVE privacy policy page
  is stale (v1.1.4-era, served from the jenifit-web repo) while
  `docs/privacy_policy.md` in THIS repo already contains the correct
  chat/OpenAI/no-training language (§172-181, §290). The correct side
  to fix is the LIVE PAGE — publishing it is a founder step and a
  **submission prerequisite** (§20). No production change was made to
  paper over it.

## 11 · Medical-language audit

Full client sweep of the p77–p80 GLP-1 surfaces (agent-assisted, then
fixes by hand). **The hard redlines were clean and test-pinned**:
population-vs-personal epistemic markers pinned with their italic
carriers and mutual exclusion; never-a-verdict pinned including the
chat seeds; the burn is a band, never a point, never attributed to
the medication, silent for young dose eras and suppressed cohorts;
era rates floor-gated ("early to read"); no dose advice anywhere; no
adherence grading; prescriber routing intact. **Two violations found
in OLDER copy and fixed** (§6.5): the year-in plateau chapter's
"holding here is the medicine's shape" (a causal efficacy read of her
body) and `ProgramArc`'s latent "the medication does its part."; plus
three one-word hedges. **The remaining violation is server-side**
(§12). Jeni does not prescribe, grade, or judge the medication —
and after the EF deploy, neither does its model.

## 12 · Production dependencies

**REQUIRED BEFORE THIS RC TRUTHFULLY SHIPS — one founder action:**
`supabase functions deploy jeni-chat`. The prepared redlines
(commit `ab4ddb1d`, verified in-repo this pass: the no-efficacy-verdict
science-posture rule + the no-homework-question / no-exclamation-praise
voice rules) exist ONLY in source; the LIVE function was observed
producing all three anti-patterns, preserved in the QA transcript
(evidence 20). The client cannot fix a server register. `deno check`
carries the same 3 pre-existing errors as HEAD, zero introduced.
Deployment was NOT performed this pass (the founder's EF-deploy gate).

Also founder-side, not code: the live privacy-policy publish (§10) and
the ASC metadata/age-rating steps (§20). No migration, no schema
change, and no other deploy is required by anything in this pass.

## 13 · Accessibility proof

AX5 on the SE: becoming (16), the ritual (17) — Newsreader scales
through `relativeTo:` exactly as Playfair did; stacks engage per the
standing AX composition classes; no mid-word shears, no truncated
facts on the inspected surfaces; the consent sheet carries the §5.2
AX escape (decision joins the scroll at accessibility sizes). The
standing pinned AX suites (p51-D2 scale floors, accessibility2 caps,
stack-at-AX) ran green in the full suite. Device VoiceOver order
walks remain on the standing device list (§5).

## 14 · Reduce Motion proof

No motion code changed this pass (typography + copy + one new sheet).
RM behavior rides the standing, test-held grammar: `ModernEntrance`
gates on `accessibilityReduceMotion`, JeniActs/moments arrive whole
under RM (p63–p66 pinned), JeniBurst renders nothing under RM (p64
pinned). The new consent sheet animates only via the system sheet
presentation. The RM pins are part of the green 1744.

## 15 · Device proof

Simulator matrix this pass: iPhone 16 (primary films), iPhone SE 3rd
gen viewport at standard type (15) and AX5 (16, 17), iPhone 17 Pro
(package suites). **Real hardware remains the founder's step** — the
standing device list (§5) plus the new serif-on-OLED check. Nothing
in this pass changed device-only code paths (haptics, camera,
HealthKit live delivery).

## 16 · Performance findings

No evidence of a regression surfaced anywhere in the pass: cold
launches on the sim settled in the usual window through ~40 seeded
launches; tab switches and sheet presentations filmed at their normal
cadence; the serif swap is a same-mechanism font-file replacement
(two files registered at launch, as before — the variable-font
instances are 257 KB + 281 KB vs Playfair's statics, a wash) and the
consent gate is one UserDefaults read on send. Following the brief —
profile only where evidence suggests a problem — no speculative
profiling was performed.

## 17 · Test results

- **App target: 1744 executed · 2 skipped · 0 failures** —
  `TEST EXECUTE SUCCEEDED`, reconciled EXACTLY: p80's 1739 + 5 new
  consent pins; declared (`func test` census) == executed. First run
  caught: the p54 fingerprint tripwire firing on the MethodCatalog
  edit (by design; pin refreshed with the version bump), the 5 new
  tests aborting on the documented iOS-26.2 MainActor-deinit sim
  class (fixed by process-lifetime session retention in the tests),
  and one stale-test-bundle rerun (the v21 trap, caught by identical
  failure signatures, cured by rebuild).
- **PlankFood: 321 executed · 0 failures** (note: p79/p80 carried
  "319" forward without a re-run; today's tree executes 321).
- **PlankSync: 29/29 · 0 failures** (exact baseline).
- **WallExitWalkUITests: 1/1 PASSED** (solo).
- **PurchaseFlowReviewWalkUITests: 4/4 PASSED** (solo) — pricing
  hierarchy · wall-dismissal no-second-surface · purchase-cancel
  no-second-surface · restore/sign-in/terms/privacy reachable.

## 18 · Release build result

`Release BUILD SUCCEEDED` (generic iOS device, unsigned, clean
`build/dd_p81rel` derived data — fresh artifacts per the ENOSPC rule;
~9 GB of stale pass trees were deleted BEFORE the first build of this
pass, and no ENOSPC window occurred). Strings scan of the built
Release binary: **0 `--uitest`, 0 `--debug` doors** (control markers
fire on the Debug binary). `CFBundleShortVersionString 1.1.7`,
`CFBundleVersion 36` (see §20 for the bump step).

## 19 · Secrets / customer-data scan

- Tracked-source scan for key material (provider key shapes, JWTs,
  private keys): **0 hits** — the only matches are comments
  documenting that the service-role key must never appear (it doesn't).
- Fixtures + evidence scan for real customer data: **0 hits** — every
  film frame carries the synthetic QA persona ("maya", seeded
  histories); no production row was read or written this pass; chat
  films ran against the mock transport or the standing QA account's
  own prior transcript.
- The evidence folder was reviewed frame-by-frame before commit.

## 20 · Exact remaining steps before archive / upload / submission

All founder-owned; the repo is prepared up to this line.

1. **Deploy the chat register:** `supabase functions deploy jeni-chat`
   (§12). Then one live chat spot-check ("is it working?" must return
   the trend + prescriber routing, no verdict).
2. **Publish the current privacy policy** to jenifit.app/privacy from
   `docs/privacy_policy.md` (the chat/OpenAI section must be live
   before the consent sheet points at it), and confirm /terms resolves.
3. **ASC metadata:** rewrite the live listing (remove any "no
   advertising trackers" claim; mention the Health integration; keep
   the p60 EULA line `Terms of Use (EULA): https://www.apple.com/
   legal/internet-services/itunes/dev/stdeula/`).
4. **ASC age rating:** verify the post-July-2025 questionnaire is
   answered (medical/wellness topics; AI chatbot capability).
5. **Version bump:** `CURRENT_PROJECT_VERSION` 36 → 37 (all four
   sites) and the marketing-version decision (1.1.8 vs 1.2.0) — after
   that, archive → export → validate → upload, per the standing p46/47
   runbook.
6. **Device pass on real hardware:** the §5 consolidated list, led by
   the new serif-on-OLED look, the ATT prompt recording for review
   notes, and one real purchase/restore/cancel walk in the sandbox.
7. Next release (accepted, named, not this one): SIWA token
   revocation (needs the .p8 + an EF) · the `energyAdjust` fact-kind
   migration · the corrected A1 storage-purge package (p42).

---

## VERDICT

Every client-side blocker found by this pass is fixed and proven in
this tree; the suites are green and reconciled; both prior rejection
classes are machine-verified dead; the typography the founder
questioned has been replaced system-wide with filmed evidence at
every scale. What remains before a customer's hands are the founder's
own steps in §20 — led by one production deploy this pass verified
but may not perform.

**RELEASE CANDIDATE: YES** — conditional on §20 steps 1–2 (the
jeni-chat register deploy and the privacy-policy publish), which are
prerequisites for the submission being truthful, not further product
work. The product itself is frozen.

**No archive, no upload, no submission, no Supabase deploy, no schema
push, no production mutation was performed. NOT ARCHIVED, NOT
UPLOADED, NOT SUBMITTED.**
