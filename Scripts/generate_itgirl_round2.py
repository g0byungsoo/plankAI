#!/usr/bin/env python3
"""it-girl round 2 (founder device QA 2026-06-11).

Regenerates the assets that failed QA (background leaks, mid-air crops)
and adds the filler-sticker set + cuisine food cards. Rebuilds /tmp/cutout
first so the eroded-mask version applies, then re-cuts EVERY raw (old set
included) for halo-free edges.

Run: python3 scripts/generate_itgirl_round2.py
"""
import base64
import concurrent.futures as futures
import json
import os
import subprocess
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "generated_illustrations", "itgirl_set", "raw")
CUT = os.path.join(ROOT, "generated_illustrations", "itgirl_set", "cut")
os.makedirs(RAW, exist_ok=True)
os.makedirs(CUT, exist_ok=True)


def env_key(name):
    with open(os.path.join(ROOT, ".env")) as f:
        for line in f:
            if line.startswith(name + "="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    raise SystemExit(f"missing {name}")


GROK_KEY = env_key("GROK_IMAGINE_API_KEY")

STYLE = (
    " Editorial photograph for a luxury women's wellness magazine, pinterest "
    "it-girl aesthetic, shot on film, warm natural light, soft shadows, "
    "expensive minimal styling, quiet luxury. The ENTIRE subject fully "
    "inside the frame with generous empty cream margin around it on a SOLID "
    "FLAT cream background, edge to edge, no other background elements, no "
    "surface line, no horizon, no text, no watermark."
)

PROMPTS = {
    # ── regenerations (failed device QA) ──
    # full subject so no mid-air canvas crop (was waist-cropped)
    "psych_water": (
        "A stylish young woman standing FULL BODY head to white sneakers, "
        "drinking from a clear glass water bottle, narrow black sunglasses, "
        "tortoiseshell claw clip, ribbed neutral tank and bike shorts, "
        "relaxed stance."
    ),
    # subject was frame-filling -> Vision kept the background
    "identity_calm": (
        "A young woman in a cream waffle robe with a towel wrap in her "
        "hair, holding a small ceramic matcha bowl with both hands, eyes "
        "closed, serene, shown from the waist up, occupying two thirds of "
        "the frame height."
    ),
    "cohort_fruit": (
        "A young woman from the chest up about to bite a slice of "
        "cantaloupe melon, oversized black sunglasses, gold chain "
        "necklace, green top, occupying two thirds of the frame height."
    ),
    # whole composition inside frame (was wrist-cropped at canvas top)
    "preeat_snap": (
        "Seen from a three-quarter top angle: two elegant female hands "
        "with neutral manicure holding a phone, photographing a colorful "
        "grain bowl with salmon and avocado on a plate below. Hands, "
        "phone, full arms to the elbow, and the entire plate all fully "
        "inside the frame."
    ),
    # ── filler sticker set (trend objects) ──
    "filler_anthurium": (
        "Two anthurium flowers on tall stems, one sage green and one soft "
        "pink, glossy heart-shaped blooms."
    ),
    "filler_bouquet": (
        "A bouquet of pink lilies and roses wrapped in brown kraft paper."
    ),
    "filler_matcha_glass": (
        "A tall glass of iced matcha latte with visible ice cubes and a "
        "glass straw, condensation droplets."
    ),
    "filler_books": (
        "A small stack of three aesthetic paperback books in muted pink, "
        "sage and cream covers, slightly fanned."
    ),
    "filler_bracelets": (
        "A woman's wrist wearing three stacked chunky gold bracelets, "
        "hand relaxed, neutral manicure."
    ),
    "filler_tumbler": (
        "A cream insulated tumbler cup with a handle and straw held by a "
        "hand in an oversized knit sleeve."
    ),
    # ── cuisine cards (case 169 revival) ──
    "cuisine_american": (
        "A plate with a gourmet smash burger and a small side salad, "
        "editorial food photography."
    ),
    "cuisine_italian": (
        "A rustic plate of tagliatelle pasta with tomato and basil, "
        "parmesan shavings, editorial food photography."
    ),
    "cuisine_mexican": (
        "Two street tacos with cilantro, lime wedges and pickled onion on "
        "a small plate, editorial food photography."
    ),
    "cuisine_eastasian": (
        "A bowl of korean bibimbap with a soft egg and neat vegetable "
        "sections, chopsticks resting on the bowl, editorial food "
        "photography."
    ),
    "cuisine_southasian": (
        "A small thali plate with curry, basmati rice, and naan bread, "
        "editorial food photography."
    ),
    "cuisine_mediterranean": (
        "A mezze plate with hummus swirl, olive oil, falafel, cucumber "
        "and warm pita triangles, editorial food photography."
    ),
}


def gen(name, prompt, retries=3):
    raw = os.path.join(RAW, f"{name}.jpg")
    if os.path.exists(raw):
        return f"raw exists {name}"
    body = {
        "model": "grok-imagine-image-quality",
        "prompt": prompt + STYLE,
        "response_format": "b64_json",
    }
    for attempt in range(retries):
        try:
            req = urllib.request.Request(
                "https://api.x.ai/v1/images/generations",
                json.dumps(body).encode(),
                {"Content-Type": "application/json", "Authorization": f"Bearer {GROK_KEY}"},
            )
            with urllib.request.urlopen(req, timeout=240) as r:
                d = json.load(r)
            img = d.get("data", [{}])[0].get("b64_json")
            if not img:
                return f"{name}: NO IMAGE {json.dumps(d)[:160]}"
            open(raw, "wb").write(base64.b64decode(img))
            return f"generated {name}"
        except Exception as e:
            if attempt == retries - 1:
                return f"{name}: {e}"
    return f"{name}: exhausted"


# regenerations need their stale raws cleared first
for stale in ("psych_water", "identity_calm", "cohort_fruit", "preeat_snap"):
    for d in (RAW, CUT):
        p = os.path.join(d, f"{stale}.{'jpg' if d == RAW else 'png'}")
        if os.path.exists(p):
            os.remove(p)

# rebuild the cutout tool with the eroded mask
subprocess.run(
    ["swiftc", "-O", os.path.join(ROOT, "scripts", "cutout.swift"), "-o", "/tmp/cutout"],
    check=True,
)

with futures.ThreadPoolExecutor(max_workers=4) as ex:
    for result in ex.map(lambda kv: gen(*kv), PROMPTS.items()):
        print(result)

# re-cut EVERYTHING (old + new) with the eroded mask
for f in sorted(os.listdir(RAW)):
    if not f.endswith(".jpg"):
        continue
    name = f[:-4]
    r = subprocess.run(
        ["/tmp/cutout", os.path.join(RAW, f), os.path.join(CUT, name + ".png")],
        capture_output=True,
        text=True,
    )
    print(("cut " + name) if r.returncode == 0 else f"CUT FAIL {name}: {r.stdout}{r.stderr}")
print("all done")
