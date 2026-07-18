# app v6.2 — THE COACH LAYER (cohesion, 2026-07-17)

Founder brief: the features are individually good but don't feel like
ONE experience; the user's real question at every surface is "so what
does this mean for my weight loss journey / my body?" The product she
can't afford is a human coach — the app should feel like one.

## What human coaches / telehealth programs actually do

From the coaching + telehealth literature
([telemedicine coaching RCT](https://pubmed.ncbi.nlm.nih.gov/29199544/),
[telehealth coaching + device adherence](https://pmc.ncbi.nlm.nih.gov/articles/PMC7071022/),
[MI in weight management](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4858594/)):

1. **Weekly cadence, data-driven topics** — sessions keyed to HER
   week of numbers, not a curriculum calendar. (The app already has
   this: the re-signing.)
2. **Data is contextualized, never just displayed** — the coach's
   core move is collaborative interpretation: fact → "which means,
   for you…". Data without reflection doesn't change behavior.
3. **Feedback ties behavior to the goal** — behavior-change
   technique "feedback on behavior" links what she did to what her
   body did.
4. **One continuous voice** — the same person reads everything;
   nothing arrives uninterpreted.

## What shipped (v6.2)

- **BodyLine** (`Signals.swift` + 4 tests) — the "so what" engine.
  Every signal page can compose a "for your body" line. LAWS:
  juxtaposition never causation ("·", "alongside", "with it" —
  never "because"); the trend is borrowed ONLY when established
  (3+ weigh-ins / 5+ days) AND genuinely eased (≤ −0.09 kg) — a
  rising trend never pairs with her habits (that's blame); mechanism
  lines carry no numerals so suppression falls out naturally.
- **JKBodyLine + JKStatTriplet** — the meaning line (rose "FOR YOUR
  BODY" kicker + serif italic) and the 2-3-column stat row (the
  weight page's started/now/goal grammar, promoted app-wide). All
  six signal pages now read: figure → stats → meaning → mechanism.
- **The reading synthesizes signals** (`DailyBriefEngine` 5.2-5.4):
  short-night care ("you slept 5h 48m. hunger runs louder on days
  like this"), the season spoken by the coach, and the synthesis
  line when two signals are strong on one morning ("13 quiet hours
  and 7h 41m of sleep. today starts on your side"). Priorities sit
  below trend/weigh-in, above the steps ack.
- **jeni-chat knows the signals** (`CoachContextAssembler` →
  `signals` block: window hours, slept hours, season word) — the
  desk and the tabs can never disagree.
- **Home material** — `JKSectionSeam` (tracked caps over a hairline
  rule, optional trailing detail: "2 plates", "auto-noticed")
  replaces floating captions; THE ONE THING card gains the top-lit
  specular material (the chat cards' paper-glass treatment adapted
  to the cocoa hero). Stickers untouched (founder-locked identity).

## Held for next round

- The method reader's deeper iteration (JFContinueButton is shared
  with founder-signed onboarding — material change needs its own
  pass); a lesson-end body line tying the day's rep to her plan.
- The weekly review referencing the signal week ("your windows held
  near 12h — keeping your evenings as they are") — the re-signing
  is the natural home for signal-informed proposals.
- A "coach's summary" page closing the becoming pager (everything
  above, synthesized in one letter) — candidate to replace/merge
  with the from-jeni page.
