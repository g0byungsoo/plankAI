# Per-cohort notification preview

**Date:** 2026-06-16
**Source spec:** `docs/notification_system_spec_2026_06_16.md`
**Purpose:** founder review of every push every cohort will receive, in timeline order, before shipping copy changes.

## Variables in the copy

- `{opener}` = `"{userName}, "` (lowercased) when set; `""` otherwise. Example: `"han, "`
- `{n}` = integer count (shown-up days or program days)
- `{coachName}` = Jeni / Sam / Kira based on `voicePreference` (encouraging/balanced/firm)
- `{hh:mm}` = literal trial conversion time, e.g. `"2:14pm"`
- `{tail}` = `" {name}"` when name set, `""` otherwise (milestones)

---

## 🅰️ Cohort A — `generalWL` (default; "none" / "prefer_not_say" / never answered)

### Trial week (Days 0-3)

**Day 0 (install day)** — onboarding completes, permission prompt fires. **No JeniFit push fires.**

**Day 1** — *bucket-hour, if shownUp == 0:*
- 🆕 **Day 1 morning push**
- Title: *your first morning here.*
- Body: `{opener}five minutes today. that's how the rhythm begins ♥`

**Day 1** — *if Mon/Wed/Fri at bucket-hour (voice-dependent body):*
- 🔄 **Daily reminder** (encouraging voice)
- Title: *five minutes, today.*
- Body: `{opener}small moves still count. they always have ♥`
- (Balanced: `{opener}sam picked a short one. open when you can.`)
- (Firm: `{opener}kira's got a short one ready.`)

**Day 2** — *evening bucket-hour, if shownUp == 0:*
- 🆕 **Day 2 value-spotlight**
- Title: *the door's still open.*
- Body: `{opener}a five-minute breath card is the softest way in.`

**Day 2** — *if Mon/Wed/Fri at bucket-hour:* same Daily reminder as Day 1

**Day 3 (trial-end day)** — *no daily reminder today, intentionally silent on morning*

**Day 3 T-30h** — *if shownUp < 2:*
- 🆕 **Pre-trial soft tap**
- Title: *still here for you.*
- Body: `{opener}a five-minute breath card is enough to feel like you ♥`

**Day 3 T-24h** — *one of three branches based on shownUp:*

If shownUp ≥ 2 (celebration):
- 🔄 **Trial-end celebration**
- Title: *look how far you've come.*
- Body: `you've shown up {n} times ♥ your trial becomes a membership tomorrow. manage anytime in iOS settings.`

If shownUp == 1 (middle):
- 🆕 **Trial-end middle**
- Title: *your trial wraps tomorrow.*
- Body: `you showed up once ♥ the door stays open. manage anytime in iOS settings.`

If shownUp == 0 (cold-zone rewrite):
- 🔄 **Trial-end cold-zone**
- Title: *the rhythm is here when you are.*
- Body: `your trial converts tomorrow. five minutes is enough to begin. manage anytime in iOS settings.`

**Day 3 T-2h** — *universal, always fires:*
- 🆕 **Trial-end disclosure**
- Title: *quick note ♥*
- Body: `your trial converts at {hh:mm}. manage anytime in iOS settings.`

### Post-conversion (Days 4-30+)

**Day 5** — *if converted on annual or quarterly AND shownUp > 0:*
- 🆕 **Day 5 anti-refund**
- Title: *five days in ♥*
- Body: `you've shown up {n} times since you joined. small moves still count.`

All other steady-state pushes — see Universal section.

---

## 🅱️ Cohort B — `onGlp1` (answered "current")

### Trial week

**Day 0** — silent

**Day 1 morning push** *(if shownUp == 0):*
- Title: *the work alongside the shot.*
- Body: `{opener}today's the day you start the daily piece ♥`

**Day 1 daily reminder** *(if Mon/Wed/Fri)* — same as Cohort A (daily reminder is voice-personalized, not cohort-routed)

**Day 2 value-spotlight** *(if shownUp == 0):*
- Title: *the lessons are waiting.*
- Body: `{opener}the protein floor + food noise piece. five minutes ♥`

**Day 2 daily reminder** *(if Mon/Wed/Fri)* — same as Cohort A

