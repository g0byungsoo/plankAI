# 48 — THREE THINGS BEFORE SUBMISSION

**feat/app-v2 · 2026-08-15 · `CURRENT_PROJECT_VERSION` 31 → 32**

Build 31 was a valid frozen release candidate. The founder found three
concrete things on a physical-device onboarding walk before submission.
The freeze was broken deliberately, for those three things and nothing
else.

**FREEZE BASELINE.** HEAD `723d0b8` · `MARKETING_VERSION` 1.2.0 ·
`CURRENT_PROJECT_VERSION` **31** at the start (30 at HEAD; the bump to
31 was already in the working tree from `46`).

---

## 1 · THE MEDICATION SCREEN DID NOT SCROLL BECAUSE THE CONSULT HAS NO SCROLL CONTAINER AT ALL

**EXPECTED** — `which one?` offers ten options (eight injectables +
*something else* + *not sure yet*); every one is reachable.

**ACTUAL** — on the founder's iPhone eight rendered, the ninth was cut,
the tenth was not there, and dragging did nothing.

**ROOT CAUSE, found in source and then measured.** `grep -rn ScrollView
PlankApp/Views/OnboardingV8/` returns **nothing**. The consult stage is a
`GeometryReader` holding `V8Transcript`, which is a plain `VStack`
positioned by a manual `.offset(y:)` — the anchored-transcript motion
that is the flow's identity. There is no scroll mechanism anywhere in
the era. The standing assumption was written into `V8Stage.inputColumn`
itself:

> *"Natural height: the column starts at the top in ask mode, so
> standard inputs always fit. (XXL overflow is a known follow-up …)"*

**[CORR] That note was wrong at DEFAULT type on a 6.7" phone.** It was
not an accessibility-size follow-up. `medOne` builds its options from
`MedicationCatalog.products(route: .injection)` — **eight** — plus two
outs. Ten `V8OptionCard`s at 18pt vertical padding and 10pt spacing is
**≈660pt of options** under a hero, a caption and 52pt of chrome. It has
never fit on any iPhone. It is the only list in the consult that
overflows: the other beats are 2–5 options, the oral list is 3.

**MEASURED, NOT INFERRED.** A film door (`--debug-v8-med-list`) mounts
the beat alone. A leg then swiped up eight times and read the last
option's frame:

```
XCTAssertLessThanOrEqual failed: ("868.6666666666666") is greater than ("818.0")
```

**868.6666666666666 before eight full-screen swipes and 868.6666666666666
after. The list moved 0.0pt.** That is the defect, stated as a number.

**A SECOND FINDING, AND IT IS WHY NOBODY CAUGHT THIS.** XCUITest reported
that button **`isHittable == true`** while its frame sat 50pt *below the
bottom of the screen*. Every walker in this repo taps `ozempic` — the
first row. A hittability-based assertion would have passed. The
regression test asserts **geometry**, against the page's own measured
bottom edge.

**THE FIX** (`V8Stage.swift`, the smallest root cause):

- ONE `ScrollView` around the column **in both modes**, so nothing
  changes identity when the input arrives mid-beat. A
  `if asking { Scroll } else { plain }` would tear down and re-insert the
  question on every beat in the consult.
- `.scrollDisabled(!scrolls(viewport:))` — scrolling engages only while
  she is being asked something **AND** the measured column height
  exceeds the viewport. **Four beats in this consult are RULERS** (age ·
  height · weight · goal) driven by a horizontal
  `DragGesture(minimumDistance: 1)`, which is exactly what a vertical
  scroll container steals. Gating on measured overflow means the only
  screens whose gesture behaviour changes at all are the ones that were
  broken.
- `.scrollBounceBehavior(.basedOnSize)` — a list that fits stays as
  immovable as the paper it is printed on. Without it every three-option
  beat would start rubber-banding, which is a redesign nobody asked for.
- Bottom padding pays back `anchorY` (the ask-mode offset is a render
  shift the scroll extent cannot see) plus a **measured** dock inset, so
  a docked commit pill can never hide the last row at any Dynamic Type
  size.

**Visual design at rest: unchanged.** Same hero, same caption, same
cards, same spacing, same copy, same options, same selection behaviour.
The scroll indicator is iOS-standard and invisible until she drags.

**PROVEN ON** iPhone SE (3rd gen, smallest, no home indicator) · iPhone
16 · iPhone 17 Pro Max · **and at AX5 (accessibility-extra-extra-extra-large)
on the SE**. Also proven in the **REAL consult with the chrome present**
— a walk from `begin` to `medOne` that scrolls to *not sure yet*, taps
it, and confirms the consult advances. No walker in this repo had ever
answered that question with anything but the first row.

