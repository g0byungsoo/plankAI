# Breathwork apps teardown — intro → session → end (2026-06-11)

Category study (Breathwrk, Othership, Open, Oak, Balance, Calm, Headspace,
Apple Mindfulness, Wim Hof) → design spec for JeniFit's three breathwork
screens. Grounded against current code: `BreathworkSessionView`, `BreathCircle`,
`BreathLibraryView`, `BreathworkPrimerView`, `BreathworkState`, and the
PlanView `.breathSession` cover (which today mounts the session directly —
no intro, no choice, hardcoded `.calming`).

---

## 1. Per-app teardown

| App | Intro / pre-session | Protocol selection | In-session | End screen |
|---|---|---|---|---|
| **Breathwrk** | Exercise detail card: pattern visualized as timed segments, duration + voice/haptic/sound toggles, one "start" tap. ~5s settle countdown before breath 1. | 5 use-case categories (Calming / Nighttime / Energizing / Performance / Health), 50+ exercises. Browse = library; daily user = quick-start row on home. | The signature: per-phase **haptic patterns** (distinct buzz for inhale / hold / exhale) so it works eyes-closed or in-pocket. Expanding bar/orb + count. | Light: completion stamp, streak tick, suggested next exercise. No mood quiz on short exercises. |
| **Othership** | "How do you want to feel?" → mood pick, then guide + guidance level (Full/Minimal) + duration before play. ~3 taps. | Feeling-first taxonomy (Calm Down / Wind Down / Power Up), 500+ sessions. Choice-paralysis managed by daily featured pick. | Audio-led journeys (voice + music are the product); visual is secondary ambient gradient. | Emotional check-out + community framing ("breathed with N others"), save/favorite. |
| **Open** | Minimal: session card (instructor, length, music) → play. No occasion quiz. | 4 pillars (Meditate / Breathe / Move / Sound); editorial daily picks over taxonomy. | Hypnotic color-shifting **orb**, premium music (Kaytranada etc.), instructor voice. | Quiet: streak + minutes, next-class tee-up. Luxury restraint — closest tonal sibling to JeniFit. |
| **Oak** | Config screen: length + sound + breath style; no narrative intro. | 3 fixed exercises (Deep Calm / Box / Awake). Tiny menu = zero paralysis. | Simple expanding circle + counts. | Growth metaphor: your oak tree grows; badges, totals. Celebration lives on home, not the end screen. |
| **Balance** | 1-2 personalization questions before most sessions ("how are you feeling?") feeding recommendations. | Plan-led: the app picks today's session; library is secondary. | Voice coach + minimal visual. | **Post-session feedback question** (trains personalization); long-term stats deliberately moved OFF the completion screen to keep it focused. |
| **Calm** | Breathe Bubble opens instantly; style + speed adjustable in-place. | 6 named visual modes (Relax / Balance / Restore / Focus / Energize / Unwind) as a wheel — pick = start. | The iconic bubble; speed control mid-session. | Check-in (mood/gratitude) is app-level, not forced post-breath. |
| **Headspace** | Short animated explainer the first time; afterwards straight in. | SOS / "breathers" surfaced by moment (panic, stress). | Animated circle + character warmth. | Run-streak + "how was that?" thumbs; warm illustration. |
| **Apple Mindfulness** | None — crown to adjust minutes, tap = start. The daily-user ceiling: **0-tap intro**. | One protocol (Breathe) + Reflect. Breaths/min in settings, not in flow. | Flower bloom + **haptic taps on inhale cue** (None/Minimal/Prominent). | Summary: time, breaths, **heart rate** — physiological receipt, zero confetti. |
| **Wim Hof** | Safety gate (first run), then rounds/breaths/tempo config. | One method; customization = depth, not breadth. | Bubble + counted breaths + retention timer, Wim's voice on final breaths, 2025 added haptics. | Retention-time table per round — data as the reward; share for the community. |

