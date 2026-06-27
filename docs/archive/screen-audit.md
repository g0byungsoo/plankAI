# Screen Audit — absmaxxing → JeniFit Brand Pivot

**Generated:** 2026-05-02
**Scope:** Every user-facing surface in the iOS app — screens, sheets, fullScreenCovers, alerts, major UI components.
**Purpose:** Pre-redesign reference. Each entry contains enough information to redesign that surface without re-reading source code.

---

## Table of Contents

1. [Onboarding (~26 surfaces)](#1-onboarding)
2. [Auth (6 surfaces)](#2-auth)
3. [Home / Analytics / Tabs (~16 surfaces)](#3-home--analytics--tabs)
4. [Session / Routine (6 surfaces)](#4-session--routine)
5. [Settings sub-pages (6 surfaces)](#5-settings-sub-pages)
6. [Paywall (1 surface)](#6-paywall)
7. [Design System Reference](#7-design-system-reference)
8. [Appendix A — Total surface count](#appendix-a--total-surface-count)
9. [Appendix B — All "absmaxxing" copy strings (verbatim with file:line)](#appendix-b--all-absmaxxing-copy-strings-verbatim-with-fileline)
10. [Appendix C — "ab routine" / "core" / "plank" positioning vs exercise references](#appendix-c--ab-routine--core--plank-positioning-vs-exercise-references)
11. [Appendix D — Voice clip filenames](#appendix-d--voice-clip-filenames)
12. [Appendix E — Brand promises locked to absmaxxing positioning](#appendix-e--brand-promises-locked-to-absmaxxing-positioning)

---

## 1. Onboarding

The onboarding flow lives in a single 2400-line file `OnboardingView.swift` plus helper components in `OnboardingComponents.swift`. The screen index is non-monotonic: screens 0–17 run linearly, then 25 (session length) sits between 17 and 18, and 26 (sign-in interstitial) sits between 21 and 22. Splash is screen -1.

### -1. Splash Screen

**File:** `PlankApp/Views/Onboarding/OnboardingView.swift:331-392`
**Purpose:** Brand introduction and loading transition. Animated logo + underline + pulsing dots before auto-advancing to welcome.
**Entry points:** App launch; `@State screen = -1` initializes here.
**Visual structure:** Centered "absmaxxing" logo (42pt black) → animated underline grows to 120pt → three pulsing dots (6pt circles).
**Copy strings (verbatim):**
```
Logo: "absmaxxing"
```
**Components used:** Palette.bgPrimary, Palette.textPrimary, Palette.accent, Haptics.medium(), withAnimation(.spring())
**State:** `splashLogoVisible`, `splashLineVisible`, `splashPulse`
**Actions:** Auto-transition to welcome after 1.8s via `go(0)`.
**Animations:** Logo scale-in (spring 0.5s, damping 0.7), underline draw (easeOut 0.6s, delay 0.4s), dots pulse forever (easeInOut 0.5s, staggered 0.15s).
**Special considerations:** Three-stage entry: logo+haptic, underline+dots, auto-advance. No interaction.
**Brand-locked copy:** `"absmaxxing"` (line 339)

### 0. Welcome

**File:** `OnboardingView.swift:398-525`
**Purpose:** Value proposition + hero mockup before questions begin.
**Entry points:** Auto-advance from splash; `go(0)`.
**Visual structure:** Phone mockup (220×380) with "47s + GOOD FORM badge + skeleton chart" + "🔥 Kira" voice bubble → "absmaxxing" headline → subhead → "Get Started" CTA → "Already have an account? Sign In" link.
**Copy strings (verbatim):**
```
Headline: "absmaxxing"
Subhead: "AI plank trainer that actually makes you show up"
CTA: "Get Started"
Link: "Already have an account? **Sign In**"
Voice bubble: "🔥 Kira" + "\"Hips! Up!\nYou're giving\nhammock rn\""
```
**Components used:** Custom phone mockup frame, gradient overlay, voice bubble card, ConfettiView, skeletonMini chart, plankShadow()
**State:** `heroVisible`, `bubbleVisible`, `visible`, `showConfetti`, `showWelcomeSignInSheet`
**Actions:** "Get Started" → `go(1)`. "Sign In" → presents SignInPromptView (mode: .signIn); if signed in post-close, sets `hasCompletedOnboarding = true` and skips entire flow.
**Animations:** Phone fades+offsets (easeOut 0.5s, delay 0.15s), text+button fade (easeOut 0.5s, delay 0.5s), confetti 2.5s, voice bubble springs in (spring 0.4s, damping 0.6, delay 1.4s).
**Special considerations:** Sign-in path can short-circuit entire onboarding for returning users.
**Brand-locked copy:** `"absmaxxing"` (line 468), AI plank trainer positioning

### 1. Goal Question

**File:** `OnboardingView.swift:167-175`
**Purpose:** Determine primary fitness goal.
**Visual structure:** Standard `questionView()` pattern — headline + subhead + four toggleable options + inline feedback toast + Continue.
**Copy strings (verbatim):**
```
Headline: "What do you want\nto achieve?"
Subhead: "We'll build your plan around this."
Options:
  "💪  Stronger core"      (strength)
  "🧍‍♀️  Better posture"     (posture)
  "✨  Feel more confident" (confidence)
  "🔥  Get toned"          (toned)
Feedbacks:
  strength:   "Strong core = strong everything 💪"
  posture:    "Good posture changes how people see you"
  confidence: "It starts from the inside out ✨"
  toned:      "30 days. You'll feel the difference 🔥"
```
**State:** `goal`, `inlineFeedback`, `showInlineFeedback`
**Actions:** Select → updates `goal`. Continue → 1.2s feedback toast, advance to screen 2.
**Animations:** Selected button scales up (spring 0.25s); feedback toast appears/disappears (scale 0.88 + opacity).
**Brand-locked copy:** "30 days" (toned feedback)

### 2. Experience Question

**File:** `OnboardingView.swift:177-185`
**Purpose:** Gauge workout history. Branches: skips Baseline if "never".
**Copy strings (verbatim):**
```
Headline: "Do you work out\nyour core?"
Subhead: "Be honest. Zero judgment."
Options:
  "🆕  Never really"        (never)
  "😅  Tried, couldn't stick" (gaveUp)
  "🔄  Here and there"      (sometimes)
  "💎  Regularly"           (regular)
Feedbacks:
  never:     "Everyone starts somewhere 🙌"
  gaveUp:    "This time you have a coach who won't let you quit"
  sometimes: "Let's make it a daily habit"
  regular:   "Let's take it to the next level 😏"
```
**State:** `experience`
**Actions:** Continue → screen 3 (Baseline) **unless** experience == "never", then jumps to screen 4 (Chart). Dynamic next screen.

### 3. Baseline Plank Time Question

**File:** `OnboardingView.swift:187-195`
**Purpose:** Establish benchmark hold time. Skipped if experience == "never".
**Copy strings (verbatim):**
```
Headline: "How long can you\nhold a plank?"
Subhead: "This sets your benchmark starting point."
Options:
  "⚡  Under 15 seconds"    (under15 → 10s)
  "🔥  15–30 seconds"       (15to30 → 20s)
  "💪  30–60 seconds"       (30to60 → 45s)
  "👑  60+ seconds"         (over60 → 60s)
Feedbacks:
  under15: "You'll double this in 2 weeks"
  15to30:  "Solid starting point"
  30to60:  "Ahead of most people already"
  over60:  "Elite. Let's perfect that form 👑"
```
**State:** `baseline`
**Special considerations:** `bS()` helper maps key → seconds.

### 4. Chart (Retention Education)

**File:** `OnboardingView.swift:740-875`
**Purpose:** Educate on dropout statistic. Visual: 87% quit; "absmaxxing" keeps engaged.
**Visual structure:** "87%" headline (64pt) → "of people quit\nhome workouts in 2 weeks" → "not with a coach in your pocket" → animated chart (dropout dashed line vs success solid line + glow dot) → axis labels + legend.
**Copy strings (verbatim):**
```
Headline: "87%"
Headline text: "of people quit\nhome workouts in 2 weeks"
Tagline: "not with a coach in your pocket"
Axis: "Week 1", "Week 4"
Legend: "gave up", "absmaxxing"
```
**State:** `chartLine1`, `chartLine2`, `chartDot`, `chartHeadline`, `chartAnimated`
**Animations:** Headline scales in (spring 0.5s, delay 0.2s); dropout line draws (easeOut 1.0s, delay 0.8s via `.trim()`); success line draws (easeOut 1.2s, delay 1.2s); fill appears; dot scales in (spring 0.4s, delay 2.4s). ~4s total.
**Brand-locked copy:** `"absmaxxing"` (chart legend, line 843)

### 5. Barriers (Multi-Select)

**File:** `OnboardingView.swift:199-203`
**Purpose:** Identify pain points. Multi-select. Customizes celebration + plan reveal.
**Copy strings (verbatim):**
```
Headline: "What usually\nstops you?"
Subhead: "Pick all that apply."
Options:
  "😴  Workouts get boring"           (boring)
  "🤷  Don't know what to do"          (dontKnow)
  "📉  Hard to stay consistent"        (motivation)
  "⏰  Never have time"                 (time)
  "🩹  Worried about doing it wrong"   (injury)
Feedbacks (first match shown):
  boring:     "We keep it fresh every day"
  dontKnow:   "That's why we pick the workout for you"
  motivation: "Your coach won't let you skip"
  time:       "5 minutes. That's all it takes"
  injury:     "Voice coaching keeps your form safe"
```
**State:** `barriers: Set<String>`, `multiFeedback`, `showMultiFeedback`
**Special considerations:** Required selection (Continue disabled until ≥1).

### 6. Celebration (Barrier-Responsive)

**File:** `OnboardingView.swift:884-962`
**Purpose:** Acknowledge barriers, introduce solution. First coach photo reveal (Kira/Sarah/Matson trio).
**Visual structure:** Three overlapping coach circles (68×68, pulsing ring halos) → barrier-responsive headline → fix tagline.
**Copy strings (verbatim):**
```
Dynamic by first selected barrier:
  boring:     msg "Boredom is the #1 reason\npeople quit planking."
              fix "Your AI coach makes\nevery second count."
  motivation: msg "Motivation fades.\nAccountability doesn't."
              fix "Your coach shows up\nevery single day."
  dontKnow:   msg "Not knowing correct form\nis more common than you think."
              fix "Your AI coach corrects\nyour form in real time."
Default:      msg "We hear you."
              fix "absmaxxing was built for this."
```
**Animations:** Photos spring in staggered (0.4s, delays 0–0.24s); text fades (easeOut 0.6s, delay 0.5s); rings pulse forever (easeInOut 1.2s, staggered 0.3s).
**Brand-locked copy:** `"absmaxxing was built for this"` (line 893, default fallback)

### 7. Age Range Question

**File:** `OnboardingView.swift:207-218`
**Copy strings (verbatim):**
```
Headline: "How old are you?"
Subhead: "This personalizes your plan intensity."
Options:
  "⚡  Under 18"   (under18)
  "🔥  18–24"      (18to24)
  "💪  25–34"      (25to34)
  "✨  35–44"      (35to44)
  "🧘  45–54"      (45to54)
  "👑  55+"        (55plus)
Feedbacks:
  under18: "Starting young = starting right"
  18to24:  "Peak building years. Let's go"
  25to34:  "The sweet spot for results"
  35to44:  "Core strength matters more every year"
  45to54:  "This is when planking pays off the most"
  55plus:  "Strong core = independence for life 👑"
```
**State:** `ageRange`

### 8. Activity Level Question

**File:** `OnboardingView.swift:220-230`
**Copy strings (verbatim):**
```
Headline: "How active are\nyou right now?"
Subhead: "This calibrates your starting level."
Options:
  "🛋️  Not very active"        (sedentary)
  "🚶  Light walks / stretching" (light)
  "🚴  A few workouts a week"   (moderate)
  "🏋️  4–5x a week"             (active)
  "🏃‍♀️  Daily training"          (athlete)
Feedbacks:
  sedentary: "We start easy. No judgment at all"
  light:     "Great foundation to build on"
  moderate:  "Perfect. This fits right in"
  active:    "We'll push you 😈"
  athlete:   "Let's see how your core stacks up 💪"
```
**State:** `activityLevel`

### 9. Did You Know (Core Fact Education)

**File:** `OnboardingView.swift:1921-1960`
**Purpose:** Education moment. Why core matters.
**Copy strings (verbatim):**
```
Label: "Did you know?"
Headline: "Your core activates\nbefore every movement\nyou make."
Subtext: "Walking. Sitting. Standing up.\nA weak core means everything\nis harder than it should be."
```
**Animations:** Text fades + offsets (easeOut 0.5s, subtext delay 0.3s).

### 10. Focus Area Question

**File:** `OnboardingView.swift:234-242`
**Purpose:** Personalize coaching targets. Drives "Abs Definition", "Waist Sculpting", "Core Strength", "Full Core" labels in later screens AND paywall headline.
**Copy strings (verbatim):**
```
Headline: "What do you want\nto target?"
Subhead: "We'll focus your coaching here."
Options:
  "🎯  Abs / front core"        (abs)
  "🔄  Obliques / waist"        (obliques)
  "🔙  Lower back"              (lowerBack)
  "💎  Full core — everything"  (fullCore)
Feedbacks:
  abs:       "Front and center. We'll get there"
  obliques:  "Waist definition takes real form"
  lowerBack: "Underrated. This changes posture"
  fullCore:  "The complete package 💎"
```
**State:** `focusArea` — feeds into `@AppStorage("focusArea")`, used by PaywallView for personalized headline.

### 11. When Do You Train Question

**File:** `OnboardingView.swift:244-252`
**Copy strings (verbatim):**
```
Headline: "When do you\nwant to train?"
Subhead: "We'll send a reminder."
Options:
  "🌅  Morning — start strong"      (morning)
  "☀️  Afternoon — energy boost"    (afternoon)
  "🌙  Evening — wind down"          (evening)
  "🤷  Whenever I feel like it"     (whenever)
Feedbacks:
  morning:   "Morning sessions build the strongest habits"
  afternoon: "Great for a midday reset"
  evening:   "Perfect way to close out the day"
  whenever:  "Flexibility works too"
```
**State:** `plankTime` (string, not numeric — schema migration earlier renamed column type to text)

### 12. Form Education (Differentiation)

**File:** `OnboardingView.swift:968-1111`
**Purpose:** "We watch your form" positioning. Compare timer apps vs follow-along videos vs AI form-detection.
**Visual structure:** Headline split across three text elements → three comparison cards (Timer apps ❌, Follow-along videos ❌, **absmaxxing** ✅ with highlight) → tagline.
**Copy strings (verbatim):**
```
Headline (3 parts): "Other apps\ncount seconds." + "We watch your form." + (compare implied)
Card 1: "Timer apps" / "60s of bad form still counts as done" / ❌
Card 2: "Follow-along videos" / "Can't see if you're doing it wrong" / ❌
Card 3: "absmaxxing" / "AI corrects your form in real time" / ✅
Tagline: "20 seconds of perfect form\nbeats 60 seconds of bad form. Every time."
```
**State:** `formStep` (multi-step animation reveal, no user input)
**Brand-locked copy:** `"absmaxxing"` (line 1063, comparison card title)

### 13. Feature Showcase

**File:** `OnboardingView.swift:1966-2001`
**Copy strings (verbatim):**
```
Headline: "Why absmaxxing\nworks"
Features (4 rows):
  1. 🔥 "Daily routines, done for you" / "5-10 min ab sessions. We pick the workout, you show up."
  2. 📢 "A coach who talks to you" / "Voice coaching with personality. Not beeps."
  3. 📷 "AI-tracked plank benchmark" / "Camera watches your form weekly. Tracks real progress."
  4. 🧠 "Gets smarter over time" / "Your workouts adapt to your ratings and performance."
```
**Brand-locked copy:** `"Why absmaxxing\nworks"` (line 1970)

### 14. Social Proof (Marquee + Counter)

**File:** `OnboardingView.swift:1134-1220`
**Visual structure:** Live activity chip ("12 active right now") → animated counter (0→2847) → "people started this month" → "+247 this week" → marquee row (10 user cards rotating).
**Copy strings (verbatim):**
```
Chip: "12 active right now"
Counter label: "people started this month"
Momentum: "+247 this week"
Marquee cards: "Maya · D14", "Aaliyah · D22", ... (10 total, repeating)
```
**State:** `cardsVisible`, `marqueeOffset1`, `proofCount`
**Animations:** Counter springs in 0→2847 over 1s (25 frames, haptic at milestone). Marquee scrolls linearly forever (40s loop).

### 15. Testimonials

**File:** `OnboardingView.swift:1363-1434`
**Purpose:** Three reviews (barrier-responsive) with 5-star ratings.
**Copy strings (verbatim, dynamic by barriers):**
```
If "boring":
  "The trainer literally roasted me for dropping my hips 😂 I've never been so motivated to hold a plank" — Jasmine, Day 22
Else:
  "I had NO idea my form was wrong until this app showed me. Game changer for real" — Maya, Day 14

If "motivation":
  "I used to quit at 15 seconds. Now I'm at 45 and actually having fun??" — Aaliyah, Day 11
Else:
  "The voice feedback hits different. Like having a friend who's also a trainer" — Destiny, Day 19

If "time":
  "2 minutes a day. That's it. I do it while my coffee brews and I'm already seeing results" — Priya, Day 17
Else:
  "My posture is noticeably better and my back pain is basically gone. Wish I started sooner" — Kayla, Day 28
```

### 16. Before/After (4-Week Progress)

**File:** `OnboardingView.swift:2037-2104`
**Copy strings (verbatim):**
```
Headline: "What 5 minutes a day\nlooks like"
Cards (4):
  Week 1: "Building the habit" / "Show up daily" / 🔥
  Week 2: "Form starts clicking" / "Plank hold improves" / 📈
  Week 3: "Exercises feel easier" / "Harder workouts unlock" / ⚡
  Week 4: "Core feels different" / "You'll know" / ⭐
Tagline: "Consistency beats intensity.\nYou just have to show up."
```

### 17. Commitment Days Question

**File:** `OnboardingView.swift:259-266`
**Copy strings (verbatim):**
```
Headline: "How many days\na week?"
Subhead: "More days = faster results. We recommend 5."
Options:
  "3️⃣  3 days — easing in"     (3)
  "5️⃣  5 days — recommended"   (5)
  "7️⃣  Every day — all in"     (7)
Feedbacks:
  3: "Consistency beats intensity"
  5: "The sweet spot for results"
  7: "Every. Single. Day. Respect 🫡"
```
**Special considerations:** Continue → screen 25 (Session Length), NOT 18. Flow order non-monotonic.

### 25. Session Length Question

**File:** `OnboardingView.swift:268-275`
**Copy strings (verbatim):**
```
Headline: "How long per\nsession?"
Subhead: "Your coach will fill the time."
Options:
  "⚡  5 min — quick & focused"   (5)
  "🔥  7 min — recommended"        (7)
  "💪  10 min — full session"      (10)
Feedbacks:
  5:  "Perfect for busy days"
  7:  "The sweet spot"
  10: "Maximum results"
```
**Special considerations:** Sits between 17 and 18 in flow order.

### 18. Name Input

**File:** `OnboardingView.swift:1460-1507`
**Copy strings (verbatim):**
```
Headline: "What should your\ntrainer call you?"
Subhead: "First name is perfect."
Placeholder: "Your name"
Button: "Continue"
```
**State:** `name`, `nameFieldFocused: FocusState`
**Special considerations:** Only screen with text input. Auto-focus 400ms after appear. Submit label `.continue`.

### 19. Coach Selector

**File:** `OnboardingView.swift:1538-1702`
**Visual structure:** Headline → three trainer rows (photo 80×100 + name + vibe tag + quote + optional "Playing…" indicator) → dynamic CTA.
**Copy strings (verbatim):**
```
Headline: "Pick your coach"
Subhead: "They'll guide every workout. Tap to preview."
Coach rows:
  1. "Kira"   / "Sassy & Real"     / "\"My mama planks better than this\""    [photo: coach-kira,   audio: kira_preview]
  2. "Sarah"  / "Warm & Mindful"   / "\"You're doing beautifully, keep breathing\"" [photo: coach-sarah,  audio: sarah_preview]
  3. "Matson" / "Chill & Playful"  / "\"We're gonna have a good time\""        [photo: coach-matson, audio: matson_preview]
Button: "Train with [Name]"
Post-select feedback toasts:
  Kira:   "Get ready to be roasted 😏"
  Sarah:  "Your biggest fan is waiting 🤗"
  Matson: "Chill vibes activated 😎"
```
**State:** `voicePreference = "keepItReal"` default → maps to Kira; "encouraging" → Sarah; "balanced" → Matson. `playingPreview`, `previewPlayer: AVAudioPlayer`.
**Special considerations:** Audio files `.m4a` in bundle. Default Kira ("keepItReal").

### 20. Analyzing (Overlay)

**File:** `OnboardingView.swift:1708-1760`
**Purpose:** Loading state. Fake progress 3.5s.
**Copy strings (verbatim):**
```
Label: "Building your plan"
Checklist (animated checkmarks at thresholds):
  20%: "Analyzing your goals"
  40%: "Setting target hold times"
  60%: "Calibrating AI coach"
  80%: "Building 30-day program"
  98%: "Finalizing your plan"
```
**State:** `analyzing`, `analyzePercent`
**Animations:** Percentage updates with `.numericText()` transition (101 steps over 3.5s); haptic every 20%; on 100% confetti 2.5s + haptic success → `go(21)`.
**Brand-locked copy:** "Building 30-day program" (checklist item 4)

### 21. Plan Reveal

**File:** `OnboardingView.swift:1766-1843`
**Visual structure:** Coach photo (72×72 circle, accent border) → "You're all set, [name]." → "Built for [goal]." → "[Coach] has your first workout ready." → four plan cards (icon + title + detail).
**Copy strings (verbatim):**
```
Headline: "You're all set\(name.isEmpty ? "" : ", \(name)")."
Subhead: "Built for [goal]." (dynamic: "a stronger core" / "better posture" / "feeling more confident" / "getting toned")
Coach intro: "[Coach] has your first workout ready."
Cards:
  1. 🔥 "Daily Routines" / "5-10 min [goal label] sessions"
  2. 📢 "Voice Coaching" / "[Coach] guides every exercise"
  3. 📷 "Weekly Plank Check" / "AI tracks your form progress"
  4. Dynamic barrier card:
       dontKnow   → viewfinder "Form, locked in"
       injury     → shield "Safe progressions"
       boring     → shuffle "Never the same workout"
       motivation → calendar "Shows up every day"
       time       → bolt "Fits the busy days"
       default    → "Adaptive Workouts" / "Gets harder as you get stronger"
Button: "Let's go"
```

### 26. Sign-In Prompt (Onboarding Interstitial)

**File:** `OnboardingView.swift:283` (presents `SignInPromptView` from screen 26 case)
**Purpose:** Offer cloud sync before camera setup + paywall. If user signs in, skip to MainTabView.
**Copy strings:** See [SignInPromptView (auth section)](#signinpromptview).
**Special considerations:** If `AuthService.shared.isAnonymous == false` after sheet closes → set `hasCompletedOnboarding = true` and skip remaining onboarding (recovery flow).

### 22. Personal Stat (Plan Summary)

**File:** `OnboardingView.swift:2144-2218`
**Visual structure:** "YOUR PLAN" small-caps label → "Built for [name]" → six plan detail rows → adapt tags.
**Copy strings (verbatim):**
```
Label: "YOUR PLAN"
Headline: "Built for [name]"
Detail rows:
  🎯 Focus: [focusLabel]    ("Abs Definition" / "Waist Sculpting" / "Core Strength" / "Full Core")
  📊 Level: [difficultyLabel] (Beginner / Intermediate, computed)
  🕐 Sessions: [sessionMin] min
  📅 Frequency: [daysPerWeek] days/week
  🔥 Weekly total: [weeklyMinutes] min
  📢 Coach: [coachName]
Adapt tagline: "Your workouts adapt based on: session ratings, plank benchmarks, consistency"
Button: "Set up camera"
```
**Difficulty calculation:** if experience in {never, gaveUp} → Beginner; if activityLevel in {active, athlete} → Intermediate; if baseline in {30to60, over60} → Intermediate; else Beginner.

### 23. Camera Setup Instructions

**File:** `OnboardingView.swift:1890-1915`
**Copy strings (verbatim):**
```
Headline: "Set up your camera"
Subhead: "Prop your phone about 6 feet away\nso your coach can see you."
Instructions:
  👤 "Full body visible"
  💡 "Good lighting"
  📱 "Lean against wall or book"
Button: "Got it"
```

### 24. Paywall (legacy in OnboardingView; superseded by PaywallView Phase D)

**File:** `OnboardingView.swift:2270-2286`
**Purpose:** Legacy onboarding paywall. Currently still in code but RootView now presents `PaywallView` as fullScreenCover after `hasCompletedOnboarding` flips. **This screen may be dead code post-Phase D.**
**Copy strings (verbatim):**
```
Headline: "Start your 30-Day\nCore Reset free."
Pricing: "3 days free, then $29.99/year"
Checkmark label: "No payment due now"
Button: "Continue for FREE"
Footer: "Restore · Terms · Privacy" (text-only, no actions)
```
**Special considerations:** Hardcoded pricing. Footer links inert. Calls `finish()` → `onComplete(OnboardingData)` → `hasCompletedOnboarding = true`.
**Brand-locked copy:** "30-Day Core Reset" (line 2273)

### OnboardingData Struct (final payload)

**File:** `OnboardingView.swift:2359-2364`
**Fields:**
```
goal: String                       (strength / posture / confidence / toned)
experience: String                 (never / gaveUp / sometimes / regular)
baselineHoldSeconds: Int           (10 / 20 / 45 / 60, default 15)
barriers: [String]                 (boring / dontKnow / motivation / time / injury)
ageRange: String                   (under18 / 18to24 / 25to34 / 35to44 / 45to54 / 55plus)
activityLevel: String              (sedentary / light / moderate / active / athlete)
focusArea: String                  (abs / obliques / lowerBack / fullCore)
plankTime: String                  (morning / afternoon / evening / whenever)
commitmentDaysPerWeek: Int         (3 / 5 / 7, default 5)
sessionLengthMinutes: Int          (5 / 7 / 10, default 7)
notificationsEnabled: Bool         (defaults false; not asked in current flow)
notificationTime: Date?
name: String
voicePreference: String            (keepItReal / encouraging / balanced)
```

### Onboarding Components (Shared)

**File:** `PlankApp/Views/Onboarding/OnboardingComponents.swift`
**Helpers used across screens:** `questionView()`, `multiView()`, `trainerRow()`, `ctaBtn()`, `planCard()`, `planDetail()`, `featureRow()`, `progressCard()`, `GradientBlob`, `ConfettiView`, `AnimatedIcon`, `PhotoSlot`, `NotificationPermission`.

---

## 2. Auth

### SignInPromptView

**File:** `PlankApp/Views/Onboarding/SignInPromptView.swift:20-184`
**Purpose:** Soft sign-in prompt with dual-mode presentation (.signUp = mid-onboarding "Save your progress" nudge; .signIn = "Already have an account?" recovery).
**Entry points:** Welcome screen "Already have an account?" link (`.signIn`), onboarding screen 26 (default `.signUp`), AccountView "Sign In" button (default `.signUp`).
**Visual structure:** Brand-shape icon (80×80, person.crop.circle.badge.checkmark) → mode-aware headline → mode-aware subhead → SignInWithAppleButton → "Continue with Email" → "Cancel"/"Maybe later".
**Copy strings (verbatim):**
```
Headline (signIn): "Welcome back."
Headline (signUp): "Save your progress."
Subhead (signIn): "Sign in to recover your routine\non this device."
Subhead (signUp): "Sign in to keep your routine\nwhen you switch phones."
Apple button label: "Continue with Apple" (.continue mode for signIn) or "Sign up with Apple" (.signUp mode)
Email button: "Continue with Email"
Cancel/Maybe: "Cancel" (signIn) or "Maybe later" (signUp)
Apple error: "Couldn't sign in with Apple. Try email instead?"
```
**Components:** SignInWithAppleButton (.continue / .signUp), CTAButtonStyle, Palette tokens, Radius 12pt, Space.lg/sm/xs
**State:** `rawNonce`, `showEmailSheet`, `working`, `errorMessage`
**Actions:** Apple → handleAppleCompletion → onContinue. Email → presents SignUpView (initialMode mapped). Cancel → onContinue.
**Special considerations:** Apple HIG: `.continue` only for existing accounts; `.signUp` for new. Cancellation silent (ASAuthorizationError.canceled).
**Brand-locked copy:** None (brand handled in AuthBootstrapSplash).

### SignUpView

**File:** `PlankApp/Views/Onboarding/SignUpView.swift:27-565`
**Purpose:** Polished email/password auth, dual-mode (signUp + signIn) inline toggle.
**Entry points:** Presented from SignInPromptView's "Continue with Email".
**Visual structure:** Headline + subhead → SignInWithAppleButton → terracotta "OR" divider → email field (small-caps "EMAIL" label) → password field (small-caps "PASSWORD" label, show/hide eye) → conditional password requirements (signUp) → conditional "Forgot password?" link (signIn) → primary terracotta CTA → mode toggle → conditional legal text (signUp).
**Copy strings (verbatim):**
```
Headline (signUp): "Create your account."
Headline (signIn): "Welcome back."
Subhead (signUp): "Save your progress on every device."
Subhead (signIn): "Sign in to keep your routine going."
Field labels: "EMAIL", "PASSWORD" (small-caps, 11pt bold, tracking 2)
Email placeholder: "you@example.com"
Password placeholder (signUp): "8+ characters"
Password placeholder (signIn): "Your password"
Divider: "OR"
Password requirement rows: "8+ characters", "Mixed case", "Contains a digit"
Forgot password: "Forgot password?"
Primary button (working, signUp): "Creating account…"
Primary button (working, signIn): "Signing in…"
Primary button (idle, signUp): "Create account"
Primary button (idle, signIn): "Sign in"
Mode toggle (signUp): "Already have an account? Sign in"
Mode toggle (signIn): "New here? Create account"
Legal text (signUp, markdown): "By creating an account you agree to our [Terms](https://absmaxxing.com/terms) and [Privacy Policy](https://absmaxxing.com/privacy)."
Email format error: "That doesn't look like a valid email"
Apple error: "Couldn't sign in with Apple. Try email instead?"

friendlyError(from:mode:) variants (lowercased substring matching):
  "already registered" / "already in use":
    → "Looks like you have an account. Try signing in instead."
  "invalid login" / "invalid credentials":
    → "That email and password don't match. Try again or reset your password."
  "network" / "connection" / "offline":
    → "Couldn't connect. Check your internet and try again."
  "password" + "weak":
    → "Add an uppercase letter and a number."
  Generic (signUp fallback): "Couldn't create account. Try again in a moment."
  Generic (signIn fallback): "Couldn't sign in. Try again in a moment."
```
**Components:** SignInWithAppleButton (.signUp / .signIn), CTAButtonStyle, ShakeEffect (4px, 3 cycles, 200ms via animatable CGFloat → sine wave), PulsingDots (8×8, 0.3↔1.0 opacity, 600ms easeInOut, 200ms stagger), SafariView (SFSafariViewController wrapper), Palette tokens, Typo.title/body/caption, Radius.md, Space.lg/md/xl
**State:** `mode`, `email`, `emailFormatError`, `password`, `showPassword`, `rawNonce`, `working`, `errorMessage`, `shakeTrigger: CGFloat`, `legalDoc: LegalDoc?`, `showForgotPassword`, `focused: FocusState<Field?>`, `dismiss`
**Actions:** Apple → completeAppleSignIn → onSuccess. Email submit → AuthService.signUpWithEmail or signInWithEmail. Mode toggle → withAnimation .easeOut(0.2). Forgot Password → presents ForgotPasswordView sheet (prefilled email). Legal links → openURL handler routes to SafariView.
**Animations:** Field focus border `divider`→`textPrimary` over 0.15s easeOut; password requirements `.opacity.combined(with: .move(edge: .top))` on toggle; forgotPassword/legalText `.opacity` on toggle; mode toggle .easeOut 0.2s; primary disable 0.15s; shake .linear 0.2s.
**Special considerations:** Email regex `^[^@\s]+@[^@\s]+\.[^@\s]+$`. Password (signUp) requires ≥8 chars + lowercase + uppercase + digit. Form shake on Apple/email/API errors.
**Brand-locked copy:** Legal URLs `https://absmaxxing.com/terms` and `/privacy` (lines 57, 58, 407).

### ForgotPasswordView

**File:** `PlankApp/Views/Onboarding/ForgotPasswordView.swift:19-271`
**Purpose:** Password reset. Anti-enumeration messaging (vague success).
**Entry points:** Presented from SignUpView (signIn mode) "Forgot password?" link, sheet [.medium, .large] detents.
**Visual structure:** Four phases — `.input` / `.sending` / `.confirmed` / `.failed(String)`.
**Copy strings (verbatim):**
```
Headline (input/sending/failed): "Reset your password."
Subhead: "Enter the email you used. We'll send a reset link."
Email label: "EMAIL"
Email placeholder: "you@example.com"
Send button: "Send reset link"
Cancel button: "Cancel"
Email format error: "That doesn't look like a valid email"
API error (.failed): "Couldn't send reset link. Check your internet and try again."
Success headline (.confirmed): "Check your email."
Success subhead: "If an account exists with that email, you'll get a reset link in a few minutes. It expires in 1 hour."
Success button: "Done"
```
**Components:** CTAButtonStyle, PulsingDots, Palette tokens, Typo.title/body/caption
**State:** `email`, `phase`, `validationError`, `emailFocused: FocusState`
**Special considerations:** Initial email prefilled from SignUpView. Auto-focus deferred 400ms after appear (so sheet slide animation finishes). Success copy intentionally vague (anti-enumeration). 1h expiry mentioned.

### AuthBootstrapSplash

**File:** `PlankApp/Auth/AuthBootstrapSplash.swift:6-88`
**Purpose:** Loading splash during AuthService.bootstrap. Returning users see for 1-2 frames; fresh installs see for anonymous sign-in roundtrip.
**Entry points:** App launch before main content.
**Visual structure:** "absmaxxing" wordmark (42pt black) → animated underline (0→120pt) → BootstrapState content (idle/running = three pulsing dots; ready = EmptyView; failed = "Couldn't connect" + message + "Try again" button).
**Copy strings (verbatim):**
```
Brand wordmark: "absmaxxing"
Error headline (.failed): "Couldn't connect"
Error message (.failed): (parameterized — "Make sure you're connected to the internet, then try again.")
Error button: "Try again"
```
**State:** `pulse`, `lineVisible`
**Animations:** Line .easeOut(0.6).delay(0.1); dots .easeInOut(0.5).repeatForever().staggered(0.15s × index).
**Brand-locked copy:** **CRITICAL: `"absmaxxing"` (line 20)** — hard-coded brand name in splash, must change to "JeniFit".

### AccountView

**File:** `PlankApp/Views/Settings/AccountView.swift:4-390`
**Purpose:** Settings → Account section. Mode-aware (anonymous vs signed-in). Exposes Sign In / Sign Out / Delete Account / Restore Purchases / Reset Onboarding.
**Entry points:** Settings sheet → Account row.
**Visual structure:** "Account" headline → app info card (Version, Build) → conditional auth section (anonymous: "SAVE YOUR PROGRESS" + Sign In + Restore; signed-in: "ACCOUNT" + email/Apple display + Sign Out + Restore + Delete) → "Reset Onboarding" button (red).
**Copy strings (verbatim):**
```
Screen headline: "Account"
Version label: "Version"
Build label: "Build"

Anonymous section:
  Header: "SAVE YOUR PROGRESS"
  Status: "Not signed in"
  Subtext: "Sign in to back up your routine"
  Button: "Sign In"

Restore Purchases (both modes):
  Button: "Restore Purchases"
  Success: "Subscriptions restored"
  Nothing-to-restore: "No active subscription found. If you think this is wrong, contact support."
  Error: "Couldn't restore. Check your internet and try again."

Signed-in section:
  Header: "ACCOUNT"
  Status (if email): user's email (truncated middle)
  Status (if no email): "Apple ID user"
  Provider labels:
    .apple:     "Signed in with Apple"
    .email:     "Signed in with email"
    .anonymous: "Anonymous"
    .unknown:   "Signed in"
  Sign Out button: "Sign Out" (idle) or "Signing out…" (working)

Delete Account button: "Delete Account"
Reset Onboarding button: "Reset Onboarding"

Reset confirmation alert:
  Title: "Reset onboarding?"
  Body: "This will take you back to the intro screens. Your workout data stays."
  Buttons: "Reset" (destructive) / "Cancel"

Sign Out confirmation alert:
  Title: "Sign out?"
  Body: "Your local data stays on this device. Sign in again to sync to the cloud."
  Buttons: "Sign Out" (destructive) / "Cancel"

Delete Account error fallback (passed to DeleteAccountSheet):
  "Couldn't delete account. Try again or contact support@absmaxxing.com."
```
**State:** `auth`, `showResetConfirm`, `showSignInSheet`, `showSignOutConfirm`, `signingOut`, `showDeleteAccountSheet`, `restoring`, `restoreFeedback: RestoreFeedback?`, `hasCompletedOnboarding @AppStorage`, `dismiss`
**Actions:** Sign Out → `AuthService.signOut()` → dismiss. Restore → `PaymentService.restorePurchases()` → 2s auto-clear feedback (race-safe via captured value comparison). Delete Account → DeleteAccountSheet. Reset Onboarding → flips `hasCompletedOnboarding = false`.
**Special considerations:** Restore button visible in BOTH anonymous and signed-in (works either way). Delete Account only signed-in. Sign Out alert uses destructive role. Sign Out failure is silent (no UI, user retries).
**Brand-locked copy:** `support@absmaxxing.com` in delete error fallback (line 260).

### DeleteAccountSheet

**File:** `PlankApp/Views/Settings/DeleteAccountSheet.swift:16-175`
**Purpose:** Permanent account deletion confirmation. Apple App Store Guideline 5.1.1(v) compliance.
**Entry points:** Presented from AccountView "Delete Account" button (signed-in only). Sheet [.medium, .large] detents with drag indicator.
**Visual structure:** Four phases — `.confirm` / `.deleting` / `.succeeded` / `.failed(String)`. Confirm: headline + body + stacked Delete/Cancel buttons. Succeeded: checkmark + "Account deleted" auto-dismiss after 1.2s.
**Copy strings (verbatim):**
```
Headline (confirm): "Delete your account?"
Body (confirm): "This permanently deletes your routine history, progress, and account. If you have an active subscription, cancel it from your iOS Settings before continuing — deletion does not cancel App Store subscriptions."
Delete button: "Delete account"
Cancel button: "Cancel"
Success headline (.succeeded): "Account deleted"
Failed inline (red text): (passed via onConfirm closure)
```
**Components:** CTAButtonStyle, PulsingDots, Palette.stateBad (delete bg), Palette.stateGood (success checkmark)
**State:** `phase: Phase` (.confirm/.deleting/.succeeded/.failed)
**Special considerations:** onConfirm async closure returns String? (nil = success, message = failure). Auto-dismiss 1.2s after .succeeded.

---

## 3. Home / Analytics / Tabs

### MainTabView (custom pill tab bar)

**File:** `PlankApp/Views/Root/MainTabView.swift:24-28`
**Purpose:** Two-tab pill nav (workout / log). ZStack layering with opacity + hitTesting (lazy AnalyticsView mount).
**Visual structure:** Capsule container (bgElevated + plankShadow), two HStack tab buttons.
**Copy strings (verbatim):**
```
Tab 1: "workout"
Tab 2: "log"
```
**State:** `selectedTab` (default `.workout`), `hasOpenedLog` (lazy gate)
**Actions:** Tab tap → withAnimation .easeInOut(0.2) swap; first "log" tap sets `hasOpenedLog = true` (mount AnalyticsView).
**Special considerations:** AnalyticsView only mounted on first .log tap (memory optimization). Tab button text weight shifts medium ↔ semibold; capsule transparent ↔ bgInverse on selection.

### HomeView — Top Message Bar (menu + trainer)

**File:** `PlankApp/Views/Home/HomeView.swift:210-248`
**Visual structure:** Ellipsis menu (left) → Spacer → trainer photo+name button (center-right) → Spacer.
**Copy strings (verbatim):**
```
Menu items:
  "Edit Profile"
  "Notifications"
  "Account"
  "Feedback"
  [DEBUG] "Debug Auth"
Trainer name (per voicePreference):
  encouraging → "Sarah"   [photo: coach-sarah]
  balanced    → "Matson"  [photo: coach-matson]
  default     → "Kira"    [photo: coach-kira]
```
**State:** `voicePreference @AppStorage`, `activeSheet: SettingsSheet?`
**Actions:** Menu items set activeSheet to corresponding case. Trainer button → activeSheet = .trainer.

### HomeView — Date Stamp

**File:** `HomeView.swift:252-257`
**Visual structure:** Centered Date.now formatted as "Monday 9:30 AM".
**Copy:** Dynamic, no static string.

### HomeView — Kira Greeting Bubble (4 voice variants)

**File:** `HomeView.swift:131-132, 261-281`
**Purpose:** Coach-voiced greeting with personalization (name + time + affirmation).
**Visual structure:** Avatar (28×28) + rounded rect bubble (bgElevated + plankShadow).
**Copy strings (verbatim) — by voice:**

```
ENCOURAGING (Sarah):
  Day 0: "Hi [name]. I'm Sarah. I put together a gentle workout for you. Let's start slow."
  Returning (todayHasSession):
         "Coming back for more[name]? I love that energy."
  Default: "[timeGreeting] [affirmation]"
    Affirmations (by currentDay % 4):
      "Every session is a gift to your body."
      "You're building something beautiful, one day at a time."
      "Your consistency speaks louder than any workout."
      "Day [currentDay]. You keep showing up. That's powerful."

BALANCED (Matson):
  Day 0: "Yo[name]. I'm Matson. I got a workout lined up for you. It's gonna be good."
  Returning: "Back again[name]? You're an animal."
  Default + affirmations:
    "You're showing up and that's the hardest part."
    "Looking stronger every day, not gonna lie."
    "Your core's getting dialed in."
    "Day [currentDay]. Still in the game. Respect."

DEFAULT (Kira):
  Day 0: "Hey[name]. I'm Kira, your coach. I made your first workout. You ready?"
  Returning: "Back for seconds[name]? I respect that."
  Default + affirmations:
    "You showed up. That's the whole game."
    "Consistency looks good on you."
    "Your core is getting stronger whether you feel it or not."
    "Day [currentDay]. Still here. That says something."

Time greetings (all voices):
  hour < 12:    "Good morning" / "Morning" / "Morning"
  12 ≤ h < 17:  "Hi" / "What's good" / "Hey"
  hour ≥ 17:    "Good evening" / "Evening" / "Evening"
```
**State:** `userName @AppStorage`, `voicePreference @AppStorage`, `currentDay` (computed), `todayHasSession` (computed)
**Animations:** msgOpacity[0] + msgOffset[0] animated in via animateIn() with 0.0s delay, spring(0.6, 0.85), Haptics.soft().

### HomeView — Routine Workout Card

**File:** `HomeView.swift:285-393`
**Visual structure:** Avatar + VStack (intro text + duration/exercise count labels + numbered exercise list (visible 2 unless expanded) + START button).
**Copy strings (verbatim) — by voice:**
```
ENCOURAGING:
  Day 0: "I chose something gentle for your first time. [workout.name]."
  Day 1+: "I have a lovely plan for today. [workout.name]."
BALANCED:
  Day 0: "First workout, let's keep it chill. [workout.name]."
  Day 1+: "Got something solid for you. [workout.name]."
DEFAULT:
  Day 0: "Here's your first one. [workout.name]."
  Day 1+: "Today's plan. [workout.name]."

Counters:
  "[count] exercises" (flame.fill icon)
  "[estimatedDuration] min" (clock icon)

Exercise rows: numbered "1, 2, 3..." + name + "[duration]s"
Expand toggle: "+[N] more" / "show less"
START button: "START"
```
**State:** `showAllExercises`, `currentWorkout: WorkoutPreset?`, `payment: PaymentService` (entitlement gate)
**Actions:** START → `guard payment.hasProAccess` → `Haptics.vibrate(); currentWorkout = workout; showRoutineSession = true` (fullScreenCover RoutineSessionView).
**Special considerations:** Pro-gated. WorkoutGenerator picks preset from pool by `routineCount % pool.count`. Difficulty considers experience + baseline + activity + ageRange.

### HomeView — Plank Benchmark Card

**File:** `HomeView.swift:397-454`
**Visual structure:** Avatar + intro text + (if lastBenchmark) two stat columns (last hold + days ago) + outlined "LET'S GO" button.
**Copy strings (verbatim) — by voice + state:**
```
ENCOURAGING:
  Never:  "Let's do your first plank together. I'll watch your form and guide you."
  Due:    "Time for your plank check-in. I'll guide you through it."
  Recent: "Last plank was [Int(holdTime)]s. Let's see how you've grown."
BALANCED:
  Never:  "Plank check. I'll watch your form, you hold. Easy."
  Due:    "Plank time. I'll watch your form, you just hold."
  Recent: "[Int(holdTime)]s last time. Think you can top it?"
DEFAULT:
  Never:  "Plank check. I watch your form, you hold. Ready?"
  Due:    "Plank check-in. I'll coach your form live."
  Recent: "Last plank: [Int(holdTime)]s. Beat it?"

Stats:
  "[holdTime]s" / "last hold"
  "[days]d" / "ago"

Button: "LET'S GO"
```
**State:** `lastBenchmark` (computed), `daysSinceLastBenchmark`, `benchmarkDue` (≥ 7 days or never).
**Actions:** LET'S GO → `guard payment.hasProAccess` → `showPreSession = true`.

### HomeView — Stats Bubble (post-first-session)

**File:** `HomeView.swift:140-143, 533-546`
**Conditional:** Only renders if `hasCompletedFirstSession == true`.
**Copy strings (verbatim) — by voice + streak:**
```
ENCOURAGING:
  ≥7: "[streak] days in a row. [count] sessions. You inspire me. ✨"
  <7: "[count] workouts complete. Every one matters."
BALANCED:
  ≥7: "[streak] day streak. [count] sessions. You're on fire. 🔥"
  <7: "[count] workouts in the bag. Keep stacking."
DEFAULT:
  ≥7: "[streak] day streak. [count] sessions. Locked in. 🔥"
  <7: "[count] workouts done. Keep showing up."
```
**State:** `hasCompletedFirstSession @AppStorage`, computed `streakCount`, `sessionLogs` (user-scoped).

### AnalyticsView — Header

**File:** `PlankApp/Views/Analytics/AnalyticsView.swift:157-169`
**Copy strings (verbatim):**
```
Title: "Log"
Subtitle: "[userName]'s progress" or "Your progress" (ternary)
```

### AnalyticsView — Empty State

**File:** `AnalyticsView.swift:173-189`
**Copy strings (verbatim):**
```
Icon: figure.core.training (48pt, divider color)
Heading: "No sessions yet"
Body: "Complete your first workout\nand it'll show up here."
```

### AnalyticsView — Hero Stats (3 cards)

**File:** `AnalyticsView.swift:193-236`
**Visual structure:** 3-card HStack (streak + workouts + minutes).
**Copy strings (verbatim):**
```
Streak: "[count]" + "day streak" (or "streak" if frozenDates non-empty)
Workouts: "[routineCount]" + "workouts"
Minutes: "[totalMinutes]" + "min total"
Icons: flame.fill (accent), checkmark.circle.fill, clock.fill
```
**State:** `streakPulse` (auto-pulse 0.6s after load).

### AnalyticsView — Activity Calendar (28-day grid)

**File:** `AnalyticsView.swift:240-321`
**Copy strings (verbatim):**
```
Title: "Activity"
Day labels: "M", "T", "W", "T", "F", "S", "S"
Legend: "active", "frozen"
```
**Cell colors:** future = clear; active = `Palette.accent`; frozen = `Color(hex: "#D6EBF5")` (light blue, **non-token literal**); inactive = `Palette.divider.opacity(0.4)`; today = stroke outline accent.

### AnalyticsView — Plank Progress Card

**File:** `AnalyticsView.swift:325-374`
**Conditional:** Renders only if `benchmarkCount > 0`.
**Copy strings (verbatim):**
```
Title: "Plank Progress"
Right header: "[count] tests"
Three stats:
  "latest (s)" / formatted holdTime
  "best (s)"   / formatted max holdTime  (highlighted Palette.accent)
  "avg rating" / formatted average or "--"
```

### AnalyticsView — Recent Sessions

**File:** `AnalyticsView.swift:378-444`
**Visual structure:** Section headers + session rows (icon circle + type label + timestamp + duration/hold).
**Copy strings (verbatim):**
```
Section headers: "This Week", "Earlier"
Session type labels:
  routine:   "Core Routine"
  benchmark: "Plank Benchmark"
Timestamp format: "Wed, Jan 9:30 AM" (.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
Duration: "[m]m [s]s" or "[s]s" (if <60s) or "--"
Plank hold: "[s]s"
```
**Special considerations:** thisWeekSessions = <7 days; earlierSessions = ≥7 days, capped at 12.

### Session Sheet Routing

**File:** `HomeView.swift:165-187`
**Sheets:**
- `showPreSession` → fullScreenCover PreSessionView (exerciseType="Plank Benchmark", dayNumber=currentDay)
- `showSession` → fullScreenCover SessionView (targetTime=60)
- `showPlankPostSession` → fullScreenCover PostSessionView
- `showRoutineSession` → fullScreenCover RoutineSessionView (workout: WorkoutPreset)
- `activeSheet: SettingsSheet?` → SettingsView (presentationDetents [.large])

---

## 4. Session / Routine

### PreSessionView (form briefing + camera permission)

**File:** `PlankApp/Views/Session/PreSessionView.swift:1-215`
**Purpose:** Gate before camera session. Phone placement instructions + camera permission flow.
**Visual structure:** Top: "Day X" label + dismiss. Middle: 3 instructional cards + lock-warning tip. Bottom: "Start Session" CTA.
**Copy strings (verbatim):**
```
Top label: "Day [dayNumber]"
Card 1: "Prop your phone up" / "About 6 feet away, leaned against something.\nMake sure I can see your whole body."
Card 2: "Get into plank" / "Forearms on the floor, elbows under shoulders.\nBody straight from head to heels. Core tight."
Card 3: "We'll handle the rest" / "Your coach watches your form\nand talks you through it."
Lock warning: "Keep your phone unlocked during sessions. Locking or switching apps will pause your workout."
Camera permission (notDetermined):
  Headline: "Your AI Coach\nNeeds to See You"
  Description: "So your coach can see your form\nand roast you properly."
  CTA: "Enable Camera"
Camera blocked (denied):
  Headline: "Camera Access\nis Turned Off"
  Description: "plankAI needs camera access to track your form.\nOpen Settings to enable it."
  CTA: "Open Settings"
Start button: "Start Session"
```
**State:** `cameraStatus: AVAuthorizationStatus`, `currentStep`
**Brand-locked copy:** `"plankAI"` (line 188) — legacy brand name, must update. "roast you properly" — voice/tone reference.

### SessionView (active plank with form feedback)

**File:** `PlankApp/Views/Session/SessionView.swift:1-592`
**Purpose:** Camera-driven plank hold with real-time pose feedback.
**Visual structure (5 layers):** Camera feed → PoseOverlay (color-coded skeleton) → rotating angular gradient border (6s loop) → goodForm green glow OR emergency red blink → UI (Day label + dismiss + center timer + form fault label + bottom controls).
**Copy strings (verbatim):**
```
Top label: "Day [dayNumber]"
Form fault labels:
  hipSag:         "HIPS"
  hipPike:        "HIPS DOWN"
  shoulderCreep:  "SHOULDERS"
  notInPosition:  "GET BACK DOWN"
Timer format: "[total]s"
Pause overlay:
  Header: "SESSION PAUSED"
  Subtitle: "Plank Hold"
  Status: "[m]m [s]s elapsed"
  Resume button: "RESUME"
  End button: "END SESSION"
End session confirmation alert:
  Title: "End Session?"
  Buttons: "End" (destructive) / "Keep Going"
```
**State:** `currentState: FormState` (goodForm, hipSag, hipPike, shoulderCreep, notInPosition, cameraBad, shaking), `sessionActive`, `sessionEnded`, `elapsedTime`, `audioMuted`, `showGuideFrame`, `pausedByBackground`, `borderRotation`, `emergencyBlink`
**Animations:** Border rotates 360° / 6s linear loop; border color/thickness easeInOut 0.3s on state change; timer .numericText() easeInOut 0.3s; form fault label opacity + scale(0.8); emergency blink easeInOut 0.35s repeatForever; good form glow opacity transition.
**Special considerations:** Audio-led design (PlankVoice import). Pose colors: green = good, neon = critical, amber = fault. `OrientationManager.shared.allowedOrientations = .all` during session, reset to .portrait on exit. Background pause auto-engages.

### RoutineSessionView (multi-exercise timed)

**File:** `PlankApp/Views/Routine/RoutineSessionView.swift:1-374`
**Purpose:** Multi-exercise routine with preview→active→rest→done state machine. No camera.
**Visual structure:** Linear gradient bg (bgPrimary → accent) → progress bar + "X of Y" + dismiss → phase label + exercise name + target area + animated icon placeholder → big timer (80pt) + total elapsed + Next preview → bottom Pause/Skip controls.
**Copy strings (verbatim):**
```
Progress label: "[index+1] of [count]"
Phase labels:
  preview: "NEXT UP"
  active:  "GO"
  rest:    "REST"
  done:    "DONE"
Exercise target area: "[targetArea].uppercased()" (e.g., "FRONT CORE")
Exercise type: "HOLD" or "MOVE"
Timer: "[timeRemaining]"
Total elapsed: "[m]:[ss]"
Next preview: "Next: [exercise.name]"
Pause overlay:
  Header: "SESSION PAUSED"
  Status: "[s]s remaining"
  Resume: "RESUME"
  End: "END SESSION"
End workout alert: "End Workout?" / "End" (destructive) / "Keep Going"
Skip button: "Skip" (with forward.fill)
```
**State (via RoutineSessionViewModel):** `phase`, `timeRemaining`, `totalElapsed`, `isPaused`, `isActive`, `currentExerciseIndex`, `exerciseCount`, `progress`, `pausedByBackground`, `showEndConfirm`, `showPostRoutine`
**Animations:** Background gradient easeInOut 0.3s on phase change; exercise name .numericText() 0.3s; timer .numericText() + easeInOut 0.15s.
**Special considerations:** No camera, audio-led via RoutineAudioManager.

### PostSessionView (single exercise celebration)

**File:** `PlankApp/Views/PostSession/PostSessionView.swift:1-191`
**Purpose:** Plank session results — emoji + headline + score breakdown + streak + best roast quote + share.
**Copy strings (verbatim):**
```
Score ≥ 7.0: emoji "🔥" / Headline "Crushed it." / Summary "Your form was solid. Your core felt that."
Score 4.0–6.9: emoji "😤" / Headline "Survived." / Summary "Your hips dropped a few times but you held it. Barely."
Score < 4.0: emoji "😅" / Headline "It happened." / Summary "We're not gonna talk about it. Tomorrow's a new day."
Score card labels: "FORM", "TIME"
Stats labels: "HOLD TIME", "STREAK"
Day progress: "Day [dayNumber] of 30 complete"
Best roast block: "BEST ROAST" + "\"[bestRoast]\""
Buttons: "SHARE", "DONE"
```
**State:** `showStats`, `showShareSheet`, `formScore`, `timeScore`
**Brand-locked copy:** "Day [N] of 30 complete" — implies fixed 30-day program.

### PostRoutineView (multi-exercise celebration)

**File:** `PlankApp/Views/Routine/PostRoutineView.swift:1-470`
**Purpose:** Multi-phase celebration (fire emoji → stats → streak → rating → tags → done) for completed routines.
**Copy strings (verbatim):**
```
Completion ≥ 90%: emoji "🔥" / Headline "You ate that."
Completion 60–89%: emoji "💪" / Headline "Good work."
Completion < 60%: emoji "👏" / Headline "You showed up."
Workout name display: "[workoutName].uppercased()"
Stats pill labels: "TIME", "DONE"
Stat values: formatDuration(totalDuration), "[completedCount]/[total]"
Streak header: "[streakCount] DAY STREAK"
Streak messages (by streakCount):
  Day 1:    "First day. This is how it starts."
  Days 2–3: "Building the habit."
  Days 4–6: "Consistency hits different."
  Day 7:    "One full week. Respect."
  Days 8–13: "You're locked in."
  Day 14:   "Two weeks. This is you now."
  Days 15–29: "Can't stop won't stop."
  Day 30+:  "Built different."
Rating header: "HOW WAS THAT?"
Tag labels:
  too_easy:     "Too Easy"
  too_hard:     "Too Hard"
  loved_it:     "Loved It"
  boring:       "Boring"
  good_variety: "Good Variety"
Done button: "DONE"
```
**State:** `phase` (0–4), `selectedRating`, `selectedTags: Set<String>`, `fireScale`, `fireOpacity`, `streakScale`, `particles: [ConfettiParticle]`
**Animations:** Phase transitions spring + opacity + move; confetti 40 particles with gravity + ±80px drift, 2.5s fall.

### RoastCardView (9:16 share card)

**File:** `PlankApp/Views/Share/RoastCardView.swift:1-82`
**Purpose:** Static 1080×1920 card for TikTok/IG Stories share.
**Visual structure:** Quote section (large opening quote mark + roast text + "— Your Plank Coach, Day X") → bottom stats bar (hold time + exercise) → watermark.
**Copy strings (verbatim):**
```
Quote mark: "\""
Roast text: [roastText param]
Attribution: "— Your Plank Coach, Day [dayNumber]"
Stat labels: "hold time", "exercise"
Watermark: "plankAI"
```
**Brand-locked copy:** `"plankAI"` watermark (line 66) — legacy brand name. "Your Plank Coach" attribution.

### RoutineSessionViewModel (state machine)

**File:** `PlankApp/Views/Routine/RoutineSessionViewModel.swift:1-262`
**State machine:** `preview(idx) -[4s countdown]→ active(idx) -[N seconds]→ rest(idx) -[rest dur]→ preview(idx+1) ... → done`
**Voice clip triggers (audio-led design):**
- onExercisePreview(exerciseId) → `intro_<exerciseId>.m4a`
- onExerciseStart() → `exercise_countdown.m4a`
- onExerciseAlmost() → `exercise_almost.m4a`
- onActiveTick() → random encourage/roast/hold/tempo (3s cooldown, ~12s cadence)
- onExerciseDone() → `exercise_done.m4a`
- onRest() → random `rest_1`–`rest_4`
- onSkip() → random `skip_1`–`skip_2`
- onSessionDone() → random `routine_done_1`–`routine_done_5`

### RoutineAudioManager

**File:** `PlankApp/Views/Routine/RoutineAudioManager.swift:1-127`
**Trainer prefix system:**
- `"keepItReal"` (default) → Kira (no prefix), has roasts
- `"encouraging"` → Sarah (`sarah_` prefix), NO roasts
- `"balanced"` → Matson (`matson_` prefix), has roasts

Cooldown: 3s between clips unless `force=true`. onActiveTick: ~20% encouragement, ~10% roast (if hasRoasts), else hold (static) or tempo (dynamic) cues.

---

## 5. Settings sub-pages

### SettingsView (router)

**File:** `PlankApp/Views/Settings/SettingsView.swift:1-51`
**Purpose:** Routes SettingsSheet enum to sub-page. Toolbar X dismiss.
**SettingsSheet enum cases:** `.editProfile`, `.trainer`, `.notifications`, `.account`, `.feedback`, `.debugAuth` (DEBUG-only).
**Copy:** No user-facing strings.

### EditProfileView

**File:** `PlankApp/Views/Settings/EditProfileView.swift:1-139`
**Copy strings (verbatim):**
```
Heading: "Edit Profile"
Section labels: "NAME", "FOCUS AREA", "SESSION LENGTH"
TextField placeholder: "Your name"
Goal options:
  "Abs Definition" (definition)
  "Waist Sculpting" (sculpting)
  "Core Strength" (strength)
  "Full Core" (fullCore)
Session length options: "5 min", "7 min", "10 min"
Save button: "Save Changes" / "Saved"
```
**State:** `userName @AppStorage`, `userGoal @AppStorage`, `sessionLengthPref @AppStorage`, `editName`, `saved`

### ChangeTrainerView

**File:** `PlankApp/Views/Settings/ChangeTrainerView.swift:1-308`
**Copy strings (verbatim):**
```
Heading: "Your Coach"
Helper: "Tap to preview their voice."
Trainer cards:
  Kira:   "Sassy & Real"     / "\"My mama planks better than this\""        [coach-kira / kira_preview]
  Sarah:  "Warm & Supportive" / "\"You're doing amazing, keep breathing\""   [coach-sarah / sarah_preview]
  Matson: "Chill & Playful"  / "\"Come on, we're gonna have a good time\""  [coach-matson / matson_preview]
Current badge: "current"
Switch button: "Switch to [name]"
Loading words (10, randomly cycled):
  "Warming up vocal cords"
  "Stretching personality"
  "Loading attitude"
  "Calibrating sass levels"
  "Flexing voice muscles"
  "Syncing vibes"
  "Tuning motivation frequency"
  "Brewing coaching energy"
  "Downloading tough love"
  "Activating gym mode"
Loading dots: ". → .. → ..."
```
**State:** `voicePreference @AppStorage` ("keepItReal" default), `selectedId`, `playingId`, `previewPlayer: AVAudioPlayer`, `isLoading`, `loadingWord`, `loadingDots`, `hasAnimated`
**Special considerations:** ONLY iOS default `ProgressView` spinner in entire codebase (line 139). 2.4s loading cycle on switch. Custom `TrainerButtonStyle` (0.97 scale on press).

### NotificationSettingsView

**File:** `PlankApp/Views/Settings/NotificationSettingsView.swift:1-143`
**Copy strings (verbatim):**
```
Heading: "Notifications"
Toggle label: "Daily Reminder"
Toggle helper: "Get reminded to work out"
Section label (if enabled): "REMINDER TIME"
Save button: "Save Time" / "Saved"
Notification title (push): "Time to work"
Notification body (push): "Your workout is ready. Don't make Kira wait."
Permission warning banner: "Notifications are off in Settings. Go to Settings > absmaxxing > Notifications to enable."
```
**State:** `notificationsEnabled @AppStorage` (default false), `notificationHour @AppStorage` (default 7), `notificationMinute @AppStorage` (default 0), `pickerTime`, `permissionGranted`, `saved`
**Brand-locked copy:** `"absmaxxing"` in warning text (line 84). "Kira" hardcoded in notification body (line 120).

### FeedbackView

**File:** `PlankApp/Views/Settings/FeedbackView.swift:1-69`
**Copy strings (verbatim):**
```
Heading: "Feedback"
Prompt: "What's working? What's broken? What do you wish existed? We read everything."
Send button: "SEND"
Success heading: "Sent. Thank you."
```
**Special considerations:** TODO at line 45 — backend integration not implemented yet.

### DebugAuthView (DEBUG-only, pending removal)

**File:** `PlankApp/Views/Settings/DebugAuthView.swift:1-162`
**Wrapped in `#if DEBUG ... #endif`.** Will be deleted pre-TestFlight.
**Copy strings (verbatim):**
```
Heading: "Debug · Auth"
Section labels: "CURRENT STATE", "CREDENTIALS"
State row labels: "user_id", "isAnonymous", "authMethod", "email"
Field placeholders: "email", "password"
Action buttons:
  "Sign up with email (upgrade anon)"
  "Sign in with email"
  "Sign in with Apple"
  "Send password reset"
Status: monospaced text ("running…", "signed up · user_id [UUID]", "error: [message]")
```

---

## 6. Paywall

### PaywallView

**File:** `PlankApp/Views/Paywall/PaywallView.swift:1-503`
**Purpose:** Post-onboarding paywall with RevenueCat integration. Personalized headline by `@AppStorage("focusArea")`.
**Entry points:**
- Onboarding completion gate (RootView fullScreenCover, `dismissable: false` — no X button)
- Future Phase G entitlement re-gate (`dismissable: true`)
**Visual structure:** Conditional close button → headline → benefits section → pricing cards → trust microcopy → CTA → restore link → auto-renewal disclosure → Terms/Privacy footer.
**Copy strings (verbatim):**

```
Personalized headlines (focusArea-driven):
  "abs":       "Define your abs in 30 days."
  "obliques":  "Sculpt your waistline in 30 days."
  "lowerBack": "Build your core foundation in 30 days."
  default:     "Start your 30-day Core Reset."

Benefit rows:
  1. "AI form coaching" / "Real-time feedback on every plank, every second."
  2. "5-minute daily routines" / "No gym, no equipment, no excuses."
  3. "Reminder before billing" / "We'll let you know 24 hours ahead. Cancel with one tap."

Yearly card:
  Badge: "3-DAY FREE TRIAL"   (10pt bold, tracking 1.5, accent bg, capsule)
  Price: "[localizedPrice]/year"   (placeholder "$29.99/year")
  Per-week: "Just [perWeek]/week · save [N]%"   (placeholder "Just $0.58/week · save 88%")

Weekly card:
  Price: "[localizedPrice]/week"   (placeholder "$4.99/week")

Trust microcopy: "Cancel anytime in iOS Settings"   (with checkmark icon)

CTA copy:
  yearly: "Start your 3-day free trial"
  weekly: "Subscribe — [weeklyPriceText]"

Restore link: "Already subscribed?" + "Restore"

Auto-renewal disclosure (yearly):
  "3 days free, then [yearlyPriceText]. Plan auto-renews unless you cancel at least 24 hours before the period ends. Manage in iOS Settings."
Auto-renewal disclosure (weekly):
  "Subscribed at [weeklyPriceText]. Plan auto-renews unless you cancel at least 24 hours before the period ends. Manage in iOS Settings."

Footer: "Terms · Privacy"

Error messages:
  Missing package: "Couldn't load pricing. Check your connection and try again."
  Inactive entitlement: "Purchase didn't activate Pro. Try again or contact support@absmaxxing.com."
  Generic: "Couldn't complete purchase. Try again in a moment."
  Offerings load failure: "Pricing didn't load. Tap to retry."
```
**Components:** CTAButtonStyle, PulsingDots, SafariView, Palette (.accent, .bgPrimary, .bgElevated, .textPrimary, .textSecondary, .textInverse, .stateBad, .stateWarn, .divider), Typo.title/caption, Radius.sm/md, Space.sm/md/lg/xl, Haptics.light/success
**State:** `selectedPlan: Plan` (.yearly/.weekly), `working`, `errorMessage`, `legalDoc: LegalDoc?`, `offering: Offering?`, `loadingOfferings`, `offeringsLoadFailed`, `focusArea @AppStorage`, `dismissable` (param)
**Actions:** Card tap → `.easeOut(0.2)` border + scale 1.02; CTA → `Purchases.shared.purchase(package:)`; Restore → `onRestore()` callback (RootView wires `Purchases.shared.restorePurchases()`); Terms/Privacy → SafariView; Retry → `loadOfferings()`.
**Animations:** Card selection .easeOut(0.2) border + scale 1.02; selection indicator scale + opacity; CTA press 0.96 (CTAButtonStyle).
**Special considerations:** `dismissable` controls close button visibility. Package lookup by `storeProduct.productIdentifier` matching `RevenueCatConfig.ProductID.*`. Per-week math + savings % computed dynamically using `storeProduct.priceFormatter`. Apple-required intro-offer disclosure baked into yearly CTA copy.
**Brand-locked copy:** Legal URLs `https://absmaxxing.com/terms` (line 52) and `/privacy` (line 53). Error: `support@absmaxxing.com` (line 496). All four headline variants reference "30 days" / "Core Reset" — central rebranding work.

---

## 7. Design System Reference

### Palette (`PlankApp/DesignSystem/Tokens.swift`)

| Token | Hex | Use |
|---|---|---|
| `Palette.bgPrimary` | `#F7F3EE` | All screen backgrounds (warm cream) |
| `Palette.bgElevated` | `#FFFEFB` | Cards, modals, elevated surfaces |
| `Palette.bgInverse` | `#2C2218` | Dark surfaces (primary CTA bg, session) |
| `Palette.textPrimary` | `#2C2218` | Body text, headings, greeting |
| `Palette.textSecondary` | `#6B5D4F` | Metadata, captions, de-emphasized |
| `Palette.textInverse` | `#F7F3EE` | Text on dark surfaces (CTA copy) |
| `Palette.accent` | `#C8612C` | Active states, selected pricing card border, CTA bg, links |
| `Palette.accentSubtle` | `#E8C9A8` | Active day node bg, subtle highlights |
| `Palette.stateGood` | `#7A9E5C` | Good form overlay (muted sage) |
| `Palette.stateWarn` | `#C8823C` | Form fault overlay (warm amber), warning icons |
| `Palette.stateBad` | `#9E5C5C` | Camera failure (muted brick), error text, destructive bg |
| `Palette.divider` | `#E8DFD3` | Hairline dividers, unselected card border |

### Typography (`Typo.*`)

| Token | Font / Weight / Size | Use |
|---|---|---|
| `Typo.display` | DMSans-Light 56pt (tight leading) | Timer display, Core Score |
| `Typo.title` | DMSans-SemiBold 32pt | Home greeting, paywall headline, Day 30 celebration |
| `Typo.heading` | DMSans-SemiBold 20pt | Section labels, exercise name on today's card |
| `Typo.body` | DMSans-Regular 16pt | Quiz questions, card descriptions, sub-CTA text |
| `Typo.caption` | DMSans-Medium 13pt | Day counter, metadata, paywall trust microcopy |

### Spacing (`Space.*`)

| Token | Value | Use |
|---|---|---|
| `Space.xs` | 4pt | Within component (icon + text gap) |
| `Space.sm` | 8pt | Between related elements (label + input) |
| `Space.md` | 16pt | Between content sections (default padding, card internal) |
| `Space.lg` | 24pt | Between distinct UI zones (card-to-card, screen H padding) |
| `Space.xl` | 48pt | Between major screen regions |
| `Space.screenPadding` | 16pt (= md) | Horizontal screen padding |
| `Space.cardPadding` | 16pt (= md) | Internal card padding |
| `Space.minTapTarget` | 44pt | Minimum tap target (Apple HIG) |

### Corner Radius (`Radius.*`)

| Token | Value | Use |
|---|---|---|
| `Radius.sm` | 8pt | Inline elements (badges), tags, pills, warning alert box |
| `Radius.md` | 14pt | Cards, buttons, modals, pricing cards, CTA |
| `Radius.lg` | 24pt | Hero cards, full-screen sheets |

### Haptics (`PlankApp/DesignSystem/Haptics.swift`)

```
Haptics.light()         — Light tap, option select, toggle, small button
Haptics.medium()        — Medium tap, card tap, navigation, confirm
Haptics.heavy()         — Heavy tap, celebration, session start, milestone
Haptics.soft()          — Soft, scroll snap, subtle feedback
Haptics.rigid()         — Rigid, error, alert, warning
Haptics.tick()          — Selection tick, picker change
Haptics.success()       — Success, session complete, good form confirmed
Haptics.warning()       — Warning, form fault detected
Haptics.error()         — Error, session failed, camera blocked
Haptics.vibrate()       — Strong vibration (AudioServices, real motor, like text message)
Haptics.doubleVibrate() — Double strong pulses (0.4s gap)
```

### Anti-patterns / Brand Constraints (from `DESIGN.md`)

- **No pure blacks (#000), no pure whites (#FFF).** All text and surfaces in warm earth tones.
- **Warm but irreverent tone.** Quote from DESIGN.md: "Hey. Day 12 of 30. Don't blow it."
- **Muted state colors.** Form faults use warm amber, not bright red — user is face-down, alarm states are jarring.
- **Single shadow style.** rgba(44, 34, 24, 0.08), radius 12, offset 0/2. Applied only to bg.elevated surfaces.
- **No `.font(.system(size:))`** in codebase. Use Typo tokens.
- **No `.padding(N)` literals.** Use Space tokens.
- **Display timer fixed at 56pt** (no Dynamic Type); all other typography scales.
- **Dark mode out of scope for v1.**
- **Typography anchors are binding:** Timer MUST be display. Home greeting MUST be title.
- **Min tap target 44pt** (Apple HIG).
- **Horizontal screen padding always Space.md (16pt).**
- **Accent (#C8612C) is warm terracotta, never bright orange.**

---

## Appendix A — Total surface count

| Section | Surfaces |
|---|---|
| Onboarding (incl. splash, OnboardingData, components) | ~26 |
| Auth | 6 |
| Home / Analytics / Tabs | ~16 |
| Session / Routine | 6 |
| Settings sub-pages | 6 |
| Paywall | 1 |
| **TOTAL** | **~61** |

Plus Design System reference (1) and 5 cross-cutting appendices. Onboarding screens dominate (40%+); paywall + design tokens + auth define the rebrandable surfaces tightly.

---

## Appendix B — All "absmaxxing" copy strings (verbatim with file:line)

### User-facing brand wordmark (4 places)

```
PlankApp/Auth/AuthBootstrapSplash.swift:20            Text("absmaxxing")              [splash brand wordmark]
PlankApp/Views/Onboarding/OnboardingView.swift:339    Text("absmaxxing")              [splash, screen -1]
PlankApp/Views/Onboarding/OnboardingView.swift:468    Text("absmaxxing")              [welcome, screen 0 headline]
PlankApp/Views/Onboarding/OnboardingView.swift:843    Text("absmaxxing")              [chart legend, screen 4]
PlankApp/Views/Onboarding/OnboardingView.swift:1063   Text("absmaxxing")              [form comparison card, screen 12]
PlankApp/Views/Onboarding/OnboardingView.swift:1970   Text("Why absmaxxing\nworks")   [feature showcase headline, screen 13]
```

### User-facing copy fallback (1 place)

```
PlankApp/Views/Onboarding/OnboardingView.swift:893    : "absmaxxing was built for this."   [celebration default fallback, screen 6]
```

### URLs in production code (4 places)

```
PlankApp/Views/Onboarding/SignUpView.swift:57         URL(string: "https://absmaxxing.com/terms")!
PlankApp/Views/Onboarding/SignUpView.swift:58         URL(string: "https://absmaxxing.com/privacy")!
PlankApp/Views/Onboarding/SignUpView.swift:407        markdown: "...[Terms](https://absmaxxing.com/terms) and [Privacy Policy](https://absmaxxing.com/privacy)."
PlankApp/Views/Paywall/PaywallView.swift:52           URL(string: "https://absmaxxing.com/terms")!
PlankApp/Views/Paywall/PaywallView.swift:53           URL(string: "https://absmaxxing.com/privacy")!
```

### Support email in error copy (2 places)

```
PlankApp/Views/Paywall/PaywallView.swift:496          errorMessage = "Purchase didn't activate Pro. Try again or contact support@absmaxxing.com."
PlankApp/Views/Settings/AccountView.swift:260         return "Couldn't delete account. Try again or contact support@absmaxxing.com."
```

### Settings copy reference (1 place)

```
PlankApp/Views/Settings/NotificationSettingsView.swift:84    Text("Notifications are off in Settings. Go to Settings > absmaxxing > Notifications to enable.")
```

### App Store / RevenueCat product identifiers (PERMANENT — DO NOT change without coordinated App Store Connect migration)

```
PlankApp/Config/RevenueCatConfig.swift:33     static let weekly = "absmaxxing_weekly"
PlankApp/Config/RevenueCatConfig.swift:35     static let yearly = "absmaxxing_yearly"
```
**These are App Store SKUs.** Renaming them requires creating new products in App Store Connect, migrating subscribers, etc. Not a simple find/replace — leave alone unless explicitly migrating.

### Notification identifier (technical, can change)

```
PlankApp/Notifications/TrialEndNotificationService.swift:27    private let identifier = "absmaxxing.trial.ending.reminder"
```

### Source comments (NOT user-facing — for awareness only)

```
PlankApp/Views/Onboarding/OnboardingView.swift:1052   // absmaxxing
PlankApp/Views/Paywall/PaywallView.swift:9            // translated into absmaxxing's voice (calm, confident, terracotta accent
```

### .storekit configuration (PlankApp/Resources/absmaxxing.storekit)

The entire file is named with `absmaxxing` and references the brand throughout (subscription group name "absmaxxing Pro", product display names "absmaxxing Pro Weekly", "absmaxxing Pro Yearly"). For dev sandbox testing only; production reads from App Store Connect. Updating this is cosmetic-only; the `productID` strings must match App Store Connect (see RevenueCatConfig note above).

### Legacy "plankAI" wordmark (separate from "absmaxxing" — earlier brand?)

```
PlankApp/Views/Session/PreSessionView.swift:188       Text("plankAI needs camera access to track your form.\nOpen Settings to enable it.")
PlankApp/Views/Share/RoastCardView.swift:66           Text("plankAI")   [share card watermark]
```
The repo / Xcode project is named `plankAI` and the app target is `plankAI.app`, suggesting an earlier rebrand from plankAI → absmaxxing left these two strings stale. The JeniFit pivot should sweep both.

---

## Appendix C — "ab routine" / "core" / "plank" positioning vs exercise references

This section disambiguates **brand-positioning** uses (rebrandable) from **exercise-vocabulary** uses (probably keep — they describe what the app does).

### Brand positioning — almost certainly rebrand

```
"30-Day Core Reset"             OnboardingView.swift:2273 (legacy paywall headline)
"Start your 30-day Core Reset." PaywallView.swift:69 (default headline fallback)
"30-day program"                OnboardingView.swift Analyzing checklist, screen 20
"Build your core foundation"    PaywallView.swift:68 (lowerBack headline)
"AI plank trainer"              OnboardingView.swift:471 (welcome subhead)
"Why absmaxxing works"          OnboardingView.swift:1970 (feature showcase headline)
"Your AI Coach\nNeeds to See You" PreSessionView.swift (camera permission)
"Your Plank Coach"              RoastCardView.swift:33 (attribution)
"plankAI needs camera access"   PreSessionView.swift:188 (camera blocked headline)
"plankAI" watermark             RoastCardView.swift:66
```

### Personalized headlines (keep the structure, may rephrase verbs)

```
"Define your abs in 30 days."           PaywallView.swift:66 (focusArea: abs)
"Sculpt your waistline in 30 days."     PaywallView.swift:67 (focusArea: obliques)
"Build your core foundation in 30 days." PaywallView.swift:68 (focusArea: lowerBack)
```
The "30 days" framing is a brand promise (see Appendix E). The verb choices ("Define", "Sculpt", "Build") are body-positive but absmaxxing-flavored.

### Exercise / feature vocabulary — keep

These describe what the product **does** (the app coaches plank holds and core routines). Renaming to JeniFit doesn't change that the app teaches planks.

```
"Plank Benchmark", "Plank Hold"       SessionView, HomeView (session type labels)
"Core Routine"                        AnalyticsView (session type label)
"Plank Progress"                      AnalyticsView (stat card title)
"Plank Check", "plank check-in"       HomeView coach copy
"Plank Mastery", "Core Catalyst"      WorkoutPreset names (see Workout/WorkoutPreset.swift)
"Core feels different"                Onboarding before/after card
"core training"                       SF Symbol "figure.core.training" (icon name)
"Forearms on the floor..."            PreSessionView form guide
```

### Edge cases — judgment call

- **"Reset Onboarding"** (AccountView) — generic UI string, not a brand promise. Keep.
- **"Core Reset" (without "30-Day")** — appears nowhere standalone except in the paywall headline. Coupled to brand.
- **Coach personas (Kira, Sarah, Matson)** — voice/tone choices, see Appendix E.
- **OnboardingData.focusArea values** ("abs", "obliques", "lowerBack", "fullCore") — internal state machine keys, do not affect UI copy.

---

## Appendix D — Voice clip filenames

`PlankApp/Resources/VoiceClips/` contains **~280 .m4a files**. The naming convention:

- **Base / Kira (no prefix):** `<category>_<index>.m4a`
- **Sarah variant:** `sarah_<category>_<index>.m4a`
- **Matson variant:** `matson_<category>_<index>.m4a`

If the JeniFit pivot keeps the three trainers, the file system stays as-is (RoutineAudioManager prefixes by `voicePreference`). If trainers rename, every file in two of the three sets renames.

### Categories (Kira / base set — Sarah & Matson have parallel sets)

| Category | Files |
|---|---|
| Camera issues | `camera_bad_1.m4a`, `camera_bad_2.m4a` |
| Countdowns | `countdown_1.m4a`, `countdown_2.m4a`, `countdown_3.m4a`, `countdown_5.m4a`, `countdown_10.m4a` |
| Encouragement | `encourage_1.m4a` … `encourage_5.m4a` |
| Session end | `end_bad.m4a`, `end_good.m4a` |
| Exercise lifecycle | `exercise_almost.m4a`, `exercise_countdown.m4a`, `exercise_done.m4a` |
| Form guides | `guide_good_1.m4a` … `guide_good_3.m4a`, `guide_setup_1.m4a` … `guide_setup_3.m4a` |
| Hip pike fault | `hip_pike_1.m4a` … `hip_pike_4.m4a` |
| Hip sag fault | `hip_sag_1.m4a` … `hip_sag_6.m4a` |
| Hold cues | `hold_1.m4a` … `hold_6.m4a` |
| Exercise intros (~24 exercises) | `intro_bear_crawl_hold.m4a`, `intro_bicycle_crunch.m4a`, `intro_bird_dog.m4a`, `intro_dead_bug.m4a`, `intro_flutter_kicks.m4a`, `intro_glute_bridge_hold.m4a`, `intro_glute_bridge_marches.m4a`, `intro_high_knees.m4a`, `intro_hollow_body_hold.m4a`, `intro_inchworms.m4a`, `intro_leg_raises.m4a`, `intro_mountain_climbers.m4a`, `intro_oblique_crunch_left.m4a`, `intro_oblique_crunch_right.m4a`, `intro_plank_shoulder_taps.m4a`, `intro_reverse_crunch.m4a`, `intro_russian_twists.m4a`, `intro_side_plank_left.m4a`, `intro_side_plank_right.m4a`, `intro_superman_hold.m4a`, `intro_superman_pulses.m4a`, `intro_toe_touches.m4a`, `intro_v_ups.m4a`, `intro_woodchoppers.m4a` |
| Milestones | `milestone_10.m4a`, `milestone_30.m4a`, `milestone_60.m4a`, `milestone_90.m4a`, `milestone_120.m4a` |
| Recovery | `recovery_1.m4a` … `recovery_4.m4a` |
| Rest | `rest_1.m4a` … `rest_4.m4a` |
| Roasts | `roast_1.m4a` … `roast_4.m4a` (Kira + Matson only — Sarah has none) |
| Routine done | `routine_done_1.m4a` … `routine_done_5.m4a` |
| Routine start | `routine_start_1.m4a` … `routine_start_3.m4a` |
| Shoulder fault | `shoulder_1.m4a` … `shoulder_4.m4a` |
| Skip | `skip_1.m4a`, `skip_2.m4a` |
| Session start | `start_1.m4a`, `start_2.m4a` |
| Session stopped | `stopped_1.m4a` … `stopped_4.m4a` |
| Tempo cues | `tempo_1.m4a` … `tempo_4.m4a`, `tempo_drive_1.m4a`, `tempo_drive_2.m4a`, `tempo_twist_1.m4a`, `tempo_twist_2.m4a` |
| Coach previews (single, no prefix) | `kira_preview.m4a`, `sarah_preview.m4a`, `matson_preview.m4a` |

### Sarah set deltas (smaller than full Kira set)

Sarah is missing some clips that Kira/Matson have:
- No roasts (RoutineAudioManager hasRoasts=false for `"encouraging"`)
- Missing `recovery_3`, `recovery_4`
- Missing some `hip_pike`, `hip_sag` variants (Sarah has hip_pike_1-2, hip_sag_1-3 only)
- Missing `shoulder_3`, `shoulder_4`, `stopped_3`, `stopped_4`

### Matson set deltas

Matson has slightly fewer hip fault clips (hip_pike_1-2, hip_sag_1-3) and shoulder clips (shoulder_1-2 only) but otherwise mirrors Kira.

### Coach photos referenced in code (Assets.xcassets)

```
coach-kira     (default)
coach-sarah    (encouraging)
coach-matson   (balanced)
```

If JeniFit keeps the three personas, photos rebrand only if Jeni decides on new names/likenesses. If JeniFit collapses to a single "Jeni" coach, the entire voicePreference / RoutineAudioManager prefix system simplifies (or the prefix can become `jeni_`).

---

## Appendix E — Brand promises locked to absmaxxing positioning

These are the **claims and framings** the app currently makes. Each carries product-positioning weight that may or may not align with JeniFit. Listed by priority of "if you change the brand promise, you change the product."

### 1. **30-Day Core Reset** (the biggest brand promise)

The app's core narrative is a **30-day program**. Users are told repeatedly that "in 30 days you'll feel it." This appears in:

- Paywall headline (default fallback): `"Start your 30-day Core Reset."`
- All four focusArea-personalized paywall headlines: `"...in 30 days."`
- Legacy onboarding paywall: `"Start your 30-Day\nCore Reset free."`
- Analyzing screen checklist: `"Building 30-day program"`
- PostSessionView: `"Day [N] of 30 complete"`
- PostRoutineView streak messaging tops at `"Day 30+: Built different."`

**JeniFit decision required:** Is JeniFit a 30-day program too? Or open-ended? The app's day-counter, plan-reveal, post-session "Day N of 30", and analytics all assume a 30-day arc. Removing it would touch dozens of screens.

### 2. **AI form coaching as the differentiator**

The product is positioned as "Other apps count seconds. We watch your form." This appears in:

- Form Education comparison screen (screen 12)
- Feature Showcase (screen 13): `"AI-tracked plank benchmark"`, `"Camera watches your form weekly"`
- Plan Reveal (screen 21) card 3: `"Weekly Plank Check / AI tracks your form progress"`
- Paywall benefit row 1: `"AI form coaching"`
- Camera permission copy: `"Your AI Coach Needs to See You"`
- `RoutineSessionView` is text-light specifically because audio + visual pose feedback carry the experience.

If JeniFit also leads with AI form coaching, this all stays. If JeniFit deemphasizes AI in favor of, say, expert-trainer-led routines, the entire positioning chain reframes.

### 3. **Three named coach personas (Kira, Sarah, Matson)**

The voice system is core. Each persona has:
- A vibe label and quote (Coach Selector)
- ~90 voice clips (intros, encouragement, faults, milestones, etc.)
- Photos referenced as `coach-kira`, `coach-sarah`, `coach-matson`
- `voicePreference` `@AppStorage` key (`keepItReal` / `encouraging` / `balanced`)

Brand decision: keep all three with same names? Rename? Collapse to one "Jeni" coach? Each option has different scope:
- **Keep:** zero work
- **Rename:** rerecord ~270 clips OR use AI voice cloning
- **Collapse to one:** rerecord ~90 clips, simplify RoutineAudioManager + ChangeTrainerView

### 4. **Roast / sass voice as Kira's signature**

Kira's persona ("Sassy & Real") includes roasts. RoutineAudioManager has `hasRoasts: Bool` flag (true for Kira and Matson, false for Sarah). PostSessionView shows "BEST ROAST" quote. Welcome screen voice bubble: `"Hips! Up! You're giving hammock rn"`. Camera permission micro-copy: `"and roast you properly"`.

If JeniFit's voice is gentler / less Gen-Z-ironic, the roast pillar drops or transforms.

### 5. **5–10 minute daily routines**

- Onboarding session length quiz (screen 25): "5 / 7 / 10 min"
- Feature Showcase: `"5-10 min ab sessions"`
- Paywall benefit row 2: `"5-minute daily routines"`
- Before/After screen headline: `"What 5 minutes a day looks like"`

If JeniFit is longer-form workouts, the routine length quiz + value prop both change.

### 6. **"No gym, no equipment" positioning**

- Paywall benefit row 2 detail: `"No gym, no equipment, no excuses."`
- Camera setup copy: `"Prop your phone about 6 feet away"`
- Form Education tagline: `"20 seconds of perfect form beats 60 seconds of bad form"`

This positions the app as bedroom/living-room friendly. JeniFit may keep this or pivot to gym-augmenting.

### 7. **Anti-toxic, body-positive framing**

The voice copy actively avoids "shred" / "burn" / weight-loss language. Affirmations focus on consistency (`"Consistency looks good on you"`) and showing up (`"You showed up. That's the whole game."`). Even the roasts are gentle ("My mama planks better than this"). Plan reveal subhead is `"Built for [a stronger core / better posture / feeling more confident / getting toned]"` — the word "toned" is the closest thing to aesthetic framing.

If JeniFit is more aesthetic-aspirational (like Cal AI / BetterMe), the voice tone moves. If JeniFit doubles down on the wellness framing, voice stays.

### 8. **Domain + support email**

- `https://absmaxxing.com/terms` and `/privacy` — must be hosted before App Store submission (already in TODOS.md)
- `support@absmaxxing.com` — error copy in PaywallView and AccountView

These are real infrastructure decisions. The JeniFit pivot needs a domain owned, pages hosted, and inbox monitored before the brand can change.

---

**End of audit document.**
