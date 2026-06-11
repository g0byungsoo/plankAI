# her75 typeface spec — identification + exact copy plan (2026-06-10)

Senior-typeface-designer pass. Method: pixel side-by-side of all 5 her75 reference
shots against rendered candidates (Playfair Display @560/650, new Playfair var
@opsz300, DM Serif Display, Fraunces opsz144 SOFT0 WONK0, Bodoni Moda opsz48/600 +
opsz11/700, iOS system Didot, iOS Bodoni 72). Proof composites at
`/tmp/compare_become.png`, `/tmp/compare_follow.png`, `/tmp/final_proof.png`.

## 1. Identification: her75 uses **Playfair Display** (free, OFL)

Not Saol, not Canela, not Lust, not Didot. Smoking-gun glyphs, all verified at
pixel level against the App Store shots:

- **Italic `w`** in "Follo*w*" — double-loop cursive w whose final stroke closes
  into a loop and ends in a **ball terminal**. That exact w exists in Playfair
  Display Italic and in none of the commercial fashion didones (Saol's w is open;
  Lust's is a swash flourish; Didot's is rigid).
- **Italic `g`** in "*girl*" — single-story g with a long sweeping descender loop
  terminating in a ball. Identical structure in Playfair Italic.
- **Italic `B`** in "*B*ecome" — thin entry stroke, two unequal bowls, curved foot.
  Match.
- Roman: ball terminals on e/c/r/f, flat minimally-bracketed hairline serifs,
  large x-height (~0.51 em), moderate-high contrast (NOT razor didone hairlines —
  this is why the Bodoni Moda copy felt wrong on sight).
- Weight: between SemiBold and Bold (our 650 instance matched the marketing
  color exactly; 560 was visibly too light).
- Their marketing sites don't expose it (her75.app webfonts = Inter + Source
  Serif 4; the screenshots are set in design tooling), but the letterform
  evidence is conclusive. her75 is an indie app using a free Google Font with
  tight tracking. We can copy it **exactly**, at zero license cost.

## 2. Why Bodoni Moda opsz48/wght600 failed (so we never repeat it)

1. **Hairline collapse** — opsz 48 pushes thin:thick past 1:10; at 38–40 pt the
   thins anti-alias to sub-pixel grey on Retina → "scratchy/brittle".
2. **Rationalist skeleton** — compass-perfect bowls, strictly vertical stress,
   unbracketed slab-flat serifs. Reads "engraved 1790 invitation", not fashion-
   editorial. her75's face has warmth: bracketed joins + prominent ball terminals.
3. **Small x-height** (0.46 em vs Playfair 0.514) + long ascenders → looks a size
   smaller and spindlier at the same pt; loses her75's dense magazine color.
4. **Stiff italic** — Bodoni Moda's italic is a restrained sloped roman: no loop
   w, no sweeping g. The intra-word flourish move (the her75 signature) dies.
   opsz 11 / wght 700 fixes only #1; #2–#4 are DNA. No Bodoni Moda setting works.

Fraunces failed for the opposite reason: oldstyle/garalde DNA — angled stress,
soft wedge terminals, low contrast, wonky warmth. "Artisanal coffee shop," never
"fashion editorial," at any axis position (opsz 144 gets contrast but keeps the
sharp angular terminals — still visibly not her75).

## 3. The pick

**Playfair Display, static-instanced from the GF variable:**
roman **wght = 650**, italic **wght = 620** (italic runs optically heavier; 620
balances 650 roman). Shipped name: **Jeni Hero Serif** (OFL Reserved Font Name
compliance — see §6; modified cuts may NOT be named "Playfair Display").

| rank | face | one-line tradeoff |
|---|---|---|
| 1 | **Playfair Display 650/620i** | It IS the her75 face; sturdy hairlines at 38 pt; lush true italic; OFL |
| 2 | Fraunces opsz=144 wght=600 SOFT=0 WONK=0 | Right contrast, zero new family, but terminals stay angular-oldstyle; founder already rejects the Fraunces feel |
| 3 | iOS Bodoni 72 (`BodoniSvtyTwoITCTT-Book/-BookIta`) | Zero bundling, warm didone, but Book(400) too light / Bold(700) too heavy at hero size, small x-height |

