#!/usr/bin/env python3
"""
Generate JeniFit Method lesson illustrations via the xAI / Grok Imagine API.

Reads GROK_IMAGINE_API_KEY from the repo's .env, sends one image request per
prompt in the manifest below, downloads the JPEG, and saves to
PlankApp/Resources/lesson_illustrations/. Idempotent at the file level — skips
any prompt whose output file already exists (delete locally to regenerate).

Cost: ~$0.02 per image with `grok-imagine-image`. The full manifest (~23
images) is well under $1.

Usage:
    python3 scripts/generate_lesson_illustrations.py
    python3 scripts/generate_lesson_illustrations.py --force      # regenerate even if file exists
    python3 scripts/generate_lesson_illustrations.py --only d1_   # only filenames matching prefix

The style preamble is shared across every prompt so all 23 illustrations
read as one set. Per-card prompts only describe the specific scene. Keep
new prompts terse + body-neutral + text-free.
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
ENV_PATH = REPO_ROOT / ".env"
OUT_DIR = REPO_ROOT / "PlankApp" / "Resources" / "lesson_illustrations"

API_URL = "https://api.x.ai/v1/images/generations"
MODEL = "grok-imagine-image"  # cheaper tier; bump to grok-imagine-image-quality for hero polish

# Shared style preamble — every prompt prepends this so the 23 illustrations
# read as one editorial set. Palette codes match DesignSystem/Tokens.swift.
STYLE_PREAMBLE = (
    "Editorial paper-craft style illustration. Soft warm cream background (#FDF6F4). "
    "Layered paper-cut texture, subtle grain. Color palette: cream (#FDF6F4), "
    "dusty rose pink (#C4677A), warm cocoa brown (#3D2A2A), soft pink accent (#F5D5D8). "
    "Hand-drawn craft feel, calm, hopeful, body-neutral. "
    "No text, no logos, no facial features on any figures. "
    "Square composition, 1024x1024."
)

# Phase 9.13 — character-illustration style with chroma-key background.
# Grok Imagine outputs JPEG (no alpha channel), so we generate on a
# vivid pure green (#00FF00) chroma backdrop and then post-process that
# color → transparent PNG. The green is a color that absolutely will not
# appear in the figure (no green clothing, no green plants), which is
# why the prompt explicitly forbids it inside the character itself.
CHROMA_PREAMBLE = (
    "Flat editorial illustration in the Storyset wellness style. "
    "The ENTIRE background must be a SOLID pure chroma green #00FF00 "
    "(vivid neon green, NOT pastel, NOT olive, NOT mint) — fill the "
    "entire canvas with this exact green, edge to edge, NO cream, NO "
    "white, NO gradient, NO shadow on the background. NO green color "
    "anywhere else in the image — no green clothing, no green plants, "
    "no green objects, no green accents on the figure. Color palette "
    "for the figure: warm light-brown skin (#C99880), dark brown hair "
    "(#3D2A2A), dusty rose pink clothing (#C4677A), soft pink accents "
    "(#F5D5D8), cream highlights (#FDF6F4), warm cocoa brown linework "
    "(#3D2A2A). Single character. Centered composition. NO text, NO "
    "logos, NO numbers. Storyset flat vector style, square 1024x1024."
)

# Per-illustration scene descriptions. Key = filename stem (used as
# Assets.xcassets / SwiftUI Image("...") name). Value = the scene-specific
# part of the prompt; STYLE_PREAMBLE is prepended automatically.
PROMPTS: dict[str, str] = {
    # ── Day 1 — why this works ──────────────────────────────────────
    "lesson_d1_hero": (
        "Abstract minimal silhouette of a woman from behind, looking toward "
        "a soft pink horizon. Calm posture, hopeful. No specific body shape."
    ),
    "lesson_d1_science": (
        # Phase 9.13 — content-tied. Beat says "muscle changes the
        # math — kg for kg, muscle burns 3x more energy at rest …
        # your body spends every day, even sitting still." So the
        # illustration shows the woman SITTING CALMLY with a warm
        # mug, while soft warm energy/glow lines radiate gently
        # from her arms and core — visualizes muscle as a quiet
        # engine running while resting. NOT a flex pose; the whole
        # point is "even when you're doing nothing."
        "Young woman seated comfortably cross-legged on the floor, "
        "leaning gently against an unseen wall. Dark brown hair in "
        "a loose low ponytail with a small pink scrunchie. Warm "
        "light-brown skin. Wearing a relaxed dusty rose cropped "
        "sweatshirt and cream high-waisted joggers. Holding a warm "
        "cream-colored mug in both hands at her lap, looking down "
        "softly at it with a calm content half-smile, eyes lowered. "
        "Subtle pink cheek blush. Around her arms and torso, soft "
        "warm GOLDEN glow rays radiate gently outward in a few thin "
        "lines (suggesting metabolic warmth) — golden #E8B86A, very "
        "soft, like sunlight. The glow lines must be SUBTLE and "
        "decorative, never overpowering. Body-neutral — loose "
        "sweatshirt, no curves emphasized. Pose communicates "
        "'resting, but my body is still working.' Single character. "
        "Storyset wellness flat vector style. Composition centered, "
        "figure occupies the middle 70% of the canvas."
    ),
    "lesson_d1_scenario_two": (
        "Two paper-craft female silhouettes standing side by side at a "
        "horizon line. Left figure slightly receding, in lighter cream. "
        "Right figure standing taller and forward, in dusty rose. No faces, "
        "no specific body shape — abstract."
    ),
    "lesson_d1_recomp": (
        # Phase 9.13 — content-tied. Beat says "right now you're in
        # a rare window … your body can do something it won't always
        # be able to — lose fat and build muscle at the same time."
        # So the illustration shows the woman CUPPING a small
        # glowing bloom in her hands at chest height, looking down
        # at it tenderly — visualizes the "rare window" as something
        # precious you hold gently. Connects visually to the
        # breath_bloom motif used throughout the ritual (iridescent
        # painted torus). The bloom is the recomp window — soft,
        # luminous, treated with care.
        "Young woman with dark brown hair in a soft chin-length bob, "
        "a small pink flower tucked behind her ear. Warm light-brown "
        "skin. Wearing a dusty rose puff-sleeve blouse with small "
        "pearl buttons. Standing facing the viewer slightly, head "
        "tilted down with a tender hopeful expression. Both hands "
        "are CUPPED together in front of her chest, holding a small "
        "luminous floating BLOOM — an iridescent rose-and-cream "
        "petal-bloom (like a small painterly flower) that glows "
        "softly with a warm pink halo. The bloom must be the visual "
        "focal point inside her cupped hands. Soft golden-pink light "
        "radiates upward from the bloom onto her face and hands. "
        "Subtle pink cheek blush, gentle small smile, eyes lowered "
        "to look at the bloom. Body-neutral — loose blouse, no "
        "curves emphasized. Pose communicates 'holding something "
        "rare and precious.' Single character. Storyset wellness "
        "flat vector style. Composition centered, figure occupies "
        "the middle 70% of the canvas, bloom in her hands is the "
        "brightest area of the image."
    ),
    "lesson_d1_close": (
        "A small pink paper heart cut from layered paper, floating slightly "
        "off the cream background with a soft shadow. Minimal. One heart, "
        "centered, beautiful."
    ),

    # ─── Phase 9.21 — Days 2-5 ritual illustrated-explanation beats ──
    # Chroma-keyed (CHROMA_PREAMBLE) PNG. Same Storyset character
    # treatment as lesson_d1_science / lesson_d1_recomp so the four
    # days visually read as one set.

    "lesson_d2_consistency": (
        # Day 2 — "small you do beats heroic you can't". Visualize
        # the consistency rule with a calendar of check marks.
        "Young woman with dark brown hair in a soft ponytail, warm "
        "light-brown skin, wearing a dusty rose cropped tank top and "
        "cream-colored joggers. Standing facing the viewer holding up "
        "a small paper monthly calendar in both hands at chest height. "
        "The calendar has a row of tiny pink heart check-marks running "
        "across the visible week — one heart per day, evenly spaced. "
        "Her expression is calm and quietly proud — small almond eyes, "
        "soft confident smile, subtle pink cheek blush. The calendar is "
        "the bright focal point. Body-neutral — loose tank, relaxed "
        "joggers. Pose communicates 'i kept showing up.' Single "
        "character. Storyset wellness flat vector style. Composition "
        "centered, figure occupies the middle 70% of canvas."
    ),

    "lesson_d3_neat": (
        # Day 3 — "your steps add up to more than your workout".
        # Visualize NEAT with a woman walking outdoors casually.
        "Young woman with dark brown hair in a soft low ponytail with "
        "a pink scrunchie, warm light-brown skin. Wearing a dusty rose "
        "cropped sweatshirt, cream joggers, and a small wristwatch. "
        "Mid-stride walking briskly to the right, body in a confident "
        "casual walking pose — one foot forward, arms swinging "
        "naturally. Carrying a soft pink reusable tote bag in one hand. "
        "Friendly expression — small almond eyes, soft smile, subtle "
        "pink cheek blush. Above and around her head a few small dusty "
        "rose dots and tiny step-icons floating (suggesting steps "
        "accumulating). Body-neutral — loose sweatshirt, comfortable "
        "joggers. Pose communicates 'i'm just walking, and it counts.' "
        "Single character. Storyset wellness flat vector style. "
        "Composition centered, figure occupies middle 70% of canvas."
    ),

    "lesson_d4_protein": (
        # Day 4 — "protein at every meal. that's it." Visualize a
        # warm balanced plate held by the woman, palm-sized protein.
        "Young woman with dark brown hair in a chin-length bob, warm "
        "light-brown skin. Wearing a dusty rose puff-sleeve blouse with "
        "small pearl buttons. Sitting at a small cream-colored table, "
        "facing the viewer, holding up a round cream-and-rose paper "
        "plate in both hands at chest height. The plate has THREE "
        "distinct soft shapes on it — one warm rose/brown palm-sized "
        "shape (representing a protein portion like chicken or salmon), "
        "one cream rounded shape (a grain like rice), and small green "
        "leafy shapes (vegetables). Generous, abundant. NO specific "
        "branding, NO logos, NO text on the plate. Her expression is "
        "calm and content — soft smile, eyes lowered toward the plate, "
        "subtle pink cheek blush. Body-neutral. Pose communicates "
        "'this is enough.' Single character. Storyset wellness flat "
        "vector style. Composition centered."
    ),

    "lesson_d5_sleep": (
        # Day 5 — "rest is offensive, not optional". Visualize the
        # nightly stretch + cozy bedtime ritual.
        "Young woman with dark brown hair in a loose low side bun, "
        "warm light-brown skin. Wearing soft cream pajamas with tiny "
        "dusty rose flower print and small dusty-rose slippers. Sitting "
        "cross-legged on the edge of a low bed with a soft cream quilt "
        "and dusty rose throw pillow. Body posture: gentle forward fold "
        "stretch, hands reaching softly toward her feet, head slightly "
        "bowed. Calm peaceful expression — small almond eyes closed or "
        "softly lowered, soft content smile, subtle pink cheek blush. "
        "Soft warm cream-and-pink lamp glow from her left side. A small "
        "phone face-down on the nightstand beside the bed. Pose "
        "communicates 'i am letting the day end.' Body-neutral — loose "
        "pajamas, comfortable. Single character. Storyset wellness flat "
        "vector style. Composition centered, figure + bed occupy middle "
        "70% of canvas."
    ),

    # ── Day 2 — don't lose the good stuff (legacy paper-craft set) ──
    "lesson_d2_hero": (
        "Abstract paper-craft column or pillar in dusty rose pink, standing "
        "tall and strong against the cream background. Like a piece of "
        "architecture made of cut paper. Represents muscle as foundation."
    ),
    "lesson_d2_validation": (
        "A woman silhouette stepping forward, with her past silhouettes "
        "echoing softly behind her in lighter cream tones. Abstract, no "
        "specific body shape, no face. Like a sequence of paper cut-outs."
    ),
    "lesson_d2_science": (
        "A simple paper-craft balance scale, perfectly level. Two small "
        "stacks on each side made of small paper rectangles in dusty rose "
        "and cream. Minimal, elegant."
    ),
    "lesson_d2_reframe": (
        "Two paper-craft figures in profile facing each other on a flat "
        "horizon line. Left figure standing where she started (lighter, "
        "receded). Right figure walking forward into the light (cocoa "
        "brown, upright). No facial features."
    ),
    "lesson_d2_close": (
        "A pink paper heart in the center, with three small cocoa brown "
        "geometric shapes scattered around it (small triangles or "
        "diamonds). Represents heart + strength. Minimal."
    ),

    # ── Day 3 — your workouts are the protection ────────────────────
    "lesson_d3_hero": (
        "Abstract paper-craft figure with arms gently spread like a shield "
        "or protection stance. Behind her, layered paper sheets in cream "
        "and rose stacked like a fortress wall. No face, no specific body."
    ),
    "lesson_d3_science": (
        "A vertical stack of paper layers, alternating cream and dusty "
        "rose, building up steadily like building blocks. Represents "
        "muscle being preserved layer by layer."
    ),
    "lesson_d3_head_start": (
        "A small paper-craft figure beginning to grow taller, with small "
        "paper sparkles or rays emanating outward from her. Like the "
        "first moments of bloom. Abstract, no face."
    ),
    "lesson_d3_close": (
        "A single dusty rose pink paper star, hand-cut, sitting slightly "
        "off-center against cream. Minimal celebration of the work."
    ),

    # ── Day 4 — eat to fuel (ED-sensitive — extra care) ─────────────
    "lesson_d4_hero": (
        "A simple round paper-craft plate viewed from above. A soft "
        "dusty-rose curved shape on one section of the plate (an abstract "
        "protein) plus small cream shapes (an abstract grain or vegetable). "
        "Calm, abundant. NOT empty, NOT measured, NOT minimal-as-restriction. "
        "Generous and warm."
    ),
    "lesson_d4_plate_principle": (
        "Three round paper-craft plates arranged in a small cluster. Each "
        "plate has a generous warm shape representing food. Abundance, not "
        "restriction. Soft pink and cream tones. No utensils, no faces, "
        "no people."
    ),
    "lesson_d4_tired_card": (
        "An abstract paper-craft woman silhouette transitioning from a "
        "drooping, low-energy posture on the left to an upright, restored "
        "posture on the right. Two paper figures side by side. No face."
    ),
    "lesson_d4_close": (
        "A pink paper heart in the center, with a small warm paper plate "
        "shape glowing softly beneath it. Represents food + heart together. "
        "Gentle, no specific food items."
    ),

    # ── Day 5 — trust the trend (ED-sensitive) ──────────────────────
    "lesson_d5_hero": (
        "A simple abstract paper-craft weight scale viewed from the side. "
        "Just the outline / shape, dusty rose. Empty (nothing on it). "
        "Sitting calmly. NO numbers, NO digits, NO display."
    ),
    "lesson_d5_science": (
        "A paper-craft line chart drawn as if cut from rose-colored ribbon, "
        "showing a gentle downward trend with small bumps up and down along "
        "the way (the noise). The overall arc is calm and downward. No "
        "axes, no numbers, no text."
    ),
    "lesson_d5_what_progress_is": (
        "Paper-craft stairs ascending diagonally, with a small abstract "
        "figure walking up them confidently. Each step is a layer of "
        "paper. Hopeful, body-neutral, no face."
    ),
    "lesson_d5_recomp": (
        "A simple paper-craft balance scale, perfectly level. On the left "
        "platform: a STACK OF GEOMETRIC PAPER LAYERS — alternating cream "
        "and soft pink rectangles. On the right platform: a STACK OF "
        "GEOMETRIC PAPER LAYERS of the same total height — but using "
        "dusty rose and cocoa brown rectangles. The two stacks are "
        "EXACTLY the same height (same weight) but different colors "
        "(different composition). STRICTLY NO HUMAN FIGURES. NO BODIES. "
        "NO SILHOUETTES. NO PEOPLE. Pure geometric paper layers + scale."
    ),
    "lesson_d5_close": (
        "A large dusty rose paper heart in the center, with small paper "
        "sparkles scattered around it like confetti. Celebration of the "
        "5-day journey. Joyful but not loud."
    ),

    # ─── Phase 10 — Days 2-14 primer fact-screen illustrations ───────
    # Chroma-keyed character illustrations, same Storyset treatment as
    # lesson_d2_consistency so the expanded arc reads as one set. Shared
    # appearance: dark brown hair, warm light-brown skin, dusty rose top
    # + cream bottoms, subtle pink blush, body-neutral loose clothing.
    "lesson_d2_paradox": (
        "Young woman with dark brown hair in a loose low ponytail, warm "
        "light-brown skin, dusty rose cropped sweatshirt and cream "
        "joggers, subtle pink cheek blush. Standing outdoors mid-stroll "
        "on a soft pink path, relaxed and content, one hand resting "
        "gently over her heart, calm half-smile, eyes forward and "
        "peaceful. Behind her a faint translucent treadmill-display "
        "number floats and is gently dissolving into soft pink dots. "
        "Body-neutral, loose clothing, no curves emphasized. Pose "
        "communicates 'i move for how it feels, not the number.' Single "
        "character. Storyset wellness flat vector style. Composition "
        "centered, figure occupies the middle 70% of the canvas."
    ),
    "lesson_d4_plank": (
        "Young woman with dark brown hair in a soft bun, warm light-brown "
        "skin, dusty rose tank and cream leggings, subtle pink cheek "
        "blush. Holding a steady forearm plank on a soft cream mat, body "
        "in a calm straight line, serene focused expression with eyes "
        "lowered. A few soft golden stillness-glow lines radiate gently "
        "around her core (golden #E8B86A, subtle). Body-neutral, loose "
        "fit. Pose communicates 'quiet strength, holding still.' Single "
        "character. Storyset wellness flat vector style. Composition "
        "centered, figure occupies the middle 70% of the canvas."
    ),
    "lesson_d5_walk": (
        "Young woman with dark brown hair in a loose ponytail, warm "
        "light-brown skin, dusty rose oversized tee and cream joggers, "
        "subtle pink cheek blush. Taking a gentle relaxed walk, mid-step, "
        "a small steaming cream teacup motif floating softly beside her, "
        "calm content smile. A soft pink path curves under her feet. "
        "Body-neutral, loose clothing. Pose communicates 'an easy little "
        "walk after eating.' Single character. Storyset wellness flat "
        "vector style. Composition centered, figure occupies the middle "
        "70% of the canvas."
    ),
    "lesson_d7_habit": (
        "Young woman with dark brown hair in a soft bob, warm light-brown "
        "skin, dusty rose puff-sleeve top and cream trousers, subtle pink "
        "cheek blush. Kneeling and tending a small potted seedling with "
        "two tiny green leaves, watering it from a little cream watering "
        "can, patient tender expression. A few soft sprout-glow dots rise "
        "from the pot. Body-neutral, loose fit. Pose communicates 'small "
        "daily care, over time.' Single character. Storyset wellness flat "
        "vector style. Composition centered, figure occupies the middle "
        "70% of the canvas."
    ),
    "lesson_d8_return": (
        "Young woman with dark brown hair in a loose ponytail, warm "
        "light-brown skin, dusty rose sweatshirt and cream joggers, "
        "subtle pink cheek blush. Gently rising back up from a soft "
        "kneel, one hand pushing off the floor, the other reaching "
        "forward, hopeful soft-determined expression. A gentle upward "
        "arc of small pink dots beside her. Body-neutral, loose clothing. "
        "Pose communicates 'getting back up, coming back.' Single "
        "character. Storyset wellness flat vector style. Composition "
        "centered, figure occupies the middle 70% of the canvas."
    ),
    "lesson_d9_kindness": (
        "Young woman with dark brown hair in a soft low bun, warm "
        "light-brown skin, dusty rose knit top and cream trousers, subtle "
        "pink cheek blush. Standing with both hands pressed softly over "
        "her own heart, eyes gently closed, a warm tender self-"
        "compassionate smile. A soft pink heart-glow radiates from her "
        "chest. Body-neutral, loose fit. Pose communicates 'being kind to "
        "myself.' Single character. Storyset wellness flat vector style. "
        "Composition centered, figure occupies the middle 70% of the "
        "canvas."
    ),
    "lesson_d11_enjoy": (
        "Young woman with dark brown hair in a bouncy ponytail, warm "
        "light-brown skin, dusty rose cropped tee and cream joggers, "
        "subtle pink cheek blush. Moving joyfully mid-sway with small "
        "headphones on, eyes closed, a relaxed happy smile. A couple of "
        "soft music-note motifs and small pink sparkles float around her. "
        "Body-neutral, loose comfy clothing. Pose communicates 'movement "
        "that's actually fun.' Single character. Storyset wellness flat "
        "vector style. Composition centered, figure occupies the middle "
        "70% of the canvas."
    ),
    "lesson_d12_snack": (
        "Young woman with dark brown hair in a loose ponytail, warm "
        "light-brown skin, dusty rose tee and cream joggers, subtle pink "
        "cheek blush. Climbing a short flight of soft cream stairs with a "
        "light energetic spring, one foot up a step, a small cream "
        "reusable tote in one hand, bright but calm expression. A few "
        "soft motion dashes trail behind her. Body-neutral, loose "
        "clothing. Pose communicates 'a quick burst of movement woven "
        "into the day.' Single character. Storyset wellness flat vector "
        "style. Composition centered, figure occupies the middle 70% of "
        "the canvas."
    ),
    "lesson_d14_freshstart": (
        "Young woman with dark brown hair in a soft bob, warm light-brown "
        "skin, dusty rose blouse and cream trousers, subtle pink cheek "
        "blush. Gently pushing open a soft arched door toward warm "
        "golden-pink morning light that washes over her, hopeful peaceful "
        "expression with eyes toward the light. A couple of small "
        "sparkles drift in the doorway. Body-neutral, loose fit. Pose "
        "communicates 'a fresh start, beginning again.' Single character. "
        "Storyset wellness flat vector style. Composition centered, "
        "figure occupies the middle 70% of the canvas."
    ),
}


def load_env() -> str:
    """Read GROK_IMAGINE_API_KEY from .env. Errors loudly if missing."""
    if not ENV_PATH.exists():
        sys.exit(f"missing .env at {ENV_PATH}")
    pattern = re.compile(r"^GROK_IMAGINE_API_KEY\s*=\s*(.+)$")
    for line in ENV_PATH.read_text().splitlines():
        match = pattern.match(line)
        if match:
            return match.group(1).strip().strip('"').strip("'")
    sys.exit("GROK_IMAGINE_API_KEY not found in .env")


# Names that use the character-illustration chroma-key pipeline
# (woman/figure illustrations that need transparent backgrounds so they
# sit cleanly inside the pink rounded frame in JeniMethodRitualView).
# Everything else uses the original STYLE_PREAMBLE (paper-craft on cream).
CHROMA_NAMES = {
    # Day 1 (existing)
    "lesson_d1_science", "lesson_d1_recomp",
    # Phase 9.21 — Days 2-5 illustrated-explanation beats. Same
    # Storyset character treatment as Day 1, chroma-keyed PNG.
    "lesson_d2_consistency", "lesson_d3_neat",
    "lesson_d4_protein", "lesson_d5_sleep",
    # Phase 10 — Days 2-14 primer fact-screen illustrations.
    "lesson_d2_paradox", "lesson_d4_plank", "lesson_d5_walk",
    "lesson_d7_habit", "lesson_d8_return", "lesson_d9_kindness",
    "lesson_d11_enjoy", "lesson_d12_snack", "lesson_d14_freshstart",
}


def generate_one(api_key: str, name: str, prompt: str, *, retries: int = 2) -> tuple[str, int]:
    """Call the API for one image. Returns (image_url, cost_ticks). Retries on transient errors."""
    preamble = CHROMA_PREAMBLE if name in CHROMA_NAMES else STYLE_PREAMBLE
    payload = json.dumps({
        "model": MODEL,
        "prompt": f"{preamble} {prompt}",
        "n": 1,
    }).encode("utf-8")
    request = urllib.request.Request(
        API_URL,
        data=payload,
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
    )
    last_error: Exception | None = None
    for attempt in range(retries + 1):
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                body = json.loads(response.read())
            url = body["data"][0]["url"]
            cost = body.get("usage", {}).get("cost_in_usd_ticks", 0)
            return url, cost
        except Exception as e:
            last_error = e
            if attempt < retries:
                wait = 2 ** attempt
                print(f"  [{name}] attempt {attempt + 1} failed ({e}); retrying in {wait}s")
                time.sleep(wait)
    raise RuntimeError(f"generation failed after {retries + 1} attempts: {last_error}")


def chroma_key_to_png(src_jpg: Path, dest_png: Path) -> None:
    """Convert a chroma-green JPEG to a transparent PNG.

    Grok Imagine outputs JPEG (no alpha). For character illustrations we
    prompt for a vivid pure green (#00FF00) background, then mask out
    that range here. JPEG compression smears the chroma edge a bit, so
    we use a tolerant HSV-style heuristic: pixel is "green-enough" if
    its G channel is dominant over both R and B AND total green-cast is
    high. Edges get a partial alpha so the cutout doesn't look jagged.

    Falls back to a hard mask if PIL is missing — but PIL is required
    for the alpha output, so we just import it lazily and let the
    ImportError bubble with a useful message.
    """
    try:
        from PIL import Image
    except ImportError:
        sys.exit("Pillow not installed — run: pip3 install Pillow")

    img = Image.open(src_jpg).convert("RGBA")
    pixels = img.load()
    w, h = img.size
    keyed = 0
    feathered = 0
    # Thresholds tuned for Grok Imagine's actual chroma output, which
    # tends to drift toward (93, 231, 21) lime rather than pure neon
    # #00FF00. The reliable signal is "green dominates by a wide
    # margin" — `g - max(r, b)` — not absolute g/r/b values.
    for y in range(h):
        for x in range(w):
            r, g, b, _ = pixels[x, y]
            green_dom = g - max(r, b)
            # Hard mask: pixel is unmistakably the chroma backdrop.
            if g >= 180 and r <= 130 and b <= 130 and green_dom >= 100:
                pixels[x, y] = (0, 0, 0, 0)
                keyed += 1
            # Soft feather: edges where JPEG smeared green into the
            # figure. Map green_dom 40..120 → alpha 220..20 so the
            # edge fades smoothly to transparent without a hard halo.
            elif g > 140 and green_dom >= 40 and r < 200 and b < 200:
                alpha = max(20, min(220, int(220 - (green_dom - 40) * 2.5)))
                pixels[x, y] = (r, g, b, alpha)
                feathered += 1
    img.save(dest_png, "PNG", optimize=True)
    print(f"    keyed {keyed:>7} px hard, {feathered:>6} px feathered → {dest_png.name}")


def download(url: str, dest: Path) -> None:
    """Fetch the generated image and save to disk. Some CDNs (including
    xAI's imgen) block the default Python-urllib User-Agent with 403, so
    we send a browser-shape header."""
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) "
                          "AppleWebKit/537.36 (KHTML, like Gecko) Safari/605.1.15",
        },
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        dest.write_bytes(response.read())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="regenerate even if output exists")
    parser.add_argument("--only", default="", help="only generate filenames containing this substring")
    args = parser.parse_args()

    api_key = load_env()
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    to_run = {n: p for n, p in PROMPTS.items() if (not args.only) or args.only in n}
    print(f"manifest: {len(PROMPTS)} total; running {len(to_run)} (model={MODEL})")

    total_cost_ticks = 0
    generated = 0
    skipped = 0
    for name, prompt in to_run.items():
        is_chroma = name in CHROMA_NAMES
        # Chroma names ship as transparent PNG; everything else stays JPG.
        final_ext = "png" if is_chroma else "jpg"
        out_path = OUT_DIR / f"{name}.{final_ext}"
        if out_path.exists() and not args.force:
            print(f"  skip {name} (exists)")
            skipped += 1
            continue
        print(f"  gen  {name} …", end=" ", flush=True)
        url, cost = generate_one(api_key, name, prompt)
        if is_chroma:
            # Download raw JPEG to a temp file in the same dir, then
            # post-process to transparent PNG, then drop the temp JPEG.
            tmp_jpg = OUT_DIR / f"{name}.chroma.jpg"
            download(url, tmp_jpg)
            print(f"saved ({cost / 1e10:.3f} USD)")
            chroma_key_to_png(tmp_jpg, out_path)
            tmp_jpg.unlink(missing_ok=True)
        else:
            download(url, out_path)
            print(f"saved ({cost / 1e10:.3f} USD)")
        total_cost_ticks += cost
        generated += 1
        # Cost is in "ticks" — xAI's micro-USD unit. 1 USD ≈ 10^10 ticks
        # based on observed grok-imagine-image price 200,000,000 ≈ $0.02.
        time.sleep(0.3)  # gentle rate limit; the API hasn't returned 429 in testing

    total_usd = total_cost_ticks / 1e10
    print(f"done — generated {generated}, skipped {skipped}, total cost ≈ ${total_usd:.2f}")
    print(f"output: {OUT_DIR}")


if __name__ == "__main__":
    main()
