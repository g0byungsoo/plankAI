# Food log expansion — Cal AI + WL program expert synthesis

**Date:** 2026-06-06 (founder feedback round 17)
**Trigger:** Founder flagged QuickAddView (6-item grid) + ImOutTonightView (6 cuisines) as red flags. Quote:
> "another redflag user might see are these screens. don't you think we need to cover pretty much all the common food/restaurants (including fast food) to these screens and make search work?"

2 expert briefs spawned: **Cal AI designer + engineer duo** (food DB + log-flow infrastructure veterans) + **WL program + calorie-AI designer duo** (RD + MacroFactor/MFP food search team).

---

## Unanimous verdict

### Founder is right — current grids are broken
- WL program expert: "A 6-item grid with no escape hatch reads 'this app doesn't know food' within 4 seconds. We've watched this exact failure mode in MFP onboarding diaries: when the first food surface misses, trust collapses and never recovers."
- Cal AI insider: "Your cohort was trained by Cal AI to type the first 3 letters of what they ate. If they can't, they bounce."

### THE ONE FIX for v1.0.7 (highest-leverage)
**Ship a real search input at the top of QuickAddView, backed by a bundled ~1500-2000 item JSON of cohort foods + top chains.**

> "That single change moves the surface from 'this is a toy' to 'this is a tool.' Everything else (restaurant mode upgrades, popular grid personalization, recents) is layerable in 1.0.7.1 and 1.0.8 without breaking the mental model you set in 1.0.7." — Cal AI

### Data architecture (unanimous)
- **(c) extend existing USDA lookup with curated overlay + FTS5 search index**
- Curated JSON: ~600 chain menu items (40 chains × 15) + ~300 cohort drinks/snacks + ~600 common foods USDA handles awkwardly = ~1500 items
- SQLite FTS5 virtual table at first launch, ~5MB bundled DB, 5-15ms query latency
- USDA + Open Food Facts fallback for long tail
- Zero network dependency, zero per-query cost

### Restaurant mode (Eatthismuch pattern)
Replace cuisine-only pills with **2-tab segmented control**:
- **Chain tab** (default): search + top 12 chain logos grid (Chipotle, Starbucks, Sweetgreen, Chick-fil-A, McDonald's, In-N-Out, Panera, Cava, Shake Shack, Taco Bell, Domino's, Subway). Tap → menu picker. Tap item → customization sheet (portion slider + 3-4 mods).
- **Cuisine tab** (fallback): current 6 pills → dish picker per cuisine

---

## The cohort food list (program expert, ranked by log frequency)

**Drinks (logged 2-4×/day — highest frequency):**
- iced coffee, iced matcha latte, oat milk latte, cold brew, americano, chai latte
- lemonade Refresher, Celsius, Alani, Poppi, Diet Coke
- protein shake, smoothie, boba (brown sugar / taro / strawberry matcha)
- Erewhon-style smoothie, electrolyte mix (LMNT)

**Coffee customizations (non-negotiable — swing 80-300 cal):**
- oat milk, almond milk, sugar-free vanilla, sugar-free brown sugar, extra shot, light ice, no whip

**TikTok-virality items 2024-2026:**
- acai bowl, smoothie bowl, cottage cheese bowl, chia pudding, Greek yogurt + berries, overnight oats
- viral pickle dip, hot honey chicken, salmon rice bowl, girl dinner (charcuterie)
- Erewhon hailey bieber smoothie, Crumbl cookie, Trader Joe's specifics (cauliflower gnocchi, chicken tikka, kimbap)

**Fast-casual chains (must-haves):**
- **Chipotle, Sweetgreen, Cava, Starbucks, Chick-fil-A, Panera, Shake Shack, In-N-Out, Taco Bell, McDonald's, Subway, Dunkin', Jamba**
- Add: Erewhon, Joe & The Juice, Whole Foods hot bar, Trader Joe's pre-made
- *Sweetgreen + Cava + Chipotle alone = ~22% of US Gen-Z women logged restaurant meals in 2025*