**[CORR] on the first draft of the test:** it subtracted a 34pt home
indicator unconditionally and failed the SE, which has a home button and
a bottom inset of 0. The bound is now **measured** from the page's own
frame — 818 on a phone with an indicator, 667 on an SE.

---

## 2 · THE FOOD SNAP SCAN DID NOT ANIMATE BECAUSE `.onChange` CANNOT SEE A VIEW'S FIRST VALUE

**EXPECTED** — photo → **scanning** → result, with `SnapDial`'s identity
motion: the outline draws itself from 12 o'clock over the resting
brackets.

**ACTUAL** — the plate expands, "reading the plate…" appears, and
nothing moves for two seconds.

**ROOT CAUSE.** `SnapDial` drove `traceTo` **only** from
`.onChange(of: isScanning)` and `.onChange(of: scanComplete)`.
`OV5SnapDemo` inserts the dial inside `if phase != .pick { … }` at the
exact instant `phase` becomes `.scanning`, so the dial is **born with
`isScanning == true`**. `.onChange` does not fire for an initial value.
`traceTo` never left its `@State` initial 0.

It is worse than "no animation": the resting brackets are stroked at
`opacity(isScanning ? 0.30 : 0.92)` — **dimmed precisely because a bright
trace is supposed to be drawing over them.** The customer got a *fainter*
still picture than the resting state would have been.

**THIS CODE PATH HAS EXACTLY ONE CALLER AND IT NEVER WORKED.** The only
other `SnapDial` call site in the product, `PhotoCaptureView:388`, passes
`isScanning: false, scanComplete: false` — it is only ever the resting
aim; the shipping camera's scan motion is a different view
(`SnapProcessingStage`).

**MEASURED, NOT INFERRED.** Screenshots of the reading window:

| frame | md5 |
|---|---|
| run A, "demo_scanning" | `aedc7ae0c304fdf86ca88e4826205d24` |
| run B, sample 0 | `aedc7ae0c304fdf86ca88e4826205d24` |
| run B, sample 1 (+0.38s) | `aedc7ae0c304fdf86ca88e4826205d24` |

**Two independent app launches, frames taken at different moments inside
the reading, byte-identical.** The reading was a still picture.

**[CORR] ON MY OWN FIRST TEST.** The first motion test *passed* against
the broken build, because the frame it caught moving was the **result
panel rising** past the 2.0s mark. Timestamps now bound every sample
inside the reading window. Re-run against the pre-fix dial:

```
XCTAssertTrue failed - the reading is a still picture:
2 frames inside the scan window are byte-identical
```

**THE FIX** (`SnapDial.swift`, at the source, not the call site): the
trace decision is a pure `SnapDial.plan(isScanning:scanComplete:reduceMotion:)`,
applied from `.onAppear` **and** both change hooks. A dial born reading
draws; a dial born idle does not. `PhotoCaptureView` is born idle, so the
appearance hook is a no-op there — the camera's resting frame did not
gain an animation.

**REDUCE MOTION.** No trace, by the law at the top of that file; the
caption line alone carries the wait. But 0.8s — of which the surface
crossfade eats ~0.3s — does not carry it. The reduce-motion hold is
**0.8s → 1.4s**. Nothing moves; the semantic state is simply held long
enough to read. The full-motion window is untouched at 2.0s.

**AFTER:** three distinct frame hashes across the reading, and the film
shows the outline closing clockwise from 12 o'clock. Calories, protein,
the photograph and the result card are byte-identical to before.

---

## 3 · THE ASSET CATALOG — 177 ENTRIES AUDITED, 7 PROVEN DEAD, 3.73 MB REMOVED

Machine-derived census over 908 files: Swift (app · widgets · packages ·
tests), JSON, plists, the project file, and every interpolated
(`"prefix\(x)suffix"`) and concatenated name-building literal in the
codebase.

| class | count | |
|---|---|---|
| **A — LIVE** | 164 | an exact reference exists in code, a bundled resource, or a build setting |
| **B — TEST/PREVIEW ONLY** | 0 | |
| **C — DYNAMIC/UNCERTAIN** | 6 | `bodytype-0…5`, produced by `Image("bodytype-\(i)")` — **not deleted** |
| **D — PROVEN UNUSED** | 7 | **deleted** |

**THE FOUNDER'S HYPOTHESIS WAS MOSTLY WRONG, WHICH IS THE POINT OF
PROVING IT.** Every family named in the brief is referenced:
`onb-itgirl-*` · `onb-logo-*` (the attribution logos) · `onb-movement-*`
· `onb-profile-*` · `onb-v5-demo-*` (**the live consult's own food
demo**) · `social-*`. Old-looking names, all wired.

