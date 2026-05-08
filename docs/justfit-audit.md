# JustFit Audit — Reference for JeniFit Pivot

**Generated:** 2026-05-02
**Source:** 88 screenshots at `screenshots/IMG_4882.PNG`–`IMG_4969.PNG`
**Purpose:** Reference catalog for selectively adopting JustFit's copy/UX patterns. Same target audience (Gen Z women, home workouts, body transformation), different brand direction.

---

## Table of Contents

1. [Section 1 — Onboarding flow (screen-by-screen)](#section-1--onboarding-flow-screen-by-screen)
2. [Section 2 — Home + main UI (screen-by-screen)](#section-2--home--main-ui-screen-by-screen)
3. [Section 3 — Voice/copy patterns](#section-3--voicecopy-patterns)
4. [Section 4 — Positioning claims](#section-4--positioning-claims)
5. [Section 5 — Question categories](#section-5--question-categories)
6. [Section 6 — Patterns to copy vs skip for JeniFit](#section-6--patterns-to-copy-vs-skip-for-jenifit)
7. [Summary stats](#summary-stats)

---

## Section 1 — Onboarding flow (screen-by-screen)

The flow runs roughly as: hero → account branch → motivation/goal → body areas → testimonials → biometrics (height/weight/goal) → body type slider → "stubborn fat" claim → first prediction → personalization (gender/age) → projection → workout location/type/level → injury filter → re-projection → lifestyle → activity level → fitness experience → testimonials → flexibility/cardio test → competitor diff → 1-week change preview → relatability statements (3) → social proof → reward + identity questions → reshape body / face change → goal Y/N triplet → loading → projection → paywall.

**Note on visual style (across all screens):** white background, red/pink accent (~`#E63946`-ish), red progress bar at top of every onboarding screen, photo-heavy (real women, before/after, body-part annotations), illustration for relatability moments, lightbulb icons for educational helper text.

### IMG_4882 — Hero / community social proof

- **Type:** splash hero (entry point)
- **Headline:** `"Together, we can achieve more!"`
- **Stats displayed:** `"31 Million" — Millions' Fitness Enthusiasts` · `"277 Million" — Accumulated Training Minutes` · `"1.53 Billion" — Calories Burned Together`
- **CTA:** `"Get Started"`
- **Footer:** `"Already have an account? Log in"`
- **Visual:** Diverse women in athletic wear, white bg, pastel decorative confetti shapes
- **Notes:** Heavy collective framing. No AI language.

### IMG_4883 — Loading splash (frame A)

- **Type:** transitional splash
- **Headline:** `"Fitness made easy"`
- **Visual:** Solid red/pink gradient + loading bar
- **Notes:** Tagline positioning: simplicity/accessibility.

### IMG_4884 — Loading splash (frame B)

- Continuation of above; same `"Fitness made easy"` tagline.

### IMG_4885 — "Welcome to Join" geographic

- **Headline:** `"Welcome to Join"`
- **Stats:** `"30 million"` `"JustFitters"`
- **Visual:** Red gradient + pixel-dot USA map with location pins
- **Notes:** "JustFitters" = community identity name.

### IMG_4886 — Hero (variant of 4882, with decorative confetti more visible)

- Identical copy to IMG_4882.

### IMG_4887 — New vs existing account branch

- **Headline:** `"Do you already have a JustFit account?"`
- **Question type:** single-select binary
- **Options:**
  - `"Yes, log in to access my fitness plan"` (with ✓ icon)
  - `"No, let's create a fitness plan"` (with ✗ icon)
- **Notes:** Framing: "create a fitness plan" not "sign up".

### IMG_4888 — Motivation question

- **Headline:** `"What motivates you most?"`
- **Question type:** single-select
- **Options:**
  - `"Get Shaped"` (weight-lifting silhouette icon)
  - `"Look Better"` (sparkle/diamond icon)
  - `"Prepare Body for Summer"` (bikini silhouette icon)
  - `"Feel More Confident"` (thumbs up icon)
  - `"Find Self-love"` (heart icon)
- **Notes:** Mix of body-transformative ("Get Shaped", "Look Better"), seasonal/aesthetic ("Prepare Body for Summer"), and mindset-focused ("Feel More Confident", "Find Self-love"). Aesthetic-aspirational dominant.

### IMG_4889 — Motivation question (selection state)

- Same as IMG_4888 with `"Prepare Body for Summer"` selected (red border).

### IMG_4890 — Main goal

- **Headline:** `"What's your main goal?"`
- **Question type:** single-select with photo options
- **Options:**
  - `"Lose weight"` (selected; before/after toned-midsection photo)
  - `"Build muscle"` (toned-torso photo)
  - `"Keep fit"` (athletic-physique photo)
- **Notes:** Photo-driven aesthetic framing. "Lose weight" preselected.

### IMG_4891 — Body focus areas (multi-select)

- **Headline:** `"Which areas do you want to focus on?"`
- **Question type:** multi-select with body-annotated photo
- **Options:**
  - `"Toned Arms"` (✓ pre-checked, red circle pointing to arms)
  - `"Flat Belly"` (✓ pre-checked, red circle pointing to midsection)
  - `"Round Butt"`
  - `"Slim Legs"`
  - `"Full Body Slimming"`
- **CTA:** `"Next"`
- **Notes:** Annotated photo of woman in black athletic crop top + leggings with red circles + arrows. Highly aesthetic-focused vocabulary ("Toned", "Flat", "Round", "Slim").

### IMG_4892 — Testimonial #1 (Raj, Toronto)

- **Headline:** `"Millions of incredible weight loss stories are happening here"`
- **Subhead:** `"Over 300,000 5-star ratings from satisfied users!"`
- **Quote:** `"I started with no experience, but JustFit's beginner-friendly training program made it so simple I've lost 20 pounds of weight in 3 months and feel more confi..."` — Raj, Toronto
- **Visual:** Before/after photos + 5-star icons
- **CTA:** `"Next"`

### IMG_4893 — Testimonial #2 (Jock, Sydney)

- **Quote:** `"Staying active in my 50s felt like a challenge until I found Jusfit. The low-impact exercises helped me stay fit without risking injuries. I feel 10 years yo..."` — Jock, Sydney
- **Notes:** Different demographic (50s). Adds health/safety angle.

### IMG_4894 — Testimonial #3 (Sarah, Chicago)

- **Quote:** `"JustFit helped me lose 20 pounds in 12 weeks! The workouts were easy to follow, and the progress tracking kept me motivated."` — Sarah, Chicago

### IMG_4895 — Testimonial #4 (Raj, Toronto repeat)

- Carousel loops back to Raj.

### IMG_4896 — Height input

- **Headline:** `"What's your height?"`
- **Question type:** slider (ruler/scale)
- **Default value:** `"5'5""`
- **Unit toggle:** `ft` / `cm`
- **CTA:** `"Next"`

### IMG_4897 — Current weight + BMI

- **Headline:** `"What's your current weight?"`
- **Question type:** slider
- **Default value:** `"150 lbs"`, unit toggle `lbs` / `kg`
- **Realtime feedback:** `"Your BMI: 25.0"` (orange)
- **Helper text:** `"You only need a bit more sweat exercise to see a fitter you!"`
- **CTA:** `"Next"`
- **Notes:** Real-time BMI calculation. Helper text is mildly judgmental.

### IMG_4898 — Goal weight

- **Headline:** `"What's your goal weight?"`
- **Question type:** slider
- **Default value:** `"130 lbs"`
- **Validation message:** `"Reasonable goal: You will lose 13% of your weight"`
- **Footer disclaimer:** `"There is scientific evidence that some obese-related conditions improved with 10% or higher weight loss."`
- **CTA:** `"Next"`
- **Notes:** Goal validation + scientific framing references "obese-related conditions" — first health framing.

### IMG_4899 — Current body type

- **Headline:** `"Choose your body type"`
- **Question type:** body-type carousel slider
- **Range labels:** `"Body fat <15%"` (left) → `">40%"` (right)
- **Visual:** Female silhouette photo, 6 carousel dots, slider currently at "Body fat <15%" (lean position)

### IMG_4900 — Desired body type

- **Headline:** `"What's your desired body type?"`
- Same slider interface; user drags toward goal composition.

### IMG_4901 — "Stubborn fat will shed" (love handle / potbelly)

- **Headline:** `"All stubborn fat will shed just like this"`
- **Visual:** Female torso in sports bra with red arrows + labels `"Love handle"`, `"Potbelly"`. Weight overlay: `"160 lbs"`
- **CTA:** `"Next"`
- **⚠ Notes:** Spot-reduction claim presented as fact. Body-part labels ("love handle", "potbelly") are pejorative-coded. High aesthetic, no health nuance.

### IMG_4902 — "Stubborn fat will shed" (flat belly)

- Same headline. Weight overlay: `"120 lbs"`. Label: `"Flat Belly"`.
- **Notes:** Implies same plan transforms 160 → 120.

### IMG_4903 — First weight prediction

- **Headline:** `"We predict that you'll be **130lbs by Jul 24**"`
- **Helper text:** `"Great! We are starting to get a clear picture of you and your body."`
- **Visual:** Curved weight-loss projection graph (blue→pink gradient), "Today" → "Jul 24" timeline, goal marker bubble
- **CTA:** `"Next"`
- **Notes:** First explicit predictive language ("We predict"). Date is ~3 months from "today".

### IMG_4904 — Section header "Part 3: About you"

- **Headline:** `"Part 3"`
- **Subhead:** `"About you"`
- **Notes:** Onboarding is sectioned. (Earlier sections likely "About your goals" etc. — not shown explicitly.)

### IMG_4905 — Gender

- **Headline:** `"What's your gender?"`
- **Subhead:** `"This will help us calculate your basal metabolic rate and adapt to your personal plan."`
- **Question type:** single-select binary
- **Options:** `"Male"`, `"Female"` (illustrated body types side-by-side)
- **Notes:** First lightbulb-icon helper text. Justifies the question with science.

### IMG_4906 — Age

- **Headline:** `"What's your age?"`
- **Subhead:** `"This will help us make adjustment to your personal plan."`
- **Question type:** scrollable picker
- **Options shown:** `23, 24, 25 years old, 26, 27` (selected shows " years old" suffix)
- **CTA:** `"Next"`

### IMG_4907 — Demographic potential education

- **Headline:** `"You have great potential to crush your goals!"`
- **Visual:** Progress chart with sad→happy emoji faces, timeline `"3 Days — 7 Days"` to `"30 Days"`
- **Footer text:** `"Based on JustFit's historical data. For women in their 20s, weight loss is usually delayed at first, but after 7 days you can burn off calories like crazy!"`
- **CTA:** `"Next"`
- **Notes:** Demographic-segmented (women in their 20s). "Crush your goals" / "burn off calories like crazy" — colloquial Gen Z energy.

### IMG_4908 — Workout location (option list)

- **Headline:** `"Choose the place for your workout"`
- **Options:**
  - `"On the yoga mat"` — `"It's suitable for all kinds of exercises."`
  - `"On the couch & bed"` — `"It's suitable for some specific exercises."` (selected)
  - `"No preference"` — `"Let JustFit decides."`
- **Notes:** "Let JustFit decides" — grammatical typo (should be "decide") but reads as Gen-Z-casual. Anthropomorphizes the app.

### IMG_4909 — Preferred workout type

- **Headline:** `"Choose your preferred workout type"`
- **Question type:** multi-select
- **Options:** `"No equipment"`, `"No jumping"`, `"All lying down exercise"`, `"Super easy"`
- **Footer label:** `"Wall pilates"`
- **CTA:** `"Next"` (grayed out until selection)

### IMG_4910 — Workout location (yoga mat selected)

- Same screen as 4908, different selection.

### IMG_4911 — Workout type with confirmation

- Same as 4909 with `"All lying down exercise"` selected.
- **Confirmation badge:** `"Ok, we got it!"` — `"We will offer you a broad suite of workouts without leaving your bed."`
- **Notes:** Casual "Ok, we got it!" feedback pattern after answer commitment.

### IMG_4912 — Workout intensity preference

- **Headline:** `"Choose your preferred level of workouts"`
- **Options:** `"Easy enough"`, `"Simple but a little bit sweaty"` (selected), `"Somewhat challenging"`
- **Confirmation badge:** `"Every drop counts!"` — `"We have a clear plan to progressively get you closer to reaching your goals."`

### IMG_4913 — Injury filter

- **Headline:** `"Have you ever suffered any injuries in these areas?"`
- **Question type:** multi-select
- **Options:** `"None"`, `"Knee"`, `"LowerBack"`, `"Ankle"`, `"Wrist"` (3 example selections)
- **Helper text:** `"We will filter unsuitable workouts for you."`
- **CTA:** `"Next"`

### IMG_4914 — Re-prediction (Jun 21)

- **Headline:** `"We predict that you'll be 130lbs by Jun 21"`
- **Confirmation badge:** `"Still on track!"` — `"We'll incorporate your goal into your personalized plan."`
- **Notes:** Repeat of prediction format with new earlier date (Jun 21 vs original Jul 24) suggesting answers improved the projection.

### IMG_4915 — Re-prediction (Jun 26 with two milestones)

- Same headline format, two timeline markers `"Jun 26"` and `"Jul 24"`.

### IMG_4916 — Lifestyle / employment

- **Headline:** `"Which of the following best describes you?"`
- **Question type:** single-select
- **Options:**
  - `"I'm a student"`
  - `"I'm a full-time professional"`
  - `"I'm working part-time"`
  - `"I'm a freelancer"`
  - `"I'm focusing on home and family life"`
  - `"I'm exploring new career opportunities"` (selected)
- **Notes:** Six lifestyle options. Inclusive of career exploration / parenting / freelance.

### IMG_4917 — Same as IMG_4916, full-screen view

### IMG_4918 — Activity level: NOT ACTIVE

- **Headline:** `"Choose your activity level"`
- **Question type:** illustrated slider
- **Active option:** `"NOT ACTIVE"` — `"I easily get out of breath while walking up the stairs"`

### IMG_4919 — Activity level: LIGHTLY ACTIVE

- `"LIGHTLY ACTIVE"` — `"Sometimes I do quick workouts to get my body moving"`

### IMG_4920 — Activity level: MODERATELY ACTIVE

- `"MODERATELY ACTIVE"` — `"I exercise regularly, at least 1-2 times a week"`

### IMG_4921 — Activity level: HIGHLY ACTIVE

- `"HIGHLY ACTIVE"` — `"Fitness is an essential part of my life"`

### IMG_4922 — Fitness experience level

- **Headline:** `"What's your fitness level?"`
- **Question type:** circular ring + slider with three positions
- **Options:** `"Beginner"`, `"INTERMEDIATE"` (`"I have been training on a regular basis"`, selected), `"Advanced"`
- **Visual:** Orange/red circular progress ring with flame icon

### IMG_4923 — Testimonial w/ quantified user count #1 (Jennifer)

- **Headline:** `"We've helped 194,578 people like you achieve their goals!"`
- **Quote:** `"I was looking for something that would help me kick start my mind & body. This app was just right easy but not too easy & I felt the burn!"` — Jennifer, lost 25lbs
- **CTA:** `"Next"`

### IMG_4924 — Testimonial w/ quantified user count #2 (Bernard)

- Same headline.
- **Quote:** `"I have been fluctuating weight after I came across this service and lost 23 lbs in just 3 weeks! I'm on the right path, thanks a million!"` — Bernard, lost 23lbs

### IMG_4925 — Testimonial w/ quantified user count #3 (Carrie)

- **Quote:** `"After trying this app for 3 months, my proudest achievement is not only my 3lbs fat loss, but being a happy and more energetic mother to my 3 children!"` — Carrie, lost 3lbs
- **Notes:** Lifestyle/holistic framing. Smaller weight loss but emotional/identity payoff.

### IMG_4926 — Testimonial #4 (Jessica)

- **Quote:** `"JustFit fits into my lifestyle perfectly. I can turn to this app day or night, and they're there for me."` — Jessica, lost 11lbs
- **Notes:** Accessibility framing.

### IMG_4927 — Testimonial #5 (Jennifer repeat)

- Same as IMG_4923. Carousel loops.

### IMG_4928 — Flexibility test

- **Headline:** `"How far could you do a seated forward bend?"`
- **Subhead:** `"According to the Physical Activity Guidelines, this will help test your flexibility."`
- **Options:** `"Far from my feet"`, `"Close to my feet"` (selected), `"Easily touch my feet"`
- **Confirmation badge:** `"Cool! 80% of users face the same as you. We will have a clear plan that is easy to follow."`
- **Notes:** Cites "Physical Activity Guidelines" for credibility. "Cool!" + 80% normalization is reassuring.

### IMG_4929 — Cardio test

- **Headline:** `"How do you feel after climbing some stairs?"`
- **Subhead:** `"This will help test your cardiorespiratory function."`
- **Options:** `"Out of breath"` (selected), `"Somewhat tired but okay"`, `"Easily"`
- **Confirmation badge:** `"We can help! Getting some cardio can be very helpful. We will select some simple but helpful exercises for you."`
- **Notes:** Empathetic ("We can help!"). No shaming.

### IMG_4930 — Competitor differentiation

- **Headline:** `"JustFit is Different: Easy, Sustainable, and Designed for You"`
- **Visual:** Two-column comparison
- **Others column:**
  - `"Unrealistic fitness goals"`
  - `"No effort needed at all"`
  - `"FAKE Generic PLAN"`
- **JustFit Plan column (pink/red box, ✓ icons):**
  - `"Safe and Steady weight loss"`
  - `"Little effort, big results"`
  - `"REAL Personalized Plan for your unique needs"`
- **CTA:** `"Next"`
- **Notes:** All-caps "REAL" vs "FAKE Generic PLAN". "Little effort, big results" walks a fine line.

### IMG_4931 — 1-week change preview

- **Headline:** `"Here's how weight loss can change in just 1 week"`
- **Visual:** Before/after photos with 3 metrics:
  - Body Fat: `35% → 33%`
  - Waist Size: `83 cm → 79 cm`
  - Weight: `85 kg → 84 kg`
- **Footer:** `"Rapid weight loss isn't healthy, but 1-15kg per week is achievable and lasting"`
- **Notes:** Multiple metrics not just scale weight. Modest health disclaimer (though 15kg/week is unhealthy by any standard — possible typo for 1-1.5kg).

### IMG_4932 — Relatability statement #1 (body image)

- **Headline:** `"Do you relate to the statement below?"`
- **Statement:** `"I always feel unsatisfied with my body when I see the mirror."`
- **Options:** `"No"` / `"Yes"`
- **Visual:** Illustration of woman with larger body looking in mirror
- **Notes:** Body-dissatisfaction normalization. Illustration, not photo (less judgmental).

### IMG_4933 — Relatability statement #2 (workout selection)

- **Statement:** `"I have no idea how to pick up suitable workouts for me."`
- **Visual:** Woman with confused expression surrounded by exercise icons.

### IMG_4934 — Relatability statement #3 (persistence)

- **Statement:** `"I can easily give up when the exercises are too hard or boring."`
- **Visual:** Woman sitting with frustrated expression.

### IMG_4935 — Social proof scale

- **Headline:** `"JustFit was made for people just like you!"`
- **Stats:** `"1,000,000+ JustFit users"` · `"83% of JustFit users claim that the workout plan we offer is easy to follow and makes it simple to stay on track."`

### IMG_4936 — Reward question

- **Headline:** `"After reaching your goal weight, how would you reward yourself?"`
- **Options:** `"Buying new clothes"` (selected), `"Take a personal day"`, `"Sharing it on the social media"`, `"Taking pictures of myself"`, `"Traveling somewhere new"`

### IMG_4937 — Identity / post-goal mindset

- **Headline:** `"After reaching your goal weight, how would you see yourself?"`
- **Options:**
  - `"Being proud of myself"`
  - `"Feeling great"` (selected)
  - `"Believe in myself"`
  - `"Feel empowered to make healthy choices"`
  - `"Worry less about my body overall"`
- **⭐ Notes:** STRONGLY body-positive. No aesthetic ("attractive", "sexy") language. All framings are emotional/mindset. **This is the most JeniFit-aligned screen in the entire flow.**

### IMG_4938 — Same as IMG_4937 (selection state)

### IMG_4939 — Body reshape education

- **Headline:** `"Reshape Your Body the Right Way, for Lasting Results"`
- **Visual:** Three silhouettes 160 → 140 → 120 lbs
- **Footer:** `"Achieving weight loss can refine your body's shape and improve your energy and overall vitality"`
- **Notes:** "Refine" + "vitality" — dignified language. "The Right Way" is implicit competitor jab.

### IMG_4940 — Face change preview

- **Headline:** `"And Experience the Change in Face as well"`
- **Visual:** Three close-up face photos at 160 / 140 / 120 lbs
- **Footer:** `"Losing weight can remove some of that extra roundness from the cheeks and jawline, and firm up your saggy skin."`
- **⚠ Notes:** "Saggy skin" / "extra roundness" — clinical-but-judgmental.

### IMG_4941 — Goal Y/N #1: lose weight

- **Headline:** `"Do you wanna lose weight?"`
- **Options:** `"No"` / `"Yes"`
- **Visual:** Smiling woman in oversized jeans (classic "after" shot)
- **Notes:** Casual `"wanna"`. Direct binary.

### IMG_4942 — Goal Y/N #2: attractive body

- **Headline:** `"Do you wanna get an attractive body?"`
- **Visual:** Fit woman in sports bra
- **⚠ Notes:** "Attractive" — explicit aesthetic framing. Most aesthetic-aspirational question in the flow.

### IMG_4943 — Goal Y/N #3: chronic disease

- **Headline:** `"Do you wanna farewell to chronic diseases?"`
- **Visual:** Fit woman flexing bicep
- **Notes:** Casual `"wanna"` + medical framing `"chronic diseases"` — odd register mix. Possibly translated copy.

### IMG_4944 — Loading 20%

- **Subhead:** `"Creating your personal plan..."`
- **Visual:** 20% circular progress + user avatars in background
- **Footer text:** `"30,000,000+ Users"` `"Have Chosen JustFit"`

### IMG_4945 — Loading 44%

- Same screen, 44% progress + 8 exercise illustrations: `Kneeling, Climber, Squat, Crunch, Climbers, Cross Reach, Rollins, Run`
- **Footer text:** `"5,000,000+ Training Hours"` `"Have Completed in JustFit"`

### IMG_4946 — Loading 77%

- 77% progress + app rating display: `"4.8 Top-Rated"` `"Fitness App"` `"4.8"` `"24.8k AppStore reviews"` + 5 stars
- **Notes:** Loading screens triple as social-proof carousel. Rotates user count → training hours → app rating.

### IMG_4947 — Plan results / projection #1

- **Headline:** `"Based on your answers,"`
- **Subhead:** `"You'll be 130 Lbs by 29 May"`
- **Visual:** Gradient line chart 150 → 145 → 130 lbs with markers `"Today"`, `"1st week"`, `"May 29"`
- **Footer:** `"83% of people in a similar situation to you have lost 15lbs after using JustFit."`
- **Notes:** Final projection screen before paywall. Specific date + specific weight.

---

## Section 2 — Home + main UI (screen-by-screen)

### IMG_4948 — Plan results expanded

- **Headline:** `"Based on your answers, You'll be 130 Lbs by 29 May"`
- **Visual:** Same chart as IMG_4947 plus a calendar showing "Workout Routine" with days 1-9 marked
- **CTA:** `"Get my plan"` (red button)
- **Footer:** `"83% of people in a similar situation to you have lost 10lbs after using JustFit."`

### IMG_4949 — Paywall (3-tier pricing)

- **Headline:** `"Get Your Personalized Plan!"`
- **Pricing tiers:**
  - `"1 Month"` / `"$19.99/mo."` / `"$19.99/mo."`
  - `"12 Months"` / `"$79.99/yr."` / `"was $89.99"` (`"Popular"` badge, red border)
  - `"3 Months"` / `"$29.99/3mo."` / `"was $89.99"`
- **CTA:** `"Continue"`
- **Top right:** `"Restore"` link
- **Trust microcopy:** `"✓ No Payment Now!"`
- **Legal/auto-renewal:** `"Terms of Service & Privacy Policy offer a 7-day free trial/User Apple ID. If the subscription is automatically charged $79.99 for the first time one Year Cancel the subscription in your iTunes & App Store/Apple ID"` (somewhat broken English in legal)
- **Notes:** Annual is "Popular" + visually emphasized. 3-month tier is most expensive per month — looks designed to anchor toward annual.

### IMG_4950 — Promotional overlay (urgency)

- **Banner:** `"7 Day Free Trial"` `"THE BEST OFFER"`
- **Body:** `"7-Day Free Trial is Being Applied!"` `"Please don't leave this page — once it's gone, it's gone for good."`
- **Visual:** Dark overlay, magenta/pink banner, crown icon, gold-foil treatment
- **Notes:** Aggressive scarcity ("once it's gone, it's gone for good"). Crown signals premium.

### IMG_4951 — Payment error / retry modal

- **Headline:** `"❤️ Oops — Payment Issue"`
- **Progress meter:** `"99.9% Subscription is 99.9% complete"`
- **Feature list (✓):**
  - `"Lazy Workout System"`
  - `"Personalized Training Plan"`
  - `"Get Your Dream Body"`
- **Warning:** `"⚠️ Your Free Trial may disappear soon — try again to keep it!"`
- **CTAs:** `"Retry"` (red), `"Cancel"` (pink link)
- **Notes:** Manufactured urgency on a payment error. "99.9% complete" is psychological framing.

### IMG_4952 — Discount celebration

- **Headlines:** `"1000+ Exercises with Detailed"` / `"SUPER PRIZE!"` / `"Congrats! You are so lucky!"`
- **Badge text:** `"NEW USER DISCOUNT"` `"LIMITED TIME OFFER"` `"57% OFF"`
- **Visual:** Dark bg, gold/yellow discount badge, sparkle icons
- **Notes:** Casino/lottery framing. Heavy gamification.

### IMG_4953 — Home / "My Plan"

- **Header:** `"My Plan"` (dropdown)
- **Primary card:** `"28 Days Bed Workouts"` — red, with `"START!"` pill button
- **Day grid:** Days 1, 2, 3, 4 cascade below
- **Coach popup:** `"Welcome Thank You — A SPECIAL GIFT FOR YOU!"` (callout from corner)
- **Top-right action:** `"Edit"`
- **Tab bar (4 tabs):** `My Plan` (calendar) · `Boost` (lightning) · `Progress` (heart) · `Profile` (person)

### IMG_4954 — Workout Day 1 detail

- **Header:** `"Day 1"` / `"Workout Details"`
- **Stats column (BASIC):** `"14 kcal"` · `"8 min"` · `"Beginner"`
- **Music row:** `"MUSIC: Choose your playlist!"`
- **Focus zones row:** `"FOCUS ZONES: Full Body"` (with anatomical diagram)
- **CTA:** `"Start"` (red)
- **Helper:** `"Measure your heart rate"` (under Start button)

### IMG_4955 — Exercise list (Day 1, 10 exercises)

- **Header:** `"10 Exercises"`
- **Items (verbatim, all 30 sec):**
  - `"Alternate Heel Touches"`
  - `"Side Clam Left"`
  - `"Side Clam Right"`
  - `"Knee To Chest Hold"`
  - `"Sitting Toe Touches"`
  - `"Cobra Pose"`
  - `"Child's Pose"`
  - (3 more cut off in scroll)

### IMG_4956 — Exercise list (continued)

- Continuation of above: `"Knee To Chest Hold"`, `"Sitting Toe Touches"`, `"Cobra Pose"`, `"Child's Pose"`, `"Leg Curls"`, `"Single Leg Side Stretch"`, `"Butterfly Stretch"`

### IMG_4957 — Progress tab dashboard

- **Header:** `"Progress"`
- **Date selector:** `"Today"` with `<` `>` nav
- **Cards:**
  - `"CALORIES BURNED"` `"0 kcal"` `"0 kcal"` `"200 kcal"` (Edit Goal link) `"0% completed"`
  - `"STEPS"` (heart icon)
  - `"DURATION"` `"0 min"` `"This Week"`
  - `"Sync steps with Apple Health"` `"Link"` button
- **Workout Library banner:** `"Quickly search the workout you want"` (pink, magnifying glass)
- **Activities row:** `"ACTIVITIES"` — `"Duration 0 min"` · `"Calories 0 kcal"` · `"Activities 0"`

### IMG_4958 — Workout library + activity log

- **Header:** `"Workout Library"`
- **Activity entry:** `"Plan - Day 1"` `"8 min, 14 kcal"`
- **Health sections:**
  - `"HEART RATE"` `"— — bpm"` (Measure button)
  - `"BLOOD PRESSURE"` `"— — / — — mmHg"` (Record button)
- **Add activity:** `"+ Add More Activities"` (pink outline)

### IMG_4959 — Profile tab

- **Top:** `"Log In"` `"Tap to login"`
- **Banner:** `"JustFit Premium"` `"Get unlimited access to all features!"` (red, with woman in sports bra)
- **Achievements:** `"Workout Days"` `"0"` · `"Day Streak"` `"0"`
- **Calendar:** `"Workout Calendar"` `"May, 2026"`

### IMG_4960 — Profile (cont'd) — weight + cross-promo + social

- **Weight section:** weight chart + log button
- **Cross-promotion ("App From Us"):**
  - `"Eato"` / `"Meal Plan"` / `"Get"`
  - `"Shuteye"` / `"Sleep Tracker"` / `"Get"`
  - `"Mo+"` / `"Routine Planner"` / `"Get"`
- **Social:** `"Join Our Fitness Community on Instagram for More"` — `"1FIT"` badge, follower stats `"130"` `"383K"` `"57"`

### IMG_4961 — All Plans (browse)

- **Header:** `"All Plans"`
- **My Plans section:** `"28 Days Bed Workouts"` (Current Plan badge)
- **More Plans section:**
  - `"Personal Customized Training"` — `"15 - 20 min Duration"` `"Full Body Target"` `"Unnecessary Equipment"` `"Intermediate Level"` (CTA: `"Customize a New Plan"`)

### IMG_4962 — All Plans (cont'd)

- `"14 Days Lie-Down Slimming"` — 5-15 min · Full Body · No equip · Beginner
- `"7 Days Plus-Size Burn Fat Blitz"` — 20-30 min · Full Body · No equip · Intermediate
- `"21 Days Indoor Power Walking"` (partial)
- **Notes:** "Plus-Size" plan explicitly named. "Burn Fat Blitz" — alliterative aspirational.

### IMG_4963 — All Plans (cont'd)

- `"Power Walking Challenge"` — 5-15 min · Beginner
- `"14 Days Gentle Full-Body Cardio for Seniors"` — 15-20 min · Water bottles equipment · Beginner
- `"21 Days Knee-Friendly Fat Burn"` (partial)
- **Notes:** Inclusive targeting (seniors, knee-friendly).

### IMG_4964 — All Plans (cont'd)

- `"7 Days Sweat & Burn Fat Blast"` — 20-30 min · Intermediate
- `"28 Days Super Easy Workouts"` — 20-30 min · Water bottles · Beginner
- `"28 Days Wall Pilates"` (partial)

### IMG_4965 — All Plans (cont'd)

- `"28 Days Wall Pilates"` — 5-15 min · Full Body · No equip · Beginner
- `"21 Days Beginner's Leg Slimming"` — 15-20 min · Lower Body · No equip · Beginner

### IMG_4966 — All Plans (cont'd)

- `"7 Days Bye-bye Arm Fat"` — 15-20 min · Upper Body · Water bottles · Beginner
- `"7 Days Easy Shoulder Sculpt"` — 15-20 min · Full Body · Water bottles · Beginner
- `"14 Days Hight Yoga"` (partial; possibly typo for "High Yoga")

### IMG_4967 — All Plans (cont'd)

- `"21 Days Efficient Weight Loss - Beginner"` — 15-20 min · Full Body · No equip · Beginner
- `"7 Days Belly Fat Burn Plan - Slim & Tone"` — 15-20 min · Abs · No equip · Intermediate
- `"14 Days Chair Quick Fat Loss"` — 20-30 min · Chair · Beginner

### IMG_4968 — All Plans (cont'd)

- `"Plus-size Weight Loss Plan"` — 15-20 min · Full Body · No equip · Beginner
- `"7 Days Dance Blast - Dynamic Cardio"` — 1-5 min · Full Body · No equip · Advanced
- `"14 Days Wall Pilates Sculpting"` (partial)

### IMG_4969 — All Plans (final visible)

- `"14 Days Wall Pilates Sculpting"` — 5-15 min · Full Body · No equip · Beginner
- `"7 Days Sit & Sweat - Fast Fat Burn"` — 5-15 min · Full Body · Chair · Intermediate

---

## Section 3 — Voice/copy patterns

### Tone profile

- **Direct + casual + slightly hyperbolic.** Short sentences, exclamation marks ("Cool!", "Great!", "We can help!"), Gen Z contractions ("wanna", "Bye-bye", "Sit & Sweat").
- **Anthropomorphizes the app.** "Let JustFit decides", "Ok, we got it!", "We will filter unsuitable workouts for you" — "we" framing throughout.
- **Empathetic + reassuring before reassuring.** Confirmation badges normalize ("80% of users face the same as you").
- **Pricing/paywall switches register.** Becomes more aggressive — "SUPER PRIZE", "you are so lucky", "once it's gone, it's gone for good", "Your Free Trial may disappear soon".

### Sentence length tendency

- **Headlines:** 4–8 words, one short clause. ("What's your main goal?", "Choose the place for your workout", "We've helped 194,578 people like you achieve their goals!")
- **Subheads:** Single sentence, 8–18 words, often justifies the question. ("This will help us calculate your basal metabolic rate and adapt to your personal plan.")
- **Confirmation badges:** Two-part — short emoji-coded reaction + one-sentence promise. ("Cool! 80% of users face the same as you. We will have a clear plan that is easy to follow.")
- **Footer/disclaimers:** Run-on or grammatically-broken in the legal/paywall sections (likely translated).

### Question formulation patterns

- **"What's your X?"** for biometrics + identity (height, weight, gender, age, fitness level, main goal)
- **"Choose the X / Choose your X"** for preferences (place, workout type, level, body type, activity level)
- **"Have you ever X / Do you wanna X / How do you feel after X"** for relatability + barrier identification (injuries, weight loss, attractive body, chronic disease, climbing stairs)
- **"Do you relate to the statement below?"** binary Y/N with illustrated relatability scenarios
- **"After reaching your goal weight, how would you X yourself?"** for outcome/identity questions (reward, see yourself)
- **"Which of the following best describes you?"** for lifestyle bucketing (career)
- **"Which areas do you want to focus on?"** for body-part multi-select

### Option subtitle patterns

- **Always one short benefit phrase.** Activity level: `"NOT ACTIVE — I easily get out of breath while walking up the stairs"`. Workout location: `"On the yoga mat — It's suitable for all kinds of exercises."`
- **Never long descriptions or marketing puff.** Subtitles are diagnostic ("X means Y about you/your routine"), not aspirational.

### Body-positive vs aesthetic-aspirational

JustFit operates on a **dual register**:

- **Body-positive layer (~30% of copy):** "Find Self-love", "Feel More Confident", relatability statements (mirror dissatisfaction, workout overwhelm), identity questions ("Being proud of myself", "Feel empowered to make healthy choices"), explicit Plus-size plans.
- **Aesthetic-aspirational layer (~70% of copy):** "Lose weight"/"Toned Arms"/"Flat Belly"/"Round Butt", "Get an attractive body", "Stubborn fat will shed", "Bye-bye Arm Fat", "Slim & Tone", before/after photos, body-part annotations, "saggy skin"/"potbelly"/"love handle" labels.

The two coexist by **bookending**: empathetic body-positive on relatability/identity questions; aesthetic-aspirational on goal-setting and plan names.

### Specific power words that recur

- **Aesthetic verbs:** Tone, Sculpt, Slim, Burn, Blast, Shred-adjacent ("Burn Fat Blitz", "Fast Fat Burn"), Reshape, Refine
- **Aesthetic adjectives:** Attractive, Lazy (positive — "Lazy Workout System"), Easy, Super Easy, Gentle, Powerful, Dynamic
- **Aspirational verbs:** Crush (your goals), Achieve, Transform, Reach
- **Community/scale words:** Together, Millions, JustFitters, Community
- **Trust/safety words:** Safe, Sustainable, Gentle, Knee-Friendly, Beginner-friendly, Plus-size
- **Time framing:** "X Days", "in 1 week", "in 12 weeks", "by [specific date]"
- **Casual Gen Z words:** wanna, bye-bye, like crazy, 'cool', "felt the burn", "kick start", "just right easy"

### What JustFit AVOIDS

- **No "AI" language anywhere.** Zero references to "AI coach", "AI plan", "smart algorithm", "machine learning". Personalization is consistently framed as "we" / "personalized" / "based on your answers" — algorithmic without naming the algorithm.
- **No medical jargon as primary framing.** "Basal metabolic rate" appears once (in the gender helper text), "cardiorespiratory function" once. Otherwise the medical framing is colloquialized ("farewell to chronic diseases").
- **No moral/shame framing.** No "you should", no "you've been lazy", no "stop making excuses". The closest is mildly judgmental "saggy skin" / "love handle" labels.
- **No fitness-bro vocabulary.** No "gains", "shred", "alpha", "grind", "discipline" (in the bro sense). Even "Crush your goals" is softened by the women-in-20s context.
- **No explicit calorie restriction or diet language.** Plans are workout-only; meal planning is offloaded to a sister app ("Eato").

---

## Section 4 — Positioning claims

### Timeframe claims

- **Specific dates** (most prominent): "We predict you'll be 130lbs by Jul 24" / "by Jun 21" / "by Jun 26" / "by 29 May" — uses calendar specificity rather than relative time
- **Day-counted plans:** "28 Days Bed Workouts", "14 Days Lie-Down Slimming", "21 Days Knee-Friendly Fat Burn", "7 Days Bye-bye Arm Fat" — every plan name leads with a day count (most commonly 7, 14, 21, 28)
- **Per-week framing:** "1-15kg per week" (suspect typo for 1-1.5kg), "burn off calories like crazy after 7 days"
- **Per-day framing:** "1-5 min Duration", "5-15 min Duration", "15-20 min Duration", "20-30 min Duration" — generous range to set "doable" expectation

### Outcome claims

- **Weight loss specific numbers:** "lost 20 pounds in 3 months" (Raj), "lost 23 lbs in just 3 weeks" (Bernard), "20 pounds in 12 weeks" (Sarah), "lost 25lbs" (Jennifer), "lost 11lbs" (Jessica), "lost 3lbs" (Carrie)
- **Body composition projections:** "Body Fat: 35% → 33%" / "Waist Size: 83 cm → 79 cm" in 1 week
- **Goal weight prediction:** "We predict you'll be 130 Lbs by [date]" — specific weight + specific date
- **Non-weight outcomes:** "feel 10 years yo[unger]", "happy and more energetic mother", "kick start my mind & body"
- **Spot reduction implied:** "All stubborn fat will shed just like this" with body-part annotations

### Method claims

- **"Personalized" plan** ("REAL Personalized Plan for your unique needs")
- **"Lazy Workout System"** (a feature name in the payment retry modal)
- **"Beginner-friendly training program"** (Raj testimonial)
- **Difficulty + level filters:** Beginner / Intermediate / Advanced
- **Equipment-aware:** "Unnecessary Equipment" (their term for "no equipment needed"), "Water bottles Equipment", "Chair Equipment"
- **Constraint-aware:** "All lying down exercise", "No jumping", "No equipment", "Knee-Friendly", "Plus-size"
- **Health sync:** Apple Health integration suggested

### Differentiation (their explicit claims)

From IMG_4930 ("JustFit is Different"):

| Others | JustFit |
|---|---|
| "Unrealistic fitness goals" | "Safe and Steady weight loss" |
| "No effort needed at all" | "Little effort, big results" |
| "FAKE Generic PLAN" | "REAL Personalized Plan for your unique needs" |

Plus implicit:
- **Scale + community** ("31 Million", "1,000,000+ users", "JustFitters")
- **Inclusive** (plus-size, seniors, knee-friendly, lying-down options)
- **Easy onset** ("Super easy", "Lazy Workout System", "Easy enough")
- **Cross-app ecosystem** (Eato, Shuteye, Mo+)

---

## Section 5 — Question categories

### Goal questions

- **"What motivates you most?"** — Get Shaped / Look Better / Prepare Body for Summer / Feel More Confident / Find Self-love
- **"What's your main goal?"** — Lose weight / Build muscle / Keep fit
- **"Which areas do you want to focus on?"** (multi) — Toned Arms / Flat Belly / Round Butt / Slim Legs / Full Body Slimming
- **"Do you wanna lose weight?"** — Y/N
- **"Do you wanna get an attractive body?"** — Y/N
- **"Do you wanna farewell to chronic diseases?"** — Y/N

### Demographic questions

- **"What's your gender?"** — Male / Female (with metabolic-rate justification)
- **"What's your age?"** — scrollable picker (e.g., 23, 24, 25 years old, 26, 27)
- **"What's your height?"** — slider, ft/cm toggle, default 5'5"
- **"What's your current weight?"** — slider, lbs/kg toggle, with realtime BMI
- **"What's your goal weight?"** — slider with % loss validation

### Fitness level / experience questions

- **"What's your fitness level?"** — Beginner / INTERMEDIATE / Advanced (with "I have been training on a regular basis" subtitle)
- **"Choose your activity level"** — NOT ACTIVE / LIGHTLY ACTIVE / MODERATELY ACTIVE / HIGHLY ACTIVE (each with relatable subtitle)
- **"How far could you do a seated forward bend?"** — Far from my feet / Close to my feet / Easily touch my feet (flexibility test)
- **"How do you feel after climbing some stairs?"** — Out of breath / Somewhat tired but okay / Easily (cardio test)

### Lifestyle / time / equipment questions

- **"Choose the place for your workout"** — On the yoga mat / On the couch & bed / No preference
- **"Choose your preferred workout type"** (multi) — No equipment / No jumping / All lying down exercise / Super easy
- **"Choose your preferred level of workouts"** — Easy enough / Simple but a little bit sweaty / Somewhat challenging
- **"Which of the following best describes you?"** (lifestyle/employment) — I'm a student / I'm a full-time professional / I'm working part-time / I'm a freelancer / I'm focusing on home and family life / I'm exploring new career opportunities

### Body focus / composition questions

- **"Choose your body type"** — body-fat carousel slider <15% to >40%
- **"What's your desired body type?"** — same slider, target position

### Limitations / health questions

- **"Have you ever suffered any injuries in these areas?"** (multi) — None / Knee / LowerBack / Ankle / Wrist

### Motivation / barrier identification (relatability)

- **"Do you relate to the statement below?"** — Y/N for each:
  - "I always feel unsatisfied with my body when I see the mirror." (body image)
  - "I have no idea how to pick up suitable workouts for me." (selection overwhelm)
  - "I can easily give up when the exercises are too hard or boring." (persistence)

### Reward + identity questions (post-goal hypotheticals)

- **"After reaching your goal weight, how would you reward yourself?"** — Buying new clothes / Take a personal day / Sharing it on the social media / Taking pictures of myself / Traveling somewhere new
- **"After reaching your goal weight, how would you see yourself?"** — Being proud of myself / Feeling great / Believe in myself / Feel empowered to make healthy choices / Worry less about my body overall

### Account branch

- **"Do you already have a JustFit account?"** — Yes/No

### Pattern observations

- **5 options is the modal count** for single-select questions.
- **Multi-select questions cap around 4–5** options.
- **Sliders are used for continuous data** (weight, height) and **for ordered categoricals** (body type, activity level, fitness level).
- **Y/N is reserved for relatability + late-stage goal confirmation.**
- **Flexibility/cardio "tests"** are functional benchmarks, not perceived-effort questions.

---

## Section 6 — Patterns to copy vs skip for JeniFit

### High-value patterns to copy

#### A. **Identity / post-goal questions (IMG_4937)**
The single most JeniFit-aligned screen in the entire flow. JustFit asks `"After reaching your goal weight, how would you see yourself?"` with options:
- "Being proud of myself"
- "Feeling great"
- "Believe in myself"
- "Feel empowered to make healthy choices"
- "Worry less about my body overall"

**Why this works:** Anchors the entire flow in emotional outcomes, not aesthetic ones. Final answer compounds across the app's notifications, post-session screens, and milestone copy. Use this verbatim shape with JeniFit-tuned options:

> *JeniFit-flavored version:*
> **"When you imagine reaching your goal — what feeling shows up first?"**
> - Being proud of myself
> - Feeling at home in my body
> - Believing what I'm capable of
> - Worrying less about how I look
> - Showing up for the people I love

Notice the substitutions: "after reaching your goal weight" → "when you imagine reaching your goal" (drops weight as the proxy). "Feel empowered to make healthy choices" reads slightly clinical → "Believing what I'm capable of" reads more interior. Add a relational option ("showing up for the people I love") since JeniFit's audience skews aspirational-feminine.

#### B. **Relatability statements (IMG_4932-4934)**
Three Y/N screens, each with a single sentence describing a common pain point + an illustration:
- "I always feel unsatisfied with my body when I see the mirror."
- "I have no idea how to pick up suitable workouts for me."
- "I can easily give up when the exercises are too hard or boring."

**Why this works:** Builds empathy without surveying. The user feels seen by the time they answer. Use this pattern with JeniFit-flavored statements:

> - "Workout apps make me feel further from my body, not closer."
> - "I want to feel strong without having to perform fitness."
> - "I quit when something stops feeling true to me."

#### C. **Confirmation badges after answers ("Cool! 80% of users face the same as you")**
Pattern: short emoji-coded reaction + normalization stat + one-line plan promise. Used after fitness-test questions (flexibility, cardio).

**Why this works:** Rewards the user for honest self-disclosure. Normalizes vulnerability. Makes the algorithm feel responsive ("we're tailoring this").

JeniFit version pattern:
> **"That makes sense."** *Most people we work with feel the same. Your plan starts where you are.*

Use after any question where the user might feel exposed (current weight, activity level, "what stops you").

#### D. **Why-justified subheads on biometric questions**
Every JustFit biometric question explains *why* it's asking:
- "What's your gender?" → *"This will help us calculate your basal metabolic rate and adapt to your personal plan."*
- "What's your age?" → *"This will help us make adjustment to your personal plan."*

**Why this works:** Reduces friction at the point of asking for sensitive data. Treats the user as a partner.

JeniFit version: same pattern, JeniFit voice:
> **"What's your age?"** *We use it to time your plan and pace your progress, nothing else.*

#### E. **Specific-date weight prediction ("by 29 May")**
JustFit shows specific calendar dates ("130 Lbs by 29 May") rather than "in 12 weeks". This is a strong commitment device.

**Why this works:** Calendar dates feel real in a way "12 weeks" doesn't. Adding a date triggers planning.

JeniFit version (and worth doing even though JeniFit isn't weight-loss-led): **a specific reachable milestone with a specific date**, e.g., "your first benchmark plank, [date]" or "your 30-day rhythm review, [date]".

#### F. **Loading screens as social-proof carousel (IMG_4944-4946)**
Three rotating frames during the "creating your personal plan" loading state, each surfacing a different proof:
- 30M+ users
- 5M+ training hours completed
- 4.8 stars / 24.8k App Store reviews

**Why this works:** Loading time becomes brand-building time. User watches numbers go up, sees scale, sees other users' commitment.

JeniFit version: Use the same pattern with JeniFit-appropriate proof points. **Don't fake them** — use whatever's true at launch (early-access list size, hours of voice-coached sessions, etc.). The format itself is the move.

#### G. **Casual "We got it!" interstitials**
After multi-step preference questions ("Choose your preferred workout type"), JustFit pops a confirmation badge:
> **"Ok, we got it!"** *We will offer you a broad suite of workouts without leaving your bed.*

**Why this works:** Acknowledges the user's input, makes a concrete promise. Two-beat interstitial that feels like a real conversation rather than a form.

#### H. **Plan-name vocabulary structure**
Every JustFit plan name follows a tight format: `[N Days] [Vibe-Verb] [Body Part / Modifier]`.
- "28 Days Bed Workouts"
- "21 Days Knee-Friendly Fat Burn"
- "7 Days Bye-bye Arm Fat"
- "14 Days Wall Pilates Sculpting"

**Why this works (the format, not the content):** Makes the entire library scannable. Sets time commitment expectation up-front. Uses one verb-y word to convey vibe.

For JeniFit, **adopt the structure with different vocabulary**:
- "7 Days · Pilates Reset"
- "21 Days · Strong Core Foundations"
- "14 Days · Slow Mornings"
- "28 Days · Anchor Your Routine"

Drop the body-part-as-fix-target framing ("Bye-bye Arm Fat", "Belly Fat Burn") in favor of practice/state framing ("Reset", "Foundations", "Anchor").

#### I. **Plan card metadata row**
Every plan card shows: `Duration · Target Area · Equipment · Level`. Compact and scannable.

JeniFit version: same metadata row, JeniFit vocabulary:
- Duration: `15-20 min`
- Focus: `Core` / `Whole-body` / `Mobility` (not "Target Area")
- Equipment: `None` / `Mat only` (not "Unnecessary Equipment")
- Pace: `Gentle` / `Steady` / `Strong` (not "Beginner / Intermediate / Advanced" — gentler)

#### J. **Body image / mindset relatability over body-shame**
Screens 4932-4937 (relatability + reward + identity) are JeniFit's wedge. JustFit only does ~30% of this work; JeniFit can do 80%.

#### K. **Section dividers ("Part 3: About you")**
JustFit divides onboarding into sections with simple typographic interstitials. Helps long flows feel less endless.

JeniFit version: keep section dividers, with JeniFit-voice section names:
- *Part 1 — Your story*
- *Part 2 — How you move now*
- *Part 3 — How you want to feel*

#### L. **Mid-flow prediction recap ("Still on track!")**
JustFit re-shows the weight prediction *twice* mid-flow (IMG_4914, 4915), each time with a confirmation badge ("Still on track!"). This reinforces commitment as the user invests more answers.

JeniFit version: at logical mid-points, show "Your plan is taking shape — [interesting fact derived from answers]. Keep going."

---

### JustFit-specific patterns to skip

These work for JustFit's bright-red, photo-heavy, casual-Gen-Z brand. **They don't fit JeniFit's dusty rose / Fraunces serif / italic accents / premium-feminine direction.**

#### 1. **Aggressive scarcity ("once it's gone, it's gone for good")**
IMG_4950's "7-Day Free Trial is Being Applied! Please don't leave this page — once it's gone, it's gone for good." Also IMG_4951's "Your Free Trial may disappear soon — try again to keep it!"

**Why skip:** Reads as anxiety-marketing. Premium-feminine brand should sell through aspiration, not loss aversion. Apple is also tightening guidelines on dark-pattern paywall copy.

#### 2. **Lottery/casino framing ("SUPER PRIZE!", "you are so lucky", "57% OFF")**
IMG_4952's discount celebration is pure casino. Crown icon, gold-foil, "Congrats! You are so lucky!"

**Why skip:** Cheapens the brand. Premium customers don't feel "lucky" to be sold to.

#### 3. **Body-part shaming labels ("Love handle", "Potbelly", "saggy skin", "Bye-bye Arm Fat")**
IMG_4901, 4902, 4940, plus dozens of plan names.

**Why skip:** JeniFit's brand promise is the opposite of this. Skip every "fix what's wrong with you" frame. Replace with strength, mobility, and feeling-anchored framing.

#### 4. **Spot-reduction promises ("All stubborn fat will shed just like this")**
IMG_4901-4902. Scientifically false and lawsuit-adjacent.

**Why skip:** Also: not how the body works. JeniFit can promise practice-led changes ("steady core strength", "mobility you can feel") without making fat-reduction claims.

#### 5. **Aggressive aesthetic-aspirational goal-Y/N triplet**
IMG_4941-4943: "Do you wanna lose weight?" / "Do you wanna get an attractive body?" / "Do you wanna farewell to chronic diseases?"

**Why skip:** Tonally jarring (casual "wanna" + clinical "chronic diseases"). Also: leading questions that the user is supposed to obviously answer "yes" to feel slightly insulting.

#### 6. **Bright red + photo-heavy visual treatment**
JustFit's whole color story is high-saturation red/pink with full-bleed body photos. JeniFit's color story is softer (dusty rose, cream, italic Fraunces serif) and probably uses photography sparingly + illustration tastefully.

**Why skip:** Visual brand mismatch. Even good copy patterns from JustFit need re-skinning.

#### 7. **"Lazy Workout System" feature name**
IMG_4951's feature list includes "Lazy Workout System". Cute for JustFit's casual-Gen-Z voice.

**Why skip:** Doesn't fit JeniFit's premium-feminine register. Use "Gentle Practice" or "Soft Start" or just don't name the feature.

#### 8. **Cross-app upsell carousel (Eato / Shuteye / Mo+)**
IMG_4960's "App From Us" promotes sister apps.

**Why skip:** JeniFit doesn't have a portfolio. Skip the pattern; if JeniFit ever launches a second product, build it as an integration not a cross-promo.

#### 9. **Broken/translated legal copy on paywall**
IMG_4949's auto-renewal text reads as poorly localized: *"Terms of Service & Privacy Policy offer a 7-day free trial/User Apple ID. If the subscription is automatically charged $79.99 for the first time one Year Cancel the subscription in your iTunes & App Store/Apple ID"*

**Why skip:** App Review will flag. JeniFit already has clean auto-renewal disclosures (per the screen audit, PaywallView writes a real sentence). Keep it.

#### 10. **5-tier reward question ("Buying new clothes", "Sharing it on the social media")**
IMG_4936's reward menu mixes performative ("Sharing it on the social media", "Taking pictures of myself") with private ("Take a personal day", "Traveling somewhere new") motivations.

**Why skip the social-media options:** JeniFit's audience leans toward private/interior reward framing. The social-share options pull toward influencer-aesthetic vibes that don't match the dusty rose / Fraunces brand.

---

### Critical reframings — every "AI" surfacing in JustFit

**Important finding from the audit:** JustFit uses **zero explicit "AI" language** across all 88 screens. There are no references to "AI coach", "AI plan", "AI-powered", "smart algorithm", or anything similar.

Personalization is consistently surfaced as:
- "We predict you'll be 130 Lbs by 29 May" — first-person plural ("we"), no algorithm named
- "REAL Personalized Plan for your unique needs"
- "Based on your answers, ..."
- "We will incorporate your goal into your personalized plan"
- "Creating your personal plan..."
- "We will filter unsuitable workouts for you"
- "Let JustFit decides" (anthropomorphism)

**This is the single most useful finding for JeniFit's anti-AI-language constraint.** JustFit demonstrates that you can market a fully algorithmic, personalization-heavy product without ever naming the algorithm. The substitution pattern is:

| AI-language phrase | Non-AI replacement (JustFit-style) |
|---|---|
| "Our AI generates your plan" | "We build your plan from your answers" |
| "AI form coach" | "Real-time form coaching" / "Live form check" |
| "Smart workout recommendations" | "Workouts picked for you" / "Your daily routine" |
| "AI-powered personalization" | "Personalized for you" / "Tailored to your routine" |
| "Machine learning adapts" | "Your plan evolves as you do" / "Gets smarter as you go" |
| "AI calorie scanning" | (N/A — Cal AI's space) |
| "AI tracks your progress" | "We track every session" / "Your progress, always tracked" |
| "Powered by AI" | (omit entirely) |

**Specific JeniFit reframings**:

The current absmaxxing copy uses "AI" repeatedly:
- Welcome subhead: `"AI plank trainer that actually makes you show up"`
- Form Education card 3: `"AI corrects your form in real time"`
- Feature Showcase: `"AI-tracked plank benchmark"` / `"AI form coaching"`
- Camera permission: `"Your AI Coach Needs to See You"`
- Plan Reveal card 3: `"AI tracks your form progress"`
- Paywall benefit row 1: `"AI form coaching"`

JeniFit replacements (cribbing JustFit's pattern):

- `"AI plank trainer that actually makes you show up"` → **"A plank practice that actually shows up with you."**
- `"AI corrects your form in real time"` → **"Your form, watched and guided in real time."**
- `"AI-tracked plank benchmark"` → **"A weekly plank check-in we track for you."**
- `"AI form coaching"` → **"Live form coaching."**
- `"Your AI Coach Needs to See You"` → **"Your coach needs to see you."** (drops the AI qualifier; the coach is *implicitly* algorithmic)
- `"AI tracks your form progress"` → **"We watch your form and chart your progress."**

The "we" framing is doing a lot of work in JustFit's copy — it makes the product feel like a partner, not a tool. JeniFit can lean into this further given its premium-feminine voice.

---

## Summary stats

- **Screens audited:** 88 (IMG_4882 → IMG_4969)
- **Onboarding screens (Section 1):** ~47 (entry → projection #2)
- **Home/main UI screens (Section 2):** ~22 (paywall → All Plans)
- **Total questions cataloged:** ~25 distinct questions across 10 categories
- **Plan names captured:** ~22 named workout plans
- **Testimonials captured:** 7 distinct user testimonials with verbatim quotes
- **AI-language references found in JustFit:** **0**
- **Paywall variants observed:** 3 (initial pricing, scarcity overlay, payment-error retry)

### Anything surprising

1. **Zero "AI" mentions across 88 screens.** JustFit is highly algorithmic (predictions, plan generation, filtering) but never names the algorithm. This is the single most actionable finding for JeniFit's anti-AI-language constraint — there's a working playbook to copy.

2. **The body-positive identity question (IMG_4937) is buried.** JustFit's strongest emotional question — "After reaching your goal weight, how would you see yourself?" with options like "Being proud of myself" / "Feel empowered" — sits late in a flow that's otherwise dominated by aesthetic-aspirational framing. JeniFit can promote this kind of question to the start of the flow and make it the anchor.

3. **The flow has two voices.** Body of onboarding is empathetic + casual ("Cool!", "We got it!", relatability statements). Paywall switches to casino/scarcity ("SUPER PRIZE", "once it's gone"). Premium brands shouldn't make this switch.

4. **"Stubborn fat will shed" + spot reduction** (IMG_4901-4902) is a hard claim presented without qualification. This is the kind of thing that can show up in App Store rejection or wellness-platform criticism. JeniFit's positioning should make zero spot-reduction promises.

5. **Loading screens triple as proof carousels** (30M users → 5M training hours → 4.8 App Store rating). Smart use of dead time. JeniFit can adopt the pattern with its own true proof points at launch.

6. **"Plus-size" is explicitly named** in plan titles ("Plus-size Weight Loss Plan", "7 Days Plus-Size Burn Fat Blitz"). Notable that JustFit calls this out rather than burying it. JeniFit can do similar inclusivity signaling without needing the "fat burn" framing.

7. **Plan name structure is rigid.** Every plan: `[N Days] [Vibe-Verb] [Body Part]`. The structure is a reusable scaffolding — JeniFit can adopt the structure and just substitute the vibe-verb vocabulary with practice-led words ("Reset", "Foundations", "Anchor", "Slow Mornings").

8. **JustFit treats "Equipment" as a constraint, not an opportunity.** Plan cards show "Unnecessary Equipment" (their phrasing for "no equipment") as a bullet point. JeniFit can flip this — equipment-light is a feature, not a missing-feature.

9. **The flexibility/cardio "tests" (IMG_4928-4929) are clever**. They're framed as benchmarks ("test your flexibility", "test your cardiorespiratory function") but functionally are perceived-effort questions. The framing makes them feel scientific. JeniFit can use the same framing for plank-hold or core-engagement self-assessment.

10. **The "We predict" → re-prediction pattern (IMG_4903 → 4914 → 4915)** is a strong commitment-escalation tool. JeniFit can use the same shape: show a prediction early, refine it as you collect answers, end with "Based on your answers, here's your plan starting [date]."

---

**End of audit document.**