### Category laws (what the winners converge on)
1. **Intro is a protocol card, not a lobby.** Pattern visualized + duration + one start tap. Education ≠ intro; education is a separate, once-ever surface (JeniFit already has this: the primer).
2. **Feeling-first selection beats technique-first.** "How do you want to feel" (Othership) outperforms "pick 4-7-8 vs box." 3-5 occasions max; always a pre-selected default so choosing is optional.
3. **A settle beat (~3-5s) before breath 1** is mandatory — every app inserts it. JeniFit's 4s hold already does this. Keep.
4. **Haptics are the moat feature** (Breathwrk's brand, Apple's default, WHM's 2025 addition). JeniFit's BreathCircle pulse-train + apex punctuation is already category-competitive — the gap is per-protocol differentiation, not existence.
5. **End screens are receipts, not parties.** Time, a physiological note, a habit tick, a soft next step. Balance explicitly moves long-term stats off this screen. Nobody fires fireworks for 1-5 min of breathing.
6. **Returning users get a collapse.** Apple = 0 taps, Breathwrk = quick-start. First-timer flow ≠ day-30 flow.

---

## 2. JeniFit synthesis — the three screens

Register everywhere: cream `bgPrimary`, Fraunces serif heroes with one italic
punch word, lowercase casual, cocoa CTA pill, ≤2 stickers (this is a quiet
surface — scatter-free per the scatter-milestone rule), anti-shame copy.

### Screen 1 — intro ("the breath card")
Replaces both straight-in PlanView mounting AND the expandable-card library as
the default entry. One card, default protocol pre-selected by occasion chips
(default-with-swap, Calm-wheel speed of entry, Othership feeling language).
The ~4 occasion-mapped protocols from the science brief slot into the chips;
science stays one tap away (ⓘ → existing why/citation block), never blocking.

```
┌─────────────────────────────────────┐
│                                  ✕  │
│  BREATHE                            │   eyebrow, accent
│  how do you want to *feel*?         │   Fraunces 34pt, italic punch
│                                     │
│  (settled)  calm   sleepy   steady  │   chips; 1st pre-selected,
│                                     │   lowercase, accentSubtle fill
│  ┌───────────────────────────────┐  │
│  │  slow exhale          ⓘ      │  │   protocol card (scrapbook chrome)
│  │  [ IN 4 ][   OUT 6      ]     │  │   existing rhythm bar, proportional
│  │  ~2 minutes · no holds        │  │   duration from protocol, honest
│  └───────────────────────────────┘  │
│                                     │
│  sit anywhere. drop your shoulders. │   one settle line, textSecondary
│                                     │
│  ╭─────────────────────────────╮    │
│  │          begin              │    │   cocoa pill, full width
│  ╰─────────────────────────────╯    │
│        2 min ▾  (1 · 2 · 5)         │   quiet duration link → 3 options;
└─────────────────────────────────────┘   5 min = the Balban-cited dose
```

- Chip tap swaps the card content with `crossFade`; no navigation.
- Duration: keep 1-min as the floor (low-friction promise) but offer 2 and 5;
  cycles derive from protocol seconds. Today's fixed ~60s undersells the
  science the app itself cites (Balban = 5 min/day).
- Ideal cost: returning user 1 tap (begin), first-timer ~2 (chip + begin).
- PlanView `.breathSession` routes HERE with the day's prescribed occasion
  pre-selected; X never marks the plan row complete.

### Screen 2 — session (keep the bloom, four upgrades)
BreathCircle (painted torus + scale + countdown-in-hollow + serif phase word
+ pulse-train haptics + lo-fi bed) already matches the best in category. Keep
all of it. Upgrades:

1. **Cycle progress, quiet**: a row of tiny dots under the phase word
   (`· · ● ○ ○ ○`), filled per completed cycle. Kills "how much longer?"
   without a clock. (Wim Hof rounds / Breathwrk segments pattern.)
2. **Per-protocol haptic identity** (Breathwrk's moat, cheap here): keep
   0.55s/0.75s pulses for the calm protocol; equal 0.6s/0.6s for balanced;
   slightly brisker 0.45s/0.45s for the energizing one. Apex/bottom `.medium()`
   punctuation stays universal. Reduce-motion already drops all of it. If a
   hold-phase protocol ships, hold = silence between two punctuations
   (extends BreathCircle's state, reserved exactly as the code comment notes).
3. **Last-cycle cue**: final exhale swaps the word to "last one, let it go"
   (WHM's final-breath voice moment, done as text). Ends the session with
   intention instead of an abrupt stop.
4. **Early exit stays kind, and counts**: keep the confirm dialog + its copy.
   Add: if ≥half the cycles finished, record the completion anyway and say so
   in the dialog ("you breathed enough. this still counts."). Anti-shame:
   leaving early is never a zero.
   Mute toggle (music/voice) joins the X in the top bar — Breathwrk-style
   sensory control, currently missing.

### Screen 3 — end ("the receipt")
Sibling of PostSessionView, at ~30% of its celebration weight: same scrapbook
chrome + serif headline + stat language, but NO fireworks, NO Lottie, NO share,
2 stickers max. A 2-minute breath earns a warm receipt, not a party — the
contrast keeps workout completions feeling big.

```
┌─────────────────────────────────────┐
│              ♡ (sticker, 1)         │
│        that's your body             │
│        *settling*.                  │   Fraunces 28pt, italic punch
│                                     │
│   your long exhale just told your   │   physiological recap, one line,
│   nervous system it's safe.         │   mechanism-true (cortisol claim
│                                     │   lives in the primer, not here)
│  ┌───────────────────────────────┐  │
│  │  this week   ● ● ○ ● ○ ○ ○    │  │   7-dot strip (reuse bento dots)
│  │  3 breaths · 2 quiet minutes  │  │   real BreathworkState data only
│  └───────────────────────────────┘  │
│                                     │
│   how do you feel?                  │   optional 1-tap, skippable:
│   (calmer)  (the same)  (not yet)   │   every answer accepted — "the
│                                     │   same" replies "that's honest.
│  ╭─────────────────────────────╮    │   it still counted." feeds
│  │           done              │    │   protocol recs later (Balance)
│  ╰─────────────────────────────╯    │
│        once more, slower            │   quiet repeat link (Oak "again");
└─────────────────────────────────────┘   Plan entry adds "back to today"
```

- Data provenance: week dots + totals come from `BreathworkState`
  (weekDayKeys / totalCompleted). No heart rate, no calories, no breaths-per-
  minute claims — nothing we don't measure.
- The check-in is the only new datum; store locally next to BreathworkState,
  skip = no nag, never shown as a streak.
- Keep the Day-1 PostPurchase variant's "ready to move" CTA only in that flow;
  home/plan entries end at done/again (matches current no-handoff decision).

---

## 3. First-time vs returning collapse rule

| State | Flow | Time to breath 1 |
|---|---|---|
| 0 completions | primer (science, once ever) → intro → session | ~60-90s, by design |
| 1-2 completions | intro, default chip = last used | ~8s |
| ≥3 completions | **quick-start**: home card tap → session directly with last protocol + duration; settle hold shortened 4s → 2s. Intro reachable via a small "change" link on the card (or the chips render for 1.5s as a passing header before auto-collapse). | **<3s** |

- The collapse keys off `BreathworkState.totalCompleted` (already persisted) +
  a `lastProtocolId` / `lastDuration` pair (new, UserDefaults).
- Plan-prescribed days override quick-start's protocol with the day's occasion
  but keep the collapsed speed.
- If the user hasn't breathed in ≥14 days, fall back one tier (show the intro
  again) — re-orientation without re-education.

Sources: [Breathwrk review](https://www.choosingtherapy.com/breathwrk-app-review/) · [Breathwrk](https://www.breathwrk.com/) · [Othership QA teardown](https://bugcrawl.qawerk.com/no-bugs-found/othership-guided-breathwork-for-android/) · [Open showcase](https://screensdesign.com/showcase/open-breathwork-meditation) · [Oak](https://www.oakmeditation.com/) · [Balance showcase](https://screensdesign.com/showcase/balance-meditation-sleep) · [Balance review](https://www.choosingtherapy.com/balance-meditation-app-review/) · [Apple Watch Breathe](https://support.apple.com/guide/watch/start-a-reflect-or-breathe-session-apd371dfe3d7/watchos) · [Wim Hof app](https://www.wimhofmethod.com/wim-hof-method-mobile-app) · [Breethe comparison](https://breethe.com/sleep-and-meditation-app-guide/compare-evaluate/how-breethes-breathing-exercises-stack-up-against-calm-and-headspace)