**REMOVED (7), with the evidence for each:**

| asset | bytes | evidence |
|---|---|---|
| `onb-cuisine-eastasian` | 807,710 | zero hits repo-wide; its five siblings' only relative, `onb-cuisine-mediterranean`, IS referenced (kept) |
| `onb-cuisine-italian` | 678,328 | as above |
| `sticker_pressed_flower` | 610,298 | every sticker resolves through one `switch` in `Stickers.swift`; 36 sticker literals exist in the codebase and 36 sticker imagesets existed — this is the one with no case |
| `onb-cuisine-mexican` | 598,582 | as above |
| `onb-cuisine-southasian` | 576,239 | as above |
| `onb-cuisine-american` | 501,825 | as above |
| `logo_jenifit_bow` | 139,648 | zero hits; no `logo_jenifit` prefix is constructed anywhere |

**Reference channels checked and closed, not assumed:**
`Image("…")` · `UIImage(named:)` · **generated asset symbols**
(`Image(.name)` / `ImageResource` — **zero first-party uses**; the only
hits in the tree are a vendored PostHog example) · bundled JSON (the
42 `jm_hero_*` are named by `PlankApp/Resources/manifest_v1.json`, so
they stay) · `Info.plist` (`LaunchBackground`, the launch colour —
**untouched**) · build settings (`ASSETCATALOG_COMPILER_APPICON_NAME =
AppIcon` — **AppIcon untouched**) · storyboards/xibs/`.xcstrings`
(**none exist**) · the widget extension (SF Symbols only).

**NEGATIVE PROOF.** `assetutil --info` on the compiled `Assets.car`,
before and after:

- named assets **181 → 174**; the delta is **exactly the seven**, and
  **nothing else changed** (`new vs baseline: []`).
- Every string literal in first-party Swift that named a compiled asset:
  **123 of 123 still resolve. Broken references: 0.**
- The seven names appear **0 times** anywhere in the built `.app`.

---

## 4 · DEAD ONBOARDING CODE — REPORTED, NOT REMOVED

`PlankApp/Views/Onboarding/OnboardingView.swift` (the legacy v4.5 flow,
**9,645 lines**) is instantiated at `PlankAIApp.swift:1874` **inside
`#if DEBUG`, behind `--onboarding-v4`**. It is compiled into the app and
unreachable in Release.

**It is the real residue the founder sensed:**

- **18 assets are referenced by nothing else** — the whole `social-*`
  family, `onb-profile-cap/towel/scarf/bun/braid`, `onb-cohort-3`,
  `onb-itgirl-produce`, and `onb-cuisine-mediterranean`: **15,133,028 B
  (14.43 MB)**
- **`bodytype-0…5`**, whose only producer is that file's
  `Image("bodytype-\(i)")`: **16,588,576 B (15.82 MB)**
- **Combined: 30.25 MB of a 76 MB catalog.**

**NOT TOUCHED.** They are class C, not class D — dynamic lookup remains
possible while the file compiles — and removing 9,645 lines is
archaeology, not asset cleanup, on a release candidate. Sequenced for a
later pass, with the prize measured so the decision can be made on a
number.

---

## 5 · PROOF

| gate | result |
|---|---|
| app unit suite | **1368 / 1368**, 2 skipped (the env-gated `SpineLiveSyncTests`), 0 failures — **exactly `46`'s baseline** |
| PlankSync | **9 / 9** |
| PlankFood | **208 / 208** (was 200; **+8 = exactly `SnapDialTraceTests`**) |
| `WallExitWalkUITests` | **PASS** — the 5.6 close-button fix |
| `KeepWallUITests` | **3 / 3** |
| `DownsellSheetUITests` | **PASS** *(`46` recorded this leg red; it is green now)* |
| `OnboardingV5WalkerUITests/testWalkV8ToPaywall` (GLP-1 current) | **PASS**, 308.1s — consult → medication beats → food demo → wall |
| `testReviewerJourneyReleaseWalk` | **PASS**, 284.8s — every wall exit |
| `OnboardingDefectsPass48UITests` | **6 / 6** on SE · iPhone 16 · 17 Pro Max |
| Release build | **BUILD SUCCEEDED**, 0 errors |

**RED PROVEN BEFORE GREEN, both defects:**