**Day 3 T-30h pre-trial soft tap** *(if shownUp < 2):*
- Title: *the daily piece is yours.*
- Body: `{opener}five minutes today. the layer underneath the shot ♥`

**Day 3 T-24h** — *three branches:*

If shownUp ≥ 2:
- Title: *look how far you've come.*
- Body: `you've shown up {n} times for the daily piece ♥ your trial becomes a membership tomorrow. manage anytime in iOS settings.`

If shownUp == 1:
- Title: *your trial wraps tomorrow.*
- Body: `you started the daily piece. it's yours tomorrow ♥ manage anytime in iOS settings.`

If shownUp == 0:
- Title: *the daily piece, alongside the shot.*
- Body: `the protein floor, the food noise quieting, the breath cards. yours tomorrow. manage anytime in iOS settings.`

**Day 3 T-2h** — same universal disclosure push as Cohort A.

### Post-conversion

**Day 5 anti-refund** *(annual/quarterly only, if shownUp > 0):*
- Title: *five days in ♥*
- Body: `the daily piece is taking shape. {n} times shown up so far ♥`

---

## 🅲️ Cohort C — `postGlp1` (answered "past")

### Trial week

**Day 0** — silent

**Day 1 morning push** *(if shownUp == 0):*
- Title: *the rhythm that keeps it.*
- Body: `{opener}five minutes today. that's how the keep-it-off habit starts ♥`

**Day 2 value-spotlight** *(if shownUp == 0):*
- Title: *the keep-it-off lessons.*
- Body: `{opener}the rhythm that holds. five minutes when you can ♥`

**Day 3 T-30h soft tap** *(if shownUp < 2):*
- Title: *the rhythm is yours.*
- Body: `{opener}five minutes today. the keep-it-off piece begins when you do ♥`

**Day 3 T-24h** — *three branches:*

If shownUp ≥ 2:
- Title: *look how far you've come.*
- Body: `you've shown up {n} times for the keep-it-off rhythm ♥ your trial becomes a membership tomorrow. manage anytime in iOS settings.`

If shownUp == 1:
- Title: *your trial wraps tomorrow.*
- Body: `you started the rhythm. it's yours tomorrow ♥ manage anytime in iOS settings.`

If shownUp == 0:
- Title: *the keep-it-off rhythm, ready.*
- Body: `the post-shot rhythm, the protein floor, the daily piece. yours tomorrow. manage anytime in iOS settings.`

### Post-conversion

**Day 5 anti-refund** *(annual/quarterly only, if shownUp > 0):*
- Title: *five days in ♥*
- Body: `the rhythm is forming. {n} times shown up so far ♥`

---

## 🅳️ Cohort D — `considering` (answered "considering")

### Trial week

**Day 0** — silent

**Day 1 morning push** *(if shownUp == 0):*
- Title: *the daily piece, day one.*
- Body: `{opener}five minutes today. begin where you are ♥`

**Day 2 value-spotlight** *(if shownUp == 0):*
- Title: *your five minutes.*
- Body: `{opener}breath card, plate check. the daily piece begins when you do ♥`

**Day 3 T-30h soft tap** *(if shownUp < 2):*
- Title: *the daily piece, ready.*
- Body: `{opener}five minutes is enough to feel the shape of it ♥`

**Day 3 T-24h** — *three branches:*

If shownUp ≥ 2:
- Title: *look how far you've come.*
- Body: `you've shown up {n} times for the daily piece ♥ your trial becomes a membership tomorrow. manage anytime in iOS settings.`

If shownUp == 1:
- Title: *your trial wraps tomorrow.*
- Body: `you started the daily piece. it's yours tomorrow ♥ manage anytime in iOS settings.`

If shownUp == 0:
- Title: *the daily piece, ready.*
- Body: `the breath cards, the protein floor, the food noise piece. yours tomorrow. manage anytime in iOS settings.`

### Post-conversion

**Day 5 anti-refund** *(annual/quarterly only, if shownUp > 0):*
- Title: *five days in ♥*
- Body: `you're {n} days into the daily piece ♥`

---

## 🌐 Universal pushes (same for all 4 cohorts)

### Daily reminder (post-week-1, daily; voice-routed, not cohort-routed)

