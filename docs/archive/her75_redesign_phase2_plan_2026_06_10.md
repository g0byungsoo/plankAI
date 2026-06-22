# her75 redesign — Phase 2 plan
2026-06-10 · senior editorial product designer · for the next Claude session

The founder is right. Below: diagnosis + 5 canonical archetypes everything
must snap to + a phased shipping plan.

---

## 1. The diagnostic

### 1.1 Line-height token is right; call sites are wrong

her75 measured leading ratios (from .webp + IMG references):
- her75-share / her75-homescreen / IMG_6275 / IMG_6280: ~42pt hero with
  -22pt leading = **-52% ratio**
- her75.webp / IMG_6281 (4-line wrap): ~38pt with -18pt = **-47%**

Current `Typo.heroHeadlineLineGap = -22` at 42pt is correct on token.

**The failure modes (call sites):**

(a) Cases that should have no sub still pass `sub:` — 132, 133, 134,
135, 3, 17, 100, 141, 167, 235, 237, 238, 239, 153. That drops jfHeader
from 42pt/-22 (heroHeadline) to 34pt/-14 (questionHero); lines no longer
touch; reads as survey.

(b) Alignment is mixed. `jfHeader` is leading (matches her75-share,
her75.webp, IMG_6275). Bridges 282/283 ship center (matches IMG_6280).
Bridges 280/281 also center but ADD a sticker — sibling inconsistency.
Case 284 ships leading. No rule.

(c) `jfHeader` floats hero inside a flex VStack with `Spacer().frame(height: Space.lg)` before options. At 42pt heroHeadline, hero block rendered
height swings 90-160pt page-to-page, so the *gap between progress bar
and the options card* changes — source of the "bar shifted" reading
(§3).

### 1.2 Italic is too restrictive

her75 italicizes a **semantic chunk**, not a single word:
- "Become *that girl*" (NP, 2w) — her75.webp
- "Follow *your routine*" (NP, 2w) — her75-homescreen.webp
- "Do it *with friends*" (PP, 2w) — her75-share.webp
- "Start the challenge *with your friends*?" (PP, 3w) — IMG_6277
- "Make *it* official" (pronoun, 1w) — her75-3.webp / IMG_6278
- "Matching *your* energy" / "Personalizing *your* space" (possessive, 1w) — IMG_6275 / IMG_6280

Locked memory already loosened to 1-3 words; call sites mostly stuck at
1. Need a decision tree — see §5.

### 1.3 Sub-copy density is still survey-app

her75 question screens carry **zero** sub-copy. JeniFit kept:
- `trustAnchor` WeAskBecauseRow on 154, 155, 156, 162, 163, 164
- `inlineFeedback` cards on 163, 164, 167 (push CTA below fold)
- Multi-paragraph teach body on 230, 231, 232, 233, 234, 166, 142, 240,
  250, 260, 270, 206

her75 earns trust with restraint, not citation chips. **Kill all trust
anchors** in Phase 1 except 163 (hormonal) and 164 (GLP-1) where the
duty-of-care inlineFeedback is real. Citations migrate to teach screens
where the body copy is the screen.

### 1.4 Alignment — strict 2-mode rule

- **Leading**: anything with options/modules/lists below
  (her75-share, her75-homescreen, her75.webp, IMG_6275, IMG_6276)
- **Centered**: pure-typography bridge/loader/celebration only
  (IMG_6280, IMG_6281, IMG_6282)

Lock per archetype in §2; no per-screen judgment calls.

### 1.5 Hero doesn't own the page

her75 reserves ~45% of vertical canvas for the hero region (her75-share:
~33% hero text + ~12% top whitespace). JeniFit reserves 70pt nav padding
+ 24pt spacer = ~11% of iPhone-13 content. Hero text then wraps at
variable height under that. The hero never "owns" the page.

### 1.6 11 layout signatures in one onboarding

Spot-audit: jfQuestion, bridgeScreen, SectionDividerScreen,
educationalScreen, recapCardScreen, methodPreviewScreen, tierLadderScreen,
comparisonScreen, videoDemoScreen, ProjectionPresentation, PacePicker /
GoalDate / FirstWeek (3 more), PairedPermissionsAsk. That's 11+ distinct
layouts in one flow. her75 has 3-4. **This is the cohesion problem.**
Solve structurally (§2), not by restyling each one in place.

---

## 2. The canonical screen archetypes (5)

Every screen in onboarding + reveal + Becoming + Settings MUST snap to
one of these 5. Anything that doesn't snap gets cut or rebuilt.

### Archetype A — Question Hero (leading)