- medication — 868.67 vs 818.0, unchanged by eight swipes.
- food snap — "the reading is a still picture: 2 frames … byte-identical".
- `SnapDialTraceTests` — **4 failures of 8** against a stub written as
  the honest before state. The 4 that passed are the resting aim, reduce
  motion, and the closing frame: behaviour that already worked. A stub
  cannot fail the rows that were never broken.
- **[CORR] on one of my own tests.** `testTheTraceDrawsWhetherItArrived
  ByChangeOrWasBornThatWay` first asserted only `born == changed`, which
  a nil-returning stub satisfies with `nil == nil` — the refusal trap
  this repo has recorded for ten sessions. It asserts a drawn trace now.

**TWO TRAPS FIRED AND BOTH WERE CAUGHT.**

1. **`Executed 0 tests` + `TEST SUCCEEDED`, exit 0.** `-only-testing:
   plankAIUITests/OnboardingWalkthroughUITests/testWalkV8ToPaywall` —
   that method lives in `OnboardingV5WalkerUITests`; the file holds nine
   classes. Caught by checking expected count against actual, then
   confirmed with `-enumerate-tests`.
2. **A RED reviewer-journey walk that was not a regression.**
   `testReviewerJourneyReleaseWalk` failed with *"the close control died
   on its second press"* — the exact leg the brief protects. It had been
   run **immediately after `KeepWallUITests` and `DownsellSheetUITests`
   on the same simulator**, and the wall's `smallerStepShown` /
   `downsellShown` once-flags are `@AppStorage`, which
   `--uitest-fresh-onboarding` does not clear. The first close therefore
   stood the wall down instead of offering, and no `rj-05` frame was
   captured. **`simctl erase`, then the same leg solo: PASS in 284.8s**,
   against `46`'s recorded 285.5s. The repo's own law — *UI legs run
   SOLO* — and I had broken it. Nothing was changed to make it pass.

**RELEASE BINARY (build 32):** `CFBundleVersion` **32** ·
`CFBundleShortVersionString` 1.2.0 · binary 84.3 MB.
`--uitest` **0** · `--debug-` **0** · `--debug-v8-med-list` **0** ·
`--debug-snap-demo` **0** · `onboarding-v4` **0**. **Controls fire:**
`ozempic` ×5, `compounded semaglutide` ×1, `shots, or pills` ×1,
`reading the plate` ×1, `not sure yet` ×1. (`which one?` reads 0 and is
not evidence of anything — at 10 UTF-8 bytes it is a Swift small string,
stored inline rather than in the string table.)

**SIZES.**

| | before | after | delta |
|---|---|---|---|
| catalog entries | 177 | 170 | −7 |
| catalog source bytes | 80,186,010 | 76,273,380 | **−3,912,630 (−3.73 MB)** |
| `Assets.car` | 63,805,608 | 61,080,328 | **−2,725,280 (−2.60 MB)** |
| Release `.app` | 228,129,399 | 225,228,215 | −2,901,184 (−2.77 MB) |

The `Assets.car` figure is the reliable one; the two `.app` builds differ
in version and carry ordinary build nondeterminism (~150 KB).

---

## 6 · SCOPE

**Six source files, mechanically enumerated with `find -newer`:**

```
PlankApp/Views/OnboardingV8/V8Stage.swift          the scroll fix
Packages/PlankFood/.../Capture/SnapDial.swift      the trace self-drive
PlankApp/Views/OnboardingV5/OV5SnapDemo.swift      reduce-motion hold, 1 number
PlankApp/App/DebugPreviewRoutes.swift              two DEBUG film doors
plankAIUITests/OnboardingWalkthroughUITests.swift  6 regression legs
Packages/PlankFood/Tests/.../SnapDialTraceTests.swift  new, 8 tests
plankAI.xcodeproj/project.pbxproj                  4 lines: 31 → 32
```

**PROTECTED PATHS, EMPTY vs HEAD:** Payment · Views/Paywall ·
Notifications · Care · BodyScan · `supabase/` · JenifitWidgets ·
`Info.plist` · entitlements. *(Auth and Analytics show diffs vs HEAD —
those are the pre-existing uncommitted v25 work from passes 30–47, not
this pass; `find -newer` lists neither.)*

**No migration. No Edge Function. No deploy. No production SQL. No
production probe. No production account. No schema, RLS, grant, policy
or function touched. Zero production mutations.** No nutrition, weight,
program, GLP-1-safety, deletion, privacy, metadata, analytics,
notification or care logic changed. No `@Model` changed, so there is no
store migration.

**NEXT — and only if the founder decides:** the v4.5 `OnboardingView`
sweep, worth a measured 30.25 MB, with its own RED→GREEN. Nothing else
in this pass is unfinished.