Titles rotate every other day:
- *five minutes, today.*
- *today's gentle one.*
- *tap in when you can.*

Bodies rotate from 4-line pool per `voicePreference`:

**Encouraging (Jeni):**
1. `{opener}five minutes is enough today. small moves still count.`
2. `{opener}come back to the rhythm. today's a soft one ♥`
3. `{opener}the version of you that shows up is already winning.`
4. `{opener}five minutes. that's the whole ask today.`

**Balanced (Sam):**
1. `{opener}sam picked a short one. easy to begin.`
2. `{opener}a five-minute breath card is waiting today.`
3. `{opener}today's short. open when you have a moment.`
4. `{opener}sam's got a quiet one ready.`

**Firm (Kira):**
1. `{opener}kira's got a short one ready today.`
2. `{opener}today's a tap-in day. five minutes.`
3. `{opener}kira chose short. show up when you can.`
4. `{opener}five minutes. then you're done for today.`

### Affirmations — Tue + Sat, bucket-hour, post week 1 only

Title: *a note from {coachName}.*

Body — picked from this library, rotated:

The "becoming-line" is personalized to her `identityFeeling` onboarding answer:
- "powerful" / "strong" → `you're becoming someone strong.`
- "calm" → `you're becoming someone steady ♥`
- "light" → `you're becoming someone light on her feet.`
- "radiant" → `you're becoming someone who glows ♥`
- default → `you're becoming someone who shows up.`

Plus this rotating pool:
1. `small moves still count. they always have ♥`
2. `you don't have to feel ready. you just have to begin.`
3. `the version of you that shows up is already winning.`
4. `progress is quiet. you're making it anyway.`
5. `be gentle with yourself today ♥`
6. `{name}, today's a good day to be soft on yourself.`
7. `the woman who came back is already the woman you wanted.`
8. `five minutes still counts. it always did ♥`

### Evening Plate Review — daily, bucket-tuned (~8:30pm)

Gated: skip if zero meals logged today, skip if "today's plate" view opened in last 3h, skip entirely during trial week 1.

Title: *today's plate ♥*

Body rotation:
1. `a soft look back. tap in when you're ready.`
2. `the day fits when you flip through it ♥`
3. `today's plate is here when you are.`

### Milestones — at 3 / 7 / 14 / 30 / 50 / 100 shown-up days

Title: *a little milestone.*

- Day 3: `three days in{tail}. you're building something ♥`
- Day 7: `you've shown up seven times{tail}. that's who you are now.`
- Day 14: `two weeks of showing up{tail}. look at you ♥`
- Day 30: `thirty days{tail}. this isn't a phase anymore. it's you.`
- Day 50: `fifty times{tail}. quietly, you became someone consistent.`
- Day 100: `one hundred{tail}. you're not the same person as day one ♥`

### Win-back — re-armed every session, fires after 3 days quiet

Title: *still here for you.*

Body rotation:
1. `{opener}one slip doesn't undo you. a short one's still here when you are ♥`
2. `{opener}no catching up needed. just come back when you can.`
3. `{opener}five minutes is enough to feel like you ♥`
4. `{opener}the door's still open. tap in when you're ready ♥`

### Sunday recap — Sunday 5pm (or bucket-hour Sunday if Q#8 confirmed)

Gated: week must have earned ≥2 engaged days.

Title: *your week, kept.*
Body: `the recap is ready. {n} days. quiet ones still count ♥`

---

## Scenarios at a glance

| Scenario | Pushes received during 3-day trial |
|---|---|
| Engaged (saves session by Day 1) | Daily reminder Mon/Wed/Fri (1-2x) + Trial-end T-24h celebration + Trial-end T-2h disclosure = **3-4 pushes** |
| Ambivalent (shownUp == 1) | Daily reminder + Day 2 value-spotlight + Pre-trial soft tap + Trial-end T-24h middle + Trial-end T-2h disclosure = **4-5 pushes** |
| Disengaged (shownUp == 0) | Day 1 morning + Daily reminder + Day 2 value-spotlight + Pre-trial soft tap + Trial-end T-24h cold + Trial-end T-2h disclosure = **5-6 pushes** |

All scenarios under the 5/wk Airbridge ceiling for trial week 1.