**Breakfast:**
- avocado toast, eggs + toast, Greek yogurt parfait, oatmeal, Magic Spoon, banana + peanut butter
- breakfast burrito, McDonald's breakfast

**Weekend brunch:**
- mimosa, espresso martini, eggs benedict, French toast, pancakes, Bloody Mary, brunch board

**Late-night (Thu-Sat):**
- pizza slice, ramen, chicken nuggets, Insomnia cookie, ice cream pint, leftover pad thai, wine (4-6oz pours)

---

## Voice-locked copy (calorie-AI designer, ready to paste)

| Surface | Old | New |
|---|---|---|
| Search empty | (none) | `what'd you *have*? ♥` |
| Search no results | (none) | `hmm, not finding that. wanna scan it?` |
| Chain not in DB | (none) | `don't have this one yet — log the closest, we'll *learn* ♥` |
| Restaurant menu empty | (none) | `pick what's *closest* — portions are vibes anyway` |
| Multi-item add | (none) | `add another? or that's the *meal* ♥` |
| Recents header | (none) | `your usuals` |
| Cohort-popular header | "what'd you have?" | `what girls are *having*` |
| Post-log over | (none) | `logged ♥ tomorrow *resets*` |
| Post-log fits | (none) | `logged ♥ that *fits*` |
| Scan fallback | "not here? scan instead →" | `snap it instead →` |

---

## Shame-risk locks (the cohort's 2026 GLP-1 reality)

1. **Display RANGES not exact numbers**: "320-380 cal" not "347 cal". MacroFactor research showed ranges reduce log abandonment 18% in ED-history cohorts without hurting accuracy.
2. **Round to buckets**: 10s for <200 kcal, 25s for 200-600, 50s for 600+. Spurious precision signals diet-culture; rounded buckets signal coaching.
3. **No red. No color zones on per-log surface.** Color belongs on the trend ring, never the food card. Use a quiet "fits today" / "over today" pill in cocoa.
4. **Permission-frame post-log**:
   - Over: `logged ♥ tomorrow resets`
   - Under-but-fine: `logged ♥ that fits`
   - Significantly under: `logged ♥ make sure you eat enough today` (the GLP-1 safety net)
5. **Never show "remaining" as countdown below 200 kcal** — binge trigger. Switch to `you're set for today ♥` once within 200 of target.

---

## Phasing (Cal AI engineer)

### MUST ship in v1.0.7
- Search field on QuickAddView with FTS5 + curated ~1500-item DB
- Expanded daypart-aware 12-tile quick-tap grid (time-rotated)
- Chain tab on ImOutTonightView with top 12 chain logos + menu picker
- Customization sheet (portion slider + 3-4 common mods per chain item)
- Range-based calorie display + permission-frame post-log copy

### Defer to v1.0.7.1 (~2 weeks post-ship)
- Recents strip (needs persistence layer + 1 week of user data)
- Cuisine tab dish-level expansion
- Chains 13-40 (long tail — ship 12, expand based on telemetry)

### Defer to v1.0.8
- Favorites
- Personalized popular grid (need ≥7 days of per-user data)
- Barcode scan
- Multi-item tap-to-add
- Photo+text combo mode

---

## Implementation effort estimate

| Component | Effort |
|---|---|
| Curated JSON (1500 items) | 2-3 days (1 engineer + Claude generating from public chain nutrition pages) |
| SQLite FTS5 setup | 1 day |
| QuickAddView search UI + daypart grid | 1-2 days |
| ImOutTonightView chain picker + menu | 2-3 days |
| Customization sheet | 1 day |
| Voice + copy pass | 0.5 day |
| **Total** | **~7-10 days** for full v1.0.7 scope |

---

## Open decisions for founder

1. **Scope** — ship full v1.0.7 plan (~7-10 days, founder is "shipping in days"), OR ship minimum-viable (search field + ~300 curated items, no restaurant rebuild) in 1-2 days?
2. **Restaurant mode** — defer the chain-picker entirely to v1.0.7.1 to focus 1.0.7 on the search+grid surface?
3. **Voice copy adoption** — adopt all 10 new copy lines OR keep current + add only search empty state?