Refs: her75-homescreen.webp, her75-share.webp, IMG_6276, IMG_6275.

**Use cases:** every `jfQuestion`, `jfMulti`, `jfYesNo`, slider/picker
screens, plus 1, 11, 17, 100, 132, 133, 134, 135, 140, 141, 153, 154,
155, 156, 162, 163, 164, 167, 168, 171, 172, 173, 235, 237, 238, 239,
285.

**Layout (iPhone 13/14/15 baseline, 852pt content area):**
- NAV REGION FIXED 56pt: 10pt eyebrow slot + 6pt gap + 40pt bar row, starts at safe area + 8pt
- HERO REGION FIXED 200pt: starts safe area + 64pt; `ItalicAccentText` at 38pt heroHeadline (post re-ladder) / -18 lineSpacing / leading-aligned / hPad `Space.screenPadding` / top-aligned inside 200pt block; NO subhead, NO trust anchor, NO inline eyebrow
- INPUT REGION (flex): starts safe area + 264pt; options stack OR slider/picker
- CTA REGION FIXED 96pt from bottom: JFContinueButton 52pt + 24pt bottom + 20pt top inset

**ALLOWED:** ItalicAccentText hero (1-3 italic chunks per §5); one input cluster (pills, slider, body-type picker); one confirmation toast post-tap.

**BANNED:** `sub:`, `trustAnchor:`, `inlineFeedback:` (except 163 + 164 duty-of-care), `StickerScatter`, bgElevated/accentSubtle panels behind hero, centered alignment.

**Progress-bar consistency:** because NAV is 56pt and HERO is 200pt fixed, the bar Y is identical on every A screen.

### Archetype B — Editorial Bridge (centered typography, no chrome)

Refs: IMG_6280, IMG_6281.

**Use cases:** every `bridgeScreen` (280, 281, 282), case 283 (cohort), case 206 (recap — rebuild here), section dividers 200-205 (rebuild), educationalScreen (230, 231, 232, 233, 234, 166).

