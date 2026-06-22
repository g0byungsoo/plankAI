# Reference: "Building a beautiful iOS app with 3 Claude Fable prompts"
Source: founder-shared article (x.com/anshuc/status/2064573467182412103), 2026-06-11.
Author: ex-Apple UI/UX (12 years). Built "Morsel," a personal calorie tracker.
Founder's reaction: "i also checked out article and inspired by the design it's
using... learn as much as possible from this article and help with building the
food log feature."

Companion screenshots (founder-provided, READ THESE):
- /Users/bko/Downloads/Screenshot 2026-06-11 at 2.07.17 AM.png  (timeline "Morsel" — magazine catalog of days, studio food images, day + total cal)
- /Users/bko/Downloads/Screenshot 2026-06-11 at 2.10.42 AM.png  (day page: "JUNE 10 / Today / 300 of 2,000 cal" + macro row + chat-log entries w/ food images)
- /Users/bko/Downloads/Screenshot 2026-06-11 at 2.10.50 AM.png  (day page w/ agent intro + meal rows)
- /Users/bko/Downloads/Screenshot 2026-06-11 at 2.11.05 AM.png  (meal detail: big studio image, name, "190 cal · 9% OF THE DAY · 20:01", macro bars, New Photo / Remove)
- /Users/bko/Downloads/Screenshot 2026-06-11 at 2.11.16 AM.png  (timeline day grid: large hero dish + smaller dishes, alternating sizes)

## Article (lightly condensed, all techniques preserved)

I've used every major AI model for iOS dev. As a launch-day test, I asked Fable
to build me a personal, delightful calorie tracker. Every tracker app is ugly
React/Flutter slop. Logging takes a bunch of taps and searching. I wanted a
simple, delightful app where I could just dump everything into an agent.

It built the whole thing, including: Nano Banana for image generation with a
custom Metal shader effect; an agent (personality, persistent memory, tool
calling, token streaming, Anthropic prompt-caching headers); USDA database for
accurate nutrition info. First pass didn't feel human-designed (generic AI
gradients, messy layout, pops/transition glitches); a couple more aesthetics-
focused passes fixed it.

### Learnings
- **Build a loop for the model to check its own aesthetics.** Highest-leverage
  instruction: directly manipulate the simulator, test every interaction and
  transition, verify every frame and pixel. The model figured out the tools
  itself: brew-installed idb to simulate touch events; ffmpeg/ffprobe to record
  the simulator and dump frames; custom Python/PIL scripts for pixel diffs
  between frames, cropping/zooming frames, fixing pops and hitches.
- Set the intent: flawless, smooth, hitch-free; require frame-level
  verification of animations.

### The prompts (condensed to the design-relevant intent)
1. One-shot: "super clean, minimalist, design-forward... sweat every tiny
   detail, super premium. One unified conversational experience — each day is
   a thread with an agent that has tools (nutrition DB, history). Food entries
   should be beautiful: studio-photo-looking images with consistent styling.
   Zoom out of the thread into a scrollable timeline where each meal is
   represented by its image — a premium magazine catalog view. Fluid
   transitions, fun gestures, bouncy Apple-y liquid-glass feel. Shader effects
   for transitions and token streaming."
2. Design pass: "100x the design — every pixel perfect, every transition
   flawless frame to frame. Audit every frame/pixel. Top 1% of human
   designers, Apple Design Award eligible."
3. Steering: "the alternating layout is a bit cheesy. Simplify, go more
   image-centric. Tiles should flow smoothly between the card and grid views
   — gorgeous custom transitions, not boring view-controller transitions."

### Design language visible in the screenshots
- Warm off-white canvas; near-black ink; ONE accent (burnt orange) used only
  on the day-progress bar.
- Eyebrow date ("JUNE 10") + huge day title ("Today") + huge cal numeral with
  small "of 2,000 cal" unit; thin progress hairline; macro row "22 PROTEIN ·
  32 CARBS · 9 FAT" (number bold, label tiny tracked caps).
- Food entries: studio-style image on a small plate (consistent styling,
  transparent/white bg) + name + portion + "120 cal 6P 10C 6F" micro-row.
- Timeline: days as sections (eyebrow date + day name + right-aligned total),
  meals as floating dish images at varying sizes, hero dish large; whitespace
  does the separation, zero card chrome.
- Meal detail: image hero, name + portion, big cal numeral, "9% OF THE DAY ·
  20:01" context line, macro slider-bars with right-aligned grams, quiet
  pill actions (New Photo / Remove).