Disqualified: DM Serif Display (contrast too low, single weight, friendly-round —
the DM Sans pairing isn't worth missing the register); Prata + Libre Caslon
Display + Abril Fatface (**no italic** → the mixing rule is impossible); Lora
(text face, low contrast); system Didot (too light + rigid italic).

Cap heights nearly match Fraunces (26.9 pt vs 26.6 pt @ 38 pt), so existing hero
layouts won't reflow. The bigger x-height (+12%) is the her75 density, free.

## 4. Exact iOS spec

Files: `JeniHeroSerif-Regular.ttf` (195 KB), `JeniHeroSerif-Italic.ttf` (178 KB)
→ `PlankApp/Resources/Fonts/`. Auto-registration picks them up; PostScript names
verified: `JeniHeroSerif-Regular`, `JeniHeroSerif-Italic`.

Metrics (per cut): UPM 1000, hhea asc 1082 / desc −251 / gap 0 → intrinsic line
height = **1.333 × size**. Cap = 0.708 em, x-height = 0.514 em.
her75 measured cadence ("Become / that girl"): baseline-to-baseline ≈ **1.17 ×
cap height** = 0.828 × size → `lineSpacing ≈ −0.505 × size`.

| token | font + size | lineSpacing (lineGap token) | call-site kerning |
|---|---|---|---|
| `heroHeadline` 38 pt | `Font.custom("JeniHeroSerif-Regular", size: 38, relativeTo: .largeTitle)` | **−19** (was −18) | **−0.4** |
| `heroHeadlineItalic` 38 pt | `"JeniHeroSerif-Italic"`, 38 | (same stack) | −0.4 |
| `questionHero` / `Italic` 34 pt | same faces, 34 | **−17** (was −14) | −0.4 |
| `displayHero` / `Italic` 38 pt | same faces, 38 | **−19** (was −16) | −0.4 |
| `programHeroDisplay` / `Italic` 44 pt (celebration peak) | same faces, 44 | **−22** (was −20) | **−0.5** |
| `mastheadDisplay` ("day one" register) 19 pt | `"JeniHeroSerif-Italic"`, 19, relativeTo: .title3 | n/a (single line) | −0.2 |
| `title` / `titleItalic` 32 pt | same faces, 32 | — | −0.3 |
| `stickyNumeral` 28 pt | `"JeniHeroSerif-Italic"`, 28 | n/a | 0 |

- The −0.505 ratio is "ascenders sit ~7% of cap below the line above" — her75
  exact. If a 3-line stack shows descender/ascender collision (g loop into a cap),
  relax that screen to −0.42 × size (38 pt → −16). Never looser.
- **Weight juxtaposition dies; roman/italic juxtaposition replaces it.** her75
  never mixes Light vs SemiBold — one weight, roman vs italic. `displayHero` and
  `programHeroDisplay` move from Fraunces *Light* to the same 650 roman. Do not
  instance a Light cut.
- Keep existing Dynamic Type clamps (`relativeTo` + `accessibility1`).
- Floor: never set Jeni Hero Serif below 16 pt. The 11 pt micro slots
  (`editorialEyebrow`, `romanOrnament`) stay on Fraunces (hairlines die at micro
  sizes); everything ≥19 pt display-class migrates.
- Delete `BodoniModa-DisplaySemiBold(.Italic).ttf` from Resources/Fonts in the
  same change (dead-code rule). Fraunces cuts stay (micro slots + body italic
  punch words elsewhere).

## 5. The roman/italic intra-word mixing rule (her75 signature)

Observed: **Become** = italic B + roman "ecome" · **Follow** = roman "Follo" +
italic w · **Start** = roman "Star" + italic t · whole-word: *girl*, *routine*,
*friends*, *it*, *your*.

**The rule — max two italic moments per headline, of two kinds:**
1. **Flourish** — ONE letter of the verb, always its **first or last letter**
   (never interior), and only letters whose Playfair italic form is dramatically
   different: **caps B M S K · lowercase w t y g f k**. (Never i l o n u m — the
   italic form is indistinguishable, it just looks like a typo.)
2. **Payload** — the identity/desire word or 2-word phrase, whole-word italic.
   It's the word she wants to be true (*her*, *today*, *yours*, *day one*).

One flourish + one payload max; never both in the same word; payload word is never
also flourished. Implementation = existing concatenation pattern:
`Text("Follo").font(.heroHeadline) + Text("w").font(.heroHeadlineItalic)`.

Six JeniFit examples (lowercase voice, post-Ozempic vocab):
1. star**t** *today* — flourish t + payload today
2. follo**w** your *rhythm* — flourish w + payload rhythm
3. become *her* — payload only
4. make it *yours* — payload only (her75's own "Make *it* official" move)
5. *day one* starts now — payload front-loaded
6. read**y** when you are — flourish y only, no payload

## 6. Implementation commands (verified run on this machine 2026-06-10)

Finished cuts already built + name-table-verified at `/tmp/JeniHeroSerif-Regular.ttf`
and `/tmp/JeniHeroSerif-Italic.ttf`. To reproduce from scratch:

```bash
cd /tmp
curl -sL -o PlayfairDisplay-var.ttf \
  "https://github.com/google/fonts/raw/main/ofl/playfairdisplay/PlayfairDisplay%5Bwght%5D.ttf"
curl -sL -o PlayfairDisplay-Italic-var.ttf \
  "https://github.com/google/fonts/raw/main/ofl/playfairdisplay/PlayfairDisplay-Italic%5Bwght%5D.ttf"
python3 /Users/bko/plankAI/Scripts/make_hero_font_cuts.py
# -> /tmp/JeniHeroSerif-Regular.ttf  (wght=650, PS name JeniHeroSerif-Regular)
# -> /tmp/JeniHeroSerif-Italic.ttf   (wght=620, PS name JeniHeroSerif-Italic)
cp /tmp/JeniHeroSerif-{Regular,Italic}.ttf /Users/bko/plankAI/PlankApp/Resources/Fonts/
```

`Scripts/make_hero_font_cuts.py` does `instantiateVariableFont` (wght pin) then
rewrites name IDs 1/2/3/4/6/16/17. Equivalent one-liner per cut if ever needed:
`python3 -m fontTools.varLib.instancer PlayfairDisplay-var.ttf wght=650 -o out.ttf`
(then rename — raw instancer output keeps the RFN, which we must not ship).

**License:** OFL 1.1 with Reserved Font Name "Playfair Display" — our modified
cuts therefore ship as "Jeni Hero Serif" (no RFN string anywhere in the name
table — already handled by the script). Include Playfair's OFL.txt in the
licenses screen alongside the existing DM Sans/Fraunces attributions.

Optional 60% size cut once glyph usage settles:
`pyftsubset JeniHeroSerif-Regular.ttf --unicodes="U+0020-007E,U+2018-201D,U+2026,U+2192" --output-file=...`
(keep `--layout-features='*'` to preserve the f-ligatures her75 shows in "official").