**Layout:**
- NAV REGION FIXED 56pt (Archetype A's nav, or hidden on auto-advance dividers)
- HERO centered Y, starts at safe area + 156pt: optional 11pt editorialEyebrow tracking 2 above + 8pt gap + 38pt heroHeadline / -18 / centered, NO chrome
- SUPPORTING LINE 32pt below hero: ONE line max, either `Typo.body 16pt textSecondary` OR a cocoa pill at `Typo.heroSubpill` (not both)
- CTA FIXED 96pt from bottom: JFContinueButton OR auto-advance after dwellSeconds

**ALLOWED:** one eyebrow, one supporting line, auto-advance.
**BANNED:** StickerScatter, single sticker above hero (kill on 200-205, 280, 281, 282), multi-line teach copy, options/lists.

### Archetype C — Photo Collage Reveal

Refs: her75.webp, her75-3.webp, IMG_6275.

**Use cases:** ProjectionPresentation hero, case 250 (method preview / coach hero), case 145 (video demo), welcome (case 0 keeps its existing composition).

**Layout:**
- NAV REGION FIXED 56pt
- HERO TEXT FIXED 130pt: 38pt heroHeadline / -18 / leading
- PHOTO/CARD REGION (flex ~360pt): ONE photo collage OR ONE scrapbookCard sticker module OR a video player; hPad `Space.lg`
- SUPPORTING TEXT 24pt: optional cocoa pill OR single caption line
- CTA FIXED 96pt bottom

**Per Direction A guardrails:** ≤2 stickers, ≤60pt size, real-photo ≥40% canvas.
**BANNED:** multiple photo modules, stickers floating outside the photo card, mixed alignment between hero and photo (both leading or both centered).

### Archetype D — Editorial Module Dashboard (scroll)

Ref: her75-homescreen.webp (75-Day-Hard section). The template Becoming + Settings copy directly.

**Use cases:** AnalyticsView (Becoming), ProfileHubView (Settings hub), every Settings sub-page (Account, Notifications, ChangeTrainer, EditProfile, Feedback, DeleteAccount, MyPlan, FoodSettings), PlanView.

**Layout:**
- NAV REGION FIXED 40pt: close mark or back chip only (no progress bar)
- PAGE HERO REGION FIXED 200pt: `JFPageHero` at 38pt heroHeadline / -18 / leading; 2-line capacity, top-aligned in block, NO eyebrow/subhead/sticker/chrome
- COCOA PILL (optional, 24pt): one short pill in `Typo.heroSubpill`, traces to collected data
- SCROLL REGION (flex): editorialCard modules (28pt corners, soft shadow, no border), 24pt vertical between, 18pt internal padding
- BOTTOM SAFE 80pt to clear tab bar

**BANNED:** per-page StickerScatter (kill AnalyticsView:426), `Typo.titleItalic` 32pt page heroes (promote all to JFPageHero 38pt), multiple cocoa pills, inline section headers between modules (cut `sectionHeader` rows at AnalyticsView:3476, 3490, 3528).

### Archetype E — Loader / Settle

Refs: IMG_6280, IMG_6282.

**Use cases:** BuildingPlanLoadingView, post-paywall AffirmationLoader, analyzing screen mid-onboarding.

**Layout:** NAV hidden. Hero centered Y at 38pt heroHeadline / -18 / centered + 32pt gap + 2pt hairline progress capsule (200pt wide, cocoa primary on cocoa 8% track) OR breathing dot. NO CTA — auto-advances.
**BANNED:** CTAs, stickers, sub-copy.

---

## 3. The "progress bar never moves" spec

### Why it currently feels like it shifts

1. **Chapter eyebrow `.id(currentChapter)` transition** (OnboardingView.swift:2123-2136) inserts the eyebrow Text in/out of the VStack. The progress-bar row drops 22pt when eyebrow disappears, reclaims it when it returns. Reads as "bar moved."
2. **Hero text height varies 90-160pt page-to-page**, so the gap between the (pinned) bar and the (floating) options card swings by ~80pt. Reads as everything shifted.
3. **ScrollView vs no ScrollView mismatch** — cases 11, 162, 163, 164 ship ScrollView; the rest don't. Inside ScrollView the top inset gets eaten by the implicit content inset; the pinned-overlay nav sits at a different visual Y vs non-scrolling siblings.
4. **`navBar` animates `Motion.entranceSoft`** on chapter change (line 2181). The bar itself ripples.

### The fix (Phase 1 deliverable)

(a) **Pin nav region at exactly 56pt always.** Wrap the eyebrow in a fixed 10pt ZStack slot (renders empty when no eyebrow) + 6pt gap + 40pt bar row. The slot height never changes, so the bar Y never changes.

(b) **Reserve 64pt** above `currentScreen` (was 70pt) — matches the new 56pt nav + 8pt buffer. Update OnboardingView.swift:386.

(c) **Pin hero region per archetype.** Archetype A: 200pt fixed (`.frame(height: 200, alignment: .topLeading)`). Archetype B: centered (not pinned, but the screen owns the whole canvas, so nothing else shifts around it). Archetype C: 130pt fixed. The hero block has a known ceiling; lines wrap predictably; the options/photo region below starts at the same Y on every page.

(d) **Remove all `ScrollView` wrappers** from question screens (cases 11, 162, 163, 164). If a question doesn't fit, the question has too many options — cut. her75 onboarding is one-viewport per screen.

(e) **Don't animate `navBar` itself** on chapter change. Fade eyebrow content inside its fixed slot only. Drop the `.animation(Motion.entranceSoft, value: currentChapter)` at line 2181.

---

## 4. Typography ladder corrections

Founder: "some texts are just ridiculously big and it doesn't give us the
feeling of modernness, editorial."

Measure-back from her75 references:

| Reference | Measured size | Notes |
|---|---|---|
| her75.webp "Become that girl" | ~38pt | Single screen, full-bleed photo below |
| her75-share.webp "Do it with friends" | ~42pt | Marketing peak |
| her75-homescreen.webp "Follow your routine" | ~42pt | Marketing peak |
| IMG_6275 "Matching your energy" | ~40pt | In-app screen |
| IMG_6280 "Personalizing your space" | ~42pt | In-app loader |
| IMG_6281 "Congrats..." (4-line wrap) | ~36pt | Tighter to fit 4 lines |

**Lock the in-app ladder at 38pt, not 42pt.** her75's 42pt is the marketing
peak (App Store screenshots); the in-app heroes (IMG_6275, 6276, 6277,
6280, 6281, 6282) sit at 36-40pt. 42pt + -22 leading at iPhone 13's
390pt-wide content area renders 3-line questions ("any weight-related
medication right now?") as a wall.

**Proposed re-ladder (Phase 1):**

| Register | Current | Proposed | Where | Why |
|---|---|---|---|---|
| heroHeadline (in-app default) | 42pt SemiBold -22 | **38pt SemiBold -18** | every Archetype A/B/D hero | matches IMG_6275-6282 measured; -18 keeps -47% ratio |
| heroHeadlineMarketing | (n/a) | **42pt SemiBold -22** | (deferred) for App Store screenshots only |
| questionHero (with-sub) | 34pt -14 | **DEPRECATED** | none — Archetype A bans subs | one register, not two |
| programHeroDisplay | 52pt Light -16 | **44pt Light -20** | ChapterCompleteView celebration only | scale stays earned but 52pt was too aggressive against the new 38pt question default |
| displayHero | 38pt Light -16 | **MERGED into heroHeadline** | n/a | one in-app hero size |

Cascade: bridge screens (Archetype B), question screens (A), dashboard
heroes (D) ALL render at 38pt/-18 leading. **One register, not three.**
This is the her75 cadence — its onboarding ships one hero size on every
screen.

Celebration peak (44pt programHeroDisplay) earns the ONE step up. Only
ChapterCompleteView "day N. you became her." uses it.

---

## 5. Italic-roman composition: refined rule

**The locked memory `feedback-her75-editorial-register` already loosened
the rule to 1-3 words. Codify it as PUNCH CHUNK, not punch word.**

### The new rule

A punch chunk is a contiguous **semantic unit**: a possessive phrase
("your routine"), a determiner phrase ("that girl"), a prepositional phrase
("with friends", "with your friends"), or a single deictic pronoun ("it",
"your"). It is NEVER a verb in isolation, NEVER a full clause, NEVER
random emphasis.

Decision tree per hero:

1. **Is there a possessive in the phrase?** Italicize the possessive +
   the noun it modifies. ("Follow *your routine*", "Matching *your* energy",
   "Personalizing *your* space")
2. **Is there a noun phrase carrying the becoming?** Italicize the full
   NP. ("Become *that girl*", "Start *your challenge*")
3. **Is there a prepositional / instrumental phrase?** Italicize the full
   PP. ("Do it *with friends*", "Make *it* official")
4. **Single-pronoun deictic in a short phrase?** Italicize the pronoun.
   ("Make *it* official")
5. **None of the above?** Don't italicize. (her75 ships unbroken-roman
   heroes too — see IMG_6281 line 1 "Congrats." — restraint.)

### Copy rewrites for 21 JeniFit cases (concrete strings to ship)

Format: `case → "copy"` (italic chunk in `*…*`). All at 38pt heroHeadline /
-18 leading / leading-aligned (Archetype A) unless noted.

- **1 name**: `"what should we call *you*?"`
- **100 attribution**: `"how did you *hear* about jeni?"`
- **111 motivation**: `"what's *pulling you* in?"`
- **132 weight**: `"what's *your* current weight?"`
- **133 goal weight**: `"and *your* goal weight?"`
- **134 body now**: `"*your* starting point."`
- **135 body goal**: `"*your* goal."`
- **140 identity**: `"the *new* you."`
- **141 reward**: `"the reward when *you become her*."`
- **154 sleep**: `"how *you* sleep."`
- **155 stress**: `"*your* stress, right now."`
- **162 food rel**: `"what *food* is, for you."`
- **163 hormonal**: `"where *your body* is right now."`
- **164 GLP-1**: `"any *weight meds* right now?"`
- **167 pace**: `"how *you* get there."`
- **168 tried before**: `"*tried* everything before?"`
- **17 commit**: `"how *many* days?"`
- **280 bridge num** (Archetype B center): `"now *the numbers*."`
- **281 bridge honest** (B center): `"the *honest* part."`
- **282 bridge thx** (B center): `"thank you for being *honest*."`
- **283 cohort** (B center): `"women *like you* are already inside."`
- **Plan reveal hero** (Archetype D leading): `"*your* becoming, plotted."`
- **Becoming page hero** (D leading, state-aware): `"you're *{state}*."` where state ∈ {becoming steady, just beginning, becoming patient, becoming her, showing up}
- **Settings sub-pages** (D leading): `"*your* account."` / `"*your* reminders."` / `"*your* plan."` / `"*your* coach."` / `"*your* details."`

Update memory `feedback-her75-editorial-register.md` to: "italic-Fraunces
applies to a punch CHUNK (1-3 words forming a semantic unit), not a
single word." Same memory ID; revised body.

---

## 6. Killing the old illustrations / stickers as primary mass

### Audit — per-screen recommendation

**KEEP scatter (1 surface only):** Welcome (case 0) — the ONE brand entrance per Direction A guardrails.

**CUT scatter, KEEP visual hero:**
- Method preview (250) — `StickerScatter(methodPreviewPlacements)` out; coach portrait stays (Archetype C, photo as primary mass)
- Plan reveal (ProjectionPresentation) — scatter out; the 6 proof tiles ARE the brand moment (Archetype D)
- Recap card (206) — scatter out; keep the card, rebuild it as Archetype B module reflecting 4 user inputs back

**CUT scatter entirely (promote to A/B/D):**
- Section dividers (200-205) — also kill the `singleSticker`. Per locked Direction A: bridges stay typography-only (the exhale moments). Archetype B
- Educational (230, 231, 232, 233, 234, 166) — scatter + Grok heroImage both out. Archetype B with one citation chip + body paragraph + signature
- Comparison (142) — Archetype A with options replaced by two-column grid
- Video demo (145) — Archetype C, video as photo
- Tier ladder (260) — Archetype A list (per-row sticker allowed at ≤32pt)
- Habit window quiz (270) — Archetype A
- Brand promises (240) — Archetype D with 3 editorialCards
- Review prompt — Archetype B
- First prediction (161) — Archetype A list
- Final prediction — Archetype B
- AnalyticsView Becoming (`StickerScatter(logsPlacements)` at line 426) — Archetype D bans page-level scatter
- Bridges 280/281 — cut the single sticker above hero; pure Archetype B
- HK ask (285) — borderline. Cut for Phase 1 cohesion; re-introduce as 32pt accent in Phase 4 only if it reads naked

**KEEP unchanged:** 282 reciprocity + 283 cohort (already typography-only).

**Settings sub-pages** (AccountView, NotificationSettingsView, ChangeTrainerView, EditProfileView, FeedbackView, DeleteAccountSheet): each ships a topTrailing sticker overlay (heartLock / sparkleGlossy / etc.). **Cut all** — Settings is utility, minimal-luxury restraint per `feedback-clean-luxury-aesthetic`. Headers become `JFPageHero` (Archetype D).

**Net effect:** ~17 StickerScatter call sites die. Welcome keeps its
scatter (brand entrance). Plan reveal celebrates with proof tiles, not
stickers. Educational screens go quiet. Bridge screens get exhale rooms
back. Becoming + Settings drop the per-page sticker decoration.

The visual richness is preserved by the **typographic** richness (38pt
italic-Fraunces hero on cream is rich) — per the locked memory
`feedback-visual-richness-over-restraint`, "premium-restraint applies to
copy/typography." Stickers were doing visual-density work that 38pt
italic-Fraunces does better.

---

## 7. Settings + Becoming her75 application

### The structural problem

The previous designer flipped the card chrome (`scrapbookCard` →
`editorialCard`: 24pt + border + hard shadow → 28pt + no border + soft
shadow) on Settings + Becoming. **The chrome was never the problem.**

her75's page-level structure is:
1. Page hero in 42pt italic-Fraunces, leading-aligned, 2 lines max
2. ONE cocoa social-proof / status pill below
3. White-card modules (her75-homescreen.webp shows numbered-list cards
   with photos)
4. Generous vertical breathing between modules
5. NO tab labels, NO mid-page section headers ("THIS WEEK" / "EARLIER")

Settings + Becoming currently ship:
- `Typo.titleItalic` (32pt) page heroes — too small per the new ladder
- inline stickers on every header (sparkleGlossy, heartLock, etc.)
- inline section headers (sectionHeader "this week" / "earlier" in
  AnalyticsView:3476, 3490, 3528)
- inconsistent eyebrow line — sometimes "settings" tracking 2 accent,
  sometimes none

### Define `JFPageHero` — drop-in for every Archetype D surface

Lives in `DesignSystem/Components.swift`. Props: `title: String`,
`italic: [String]`, `pill: String?` (cocoa social-proof / status pill),
`alignment: HorizontalAlignment` (.leading or .center).

Composition: `ItalicAccentText` at `Typo.heroHeadline` (38pt post-re-ladder)
+ `Typo.heroHeadlineItalic`, kerning -0.4, lineSpacing -18, fixedSize
vertical, leading or center aligned. Optional `pill` below at
`Typo.heroSubpill` 13pt with cocoa fill + textInverse copy + 6pt
vertical / 12pt horizontal padding inside a Capsule. Frame
`maxWidth: .infinity`, hPad `Space.screenPadding`, top pad `Space.md`.

### Per-surface page hero copy + pill

- Becoming (AnalyticsView): hero state-aware (see §5 last bullet); pill =
  `becoming since {month}` (real) OR `day {N}` (real). Hero leading.
- Settings hub (ProfileHubView): `"*your* space."` + pill `becoming since {month}`. Leading.
- AccountView: `"*your* account."` no pill
- NotificationSettingsView: `"*your* reminders."` no pill
- ChangeTrainerView: `"*your* coach."` + pill = current coach name
- EditProfileView: `"*your* details."` no pill
- FeedbackView: `"tell us *anything* ♥"` no pill
- DeleteAccountSheet: `"leaving for *now*?"` no pill
- MyPlanView: `"*your* plan."` + pill = current focus area
- FoodSettings: `"*your* plate, *your* rules."` no pill (2-chunk italic)

Each pill traces to a collected field (data-provenance rule). When the
data isn't available, the pill is omitted — never fabricated.

### Inline section headers (THIS WEEK / EARLIER)

her75-homescreen.webp has zero mid-page section labels. The numbered
cards (1, 2, 3, 4, 5) speak for themselves. **Cut `sectionHeader` from
AnalyticsView (lines 3476, 3490, 3528) and from any other dashboard.**
If chronological grouping matters, render an editorial-eyebrow inside the
FIRST card of each group ("THIS WEEK" tracked-eyebrow 11pt inside the
card's top-left), not a separate section divider row.

---

## 8. Phased shipping plan

Six phases. Each ≤8 changes. Build verify between every phase. No phase
requires new photo asset commission.

### Phase 1 — Pin the rails (the founder's loudest complaint)

Fix the progress-bar drift + lock the typography ladder. Visible win:
the bar stays put on every page.

1. Edit `Typo.heroHeadline` 42pt → 38pt; update `heroHeadlineLineGap`
   -22 → -18 (Tokens.swift:229-240)
2. Edit `Typo.programHeroDisplay` 52pt → 44pt; `programHeroLineGap` -16 → -20
   (Tokens.swift:135-149)
3. Refactor `navBar` to fixed 56pt with a fixed 10pt eyebrow slot
   (OnboardingView.swift:2111-2182, spec in §3)
4. Set `currentScreen` top padding to fixed 64pt (was 70pt, OnboardingView.swift:386)
5. Remove `ScrollView` wrappers from cases 11, 162, 163, 164 — cut
   options to fit if needed (each ~10 LOC)
6. Cut `Motion.entranceSoft` on navBar's `currentChapter` change
   (OnboardingView.swift:2181) — eyebrow content fades inside its slot,
   bar itself never animates
7. Cut all `trustAnchor:` parameters from `jfQuestion` call sites for
   cases 154, 155, 156, 162, 164 — keep only 163's inlineFeedback (real
   duty-of-care per `feedback-her75-editorial-register`)
8. Cut `sub:` parameter from cases 132, 133, 235, 237, 238, 239, 3, 153

**Build verify:** open each touched case in sim. Progress bar must sit
at identical Y on screen→screen swap. Hero text on case 164 must fit
without scroll.

### Phase 2 — Kill the scatter, kill the bridges' stickers

Drops the visual mass that's making the flow read as "12 different apps."

1. Cut `singleSticker` from cases 200-205 (SectionDividerScreen — change
   signature to default nil, or strip parameter — OnboardingView.swift:546-587)
2. Cut `sticker:` from `bridgeScreen` cases 280, 281, 282 (OnboardingView.swift:1589-1656)
3. Cut `StickerScatter` from: educationalAntiShameScreen, educationalFiveMinScreen,
   educationalPlateauScreen, methodPreviewScreen, tierLadderScreen,
   habitWindowQuizScreen, brandPromisesScreen, comparisonScreen, videoDemoScreen,
   recapCardScreen, planRevealPlacements use in ProjectionPresentation,
   review prompt, firstPredictionPlacements, finalPredictionPlacements
   (~14 file sites; each is 1 line removal of the `StickerScatter(...)` overlay)
4. Cut sticker overlay from each Settings sub-page header (AccountView:131-142,
   NotificationSettingsView:168-179, ChangeTrainerView, FeedbackView, DeleteAccountSheet,
   EditProfileView, ProfileHubView's identityHeader)
5. Cut `StickerScatter(logsPlacements)` from AnalyticsView:426
6. Cut sectionHeader rows from AnalyticsView (lines 3476, 3490, 3528)
7. Update the educational heroImage parameter — set to nil on every call
   site, OR remove the optional path entirely. Educational screens become
   pure-typography Archetype B (one citation chip + headline + body
   paragraph + signature, no Grok illustration)
8. Re-test welcome screen still has its scatter (keep this one)

**Build verify:** the flow now visually reads as 4-5 modes, not 12. Run
the full onboarding to plan-reveal once and confirm.

### Phase 3 — Archetype enforcement on Question + Bridge

Refactor `jfHeader` and add archetype helpers. Convert all jfQuestion
to Archetype A spec; rebuild bridge surfaces as Archetype B.

1. Rewrite `jfHeader` (OnboardingView.swift:2785-2814): drop the sub
   path entirely (or keep but never used); add `.frame(height: 200, alignment: .topLeading)`;
   accept an optional `italic: [String]` parameter and compose via
   `ItalicAccentText` instead of plain Text. Backwards-compatible signature.
2. Update every `jfQuestion` call site to pass the italic chunk per §5's
   audit table (~25 call sites — bulk find+replace in OnboardingView.swift)
3. Rebuild `bridgeScreen` helper (OnboardingView.swift:5217-5250) to
   Archetype B spec: centered hero only, no sticker param, optional ONE
   supporting line; fix the Spacer/Spacer top+bottom to anchor vertically
4. Rebuild `SectionDividerScreen` (in the file it's defined) to Archetype B
   with eyebrow + centered hero only; the partNumber renders as the
   editorial eyebrow ("part one") at 11pt tracking 2
5. Cut `inlineFeedback:` from cases 167 (pace) — was filler. KEEP on 163,
   164 (real duty-of-care)
6. Convert recapCardScreen (case 206) to Archetype B: centered hero
   "*so* — here's you." + 4 user inputs in a single editorialCard module
   below (no scatter, no scrapbookCard chrome)
7. Convert 142 comparisonScreen, 145 videoDemoScreen, 250 methodPreviewScreen,
   240 brandPromisesScreen to Archetype A or D depending on content:
   - 142 → Archetype A (two-column inside option region)
   - 145 → Archetype C (video as photo region)
   - 250 → Archetype C (coach as photo)
   - 240 → Archetype D (3 editorialCards under one page hero)
8. Convert 260 tierLadderScreen, 270 habitWindowQuizScreen, 161 prediction
   screens to Archetype A

**Build verify:** every screen now snaps to one of A/B/C. No bespoke
layouts left except welcome (which keeps its scrapbook-coquette identity
moment) and the 6 OnboardingRevealView phases (Phase 4 will land them).

### Phase 4 — Reveal flow on the same rails

OnboardingRevealView's 6 phases each have a bespoke layout today. Convert
all to Archetypes A/B/C/D using the new tokens.

1. `BuildingPlanLoadingView` → Archetype E (loader). Hero "personalizing
   *your* program." + 2pt hairline bar
2. `ProjectionPresentation` (the plan reveal) → Archetype D. Hero "*your*
   becoming, plotted." + cocoa pill `your becoming date: {goalDateText}` +
   the 6 proof tiles in editorialCards + the projection curve card
3. `PacePickerPresentation` → Archetype A. Hero "how *you* get there." +
   3 pace pills (no sticker mass on the pills; her75 has none on its
   pickers)
4. `GoalDateRevealPresentation` → Archetype B. Hero "by *{goalDateText}*."
   centered + one calm context line below
5. `FirstWeekPresentation` → Archetype D. Hero "*your* first week." +
   7-day chip row module
6. `PairedPermissionsAsk` → Archetype B with 2 inline option rows (no
   stickers)
7. Verify `HealthKitPermissionScreen` (mid-onboarding case 285) matches
   the new bridge spec — sticker already cut in Phase 2; verify hero copy
   and font tokens
8. Single audit pass: every `Typo.heroHeadline` call in this file uses
   `.kerning(-0.4)` + `.lineSpacing(-18)` after the re-ladder

**Build verify:** the full onboarding → reveal flow now reads as one
magazine. Take 30 screenshots back-to-back and compare against the
her75-share + her75-homescreen + IMG_6275-6282 reference set.

### Phase 5 — Becoming dashboard on Archetype D

The Becoming tab rebuilt around `JFPageHero` + editorialCard modules.

1. Add `JFPageHero` to `DesignSystem/Components.swift` (spec in §7)
2. Add `becomingState` derivation function (returns one of 5 italic
   chunks based on weight logs + sessions + trend) to AnalyticsView
3. Replace BecomingStatusStrip (AnalyticsView:447) with `JFPageHero(title:
   "you're {state}.", italic: [state], pill: becomingPill, alignment: .leading)`
4. Cut `sectionHeader` calls from "more depth" sheet (AnalyticsView:3476,
   3490, 3528) — replace with in-card eyebrow inside first card of group
5. Update all bento tiles' headers — `tileHeader` (AnalyticsView:2637) —
   to use `Typo.heading` (20pt DM Sans SemiBold) NOT `Typo.titleItalic`.
   Module titles are utility, hero is editorial — separation per
   `feedback-clean-luxury-aesthetic`
6. Tighten LazyVStack spacing on Becoming from 20pt to Space.lg (24pt)
   matching the her75-homescreen vertical rhythm (AnalyticsView:434)
7. Confirm `editorialCard` 28pt corners + soft shadow is the only chrome
   used (no scrapbookCard on Becoming surfaces)
8. Update Becoming task `.onAppear` to cascade the page hero THEN modules
   per Motion.cascadeTight (0.06s stagger) — module reveal already cascades;
   tie page hero to delay=0

**Build verify:** Becoming reads as a magazine spread. Same page-hero
height as onboarding. Modules feel like cards in a printed dashboard,
not iOS list rows.

### Phase 6 — Settings on Archetype D

Last surface area. Settings hub + every sub-page conforms to JFPageHero.

1. ProfileHubView.identityHeader (lines 178-227) → `JFPageHero(title:
   "*your* space.", italic: ["your"], pill: becomingPill)`. The
   user-initial circle + name + shownUpCount becomes a SEPARATE
   `IdentityModule` editorialCard rendered below the hero
2. Each settings sub-page header replaced with `JFPageHero`:
   - AccountView (lines 121-143)
   - NotificationSettingsView (lines 158-180)
   - EditProfileView
   - ChangeTrainerView
   - FeedbackView
   - DeleteAccountSheet
   - MyPlanView (find + apply)
   - FoodSettings (find + apply)
3. Each sub-page's eyebrow ("settings" accent-text tracking 2) becomes
   the editorial eyebrow in the JFPageHero (or is dropped — her75
   doesn't show breadcrumb-eyebrows on its sub-pages; consider dropping)
4. Confirm every Settings sub-page background is `Palette.bgPrimary` (cream)
   — no programEraBg alias variance
5. Cut the sticker overlay from each header (heartLock, sparkleGlossy,
   etc.) — already done in Phase 2; verify
6. Promote `versionFooter` + `resetButton` (AccountView) into a
   `editorialCard` at the bottom — consistent with the rest of the
   page modules
7. Audit `Typo.titleItalic` usage across files via grep — every remaining
   call site is either inside a card chrome OR a sheet hero. Confirm
   each is correct in context (e.g., MetricExplainerSheet's titleItalic
   is correct because the sheet is its own page; the LogWeightSheet
   header is also correct). No call site should be a page-level hero
   any more (those are JFPageHero)
8. Final cross-flow QA: walk from welcome → onboarding → reveal → home →
   Becoming → Settings → every sub-page. Capture 12 screenshots and
   verify all heros use 38pt italic-Fraunces leading-aligned with the
   identical hero region height and the identical post-hero gap.

**Build verify:** every page across the app now has the same hero
silhouette. The progress-bar consistency, the typography consistency,
the chrome consistency. Founder QA pass.

---

## Cross-cutting reminders

- **Italic-roman composition refinement** (§5): update the memory
  `feedback-her75-editorial-register.md` to "italic-Fraunces on a punch
  CHUNK (semantic unit), 1-3 words, per decision tree." Memory ID and
  metadata stay, body extends.
- **38pt re-ladder** (§4): update memory `feedback-hero-typography-ladder.md`
  with the new 38pt/-18 number and the merged displayHero deprecation.
- **JFPageHero** (§7): once shipped, document it in `DesignSystem/Components.swift`
  as the canonical drop-in for every Archetype D surface (Becoming, Settings,
  PlanView). No surface ships a one-off page hero composition.
- **No new memory files** unless a new principle emerges from Phase 1-6
  build feedback. The locked memories already cover the surface area.
- **The `editorialCard` 28pt-corner / soft-shadow chrome stays** (the
  previous designer's last call was right at the chrome level). What
  was wrong was the page-level structure, which §7 now fixes.

---

## What this plan does NOT cover

- Welcome screen redesign beyond keeping it as the brand entrance (the
  scatter stays; the photo/video composition stays). Welcome belongs in
  a separate landing-page redesign (different audience: first impression
  vs in-flow user)
- Paywall redesign — locked memory `project_paywall_v107_single_screen`
  already covers it. Apply Archetype D to paywall when that lands
- Home screen — `project_home_architecture` is the right doc for that
- Food rail surfaces — separate locked memory `project_food_rail_v3_locked`
- Direction A photo library commission — gated per the Direction A
  guardrails memo

The phases above are surgically scoped to the founder's actual complaint:
onboarding cohesion + Becoming + Settings in the her75 register.
